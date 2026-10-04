#!/usr/bin/env node
// cost-curves.mjs -- the data of the cost-curves widget (public/widgets/cost-curves/).
//
// The question: what does an N-bit adder, multiplier, MAC or comparator cost on a Xilinx
// 7-series, and where does a t27 ternary spec land beside it at equal information?
// Every number on the page is from a run of this script; nothing is typed in:
//
//   1. the sweep is read from specs/widgets/cost-curves.t27 (K_WIDTHS, K_OPS, K_TRIT_COUNTS,
//      K_T27_SPECS) through the vendored compiler, so the spec says what is measured;
//   2. small Verilog modules are written for every binary op and width, a reference
//      balanced-ternary ripple adder for every trit count (checked exhaustively at 3 trits
//      under Icarus Verilog first), and the binary twins of the two t27 adder specs;
//   3. the listed t27 specs are compiled to Verilog by public/t27/t27_compiler.wasm, the same
//      file the site ships (the native t27c is not run on this machine: Railway-only rule);
//   4. every module is synthesised by yosys `synth_xilinx -family xc7 -flatten`, once with DSPs
//      allowed and once with `-nodsp`; `stat -json` is parsed for LUT1..LUT6, CARRY4, FD*,
//      DSP48E1, MUXF7/8. A module yosys refuses, or one that synthesises to nothing, is written
//      down as a finding, never skipped;
//   5. the XC7A200T capacity is read twice from real device data: prjxray-db's tilegrid.json
//      site counts, and nextpnr-xilinx's "Device utilisation" lines on the board's chipdb;
//   6. data.json is written beside the page, and then every K_ fact in the spec is re-checked
//      against it. A spec that disagrees with the data fails the run.
//
// Run (from apps/website):
//   node scripts/widget-data/cost-curves.mjs            synthesise, write data.json, check the spec
//   node scripts/widget-data/cost-curves.mjs --check    only re-check the spec against data.json
//   node scripts/widget-data/cost-curves.mjs --spec-lines   print the spec's fact lines from data.json
// Env: YOSYS, IVERILOG, VVP, NEXTPNR, PRJXRAY_DB, CHIPDB, JOBS override the defaults below.
import { execFileSync, spawn } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { cpus } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { constsOf, loadCompiler, sha256 } from '../agents-from-specs.mjs'
import { runSpecTests } from '../viewport-from-spec.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const WASM = 'public/t27/t27_compiler.wasm'
const SPEC = 'specs/widgets/cost-curves.t27'
const CORPUS = 'public/t27/files/specs'
const OUT_DIR = 'public/widgets/cost-curves'
const OUT_JSON = `${OUT_DIR}/data.json`
const WORK = '/tmp/widget-cost-curves'
const MAX_BYTES = 1024 * 1024
const pick = (env, path, name) => process.env[env] || (existsSync(path) ? path : name)
const YOSYS = pick('YOSYS', '/opt/homebrew/bin/yosys', 'yosys')
const IVERILOG = pick('IVERILOG', '/opt/homebrew/bin/iverilog', 'iverilog')
const VVP = pick('VVP', '/opt/homebrew/bin/vvp', 'vvp')
const NEXTPNR = pick('NEXTPNR', join(process.env.HOME, '.local/bin/nextpnr-xilinx'), 'nextpnr-xilinx')
const PRJXRAY_DB = process.env.PRJXRAY_DB || join(process.env.HOME, '.cache/openxc7/prjxray-db-ab1fc60/artix7')
const CHIPDB = process.env.CHIPDB || join(process.env.HOME, 'openxc7-src/chipdb/xc7a200tfbg676-1.bin')
const JOBS = Number(process.env.JOBS) || Math.max(2, Math.min(6, cpus().length - 2))
const SYNTH = 'synth_xilinx -family xc7 -flatten'

