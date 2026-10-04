// What the X player gate refuses, and what the player reads out of the compiler's Verilog.
//
// play-from-spec.mjs writes the player card pages only when specs/x/player.t27 compiles, its
// constants fit X's rules and its own test blocks hold. These tests hold that gate to its word
// (a clean spec writes exactly the committed files; an animation over X's limit, a title X would
// cut, a tab with no pane, a non-https origin are each refused), hold the site bundle to the site
// source it is built from, and hold public/play/rtl.js -- the RTL tab -- to what t27c emitted for
// hello_world and to the cases that once fooled it.
//
//   node --test scripts/play-from-spec.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { SITE, loadCompiler } from './agents-from-specs.mjs'
import { PLAYER_SPEC, SITE_BUNDLE_OUT, buildPlay, imageOf, playerBuild, renderSiteBundle } from './play-from-spec.mjs'
import { readRtl } from '../public/play/rtl.js'
import { COMMANDS, dispatch, factsOf, fill, makeShell } from '../public/play/shell.js'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const spec = readFileSync(join(SITE, PLAYER_SPEC), 'utf8')
const edit = (from, to) => {
  assert.ok(spec.includes(from), `the spec still says ${from}`)
  return spec.replace(from, to)
}
const importText = (text) => import(`data:text/javascript;base64,${Buffer.from(text).toString('base64')}`)
const site = await importText(readFileSync(join(SITE, SITE_BUNDLE_OUT), 'utf8'))

const helloSource = readFileSync(join(SITE, 'public/t27/files/specs/demos/hello_world.t27'), 'utf8')
const hello = analyze(helloSource)
const emitted = (a, name) => a.targets[name].code
const has = (r, level, re) => r.findings.some((x) => x.level === level && re.test(x.text))

// --- the gate -----------------------------------------------------------------------------------

test('the committed spec builds clean and writes exactly the committed files', async () => {
  const out = await buildPlay({ specText: spec, analyze })
  assert.deepEqual(out.problems, [])
  assert.ok(out.tests.tests >= 8 && out.tests.failures.length === 0, 'the spec tests its own limits, and they hold')
  for (const [rel, text] of out.files) assert.equal(readFileSync(join(SITE, rel), 'utf8'), text, `${rel} is stale; run node scripts/play-from-spec.mjs`)
})

test('an animation longer than X lets a card start by itself is refused', async () => {
  const out = await buildPlay({ specText: edit('COMPILE_ANIMATION_MS : u16 = 8000', 'COMPILE_ANIMATION_MS : u16 = 12000'), analyze })
  assert.ok(out.problems.some((p) => p.includes('COMPILE_ANIMATION_MS exceeds AUTOPLAY_LIMIT_MS')), out.problems.join('\n'))
  assert.equal(out.files, null)
})

test('a title longer than X shows is refused, not cut', async () => {
  const out = await buildPlay({ specText: edit('"hello_world.t27, compiled inside the post"', `"${'x'.repeat(71)}"`), analyze })
  assert.ok(out.problems.some((p) => /PLAY_TITLES is 71 characters, X allows 1\.\.70/.test(p)), out.problems.join('\n'))
})

test('a tab the page has no pane for is refused', async () => {
  const out = await buildPlay({ specText: edit('"code", "rtl", "term"]', '"code", "lint", "term"]'), analyze })
  assert.ok(out.problems.some((p) => p.includes('tab lint has no pane-lint')), out.problems.join('\n'))
})

test('the player is served over https or not at all', async () => {
  const out = await buildPlay({ specText: edit('ORIGIN : str = "https://t27.ai/"', 'ORIGIN : str = "http://t27.ai/"'), analyze })
  assert.ok(out.problems.some((p) => p.includes('ORIGIN must be an https origin')), out.problems.join('\n'))
})

// --- the terminal -------------------------------------------------------------------------------

const committed = await buildPlay({ specText: spec, analyze })
const cfg = committed.fields

