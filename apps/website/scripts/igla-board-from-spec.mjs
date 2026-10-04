#!/usr/bin/env node
// Compile the IGLA CODER board shown inside WARS from one .t27 source into its
// three projections. The spec itself is generated in gHashTag/igla-coder-gpu
// (scripts/board_t27.py) from that repo's committed results; this site neither
// authors nor edits a number of it. Unknown values are empty strings, never zero.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  CYRILLIC,
  SITE,
  checkSchema,
  compilerErrors,
  constsOf,
  loadCompiler,
  sha256,
  verdictOf,
} from './agents-from-specs.mjs'
import { runSpecTests } from './viewport-from-spec.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
export const BOARD_SPEC = 'specs/queen/igla_board.t27'
export const TS_OUT = 'src/lib/iglaBoard.generated.ts'
export const JSON_OUT = 'public/queen/igla-board.json'
export const PUBLIC_SPEC_OUT = 'public/queen/igla-board.t27'
export const EXPECTED_MODULE = 'queen_igla_board'

const REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', SCHEMA_VERSION: 'u8', GENERATED: 'arr', EVIDENCE_LEVELS: 'arr',
  SOURCE_REPO: 'str', SOURCE_COMMIT: 'str', SNAPSHOT_AT: 'str', LIVE_BOARD_URL: 'str', LIVE_STATE_URL: 'str',
  MODEL_URL: 'str', JUDGE: 'str',
  HEADLINE_COUNT: 'u8', HEADLINE_KEYS: 'arr', HEADLINE_LABELS: 'arr', HEADLINE_VALUES: 'arr', HEADLINE_OF: 'arr',
  HEADLINE_HINTS: 'arr', HEADLINE_EVIDENCE: 'arr',
  GATE_COUNT: 'u8', GATE_KEYS: 'arr', GATE_RULES: 'arr',
  CANDIDATE_COUNT: 'u8', CANDIDATE_IDS: 'arr', CANDIDATE_FORMATS: 'arr', CANDIDATE_BYTES: 'arr', CANDIDATE_SHAS: 'arr',
  CANDIDATE_RANKS: 'arr', CANDIDATE_VERDICTS: 'arr', CANDIDATE_GATES: 'arr', CANDIDATE_COMPILE: 'arr',
  CANDIDATE_STRICT_PASS: 'arr', CANDIDATE_TOK_S: 'arr', CANDIDATE_BPB: 'arr', CANDIDATE_PROVENANCE: 'arr',
  ARENA_DECISION: 'str',
  LEVER_COUNT: 'u8', LEVER_IDS: 'arr', LEVER_CHANGES: 'arr', LEVER_VERDICTS: 'arr', LEVER_P: 'arr',
  LEVER_ONLY_BASE: 'arr', LEVER_ONLY_ARM: 'arr', LEVER_EVIDENCE: 'arr',
  PAIR_COUNT: 'u8', PAIR_LEVERS: 'arr', PAIR_SEEDS: 'arr', PAIR_BASES: 'arr', PAIR_ARMS: 'arr',
  PAIR_BASE_COMPILE: 'arr', PAIR_ARM_COMPILE: 'arr', PAIR_ONLY_BASE: 'arr', PAIR_ONLY_ARM: 'arr', PAIR_P: 'arr',
  PAIR_BASE_PASS: 'arr', PAIR_ARM_PASS: 'arr', PAIR_EVIDENCE: 'arr',
  STAGE_COUNT: 'u8', STAGE_IDS: 'arr', STAGE_TITLES: 'arr', STAGE_STATES: 'arr', STAGE_METRICS: 'arr', STAGE_DETAILS: 'arr',
  ROAD_COUNT: 'u8', ROAD_WHEN: 'arr', ROAD_STATES: 'arr', ROAD_TITLES: 'arr', ROAD_RESULTS: 'arr',
}

