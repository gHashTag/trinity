// Live status of the Inngest functions -- read, never invented.
//
// The bot exposes a public read-only endpoint (design: inngest-spec-first §3
// item 8) that summarises what Inngest saw for each function: run counters over
// 24 h and 7 d, the last organic run, the last probe, the last error. This
// module fetches it, keeps the shape honest (anything the endpoint did not send
// is null, not zero), and says so when the source is not reachable: 404, CORS,
// a network failure or a body that is not the expected shape all end in
// `offline`, and the page draws an explicit "status source offline" state.
// Nothing here falls back to remembered numbers; the polling interval is a
// minute.
//
// WIRE CONTRACT. Every field below is the type the endpoint actually sends,
// measured against the live body on 2026-09-22 and against the bot's own
// `src/inngest_app/status/functionsStatus.ts`. Declaring a field at the wrong
// type is not a cosmetic error: it is silent data loss. `lastError` was typed
// `string | null` while the wire sent an object, so the string coercion
// returned null for every function on every poll and the one field that names a
// problem was discarded in transit. `triggers` was typed `string[]` while the
// wire sent `{type,value}` objects, so the list was always empty. Both are
// invisible at runtime -- the page renders, it just renders nothing. The gate
// that keeps this honest is scripts/api-contract-check.mjs; it parses a
// recorded body through the real parser below and fails when a value the wire
// carried does not survive the trip.

export const DEFAULT_STATUS_URL = 'https://999-multibots-telegraf-production-2008.up.railway.app/api/inngest/functions/status'
export const STATUS_POLL_MS = 60_000

export function functionsStatusUrl(): string {
  const raw = (import.meta.env?.VITE_INNGEST_STATUS_URL as string | undefined) ?? ''
  const url = raw.trim()
  return url.length > 0 ? url : DEFAULT_STATUS_URL
}

/**
 * The six counters the endpoint sends per window. `invoked` counts runs started
 * by hand (the probe suite, the dashboard's Invoke button, MCP) and is counted
 * in `total` but deliberately NOT in completed/failed/running -- a probe that
 * stops at its guard is not a production failure. So completed + failed +
 * running + cancelled does not equal total, and `total` is the only honest
 * denominator. Keeping only three of the six is what made the site's own
 * arithmetic fail to close.
 */
export interface RunCounts {
  completed: number | null
  failed: number | null
  running: number | null
  cancelled: number | null
  invoked: number | null
  total: number | null
}

/** One trigger as the endpoint states it: an event name or a cron expression. */
export interface FunctionTriggerRef {
  type: 'event' | 'cron' | null
  value: string | null
}

export interface LastRun {
  id: string | null
  status: string | null
  /** When the run entered the queue. The only timestamp a run still in flight has. */
  queuedAt: string | null
  /** null while the run has not finished. */
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

/**
 * Newest organic FAILED run. Probe failures are excluded by the endpoint, so
 * this only ever names real trouble. Note the key is `runId`, not `id` as in
 * LastRun/LastProbe: reusing the LastRun parser here yields null.
 */
export interface LastError {
  runId: string | null
  endedAt: string | null
  /** null for a cron-triggered run; the event name for an event-triggered one. */
  eventName: string | null
}

export interface FunctionStatus {
  id: string
  /** null exactly when the app does not serve the function. */
  slug: string | null
  /** The name the Inngest app serves it under. Frequently carries an emoji. */
  name: string | null
  domain: string | null
  triggers: FunctionTriggerRef[]
  /**
   * `spec+code` for every record the endpoint emits: it filters the manifest to
   * that value before building. Carried so the contract gate can see it, and so
   * a future endpoint that widens the filter is visible rather than silent.
   */
  control: string | null
  /** false when the manifest knows the function but the connected app does not serve it. */
  deployed: boolean | null
  runs24h: RunCounts
  runs7d: RunCounts
  /** Newest run NOT invoked by hand (event or cron traffic) - the health dot. */
  lastRun: LastRun | null
  lastProbe: LastProbe | null
  /** `probe_expect` from the bot manifest: COMPLETED | FAILED-at-guard | skip. */
  probeExpect: string | null
  lastError: LastError | null
}

export interface FunctionsStatus {
  generatedAt: string | null
  /**
   * How the body was produced. `cached` is the useful half: the endpoint holds
   * a 30 s in-memory cache and the page polls every 60 s, so roughly half of
   * all bodies are older than the `read at` stamp the page prints for itself.
   * `gqlUrl` is the bot's internal Railway address; it is parsed so the shape
   * is complete and the gate can account for it, and deliberately never drawn.
   */
  source: { gqlUrl: string | null; cached: boolean | null }
  app: { name: string | null; sdk: string | null; url: string | null; connected: boolean | null }
  functions: FunctionStatus[]
  /** Slugs the app serves that the manifest does not know: manifest/app drift. */
  unknownInApp: string[]
  /** Which function ids the endpoint reported, for a quick join. */
  byId: Map<string, FunctionStatus>
}

export type StatusState =
  | { kind: 'loading' }
  | { kind: 'ok'; status: FunctionsStatus; fetchedAt: string; url: string }
  | { kind: 'offline'; reason: string; fetchedAt: string; url: string }

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null)
const str = (v: unknown): string | null => (typeof v === 'string' && v.length > 0 ? v : null)
const bool = (v: unknown): boolean | null => (typeof v === 'boolean' ? v : null)
const rec = (v: unknown): Record<string, unknown> | null => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : null)

