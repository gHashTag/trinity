#!/usr/bin/env node
// t27c-stages.mjs -- the receipt behind the t27c-stages widget's card and hook.
//
// The widget (public/widgets/t27c-stages/) computes everything it shows in the reader's tab with
// public/t27/t27_compiler.wasm. Only the card and the hook state numbers ahead of time, so this
// script makes them real:
//
//   1. reads specs/widgets/t27c-stages.t27 through the same wasm (the native t27c is not run on
//      this machine: Railway-only rule) and takes SAY_EXAMPLE_SOURCES and the K_EXAMPLE_ numbers;
//   2. runs t27_analyze on every example and keeps what each stage answered: bytes, lines, tokens,
//      nodes, depth, the type check, the HIR's line and port counts, every backend's bytes, and
//      what the lexer and parser dropped;
//   3. checks the spec against that: every K_EXAMPLE_ number equals the answer for example 0, the
//      HOOK and IMAGE_ALT quote those same numbers, example 0's Verilog has the data ports a, b
//      and result, and examples 1-3 show what their names promise (a type error, a byte the lexer
//      threw away, tokens the parser skipped);
//   4. writes public/widgets/t27c-stages/examples.json, from which t27c-stages-card.py draws.
//
// A negative control runs first: the same checks against example 0 with one token count off by
// one must fail, so a check that cannot fail is caught.
//
// Run (from apps/website):  node scripts/widget-data/t27c-stages.mjs [--check]
import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, constsOf, loadCompiler, sha256 } from '../agents-from-specs.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
const SPEC = 'specs/widgets/t27c-stages.t27'
const OUT = 'public/widgets/t27c-stages/examples.json'
const checkOnly = process.argv.includes('--check')

const wasm = readFileSync(join(SITE, WASM))
const analyze = await loadCompiler(wasm)
const specText = readFileSync(join(SITE, SPEC), 'utf8')
const K = Object.fromEntries(Object.entries(constsOf(analyze(specText))).map(([k, v]) => [k, v.value]))

