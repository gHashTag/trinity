// The frame side of lib/queenEmbed: what an Explorer page does when the Queen hosts it.
//
// It imports nothing on purpose. main.tsx and useHashParams load it on every route, so
// it stays out of the entry chunk's way: the catalogs and hash helpers the host needs to
// validate an id live in lib/queenEmbed, which only the Queen's tabs load. The frame
// does not validate: it reports what it wrote and forwards what was clicked, and the
// Queen checks both before it acts.
//
// postMessage rather than reaching into the parent window: the frame needs to know
// nothing of the Queen's router, and the check on origin and source is explicit on
// the side that acts. A frame the Queen did not name -- the Spec Explorer inside a
// skill card, the landing's previews -- posts nothing and keeps its own links.

/** The name the Queen gives its Explorer frame; a page that finds it on its own window is hosted by the Queen. */
export const QUEEN_FRAME_NAME = 't27-queen-explorer'
const MESSAGE_TYPE = 't27:queen-explorer'

/** `selected`: the Explorer wrote this card to its address. `open`: a link to this route was followed. */
export interface QueenFrameMessage {
  type: typeof MESSAGE_TYPE
  action: 'selected' | 'open'
  hash: string
}

export function isQueenFrameMessage(data: unknown): data is QueenFrameMessage {
  const m = data as Partial<QueenFrameMessage> | null
  return typeof m === 'object' && m !== null && m.type === MESSAGE_TYPE && (m.action === 'selected' || m.action === 'open') && typeof m.hash === 'string'
}

const ROUTE = /^#\/(specs|skills|crons|agents|functions|tools|docs)(?:\/([^?#]*))?(?:\?([^#]*))?(?:#.*)?$/

/** The Explorer route a hash names, unvalidated, or null when it names none. Only the docs have sub-routes. */
export function explorerRouteParts(hash: string): { route: string; sub: string | undefined; query: URLSearchParams } | null {
  const m = ROUTE.exec(hash)
  if (!m || (m[1] !== 'docs' && m[2] !== undefined)) return null
  return { route: m[1], sub: m[2], query: new URLSearchParams(m[3] ?? '') }
}

function queenHost(): Window | null {
  if (typeof window === 'undefined' || window.parent === window || window.name !== QUEEN_FRAME_NAME) return null
  return window.parent
}

function post(action: QueenFrameMessage['action'], hash: string): void {
  const message: QueenFrameMessage = { type: MESSAGE_TYPE, action, hash }
  queenHost()?.postMessage(message, window.location.origin)
}

/** Frame side: the Explorer has just written `hash` to its own address. */
export function reportExplorerAddress(hash: string): void {
  post('selected', hash)
}

/**
 * Frame side, installed once at boot: in a frame the Queen hosts, a plain click on a
 * link to an Explorer route asks the Queen to open it -- the Queen switches its tab
 * when the route is another Explorer's -- instead of navigating the frame under a
 * rail that names a different tab. Links a page handles itself (preventDefault),
 * modified clicks and links with a target are left alone.
 */
export function handExplorerLinksToQueen(): void {
  if (!queenHost()) return
  document.addEventListener('click', (event) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const link = event.target instanceof Element ? event.target.closest('a[href^="#/"]') : null
    if (!(link instanceof HTMLAnchorElement) || (link.target && link.target !== '_self')) return
    const hash = link.getAttribute('href') ?? ''
    if (!explorerRouteParts(hash)) return
    event.preventDefault()
    post('open', hash)
  })
}
