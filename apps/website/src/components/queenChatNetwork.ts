// THE THREE TABS OF THE QUEEN'S PANEL, AND THE ARITHMETIC BEHIND TWO OF THEM.
//
// The owner's ask, 2026-09-21: "сделай в чате фильтр с логами в отдельном табе,
// в основном табе диалог с королевой, и третий чат агентная сеть a2a для
// коллаборации агентов" — the conversation in the main tab, the log with a
// filter in its own, and the agents' network in a third.
//
// Everything here is a pure function over the events the board already has, so
// the panel renders one derivation and the gate runs the same one. None of it
// invents a field: WHAT THE WIRE CARRIES IS THE CEILING OF WHAT THIS FILE CAN
// SAY.
//
// Measured against the live feed on 2026-09-21:
//
//   /queen/public-activity   {id, kind, issue, title, at, state} — and no
//                            worker, agent, bee or slot identifier anywhere
//   /a2a                     403 Forbidden
//   /queen/agents            404
//   /queen/a2a               404
//   /.well-known/agent.json  404
//   /queen/network           404
//   /queen/peers             404
//
// So the network cannot be drawn as "agent ↔ agent": there are no agent names
// to draw. What the feed does carry is an issue number on every row, and an
// issue in flight IS one worker's assignment. The network below is therefore
// the Queen at the hub and one link per issue, with the traffic counted in the
// direction it actually travelled. The A2A tab says this in a sentence rather
// than letting a picture imply identities nobody published.

import type { HudEvent, HudEventKind } from './queenHud'

export type ChatTab = 'queen' | 'logs' | 'a2a'
export const CHAT_TABS: readonly ChatTab[] = ['queen', 'logs', 'a2a'] as const

// A fixed order, so the chips in the filter keep their places as the counts
// move under them. Chips that re-sort themselves while a thumb is travelling
// towards one are a different control every second.
export const KIND_ORDER: readonly HudEventKind[] = [
  'dispatch', 'progress', 'tool', 'result', 'usage', 'review', 'finished', 'error',
] as const

// Who is speaking. The Queen dispatches work and returns a verdict on it;
// everything else on the wire is a worker reporting back to her.
const FROM_QUEEN: ReadonlySet<HudEventKind> = new Set<HudEventKind>(['dispatch', 'review'])

// Kinds whose `title` is the ISSUE's title rather than a line about the moment.
// Measured on the live feed 2026-09-21: dispatch, finished and review all carry
// the issue title verbatim, while an error carries the failure ("The worktree
// volume was full"). A link titled by whatever spoke last is therefore titled
// by its most recent problem, which reads as the name of the work.
//
// `result`, `tool`, `progress` and `usage` are left out because none of them
// appeared in the window that was measured, and a guess here puts a status line
// in the slot where a person looks for the name of the issue.
const NAMES_THE_WORK: ReadonlySet<HudEventKind> = new Set<HudEventKind>(['dispatch', 'finished', 'review'])

export type Direction = 'to-worker' | 'to-queen'

export function eventDirection(kind: HudEventKind): Direction {
  return FROM_QUEEN.has(kind) ? 'to-worker' : 'to-queen'
}

// ── the filter ───────────────────────────────────────────────────────────────

export interface LogFilter {
  /** Kinds to keep. EMPTY MEANS EVERY KIND — see filterEvents. */
  kinds: readonly HudEventKind[]
  /** A word from the title, a state, or an issue number with or without its #. */
  text: string
}

export const NO_FILTER: LogFilter = { kinds: [], text: '' }

const ISSUE_QUERY = /^#?(\d+)$/

/**
 * An EMPTY `kinds` keeps everything.
 *
 * This is the one decision in the filter that can be read two ways, and the
 * other reading — no chip lit, so nothing shown — opens the tab on an empty
 * list and tells the reader the board is idle. It is not. Nothing selected is
 * no restriction.
 */
export function filterEvents(events: readonly HudEvent[], filter: LogFilter): HudEvent[] {
  const kinds = new Set(filter.kinds)
  const needle = filter.text.trim().toLowerCase()
  const number = ISSUE_QUERY.exec(needle)
  return events.filter((event) => {
    if (kinds.size > 0 && !kinds.has(event.kind)) return false
    if (!needle) return true
    // A number is a question about an issue, never a coincidence in a title:
    // typing 4395 should not also return the card that has 4395 in its text.
    if (number) return event.issue !== null && String(event.issue).includes(number[1])
    return `${event.title} ${event.kind} ${event.state ?? ''}`.toLowerCase().includes(needle)
  })
}

