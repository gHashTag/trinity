import type { HudCard, HudEvent, FoundationIssue, EpicRecord } from './queenHud';

export interface HiveDisplay {
  key: string;
  repo: string;
  number: number;
  title: string;
  kind: 'issue' | 'epic';
  state: string;
  closedAt: string | null;
  children: EpicRecord['children'];
  /** The public issue ledger supplies no issue-to-module coverage proof. */
  coverage: 'unknown';
}
type Snapshot = { repo: string; closedIssues: FoundationIssue[]; epics: EpicRecord[] };

/** Task-goal color is separate from code provenance. No ledger adapter invents T27 proof. */
type HiveTaskSignal = { state: string; coverage: 'unknown' | 'awaiting' | 'manual' | 't27' };
export const HIVE_TASK_PALETTE = {
  problem: { hex: '#ff4d5e', rgb: '255 77 94', symbol: '○', alpha: .36 },
  blocked: { hex: '#ff334f', rgb: '255 51 79', symbol: '!', alpha: .65 },
  active: { hex: '#64dcff', rgb: '100 220 255', symbol: '→', alpha: .42 },
  review: { hex: '#bb96ff', rgb: '187 150 255', symbol: '◇', alpha: .42 },
  paused: { hex: '#8a9bac', rgb: '138 155 172', symbol: 'Ⅱ', alpha: .22 },
  honey: { hex: '#ffd45a', rgb: '255 212 90', symbol: '✓', alpha: .5 },
} as const;
export type HiveTaskTone = keyof typeof HIVE_TASK_PALETTE;
type HiveTaskPaint = { tone: HiveTaskTone; reason: 'work' | 'blocked' | 'paused' | 'proof' | 'running' | 'review' | 'verified' };

export function hiveTaskPaint(row: HiveTaskSignal | null | undefined): HiveTaskPaint | null {
  if (!row) return null;
  if (['blocked','failed','error','refused','rejected'].includes(row.state)) return { tone: 'blocked', reason: 'blocked' };
  if (['dropped','paused','cancelled'].includes(row.state)) return { tone: 'paused', reason: 'paused' };
  if (row.state === 'running') return { tone: 'active', reason: 'running' };
  if (row.state === 'review') return { tone: 'review', reason: 'review' };
  if (row.state === 'done' || row.state === 'closed') {
    return row.coverage === 't27' ? { tone: 'honey', reason: 'verified' } : { tone: 'problem', reason: 'proof' };
  }
  return { tone: 'problem', reason: 'work' };
}

export function hiveTaskCounts(rows: readonly (HiveTaskSignal | null)[]): Record<HiveTaskTone, number> {
  const counts = { problem: 0, blocked: 0, active: 0, review: 0, paused: 0, honey: 0 };
  for (const row of rows) { const paint = hiveTaskPaint(row); if (paint) counts[paint.tone]++; }
  return counts;
}

export type HiveFeedHealth = 'live' | 'stale' | 'unknown';
export type HiveSignalHealth = { board: HiveFeedHealth; activity: HiveFeedHealth };
export function hiveFeedHealth(loaded: boolean, error: string | null): HiveFeedHealth {
  return !loaded ? 'unknown' : error ? 'stale' : 'live';
}
export function hiveRunningIssueNumbers(rows: readonly {number:number;state:string}[], boardLive: boolean): number[] {
  return boardLive ? rows.filter(row=>row.state === 'running').map(row=>row.number) : [];
}