// The terminal with no page: every printed line and every SAY_ key it said, the js runner stubbed
// (Node cannot import a blob: URL; the page's runner is the one the browser measurement covers).
function term(backend = cfg.BACKENDS[0]) {
  const out = []
  const said = []
  const ran = []
  const saved = []
  const sh = makeShell({
    cfg, specName: 'hello_world.t27', stem: 'hello_world', backend,
    source: () => helloSource, analyze,
    specHtml: () => '<spec>', codeHtml: (code) => code, download: (text, name) => saved.push([name, text.length]),
    replay: null,
  }, (kind, h = '') => out.push(`${kind} ${h.replace(/<[^>]+>/g, '')}`), { js: async (code) => { ran.push(code.length); return 'stub' } })
  const say = sh.say
  sh.say = (key, vars) => { said.push(key); return say(key, vars) }
  return { sh, out, said, ran, saved, run: (text) => dispatch(sh, text) }
}

test('a backend the compiler does not emit is refused', async () => {
  const out = await buildPlay({ specText: edit('"verilog_hir", "js", "ts"]', '"verilog_hir", "js", "py"]'), analyze })
  assert.ok(out.problems.some((p) => p.includes("BACKENDS must be the compiler's targets")), out.problems.join('\n'))
})

test('a command with no handler, or a handler with no command, is refused', async () => {
  const out = await buildPlay({ specText: edit('"history", "clear"]', '"whoami", "clear"]'), analyze })
  assert.ok(out.problems.some((p) => p.includes('command "whoami" has no handler')), out.problems.join('\n'))
  assert.ok(out.problems.some((p) => p.includes('handles "history", which SHELL_COMMANDS does not list')), out.problems.join('\n'))
})

test('a phrase the spec defines and the terminal never says, or says and the spec lacks, is refused', async () => {
  const out = await buildPlay({ specText: edit('pub const SAY_FAILED : str', 'pub const SAY_FAILURE : str'), analyze })
  assert.ok(out.problems.some((p) => p.includes('says SAY_FAILED, which this spec does not define')), out.problems.join('\n'))
  assert.ok(out.problems.some((p) => p.includes('SAY_FAILURE is never said')), out.problems.join('\n'))
})

test('a card demo too long to type inside the box, or inside X\'s autoplay limit, is refused', async () => {
  const long = await buildPlay({ specText: edit('SHELL_DEMO : str = "t27c gen {backend}"', 'SHELL_DEMO : str = "t27c gen {backend} and then some"'), analyze })
  assert.ok(long.problems.some((p) => /SHELL_DEMO for verilog_hir is \d+ characters/.test(p)), long.problems.join('\n'))
  const slow = await buildPlay({ specText: edit('SHELL_DEMO_MAX_CHARS : u8 = 32', 'SHELL_DEMO_MAX_CHARS : u8 = 255'), analyze })
  assert.ok(slow.problems.some((p) => p.includes('typing SHELL_DEMO would outlast AUTOPLAY_LIMIT_MS')), slow.problems.join('\n'))
})

test('every backend has a share page whose player opens the terminal on that backend, and git keeps it', () => {
  const written = new Map(committed.files)
  const paths = []
  cfg.BACKENDS.forEach((b, j) => {
    const page = `public/play/hello-world/${cfg.BACKEND_PAGES[j]}/index.html`
    assert.ok(written.has(page), `${page} is written`)
    assert.match(written.get(page), new RegExp(`name="twitter:player" content="[^"]*tab=term&amp;backend=${b}&amp;`))
    paths.push(page, imageOf(cfg, 'hello-world', cfg.BACKEND_PAGES[j]))
  })
  // The root .gitignore has `zig/` for SDK downloads; a page git ignores is a page the site 404s.
  const ignored = (list) => spawnSync('git', ['check-ignore', '--no-index', '--', ...list], { cwd: SITE, encoding: 'utf8' }).stdout.trim()
  assert.equal(ignored(paths), '', 'no generated page or card is ignored by git')
  assert.equal(ignored(['public/elsewhere/zig/card.png']), 'public/elsewhere/zig/card.png', 'the check sees the rule it guards against')
})

