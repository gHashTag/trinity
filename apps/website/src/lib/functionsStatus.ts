// Live status of the Inngest functions -- read, never invented.
//
// The bot exposes a public read-only endpoint (design: inngest-spec-first §3
// item 8) that summarises what Inngest saw for each function: runs in the last
// 24 h and 7 d, the last run, the last error. This module fetches it, keeps the
// shape honest (anything the endpoint did not send is null, not zero), and
// says so when the source is not reachable: 404, CORS, a network failure or a
// body that is not the expected shape all end in `offline`, and the page draws
// an explicit "status source offline" state. Nothing here falls back to
// remembered numbers; the polling interval is a minute.

export const DEFAULT_STATUS_URL = 'https://999-multibots-telegraf-production-2008.up.railway.app/api/inngest/functions/status'
export const STATUS_POLL_MS = 60_000

export function functionsStatusUrl(): string {
  const raw = (import.meta.env?.VITE_INNGEST_STATUS_URL as string | undefined) ?? ''
  const url = raw.trim()
  return url.length > 0 ? url : DEFAULT_STATUS_URL
}

export interface RunCounts {
  completed: number | null
  failed: number | null
  running: number | null
}

export interface LastRun {
  id: string | null
  status: string | null
  endedAt: string | null
}

/**
 * Newest run that WAS invoked by hand (probe suite, dashboard Invoke), with the manifest
 * expectation beside it. `asExpected` is judged from the run status only; null when the
 * manifest says `skip` or the run has not ended. Never a health signal.
 */
export interface LastProbe extends LastRun {
  expect: string | null
  asExpected: boolean | null
}

export interface FunctionStatus {
  id: string
  slug: string | null
  triggers: string[]
  runs24h: RunCounts
  runs7d: RunCounts
  /** Per-day counts for the last seven days, oldest first, when the endpoint sends them; null otherwise. */
  daily7d: { day: string; completed: number | null; failed: number | null }[] | null
  /** Newest run NOT invoked by hand (event or cron traffic) - the health dot. */
  lastRun: LastRun | null
  lastProbe: LastProbe | null
  /** `probe_expect` from the bot manifest: COMPLETED | FAILED-at-guard | skip. */
  probeExpect: string | null
  lastError: string | null
}

export interface FunctionsStatus {
  generatedAt: string | null
  app: { name: string | null; sdk: string | null; url: string | null; connected: boolean | null }
  functions: FunctionStatus[]
  /** Which function ids the endpoint reported, for a quick join. */
  byId: Map<string, FunctionStatus>
}

export type StatusState =
  | { kind: 'loading' }
  | { kind: 'ok'; status: FunctionsStatus; fetchedAt: string; url: string }
  | { kind: 'offline'; reason: string; fetchedAt: string; url: string }

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null)
const str = (v: unknown): string | null => (typeof v === 'string' && v.length > 0 ? v : null)
const rec = (v: unknown): Record<string, unknown> | null => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : null)

function counts(v: unknown): RunCounts {
  const r = rec(v)
  return { completed: num(r?.completed), failed: num(r?.failed), running: num(r?.running) }
}

/** Parse the endpoint body. Returns null when it is not the documented shape. */
export function parseFunctionsStatus(body: unknown): FunctionsStatus | null {
  const root = rec(body)
  if (!root || !Array.isArray(root.functions)) return null
  const app = rec(root.app)
  const functions: FunctionStatus[] = []
  for (const raw of root.functions) {
    const f = rec(raw)
    const id = str(f?.id)
    if (!f || !id) continue
    const last = rec(f.lastRun)
    const probe = rec(f.lastProbe)
    const daily = Array.isArray(f.daily7d)
      ? f.daily7d
          .map((d) => rec(d))
          .filter((d): d is Record<string, unknown> => d !== null && typeof d.day === 'string')
          .map((d) => ({ day: d.day as string, completed: num(d.completed), failed: num(d.failed) }))
      : null
    functions.push({
      id,
      slug: str(f.slug),
      triggers: Array.isArray(f.triggers) ? f.triggers.filter((t): t is string => typeof t === 'string') : [],
      runs24h: counts(f.runs24h),
      runs7d: counts(f.runs7d),
      daily7d: daily,
      lastRun: last ? { id: str(last.id), status: str(last.status), endedAt: str(last.endedAt) } : null,
      lastProbe: probe
        ? {
            id: str(probe.id),
            status: str(probe.status),
            endedAt: str(probe.endedAt),
            expect: str(probe.expect),
            asExpected: typeof probe.asExpected === 'boolean' ? probe.asExpected : null,
          }
        : null,
      probeExpect: str(f.probeExpect),
      lastError: str(f.lastError),
    })
  }
  return {
    generatedAt: str(root.generatedAt),
    app: { name: str(app?.name), sdk: str(app?.sdk), url: str(app?.url), connected: typeof app?.connected === 'boolean' ? app.connected : null },
    functions,
    byId: new Map(functions.map((f) => [f.id, f])),
  }
}

/** One fetch. Every failure mode becomes `offline` with the reason spelled out. */
export async function fetchFunctionsStatus(url = functionsStatusUrl(), timeoutMs = 8000): Promise<StatusState> {
  const fetchedAt = new Date().toISOString()
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    const r = await fetch(url, { credentials: 'omit', signal: ctrl.signal, headers: { accept: 'application/json' } })
    if (!r.ok) return { kind: 'offline', reason: `HTTP ${r.status}`, fetchedAt, url }
    const body: unknown = await r.json().catch(() => null)
    const status = parseFunctionsStatus(body)
    if (!status) return { kind: 'offline', reason: 'unexpected body shape', fetchedAt, url }
    return { kind: 'ok', status, fetchedAt, url }
  } catch (e) {
    const name = e instanceof Error ? e.name : ''
    // A CORS refusal and a DNS failure both surface as a TypeError from fetch;
    // the browser hides which. Say "unreachable", not a guess.
    const reason = name === 'AbortError' ? `no answer in ${Math.round(timeoutMs / 1000)} s` : 'unreachable (network or CORS)'
    return { kind: 'offline', reason, fetchedAt, url }
  } finally {
    clearTimeout(timer)
  }
}

/** Sum the run counts over the functions the endpoint reported; null when none carried a number. */
export function totalRuns(status: FunctionsStatus, window: 'runs24h' | 'runs7d'): RunCounts {
  let completed: number | null = null
  let failed: number | null = null
  let running: number | null = null
  for (const f of status.functions) {
    const c = f[window]
    if (c.completed !== null) completed = (completed ?? 0) + c.completed
    if (c.failed !== null) failed = (failed ?? 0) + c.failed
    if (c.running !== null) running = (running ?? 0) + c.running
  }
  return { completed, failed, running }
}