const fail = (m) => { console.error(`cost-curves: ${m}`); process.exit(1) }
const run = (cmd, args, cwd) => {
  try { return execFileSync(cmd, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024 }) } catch (e) { fail(`${cmd} ${args.join(' ')} failed:\n${e.stdout ?? ''}${e.stderr ?? ''}`) }
}
const firstLine = (s) => String(s).split('\n').map((l) => l.trim()).find(Boolean) ?? ''

// --- the spec: what to measure, and the facts it claims ------------------------------------------
async function readSpec() {
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const text = readFileSync(join(SITE, SPEC), 'utf8')
  const analysis = analyze(text)
  const consts = constsOf(analysis)
  const K = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
  for (const k of ['K_WIDTHS', 'K_OPS', 'K_TRIT_COUNTS', 'K_T27_SPECS', 'K_T27_OPS', 'K_T27_INFO_MILLIBITS', 'K_T27_TWINS', 'K_LOG2_3_MILLI']) if (!(k in K)) fail(`${SPEC} has no ${k}`)
  return { analyze, text, K, analysis }
}

// --- Verilog the script writes ---------------------------------------------------------------
// Binary ops are unsigned. The MAC's accumulator is 2W bits with a synchronous active-low reset
// (FDRE, the reset style the DSP48E1's own P register takes), so yosys may fold it into a DSP.
const binary = {
  add: (w) => ({ top: `add_${w}`, v: `module add_${w} (input wire [${w - 1}:0] a, input wire [${w - 1}:0] b, output wire [${w}:0] y);\n  assign y = a + b;\nendmodule\n` }),
  mul: (w) => ({ top: `mul_${w}`, v: `module mul_${w} (input wire [${w - 1}:0] a, input wire [${w - 1}:0] b, output wire [${2 * w - 1}:0] y);\n  assign y = a * b;\nendmodule\n` }),
  mac: (w) => ({ top: `mac_${w}`, v: `module mac_${w} (input wire clk, input wire rst_n, input wire en, input wire [${w - 1}:0] a, input wire [${w - 1}:0] b, output reg [${2 * w - 1}:0] acc);\n  always @(posedge clk) begin\n    if (!rst_n) acc <= 0;\n    else if (en) acc <= acc + a * b;\n  end\nendmodule\n` }),
  cmp: (w) => ({ top: `cmp_${w}`, v: `module cmp_${w} (input wire [${w - 1}:0] a, input wire [${w - 1}:0] b, output wire lt);\n  assign lt = a < b;\nendmodule\n` }),
}
// The binary twins of the two t27 adder specs: the same function in plain binary.
const twins = {
  fa1: { top: 'twin_fa1', bits: 1, v: 'module twin_fa1 (input wire a, input wire b, input wire cin, output wire [1:0] y);\n  assign y = a + b + cin;\nendmodule\n' },
  add2: { top: 'twin_add2', bits: 2, v: 'module twin_add2 (input wire [1:0] a, input wire [1:0] b, output wire [2:0] y);\n  assign y = a + b;\nendmodule\n' },
}
// A reference n-trit balanced-ternary ripple adder in the t27 trit code (N=2'b00, Z=2'b01,
// P=2'b10; 2'b11 is read as Z). n+1 result trits, the last one the carry. Written here, not
// generated from a t27 spec: no spec in the corpus is an n-trit adder.
const tadd = (n) => ({
  top: `tadd_${n}`,
  v: `module tadd_${n} (input wire [${2 * n - 1}:0] a, input wire [${2 * n - 1}:0] b, output reg [${2 * n + 1}:0] s);
  integer i;
  reg signed [3:0] va, vb, c, t;
  always @* begin
    c = 0;
    s = 0;
    for (i = 0; i < ${n}; i = i + 1) begin
      va = (a[2*i +: 2] == 2'b10) ? 4'sd1 : (a[2*i +: 2] == 2'b00) ? -4'sd1 : 4'sd0;
      vb = (b[2*i +: 2] == 2'b10) ? 4'sd1 : (b[2*i +: 2] == 2'b00) ? -4'sd1 : 4'sd0;
      t = va + vb + c;
      if (t > 4'sd1) begin t = t - 4'sd3; c = 4'sd1; end
      else if (t < -4'sd1) begin t = t + 4'sd3; c = -4'sd1; end
      else c = 4'sd0;
      s[2*i +: 2] = (t == 4'sd1) ? 2'b10 : (t == -4'sd1) ? 2'b00 : 2'b01;
    end
    s[2*${n} +: 2] = (c == 4'sd1) ? 2'b10 : (c == -4'sd1) ? 2'b00 : 2'b01;
  end
endmodule
`,
})

