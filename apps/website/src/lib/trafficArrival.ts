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
