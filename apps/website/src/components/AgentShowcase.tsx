import { useEffect, useState } from 'react'
import { AGENTS_ENDPOINT, AGENT_PROFILES, type AgentProfile } from '../data/agents'
import { clubPrice, clubPriceUsd, orderUrl } from '../data/club'

type Live = { id: string; icon?: string; name?: AgentProfile['name']; promise?: AgentProfile['promise'] }

const isProfile = (x: Live): x is AgentProfile => Boolean(x.id && x.icon && x.name && x.promise)

// The bot's catalogue wins when it answers; the bundled list is the fallback.
function useAgents(): readonly AgentProfile[] {
  const [agents, setAgents] = useState<readonly AgentProfile[]>(AGENT_PROFILES)
  useEffect(() => {
    const ctl = new AbortController()
    fetch(AGENTS_ENDPOINT, { signal: ctl.signal })
      .then(r => (r.ok ? r.json() : null))
      .then((body: { packages?: Live[] } | Live[] | null) => {
        const list = Array.isArray(body) ? body : body?.packages
        const live = (list ?? []).filter(isProfile)
        const hasLive = live.length > 0
        if (hasLive) setAgents(live)
      })
      .catch(() => {})
    return () => ctl.abort()
  }, [])
  return agents
}

// `featured` puts one profile first, full width, with the accent border and the
// primary button — on #/foundry that is TRI DEV, the club's own agent.
export default function AgentShowcase({ ru, featured }: { ru: boolean; featured?: string }) {
  const all = useAgents()
  const agents = [...all.filter(a => a.id === featured), ...all.filter(a => a.id !== featured)]
  return (
    <section className="section">
      <div className="section-inner">
        <h2 style={{ marginTop: 0 }}>{ru ? 'Агенты' : 'Agents'}</h2>
        <p style={{ marginTop: 0, color: 'var(--muted)' }}>
          {ru
            ? `Одна цена для всех — ${clubPrice(true)} (${clubPriceUsd(true)}), подписка Telegram Stars. Агенты различаются профилем.`
            : `One price for every agent — ${clubPrice(false)} (${clubPriceUsd(false)}), a Telegram Stars subscription. Agents differ by profile.`}
        </p>
        <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
          {agents.map(a => {
            const lead = a.id === featured
            return (
              <div
                key={a.id}
                className="premium-card"
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  textAlign: 'center',
                  ...(lead ? { gridColumn: '1 / -1', borderColor: 'var(--accent)', boxShadow: '0 0 0 1px var(--accent), 0 0 40px rgba(0,255,136,0.12)' } : {}),
                }}
              >
                {lead ? (
                  <div style={{ fontSize: '0.72rem', letterSpacing: '0.2em', textTransform: 'uppercase', color: 'var(--accent)', marginBottom: '0.6rem' }}>
                    {ru ? 'Агент клуба' : 'The club agent'}
                  </div>
                ) : null}
                <div style={{ fontSize: lead ? '2.2rem' : '1.6rem', lineHeight: 1 }}>{a.icon}</div>
                <h3 style={{ margin: '0.6rem 0 0.4rem', fontSize: lead ? '1.6rem' : '1.05rem' }}>{ru ? a.name.ru : a.name.en}</h3>
                <p style={{ margin: '0 0 1rem', color: 'var(--muted)', fontSize: lead ? '1rem' : '0.92rem', lineHeight: 1.6, flex: 1, maxWidth: lead ? '40rem' : undefined }}>
                  {ru ? a.promise.ru : a.promise.en}
                </p>
                {lead ? <div style={{ fontSize: '1.8rem', fontWeight: 700, marginBottom: '0.25rem' }}>{clubPrice(ru)}</div> : null}
                {lead ? <div style={{ fontSize: '0.85rem', color: 'var(--muted)', marginBottom: '1rem' }}>{clubPriceUsd(ru)}</div> : null}
                <a className={lead ? 'btn' : 'btn secondary'} href={orderUrl(a.id)} style={{ display: 'inline-block' }}>
                  {ru ? 'Подключить в Telegram' : 'Get it in Telegram'}
                </a>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
