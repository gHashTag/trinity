import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import test from 'node:test'
import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { transformSync } from 'esbuild'

const require = createRequire(import.meta.url)
const componentSource = readFileSync(new URL('../src/components/BlogCover.tsx', import.meta.url), 'utf8')
const { code } = transformSync(componentSource, { loader: 'tsx', jsx: 'automatic', format: 'cjs' })
const panels = [1, 2, 3].map(n => ({ heading: `PANEL ${n}`, caption: `Finding ${n}.` }))

function render(props, captions = { sample: { en: panels } }) {
  const module = { exports: {} }
  new Function('module', 'exports', 'require', code)(module, module.exports, id => (
    id === '../data/blog/coverVersions'
      ? { BLOG_COVER_VERSIONS: { sample: { en: 'englishhash', ru: 'russianhash' } }, BLOG_COVER_CAPTIONS: captions }
      : require(id)
  ))
  return renderToStaticMarkup(createElement(module.exports.default, {
    slug: 'sample', title: 'A measured result', lang: 'en', className: 'blog-lead-cover', ...props,
  }))
}

test('article hero exposes complete image, meaningful ALT, full-size link and three visible captions', () => {
  const html = render({ priority: true })
  assert.match(html, /<figure class="blog-cover-figure">/)
  assert.match(html, /src="\/og-blog-sample.png\?v=englishhash"/)
  assert.match(html, /alt="Three-panel engraved illustration for: A measured result. PANEL 1 \/ PANEL 2 \/ PANEL 3"/)
  assert.match(html, /width="1200" height="630" loading="eager" decoding="async"/)
  assert.equal((html.match(/<a /g) ?? []).length, 2)
  assert.match(html, /aria-label="View the complete triptych at full size — A measured result"/)
  assert.equal((html.match(/<li>/g) ?? []).length, 3)
  assert.match(html, /Finding 3\./)
  assert.doesNotMatch(html, /<details|hidden=/)
})

test('card image stays non-interactive inside its existing article Link', () => {
  const html = render({ priority: false, className: 'blog-card-cover' })
  assert.match(html, /loading="lazy"/)
  assert.match(html, /alt="[^\"]*PANEL 3"/)
  assert.doesNotMatch(html, /<a\b|<button\b|<figure\b|<figcaption\b/)
})

test('Russian hero uses Russian asset hash and identifies English caption fallback', () => {
  const html = render({ priority: true, lang: 'ru', title: 'Измеренный результат' })
  assert.match(html, /og-blog-sample-ru.png\?v=russianhash/)
  assert.match(html, /Гравюрный триптих к статье: Измеренный результат/)
  assert.match(html, /Подписи на изображении — на английском/)
  assert.match(html, /<ol class="blog-cover-panels" lang="en">/)
})

test('explicit Russian captions replace fallback, and missing captions never invent a transcription', () => {
  const ru = [1, 2, 3].map(n => ({ heading: `ПАНЕЛЬ ${n}`, caption: `Вывод ${n}.` }))
  const html = render({ priority: true, lang: 'ru' }, { sample: { en: panels, ru } })
  assert.match(html, /lang="ru"/)
  assert.match(html, /Вывод 3/)
  assert.doesNotMatch(html, /Подписи на изображении — на английском/)
  const missing = render({ priority: true }, {})
  assert.match(missing, /A measured result/)
  assert.match(missing, /View the complete triptych/)
  assert.doesNotMatch(missing, /<ol|PANEL/)
})

test('caption text is escaped by React and mobile CSS preserves the whole image', () => {
  const malicious = panels.map(p => ({ ...p, caption: '<script>alert(1)</script>' }))
  const html = render({ priority: true }, { sample: { en: malicious } })
  assert.match(html, /&lt;script&gt;/)
  assert.doesNotMatch(html, /<script>/)
  const css = readFileSync(new URL('../src/index.css', import.meta.url), 'utf8')
  assert.match(css, /\.blog-cover-figure \.blog-lead-cover\s*\{[^}]*object-fit: contain;[^}]*aspect-ratio: 40 \/ 21;/)
  assert.match(css, /@media \(max-width: 600px\) \{ \.blog-cover-panels \{ grid-template-columns: 1fr;/)
})
