/**
 * hive_board: the CLIENTS half of the Queen's kanban, asked of the hive as the
 * person who is signed in.
 *
 * The Queen's board has always shown the same public task board to everybody.
 * This adds the second lane: the people a signed-in visitor is actually
 * responsible for — their pipeline, in the same columns the owner's console
 * uses, on the same screen as the work.
 *
 * WHY THIS FILE HOLDS NO CREDENTIAL
 *
 * There are two credentials in this app and they must never meet. The console's
 * agent key and session bearer live in crmClient.ts and nowhere else; the game
 * token the player mints lives in triIdentity.ts and nowhere else — not in
 * storage, not in a URL, not in a log, and not in a variable a component can
 * read. So this module does not fetch. It says what it wants asked
 * (`callAsPlayer`), and triIdentity makes the request with the token it already
 * holds. The rule that exactly one identity header goes out, that it is
 * `Authorization` and never the console's own key header, and that no request
 * carries a cookie, is kept in ONE place by ONE file, which is the only way a
 * rule like that survives contact with a growing page. The
 * console's header is not spelled out here on purpose: the gate asserts the
 * literal is absent from this file, and a rule with no judgement in it has no
 * way to erode.
 *
 * WHY IT PRINTS NO NUMBER THE SERVER SENT
 *
 * `hive_board` answers with a count on every column and every filter option.
 * This module drops all of them on the floor. A bee may see their own clients
 * and nothing else — not a list of other people's, and not an aggregate that
 * says how many other people's there are. "Seventeen elsewhere" is a leak with
 * a smaller vocabulary, not a safe summary. The only numbers that reach the
 * screen are counts of the cards actually in hand, which cannot describe a row
 * that was never sent. A count the server has not answered for is not zero; it
 * renders as an em dash, the way the public board's counts already do.
 *
 * WHY THE FILTER NEVER GOES BACK TO THE SERVER
 *
 * The tool takes a `client` argument, and this module never sends it. The
 * server has already decided what this person may see; narrowing to one bot or
 * one client after that is a view concern, and doing it locally means a control
 * on a page can only ever show a subset of what already arrived. A filter that
 * re-asks is a filter that can be made to ask for something else.
 *
 * Everything that comes back is DATA from a remote service — names and bot
 * handles are other people's text. React renders them as text nodes; nothing
 * here builds markup, and nothing here is ever treated as an instruction.
 */

import { mcpPayload } from './mcpAnswer.ts'
import { STAGES, STAGE_LABEL, label } from './crmModel.ts'
import type { Stage } from './crmModel.ts'
import { triIdentity } from './triIdentity.ts'
import type { HiveRole, PlayerTool, TriIdentity } from './triIdentity.ts'

/**
 * Typed as PlayerTool so this name has to be in triIdentity's allowlist to
 * compile. A tool the token may not ask for cannot be named here by accident.
 */
export const HIVE_BOARD_TOOL: PlayerTool = 'hive_board'

/** Who the answer was assembled for, in the hive's own words. */
export interface HiveScope {
  /** keeper, owner, bee — or null when the service names a role we do not know. */
  role: HiveRole | null
  /** The service's own description of the scope; the fallback for an unknown role. */
  label: string
  /** The bots this person answers for. A keeper's list may be long; a bee's is short. */
  bots: string[]
}

/** One person in the pipeline. Nothing here is aggregated and nothing is inferred. */
export interface ClientCard {
  id: string
  name: string
  bot: string
  /** A stage from crmModel's vocabulary, or a stage this build has not met yet. */
  stage: string
  paid: boolean
  waitingForReply: boolean
  /** Days since anybody spoke. null when the service did not say — never 0. */
  quietDays: number | null
  lastTouchAt: string | null
}

/**
 * A column of the clients lane. No count: see the header. The title is OURS,
 * in the reader's language, taken from crmModel's stage vocabulary — the same
 * words the console uses, so the two surfaces cannot come to disagree about
 * what "written to" means. The service's own title is the fallback for a stage
 * this build has never heard of, which is better than showing a bare key.
 */
export interface LaneColumn {
  key: string
  title: string
}

