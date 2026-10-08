// The board reads the Queen's event bus: one snapshot, then only what changed.
//
// THE SOURCE IS A SPEC, NOT THIS FILE
//
// gHashTag/t27 specs/queen/events.t27 (epic gHashTag/t27#7718, slice 3) says how
// an event travels: numbers with no gap, a page past a cursor, and what a reader
// does with each event. The supervisor serves it at GET /queen/public-events, and
// GET /queen/public-tasks carries the cursor its snapshot was read at. Here the
// card decides, as wasm (queenEventsCard.ts): delta_action (skip, apply or
// resync), board_action (refresh the task, touch its bee, or nothing) and
// refresh_action (the named tasks, or one whole snapshot). This file only carries
// the answers to the feed.
//
// WHY. Measured 2026-10-08: the board and the game redrew the whole task list
// every five seconds, about 1,500 tasks each time, to learn that one bee spoke.

import {
  DA_RESYNC,
  DA_SKIP,
  EA_REFRESH,
  EA_TOUCH,
  RF_SNAPSHOT,
} from "./queenEvents.generated";
import { cardBoardAction, cardDeltaAction, cardRefreshAction } from "./queenEventsCard";
import { BEE_STATE_NAMES } from "./queenTasks.generated";
import { cardBeeState } from "./queenTasksCard";
import type { QueenBee, QueenTask, QueenTasksFeed } from "./queenTasks";

export interface BusEvent {
  seq: number;
  kind: number;
  at: string;
  issue: number | null;
  /** `owner/name#N`, the task the event names. */
  task: string | null;
  /** A review's verdict, as the route projects it (a plain token). */
  verdict: string | null;
}

/** An event as this page received it: `seenAt` is this page's clock, which is what a flash fades by. */
export interface SeenEvent extends BusEvent {
  seenAt: number;
}

export interface BusPage {
  cursor: number;
  resync: boolean;
  events: BusEvent[];
}

const record = (value: unknown): Record<string, unknown> | null =>
  value !== null && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
const whole = (value: unknown): number | null => (typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null);

/** The route's answer, checked field by field; null when it is not the contract. */
export function parseBusPage(raw: unknown): BusPage | null {
  const body = record(raw);
  const cursor = whole(body?.cursor);
  if (!body || cursor === null || !Array.isArray(body.events)) return null;
  const events: BusEvent[] = [];
  for (const item of body.events) {
    const row = record(item);
    const seq = whole(row?.seq), kind = whole(row?.kind);
    if (!row || seq === null || kind === null) continue;
    const issue = whole(row.issue);
    events.push({
      seq,
      kind,
      at: typeof row.at === "string" ? row.at : "",
      issue: issue !== null && issue > 0 ? issue : null,
      task: typeof row.task === "string" ? row.task : null,
      verdict: typeof row.verdict === "string" ? row.verdict : null,
    });
  }
  return { cursor, resync: body.resync === true, events };
}

export function busUrl(api: string, after: number, waitSeconds: number): string {
  return `${api}/queen/public-events?after=${after}&wait=${waitSeconds}`;
}

/** One read past `after`, waiting up to `waitSeconds` for the next event. Throws when it is not the contract. */
export async function loadBusPage(api: string, after: number, waitSeconds: number, signal?: AbortSignal): Promise<BusPage> {
  const response = await fetch(busUrl(api, after, waitSeconds), { headers: { Accept: "application/json" }, cache: "no-store", signal });
  if (!response.ok) throw Object.assign(new Error(`HTTP ${response.status}`), { status: response.status });
  const page = parseBusPage(await response.json());
  if (!page) throw new Error("not the events contract");
  return page;
}

export interface PagePlan {
  /** The cursor after this page. */
  cursor: number;
  /** The events applied from this page, in order: what the game draws. */
  applied: BusEvent[];
  /** Take a whole snapshot: a gap, a pruned cursor, or more changed tasks than one refresh carries. */
  snapshot: boolean;
  /** The repository of the tasks to read again, and their numbers. */
  repo: string | null;
  refresh: number[];
  /** Bees heard, by issue, at the event's time. */
  touched: Map<number, string>;
}

