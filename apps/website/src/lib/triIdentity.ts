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
//   player -> game:  {v:1, type:'tri-identity-dismiss', nonce}
//                    (the person pressed Not now on the consent prompt)
//   game -> player:  {v:1, type:'t27-app', kind:'sign-in'}
//                    (only to the player framing the game, its Hive tab; the player
//                    signs in in its own modal and says nothing, so the game asks
//                    again when the person comes back to it)
//
// Who answers: when the game is framed by the player (its Hive tab), the parent
// window. Otherwise a hidden frame of https://app.t27.ai/bridge?lang=<ru|en>,
// shown small only while the bridge needs a click to continue
// ('consent-required'), the person has not said Not now, and something on
// screen subscribes (the Queen's chip): leaving the Queen hides it.
//
// THE RULES THIS FILE KEEPS (qa/tri-identity-contract.mjs holds it to them):
//   1. Active on https://t27.ai only. Any other origin stays anonymous.
//   2. A message counts only from https://app.t27.ai AND from the one window asked
//      (the parent, or the bridge frame), with the nonce of the open request or
//      nonce null (a dismiss: the open nonce only).
//   3. The game token lives in this module's memory: never storage, never a
//      URL, never a log, never the published snapshot.
//   4. whoami goes out with credentials 'omit' and exactly two headers,
//      Content-Type and Authorization. Never X-Agent-Key: the console's agent
//      key (crmClient.ts) is a different path and never meets this one.
//   5. Nobody looking, nothing running: with no subscriber the renewal and
//      retry timers stop and the bridge frame is blanked (unless it holds a
//      prompt waiting for its click). A hidden page asks nothing by itself.
//
// Everything that touches the browser comes in through IdentityEnv, so the
// contract drives the same code with fakes.

export const GAME_ORIGIN = 'https://t27.ai'
export const APP_ORIGIN = 'https://app.t27.ai'
export const BRIDGE_URL = `${APP_ORIGIN}/bridge`
export const RENDER_BASE = 'https://vibee-render-production.up.railway.app'

/** Without an answer this long after asking (or after mounting the bridge), the identity is 'unavailable'. */
export const IDENTITY_ANSWER_MS = 10000
/** Ask again this long before the token expires. */
export const RENEW_BEFORE_S = 30
/** whoami is abandoned after this long: signed in, name unknown. */
export const WHOAMI_TIMEOUT_MS = 5000
/** Pauses before asking again after a failure that may pass by itself; the last one repeats. */
export const RETRY_BACKOFF_S = [5, 15, 60, 300] as const

/**
 * Spelled as the player sends them: public/bridge/bridge.js (all five) and
 * src/lib/hive.ts (signed-in, signed-out, unavailable).
 */
export const IDENTITY_STATES = ['signed-in', 'signed-out', 'consent-required', 'expired', 'unavailable'] as const
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
  /** consent-required, and the person said Not now: the prompt stays hidden until asked again. */
  dismissed?: true
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
  /** Load another address in the frame; null blanks it (about:blank, which fires no onLoad). */
  setSrc(src: string | null): void
}

