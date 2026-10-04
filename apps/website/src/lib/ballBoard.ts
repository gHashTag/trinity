/**
 * ball_board: the owner's MAIL, CRM and open work by client, with whose move it
 * is -- the kanban's third lane, asked of the hive as the person signed in.
 *
 * Owner, 2026-10-01: every task from the mail visible to the owner when signed
 * in, "and to others if I allowed it -- sort out privacy and security".
 *
 * WHO DECIDES WHO SEES WHAT: THE SERVER, AND ONLY THE SERVER
 *
 * The rules live in gHashTag/t27 specs/automation/ball-board.t27 and
 * ball-grants.t27, enforced by the render service before it reads a row:
 *   - the mailbox is the owner's, plus whoever the owner granted it to, for
 *     one linked client or all of them, until the grant runs out;
 *   - a viewer never receives an unlinked matter, an address, or the owner's
 *     links -- they are applied on the server;
 *   - the open-work column (private repositories) is the owner's alone;
 *   - the t27.ai game token cannot open this tool at all. On app.t27.ai the
 *     app's own session asks, and the person's identity is the server's.
 * This module adds no rule of its own to those. It cannot widen them -- it
 * sends no argument, so there is nothing to widen them with -- and it does not
 * pretend to narrow them either.
 *
 * WHY THE LANE IS ABSENT, NOT EMPTY, FOR EVERYBODY THE MAIL WAS REFUSED TO
 *
 * A signed-in person with no grant still gets an answer: their own CRM cards,
 * with the mail marked `not_yours`. Drawing a "mail" lane for them -- even an
 * empty one, even a locked one -- names a screen they cannot open and says the
 * owner has mail somebody might be shown. So the lane exists only when the
 * server actually sent the mail source; refused, it is the same page it was.
 *
 * Like hiveBoard.ts, this file holds no credential (triIdentity.ts sends),
 * reads no count the server sent (a number describing rows that were not sent
 * is a description of somebody else's mail), and treats every string as other
 * people's text: rendered as text nodes, never markup, never an instruction.
 * The one thing a card may carry that is not text is a link, and only to
 * github.com over https -- an address from a remote service is a place the
 * page would send a click, and `javascript:` is also an address.
 */

import { mcpPayload } from './mcpAnswer.ts'
import { triIdentity } from './triIdentity.ts'
import type { PlayerTool, TriIdentity } from './triIdentity.ts'

/** Typed as PlayerTool: a name the token may not ask for cannot be written here. */
export const BALL_BOARD_TOOL: PlayerTool = 'ball_board'

/**
 * The ball vocabulary in its column order (ball-board.t27 BALL_OURS, BALL_DUE,
 * BALL_THEIRS, BALL_NONE): ours to move first, then promised, then waiting on
 * somebody else, then nobody's.
 */
export const BALLS = ['ours', 'due', 'theirs', 'none'] as const
export type BallKey = (typeof BALLS)[number]

/** Where a card came from. A source this build has not met keeps its own key. */
export type BallSource = 'mail' | 'crm' | 'github' | string

export interface BallCard {
  source: BallSource
  /** The client row it belongs to, by the server's key and display name. */
  client: string
  clientKey: string
  ref: string
  title: string
  ball: string
  /** Days since the last move. null when the service did not say -- never 0. */
  days: number | null
  because: string | null
  /** https://github.com/... or null. Nothing else survives the reader. */
  link: string | null
}

export type BallSourceStatus = 'ok' | 'empty' | 'stale' | 'not_yours' | 'unreachable' | 'unknown'

export interface BallBoard {
  cards: BallCard[]
  sources: Record<string, BallSourceStatus>
}

export type BallBoardReason = 'signed-out' | 'refused' | 'offline' | 'unreadable'
export type BallBoardAnswer = { ok: true; board: BallBoard } | { ok: false; reason: BallBoardReason }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value)

const text = (value: unknown, max = 120): string => (typeof value === 'string' ? value.trim().slice(0, max) : '')

const days = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : null