function counts(v: unknown): RunCounts {
  const r = rec(v)
  return {
    completed: num(r?.completed),
    failed: num(r?.failed),
    running: num(r?.running),
    cancelled: num(r?.cancelled),
    invoked: num(r?.invoked),
    total: num(r?.total),
  }
}

function triggers(v: unknown): FunctionTriggerRef[] {
  if (!Array.isArray(v)) return []
  const out: FunctionTriggerRef[] = []
  for (const raw of v) {
    const t = rec(raw)
    if (!t) continue
    const kind = t.type === 'event' || t.type === 'cron' ? t.type : null
    out.push({ type: kind, value: str(t.value) })
  }
  return out
}

/** The four fields `lastRun` and `lastProbe` share, read off an already-narrowed record. */
function runFields(r: Record<string, unknown>): LastRun {
  return { id: str(r.id), status: str(r.status), queuedAt: str(r.queuedAt), endedAt: str(r.endedAt) }
}

/** Parse the endpoint body. Returns null when it is not the documented shape. */
export function parseFunctionsStatus(body: unknown): FunctionsStatus | null {
  const root = rec(body)
  if (!root || !Array.isArray(root.functions)) return null
  const app = rec(root.app)
  const source = rec(root.source)
  const functions: FunctionStatus[] = []
  for (const raw of root.functions) {
    const f = rec(raw)
    const id = str(f?.id)
    if (!f || !id) continue
    const run = rec(f.lastRun)
    const probe = rec(f.lastProbe)
    const error = rec(f.lastError)
    functions.push({
      id,
      slug: str(f.slug),
      name: str(f.name),
      domain: str(f.domain),
      triggers: triggers(f.triggers),
      control: str(f.control),
      deployed: bool(f.deployed),
      runs24h: counts(f.runs24h),
      runs7d: counts(f.runs7d),
      lastRun: run ? runFields(run) : null,
      lastProbe: probe ? { ...runFields(probe), expect: str(probe.expect), asExpected: bool(probe.asExpected) } : null,
      probeExpect: str(f.probeExpect),
      // `runId`, not `id`: the endpoint names this key differently from the
      // other two run objects, and the mismatch is silent.
      lastError: error ? { runId: str(error.runId), endedAt: str(error.endedAt), eventName: str(error.eventName) } : null,
    })
  }
  return {
    generatedAt: str(root.generatedAt),
    source: { gqlUrl: str(source?.gqlUrl), cached: bool(source?.cached) },
    app: { name: str(app?.name), sdk: str(app?.sdk), url: str(app?.url), connected: bool(app?.connected) },
    functions,
    unknownInApp: Array.isArray(root.unknownInApp) ? root.unknownInApp.filter((s): s is string => typeof s === 'string') : [],
    byId: new Map(functions.map((f) => [f.id, f])),
  }
}

/**
 * The 503 body. The endpoint answers a failure with a different shape -- no
 * `functions` key -- and `detail` is the only text that names why Inngest was
 * unreachable. Reading the status line alone threw it away.
 */
export function parseStatusError(body: unknown): string | null {
  const r = rec(body)
  if (!r) return null
  const error = str(r.error)
  const detail = str(r.detail)
  if (!error && !detail) return null
  return [error, detail].filter((s): s is string => s !== null).join(': ')
}

/** One fetch. Every failure mode becomes `offline` with the reason spelled out. */
export async function fetchFunctionsStatus(url = functionsStatusUrl(), timeoutMs = 8000): Promise<StatusState> {
  const fetchedAt = new Date().toISOString()
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    const r = await fetch(url, { credentials: 'omit', signal: ctrl.signal, headers: { accept: 'application/json' } })
    const body: unknown = await r.json().catch(() => null)
    if (!r.ok) {
      const detail = parseStatusError(body)
      return { kind: 'offline', reason: detail ? `HTTP ${r.status} - ${detail}` : `HTTP ${r.status}`, fetchedAt, url }
    }
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

const COUNTERS: (keyof RunCounts)[] = ['completed', 'failed', 'running', 'cancelled', 'invoked', 'total']

/** Sum the run counts over the functions the endpoint reported; null when none carried a number. */
export function totalRuns(status: FunctionsStatus, window: 'runs24h' | 'runs7d'): RunCounts {
  const out: RunCounts = { completed: null, failed: null, running: null, cancelled: null, invoked: null, total: null }
  for (const f of status.functions) {
    const c = f[window]
    for (const k of COUNTERS) {
      const v = c[k]
      if (v !== null) out[k] = (out[k] ?? 0) + v
    }
  }
  return out
}