const PARALLEL = {
  HEADLINE_COUNT: ['HEADLINE_KEYS', 'HEADLINE_LABELS', 'HEADLINE_VALUES', 'HEADLINE_OF', 'HEADLINE_HINTS', 'HEADLINE_EVIDENCE'],
  GATE_COUNT: ['GATE_KEYS', 'GATE_RULES'],
  CANDIDATE_COUNT: ['CANDIDATE_IDS', 'CANDIDATE_FORMATS', 'CANDIDATE_BYTES', 'CANDIDATE_SHAS', 'CANDIDATE_RANKS', 'CANDIDATE_VERDICTS', 'CANDIDATE_GATES', 'CANDIDATE_COMPILE', 'CANDIDATE_STRICT_PASS', 'CANDIDATE_TOK_S', 'CANDIDATE_BPB', 'CANDIDATE_PROVENANCE'],
  LEVER_COUNT: ['LEVER_IDS', 'LEVER_CHANGES', 'LEVER_VERDICTS', 'LEVER_P', 'LEVER_ONLY_BASE', 'LEVER_ONLY_ARM', 'LEVER_EVIDENCE'],
  PAIR_COUNT: ['PAIR_LEVERS', 'PAIR_SEEDS', 'PAIR_BASES', 'PAIR_ARMS', 'PAIR_BASE_COMPILE', 'PAIR_ARM_COMPILE', 'PAIR_ONLY_BASE', 'PAIR_ONLY_ARM', 'PAIR_P', 'PAIR_BASE_PASS', 'PAIR_ARM_PASS', 'PAIR_EVIDENCE'],
  STAGE_COUNT: ['STAGE_IDS', 'STAGE_TITLES', 'STAGE_STATES', 'STAGE_METRICS', 'STAGE_DETAILS'],
  ROAD_COUNT: ['ROAD_WHEN', 'ROAD_STATES', 'ROAD_TITLES', 'ROAD_RESULTS'],
}

export const EVIDENCE_LEVELS = ['OBSERVED', 'SESSION-OBSERVED', 'SOURCE-CLAIM', 'TARGET', 'UNKNOWN']
export const LEVER_VERDICTS = ['kept', 'no-effect', 'harmful', 'pending']
const COUNT_FIELDS = ['PAIR_BASE_COMPILE', 'PAIR_ARM_COMPILE', 'PAIR_ONLY_BASE', 'PAIR_ONLY_ARM', 'PAIR_BASE_PASS', 'PAIR_ARM_PASS', 'LEVER_ONLY_BASE', 'LEVER_ONLY_ARM']
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const uniq = (values) => new Set(values).size === values.length
const isCount = (v) => /^\d+$/.test(v)
const isP = (v) => v !== '' && Number.isFinite(Number(v)) && Number(v) >= 0 && Number(v) <= 1

// Exact two-sided McNemar on discordant counts: the same test the source repo
// ran (scripts/tc_arena.py mcnemar). The site recomputes it, so a p typed into
// the spec that the counts do not support is refused.
export function mcnemar(b, c) {
  const n = b + c
  if (n === 0) return 1
  const k = Math.min(b, c)
  let tail = 0
  let comb = 1
  for (let i = 0; i <= k; i++) { tail += comb; comb = comb * (n - i) / (i + 1) }
  return Math.min(1, 2 * tail / 2 ** n)
}
// The source prints p to two significant digits (python `:.2g`).
const sameP = (typed, b, c) => {
  const exact = mcnemar(b, c)
  const halfUlp = 0.5 * 10 ** (Math.floor(Math.log10(exact)) - 1)
  return Math.abs(Number(typed) - exact) <= halfUlp + 1e-12
}

