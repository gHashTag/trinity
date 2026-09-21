#!/usr/bin/env node
// onboarding-from-spec.mjs -- the agent-facing surface of t27.ai, from `specs/catalog/onboarding.t27`.
//
// Reads `apps/website/specs/catalog/onboarding.t27` through the real compiler
// (`t27_compiler.wasm`), checks the constant schema, evaluates every `test` block of the spec,
// and writes the two files the site serves to anything that crawls it:
//
//   public/agents.t27   the document
//   public/llms.txt     the same bytes, at the address a crawler already asks for
//
// The two files are byte-identical on purpose. `llms.txt` has no schema -- it is a text file for
// language models -- so the text we put there is our own language rather than a translation of
// the offer into Markdown, an A2A card and an ai-plugin manifest. What is published compiles:
// this generator hands the rendered document back to the compiler before writing it, so an
// invitation written in t27 cannot ship as something t27 cannot read.
//
// Nothing here parses a `.t27` with a regular expression; constants and asserts come from the
// compiler's AST. The asserts are evaluated on purpose: `typecheck.ok` stays true for
// `assert 1 > 2`, so a spec whose own tests do not hold must not produce a green build.
//
// Run:      node scripts/onboarding-from-spec.mjs            (write)
//           node scripts/onboarding-from-spec.mjs --check    (fail if the committed files are stale)
//           node scripts/onboarding-from-spec.mjs --json     (print the constants as JSON)
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { CYRILLIC, SITE, checkSchema, compilerErrors, constsOf, loadCompiler, sha256, verdictOf } from './agents-from-specs.mjs'
import { runSpecTests } from './viewport-from-spec.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
// LIVE_TRUTH in the spec points at this file's published copy. The spec's snapshot constants
// are checked against it, so "the manifest supersedes these counts" is enforced, not asserted.
const MANIFEST = 'public/t27/manifest.json'
// This spec is ours, and it lives outside `public/t27/`. That directory is the
// vendored mirror of the t27 corpus: `sync-t27-specs.mjs` wipes and rewrites it
// from the tarballs, so a file that is in no t27 ref does not survive a refresh.
// It sat there for one day and would have been deleted by the first complete
// sync, taking /llms.txt and /agents.t27 down with it. It belongs here anyway --
// its numbers are measured from trinity's manifest by trinity's generator behind
// trinity's gate, so a home upstream would mean a cross-repo PR every time the
// corpus moves. Nothing reads it but this file: `renderDoc` embeds the whole
// spec text into the published document, so the raw path is a label, not a URL.
export const ONBOARDING_SPEC = 'specs/catalog/onboarding.t27'
export const DOC_OUT = 'public/agents.t27'
export const LLMS_OUT = 'public/llms.txt'
export const EXPECTED_MODULE = 'catalog_onboarding'
export const ORIGIN = 'https://t27.ai/'

export const ONBOARDING_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', GENERATED: 'arr', LICENCE: 'str', CONTACT: 'str',
  SITE: 'str', DOC: 'str', DOC_ALIAS: 'str', LIVE_TRUTH: 'str', RAW_PREFIX: 'str',
  READ: 'arr', READ_ABOUT: 'arr',
  COMPILER: 'str', COMPILER_EXPORTS: 'arr', COMPILER_ABI: 'str', REQUIRES_RUNNING_OUR_CODE: 'bool',
  BACKENDS: 'arr', BACKENDS_NOTE: 'str',
  TS_SHARES_THE_JS_VALUE_LAYER: 'bool', JS_TS_DIVERGENCES: 'u16',
  MEASURED_AT: 'str', SPEC_COUNT: 'u16', SPEC_LINES: 'u32',
  HEALTH_OK: 'u16', HEALTH_WARN: 'u16', HEALTH_FAIL: 'u16', HEALTH_FAIL_NOTE: 'str', HEALTH_FAIL_JS_ONLY: 'u16',
  REPO_COUNT: 'u8', WORLD_COUNT: 'u8',
  GAME: 'str', GAME_DOC: 'str', GAME_BOARD: 'str', WIN_CONDITION: 'str',
  CAMPAIGN: 'str', CAMPAIGN_NOTE: 'str', CYCLE: 'arr', CYCLE_ABOUT: 'arr',
  CLAIM_COLOURS: 'arr', CLAIM_MEANINGS: 'arr', HOVER_COLOUR: 'str', HOVER_NOTE: 'str', HONESTY_LAW: 'str',
  JOIN: 'arr', CONTRIBUTE: 'str', CONTRIBUTE_NOTE: 'str',
  WRITE_API: 'bool', WRITE_API_NOTE: 'str', MCP_HOSTED: 'bool', MCP_NOTE: 'str',
  AGENT_REGISTRY: 'bool', AGENT_REGISTRY_NOTE: 'str', ACCOUNTS: 'bool', UNKNOWN: 'arr',
  IS_INSTRUCTION: 'bool', OWNER_CONSENT_REQUIRED: 'bool', ASKS_FOR_CREDENTIALS: 'bool', ASKS_TO_ACT_ALONE: 'bool',
}

