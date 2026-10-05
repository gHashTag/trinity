import assert from 'node:assert/strict'
import { test } from 'node:test'
import { buildPages, loadCourse, sitemapOf } from './course-pages.mjs'

const C = loadCourse()
const pages = buildPages(C)
const meta = (html, key) => html.match(new RegExp(`<meta (?:property|name)="${key}" content="([^"]*)"`))?.[1]

test('one page per lesson and one for the course, in every language', () => {
  assert.equal(pages.length, C.locales.length * (C.lessons.length + 1))
  for (const l of C.lessons) for (const lang of C.locales) assert.ok(pages.some((p) => p.lang === lang && p.lesson?.id === l.id))
})

test('every page is indexable: no redirect, its own canonical, a reciprocal hreflang pair', () => {
  for (const p of pages) {
    assert.doesNotMatch(p.html, /location\.replace|http-equiv="refresh"/)
    assert.match(p.html, new RegExp(`<html lang="${p.lang}">`))
    const canonical = p.html.match(/<link rel="canonical" href="([^"]+)">/)[1]
    assert.equal(canonical, `https://t27.ai/${p.dir}`)
    assert.equal(meta(p.html, 'og:url'), canonical)
    for (const h of ['en', 'ru', 'x-default']) assert.match(p.html, new RegExp(`hreflang="${h}" href="https://t27\\.ai/`))
  }
})

test('every page carries a large card of its own and the lesson words', () => {
  for (const p of pages) {
    assert.equal(meta(p.html, 'twitter:card'), 'summary_large_image')
    assert.match(meta(p.html, 'og:image'), new RegExp(`^https://t27\\.ai/${p.dir}card\\.png\\?v=`))
    assert.equal(meta(p.html, 'twitter:image'), meta(p.html, 'og:image'))
    if (p.lesson) {
      const t = p.lesson[p.lang]
      for (const w of [t.title, t.goal, t.task]) assert.ok(p.html.includes(w.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')), `${p.dir} lacks: ${w}`)
      assert.ok(p.html.includes(`href="/#/course/${p.lesson.id}"`), `${p.dir} does not open the lesson`)
    }
  }
})

test('JSON-LD parses, names the page and carries its breadcrumbs', () => {
  for (const p of pages) {
    const ld = [...p.html.matchAll(/<script type="application\/ld\+json">(.*?)<\/script>/gs)].map((m) => JSON.parse(m[1]))
    assert.equal(ld[0].url, `https://t27.ai/${p.dir}`)
    assert.equal(ld[0]['@type'], p.lesson ? 'LearningResource' : 'Course')
    const crumbs = ld.find((x) => x['@type'] === 'BreadcrumbList')
    assert.equal(crumbs.itemListElement.at(-1).item, `https://t27.ai/${p.dir}`)
    if (!p.lesson) assert.equal(ld.find((x) => x['@type'] === 'ItemList').itemListElement.length, C.lessons.length)
  }
})

test('titles and descriptions fit a search result', () => {
  for (const p of pages) {
    const d = p.html.match(/<meta name="description" content="([^"]*)">/)[1]
    assert.ok(d.length <= 160, `${p.dir} description is ${d.length} characters`)
    assert.match(p.html, p.lang === 'ru' ? /<title>[^<]*FPGA[^<]*<\/title>/ : /<title>[^<]*FPGA[^<]*<\/title>/)
  }
})

test('the sitemap lists every page once', () => {
  const sm = sitemapOf(pages)
  for (const p of pages) assert.equal(sm.split(`<loc>https://t27.ai/${p.dir}</loc>`).length, 2)
})
