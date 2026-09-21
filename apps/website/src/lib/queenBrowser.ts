/**
 * THE PERSON'S OWN BROWSER, AS A VIEW OF THE QUEEN.
 *
 * Owner, 2026-09-21: the browser from the app goes into its own tab here,
 * beside KANBAN. It is the SAME browser -- one pod per person, the one the
 * app's Browser tab shows and the agent drives (gHashTag/999-multibots-telegraf,
 * docs/architecture/remote-browser-per-user.md). Not a copy, not a second pod.
 *
 * WHY THIS CAN WORK HERE AT ALL. The board is served at app.t27.ai/queen/, the
 * same origin as the app (see appSessionIdentity.ts). That gives two things
 * nothing else could:
 *
 *   - the app's access token, read from the tab's own sessionStorage, so the
 *     broker knows whose browser this is without a bridge or a game token;
 *   - the viewer's cookie. The broker answers a PATH, `/live/<id>?t=...`, and
 *     the app's nginx proxies /live/ under this same origin, so the cookie the
 *     window sets is first-party. A cross-site frame would load and then be
 *     refused (SameSite=Lax; WKWebView drops third-party cookies outright).
 *     So a view address that resolves anywhere but our own origin is never
 *     framed -- `frameSrcOf` returns null for it.
 *
 * WHAT THIS VIEW NEVER DOES ON ITS OWN.
 *
 *   - It never STARTS a browser. Opening one wakes a pod and costs a person a
 *     machine; reading the status is free. Only a press of Open posts.
 *   - It never asks for, types or holds a password. Passwords are typed by the
 *     person inside the stream and go straight into the pod.
 *   - It never talks to the pod. Everything it knows is what the broker chose
 *     to say: a state, a session id and a path.
 *
 * Pure and driven through its arguments, so qa/queen-browser-contract.mjs
 * calls the decisions instead of reading this file for reassuring lines.
 */

import type { AppSessionVerdict } from './appSessionIdentity.ts'

/** The broker lives on the render server, like /mcp (triIdentity.RENDER_BASE). */
export const BROKER_BASE = 'https://vibee-render-production.up.railway.app'

/** The only path prefix the broker hands out for a viewer window. */
export const LIVE_PREFIX = '/live/'

/** The app's own Browser tab, for the one place this view cannot frame it. */
export const APP_BROWSER_URL = 'https://app.t27.ai/browser'

export type BrowserState = 'none' | 'starting' | 'live' | 'unavailable' | 'signin'

export interface BrowserView {
  state: BrowserState
  sessionId?: string
  viewUrl?: string
}

/**
 * What the panel is, before any network:
 *
 *   preview  -- a homepage block (?embed=1). Many previews on one page; none
 *               of them may touch a person's browser, not even to read it.
 *   nested   -- the board is itself inside the app (the Hive tab). The app
 *               already has a Browser tab; a pod window inside a board inside
 *               the app is a stamp, so this points there instead.
 *   signin   -- no app session in this tab. Not an error: the ordinary visit.
 *   ready    -- signed in, on the app's own copy of the board.
 */
export type PanelMode = 'preview' | 'nested' | 'signin' | 'ready'

export function panelMode(input: { embedded: boolean; nested: boolean; session: AppSessionVerdict }): PanelMode {
  if (input.embedded) return 'preview'
  if (input.nested) return 'nested'
  // `bridge` means this is not the app's copy of the board (t27.ai, a local
  // build). There is no first-party /live/ there, so nothing to show but the
  // way to the app.
  if (input.session.source !== 'app-session') return 'signin'
  return input.session.state === 'signed-in' ? 'ready' : 'signin'
}

const STATES: readonly BrowserState[] = ['none', 'starting', 'live', 'unavailable', 'signin']

/**
 * The broker's answer, narrowed. An unknown state is `none` rather than passed
 * through: the panel renders one of five states, and a sixth word from a newer
 * server must not reach the screen as a blank.
 */
export function viewOf(answer: unknown): BrowserView {
  const a = (answer && typeof answer === 'object' ? answer : {}) as Record<string, unknown>
  const state = STATES.includes(a.state as BrowserState) ? (a.state as BrowserState) : 'none'
  const view: BrowserView = { state }
  if (typeof a.sessionId === 'string') view.sessionId = a.sessionId
  if (typeof a.viewUrl === 'string') view.viewUrl = a.viewUrl
  return view
}

/**
 * The address to frame, or null when it must not be framed here.
 *
 * Framed only when it resolves to OUR OWN origin under /live/: anywhere else
 * the viewer's cookie is third-party and the window would open and then
 * forget the person. The broker is expected to return a path; an absolute URL
 * is honoured only if it happens to be ours.
 */
export function frameSrcOf(viewUrl: string | undefined, ownOrigin: string): string | null {
  if (!viewUrl) return null
  let url: URL
  try {
    url = new URL(viewUrl, ownOrigin)
  } catch {
    return null
  }
  if (url.origin !== ownOrigin) return null
  if (!url.pathname.startsWith(LIVE_PREFIX)) return null
  return url.toString()
}

export type BrokerCall = 'read' | 'open' | 'close'

const METHOD: Record<BrokerCall, 'GET' | 'POST' | 'DELETE'> = { read: 'GET', open: 'POST', close: 'DELETE' }

export interface BrokerEnv {
  fetch(
    url: string,
    init: { method: string; credentials: 'omit'; headers: Record<string, string> },
  ): Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
  /** Read at call time: the token may expire while the tab stays open. */
  token(): string | null
}

/**
 * One call to the broker, with the two refusals it answers by design turned
 * into states: 401 is "sign in" (no session, or one that just expired) and 503
 * is "not on this server" (no pod driver). Anything else is a real failure and
 * is thrown for the panel to say so.
 *
 * The token goes out in exactly one header, with credentials omitted: the same
 * rule appSessionIdentity.ts sets for this credential -- never a URL, never a
 * cookie of ours, never a log.
 */
export async function callBroker(env: BrokerEnv, call: BrokerCall): Promise<BrowserView> {
  const token = env.token()
  if (!token) return { state: 'signin' }
  const res = await env.fetch(`${BROKER_BASE}/api/browser/session`, {
    method: METHOD[call],
    credentials: 'omit',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
  })
  if (res.status === 401) return { state: 'signin' }
  if (res.status === 503) return { state: 'unavailable' }
  if (!res.ok) throw new Error(`broker ${res.status}`)
  return viewOf(await res.json().catch(() => ({})))
}

/** How long a `starting` answer waits before it is asked again. */
export const STARTING_POLL_MS = 2000
