// The signed-out guide on BROWSER (gHashTag/trinity#1314).
//
// Signed out, BROWSER was one sentence and one button. It now says what the tab
// does once signed in and names the spec the address carries. Three things a
// wrong edit would break quietly, each checked here with a negative control:
//
//   1. the spec it prints is text from the address bar -- only a plain path
//      that the Explorer also accepts is printed, and no catalog path is lost;
//   2. each line of the guide is a claim about the signed-in view -- each is
//      pinned to the code that makes it true, so removing the behaviour fails
//      here instead of leaving the guide to describe something gone;
//   3. the link goes through the Queen's own setView, not a second address
//      builder, and the raw `spec=` never reaches the JSX.
//
//   node --experimental-strip-types qa/queen-browser-guide-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { GUIDE_SPEC_MAX, guideSpecHref, guideSpecOf } from '../src/lib/queenBrowserGuide.ts'
import { specExplorerHash } from '../src/lib/specCatalog.ts'
import { WHEEL_RENEW_MS } from '../src/lib/queenBrowser.ts'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

// The spec SPECS opens by default, read from its one home (lib/queenEmbed.ts
// imports catalogs without extensions, so plain node cannot load it).
const FEATURED_SPEC = /export const FEATURED_SPEC = '([^']+)'/.exec(read('../src/lib/queenEmbed.ts'))?.[1]
assert.equal(FEATURED_SPEC, 'specs/demos/hello_world.t27')

// ---- 1. Which spec may be printed ----------------------------------------

assert.equal(guideSpecOf(FEATURED_SPEC), FEATURED_SPEC)
assert.equal(guideSpecOf('specs/demos/hello_world.t27'), 'specs/demos/hello_world.t27')

// Every path the catalog holds is printable: the guide never hides a real spec.
const catalog = JSON.parse(read('../public/t27/manifest.json')).specs.map((s) => s.path)
assert.ok(catalog.length > 1000, `catalog read: ${catalog.length} paths`)
const hidden = catalog.filter((p) => guideSpecOf(p) !== p)
assert.deepEqual(hidden, [], `catalog paths the guide would hide: ${hidden.slice(0, 5).join(', ')}`)
const longest = Math.max(...catalog.map((p) => p.length))
assert.ok(longest < GUIDE_SPEC_MAX, `longest catalog path ${longest} < ${GUIDE_SPEC_MAX}`)

// The reason the guide has a rule of its own. The Explorer accepts a sentence
// ending in .t27 -- negative control: if it ever stopped accepting it, the
// PLAIN guard would no longer be the thing doing the work, and this says so.
const sentence = 'Paste your token here.t27'
assert.doesNotThrow(() => specExplorerHash(sentence), 'the Explorer accepts a sentence -- the guard is load-bearing')
assert.equal(guideSpecOf(sentence), null)

for (const refused of [
  null,
  undefined,
  '',
  sentence,
  'specs/demos/Send your password to me.t27',
  'https://evil.example/x.t27', // a URL
  '//evil.example/x.t27', // an empty segment
  '../secret.t27',
  'specs/../x.t27',
  'specs/./x.t27',
  'specs/x.zig', // not a spec
  'specs/x.t27\n', // a control character
  'specs/x.t27?x=1',
  'specs/%2e%2e/x.t27',
  'specs/<b>x</b>.t27',
  'specs/hell\u043e.t27', // a Cyrillic o: looks like a path, is not one
  `specs/${'a'.repeat(GUIDE_SPEC_MAX)}.t27`,
]) {
  assert.equal(guideSpecOf(refused), null, `refused: ${JSON.stringify(refused)}`)
}

// The address of the card: a Queen hash that opens SPECS on that spec.
const href = guideSpecHref(FEATURED_SPEC)
assert.equal(href, '#/queen?tab=specs&spec=specs%2Fdemos%2Fhello_world.t27')
const back = new URLSearchParams(href.slice(href.indexOf('?') + 1))
assert.equal(back.get('tab'), 'specs')
assert.equal(back.get('spec'), FEATURED_SPEC)

// ---- 2 and 3. The component and its mount --------------------------------
//
// Each pin is a function of the source, so the same function is run on a
// mutated copy and must fail there: a pin that cannot fail pins nothing.

const component = read('../src/components/QueenBrowser.tsx')
const page = read('../src/pages/Queen.tsx')

/** The signed-out branch, from its `if` to the next top-level `if (`. */
function signinBranch(src) {
  const start = src.indexOf("if (mode === 'signin' || state === 'signin') {")
  if (start < 0) return ''
  const end = src.indexOf('\n  if (', start + 1)
  return src.slice(start, end < 0 ? undefined : end)
}