export interface KindCount { kind: HudEventKind; count: number }

/**
 * Counted over ALL events, never over the filtered ones: a chip has to say how
 * much it would add back, and a chip counted after its own filter reads 0 for
 * every kind that is currently hidden.
 */
export function kindCounts(events: readonly HudEvent[]): KindCount[] {
  const tally = new Map<HudEventKind, number>()
  for (const event of events) tally.set(event.kind, (tally.get(event.kind) ?? 0) + 1)
  const known = KIND_ORDER.filter((kind) => tally.has(kind)).map((kind) => ({ kind, count: tally.get(kind) as number }))
  // A kind the board starts sending that this file has never heard of still
  // gets a chip, at the end. Dropping it would hide rows behind a filter that
  // does not admit they exist.
  const extra = [...tally.keys()].filter((kind) => !KIND_ORDER.includes(kind)).sort()
  return [...known, ...extra.map((kind) => ({ kind, count: tally.get(kind) as number }))]
}

// ── the network ──────────────────────────────────────────────────────────────

/** Where the turn sits, as far as the feed is able to say. */
export type Stance = 'accepted' | 'with-worker' | 'with-queen'

export interface A2ALink {
  /** The issue. It is the only identity on the wire — see the header. */
  issue: number
  /** The issue's own title — see NAMES_THE_WORK, never the latest status line. */
  title: string
  /** When that title was last set. Internal; the panel has no use for it. */
  titleAt: number
  /** Messages this worker sent up to the Queen. */
  toQueen: number
  /** Messages the Queen sent down: the dispatch and her verdicts. */
  toWorker: number
  messages: number
  last: HudEvent
  lastAt: number
  stance: Stance
}

export interface A2ANetwork {
  links: A2ALink[]
  /** Rows the wire gave no issue. They belong to no link and are not hidden. */
  unattributed: number
  /** Every message counted, including the unattributed ones. */
  messages: number
  toQueen: number
  toWorker: number
}

/**
 * Her verdict is the one message on this wire that closes a loop. A `sendBack`
 * does not: it is work returned, and the link is live again. So only an
 * accepted review settles a link, and everything else reports whose turn it is
 * rather than pretending to know whether a process is still running.
 */
function stanceOf(last: HudEvent): Stance {
  if (last.kind === 'review' && last.state === 'accept') return 'accepted'
  return eventDirection(last.kind) === 'to-worker' ? 'with-worker' : 'with-queen'
}

export function a2aNetwork(events: readonly HudEvent[]): A2ANetwork {
  const byIssue = new Map<number, A2ALink>()
  let unattributed = 0
  let toQueen = 0
  let toWorker = 0

  for (const event of events) {
    const up = eventDirection(event.kind) === 'to-queen'
    if (up) toQueen += 1
    else toWorker += 1
    if (event.issue === null) { unattributed += 1; continue }

    const at = Date.parse(event.at) || 0
    const names = NAMES_THE_WORK.has(event.kind) && event.title !== ''
    const link = byIssue.get(event.issue)
    if (!link) {
      byIssue.set(event.issue, {
        issue: event.issue,
        title: event.title,
        titleAt: names ? at : -Infinity,
        toQueen: up ? 1 : 0,
        toWorker: up ? 0 : 1,
        messages: 1,
        last: event,
        lastAt: at,
        stance: stanceOf(event),
      })
      continue
    }
    link.messages += 1
    if (up) link.toQueen += 1
    else link.toWorker += 1
    // The feed is not promised in order, so "last" is the latest timestamp
    // rather than the last row read. Reading it as arrival order made an
    // accepted issue look live whenever two rows shared a second.
    if (at >= link.lastAt) {
      link.last = event
      link.lastAt = at
      link.stance = stanceOf(event)
    }
    // The title follows its own clock, and only rows that carry the issue's
    // name are allowed to set it.
    if (names && at >= link.titleAt) {
      link.title = event.title
      link.titleAt = at
    }
  }

  const links = [...byIssue.values()].sort((a, b) => b.lastAt - a.lastAt || a.issue - b.issue)
  return { links, unattributed, messages: events.length, toQueen, toWorker }
}