test('every terminal command runs on hello_world and says only what the spec lets it say', async () => {
  const facts = factsOf(cfg, helloSource, hello)
  const one = (c, i) => (cfg.SHELL_ARGS[i] === '<file>' ? `${c} hello_world.t27` : cfg.SHELL_ARGS[i] ? `${c} ${cfg.BACKENDS[2]}` : c)
  for (const [i, c] of cfg.SHELL_COMMANDS.entries()) {
    const t = term()
    await t.run(one(c, i))
    assert.ok(!t.said.includes('SAY_ERR_THREW'), `${c} threw: ${t.out.join(' | ')}`)
    assert.ok(!t.said.some((k) => k.startsWith('SAY_ERR_')), `${c}: ${t.said.join(', ')}`)
    assert.ok(t.out.length > 0 || c === 'clear', `${c} printed nothing`)
  }
  assert.deepEqual(Object.keys(COMMANDS), cfg.SHELL_COMMANDS)
  const t = term()
  await t.run('t27c test')
  assert.equal(facts.tests.fail, 0)
  assert.ok(t.out.some((l) => l.includes(fill(cfg.SAY_TESTS, { pass: facts.tests.pass, fail: 0, skip: facts.tests.skip }))), t.out.join('\n'))
})

test('run prints the command for a machine with rustc and never a result; js is imported here', async () => {
  const rust = term()
  await rust.run('run rust')
  assert.deepEqual(rust.said, ['SAY_WARN_NOT_HERE'])
  assert.ok(rust.out.some((l) => l.includes('$ rustc --crate-type lib --edition 2021 hello_world.rs')), rust.out.join('\n'))
  assert.equal(rust.ran.length, 0, 'nothing ran')
  const js = term()
  await js.run('node hello_world.js')
  assert.deepEqual(js.said, ['SAY_NOTE_IMPORTING'])
  assert.equal(js.ran.length, 1, 'the emitted JavaScript went to the runner once')
  assert.equal(js.sh.backend, 'js')
})

test('t27c gen-rust is t27c gen rust; gcc, an unknown t27c subcommand and a typo each say why', async () => {
  const a = term()
  await a.run('t27c gen-rust')
  const b = term()
  await b.run('t27c gen rust')
  const timeless = (out) => out.map((l) => l.replace(/ in \d+ ms /, ' in N ms '))
  assert.deepEqual(timeless(a.out), timeless(b.out))
  assert.equal(a.sh.backend, 'rust')
  const cases = [['gcc hello_world.c', 'SAY_WARN_NATIVE'], ['t27c fmt', 'SAY_ERR_T27C'], ['lss', 'SAY_ERR_NOT_FOUND'], ['t27c gen cobol', 'SAY_ERR_NO_BACKEND'], ['cat nope.v', 'SAY_ERR_NO_FILE'], ['cat', 'SAY_ERR_WHICH_FILE']]
  for (const [typed, key] of cases) {
    const t = term()
    await t.run(typed)
    assert.ok(t.said.includes(key), `${typed}: ${t.said.join(', ')}`)
    assert.ok(!t.out.join('\n').includes('needs {'), `${typed}: a phrase was printed unfilled`)
  }
})

test('save asks for a download of exactly what the compiler emitted', async () => {
  const t = term()
  await t.run('save hello_world.rs')
  assert.deepEqual(t.saved, [['hello_world.rs', hello.targets.rust.code.length]])
})

// --- the site bundle ---------------------------------------------------------------------------