/** Exhaustive check of the reference adder at 3 trits: all 27 x 27 valid inputs. */
function checkTernaryAdder() {
  const n = 3
  const dir = join(WORK, 'tadd-check')
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, 'tadd.v'), tadd(n).v)
  writeFileSync(join(dir, 'tb.v'), `module tb; reg [5:0] a, b; wire [7:0] s; integer i, j;
  tadd_3 dut (.a(a), .b(b), .s(s));
  function [5:0] code(input integer k); integer q, d; begin code = 0; for (q = 0; q < 3; q = q + 1) begin d = (k / (3 ** q)) % 3; code[2*q +: 2] = d[1:0]; end end endfunction
  initial begin for (i = 0; i < 27; i = i + 1) for (j = 0; j < 27; j = j + 1) begin a = code(i); b = code(j); #1 $display("%0d %0d %0d", a, b, s); end $finish; end
endmodule
`)
  run(IVERILOG, ['-g2012', '-o', 'tb.vvp', 'tb.v', 'tadd.v'], dir)
  const out = run(VVP, ['-n', 'tb.vvp'], dir)
  const val = (code, trits) => { let v = 0; for (let q = trits - 1; q >= 0; q--) { const t = (code >> (2 * q)) & 3; v = v * 3 + (t === 2 ? 1 : t === 0 ? -1 : 0) } return v }
  let cases = 0
  for (const line of out.split('\n')) {
    const m = /^(\d+) (\d+) (\d+)$/.exec(line.trim())
    if (!m) continue
    cases++
    const [a, b, s] = m.slice(1).map(Number)
    if (val(a, n) + val(b, n) !== val(s, n + 1)) fail(`reference ternary adder is wrong: ${val(a, n)} + ${val(b, n)} gave ${val(s, n + 1)}`)
  }
  if (cases !== 729) fail(`reference ternary adder check ran ${cases} cases, expected 729`)
  return { trits: n, cases, all_pass: true, command: `iverilog -g2012 -o tb.vvp tb.v tadd.v && vvp -n tb.vvp   # in ${dir}` }
}

// --- yosys ----------------------------------------------------------------------------------
const CELL_KEYS = { lut: /^LUT[1-6]$/, ff: /^FD(RE|SE|CE|PE)$/, carry4: /^CARRY4$/, dsp: /^DSP48E1$/, muxf7: /^MUXF7$/, muxf8: /^MUXF8$/ }
export function metricsOf(cells) {
  const m = Object.fromEntries(Object.keys(CELL_KEYS).map((k) => [k, 0]))
  for (const [type, n] of Object.entries(cells)) for (const [k, re] of Object.entries(CELL_KEYS)) if (re.test(type)) m[k] += n
  return m
}