const HEX = /^#[0-9A-F]{6}$/

// ---------------------------------------------------------------------------
// Semantic checks the schema cannot express.
//
// The four consent constants are checked here as well as in the spec's own tests. That is
// deliberate duplication: the spec could be edited to flip a flag AND to relax the test that
// guards it in one commit, and the whole point of the document is that it does not quietly
// become an instruction addressed at somebody else's agent.
// ---------------------------------------------------------------------------
export function semanticProblems(f, file) {
  const p = []
  if (f.KIND !== 'onboarding') p.push(`${file}: KIND must be "onboarding"`)
  if (f.ID !== 'catalog/onboarding') p.push(`${file}: ID must be "catalog/onboarding"`)
  if (JSON.stringify(f.GENERATED) !== JSON.stringify([LLMS_OUT, DOC_OUT])) {
    p.push(`${file}: GENERATED must be exactly ${JSON.stringify([LLMS_OUT, DOC_OUT])}`)
  }
  if (f.SITE !== ORIGIN) p.push(`${file}: SITE must be ${ORIGIN}`)
  if (f.DOC !== `${ORIGIN}agents.t27`) p.push(`${file}: DOC must be ${ORIGIN}agents.t27`)
  if (f.DOC_ALIAS !== `${ORIGIN}llms.txt`) p.push(`${file}: DOC_ALIAS must be ${ORIGIN}llms.txt`)

  if (f.READ.length !== f.READ_ABOUT.length) p.push(`${file}: READ has ${f.READ.length} addresses and READ_ABOUT ${f.READ_ABOUT.length} descriptions`)
  f.READ.forEach((url, i) => {
    if (!url.startsWith(ORIGIN)) p.push(`${file}: READ[${i}] ${url} is not on ${ORIGIN}`)
    if (!(f.READ_ABOUT[i] ?? '').trim()) p.push(`${file}: READ_ABOUT[${i}] is empty; an address nobody can explain does not belong on the list`)
  })
  if (f.LIVE_TRUTH !== f.READ[0]) p.push(`${file}: LIVE_TRUTH must be the first READ address (the manifest)`)
  if (!f.RAW_PREFIX.startsWith(ORIGIN) || !f.RAW_PREFIX.endsWith('/')) p.push(`${file}: RAW_PREFIX must be a ${ORIGIN} path ending in /`)
  if (!f.COMPILER.startsWith(ORIGIN)) p.push(`${file}: COMPILER must be served from ${ORIGIN}`)
  for (const name of ['t27_alloc', 't27_analyze', 't27_free']) {
    if (!f.COMPILER_EXPORTS.includes(name)) p.push(`${file}: COMPILER_EXPORTS must name ${name}`)
  }

  if (f.HEALTH_OK + f.HEALTH_WARN + f.HEALTH_FAIL !== f.SPEC_COUNT) {
    p.push(`${file}: health ${f.HEALTH_OK}+${f.HEALTH_WARN}+${f.HEALTH_FAIL} does not add up to SPEC_COUNT ${f.SPEC_COUNT}`)
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(f.MEASURED_AT)) p.push(`${file}: MEASURED_AT must be an ISO date; a snapshot without its day is not a snapshot`)

  if (f.CYCLE.length !== 5) p.push(`${file}: the cycle is five steps, not ${f.CYCLE.length}`)
  if (f.CYCLE.length !== f.CYCLE_ABOUT.length) p.push(`${file}: every cycle step needs its line in CYCLE_ABOUT`)
  if (f.CLAIM_COLOURS.length !== 3) p.push(`${file}: there are exactly three claim colours, not ${f.CLAIM_COLOURS.length}`)
  if (f.CLAIM_COLOURS.length !== f.CLAIM_MEANINGS.length) p.push(`${file}: every claim colour needs its meaning`)
  for (const [i, c] of f.CLAIM_COLOURS.entries()) if (!HEX.test(c)) p.push(`${file}: CLAIM_COLOURS[${i}] ${c} is not an upper-case #RRGGBB`)
  if (!HEX.test(f.HOVER_COLOUR)) p.push(`${file}: HOVER_COLOUR ${f.HOVER_COLOUR} is not an upper-case #RRGGBB`)
  if (f.CLAIM_COLOURS.includes(f.HOVER_COLOUR)) p.push(`${file}: the hover colour is not a claim state and must not be one of the three`)

  // The invitation has to keep routing through a person. If the first step stops naming the
  // owner, what is published is no longer an invitation.
  if (!/owner/i.test(f.JOIN[0] ?? '')) p.push(`${file}: JOIN[0] must address the reader's owner; an offer that skips them is not an offer`)
  for (const [i, s] of f.JOIN.entries()) if (!s.trim()) p.push(`${file}: JOIN[${i}] is empty`)
  if (!f.UNKNOWN.length) p.push(`${file}: UNKNOWN must not be empty -- the honesty law needs somewhere to land`)
  for (const [i, s] of f.UNKNOWN.entries()) if (!s.trim()) p.push(`${file}: UNKNOWN[${i}] is empty`)

  if (f.IS_INSTRUCTION !== false) p.push(`${file}: IS_INSTRUCTION must be false`)
  if (f.OWNER_CONSENT_REQUIRED !== true) p.push(`${file}: OWNER_CONSENT_REQUIRED must be true`)
  if (f.ASKS_FOR_CREDENTIALS !== false) p.push(`${file}: ASKS_FOR_CREDENTIALS must be false`)
  if (f.ASKS_TO_ACT_ALONE !== false) p.push(`${file}: ASKS_TO_ACT_ALONE must be false`)
  if (f.REQUIRES_RUNNING_OUR_CODE !== false) p.push(`${file}: REQUIRES_RUNNING_OUR_CODE must be false while every READ address is plain JSON`)
  for (const flag of ['WRITE_API', 'MCP_HOSTED', 'AGENT_REGISTRY', 'ACCOUNTS']) {
    if (typeof f[flag] !== 'boolean') p.push(`${file}: ${flag} must be a boolean`)
  }
  if (f.WRITE_API === false && !f.WRITE_API_NOTE.trim()) p.push(`${file}: WRITE_API is false and WRITE_API_NOTE says nothing`)
  if (f.MCP_HOSTED === false && !f.MCP_NOTE.trim()) p.push(`${file}: MCP_HOSTED is false and MCP_NOTE says nothing`)
  if (f.AGENT_REGISTRY === false && !f.AGENT_REGISTRY_NOTE.trim()) p.push(`${file}: AGENT_REGISTRY is false and AGENT_REGISTRY_NOTE says nothing`)
  return p
}

