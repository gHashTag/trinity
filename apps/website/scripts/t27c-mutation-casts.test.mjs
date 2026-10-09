// The nine recordings of "AI numbers" lessons 13 to 21 show what their lessons say: the committed
// session.cast of each runs the commands meta.json lists, its baseline report passes every test, and
// the report after the one-line sed names exactly the test the recorder was told must fail.
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import { RECORDINGS, Screen, commandsOf, indexWith, problemsOf, reportOf } from './t27c-mutation-casts.mjs'

const TERM = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'term')

const PASS = `--- test report: specs/ternary/x.t27 ---

  tests       4
  pass        4
  FAIL        0
  rate    100.0%
  vacuous passes  0 of 4  (passed with 0 runtime asserts executed)
`
const ONE_FAIL = `--- test report: specs/ternary/x.t27 ---
  FAIL  negz

  tests       4
  pass        3
  FAIL        1
  rate    75.0%
`

test('reportOf reads the counts and the failed tests of t27c test-report', () => {
  assert.deepEqual(reportOf(PASS), { tests: 4, pass: 4, fail: 0, failed: [], vacuous: 0 })
  assert.deepEqual(reportOf(ONE_FAIL), { tests: 4, pass: 3, fail: 1, failed: ['negz'], vacuous: null })
})

const H = 'a'.repeat(64)
const stepsOf = (outs) => ({ steps: outs.map((text) => ({ exit: '0', chunks: [{ at: 0, text }] })) })
const good = ['abc x\n', 't27c 0.5.1\n0.16.0\n', `${H}  s\nline\n`, PASS, '-  a\n+  b\n', ONE_FAIL, `Updated 1 path from the index\n${H}  s\n`]
const r = { id: 'x', fails: 'negz' }

test('problemsOf accepts a run that shows the lesson, and refuses each way it can lie', () => {
  assert.deepEqual(problemsOf(r, stepsOf(good)), [])
  assert.match(problemsOf({ ...r, fails: 'pos' }, stepsOf(good)).join(), /not exactly pos/)
  assert.match(problemsOf(r, stepsOf(good.map((o, i) => (i === 3 ? ONE_FAIL : o)))).join(), /baseline/)
  assert.match(problemsOf(r, stepsOf(good.map((o, i) => (i === 4 ? '-  a\n+  b\n-  c\n' : o)))).join(), /one-line/)
  assert.match(problemsOf(r, stepsOf(good.map((o, i) => (i === 6 ? `${'b'.repeat(64)}  s\n` : o)))).join(), /hash/)
  const failedExit = stepsOf(good)
  failedExit.steps[1].exit = '1'
  assert.match(problemsOf(r, failedExit).join(), /exited/)
})

test('the screen wraps at 104 columns and keeps the prompt colour', () => {
  const s = new Screen().feed('\u001b[38;2;255;215;0mt27 $ \u001b[0m' + 'x'.repeat(110) + '\r\n')
  const rows = s.runs()
  assert.deepEqual(rows[0].map((run) => run.fg), ['#ffd700', '#ebebeb'])
  assert.equal(rows[0].map((run) => run.text).join('').length, 104)
  assert.equal(rows[1][0].text.trimEnd(), 'x'.repeat(12))
})

test('indexWith lists the recordings first, newest first, and keeps the count honest', () => {
  const html = ['<meta property="og:image" content="https://t27.ai/term/old/card.png">', '<p class="lede">Terminal sessions recorded from real commands: the output is what the commands printed. 2 so far.</p>', '<div class="grid">', '<a href="old/"><img src="old/card.png"></a>', '<a href="x/"><img src="x/card.png"></a>', '</div>'].join('\n')
  const out = indexWith(html, [{ id: 'x', title: 'X', recorded: '2026-10-09 08:43 UTC', real_s: 1 }, { id: 'y', title: 'Y', recorded: '2026-10-09 08:44 UTC', real_s: 2 }])
  const ids = [...out.matchAll(/^<a href="([^"/]+)\/">/gm)].map((m) => m[1])
  assert.deepEqual(ids, ['y', 'x', 'old'])
  assert.match(out, /3 so far\./)
  assert.match(out, /term\/y\/card\.png/)
})

for (const rec of RECORDINGS) {
  test(`${rec.id}: the published recording shows exactly ${rec.fails} failing`, () => {
    const dir = join(TERM, rec.id)
    const meta = JSON.parse(readFileSync(join(dir, 'meta.json'), 'utf8'))
    const [head, ...rows] = readFileSync(join(dir, 'session.cast'), 'utf8').trim().split('\n')
    const header = JSON.parse(head)
    const events = rows.map((l) => JSON.parse(l))
    assert.equal(meta.id, rec.id)
    assert.equal(meta.pending, undefined, 'no recording is pending any more')
    assert.deepEqual(meta.commands, commandsOf(rec))
    assert.deepEqual(header.commands, meta.commands)
    assert.equal(header.version, 2)
    assert.deepEqual(meta.exit_codes, meta.commands.map(() => '0'))
    assert.equal(meta.gif, null)
    assert.equal(existsSync(join(dir, 'session.gif')), false, 'gif is null, so there is no GIF file either')
    assert.match(meta.desc, /cloud container/)
    assert.match(meta.desc, /t27c \d+\.\d+\.\d+ and zig \d+\.\d+\.\d+/)
    // The output of each command: the events between its exit and the next one.
    const outputs = []
    let cur = ''
    let typing = true
    for (const [, kind, text] of events) {
      if (kind === 'x') { outputs.push(cur); cur = ''; typing = true; continue }
      if (typing) { if (text === '\r\n') typing = false; continue }
      cur += text
    }
    assert.equal(outputs.length, 7)
    const base = reportOf(outputs[3].replace(/\r\n/g, '\n'))
    const mutant = reportOf(outputs[5].replace(/\r\n/g, '\n'))
    assert.equal(base.fail, 0)
    assert.equal(base.pass, base.tests)
    assert.deepEqual(mutant.failed, [rec.fails])
    assert.equal(mutant.fail, 1)
    const hashes = [outputs[2], outputs[6]].map((o) => /^([0-9a-f]{64})\s/m.exec(o)[1])
    assert.equal(hashes[0], hashes[1], 'git checkout restores the spec byte for byte')
  })
}
