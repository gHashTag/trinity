/**
 * ball_board: the ALL lane of the Queen's kanban -- every open thing the
 * signed-in person is part of, by client, with whose move it is.
 *
 * The spec of record is specs/automation/ball-board.t27 in the t27 repo; the
 * host that answers is the render's `ball_board` tool. This file decides
 * nothing about where a ball lies. It reads the answer, refuses what it cannot
 * vouch for, and hands the lane a shape it can draw.
 *
 * WHY THIS FILE HOLDS NO CREDENTIAL
 *
 * Same rule as hiveBoard.ts, kept in the same place: this module names the
 * tool (`callAsPlayer`) and triIdentity makes the request with the token it
 * already holds. A tool the token may not ask for cannot be named here,
 * because BALL_BOARD_TOOL is typed as PlayerTool.
 *
 * WHY A LINK IS CHECKED HERE AND NOT TRUSTED
 *
 * A card's link comes from a remote service, and part of it is other people's
 * text (an issue URL, a mail subject's host). A link is drawn only if it is
 * https on a host this app already sends people to (github.com, t27.ai), or
 * exactly the app's own browser view. Anything else is dropped, not rewritten:
 * a rewritten link is a link nobody checked.
 *
 * WHY A BROWSER CARD CARRIES NO KEY
 *
 * The board shows the caller's own AI-browser session as a card so the person
 * can see what the agent is doing and step in. The card holds a state, a time
 * and the last step's bare host and path -- never the stream URL, never a view
 * token, never typed text (the host's BROWSER_FIELDS and CARD_CARRIES_NO_TOKEN).
 * Opening the browser is the app's own view, behind the app's own sign-in;
 * this module only says that a card IS a browser card.
 *
 * Everything that comes back is DATA. React renders it as text nodes; nothing
 * here builds markup and nothing here is treated as an instruction.
 */

import { mcpPayload } from './mcpAnswer.ts'
import { triIdentity } from './triIdentity.ts'
import type { PlayerTool, TriIdentity } from './triIdentity.ts'

export const BALL_BOARD_TOOL: PlayerTool = 'ball_board'

/** Whose move it is. The order is the spec's: ours first, nobody's last. */
export const BALLS = ['ours', 'due', 'theirs', 'none'] as const
export type Ball = (typeof BALLS)[number]

export const SOURCES = ['crm', 'mail', 'github', 'browser'] as const
export type BallSource = (typeof SOURCES)[number]

/** The app's own browser view: the only relative link a card may carry. */
export const BROWSER_VIEW_PATH = '/game/browser'

/** A spec path the specs view can open. Anything else is not a spec. */
const SPEC_PATH = /^specs\/[\w./-]+\.t27$/
const LINK_HOSTS = ['github.com', 't27.ai']

export interface BallCard {
  source: BallSource
  ref: string
  title: string
  ball: Ball
  /** Days since it moved. null when the service did not say -- never 0. */
  days: number | null
  because: string | null
  /** A checked link, or null. See the header. */
  link: string | null
  /** The .t27 spec the card stands on, or null when it names none. */
  spec: string | null
}

export interface BallClient {
  key: string
  name: string
  ball: Ball
  cards: BallCard[]
  /** Cards the service counted but did not send (its own cap). */
  hidden: number
}

export interface BallSourceState {
  /** ok, empty, stale, unreachable -- or whatever the service said, capped. */
  status: string
  cards: number | null
  ageH: number | null
}

export interface BallBoard {
  total: number | null
  counts: Record<Ball, number | null>
  /** Cards that stand on no spec. Counted, never given one. */
  unspecced: number | null
  sources: Partial<Record<BallSource, BallSourceState>>
  clients: BallClient[]
  clientsTotal: number | null
}

export type BallBoardReason = 'signed-out' | 'refused' | 'offline' | 'unreadable'
export type BallBoardAnswer = { ok: true; board: BallBoard } | { ok: false; reason: BallBoardReason }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value)

const text = (value: unknown, max = 64): string =>
  typeof value === 'string' ? value.trim().slice(0, max) : ''

/** A count, or null. Absent is not zero. */
const count = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : null

const ballOf = (value: unknown): Ball =>
  (BALLS as readonly string[]).includes(value as string) ? (value as Ball) : 'none'

/** The link if this app may send a person there, else null. */
export function safeLink(value: unknown): string | null {
  const raw = text(value, 400)
  if (!raw) return null
  if (raw === BROWSER_VIEW_PATH) return raw
  let url: URL
  try {
    url = new URL(raw)
  } catch {
    return null
  }
  if (url.protocol !== 'https:' || url.username || url.password) return null
  const host = url.hostname.toLowerCase()
  return LINK_HOSTS.some((allowed) => host === allowed || host.endsWith(`.${allowed}`)) ? url.href : null
}