/** What one page asks of the board, decided event by event by the card. */
export function planPage(cursor: number, page: BusPage): PagePlan {
  const none: PagePlan = { cursor: page.cursor, applied: [], snapshot: true, repo: null, refresh: [], touched: new Map() };
  if (page.resync) return none;
  let at = cursor;
  let repo: string | null = null;
  const refresh = new Set<number>();
  const touched = new Map<number, string>();
  const applied: BusEvent[] = [];
  for (const event of page.events) {
    const action = cardDeltaAction(at, event.seq);
    if (action === DA_SKIP) continue;
    if (action === DA_RESYNC) return none;
    at = event.seq;
    applied.push(event);
    if (event.issue === null) continue;
    const doing = cardBoardAction(event.kind);
    if (doing === EA_REFRESH) {
      refresh.add(event.issue);
      repo ??= event.task?.split("#")[0] ?? null;
    } else if (doing === EA_TOUCH && event.at) {
      touched.set(event.issue, event.at);
    }
  }
  const snapshot = cardRefreshAction(refresh.size) === RF_SNAPSHOT;
  return { cursor: at, applied, snapshot, repo, refresh: [...refresh], touched };
}

/** A bee's state at `nowMs`, as the card says: queued stays queued; the rest is working or quiet by when it was last heard. */
function aged(bee: QueenBee, nowMs: number): QueenBee {
  if (bee.state === "queued") return bee;
  const from = Date.parse(bee.lastEventAt ?? bee.since ?? "");
  const silent = Number.isFinite(from) ? Math.max(0, (nowMs - from) / 1000) : Number.MAX_SAFE_INTEGER;
  const state = BEE_STATE_NAMES[cardBeeState(true, silent)] ?? bee.state;
  return state === bee.state ? bee : { ...bee, state };
}

/** Every bee's state recomputed for `nowMs`: a bee nobody hears from turns quiet with no event to say so. */
export function ageBees(feed: QueenTasksFeed, nowMs: number): QueenTasksFeed {
  let changed = false;
  const bees = feed.bees.map((bee) => {
    const next = aged(bee, nowMs);
    if (next !== bee) changed = true;
    return next;
  });
  return changed ? { ...feed, bees } : feed;
}

/** The bees of the touched issues, heard at the event's time; nothing else moves. */
export function touchBees(feed: QueenTasksFeed, touched: ReadonlyMap<number, string>, nowMs: number): QueenTasksFeed {
  if (touched.size === 0) return feed;
  let changed = false;
  const bees = feed.bees.map((bee) => {
    const at = bee.number !== null ? touched.get(bee.number) : undefined;
    if (at === undefined || (bee.lastEventAt !== null && Date.parse(bee.lastEventAt) >= Date.parse(at))) return bee;
    changed = true;
    return aged({ ...bee, lastEventAt: at }, nowMs);
  });
  return changed ? { ...feed, bees } : feed;
}

/**
 * The feed with the named issues of `repo` read again: their tasks (not the
 * reviews, which are pull requests that share the numbering) and their bees are
 * replaced by what `fresh` says, in place where they were, and an issue `fresh`
 * no longer has leaves.
 */
export function patchFeed(feed: QueenTasksFeed, fresh: QueenTasksFeed, repo: string, issues: readonly number[]): QueenTasksFeed {
  const named = new Set(issues);
  const covers = (task: Pick<QueenTask, "repo" | "kind" | "number">) =>
    task.repo === repo && task.kind !== "review" && task.number !== null && named.has(task.number);
  const replacement = new Map(fresh.tasks.filter(covers).map((task) => [task.key, task]));
  const tasks: QueenTask[] = [];
  for (const task of feed.tasks) {
    if (!covers(task)) tasks.push(task);
    else if (replacement.has(task.key)) {
      tasks.push(replacement.get(task.key) as QueenTask);
      replacement.delete(task.key);
    }
  }
  tasks.push(...replacement.values());
  const bees = [
    ...feed.bees.filter((bee) => !(bee.repo === repo && bee.number !== null && named.has(bee.number))),
    ...fresh.bees.filter((bee) => bee.repo === repo && bee.number !== null && named.has(bee.number)),
  ];
  return { ...feed, at: fresh.at ?? feed.at, tasks, bees };
}
