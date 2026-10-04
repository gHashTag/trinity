/**
 * THE QUEEN MOVED. https://t27.ai/#/queen NOW SENDS YOU TO app.t27.ai/queen/.
 *
 * The owner asked for one server at one address, with the address kept as
 * app.t27.ai because the app is the product. app.t27.ai now builds and serves
 * the board at /queen/ (999-multibots-telegraf, the `queen` Docker stage and
 * `location ^~ /queen/`), so this address is the old one and its job is to
 * hand visitors over — every link, bookmark and pasted URL still works.
 *
 * A REDIRECT AND NOT A FRAME, deliberately. The board at its new home reads
 * the app's session and can do everything the app can, so its frame-ancestors
 * refuses t27.ai — a page here framing it would be blocked, and rightly:
 * frame-ancestors is per origin, so admitting t27.ai would admit every
 * gHashTag site published there (t27.ai/leela/, /trinity/, ...), any of which
 * could hide the board under a decoy. A redirect consults no frame-ancestors
 * and hands over nothing.
 *
 * THE TRAP THIS FUNCTION EXISTS TO AVOID: ONE BUNDLE, TWO ORIGINS.
 *
 * app.t27.ai builds the board from THIS repository, so the code below is also
 * running at https://app.t27.ai/queen/#/queen — the destination. A redirect
 * keyed on the route alone would send that page to itself, for ever. So the
 * decision is keyed on the ORIGIN first, and the destination is excluded twice
 * over: by hostname, and by the /queen/ path prefix.
 *
 * Split into a pure function because that is the part worth testing, and
 * qa/queen-redirect-contract.mjs calls it with real inputs rather than reading
 * this file for reassuring-looking lines.
 */

/** Just the parts of `window.location` the decision reads. */
export interface LegacyQueenLocation {
  hostname: string
  pathname: string
  search: string
  hash: string
}

/** Where the board lives now. Trailing slash: nginx would 301 to it anyway. */
export const QUEEN_HOME = 'https://app.t27.ai/queen/'

/** The origins that no longer host the board. www.t27.ai already 301s to the apex. */
const OLD_HOSTS = ['t27.ai', 'www.t27.ai']

/**
 * `#/queen`, `#/queen?tab=kanban`, `#/queen/anything` — but not `#/queenly`,
 * which is why the character after the route is pinned.
 */
const QUEEN_ROUTE = /^#\/queen(?:[?/]|$)/

/**
 * The address to send this visitor to, or null to stay put.
 *
 * @param isTop  whether the document is the top-level one. A framed copy is
 *               left alone: navigating out of a frame is something a page does
 *               TO its host, and ?embed=1 previews exist to be framed.
 */
export function queenRedirectTarget(
  loc: LegacyQueenLocation,
  isTop: boolean
): string | null {
  // The destination runs this same bundle. Both of these keep it still.
  if (!OLD_HOSTS.includes(loc.hostname)) return null
  if (loc.pathname === '/queen/' || loc.pathname.startsWith('/queen/')) {
    return null
  }

  if (!isTop) return null
  if (!QUEEN_ROUTE.test(loc.hash)) return null

  // ?embed=1 is a preview of the board inside another page. It asks nobody for
  // an identity and it is not a visitor to hand over.
  const params = new URLSearchParams(loc.hash.split('?')[1] ?? '')
  if (params.get('embed') === '1') return null

  // Both halves are carried: ?lang= lives in the search, the tab in the hash,
  // so https://t27.ai/?lang=ru#/queen?tab=kanban survives whole.
  return `${QUEEN_HOME}${loc.search}${loc.hash}`
}

/**
 * Applies it. `replace` and not `assign`: the old address should not sit in
 * history as a place Back can return to, because Back would redirect again.
 */
export function redirectLegacyQueen(): boolean {
  if (typeof window === 'undefined') return false
  let isTop = true
  try {
    isTop = window.top === window.self
  } catch {
    // Reading window.top across origins throws; that it threw means framed.
    isTop = false
  }
  const target = queenRedirectTarget(window.location, isTop)
  if (!target) return false
  window.location.replace(target)
  return true
}
