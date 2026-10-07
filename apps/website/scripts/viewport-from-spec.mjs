#!/usr/bin/env node
// viewport-from-spec.mjs -- the site's viewport contract from `specs/ui/viewport.t27`.
//
// Reads the vendored `public/t27/files/specs/ui/viewport.t27` through the real compiler
// (`t27_compiler.wasm`), checks the constant schema, evaluates every `test` block of the
// spec against the declared constants, and writes two generated files nobody edits by hand:
//
//   src/lib/viewport.generated.ts     the constants, the matrix, and `tierOf(width)`
//   src/styles/viewport.generated.css  `:root { --bp-phone-max: 600px; ... }`
//
// Nothing here parses a `.t27` with a regular expression; constants and test asserts come
// from the compiler's AST. The asserts are evaluated here on purpose: the analyzer's
// `typecheck.ok` is necessary, not sufficient (it stays true for `assert 1 > 2`), so a spec
// whose own tests do not hold must not produce a green build.
//
// Run:      node scripts/viewport-from-spec.mjs            (write)
//           node scripts/viewport-from-spec.mjs --check    (fail if the committed files are stale)
//           node scripts/viewport-from-spec.mjs --json     (print the constants as JSON for the QA contracts)
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { SITE, checkSchema, compilerErrors, constsOf, loadCompiler, sha256, verdictOf } from './agents-from-specs.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
export const VIEWPORT_SPEC = 'public/t27/files/specs/ui/viewport.t27'
export const TS_OUT = 'src/lib/viewport.generated.ts'
export const CSS_OUT = 'src/styles/viewport.generated.css'
export const EXPECTED_MODULE = 'ui_viewport'

export const VIEWPORT_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', GENERATED: 'arr',
  TIERS: 'arr', PHONE_MAX: 'u16', TABLET_MAX: 'u16', DESKTOP_MAX: 'u16', COARSE_POINTER_QUERY: 'str', HEADER_CHROME_MAX: 'u16',
  PHONE_PANES: 'u8', TABLET_PANES: 'u8', DESKTOP_PANES: 'u8', ONE_SCROLLER_PER_PANE: 'bool', DOCUMENT_SCROLLS: 'bool',
  TOUCH_TARGET_MIN_PX: 'u8', BACK_CONTROL_MIN_PX: 'u8',
  VIEWPORTS: 'arr', VIEWPORT_WIDTHS: 'arr-u16', VIEWPORT_HEIGHTS: 'arr-u16', VIEWPORT_TIERS: 'arr', DESKTOP_REFERENCE_WIDTH: 'u16',
  RAIL_TILES: 'u8', RAIL_TILE_W_COMPACT: 'u8', RAIL_TILE_GAP_COMPACT: 'u8', RAIL_TILE_H_COMPACT: 'u8', RAIL_CLIENT_W_PHONE: 'u16',
  RAIL_TILE_H_COLUMN: 'u8', RAIL_TILE_GAP_COLUMN: 'u8', RAIL_CHROME_H: 'u16', RAIL_ROW_H_COLUMN: 'u8', RAIL_ROW_W_COMPACT: 'u8',
  RAIL_MIN_VISIBLE: 'u8', RAIL_CAPACITY_BY_HEIGHT: 'arr-u8',
}
export const TIER_NAMES = ['phone', 'tablet', 'desktop', 'wide']

// ---------------------------------------------------------------------------
// Test blocks. The evaluator is the one the player ships -- public/play/t27run.js,
// the interpreter over the compiler's AST -- imported here so the build and the
// browser run the SAME code and cannot disagree about what a spec's tests mean.
// Until #1477 this file carried a second, weaker reader (literals, constant
// identifiers, indexing, integer operators) that read "statement is not an
// assert" for every local, call, struct or branch a spec's test used, which is
// why hardware specs could not be gated at build time.
// ---------------------------------------------------------------------------
import { runSpec } from '../public/play/t27run.js'

/**
 * Every assert of every test block, evaluated by the player's evaluator.
 * Returns { tests, asserts, failures[] }: the count of blocks, the count of
 * assertions checked, and one line per block that did not pass. A block the
 * evaluator cannot run is a failure here too -- a skip is never a green build.
 *
 * `env` is no longer read: t27run resolves the module's own constants from the
 * AST (and computes them, which the old reader could not). The parameter stays
 * because five importers pass it.
 */