// ---------------------------------------------------------------------------
// The corpus snapshot, checked against the corpus.
//
// The spec writes down a day's counts and says LIVE_TRUTH supersedes them. That was true of
// the wording and false of the numbers: nothing compared them to anything. Its own test only
// asserts OK+WARN+FAIL == SPEC_COUNT, which held for 1002+399+6=1407 and holds just as well
// for the triple that replaced it -- so a corpus refresh could move every figure and leave a
// green gate publishing the old ones at the address the document calls live truth.
//
// So read the manifest that is about to be published and compare. The message names the value
// to write, because a gate that says "wrong" without saying "this" gets fixed by guessing.
// ---------------------------------------------------------------------------

// The backends that emit declarations and nothing else -- const, enum, struct -- and name
// every fn, test, bench and invariant they skipped in a comment. A spec that only these
// decline is not a broken spec; it is a spec with a body, which is most of them.
const DECLARATIONS_ONLY = ['js', 'ts']
const sameSet = (a, b) => a.length === b.length && [...a].sort().join() === [...b].sort().join()

export function corpusProblems(f, file, manifest) {
  const p = []
  const backends = [...new Set(manifest.specs.flatMap((s) => Object.keys(s.outBytes ?? {})))].sort()
  const want = {
    SPEC_COUNT: manifest.specCount,
    SPEC_LINES: manifest.totalLines,
    HEALTH_OK: manifest.health.ok,
    HEALTH_WARN: manifest.health.warn,
    HEALTH_FAIL: manifest.health.fail,
    REPO_COUNT: manifest.repos.length,
    WORLD_COUNT: manifest.discovery.worlds.length,
    // The share of health=fail that is the declarations-only backends declining to emit, on
    // a file the other five accepted. Counted here rather than typed into the spec, because
    // the number it qualifies is the one a reader is most likely to misread as "338 broken
    // specs".
    //
    // This test was `join() === 'js'` while js was the only backend of its kind. gen-ts made
    // that silently read 0 -- every such spec now lists BOTH, so an exact-match on one name
    // matches nothing, and the constant would have been "corrected" to zero by a generator
    // that was measuring the wrong set. Compare against DECLARATIONS_ONLY instead, so the
    // next backend of this kind is a one-word edit there and not a wrong number here.
    HEALTH_FAIL_JS_ONLY: manifest.specs.filter((s) => sameSet(s.failedBackends ?? [], DECLARATIONS_ONLY)).length,
  }
  // The spec claims codegen_ts shares codegen_js's value layer. That is falsifiable over the
  // corpus and therefore gets falsified here rather than believed: a spec that loses one of
  // the two and keeps the other is drift, whatever the comment upstream says.
  const divergent = manifest.specs.filter((s) => {
    const failed = new Set(s.failedBackends ?? [])
    return failed.has('js') !== failed.has('ts')
  })
  if (f.JS_TS_DIVERGENCES !== divergent.length) {
    p.push(`${file}: JS_TS_DIVERGENCES says ${f.JS_TS_DIVERGENCES}, the manifest has ${divergent.length}` +
      (divergent.length ? ` (e.g. ${divergent.slice(0, 3).map((s) => s.path).join(', ')})` : ''))
  }
  for (const [k, v] of Object.entries(want)) {
    if (f[k] !== v) p.push(`${file}: ${k} says ${f[k]}, the manifest says ${v} -- write ${v}`)
  }
  const named = [...(f.BACKENDS ?? [])].sort()
  if (JSON.stringify(named) !== JSON.stringify(backends)) {
    p.push(`${file}: BACKENDS is ${JSON.stringify(named)}, the manifest emits ${JSON.stringify(backends)}`)
  }
  return p
}

