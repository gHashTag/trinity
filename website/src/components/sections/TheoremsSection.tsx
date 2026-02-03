import { motion } from 'framer-motion'
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
      <div className="radial-glow" style={{ opacity: 0.2 }} />
      <div className="tight fade">
        <div className="badge" style={{ marginBottom: '1rem' }}>MATHEMATICAL FOUNDATION</div>
        <h2 dangerouslySetInnerHTML={{ __html: theorems.title }} />
        <p style={{ maxWidth: '700px', margin: '0 auto', opacity: 0.9 }}>{theorems.sub}</p>
      </div>

      {/* Vertical layout - 4 rows */}
      <div className="fade" style={{ 
        marginTop: '3rem',
        display: 'flex',
        flexDirection: 'column',
        gap: '1.2rem',
        maxWidth: '850px',
        margin: '3rem auto 0',
        padding: '0 1rem'
      }}>
        {theorems.cards?.map((card: TheoremCard, i: number) => (
          <motion.div 
            key={i} 
            className="premium-card"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1, duration: 0.4 }}
            viewport={{ once: true }}
            style={{ 
              padding: '1.5rem',
              display: 'flex',
              flexDirection: 'column',
              gap: '1rem'
            }}
          >
            {/* Header row: Number + Title + Verified */}
            <div style={{ 
              display: 'flex',
              alignItems: 'center',
              gap: '1rem',
              flexWrap: 'wrap'
            }}>
              {/* Number badge - smaller, cleaner */}
              <div style={{ 
                width: '36px', 
                height: '36px', 
                borderRadius: '8px', 
                background: 'var(--accent)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1rem',
                fontWeight: 700,
                color: '#000',
                flexShrink: 0
              }}>
                #{card.number}
              </div>

              {/* Title */}
              <h3 style={{ 
                margin: 0, 
                fontSize: '1.1rem', 
                color: 'var(--text)',
                fontWeight: 600,
                flex: 1,
                minWidth: '150px'
              }}>
                {card.title}
              </h3>

              {/* Verified badge - compact */}
              <div style={{ 
                padding: '0.4rem 0.8rem',
                background: 'rgba(34, 197, 94, 0.15)',
                borderRadius: '4px',
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                flexShrink: 0
              }}>
                <span style={{ color: '#22c55e', fontSize: '0.75rem' }}>✓</span>
                <span style={{ 
                  fontSize: '0.75rem', 
                  color: '#22c55e',
                  fontWeight: 600
                }}>
                  {card.verified.metric}
                </span>
              </div>
            </div>

            {/* Formula */}
            <div style={{ 
              background: 'rgba(99, 102, 241, 0.08)', 
              padding: '0.8rem 1rem', 
              borderRadius: '6px',
              fontFamily: 'ui-monospace, monospace',
              fontSize: '1rem',
              color: 'var(--accent)',
              textAlign: 'center',
              letterSpacing: '0.02em'
            }}>
              {card.formula}
            </div>

            {/* Result */}
            <p style={{ 
              fontSize: '0.9rem', 
              color: 'var(--text)', 
              margin: 0,
              lineHeight: 1.5
            }}>
              {card.result}
            </p>

            {/* Source - subtle */}
            <p style={{ 
              fontSize: '0.75rem', 
              color: 'var(--muted)', 
              margin: 0,
              opacity: 0.6
            }}>
              {card.source}
            </p>
          </motion.div>
        ))}
      </div>

      {/* Reports links */}
      {theorems.reports && (
        <div className="fade" style={{ marginTop: '2.5rem', textAlign: 'center' }}>
          <h4 style={{ 
            marginBottom: '1rem', 
            color: 'var(--muted)',
            fontSize: '0.8rem',
            textTransform: 'uppercase',
            letterSpacing: '0.1em'
          }}>
            {theorems.reportsTitle}
          </h4>
          <div style={{ 
            display: 'flex', 
            flexWrap: 'wrap', 
            justifyContent: 'center', 
            gap: '0.6rem' 
          }}>
            {theorems.reports.map((report: Report, i: number) => (
              <a 
                key={i}
                href={report.url}
                target="_blank"
                rel="noopener noreferrer"
                className="premium-card"
                style={{
                  padding: '0.5rem 1rem',
                  color: 'var(--text)',
                  textDecoration: 'none',
                  fontSize: '0.8rem',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.5rem'
                }}
              >
                {report.name}
                <span style={{ color: 'var(--accent)', fontWeight: 600 }}>{report.highlight}</span>
              </a>
            ))}
          </div>
        </div>
      )}

      {/* CTA Button */}
      {theorems.cta && (
        <div className="fade" style={{ marginTop: '2rem', textAlign: 'center' }}>
          <a 
            href={theorems.ctaUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="btn"
          >
            {theorems.cta} →
          </a>
        </div>
      )}
    </Section>
  )
}
