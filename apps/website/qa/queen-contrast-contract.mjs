// CAN THE HUD BE READ WHILE THE MAP IS LIT?
//
// The owner's report, 2026-09-21, with a photograph of the clients strip:
// "тускло! сделай видимость лучше" — it is dim, make it more visible. The
// picture shows the filter chips with the honeycomb running straight through
// the words, a hex line crossing every second glyph.
//
// The Queen's board draws every panel over a LIVE field: a hex hive, a
// starfield, and cells that light gold, green and red. So every colour on this
// page has two contrasts, not one — the one over empty sky, which is always
// fine, and the one over the brightest thing the field can put underneath it,
// which is the one nobody checks by looking. Three separate CSS comments in
// Queen.css record somebody raising an alpha because a panel "was legible only
// where the map happened to be empty". Raising it by eye is how you get four
// different alphas and no statement of what any of them buys.
//
// This gate does the arithmetic instead. It reads the tokens out of the
// stylesheet, composites each ground over a field at FULL brightness, puts the
// text colour on that, and applies WCAG 2.1 relative luminance. A colour pair
// that cannot clear its threshold with the hive at its loudest does not ship.
//
// White is the bound for the field. The hive's own brightest paint is gold
// (#ffd700, L=0.699) and the starfield's is white (L=1.0), so white is both the
// true upper bound and the simple thing to state.
//
// The second half of the gate is about WHERE a ground may be written. The veil
// under the content surfaces was fifteen hand-written rgba() literals ranging
// from 0.42 to 0.86, which is fifteen independent chances to be wrong and no
// way to fix them together. There is one token now, and this refuses a
// sixteenth literal.
//
// ── WHAT 2026-09-21 ADDED, AND WHY THE GATE MISSED THE PHOTOGRAPH ────────────
//
// The owner sent a second photograph the same day, of the DIRECTION row this
// time, with the same complaint. Everything above had passed. Three reasons,
// each a blind spot rather than a wrong number:
//
// 1. SCOPE. This file read one stylesheet, `src/pages/Queen.css`. SEVENTEEN
//    stylesheets draw this board. The chip in the photograph was measured; the
//    row it sits in is in the same file, but `.mcp-cmd`, `.queen-chat-tab`,
//    `.queen-universe-nav` and a dozen others were never looked at by anything.
//    The list is no longer written down: the gate walks the import graph from
//    the page's own route entry and checks whatever it finds, so a stylesheet
//    added to the board tomorrow is under the gate the moment it is imported.
//
// 2. GROUND DETECTION. The pattern below used to match a literal `rgba(...)`
//    and nothing else, so every ground written `var(--hud-panel)` was invisible
//    to it — including, exactly, the chip the owner photographed. Grounds are
//    now resolved through the token table and through `#rgb`/`#rgba`/`#rrggbb`/
//    `#rrggbbaa`, which is how `.queen-hive-zoom-hint` (`#041115a0`) had gone
//    unmeasured since it was written.
//
// 3. THE BLUR LAW. It existed as one by-name assertion about one selector, and
//    it is the half of the treatment that actually answers this complaint.
//    Contrast arithmetic models a backdrop as one flat colour. The hive is not
//    one: it is a lattice. A ground at 0.88 measures 9.90:1 and still passes 12%
//    of that lattice THROUGH ITS PATTERN INTACT, and a hexagon edge crossing a
//    letterform reads as a stroke of the letter. Alpha scales the backdrop's
//    amplitude and leaves its spatial frequency alone; `backdrop-filter: blur()`
//    is the only declaration here that touches the frequency. So a translucent
//    dark ground that carries text now owes a low pass — on itself, or on a
//    named ancestor that is checked to still have one.
//
// The roster this replaces is the defect it is named for. Queen.css keeps a
// hand-written `:is(...)` list of everything that gets frosted, with a note
// above it saying "a new row above the board belongs on this list the day it is
// added". Four chrome rows sit in the board stack; the outer two were built
// with both halves of the treatment and the two between them with neither, and
// the same omission had happened five more times where nobody had taken a
// photograph. A list kept by whoever last looked at the screen is a list that
// is wrong between photographs.

import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, relative } from 'node:path'
import assert from 'node:assert/strict'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..')

// ── the board's own stylesheets, derived rather than listed ──────────────────

// main.tsx routes /queen at pages/QueenUniverse.tsx, which is the outer shell:
// it mounts the board, the atlas and the shared core, and Queen.tsx is what
// puts `queen-shell` on <body>. Starting the walk anywhere else silently loses
// a quarter of the board — starting it at Queen.tsx finds 13 of the 17, and the
// four it misses are named rather than counted, because a count cannot be
// checked: QueenSharedCore.css, QueenSpecTreasury.css, QueenUniverseAtlas.css
// and QueenUniverse.css. The last of those is the world bar, which was the
// thinnest text ground on the whole page at 0.42.
//
// The second root is the same mistake one level up, found the same way. The
// board is not the only page that mounts the hive: App.tsx renders
// QueenHeroBlock, which mounts the same QueenCatalogHive -> QueenCombBabylon
// with foundationVisible and fitInset 0 — a live lattice on the public
// landing, above the fold. Its stats carried a 0.72 ground and no blur at all,
// and this gate could not have said so, because a walk from QueenUniverse.tsx
// never opens QueenHeroBlock.css. It reported "17 stylesheets walked" and was
// telling the truth about the seventeen; the sentence a reader took from it was
// about the site. A gate rooted at one page is honest about one page and
// silent about the rest, and silence here had been reading as approval.
const ENTRIES = [
  resolve(root, 'src/pages/QueenUniverse.tsx'),
  resolve(root, 'src/App.tsx'),
]

const EXTENSIONS = ['', '.tsx', '.ts', '.css', '/index.tsx', '/index.ts']

/** Vite's own resolution, reduced to what this codebase actually writes. */
function resolveSpecifier(from, spec) {
  if (!spec.startsWith('.')) return null
  const base = resolve(dirname(from), spec)
  for (const ext of EXTENSIONS) {
    const candidate = base + ext
    if (existsSync(candidate)) return candidate
  }
  return null
}

