import { useEffect, useState } from 'react'
import './Queen.css'

// The queen's panels read a backend that this site does not contain. t27.ai is
// static hosting; there is no /health and no /api here. The original app in
// apps/queen-web assumed same-origin and called res.json() on whatever came
// back, so on static hosting every panel silently rendered '...' forever -- a
// dashboard that looks alive and reports nothing.
//
// So the base URL is explicit, and "no backend" is a state the page SHOWS
// rather than a state it hides:
//   - VITE_QUEEN_API set at build time  -> that origin
//   - localhost                         -> http://localhost:8080
//   - anything else                     -> unset, and the page says so
const ENV_API = (import.meta.env.VITE_QUEEN_API as string | undefined)?.replace(/\/+$/, '')
const IS_LOCAL = typeof window !== 'undefined' && /^(localhost|127\.0\.0\.1)$/.test(window.location.hostname)
const QUEEN_API = ENV_API ?? (IS_LOCAL ? 'http://localhost:8080' : null)

type ProbeState = 'loading' | 'ok' | 'unreachable'

interface Probe<T> {
  state: ProbeState
  data: T | null
  error: string | null
}

/** Fetch that reports what actually happened instead of throwing it away. */
async function readJson<T>(path: string, init?: RequestInit): Promise<T> {
  if (!QUEEN_API) throw new Error('no backend configured')
  const res = await fetch(QUEEN_API + path, init)
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  // A static host answers /api/status with an HTML 200 for its SPA fallback.
  // Parsing that as JSON throws a syntax error that reads like a bug in the
  // queen; checking the type first names the real cause.
  const type = res.headers.get('content-type') ?? ''
  if (!type.includes('json')) throw new Error(`expected JSON, got ${type.split(';')[0] || 'nothing'}`)
  return res.json() as Promise<T>
}

function useProbe<T>(path: string, intervalMs: number): Probe<T> {
  const [probe, setProbe] = useState<Probe<T>>({ state: 'loading', data: null, error: null })

  useEffect(() => {
    if (!QUEEN_API) {
      setProbe({ state: 'unreachable', data: null, error: 'no backend configured' })
      return
    }
    let alive = true
    const tick = async () => {
      try {
        const data = await readJson<T>(path)
        if (alive) setProbe({ state: 'ok', data, error: null })
      } catch (e) {
        if (alive) setProbe({ state: 'unreachable', data: null, error: (e as Error).message })
      }
    }
    void tick()
    const id = setInterval(tick, intervalMs)
    return () => { alive = false; clearInterval(id) }
  }, [path, intervalMs])

  return probe
}

// These are the shapes the brain ACTUALLY returns, read off
// src/background_agent/server.zig rather than assumed.
//
// The version of this page in apps/queen-web rendered five metrics --
// trinity_signature, improve_cycles, uptime_seconds, env_status, swarm_active --
// and called /api/status, /api/episodes, /api/improve and /api/pipeline. The
// brain serves NONE of those. /health returns exactly {"status":"ok"}, and the
// only /api routes that exist are /api/containers and /api/sessions.
//
// So those five metrics could never be filled, by any deployment, ever. A panel
// whose value is structurally unobtainable is worse than a missing panel: it
// reads as "not yet" when the truth is "not ever".

interface HealthResponse {
  status: string
}

interface Container {
  id: string
  name: string
  status: string
  railway_service_id?: string
}

interface Session {
  id: string
  name?: string
  status?: string
}