test('site.js is built from the site source, so a palette change there reaches the player', async () => {
  const out = await buildPlay({ specText: spec, analyze })
  const root = mkdtempSync(join(tmpdir(), 'play-site-'))
  try {
    mkdirSync(join(root, 'src/lib'), { recursive: true })
    for (const m of out.fields.SITE_MODULES) cpSync(join(SITE, m), join(root, m))
    const highlight = join(root, 'src/lib/highlight.ts')
    writeFileSync(highlight, readFileSync(highlight, 'utf8').replace("kw: '#FFD700'", "kw: '#123456'"))
    const moved = renderSiteBundle(out.fields, root)
    assert.equal((await importText(moved)).CLS_COLOR.kw, '#123456')
    assert.equal(site.CLS_COLOR.kw, '#FFD700', 'the committed bundle carries the committed palette')
    assert.notEqual(playerBuild(SITE, { [SITE_BUNDLE_OUT]: moved }), out.build, 'the player build, and so every ?v=, moves with it')
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})

test('the spec highlighter: a /* inside a string opens no comment, and a ; line is prose', () => {
  const src = 'module m;\npub const S : str = "a /* b";\n; prose\npub const N : u8 = 1;\n'
  const rows = site.highlightSource(src, analyze(src).tokens)
  const text = (row) => row.map((s) => s.text).join('')
  assert.deepEqual(rows.map(text), src.split('\n'), 'every character is kept')
  assert.ok(rows[1].some((s) => s.cls === 'str' && s.text === '"a /* b"'))
  assert.deepEqual(rows[2].map((s) => s.cls), ['comment'])
  assert.ok(rows[3].some((s) => s.cls === 'kw' && s.text === 'pub'), 'the line after the string is code, not comment')
  assert.ok(rows[3].some((s) => s.cls === 'num' && s.text === '1'))
})

// --- the RTL tab --------------------------------------------------------------------------------

test('hello_world: gen-verilog emits what a Verilog-2005 reader refuses, and the struct packs to 25', () => {
  const r = readRtl(emitted(hello, 'verilog'), hello.ast)
  assert.equal(r.module, 'HelloWorld')
  assert.ok(has(r, 'error', /^4 SystemVerilog size casts/), 'iverilog -g2005 and yosys stop at line 66 on these')
  assert.ok(has(r, 'error', /^cast\(\) is called and declared nowhere/), 'iverilog -g2012 and verilator stop at line 79 on this')
  assert.equal(r.findings.find((x) => /size casts/.test(x.text)).line, 66)
  assert.equal(r.findings.find((x) => /^cast\(\)/.test(x.text)).line, 79)
  const s = r.structs.find((x) => x.name === 'ConfigPacked')
  assert.equal(s.bits, 25)
  assert.equal(s.stated, 25, 'the width gen-verilog states')
  assert.ok(s.lowered)
  assert.deepEqual(s.fields.map((x) => [x.name, x.hi, x.lo]), [['width', 7, 0], ['height', 15, 8], ['depth', 23, 16], ['enable', 24, 24]])
})

test('hello_world: the HIR backend writes an unescaped `config` port 32 bits wide for a 25-bit struct', () => {
  const r = readRtl(emitted(hello, 'verilog_hir'), hello.ast)
  assert.ok(has(r, 'error', /^port config is a Verilog-2005 reserved word/), 'iverilog and verilator stop at line 15 on this')
  assert.ok(has(r, 'warn', /^config carries a ConfigPacked as 32 bits \(port\); the struct packs to 25\./))
  assert.ok(has(r, 'warn', /^The module body is empty/))
  assert.ok(has(r, 'warn', /^3 outputs with no driver/))
})

test('a "/*" inside a Verilog string opens no comment, so what follows still counts', () => {
  const v = [
    'module m (input wire clk, output wire ready);',
    '  initial $display("/* not a comment");',
    '  assign ready = clk;',
    'endmodule',
  ].join('\n')
  const r = readRtl(v, null)
  assert.ok(!has(r, 'warn', /no driver/), 'ready is driven on line 3')
  assert.ok(!has(r, 'info', /never read/), 'clk is read on line 3')
})

test('a task is declared, and `function real` names its result type, not the function', () => {
  const v = [
    'module m (input wire [7:0] a, output wire [63:0] y);',
    '  task show; input [7:0] x; begin $display("%d", x); end endtask',
    '  function real half; input [7:0] x; begin half = x / 2.0; end endfunction',
    '  initial show(a);',
    '  assign y = $realtobits(half(a));',
    'endmodule',
  ].join('\n')
  const r = readRtl(v, null)
  assert.ok(!has(r, 'error', /show\(\) is called and declared nowhere/))
  assert.ok(!has(r, 'error', /half\(\) is called and declared nowhere/))
  assert.deepEqual(r.functions.map((f) => [f.name, f.width]), [['half', 64]])
  assert.deepEqual(r.tasks.map((t) => t.name), ['show'])
})

test('an array sized by a constant packs the way t27c packs it', () => {
  const src = [
    'module dims;',
    'pub const LANES : usize = 4;',
    'pub const Frame = struct { tag : u8, lane : [LANES]u16 };',
    'pub fn tag_of(f : Frame) -> u8 { return f.tag; }',
    'test t { assert LANES == 4; }',
  ].join('\n')
  const a = analyze(src)
  const r = readRtl(emitted(a, 'verilog'), a.ast)
  const s = r.structs.find((x) => x.name === 'Frame')
  assert.ok(s, 'Frame is read from the spec')
  assert.equal(s.bits, 8 + 4 * 16)
  assert.equal(s.stated, s.bits, 'gen-verilog states the same width: "lowered as packed vector (72 bits)"')
})