// `from "./x"`, `import "./x.css"` and `import("./x")` — the third is the one
// that matters, because every heavy part of this board is lazy.
//
// Run over the raw text, so an import somebody has commented out is still
// walked. Left that way on purpose: the error it makes is to measure a sheet
// the app has stopped loading, which costs a failure on dead CSS and never a
// silent pass on live CSS. The one thing it will not notice is a surface
// switched off by commenting its import out -- and a surface that paints
// nothing cannot fail a contrast test anyway.
const SPECIFIER = /(?:from\s*|import\s*\(\s*|import\s+)["'](\.[^"']+)["']/g

// A stylesheet can load a stylesheet, and this walk used to stop the moment it
// reached one -- every `.css` was a leaf. QueenCatalogHive.css opens with two
// `@import` lines, and the hive is mounted by the LANDING as well as by the
// board, so the landing loads the whole of Queen.css and every surface in it.
// Walking from src/App.tsx and stopping at the first stylesheet said otherwise.
// That is the same defect as rooting the walk at one page, one level down: a
// boundary drawn by the parser rather than by the app, reading as approval.
const CSS_IMPORT = /@import\s+(?:url\(\s*)?["'](\.[^"']+)["']/g

/** Every stylesheet reachable from one entry, by the walk above. */
function sheetsFrom(entry) {
  const found = []
  const seen = new Set()
  const stack = [entry]
  while (stack.length) {
    const file = stack.pop()
    if (seen.has(file)) continue
    seen.add(file)
    const isCss = file.endsWith('.css')
    if (isCss) found.push(file)
    else if (!/\.tsx?$/.test(file)) continue
    const text = readFileSync(file, 'utf8')
    for (const match of text.matchAll(isCss ? CSS_IMPORT : SPECIFIER)) {
      const target = resolveSpecifier(file, match[1])
      if (target && !seen.has(target)) stack.push(target)
    }
  }
  return found
}

const perRoot = ENTRIES.map((entry) => [entry, sheetsFrom(entry)])
const sheetPaths = [...new Set(perRoot.flatMap(([, found]) => found))].sort()

/** Every stylesheet each root reaches, written out by name.
 *
 *  A floor on a count stood here, and a count is the wrong instrument twice
 *  over. `>= 20` against a union of 26 let the walk lose a fifth of the board
 *  and still pass, and no count can say WHICH sheet went missing, which is the
 *  only thing the person reading the failure needs. This gate walked one root
 *  for months while the landing page's hive sat unmeasured above the fold, and
 *  the count it printed was true the whole time.
 *
 *  Both directions are asserted. A name here the walk no longer reaches is an
 *  import that broke, and the message says which sheet and from which root. A
 *  sheet the walk reaches that is not named here is a surface nobody has
 *  decided about, and it fails asking to be added -- which is what keeps this
 *  list from going stale, and a stale list is a count with extra steps.
 *
 *  Per root rather than as one union, because the two overlap in the shared
 *  core and a union cannot tell "still loaded by the board" from "still loaded
 *  by the landing". Telling those apart is the whole reason there are two
 *  roots. The union needs no assertion of its own: it is the union of two sets
 *  now fixed by name, so it cannot move without one of these failing first. */
const REACHED = {
  'src/pages/QueenUniverse.tsx': [
    /* Arrived with the BROWSER view in #1088 and was registered here because
       this list refused to pass without it -- which is the whole argument for
       keeping the list instead of a count, made on the first sheet to land
       after it was written. */
    'src/components/QueenBrowser.css',
    'src/components/QueenCatalogHive.css',
    'src/components/QueenCellStage.css',
    'src/components/QueenChat.css',
    'src/components/QueenCombEmbedded.css',
    'src/components/QueenContext.css',
    'src/components/QueenIntel.css',
    'src/components/QueenLoading.css',
    'src/components/QueenMcp.css',
    'src/components/QueenSharedCore.css',
    'src/components/QueenSpecTreasury.css',
    'src/components/QueenTri.css',
    'src/components/QueenUniverseAtlas.css',
    'src/components/QueenWars.css',
    'src/pages/Queen.css',
    'src/pages/QueenUniverse.css',
    'src/pages/passport.css',
    'src/pages/queen-phone.css',
    /* The ROADMAP view, #1092, landed on main while this gate was being
       written and failed it on the first run -- which is the second sheet in a
       row to arrive after the list was introduced and be caught by it. Its
       surfaces are grounded below with the rest of the board's, because a view
       that renders inside .queen27-hud-vp-body sits over the same hive every
       other view does, and arriving three days later does not exempt it. */
    'src/components/queenRoadmap.css',
  ],
  'src/App.tsx': [
    'src/components/AgiGameBlock.css',
    'src/components/FaqBlock.css',
    'src/components/GameHero.css',
    'src/components/ModuleHeroBlock.css',
    'src/components/ModulesBlock.css',
    'src/components/PlayBlock.css',
    'src/components/PlayLine.css',
    'src/components/QueenCatalogHive.css',
    'src/components/QueenCellStage.css',
    'src/components/QueenChat.css',
    'src/components/QueenCombEmbedded.css',
    'src/components/QueenHeroBlock.css',
    'src/components/SpecHeroBlock.css',
    /* Not imported by any component on the landing page. They arrive through
       the two `@import` lines at the top of QueenCatalogHive.css, which is what
       makes them the proof that walking stylesheets matters: the landing loads
       the entire board palette and every surface Queen.css declares, and until
       the walk followed a stylesheet's own imports this root claimed it did
       not. */
    'src/pages/Queen.css',
    'src/pages/queen-phone.css',
  ],
}

for (const [entry, found] of perRoot) {
  const name = relative(root, entry)
  const expected = REACHED[name]
  assert.ok(
    expected,
    `${name} is walked as an entry but has no list in REACHED -- ` +
      'add one naming every stylesheet it loads, or this root is measured with nothing asked of it',
  )
  const walked = new Set(found.map((sheet) => relative(root, sheet)))
  const missing = expected.filter((sheet) => !walked.has(sheet))
  const unlisted = [...walked].filter((sheet) => !expected.includes(sheet)).sort()
  assert.equal(
    missing.length,
    0,
    `${name} no longer reaches ${missing.join(', ')} -- ` +
      'either an import broke and that sheet is now unmeasured, or it was removed on purpose ' +
      'and the list above is what records the decision',
  )
  assert.equal(
    unlisted.length,
    0,
    `${name} now reaches ${unlisted.join(', ')}, which this gate has never measured -- ` +
      `add each one to REACHED['${name}'] so a later import break fails by name`,
  )
}

/** Comments out, whitespace in: brace matching below must not meet a `{` that
    somebody wrote inside a sentence, and this file is full of sentences that
    quote selectors. Replacing the comment with spaces of the same length keeps
    every reported line number honest.

    The one thing a comment in those stylesheets may not contain is the sequence
    that ends it, and a glob is the way it gets written by accident: a sentence
    saying the census covered `src` slash star star slash star dot tsx ends the
    comment at the second star-slash, and everything after it is read as CSS.
    That costs a confusing failure rather than a silent pass — the tail lands in
    the next rule's selector list and arrives here as junk subjects with half a
    paragraph in the name — but it is worth knowing on sight, because the last
    theory about this parser to be written down (that a comma in a comment
    manufactures subjects) was wrong, and looked exactly like this. Commas are
    fine. Spell the glob in words. */
const decomment = (text) => text.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '))

const SHEETS = sheetPaths.map((path) => {
  const text = decomment(readFileSync(path, 'utf8'))
  return { path, name: relative(root, path), text }
})

const sheet = (name) => {
  const found = SHEETS.find((s) => s.name === name)
  assert.ok(found, `${name} is no longer reachable from the board's route entry`)
  return found
}

// Sections 1 and 3 are about tokens and about named rules, and both live in
// Queen.css — it is the file that declares the palette.
const css = sheet('src/pages/Queen.css').text

// ── colour ───────────────────────────────────────────────────────────────────

/** A channel: `255`, or `100%` of 255. */
function channel(text) {
  const pct = /^([-+]?[\d.]+)%$/.exec(String(text).trim())
  return pct ? (Number(pct[1]) / 100) * 255 : Number(text)
}

/** An alpha: `0.72`, or the same alpha written `72%`. Absent means opaque. */
function alphaOf(text) {
  if (text === undefined) return 1
  const pct = /^([-+]?[\d.]+)%$/.exec(String(text).trim())
  return pct ? Number(pct[1]) / 100 : Number(text)
}

/** CSS Color 4's hsl -> rgb. Hue in degrees, bare or with `deg`; saturation
    and lightness as percentages, which is the only way CSS spells them. */
function hslToRgb(h, s, l) {
  const hue = ((Number(String(h).replace(/deg$/i, '')) % 360) + 360) % 360
  const sat = Number(String(s).replace('%', '')) / 100
  const lig = Number(String(l).replace('%', '')) / 100
  const f = (n) => {
    const k = (n + hue / 30) % 12
    const a = sat * Math.min(lig, 1 - lig)
    return (lig - a * Math.max(-1, Math.min(k - 3, 9 - k, 1))) * 255
  }
  return { r: f(0), g: f(8), b: f(4) }
}

/** `rgba(2, 8, 6, 0.72)` / `rgb(1 2 3)` / `#ffd700` / `#041115a0` / `#000b`
    -> {r,g,b,a} in 0..255,0..1. The short and the 8-digit forms are here
    because the board writes both: `#000b` grounds the catalog region and
    `#041115a0` grounds the zoom hint, and neither was a colour this gate could
    read until they were measured and found thin.

    The percentage and `hsl()` forms are here for a harder reason, and it is the
    reason this function deserves more care than its size suggests. A syntax
    this parser cannot read yields no ground, and a ground this gate cannot see
    is a ground it PASSES -- so the set of colour notations understood here is,
    exactly, the set of ways a translucent surface on this board is allowed to
    be written. Nobody chose that set; it accreted. `rgb(2 8 6 / 20%)` and
    `rgba(2 8 6 / 0.2)` are the modern spelling of the one notation this file
    did read, and both sailed through at alpha 0.2 while the comma spelling of
    the identical colour failed at 1.44:1 -- the gate answering a question about
    punctuation when it was asked one about legibility.

    Reading more notations narrows that hole; it does not close it, because CSS
    will add another. What closes it is the census at the foot of section 1,
    which fails on any `background` this function still cannot read instead of
    letting it through. Widen the parser when the board needs a notation, and
    let the census be the thing that notices. */
function parseColor(text) {
  const hex = /^#([0-9a-f]{3,8})$/i.exec(text.trim())
  if (hex) {
    const d = hex[1]
    const wide = d.length <= 4 ? d.split('').map((c) => c + c).join('') : d
    assert.ok(wide.length === 6 || wide.length === 8, `not a hex colour: ${text}`)
    const n = parseInt(wide.slice(0, 6), 16)
    return {
      r: (n >> 16) & 255,
      g: (n >> 8) & 255,
      b: n & 255,
      a: wide.length === 8 ? parseInt(wide.slice(6), 16) / 255 : 1,
    }
  }
  const fn = /^(rgba?|hsla?)\(([^)]+)\)$/i.exec(text.trim())
  assert.ok(fn, `not a colour this gate can read: ${text}`)
  const parts = fn[2].split(/[,/\s]+/).filter(Boolean)
  assert.ok(parts.length === 3 || parts.length === 4, `odd colour: ${text}`)
  const rgb = /^hsl/i.test(fn[1])
    ? hslToRgb(parts[0], parts[1], parts[2])
    : { r: channel(parts[0]), g: channel(parts[1]), b: channel(parts[2]) }
  const a = alphaOf(parts[3])
  const finite = [rgb.r, rgb.g, rgb.b, a].every((n) => Number.isFinite(n))
  assert.ok(finite, `odd colour: ${text}`)
  return { ...rgb, a }
}

/** `over` is opaque. Returns the opaque result of painting `top` on it. */
function composite(top, over) {
  return {
    r: top.a * top.r + (1 - top.a) * over.r,
    g: top.a * top.g + (1 - top.a) * over.g,
    b: top.a * top.b + (1 - top.a) * over.b,
    a: 1,
  }
}

/** WCAG 2.1 relative luminance. */
function luminance({ r, g, b }) {
  const lin = (c) => {
    const s = c / 255
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
  }
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

function contrast(fg, bg) {
  const a = luminance(fg)
  const b = luminance(bg)
  const [hi, lo] = a > b ? [a, b] : [b, a]
  return (hi + 0.05) / (lo + 0.05)
}

// The field at its loudest, and the sky behind it when it is quiet. Every pair
// below is measured against BOTH, because a colour that only works over a lit
// hive is the same defect pointing the other way.
const LIT = { r: 255, g: 255, b: 255, a: 1 }
const DARK = { r: 0, g: 0, b: 0, a: 1 }

// ── the tokens, read from the stylesheet ─────────────────────────────────────

function token(name) {
  const rule = new RegExp(`--${name}:\\s*([^;]+);`).exec(css)
  assert.ok(rule, `the stylesheet no longer defines --${name}`)
  return parseColor(rule[1])
}

const PANEL = token('hud-panel')
const VEIL = token('hud-veil')
const NAV = token('hud-nav')
const MUTED = token('hud-muted')
const GOLD = token('hud-gold')
const GREEN = token('hud-green')
const CYAN = token('hud-cyan')

/** Every custom property on the board that holds a colour, from every sheet,
    so a ground written `var(--hud-panel)` resolves to the same number the
    section above measures.

    Declared here and FILLED further down, once the rules are parsed, and the
    move is the point rather than tidying. This table was built from raw sheet
    text, which has no notion of the selector a declaration sits on -- and a
    custom property is inherited, so the selector is the whole question of
    whether a declaration reaches this board at all. See TOKEN_SCOPES. */
const TOKENS = new Map()
const recordTokens = (text) => {
  for (const match of text.matchAll(/(--[\w-]+)\s*:\s*([^;{}]+);/g)) {
    const name = match[1]
    if (TOKENS.has(name)) continue
    // Stored as the raw text in every case. A custom property is a token
    // stream, not a value: `--hive-task-rgb: 255 77 94` is not a colour and is
    // not nonsense either, it is three quarters of one, and the sheet that
    // declares it writes `rgb(var(--hive-task-rgb) / .18)` two lines later.
    // Parsing at declaration time threw that shape away; substituting the text
    // and parsing the RESULT keeps it.
    TOKENS.set(name, match[2].trim())
  }
}
/** The site palette, which the board inherits and never declares.
 *
 *  Every custom property above comes from a sheet the walk reached, and the
 *  walk starts at two components. `src/index.css` is loaded by main.tsx, above
 *  both of them, and it holds `--text`, `--muted`, `--border`, `--accent` and
 *  the rest of the site's `:root` — so the board's own stylesheets write
 *  `var(--muted, #8b9490)` and this table had no `--muted` in it at all.
 *
 *  The consequence was not a missing measurement, which would have been
 *  visible. It was a WRONG one: with the name unknown, `colorOf` falls to the
 *  fallback written beside it, and a fallback beside a declared token is dead
 *  text -- it is what somebody thought the colour was, which is a different
 *  thing from what the browser paints. This gate read the TRI chips as
 *  `#8b9490` at 1.74:1 and reported that number in a failure; the ink on the
 *  screen was `#888888` at 1.53:1. Both fail, so the defect was found anyway,
 *  and that is luck rather than method: the same shape with a fallback LIGHTER
 *  than the token hides a real failure instead of exaggerating one. 31 refs on
 *  this board resolved to their fallback that way, and 96 more to nothing.
 *
 *  Read last and only where a name is still missing, because `:root` on the
 *  document is the outermost ancestor and anything nearer the element wins.
 *  "Nearer" is the word that was doing unexamined work here: the sentence used
 *  to say ANY board sheet that declares the name is nearer, and a sheet is not
 *  an ancestor -- `.pp` declares `--accent` and is a sibling route. That is
 *  what TOKEN_SCOPES is for, and only the declarations it admits are read
 *  before this file.
 *
 *  Listed by name rather than walked, because walking from main.tsx would pull
 *  in every page on the site and measure the whole of it under a gate that is
 *  about one board. Read through the same parser as every other sheet and
 *  filtered the same way, so the palette gets no privilege the board's own
 *  sheets do not have. */
const GLOBAL_PALETTE = ['src/index.css']

/** The text inside `name(` ... `)`, bracket-balanced, because an argument is
    very often itself an `rgba(...)` and a lazy `[^)]*` stops at its first
    bracket — which reads `var(--hud-panel, rgba(2, 8, 6, 0.62))` as the
    fallback `rgba(2, 8, 6, 0.62` and then throws on it. Written for `var` and
    generalised when `color-mix` turned up carrying a `var()` of its own, which
    is the same trap one level deeper. */
function readFn(value, name) {
  const open = `${name}(`
  const start = value.indexOf(open)
  if (start < 0) return null
  let depth = 0
  for (let i = start + open.length - 1; i < value.length; i += 1) {
    if (value[i] === '(') depth += 1
    else if (value[i] === ')') {
      depth -= 1
      if (depth === 0) return value.slice(start + open.length, i)
    }
  }
  return null
}

const readVar = (value) => readFn(value, 'var')

/** Commas at bracket depth 0. `rgba(2, 8, 6, 0.6)` sitting in an argument list
    is one argument, not four, and both callers below get that wrong without
    this. */
function topLevelCommas(text) {
  const out = []
  let depth = 0
  let last = 0
  for (let i = 0; i < text.length; i += 1) {
    if (text[i] === '(') depth += 1
    else if (text[i] === ')') depth -= 1
    else if (text[i] === ',' && depth === 0) {
      out.push(text.slice(last, i))
      last = i + 1
    }
  }
  out.push(text.slice(last))
  return out.map((s) => s.trim())
}

const TRANSPARENT = { r: 0, g: 0, b: 0, a: 0 }

/** `color-mix(in srgb, <colour> N%, transparent)` — CSS Color 5, reduced to the
    one shape this board writes, and it writes it on the surface the owner sent
    a photograph of. `.queen27-card[data-dir]` tints a direction card with 7% of
    its hue over nothing at all; the mix is therefore a 0.07 ground, over a live
    hive, under a card's worth of text. This gate read it as no ground and said
    nothing, twice, across both of the changes that were meant to answer that
    photograph.

    Premultiplied, per the spec: mix the channels weighted by alpha, then divide
    the alpha back out. Mixing straight RGB drags every colour toward black as
    soon as one side is `transparent`, because transparent IS black in CSS --
    the very case this board writes. */
function mixColor(args, depth) {
  const parts = topLevelCommas(args)
  if (parts.length !== 3) return null
  if (!/^in\s+srgb$/i.test(parts[0])) return null
  const side = (part) => {
    const pct = /\s([\d.]+)%$/.exec(part)
    const body = (pct ? part.slice(0, pct.index) : part).trim()
    const color = /^transparent$/i.test(body) ? TRANSPARENT : colorOf(body, depth + 1)
    return color ? { color, weight: pct ? Number(pct[1]) / 100 : null } : null
  }
  const a = side(parts[1])
  const b = side(parts[2])
  if (!a || !b) return null
  let wa = a.weight
  let wb = b.weight
  if (wa === null && wb === null) [wa, wb] = [0.5, 0.5]
  else if (wa === null) wa = 1 - wb
  else if (wb === null) wb = 1 - wa
  const sum = wa + wb
  if (!(sum > 0)) return null
  wa /= sum
  wb /= sum
  const alpha = wa * a.color.a + wb * b.color.a
  if (!(alpha > 0)) return TRANSPARENT
  const mix = (k) => (wa * a.color.a * a.color[k] + wb * b.color.a * b.color[k]) / alpha
  return { r: mix('r'), g: mix('g'), b: mix('b'), a: alpha }
}

const COLOR_LITERAL = /(#[0-9a-f]{3,8}\b|(?:rgba?|hsla?)\([^)]*\))/i

/** Every `var()` in a value replaced by the text it stands for, or null if any
 *  of them names a token this gate has never seen and carries no fallback.
 *
 *  Textual, and only textual, because `var()` in CSS is textual: it substitutes
 *  a token stream and the result is parsed afterwards. Resolving a var to a
 *  COLOUR, which is what this used to do, can only read the var when it IS the
 *  whole value. `rgb(var(--hive-task-rgb) / .18)` puts three channels inside a
 *  colour function and the alpha outside it, and the old code walked straight
 *  past that to the literal matcher, which stopped at the first `)` and threw.
 *  The catalog cell, the hive display and both direction cards were unreadable
 *  for that one reason.
 *
 *  Four passes, so a token whose value is another `var()` resolves and a token
 *  that names itself stops. A fallback is used ONLY when the name is unknown,
 *  which is the cascade's rule and not this file's preference -- a fallback
 *  beside a declared token never paints, and treating it as the colour is how
 *  this gate came to report a grey the browser does not use. */
function substituteVars(text, depth) {
  let out = text
  for (let pass = 0; pass <= 4 - depth && out.includes('var('); pass += 1) {
    const start = out.indexOf('var(')
    const inner = readFn(out.slice(start), 'var')
    if (inner === null) return null
    const args = topLevelCommas(inner)
    const known = TOKENS.get(args[0])
    const fallback = args.length > 1 ? args.slice(1).join(', ') : null
    const replacement = known === undefined ? fallback : known
    if (replacement === null || replacement === undefined) return null
    out = out.slice(0, start) + replacement + out.slice(start + 4 + inner.length + 1)
  }
  return out.includes('var(') ? null : out
}

/** The colour a `background:` value paints, or null if this gate cannot say. */
function colorOf(value, depth = 0) {
  if (depth > 4) return null
  let text = value.replace(/!important/g, '').trim()
  if (text.includes('var(')) {
    const substituted = substituteVars(text, depth)
    if (substituted === null) return null
    text = substituted.trim()
  }
  if (/^transparent$/i.test(text)) return TRANSPARENT
  if (/^color-mix\(/i.test(text)) {
    const args = readFn(text, 'color-mix')
    return args === null ? null : mixColor(args, depth)
  }
  const literal = COLOR_LITERAL.exec(text)
  if (!literal) return null
  try {
    return parseColor(literal[1])
  } catch {
    return null
  }
}

/** EVERY colour a `background:` value paints, in the order written.
 *
 *  `colorOf` answers with the first one, which is the right answer for a flat
 *  fill and the wrong one for a gradient -- and this board grounds surfaces
 *  with gradients. `.queen-hive-display` runs a red wash into
 *  `rgba(3, 14, 18, 0.44)` at 56% and back out, and the reader of that cell's
 *  text is looking at the middle stop. Taking the first stop reported a light
 *  tint, which `groundsIn` then correctly declined as not-a-ground, so a 0.44
 *  dark ground over a live hive went unmeasured because of where it sat in a
 *  list. Every stop is a surface some pixel of that element actually has. */
function colorsIn(value, depth = 0) {
  if (depth > 4) return []
  let text = value.replace(/!important/g, '').trim()
  if (text.includes('var(')) {
    const substituted = substituteVars(text, depth)
    if (substituted === null) return []
    text = substituted.trim()
  }
  const out = []
  // `transparent` IS a colour — `rgba(0, 0, 0, 0)` — and it appears both as a
  // whole value and as a gradient stop. Spelling it out here rather than
  // special-casing the whole-value form keeps a gradient that fades to nothing
  // readable instead of unreadable.
  let rest = text.replace(/\btransparent\b/gi, 'rgba(0, 0, 0, 0)')
  while (rest) {
    const mix = /color-mix\(/i.exec(rest)
    const literal = COLOR_LITERAL.exec(rest)
    if (mix && (!literal || mix.index < literal.index)) {
      const args = readFn(rest.slice(mix.index), 'color-mix')
      if (args === null) break
      const color = mixColor(args, depth)
      if (color) out.push(color)
      rest = rest.slice(mix.index + 'color-mix('.length + args.length + 1)
      continue
    }
    if (!literal) break
    try {
      out.push(parseColor(literal[1]))
    } catch {
      // Not a colour after all — a hex-looking id, a function this gate cannot
      // read. Skip it and keep scanning; the census decides about the value.
    }
    rest = rest.slice(literal.index + literal[1].length)
  }
  return out
}

// ── 1. every ground carries its text over a lit field ────────────────────────

// 4.5 is WCAG AA for body text, and everything in this HUD is body text: the
// whole interface is 0.6-0.72rem mono. 3.0 is the large-text threshold and is
// allowed only for the status hues, which appear as headline numbers and bold
// one-word states, never as a sentence.
const GROUNDS = [
  { name: '--hud-panel', color: PANEL },
  { name: '--hud-veil', color: VEIL },
  { name: '--hud-nav', color: NAV },
]
const INKS = [
  { name: '--hud-muted', color: MUTED, min: 4.5, why: 'every label, note and sub-line on the board' },
  { name: '--hud-gold', color: GOLD, min: 3.0, why: 'headline numbers and the private badge' },
  { name: '--hud-green', color: GREEN, min: 3.0, why: 'live states' },
  { name: '--hud-cyan', color: CYAN, min: 3.0, why: 'research states' },
]

const table = []
for (const ground of GROUNDS) {
  for (const ink of INKS) {
    for (const [field, fieldName] of [[LIT, 'lit'], [DARK, 'dark']]) {
      const bg = composite(ground.color, field)
      const fg = composite(ink.color, bg)
      const ratio = contrast(fg, bg)
      table.push({ ground: ground.name, ink: ink.name, field: fieldName, ratio })
      assert.ok(
        ratio >= ink.min,
        `${ink.name} on ${ground.name} over a ${fieldName} field is ${ratio.toFixed(2)}:1, ` +
          `below the ${ink.min}:1 this text needs (${ink.why}). ` +
          `Raise the ground's alpha or the ink's, in the token — not in the rule that noticed.`,
      )
    }
  }
}

// The pressed chip is the one control on this board whose colour and ground are
// BOTH written down, and it has been broken twice by a layer that restyled one
// of them. Gold ground, near-black ink: check the pair as shipped.
{
  const ratio = contrast(parseColor('#050505'), parseColor('#d9a441'))
  assert.ok(ratio >= 4.5, `the pressed chip reads ${ratio.toFixed(2)}:1`)
}

// The veil is meant to stay LIGHTER than a panel — that difference is the whole
// reason there are two tokens. A veil that creeps up to the panel's alpha is a
// board with no map under it, which is a different complaint from the same
// person.
assert.ok(
  VEIL.a < PANEL.a,
  `--hud-veil (${VEIL.a}) must stay lighter than --hud-panel (${PANEL.a}): content lets the map through, chrome does not`,
)
assert.ok(VEIL.a >= 0.6, `--hud-veil at ${VEIL.a} cannot carry --hud-muted over a lit hive`)

// ── 2. every ground on the board carries text too ────────────────────────────

// The first draft of this section banned literals outright, which was the wrong
// rule twice over: it flagged 52 places, of which 39 were translucent TINTS
// (rgba(255,255,255,0.04) on a chip, a green wash on a lit cell) that are
// painted ON a ground and carry no text at all — and banning a number does not
// say what is wrong with it. The rule below does the same arithmetic as section
// 1 on every dark translucent ground on the board, so a ground is allowed
// exactly when it is legible, and the failure prints the ratio rather than a
// style preference.
//
// One thing this does NOT do, stated so the number is not read as more than it
// is: it measures every ground against --hud-muted rather than against whatever
// ink that particular rule sets. --hud-muted is the LIGHTEST ink on the board,
// so the claim is one-directional and sound — a ground that fails here fails
// for every ink on it — but passing here is necessary, not sufficient.
// .queen-starfield-source is the worked example: it scored 4.24:1 against
// --hud-muted and 3.41:1 against its own #b9cad5.

/** Every `{ ... }` in a stylesheet, with at-rules walked into rather than
    treated as rules of their own. The old splitter took the text between the
    last `}` and the next `{`, which put `@media (max-width: 720px) {` on the
    front of the selector of every rule inside a media query and counted the
    media query itself as a rule whose body was its first child's declarations.
    It found the right grounds by accident and could not have found the right
    subjects at all. */
function rulesOf(sheetFile) {
  const { text, name } = sheetFile
  const out = []
  const walk = (from, to) => {
    let cursor = from
    let i = from
    while (i < to) {
      if (text[i] !== '{') {
        i += 1
        continue
      }
      const selector = text.slice(cursor, i).trim()
      let depth = 1
      let j = i + 1
      while (j < to && depth > 0) {
        if (text[j] === '{') depth += 1
        else if (text[j] === '}') depth -= 1
        j += 1
      }
      if (selector.startsWith('@')) walk(i + 1, j - 1)
      else out.push({ sheet: name, selector, body: text.slice(i + 1, j - 1), at: i })
      cursor = j
      i = j
    }
  }
  walk(0, text.length)
  return out
}

const RULES = SHEETS.flatMap(rulesOf)
for (const rule of RULES) rule.subjects = subjectsOf(rule.selector)

const lineOf = (sheetFile, index) => sheetFile.text.slice(0, index).split('\n').length
const whereOf = (rule) => {
  const s = SHEETS.find((x) => x.name === rule.sheet)
  return `${rule.sheet}:${lineOf(s, rule.at)}`
}
const selectorOf = (rule) => rule.selector.split('\n').map((l) => l.trim()).filter(Boolean).join(' ')

/** ── which selectors may put a name into TOKENS ───────────────────────────
 *
 *  A custom property is inherited, so a declaration reaches an element only
 *  when it is written on that element, on an ancestor of it, or on something
 *  the element is inside. The token table was filled from raw sheet text,
 *  which knows none of that, and so it answered a question about ancestry with
 *  a question about file order.
 *
 *  It got one wrong. `src/pages/passport.css` declares `--accent: #d4af37` on
 *  `.pp`, the passport page's root, with a paragraph above it explaining that
 *  the gold is deliberate and scoped. `.pp` is a sibling route: the board is
 *  not inside it and never will be. Sorted sheet order put passport.css ahead
 *  of the site palette, so the gate resolved `--accent` to that gold, and
 *  `--q-green: var(--accent, #00ff88)` at the top of Queen.css carried it into
 *  twenty board rules including three grounds -- while the browser paints
 *  `#00FF88` from `:root` in src/index.css.
 *
 *  No verdict moved, because both values are bright and `groundsIn` wants a
 *  dark fill. That is the reason to fix it rather than the reason not to: this
 *  file exists because a number that happens to be harmless is still a number
 *  the browser does not paint, and the next one may not be harmless.
 *
 *  'board' means the board is inside this selector or this selector is inside
 *  the board -- either way its declarations are in the same inheritance chain
 *  as something measured here. 'off-board' means neither. Only 'board' is
 *  read. Asserted in both directions, like REACHED: a selector that starts
 *  declaring a custom property fails here asking which side it is on, and an
 *  entry that has stopped declaring one fails as stale. Which element is
 *  inside which is a fact about the markup, and a stylesheet cannot supply it
 *  -- the same reason SEALED is written by hand further down. */
const TOKEN_SCOPES = new Map([
  // The board itself and its two roots.
  ['.queen27-page', 'board'],
  ['.queen27-page.is-shell', 'board'],
  ['.queen27-page.is-shell:has(.queen-chat-tab)', 'board'],
  // Views and components mounted inside it.
  ['.rm', 'board'],
  ['.queen-catalog-layer', 'board'],
  ['.queen-catalog-layer:has(.queen-catalog-toolbar.is-search-open)', 'board'],
  ['.queen-hive-display', 'board'],
  ['.queen-wars', 'board'],
  ['.queen27-context', 'board'],
  ['.queen27-cycle-brand', 'board'],
  ['.queen27-factory', 'board'],
  ['.queen27-factory-station', 'board'],
  ['.queen27-factory-station.is-running', 'board'],
  ['.queen27-factory-station.is-review', 'board'],
  ['.queen27-factory-station.is-blocked, .queen27-factory-station.is-dropped', 'board'],
  ['.queen27-factory-station.is-done', 'board'],
  // The site palette, an ancestor of every page including this one.
  [':root', 'board'],
  // Other routes' roots. Neither an ancestor of the board nor inside it:
  // `.pp` is the passport page, `.spec-x` the spec explainer on the site.
  ['.pp', 'off-board'],
  ['.spec-x', 'off-board'],
])

const DECLARES_TOKEN = /--[\w-]+\s*:/
const TOKEN_DECL = /(--[\w-]+)\s*:\s*([^;{}]+);/g

/** Sheets the palette is read from, parsed the same way the board's are. */
const paletteRules = GLOBAL_PALETTE.flatMap((name) => {
  const path = resolve(root, name)
  assert.ok(existsSync(path), `${name} holds the site palette this board inherits and is gone`)
  return rulesOf({ name, text: decomment(readFileSync(path, 'utf8')) })
})

{
  // Board sheets first, palette last, which is the precedence the cascade
  // gives `:root`. Within that, first declaration wins -- see the limit
  // recorded beside TOKEN_VARIANTS for what that does and does not model.
  const declaring = [...RULES, ...paletteRules].filter((r) => DECLARES_TOKEN.test(r.body))
  const seen = new Set()
  for (const rule of declaring) {
    const selector = selectorOf(rule)
    const side = TOKEN_SCOPES.get(selector)
    assert.ok(
      side,
      `${rule.sheet} declares a custom property on \`${selector}\`, and TOKEN_SCOPES does not say ` +
        'whether this board inherits from it. Add it as \'board\' if the board is inside that ' +
        'selector or that selector is inside the board, and \'off-board\' otherwise -- a ' +
        'declaration on another route reaches nothing here, and reading it puts a colour in the ' +
        'table that the browser never paints.',
    )
    seen.add(selector)
    if (side === 'board') recordTokens(rule.body)
  }
  for (const selector of TOKEN_SCOPES.keys()) {
    assert.ok(
      seen.has(selector),
      `TOKEN_SCOPES lists \`${selector}\`, which no longer declares a custom property. Delete the ` +
        'entry: a list that is only ever added to stops being read.',
    )
  }
}
assert.ok(TOKENS.has('--muted'), 'the site palette is no longer reaching this gate')
assert.strictEqual(
  TOKENS.get('--accent'),
  '#00FF88',
  'the board resolves --accent from `:root`, and this gate no longer agrees with it',
)

/** Names deliberately declared more than once, with what the extra
 *  declarations are for.
 *
 *  First-wins is a model of the cascade, not the cascade. It does not know
 *  that a later declaration at equal specificity beats an earlier one, and it
 *  does not know which `@media` block is matching -- `rulesOf` walks into
 *  at-rules and hands their contents back with no record of the condition. On
 *  this board that is currently harmless and currently checkable: the six
 *  `--hud-*` names re-declared under `@media (max-width: 1279px)` in Queen.css
 *  are all lengths, and a length is measured by nothing here.
 *
 *  So the hole is fenced rather than modelled. A name re-declared with a
 *  different value, where any of those values reads as a colour, fails below
 *  unless it is listed here -- because that is the shape that would make this
 *  gate print a ratio for an alpha the browser has stopped painting, and pass.
 *  Thinning `--hud-veil` for phones is one edit away from being written, and
 *  it would be silent. */
const TOKEN_VARIANTS = new Map([
  [
    '--station-color',
    'One colour per station state on the FACTORY view -- grey idle, gold in review, green ' +
      'running, red blocked. Five declarations on five mutually exclusive variant selectors, ' +
      'which is a switch rather than an override, and no element sees two of them.',
  ],
])

{
  const byName = new Map()
  for (const rule of [...RULES, ...paletteRules]) {
    if (TOKEN_SCOPES.get(selectorOf(rule)) !== 'board') continue
    for (const match of rule.body.matchAll(TOKEN_DECL)) {
      const name = match[1]
      if (!byName.has(name)) byName.set(name, new Set())
      byName.get(name).add(match[2].trim())
    }
  }
  for (const [name, values] of byName) {
    if (values.size < 2) continue
    if (TOKEN_VARIANTS.has(name)) continue
    const colours = [...values].filter((v) => COLOR_LITERAL.test(v) || v.startsWith('var('))
    assert.ok(
      colours.length === 0,
      `${name} is declared ${values.size} times with different values -- ${[...values].join(' / ')} ` +
        `-- and this gate reads the first of them (${TOKENS.get(name)}). For a length that is ` +
        'harmless; for a colour it means every ratio printed below is for a value the browser may ' +
        'have replaced. Either make the declarations agree, or add the name to TOKEN_VARIANTS ' +
        'saying which elements see which.',
    )
  }
}

/** The three properties that can paint a ground, and the reason the third is
 *  here. This regex is the single input to `groundsIn`, to `opaqueOf` and to
 *  the census at the foot of section 1 — so a property it does not name is a
 *  ground that is neither measured nor reported unreadable, which is the one
 *  failure mode this file is built to refuse. It read `background` and
 *  `background-color` and stopped, and `background-image` paints gradients:
 *  `linear-gradient(rgba(2, 8, 6, 0.5), rgba(2, 8, 6, 0.5))` written in the
 *  longhand was a dark translucent ground the gate passed in silence, while the
 *  byte-identical fill written in the shorthand failed at 2.98:1. Adding it
 *  changes no verdict on the board as it stands — six longhand declarations,
 *  all either `none`, an SVG arrow, or a bright lattice tint — which is the
 *  point: the hole is closed while it is still cheap to close. */
const BACKGROUND = /(?:^|[;])\s*background(?:-color|-image)?\s*:\s*([^;]+)/g

/** The dark translucent fills a rule paints — a ground, not a tint.
 *
 *  Near-black, because a translucent LIGHT fill is a tint laid on a ground that
 *  is somebody else's rule, and measuring it as if it were the ground would
 *  report a false failure on every chip on the board. The bound is 40 rather
 *  than the 20 it was: `#041115` is (4, 17, 21) and sat one point outside a
 *  threshold picked before anything wrote a hex ground, which is exactly how
 *  the zoom hint went unmeasured.
 *
 *  `Math.max` is the right operator and the sentence that used to justify it
 *  was not. It read "they are white, green or gold, and their smallest channel
 *  is 136", and the board's own tokens refute it in one line: `--hud-gold` is
 *  #ffd700, whose blue is 0, and `--hud-green` is #00ff88, whose red is 0. What
 *  is true of a tint is that its LARGEST channel is high, and that is the
 *  channel this test reads. The old sentence would have argued for Math.min,
 *  which would have classed every gold tint on the board as a ground.
 *
 *  Which left a real hole under a wrong argument. A fill with a largest channel
 *  of, say, 60 is neither excluded as a tint nor collected as a ground — it
 *  falls out of the gate in silence, and 60 is a perfectly ordinary dark
 *  surface. So the band above 40 is not assumed empty, it was counted: widen
 *  this test to `top > 40 && top < 255` and the board paints seven distinct
 *  translucent fills there. They split cleanly, and neither half is a ground.
 *  Four are bright — largest channel 207 to 245, the cyan, red and green
 *  accents — tints by colour. Three are dark and thin — largest channel 51, 71
 *  and 100, none carrying more than alpha 0.2 — tints by weight; the middle one
 *  is the atlas's own radial stop, which sits on an opaque #020806 written in
 *  the same declaration.
 *
 *  Hence two cuts rather than one. Certainly a ground: near-black at any
 *  weight. Also a ground: dark enough to read as a surface AND heavy enough to
 *  be the one being read through — which is the fill that used to escape, and
 *  the reason the second clause exists at all. 135 leaves the three thin ones
 *  well outside on weight and the four bright ones well outside on colour. */
const GROUND_DARK = 40
const GROUND_DARKISH = 135
const GROUND_WEIGHT = 0.3
function groundsIn(body) {
  const found = []
  for (const match of body.matchAll(BACKGROUND)) {
    for (const color of colorsIn(match[1])) {
      if (!(color.a > 0 && color.a < 1)) continue
      const top = Math.max(color.r, color.g, color.b)
      if (top <= GROUND_DARK) found.push(color)
      else if (top <= GROUND_DARKISH && color.a >= GROUND_WEIGHT) found.push(color)
    }
  }
  return found
}

/** Every `background` this gate looked at and could not turn into a colour.
 *
 *  This is the backstop for the parser, and the reason it exists is that the
 *  parser's failures are SILENT and they fail OPEN. `colorOf` returning null
 *  reads, three lines up, as "not a ground" — identical to a gradient of
 *  opaque stops, identical to `background: none`, identical to a keyword this
 *  file has never heard of. Every notation the parser cannot read is therefore
 *  a way to paint a 0.05 ground on this board and have the contrast gate
 *  approve it, and CSS adds notations faster than anybody edits this file.
 *
 *  So the set is pinned by name, in the idiom REACHED uses for sheets: each
 *  entry is a decision somebody made and can be checked, and a NEW unreadable
 *  background fails asking to be decided rather than passing in silence. The
 *  entry is `sheet:selector`, not a line number, because line numbers in this
 *  file have rotted twice and a selector cannot.
 *
 *  Two honest reasons to be on this list, and it is worth knowing which:
 *
 *  - The value is opaque or has no colour in it at all — a gradient of solid
 *    stops, `none`, `currentColor`, an image. Nothing translucent, nothing to
 *    measure, and the null is the right answer.
 *  - The value's COLOUR comes from JavaScript. `--queen-dir` is set per card by
 *    src/lib/queenDirection.ts, so no stylesheet holds the hue and no amount of
 *    parsing recovers it. The alpha IS knowable in those cases and is recorded
 *    beside the entry, which is the part a reader of the selector cannot work
 *    out and the part that decides whether the surface is thin. */
const UNREADABLE = new Map([
  /* `currentColor`. The colour is whatever the element's own `color` computes
     to, which is a cascade this gate does not run and will not pretend to. All
     six are the same object: a 5-6px dot or a progress bar's fill, sized in
     the rule itself, with `content: ""` or no child at all. A surface that is
     six pixels across carries no sentence, so nothing about it can be made
     illegible -- the NO_TEXT argument, arrived at from the other direction. */
  ['src/components/QueenIntel.css:.queen27-sectors-bar > span', 'the bar fill itself, no text'],
  ['src/pages/Queen.css:.queen27-activity-stream > div span::before', '0.42rem dot, content: ""'],
  ['src/pages/Queen.css:.queen27-card .queen27-dir-tag i', '5px dot, empty <i>'],
  ['src/pages/Queen.css:.queen27-card-signal i', '5px dot, empty <i>'],
  ['src/pages/Queen.css:.queen27-hive-law i', '0.5rem square, empty <i>'],
  ['src/pages/Queen.css:.queen27-page.is-shell .queen27-hud-pill > i', '6px dot, empty <i>'],

  /* `--queen-dir` is set per element by src/lib/queenDirection.ts, so no
     stylesheet holds the hue and no parser recovers it. What matters is that
     the alpha is not in question in either of these: both write the token
     neat, and a token used neat is OPAQUE. An opaque ground passes nothing
     through, which is the whole subject of this gate, so the unknown hue costs
     the measurement nothing.

     The pressed chip is worth naming for a second reason: it is a chip in the
     owner's photograph of the DIRECTION row, and it is the one chip in that row
     that was never part of the complaint. Its ground is solid and its ink is
     #050505 on it. The chips that WERE the complaint are the unpressed ones,
     and those take --hud-muted on a veil a few hundred lines up, where this
     gate measures them. */
  ['src/pages/Queen.css:.queen27-dir-chip > i', 'opaque var(--queen-dir), 6px dot'],
  ['src/pages/Queen.css:.queen27-dir-filter .queen27-dir-chip[aria-pressed="true"]', 'opaque var(--queen-dir) under #050505'],

  /* The direction cards: `color-mix(in srgb, var(--queen-dir) N%, transparent)`
     at 7% resting and 16% on hover. The alpha IS known and is written here
     because it is the number a reader of the selector cannot work out; the hue
     is not, and with a direction hue on one side the mix is a LIGHT translucent
     fill, which `groundsIn` classifies as a tint laid on somebody else's ground
     rather than as a ground -- the same answer it would give if the hue were
     resolved. So this entry records an unreadable value that changes no verdict.

     It does leave a real question open, and this is the honest place to say so
     rather than in a commit message: `.queen27-card` paints `rgba(255, 255,
     255, 0.018)` and the shell layer gives it a border and a clip-path and no
     ground at all, so a card's text on this board sits on the live hive with
     nothing but a 1.8% wash between. That is not a contrast failure this gate
     can state -- there is no dark ground to measure and no ink is declared
     against one -- it is the bare-text case, which nothing in qa/ checks for. */
  ['src/pages/Queen.css:.queen27-card[data-dir], .queen27-page.is-shell .queen27-card[data-dir]', 'alpha 0.07, hue from JS'],
  ['src/pages/Queen.css:.queen27-card[data-dir]:hover, .queen27-page.is-shell .queen27-card[data-dir]:hover', 'alpha 0.16, hue from JS'],

  /* `color-mix(in srgb, var(--tech-color) 8%, #020202)`. Unreadable for the
     hue, and decided by the OTHER side: #020202 is opaque, so 92% of the mix is
     opaque and the result is too, whatever --tech-color turns out to be. The
     base rule under it grounds the node at rgba(3, 5, 3, 0.96) in any case. */
  ['src/pages/Queen.css:.queen27-tech-node.is-researched', 'mixed into opaque #020202'],

  /* `background-image: url("data:image/svg+xml,...")` -- the dropdown chevron,
     the same twelve-pixel arrow in both files. These are the first two entries
     the census caught when BACKGROUND learned to read the longhand, and they
     are the honest shape of a url(): a value that paints, carries no colour a
     parser can recover, and is nonetheless not a ground. The geometry is what
     settles it rather than the notation -- `background-size: 12px 12px` and
     `background-position: right 14px center` in the same rule, so it covers 144
     square pixels in the gutter a `padding-right: 2.75rem` was opened for, and
     no glyph is ever under it. The ground each select actually sits on is
     declared by its companion rule and IS measured: rgba(3, 12, 14, 0.88) with
     blur(8px) at Queen.css, opaque #041115 at QueenUniverse.css.

     They are listed rather than skipped because skipping every url() is the
     silent hole this file exists to refuse: a full-bleed opaque image IS a
     ground, and the day somebody writes one the census should stop them. */
  ['src/pages/Queen.css:.queen-hive-inspect-tools select', '12px chevron in the padding gutter, ground is the companion rule at 0.88'],
  ['src/pages/QueenUniverse.css:.queen-universe-nav select', '12px chevron in the padding gutter, ground is opaque #041115'],
])

// Surfaces that draw rather than write. A ground with no text on it cannot make
// text illegible, so it is free to be as thin as the design wants, and it owes
// no low pass either. Every one is named with the evidence, rather than
// pattern-matched — a third one is a decision somebody has to write down here.
const NO_TEXT = [
  // aria-hidden="true" in QueenResearchCity.tsx:293.
  '.queen27-city-canvas',
]

// The other exemption, and it is not the same one. These surfaces DO carry text
// — the viewport carries every word on the board — but the hive is their
// DESCENDANT rather than their backdrop, so their ground paints beneath it and
// attenuates nothing. Thickening one of them would darken the page and leave
// the lattice exactly where it was; the surfaces that actually stand between
// the hive and a reader are the panels inside, and those are measured.
//
// .queen27-comb-field spent a while in NO_TEXT, where its own comment already
// gave this reason rather than that one. The two lists are split because the
// remedies differ: a NO_TEXT entry says "nothing here can be made illegible",
// and this one says "this ground is on the wrong side of the thing it would
// have to cover".
const UNDER_SCENE = [
  // The page's own base, painted BEHIND .queen-hive-stage / canvas.queen-starfield
  // / .queen27-hover-card rather than over them (they are its children), which
  // is why it attenuates nothing and why every ratio here is measured against a
  // fully lit field.
  '.queen27-comb-field',
  // Every tab that mounts a SceneBoundary puts .queen-scene-holder and its own
  // view root in .queen27-hud-vp-body as siblings, inside this. The holder is
  // absolutely positioned and the view roots are in flow, which is the whole of
  // the show-through this branch repairs: positioned descendants paint at step
  // 6 of the painting order and in-flow blocks at step 3, so the hive drew OVER
  // the board's text until the VIEW ROOTS were raised above it. (That way round:
  // the holder has no z-index of its own in any Queen.css rule that names it,
  // and the fix is a z-index on its siblings -- a count of those rules stood
  // here and was wrong, and a count rots exactly like a line number does. The
  // ?engine=canvas branch is
  // the state with no holder at all, and Queen.css names its comb beside the
  // holder in both the pointer rule and the paint rule.) Either way this
  // element's own ground is under all of them.
  //
  // The second reason it is here is the one that makes it load-bearing, and it
  // is about this parser rather than about the page: .queen27-hud-viewport
  // declares a ground twice in Queen.css and both are overridden to
  // `transparent` by a later rule at identical specificity, so the class paints
  // nothing on any live page. This gate reads declarations, not the cascade, so
  // it sees two grounds where the browser sees none. Removing this entry fails
  // the blur law on a declaration that never paints. If the dead declarations
  // are ever deleted the entry can go with them.
  '.queen27-hud-viewport',
]

const EXEMPT = new Set([...NO_TEXT, ...UNDER_SCENE])

// The census itself. Both directions, as with REACHED: an unreadable value
// nobody listed fails, and a listed value the parser has since learned to read
// fails too, so the list shrinks as the parser grows instead of accumulating
// entries that stopped being true.
{
  const unread = []
  for (const rule of RULES) {
    for (const match of rule.body.matchAll(BACKGROUND)) {
      const value = match[1].trim().replace(/!important/g, '').trim()
      // `background: none` paints nothing and is the one honest null.
      if (/^(?:none|inherit|initial|unset|revert)$/i.test(value)) continue
      if (colorsIn(value).length) continue
      unread.push(`${rule.sheet}:${selectorOf(rule)}`)
    }
  }
  const seen = new Set(unread)
  const unlisted = [...seen].filter((k) => !UNREADABLE.has(k)).sort()
  const stale = [...UNREADABLE.keys()].filter((k) => !seen.has(k)).sort()
  assert.equal(
    unlisted.length,
    0,
    `these rules paint a background this gate cannot read, and a background it cannot read is one it passes:\n  ` +
      `${unlisted.join('\n  ')}\n` +
      'teach parseColor/colorOf the notation, or add each to UNREADABLE with the reason and the alpha',
  )
  assert.equal(
    stale.length,
    0,
    `UNREADABLE still lists ${stale.join(', ')}, which this gate now reads or no longer finds -- ` +
      'delete the entry, so the list keeps measuring the parser instead of remembering it',
  )
}

// ── 3. the shell restyles a ground and its ink together ──────────────────────

// #888888 on solid #050505 is 5.9:1 and perfectly fine. The defect is a layer
// that swaps the ground for a translucent one and leaves the colour written
// against the old one — measured at 1.6:1 on the chips in the owner's
// photograph. These are the rules that repaired it; they are asserted by name
// because the next person to touch this file will be reading the chip's base
// rule, where the colour still says --muted.
const shell = css.slice(css.indexOf('.queen27-page.is-shell .queen27-chip:not([aria-pressed="true"]),'))
assert.match(
  shell,
  /\.queen27-page\.is-shell \.queen27-chip:not\(\[aria-pressed="true"\]\) \{\s*color: var\(--hud-muted\);/,
  'the shell gives the resting chip a translucent ground; it must give it the ink to go with it',
)
assert.match(
  shell,
  /\.queen27-page\.is-shell :is\(\.queen27-lane-filter, \.queen27-dir-filter\),[\s\S]{0,120}\{\s*color: var\(--hud-muted\);/,
  'the filter rows set --muted directly on themselves, so the heading\'s --hud-muted never reaches them',
)

// The clients strip is the one row on this board that carries another person's
// name, over the densest gold the hive paints. It gets the panel, not the veil.
const laneHead = /\.queen27-lane-head\.is-private \{([^}]+)\}/.exec(css)
assert.ok(laneHead, '.queen27-lane-head.is-private is gone')
assert.match(
  laneHead[1],
  /background: var\(--hud-panel/,
  'the private clients strip must sit on the panel: the map may run under a column of cards, not under somebody\'s name',
)

// The search box has no <label>: its placeholder is the accessible name, so it
// is body text and not a hint. Left to the UA it is #757575 — 4.39:1 measured
// in the browser, which is how a word in the owner's photograph was still
// failing after the ground under it had been fixed.
assert.match(
  css,
  /\.queen27-lane-search::placeholder \{\s*color: var\(--hud-muted/,
  'the only label on the person-search box is its placeholder; it may not keep the UA grey',
)

// The premise both of the sections around this one rest on: the hive is BEHIND
// the words.
//
// Everything this file measures is a composite of ink over ground over field,
// in that order. If the field is painted LAST the arithmetic is not merely
// pessimistic, it is answering a different question — no ground hides a thing
// drawn after it, at any alpha, and a gate reporting 12:1 would be telling the
// truth about a board the reader cannot read.
//
// It was drawn after it, on every tab but the comb, for as long as this board
// has existed. The viewport body has two children: .queen-scene-holder, which
// is positioned, and the view root, which is a static in-flow block. CSS paints
// in-flow blocks at step 3 of a stacking context and positioned descendants at
// step 6, so the lattice went on top. Twice photographed — the lattice through
// HARDWARE and PROOF in the direction row, a hexagon over the CRM button on TRI
// — and twice answered with a thicker ground, which is the answer that cannot
// work.
//
// The fix raises the view roots rather than lowering the holder, and it is
// asserted here rather than left to a screenshot because it is one rule, far
// from anything it protects, whose deletion would make every other assertion in
// this file quietly meaningless. Both :not()s are named: the holder because on
// the comb it IS the content, and .queen27-comb.is-embedded because under
// ?engine=canvas the hive arrives with no holder around it, and lifting THAT to
// z-index 1 ties it with the view roots — a tie settled by JSX order, which is
// the same bug with a longer fuse.
{
  const order = /\.queen27-page\.is-shell \.queen27-hud-vp-body > \*((?::not\([^)]*\))+) \{([^}]*)\}/.exec(css)
  assert.ok(
    order,
    'the rule that puts the hive behind the board is gone: nothing else stops ' +
      '.queen-scene-holder, which is positioned, from painting over a view root, which is not. ' +
      'Without it every ratio measured below is arithmetic about the wrong compositing order.',
  )
  assert.match(order[1], /:not\(\.queen-scene-holder\)/, 'the scene holder must stay excluded: on the comb it is the content')
  assert.match(
    order[1],
    /:not\(\.queen27-comb\.is-embedded\)/,
    'the canvas engine mounts the hive with no holder around it; without this :not() the rule lifts the hive itself to z-index 1 and the stacking order falls to JSX order',
  )
  assert.match(order[2], /position:\s*relative/, 'z-index does nothing to a static box')
  assert.match(order[2], /z-index:\s*[1-9]/, 'the view roots must sit above the scene, not merely be positioned')
}

// ── 4. the low pass, which is the half a ratio cannot see ────────────────────

// A ground is an AMPLITUDE. The hive is a FREQUENCY. Alpha compositing is a
// linear mix: it scales what is behind and leaves its structure exactly where
// it was, so 0.88 delivers 12% of a hexagon lattice to the reader with every
// edge in place, and an edge that crosses a letterform is read as part of the
// letter. That is the complaint in both photographs, and no number in sections
// 1 to 3 can see it. `backdrop-filter: blur()` is the only declaration on this
// board that touches the frequency, and it is why the rule that fixed the
// clients strip has one.
//
// So: a dark translucent ground on the board owes a low pass. Three ways to be
// excused, and each has to be written down here rather than noticed later.

/** The SUBJECT of a selector is its rightmost compound — the element the rule
    actually paints. `.queen27-page.is-shell .queen27-chip` paints the chip, not
    the page. Matching an exemption against every class in the selector string
    lets `.queen27-page` and `.is-shell`, which appear in the big shared rules,
    silently vouch for everything downstream of them. */
function subjectsOf(selector) {
  const out = new Set()
  for (const raw of splitSelectorList(selector)) {
    const part = raw.trim()
    if (!part) continue
    const trailing = /:(?:is|where|not|has)\(([^()]*)\)[^\s>+~]*$/.exec(part)
    if (trailing) {
      /* `.a :is(.b)` and `.a:is(.b)` are different sentences and the regex above
         cannot tell them apart, because what separates them is the character in
         front of the colon. With a space, the `:is()` is a compound of its own
         and `.a` is an ANCESTOR — reading `.a` as a subject here is how the
         shared `.queen27-page.is-shell` prefix came to vouch for every element
         on the board. Without one, the two are the same compound and both hold. */
      const left = part.slice(0, trailing.index)
      const descendant = /[\s>+~]$/.test(left)
      for (const member of trailing[1].split(',')) {
        const classes = member.match(/\.[A-Za-z0-9_-]+/g)
        if (classes) {
          out.add(classes.join(''))
          continue
        }
        /* A member with no class in it — `.a .b :is(input, select, button)`.
           Each of these used to add nothing at all, and when EVERY member was
           bare the rule left this function with an empty subject list, which
           the loop at the bottom of the file reads as "no subjects, no
           questions to ask": the rule was not measured, not exempted, and not
           counted in the summary it prints. Thirteen rules across five sheets
           are written this way -- the catalogue's toolbar and its detail pane,
           the shared core's focus ring, the atlas, the viewport head's
           controls, the universe nav -- and a gate that drops a rule in silence
           is worse than one that fails it, because the number it goes on
           printing stays plausible.

           Measured rather than argued, because a parser fix that changes no
           output is indistinguishable from one that does nothing: giving
           `.queen27-page.is-shell .queen27-hud-vp-head :is(button, select, a)`
           a `background: rgba(2, 8, 6, 0.3)` makes this gate fail with
           "`.queen27-hud-vp-head button` ... alpha 0.3, 1.79:1", and makes the
           same gate without these twenty lines print a summary one ground
           shorter and pass. The count itself is deliberately not written down
           here: it moves with every rule anyone adds, and a number in a comment
           that nothing recompiles is a claim rotting in place — which is the
           defect this file spends a paragraph on at FROSTED. Today the thirteen
           declare no translucent ground, so the summary is unchanged; what
           changed is that the fourteenth cannot arrive unseen.

           Scoped by the class to their left, exactly as a trailing bare element
           is twenty lines down and for the same reason: `input` on its own is
           not an identity, it is every text field on the board, and a subject
           keyed on it would excuse or condemn all of them together. */
        if (!descendant) continue
        const bare = member.trim().replace(/::?[\w-]+.*$/, '')
        if (!bare) continue
        const host = hostOf(left)
        out.add(host ? `${host} ${bare}` : bare)
      }
      if (descendant) continue
    }
    const stripped = part.replace(/:(?:is|where|not|has)\([^()]*\)/g, ' ')
    const compounds = stripped.split(/[\s>+~]+/).filter(Boolean)
    const compound = compounds.pop() || ''
    const classes = compound.match(/\.[A-Za-z0-9_-]+/g) || []
    if (classes.length) out.add(classes.join(''))
    if (classes.length || !compound) continue
    /* A bare element — `.queen-chat-find input`, `.queen27-map-nodes a`. See
       the scoping note above; this is the same subject written the same way. */
    const bare = compound.replace(/::?[\w-]+.*$/, '')
    const host = hostOf(compounds.join(' '))
    out.add(host ? `${host} ${bare}` : bare)
  }
  return [...out].filter(Boolean)
}

/** Every name one subject answers to.
 *
 *  `.queen27-tri-screen.is-active` is ONE element with two names, and the two
 *  are not peers: the first says what it is and the second says what it is
 *  doing. Emitting them as two subjects — which is what this file did until the
 *  gate reported `.is-active` as an unfrosted surface in its own right —
 *  manufactures an element out of a state, and then asks that element to have
 *  its own ground, its own blur and its own entry in every list here. There is
 *  no such element. The blur on `.queen27-tri-screen` is on the same box.
 *
 *  So a compound is one subject, written as it appears, and a lookup for it
 *  tries the whole name and then each class in it. That direction matters:
 *  anything declared about `.queen27-tri-screen` is true of every element that
 *  carries the class, including the active one, so a class of the compound may
 *  vouch for the compound.
 *
 *  It does NOT work the other way, and the change closes a hole this file used
 *  to name at FROSTED and accept: a blur written on `.queen27-lane-head
 *  .is-private` went into the roster as a bare `.is-private`, from where it
 *  excused every plain `.queen27-lane-head` on the board. It now goes in under
 *  its compound and excuses only elements that are private. The generic heading
 *  carries its own blur one rule below, which is why closing the hole shows up
 *  here as an argument rather than as a failure. */
const namesOf = (subject) => {
  if (subject.includes(' ') || !subject.startsWith('.')) return [subject]
  const classes = subject.match(/\.[A-Za-z0-9_-]+/g) || []
  return classes.length > 1 ? [subject, ...classes] : [subject]
}

/** Whether a rule paints the named surface, under any of the names it answers
    to. Used by every "what does the ancestor still do" question below, where
    missing a rule is the dangerous direction: a state rule that thins an
    ancestor, or clears its ground, has to be able to take the excuse away. */
const paints = (rule, name) => rule.subjects.some((s) => namesOf(s).includes(name))

/** The class chain that scopes a bare element: the nearest compound to its left
    that carries a class, written as that compound's classes joined. One
    function and two callers, because the two paths that need it — a bare
    element inside `:is()` and a bare element at the end of a selector — are the
    same question, and a second hand-written copy is how they would come to
    disagree. */
function hostOf(left) {
  const compounds = left
    .replace(/:(?:is|where|not|has)\([^()]*\)/g, ' ')
    .split(/[\s>+~]+/)
    .filter(Boolean)
  const scope = compounds.reverse().find((c) => /\.[A-Za-z0-9_-]+/.test(c))
  return scope ? (scope.match(/\.[A-Za-z0-9_-]+/g) || []).join('') : ''
}

/** Commas inside `:is(...)` / `:not(...)` do not end a selector. The scanner
    that ignored this lost the last member of every multi-line `:is()` list to a
    stray `)`, which is a false pass on whichever rule happened to be written
    last — the quietest possible way for this gate to be wrong. */
function splitSelectorList(selector) {
  const out = []
  let depth = 0
  let start = 0
  for (let i = 0; i < selector.length; i += 1) {
    const ch = selector[i]
    if (ch === '(' || ch === '[') depth += 1
    else if (ch === ')' || ch === ']') depth -= 1
    else if (ch === ',' && depth === 0) {
      out.push(selector.slice(start, i))
      start = i + 1
    }
  }
  out.push(selector.slice(start))
  return out
}

const HAS_BLUR = /-?(?:webkit-)?backdrop-filter\s*:\s*[^;]*blur\(/

/** Surfaces that are painted INSIDE another named surface, and the surface they
    are inside. One entry buys two different things, because they are the same
    physical fact stated twice:

    - The ancestor is part of the backdrop. A ground at 0.45 is not 0.45 of a
      lit hive if it sits on a panel at 0.94; it is 0.45 of the 6% that panel
      lets past. Measuring it against a fully lit field — which is what every
      ratio in section 1 assumes, correctly, for a surface with nothing but the
      scene behind it — reports `.mcp-cmd` at 2.68:1 when the reader is looking
      at something nearer 19:1. That is a false failure, and a false failure is
      how a gate gets an exception added for the wrong reason.
    - The ancestor is the backdrop ROOT. `backdrop-filter` on a parent makes it
      one for everything inside it, so a child sees a field that has already
      been low-passed and pays for a second compositing layer to blur a blurred
      thing. One layer per panel, not one per element in it.

    Both halves are checked rather than trusted: the named ancestor must still
    paint a ground and must still carry a blur. Take either away and every
    element listed against it fails here, with the ancestor's name in the
    message — which is the property a hand-written exemption list does not
    normally have, and the reason this one is allowed to exist at all. */
const INSIDE = {
  // `.mcp-view` in QueenMcp.css — the scroll owner for the whole fleet face.
  // (Addressed by selector, not by line: this branch adds ~300 lines to
  // Queen.css alone, and every line number written into a comment before that
  // now points at whatever slid into its place. Four of them did. A selector is
  // the address that survives an edit above it.) QueenMcp.tsx
  // renders .mcp-down, and .mcp-cmd inside it, only from within .mcp-view.
  '.mcp-cmd': '.mcp-view',
  // The other two surfaces in that face, and the reason the economy argument is
  // worth stating twice: .mcp-view is the ONLY element either of these ever
  // renders inside (QueenMcp.tsx:238 and :259), and it is frosted. The metrics
  // are five boxes and the hub can return dozens of cards, so frosting them
  // where they are written would have bought fifty compositing layers over a
  // backdrop that has already been through the filter once.
  '.mcp-metric': '.mcp-view',
  '.mcp-card': '.mcp-view',
  // The catalogue's search field. Three layouts, one answer: in the shell the
  // toolbar is `.queen27-page.is-shell .queen-catalog-toolbar` in Queen.css,
  // over the map with the roster's blur on it; on the
  // landing it sits in the headroom row of .queen-catalog-layer, which is
  // OPAQUE black, with the hive in the row below rather than behind it; and in
  // landscape it floats, which is the one case that needed a declaration and
  // now has one beside its ground in QueenCatalogHive.css.
  '.queen-catalog-tools input': '.queen-catalog-toolbar',
  // The mission map's node links. The sector is frosted twice over — blur(10px)
  // on its base rule and the roster's 6px in the shell — so a blur on the link
  // would sample the sector's own box rather than the field and change nothing.
  '.queen27-map-nodes a': '.queen27-map-sector',
  // `.queen27-tri-screen` was listed here against `.queen27-tri-screens`. The
  // row is a bare flex container — no ground, no blur, never had either — so
  // the excuse named a backdrop that does not exist and the chips were being
  // measured against a panel that was never painted. Each chip is its own
  // surface over the live hive and now answers for itself in QueenTri.css.
  // Queen.css — the command rail; this is the collapse handle inside it,
  // QueenCommand.tsx:115, a direct child of the <nav> at :66. The ancestor here
  // used to be spelled `.queen27-hud-commands`, plural, which nothing renders:
  // the entry passed the two checks below because the dead name was still
  // carrying a ground and a blur in Queen.css, so an excuse that was true of
  // the element was false of the class it was written against. Both dead rules
  // are gone; this is the live one.
  '.queen27-hud-cmd-collapse': '.queen27-hud-command',
  // The clients strip, the one row on the board that carries a person's name.
  '.queen27-lane-private': '.queen27-lane-head',
  '.queen-chat-find input': '.queen-chat',
  // Two of the three button grounds written on one line at
  // QueenCatalogHive.css:55. That line's own comment has said this since it was
  // written — the share strip and the spec sheet each paint a ground and carry
  // a blur, and only the level row, a bare flex row over the live hive, pays
  // for its own — but nothing checked it, because the level row's blur was
  // sitting in the same selector list and answering for all three.
  '.queen-catalog-share button': '.queen-catalog-share',
  '.queen-catalog-spec button': '.queen-catalog-spec',
  // The top bar's sector tiles. QueenIntel.css grounds the feed and the sectors
  // in one breath and frosts only the feed, and its comment gives the reason:
  // the one place QueenSectors renders is inside .queen27-hud-sectors in the
  // top bar, where Queen.css strips this ground to `none` outright on
  // `.queen27-hud-sectors > .queen27-sectors`, and the
  // bar itself carries --hud-panel and the roster's blur. So the ground being
  // measured here is not even painted where the element lives, and a blur
  // written beside it would low-pass a surface that paints nothing -- which is
  // the band-over-bare-map defect, on the tab with the map on it.
  '.queen27-sectors': '.queen27-hud-top',
  // The bay strip's rows and its worker slots, grounded in Queen.css by the one
  // `background: var(--hud-veil)` rule that also names `.queen27-map-sector`,
  // the factory floor and the inspector — both on the blur roster, and both of
  // them vouching for these two until the loop below started asking per
  // subject. Neither of these is a bare single class, so the roster is closed
  // to them; they do not need it, because QueenFactory.tsx:112 puts the strip
  // inside .queen27-factory, which carries --hud-veil and is on the roster.
  '.queen27-factory-bays div': '.queen27-factory',
  '.queen27-factory-bays li': '.queen27-factory',
}

/** The ink this ground was written for.
 *
 *  A rule that paints a ground and names a colour in the same breath is stating
 *  a PAIR, and the pair is what a reader sees — `.queen-chat-tab` grounds itself
 *  at 0.55 and writes `--hud-gold` on it, and judging that gold as if it were
 *  `--hud-muted` fails a button that is perfectly legible. Queen.css says this
 *  about itself at the resting-chip rule: a rule that changes a background
 *  without changing the colour written against it "has not restyled a control,
 *  it has broken the pair".
 *
 *  A ground with no colour beside it gets judged against `--hud-muted`, because
 *  that is the board's default quiet ink and therefore the dimmest thing that
 *  will land on the surface. Guessing anything lighter would be the gate
 *  choosing the reading that lets it pass. */
const COLOR_DECL = /(?:^|[;])\s*color\s*:\s*([^;]+)/g
function inkIn(body) {
  let last = null
  for (const match of body.matchAll(COLOR_DECL)) {
    const color = colorOf(match[1])
    if (color) last = color
  }
  return last
}

/** A ground written `background: none` or `background-color: transparent`.
    Not a colour, so `groundsIn` has nothing to return for it, and the ancestor
    below would fall back to whatever earlier rule still painted one. */
const CLEARED = /(?:^|[;])\s*background(?:-color)?\s*:\s*(?:none|transparent)\s*(?:!important)?\s*(?:;|$)/

/** What a named ancestor in INSIDE lets through, taken as the THINNEST ground
    any rule gives it.
 *
 *  This used to return the first one it met, walking RULES in sheet-path order
 *  and stopping — which is neither the cascade's answer nor a safe one. A media
 *  query that thins the ancestor, a state rule that replaces its ground, a
 *  later rule that clears it outright: none of them could be seen from here, so
 *  the excuse went on vouching with an alpha the page had stopped painting. The
 *  direction of the error is the bad one. `field = composite(above, LIT)`, so a
 *  thinner ancestor lets more of the lit hive through and makes the test of
 *  everything inside it HARSHER; keeping the thickest reading is the gate
 *  choosing the number that lets its subjects pass.
 *
 *  The thinnest is a bound rather than a cascade model, and it is the bound
 *  that errs toward failing. Clearing the ground counts as alpha 0, which is
 *  what it physically is: the whole lit field arrives. A name no rule mentions
 *  at all still returns null, and the assertion below still says so — that case
 *  is a renamed or deleted ancestor, and it needs a person, not an arithmetic.
 *
 *  Three of the ten ancestors in INSIDE answer differently under the two
 *  readings, so this is not a precaution against a hypothetical:
 *  `.queen-catalog-spec` 0.96 -> 0.72, `.queen27-lane-head` 0.88 -> 0.72,
 *  `.queen27-map-sector` 0.88 -> 0.72. Everything they cover is now measured
 *  through the thinner of the two, and the board passes anyway. */
const groundOf = (name) => {
  let thinnest = null
  for (const rule of RULES) {
    if (!paints(rule, name)) continue
    const found = groundsIn(rule.body)
    if (CLEARED.test(rule.body)) found.push({ r: 0, g: 0, b: 0, a: 0 })
    for (const ground of found) {
      if (!thinnest || ground.a < thinnest.a) thinnest = ground
    }
  }
  return thinnest
}

/** Surfaces with an OPAQUE ancestor between them and the scene.
 *
 *  The third exemption, and the three are not interchangeable. NO_TEXT says
 *  nothing here can be made illegible. UNDER_SCENE says this ground is on the
 *  wrong side of the thing it would have to cover. This one says the hive is
 *  not behind this element at all, because something in front of the hive and
 *  behind the element paints a ground with no alpha in it — and a reader of a
 *  surface with no field behind it is looking at a flat colour, which is the
 *  one case every ratio in section 1 already models exactly.
 *
 *  The half that cannot be derived is which side of the scene the ancestor is
 *  on, and that is markup rather than CSS. An opaque `.queen27-page.is-shell`
 *  would seal the whole board by this argument and seal nothing in fact, since
 *  the hive is mounted INSIDE it. So the ancestor is named by hand with the
 *  markup that puts the scene outside it, and the opacity — the half a
 *  stylesheet does know — is checked below rather than trusted.
 *
 *  Checked in the direction that errs toward failing: EVERY rule that grounds
 *  the ancestor must bottom out opaque, none may clear it, and at least one
 *  must exist. A media query that thins it, or a state rule that replaces its
 *  ground with a wash, takes the seal away and fails everything listed here
 *  with the ancestor's name in the message. */
const SEALED = {
  // QueenUniverse.tsx:105 mounts <Atlas> in the BRANCH OPPOSITE <Runtime/>:
  // the atlas view and the board are alternatives, so the shell that holds
  // .queen-scene-holder is not rendered at all while these cards are on
  // screen. The seal does not rest on that, because a branch can be rewritten
  // — .queen-atlas is `<main>` and paints `radial-gradient(...), #020806`,
  // whose bottom layer has no alpha, so anything behind it is invisible
  // whatever the page decides to mount there.
  //
  // Found by this gate, on the run that taught colorsIn to read every stop of
  // a gradient rather than the first: `background: linear-gradient(135deg,
  // #49cfe512, #04100e90)` had been passing on the strength of #49cfe512, a
  // 7% cyan tint, while the stop that actually covers most of the card is
  // #04100e90 — alpha 0.5647, and 3.45:1 against --hud-muted if the hive were
  // behind it. It is not. The reading the parser could not do before was
  // right, and the verdict it reached with it was wrong; both halves are worth
  // keeping, because the next surface the parser learns to read may be a real
  // failure and will look exactly like this one.
  '.atlas-world': '.queen-atlas',

  // The ROADMAP view, #1092. Its three panels are `var(--rm-panel)`, which
  // resolves to rgba(2, 8, 6, 0.88) — the board's veil alpha, and by the
  // argument this file makes everywhere else that is 12% of a live lattice
  // with its edges intact. It is not, because `.rm` is the view root and
  // paints `radial-gradient(ellipse at top, #06140d 0%, #020806 70%)`: one
  // layer, both stops opaque, so the hive stops at the section boundary and
  // what these panels have behind them is a flat wash.
  //
  // `.rm` is a direct child of .queen27-hud-vp-body (Queen.tsx:3965) and the
  // scene holder is its SIBLING, which is the markup half the seal needs and a
  // stylesheet cannot supply. The opacity half is checked by opaqueOf, so the
  // day somebody thins that radial to let the hive show through, these three
  // fail again by name and with `.rm` in the message.
  //
  // Worth recording how they got here: this view landed on main three days
  // after the gate was written, and the gate caught it on its first run
  // against the merged tree — first the manifest, for a sheet it had never
  // measured, and then these three, for the exact defect the owner had
  // photographed on a different view. That is the gate doing the job on
  // traffic rather than on a probe.
  '.rm-hero': '.rm',
  '.rm-kpis div': '.rm',
  '.rm-stages li': '.rm',
}

/** Surfaces that buy legibility with a HALO instead of with a ground.
 *
 *  The fourth exemption, and the only one that concedes the ratio is right.
 *  `.queen-hive-display` really does carry an issue title on a ground that
 *  thins to 0.44 in the middle and to a 12% hue wash at the corners, over a
 *  turning wall; 2.75:1 is what a reader of a FLAT backdrop would get. The
 *  backdrop is not flat, and it is not covered — it is displaced, one letter at
 *  a time, by `text-shadow: 0 1px 4px #000, 0 0 8px #000`. An opaque black halo
 *  drawn under each glyph makes the LOCAL backdrop of every stroke near-black
 *  whatever the wall is doing four pixels away, which is the one thing a
 *  whole-surface ratio cannot represent and the reason this cell is readable in
 *  a screenshot and unreadable in arithmetic.
 *
 *  It is also not this gate's call. The transparency here was asked for: these
 *  are windows onto the star catalogue, and qa/queen-starfield-contract.mjs
 *  pins it — `backdrop-filter:none`, "the user removed frosting so stars stay
 *  sharp", and `doesNotMatch(/gradient|blur\(/, 'do not restore rejected
 *  gradients or frosting')`. Two gates that demand opposite things of one rule
 *  do not make a board better; they make whichever runs second a nuisance to be
 *  switched off. So this one states its objection, names the contract that
 *  overrules it, and checks the thing that is actually load-bearing.
 *
 *  Checked, not trusted: the named holder must still declare a text-shadow, and
 *  every colour in it must be opaque and dark. Soften the halo to a grey or a
 *  translucent black and the cell loses its only legibility device, and this
 *  fails with the ratio it has been holding back. */
const HALOED = {
  // QueenHiveDisplay renders the whole of a cell's text inside this element —
  // heading, state, status line, events — so one declaration carries every
  // glyph on the face.
  '.queen-hive-display': '.queen-hive-display-content',
}

/** Whether a named surface still draws an opaque dark halo under its text. */
function haloOf(name) {
  let found = false
  for (const rule of RULES) {
    if (!paints(rule, name)) continue
    for (const match of rule.body.matchAll(/(?:^|[;])\s*text-shadow\s*:\s*([^;]+)/g)) {
      const colors = colorsIn(match[1])
      if (!colors.length) return false
      if (colors.some((c) => c.a < 1 || Math.max(c.r, c.g, c.b) > 40)) return false
      found = true
    }
  }
  return found
}

/** Whether a named ancestor paints something with no alpha in it.
 *
 *  The BOTTOM layer decides. CSS paints background layers first-on-top, so a
 *  stack is opaque when its last layer is — `radial-gradient(...), #020806` is
 *  a wash over black and passes no light, while `#020806, radial-gradient(...)`
 *  would be the same two colours with the black on top of a gradient that may
 *  be transparent anywhere. A gradient in the bottom slot counts only if every
 *  stop it names is opaque, since a stop is a place on the surface and a reader
 *  may be standing on any of them. */
function opaqueOf(name) {
  let found = false
  for (const rule of RULES) {
    if (!paints(rule, name)) continue
    if (CLEARED.test(rule.body)) return false
    for (const match of rule.body.matchAll(BACKGROUND)) {
      const layers = topLevelCommas(match[1].replace(/!important/g, '').trim())
      const bottom = colorsIn(layers[layers.length - 1] || '')
      if (!bottom.length || bottom.some((color) => color.a < 1)) return false
      found = true
    }
  }
  return found
}

/** Every class this board frosts anywhere, from any rule in any of its sheets.
 *
 *  The law belongs to the ELEMENT, not to the declaration, and on this board
 *  the two are routinely written thousands of lines apart. `.queen27-column`
 *  takes a flat ground near the top of Queen.css, is re-grounded by the shell
 *  layer far below that, and is frosted only by the shared `:is(...)` roster
 *  further down again -- three rules, one element, no two of them adjacent.
 *  Addressed by selector rather than by line deliberately: this paragraph first
 *  carried two line numbers, and by the time anybody checked them both pointed
 *  at unrelated rules and the distances drawn from them were wrong. That is the
 *  defect this file argues against a few hundred lines up, committed here.
 *  Asking "does THIS rule carry a blur" flagged thirty-two rules of which
 *  twenty-nine were already frosted by their roster — a gate that cries at
 *  correct code teaches people to widen its exemption list, which is how the
 *  roster became the defect in the first place.
 *
 *  What this proves and what it does not, so the pass is not read as more than
 *  it is: it proves SOME rule frosts this class. It cannot prove EVERY element
 *  wearing the class is frosted, because that needs the ancestry the DOM has
 *  and a stylesheet does not. A subject is the RIGHTMOST compound of a selector
 *  and the ancestors above it are dropped, so one key can stand for two
 *  elements on two pages. `.queen27-card` is the proof and is worth keeping
 *  here because it is not hypothetical: Queen.css writes a bare
 *  `.queen27-card` that grounds the public page's card, and
 *  `.queen27-page.is-shell .queen27-card` that clears the board's to
 *  transparent. Different surfaces, different backdrops, one name in this Set.
 *
 *  The half of that bound that WAS closable is closed, and the paragraph it
 *  used to be written in is one screen down: a blur on
 *  `.queen27-lane-head.is-private` no longer vouches for a plain
 *  `.queen27-lane-head`, because a compound now enters as one subject rather
 *  than as its parts. That direction was never sound — an element is private or
 *  it is not. This one is: `.a` genuinely matches every `.a.b`, so a blur on
 *  the bare class vouching for the compound is the cascade, not a guess.
 *
 *  The arithmetic in the loop below is exact; this half is a lower bound on the
 *  defect, and it found seven surfaces nobody had looked at. */
const FROSTED = new Set()
for (const rule of RULES) {
  if (!HAS_BLUR.test(rule.body)) continue
  for (const subject of rule.subjects) FROSTED.add(subject)
}
const isFrosted = (name) => namesOf(name).some((n) => FROSTED.has(n))

const unfrosted = []
let measured = 0
let excused = 0
let sealed = 0
let haloed = 0
/** Per SUBJECT, not per rule.
 *
 *  A selector list is one declaration and several surfaces, and they do not
 *  have to be in the same state. `.queen27-context, .queen27-context-chip` in
 *  QueenContext.css grounded both at --hud-panel in one breath; the card was
 *  frosted and the collapsed chip was not, and the chip floated over the live
 *  scene on its own. (The chip has since been removed from the board, so that
 *  list is one selector now — the shape it exposed is what this guards.)
 *  Every question here used to be asked of the rule with
 *  `subjects.some(...)` or `NO_TEXT.some(...)`, so one qualifying member spoke
 *  for the whole list: the frosted card vouched for the bare chip, and the gate
 *  reported the board clean while an 0.86 ground sat over a moving lattice with
 *  nothing taking its edges out. The same shape hid two more — a selector list
 *  whose one live member is exempt excuses its dead siblings, and NO_TEXT on
 *  one subject excused a sibling that carries a paragraph.
 *
 *  This is a cousin of the bound the file names one screen up, at FROSTED,
 *  where a subject keeps only the rightmost compound of its selector and one
 *  key therefore covers the public page's `.queen27-card` and the board's. That
 *  one cannot be closed from a stylesheet — a class is not an element. This one
 *  could: the subjects of one rule are written on one line, and there was never
 *  a reason to let them answer for each other.
 *
 *  A third was closed with them, and it is the reason `.is-active` is not on
 *  the list of surfaces this gate reports. `.queen27-tri-screen.is-active` is
 *  ONE element with two names. Emitting the classes separately manufactured an
 *  element out of a state — a bare `.is-active` that owed its own ground and
 *  its own blur, when the blur it needed is on the same box, written on
 *  `.queen27-tri-screen`. A compound now enters as one subject spelled as it
 *  appears, and namesOf resolves a lookup for it through the whole name and
 *  then each class in it, in that direction only. */
const nameless = []
for (const rule of RULES) {
  const grounds = groundsIn(rule.body)
  if (!grounds.length) continue
  /* A ground with nobody to attach it to leaves through here, and this is the
     only place that can notice. Everything below is per subject, so a rule
     whose selector reduces to zero subjects is not measured, not exempted and
     not counted — it is simply absent from a summary that goes on printing a
     plausible number. Silence reading as approval is the failure mode this
     whole file was rewritten to stop, and the parser has three known ways to
     produce it: a bare `:root`, a pseudo-element on nothing (`::selection`),
     and a TOP-LEVEL `:is(button, a)` with no class to its left to scope it.
     The scoped form twenty lines up in subjectsOf is handled; these are not,
     and cannot be, because there is no identity in them to key on — `button`
     alone is every button on the board.
     So the gate does not try to name them. It refuses to let one paint a
     translucent dark ground unseen, which is the part that matters: the fix
     for a hit here is to give the rule a class, not to teach this function to
     invent one. */
  if (!rule.subjects.length) nameless.push(whereOf(rule))
  const stated = inkIn(rule.body)
  const ink = stated || MUTED
  const many = rule.subjects.length > 1

  for (const subject of rule.subjects) {
    const names = namesOf(subject)
    if (names.some((n) => EXEMPT.has(n))) continue

    const seal = names.map((n) => SEALED[n]).find(Boolean)
    if (seal) {
      assert.ok(
        opaqueOf(seal),
        `${whereOf(rule)}: ${subject} is excused every question on this board because ` +
          `${seal} stands between it and the hive with a ground that has no alpha in it, ` +
          `and ${seal} no longer paints one. Either make it opaque again or take this ` +
          'entry out of SEALED and let the element answer for itself.',
      )
      sealed += 1
      continue
    }

    const halo = names.map((n) => HALOED[n]).find(Boolean)
    if (halo) {
      assert.ok(
        haloOf(halo),
        `${whereOf(rule)}: ${subject} is excused the ratio because ${halo} draws an ` +
          'opaque dark halo under every glyph it holds, and that halo is gone or has ' +
          'been softened. Restore it, or take this entry out of HALOED — in which case ' +
          'this surface owes a ground, and qa/queen-starfield-contract.mjs has to be ' +
          'asked first, because it is the gate that requires the transparency.',
      )
      haloed += 1
      continue
    }

    const cover = names.map((n) => INSIDE[n]).find(Boolean)
    let field = LIT
    if (cover) {
      const above = groundOf(cover)
      assert.ok(
        above,
        `${whereOf(rule)}: ${subject} is measured against the field that ${cover} ` +
          `lets through, and ${cover} no longer paints a ground at all. Either give it one ` +
          'again or take this entry out of INSIDE and let the element answer for itself.',
      )
      field = composite(above, LIT)
    }

    for (const ground of grounds) {
      measured += 1
      const bg = composite(ground, field)
      const ratio = contrast(composite(ink, bg), bg)
      assert.ok(
        ratio >= 4.5,
        `${whereOf(rule)}: ${subject}${many ? ` (in ${selectorOf(rule)})` : ''} — a ground ` +
          `was thinned until the hive came through the words: alpha ${ground.a}, ` +
          `${ratio.toFixed(2)}:1 against ` +
          `${stated ? 'the colour this rule writes on it' : '--hud-muted'}` +
          `${cover ? ` (over ${cover})` : ''}. ` +
          'Use var(--hud-veil) for a content surface or var(--hud-panel) for chrome — ' +
          'both are chosen by this threshold rather than by eye. If the surface truly ' +
          'carries no text, add it to NO_TEXT above with the evidence that says so; if ' +
          'it carries text but the hive is inside it rather than behind it, UNDER_SCENE ' +
          'is the list, and the evidence is the markup that puts the scene under it; and ' +
          'if an opaque ancestor stands between it and the hive, SEALED is the list, and ' +
          'the evidence is the markup that puts the scene outside that ancestor.',
      )
    }

    /* Asked of the ELEMENT, not of this rule: see FROSTED above. The roster that
       frosts `.queen27-column` sits seven hundred lines from the rule that grounds
       it, and both are correct. */
    if (isFrosted(subject)) continue
    if (cover) {
      assert.ok(
        isFrosted(cover),
        `${whereOf(rule)}: ${subject} is excused from the low pass because ` +
          `${cover} carries one, and ${cover} no longer does. Either frost ${cover} again ` +
          'or frost this rule and take the entry out of INSIDE.',
      )
      excused += 1
      continue
    }
    unfrosted.push(`${whereOf(rule)}: ${subject}${many ? ` (in ${selectorOf(rule)})` : ''}`)
  }
}

assert.deepEqual(
  nameless,
  [],
  'a rule paints a dark translucent ground over the live hive and this gate cannot ' +
    'say WHICH surface it is: the selector reduces to no subject, so every question ' +
    'below was skipped for it and the summary counted it as nothing at all. That is ' +
    'the one outcome this file treats as worse than a failure, because the number it ' +
    'goes on printing stays plausible. Give the rule a class of its own — a bare ' +
    '`:root`, a `::selection`, or a top-level `:is(button, a)` names no element this ' +
    'board can reason about, and teaching the parser to guess one would make every ' +
    'button on the board answer for every other.',
)

assert.deepEqual(
  unfrosted,
  [],
  'a dark translucent ground on the board carries text over a live hex lattice ' +
    'with nothing taking the lattice\'s EDGES out of it. A ratio cannot see this: ' +
    'alpha scales the field\'s amplitude and leaves its spatial frequency alone, so ' +
    'a hexagon edge still crosses the letterforms at full sharpness. Add ' +
    '`backdrop-filter: blur(6px)` (8px for chrome that has to be read while the ' +
    'board moves), or — if a frosted ancestor already low-passes the field for this ' +
    'element — name that ancestor in INSIDE above, where it will be checked.',
)

// ── done ─────────────────────────────────────────────────────────────────────

const worst = table.reduce((a, b) => (a.ratio < b.ratio ? a : b))
const mutedLit = table.find((r) => r.ink === '--hud-muted' && r.ground === '--hud-veil' && r.field === 'lit')
console.log(
  `queen-contrast: ${table.length} pairs measured over a lit and a dark field, ` +
    `worst ${worst.ratio.toFixed(2)}:1 (${worst.ink} on ${worst.ground}, ${worst.field}), ` +
    `--hud-muted on --hud-veil over a lit hive ${mutedLit.ratio.toFixed(2)}:1; ` +
    `${SHEETS.length} stylesheets walked from ${ENTRIES.map((e) => relative(root, e)).join(' + ')}, ` +
    `${RULES.length} rules, ${measured} grounds measured and low-passed ` +
    `(${excused} by a checked ancestor, ${sealed} behind a checked opaque one, ` +
    `${haloed} carried by a checked halo, ${NO_TEXT.length} exempt as draw surfaces, ` +
    `${UNDER_SCENE.length} with the scene inside them)`,
)
