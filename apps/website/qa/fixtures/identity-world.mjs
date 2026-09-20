// The fake world src/lib/triIdentity.ts runs in, for every gate that needs a
// signed-in person without a browser.
//
// This started inside qa/tri-identity-contract.mjs, which is still its main
// customer. It moved here the day a second gate — qa/hive-board-contract.mjs —
// needed the same thing: a client that has actually been through the handshake
// (bridge mounted, request posted, answer delivered, whoami answered) rather
// than an object that merely claims to be signed in.
//
// It is here rather than copied because a copy is the failure. Two harnesses
// drift; the day the handshake grows a step, one gate learns it and the other
// keeps proving a conversation the module no longer has — and keeps passing,
// which is the worst way to be wrong. One world, two gates, one place to fix.
//
// Nothing in here asserts anything. A fixture that judges is a second gate
// nobody reads; the judging belongs in the gate that imports this.
import { GAME_ORIGIN, APP_ORIGIN, createTriIdentity } from '../../src/lib/triIdentity.ts'

/**
 * A token shaped like the real one — three base64url segments, the middle one
 * decoding to {"v":2} — and never a real one. Gates assert this exact string
 * does not appear where it must not, so it has to be distinctive enough that
 * an accidental match means something.
 */
export const TOKEN = 'eyJhbGciOiJIUzI1NiJ9.eyJ2IjoyfQ.c2lnbmF0dXJl'

/** The player's answer to an open request: signed in, with a 300 s token. */
export const signedIn = (nonce) => ({ v: 1, type: 'tri-identity', nonce, state: 'signed-in', game_token: TOKEN, expires_in: 300, telegram_id: '144022504' })

/**
 * whoami as the service answers it: structuredContent, Russian keys for the
 * profile and the avatar (the service's own language), role in English.
 */
export const WHOAMI = { jsonrpc: '2.0', id: 1, result: { structuredContent: { telegram_id: '144022504', role: 'owner', профиль: { display_name: 'Ada', first_name: 'A', username: 'ada' }, аватар: 'https://cdn.example/ada.jpg' } } }

/**
 * Everything a module under test touched that it had no business touching.
 * A gate asserts this stays empty; the trap records rather than throws for the
 * console so that a stray log is reported as itself instead of as a crash
 * somewhere else.
 */
export const TRAPPED = []

/**
 * Make window, document, storage, location, history, navigator and the console
 * unreachable, and hand back the undo. Reading any of them throws with the name
 * in the message, so a module that reaches for storage fails where it reached
 * instead of failing a size comparison three screens later.
 */
export function trapGlobals() {
  const names = ['window', 'document', 'localStorage', 'sessionStorage', 'indexedDB', 'location', 'history', 'navigator']
  const saved = names.map((name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)])
  for (const name of names) {
    Object.defineProperty(globalThis, name, { configurable: true, get() { TRAPPED.push(name); throw new Error(`triIdentity touched ${name}`) } })
  }
  const consoleSaved = {}
  for (const level of ['log', 'info', 'warn', 'error', 'debug']) {
    consoleSaved[level] = console[level]
    console[level] = (...args) => { TRAPPED.push(`console.${level}:${args.map(String).join(' ')}`) }
  }
  return () => {
    for (const [name, descriptor] of saved) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
    Object.assign(console, consoleSaved)
  }
}

/**
 * A whole environment for one client: a fake parent, a fake bridge frame, fake
 * timers and clock, a fake fetch, fake visibility. Every message, mount, src,
 * fetch and snapshot is recorded in `log`, which is how a gate proves what did
 * NOT happen — the interesting half of a security contract.
 *
 * `whoami` is the fetch: it answers every request the client makes, and a gate
 * that wants to watch the wire replaces it rather than patching globalThis.
 */
export function fakeWorld({ origin = GAME_ORIGIN, isTop = true, ancestorOrigins = [], referrer = '', whoami = () => ({ ok: true, status: 200, json: async () => WHOAMI }) } = {}) {
  const log = { bridgePosts: [], parentPosts: [], mounts: [], srcs: [], fetches: [], visible: [], snapshots: [] }
  const bridgeWindow = { postMessage: (m, t) => log.bridgePosts.push({ m, t }) }
  const parent = { postMessage: (m, t) => log.parentPosts.push({ m, t }) }
  const timers = new Map()
  let nextTimer = 1
  let handler = null
  let onLoad = null
  let visible = false
  let n = 0
  let clock = 1_000_000
  let hidden = false
  let onVisible = null
  let onOnline = null
  let onReturn = null
  const env = {
    origin, isTop, ancestorOrigins, referrer, parent,
    mountBridge(src, load) { log.mounts.push(src); onLoad = load; return { target: () => bridgeWindow, setVisible: (v) => { visible = v; log.visible.push(v) }, setSrc: (s) => log.srcs.push(s) } },
    onMessage(h) { handler = h },
    fetch: async (url, init) => { log.fetches.push({ url, init }); return whoami(url, init) },
    setTimeout(fn, ms) { const id = nextTimer++; timers.set(id, { fn, ms }); return id },
    clearTimeout(id) { timers.delete(id) },
    nonce: () => (++n).toString(16).padStart(32, '0'),
    now: () => clock,
    hidden: () => hidden,
    onVisible(h) { onVisible = h },
    onOnline(h) { onOnline = h },
    onReturn(h) { onReturn = h },
  }
  const client = createTriIdentity(env)
  const settle = async () => { for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r)) }
  return {
    log, bridgeWindow, parent, client,
    start: () => client.subscribe(() => log.snapshots.push(client.getSnapshot())),
    load: () => onLoad?.(),
    deliver: async (data, over = {}) => { handler?.({ origin: APP_ORIGIN, source: bridgeWindow, data, ...over }); await settle() },
    timer: (ms) => [...timers.values()].filter((t) => t.ms === ms),
    timerCount: () => timers.size,
    fire: async (ms) => { for (const [id, t] of [...timers]) if (t.ms === ms) { timers.delete(id); t.fn() } await settle() },
    advance: (ms) => { clock += ms },
    setHidden: async (value) => { hidden = value; if (!value) onVisible?.(); await settle() },
    online: async () => { onOnline?.(); await settle() },
    comeBack: async () => { onReturn?.(); await settle() },
    get returnHandler() { return onReturn },
    get visible() { return visible },
    get handler() { return handler },
    lastNonce: (posts) => posts.at(-1)?.m?.nonce ?? null,
  }
}

/** Let every pending microtask land before looking at what happened. */
export const settleAll = async () => { for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r)) }

/**
 * Take a world all the way to signed-in: mount, load, answer the request it
 * posts, let whoami settle. The gates that are not about the handshake say
 * this in one line instead of re-performing it.
 */
export async function signIn(world) {
  world.start()
  world.load()
  const nonce = world.lastNonce(world.log.bridgePosts)
  await world.deliver(signedIn(nonce))
  await settleAll()
  return world
}