function BrainOffline({ reason }: { reason: string | null }) {
  return (
    <div className="queen-offline">
      <h3>The brain is not connected</h3>
      <p>
        This page is the queen's face. Her brain is a separate service that answers{' '}
        <code>/health</code>, <code>/api/containers</code> and <code>/api/sessions</code>.
        This site is static hosting and serves none of them.
      </p>
      <p className="queen-offline-detail">
        {QUEEN_API
          ? <>Tried <code>{QUEEN_API}</code> — {reason}</>
          : <>No address configured. Build with <code>VITE_QUEEN_API=https://your-brain.example</code> to point this page at a running brain.</>}
      </p>
      <p className="queen-offline-note">
        Nothing below is live. Empty panels would have looked the same as a healthy
        queen with nothing to report, so the page says which one it is.
      </p>
    </div>
  )
}

function MetricCard({ label, value, status }: { label: string; value: string | number; status?: string }) {
  const colour = status === 'active' ? '#4caf50' : status === 'degraded' ? '#ff9800' : undefined
  return (
    <div className="queen-metric" style={colour ? { borderColor: colour } : undefined}>
      <span className="queen-metric-label">{label}</span>
      <span className="queen-metric-value">{value}</span>
    </div>
  )
}

function StatusDashboard({ health }: { health: Probe<HealthResponse> }) {
  const dash = '—'
  return (
    <section className="queen-card">
      <h2>👑 Liveness</h2>
      <div className="queen-metrics">
        <MetricCard
          label="Brain"
          value={health.state === 'ok' ? (health.data?.status ?? 'ok') : dash}
          status={health.state === 'ok' ? 'active' : undefined}
        />
        <MetricCard label="Address" value={QUEEN_API ?? 'not configured'} />
      </div>
      <p className="queen-sub" style={{ marginTop: '1rem', marginBottom: 0 }}>
        <code>/health</code> is the only endpoint the brain answers without a token,
        and it returns liveness alone — no counters, no uptime. Anything more
        specific here would be invented rather than measured.
      </p>
    </section>
  )
}

function ImprovementPanel() {
  // The button used to POST /api/improve. That route does not exist in
  // src/background_agent/server.zig -- the brain's whole surface is /health,
  // /api/containers and /api/sessions. A button that always fails is worse
  // than no button, so this states the gap instead of pretending at it.
  return (
    <section className="queen-card">
      <h2>🔄 Self-improvement</h2>
      <p className="queen-sub">
        The queen's original panel triggered a cycle through <code>POST /api/improve</code>.
        The brain does not implement that route, so the control is not shown: it could
        only ever have returned an error.
      </p>
      <p className="queen-sub" style={{ marginBottom: 0 }}>
        Restoring it means adding the route to <code>src/background_agent/server.zig</code>,
        which is a change to the brain rather than to this page.
      </p>
    </section>
  )
}

/** The two collections the brain really exposes. Both sit behind a token. */
function BrainInventory() {
  const containers = useProbe<Container[]>('/api/containers', 20000)
  const sessions = useProbe<Session[]>('/api/sessions', 20000)

  // The original called episodes?.slice(0, 10) on whatever came back; an object
  // rather than an array crashed the page on that line. Shape is checked first.
  const asList = <T,>(p: Probe<T[]>) => (Array.isArray(p.data) ? p.data : [])

  const renderState = (p: Probe<unknown>, what: string) => {
    if (p.state === 'loading') return <p className="queen-sub">Loading {what}…</p>
    if (p.state === 'unreachable') {
      const locked = p.error === 'HTTP 401'
      return (
        <p className="queen-sub">
          {locked
            ? <>Requires a token. <code>/api/{what}</code> is authenticated — this page holds no credentials and does not ask for any.</>
            : <>No {what}: {p.error}</>}
        </p>
      )
    }
    return null
  }

  return (
    <>
      <section className="queen-card">
        <h2>📦 Containers</h2>
        {renderState(containers, 'containers')}
        <div className="queen-episodes">
          {asList(containers).slice(0, 10).map(c => (
            <article key={c.id} className={`queen-episode ${c.status === 'ACTIVE' ? 'success' : 'failure'}`}>
              <header>
                <code>{c.id.slice(0, 8)}</code>
                <span>{c.status}</span>
              </header>
              <p><strong>{c.name}</strong></p>
              {c.railway_service_id && <footer><span>railway: {c.railway_service_id.slice(0, 8)}</span></footer>}
            </article>
          ))}
        </div>
      </section>

      <section className="queen-card" style={{ marginTop: '1.25rem' }}>
        <h2>🧵 Sessions</h2>
        {renderState(sessions, 'sessions')}
        <div className="queen-episodes">
          {asList(sessions).slice(0, 10).map(s => (
            <article key={s.id} className="queen-episode">
              <header>
                <code>{s.id.slice(0, 8)}</code>
                <span>{s.status ?? ''}</span>
              </header>
              {s.name && <p><strong>{s.name}</strong></p>}
            </article>
          ))}
        </div>
      </section>
    </>
  )
}

type Kingdom = 'brain' | 'body' | 'spirit'

const KINGDOMS: { key: Kingdom; label: string }[] = [
  { key: 'brain', label: '🧠 Brain (Strand I)' },
  { key: 'body', label: '💪 Body (Strand II)' },
  { key: 'spirit', label: '🔮 Spirit (Strand III)' },
]

export default function Queen() {
  // In the original these three tabs were <Link to="?kingdom=…"> and the state
  // setter was never called, so the highlight sat on "brain" whatever you
  // clicked and nothing read the query string. They are buttons now, and the
  // selection is the thing the page actually renders from.
  const [kingdom, setKingdom] = useState<Kingdom>('brain')
  const health = useProbe<HealthResponse>('/health', 15000)
  const connected = health.state === 'ok'

  return (
    <div className="queen-page">
      <header className="queen-header">
        <h1>👑 Queen Trinity</h1>
        <p>Self-improving container · φ² + 1/φ² = 3</p>
      </header>

      <nav className="queen-tabs">
        {KINGDOMS.map(k => (
          <button
            key={k.key}
            onClick={() => setKingdom(k.key)}
            className={kingdom === k.key ? 'active' : ''}
            aria-pressed={kingdom === k.key}
          >
            {k.label}
          </button>
        ))}
      </nav>

      {!connected && <BrainOffline reason={health.error} />}

      {kingdom === 'brain' && (
        <>
          <div className="queen-grid">
            <StatusDashboard health={health} />
            <ImprovementPanel />
          </div>
          <BrainInventory />
        </>
      )}

      {kingdom === 'body' && (
        <section className="queen-card">
          <h2>💪 Body</h2>
          <p className="queen-sub">
            The body is the hardware strand — FPGA fleet and silicon. It has no
            endpoint on the queen's brain yet, so there is nothing here to read.
          </p>
        </section>
      )}

      {kingdom === 'spirit' && (
        <section className="queen-card">
          <h2>🔮 Spirit</h2>
          <p className="queen-sub">
            The spirit strand is the corpus and its claims. It has no endpoint on
            the queen's brain yet, so there is nothing here to read.
          </p>
        </section>
      )}
    </div>
  )
}
