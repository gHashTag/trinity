#!/usr/bin/env node
// t27-vs-nvfp4.mjs -- the data behind public/widgets/t27-vs-nvfp4/, read from the trinity-fpga run.
//
// Read only, nothing is re-run: the numbers are the second ternary storage search of 2026-09-27
// (SmolLM2-135M, wikitext-2, weights only), as its runner wrote them and its verdict reported them.
//
//   node scripts/widget-data/t27-vs-nvfp4.mjs           write public/widgets/t27-vs-nvfp4/data.json
//   node scripts/widget-data/t27-vs-nvfp4.mjs --check   re-read the sources, fail if data.json or any
//                                                       K_ fact of specs/widgets/t27-vs-nvfp4.t27
//                                                       disagrees, run the spec's tests on the facts
//                                                       and a negative control that must fail them
//
// Sources (TRINITY_FPGA, default ~/trinity-fpga):
//   research/block/ternary_storage_search_v2.json       perplexities, permille ratios, verdicts
//   specs/numeric/ternary_storage_search_v2.t27         the pre-registration: ladder, windows, storage
//   research/block/TERNARY_STORAGE_V2_VERDICT_2026-09-27.md   the report: its tables are cross-checked
//
// The pre-registered ladder compares T27_STAR with NVFP4, MXPLUS and MXFP4 only. E2M2 is not on it;
// its ratio is computed here from the two test perplexities with the same formula and flagged so.
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { constsOf, loadCompiler, sha256, verdictOf } from '../agents-from-specs.mjs'
import { runSpecTests } from '../viewport-from-spec.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const WASM = 'public/t27/t27_compiler.wasm'
const SPEC = 'specs/widgets/t27-vs-nvfp4.t27'
const OUT = 'public/widgets/t27-vs-nvfp4/data.json'
const FPGA = process.env.TRINITY_FPGA || join(homedir(), 'trinity-fpga')
const SRC = {
  results: 'research/block/ternary_storage_search_v2.json',
  prereg: 'specs/numeric/ternary_storage_search_v2.t27',
  verdict: 'research/block/TERNARY_STORAGE_V2_VERDICT_2026-09-27.md',
}
// The order the page shows the arms in, and the comparators of T27_STAR (E2M2 first: the one it loses to).
const ARMS = ['BASE', 'E2M2', 'T27_STAR', 'NVFP4', 'MXPLUS', 'MXFP4']
const COMPARATORS = ['E2M2', 'NVFP4', 'MXPLUS', 'MXFP4']
// Storage per 32 weights: which constant of the pre-registration belongs to which arm.
const TRITS = { E2M2: 'TRITS_E2M2', T27_STAR: 'TRITS_T27', NVFP4: 'TRITS_NVFP4', MXPLUS: 'TRITS_MXPLUS', MXFP4: 'TRITS_MXFP4' }
const BITS = { E2M2: 'BITS_E2M2', T27_STAR: 'BITS_T27_DENSE', NVFP4: 'BITS_NVFP4', MXPLUS: 'BITS_MXPLUS', MXFP4: 'BITS_MXFP4' }

const fail = (m) => { console.error(`t27-vs-nvfp4: ${m}`); process.exit(1) }
const git = (...a) => execFileSync('git', ['-C', FPGA, ...a], { encoding: 'utf8' }).trim()
const e4 = (x) => Math.round(x * 1e4)
const x10 = (x) => Math.round(x * 10)

let analyzeP = null
const analyzer = () => (analyzeP ??= loadCompiler(readFileSync(join(SITE, WASM))))

/** The pre-registration, compiled by the same wasm compiler the site uses. */
async function prereg() {
  const text = readFileSync(join(FPGA, SRC.prereg), 'utf8')
  const a = (await analyzer())(text)
  const v = verdictOf(a)
  if (!v.typecheckOk || v.discarded || !v.hirOk) fail(`${SRC.prereg} does not compile cleanly: ${JSON.stringify(v)}`)
  const K = Object.fromEntries(Object.entries(constsOf(a)).map(([k, c]) => [k, c.value]))
  return { K, sha: sha256(Buffer.from(text)) }
}

