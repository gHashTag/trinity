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

test('JSON-LD parses and names the page', () => {
  for (const p of pages) {
    const ld = JSON.parse(p.html.match(/<script type="application\/ld\+json">(.*?)<\/script>/s)[1])
    assert.equal(ld.url, `https://t27.ai/${p.dir}`)
    assert.equal(ld['@type'], p.lesson ? 'LearningResource' : 'Course')
  }
})

test('the sitemap lists every page once', () => {
  const sm = sitemapOf(pages)
  for (const p of pages) assert.equal(sm.split(`<loc>https://t27.ai/${p.dir}</loc>`).length, 2)
})
