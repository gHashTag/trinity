/**
 * INVITE SOMEONE TO WATCH YOUR BROWSER.
 *
 * The render server has had read-only watch links since 2026-10-03
 * (gHashTag/999-multibots-telegraf #3510, render/src/browser/watch-link.ts):
 * a person mints a link, sends it, and whoever opens it sees the person's
 * browser live -- frames only. A viewer has no input path at all: no click,
 * no key, no wheel, no agent. Private sites (mail, bank, a password field)
 * are held, not shown. Nothing on the board or in the app could reach those
 * links, so the feature existed and nobody could use it. This is the board's
 * half.
 *
 * THE RULES THE SERVER SETS, MIRRORED SO THE PANEL NEVER ASKS FOR A REFUSAL:
 *
 *   - only the person makes, lists or revokes a link (the agent key is 403:
 *     an agent that could mint a link could publish its owner's screen);
 *   - a link lives above 0 and at most 72 hours, 24 by default;
 *   - at most 5 live links; a sixth is 409 until one is revoked or ends;
 *   - at most 2 viewers per link;
 *   - the TOKEN is in the answer to the create call only, once. The list has
 *     the short id (enough to revoke, not to open). So the address is shown
 *     once and kept nowhere: not in storage, not in a URL of ours, not in a
 *     log. Lose it and the move is revoke and make another.
 *
 * WHY NOT JUST SHARE /live/. The /live/<id> address the panel frames swaps a
 * view token for a cookie that DRIVES the browser. Handing that out is the
 * anti-pattern every competitor with a "read-only" CSS overlay ships; a
 * watch link is enforced on the server instead.
 *
 * Pure and driven through its arguments, like queenBrowser.ts, so
 * qa/queen-watch-contract.mjs calls the decisions with a fake fetch.
 */

import { BROKER_BASE } from './queenBrowser.ts'

export const WATCH_DEFAULT_HOURS = 24
export const WATCH_MAX_HOURS = 72
export const WATCH_MAX_ACTIVE = 5
export const WATCH_MAX_VIEWERS = 2
export const WATCH_LABEL_MAX = 60
/** The three lengths the panel offers: an hour, a day, the most the server allows. */
export const WATCH_HOURS_CHOICES: readonly number[] = [1, WATCH_DEFAULT_HOURS, WATCH_MAX_HOURS]
/** While a link is live and the board is on screen, who is watching is re-read this often. */
export const WATCH_POLL_MS = 15_000

const WATCH_PATH = '/api/browser/watch-links'
/** render watch-link.ts TOKEN_SHAPE and idOf: what a token and an id look like. */
const TOKEN_SHAPE = /^[A-Za-z0-9_-]{32,64}$/
const ID_SHAPE = /^[0-9a-f]{12}$/

export interface WatchLink {
  id: string
  label: string | null
  createdAt: string
  expiresAt: string
  revoked: boolean
  live: boolean
  views: number
  watchingNow: number
  lastViewAt: string | null
}

export interface MintedLink {
  id: string
  /** Shown once. Never stored. */
  url: string
  expiresAt: string
}

/** Same rules as BrokerEnv in queenBrowser.ts, plus a body for the one POST. */
export interface WatchEnv {
  fetch(
    url: string,
    init: { method: string; credentials: 'omit'; headers: Record<string, string>; body?: string },
  ): Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
  token(): string | null
}

/**
 * Why a call did not do what it was asked, in the words the panel needs:
 *
 *   signin -- no session in this tab, or it just expired (401);
 *   person -- the server says this is not the person (403);
 *   full   -- five links are live already (409);
 *   bad    -- the server did not accept what was sent (400, or an id that
 *             was never an id and so was not sent at all);
 *   gone   -- nothing to revoke: already revoked, ended, or not theirs (404);
 *   failed -- anything else, including no network and an answer of the
 *             wrong shape.
 */
export type WatchRefusal = 'signin' | 'person' | 'full' | 'bad' | 'gone' | 'failed'

export type WatchAnswer<T> = { ok: true; value: T } | { ok: false; why: WatchRefusal }

export function refusalOf(status: number): WatchRefusal {
  if (status === 401) return 'signin'
  if (status === 403) return 'person'
  if (status === 409) return 'full'
  if (status === 400) return 'bad'
  if (status === 404) return 'gone'
  return 'failed'
}

/** Hours the server will accept: a non-number is the default, the rest is held to (0, 72]. */
export function clampHours(hours: unknown): number {
  const n = typeof hours === 'number' ? hours : Number(hours)
  if (!Number.isFinite(n) || n <= 0) return WATCH_DEFAULT_HOURS
  return Math.min(n, WATCH_MAX_HOURS)
}

/** A label is a note to the person, trimmed and cut where the server cuts it; empty is none. */
export function cleanLabel(label: unknown): string | null {
  if (typeof label !== 'string') return null
  const flat = Array.from(label, ch => (ch.charCodeAt(0) < 32 || ch.charCodeAt(0) === 127 ? ' ' : ch)).join('')
  const t = flat.trim().slice(0, WATCH_LABEL_MAX).trim()
  return t || null
}

/**
 * The only address the panel will show for a minted link: https, nobody's
 * credentials in it, the path exactly /watch/<token>, no query, no fragment.
 * The host is the server's PUBLIC_URL, which the board cannot know -- so the
 * host is not judged, the shape is. An answer of any other shape is not
 * rendered as a link (a javascript: or data: address would be one click).
 */
