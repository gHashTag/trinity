import { useEffect, useMemo, useState } from 'react'
import { useI18n } from '../i18n/context'

// The MCP catalog reads a hub that runs on the owner's own machine
// (mcp-hub/scan.mjs --serve). It is deliberately NOT a file published with this
// site: the inventory names private projects, so it stays on the machine that
// owns it and the page asks for it live.
//
// A loopback origin is treated as potentially trustworthy by browsers, so this
// fetch works from https://t27.ai as well as from a local dev server. When the
// hub is not running, the page says exactly that and how to start it, rather
// than rendering an empty catalog that looks like "no servers".
const HUB = (import.meta.env.VITE_MCP_HUB as string | undefined)?.replace(/\/+$/, '') ?? 'http://127.0.0.1:8899'

type Status = 'online' | 'reachable' | 'offline'

interface McpTool {
  name: string
  description: string
}

interface McpServer {
  name: string
  transport: string
  url: string | null
  command: string | null
  args: string[]
  envKeys: string[]
  headerKeys: string[]
  secretsInConfig: boolean
  origins: string[]
  status: Status
  ms: number
  error: string | null
  note?: string | null
  toolCount: number | null
  tools: McpTool[]
}

interface HubPayload {
  generatedAt: string
  counts: { servers: number; online: number; reachable: number; offline: number; tools: number }
  note: string
  servers: McpServer[]
}

const RU = {
  title: '🔌 MCP',
  subtitle: 'Каталог MCP-серверов этой машины: кто отвечает прямо сейчас и какие инструменты отдаёт.',
  hubOffline: 'Хаб не запущен',
  hubP1: 'Каталог читается живьём с',
  hubP2: 'Этот список не публикуется вместе с сайтом — он называет приватные проекты, поэтому остаётся на машине владельца.',
  hubStart: 'Запустить:',
  loading: 'Опрос серверов…',
  servers: 'Серверов',
  online: 'Онлайн',
  offline: 'Не отвечают',
  tools: 'Инструментов',
  updated: 'Обновлено',
  refresh: 'Переопросить',
  search: 'Поиск по серверу или инструменту',
  all: 'Все',
  onlyOnline: 'Только онлайн',
  onlyOffline: 'Только офлайн',
  toolsWord: 'инструментов',
  noTools: 'список инструментов недоступен',
  configuredIn: 'настроен в',
  secretNote: 'В конфиге есть секрет: значения аргументов и переменных здесь не показываются.',
  nothing: 'Ничего не найдено.',
  statusOnline: 'онлайн',
  statusReachable: 'отвечает',
  statusOffline: 'офлайн',
}

const EN: typeof RU = {
  title: '🔌 MCP',
  subtitle: "Catalog of this machine's MCP servers: which answer right now, and what tools they expose.",
  hubOffline: 'The hub is not running',
  hubP1: 'The catalog is read live from',
  hubP2: 'This list is not published with the site — it names private projects, so it stays on the machine that owns it.',
  hubStart: 'Start it with:',
  loading: 'Probing servers…',
  servers: 'Servers',
  online: 'Online',
  offline: 'Not answering',
  tools: 'Tools',
  updated: 'Updated',
  refresh: 'Probe again',
  search: 'Search a server or a tool',
  all: 'All',
  onlyOnline: 'Online only',
  onlyOffline: 'Offline only',
  toolsWord: 'tools',
  noTools: 'tool list unavailable',
  configuredIn: 'configured in',
  secretNote: 'This config carries a secret: argument and environment values are never shown here.',
  nothing: 'Nothing matches.',
  statusOnline: 'online',
  statusReachable: 'answers',
  statusOffline: 'offline',
}

const DOT: Record<Status, string> = { online: '●', reachable: '◐', offline: '○' }

function StatusPill({ status, c }: { status: Status; c: typeof RU }) {
  const label = status === 'online' ? c.statusOnline : status === 'reachable' ? c.statusReachable : c.statusOffline
  return (
    <span className={`mcp-pill mcp-${status}`}>
      {DOT[status]} {label}
    </span>
  )
}