/** The ladder of the pre-registration, applied to a permille ratio. */
const rung = (r, P) => (r <= P.BEAT_PERMILLE ? 'beat' : r <= P.TIE_PERMILLE ? 'tie' : 'lose')
const RUNG_OF_RUNNER = { 'T27 better': 'beat', tie: 'tie', 'C better': 'lose' }

function verdictTables(md) {
  // "| arm | test perplexity | ..." rows and "| comparator | test r ..." rows, as printed.
  const rows = md.split('\n').filter((l) => l.startsWith('|')).map((l) => l.split('|').slice(1, -1).map((c) => c.replace(/\*/g, '').trim()))
  const num = (s) => Number(String(s).replace(/[^\d.]/g, ''))
  const ppl = {}, r = {}
  for (const c of rows) {
    const name = c[0].split(/\s/)[0]
    if (c.length === 5 && /^\d+\.\d{4}$/.test(c[1]) && /^\d\.\d{3}$/.test(c[2])) ppl[name] = num(c[1])
    if (c.length === 5 && /^\d+\.\d$/.test(c[1]) && /^\d+\.\d$/.test(c[3])) r[name] = { test: num(c[1]), dev: num(c[3]) }
  }
  return { ppl, r }
}

async function build() {
  for (const f of Object.values(SRC)) if (!existsSync(join(FPGA, f))) fail(`${join(FPGA, f)} not found (set TRINITY_FPGA)`)
  const res = JSON.parse(readFileSync(join(FPGA, SRC.results), 'utf8'))
  const { K: P, sha: preregSha } = await prereg()

  // The run is the one the pre-registration describes, and it finished.
  if (res.status !== 'done' || res.retry !== false) fail(`run status ${res.status}, retry ${res.retry}`)
  if (res.spec !== SRC.prereg) fail(`run names spec ${res.spec}`)
  if (res.spec_sha256 !== preregSha) fail(`run used spec sha256 ${res.spec_sha256}, ${SRC.prereg} is now ${preregSha}`)
  if (!res.rulers_reproduced) fail('the rulers were not reproduced; the run has no numbers to show')
  if (JSON.stringify(P.LADDER_COMPARATORS) !== JSON.stringify(COMPARATORS.slice(1))) fail(`ladder is ${P.LADDER_COMPARATORS}, this page assumes ${COMPARATORS.slice(1)}`)
  if (P.PRIMARY !== 'NVFP4') fail(`primary is ${P.PRIMARY}`)
  const star = res.t27_star
  const cands = P.T27_CANDIDATES
  if (!cands.includes(star)) fail(`T27_STAR ${star} is not a candidate`)

  // Test perplexity of every arm. BASE and MXFP4 come from the ruler rows (E2M1, rule B, on test).
  const ruler = (arm) => res.arms.find((a) => a.phase === 'ruler' && a.split === 'test' && a.arm === arm)?.ppl
  const test = { BASE: ruler('BASE'), E2M2: res.test.E2M2, T27_STAR: res.test.T27_STAR, NVFP4: res.test.NVFP4, MXPLUS: res.test.MXPLUS, MXFP4: res.test.MXFP4 }
  if (ruler('E2M1') !== res.test.MXFP4) fail('MXFP4 test is not its ruler row')
  // Dev: BASE was not run on dev. MXFP4's dev arm is named E2M1 in the run.
  const dev = { BASE: null, E2M2: res.dev.E2M2, T27_STAR: res.dev[star], NVFP4: res.dev.NVFP4, MXPLUS: res.dev.MXPLUS, MXFP4: res.dev.E2M1 }
  for (const [s, o] of Object.entries({ test, dev })) for (const a of ARMS) if (!(a === 'BASE' && s === 'dev') && !(o[a] > 0)) fail(`${s} perplexity of ${a} missing`)

  const ratios = {}
  for (const [split, o] of Object.entries({ test, dev })) {
    ratios[split] = COMPARATORS.map((c) => {
      const r = (1000 * o.T27_STAR) / o[c]
      const ladder = P.LADDER_COMPARATORS.includes(c)
      if (ladder) {
        const ran = res.verdicts[c][`${split}_permille`]
        if (Math.abs(ran - r) > 1e-9) fail(`${split} r for ${c}: runner ${ran}, recomputed ${r}`)
        if (RUNG_OF_RUNNER[res.verdicts[c][split]] !== rung(r, P)) fail(`${split} verdict for ${c}: runner "${res.verdicts[c][split]}", ladder says ${rung(r, P)}`)
      }
      return { c, r, verdict: rung(r, P), ladder }
    })
  }

  // The verdict report must print what the run wrote (4 decimals for ppl, 1 for r).
  const md = verdictTables(readFileSync(join(FPGA, SRC.verdict), 'utf8'))
  const mdName = { T27_STAR: star, E2M2: 'E2M2', BASE: 'BASE', NVFP4: 'NVFP4', MXPLUS: 'MXPLUS', MXFP4: 'MXFP4' }
  for (const a of ARMS) if (md.ppl[mdName[a]] !== Math.round(test[a] * 1e4) / 1e4) fail(`verdict prints ${mdName[a]} test ${md.ppl[mdName[a]]}, run wrote ${test[a]}`)
  for (const x of ratios.test.filter((q) => q.ladder)) {
    const row = md.r[x.c]
    const devR = ratios.dev.find((q) => q.c === x.c).r
    if (!row || row.test !== Math.round(x.r * 10) / 10 || row.dev !== Math.round(devR * 10) / 10) fail(`verdict prints ${x.c} r ${JSON.stringify(row)}, run gives ${x.r} / ${devR}`)
  }

  const excess = (a) => test[a] - test.BASE
  const gapClosed = 1 - excess('T27_STAR') / excess('NVFP4')
  const source = {}
  for (const [k, f] of Object.entries(SRC)) {
    source[k] = { repo: 'trinity-fpga', path: f, commit: git('log', '-1', '--format=%h', '--abbrev=10', '--', f), sha256: sha256(readFileSync(join(FPGA, f))) }
  }
  return {
    about: 'Generated by scripts/widget-data/t27-vs-nvfp4.mjs from the trinity-fpga files named in source; do not edit.',
    source,
    run: { started: res.started, finished: res.finished, versions: res.versions, retry: res.retry, rulers_reproduced: res.rulers_reproduced },
    protocol: {
      windows: P.NWIN, seqlen: P.SEQLEN, block: P.BLOCK, beat_permille: P.BEAT_PERMILLE, tie_permille: P.TIE_PERMILLE,
      primary: P.PRIMARY, ladder: P.LADDER_COMPARATORS, t27_star: star, candidates: cands,
    },
    arms: ARMS.map((a) => ({
      id: a, name: a === 'T27_STAR' ? star : a,
      test: test[a], dev: dev[a],
      trits32: TRITS[a] ? P[TRITS[a]] : null, bits32: BITS[a] ? P[BITS[a]] : null,
    })),
    dev_candidates: cands.map((c) => ({ name: c, dev: res.dev[c], chosen: c === star })),
    ratios,
    gap: { base: test.BASE, t27_excess: excess('T27_STAR'), nvfp4_excess: excess('NVFP4'), closed: gapClosed },
  }
}

