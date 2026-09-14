// Who is playing: the TRI identity of the visitor on https://t27.ai, live,
// without this page ever holding the player's session.
//
// The player on https://app.t27.ai is the only credential holder. It mints a
// game token (300 s, v:2, audience https://t27.ai, accepted by /mcp for whoami
// and hive_pulse only) and hands it to this page by postMessage:
//
//   game -> player:  {v:1, type:'tri-identity-request', nonce}
//   player -> game:  {v:1, type:'tri-identity', nonce, state, game_token?, expires_in?, telegram_id?, code?}
//                    (nonce null: a state change the player sends unprompted)
//
// Who answers: when the game is framed by the player (its Hive tab), the parent
// window. Otherwise a hidden frame of https://app.t27.ai/bridge, shown small only
// while the bridge needs a click to continue ('consent-required').
//
// THE RULES THIS FILE KEEPS (qa/tri-identity-contract.mjs holds it to them):
//   1. Active on https://t27.ai only. Any other origin stays anonymous.
//   2. A reply counts only from https://app.t27.ai AND from the one window asked
//      (the parent, or the bridge frame), with the nonce of the open request or
//      nonce null.
//   3. The game token lives in this module's memory: never storage, never a
//      URL, never a log, never the published snapshot.
//   4. whoami goes out with credentials 'omit' and exactly two headers,
//      Content-Type and Authorization. Never X-Agent-Key: the console's agent
//      key (crmClient.ts) is a different path and never meets this one.
//
// Everything that touches the browser comes in through IdentityEnv, so the
// contract drives the same code with fakes.

export const GAME_ORIGIN = 'https://t27.ai'
export const APP_ORIGIN = 'https://app.t27.ai'
export const BRIDGE_URL = `${APP_ORIGIN}/bridge`
export const RENDER_BASE = 'https://vibee-render-production.up.railway.app'

/** Without an answer this long after asking, the identity is 'unavailable'. */
export const IDENTITY_ANSWER_MS = 10000
/** Ask again this long before the token expires. */
export const RENEW_BEFORE_S = 30

/** Spelled as the player sends them: public/bridge/bridge.js and src/lib/hive.ts. */
export const IDENTITY_STATES = ['signed-in', 'signed-out', 'consent-required', 'unavailable'] as const
export type IdentityState = (typeof IDENTITY_STATES)[number]
export const HIVE_ROLES = ['keeper', 'owner', 'bee'] as const
export type HiveRole = (typeof HIVE_ROLES)[number]

export interface IdentityReply {
  state: IdentityState
  nonce: string | null
  gameToken?: string
  expiresIn?: number
  telegramId?: string
  code?: string
}

/** What the page may see. The token is not in it. */
export interface Identity {
  state: 'pending' | IdentityState
  code?: string
  name?: string
  avatar?: string
  role?: HiveRole
}

export interface MessageLike {
  origin: string
  source: unknown
  data: unknown
}

export interface Poster {
  postMessage(message: unknown, targetOrigin: string): void
}

export interface BridgeFrame {
  /** The frame's window, read when needed (the frame's contentWindow). */
  target(): Poster | null
  setVisible(visible: boolean): void
}

export interface IdentityEnv {
  origin: string
  isTop: boolean
  ancestorOrigins?: readonly string[]
  referrer: string
  parent: Poster
  mountBridge(src: string, onLoad: () => void): BridgeFrame
  onMessage(handler: (event: MessageLike) => void): void
  fetch(url: string, init: { method: string; credentials: 'omit'; headers: Record<string, string>; body: string }): Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
  setTimeout(fn: () => void, ms: number): number
  clearTimeout(id: number): void
  nonce(): string
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value)

const originOf = (url: string): string | null => {
  try {
    return url ? new URL(url).origin : null
  } catch {
    return null
  }
}

/** Rule 1. */
export function identityActiveOn(origin: string): boolean {
  return origin === GAME_ORIGIN
}

/** The direct parent is the player (its Hive tab frames the game). */
export function framedByPlayer({ isTop, ancestorOrigins, referrer }: Pick<IdentityEnv, 'isTop' | 'ancestorOrigins' | 'referrer'>): boolean {
  if (isTop) return false
  if (ancestorOrigins && ancestorOrigins.length > 0) return ancestorOrigins[0] === APP_ORIGIN
  return originOf(referrer) === APP_ORIGIN
}

const TOKEN_SHAPE = /^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+){0,4}$/
const CODE_SHAPE = /^[a-z0-9_]{1,64}$/
const TELEGRAM_ID_SHAPE = /^\d{1,20}$/