export function semanticProblems(f, file = BOARD_SPEC) {
  const p = []
  if (f.KIND !== 'queen-igla-board') p.push(`${file}: KIND must be "queen-igla-board"`)
  if (f.ID !== 'queen/igla-board') p.push(`${file}: ID must be "queen/igla-board"`)
  if (f.SCHEMA_VERSION !== 1) p.push(`${file}: SCHEMA_VERSION must be 1`)
  if (!same(f.GENERATED, [TS_OUT, JSON_OUT, PUBLIC_SPEC_OUT])) p.push(`${file}: GENERATED must be ${JSON.stringify([TS_OUT, JSON_OUT, PUBLIC_SPEC_OUT])}`)
  if (!same(f.EVIDENCE_LEVELS, EVIDENCE_LEVELS)) p.push(`${file}: EVIDENCE_LEVELS must be ${JSON.stringify(EVIDENCE_LEVELS)}`)
  if (!/^[0-9a-f]{40}$/.test(f.SOURCE_COMMIT)) p.push(`${file}: SOURCE_COMMIT must be a 40-character git SHA`)
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(f.SNAPSHOT_AT)) p.push(`${file}: SNAPSHOT_AT must be UTC ISO-8601 seconds`)
  for (const url of ['LIVE_BOARD_URL', 'LIVE_STATE_URL', 'MODEL_URL']) if (!/^https:\/\/\S+$/.test(f[url])) p.push(`${file}: ${url} must use https`)
  for (const [countName, arrays] of Object.entries(PARALLEL)) {
    for (const name of arrays) if (f[name].length !== f[countName]) p.push(`${file}: ${name}.length ${f[name].length} != ${countName} ${f[countName]}`)
  }
  for (const ids of ['HEADLINE_KEYS', 'GATE_KEYS', 'CANDIDATE_IDS', 'LEVER_IDS', 'STAGE_IDS']) if (!uniq(f[ids])) p.push(`${file}: ${ids} must be unique`)
  for (const ev of ['HEADLINE_EVIDENCE', 'LEVER_EVIDENCE', 'PAIR_EVIDENCE']) {
    f[ev].forEach((v, i) => { if (!EVIDENCE_LEVELS.includes(v)) p.push(`${file}: ${ev}[${i}] is unknown`) })
  }
  for (const name of COUNT_FIELDS) {
    f[name].forEach((v, i) => { if (v !== '' && !isCount(v)) p.push(`${file}: ${name}[${i}] ${v} is not a count`) })
  }
  // A candidate is ranked only when it passed every gate.
  f.CANDIDATE_RANKS.forEach((rank, i) => {
    if (rank === '') return
    if (!isCount(rank)) p.push(`${file}: CANDIDATE_RANKS[${i}] is not a rank`)
    if (/:(fail|pending)/.test(f.CANDIDATE_GATES[i])) p.push(`${file}: candidate ${f.CANDIDATE_IDS[i]} is ranked with a failed or pending gate`)
  })
  // Pairs: a measured pair carries all its numbers and a p the counts support.
  for (let i = 0; i < f.PAIR_COUNT; i++) {
    if (!f.LEVER_IDS.includes(f.PAIR_LEVERS[i])) p.push(`${file}: pair ${i} names unknown lever ${f.PAIR_LEVERS[i]}`)
    const measured = f.PAIR_EVIDENCE[i] !== 'UNKNOWN'
    const nums = ['PAIR_BASE_COMPILE', 'PAIR_ARM_COMPILE', 'PAIR_ONLY_BASE', 'PAIR_ONLY_ARM', 'PAIR_BASE_PASS', 'PAIR_ARM_PASS'].map((n) => f[n][i])
    if (measured && (nums.some((v) => v === '') || !isP(f.PAIR_P[i]))) p.push(`${file}: pair ${i} is measured but has an empty number`)
    if (!measured && (nums.some((v) => v !== '') || f.PAIR_P[i] !== '')) p.push(`${file}: pair ${i} is UNKNOWN but carries numbers`)
    if (measured) {
      const [bc, ac, ob, oa] = nums.map(Number)
      if (ac - bc !== oa - ob) p.push(`${file}: pair ${i} compile ${bc}->${ac} disagrees with discordants ${ob}/${oa}`)
      if (!sameP(f.PAIR_P[i], ob, oa)) p.push(`${file}: pair ${i} p ${f.PAIR_P[i]} is not the exact McNemar p of ${ob}/${oa}`)
    }
  }
  // Levers: the pooled counts are the sum of the lever's pairs, and the verdict follows the test.
  for (let i = 0; i < f.LEVER_COUNT; i++) {
    if (!LEVER_VERDICTS.includes(f.LEVER_VERDICTS[i])) { p.push(`${file}: LEVER_VERDICTS[${i}] is unknown`); continue }
    const at = f.PAIR_LEVERS.map((id, j) => id === f.LEVER_IDS[i] ? j : -1).filter((j) => j >= 0)
    if (at.length < 2) p.push(`${file}: lever ${f.LEVER_IDS[i]} needs pairs on at least two seeds`)
    if (new Set(at.map((j) => f.PAIR_SEEDS[j])).size !== at.length) p.push(`${file}: lever ${f.LEVER_IDS[i]} repeats a seed`)
    const measured = at.length > 0 && at.every((j) => f.PAIR_EVIDENCE[j] !== 'UNKNOWN')
    if (f.LEVER_VERDICTS[i] === 'pending') {
      if (measured) p.push(`${file}: lever ${f.LEVER_IDS[i]} is pending but every pair is measured`)
      continue
    }
    if (!measured) { p.push(`${file}: lever ${f.LEVER_IDS[i]} has a verdict without measured pairs`); continue }
    const ob = at.reduce((s, j) => s + Number(f.PAIR_ONLY_BASE[j]), 0)
    const oa = at.reduce((s, j) => s + Number(f.PAIR_ONLY_ARM[j]), 0)
    if (String(ob) !== f.LEVER_ONLY_BASE[i] || String(oa) !== f.LEVER_ONLY_ARM[i]) p.push(`${file}: lever ${f.LEVER_IDS[i]} pooled counts are not the sum of its pairs`)
    if (!isP(f.LEVER_P[i]) || !sameP(f.LEVER_P[i], ob, oa)) p.push(`${file}: lever ${f.LEVER_IDS[i]} p ${f.LEVER_P[i]} is not the pooled exact McNemar p of ${ob}/${oa}`)
    const pv = mcnemar(ob, oa)
    const expected = pv < 0.05 ? (oa > ob ? 'kept' : 'harmful') : 'no-effect'
    if (f.LEVER_VERDICTS[i] !== expected) p.push(`${file}: lever ${f.LEVER_IDS[i]} verdict ${f.LEVER_VERDICTS[i]} does not follow its test (${expected})`)
  }
  return p
}