/** The K_ facts the widget spec must carry, from the built data. */
function factsOf(d) {
  const arm = (id) => d.arms.find((a) => a.id === id)
  const devOf = (a) => (a.dev === null ? 0 : e4(a.dev))
  return {
    K_ARMS: d.arms.map((a) => a.name),
    K_PPL_TEST_E4: d.arms.map((a) => e4(a.test)),
    K_PPL_DEV_E4: d.arms.map(devOf),
    K_COMPARATORS: d.ratios.test.map((q) => q.c),
    K_COMPARATOR_ARM: d.ratios.test.map((q) => d.arms.findIndex((a) => a.id === q.c)),
    K_R_TEST_X10: d.ratios.test.map((q) => x10(q.r)),
    K_R_DEV_X10: d.ratios.dev.map((q) => x10(q.r)),
    K_BEAT_PERMILLE: d.protocol.beat_permille,
    K_TIE_PERMILLE: d.protocol.tie_permille,
    K_WINDOWS: d.protocol.windows,
    K_SEQLEN: d.protocol.seqlen,
    K_TRITS_32: d.arms.map((a) => a.trits32 ?? 0),
    K_BITS_32: d.arms.map((a) => a.bits32 ?? 0),
    K_GAP_CLOSED_PCT: Math.round(d.gap.closed * 100),
    K_EXCESS_T27_E2: Math.round(d.gap.t27_excess * 100),
    K_EXCESS_NVFP4_E2: Math.round(d.gap.nvfp4_excess * 100),
    K_T27_ARM: d.arms.findIndex((a) => a.id === 'T27_STAR'),
    K_BASE_ARM: d.arms.findIndex((a) => a.id === 'BASE'),
    K_NVFP4_ARM: d.arms.findIndex((a) => a.id === 'NVFP4'),
    _check_t27: arm('T27_STAR').name,
  }
}

