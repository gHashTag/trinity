#!/usr/bin/env node
// test-waves.mjs -- the demo data of the test-waves widget (public/widgets/test-waves/).
//
// One real simulation, nothing invented:
//   1. compile public/t27/files/specs/ternary/stream_ternary_mac.t27 with the vendored compiler
//      (public/t27/t27_compiler.wasm, the same file the X player runs) and take its `verilog`
//      target: module StreamTernaryMac, a clocked ternary multiply-accumulate;
//   2. read the test vectors from the spec's own `test` blocks, assert_eq(dot27(a, b), d);
//   3. simulate the generated module with scripts/widget-data/test-waves-tb.v under Icarus
//      Verilog in /tmp/widget-waves (iverilog, then vvp);
//   4. ship the VCD it dumped and a JSON beside it: provenance (spec and compiler sha256, tool
//      versions, the exact commands), the role of every signal and the pass/fail of every check.
//
// The native t27c is not built or run: the owner's rule is that t27c runs on the Railway lab, not
// on this machine; the WebAssembly compiler in node is the same front end the site ships.
//
// Run (from apps/website):  node scripts/widget-data/test-waves.mjs
// Needs iverilog and vvp on PATH, or IVERILOG / VVP set to their paths.
import { execFileSync, spawnSync } from 'node:child_process'
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadCompiler, sha256 } from '../agents-from-specs.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const WASM = 'public/t27/t27_compiler.wasm'
const SPEC = 'public/t27/files/specs/ternary/stream_ternary_mac.t27'
const SPEC_NAME = 'specs/ternary/stream_ternary_mac.t27'
const TOP = 'StreamTernaryMac'
const TB = 'scripts/widget-data/test-waves-tb.v'
const WORK = '/tmp/widget-waves'
const OUT_DIR = 'public/widgets/test-waves'
const OUT_VCD = `${OUT_DIR}/demo.vcd`
const OUT_JSON = `${OUT_DIR}/demo.json`
const MAX_BYTES = 1024 * 1024
const IVERILOG = process.env.IVERILOG || (existsSync('/opt/homebrew/bin/iverilog') ? '/opt/homebrew/bin/iverilog' : 'iverilog')
const VVP = process.env.VVP || (existsSync('/opt/homebrew/bin/vvp') ? '/opt/homebrew/bin/vvp' : 'vvp')
// Signal roles, in the order the widget draws them. Names are the VCD's own (scope tb).
// acc is `output reg signed [31:0]` in the generated module and expected is signed in the
// testbench, so both are drawn as signed decimal; the 54-trit buses a and b stay hex.
const ROLES = [['clk', 'clock'], ['rst_n', 'in'], ['en', 'in'], ['a', 'in'], ['b', 'in'], ['acc', 'out', 'sdec'], ['expected', 'tb', 'sdec'], ['ready', 'out']]
const EXTRA_CHECKS = { 100: 'en_low_holds_acc', 101: 'reset_clears_acc' }

const fail = (m) => { console.error(`test-waves: ${m}`); process.exit(1) }
const hex = (big, bits) => (BigInt.asUintN(bits, big)).toString(16).padStart(bits / 4, '0')

/** The spec's test vectors: every `test` block must be one assert_eq(dot27(a, b), d). */
export function specVectors(src) {
  const blocks = [...src.matchAll(/^\s*test\s+(\w+)\s*\{([^}]*)\}/gm)]
  const total = (src.match(/^\s*test\s+\w+/gm) ?? []).length
  if (!blocks.length || blocks.length !== total) fail(`${SPEC_NAME}: ${total} test blocks, ${blocks.length} readable`)
  return blocks.map(([, name, body]) => {
    const m = /^\s*assert_eq\(\s*dot27\(\s*(\d+)\s*,\s*(\d+)\s*\)\s*,\s*(-?\d+)\s*\)\s*;\s*$/.exec(body)
    if (!m) fail(`${SPEC_NAME}: test ${name} is not assert_eq(dot27(a, b), d): ${body.trim()}`)
    return { name, a: BigInt(m[1]), b: BigInt(m[2]), d: BigInt(m[3]) }
  })
}

/** Seconds per VCD time unit, from its $timescale. */
export function timescaleSeconds(vcd) {
  const m = /\$timescale\s+(\d+)\s*(s|ms|us|ns|ps|fs)\s+\$end/.exec(vcd)
  if (!m) fail('the VCD has no $timescale')
  return Number(m[1]) * { s: 1, ms: 1e-3, us: 1e-6, ns: 1e-9, ps: 1e-12, fs: 1e-15 }[m[2]]
}

const run = (cmd, args, cwd) => {
  try { return execFileSync(cmd, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }) } catch (e) { fail(`${cmd} ${args.join(' ')} failed:\n${e.stdout ?? ''}${e.stderr ?? ''}`) }
}

