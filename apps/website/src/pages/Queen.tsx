import { useCallback, useEffect, useState } from 'react'
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

interface HealthResponse {
  status: string
  trinity_signature: number
  improve_cycles: number
  uptime_seconds: number
}

interface SystemStatus {
  trinity_identity: number
  env_status: 'active' | 'degraded' | 'maintenance'
  swarm_active: boolean
}

interface Episode {
  id: string
  timestamp: number
  action_type: string
  outcome: string
  success: boolean
  duration_ms: number
}

interface ImproveResponse {
  success: boolean
  message: string
  applied_deltas: number
  quality_score: number
}

function formatUptime(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

function BrainOffline({ reason }: { reason: string | null }) {
  return (
    <div className="queen-offline">
      <h3>The brain is not connected</h3>
      <p>
        This page is the queen's face. Her brain is a separate service that answers{' '}
        <code>/health</code>, <code>/api/status</code>, <code>/api/episodes</code> and{' '}
        <code>/api/improve</code>. This site is static hosting and serves none of them.
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

function StatusDashboard() {
  const health = useProbe<HealthResponse>('/health', 5000)
  const status = useProbe<SystemStatus>('/api/status', 10000)
  const dash = '—'

  return (
    <section className="queen-card">
      <h2>👑 Status</h2>
      <div className="queen-metrics">
        <MetricCard
          label="Trinity signature"
          value={health.data ? `φ² + 1/φ² = ${health.data.trinity_signature}` : dash}
        />
        <MetricCard label="Uptime" value={health.data ? formatUptime(health.data.uptime_seconds) : dash} />
        <MetricCard label="Improve cycles" value={health.data ? health.data.improve_cycles : dash} />
        <MetricCard
          label="Environment"
          value={status.data ? status.data.env_status : dash}
          status={status.data?.env_status}
        />
        <MetricCard label="Swarm" value={status.data ? (status.data.swarm_active ? 'active' : 'idle') : dash} />
      </div>
    </section>
  )
}

function ImprovementPanel({ enabled }: { enabled: boolean }) {
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<ImproveResponse | null>(null)
  const [error, setError] = useState<string | null>(null)

  const trigger = useCallback(async () => {
    setRunning(true); setResult(null); setError(null)
    try {
      setResult(await readJson<ImproveResponse>('/api/improve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      }))
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setRunning(false)
    }
  }, [])

  return (
    <section className="queen-card">
      <h2>🔄 Self-improvement</h2>
      <p className="queen-sub">Runs one autonomous cycle through the .tri pipeline.</p>
      <button className="queen-button" onClick={trigger} disabled={!enabled || running}>
        {running ? 'Running…' : enabled ? 'Trigger improvement' : 'Unavailable — no brain'}
      </button>
      {error && <div className="queen-result failure">Request failed: {error}</div>}
      {result && (
        <div className={`queen-result ${result.success ? 'success' : 'failure'}`}>
          <strong>{result.success ? '✓' : '✗'}</strong> {result.message}
          <div className="queen-result-rows">
            <span>Applied deltas: {result.applied_deltas}</span>
            <span>Quality: {(result.quality_score * 100).toFixed(0)}%</span>
          </div>
        </div>
      )}
    </section>
  )
}

function EpisodeViewer() {
  const episodes = useProbe<Episode[]>('/api/episodes', 30000)
  // The original called episodes?.slice(0, 10) directly. A backend that answers
  // with an object rather than an array crashes the page on that line, so the
  // shape is checked before it is used.
  const list = Array.isArray(episodes.data) ? episodes.data.slice(0, 10) : []

  return (
    <section className="queen-card">
      <h2>📜 Recent episodes</h2>
      {episodes.state === 'loading' && <p className="queen-sub">Loading…</p>}
      {episodes.state === 'ok' && list.length === 0 && (
        <p className="queen-sub">The brain answered, and has no episodes to report.</p>
      )}
      {episodes.state === 'unreachable' && <p className="queen-sub">No episodes: {episodes.error}</p>}
      <div className="queen-episodes">
        {list.map(ep => (
          <article key={ep.id} className={`queen-episode ${ep.success ? 'success' : 'failure'}`}>
            <header>
              <code>{ep.id.slice(0, 8)}</code>
              <time>{new Date(ep.timestamp).toLocaleString()}</time>
            </header>
            <p>
              <strong>{ep.action_type}</strong> — {ep.outcome}
            </p>
            <footer>
              <span>{ep.duration_ms} ms</span>
              <span className={ep.success ? 'ok' : 'bad'}>{ep.success ? '✓ success' : '✗ failed'}</span>
            </footer>
          </article>
        ))}
      </div>
    </section>
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
            <StatusDashboard />
            <ImprovementPanel enabled={connected} />
          </div>
          <EpisodeViewer />
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
