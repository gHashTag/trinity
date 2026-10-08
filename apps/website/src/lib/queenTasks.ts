// One task, three kinds, and the bees working on them -- read the way the board
// and the game read them.
//
// THE SOURCE IS A SPEC, NOT THIS FILE
//
// gHashTag/t27 specs/queen/tasks.t27 (epic gHashTag/t27#7718, slice 1) defines
// the view: the kinds, the seven states, what a bee is, and the filter that the
// supervisor's route, the board and the game all apply. The supervisor serves it
// at GET /queen/public-tasks. The constants and `taskMatches` below MIRROR that
// spec; qa/queen-tasks-contract.mjs runs the spec's own test vectors against
// them, so the day the two disagree the gate is red rather than the board.
//
// WHY THERE IS A FALLBACK, AND WHY IT SAYS SO
//
// The route is new. When it does not answer (404 while it deploys, a network
// failure, a body that is not the contract), the page already holds the public
// board and the activity feed it polls anyway, and `tasksFromBoard` builds the
// same shape from those: every card an issue in its column, and one bee per
// running card. That bee is DERIVED -- the board names no bee -- so the feed
// carries `source: "board"` and the screen says which of the two it is drawing.
// A fallback indistinguishable from the real answer would be a claim.
//
// Nothing in this module fetches on import or reads the build environment: the
// gate imports it under plain node.

/** KIND_NAMES; the index is the spec's (TK_ISSUE 0, TK_REVIEW 1, TK_JOB 2). */
export const TASK_KINDS = ["issue", "review", "job"] as const;
/** STATE_NAMES; TS_BACKLOG 0 .. TS_FAILED 6. An issue's board column IS its state. */
export const TASK_STATES = ["backlog", "blocked", "running", "review", "done", "dropped", "failed"] as const;
/** BEE_STATE_NAMES: offered and not claimed, heard recently, silent longer. */
export const BEE_STATES = ["queued", "working", "quiet"] as const;
/** BEE_QUIET_SECONDS: a bee heard within this many seconds is working. */
export const BEE_QUIET_SECONDS = 180;
/** TASK_PAGE_MAX: the most tasks one answer carries. */
export const TASK_PAGE_MAX = 2000;

export type TaskKind = (typeof TASK_KINDS)[number];
export type TaskState = (typeof TASK_STATES)[number];
export type BeeState = (typeof BEE_STATES)[number];

/**
 * task_matches, line for line: an index out of range matches nothing, even with
 * no filter; a mask of 0 means "any"; otherwise the index's bit must be set.
 * The spec's indices are u8, so a negative or fractional index (what indexOf
 * returns for a name this build has not met) is out of range here as well.
 */
export function taskMatches(kindMask: number, stateMask: number, kind: number, state: number): boolean {
  if (!Number.isInteger(kind) || !Number.isInteger(state)) return false;
  if (kind < 0 || state < 0 || kind >= TASK_KINDS.length || state >= TASK_STATES.length) return false;
  if (kindMask !== 0 && (kindMask & (1 << kind)) === 0) return false;
  if (stateMask !== 0 && (stateMask & (1 << state)) === 0) return false;
  return true;
}

export function kindIndex(kind: string): number {
  return (TASK_KINDS as readonly string[]).indexOf(kind);
}

export function stateIndex(state: string): number {
  return (TASK_STATES as readonly string[]).indexOf(state);
}

/** The mask of the named members of `order`; a name that is not a member adds nothing. */
export function maskOf(names: readonly string[], order: readonly string[]): number {
  let mask = 0;
  for (const name of names) {
    const at = order.indexOf(name);
    if (at >= 0) mask |= 1 << at;
  }
  return mask;
}

export interface QueenTask {
  /** `owner/name#N` for an issue; a review or a job has its own key shape. */
  key: string;
  kind: TaskKind;
  repo: string;
  number: number | null;
  title: string;
  state: TaskState;
  criteria: number | null;
  needs: string[];
  verdict: string | null;
  url: string | null;
  /** The bee on it, by id, or null. */
  bee: string | null;
  updatedAt: string | null;
}

export interface QueenBee {
  id: string;
  /** An anonymous lane: the same lane is the same bee. Null when unknown. */
  lane: number | null;
  kind: string;
  /** The key of the task it works on. */
  task: string;
  repo: string;
  number: number | null;
  state: BeeState;
  since: string | null;
  lastEventAt: string | null;
}

export interface QueenTasksFeed {
  at: string | null;
  /** "tasks": the route answered. "board": derived here from the public board. */
  source: "tasks" | "board";
  tasks: QueenTask[];
  bees: QueenBee[];
  /** The route stopped at its page limit, so the tasks are not all of them. */
  truncated: boolean;
}

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}
const text = (value: unknown): string | null => (typeof value === "string" ? value : null);
const count = (value: unknown): number | null => (typeof value === "number" && Number.isSafeInteger(value) ? value : null);