/** The spec path if it is one, else null. `..` never names a spec. */
export function specPath(value: unknown): string | null {
  const raw = text(value, 200)
  return SPEC_PATH.test(raw) && !raw.includes('..') ? raw : null
}

function readCard(card: unknown): BallCard | null {
  if (!isRecord(card)) return null
  const source = text(card.source, 16)
  if (!(SOURCES as readonly string[]).includes(source)) return null
  const ref = text(card.ref, 120)
  if (!ref) return null
  return {
    source: source as BallSource,
    ref,
    title: text(card.title, 160),
    ball: ballOf(card.ball),
    days: count(card.days),
    because: text(card.because, 120) || null,
    link: safeLink(card.link),
    spec: specPath(card.spec),
  }
}

/**
 * Read one `ball_board` answer. Pure, like readHiveBoard, so the gate can feed
 * it a hostile answer. Null means "not a board", which is not an empty board.
 */
export function readBallBoard(body: unknown): BallBoard | null {
  if (isRecord(body) && body.error !== undefined) return null
  const payload = mcpPayload(isRecord(body) ? body.result : undefined)
  if (!isRecord(payload) || !Array.isArray(payload.clients)) return null

  const rawCounts = isRecord(payload.counts) ? payload.counts : {}
  const counts = Object.fromEntries(BALLS.map((ball) => [ball, count(rawCounts[ball])])) as Record<
    Ball,
    number | null
  >

  const rawSources = isRecord(payload.sources) ? payload.sources : {}
  const sources: Partial<Record<BallSource, BallSourceState>> = {}
  for (const source of SOURCES) {
    const state = rawSources[source]
    if (!isRecord(state)) continue
    sources[source] = {
      status: text(state.status, 16) || 'unknown',
      cards: count(state.cards),
      ageH: count(state.age_h),
    }
  }

  const clients: BallClient[] = payload.clients
    .map((client) => {
      if (!isRecord(client)) return null
      const key = text(client.key, 120)
      if (!key) return null
      const cards = (Array.isArray(client.cards) ? client.cards : [])
        .map(readCard)
        .filter((card): card is BallCard => card !== null)
      if (cards.length === 0) return null
      return {
        key,
        name: text(client.name, 64) || key,
        ball: ballOf(client.ball),
        cards,
        hidden: count(client.hidden) ?? 0,
      }
    })
    .filter((client): client is BallClient => client !== null)

  return {
    total: count(payload.total),
    counts,
    unspecced: count(payload.unspecced),
    sources,
    clients,
    clientsTotal: count(payload.clients_total),
  }
}

/** Ask for this person's board. No arguments: identity is the token's. */
export async function loadBallBoard(
  caller: Pick<TriIdentity, 'callAsPlayer'> = triIdentity(),
): Promise<BallBoardAnswer> {
  const answer = await caller.callAsPlayer(BALL_BOARD_TOOL)
  if (!answer.ok) return { ok: false, reason: answer.reason }
  const board = readBallBoard(answer.body)
  return board ? { ok: true, board } : { ok: false, reason: 'unreadable' }
}

/** One card on screen, with the client it belongs to. */
export interface BallLaneCard extends BallCard {
  client: string
  clientKey: string
}

export interface BallLane {
  groups: Array<{ ball: Ball; cards: BallLaneCard[] }>
  /** Cards drawn, after the search. A count of what is on screen. */
  shown: number
  browser: BallLaneCard | null
}

/**
 * The lane, ready to render -- or null, which means draw nothing private.
 * Columns follow the cards' own balls (a client's row ball is its most urgent
 * card's, so a column per card is the honest split). The search is local and
 * can only narrow what arrived.
 */
export function ballLane(board: BallBoard | null, search = ''): BallLane | null {
  if (!board) return null
  const needle = typeof search === 'string' ? search.trim().slice(0, 64).toLowerCase() : ''
  const cards: BallLaneCard[] = board.clients.flatMap((client) =>
    client.cards.map((card) => ({ ...card, client: client.name, clientKey: client.key })),
  )
  const kept = needle
    ? cards.filter((card) =>
        [card.client, card.title, card.ref, card.because ?? '', card.spec ?? ''].some((field) =>
          field.toLowerCase().includes(needle),
        ),
      )
    : cards
  return {
    groups: BALLS.map((ball) => ({ ball, cards: kept.filter((card) => card.ball === ball) })),
    shown: kept.length,
    browser: cards.find((card) => card.source === 'browser') ?? null,
  }
}
