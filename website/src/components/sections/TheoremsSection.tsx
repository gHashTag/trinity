import { useI18n } from '../../i18n/context'
import Section from '../Section'

interface TheoremCard {
  number: string
  title: string
  formula: string
  proof: string
  result: string
  source: string
  advantage: string
  verified: {
    metric: string
    value: string
    report: string
  }
}

interface Report {
  name: string
  url: string
  highlight: string
}

export default function TheoremsSection() {
  const { t } = useI18n()
  const theorems = t.theorems

  if (!theorems) return null

  return (
    <Section id="theorems">
      <div className="tight fade">
        <div className="badge" style={{ marginBottom: '1rem' }}>MATHEMATICAL FOUNDATION</div>
        <h2 dangerouslySetInnerHTML={{ __html: theorems.title }} />
        <p style={{ maxWidth: '700px', margin: '0 auto', opacity: 0.9 }}>{theorems.sub}</p>
      </div>

      <div className="grid fade" style={{ 
        marginTop: '3rem',
        gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        gap: '1.5rem',
        maxWidth: '1200px',
        margin: '3rem auto 0'
      }}>
        {theorems.cards?.map((card: TheoremCard, i: number) => (
          <div key={i} className="premium-card" style={{ 
            padding: '2rem',
            display: 'flex',
            flexDirection: 'column',
            gap: '1rem'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
              <div style={{ 
                width: '48px', 
                height: '48px', 
                borderRadius: '50%', 
                background: 'linear-gradient(135deg, var(--accent), #8b5cf6)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1.5rem',
                fontWeight: 700,
                color: '#fff'
              }}>
                {card.number}
              </div>
              <h3 style={{ margin: 0, fontSize: '1.2rem', color: 'var(--text)' }}>{card.title}</h3>
            </div>

            <div style={{ 
              background: 'rgba(99, 102, 241, 0.1)', 
              padding: '1rem', 
              borderRadius: '8px',
              fontFamily: 'monospace',
              fontSize: '1.1rem',
              color: 'var(--accent)',
              textAlign: 'center'
            }}>
              {card.formula}
            </div>

            <p style={{ fontSize: '0.9rem', color: 'var(--muted)', margin: 0 }}>
              <strong style={{ color: 'var(--text)' }}>Proof:</strong> {card.proof}
            </p>

            <p style={{ fontSize: '0.9rem', color: 'var(--text)', margin: 0 }}>
              <strong>Result:</strong> {card.result}
            </p>

            <div style={{ 
              marginTop: 'auto',
              padding: '1rem',
              background: 'rgba(34, 197, 94, 0.1)',
              borderRadius: '8px',
              borderLeft: '3px solid #22c55e'
            }}>
              <div style={{ fontSize: '0.8rem', color: '#22c55e', fontWeight: 600, marginBottom: '0.3rem' }}>
                ✓ VERIFIED: {card.verified.metric}
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--text)' }}>
                {card.verified.value}
              </div>
            </div>

            <div style={{ fontSize: '0.75rem', color: 'var(--muted)', fontStyle: 'italic' }}>
              Source: {card.source}
            </div>
          </div>
        ))}
      </div>

      {theorems.reports && (
        <div className="fade" style={{ marginTop: '3rem', textAlign: 'center' }}>
          <h3 style={{ marginBottom: '1.5rem', color: 'var(--text)' }}>{theorems.reportsTitle}</h3>
          <div style={{ 
            display: 'flex', 
            flexWrap: 'wrap', 
            justifyContent: 'center', 
            gap: '1rem' 
          }}>
            {theorems.reports.map((report: Report, i: number) => (
              <a 
                key={i}
                href={report.url}
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  padding: '0.8rem 1.5rem',
                  background: 'rgba(99, 102, 241, 0.1)',
                  border: '1px solid var(--border)',
                  borderRadius: '8px',
                  color: 'var(--text)',
                  textDecoration: 'none',
                  fontSize: '0.9rem',
                  transition: 'all 0.2s'
                }}
              >
                {report.name} <span style={{ color: 'var(--accent)' }}>({report.highlight})</span>
              </a>
            ))}
          </div>
        </div>
      )}

      {theorems.cta && (
        <div className="fade" style={{ marginTop: '2rem', textAlign: 'center' }}>
          <a 
            href={theorems.ctaUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="btn"
            style={{ display: 'inline-block' }}
          >
            {theorems.cta} →
          </a>
        </div>
      )}
    </Section>
  )
}