/** Something the view may narrow to: one bot, or one client. No count. */
export interface FilterOption {
  key: string
  label: string
}

export interface HiveBoard {
  scope: HiveScope
  columns: LaneColumn[]
  cards: ClientCard[]
  /** What may be narrowed to, and what the SERVER already narrowed to (which the view cannot undo). */
  filter: { available: FilterOption[]; applied: string | null }
  /** The service explaining its own board. Foreign prose: shown on hover, never as layout. */
  howToRead: string | null
}

/**
 * Which of the four things happened. Four, not one, because each is a different
 * sentence and a different next step: sign in, you were refused, the hive did
 * not answer, the hive answered something this page cannot read.
 */
export type HiveBoardReason = 'signed-out' | 'refused' | 'offline' | 'unreadable'

export type HiveBoardAnswer = { ok: true; board: HiveBoard } | { ok: false; reason: HiveBoardReason }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value)

/** A stranger's string, capped. Anything else is the empty string, never `undefined` on screen. */
const text = (value: unknown, max = 64): string =>
  typeof value === 'string' ? value.trim().slice(0, max) : ''

/** A whole number of days, or null. Absent is NOT zero: zero days quiet means "we spoke today". */
const days = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : null

/** An ISO moment, or null. Not parsed here — formatMoment already refuses what it cannot read. */
const moment = (value: unknown): string | null => (typeof value === 'string' && value !== '' ? value : null)

const HIVE_ROLES_KNOWN = new Set<string>(['keeper', 'owner', 'bee'])

/**
 * Read one `hive_board` answer. Pure: no clock, no network, no globals — which
 * is what lets the gate feed it a hostile answer and watch what survives.
 *
 * Returns null when the body is not a board at all. Null is not an empty
 * board: an empty board is a true statement about a person with no clients,
 * and null is "the hive said something this page cannot read". Rendering the
 * second as the first is how a page comes to claim, in a confident empty
 * column, that somebody has no clients.
 */
export function readHiveBoard(body: unknown): HiveBoard | null {
  const payload = mcpPayload(isRecord(body) ? body.result : undefined)
  if (!isRecord(payload)) return null
  // An envelope-level error is an answer about the request, not a board. The
  // caller turns the absence into a sentence; guessing which sentence from the
  // service's wording is how a refusal gets shown as an outage.
  if (isRecord(body) && body.error !== undefined) return null

  const rawScope = isRecord(payload.scope) ? payload.scope : {}
  const rawRole = text(rawScope.role, 16)
  const scope: HiveScope = {
    role: HIVE_ROLES_KNOWN.has(rawRole) ? (rawRole as HiveRole) : null,
    label: text(rawScope.label, 120),
    bots: Array.isArray(rawScope.bots) ? rawScope.bots.map((bot) => text(bot, 64)).filter(Boolean) : [],
  }

  const clients = isRecord(payload.clients) ? payload.clients : {}
  const columns: LaneColumn[] = (Array.isArray(clients.columns) ? clients.columns : [])
    .map((column) => {
      if (!isRecord(column)) return null
      const key = text(column.key, 32)
      if (!key) return null
      // `count` is deliberately not read. See the header.
      return { key, title: text(column.title, 48) }
    })
    .filter((column): column is LaneColumn => column !== null)

  const cards: ClientCard[] = (Array.isArray(clients.cards) ? clients.cards : [])
    .map((card) => {
      if (!isRecord(card)) return null
      const id = text(card.id, 64)
      if (!id) return null
      return {
        id,
        name: text(card.name, 64),
        bot: text(card.bot, 64),
        stage: text(card.stage, 32),
        paid: card.paid === true,
        waitingForReply: card.waiting_for_reply === true,
        quietDays: days(card.quiet_days),
        lastTouchAt: moment(card.last_touch_at),
      }
    })
    .filter((card): card is ClientCard => card !== null)

  const rawFilter = isRecord(payload.filter) ? payload.filter : {}
  const available: FilterOption[] = (Array.isArray(rawFilter.available) ? rawFilter.available : [])
    .map((option) => {
      if (!isRecord(option)) return null
      const key = text(option.key, 64)
      if (!key) return null
      return { key, label: text(option.label, 64) || key }
    })
    .filter((option): option is FilterOption => option !== null)

  return {
    scope,
    columns,
    cards,
    filter: { available, applied: text(rawFilter.applied, 64) || null },
    howToRead: text(payload.how_to_read, 400) || null,
  }
}