const rows = (count, make) => Array.from({ length: count }, (_, i) => make(i))
const orNull = (v) => v === '' ? null : v

export function boardOf(f, specSha) {
  return {
    source: { spec: BOARD_SPEC, publicSpec: PUBLIC_SPEC_OUT, sha256: specSha, schemaVersion: f.SCHEMA_VERSION, repo: f.SOURCE_REPO, commit: f.SOURCE_COMMIT, snapshotAt: f.SNAPSHOT_AT },
    name: f.NAME,
    live: { board: f.LIVE_BOARD_URL, state: f.LIVE_STATE_URL },
    model: f.MODEL_URL,
    judge: f.JUDGE,
    headline: rows(f.HEADLINE_COUNT, (i) => ({ key: f.HEADLINE_KEYS[i], label: f.HEADLINE_LABELS[i], value: f.HEADLINE_VALUES[i], of: orNull(f.HEADLINE_OF[i]), hint: f.HEADLINE_HINTS[i], evidence: f.HEADLINE_EVIDENCE[i] })),
    gates: rows(f.GATE_COUNT, (i) => ({ key: f.GATE_KEYS[i], rule: f.GATE_RULES[i] })),
    candidates: rows(f.CANDIDATE_COUNT, (i) => ({
      id: f.CANDIDATE_IDS[i], format: f.CANDIDATE_FORMATS[i], bytes: f.CANDIDATE_BYTES[i], sha: f.CANDIDATE_SHAS[i],
      rank: orNull(f.CANDIDATE_RANKS[i]), verdict: f.CANDIDATE_VERDICTS[i],
      gates: Object.fromEntries(f.CANDIDATE_GATES[i].split(' ').map((g) => g.split(':'))),
      compile: orNull(f.CANDIDATE_COMPILE[i]), strictPass: orNull(f.CANDIDATE_STRICT_PASS[i]),
      tokS: orNull(f.CANDIDATE_TOK_S[i]), bpb: orNull(f.CANDIDATE_BPB[i]), provenance: f.CANDIDATE_PROVENANCE[i],
    })),
    arenaDecision: f.ARENA_DECISION,
    levers: rows(f.LEVER_COUNT, (i) => ({
      id: f.LEVER_IDS[i], change: f.LEVER_CHANGES[i], verdict: f.LEVER_VERDICTS[i], p: orNull(f.LEVER_P[i]),
      onlyBase: orNull(f.LEVER_ONLY_BASE[i]), onlyArm: orNull(f.LEVER_ONLY_ARM[i]), evidence: f.LEVER_EVIDENCE[i],
      pairs: rows(f.PAIR_COUNT, (j) => j).filter((j) => f.PAIR_LEVERS[j] === f.LEVER_IDS[i]).map((j) => ({
        seed: f.PAIR_SEEDS[j], base: f.PAIR_BASES[j], arm: f.PAIR_ARMS[j],
        baseCompile: orNull(f.PAIR_BASE_COMPILE[j]), armCompile: orNull(f.PAIR_ARM_COMPILE[j]),
        onlyBase: orNull(f.PAIR_ONLY_BASE[j]), onlyArm: orNull(f.PAIR_ONLY_ARM[j]), p: orNull(f.PAIR_P[j]),
        basePass: orNull(f.PAIR_BASE_PASS[j]), armPass: orNull(f.PAIR_ARM_PASS[j]), evidence: f.PAIR_EVIDENCE[j],
      })),
    })),
    stages: rows(f.STAGE_COUNT, (i) => ({ id: f.STAGE_IDS[i], title: f.STAGE_TITLES[i], state: f.STAGE_STATES[i], metric: f.STAGE_METRICS[i], detail: f.STAGE_DETAILS[i] })),
    roadmap: rows(f.ROAD_COUNT, (i) => ({ when: f.ROAD_WHEN[i], state: f.ROAD_STATES[i], title: f.ROAD_TITLES[i], result: f.ROAD_RESULTS[i] })),
  }
}

