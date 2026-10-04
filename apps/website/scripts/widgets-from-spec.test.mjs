import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler } from './agents-from-specs.mjs'
import { PUBLIC_SPEC_OUT, TS_OUT, WIDGETS_SPEC, buildWidgets, metaOf } from './widgets-from-spec.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const source = readFileSync(join(SITE, WIDGETS_SPEC), 'utf8')
const replaceConst = (text, name, value) => {
  const pattern = new RegExp(`^(pub const ${name} : [a-z0-9\\[\\]-]+ = )[^;]+;`, 'm')
  assert.match(text, pattern, `${name} exists in the spec`)
  return text.replace(pattern, `$1${value};`)
}

test('the committed spec builds clean and the derived files are current', async () => {
  const out = await buildWidgets({ specText: source, analyze })
  assert.deepEqual(out.problems, [])
  assert.equal(readFileSync(join(SITE, TS_OUT), 'utf8'), out.ts)
  assert.equal(readFileSync(join(SITE, PUBLIC_SPEC_OUT), 'utf8'), source)
  assert.equal(out.gallery.widgets.length, out.fields.WIDGET_COUNT)
  assert.equal(out.gallery.postsNothing, true)
})

test('every widget title comes from its page, never from the gallery', async () => {
  const out = await buildWidgets({ specText: source, analyze })
  for (const w of out.gallery.widgets) {
    assert.ok(w.title.length > 0, `${w.id} has a title`)
    assert.ok(w.url.startsWith('https://t27.ai/'), `${w.id} copies an absolute address`)
    if (w.kind === 'tab') continue
    const meta = metaOf(readFileSync(join(SITE, 'public', w.url.slice('https://t27.ai/'.length), 'index.html'), 'utf8'))
    assert.equal(w.title, meta['og:title'], `${w.id} title is the page's og:title`)
  }
})

test('a widget whose page does not exist fails the build', async () => {
  const broken = source.replace('"term/x7-board/"', '"term/no-such-recording/"')
  const out = await buildWidgets({ specText: broken, analyze })
  assert.ok(out.problems.some((p) => p.includes('no-such-recording')), out.problems.join('\n'))
  assert.equal(out.ts, null)
})

test('a failing spec test blocks the write', async () => {
  const broken = replaceConst(source, 'POSTS_NOTHING', 'false')
  const out = await buildWidgets({ specText: broken, analyze })
  assert.ok(out.problems.length > 0)
  assert.equal(out.ts, null)
})

test('a tab widget must name a real board view', async () => {
  const broken = source.replace(/"wars", "term\/tri-game-tick\/"/, '"nowhere", "term/tri-game-tick/"')
  const out = await buildWidgets({ specText: broken, analyze })
  assert.ok(out.problems.length > 0)
})
