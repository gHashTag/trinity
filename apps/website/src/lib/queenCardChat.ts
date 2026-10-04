// A card on the board opens its conversation with the agent, in the app that frames it.
//
// Owner, 2026-10-01: tap any card on app.t27.ai/game/kanban and a chat with the
// agent opens, with the task's history, so any task can be written to and carried
// on. The chat lives in the player (999 apps/vibee-editor/player, the Hive's card
// sheet); the board only says which card was tapped. Spec of record: gHashTag/t27
// specs/automation/kanban-card-chat.t27 (MSG_V, MSG_TYPE, MSG_KIND, SAME_ORIGIN_ONLY).
//
// The message goes to the parent only when the parent is this page's own origin --
// the board served at https://app.t27.ai/queen/ inside the player's /game. Reading
// the parent's origin throws across origins, so t27.ai/#/queen, a page that frames
// the board elsewhere, and the board on its own all keep the card's GitHub link.
// A modified click, a middle click and a click something else already handled keep
// it too: cmd-click still opens the issue in a new tab.
//
// It imports nothing, so the node test can load it with --experimental-strip-types.

export const OPEN_CARD = { v: 1, type: 't27-app', kind: 'open-card' } as const

export interface OpenCardMessage {
  v: 1
  type: 't27-app'
  kind: 'open-card'
  repo: string
  number: number
  title: string
  column: string
}

export function openCardMessage(repo: string, number: number, title: string, column: string): OpenCardMessage {
  return { ...OPEN_CARD, repo, number, title, column }
}

/** The part of a click this module reads; a React MouseEvent fits. */
export interface CardTap {
  defaultPrevented: boolean
  button: number
  metaKey: boolean
  ctrlKey: boolean
  shiftKey: boolean
  altKey: boolean
  preventDefault(): void
}

/** The part of `window` this module reads. */
export interface CardWindow {
  parent: unknown
  location: { origin: string }
}

/** The parent window when it is this page's own origin, else null. */
export function sameOriginParent(win: CardWindow): { postMessage(m: unknown, origin: string): void } | null {
  const parent = win.parent as { location?: { origin?: string }; postMessage?: unknown } | null
  if (!parent || parent === win) return null
  try {
    if (parent.location?.origin !== win.location.origin) return null
  } catch {
    return null
  }
  return typeof parent.postMessage === 'function' ? (parent as { postMessage(m: unknown, origin: string): void }) : null
}

/**
 * The card's anchor onClick. True when the app took the tap -- the link is not
 * followed and the app opens the card's chat; false leaves the link to the browser.
 */
export function openCardInApp(event: CardTap, message: OpenCardMessage, win: CardWindow | undefined = typeof window === 'undefined' ? undefined : window): boolean {
  if (!win || event.defaultPrevented || event.button !== 0) return false
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false
  const parent = sameOriginParent(win)
  if (!parent) return false
  event.preventDefault()
  parent.postMessage(message, win.location.origin)
  return true
}