function ServerCard({ s, c, query }: { s: McpServer; c: typeof RU; query: string }) {
  const [open, setOpen] = useState(false)
  const q = query.trim().toLowerCase()
  const shown = q ? s.tools.filter(t => t.name.toLowerCase().includes(q) || t.description.toLowerCase().includes(q)) : s.tools
  const list = open || (q && shown.length) ? shown : shown.slice(0, 6)

  return (
    <article className={`queen-card mcp-card mcp-border-${s.status}`}>
      <header className="mcp-card-head">
        <h3>{s.name}</h3>
        <StatusPill status={s.status} c={c} />
      </header>

      <p className="mcp-meta">
        <code>{s.transport}</code>
        {s.url && <> · <code>{s.url}</code></>}
        {!s.url && s.command && <> · <code>{[s.command, ...s.args].join(' ')}</code></>}
        {s.ms > 0 && <> · {s.ms} ms</>}
      </p>

      {s.status === 'online' && (
        <p className="mcp-count">
          {s.toolCount} {c.toolsWord}
        </p>
      )}
      {s.status === 'reachable' && <p className="mcp-error">{s.note ?? c.noTools}</p>}
      {s.status === 'offline' && <p className="mcp-error">{s.error}</p>}

      {list.length > 0 && (
        <ul className="mcp-tools">
          {list.map(t => (
            <li key={t.name}>
              <code>{t.name}</code>
              {t.description && <span>{t.description}</span>}
            </li>
          ))}
        </ul>
      )}

      {!q && s.tools.length > 6 && (
        <button className="mcp-more" onClick={() => setOpen(o => !o)}>
          {open ? '−' : `+${s.tools.length - 6}`}
        </button>
      )}

      <footer className="mcp-origins">
        {c.configuredIn} {s.origins.join(', ')}
        {s.secretsInConfig && <span className="mcp-secret"> · 🔒 {c.secretNote}</span>}
      </footer>
    </article>
  )
}

export default function QueenMcp() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : EN

  const [data, setData] = useState<HubPayload | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(true)
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<'all' | 'online' | 'offline'>('all')
  const [nonce, setNonce] = useState(0)

  useEffect(() => {
    let alive = true
    setBusy(true)
    fetch(`${HUB}/mcp.json`)
      .then(r => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        return r.json() as Promise<HubPayload>
      })
      .then(d => alive && (setData(d), setError(null)))
      .catch(e => alive && setError((e as Error).message))
      .finally(() => alive && setBusy(false))
    return () => {
      alive = false
    }
  }, [nonce])

  const servers = useMemo(() => {
    if (!data) return []
    const q = query.trim().toLowerCase()
    return data.servers.filter(s => {
      if (filter === 'online' && s.status === 'offline') return false
      if (filter === 'offline' && s.status !== 'offline') return false
      if (!q) return true
      return (
        s.name.toLowerCase().includes(q) ||
        s.tools.some(t => t.name.toLowerCase().includes(q) || t.description.toLowerCase().includes(q))
      )
    })
  }, [data, query, filter])

  if (!data) {
    return (
      <section className="queen-offline">
        <h3>{busy ? c.loading : c.hubOffline}</h3>
        <p>
          {c.hubP1} <code>{HUB}/mcp.json</code>
          {error && <> — {error}</>}
        </p>
        <p className="queen-offline-note">{c.hubP2}</p>
        <p className="queen-offline-detail">
          {c.hubStart} <code>node ~/mcp-hub/scan.mjs --serve</code>
        </p>
      </section>
    )
  }

  return (
    <>
      <section className="queen-card mcp-summary">
        <h2>{c.title}</h2>
        <p className="queen-sub">{c.subtitle}</p>
        <div className="queen-metrics">
          <div className="queen-metric">
            <span className="queen-metric-label">{c.servers}</span>
            <span className="queen-metric-value">{data.counts.servers}</span>
          </div>
          <div className="queen-metric" style={{ borderColor: '#4caf50' }}>
            <span className="queen-metric-label">{c.online}</span>
            <span className="queen-metric-value">{data.counts.online + data.counts.reachable}</span>
          </div>
          <div className="queen-metric">
            <span className="queen-metric-label">{c.offline}</span>
            <span className="queen-metric-value">{data.counts.offline}</span>
          </div>
          <div className="queen-metric">
            <span className="queen-metric-label">{c.tools}</span>
            <span className="queen-metric-value">{data.counts.tools}</span>
          </div>
        </div>
        <div className="mcp-controls">
          <input
            className="mcp-search"
            value={query}
            placeholder={c.search}
            onChange={e => setQuery(e.target.value)}
          />
          <div className="queen-tabs mcp-filters">
            {(['all', 'online', 'offline'] as const).map(f => (
              <button key={f} className={filter === f ? 'active' : ''} onClick={() => setFilter(f)}>
                {f === 'all' ? c.all : f === 'online' ? c.onlyOnline : c.onlyOffline}
              </button>
            ))}
          </div>
          <button className="queen-button" onClick={() => setNonce(n => n + 1)} disabled={busy}>
            {c.refresh}
          </button>
        </div>
        <p className="queen-sub mcp-stamp">
          {c.updated}: <code>{data.generatedAt}</code> · {data.note}
        </p>
      </section>

      {servers.length === 0 ? (
        <p className="queen-sub" style={{ marginTop: '1.25rem' }}>{c.nothing}</p>
      ) : (
        <div className="mcp-grid">
          {servers.map(s => (
            <ServerCard key={`${s.name}-${s.transport}-${s.url ?? s.command ?? ''}`} s={s} c={c} query={query} />
          ))}
        </div>
      )}
    </>
  )
}
