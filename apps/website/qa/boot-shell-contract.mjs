// WHAT A CRAWLER READS ON THE HOME PAGE: the shell index.html carries before
// any script runs (scripts/boot-shell.ts).
//
// Until 2026-10-04 that shell was the retired GFTernary hero, read from
// messages/en.json, with two links -- relative ones, which under
// app.t27.ai/game/ point at pages that are not there. A crawler's first pass
// saw a different site from the one a reader saw, and could reach two of its
// sections. Each rule below is one a quiet edit would break: the shell's words
// parting from GameHero's, a link written relative or as a #/ route (a crawler
// drops the hash, so every such link is the home page again), a section
// dropped, the Russian entry losing its hreflang.
//
//   node --experimental-strip-types qa/boot-shell-contract.mjs

import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { APEX, RU_PAGE, STATIC_PAGES, bootShell } from '../scripts/boot-shell.ts'
import { MOTTO, SITE_NAME } from '../src/lib/motto.ts'

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8')

/** Every way a shell's links can be wrong, as a list of complaints. */
function linkProblems(html) {
  const hrefs = [...html.matchAll(/<a\b[^>]*\bhref="([^"]*)"/g)].map((m) => m[1])
  const out = []
  if (hrefs.length < 10) out.push(`only ${hrefs.length} links`)
  for (const h of hrefs) {
    if (h.includes('#')) out.push(`${h}: a crawler drops the hash`)
    else if (!h.startsWith(APEX)) out.push(`${h}: not absolute on the apex, so wrong under app.t27.ai/game/`)
    // A course's share page sits one level down (learn/<id>/, courses.t27 SHARE_BASE).
    else if (!/^[a-z0-9-]+\/([a-z0-9-]+\/)?$/.test(h.slice(APEX.length))) out.push(`${h}: not a section path with its trailing slash`)
  }
  if (new Set(hrefs).size !== hrefs.length) out.push('a link twice')
  return out
}

/** Every way a shell's words can part from the first screen. */
function wordProblems(html) {
  const m = MOTTO.en
  const out = []
  const h1 = html.match(/<h1>([^<]*)<\/h1>/g) ?? []
  if (h1.length !== 1) out.push(`${h1.length} h1 elements`)
  else if (h1[0] !== `<h1>${m.headline}: ${m.clause}</h1>`) out.push(`h1 is ${h1[0]}`)
  if (!html.includes(`<p class="mark">${SITE_NAME}</p>`)) out.push('no wordmark')
  if (!html.includes(`<p class="cap">${m.caption}</p>`)) out.push('no caption')
  if (!html.includes('<img src="favicon.svg" alt="" ')) out.push('the mark is not the bare, decorative triangle')
  if (/GFTernary|TNF/.test(html)) out.push('the retired hero')
  return out
}

const shell = bootShell()

// 1. The shell, as built.
assert.deepEqual(wordProblems(shell), [], 'the shell says what the first screen says')
assert.deepEqual(linkProblems(shell), [], 'the shell links every static section, absolutely')
for (const p of STATIC_PAGES) assert.ok(shell.includes(`href="${APEX}${p.path}"`), p.path)
assert.ok(STATIC_PAGES.some((p) => p.path === 'blog/'), 'the blog: the section with the most pages')
assert.match(shell, new RegExp(`<a href="${APEX}${RU_PAGE.path}" hreflang="ru" lang="ru">${MOTTO.ru.headline}</a>`))
assert.equal(shell.match(/<nav\b/g)?.length, 1)
assert.ok(shell.startsWith('<div id="boot">') && shell.endsWith('<!-- /boot -->'), 'the marker vite.config replaces')

// 2. The checks catch what they are for. Each of these is a shell that was, or
//    nearly was, shipped.
const bad = (from, to) => shell.replace(from, to)
assert.ok(linkProblems(bad(`href="${APEX}gft/"`, 'href="gft/"')).some((s) => s.includes('not absolute')), 'relative, as before')
assert.ok(linkProblems(bad(`href="${APEX}gft/"`, 'href="/gft/"')).some((s) => s.includes('not absolute')), 'root-absolute')
assert.ok(linkProblems(bad(`href="${APEX}gft/"`, 'href="#/gft"')).some((s) => s.includes('hash')), 'a hash route')
assert.ok(linkProblems(bad(`href="${APEX}gft/"`, `href="${APEX}gft"`)).some((s) => s.includes('trailing slash')), 'no slash: a redirect')
assert.ok(linkProblems(bad(`href="${APEX}gft/"`, `href="${APEX}blog/"`)).some((s) => s.includes('twice')), 'a duplicate')
assert.ok(linkProblems('<a href="https://t27.ai/ip/">a</a><a href="https://t27.ai/proof/">b</a>').some((s) => s.includes('only 2')), 'the old two')
assert.ok(wordProblems(bad(MOTTO.en.clause, 'the board is private')).some((s) => s.startsWith('h1 is')), 'other words')
assert.ok(wordProblems(bad('<h1>', '<h1>x</h1><h1>')).some((s) => s.includes('2 h1')), 'two headings')
assert.ok(wordProblems(`${shell}GFTernary · TNF`).includes('the retired hero'))
assert.ok(wordProblems(bad('src="favicon.svg" alt=""', 'src="trinity-logo-with-label.svg" alt="TRINITY"')).some((s) => s.includes('triangle')), 'the name, twice')

// 3. The build uses it, and nothing reads the retired hero any more.
const config = read('vite.config.ts')
assert.match(config, /import \{ bootShell, escapeHtml \} from '\.\/scripts\/boot-shell\.ts'/)
assert.match(config, /return html\.replace\(marker, bootShell\(\)\)/)
assert.doesNotMatch(config, /messages\/en\.json/, 'the shell is not read from the retired hero')

// 4. index.html: the fallback and the site name a search result prints.
const index = read('index.html')
const fallback = index.match(/<div id="boot">[\s\S]*?<!-- \/boot -->/)?.[0] ?? ''
assert.ok(fallback, 'the marker is there to replace')
assert.doesNotMatch(fallback, /GFTernary|TNF/)
const org = index.match(/"@type": "Organization",\s*"name": "([^"]*)"/)?.[1]
assert.equal(org, SITE_NAME, 'one site name: og:site_name, the title and the Organization agree')
for (const cls of ['mark', 'cap']) assert.match(index, new RegExp(`#boot \\.${cls} \\{`), `#boot .${cls} is styled`)
assert.match(index, /#boot nav a \{/)

// 5. A built page, when there is one: the shell is in it, byte for byte.
const dist = new URL('../dist/index.html', import.meta.url)
let built = 'no dist/ (run the build to check it too)'
if (existsSync(dist)) {
  assert.ok(readFileSync(dist, 'utf8').includes(shell), 'dist/index.html carries the shell')
  built = 'dist/index.html carries it'
}

console.log(`boot-shell contract: ok (${STATIC_PAGES.length + 1} links, h1 "${MOTTO.en.headline}: ...", ${built})`)