/** Rule 2, and the shape of the message. Anything else is null. */
export function acceptIdentityMessage(event: MessageLike | null | undefined, expectedSource: unknown, openNonce: string | null): IdentityReply | null {
  if (!event || event.origin !== APP_ORIGIN) return null
  if (!expectedSource || event.source !== expectedSource) return null
  const data = event.data
  if (!isRecord(data) || data.v !== 1 || data.type !== 'tri-identity') return null
  const state = data.state
  if (typeof state !== 'string' || !(IDENTITY_STATES as readonly string[]).includes(state)) return null
  const nonce = data.nonce
  if (nonce !== null && (typeof nonce !== 'string' || openNonce === null || nonce !== openNonce)) return null
  const reply: IdentityReply = { state: state as IdentityState, nonce }
  if (typeof data.code === 'string' && CODE_SHAPE.test(data.code)) reply.code = data.code
  if (state === 'signed-in' && data.game_token !== undefined) {
    const token = data.game_token
    const expiresIn = data.expires_in
    const telegramId = typeof data.telegram_id === 'number' ? String(data.telegram_id) : data.telegram_id
    if (typeof token !== 'string' || token.length > 4096 || !TOKEN_SHAPE.test(token)) return null
    if (typeof expiresIn !== 'number' || !Number.isFinite(expiresIn) || expiresIn <= 0 || expiresIn > 3600) return null
    if (typeof telegramId !== 'string' || !TELEGRAM_ID_SHAPE.test(telegramId)) return null
    reply.gameToken = token
    reply.expiresIn = expiresIn
    reply.telegramId = telegramId
  }
  return reply
}

/** When to ask again: RENEW_BEFORE_S before expiry, never sooner than 5 s from now. */
export function renewDelayMs(expiresIn: number): number {
  return Math.max(5, expiresIn - RENEW_BEFORE_S) * 1000
}

/** name, avatar (https only) and role from a whoami answer; nothing it does not recognise. */
export function whoamiProfile(body: unknown): Pick<Identity, 'name' | 'avatar' | 'role'> {
  const result = isRecord(body) && isRecord(body.result) ? body.result : null
  if (!result) return {}
  let data: unknown = result.structuredContent
  if (data === undefined && Array.isArray(result.content)) {
    const text = result.content.find((c): c is { type: string; text: string } => isRecord(c) && c.type === 'text' && typeof c.text === 'string')?.text
    try {
      data = text === undefined ? undefined : JSON.parse(text)
    } catch {
      data = undefined
    }
  }
  if (!isRecord(data)) return {}
  const profile = isRecord(data['профиль']) ? data['профиль'] : {}
  const name = [profile.display_name, profile.first_name, profile.username]
    .find((v): v is string => typeof v === 'string' && v.trim() !== '')
    ?.trim()
    .slice(0, 64)
  let avatar: string | undefined
  const rawAvatar = data['аватар']
  if (typeof rawAvatar === 'string' && rawAvatar.length <= 2048) {
    try {
      const url = new URL(rawAvatar)
      if (url.protocol === 'https:') avatar = url.href
    } catch {
      /* not a URL: no avatar */
    }
  }
  const role = typeof data.role === 'string' && (HIVE_ROLES as readonly string[]).includes(data.role) ? (data.role as HiveRole) : undefined
  return { name, avatar, role }
}

/**
 * The top-level sign-in link: the player's login, with a return hint to one of
 * a fixed set of Queen routes, one per view. No ids, no screen or path, no embed.
 */
export function signInHref(view: string, views: readonly string[]): string {
  const tab = view !== 'comb' && views.includes(view) && /^[a-z]+$/.test(view) ? view : null
  const route = tab ? `${GAME_ORIGIN}/#/queen?tab=${tab}` : `${GAME_ORIGIN}/#/queen`
  return `${APP_ORIGIN}/?return=${encodeURIComponent(route)}`
}

export interface TriIdentity {
  subscribe(listener: () => void): () => void
  getSnapshot(): Identity
}