export function runSpecTests(analysis, env) {
  void env
  const blocks = (analysis.ast?.children ?? []).filter((n) => n.kind === 'TestBlock' || n.kind === 'InvariantBlock')
  if (!analysis.ast) return { tests: 0, asserts: 0, failures: [] }
  const r = runSpec(analysis.ast)
  const failures = []
  let k = 0
  for (const b of r.results) {
    for (const a of b.asserts) {
      k++
      if (!a.ok) failures.push(`${b.name}: assert #${k} is false${a.detail && a.detail !== 'is false' ? ` (${a.detail})` : ''}`)
    }
    if (b.asserts.length === 0) failures.push(`${b.name}: ${b.reason || 'no assert to check'}`)
    else if (b.status !== 'pass') failures.push(`${b.name}: ${b.reason || 'assertion failed'}`)
  }
  return { tests: blocks.length, asserts: r.results.reduce((n, b) => n + b.asserts.length, 0), failures }
}

// ---------------------------------------------------------------------------
// Semantic checks the schema cannot express.
// ---------------------------------------------------------------------------
export function semanticProblems(f, file) {
  const problems = []
  if (f.KIND !== 'viewport') problems.push(`${file}: KIND must be "viewport"`)
  if (JSON.stringify(f.TIERS) !== JSON.stringify(TIER_NAMES)) problems.push(`${file}: TIERS must be ${JSON.stringify(TIER_NAMES)}`)
  const n = f.VIEWPORTS.length
  if (f.VIEWPORT_WIDTHS.length !== n || f.VIEWPORT_HEIGHTS.length !== n || f.VIEWPORT_TIERS.length !== n) {
    problems.push(`${file}: VIEWPORTS, VIEWPORT_WIDTHS, VIEWPORT_HEIGHTS, VIEWPORT_TIERS must have one entry each per size`)
  }
  for (let i = 0; i < n; i++) {
    if (f.VIEWPORTS[i] !== `${f.VIEWPORT_WIDTHS[i]}x${f.VIEWPORT_HEIGHTS[i]}`) problems.push(`${file}: VIEWPORTS[${i}] ${f.VIEWPORTS[i]} is not ${f.VIEWPORT_WIDTHS[i]}x${f.VIEWPORT_HEIGHTS[i]}`)
    const tier = tierOf(f.VIEWPORT_WIDTHS[i], f)
    if (f.VIEWPORT_TIERS[i] !== tier) problems.push(`${file}: VIEWPORT_TIERS[${i}] says ${f.VIEWPORT_TIERS[i]}, the bounds say ${tier}`)
  }
  if (f.RAIL_CAPACITY_BY_HEIGHT.length !== n) problems.push(`${file}: RAIL_CAPACITY_BY_HEIGHT must have one entry per size`)
  if (!f.GENERATED.includes(TS_OUT) || !f.GENERATED.includes(CSS_OUT)) problems.push(`${file}: GENERATED must name ${TS_OUT} and ${CSS_OUT}`)
  return problems
}

export function tierOf(width, f) {
  if (width <= f.PHONE_MAX) return 'phone'
  if (width <= f.TABLET_MAX) return 'tablet'
  if (width <= f.DESKTOP_MAX) return 'desktop'
  return 'wide'
}

// ---------------------------------------------------------------------------
// Emission. Deterministic: the same spec bytes give the same two files.
// ---------------------------------------------------------------------------
const kebab = (name) => name.toLowerCase().replace(/_/g, '-')

