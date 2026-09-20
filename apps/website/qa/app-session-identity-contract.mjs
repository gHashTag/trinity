// The board's identity at its new home, where the bridge cannot reach it.
//
// THE FAILURE THIS GATE EXISTS FOR. The move to app.t27.ai/queen/ was landed
// as a redirect (qa/queen-redirect-contract.mjs) while identity was still
// pinned to https://t27.ai in three independent places -- this module's own
// rule 1, the player's bridge page, and nginx's frame-ancestors on /bridge,
// which is https://t27.ai and deliberately never 'self'. Each alone is enough.
// Shipped like that, every visitor would have been handed over to a board they
// could never sign in to, and the owner's ask -- the Telegram auth layer from
// app.t27.ai -- would have been the exact thing the move broke.
//
// So this calls the decision with real inputs. Reading the source for a
// reassuring line is the failure mode of gHashTag/999-multibots-telegraf#2634:
// of 202 audited claims not one earned "works", and the evidence that
// collapsed was a faked fetch, a faked pool, or a readFileSync of the source.
//
//   node --experimental-strip-types qa/app-session-identity-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  appSessionIdentity,
  onAppBoard,
  APP_ORIGIN,
  BOARD_PATH,
  ACCESS_KEY,
  EXPIRES_KEY,
} from '../src/lib/appSessionIdentity.ts'

const NOW = 1_700_000_000_000
const store = (entries) => ({ getItem: (k) => (k in entries ? entries[k] : null) })
const live = { [ACCESS_KEY]: 'app-access-token', [EXPIRES_KEY]: String(NOW + 60_000) }

const verdict = (over = {}) =>
  appSessionIdentity({
    origin: APP_ORIGIN,
    pathname: BOARD_PATH,
    storage: store(live),
    now: NOW,
    ...over,
  })

// ---------------------------------------------------------------- the address

// Only the app's own copy of the board reads the app's session. Everywhere
// else the bridge decides, exactly as before -- this module adds a source, it
// does not replace one.
const ELSEWHERE = [
  ['https://t27.ai', '/', 'the old home still uses the bridge'],
  ['https://t27.ai', '/queen/', 'the path alone is not the app'],
  ['http://localhost:5175', '/', 'a dev build is not the app'],
  ['https://app.t27.ai.evil.example', '/queen/', 'a look-alike origin'],
  ['https://app.t27.ai', '/', "the app's own front page is not the board"],
  ['https://app.t27.ai', '/queenly/', 'a path that merely starts the same'],
  ['https://app.t27.ai', '/crm/', "the app's other pages are not this bundle"],
]
for (const [origin, pathname, why] of ELSEWHERE) {
  assert.equal(verdict({ origin, pathname }).source, 'bridge', `${origin}${pathname}: ${why}`)
  assert.equal(onAppBoard(origin, pathname), false, `onAppBoard ${origin}${pathname} (${why})`)
}

const HERE = [
  ['/queen/', 'the address nginx serves'],
  ['/queen', 'without the slash, which nginx 301s here anyway'],
  ['/queen/index.html', 'the document itself'],
  ['/queen/anything', 'a deeper path of the same bundle'],
]
for (const [pathname, why] of HERE) {
  assert.equal(onAppBoard(APP_ORIGIN, pathname), true, `onAppBoard ${pathname} (${why})`)
  assert.equal(verdict({ pathname }).source, 'app-session', `${pathname}: ${why}`)
}

// ------------------------------------------------------------- the credential

const signedIn = verdict()
assert.deepEqual(signedIn, {
  source: 'app-session',
  state: 'signed-in',
  token: 'app-access-token',
  expiresAt: NOW + 60_000,
})