function synth(job) {
  const stat = `${job.id}.stat.json`
  const script = `read_verilog -sv ${job.file}; ${SYNTH} -top ${job.top}${job.dsp ? '' : ' -nodsp'}; tee -q -o ${stat} stat -json`
  const args = ['-q', '-l', `${job.id}.log`, '-p', script]
  return new Promise((resolve) => {
    const t0 = process.hrtime.bigint()
    const p = spawn(YOSYS, args, { cwd: WORK, stdio: ['ignore', 'pipe', 'pipe'] })
    let err = ''
    p.stdout.on('data', (d) => { err += d })
    p.stderr.on('data', (d) => { err += d })
    p.on('close', (code) => {
      const seconds = Math.round(Number(process.hrtime.bigint() - t0) / 1e6) / 1000
      const command = `yosys -q -l ${job.id}.log -p "${script}"`
      if (code !== 0 || !existsSync(join(WORK, stat))) {
        const why = err.split('\n').map((l) => l.trim()).filter((l) => /error/i.test(l)).slice(0, 3).join(' / ') || firstLine(err) || `exit ${code}`
        return resolve({ ...job, status: 'rejected', seconds, command, error: why.slice(0, 400) })
      }
      const d = JSON.parse(readFileSync(join(WORK, stat), 'utf8'))
      const cells = d.design?.num_cells_by_type ?? {}
      const metrics = metricsOf(cells)
      const logic = metrics.lut + metrics.ff + metrics.carry4 + metrics.dsp + metrics.muxf7 + metrics.muxf8
      resolve({ ...job, status: logic === 0 ? 'empty' : 'ok', seconds, command, cells, metrics })
    })
  })
}

async function pool(jobs, n) {
  const out = new Array(jobs.length)
  let next = 0
  const worker = async () => { while (next < jobs.length) { const i = next++; out[i] = await synth(jobs[i]); process.stdout.write(`  ${out[i].id.padEnd(34)} ${out[i].status.padEnd(8)} ${out[i].seconds}s\n`) } }
  await Promise.all(Array.from({ length: n }, worker))
  return out
}

// --- the device ------------------------------------------------------------------------------
function capacity() {
  const grid = join(PRJXRAY_DB, 'xc7a200t/tilegrid.json')
  const g = JSON.parse(readFileSync(grid, 'utf8'))
  const sites = {}
  for (const tile of Object.values(g)) for (const type of Object.values(tile.sites ?? {})) sites[type] = (sites[type] ?? 0) + 1
  const slices = (sites.SLICEL ?? 0) + (sites.SLICEM ?? 0)
  const prjxray = { file: grid.replace(process.env.HOME, '~'), sha256: sha256(readFileSync(grid)), SLICEL: sites.SLICEL, SLICEM: sites.SLICEM, DSP48E1: sites.DSP48E1, slices }

  // nextpnr-xilinx prints the bel counts of the chipdb after packing; a one-gate design is enough.
  const dir = join(WORK, 'capacity')
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, 'tiny.v'), 'module tiny (input wire a, input wire b, output wire y);\n  assign y = a & b;\nendmodule\n')
  writeFileSync(join(dir, 'tiny.xdc'), ['a', 'b', 'y'].flatMap((p, i) => [`set_property PACKAGE_PIN ${['A3', 'A4', 'A5'][i]} [get_ports ${p}]`, `set_property IOSTANDARD LVCMOS33 [get_ports ${p}]`]).join('\n') + '\n')
  run(YOSYS, ['-q', '-p', `read_verilog tiny.v; ${SYNTH} -top tiny; write_json tiny.json`], dir)
  const pnrArgs = ['--chipdb', CHIPDB, '--json', 'tiny.json', '--xdc', 'tiny.xdc', '--pack-only']
  // nextpnr logs on stderr, so both streams are read together.
  const log = execFileSync('/bin/sh', ['-c', `"${NEXTPNR}" ${pnrArgs.map((a) => `'${a}'`).join(' ')} 2>&1 || true`], { cwd: dir, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 })
  const bel = (name) => { const m = new RegExp(`\\b${name}:\\s*\\d+/\\s*(\\d+)`).exec(log); if (!m) fail(`nextpnr-xilinx printed no ${name} line`); return Number(m[1]) }
  const nextpnr = {
    chipdb: CHIPDB.replace(process.env.HOME, '~'),
    chipdb_sha256: sha256(readFileSync(CHIPDB)),
    version: ((v) => /Version ([^)\s]+)/.exec(v)?.[1] ?? firstLine(v))(execFileSync('/bin/sh', ['-c', `"${NEXTPNR}" --version 2>&1 || true`], { encoding: 'utf8' })),
    command: `nextpnr-xilinx ${pnrArgs.join(' ')}   # in ${dir}`,
    SLICE_LUTX: bel('SLICE_LUTX'), SLICE_FFX: bel('SLICE_FFX'), CARRY4: bel('CARRY4'), DSP48E1: bel('DSP48E1'),
  }
  // A 7-series slice has four LUT6 sites, eight flip-flops and one CARRY4. nextpnr-xilinx
  // models each LUT6 site as two bels (the 6-input LUT and its 5-input half), so SLICE_LUTX is
  // twice the LUT6 count. The two sources must agree or the run stops.
  const cap = { lut: 4 * slices, ff: 8 * slices, carry4: slices, dsp: prjxray.DSP48E1 }
  if (nextpnr.SLICE_LUTX !== 2 * cap.lut) fail(`nextpnr SLICE_LUTX ${nextpnr.SLICE_LUTX} is not 2 x ${cap.lut} LUT6 from prjxray-db`)
  if (nextpnr.SLICE_FFX !== cap.ff) fail(`nextpnr SLICE_FFX ${nextpnr.SLICE_FFX} != ${cap.ff} from prjxray-db`)
  if (nextpnr.CARRY4 !== cap.carry4) fail(`nextpnr CARRY4 ${nextpnr.CARRY4} != ${cap.carry4} from prjxray-db`)
  if (nextpnr.DSP48E1 !== cap.dsp) fail(`nextpnr DSP48E1 ${nextpnr.DSP48E1} != ${cap.dsp} from prjxray-db`)
  return { device: 'XC7A200T', ...cap, slices, prjxray, nextpnr }
}