const EVENT_SIGNALS = {
  blocked: { tone:'blocked', hex:'#ff334f', symbol:'!', priority:5 },
  accepted: { tone:'accepted', hex:'#00ff88', symbol:'✓', priority:4 },
  review: { tone:'review', hex:'#bb96ff', symbol:'◇', priority:3 },
  result: { tone:'result', hex:'#e7f4ff', symbol:'↓', priority:2 },
  active: { tone:'active', hex:'#64dcff', symbol:'→', priority:1 },
} as const;
export function hiveEventSignal(event: Pick<HudEvent,'kind'|'state'>) {
  const state = event.state?.toLowerCase() ?? '';
  if (event.kind === 'error' || ['refused','rejected','failed','error','blocked'].includes(state)) return EVENT_SIGNALS.blocked;
  if (event.kind === 'review') return ['accepted','approved','pass','passed'].includes(state) ? EVENT_SIGNALS.accepted : EVENT_SIGNALS.review;
  return event.kind === 'result' || event.kind === 'finished' ? EVENT_SIGNALS.result : EVENT_SIGNALS.active;
}

/** Fresh ring candidates; archive/tool chatter stays in the timestamped list. */
export function hiveFreshSignals(events: readonly HudEvent[], now: number, limit=24): HudEvent[] {
  const latest = new Map<number,HudEvent>();
  for (const event of events) {
    const age = now-Date.parse(event.at);
    if (event.issue === null || !Number.isSafeInteger(event.issue) || event.issue < 1 || !Number.isFinite(age) || age < 0 || age > 15_000 || event.kind === 'tool' || event.kind === 'usage') continue;
    const previous = latest.get(event.issue);
    if (!previous || Date.parse(event.at)>Date.parse(previous.at) || (Date.parse(event.at)===Date.parse(previous.at) && hiveEventSignal(event).priority>hiveEventSignal(previous).priority)) latest.set(event.issue,event);
  }
  return [...latest.values()].sort((a,b)=>hiveEventSignal(b).priority-hiveEventSignal(a).priority || Date.parse(b.at)-Date.parse(a.at)).slice(0,limit);
}

export type HiveSignalCursor = {ready:boolean;seen:ReadonlySet<string>};
export function hiveSignalDelivery(events: readonly HudEvent[], now: number, health: HiveFeedHealth, cursor: HiveSignalCursor, identity: (event: HudEvent)=>string) {
  // Select newest across the whole snapshot BEFORE seen filtering: a late old
  // failure cannot supersede the newer (already seen) result for that issue.
  const fresh = health==='live' && cursor.ready ? hiveFreshSignals(events,now,Infinity).filter(e=>!cursor.seen.has(identity(e))).slice(0,24) : [];
  const seen = new Set(cursor.seen.size>2000 ? [] : cursor.seen);
  for(const event of events) seen.add(identity(event));
  return {events:fresh,cursor:{ready:health==='live',seen}};
}

export type HiveEventRing = {signalColor:string;sourceAt:number;priority:number;start:number};
export function hiveSignalRing(current: HiveEventRing | null, event: HudEvent, stamp: number): HiveEventRing {
  const signal=hiveEventSignal(event); const sourceAt=Date.parse(event.at);
  if(current && (sourceAt<current.sourceAt || (sourceAt===current.sourceAt && signal.priority<=current.priority))) return current;
  return {signalColor:signal.hex,sourceAt,priority:signal.priority,start:current?.start ?? stamp};
}

/** Include state/provenance in GPU invalidation, not just stable issue identity. */
export function hiveDisplayPaintKey(rows?: readonly ((HiveTaskSignal & { key: string }) | null)[]): string {
  return JSON.stringify(rows?.map(row => row ? [row.key, row.state, row.coverage] : null) ?? null);
}

export function hiveSameRepositorySnapshot<T extends { repo: string }>(repo: string | null, snapshot: T | null): T | null {
  return repo && hiveIssueUrl(repo, 1) && typeof snapshot?.repo === 'string' && snapshot.repo.toLowerCase() === repo.toLowerCase() ? snapshot : null;
}

export function hiveIssueUrl(repo: string, number: number): string | null {
  return /^[a-z0-9-]+\/[a-z0-9_.-]+$/i.test(repo) && Number.isSafeInteger(number) && number > 0
    ? `https://github.com/${repo}/issues/${number}` : null;
}

