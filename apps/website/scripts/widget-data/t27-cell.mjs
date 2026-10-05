#!/usr/bin/env node
// t27-cell.mjs -- the data of the t27-cell widget (public/widgets/t27-cell/).
//
// The question: a 3-trit cell has 27 codes, a 4-bit E2M1 (FP4) code 16. Where do the 27 levels of
// T27_N sit against the 15 values of E2M1, and what do 32 weights cost in trits and in bits?
// Nothing numeric is typed here. Every number is read from trinity-fpga (read only):
//
//   1. specs/numeric/ternary_storage_search.t27 (v1) and ternary_storage_search_v2.t27 (v2) are
//      compiled by public/t27/t27_compiler.wasm; both must type-check and every one of their own
//      test blocks must hold; the level tables the two share must be identical;
//   2. T27_N is recomputed from its stated recipe (magnitude k = Phi^-1(p_k) / Phi^-1(p_13) x top,
//      p = linspace(0.5, NUM/DEN, 14)[1:], rounded) with python3 statistics.NormalDist;
//   3. the NVFP4 per-tensor scale is read from the v2 storage line "NVFP4 144 (+32 per tensor)";
//   4. research/block/ternary_storage_search_v2.json gives the measured test perplexities, after its
//      spec_sha256 is checked against the v2 file's sha256;
//   5. every source file must be clean in git; its last commit is written beside it;
//   6. data.json is written, then every K_ fact in specs/widgets/t27-cell.t27 is checked against it.
//
// Run (from apps/website):
//   node scripts/widget-data/t27-cell.mjs           write data.json and check the spec
//   node scripts/widget-data/t27-cell.mjs --check   only check the spec against data.json
//   python3 scripts/widget-data/t27-cell-card.py    then draw card.png from data.json
// Env: TRINITY_FPGA overrides ~/trinity-fpga.
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, constsOf, loadCompiler, sha256, verdictOf } from '../agents-from-specs.mjs'
import { runSpecTests } from '../viewport-from-spec.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
const SPEC = 'specs/widgets/t27-cell.t27'
const OUT_JSON = 'public/widgets/t27-cell/data.json'
const REPO = process.env.TRINITY_FPGA || join(process.env.HOME, 'trinity-fpga')
const V1 = 'specs/numeric/ternary_storage_search.t27'
const V2 = 'specs/numeric/ternary_storage_search_v2.t27'
const RESULT = 'research/block/ternary_storage_search_v2.json'
const VERDICT = 'research/block/TERNARY_STORAGE_V2_VERDICT_2026-09-27.md'
// The storage rows, in the order the v2 spec lists them per 32 weights; each maps to the v2
// constants and to the arm name in the result JSON.
const ROWS = [
  { id: 'T27', trits: 'TRITS_T27', bits: 'BITS_T27_DENSE', arm: 'T27_STAR', dense: true },
  { id: 'MXFP4', trits: 'TRITS_MXFP4', bits: 'BITS_MXFP4', arm: 'MXFP4' },
  { id: 'MXPLUS', trits: 'TRITS_MXPLUS', bits: 'BITS_MXPLUS', arm: 'MXPLUS' },
  { id: 'NVFP4', trits: 'TRITS_NVFP4', bits: 'BITS_NVFP4', arm: 'NVFP4', tensor: true },
  { id: 'E2M2', trits: 'TRITS_E2M2', bits: 'BITS_E2M2', arm: 'E2M2' },
]

const fail = (m) => { console.error(`t27-cell: ${m}`); process.exit(1) }
const git = (...args) => execFileSync('git', ['-C', REPO, ...args], { encoding: 'utf8' }).trim()
const valuesOf = (analysis) => Object.fromEntries(Object.entries(constsOf(analysis)).map(([k, v]) => [k, v.value]))
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)

function source(rel) {
  const dirty = git('status', '--porcelain', '--', rel)
  if (dirty) fail(`${rel} has uncommitted changes in ${REPO}; the page cites commits, not a working tree`)
  const bytes = readFileSync(join(REPO, rel))
  return { file: rel, commit: git('log', '-1', '--format=%h', '--', rel), date: git('log', '-1', '--format=%cs', '--', rel), sha256: sha256(bytes), bytes }
}

