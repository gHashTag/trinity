#!/usr/bin/env node
// uart-bucket.mjs -- the measured runs behind public/widgets/uart-bucket/, parsed from the record
// files of gHashTag/trinity-fpga. Nothing here is typed by hand: every number in data.json is
// matched out of a record file read with `git show <commit>:<path>`, where <commit> is the last
// commit that touched the file. The commits are also named in DATA_SOURCES of
// specs/widgets/uart-bucket.t27; this script fails if the two disagree, if a K_ constant of that
// spec drifts from the diagnostic's own spec, or if any expected line is missing.
//
// Usage: node scripts/widget-data/uart-bucket.mjs [--repo ~/trinity-fpga]
//        then python3 scripts/widget-data/uart-bucket-card.py
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT = join(SITE, 'public/widgets/uart-bucket/data.json')
const SPEC = join(SITE, 'specs/widgets/uart-bucket.t27')
const ri = process.argv.indexOf('--repo')
const REPO = ri > 0 ? process.argv[ri + 1] : join(homedir(), 'trinity-fpga')
const REPO_NAME = 'gHashTag/trinity-fpga'

const FILES = {
  diag: 'conformance/UART_LOSS_DIAG.md',
  diagSpec: 'specs/trinet/uart_loss_diag_ax7203.t27',
  receipts: 'conformance/TERN_TC_LAYER_RECEIPTS.md',
  generate: 'conformance/TERN_TC_GENERATE.md',
}

const git = (...args) => execFileSync('git', ['-C', REPO, ...args], { encoding: 'utf8', maxBuffer: 64 << 20 })
const die = (msg) => { console.error(`uart-bucket: ${msg}`); process.exit(1) }
const num = (s) => Number(String(s).replace(/,/g, ''))
const need = (text, re, what) => { const m = text.match(re); if (!m) die(`${what}: no match for ${re}`); return m }

// --- Read each file at the last commit that touched it ------------------------------------
const src = {}
const sources = []
for (const [key, path] of Object.entries(FILES)) {
  const commit = git('log', '-1', '--format=%h', '--', path).trim()
  if (!commit) die(`${path}: no commit in ${REPO}`)
  src[key] = git('show', `${commit}:${path}`)
  sources.push({ path, commit })
}

// --- The diagnostic's own spec: frame sizes, buffer, arms ---------------------------------
const pubConst = (name) => need(src.diagSpec, new RegExp(`pub const ${name} : [^=]+= (.+);`), FILES.diagSpec)[1].trim()
const diagSpec = {
  reqLen: num(pubConst('REQ_LEN')),
  respLen: num(pubConst('RESP_LEN')),
  rxBytes: num(pubConst('CP2102N_RX_BYTES')),
  armWindows: JSON.parse(pubConst('ARM_WINDOWS')),
  jobsPerPass: num(pubConst('JOBS_PER_PASS')),
  jobsPerArm: num(pubConst('JOBS_PER_ARM')),
}