// Every way of not being signed in. NONE of them is an error: a person who has
// not signed into the app in this tab is signed out, and a board that showed
// them a failure would be lying about its own health.
const SIGNED_OUT = [
  [{ storage: store({}) }, 'no_session', 'an empty store: this tab never signed in'],
  [
    { storage: store({ [EXPIRES_KEY]: String(NOW + 60_000) }) },
    'no_session',
    'an expiry with no token is not a session',
  ],
  [
    { storage: store({ ...live, [EXPIRES_KEY]: String(NOW - 1) }) },
    'expired',
    'a token past the expiry the player itself wrote',
  ],
  [
    { storage: store({ ...live, [EXPIRES_KEY]: String(NOW) }) },
    'expired',
    'expiring exactly now is expired, not alive',
  ],
  [
    { storage: store({ [ACCESS_KEY]: 'app-access-token' }) },
    'expired',
    'NO EXPIRY IS NOT FOR EVER: the one direction that must fail safe',
  ],
  [
    { storage: store({ ...live, [EXPIRES_KEY]: 'soon' }) },
    'expired',
    'an unparseable expiry is not a licence',
  ],
  [{ storage: null }, 'no_storage', 'a browser that refuses storage'],
  [
    {
      storage: {
        getItem() {
          throw new Error('blocked')
        },
      },
    },
    'no_storage',
    'a store that throws on read is a store we do not have',
  ],
]
for (const [over, code, why] of SIGNED_OUT) {
  const v = verdict(over)
  assert.equal(v.state, 'signed-out', why)
  assert.equal(v.code, code, `${why}: code`)
  assert.equal('token' in v, false, `${why}: a refused verdict carries no token`)
}

// --------------------------------------------------------------- the handling

// The token is the app's OWN credential, far stronger than the 300 s game
// token the bridge mints. So the module that reads it must only ever read:
// anything it wrote would outlive the app's own sign-out and become a
// credential nobody can revoke.
const source = readFileSync(new URL('../src/lib/appSessionIdentity.ts', import.meta.url), 'utf8')
for (const forbidden of ['setItem', 'removeItem', 'localStorage', 'document.cookie']) {
  assert.ok(!source.includes(forbidden), `appSessionIdentity.ts must not use ${forbidden}`)
}

// The keys are the player's, and the player is in another repository. Spelled
// wrong, every read returns null and every visitor is quietly signed out --
// which looks exactly like "nobody has signed in yet" and so would never be
// reported as a defect. Pinned here as literals so a rename has to come past
// this line.
assert.equal(ACCESS_KEY, 'trinity.app.session.access')
assert.equal(EXPIRES_KEY, 'trinity.app.session.expires-at')

// The identity module must actually consult this source. A decision nobody
// calls decides nothing, and a gate that only exercised the function would
// pass in exactly that case.
const identity = readFileSync(new URL('../src/lib/triIdentity.ts', import.meta.url), 'utf8')
// Named precisely. An earlier version of this assertion matched the module
// PATH, which a type-only import satisfies -- so deleting the call left the
// gate green. The two halves are asserted apart because either alone is a
// board that never signs anybody in: the wiring into the live env, and the
// call that consults it.
assert.match(
  identity,
  /appSession:\s*appSessionFromWindow/,
  'browserEnv() does not wire the app session into the identity env'
)
// start() must consult the session, and must do it BEFORE rule 1. Rule 1 is
// about the bridge and is false on app.t27.ai, so checked first it publishes
// not_t27 — "you are not on t27.ai" — to a person who is signed into the app
// two documents away. That is the exact bug this whole file exists to prevent,
// so the order is asserted and not left to a comment.
const consults = identity.indexOf('const app = env.appSession')
assert.notEqual(
  consults,
  -1,
  'start() never calls env.appSession(): the app-session source is dead code'
)
const ruleOne = identity.indexOf("code: 'not_t27'")
assert.notEqual(ruleOne, -1, "triIdentity no longer publishes not_t27 -- update this gate")
assert.ok(
  consults < ruleOne,
  'the app session must be read before rule 1 rejects the origin, or the app ' +
    "board publishes not_t27 for a person who is signed in"
)

console.log(
  `app-session-identity: ${HERE.length} addresses read the app session, ` +
    `${ELSEWHERE.length} leave it to the bridge, ${SIGNED_OUT.length} ways to be signed out`
)
