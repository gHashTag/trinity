import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler } from './agents-from-specs.mjs'
import { CARD, buildAll, buildTool, galleryWords, pageOut, pngSize, specOut, toolSpecs } from './widget-pages-from-spec.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const { g } = galleryWords(analyze)

test('every tool spec builds clean and its page and spec copy are current', async () => {
  const { problems, tools } = await buildAll({ analyze })
  assert.deepEqual(problems, [])
  for (const t of tools) {
    assert.equal(readFileSync(join(SITE, pageOut(t.fields.ID)), 'utf8'), t.page, `${t.fields.ID} page is current`)
    assert.equal(readFileSync(join(SITE, specOut(t.fields.ID)), 'utf8'), t.publicSpec, `${t.fields.ID} spec copy is current`)
    assert.ok(t.tests.tests >= 2, `${t.fields.ID} tests at least two invariants`)
  }
})

test('every page carries a large card, its own words and no words of its own', async () => {
  const { tools } = await buildAll({ analyze })
  for (const t of tools) {
    const f = t.fields
    assert.match(t.page, /<meta name="twitter:card" content="summary_large_image">/)
    assert.ok(t.page.includes(`https://t27.ai/widgets/${f.ID}/card.png`), `${f.ID} og:image is absolute`)
    assert.ok(t.page.includes('window.T27_WIDGET'), `${f.ID} hands its constants to tool.js`)
    const size = pngSize(readFileSync(join(SITE, 'public/widgets', f.ID, 'card.png')))
    assert.deepEqual(size, { width: CARD.width, height: CARD.height })
  }
})

test('a spec that claims to send data, or tests nothing, is refused', () => {
  for (const file of toolSpecs()) {
    const text = readFileSync(join(SITE, file), 'utf8')
    const sends = text.replace(/^(pub const SENDS_NOTHING : bool = )true;/m, '$1false;')
    assert.notEqual(sends, text, `${file} declares SENDS_NOTHING`)
    assert.ok(buildTool({ file, specText: sends, analyze, gallery: g }).problems.length > 0, `${file} with SENDS_NOTHING false is refused`)
    const wrongId = text.replace(/^(pub const ID : str = )"[^"]*";/m, '$1"not-this-file";')
    assert.ok(buildTool({ file, specText: wrongId, analyze, gallery: g }).problems.length > 0, `${file} under another ID is refused`)
  }
})