// --- UART_LOSS_DIAG.md: the result table -------------------------------------------------
const diagTitle = need(src.diag, /^# UART loss diagnostic, (\S+) node, (\d{4}-\d\d-\d\d)/m, FILES.diag)
const board = diagTitle[1]
const date = diagTitle[2]
const row = (label) => {
  const m = need(src.diag, new RegExp(`^\\| ${label.replace(/[()+]/g, '\\$&')} \\| ([^|]+) \\| ([^|]+) \\|`, 'm'), `${FILES.diag} row "${label}"`)
  return [m[1].trim(), m[2].trim()]
}
const head = need(src.diag, /^\| \| window (\d+) \| window (\d+) \|/m, `${FILES.diag} table head`)
const windows = [num(head[1]), num(head[2])]
const lead = (s) => num(need(s, /^[\d,.]+/, `cell "${s}"`)[0])
const cols = {
  inFlight: row('bytes in flight').map(num),
  jobsSent: row('jobs sent').map(num),
  accepted: row('answers accepted (tag + y)').map(num),
  wrongY: row('wrong y under a valid tag').map(num),
  lost: row('answers lost').map(num),
  events: row('loss events').map(lead),
  elapsedS: row('elapsed').map((s) => lead(s.replace(/\s*s$/, ''))),
}
const arms = windows.map((w, i) => Object.fromEntries([['window', w], ...Object.entries(cols).map(([k, v]) => [k, v[i]])]))

// The rule and the edge windows as the record states them.
const rule = need(src.diag, /(\d+) \/ (\d+) = ([\d.]+), so (\d+) is the largest window that fits/, `${FILES.diag} rule`)
const edgeLine = need(src.diag, /W(\d+) \((\d+) B\) passed and W(\d+) \((\d+) B\) failed/, `${FILES.diag} edge windows`)
const wire = need(src.diag, /takes (\d+) B \S+ (\d+) bit at\s+([\d,]+) baud \S+ ([\d,]+) = ([\d.]+) s/, `${FILES.diag} wire time`)
need(src.diag, /request\s+direction is the bottleneck/, `${FILES.diag} bottleneck sentence`)
need(src.diag, /It does not show that the buffer is the cause\. The pattern fits the\s+buffer, but nothing proves it\./, `${FILES.diag} caveat`)
const usbPath = need(src.diag, /On this USB path \(a (\w+) hub/, `${FILES.diag} USB path`)[1]

// --- TERN_TC_LAYER_RECEIPTS.md: the single runs ------------------------------------------
const section = (start, stop) => {
  const a = src.receipts.indexOf(start)
  if (a < 0) die(`${FILES.receipts}: no section "${start}"`)
  const b = src.receipts.indexOf(stop, a + start.length)
  return src.receipts.slice(a, b < 0 ? undefined : b)
}
const harness = (text, what) => {
  const sent = need(text, /jobs sent\s+: (\d+) of (\d+) planned \(window (\d+)\)/, `${what} jobs sent`)
  const rec = need(text, /receipts verified \(tag\) : (\d+)\/(\d+)/, `${what} receipts`)
  const rows = need(text, /rows bit-exact\s+: (\d+)\/(\d+)/, `${what} rows`)
  const el = need(text, /elapsed\s+: ([\d.]+) s \((\d+) answers\/s\)/, `${what} elapsed`)
  return {
    window: num(sent[3]), jobsSent: num(sent[1]), planned: num(sent[2]),
    receipts: num(rec[1]), receiptsOf: num(rec[2]), rows: num(rows[1]), rowsOf: num(rows[2]),
    elapsedS: num(el[1]), answersPerS: num(el[2]),
  }
}
// From "Got:" on: the lines before it are the expectation, not the result.
const step1All = section('### Rerun step 1: `--all` at window 24', '### Rerun step 2')
const step1 = step1All.slice(step1All.indexOf('Got:'))
if (!step1.startsWith('Got:')) die(`${FILES.receipts}: rerun step 1 has no "Got:"`)
const model = need(step1, /model\.bin: (\d+) matrices, (\d+) rows, (\d+) ternary weights/, `${FILES.receipts} model line`)
const carried = {
  ...harness(step1, 'rerun step 1'),
  matrices: num(model[1]), modelRows: num(model[2]), weights: num(model[3]),
}
const w26 = harness(section('**Window 26 (', '**Window 30 ('), 'window 26')
const w30 = harness(section('**Window 30 (', '- **The two predictions'), 'window 30')
const edges = [w26, w30].map((r) => ({ ...r, inFlight: r.window * diagSpec.respLen, slipped: r.receipts < r.receiptsOf }))

// --- TERN_TC_GENERATE.md: where generation ran -------------------------------------------
need(src.generate, /on synthetic activation vectors\.\s+No token came out of it: generation ran on the Mac\./, `${FILES.generate} generation on the Mac`)
need(src.generate, /The host still does\s+everything except the ternary dot products\./, `${FILES.generate} host does everything else`)

// --- Cross-checks: the record against itself, and this widget's spec against the record ---
const checks = [
  [diagSpec.respLen === num(rule[2]), 'the rule divides by RESP_LEN'],
  [diagSpec.rxBytes === num(rule[1]), 'the rule divides CP2102N_RX_BYTES'],
  [Math.floor(diagSpec.rxBytes / diagSpec.respLen) === num(rule[4]), 'floor(rx / resp) is the stated largest window'],
  [JSON.stringify(diagSpec.armWindows) === JSON.stringify(windows), 'the table arms are ARM_WINDOWS'],
  [arms.every((a) => a.inFlight === a.window * diagSpec.respLen), 'bytes in flight = window x RESP_LEN'],
  [arms.every((a) => a.jobsSent === diagSpec.jobsPerArm), 'jobs sent = JOBS_PER_ARM'],
  [arms.every((a) => a.accepted + a.lost + a.wrongY === a.jobsSent), 'accepted + lost + wrong y = jobs sent'],
  [diagSpec.reqLen === num(wire[1]), 'the wire time uses REQ_LEN'],
  [num(wire[4]) === diagSpec.jobsPerArm, 'the wire time covers one arm'],
  [num(edgeLine[1]) === w26.window && num(edgeLine[2]) === edges[0].inFlight, 'W26 line matches the window-26 run'],
  [num(edgeLine[3]) === w30.window && num(edgeLine[4]) === edges[1].inFlight, 'W30 line matches the window-30 run'],
  [carried.planned === diagSpec.jobsPerPass && w26.planned === diagSpec.jobsPerPass, 'the single runs plan JOBS_PER_PASS'],
]
for (const [ok, what] of checks) if (!ok) die(`record disagrees with itself: ${what}`)

const spec = readFileSync(SPEC, 'utf8')
const k = (name) => {
  const v = need(spec, new RegExp(`pub const ${name} : [^=]+= (.+);`), `${SPEC} ${name}`)[1].trim()
  return JSON.parse(v)
}
const specChecks = [
  ['K_RX_BYTES', diagSpec.rxBytes], ['K_ANSWER_BYTES', diagSpec.respLen], ['K_REQUEST_BYTES', diagSpec.reqLen],
  ['K_LARGEST_FIT', num(rule[4])], ['K_ARM_WINDOWS', windows], ['K_EDGE_WINDOWS', [w26.window, w30.window]],
]
for (const [name, want] of specChecks) {
  if (JSON.stringify(k(name)) !== JSON.stringify(want)) die(`${name} in specs/widgets/uart-bucket.t27 is ${JSON.stringify(k(name))}, the record says ${JSON.stringify(want)}`)
}
for (const s of sources) {
  if (!spec.includes(`${s.path} at commit ${s.commit}`)) die(`DATA_SOURCES must name ${s.path} at commit ${s.commit}`)
}

const data = {
  repo: REPO_NAME,
  sources,
  board,
  date,
  usbHub: usbPath,
  rxBytes: diagSpec.rxBytes,
  answerBytes: diagSpec.respLen,
  requestBytes: diagSpec.reqLen,
  ratio: rule[3],
  largestFit: num(rule[4]),
  jobsPerArm: diagSpec.jobsPerArm,
  arms,
  wire: { requestBytes: num(wire[1]), bitsPerByte: num(wire[2]), baud: num(wire[3]), jobs: num(wire[4]), seconds: num(wire[5]) },
  edges,
  carried,
  generationOnMac: true,
}
mkdirSync(dirname(OUT), { recursive: true })
writeFileSync(OUT, JSON.stringify(data, null, 2) + '\n')
console.log(`uart-bucket: wrote ${OUT.replace(SITE + '/', '')} from ${sources.map((s) => `${s.path}@${s.commit}`).join(', ')}`)
console.log(`  arms ${arms.map((a) => `W${a.window} ${a.inFlight} B lost ${a.lost}/${a.jobsSent} in ${a.elapsedS} s`).join('; ')}`)
console.log(`  edges ${edges.map((e) => `W${e.window} ${e.receipts}/${e.receiptsOf}`).join('; ')}; carried ${carried.receipts}/${carried.receiptsOf} in ${carried.elapsedS} s`)
