// TRI: the app at app.t27.ai inside the Queen. The one table of its screens and
// every rule about addresses and messages, pure so qa/tri-screens-contract.mjs
// can import it with node --experimental-strip-types.
//
// Each screen is the real app page in a frame. The frame URL is always
// APP_ORIGIN + a route from this table (or a deep path checked against the same
// table), so nothing in the Queen's address can change the frame's origin.

export const APP_ORIGIN = 'https://app.t27.ai'

export type TriScreen = 'feed' | 'chat' | 'script' | 'audio' | 'image' | 'avatar' | 'video' | 'editor' | 'profile' | 'crm'
export type TriGroup = 'feed' | 'chat' | 'ai' | 'profile' | 'crm'

export interface TriScreenEntry {
  screen: TriScreen
  route: string
  group: TriGroup
}

// The app's primary navigation (feed, agent, AI, profile) plus the owner's CRM.
// The AI group is the app's pipeline, script to editor; its stages switch inside
// the frame, and the route message records the stage here.
export const TRI_SCREENS: readonly TriScreenEntry[] = [
  { screen: 'feed', route: '/feed', group: 'feed' },
  { screen: 'chat', route: '/chat', group: 'chat' },
  { screen: 'script', route: '/generate/script', group: 'ai' },
  { screen: 'audio', route: '/generate/audio', group: 'ai' },
  { screen: 'image', route: '/generate/image', group: 'ai' },
  { screen: 'avatar', route: '/generate/avatar', group: 'ai' },
  { screen: 'video', route: '/generate/video', group: 'ai' },
  { screen: 'editor', route: '/generate/editor', group: 'ai' },
  { screen: 'profile', route: '/profile', group: 'profile' },
  { screen: 'crm', route: '/crm', group: 'crm' },
] as const

/** One button per group: the group's first screen. */
export const TRI_BUTTONS: readonly TriScreen[] = ['feed', 'chat', 'script', 'profile', 'crm'] as const

/** The default screen carries no `screen=`, the way the comb carries no `tab=`. */
export const DEFAULT_TRI_SCREEN: TriScreen = 'feed'

const entryOf = (screen: TriScreen): TriScreenEntry => TRI_SCREENS.find((entry) => entry.screen === screen) ?? TRI_SCREENS[0]

export const triGroupOf = (screen: TriScreen): TriGroup => entryOf(screen).group

/** `?screen=` read from the address: a screen of the table, otherwise the feed. */
export function triScreenOf(param: string | null | undefined): TriScreen {
  const found = TRI_SCREENS.find((entry) => entry.screen === param)
  return found ? found.screen : DEFAULT_TRI_SCREEN
}

const AI_STAGES = new Set(['script', 'audio', 'image', 'avatar', 'video', 'editor'])
// Top-level app routes that are not a person's profile (the app's route table
// declares them before `/:username`).
const NOT_A_PROFILE = new Set(['home', 'feed', 'blog', 'search', 'editor', 'generate', 'hive', 'crm', 'templates', 'chat', 'learn', 'profile', 'instagram'])
const CRM_PATH = /^\/crm(?:\/([A-Za-z0-9_-]{1,64})(?:\/chat)?)?$/
const PROFILE_PATH = /^\/([A-Za-z0-9_]{1,64})$/

/**
 * The screen an app pathname belongs to, or null when it belongs to none
 * (the hive, templates, the blog...), which leaves the address alone.
 * `/:username` is another person's profile and belongs to the profile screen.
 */
export function screenOfAppPath(path: string): TriScreen | null {
  if (typeof path !== 'string' || !path.startsWith('/') || path.startsWith('//')) return null
  const clean = path.length > 1 && path.endsWith('/') ? path.slice(0, -1) : path
  if (clean === '/feed' || clean.startsWith('/feed/')) return 'feed'
  if (clean === '/chat') return 'chat'
  if (clean === '/generate') return 'script'
  const stage = clean.match(/^\/generate\/([a-z]+)$/)
  if (stage) return AI_STAGES.has(stage[1]) ? (stage[1] as TriScreen) : null
  if (clean === '/editor') return 'editor'
  if (clean === '/profile') return 'profile'
  if (CRM_PATH.test(clean)) return 'crm'
  const single = clean.match(PROFILE_PATH)
  if (single && !NOT_A_PROFILE.has(single[1])) return 'profile'
  return null
}