export function watchUrlOf(url: unknown): string | null {
  if (typeof url !== 'string') return null
  let u: URL
  try {
    u = new URL(url)
  } catch {
    return null
  }
  if (u.protocol !== 'https:' || u.username || u.password || u.search || u.hash) return null
  const m = /^\/watch\/([^/]+)$/.exec(u.pathname)
  if (!m || !TOKEN_SHAPE.test(m[1])) return null
  return u.toString()
}

function linkOf(raw: unknown): WatchLink | null {
  if (!raw || typeof raw !== 'object') return null
  const r = raw as Record<string, unknown>
  if (typeof r.id !== 'string' || !ID_SHAPE.test(r.id)) return null
  if (typeof r.expiresAt !== 'string') return null
  const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : 0)
  return {
    id: r.id,
    label: typeof r.label === 'string' ? r.label : null,
    createdAt: typeof r.createdAt === 'string' ? r.createdAt : r.expiresAt,
    expiresAt: r.expiresAt,
    revoked: r.revoked === true,
    live: r.live === true && r.revoked !== true,
    views: num(r.views),
    watchingNow: num(r.watchingNow),
    lastViewAt: typeof r.lastViewAt === 'string' ? r.lastViewAt : null,
  }
}

async function call(
  env: WatchEnv,
  method: 'GET' | 'POST' | 'DELETE',
  query: string,
  body?: string,
): Promise<{ ok: true; json: unknown } | { ok: false; why: WatchRefusal }> {
  const token = env.token()
  if (!token) return { ok: false, why: 'signin' }
  const headers: Record<string, string> = { Authorization: `Bearer ${token}` }
  if (body !== undefined) headers['Content-Type'] = 'application/json'
  try {
    const res = await env.fetch(`${BROKER_BASE}${WATCH_PATH}${query}`, {
      method,
      credentials: 'omit',
      headers,
      ...(body !== undefined ? { body } : {}),
    })
    if (!res.ok) return { ok: false, why: refusalOf(res.status) }
    return { ok: true, json: await res.json() }
  } catch {
    return { ok: false, why: 'failed' }
  }
}

/** The person's links, newest first, malformed rows dropped. Never throws. */
export async function listWatchLinks(env: WatchEnv): Promise<WatchAnswer<WatchLink[]>> {
  const r = await call(env, 'GET', '')
  if (!r.ok) return r
  const links = (r.json as { links?: unknown })?.links
  if (!Array.isArray(links)) return { ok: false, why: 'failed' }
  return { ok: true, value: links.map(linkOf).filter((l): l is WatchLink => l !== null) }
}

/**
 * Mint a link. The answer's address is checked before it is handed back; a
 * link the panel will not show is revoked on the spot, because a live link
 * its owner cannot see is a door nobody knows is open. Never throws.
 */
export async function createWatchLink(
  env: WatchEnv,
  want: { hours?: unknown; label?: unknown } = {},
): Promise<WatchAnswer<MintedLink>> {
  const label = cleanLabel(want.label)
  const body = JSON.stringify({ hours: clampHours(want.hours), ...(label ? { label } : {}) })
  const r = await call(env, 'POST', '', body)
  if (!r.ok) return r
  const j = (r.json ?? {}) as Record<string, unknown>
  const id = typeof j.id === 'string' && ID_SHAPE.test(j.id) ? j.id : null
  const url = watchUrlOf(j.url)
  if (!url || !id || typeof j.expiresAt !== 'string') {
    if (id) await revokeWatchLink(env, id)
    return { ok: false, why: 'failed' }
  }
  return { ok: true, value: { id, url, expiresAt: j.expiresAt } }
}

/** Revoke by the short id. An id that is not one is never sent. Never throws. */
export async function revokeWatchLink(env: WatchEnv, id: string): Promise<WatchAnswer<true>> {
  if (!ID_SHAPE.test(id)) return { ok: false, why: 'bad' }
  const r = await call(env, 'DELETE', `?id=${id}`)
  if (!r.ok) return r
  return (r.json as { revoked?: unknown })?.revoked === true ? { ok: true, value: true } : { ok: false, why: 'gone' }
}

/** Live links only: the ones that could be opened right now. */
export const liveLinks = (links: WatchLink[], nowMs: number): WatchLink[] =>
  links.filter(l => l.live && !l.revoked && Date.parse(l.expiresAt) > nowMs)

/** How many people are watching the browser right now, over every live link. */
export const watchingNow = (links: WatchLink[], nowMs: number): number =>
  liveLinks(links, nowMs).reduce((n, l) => n + l.watchingNow, 0)

/** May the panel offer to make another? (The server would answer 409 otherwise.) */
export const canMint = (links: WatchLink[], nowMs: number): boolean => liveLinks(links, nowMs).length < WATCH_MAX_ACTIVE

/** Re-read who is watching only while there is something that could be watched. */
export const shouldPollWatch = (links: WatchLink[], nowMs: number): boolean => liveLinks(links, nowMs).length > 0

/** What is left of a link, short: "23 h", "45 min", or null when it has ended. */
export function timeLeft(expiresAt: string, nowMs: number, lang: 'ru' | 'en'): string | null {
  const left = Date.parse(expiresAt) - nowMs
  if (!Number.isFinite(left) || left <= 0) return null
  const min = Math.ceil(left / 60_000)
  if (min < 60) return `${min} ${lang === 'ru' ? 'мин' : 'min'}`
  return `${Math.round(min / 60)} ${lang === 'ru' ? 'ч' : 'h'}`
}
