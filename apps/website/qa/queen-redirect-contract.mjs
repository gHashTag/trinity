// The Queen moved to app.t27.ai/queen/, and this address hands visitors over.
//
// The board is now built and served by app.t27.ai (999-multibots-telegraf, the
// `queen` Docker stage and `location ^~ /queen/`). https://t27.ai/#/queen is
// the OLD address, and every link, bookmark and pasted URL still has to arrive
// somewhere useful.
//
// THE FAILURE THIS GATE EXISTS FOR: one bundle, two origins. app.t27.ai builds
// the board FROM THIS REPOSITORY, so the redirect code also runs at the
// destination. Keyed on the route alone it would send that page to itself for
// ever, and an infinite redirect is not a subtle defect -- it is the board
// being unreachable at the only address that now serves it.
//
// So this gate CALLS the decision with real inputs instead of reading the
// source for reassuring lines. That distinction is the whole finding of
// gHashTag/999-multibots-telegraf#2634: of 55 functions audited, not one
// earned "works", almost all downgraded because their evidence turned out to
// be a faked fetch, a faked pool, or a readFileSync of the source checking
// that a line is present.
//
//   node --experimental-strip-types qa/queen-redirect-contract.mjs

import assert from 'node:assert/strict'
import {
  queenRedirectTarget,
  QUEEN_HOME,
} from '../src/lib/legacyQueenRedirect.ts'

/** A window.location, as the decision reads it. */
const at = (url) => {
  const u = new URL(url)
  return { hostname: u.hostname, pathname: u.pathname, search: u.search, hash: u.hash }
}

const MOVED = [
  {
    why: 'the bare address the board was linked by',
    url: 'https://t27.ai/#/queen',
    to: 'https://app.t27.ai/queen/#/queen',
  },
  {
    why: 'the kanban link the owner actually sends people',
    url: 'https://t27.ai/#/queen?tab=kanban',
    to: 'https://app.t27.ai/queen/#/queen?tab=kanban',
  },
  {
    why: 'the language lives in the search and the tab in the hash; both survive',
    url: 'https://t27.ai/?lang=ru#/queen?tab=kanban',
    to: 'https://app.t27.ai/queen/?lang=ru#/queen?tab=kanban',
  },
  {
    why: 'www 301s to the apex, but a redirect that fires one hop earlier costs nothing',
    url: 'https://www.t27.ai/#/queen',
    to: 'https://app.t27.ai/queen/#/queen',
  },
  {
    why: 'a deeper board route is still the board',
    url: 'https://t27.ai/#/queen/anything',
    to: 'https://app.t27.ai/queen/#/queen/anything',
  },
]

for (const c of MOVED) {
  assert.equal(
    queenRedirectTarget(at(c.url), true),
    c.to,
    `${c.url} should move (${c.why})`
  )
}

const STAYS = [
  {
    why: 'THE LOOP. This same bundle runs at the destination; by hostname.',
    url: 'https://app.t27.ai/queen/#/queen',
    top: true,
  },
  {
    why: 'THE LOOP, caught a second time by the path, if the host list ever grows',
    url: 'https://t27.ai/queen/#/queen',
    top: true,
  },
  {
    why: 'a framed copy: navigating out of a frame is done TO the host, not by it',
    url: 'https://t27.ai/#/queen',
    top: false,
  },
  {
    why: 'an embedded preview asks nobody for an identity and is not a visitor',
    url: 'https://t27.ai/#/queen?embed=1',
    top: true,
  },
  {
    why: 'another page on t27.ai is not the board',
    url: 'https://t27.ai/#/skills',
    top: true,
  },
  {
    why: 'the landing page is not the board',
    url: 'https://t27.ai/',
    top: true,
  },
  {
    why: 'a route that merely starts with the same letters',
    url: 'https://t27.ai/#/queenly',
    top: true,
  },
  {
    why: 'a lookalike host is not this one',
    url: 'https://evil-t27.ai/#/queen',
    top: true,
  },
  {
    why: 'a subdomain is not the apex',
    url: 'https://old.t27.ai/#/queen',
    top: true,
  },
  {
    why: 'dev: a local build must stay where the developer put it',
    url: 'http://localhost:5175/#/queen?tab=kanban',
    top: true,
  },
]

for (const c of STAYS) {
  assert.equal(
    queenRedirectTarget(at(c.url), c.top),
    null,
    `${c.url} (top=${c.top}) should stay (${c.why})`
  )
}

// Following the redirect must reach a resting place. Feeding the answer back in
// is the loop the gate above is about, stated as the property rather than as a
// list of hosts -- if someone adds an origin to OLD_HOSTS that the destination
// also matches, this fails without anyone having thought to add a case.
for (const c of MOVED) {
  const once = queenRedirectTarget(at(c.url), true)
  assert.equal(
    queenRedirectTarget(at(once), true),
    null,
    `${c.url} redirects again after arriving -- infinite loop`
  )
}

// The destination is the address nginx serves, trailing slash included: without
// it nginx answers 301 to /queen/ and every visitor pays a second round trip.
assert.equal(QUEEN_HOME, 'https://app.t27.ai/queen/')
assert.ok(QUEEN_HOME.endsWith('/'), 'QUEEN_HOME must end in a slash')

// The entry calls it. A pure function nobody invokes redirects nobody -- and a
// gate that only exercised the function would pass in exactly that case.
const entry = await import('node:fs').then((fs) =>
  fs.readFileSync(new URL('../src/main.tsx', import.meta.url), 'utf8')
)
assert.match(
  entry,
  /redirectLegacyQueen\(\)/,
  'src/main.tsx does not call redirectLegacyQueen()'
)
assert.ok(
  entry.indexOf('redirectLegacyQueen()') < entry.indexOf('triIdentity().prime()'),
  'redirect must be decided before the identity bridge is primed: priming ' +
    'costs a cross-origin document for a page that is about to leave'
)

console.log(
  `queen-redirect: ${MOVED.length} addresses move, ${STAYS.length} stay, ` +
    `${MOVED.length} proved to settle after one hop`
)