// --- the spec's facts, re-checked against the data -------------------------------------------
const find = (data, f) => data.results.find((r) => Object.entries(f).every(([k, v]) => r[k] === v))
const metricRow = (data, family, op, dsp, key, xs, xkey) => xs.map((x) => { const r = find(data, { family, op, dsp, [xkey]: x }); return r?.status === 'ok' ? r.metrics[key] : null })

/** The facts the spec states as K_ constants, computed from data.json. */
export function factsOf(data, K) {
  const W = K.K_WIDTHS
  const mul = find(data, { family: 'binary', op: 'mul', dsp: false, width: W[W.length - 1] })
  const t27 = (stem) => data.results.find((r) => r.family === 't27' && r.spec.endsWith(stem) && r.dsp === false)
  const stream = t27('stream_ternary_mac.t27')
  return {
    K_ADD_LUTS: metricRow(data, 'binary', 'add', false, 'lut', W, 'width'),
    K_ADD_CARRY4: metricRow(data, 'binary', 'add', false, 'carry4', W, 'width'),
    K_TADD_LUTS: metricRow(data, 'ternary-ref', 'add', false, 'lut', K.K_TRIT_COUNTS, 'trits'),
    K_MUL_NODSP_LUTS: metricRow(data, 'binary', 'mul', false, 'lut', W, 'width'),
    K_MUL_DSP48: metricRow(data, 'binary', 'mul', true, 'dsp', W, 'width'),
    K_MAC_DSP48: metricRow(data, 'binary', 'mac', true, 'dsp', W, 'width'),
    K_HOOK_LUTS: mul?.metrics.lut ?? null,
    K_HOOK_BASIS_POINTS: mul ? Math.trunc((mul.metrics.lut * 10000) / data.capacity.lut) : null,
    K_T27_FA_LUTS: t27('ternary_full_adder.t27')?.metrics?.lut ?? null,
    K_TWIN_FA1_LUTS: find(data, { family: 'twin', twin: 'fa1', dsp: false })?.metrics?.lut ?? null,
    K_T27_RIPPLE_LUTS: t27('ternary_ripple_adder.t27')?.metrics?.lut ?? null,
    K_TWIN_ADD2_LUTS: find(data, { family: 'twin', twin: 'add2', dsp: false })?.metrics?.lut ?? null,
    K_COMB_DOT_LUTS: t27('comb_ternary_dot.t27')?.metrics?.lut ?? null,
    K_STREAM_MAC_LUTS: stream?.metrics?.lut ?? null,
    K_STREAM_MAC_FFS: stream?.metrics?.ff ?? null,
    K_STREAM_MAC_DSP48: find(data, { family: 't27', spec: stream?.spec, dsp: true })?.metrics?.dsp ?? null,
    K_CAP_SLICES: data.capacity.slices,
    K_CAP_LUT6: data.capacity.lut,
    K_CAP_FF: data.capacity.ff,
    K_CAP_CARRY4: data.capacity.carry4,
    K_CAP_DSP: data.capacity.dsp,
    K_CAP_LUT_BELS: data.capacity.nextpnr.SLICE_LUTX,
    K_REJECTED: data.results.filter((r) => r.status === 'rejected').length,
    K_EMPTY: data.results.filter((r) => r.status === 'empty').length,
  }
}