// ---------------------------------------------------------------------------
// Emission. Deterministic: the same spec bytes give the same document.
// ---------------------------------------------------------------------------
export function renderDoc(specText, specSha) {
  return `; GENERATED by apps/website/scripts/onboarding-from-spec.mjs (gHashTag/trinity)
; from ${ONBOARDING_SPEC}, sha256 ${specSha}
; Served as ${ORIGIN}agents.t27 and ${ORIGIN}llms.txt -- the same bytes at both addresses.
; Do not edit either file: edit the spec and re-run the generator.

; You asked for llms.txt and got a t27 module. That is not a mistake and not a wall: this
; file is plain text, every line of prose is a comment, and you can read it exactly as you
; read anything else. It is written in the language the site is about, because the offer
; below is an offer to write that language, and handing you a translation would have been
; the first thing here that was not true of us. It compiles; a generator checked that before
; publishing it, along with every number it states about itself.

${specText}`
}

// ---------------------------------------------------------------------------
// Build.
// ---------------------------------------------------------------------------
export async function buildOnboarding({ specText, analyze, shippedExports = null, manifest = null }) {
  const problems = []
  const file = ONBOARDING_SPEC
  const analysis = analyze(specText)
  const verdict = verdictOf(analysis)
  if (!verdict.typecheckOk || verdict.discarded > 0 || !verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(verdict)})`)
  problems.push(...compilerErrors(analysis).map((m) => `${file}: ${m}`))
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${file}: non-ASCII byte in the spec (L3)`)
  if (CYRILLIC.test(specText)) problems.push(`${file}: Cyrillic in the spec (LANG-EN)`)
  const moduleName = analysis.ast?.name ?? null
  if (moduleName !== EXPECTED_MODULE) problems.push(`${file}: module must be ${EXPECTED_MODULE}, is ${moduleName}`)

  let consts = {}
  try { consts = constsOf(analysis) } catch (e) { problems.push(`${file}: ${e.message}`) }
  problems.push(...checkSchema(consts, ONBOARDING_REQUIRED, {}, file))
  const f = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))

  let tests = { tests: 0, asserts: 0, failures: [] }
  if (problems.length === 0) {
    problems.push(...semanticProblems(f, file))
    // COMPILER_EXPORTS is an ABI promise about a binary we serve, so ask the binary
    // rather than the schema. `semanticProblems` only checks that three names are
    // present in the list; it cannot tell whether the wasm at COMPILER still has
    // them, and an agent that fetches it finds out the hard way.
    if (shippedExports) {
      for (const name of f.COMPILER_EXPORTS ?? []) {
        if (!shippedExports.includes(name)) problems.push(`${file}: COMPILER_EXPORTS names ${name}, which ${WASM} does not export`)
      }
    }
    if (manifest) problems.push(...corpusProblems(f, file, manifest))
    tests = runSpecTests(analysis, f)
    if (tests.tests === 0) problems.push(`${file}: no test block; the spec must test its own claims`)
    problems.push(...tests.failures.map((m) => `${file}: test ${m}`))
  }

  const specSha = sha256(Buffer.from(specText, 'utf8'))
  let doc = null
  if (problems.length === 0) {
    doc = renderDoc(specText, specSha)
    // What is published has to be readable by the thing it advertises.
    const republished = analyze(doc)
    const rv = verdictOf(republished)
    if (republished.ast?.name !== EXPECTED_MODULE || !rv.typecheckOk || rv.discarded > 0) {
      problems.push(`${DOC_OUT}: the rendered document does not compile (${JSON.stringify(rv)}); the generated header broke it`)
      doc = null
    }
  }
  return { problems, verdict, fields: f, specSha, tests, doc }
}