export function createTriIdentity(env: IdentityEnv): TriIdentity {
  let snapshot: Identity = { state: 'pending' }
  const listeners = new Set<() => void>()
  let started = false
  let viaParent = false
  let frame: BridgeFrame | null = null
  let frameLoaded = false
  let openNonce: string | null = null
  // Rule 3: here and nowhere else.
  let token: { value: string; telegramId: string } | null = null
  let profileFor: string | null = null
  let renewTimer: number | null = null
  let answerTimer: number | null = null
  let whoamiRun = 0

  const publish = (next: Identity) => {
    snapshot = next
    listeners.forEach((listener) => listener())
  }
  const stopTimer = (id: number | null) => {
    if (id !== null) env.clearTimeout(id)
  }
  const asked = (): Poster | null => (viaParent ? env.parent : frame ? frame.target() : null)

  function request() {
    const target = asked()
    if (!target || (!viaParent && !frameLoaded)) return
    const nonce = env.nonce()
    openNonce = nonce
    target.postMessage({ v: 1, type: 'tri-identity-request', nonce }, APP_ORIGIN)
    stopTimer(answerTimer)
    answerTimer = env.setTimeout(() => {
      answerTimer = null
      if (openNonce !== nonce) return
      forget()
      publish({ state: 'unavailable', code: 'no_answer' })
    }, IDENTITY_ANSWER_MS)
  }

  function forget() {
    token = null
    profileFor = null
    whoamiRun++
    stopTimer(renewTimer)
    renewTimer = null
  }

  async function loadProfile(bearer: string, telegramId: string) {
    const run = ++whoamiRun
    let profile: Pick<Identity, 'name' | 'avatar' | 'role'> = {}
    try {
      const res = await env.fetch(`${RENDER_BASE}/mcp`, {
        method: 'POST',
        credentials: 'omit',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bearer}` },
        body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'whoami', arguments: {} } }),
      })
      if (run !== whoamiRun) return
      if (res.status === 401) {
        forget()
        publish({ state: 'unavailable', code: 'whoami_rejected' })
        return
      }
      if (res.ok) profile = whoamiProfile(await res.json())
    } catch {
      /* offline: signed in, name unknown */
    }
    if (run !== whoamiRun) return
    profileFor = telegramId
    publish({ state: 'signed-in', ...profile })
  }

  function apply(reply: IdentityReply) {
    if (reply.state !== 'signed-in') {
      forget()
      frame?.setVisible(reply.state === 'consent-required')
      publish(reply.code ? { state: reply.state, code: reply.code } : { state: reply.state })
      return
    }
    frame?.setVisible(false)
    if (!reply.gameToken || !reply.telegramId || !reply.expiresIn) {
      // A push saying "signed in now" is a cue to ask; an answer without a token is not an identity.
      if (reply.nonce === null) request()
      else {
        forget()
        publish({ state: 'unavailable', code: 'no_token' })
      }
      return
    }
    const sameUser = profileFor === reply.telegramId && snapshot.state === 'signed-in'
    token = { value: reply.gameToken, telegramId: reply.telegramId }
    stopTimer(renewTimer)
    renewTimer = env.setTimeout(() => {
      renewTimer = null
      request()
    }, renewDelayMs(reply.expiresIn))
    if (!sameUser) void loadProfile(token.value, token.telegramId)
  }

  function onMessage(event: MessageLike) {
    const reply = acceptIdentityMessage(event, asked(), openNonce)
    if (!reply) return
    if (reply.nonce !== null) {
      openNonce = null
      stopTimer(answerTimer)
      answerTimer = null
    }
    apply(reply)
  }

  function start() {
    if (started) return
    started = true
    if (!identityActiveOn(env.origin)) {
      publish({ state: 'unavailable', code: 'not_t27' })
      return
    }
    viaParent = framedByPlayer(env)
    env.onMessage(onMessage)
    if (viaParent) {
      request()
      return
    }
    frame = env.mountBridge(BRIDGE_URL, () => {
      frameLoaded = true
      request()
    })
  }

  return {
    subscribe(listener) {
      listeners.add(listener)
      start()
      return () => listeners.delete(listener)
    },
    getSnapshot: () => snapshot,
  }
}

function browserEnv(): IdentityEnv {
  return {
    origin: window.location.origin,
    isTop: window.self === window.top,
    ancestorOrigins: window.location.ancestorOrigins ? [...window.location.ancestorOrigins] : undefined,
    referrer: document.referrer,
    parent: window.parent,
    mountBridge(src, onLoad) {
      const el = document.createElement('iframe')
      el.className = 'queen27-identity-bridge'
      el.title = 'app.t27.ai'
      el.hidden = true
      el.addEventListener('load', onLoad)
      el.src = src
      document.body.appendChild(el)
      return {
        target: () => el.contentWindow,
        setVisible: (visible) => {
          el.hidden = !visible
        },
      }
    },
    onMessage: (handler) => window.addEventListener('message', handler),
    fetch: (url, init) => window.fetch(url, init),
    setTimeout: (fn, ms) => window.setTimeout(fn, ms),
    clearTimeout: (id) => window.clearTimeout(id),
    nonce: () => {
      const bytes = new Uint8Array(16)
      window.crypto.getRandomValues(bytes)
      return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
    },
  }
}

let shared: TriIdentity | null = null

/** The page's one identity, started by its first subscriber. */
export function triIdentity(): TriIdentity {
  if (!shared) shared = createTriIdentity(browserEnv())
  return shared
}