function summary(name, source) {
  const r = analyze(source)
  const targets = {}
  for (const id of K.SAY_TARGET_IDS) {
    const t = r.targets?.[id] ?? {}
    targets[id] = { ok: !!t.ok, bytes: t.bytes ?? 0, notEmitted: t.notEmitted ?? null, error: t.ok ? null : (t.error ?? null) }
  }
  const hirText = r.hir?.ok ? r.hir.text : ''
  return {
    name,
    sourceBytes: r.sourceBytes,
    sourceLines: r.sourceLines,
    tokenCount: r.tokenCount,
    tokenKinds: [...new Set((r.tokens ?? []).map((t) => t.kind))].length,
    tokens: (r.tokens ?? []).map((t) => [t.lexeme, t.kind, t.line, t.col]),
    nodeCount: r.nodeCount ?? null,
    astDepth: r.astDepth ?? null,
    topLevel: r.topLevel ?? null,
    astError: r.astError ?? null,
    typecheck: r.typecheck,
    hir: { ok: !!r.hir?.ok, lines: hirText ? hirText.split('\n').length : 0, ports: (hirText.match(/HirPort \{/g) ?? []).length, error: r.hir?.ok ? null : (r.hir?.error ?? null) },
    targets,
    targetsOk: Object.values(targets).filter((t) => t.ok).length,
    targetBytes: Object.values(targets).reduce((s, t) => s + t.bytes, 0),
    verilog: r.targets?.verilog?.code ?? '',
    lexerDiscarded: r.lexerDiscarded ?? [],
    swallowed: r.swallowed ?? [],
    discarded: r.discarded ?? [],
  }
}

const fmt = (n) => Number(n).toLocaleString('en-US')
function problemsOf(ex, k) {
  const p = []
  const [e0, e1, e2, e3] = ex
  const want = [['K_EXAMPLE_LINES', e0.sourceLines], ['K_EXAMPLE_BYTES', e0.sourceBytes], ['K_EXAMPLE_TOKENS', e0.tokenCount], ['K_EXAMPLE_NODES', e0.nodeCount], ['K_EXAMPLE_DEPTH', e0.astDepth], ['K_EXAMPLE_TARGETS_OK', e0.targetsOk], ['K_EXAMPLE_TARGET_BYTES', e0.targetBytes]]
  for (const [name, got] of want) if (k[name] !== got) p.push(`${name} is ${k[name]} in the spec, the compiler says ${got}`)
  if (k.K_TARGETS !== k.SAY_TARGET_IDS.length) p.push(`K_TARGETS ${k.K_TARGETS} != ${k.SAY_TARGET_IDS.length} SAY_TARGET_IDS`)
  for (const s of [`${e0.sourceLines} lines`, `${e0.tokenCount} tokens`, `${e0.nodeCount}-node`, `${e0.targetsOk} languages`]) if (!k.HOOK.includes(s)) p.push(`HOOK does not say "${s}"`)
  if (!k.SAY_CARD_TARGETS.includes(`${e0.sourceLines} lines`)) p.push(`SAY_CARD_TARGETS does not say "${e0.sourceLines} lines"`)
  for (const s of [`${e0.sourceLines}-line`, `${e0.sourceBytes} bytes`, `${e0.tokenCount} tokens`, `${e0.nodeCount} nodes`, `${e0.astDepth} levels`, `${e0.hir.lines}-line HIR`, `${e0.targetsOk} backends`, `${fmt(e0.targetBytes)} bytes`]) if (!k.IMAGE_ALT.includes(s)) p.push(`IMAGE_ALT does not say "${s}"`)
  if (!e0.typecheck?.ok || e0.typecheck.errors.length) p.push('example 0 does not type-check clean')
  if (e0.lexerDiscarded.length + e0.swallowed.length + e0.discarded.length) p.push('example 0 has dropped text')
  for (const port of [/input\s+wire\s+\[7:0\]\s+a,/, /input\s+wire\s+\[7:0\]\s+b,/, /output\s+wire\s+\[7:0\]\s+result/, /assign result = on_comb\(a, b\);/]) if (!port.test(e0.verilog)) p.push(`example 0's Verilog lacks ${port}`)
  if (e1.typecheck?.ok !== false || !(e1.typecheck.errorCount > 0)) p.push('example 1 (a value too big) has no type error')
  if (e1.targetsOk === 0) p.push('example 1: no backend wrote code, so SAY_TC_NOT_A_GATE would be false')
  if (!e2.lexerDiscarded.some((d) => d.char === '$')) p.push('example 2 (a stray character): the lexer did not drop $')
  if (!e3.swallowed.length) p.push('example 3 (junk after a value): the parser skipped nothing')
  return p
}

const examples = K.SAY_EXAMPLE_SOURCES.map((src, i) => summary(K.SAY_EXAMPLE_NAMES[i], src))

// Negative control: one number wrong must be caught.
const control = problemsOf(examples, { ...K, K_EXAMPLE_TOKENS: K.K_EXAMPLE_TOKENS + 1 })
if (!control.some((m) => m.startsWith('K_EXAMPLE_TOKENS'))) { console.error('negative control passed: the checks cannot fail'); process.exit(2) }

const problems = problemsOf(examples, K)
for (const e of examples) console.log(`${e.name}: ${e.sourceBytes} B, ${e.sourceLines} lines, ${e.tokenCount} tokens, ${e.nodeCount} nodes, depth ${e.astDepth}, typecheck ${e.typecheck?.ok ? 'ok' : 'fail'} (${(e.typecheck?.errors ?? []).length} msgs), HIR ${e.hir.lines} lines/${e.hir.ports} ports, ${e.targetsOk}/7 targets ${e.targetBytes} B, dropped L${e.lexerDiscarded.length} S${e.swallowed.length} D${e.discarded.length}`)
if (problems.length) { for (const m of problems) console.error(`PROBLEM ${m}`); process.exit(1) }

if (!checkOnly) {
  const doc = {
    generatedBy: 'scripts/widget-data/t27c-stages.mjs',
    node: process.version,
    compiler: { file: WASM, bytes: wasm.length, sha256: sha256(wasm) },
    spec: { file: SPEC, sha256: sha256(Buffer.from(specText, 'utf8')) },
    examples: examples.map(({ verilog, ...e }) => ({ ...e, verilogHead: verilog.split('\n').filter((l) => /^\s*(module|input|output)\b/.test(l)).slice(0, 8) })),
  }
  writeFileSync(join(SITE, OUT), JSON.stringify(doc, null, 1) + '\n')
  console.log(`wrote ${OUT}`)
}
console.log('ok: spec numbers equal the compiler\'s answers; negative control caught')
