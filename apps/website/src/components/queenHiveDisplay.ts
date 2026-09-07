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
  const state = new Map(rows.map(r => [r.number, r.state]));
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
