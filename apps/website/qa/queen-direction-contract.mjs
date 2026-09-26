// The contract of the direction filter: what the chips may do to the board,
// and what a colour is allowed to claim.
//
// The owner asked for a filter over CRM, code and content with the cards
// coloured "so that any direction can be picked out". Two things in that
// sentence can go wrong, and they go wrong in different places.
//
//   WHAT THE CHIPS DO is this page's answer, and it is the same property the
//   clients lane is held to in qa/clients-filter-contract.mjs:
//
//       for every input, the cards drawn are a SUBSET of the cards that arrived
//
//   A chip that narrows is one edit away from a chip that ASKS — and the moment
//   it asks, what is on screen stops being a subset of what the hive decided to
//   send. Here the property is checked against every selection a reader can
//   produce and several they cannot: an unknown key, a repeated key, every key
//   at once, a key with no cards behind it.
//
//   WHAT A COLOUR CLAIMS is the classifier's answer. A colour is read as a
//   fact, so a card must only be given one when its title actually said
//   something. The cards the hive sends as a bare `#1234` — 383 of the 1100 on
//   the live board, all of them finished — said nothing, and they must land in
//   `other` rather than being quietly counted as code.
//
// The gate proves its own assertions first: each property is run against a
// deliberately broken implementation, and the run fails if the broken one is
// accepted. A subset check that cannot see a leak is worse than no check,
// because it is read as one.

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

import {
  DIRECTIONS,
  directionColor,
  directionCounts,
  directionLabel,
  directionOf,
  narrowByDirection,
} from '../src/lib/queenDirection.ts'

let checks = 0
const A = (cond, message) => {
  checks += 1
  assert.ok(cond, message)
}
const EQ = (actual, expected, message) => {
  checks += 1
  assert.deepEqual(actual, expected, message)
}

const KEYS = DIRECTIONS.map((direction) => direction.key)

// A board shaped like the real one: a title per direction, the ambiguous ones
// that decide precedence, and the titleless finished cards.
const BOARD = [
  { number: 1, column: 'backlog', title: 'CRM board: clients waiting on a reply' },
  { number: 2, column: 'backlog', title: 'Rewrite the landing content for the docs page' },
  { number: 3, column: 'running', title: 'FPGA: nextpnr fails to place the bitstream' },
  { number: 4, column: 'running', title: 'Prove the parity invariant for ring 00' },
  { number: 5, column: 'review', title: 'Railway deploy skips the workflow on main' },
  { number: 6, column: 'review', title: 'Fix the parser crash on an empty module' },
  { number: 7, column: 'done', title: '#1234' },
  { number: 8, column: 'done', title: '' },
  { number: 9, column: 'blocked', title: 'Wednesday' },
  // Precedence, said out loud: each of these matches TWO rules, and the one it
  // must take is the narrower subject, not the word every ticket contains.
  { number: 10, column: 'backlog', title: 'Add a test for the FPGA bitstream loader' },
  { number: 11, column: 'backlog', title: 'Fix the client onboarding form' },
  { number: 12, column: 'backlog', title: 'Docs: build the release notes' },
]

// ── the classifier ──────────────────────────────────────────────────────────

EQ(directionOf(BOARD[0].title), 'crm', 'a CRM title is CRM')
EQ(directionOf(BOARD[1].title), 'content', 'a content title is content')
EQ(directionOf(BOARD[2].title), 'hardware', 'an FPGA title is hardware')
EQ(directionOf(BOARD[3].title), 'proof', 'a proof title is proof')
EQ(directionOf(BOARD[4].title), 'infra', 'a deploy title is infra')
EQ(directionOf(BOARD[5].title), 'code', 'a parser fix is code')

// No evidence is not a direction. These are the ones a guess would ruin: the
// hive sends a finished card as its own number, and a colour on it would be a
// claim nobody made.
EQ(directionOf('#1234'), 'other', 'a bare issue number is not code')
EQ(directionOf(''), 'other', 'an empty title is not code')
EQ(directionOf('   '), 'other', 'a blank title is not code')
EQ(directionOf(null), 'other', 'a missing title is not code')
EQ(directionOf(undefined), 'other', 'an absent title is not code')
EQ(directionOf('Wednesday'), 'other', 'a title with no evidence is not code')

// Precedence: the table order IS the rule, so the narrow subject wins over the
// word that appears on every ticket ever written.
EQ(directionOf(BOARD[9].title), 'hardware', 'an FPGA test is hardware work with a test in it')
EQ(directionOf(BOARD[10].title), 'crm', 'a client form is CRM work with a form in it')
EQ(directionOf(BOARD[11].title), 'content', 'docs that need building are still docs')