const STATUSES = new Set<string>(['ok', 'empty', 'stale', 'not_yours', 'unreachable'])

/** A link the page may send a click to: github over https, or nothing. */
export function safeLink(value: unknown): string | null {
  if (typeof value !== 'string' || value.length > 300) return null
  try {
    const url = new URL(value)
    return url.protocol === 'https:' && url.hostname === 'github.com' && !url.username && !url.password
      ? url.href
      : null
  } catch {
    return null
  }
}

/**
 * Read one `ball_board` answer. Pure, so the gate can feed it a hostile one.
 * Null is "not a board", which is not the same statement as an empty board.
 */
export function readBallBoard(body: unknown): BallBoard | null {
  if (isRecord(body) && body.error !== undefined) return null
  const payload = mcpPayload(isRecord(body) ? body.result : undefined)
  if (!isRecord(payload) || !Array.isArray(payload.clients)) return null

  const sources: Record<string, BallSourceStatus> = {}
  if (isRecord(payload.sources)) {
    for (const [key, value] of Object.entries(payload.sources)) {
      const name = text(key, 16)
      if (!name) continue
      // `cards` and `age_h` are deliberately not read. See the header.
      const status = isRecord(value) ? text(value.status, 16) : ''
      sources[name] = STATUSES.has(status) ? (status as BallSourceStatus) : 'unknown'
    }
  }

  const cards: BallCard[] = []
  for (const row of payload.clients) {
    if (!isRecord(row) || !Array.isArray(row.cards)) continue
    const clientKey = text(row.key, 120)
    if (!clientKey) continue
    const client = text(row.name, 80) || clientKey
    for (const card of row.cards) {
      if (!isRecord(card)) continue
      const ref = text(card.ref, 160)
      if (!ref) continue
      cards.push({
        source: text(card.source, 16) || 'unknown',
        client,
        clientKey,
        ref,
        title: text(card.title, 200) || ref,
        ball: text(card.ball, 16) || 'none',
        days: days(card.days),
        because: text(card.because, 120) || null,
        link: safeLink(card.link),
      })
    }
  }
  return { cards, sources }
}

/**
 * Ask the hive for this person's ball board. No arguments: identity and scope
 * are the server's, from the session, and this page has nothing to add to them.
 */
export async function loadBallBoard(
  caller: Pick<TriIdentity, 'callAsPlayer'> = triIdentity(),
): Promise<BallBoardAnswer> {
  const answer = await caller.callAsPlayer(BALL_BOARD_TOOL)
  if (!answer.ok) return { ok: false, reason: answer.reason }
  const board = readBallBoard(answer.body)
  return board ? { ok: true, board } : { ok: false, reason: 'unreadable' }
}

export interface BallGroup {
  ball: string
  cards: BallCard[]
}

export interface BallLane {
  groups: BallGroup[]
  /** Cards drawn. A count of what is on screen, never of what is not. */
  shown: number
  /** The mail source's own word, for the lane's tooltip: ok, empty, stale... */
  mail: BallSourceStatus
}

/**
 * The lane, ready to render -- or null, which means DRAW NOTHING.
 *
 * Null when there is no board (signed out, refused), and null when the board
 * came without the mail: a person the mailbox was refused to gets the page
 * they had before this lane existed. Columns run in the ball's order; a ball
 * this build has never heard of still gets a column, because a dropped card is
 * a thing somebody owes that vanished from the board of the person who owes it.
 */
export function ballLane(board: BallBoard | null): BallLane | null {
  if (!board) return null
  const mail = board.sources.mail ?? 'unknown'
  if (mail === 'not_yours' || mail === 'unknown') return null

  const keys: string[] = [...BALLS]
  for (const card of board.cards) if (!keys.includes(card.ball)) keys.push(card.ball)
  const byWait = (a: BallCard, b: BallCard) => (b.days ?? -1) - (a.days ?? -1)
  return {
    groups: keys.map((ball) => ({ ball, cards: board.cards.filter((card) => card.ball === ball).sort(byWait) })),
    shown: board.cards.length,
    mail,
  }
}