export function renderTs(f, specSha) {
  const matrix = f.VIEWPORTS.map((label, i) => `  { label: ${JSON.stringify(label)}, width: ${f.VIEWPORT_WIDTHS[i]}, height: ${f.VIEWPORT_HEIGHTS[i]}, tier: ${JSON.stringify(f.VIEWPORT_TIERS[i])}, railCapacity: ${f.RAIL_CAPACITY_BY_HEIGHT[i]} },`)
  return `// GENERATED by scripts/viewport-from-spec.mjs from ${VIEWPORT_SPEC}
// spec sha256 ${specSha}
// Do not edit by hand: change specs/ui/viewport.t27 in gHashTag/t27, re-vendor, re-run the generator.

export type ViewportTier = ${TIER_NAMES.map((t) => JSON.stringify(t)).join(' | ')}
/** The tiers, narrowest first. */
export const TIERS_ORDER: readonly ViewportTier[] = ${JSON.stringify(f.TIERS)}

/** Inclusive upper bound of the phone tier (CSS px, window.innerWidth). */
export const PHONE_MAX = ${f.PHONE_MAX}
/** Inclusive upper bound of the tablet tier. */
export const TABLET_MAX = ${f.TABLET_MAX}
/** Inclusive upper bound of the desktop tier; wider is "wide". */
export const DESKTOP_MAX = ${f.DESKTOP_MAX}
export const COARSE_POINTER_QUERY = ${JSON.stringify(f.COARSE_POINTER_QUERY)}
/** Below this width the explorer header drops subtitle and note; inside the desktop tier, not a tier. */
export const HEADER_CHROME_MAX = ${f.HEADER_CHROME_MAX}

/** Smallest interactive box, each side, on phone and tablet. */
export const TOUCH_TARGET_MIN_PX = ${f.TOUCH_TARGET_MIN_PX}
export const BACK_CONTROL_MIN_PX = ${f.BACK_CONTROL_MIN_PX}

export const PHONE_PANES = ${f.PHONE_PANES}
export const TABLET_PANES = ${f.TABLET_PANES}
export const DESKTOP_PANES = ${f.DESKTOP_PANES}
export const ONE_SCROLLER_PER_PANE = ${f.ONE_SCROLLER_PER_PANE}
export const DOCUMENT_SCROLLS = ${f.DOCUMENT_SCROLLS}

/** The width the desktop layout must stay pixel-identical at across a change. */
export const DESKTOP_REFERENCE_WIDTH = ${f.DESKTOP_REFERENCE_WIDTH}

export interface ViewportSize {
  label: string
  width: number
  height: number
  tier: ViewportTier
  /** Queen rail tiles the one-column rail holds at this height (model, see the spec). */
  railCapacity: number
}

/** The QA matrix every viewport contract iterates. */
export const VIEWPORTS: readonly ViewportSize[] = [
${matrix.join('\n')}
]

export const RAIL_TILES = ${f.RAIL_TILES}
export const RAIL_MIN_VISIBLE = ${f.RAIL_MIN_VISIBLE}
export const RAIL_TILE_W_COMPACT = ${f.RAIL_TILE_W_COMPACT}
export const RAIL_TILE_H_COMPACT = ${f.RAIL_TILE_H_COMPACT}
export const RAIL_TILE_H_COLUMN = ${f.RAIL_TILE_H_COLUMN}

/** The tier a CSS viewport width falls into, by the inclusive bounds above. */
export function tierOf(width: number): ViewportTier {
  if (width <= PHONE_MAX) return 'phone'
  if (width <= TABLET_MAX) return 'tablet'
  if (width <= DESKTOP_MAX) return 'desktop'
  return 'wide'
}

/** The media query that is true exactly on the given tier. */
export function tierQuery(tier: ViewportTier): string {
  switch (tier) {
    case 'phone': return \`(max-width: \${PHONE_MAX}px)\`
    case 'tablet': return \`(min-width: \${PHONE_MAX + 1}px) and (max-width: \${TABLET_MAX}px)\`
    case 'desktop': return \`(min-width: \${TABLET_MAX + 1}px) and (max-width: \${DESKTOP_MAX}px)\`
    case 'wide': return \`(min-width: \${DESKTOP_MAX + 1}px)\`
  }
}
`
}

export function renderCss(f, specSha) {
  const px = (name) => `  --${kebab(name)}: ${f[name]}px;`
  return `/* GENERATED by scripts/viewport-from-spec.mjs from ${VIEWPORT_SPEC}
   spec sha256 ${specSha}
   Do not edit by hand: change specs/ui/viewport.t27 in gHashTag/t27, re-vendor, re-run the generator.
   Custom properties cannot drive @media, so the tiers are applied by useViewport (data-tier);
   these values are for sizes inside a tier (touch targets, the back control). */
:root {
  --bp-phone-max: ${f.PHONE_MAX}px;
  --bp-tablet-max: ${f.TABLET_MAX}px;
  --bp-desktop-max: ${f.DESKTOP_MAX}px;
${px('TOUCH_TARGET_MIN_PX')}
${px('BACK_CONTROL_MIN_PX')}
${px('RAIL_TILE_W_COMPACT')}
${px('RAIL_TILE_H_COMPACT')}
${px('RAIL_TILE_H_COLUMN')}
}
`
}