export const renderJson = (board) => JSON.stringify(board, null, 2) + '\n'
export const renderTs = (board) => `// GENERATED by scripts/igla-board-from-spec.mjs from ${BOARD_SPEC}\n// spec sha256 ${board.source.sha256}\n// Do not edit: regenerate the .t27 in ${board.source.repo} (scripts/board_t27.py), then this.\n\nexport const IGLA_BOARD = ${JSON.stringify(board, null, 2)} as const\n\nexport type IglaBoard = typeof IGLA_BOARD\n`

export async function buildBoard({ specText, analyze }) {
  const problems = []
  const analysis = analyze(specText)
  const verdict = verdictOf(analysis)
  if (!verdict.typecheckOk || verdict.discarded > 0 || !verdict.hirOk) problems.push(`${BOARD_SPEC}: compiler verdict not clean (${JSON.stringify(verdict)})`)
  problems.push(...compilerErrors(analysis).map((message) => `${BOARD_SPEC}: ${message}`))
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${BOARD_SPEC}: non-ASCII byte in the spec (L3)`)
  if (CYRILLIC.test(specText)) problems.push(`${BOARD_SPEC}: Cyrillic in the spec (LANG-EN)`)
  if (analysis.ast?.name !== EXPECTED_MODULE) problems.push(`${BOARD_SPEC}: module must be ${EXPECTED_MODULE}, is ${analysis.ast?.name ?? 'missing'}`)
  let consts = {}
  try { consts = constsOf(analysis) } catch (error) { problems.push(`${BOARD_SPEC}: ${error.message}`) }
  problems.push(...checkSchema(consts, REQUIRED, {}, BOARD_SPEC))
  const fields = Object.fromEntries(Object.entries(consts).map(([name, decl]) => [name, decl.value]))
  let tests = { tests: 0, asserts: 0, failures: [] }
  if (problems.length === 0) {
    problems.push(...semanticProblems(fields))
    tests = runSpecTests(analysis, fields)
    if (tests.tests === 0) problems.push(`${BOARD_SPEC}: no test block; the board must test its own invariants`)
    problems.push(...tests.failures.map((message) => `${BOARD_SPEC}: test ${message}`))
  }
  const specSha = sha256(Buffer.from(specText, 'utf8'))
  const board = problems.length ? null : boardOf(fields, specSha)
  return { problems, verdict, fields, specSha, tests, board, json: board ? renderJson(board) : null, ts: board ? renderTs(board) : null, publicSpec: board ? specText : null }
}

async function main() {
  const check = process.argv.includes('--check')
  const specPath = join(SITE, BOARD_SPEC)
  if (!existsSync(specPath)) { console.error(`igla-board-from-spec: ${BOARD_SPEC} is missing`); process.exit(1) }
  const specText = readFileSync(specPath, 'utf8')
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const out = await buildBoard({ specText, analyze })
  if (out.problems.length) {
    console.error(`igla-board-from-spec: ${out.problems.length} problem(s)`)
    for (const problem of out.problems) console.error(`  ${problem}`)
    process.exit(1)
  }
  const targets = [[TS_OUT, out.ts], [JSON_OUT, out.json], [PUBLIC_SPEC_OUT, out.publicSpec]]
  if (check) {
    const stale = targets.filter(([rel, value]) => !existsSync(join(SITE, rel)) || readFileSync(join(SITE, rel), 'utf8') !== value)
    if (stale.length) {
      console.error(`igla-board-from-spec --check: stale ${stale.map(([rel]) => rel).join(', ')}; run node scripts/igla-board-from-spec.mjs`)
      process.exit(1)
    }
  } else {
    for (const [rel, value] of targets) {
      mkdirSync(dirname(join(SITE, rel)), { recursive: true })
      writeFileSync(join(SITE, rel), value)
    }
  }
  console.log(`igla-board-from-spec: ${check ? 'up to date' : 'wrote'} ${targets.map(([rel]) => rel).join(', ')}; spec ${out.specSha.slice(0, 16)}; ${out.fields.CANDIDATE_COUNT} candidates, ${out.fields.LEVER_COUNT} levers, ${out.fields.PAIR_COUNT} pairs; spec tests ${out.tests.tests}, asserts ${out.tests.asserts}, all hold`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => { console.error(error); process.exit(1) })
}
