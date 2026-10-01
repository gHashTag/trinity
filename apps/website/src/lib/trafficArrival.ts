/**
 * A VISITOR FROM A TAGGED LINK IS COUNTED ONCE, BY CHANNEL.
 *
 * The agents publish blog links with their channel in the address
 * (`https://t27.ai/?utm_source=x&utm_campaign=blog&utm_content=<slug>#/blog/<slug>`,
 * 999-multibots-telegraf render/src/agent/utm.ts). Tags on a link count
 * nothing by themselves: this is the arrival half. On load the page reads
 * the tags from its own query -- BEFORE the `#`, where HashRouter leaves
 * them -- and tells the render service once per browser session, which
 * keeps a count per (day, channel) and nothing else: no IP, no user id.
 *
 * No tags, no call. A failed call is dropped; the page never waits on it.
 */
export const ARRIVAL_URL =
  'https://vibee-render-production.up.railway.app/api/traffic/arrival'

export interface ArrivalTags {
  source: string
  medium?: string
  campaign?: string
  content?: string
}

/** The utm tags of a query string, or null when it names no source. Pure. */
export function arrivalFromSearch(search: string): ArrivalTags | null {
  const q = new URLSearchParams(search.startsWith('?') ? search : `?${search}`)
  const source = (q.get('utm_source') ?? '').trim()
  if (!source) return null
  const tags: ArrivalTags = { source }
  const more: Array<[string, 'medium' | 'campaign' | 'content']> = [
    ['utm_medium', 'medium'],
    ['utm_campaign', 'campaign'],
    ['utm_content', 'content'],
  ]
  for (const [k, key] of more) {
    const v = (q.get(k) ?? '').trim()
    if (v) tags[key] = v
  }
  return tags
}

const ONCE_KEY = 'traffic:arrival-reported'

/** Report this visit's tags, once per browser session. Never throws. */
export async function reportArrival(
  search: string = typeof window !== 'undefined' ? window.location.search : '',
  send: typeof fetch = fetch,
  storage: Pick<Storage, 'getItem' | 'setItem'> | null = typeof sessionStorage !== 'undefined'
    ? sessionStorage
    : null
): Promise<boolean> {
  const tags = arrivalFromSearch(search)
  if (!tags) return false
  try {
    // The channel of this visit, for the links into our bot (carrySource).
    if (!storage?.getItem(SOURCE_KEY)) storage?.setItem(SOURCE_KEY, tags.source)
  } catch {
    /* no storage: the bot link goes untagged */
  }
  try {
    if (storage?.getItem(ONCE_KEY)) return false
    storage?.setItem(ONCE_KEY, '1')
  } catch {
    /* no storage: count anyway */
  }
  try {
    await send(ARRIVAL_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(tags),
      keepalive: true,
    })
    return true
  } catch {
    return false
  }
}

/*
 * THE CHANNEL RIDES ON INTO THE BOT (owner, 2026-09-26: "end-to-end
 * conversion from t27.ai").
 *
 * A visitor from X who presses "open in Telegram" used to reach the bot as
 * nobody from nowhere: the visit was counted, the start was not tied to it.
 * The bot reads the channel at the end of its /start payload after `__`
 * (999-multibots-telegraf src/navigation/helpers/appLinks.ts
 * splitStartSource) and counts the start by channel; this puts it there, at
 * the moment of the click, for OUR bot's links only, never past Telegram's
 * 64 characters, never over a channel already in the link.
 */
export const SOURCE_KEY = 'traffic:source'
export const OUR_BOTS = ['t27ai_bot']
const START_MAX = 64

/** The bot link carrying this visit's channel; anything else as given. Pure. */
export function carrySource(href: string, source: string | null): string {
  const tag = String(source ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 32)
  if (!tag) return href
  let u: URL
  try {
    u = new URL(href)
  } catch {
    return href
  }
  if (!['t.me', 'telegram.me'].includes(u.hostname.toLowerCase())) return href
  if (!OUR_BOTS.includes(u.pathname.replace(/^\//, '').toLowerCase())) return href
  const start = u.searchParams.get('start')
  if (!start || start.includes('__')) return href
  const next = `${start}__${tag}`
  if (next.length > START_MAX || !/^[A-Za-z0-9_-]+$/.test(next)) return href
  u.searchParams.set('start', next)
  return u.toString()
}

/** Tag our bot links as they are pressed. Never throws, never blocks a click. */
export function installBotLinkCarry(
  doc: Pick<Document, 'addEventListener'> | null = typeof document !== 'undefined' ? document : null,
  storage: Pick<Storage, 'getItem'> | null = typeof sessionStorage !== 'undefined'
    ? sessionStorage
    : null
): void {
  if (!doc) return
  const tag = (e: Event) => {
    try {
      const a = (e.target as Element | null)?.closest?.('a[href]') as HTMLAnchorElement | null
      if (!a) return
      const next = carrySource(a.href, storage?.getItem(SOURCE_KEY) ?? null)
      if (next !== a.href) a.href = next
    } catch {
      /* a link stays as it was */
    }
  }
  doc.addEventListener('click', tag, true)
  doc.addEventListener('auxclick', tag, true)
}
