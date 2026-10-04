/**
 * WHO IS PLAYING, WHEN THE BOARD IS ALREADY INSIDE THE APP.
 *
 * The board moved to https://app.t27.ai/queen/ (see legacyQueenRedirect.ts).
 * At that address the bundle is SAME-ORIGIN with the player, and the whole
 * bridge apparatus in triIdentity.ts — a hidden frame, a nonce, a consent
 * popup, a 300 s game token — exists to cross an origin boundary that is no
 * longer there.
 *
 * IT IS NOT MERELY UNNECESSARY. IT CANNOT WORK.
 *
 * Three separate gates pin the bridge to https://t27.ai, and each one alone is
 * enough to leave this page anonymous for ever:
 *
 *   1. triIdentity's own rule 1 (`identityActiveOn`) returns false off t27.ai,
 *      so the board never asks.
 *   2. The bridge answers only a parent whose origin is exactly t27.ai, and
 *      replies with that targetOrigin (999-multibots-telegraf,
 *      player/public/bridge/bridge.js).
 *   3. nginx serves /bridge with `frame-ancestors https://t27.ai`, deliberately
 *      never 'self' — so framing it from app.t27.ai is refused by the browser
 *      before a message is ever sent.
 *
 * So the move would have handed every visitor a board they could never sign in
 * to. This module is the other half of the move.
 *
 * WHAT IT READS, AND WHY THAT IS ALLOWED HERE AND NOWHERE ELSE
 *
 * The player keeps its access token in sessionStorage under the keys below.
 * A document on app.t27.ai may read them because it IS app.t27.ai; the same
 * read from t27.ai is impossible, which is the reason the bridge exists.
 *
 * This token is the app's OWN credential, not a 300 s game token: it carries
 * the full authority of the person, which is exactly right on their own origin
 * (the app's own pages use it for the same calls) and exactly wrong anywhere
 * else. So every rule that guarded the weaker token guards this one:
 * memory only, never storage of our own, never a URL, never a log, never the
 * published snapshot, `credentials: 'omit'`, two headers.
 *
 * AN EMPTY STORE IS SIGNED-OUT, NOT BROKEN.
 *
 * sessionStorage is per-origin AND PER-TAB. A tab that arrived here from a
 * bookmark has never signed into the app, so it holds nothing — the same
 * answer the bridge gives that visitor today, reached without a round trip.
 *
 * Pure, and driven entirely through its argument, so
 * qa/app-session-identity-contract.mjs calls the decision rather than reading
 * this file for reassuring lines.
 */

/** The player's origin. The board's new home is a path on it. */
export const APP_ORIGIN = 'https://app.t27.ai'

/**
 * The only path on the app that serves this bundle (nginx `location ^~
 * /queen/`). Pinned rather than left open: the app is a different product with
 * its own pages, and "any page on app.t27.ai may read the session token" is a
 * much larger claim than the one this move needs.
 */
export const BOARD_PATH = '/queen/'

/**
 * The player's keys, spelled as the player writes them
 * (999-multibots-telegraf, player/public/bridge/bridge.js). Taken from there
 * rather than named afresh: a second spelling reads an empty store for ever
 * and calls the person signed out.
 */
export const ACCESS_KEY = 'trinity.app.session.access'
export const EXPIRES_KEY = 'trinity.app.session.expires-at'

/** Just the read side of sessionStorage, so the contract can drive it. */
export interface SessionStoreLike {
  getItem(key: string): string | null
}

export interface AppSessionEnv {
  origin: string
  pathname: string
  /** null when the browser refuses storage (private mode, blocked cookies). */
  storage: SessionStoreLike | null
  now: number
}

export type AppSessionVerdict =
  /** Not the app's own copy of the board: triIdentity's bridge path decides. */
  | { source: 'bridge' }
  | { source: 'app-session'; state: 'signed-in'; token: string; expiresAt: number }
  | {
      source: 'app-session'
      state: 'signed-out'
      /** Why, for the chip. Never shown as an error: none of these is one. */
      code: 'no_session' | 'expired' | 'no_storage'
    }

/**
 * Is this document the app's own copy of the board?
 *
 * The path is compared with a trailing slash on both sides so that /queenly
 * cannot answer yes, and /queen (no slash) is admitted because nginx redirects
 * it here anyway.
 */
export function onAppBoard(origin: string, pathname: string): boolean {
  if (origin !== APP_ORIGIN) return false
  const path = pathname.endsWith('/') ? pathname : `${pathname}/`
  return path === BOARD_PATH || path.startsWith(BOARD_PATH)
}

/**
 * The credential this document may use, or the instruction to use the bridge.
 *
 * The expiry is the player's own, and it is checked here rather than trusted:
 * a token still sitting in the store past its expiry is not a credential, it
 * is litter from a session that ended. Same rule as the bridge's
 * `accessToken()`, taken from there so the two cannot drift into disagreeing
 * about who is signed in.
 */
export function appSessionIdentity(env: AppSessionEnv): AppSessionVerdict {
  if (!onAppBoard(env.origin, env.pathname)) return { source: 'bridge' }
  if (!env.storage) return { source: 'app-session', state: 'signed-out', code: 'no_storage' }

  let token: string | null = null
  let expires: string | null = null
  try {
    token = env.storage.getItem(ACCESS_KEY)
    expires = env.storage.getItem(EXPIRES_KEY)
  } catch {
    // A store that throws on read is a store we do not have.
    return { source: 'app-session', state: 'signed-out', code: 'no_storage' }
  }

  if (!token) return { source: 'app-session', state: 'signed-out', code: 'no_session' }

  // An unparseable or absent expiry is treated as expired, never as "no expiry
  // means for ever": the one direction that fails safe.
  const expiresAt = Number(expires)
  if (!Number.isFinite(expiresAt) || expiresAt <= env.now) {
    return { source: 'app-session', state: 'signed-out', code: 'expired' }
  }

  return { source: 'app-session', state: 'signed-in', token, expiresAt }
}

/**
 * Reads the live document. Split from the decision above because the decision
 * is the part worth testing and the browser is the part that cannot be.
 */
export function appSessionFromWindow(): AppSessionVerdict {
  if (typeof window === 'undefined') return { source: 'bridge' }
  let storage: SessionStoreLike | null = null
  try {
    storage = window.sessionStorage
  } catch {
    storage = null
  }
  return appSessionIdentity({
    origin: window.location.origin,
    pathname: window.location.pathname,
    storage,
    now: Date.now(),
  })
}