/**
 * A deep path the address may carry as `path=` for this screen: one person's
 * profile (/<username>), without a trailing slash. Anything else, including the
 * screen's own root, is null.
 *
 * The CRM is addressed at the list only. Its client ids (/crm/<id>) are the
 * Telegram user ids of customers, and `path=` would put them in the t27.ai
 * address bar, its history and every copied link. A reload inside one client
 * therefore reopens the CRM list.
 */
export function triPathOf(screen: TriScreen, raw: string | null | undefined): string | null {
  if (typeof raw !== 'string' || screen !== 'profile') return null
  const clean = raw.length > 1 && raw.endsWith('/') ? raw.slice(0, -1) : raw
  if (screenOfAppPath(clean) === 'profile' && PROFILE_PATH.test(clean) && clean !== '/profile') return clean
  return null
}

/** The frame URL. Built by concatenation with APP_ORIGIN from checked parts only. */
export function triFrameSrc(screen: TriScreen, lang: string, path?: string | null): string {
  const target = triPathOf(screen, path) ?? entryOf(screen).route
  return `${APP_ORIGIN}${target}?embed=1&lang=${encodeURIComponent(lang)}`
}

/** The same screen in the app itself, for the link out. */
export function appScreenUrl(screen: TriScreen, path?: string | null): string {
  return `${APP_ORIGIN}${triPathOf(screen, path) ?? entryOf(screen).route}`
}

export interface AppMessage {
  kind: 'ready' | 'route'
  path: string
}

/**
 * The only messages TRI listens to: a plain object {type:'t27-app', kind, path}
 * from the app's origin and from the frame TRI itself holds. telegram-web-app.js
 * inside the app posts JSON strings to '*'; those, and anything from any other
 * window, are rejected.
 */
export function acceptAppMessage(
  event: { origin: string; source: unknown; data: unknown } | null | undefined,
  frameWindow: unknown,
): AppMessage | null {
  if (!event || event.origin !== APP_ORIGIN) return null
  if (!frameWindow || event.source !== frameWindow) return null
  const data = event.data
  if (!data || typeof data !== 'object' || Array.isArray(data)) return null
  const { type, kind, path } = data as { type?: unknown; kind?: unknown; path?: unknown }
  if (type !== 't27-app') return null
  if (kind !== 'ready' && kind !== 'route') return null
  if (typeof path !== 'string' || !path.startsWith('/') || path.startsWith('//')) return null
  return { kind, path }
}

const originOf = (url: string | null | undefined): string | null => {
  try {
    return url ? new URL(url).origin : null
  } catch {
    return null
  }
}

/**
 * True when this game is itself running inside the app (the app's Hive tab
 * frames it): framing the app again from here would nest app > game > app.
 * The game served from the app's own origin (app.t27.ai/game/) is not that.
 */
export function insidePlayer({
  isTop,
  ancestorOrigins,
  referrer,
  ownOrigin,
}: {
  isTop: boolean
  ancestorOrigins?: readonly string[]
  referrer: string
  ownOrigin: string
}): boolean {
  if (isTop || ownOrigin === APP_ORIGIN) return false
  if (ancestorOrigins) return ancestorOrigins.includes(APP_ORIGIN)
  return originOf(referrer) === APP_ORIGIN
}

// ---- The Queen's address (#/queen?tab=...&screen=...&path=...) ----
//
// Two writers share these params: the shell writes `tab`, TRI writes `screen`
// and `path`. React Router's setSearchParams updater is handed the params of
// that hook's last render, not the latest address, and its navigations wait in
// a transition, so two quick writes built from render-time params erase each
// other. Both writers build from the live hash instead.

export function hashParamsOf(hash: string): URLSearchParams {
  const at = hash.indexOf('?')
  return new URLSearchParams(at >= 0 ? hash.slice(at + 1) : '')
}

/** The shell's write: the tab, and no screen of a tab you left. */
export function tabAddress(hash: string, next: string): URLSearchParams {
  const params = hashParamsOf(hash)
  if (next === 'comb') params.delete('tab')
  else params.set('tab', next)
  if (next !== 'tri') {
    params.delete('screen')
    params.delete('path')
  }
  return params
}

/** TRI's write: its tab, its screen (none for the feed) and a checked profile path. */
export function triAddress(hash: string, screen: TriScreen, path: string | null): URLSearchParams {
  const params = hashParamsOf(hash)
  params.set('tab', 'tri')
  if (screen === DEFAULT_TRI_SCREEN) params.delete('screen')
  else params.set('screen', screen)
  const deep = triPathOf(screen, path)
  if (deep) params.set('path', deep)
  else params.delete('path')
  return params
}