/** Only a same-repository ledger may enrich a board issue. No module/title joins. */
export function hiveDisplayRecords(repo: string | null, board: readonly HudCard[], snapshot: Snapshot | null): HiveDisplay[] {
  if (!repo || !hiveIssueUrl(repo, 1)) return [];
  const records = new Map<number, HiveDisplay>();
  const row = (number: number, title: string, state: string, closedAt: string | null): HiveDisplay => ({ key: `${repo}#${number}`, repo, number, title, kind: 'issue', state, closedAt, children: [], coverage: 'unknown' });
  snapshot = hiveSameRepositorySnapshot(repo, snapshot);
  if (snapshot) {
    for (const issue of snapshot.closedIssues) if (hiveIssueUrl(repo, issue.number)) records.set(issue.number, row(issue.number, issue.title, 'closed', issue.closedAt));
    for (const epic of snapshot.epics) if (hiveIssueUrl(repo, epic.number)) records.set(epic.number, { ...row(epic.number, epic.title, epic.state, epic.closedAt), kind: 'epic', children: epic.children });
  }
  for (const card of board) {
    if (!hiveIssueUrl(repo, card.number)) continue;
    const old = records.get(card.number);
    records.set(card.number, { ...(old ?? row(card.number, card.title, card.column, null)), title: card.title, state: card.column, closedAt: card.column === 'done' ? old?.closedAt ?? null : null });
  }
  return [...records.values()].sort((a, b) => a.number - b.number);
}

/** Cells are leased by canonical issue identity; a refresh cannot move its neighbours. */
export function placeHiveDisplays(previous: ReadonlyMap<string, number>, rows: readonly HiveDisplay[], count: number) {
  const placed: (HiveDisplay | null)[] = Array.from({ length: count }, () => null);
  const ledger = new Map<string, number>();
  for (const row of rows) {
    const index = previous.get(row.key);
    if (index !== undefined && index > 0 && index < count && !placed[index]) { placed[index] = row; ledger.set(row.key, index); }
  }
  let free = 1;
  for (const row of rows) {
    if (ledger.has(row.key)) continue;
    while (free < count && placed[free]) free++;
    if (free >= count) break;
    placed[free] = row; ledger.set(row.key, free++);
  }
  return { placed, ledger };
}

export function hiveDisplayEvents(row: HiveDisplay, events: readonly HudEvent[], limit = 3): HudEvent[] {
  const numbers = new Set([row.number, ...row.children.map(c => c.number)]);
  const unique = new Map<string, HudEvent>();
  for (const event of events) if (event.issue !== null && numbers.has(event.issue) && Number.isFinite(Date.parse(event.at))) unique.set(`${event.issue}:${event.id}`, event);
  // Stable sort preserves the feed's meaningful wire order for same-second events.
  return [...unique.values()].sort((a,b) => Date.parse(b.at)-Date.parse(a.at)).slice(0, limit);
}

export function hiveEpicProgress(row: HiveDisplay, rows: readonly HiveDisplay[]) {
  const state = new Map(rows.filter(r=>r.repo.toLowerCase()===row.repo.toLowerCase()).map(r => [r.number, r.state]));
  const children = [...new Map(row.children.map(c => [c.number, c])).values()];
  return { done: children.filter(c => ['done','closed'].includes(state.get(c.number) ?? c.state)).length, total: children.length };
}

export function hiveDisplayLod(width: number): 'overview' | 'badge' | 'title' | 'detail' {
  return width < 64 ? 'overview' : width < 140 ? 'badge' : width < 260 ? 'title' : 'detail';
}

export function hiveFocusZoom(baseCellWidth: number, viewportWidth: number, viewportHeight: number): number {
  if (!(baseCellWidth > 0)) return 1;
  const target = Math.max(64, Math.min(520, viewportWidth * .84, viewportHeight * .74));
  return Math.min(128, Math.max(.5, target / baseCellWidth));
}

export interface HiveDisplayProjection { index: number; x: number; y: number; width: number; height: number }