function compileSource(analyze, src) {
  const analysis = analyze(src.bytes.toString('utf8'))
  const v = verdictOf(analysis)
  if (!v.typecheckOk || !v.hirOk || v.discarded > 0) fail(`${src.file}: compiler verdict not clean ${JSON.stringify(v)}`)
  const K = valuesOf(analysis)
  const t = runSpecTests(analysis, K)
  if (t.failures.length) fail(`${src.file}: its own tests fail: ${t.failures.join('; ')}`)
  return { K, tests: t.tests, asserts: t.asserts, module: analysis.ast?.name }
}

function recomputeT27N(num, den, top) {
  const py = `from statistics import NormalDist\nimport json\nN=NormalDist()\nps=[0.5+(${num}/${den}-0.5)*i/13 for i in range(14)][1:]\nt=N.inv_cdf(ps[-1])\nprint(json.dumps([0]+[round(N.inv_cdf(p)/t*${top}) for p in ps]))`
  return JSON.parse(execFileSync('python3', ['-c', py], { encoding: 'utf8' }))
}

async function build(analyze) {
  const v1 = source(V1), v2 = source(V2), result = source(RESULT), verdict = source(VERDICT)
  const a = compileSource(analyze, v1), b = compileSource(analyze, v2)
  for (const k of ['E2M1', 'E2M2', 'T27_N', 'T27_N_OFFSET_NUM', 'T27_N_OFFSET_DEN', 'BLOCK', 'NWIN', 'SEQLEN']) {
    if (!same(a.K[k], b.K[k])) fail(`${k} differs between ${V1} and ${V2}`)
  }
  const T27_N = b.K.T27_N, E2M1 = b.K.E2M1
  const top27 = T27_N[T27_N.length - 1], topE = E2M1[E2M1.length - 1]
  const recomputed = recomputeT27N(b.K.T27_N_OFFSET_NUM, b.K.T27_N_OFFSET_DEN, top27)
  if (!same(recomputed, T27_N)) fail(`T27_N recomputed ${JSON.stringify(recomputed)} differs from the spec's ${JSON.stringify(T27_N)}`)

  const m = /NVFP4 (\d+) \(\+(\d+) per tensor\)/.exec(v2.bytes.toString('utf8'))
  if (!m) fail(`${V2}: no "NVFP4 N (+M per tensor)" storage line`)
  if (Number(m[1]) !== b.K.BITS_NVFP4) fail(`${V2}: the storage line says NVFP4 ${m[1]} bits, BITS_NVFP4 is ${b.K.BITS_NVFP4}`)
  const tensorBits = Number(m[2])

  const r = JSON.parse(result.bytes.toString('utf8'))
  if (r.spec !== V2 || r.spec_sha256 !== v2.sha256) fail(`${RESULT} was run against ${r.spec} ${r.spec_sha256}, not ${V2} ${v2.sha256}`)
  if (r.status !== 'done' || r.t27_star !== 'T27_N') fail(`${RESULT}: status ${r.status}, t27_star ${r.t27_star}; the page draws T27_N`)
  const base = r.arms.find((x) => x.arm === 'BASE' && x.phase === 'ruler')
  if (!base) fail(`${RESULT}: no BASE ruler arm`)

  const rows = ROWS.map((row) => {
    const ppl = r.test[row.arm]
    if (typeof ppl !== 'number') fail(`${RESULT}: no test perplexity for ${row.arm}`)
    return { id: row.id, trits: b.K[row.trits], bits: b.K[row.bits], dense: !!row.dense, tensorBits: row.tensor ? tensorBits : 0, ppl, permille: r.verdicts?.[row.id]?.test_permille ?? null }
  })
  for (const row of rows) if (!Number.isInteger(row.trits) || !Number.isInteger(row.bits)) fail(`${row.id}: storage not found in ${V2}`)

  return {
    widget: 't27-cell',
    note: 'Generated by scripts/widget-data/t27-cell.mjs from trinity-fpga; do not edit by hand.',
    sources: Object.fromEntries([['v1', v1], ['v2', v2], ['result', result], ['verdict', verdict]].map(([k, s]) => [k, { file: s.file, commit: s.commit, date: s.date, sha256: s.sha256 }])),
    compiler: { wasm: WASM, sha256: sha256(readFileSync(join(SITE, WASM))), v1: { module: a.module, tests: a.tests, asserts: a.asserts }, v2: { module: b.module, tests: b.tests, asserts: b.asserts } },
    cell: { trits: b.K.CELL_TRITS, codes: 3 ** b.K.CELL_TRITS, mags: b.K.T27_MAGS, scaleTrits: b.K.T27_SCALE_TRITS, block: b.K.BLOCK },
    t27: { name: r.t27_star, levels: T27_N, top: top27, recomputed: true, recipe: { num: b.K.T27_N_OFFSET_NUM, den: b.K.T27_N_OFFSET_DEN } },
    e2m1: { name: 'E2M1', levels: E2M1, top: topE, codes: 2 * E2M1.length, distinct: 2 * E2M1.length - 1, unit: 'half' },
    storage: rows,
    quality: { base: base.ppl, nwin: b.K.NWIN, seqlen: b.K.SEQLEN, split: 'test', primary: r.primary, finished: r.finished, versions: r.versions },
  }
}