export interface IdentityEnv {
  origin: string
  isTop: boolean
  ancestorOrigins?: readonly string[]
  referrer: string
  parent: Poster
  mountBridge(src: string, onLoad: () => void): BridgeFrame
  onMessage(handler: (event: MessageLike) => void): void
  fetch(url: string, init: { method: string; credentials: 'omit'; headers: Record<string, string>; body: string; signal: AbortSignal }): Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
  setTimeout(fn: () => void, ms: number): number
  clearTimeout(id: number): void
  nonce(): string
  now(): number
  hidden(): boolean
  onVisible(handler: () => void): void
  onOnline(handler: () => void): void
  /** The person coming back to this document: its window focused, or the pointer entering it. */
  onReturn(handler: () => void): void
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

/** The bridge in the game's language: the bridge speaks ru, and en for anything else. */
export function bridgeUrl(lang: string): string {
  return `${BRIDGE_URL}?lang=${lang === 'ru' ? 'ru' : 'en'}`
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

/**
 * Rule 2 for Not now: {v:1, type:'tri-identity-dismiss', nonce} from the window
 * asked, with the nonce of the request waiting for its click. Its nonce, or null.
 */
export function acceptDismissMessage(event: MessageLike | null | undefined, expectedSource: unknown, openNonce: string | null): string | null {
  if (!event || event.origin !== APP_ORIGIN) return null
  if (!expectedSource || event.source !== expectedSource) return null
  const data = event.data
  if (!isRecord(data) || data.v !== 1 || data.type !== 'tri-identity-dismiss') return null
  if (typeof data.nonce !== 'string' || openNonce === null || data.nonce !== openNonce) return null
  return data.nonce
}

/** When to ask again: RENEW_BEFORE_S before expiry, never sooner than 5 s from now. */
export function renewDelayMs(expiresIn: number): number {
  return Math.max(5, expiresIn - RENEW_BEFORE_S) * 1000
}

/**
 * Failures that may pass by themselves, so the client asks again after a pause:
 * the network, silence, a 5xx, a rate limit. A refusal stays until someone acts.
 */
export function retriesByItself(code: string | undefined): boolean {
  return code === 'network' || code === 'no_answer' || code === 'game_token_rate_limited' || code === 'http_429' || /^http_5\d\d$/.test(code ?? '')
}

/** The pause before the next try after `failures` failures in a row. */
export function retryDelayMs(failures: number): number {
  return RETRY_BACKOFF_S[Math.min(Math.max(0, failures), RETRY_BACKOFF_S.length - 1)] * 1000
}

/**
 * What the chip shows, one kind per next step. The codes are those the client
 * can receive: the render server's /api/auth/game-token errors relayed by the
 * bridge or the Hive (game_token_*), http_<status>, bad_response and network
 * from the bridge, and no_answer, no_token, whoami_rejected and not_t27 from
 * this file. Any other code is 'unavailable' with a Retry.
 */
export type ChipKind = 'pending' | 'signed-in' | 'consent-required' | 'signed-out' | 'expired' | 'sign-in-again' | 'unavailable' | 'web-only' | 'off-site'
export type ChipReason = 'offline' | 'no_answer' | 'busy' | 'refused' | 'server'
export interface Chip {
  kind: ChipKind
  reason?: ChipReason
}

const REFUSED_CODES = new Set(['game_token_credential_rejected', 'game_token_credential_required', 'whoami_rejected', 'http_401', 'http_403'])
const WEB_ONLY_CODES = new Set(['game_token_launch_bots_unset', 'game_token_bot_not_allowed'])

export function chipOf(identity: Pick<Identity, 'state' | 'code'>): Chip {
  if (identity.state !== 'unavailable') return { kind: identity.state }
  const code = identity.code ?? ''
  if (code === 'game_token_parent_not_web') return { kind: 'sign-in-again' }
  if (WEB_ONLY_CODES.has(code)) return { kind: 'web-only' }
  if (code === 'not_t27') return { kind: 'off-site' }
  if (code === 'network') return { kind: 'unavailable', reason: 'offline' }
  if (code === 'no_answer') return { kind: 'unavailable', reason: 'no_answer' }
  if (code === 'game_token_rate_limited' || code === 'http_429') return { kind: 'unavailable', reason: 'busy' }
  if (REFUSED_CODES.has(code)) return { kind: 'unavailable', reason: 'refused' }
  return { kind: 'unavailable', reason: 'server' }
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
 * The top-level sign-in link: the player's login, with a return to a fixed
 * Queen route. The player (gHashTag/999-multibots-telegraf
 * apps/vibee-editor/player/src/lib/returnTarget.ts) accepts exactly
 * https://t27.ai/#/queen, ?tab=<view> and ?tab=tri&screen=<screen>. So: one
 * route per view, and on the TRI tab its screen (none for its first screen,
 * the way the Queen's own address carries none). No ids, no path, no embed.
 */
export function signInHref(view: string, views: readonly string[], screen?: string | null, screens: readonly string[] = []): string {
  const tab = view !== 'comb' && views.includes(view) && /^[a-z]+$/.test(view) ? view : null
  let route = tab ? `${GAME_ORIGIN}/#/queen?tab=${tab}` : `${GAME_ORIGIN}/#/queen`
  if (tab === 'tri' && typeof screen === 'string' && screen !== screens[0] && screens.includes(screen) && /^[a-z]{1,16}$/.test(screen)) route += `&screen=${screen}`
  return `${APP_ORIGIN}/?return=${encodeURIComponent(route)}`
}

export interface TriIdentity {
  subscribe(listener: () => void): () => void
  getSnapshot(): Identity
  /** Ask again now (the chip's Retry and Confirm in TRI). Undoes Not now. */
  retry(): void
  /** Inside the player's Hive: ask the player to open its sign-in in place. */
  signIn(): void
  /** Whether the player frames the game (its Hive tab); known once started. */
  inPlayer(): boolean
  /** The page's language, for the bridge prompt. */
  setLanguage(lang: string): void
  /** Start before the first subscriber: mount the bridge and ask once, so the answer is there when the chip is. */
  prime(): void
}

export function createTriIdentity(env: IdentityEnv): TriIdentity {
  let snapshot: Identity = { state: 'pending' }
  const listeners = new Set<() => void>()
  let started = false
  let viaParent = false
  let lang: 'ru' | 'en' = 'en'
  let frame: BridgeFrame | null = null
  // The bridge frame: loading the bridge, loaded, or blank while nobody looks.
  let frameState: 'loading' | 'loaded' | 'blank' = 'loading'
  let askOnLoad = false
  // The frame may hold an error page (it never answered): the next ask reloads it.
  let frameSuspect = false
  let consentAsked = false
  let dismissed = false
  // Sign in was pressed inside the Hive: the player signs in in its own modal
  // and tells nobody, so the person coming back to the game is the cue to ask.
  let signInPending = false
  let openNonce: string | null = null
  // Rule 3: here and nowhere else.
  let token: { value: string; telegramId: string; expiresAt: number } | null = null
  let profileFor: string | null = null
  let renewTimer: number | null = null
  let answerTimer: number | null = null
  let retryTimer: number | null = null
  let failures = 0
  let owed = false
  let asleep = false
  let whoamiRun = 0
  let whoamiRetried = false

  const publish = (next: Identity) => {
    snapshot = next
    listeners.forEach((listener) => listener())
  }
  const stopTimer = (id: number | null) => {
    if (id !== null) env.clearTimeout(id)
  }
  const looking = () => listeners.size > 0
  const source = (): Poster | null => (viaParent ? env.parent : frame ? frame.target() : null)
  // The frame sits above every route, so it shows only while someone subscribes.
  const showFrame = () => frame?.setVisible(consentAsked && !dismissed && looking())

  function deadline(nonce: string | null) {
    stopTimer(answerTimer)
    answerTimer = env.setTimeout(() => {
      answerTimer = null
      if (nonce === null ? !askOnLoad : openNonce !== nonce) return
      // A late answer is refused from here on.
      openNonce = null
      // Still loading is slow, not broken: the load asks. Loaded and silent may
      // be an error page: the next ask loads the bridge again.
      if (nonce !== null) frameSuspect = !viaParent
      unavailable('no_answer')
    }, IDENTITY_ANSWER_MS)
  }

  function post() {
    const target = source()
    if (!target) return
    const nonce = env.nonce()
    openNonce = nonce
    target.postMessage({ v: 1, type: 'tri-identity-request', nonce }, APP_ORIGIN)
    deadline(nonce)
  }

  function request() {
    stopTimer(retryTimer)
    retryTimer = null
    owed = false
    if (viaParent) return post()
    if (!frame) return
    if (frameState === 'blank' || (frameSuspect && frameState === 'loaded')) {
      frameSuspect = false
      frameState = 'loading'
      openNonce = null
      askOnLoad = true
      frame.setSrc(bridgeUrl(lang))
      deadline(null)
      return
    }
    if (frameState === 'loading') {
      askOnLoad = true
      return
    }
    post()
  }

  function onBridgeLoad() {
    frameState = 'loaded'
    frameSuspect = false
    if (!askOnLoad) return
    askOnLoad = false
    post()
  }

  // Asked by a timer or an event, not by a person: only for someone looking at a visible page.
  function later() {
    if (!looking() || env.hidden() || dismissed) {
      owed = true
      return
    }
    request()
  }

  function forget() {
    token = null
    profileFor = null
    whoamiRun++
    stopTimer(renewTimer)
    renewTimer = null
  }

  function renewIn(ms: number) {
    stopTimer(renewTimer)
    renewTimer = env.setTimeout(() => {
      renewTimer = null
      later()
    }, ms)
  }

  function unavailable(code: string | undefined) {
    forget()
    consentAsked = false
    showFrame()
    publish(code ? { state: 'unavailable', code } : { state: 'unavailable' })
    stopTimer(retryTimer)
    retryTimer = null
    if (!retriesByItself(code)) return
    retryTimer = env.setTimeout(() => {
      retryTimer = null
      later()
    }, retryDelayMs(failures))
    failures++
  }

  async function loadProfile(bearer: string) {
    const run = ++whoamiRun
    const abort = new AbortController()
    const giveUp = env.setTimeout(() => abort.abort(), WHOAMI_TIMEOUT_MS)
    let profile: Pick<Identity, 'name' | 'avatar' | 'role'> = {}
    try {
      const res = await env.fetch(`${RENDER_BASE}/mcp`, {
        method: 'POST',
        credentials: 'omit',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bearer}` },
        body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'whoami', arguments: {} } }),
        signal: abort.signal,
      })
      if (run !== whoamiRun) return
      if (res.status === 401) {
        // Refused once: ask the player for a fresh token, silently, when someone
        // looks (the chip may have left while whoami was out). Twice: say so.
        forget()
        if (whoamiRetried) return unavailable('whoami_rejected')
        whoamiRetried = true
        later()
        return
      }
      if (res.ok) profile = whoamiProfile(await res.json())
    } catch {
      /* offline or too slow: signed in, name unknown */
    } finally {
      env.clearTimeout(giveUp)
    }
    if (run !== whoamiRun) return
    whoamiRetried = false
    publish({ state: 'signed-in', ...profile })
  }

  function apply(reply: IdentityReply) {
    if (reply.state !== 'signed-out') signInPending = false
    if (reply.state === 'unavailable') {
      whoamiRetried = false
      unavailable(reply.code)
      return
    }
    failures = 0
    stopTimer(retryTimer)
    retryTimer = null
    if (reply.state !== 'signed-in') {
      forget()
      whoamiRetried = false
      consentAsked = reply.state === 'consent-required'
      if (!consentAsked) dismissed = false
      showFrame()
      const next: Identity = reply.code ? { state: reply.state, code: reply.code } : { state: reply.state }
      if (consentAsked && dismissed) next.dismissed = true
      publish(next)
      return
    }
    consentAsked = false
    dismissed = false
    showFrame()
    if (!reply.gameToken || !reply.telegramId || !reply.expiresIn) {
      // A push saying "signed in now" is a cue to ask; an answer without a token is not an identity.
      if (reply.nonce === null) request()
      else unavailable('no_token')
      return
    }
    const samePerson = profileFor === reply.telegramId && snapshot.state === 'signed-in'
    token = { value: reply.gameToken, telegramId: reply.telegramId, expiresAt: env.now() + reply.expiresIn * 1000 }
    renewIn(renewDelayMs(reply.expiresIn))
    if (samePerson) return
    // Signed in as soon as the token is here; the name follows from whoami.
    profileFor = reply.telegramId
    publish({ state: 'signed-in' })
    void loadProfile(token.value)
  }

  function onMessage(event: MessageLike) {
    if (acceptDismissMessage(event, source(), openNonce) !== null) {
      if (!consentAsked) return
      openNonce = null
      dismissed = true
      showFrame()
      publish({ state: 'consent-required', dismissed: true })
      return
    }
    const reply = acceptIdentityMessage(event, source(), openNonce)
    if (!reply) return
    if (reply.nonce !== null) {
      stopTimer(answerTimer)
      answerTimer = null
      // consent-required is not the last answer: after the click the bridge
      // answers this same nonce with the token. A newer request() replaces it.
      if (reply.state !== 'consent-required') openNonce = null
    }
    apply(reply)
  }

  // Rule 5: the last subscriber left.
  function sleep() {
    asleep = true
    stopTimer(renewTimer)
    renewTimer = null
    stopTimer(retryTimer)
    retryTimer = null
    if (!frame || consentAsked || frameState === 'blank') return
    if (openNonce !== null || askOnLoad) owed = true
    stopTimer(answerTimer)
    answerTimer = null
    openNonce = null
    askOnLoad = false
    frameState = 'blank'
    frame.setSrc(null)
  }

  // A subscriber came back: ask only when the token is missing or about to expire.
  function wake() {
    if (!asleep) return
    asleep = false
    if (dismissed) return
    const left = token ? token.expiresAt - env.now() : 0
    if (token && left > RENEW_BEFORE_S * 1000) {
      renewIn(left - RENEW_BEFORE_S * 1000)
      return
    }
    if (openNonce !== null || askOnLoad) return
    if (env.hidden()) {
      owed = true
      return
    }
    request()
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
    env.onVisible(() => {
      if (owed && looking() && !dismissed) request()
    })
    env.onOnline(() => {
      if (looking() && !dismissed && snapshot.state === 'unavailable' && retriesByItself(snapshot.code)) request()
    })
    if (viaParent) {
      env.onReturn(() => {
        if (signInPending && openNonce === null && looking() && !env.hidden()) request()
      })
      request()
      return
    }
    frameState = 'loading'
    askOnLoad = true
    frame = env.mountBridge(bridgeUrl(lang), onBridgeLoad)
    deadline(null)
  }

  return {
    subscribe(listener) {
      const first = listeners.size === 0
      listeners.add(listener)
      if (!started) start()
      else if (first) wake()
      showFrame()
      return () => {
        if (!listeners.delete(listener)) return
        if (listeners.size === 0) sleep()
        showFrame()
      }
    },
    getSnapshot: () => snapshot,
    retry() {
      if (!started || !identityActiveOn(env.origin)) return
      if (dismissed) {
        // After Not now the bridge has hidden its prompt: the frame stays hidden
        // until the bridge answers consent-required again, so no empty frame
        // sits over the page in between.
        dismissed = false
        consentAsked = false
      }
      request()
      showFrame()
    },
    signIn() {
      if (!started || !viaParent) return
      env.parent.postMessage({ v: 1, type: 't27-app', kind: 'sign-in' }, APP_ORIGIN)
      signInPending = true
    },
    inPlayer: () => viaParent,
    setLanguage(next) {
      const value = next === 'ru' ? 'ru' : 'en'
      if (value === lang) return
      lang = value
      if (!frame || frameState === 'blank') return
      // The prompt speaks the page's language: the bridge loads again in it.
      askOnLoad = askOnLoad || openNonce !== null || consentAsked || snapshot.state === 'pending'
      openNonce = null
      frameState = 'loading'
      frame.setSrc(bridgeUrl(lang))
      if (askOnLoad) deadline(null)
    },
    prime: start,
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
      // A blanked frame's about:blank load is not the bridge loading.
      el.addEventListener('load', () => {
        if (el.getAttribute('src') !== 'about:blank') onLoad()
      })
      el.src = src
      document.body.appendChild(el)
      return {
        target: () => el.contentWindow,
        setVisible: (visible) => {
          el.hidden = !visible
        },
        setSrc: (next) => {
          el.src = next ?? 'about:blank'
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
    now: () => Date.now(),
    hidden: () => document.visibilityState === 'hidden',
    onVisible: (handler) =>
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') handler()
      }),
    onOnline: (handler) => window.addEventListener('online', handler),
    onReturn: (handler) => {
      window.addEventListener('focus', handler)
      document.documentElement.addEventListener('pointerenter', handler)
    },
  }
}

let shared: TriIdentity | null = null

/** The page's one identity, started by its first subscriber (or primed earlier). */
export function triIdentity(): TriIdentity {
  if (!shared) shared = createTriIdentity(browserEnv())
  return shared
}