const typeOf = (k, v) => (Array.isArray(v) ? `[${v.length}]${v.every((x) => x <= 65535) ? 'u16' : 'u32'}` : v <= 65535 ? 'u16' : 'u32')
const specLine = (k, v) => `pub const ${k} : ${typeOf(k, v)} = ${Array.isArray(v) ? `[${v.join(', ')}]` : v};`

function checkSpec(data, K, analysis) {
  const facts = factsOf(data, K)
  const bad = []
  // The spec's own test blocks, evaluated with every fact taken from data.json instead of the
  // spec: a test that holds of the spec but not of the run fails here.
  const tests = runSpecTests(analysis, { ...K, ...Object.fromEntries(Object.entries(facts).filter(([, v]) => v !== null && !(Array.isArray(v) && v.includes(null)))) })
  for (const f of tests.failures) bad.push(`spec test on data.json: ${f}`)
  if (tests.asserts === 0) bad.push('the spec has no asserts to run against the data')
  for (const [k, v] of Object.entries(facts)) {
    if (v === null || (Array.isArray(v) && v.includes(null))) { bad.push(`${k}: the data has no value for it`); continue }
    if (!(k in K)) bad.push(`${k}: missing from the spec; it should read  ${specLine(k, v)}`)
    else if (JSON.stringify(K[k]) !== JSON.stringify(v)) bad.push(`${k}: spec says ${JSON.stringify(K[k])}, data.json says ${JSON.stringify(v)}`)
  }
  // Claims that are about the data rather than equal to it.
  const mono = (xs) => xs.every((x, i) => i === 0 || x > xs[i - 1])
  if (!mono(facts.K_ADD_LUTS)) bad.push('the add LUT count is not strictly increasing in width')
  if (!mono(facts.K_MUL_NODSP_LUTS)) bad.push('the -nodsp multiply LUT count is not strictly increasing in width')
  // The budget is wall-clock: the yosys seconds summed over parallel jobs grow when the machine is
  // shared, and both numbers are in data.json.
  if (data.timing.wall_seconds > K.K_SYNTH_BUDGET_S) bad.push(`synthesis took ${data.timing.wall_seconds}s of wall clock, over the ${K.K_SYNTH_BUDGET_S}s budget`)
  return { facts, bad }
}