async function main() {
  const check = process.argv.includes('--check')
  const json = process.argv.includes('--json')
  const specPath = join(SITE, ONBOARDING_SPEC)
  if (!existsSync(specPath)) { console.error(`onboarding-from-spec: ${ONBOARDING_SPEC} is missing`); process.exit(1) }
  const wasmBytes = readFileSync(join(SITE, WASM))
  const analyze = await loadCompiler(wasmBytes)
  const { instance } = await WebAssembly.instantiate(wasmBytes, {})
  const shippedExports = Object.keys(instance.exports)
  const manifestPath = join(SITE, MANIFEST)
  if (!existsSync(manifestPath)) { console.error(`onboarding-from-spec: ${MANIFEST} is missing; the corpus snapshot cannot be checked against anything`); process.exit(1) }
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  const specText = readFileSync(specPath, 'utf8')
  const out = await buildOnboarding({ specText, analyze, shippedExports, manifest })
  if (out.problems.length) {
    console.error(`onboarding-from-spec: ${out.problems.length} problem(s)`)
    for (const p of out.problems) console.error('  ' + p)
    process.exit(1)
  }
  if (json) { console.log(JSON.stringify({ specSha: out.specSha, ...out.fields })); return }

  const targets = [[DOC_OUT, out.doc], [LLMS_OUT, out.doc]]
  if (check) {
    const stale = targets.filter(([rel, text]) => !existsSync(join(SITE, rel)) || readFileSync(join(SITE, rel), 'utf8') !== text)
    if (stale.length) {
      console.error(`onboarding-from-spec --check: stale ${stale.map(([r]) => r).join(', ')}; run node scripts/onboarding-from-spec.mjs`)
      process.exit(1)
    }
  } else {
    for (const [rel, text] of targets) {
      mkdirSync(dirname(join(SITE, rel)), { recursive: true })
      writeFileSync(join(SITE, rel), text)
    }
  }
  const f = out.fields
  console.log(`onboarding-from-spec: ${check ? 'up to date' : 'wrote'} ${DOC_OUT}, ${LLMS_OUT} (${Buffer.byteLength(out.doc)} bytes each); spec sha256 ${out.specSha.slice(0, 16)}; ${f.READ.length} read addresses, ${f.JOIN.length} join steps, ${f.UNKNOWN.length} stated unknowns; spec tests ${out.tests.tests}, asserts ${out.tests.asserts}, all hold`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => { console.error(e); process.exit(1) })
}
