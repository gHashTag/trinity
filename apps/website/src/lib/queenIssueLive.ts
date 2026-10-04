import { useEffect, useRef, useState } from 'react'
import { QUEEN_API } from './queenApi'

// One cell, live.
//
// The close-up needs two things the catalog snapshot does not carry: where the
// issue stands on the supervisor's own board right now, and what the bee holding
// it has just done. Both already exist on the wire -- /queen/public-board and
// /queen/public-activity -- and neither is per-issue, so this hook reads the two
// public feeds and keeps only the rows that name this number.
//
// Nothing here infers liveness. "A bee has it now" is the board's own column,
// not a guess from the age of an event; the newest event's timestamp is printed
// as the timestamp it is. An absent field reads as absent.

export interface CellEvent {
  id: string
  kind: string
  issue: number | null
  title: string
  at: string
  state: string | null
}

export interface CellCard {
  number: number
  title: string
  column: string
  criteria?: number
  needs?: string[]
}

export interface BoardColumn {
  key: string
  title: string
  blurb: string
}

export interface CellLive {
  /** The card as the supervisor's board holds it, or null when the board does not carry this number. */
  card: CellCard | null
  /** The column the card sits in, with the board's own word for what that column means. */
  column: BoardColumn | null
  /** The board's round pulse: when the last round closed, and how long a round is. */
  lastRoundAt: string | null
  /** Events naming this issue, oldest first. */
  events: CellEvent[]
  /** The newest event's timestamp, or null when the window carries none. */
  lastEventAt: string | null
  boardError: string | null
  activityError: string | null
  /** False until the first board answer arrives, so "no card" is never shown as a fact before it is one. */
  boardRead: boolean
  activityRead: boolean
}

const BOARD_POLL_MS = 30_000
const ACTIVITY_POLL_MS = 6_000
// The first read asks for a day so a cell picked cold still shows the round that
// touched it; every read after that carries the cursor, so the answers are small.
const FIRST_WINDOW_MS = 24 * 60 * 60 * 1_000
const EVENT_CAP = 200

function rows(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

export function readBoardCell(raw: unknown, number: number): { card: CellCard | null; column: BoardColumn | null; lastRoundAt: string | null } {
  const board = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}
  const card = rows(board.cards)
    .map((row) => (row !== null && typeof row === 'object' ? (row as Record<string, unknown>) : {}))
    .find((row) => row.number === number)
  const columns = rows(board.columns).map((row) => {
    const column = row !== null && typeof row === 'object' ? (row as Record<string, unknown>) : {}
    return { key: text(column.key), title: text(column.title), blurb: text(column.blurb) }
  })
  const pulse = board.pulse !== null && typeof board.pulse === 'object' ? (board.pulse as Record<string, unknown>) : {}
  if (!card) return { card: null, column: null, lastRoundAt: text(pulse.lastRoundAt) || null }
  const key = text(card.column)
  return {
    card: {
      number,
      title: text(card.title),
      column: key,
      criteria: typeof card.criteria === 'number' ? card.criteria : undefined,
      needs: rows(card.needs).filter((need): need is string => typeof need === 'string'),
    },
    column: columns.find((column) => column.key === key) ?? null,
    lastRoundAt: text(pulse.lastRoundAt) || null,
  }
}

export function readActivityRows(raw: unknown, number: number): CellEvent[] {
  const body = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}
  return rows(body.events)
    .map((row) => (row !== null && typeof row === 'object' ? (row as Record<string, unknown>) : {}))
    .filter((row) => row.issue === number)
    .map((row) => ({
      id: text(row.id),
      kind: text(row.kind),
      issue: number,
      title: text(row.title),
      at: text(row.at),
      state: typeof row.state === 'string' ? row.state : null,
    }))
    .filter((row) => row.id !== '')
}

/** Oldest first, one row per id, capped -- the feed is the archive, this is a window onto it. */
export function mergeCellEvents(previous: CellEvent[], next: CellEvent[]): CellEvent[] {
  if (next.length === 0) return previous
  const merged = new Map(previous.map((row) => [row.id, row]))
  for (const row of next) merged.set(row.id, row)
  return [...merged.values()]
    .sort((a, b) => (Date.parse(a.at) || 0) - (Date.parse(b.at) || 0))
    .slice(-EVENT_CAP)
}

/** Whole seconds, minutes, hours or days between two instants the page was handed. Never an estimate. */
export function elapsed(fromISO: string, now: number): string | null {
  const at = Date.parse(fromISO)
  if (!Number.isFinite(at)) return null
  const seconds = Math.max(0, Math.round((now - at) / 1000))
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86_400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86_400)}d`
}

export function useCellLive(number: number | null): CellLive {
  const [board, setBoard] = useState<{ card: CellCard | null; column: BoardColumn | null; lastRoundAt: string | null }>({ card: null, column: null, lastRoundAt: null })
  const [events, setEvents] = useState<CellEvent[]>([])
  const [boardError, setBoardError] = useState<string | null>(null)
  const [activityError, setActivityError] = useState<string | null>(null)
  const [boardRead, setBoardRead] = useState(false)
  const [activityRead, setActivityRead] = useState(false)
  const cursor = useRef(0)

  useEffect(() => {
    if (number === null) return
    setBoard({ card: null, column: null, lastRoundAt: null })
    setEvents([])
    setBoardRead(false)
    setActivityRead(false)
    let alive = true
    const read = async () => {
      try {
        const response = await fetch(`${QUEEN_API}/queen/public-board`, { headers: { Accept: 'application/json' }, cache: 'no-store' })
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const next = readBoardCell(await response.json(), number)
        if (!alive) return
        setBoard(next)
        setBoardError(null)
        setBoardRead(true)
      } catch (error) {
        if (alive) setBoardError(error instanceof Error ? error.message : String(error))
      }
    }
    void read()
    const timer = window.setInterval(read, BOARD_POLL_MS)
    return () => { alive = false; window.clearInterval(timer) }
  }, [number])

  useEffect(() => {
    if (number === null) return
    let alive = true
    cursor.current = Date.now() - FIRST_WINDOW_MS
    const read = async () => {
      try {
        const response = await fetch(`${QUEEN_API}/queen/public-activity?since=${cursor.current}`, { headers: { Accept: 'application/json' }, cache: 'no-store' })
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const body: unknown = await response.json()
        if (!alive) return
        const at = body !== null && typeof body === 'object' ? (body as Record<string, unknown>).cursor : null
        // A tick back, so an event written in the same second as the cursor is
        // not lost between two polls; the merge is by id, so a repeat is free.
        if (typeof at === 'number') cursor.current = at - ACTIVITY_POLL_MS
        setEvents((previous) => mergeCellEvents(previous, readActivityRows(body, number)))
        setActivityError(null)
        setActivityRead(true)
      } catch (error) {
        if (alive) setActivityError(error instanceof Error ? error.message : String(error))
      }
    }
    void read()
    const timer = window.setInterval(read, ACTIVITY_POLL_MS)
    return () => { alive = false; window.clearInterval(timer) }
  }, [number])

  return {
    card: board.card,
    column: board.column,
    lastRoundAt: board.lastRoundAt,
    events,
    lastEventAt: events.length > 0 ? events[events.length - 1].at : null,
    boardError,
    activityError,
    boardRead,
    activityRead,
  }
}