/**
 * Ask the hive for this person's board.
 *
 * The caller is injectable so the gate can drive a real signed-in identity — or
 * a signed-out one — and watch the wire. It defaults to the app's single
 * identity because a second identity would be a second token.
 */
export async function loadHiveBoard(
  caller: Pick<TriIdentity, 'callAsPlayer'> = triIdentity(),
): Promise<HiveBoardAnswer> {
  // No arguments. The tool takes `client`, and sending it is how a view control
  // would come to touch the authorization path; identity is the server's from
  // the token, and this page has nothing to add to it.
  const answer = await caller.callAsPlayer(HIVE_BOARD_TOOL)
  if (!answer.ok) return { ok: false, reason: answer.reason }
  const board = readHiveBoard(answer.body)
  return board ? { ok: true, board } : { ok: false, reason: 'unreadable' }
}

/** A column with the cards that are in it: what the lane draws. */
export interface LaneGroup {
  column: LaneColumn
  cards: ClientCard[]
}

export interface ClientsLane {
  scope: HiveScope
  groups: LaneGroup[]
  /** The choices offered by the control. Never more than the server sent. */
  options: FilterOption[]
  /** The view's narrowing: one option key, or null for all of them. */
  narrow: string | null
  /** The server's own narrowing, which no control here can widen. */
  applied: string | null
  howToRead: string | null
  /** Cards drawn, after narrowing. A count of what is on screen, never of what is not. */
  shown: number
}

/**
 * The lane, ready to render — or null, which means DRAW NOTHING CLIENT-SCOPED.
 *
 * Null is the signed-out answer, and it is the whole of the signed-out
 * behaviour: no lane, no header, no empty column, no count, not even a label
 * saying a lane exists. A visitor who is not signed in sees the public task
 * board exactly as it was before this feature, because there is nothing to
 * hide when there is nothing rendered.
 */
export function clientsLane(board: HiveBoard | null, narrow: string | null, lang: string): ClientsLane | null {
  if (!board) return null
  const locale = lang === 'ru' ? 'ru' : 'en'

  // A narrowing to something the server never offered is not a narrowing; it is
  // a key from somewhere else, and honouring it would let a control describe a
  // set the server did not answer for. Ignoring it shows everything that
  // arrived, which is by definition still within what this person may see.
  const offered = new Set(board.filter.available.map((option) => option.key))
  const applied = narrow && offered.has(narrow) ? narrow : null
  const cards = applied ? board.cards.filter((card) => card.bot === applied || card.id === applied) : board.cards

  // The server's order, plus any stage its column list did not mention but its
  // cards used, plus crmModel's order when it sent no columns at all. A card
  // whose column nobody declared must still be drawn: a silently dropped card
  // is a person who has disappeared from the board of the one who owes them
  // an answer.
  const keys = board.columns.map((column) => column.key)
  const seen = new Set(keys)
  for (const stage of cards.map((card) => card.stage)) {
    if (stage && !seen.has(stage)) {
      seen.add(stage)
      keys.push(stage)
    }
  }
  if (keys.length === 0) for (const stage of STAGES) keys.push(stage)

  const titles = new Map(board.columns.map((column) => [column.key, column.title]))
  const groups: LaneGroup[] = keys.map((key) => ({
    column: {
      key,
      // Ours when we know the stage, the service's words when we do not, the
      // bare key when it sent none. `label` answers the key for an unknown
      // stage, so ask STAGE_LABEL directly rather than reading that fallback.
      title: key in STAGE_LABEL ? label(STAGE_LABEL, key as Stage, locale) : titles.get(key) || key,
    },
    cards: cards.filter((card) => card.stage === key),
  }))

  return {
    scope: board.scope,
    groups,
    options: board.filter.available,
    narrow: applied,
    applied: board.filter.applied,
    howToRead: board.howToRead,
    shown: cards.length,
  }
}
