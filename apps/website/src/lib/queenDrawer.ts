// One task, opened: what GET /queen/public-task answers (gHashTag/t27
// specs/queen/dashboard.t27 section 2; the supervisor decides what is public,
// and this file only checks the answer is the contract before the drawer shows
// it). A server that does not answer the route yet is said, not hidden.

export interface DrawerEvent {
  seq: number;
  kind: number;
  name: string;
  at: string;
  verdict: string | null;
  outcome: string | null;
}

export interface TaskDrawerData {
  key: string;
  timeline: DrawerEvent[];
  lease: { state: "none" | "live" | "expired"; fence: number; expiresAt: string } | null;
  attempts: {
    reviewState: string | null;
    outcome: string | null;
    dispatchedAt: string | null;
    finishedAt: string | null;
    sendBacks: number;
    freeAttempts: number;
    ceilingReleases: number;
    reviewerMisses: number;
  } | null;
  effects: Array<{ step: number | null; kind: number; state: number; runs: number; updatedAt: string | null }>;
}

const record = (value: unknown): Record<string, unknown> | null =>
  value !== null && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
const text = (value: unknown): string | null => (typeof value === "string" ? value : null);
const whole = (value: unknown): number => (typeof value === "number" && Number.isFinite(value) ? value : 0);

export function parseDrawer(raw: unknown): TaskDrawerData | null {
  const body = record(raw);
  if (!body || typeof body.key !== "string" || !Array.isArray(body.timeline)) return null;
  const lease = record(body.lease);
  const attempts = record(body.attempts);
  const leaseState = text(lease?.state);
  return {
    key: body.key,
    timeline: body.timeline.flatMap((item) => {
      const row = record(item);
      if (!row || typeof row.seq !== "number" || typeof row.kind !== "number") return [];
      return [{ seq: row.seq, kind: row.kind, name: text(row.name) ?? "", at: text(row.at) ?? "", verdict: text(row.verdict), outcome: text(row.outcome) }];
    }),
    lease:
      lease && (leaseState === "none" || leaseState === "live" || leaseState === "expired")
        ? { state: leaseState, fence: whole(lease.fence), expiresAt: text(lease.expiresAt) ?? "" }
        : null,
    attempts: attempts
      ? {
          reviewState: text(attempts.reviewState),
          outcome: text(attempts.outcome),
          dispatchedAt: text(attempts.dispatchedAt),
          finishedAt: text(attempts.finishedAt),
          sendBacks: whole(attempts.sendBacks),
          freeAttempts: whole(attempts.freeAttempts),
          ceilingReleases: whole(attempts.ceilingReleases),
          reviewerMisses: whole(attempts.reviewerMisses),
        }
      : null,
    effects: Array.isArray(body.effects)
      ? body.effects.flatMap((item) => {
          const row = record(item);
          return row ? [{ step: typeof row.step === "number" ? row.step : null, kind: whole(row.kind), state: whole(row.state), runs: whole(row.runs), updatedAt: text(row.updatedAt) }] : [];
        })
      : [],
  };
}

/** The route's address for a task key: `owner/name#N` is an issue, `job:N` a job; a review has no drawer. */
export function drawerUrl(api: string, key: string): string | null {
  const job = /^job:([1-9]\d{0,9})$/.exec(key);
  if (job) return `${api}/queen/public-task?job=${job[1]}`;
  const issue = /^[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+#([1-9]\d{0,9})$/.exec(key);
  return issue ? `${api}/queen/public-task?issue=${issue[1]}` : null;
}

export type DrawerLoad = { kind: "ready"; data: TaskDrawerData } | { kind: "missing" } | { kind: "error"; message: string };

export async function loadDrawer(api: string, key: string, signal?: AbortSignal): Promise<DrawerLoad> {
  const url = drawerUrl(api, key);
  if (!url) return { kind: "missing" };
  const response = await fetch(url, { headers: { Accept: "application/json" }, cache: "no-store", signal });
  if (response.status === 404) return { kind: "missing" };
  if (!response.ok) return { kind: "error", message: `HTTP ${response.status}` };
  const data = parseDrawer(await response.json());
  return data ? { kind: "ready", data } : { kind: "error", message: "not the drawer contract" };
}
