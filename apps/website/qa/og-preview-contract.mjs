// WHAT A LINK TO t27.ai SHOWS.
//
// A preview (Telegram, X, Slack, iMessage) reads four things from index.html:
// the site name, the title, the description and the picture. Until 2026-10-04
// all four described the GFTernary/TNF page the site used to open on ("52
// theorems, 16 retractions", "Hardware-verified RTL"), while the page itself
// had become the game. Owner, 2026-10-04, a screenshot of that preview: say
// "TRINITY S³AI / AGI game — play, direct, earn / Play, direct, earn: the core
// is a game, and the board is public".
//
// Those are the page's own words, and lib/motto.ts is their one home: the
// name (SITE_NAME), the caption, the headline opening and the clause after its
// colon. Every other copy is held to that file here -- the hero that draws
// them, the i18n provider that writes the tab title and description at run
// time, the head tags a crawler reads without running anything, and the words
// drawn in og/og-image.svg.
//
//   node --experimental-strip-types qa/og-preview-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { MOTTO, SITE_NAME } from '../src/lib/motto.ts'

const read = rel => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')

// 1. The page's words, from their home.
const SITE = SITE_NAME
const CAPTION = MOTTO.en.caption
const CLAUSE = MOTTO.en.clause
const DESCRIPTION = `${MOTTO.en.headline}: ${CLAUSE}`

// The owner's three lines, so a change of the page's words is a decision and
// not a side effect of editing a component.
assert.equal(SITE, 'TRINITY S³AI')
assert.equal(CAPTION, 'AGI game — play, direct, earn')
assert.equal(DESCRIPTION, 'Play, direct, earn: the core is a game, and the board is public')
for (const lang of ['en', 'ru']) assert.ok(MOTTO[lang].clause, `lib/motto gives ${lang} no clause`)

// The hero draws them from there, not from copies of its own.
const hero = read('src/components/GameHero.tsx')
assert.match(hero, /<span className="game-hero-wordmark">\{SITE_NAME\}<\/span>/)
assert.match(hero, /<h1 id="game-hero-title">\{motto\.headline\}: \{motto\.clause\}<\/h1>/)
assert.doesNotMatch(hero, /wordmark: '|title: '/, 'the hero keeps no copy of the name or the clause')

// The i18n provider rewrites the tab title, the description and og:title on
// every load; it used to write the GFTernary/TNF claims back over the head.
const i18n = read('src/i18n/context.tsx')
assert.match(i18n, /import \{ MOTTO, SITE_NAME \} from '\.\.\/lib\/motto'/)
assert.match(i18n, /en: \{ locale: 'en_US', \.\.\.seoOf\(MOTTO\.en\) \}/)
assert.match(i18n, /ru: \{ locale: 'ru_RU', \.\.\.seoOf\(MOTTO\.ru\) \}/)
assert.match(i18n, /title: `\$\{SITE_NAME\} — \$\{m\.caption\}`/)
assert.match(i18n, /description: `\$\{m\.headline\}: \$\{m\.clause\}`/)
assert.match(i18n, /set\('meta\[property="og:title"\]', 'content', meta\.caption\)/, 'og:title stays the caption after load too')
// The code, not the comment that records why it changed.
const seoCode = i18n.slice(i18n.indexOf('const SEO = {'), i18n.indexOf('export function I18nProvider'))
assert.ok(seoCode.length > 0, 'context.tsx has a SEO block')
assert.doesNotMatch(seoCode, /GFTernary|52 theorems|52 теорем/)

// 2. The head.
const html = read('index.html')
const meta = (attr, key) => {
  const all = [...html.matchAll(new RegExp(`<meta ${attr}="${key}"\\s+content="([^"]*)"`, 'g'))]
  assert.equal(all.length, 1, `exactly one <meta ${attr}="${key}">`)
  return all[0][1]
}
assert.equal(html.match(/<title>([^<]*)<\/title>/)?.[1], `${SITE} — ${CAPTION}`, '<title>: the site, then the caption')
assert.equal(meta('property', 'og:site_name'), SITE)
assert.equal(meta('name', 'apple-mobile-web-app-title'), SITE)
// The site name is its own line in a preview, so the title does not repeat it.
assert.equal(meta('property', 'og:title'), CAPTION)
assert.equal(meta('name', 'twitter:title'), CAPTION)
for (const [attr, key] of [['name', 'description'], ['property', 'og:description'], ['name', 'twitter:description']])
  assert.equal(meta(attr, key), DESCRIPTION, key)
assert.equal(meta('property', 'og:image'), 'https://t27.ai/og-image.png')
assert.equal(meta('name', 'twitter:image'), 'https://t27.ai/og-image.png')
assert.equal(meta('name', 'twitter:card'), 'summary_large_image')
assert.equal(meta('property', 'og:image:width'), '1200')
assert.equal(meta('property', 'og:image:height'), '630')
assert.equal(meta('property', 'og:image:alt'), `${SITE}. ${CAPTION}. ${DESCRIPTION}.`)
const said = html.replace(/<!--[\s\S]*?-->/g, '')
for (const old of ['GFTernary · TNF — a reference format pair', '52 theorems, 16 retractions', '66 LUT against a 112 LUT'])
  assert.ok(!said.slice(0, said.indexOf('</head>')).includes(old), `the head no longer says "${old}"`)

// 3. The picture says the same words, drawn with the site's font, under the
//    site's mark.
const svg = read('og/og-image.svg')
const drawn = cls => [...svg.matchAll(new RegExp(`<text class="${cls}"[^>]*>([^<]*)</text>`, 'g'))].map(m => m[1])
assert.deepEqual(drawn('wordmark'), [SITE])
assert.deepEqual(drawn('caption'), [CAPTION], 'the caption, as written: upper case is the style\'s')
assert.deepEqual(drawn('headline'), [`${MOTTO.en.headline}:`])
assert.equal(drawn('rest').join(' '), CLAUSE, 'the clause, over its lines')
assert.match(svg, /<svg xmlns="http:\/\/www\.w3\.org\/2000\/svg" width="1200" height="630"/)
assert.match(svg, /src: url\(\.\.\/public\/fonts\/outfit-latin\.woff2\)/, 'the site\'s own font file')
const pieces = s => s.match(/<path [^>]*\/>/g) ?? []
assert.equal(pieces(read('public/favicon.svg')).length, 27)
assert.deepEqual(pieces(svg), pieces(read('public/favicon.svg')), 'the mark is the favicon\'s 27 pieces, unchanged')
const comment = svg.slice(svg.indexOf('<!--') + 4, svg.indexOf('-->'))
assert.ok(!comment.includes('--'), 'no "--" inside an XML comment: the renderer stops at it and draws an error page')

// 4. The rendered file is the size the tags declare.
const png = readFileSync(new URL('../public/og-image.png', import.meta.url))
assert.equal(png.subarray(1, 4).toString(), 'PNG')
assert.equal(png.readUInt32BE(16), 1200)
assert.equal(png.readUInt32BE(20), 630)

console.log(`og-preview contract: ok ("${SITE}" / "${CAPTION}" / "${DESCRIPTION}")`)
