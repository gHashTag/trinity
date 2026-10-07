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
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
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
// The corpus runnability report (#1477): which specs' tests the player's
// evaluator runs, per spec, over the five hardware trees.
//
// The CONTRACT lives in specs/player/spec-runnable.t27 -- the trees, the gates,
// the outcome vocabulary, the columns, the ratchet rule -- and that spec is
// compiled and its own test blocks run (by this file's runSpecTests, i.e. by
// the very evaluator being reported on) before the walk starts. This side is
// I/O glue only: walk, compile, run, compare, print. There is deliberately no
// new script file for it: the owner's only-t27 rule forbids new hand-written
// non-t27 code, so the report is a mode of the file that already owns the
// build-time spec tests.
//
//   node scripts/viewport-from-spec.mjs --spec-runnable          print + ratchet-check
//   node scripts/viewport-from-spec.mjs --spec-runnable --write  rewrite the baseline
// ---------------------------------------------------------------------------
export const RUNNABLE_SPEC = 'specs/player/spec-runnable.t27'
export const RUNNABLE_BASELINE = 'spec-runnable-baseline.json'
export const RUNNABLE_MODULE = 'player_spec_runnable'
export const RUNNABLE_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', GENERATED: 'arr',
  TREES: 'arr', OUTCOMES: 'arr', SKIP_IS_NEVER_PASS: 'bool', GATES: 'arr', COLUMNS: 'arr',
  FIRST_GAP_UNKNOWN: 'str', LEGACY_BRACE_FORM_SPECS: 'arr',
  RATCHET_MODE: 'str', RATCHET_PER: 'str', MAY_NEWLY_APPEAR: 'bool',
}
export const CORPUS_FILES = 'public/t27/files'

/** Gate the contract the way every generator gates its spec: ASCII, clean verdict, module, schema, own tests. */
export function loadRunnableSpec(analyze, specText, file = RUNNABLE_SPEC) {
  const problems = []
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${file}: non-ASCII byte in the spec (L3)`)
  const analysis = analyze(specText)
  problems.push(...compilerErrors(analysis).map((m) => `${file}: ${m}`))
  if (analysis.ast?.name !== RUNNABLE_MODULE) problems.push(`${file}: module must be ${RUNNABLE_MODULE}, is ${analysis.ast?.name}`)
  let consts = {}
  try { consts = constsOf(analysis) } catch (e) { problems.push(`${file}: ${e.message}`) }
  problems.push(...checkSchema(consts, RUNNABLE_REQUIRED, {}, file))
  const f = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
  if (problems.length === 0) {
    const tests = runSpecTests(analysis, f)
    if (tests.tests === 0) problems.push(`${file}: no test block; the contract must test its own rules`)
    problems.push(...tests.failures.map((m) => `${file}: test ${m}`))
  }
  return { problems, fields: f, analysis }
}

/** One row per spec: the gates, the three outcome counts, and the first thing that blocked the run. */
export function runnableRow(analyze, text, path, tree, fields) {
  const a = analyze(text)
  const errs = compilerErrors(a)
  const typecheck = a.typecheck?.ok === true && !a.astError
  const hir = a.hir?.ok !== false && !!a.ast
  const row = {
    path, tree,
    typecheck, hir, blocks: 0, pass: 0, fail: 0, skip: 0,
    gap: fields.FIRST_GAP_UNKNOWN,
  }
  if (!typecheck || !hir) {
    const gate = !typecheck ? 'typecheck' : 'hir'
    row.gap = `${gate}: ${errs[0] ?? 'no error text'}`.slice(0, 160)
    return row
  }
  const r = runSpec(a.ast)
  row.blocks = r.results.length
  row.pass = r.pass
  row.fail = r.fail
  row.skip = r.skip
  const blocked = r.results.find((b) => b.status === 'skip')
  if (blocked) row.gap = blocked.reason
  return row
}

/** Walk the contract's trees and measure every spec. Refuses to return nothing: an empty walk is a lie. */
export function runnableRows(analyze, fields, { readFileSync: rd = readFileSync, readdir: rr = readdirSync } = {}) {
  const rows = []
  for (const tree of fields.TREES) {
    const dir = join(SITE, CORPUS_FILES, tree)
    const files = rr(dir, { recursive: true }).map(String).filter((p) => p.endsWith('.t27')).sort()
    for (const rel of files) {
      const path = `${tree}/${rel}`
      rows.push(runnableRow(analyze, rd(join(dir, rel), 'utf8'), path, tree, fields))
    }
  }
  if (rows.length === 0) throw new Error(`no specs found under ${fields.TREES.join(', ')} -- the report refuses to call an empty walk a measurement`)
  return rows
}

export const runnableTotals = (rows) => ({
  specs: rows.length,
  typecheckOk: rows.filter((r) => r.typecheck).length,
  hirOk: rows.filter((r) => r.hir).length,
  blocks: rows.reduce((n, r) => n + r.blocks, 0),
  pass: rows.reduce((n, r) => n + r.pass, 0),
  fail: rows.reduce((n, r) => n + r.fail, 0),
  skip: rows.reduce((n, r) => n + r.skip, 0),
  clean: rows.filter((r) => r.typecheck && r.hir && r.blocks > 0 && r.fail === 0 && r.skip === 0).length,
})

/** The baseline's per-spec entry: short keys, the file is diffed by people. */
export const runnableEntry = (r) => ({ t: r.typecheck ? 1 : 0, h: r.hir ? 1 : 0, b: r.blocks, p: r.pass, f: r.fail, s: r.skip, g: r.gap })

/**
 * The ratchet, per spec (RATCHET_PER), only-improves (RATCHET_MODE): pass may
 * rise, fail and skip may fall, a gate once ok stays ok. A newly vendored spec
 * is not a regression (MAY_NEWLY_APPEAR); a spec gone from disk is noted, never
 * counted. Everything else that moved is listed for a human.
 */
export function runnableRegressions(base, rows) {
  const now = new Map(rows.map((r) => [r.path, r]))
  const out = []
  for (const r of rows) {
    const b = base[r.path]
    if (!b) continue
    if (b.t === 1 && !r.typecheck) out.push(`${r.path}: typecheck was ok, is not (${r.gap})`)
    if (b.h === 1 && !r.hir) out.push(`${r.path}: hir was ok, is not (${r.gap})`)
    if (r.pass < b.p) out.push(`${r.path}: pass ${b.p} -> ${r.pass}`)
    if (r.fail > b.f) out.push(`${r.path}: fail ${b.f} -> ${r.fail} (a spec's own assertion now failing; read it before --write)`)
    if (r.skip > b.s) out.push(`${r.path}: skip ${b.s} -> ${r.skip}`)
  }
  const gone = Object.keys(base).filter((p) => !now.has(p))
  return { regressions: out, gone }
}