async function main() {
  const wasm = readFileSync(join(SITE, WASM))
  const src = readFileSync(join(SITE, SPEC), 'utf8')
  const analyze = await loadCompiler(wasm)
  const analysis = analyze(src)
  const v = analysis.targets?.verilog
  if (!v?.ok || !v.code) fail(`${SPEC_NAME}: the verilog target did not generate`)
  if (!new RegExp(`^module ${TOP} \\(`, 'm').test(v.code)) fail(`${SPEC_NAME}: generated Verilog has no module ${TOP}`)
  if (/\bcast\(/.test(v.code)) fail(`${SPEC_NAME}: generated Verilog calls an undeclared cast() (t27#6100)`)
  const vectors = specVectors(src)
  if (vectors[0].d === 0n) fail('the first spec vector has a zero dot product; the en-low check needs a non-zero one')

  rmSync(WORK, { recursive: true, force: true })
  mkdirSync(WORK, { recursive: true })
  const vFile = 'stream_ternary_mac.v'
  writeFileSync(join(WORK, vFile), v.code)
  copyFileSync(join(SITE, TB), join(WORK, 'test-waves-tb.v'))
  writeFileSync(join(WORK, 'vectors_a.hex'), vectors.map((x) => hex(x.a, 64)).join('\n') + '\n')
  writeFileSync(join(WORK, 'vectors_b.hex'), vectors.map((x) => hex(x.b, 64)).join('\n') + '\n')
  writeFileSync(join(WORK, 'vectors_d.hex'), vectors.map((x) => hex(x.d, 32)).join('\n') + '\n')

  const compileArgs = ['-g2012', '-Wall', '-s', 'tb', '-o', 'sim.vvp', 'test-waves-tb.v', vFile]
  const simArgs = ['-n', 'sim.vvp', `+N=${vectors.length}`]
  run(IVERILOG, compileArgs, WORK)
  const stdout = run(VVP, simArgs, WORK)
  writeFileSync(join(WORK, 'vvp.log'), stdout)
  const vcd = readFileSync(join(WORK, 'waves.vcd'), 'utf8')
  const unit = timescaleSeconds(vcd)

  const checks = []
  for (const line of stdout.split('\n')) {
    const m = /^CHECK (\d+) (\d+) (pass|fail) (-?\d+) (-?\d+)$/.exec(line.trim())
    if (!m) continue
    const id = Number(m[2])
    const spec = id < vectors.length
    const name = spec ? vectors[id].name : EXTRA_CHECKS[id]
    if (!name) fail(`vvp printed a check with unknown id ${id}`)
    // $time in the testbench counts nanoseconds (`timescale 1ns); the VCD counts `unit` seconds.
    checks.push({ t: Math.round((Number(m[1]) * 1e-9) / unit), name, source: spec ? 'spec' : 'testbench', pass: m[3] === 'pass', acc: Number(m[4]), expected: Number(m[5]) })
  }
  const done = /DONE errors=(\d+)/.exec(stdout)
  if (!done) fail(`vvp did not finish:\n${stdout}`)
  if (checks.length !== vectors.length + Object.keys(EXTRA_CHECKS).length) fail(`expected ${vectors.length + 2} checks, vvp printed ${checks.length}`)
  if (Number(done[1]) !== checks.filter((c) => !c.pass).length) fail('the testbench error count disagrees with its CHECK lines')

  // vvp -V prints its banner on stderr; either stream is read.
  const version = (cmd) => { const r = spawnSync(cmd, ['-V'], { encoding: 'utf8' }); return `${r.stdout ?? ''}${r.stderr ?? ''}`.split('\n').map((l) => l.trim()).find(Boolean) ?? fail(`${cmd} -V printed nothing`) }
  const ivVersion = version(IVERILOG)
  const vvpVersion = version(VVP)
  const demo = {
    spec: { path: SPEC_NAME, sha256: sha256(Buffer.from(src, 'utf8')), module: TOP },
    compiler: { path: WASM.replace(/^public\//, ''), sha256: sha256(wasm), target: 'verilog' },
    verilog_sha256: sha256(Buffer.from(v.code, 'utf8')),
    testbench: { path: `apps/website/${TB}`, sha256: sha256(readFileSync(join(SITE, TB))) },
    tools: { iverilog: ivVersion, vvp: vvpVersion },
    commands: [
      `node scripts/widget-data/test-waves.mjs   # wasm gen-verilog -> ${WORK}/${vFile}`,
      `cd ${WORK}`,
      `iverilog ${compileArgs.join(' ')}`,
      `vvp ${simArgs.join(' ')}`,
    ],
    vectors: vectors.map((x) => ({ test: x.name, a: '0x' + hex(x.a, 64), b: '0x' + hex(x.b, 64), dot: Number(x.d) })),
    signals: ROLES.map(([name, role, radix]) => ({ name: `tb.${name}`, role, radix: radix ?? 'hex' })),
    checks,
    summary: { pass: checks.filter((c) => c.pass).length, total: checks.length, spec_pass: checks.filter((c) => c.pass && c.source === 'spec').length, spec_total: vectors.length },
  }
  mkdirSync(join(SITE, OUT_DIR), { recursive: true })
  writeFileSync(join(SITE, OUT_VCD), vcd)
  writeFileSync(join(SITE, OUT_JSON), JSON.stringify(demo, null, 1) + '\n')
  for (const f of [OUT_VCD, OUT_JSON]) if (statSync(join(SITE, f)).size > MAX_BYTES) fail(`${f} is over ${MAX_BYTES} bytes`)
  console.log(`test-waves: ${SPEC_NAME} -> ${TOP}; ${demo.summary.pass}/${demo.summary.total} checks pass (${demo.summary.spec_pass}/${demo.summary.spec_total} spec tests); ${relative(SITE, join(SITE, OUT_VCD))} ${statSync(join(SITE, OUT_VCD)).size} bytes`)
  if (demo.summary.pass !== demo.summary.total) process.exitCode = 2
}

await main()