// ---------------------------------------------------------------------------
// Build.
// ---------------------------------------------------------------------------
export async function buildViewport({ specText, analyze }) {
  const problems = []
  const analysis = analyze(specText)
  const verdict = verdictOf(analysis)
  const file = VIEWPORT_SPEC.replace(/^public\/t27\/files\//, '')
  if (!verdict.typecheckOk || verdict.discarded > 0 || !verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(verdict)})`)
  problems.push(...compilerErrors(analysis).map((m) => `${file}: ${m}`))
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${file}: non-ASCII byte in the spec (L3)`)
  const moduleName = analysis.ast?.name ?? null
  if (moduleName !== EXPECTED_MODULE) problems.push(`${file}: module must be ${EXPECTED_MODULE}, is ${moduleName}`)
  let consts = {}
  try { consts = constsOf(analysis) } catch (e) { problems.push(`${file}: ${e.message}`) }
  problems.push(...checkSchema(consts, VIEWPORT_REQUIRED, {}, file))
  const f = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
  let tests = { tests: 0, asserts: 0, failures: [] }
  if (problems.length === 0) {
    problems.push(...semanticProblems(f, file))
    tests = runSpecTests(analysis, f)
    if (tests.tests === 0) problems.push(`${file}: no test block; the spec must test its own invariants`)
    problems.push(...tests.failures.map((m) => `${file}: test ${m}`))
  }
  const specSha = sha256(Buffer.from(specText, 'utf8'))
  return {
    problems, verdict, fields: f, specSha, tests,
    ts: problems.length ? null : renderTs(f, specSha),
    css: problems.length ? null : renderCss(f, specSha),
  }
}

async function main() {
  const check = process.argv.includes('--check')
  const json = process.argv.includes('--json')
  const specPath = join(SITE, VIEWPORT_SPEC)
  if (!existsSync(specPath)) { console.error(`viewport-from-spec: ${VIEWPORT_SPEC} is not vendored`); process.exit(1) }
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const specText = readFileSync(specPath, 'utf8')
  const out = await buildViewport({ specText, analyze })
  if (out.problems.length) {
    console.error(`viewport-from-spec: ${out.problems.length} problem(s)`)
    for (const p of out.problems) console.error('  ' + p)
    process.exit(1)
  }
  if (json) {
    // For qa/explorer-viewport-contract.mjs: the matrix and thresholds without importing TypeScript.
    console.log(JSON.stringify({ specSha: out.specSha, ...out.fields }))
    return
  }
  const targets = [[TS_OUT, out.ts], [CSS_OUT, out.css]]
  if (check) {
    const stale = targets.filter(([rel, text]) => !existsSync(join(SITE, rel)) || readFileSync(join(SITE, rel), 'utf8') !== text)
    if (stale.length) {
      console.error(`viewport-from-spec --check: stale ${stale.map(([r]) => r).join(', ')}; run node scripts/viewport-from-spec.mjs`)
      process.exit(1)
    }
  } else {
    for (const [rel, text] of targets) {
      mkdirSync(dirname(join(SITE, rel)), { recursive: true })
      writeFileSync(join(SITE, rel), text)
    }
  }
  const f = out.fields
  console.log(`viewport-from-spec: ${check ? 'up to date' : 'wrote'} ${TS_OUT}, ${CSS_OUT}; spec sha256 ${out.specSha.slice(0, 16)}; tiers phone<=${f.PHONE_MAX} tablet<=${f.TABLET_MAX} desktop<=${f.DESKTOP_MAX}; matrix ${f.VIEWPORTS.join(' ')}; spec tests ${out.tests.tests}, asserts ${out.tests.asserts}, all hold`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => { console.error(e); process.exit(1) })
}