export function renderRunnableReport(rows, fields, totals) {
  const line = (r) => `${r.path.padEnd(52)} tc ${r.typecheck ? 'ok' : 'NO'}  hir ${r.hir ? 'ok' : 'NO'}  b ${String(r.blocks).padStart(4)}  p ${String(r.pass).padStart(4)}  f ${String(r.fail).padStart(3)}  s ${String(r.skip).padStart(3)}  ${r.gap}`
  const out = []
  for (const tree of fields.TREES) {
    const inTree = rows.filter((r) => r.tree === tree)
    const t = runnableTotals(inTree)
    out.push(`tree ${tree}: ${inTree.length} specs, ${t.typecheckOk} typecheck ok, ${t.hirOk} hir ok; ${t.blocks} blocks: ${t.pass} pass, ${t.fail} fail, ${t.skip} skip`)
    for (const r of inTree) out.push('  ' + line(r))
  }
  out.push(`total: ${totals.specs} specs in ${fields.TREES.length} trees; typecheck ${totals.typecheckOk}, hir ${totals.hirOk}; ${totals.blocks} blocks: ${totals.pass} pass, ${totals.fail} fail, ${totals.skip} skip; ${totals.clean} specs fully clean (0 fail, 0 skip)`)
  const blocked = rows.filter((r) => r.gap !== fields.FIRST_GAP_UNKNOWN)
  out.push(`not runnable as measured: ${blocked.length} spec(s) with a refused gate or a skipped block`)
  for (const r of blocked) out.push(`  ${r.path.padEnd(52)} ${r.gap}`)
  if (fields.LEGACY_BRACE_FORM_SPECS.length === 0) {
    out.push('legacy `module X { }` brace form: none in the five trees -- the compiler normalises it away (measured 2026-10-07, zero parse refusals); a file that ever fails a gate lists above with the gate reason')
  } else {
    for (const p of fields.LEGACY_BRACE_FORM_SPECS) out.push(`legacy brace form: ${p}`)
  }
  return out.join('\n')
}

async function specRunnableMain() {
  const write = process.argv.includes('--write')
  const specPath = join(SITE, RUNNABLE_SPEC)
  if (!existsSync(specPath)) { console.error(`spec-runnable: ${RUNNABLE_SPEC} is missing`); process.exit(1) }
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const contract = loadRunnableSpec(analyze, readFileSync(specPath, 'utf8'))
  if (contract.problems.length) {
    console.error(`spec-runnable: the contract itself does not hold (${contract.problems.length} problem(s))`)
    for (const p of contract.problems) console.error('  ' + p)
    process.exit(1)
  }
  const fields = contract.fields
  const rows = runnableRows(analyze, fields)
  const totals = runnableTotals(rows)
  console.log(renderRunnableReport(rows, fields, totals))
  const baselinePath = join(SITE, RUNNABLE_BASELINE)
  const generated = fields.GENERATED
  if (write) {
    if (generated.length !== 1 || generated[0] !== RUNNABLE_BASELINE) { console.error(`spec-runnable: the contract's GENERATED must name ${RUNNABLE_BASELINE} alone`); process.exit(1) }
    const doc = { kind: fields.KIND, ratchet: `${fields.RATCHET_MODE} per ${fields.RATCHET_PER}`, trees: fields.TREES, totals, specs: Object.fromEntries(rows.map((r) => [r.path, runnableEntry(r)])) }
    writeFileSync(baselinePath, JSON.stringify(doc, null, 2) + '\n')
    console.log(`spec-runnable: wrote ${RUNNABLE_BASELINE} (${totals.specs} specs)`)
    return
  }
  if (!existsSync(baselinePath)) { console.error(`spec-runnable: no baseline at ${RUNNABLE_BASELINE}; run with --write first`); process.exit(1) }
  const doc = JSON.parse(readFileSync(baselinePath, 'utf8'))
  if (doc.kind !== fields.KIND) { console.error(`spec-runnable: baseline kind ${doc.kind} is not ${fields.KIND}`); process.exit(1) }
  const { regressions, gone } = runnableRegressions(doc.specs ?? {}, rows)
  for (const g of gone) console.log(`spec-runnable: note: ${g} is no longer on disk (not a regression)`)
  if (regressions.length) {
    console.error(`spec-runnable: ${regressions.length} regression(s) against ${RUNNABLE_BASELINE} (${fields.RATCHET_MODE} per ${fields.RATCHET_PER})`)
    for (const m of regressions) console.error('  ' + m)
    process.exit(1)
  }
  console.log(`spec-runnable: ratchet holds against ${RUNNABLE_BASELINE}; improvements may be locked in with --write`)
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
  if (process.argv.includes('--spec-runnable')) return specRunnableMain()
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