// --- main ------------------------------------------------------------------------------------
async function main() {
  const { analyze, text, K, analysis } = await readSpec()
  const outPath = join(SITE, OUT_JSON)
  if (process.argv.includes('--check') || process.argv.includes('--spec-lines')) {
    if (!existsSync(outPath)) fail(`${OUT_JSON} does not exist; run without --check first`)
    const data = JSON.parse(readFileSync(outPath, 'utf8'))
    if (process.argv.includes('--spec-lines')) { for (const [k, v] of Object.entries(factsOf(data, K))) console.log(specLine(k, v)); return }
    const { bad } = checkSpec(data, K, analysis)
    if (bad.length) { console.error(`cost-curves --check: ${bad.length} fact(s) disagree with ${OUT_JSON}`); for (const b of bad) console.error('  ' + b); process.exit(3) }
    console.log(`cost-curves --check: every K_ fact in ${SPEC} matches ${OUT_JSON}, and its tests hold of the data`)
    return
  }

  rmSync(WORK, { recursive: true, force: true })
  mkdirSync(WORK, { recursive: true })
  const wasm = readFileSync(join(SITE, WASM))
  const jobs = []
  const add = (j) => { writeFileSync(join(WORK, j.file), j.v); for (const dsp of [true, false]) jobs.push({ ...j, v: undefined, id: `${j.top}${dsp ? '' : '_nodsp'}`, dsp }) }
  const log2_3 = Math.log2(3)

  for (const op of K.K_OPS) {
    if (!binary[op]) fail(`${SPEC}: K_OPS names ${op}, which this script cannot write`)
    for (const w of K.K_WIDTHS) { const m = binary[op](w); add({ family: 'binary', op, width: w, info_bits: w, top: m.top, file: `${m.top}.v`, v: m.v }) }
  }
  for (const n of K.K_TRIT_COUNTS) { const m = tadd(n); add({ family: 'ternary-ref', op: 'add', trits: n, info_bits: Math.round(n * log2_3 * 1000) / 1000, top: m.top, file: `${m.top}.v`, v: m.v }) }
  const adderCheck = checkTernaryAdder()

  const specs = []
  K.K_T27_SPECS.forEach((rel, i) => {
    const src = readFileSync(join(SITE, CORPUS, rel), 'utf8')
    const a = analyze(src)
    const v = a.targets?.verilog
    const stem = rel.split('/').pop().replace(/\.t27$/, '')
    const top = /^module (\w+)\s*\(/m.exec(v?.code ?? '')?.[1]
    // The module header only: from `module X (` to the first `);`. Function inputs are not ports.
    const header = /^module \w+\s*\(([\s\S]*?)\);/m.exec(v?.code ?? '')?.[1] ?? ''
    const ports = header.split('\n').filter((l) => /^\s*(input|output)\b/.test(l)).map((l) => l.trim().replace(/,$/, ''))
    const entry = { spec: `specs/${rel}`, sha256: sha256(Buffer.from(src, 'utf8')), op: K.K_T27_OPS[i], info_bits: K.K_T27_INFO_MILLIBITS[i] / 1000, twin: K.K_T27_TWINS[i] === 'none' ? null : K.K_T27_TWINS[i], top: top ?? null, ports, generated: Boolean(v?.ok && v.code && top) }
    if (entry.generated) entry.verilog_sha256 = sha256(Buffer.from(v.code, 'utf8'))
    specs.push(entry)
    if (!entry.generated) return
    const file = `t27_${stem}.v`
    add({ family: 't27', op: entry.op, spec: entry.spec, info_bits: entry.info_bits, ...(K.K_T27_TRITS?.[i] ? { trits: K.K_T27_TRITS[i] } : {}), twin: entry.twin, top, file, v: v.code })
  })
  for (const [key, t] of Object.entries(twins)) add({ family: 'twin', op: 'add', twin: key, width: t.bits, info_bits: t.bits, top: t.top, file: `${t.top}.v`, v: t.v })

  console.log(`cost-curves: ${jobs.length} yosys runs, ${JOBS} at a time, in ${WORK}`)
  const t0 = Date.now()
  const results = await pool(jobs, JOBS)
  const wall = Math.round((Date.now() - t0) / 100) / 10
  const sum = Math.round(results.reduce((s, r) => s + r.seconds, 0) * 10) / 10

  const findings = []
  const CONTROL = /\b(clk|rst_n|en|ready)$/
  for (const s of specs) {
    if (!s.generated) findings.push({ kind: 'not-generated', spec: s.spec, detail: 'the wasm compiler produced no Verilog module for it' })
    else if (!s.ports.some((p) => !CONTROL.test(p))) findings.push({ kind: 'no-data-ports', spec: s.spec, detail: `the generated module ${s.top} has only clk, rst_n, en and ready: no value can cross its boundary, so even when it parses it synthesises to nothing`, ports: s.ports })
  }
  for (const r of results) {
    if (r.status === 'rejected') {
      // Quote the source line yosys stopped at, so the finding can be checked without a rerun.
      const at = /^([\w.]+):(\d+):/.exec(r.error ?? '')
      const line = at && existsSync(join(WORK, at[1])) ? readFileSync(join(WORK, at[1]), 'utf8').split('\n')[Number(at[2]) - 1]?.trim() : null
      findings.push({ kind: 'rejected', id: r.id, spec: r.spec ?? null, detail: r.error, line })
    }
    if (r.status === 'empty') {
      findings.push({ kind: 'empty', id: r.id, spec: r.spec ?? null, detail: 'synthesised to no logic cells' })
    }
  }

  const cap = capacity()
  const versions = {
    yosys: firstLine(run(YOSYS, ['-V'])),
    iverilog: firstLine(execFileSync('/bin/sh', ['-c', `"${IVERILOG}" -V 2>&1 || true`], { encoding: 'utf8' })),
    node: process.version,
  }
  const data = {
    generated_at: new Date().toISOString().replace(/\.\d+Z$/, 'Z'),
    spec: { path: `apps/website/${SPEC}`, sha256: sha256(Buffer.from(text, 'utf8')) },
    compiler: { path: WASM.replace(/^public\//, ''), sha256: sha256(wasm), target: 'verilog' },
    tools: versions,
    synth: SYNTH,
    commands: [
      'node scripts/widget-data/cost-curves.mjs',
      `cd ${WORK}`,
      ...results.map((r) => r.command),
      adderCheck.command,
      cap.nextpnr.command,
    ],
    sweep: { widths: K.K_WIDTHS, ops: K.K_OPS, trit_counts: K.K_TRIT_COUNTS, log2_3: log2_3 },
    adder_check: adderCheck,
    specs,
    capacity: cap,
    timing: { jobs: JOBS, runs: results.length, sum_seconds: sum, wall_seconds: wall },
    results: results.map(({ v, file, ...r }) => ({ ...r, file })),
    findings,
  }
  mkdirSync(join(SITE, OUT_DIR), { recursive: true })
  // The home directory is written as ~ so the file names no user.
  writeFileSync(outPath, JSON.stringify(data, null, 1).replaceAll(process.env.HOME, '~') + '\n')
  if (statSync(outPath).size > MAX_BYTES) fail(`${OUT_JSON} is over ${MAX_BYTES} bytes`)
  console.log(`cost-curves: ${results.length} runs in ${wall}s wall (${sum}s of yosys); ${findings.length} finding(s); wrote ${OUT_JSON} (${statSync(outPath).size} bytes)`)

  const { bad } = checkSpec(data, K, analysis)
  if (bad.length) {
    console.error(`cost-curves: ${bad.length} fact(s) in ${SPEC} disagree with the run; the spec's lines from this run:`)
    for (const b of bad) console.error('  ' + b)
    process.exit(3)
  }
  console.log(`cost-curves: every K_ fact in ${SPEC} matches the run, and its tests hold of the data`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) await main()
