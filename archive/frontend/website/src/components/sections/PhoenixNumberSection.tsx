"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function PhoenixNumberSection() {
  const { t } = useI18n()
  const p = t.phoenixNumber

  if (!p) return null

  return (
    <Section id="phoenix">
      <div className="tight fade">
        <span className="badge">{p.badge}</span>
        <h2 dangerouslySetInnerHTML={{ __html: p.title }} />
        <p className="sub">{p.sub}</p>
      </div>

      {/* Main Supply Display */}
      <div className="fade" style={{ 
        marginTop: '2rem',
        padding: '2rem',
        background: 'linear-gradient(135deg, rgba(0, 255, 136, 0.1), rgba(0, 204, 102, 0.1))',
        borderRadius: '16px',
        border: '1px solid var(--border)',
        textAlign: 'center'
      }}>
        <div style={{ fontSize: 'clamp(2rem, 6vw, 4rem)', fontWeight: 700, color: 'var(--accent)' }}>
          {p.supply.value}
        </div>
        <div style={{ fontSize: '1.2rem', color: 'var(--muted)', marginTop: '0.5rem' }}>
          {p.supply.label}
        </div>
        <div style={{ 
          fontSize: '1.5rem', 
          fontFamily: 'monospace',
          color: 'var(--text)',
          marginTop: '1rem',
          padding: '0.5rem 1rem',
          background: 'rgba(0,0,0,0.3)',
          borderRadius: '8px',
          display: 'inline-block'
        }}>
          {p.supply.formula}
        </div>
      </div>

      {/* Golden Identity */}
      <div className="fade" style={{ 
        marginTop: '2rem',
        padding: '1.5rem',
        background: 'rgba(255, 215, 0, 0.1)',
        borderRadius: '12px',
        border: '1px solid rgba(255, 215, 0, 0.3)',
        textAlign: 'center'
      }}>
        <h3 style={{ color: 'gold', marginBottom: '0.5rem' }}>{p.identity.title}</h3>
        <div style={{ fontSize: '2rem', fontFamily: 'monospace', color: 'var(--text)' }}>
          {p.identity.formula}
        </div>
        <div style={{ color: 'var(--muted)', marginTop: '0.5rem' }}>{p.identity.desc}</div>
      </div>

      {/* Formulas Grid */}
      <div className="fade" style={{ 
        marginTop: '2rem',
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
        gap: '1rem'
      }}>
        {p.formulas?.map((f: { title: string; formula: string; desc: string }, i: number) => (
          <div key={i} style={{
            padding: '1.5rem',
            background: 'rgba(255,255,255,0.02)',
            borderRadius: '12px',
            border: '1px solid var(--border)'
          }}>
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.5rem' }}>{f.title}</h4>
            <div style={{ 
              fontSize: '1.2rem', 
              fontFamily: 'monospace',
              color: 'var(--text)',
              padding: '0.5rem',
              background: 'rgba(0,0,0,0.2)',
              borderRadius: '6px',
              marginBottom: '0.5rem'
            }}>
              {f.formula}
            </div>
            <div style={{ fontSize: '0.85rem', color: 'var(--muted)' }}>{f.desc}</div>
          </div>
        ))}
      </div>

      {/* Constants */}
      <div className="fade" style={{ marginTop: '2rem' }}>
        <div style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: '1rem',
          justifyContent: 'center'
        }}>
          {p.constants?.map((c: { symbol: string; value: string; name: string }, i: number) => (
            <div key={i} style={{
              padding: '1rem 1.5rem',
              background: 'rgba(255,255,255,0.02)',
              borderRadius: '8px',
              border: '1px solid var(--border)',
              textAlign: 'center',
              minWidth: '120px'
            }}>
              <div style={{ fontSize: '2rem', color: 'var(--accent)' }}>{c.symbol}</div>
              <div style={{ fontSize: '0.9rem', fontFamily: 'monospace', color: 'var(--text)' }}>{c.value}</div>
              <div style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>{c.name}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Genetic Algorithm Constants */}
      <div className="fade" style={{ marginTop: '2rem' }}>
        <h3 style={{ textAlign: 'center', marginBottom: '1rem' }}>{p.genetics?.title}</h3>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '1rem'
        }}>
          {p.genetics?.items?.map((g: { symbol: string; formula: string; name: string }, i: number) => (
            <div key={i} style={{
              padding: '1rem',
              background: 'rgba(0, 255, 136, 0.05)',
              borderRadius: '8px',
              border: '1px solid rgba(0, 255, 136, 0.2)',
              textAlign: 'center'
            }}>
              <div style={{ fontSize: '1.5rem', color: '#00FF88' }}>{g.symbol}</div>
              <div style={{ fontSize: '0.9rem', fontFamily: 'monospace', color: 'var(--text)' }}>{g.formula}</div>
              <div style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>{g.name}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Physics Constants */}
      <div className="fade" style={{ marginTop: '2rem' }}>
        <h3 style={{ textAlign: 'center', marginBottom: '1rem' }}>{p.physics?.title}</h3>
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '0.5rem'
        }}>
          {p.physics?.items?.map((ph: { name: string; formula: string }, i: number) => (
            <div key={i} style={{
              padding: '0.75rem 1rem',
              background: 'rgba(255,255,255,0.02)',
              borderRadius: '6px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '0.5rem'
            }}>
              <span style={{ color: 'var(--muted)' }}>{ph.name}</span>
              <span style={{ fontFamily: 'monospace', color: 'var(--accent)' }}>{ph.formula}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Token Distribution */}
      <div className="fade" style={{ marginTop: '2rem' }}>
        <h3 style={{ textAlign: 'center', marginBottom: '1rem' }}>{p.distribution?.title}</h3>
        <div style={{
          background: 'rgba(255,255,255,0.02)',
          borderRadius: '12px',
          border: '1px solid var(--border)',
          overflow: 'hidden'
        }}>
          {p.distribution?.items?.map((d: { name: string; percent: string; amount: string }, i: number) => (
            <div key={i} style={{
              padding: '1rem',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              borderBottom: i < p.distribution.items.length - 1 ? '1px solid var(--border)' : 'none'
            }}>
              <span style={{ color: 'var(--text)' }}>{d.name}</span>
              <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                <span style={{ color: 'var(--accent)', fontWeight: 600 }}>{d.percent}</span>
                <span style={{ fontFamily: 'monospace', color: 'var(--muted)', fontSize: '0.85rem' }}>{d.amount}</span>
              </div>
            </div>
          ))}
          <div style={{
            padding: '1rem',
            background: 'rgba(0, 229, 153, 0.1)',
            textAlign: 'center',
            fontWeight: 600,
            color: 'var(--accent)'
          }}>
            {p.distribution?.total}
          </div>
        </div>
      </div>

      {/* Quote */}
      <div className="fade" style={{ 
        marginTop: '2rem',
        textAlign: 'center',
        fontStyle: 'italic',
        color: 'var(--muted)',
        fontSize: '1.1rem'
      }}>
        {p.quote}
      </div>

      {/* CTA */}
      <div className="fade" style={{ marginTop: '2rem', textAlign: 'center' }}>
        <a 
          href={p.ctaUrl} 
          target="_blank" 
          rel="noopener noreferrer"
          className="btn"
          style={{
            display: 'inline-block',
            padding: '1rem 2rem',
            background: 'var(--accent)',
            color: 'white',
            borderRadius: '8px',
            textDecoration: 'none',
            fontWeight: 600
          }}
        >
          {p.cta} →
        </a>
      </div>
    </Section>
  )
}
