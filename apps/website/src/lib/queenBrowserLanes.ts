/**
 * TASKS SIDE BY SIDE, IN THE PERSON'S ONE BROWSER.
 *
 * The person has one browser on the render, with their logins in it. Two
 * chats driving it at once used to fight over the one tab the tools act in:
 * the second chat's `browser_open` chose ITS tab, and the first chat's next
 * click landed there. The render now runs a chat in a LANE
 * (999-multibots-telegraf render/src/browser/lanes.ts, #3554): `main` is the
 * chat as it always was, and any other lane works in a window of its own in
 * the same browser, with its own chosen tab.
 *
 * On the board, the chat panel stays the main lane. A task card is one more
 * lane: its own question, its own answer, its own window -- so the person can
 * send one task off and keep talking to the Queen about another.
 *
 * What the render enforces, and this file only mirrors so the board can say
 * it before the server refuses it:
 *  - the shape of a lane name (400 `bad_request` otherwise);
 *  - at most LANE_CAP lanes per person, main included (409 `lane_limit`);
 *  - a lane idle for LANE_IDLE_MIN minutes is let go -- its window closed.
 *
 * A render from before lanes reads no `lane` at all and answers 200 from main.
 * The status cannot tell the two apart, so the render confirms a lane on the
 * first line of its stream (`{тип:'lane', lane}`) and its absence is the old
 * render: the board then says the answer came from the main conversation and
 * offers no more cards, rather than pretending two tasks ran apart.
 *
 * Pure and driven through its arguments, so qa/queen-browser-lanes-contract.mjs calls
 * the decisions directly.
 */

/** The chat panel's lane: what there was before lanes, and never sent by name. */
export const MAIN_LANE = 'main'

/** The render's own shape (render/src/browser/lanes.ts LANE_SHAPE). */
export const LANE_SHAPE = /^[a-z0-9][a-z0-9-]{0,23}$/

/** Windows per person, main included (render/src/browser/windows.ts MAX_WINDOWS). */
export const LANE_CAP = 3

/** Task cards the board may open beside the chat: every lane but main. */
export const EXTRA_LANES = LANE_CAP - 1

/** Idle minutes before the render lets a lane go (render front-page.ts CHOICE_TTL_MS). */
export const LANE_IDLE_MIN = 30

/** A card's lane name: the first free `task-N`, N from 2 (the chat is task 1). */
export function laneNameFor(taken: readonly string[]): string | null {
  if (taken.length >= EXTRA_LANES) return null
  for (let n = 2; n <= LANE_CAP + taken.length; n++) {
    const name = `task-${n}`
    if (!taken.includes(name)) return name
  }
  return null
}

/**
 * The `lane` field of a chat request. Main is left out, so a request from the
 * chat panel is byte-for-byte what it was before lanes; a name of the wrong
 * shape is a bug on this side and throws rather than reaching the server.
 */
export function laneField(lane: string | undefined): { lane?: string } {
  if (lane === undefined || lane === MAIN_LANE) return {}
  if (!LANE_SHAPE.test(lane)) throw new Error(`not a lane name: ${JSON.stringify(lane)}`)
  return { lane }
}

/** Whether the render runs lanes: unknown until a card has had an answer. */
export type LaneSupport = 'unknown' | 'yes' | 'no'

/**
 * What one finished answer says about the render. A lane that came back
 * confirmed proves lanes; a lane that came back without the confirmation was
 * answered from main by a render from before lanes. Main proves nothing.
 */
export function supportAfter(prev: LaneSupport, asked: string, confirmed: string | null): LaneSupport {
  if (asked === MAIN_LANE) return prev
  return confirmed === asked ? 'yes' : 'no'
}

/** A lane the render refused, before any of it ran. */
export type LaneRefusal = 'limit' | 'shape'

/** The render's refusal of a lane, from its status and body; null if it is not one. */
export function refusalOf(status: number, raw: string): LaneRefusal | null {
  let code: unknown = null
  let error = ''
  try {
    const body = JSON.parse(raw) as Record<string, unknown>
    code = body.code
    error = typeof body.error === 'string' ? body.error : ''
  } catch {
    return null
  }
  if (status === 409 && code === 'lane_limit') return 'limit'
  if (status === 400 && code === 'bad_request' && /\blane\b/.test(error)) return 'shape'
  return null
}

export class AgentLaneRefused extends Error {
  readonly refusal: LaneRefusal
  constructor(refusal: LaneRefusal, detail: string) {
    super(`lane refused (${refusal}): ${detail.slice(0, 300)}`)
    this.refusal = refusal
  }
}

/**
 * Whether the board offers one more card: over a live browser, to a signed-in
 * person, while the render has not shown it cannot run lanes, and below the
 * cap. A render that refused with `lane_limit` holds lanes the board does not
 * see (another device, the bot), so `full` closes the offer until a card goes.
 */
export function canAddLane(s: { live: boolean; signedIn: boolean; support: LaneSupport; cards: number; full: boolean }): boolean {
  return s.live && s.signedIn && s.support !== 'no' && !s.full && s.cards < EXTRA_LANES
}

/** What a card shows under its question. */
export type CardState = 'idle' | 'working' | 'answered' | 'limit' | 'old' | 'signedout' | 'failed'

/**
 * A card's state after its answer, or after its refusal. `old` is an answer
 * that came from main: it is shown, and said to be from the main conversation.
 */
export function cardStateAfter(outcome: { lane: string; confirmed: string | null } | { refusal: LaneRefusal } | 'signedout' | 'failed'): CardState {
  if (outcome === 'signedout' || outcome === 'failed') return outcome
  if ('refusal' in outcome) return outcome.refusal === 'limit' ? 'limit' : 'failed'
  return outcome.confirmed === outcome.lane ? 'answered' : 'old'
}

/** The lane a journal step ran in: its `detail.lane`, or main when there is none. */
export function laneOfStep(detail: Record<string, unknown> | null | undefined): string {
  const lane = detail?.lane
  return typeof lane === 'string' && LANE_SHAPE.test(lane) ? lane : MAIN_LANE
}