/** A GitHub address, and nothing else: the board links every card it draws. */
function githubUrl(value: unknown): string | null {
  const url = text(value);
  return url && /^https:\/\/github\.com\/[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\/(issues|pull)\/[1-9]\d*$/.test(url) ? url : null;
}

/**
 * The route's answer, checked field by field. A row with a kind or state this
 * build has not met is dropped: the spec says it matches nothing, so no filter
 * would ever show it. Anything that is not the contract at all returns null,
 * which is the caller's cue to fall back.
 */
export function parseTasksFeed(raw: unknown): QueenTasksFeed | null {
  const body = record(raw);
  if (!body || !Array.isArray(body.tasks) || !Array.isArray(body.bees)) return null;
  const tasks: QueenTask[] = [];
  for (const item of body.tasks) {
    const row = record(item);
    if (!row) continue;
    const key = text(row.key), kind = text(row.kind), state = text(row.state), repo = text(row.repo);
    if (!key || !repo || kind === null || state === null || kindIndex(kind) < 0 || stateIndex(state) < 0) continue;
    const number = count(row.number);
    tasks.push({
      key,
      kind: kind as TaskKind,
      repo,
      number: number !== null && number > 0 ? number : null,
      title: text(row.title) ?? "",
      state: state as TaskState,
      criteria: count(row.criteria),
      needs: Array.isArray(row.needs) ? row.needs.filter((need): need is string => typeof need === "string") : [],
      verdict: text(row.verdict),
      url: githubUrl(row.url),
      bee: text(row.bee),
      updatedAt: text(row.updatedAt),
    });
  }
  const bees: QueenBee[] = [];
  for (const item of body.bees) {
    const row = record(item);
    if (!row) continue;
    const id = text(row.id), task = text(row.task), state = text(row.state);
    if (!id || !task || !state || !(BEE_STATES as readonly string[]).includes(state)) continue;
    const number = count(row.number);
    bees.push({
      id,
      lane: count(row.lane),
      kind: text(row.kind) ?? "worker",
      task,
      repo: text(row.repo) ?? "",
      number: number !== null && number > 0 ? number : null,
      state: state as BeeState,
      since: text(row.since),
      lastEventAt: text(row.lastEventAt),
    });
  }
  return { at: text(body.at), source: "tasks", tasks, bees, truncated: body.truncated === true };
}

/**
 * The next answer, with each bee's `since` no later than the earliest the page
 * has been told for that same bee. Measured 2026-10-08: the route re-stamps
 * `since` on every answer (b7510 answered "quiet" with a `since` four minutes
 * after its `lastEventAt`), so read alone every bee would always be "12 s" old.
 * Keeping the earliest moment stated for a bee that is still in flight makes
 * the age grow while the page is open; it never claims an earlier start than
 * the route itself once stated. A bee that leaves the answer is forgotten.
 */
export function withEarliestSince(previous: QueenTasksFeed | null, next: QueenTasksFeed): QueenTasksFeed {
  if (!previous) return next;
  const earliest = new Map<string, number>();
  for (const bee of previous.bees) {
    const at = bee.since ? Date.parse(bee.since) : NaN;
    if (Number.isFinite(at)) earliest.set(bee.id, at);
  }
  let changed = false;
  const bees = next.bees.map((bee) => {
    const before = earliest.get(bee.id);
    const now = bee.since ? Date.parse(bee.since) : NaN;
    if (before === undefined || (Number.isFinite(now) && now <= before)) return bee;
    changed = true;
    return { ...bee, since: new Date(before).toISOString() };
  });
  return changed ? { ...next, bees } : next;
}

/** The two answers the page asks for: every task, or only the running ones (the bees come with either). */
export type TasksScope = "all" | "running";

export function tasksUrl(api: string, scope: TasksScope): string {
  return scope === "all"
    ? `${api}/queen/public-tasks?limit=${TASK_PAGE_MAX}`
    : `${api}/queen/public-tasks?state=running&limit=${TASK_PAGE_MAX}`;
}

/** One read of the route. Throws on anything that is not the contract, so the caller can fall back. */
export async function loadTasksFeed(api: string, scope: TasksScope, signal?: AbortSignal): Promise<QueenTasksFeed> {
  const response = await fetch(tasksUrl(api, scope), { headers: { Accept: "application/json" }, cache: "no-store", signal });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const feed = parseTasksFeed(await response.json());
  if (!feed) throw new Error("not the tasks contract");
  return feed;
}

// ---- the fallback: the same shape, from the board the page already holds ----

export interface BoardCardLike {
  number: number;
  title: string;
  column: string;
  criteria?: number;
  needs?: string[];
  verdict?: string;
}

export interface ActivityLike {
  issue: number | null;
  at: string;
}

/**
 * When each running issue was first seen running by THIS page: kept for the
 * numbers still running, added for the new ones at `nowIso`, dropped for the
 * rest. The board carries no start time, so "since" can only ever be "since we
 * saw it", and the label says no more than that.
 */
export function observeRunning(previous: ReadonlyMap<number, string>, running: readonly number[], nowIso: string): Map<number, string> {
  const next = new Map<number, string>();
  for (const number of running) next.set(number, previous.get(number) ?? nowIso);
  return next;
}

/**
 * The tasks feed, derived from `GET /queen/public-board` and the activity feed:
 * every card an issue whose state is its column, and one bee per running card,
 * `b<number>`, with no lane (the board has none). The bee is working when the
 * activity feed holds an event for its issue within BEE_QUIET_SECONDS of `nowMs`,
 * and quiet otherwise -- the spec's bee_state with "claimed" true, because a
 * card in RUNNING has been taken.
 */
export function tasksFromBoard(
  repo: string,
  cards: readonly BoardCardLike[],
  events: readonly ActivityLike[],
  firstSeen: ReadonlyMap<number, string>,
  nowMs: number,
): QueenTasksFeed {
  const lastHeard = new Map<number, number>();
  for (const event of events) {
    if (event.issue === null) continue;
    const at = Date.parse(event.at);
    if (Number.isFinite(at) && at > (lastHeard.get(event.issue) ?? -Infinity)) lastHeard.set(event.issue, at);
  }
  const tasks: QueenTask[] = [];
  const bees: QueenBee[] = [];
  for (const card of cards) {
    if (!Number.isSafeInteger(card.number) || card.number < 1 || stateIndex(card.column) < 0) continue;
    const key = `${repo}#${card.number}`;
    const running = card.column === "running";
    const id = `b${card.number}`;
    tasks.push({
      key,
      kind: "issue",
      repo,
      number: card.number,
      title: card.title,
      state: card.column as TaskState,
      criteria: typeof card.criteria === "number" ? card.criteria : null,
      needs: card.needs ?? [],
      verdict: card.verdict ?? null,
      url: githubUrl(`https://github.com/${repo}/issues/${card.number}`),
      bee: running ? id : null,
      updatedAt: null,
    });
    if (!running) continue;
    const heard = lastHeard.get(card.number);
    const quiet = heard === undefined || (nowMs - heard) / 1000 > BEE_QUIET_SECONDS;
    bees.push({
      id,
      lane: null,
      kind: "worker",
      task: key,
      repo,
      number: card.number,
      state: quiet ? "quiet" : "working",
      since: firstSeen.get(card.number) ?? null,
      lastEventAt: heard === undefined ? null : new Date(heard).toISOString(),
    });
  }
  return { at: new Date(nowMs).toISOString(), source: "board", tasks, bees, truncated: false };
}

// ---- the filter, as the board's address carries it ----

/**
 * What the reader narrowed the board to. Empty lists mean "any", as a mask of
 * 0 does in the spec. Repository and text are matched beside the masks; the
 * spec leaves string equality to the caller, and here it ignores case, because
 * the atlas spells `ghashtag/t27` and the board `gHashTag/t27`.
 */
export interface TaskFilter {
  kinds: TaskKind[];
  states: TaskState[];
  repos: string[];
  q: string;
}

export const EMPTY_TASK_FILTER: TaskFilter = { kinds: [], states: [], repos: [], q: "" };

/**
 * The address keys. Plural, and not the route's own `kind`/`state`/`repo`,
 * because the universe around the board already reads `repo` (it opens that
 * repository's world) and `task` (it focuses an issue cell): a filter written
 * under those names would move the map instead of narrowing the board.
 */
export const TASK_FILTER_KEYS = ["kinds", "states", "repos", "q"] as const;

const REPO = /^[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+$/;
const list = (value: string | null): string[] => (value ? value.split(",").map((part) => part.trim()).filter(Boolean) : []);
const unique = <T>(values: T[]): T[] => [...new Set(values)];

/** The filter an address asks for. Unknown kinds, states and malformed repositories are ignored, not guessed at. */
export function taskFilterFromParams(params: URLSearchParams): TaskFilter {
  return {
    kinds: unique(list(params.get("kinds")).filter((kind): kind is TaskKind => kindIndex(kind) >= 0)),
    states: unique(list(params.get("states")).filter((state): state is TaskState => stateIndex(state) >= 0)),
    repos: unique(list(params.get("repos")).filter((repo) => REPO.test(repo))),
    q: (params.get("q") ?? "").slice(0, 200),
  };
}

/** Writes the filter into `params`, in the spec's order, and removes the keys it does not need. */
export function writeTaskFilter(params: URLSearchParams, filter: TaskFilter): URLSearchParams {
  const kinds = TASK_KINDS.filter((kind) => filter.kinds.includes(kind));
  const states = TASK_STATES.filter((state) => filter.states.includes(state));
  const q = filter.q.trim();
  const set = (key: string, value: string) => (value ? params.set(key, value) : params.delete(key));
  set("kinds", kinds.join(","));
  set("states", states.join(","));
  set("repos", unique(filter.repos.filter((repo) => REPO.test(repo))).join(","));
  set("q", q);
  return params;
}

/** A filter that leaves the board alone. */
export function taskFilterIsEmpty(filter: TaskFilter): boolean {
  return filter.kinds.length === 0 && filter.states.length === 0 && filter.repos.length === 0 && filter.q.trim() === "";
}

/** One string per filter, for telling an address the reader wrote from one this page wrote. */
export function taskFilterKey(filter: TaskFilter): string {
  return writeTaskFilter(new URLSearchParams(), filter).toString();
}

/**
 * Text against a task: `#7513` or `7513` is the number, anything else is a
 * piece of the title, both ignoring case. The number is matched exactly, so
 * "75" does not find #7513 by its digits -- it finds titles that say 75.
 */
export function taskTextMatches(task: Pick<QueenTask, "number" | "title" | "key">, q: string): boolean {
  const needle = q.trim().toLowerCase();
  if (!needle) return true;
  const number = /^#?([1-9]\d*)$/.exec(needle);
  if (number && task.number === Number(number[1])) return true;
  return task.title.toLowerCase().includes(needle) || task.key.toLowerCase() === needle;
}

/** The tasks the filter keeps, in the order they arrived. A filter can only hide. */
export function filterTasks<T extends Pick<QueenTask, "kind" | "state" | "repo" | "number" | "title" | "key">>(
  tasks: readonly T[],
  filter: TaskFilter,
): T[] {
  const kindMask = maskOf(filter.kinds, TASK_KINDS);
  const stateMask = maskOf(filter.states, TASK_STATES);
  const repos = new Set(filter.repos.map((repo) => repo.toLowerCase()));
  return tasks.filter(
    (task) =>
      taskMatches(kindMask, stateMask, kindIndex(task.kind), stateIndex(task.state)) &&
      (repos.size === 0 || repos.has(task.repo.toLowerCase())) &&
      taskTextMatches(task, filter.q),
  );
}

// ---- words ----

const BEE_WORDS = {
  en: { queued: "queued", working: "working", quiet: "quiet", min: "min", s: "s", h: "h", lane: "lane", heard: "heard", never: "not heard yet" },
  ru: { queued: "в очереди", working: "работает", quiet: "молчит", min: "мин", s: "с", h: "ч", lane: "линия", heard: "слышно", never: "ещё не слышно" },
} as const;

/** How long since `iso`, in the largest unit that says it, or null when there is no moment to count from. */
export function ageWords(iso: string | null, nowMs: number, lang: "en" | "ru"): string | null {
  if (!iso) return null;
  const at = Date.parse(iso);
  if (!Number.isFinite(at)) return null;
  const seconds = Math.max(0, Math.round((nowMs - at) / 1000));
  const w = BEE_WORDS[lang];
  if (seconds < 60) return `${seconds} ${w.s}`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} ${w.min}`;
  return `${Math.floor(seconds / 3600)} ${w.h} ${Math.floor((seconds % 3600) / 60)} ${w.min}`;
}

export function beeStateWord(state: BeeState, lang: "en" | "ru"): string {
  return BEE_WORDS[lang][state];
}

/** The game's label over a bee: "#7513 · working · 12 min". */
export function beeLabel(bee: Pick<QueenBee, "number" | "state" | "since">, nowMs: number, lang: "en" | "ru"): string {
  const age = ageWords(bee.since, nowMs, lang);
  return [bee.number !== null ? `#${bee.number}` : null, beeStateWord(bee.state, lang), age].filter(Boolean).join(" · ");
}

/**
 * The board's badge on a running card: its state, how long, when it was last
 * heard, and its lane -- in that order, because a card is narrow and the end of
 * the line is the part that gets cut.
 */
export function beeBadge(bee: QueenBee, nowMs: number, lang: "en" | "ru"): string {
  const w = BEE_WORDS[lang];
  const heard = ageWords(bee.lastEventAt, nowMs, lang);
  return [
    beeStateWord(bee.state, lang),
    ageWords(bee.since, nowMs, lang),
    heard ? `${w.heard} ${heard}` : w.never,
    bee.lane !== null ? `${w.lane} ${bee.lane}` : null,
  ]
    .filter(Boolean)
    .join(" · ");
}