// The false positive that was measured on the live board and must stay dead:
// a clean checkout is a git clone, not a customer.
A(
  directionOf('tri reseal check fails on every clean checkout') !== 'crm',
  'a clean checkout is not a client',
)

// The vocabulary was read off the live board, not invented, and these three
// are the decisions that reading forced. `wave` and `loop` are the commonest
// words among the titles nothing can name — and they stay unnamed, because
// they say how this project organises work, never what the work is about.
EQ(directionOf('Wave 77: the standing charter'), 'other', 'a wave is not a direction')
EQ(directionOf('The loop took the same three tasks twice'), 'other', 'a loop is not a direction')
EQ(directionOf('The backtick gate was blind for eight passes'), 'infra', 'a gate is machinery')
EQ(directionOf('[spec] Specify the evidence contracts'), 'code', 'a spec is source here')

// Whole words, not substrings. `ci` inside "specific" and `lead` inside
// "leading" are the two that a careless rule catches.
EQ(directionOf('The leading edge of the wave'), 'other', 'leading is not a lead')
EQ(directionOf('Be more specific about the sector'), 'other', 'specific is not CI')

// ── the table ───────────────────────────────────────────────────────────────

A(KEYS[KEYS.length - 1] === 'other', 'other is last, because it is the absence of a rule')
A(new Set(KEYS).size === KEYS.length, 'no direction key appears twice')
A(
  DIRECTIONS.filter((direction) => direction.match === null).length === 1,
  'exactly one direction has no rule, and it is other',
)
A(
  DIRECTIONS.find((direction) => direction.key === 'other').match === null,
  'other has no rule: nothing may be matched INTO it',
)
for (const direction of DIRECTIONS) {
  A(direction.en.trim().length > 0, `${direction.key} has an English label`)
  A(direction.ru.trim().length > 0, `${direction.key} has a Russian label`)
  A(/^#[0-9a-f]{6}$/i.test(direction.color), `${direction.key} has a literal colour`)
  A(
    directionLabel(direction.key, 'ru') === direction.ru &&
      directionLabel(direction.key, 'en') === direction.en,
    `${direction.key} is labelled in the reader's language`,
  )
}
// The three the owner asked for, by name, all present.
for (const asked of ['crm', 'content', 'code']) {
  A(KEYS.includes(asked), `the board can still be narrowed to ${asked}`)
}
A(
  new Set(DIRECTIONS.map((direction) => direction.color)).size === DIRECTIONS.length,
  'no two directions share a colour: a legend that repeats itself is a legend that lies',
)
// An unknown key must be a grey nothing rather than an exception: a card from a
// newer build arriving in an older page is a Tuesday, not an outage.
A(directionColor('not-a-direction') === directionColor('other'), 'an unknown key reads as other')
A(directionLabel('not-a-direction', 'ru') === 'NOT-A-DIRECTION', 'an unknown key labels itself')

// ── the counts on the chips ─────────────────────────────────────────────────

const tally = directionCounts(BOARD)
EQ(
  tally.reduce((sum, entry) => sum + entry.count, 0),
  BOARD.length,
  'every card is counted exactly once',
)
EQ(
  tally.map((entry) => entry.key),
  KEYS.filter((key) => tally.some((entry) => entry.key === key)),
  'chips come in table order, which is the order of the legend',
)
A(
  tally.every((entry) => entry.count > 0),
  'no chip is offered for a direction with nothing behind it',
)
EQ(directionCounts([]), [], 'an empty board offers no chips at all')
EQ(
  directionCounts([{ title: '#1' }, { title: '#2' }]).map((entry) => entry.key),
  ['other'],
  'a board of titleless cards says so, instead of calling itself code',
)

// ── the property: narrowing can only ever hide ──────────────────────────────

// Every selection a reader can make, and several they cannot.
const SELECTIONS = [
  [],
  ...KEYS.map((key) => [key]),
  KEYS,
  ['crm', 'content', 'code'],
  ['crm', 'crm', 'crm'],
  ['hardware', 'not-a-direction'],
  ['not-a-direction'],
  ['', ' ', 'CRM'],
]

/**
 * The one property, written once so it can be pointed at both the real
 * narrowing and a broken one. Returns the failures rather than throwing, which
 * is what lets the self-test below prove it can see them.
 */
function subsetViolations(narrow, cards, selections) {
  const problems = []
  const arrived = new Set(cards)
  for (const selection of selections) {
    const shown = narrow(cards, selection)
    const label = JSON.stringify(selection)
    if (!Array.isArray(shown)) {
      problems.push(`${label}: did not return a list`)
      continue
    }
    for (const card of shown) {
      if (!arrived.has(card)) problems.push(`${label}: drew a card that never arrived`)
    }
    if (shown.length > cards.length) problems.push(`${label}: drew more cards than arrived`)
    if (new Set(shown).size !== shown.length) problems.push(`${label}: drew a card twice`)
    const order = shown.map((card) => cards.indexOf(card))
    for (let i = 1; i < order.length; i += 1) {
      if (order[i] <= order[i - 1]) problems.push(`${label}: reordered the board`)
    }
  }
  return problems
}

EQ(
  subsetViolations(narrowByDirection, BOARD, SELECTIONS),
  [],
  'whatever is selected, the board on screen is a subset of the board that arrived',
)

// An empty selection is ALL, not NONE. This is the one a reader hits first.
EQ(narrowByDirection(BOARD, []).length, BOARD.length, 'no selection shows the whole board')
// And it is a copy: narrowing must not be able to edit the board it was given.
A(narrowByDirection(BOARD, []) !== BOARD, 'narrowing hands back its own list')

// Selecting everything and selecting nothing agree, because every card has a
// direction — including the ones whose direction is `other`.
EQ(
  narrowByDirection(BOARD, KEYS).map((card) => card.number),
  BOARD.map((card) => card.number),
  'selecting every direction is the whole board',
)
// Selecting only a key nothing matches empties the board rather than filling it.
EQ(narrowByDirection(BOARD, ['not-a-direction']), [], 'an unknown key shows nothing, not everything')
// The union of the single-key selections is the board, once.
EQ(
  KEYS.flatMap((key) => narrowByDirection(BOARD, [key])).length,
  BOARD.length,
  'the directions partition the board: no card in two, none in none',
)

// ── the wiring, read as text ────────────────────────────────────────────────
//
// The module can be right while the page draws it wrong, and two of the ways
// it can be wrong are cheap to see from here.

const page = readFileSync(new URL('../src/pages/Queen.tsx', import.meta.url), 'utf8')
const style = readFileSync(new URL('../src/pages/Queen.css', import.meta.url), 'utf8')

A(page.includes('narrowByDirection('), 'the board narrows through the module, not by hand')
A(
  !/className="[^"]*queen27-lane-filter[^"]*queen27-dir-filter/.test(page) &&
    !/className="[^"]*queen27-dir-filter[^"]*queen27-lane-filter/.test(page),
  'the direction row does not wear the clients row class: that class is counted ' +
    'next door to prove the ONE clients filter is inside the sign-in check',
)
A(page.includes('data-dir={direction}'), 'a card says which direction it is in')
A(
  /aria-pressed=\{directions\.includes\(key\)\}/.test(page),
  'the pressed state a screen reader hears is the state the chip shows',
)
// Structure is read from the rules, never from the prose around them. These
// comments quote the selectors they are about — the first run of the assertion
// below counted a selector named inside a comment explaining why that selector
// exists, and called it a third rule. Only the palette check keeps reading the
// raw file, on purpose: a stray hex is worth catching wherever it is written.
const css = style.replace(/\/\*[\s\S]*?\*\//g, '')

// The tint has to survive the shell layout, which zeroes card backgrounds on
// purpose at a higher specificity than a bare `.queen27-card[data-dir]`. This
// is not a hypothetical: the first build of this filter shipped the dot, the
// tag and the right edge to the live board and silently dropped the colour,
// and that is the whole of what the ask was for.
// Twice, and the count is the point: the shell states a background for the
// resting card AND for the hovered one, so naming it once leaves the other
// still being thrown away. Counting `:hover` separately is what makes this
// survive an edit that drops the resting selector — the first draft of this
// assertion did not, and a mutation walked straight through it.
EQ(
  css.split('.queen27-page.is-shell .queen27-card[data-dir]').length - 1,
  2,
  'the direction tint outranks the shell rule that clears card backgrounds, ' +
    'at rest and on hover',
)
A(
  css.includes('.queen27-page.is-shell .queen27-card[data-dir]:hover'),
  'the hovered card keeps its direction colour in the shell layout',
)
A(
  !/\.queen27-card\[data-dir\][^{]*\{[^}]*rgba\(255, 255, 255/.test(css),
  'the tint mixes against transparent: one layer of ground, which is the ' +
    'rule the shell layout states for every card on this board',
)

// THE SAME DEFECT, A SECOND TIME, WHICH IS WHY THIS PART IS GENERIC.
//
// The card assertions above were written after the shell layout silently ate
// the card tint. They were written about the card, so they did not notice the
// shell doing exactly the same thing to the CHIP: a 0,3,0 rule replaced the
// pressed chip's background and left its `color: #050505` standing, and the
// selected chip reached the live board as near-black text on the near-black HUD
// panel. Checking the one surface I had just fixed is how the second instance
// shipped, so this scans every rule instead of naming one.
const RULES = [...css.matchAll(/([^{}]*)\{([^{}]*)\}/g)].map((match) => ({
  selector: match[1].trim(),
  body: match[2],
}))

for (const rule of RULES) {
  if (!rule.selector.includes('.is-shell')) continue
  if (!rule.selector.includes('.queen27-chip')) continue
  if (!/background/.test(rule.body)) continue
  A(
    rule.selector.includes(':not([aria-pressed="true"])'),
    'a shell rule may restyle a resting chip and must leave the pressed one ' +
      `alone — this one does not: ${rule.selector}`,
  )
}

// THE SAME DEFECT, A THIRD TIME, WHICH IS WHY THE PROPERTY IS NOW ABOUT INK AS
// WELL AS GROUND.
//
// The loop above says a shell layer may restyle a resting chip's BACKGROUND and
// must leave the pressed one alone. Writing the lane switch produced the mirror
// image of that and slipped straight past it: a shell rule painting the private
// chip's word `--hud-gold`, at 0,3,0 and later in the file than the rule that
// makes the pressed chip's text go dark. Gold on gold. Nothing in the gate was
// looking, because the gate was looking at backgrounds.
//
// So the rule is the rule, in both colours: if a shell selector reaches a chip
// and has an opinion about ink or ground, it must decline to reach the pressed
// one. A pressed chip is a state, and the state owns its own pair.
//
// The class test is `-chip`, not `.queen27-chip`: `.queen27-lane-private-chip`
// does not contain that string, and a check that only knows the base class
// would have watched this one sail past a fourth time.
for (const rule of RULES) {
  if (!rule.selector.includes('.is-shell')) continue
  if (!/\.[\w-]*-chip\b/.test(rule.selector)) continue
  if (!/(?:^|[;{\s])(?:color|background)\s*:/.test(rule.body)) continue
  A(
    rule.selector.includes(':not([aria-pressed="true"])'),
    'a shell rule may colour a resting chip and must leave the pressed one ' +
      `alone — this one does not: ${rule.selector.replace(/\s+/g, ' ')}`,
  )
}

// A pressed chip is black text, so whichever rule wins MUST hand it a light
// background in the same breath. Splitting the two across rules is how the
// invisible chip became possible in the first place.
for (const rule of RULES) {
  if (!/aria-pressed="true"/.test(rule.selector)) continue
  if (!/color:\s*#050505/.test(rule.body)) continue
  A(
    /background:/.test(rule.body),
    `${rule.selector} paints text #050505 without stating its own background`,
  )
}

// The gold pressed chip is ~6300 lines below the direction chip's own rule and
// was beating it on source order at equal specificity. Naming the container is
// what wins; counting is what keeps a later edit from quietly dropping it.
EQ(
  css.split('.queen27-dir-chip[aria-pressed="true"]').length - 1,
  css.split('.queen27-dir-filter .queen27-dir-chip[aria-pressed="true"]')
    .length - 1,
  'every pressed direction-chip rule outranks the shared gold one by naming ' +
    'the filter it lives in, rather than by sitting in the right place',
)

// The colours live in ONE place. A hex from the table appearing in the
// stylesheet would be a second copy of the palette, free to drift.
for (const direction of DIRECTIONS) {
  A(
    !style.toLowerCase().includes(direction.color.toLowerCase()),
    `Queen.css must not carry a second copy of the ${direction.key} colour`,
  )
}

// ── the gate proves itself ──────────────────────────────────────────────────

function selfTest() {
  const cards = BOARD

  // A narrowing that adds a card nobody sent — the leak the property exists for.
  const leaks = (list, selection) => [
    ...narrowByDirection(list, selection),
    { number: 999, column: 'backlog', title: "somebody else's card" },
  ]
  if (!subsetViolations(leaks, cards, SELECTIONS).length) {
    throw new Error('self-test: the subset property did not notice a foreign card')
  }

  // A narrowing that sorts. Harmless-looking, and it means the reader's eye
  // loses the row it was on every time a chip is pressed.
  const sorts = (list, selection) =>
    [...narrowByDirection(list, selection)].sort((a, b) => b.number - a.number)
  if (!subsetViolations(sorts, cards, SELECTIONS).length) {
    throw new Error('self-test: the subset property did not notice a reordering')
  }

  // A narrowing that treats "nothing selected" as "nothing shown".
  const hidesAll = (list, selection) =>
    selection.length === 0 ? [] : narrowByDirection(list, selection)
  if (subsetViolations(hidesAll, cards, SELECTIONS).length) {
    throw new Error('self-test: an empty result is still a subset — the property must allow it')
  }
  // ...which is exactly why the empty selection is asserted separately above.
  if (hidesAll(cards, []).length === cards.length) {
    throw new Error('self-test: the broken narrowing did not break')
  }
}

selfTest()

console.log(`Queen direction contract: PASS (${checks} checks, ${DIRECTIONS.length} directions)`)