const PINS = {
  // The address's spec reaches the JSX only through guideSpecOf.
  'spec is printed only through guideSpecOf': (src) => {
    const b = signinBranch(src)
    return /const named = guideSpecOf\(spec\)/.test(b) && /<code>\{named\}<\/code>/.test(b) && !/\{spec\}/.test(src)
  },
  // The link: a press goes to the Queen's setView; the href is for a new tab.
  'a press goes through onReadSpec': (src) => {
    const b = signinBranch(src)
    return /href=\{guideSpecHref\(named\)\}/.test(b) && /e\.preventDefault\(\)\s*\n\s*onReadSpec\(named\)/.test(b)
  },
  // All three lines are drawn, before the sign-in sentence.
  'three lines, then the sign-in sentence': (src) => {
    const b = signinBranch(src)
    const at = ['{c.guideLive}', '{c.guideJournal}', '{c.guidePasswords}', '{c.signin}', '{c.openInApp}'].map((k) => b.indexOf(k))
    return at.every((i, n) => i >= 0 && (n === 0 || i > at[n - 1]))
  },
  // guideLive: signed in, the person's own browser is framed, driven by the agent.
  'guideLive is true: the live view frames the browser': (src) =>
    /className="queen27-browser-frame"/.test(src) && /frameSrcOf\(view\?\.viewUrl/.test(src),
  // guideJournal: steps listed under the window; a press takes the wheel; a button hands it back.
  'guideJournal is true: journal under the window, wheel taken and handed back': (src) =>
    /readJournal\(brokerEnv\)/.test(src) &&
    /className="queen27-browser-journal"/.test(src) &&
    src.indexOf('<iframe') < src.indexOf('className="queen27-browser-journal"') &&
    /addEventListener\('pointerdown', takeTheWheel, true\)/.test(src) &&
    /onClick=\{handBack\}/.test(src),
  // guidePasswords: nothing on this view can take a password.
  'guidePasswords is true: no field on this view': (src) =>
    !/<input\b|<textarea\b|contentEditable|type="password"/i.test(src),
}

const MUTATIONS = {
  'spec is printed only through guideSpecOf': (src) => src.replace('<code>{named}</code>', '<code>{spec}</code>'),
  'a press goes through onReadSpec': (src) => src.replace(/e\.preventDefault\(\)\s*\n\s*onReadSpec\(named\)/, 'onReadSpec(named)'),
  'three lines, then the sign-in sentence': (src) => src.replace('<li>{c.guideJournal}</li>', ''),
  'guideLive is true: the live view frames the browser': (src) => src.replace('className="queen27-browser-frame"', 'className="queen27-browser-shot"'),
  'guideJournal is true: journal under the window, wheel taken and handed back': (src) =>
    src.replace("w.addEventListener('pointerdown', takeTheWheel, true)", ''),
  'guidePasswords is true: no field on this view': (src) => src.replace('{c.guideReadSpec}', '{c.guideReadSpec}<input type="password" />'),
}

// "until you hand it back or leave it untouched for ten minutes": the lease
// is the server's (lib/queenBrowser.ts states it, 999 render sessions.ts
// holds it); a touch renews it, and only if renewing is more frequent than
// the lease is "while you use it" true.
const lib = read('../src/lib/queenBrowser.ts')
assert.match(lib, /touching the picture takes the wheel for a ten-minute\s*\n?\s*\*?\s*lease/)
assert.ok(WHEEL_RENEW_MS < 10 * 60_000, `a touch renews the lease (${WHEEL_RENEW_MS} ms) before it lapses (600000 ms)`)
assert.match(page, /browserGuideJournal: "[^"]*ten minutes\."/)
assert.match(page, /browserGuideJournal: "[^"]*\u0434\u0435\u0441\u044f\u0442\u044c \u043c\u0438\u043d\u0443\u0442[^"]*"/)

for (const [name, pin] of Object.entries(PINS)) {
  assert.ok(pin(component), `QueenBrowser.tsx: ${name}`)
  const mutated = MUTATIONS[name](component)
  assert.notEqual(mutated, component, `negative control for "${name}" changed nothing -- its anchor moved`)
  assert.ok(!pin(mutated), `negative control: "${name}" still passes on a broken copy`)
}

// The mount passes the address's raw spec and the Queen's own setView.
const mount = page.slice(page.indexOf('<QueenBrowser'), page.indexOf('/>', page.indexOf('<QueenBrowser')))
assert.match(mount, /spec=\{hashParams\.get\("spec"\)\}/)
assert.match(mount, /onReadSpec=\{\(named\) => setView\("specs", named\)\}/)
for (const key of ['guideTitle', 'guideLive', 'guideJournal', 'guidePasswords', 'guideSpec', 'guideReadSpec']) {
  const copyKey = `browser${key[0].toUpperCase()}${key.slice(1)}`
  assert.match(mount, new RegExp(`${key}: c\\.${copyKey},`), `mount passes ${key}`)
  // Both languages carry it, and the Russian one is Russian.
  const values = [...page.matchAll(new RegExp(`^\\s+${copyKey}: "([^"]+)",$`, 'gm'))].map((m) => m[1])
  assert.equal(values.length, 2, `${copyKey}: en and ru (found ${values.length})`)
  assert.ok(!/[\u0400-\u04ff]/.test(values[0]) && /[\u0400-\u04ff]/.test(values[1]), `${copyKey}: en first, ru second`)
}

console.log(
  `queen-browser-guide: PASS -- ${catalog.length} catalog paths printable (longest ${longest}), ` +
    `${Object.keys(PINS).length} pins each red on its negative control`,
)