function checkSpec(K, d) {
  const row = (id) => d.storage.find((r) => r.id === id)
  const facts = {
    K_BLOCK: d.cell.block, K_CELL_TRITS: d.cell.trits, K_CELL_CODES: d.cell.codes, K_T27_MAGS: d.cell.mags,
    K_T27_SCALE_TRITS: d.cell.scaleTrits, K_E2M1_CODES: d.e2m1.codes, K_E2M1_MAGS: d.e2m1.levels.length,
    K_E2M1_DISTINCT: d.e2m1.distinct, K_TRITS_T27: row('T27').trits, K_TRITS_NVFP4: row('NVFP4').trits,
    K_BITS_NVFP4: row('NVFP4').bits, K_BITS_T27_DENSE: row('T27').bits, K_BITS_E2M2: row('E2M2').bits,
  }
  const bad = Object.entries(facts).filter(([k, v]) => K[k] !== v).map(([k, v]) => `${k} is ${K[k]}, data says ${v}`)
  if (d.t27.levels.length !== K.K_T27_MAGS + 1) bad.push(`T27_N has ${d.t27.levels.length} entries, not ${K.K_T27_MAGS + 1}`)
  const ids = d.storage.map((r) => r.id)
  if (!same(ids, K.SAY_FORMAT_IDS)) bad.push(`SAY_FORMAT_IDS ${JSON.stringify(K.SAY_FORMAT_IDS)} differ from the data rows ${JSON.stringify(ids)}`)
  for (const n of [row('T27').trits, row('NVFP4').trits, row('T27').bits, row('NVFP4').bits]) if (!K.HOOK.includes(String(n))) bad.push(`HOOK does not say ${n}`)
  if (bad.length) fail(`${SPEC} disagrees with ${OUT_JSON}:\n  ${bad.join('\n  ')}`)
}

const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
const spec = analyze(readFileSync(join(SITE, SPEC), 'utf8'))
const K = valuesOf(spec)
let data
if (process.argv.includes('--check')) data = JSON.parse(readFileSync(join(SITE, OUT_JSON), 'utf8'))
else {
  data = await build(analyze)
  writeFileSync(join(SITE, OUT_JSON), JSON.stringify(data, null, 1) + '\n')
}
checkSpec(K, data)
const t = data.storage.find((r) => r.id === 'T27'), nv = data.storage.find((r) => r.id === 'NVFP4')
console.log(`t27-cell: ${process.argv.includes('--check') ? 'checked' : 'wrote'} ${OUT_JSON}; T27 ${t.trits} trits / ${t.bits} bits, NVFP4 ${nv.trits} trits / ${nv.bits} bits; test ppl ${t.ppl.toFixed(4)} vs ${nv.ppl.toFixed(4)}; spec facts hold`)