async function checkSpec(d) {
  const text = readFileSync(join(SITE, SPEC), 'utf8')
  const analysis = (await analyzer())(text)
  const K = Object.fromEntries(Object.entries(constsOf(analysis)).map(([k, v]) => [k, v.value]))
  const facts = factsOf(d)
  const bad = []
  for (const [k, v] of Object.entries(facts)) {
    if (k.startsWith('_')) continue
    if (!(k in K)) bad.push(`${k} missing from ${SPEC}; it should be ${JSON.stringify(v)}`)
    else if (JSON.stringify(K[k]) !== JSON.stringify(v)) bad.push(`${k}: spec says ${JSON.stringify(K[k])}, the run says ${JSON.stringify(v)}`)
  }
  const t = runSpecTests(analysis, K)
  for (const f of t.failures) bad.push(`spec test: ${f}`)
  // Negative control: move T27's test perplexity 2 permille and the ratio tests must fail.
  const broken = { ...K, K_PPL_TEST_E4: K.K_PPL_TEST_E4.map((v, i) => (i === K.K_T27_ARM ? Math.round(v * 1.002) : v)) }
  const neg = runSpecTests(analysis, broken)
  if (neg.failures.length === 0) bad.push('negative control: the spec tests still hold with T27 test perplexity moved 2 permille')
  return { bad, tests: t, neg: neg.failures.length }
}

async function main() {
  const d = await build()
  const json = JSON.stringify(d, null, 2) + '\n'
  if (process.argv.includes('--check')) {
    const out = join(SITE, OUT)
    if (!existsSync(out)) fail(`${OUT} missing; run without --check`)
    if (readFileSync(out, 'utf8') !== json) fail(`${OUT} differs from the sources; run without --check`)
  } else {
    writeFileSync(join(SITE, OUT), json)
    console.log(`wrote ${OUT} (${json.length} bytes)`)
  }
  if (existsSync(join(SITE, SPEC))) {
    const { bad, tests, neg } = await checkSpec(d)
    if (bad.length) fail(`spec disagrees:\n  ${bad.join('\n  ')}`)
    console.log(`${SPEC}: every K_ fact matches the run; ${tests.tests} tests, ${tests.asserts} asserts pass; negative control fails ${neg}`)
  }
  for (const q of d.ratios.test) console.log(`test r ${q.c.padEnd(6)} ${q.r.toFixed(1)} permille  ${q.verdict}${q.ladder ? '' : '  (not on the pre-registered ladder)'}`)
  console.log(`gap closed ${(d.gap.closed * 100).toFixed(1)}%  excess T27 ${d.gap.t27_excess.toFixed(2)} vs NVFP4 ${d.gap.nvfp4_excess.toFixed(2)}`)
}

main().catch((e) => fail(e.stack || e.message))
