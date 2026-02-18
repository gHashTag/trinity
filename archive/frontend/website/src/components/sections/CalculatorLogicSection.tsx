"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

interface Example {
  op: string
  binary: string
  ternary: string
  savings: string
}

interface ComparisonItem {
  icon: string
  title: string
  desc: string
  details?: string[]
  examples?: Example[]
  features?: string[]
}

export default function CalculatorLogicSection() {
  const { t } = useI18n()
  const cl = t.calculatorLogic

  if (!cl) return null

  const binaryItem = cl.comparison?.[0] as ComparisonItem

  return (
    <Section id="calculator-logic">
      <div className="radial-glow" style={{ opacity: 0.15 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: cl.title }} />
        <p>{cl.sub}</p>
      </div>
      
      {/* Main comparison cards */}
      <div className="fade" style={{ marginTop: '3rem', display: 'flex', gap: '2rem', flexWrap: 'wrap', justifyContent: 'center' }}>
        {cl.comparison?.map((item: ComparisonItem, i: number) => (
          <motion.div 
            key={i} 
            className="premium-card" 
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            viewport={{ once: true }}
            style={{ 
              flex: '1 1 300px', 
              maxWidth: '500px', 
              textAlign: 'center', 
              borderColor: i === 1 ? 'var(--accent)' : 'var(--border)', 
              padding: 'clamp(1.5rem, 5vw, 2.5rem)' 
            }}
          >
            <div style={{ fontSize: 'clamp(2.5rem, 8vw, 3.5rem)', marginBottom: '1rem' }}>{item.icon}</div>
            <h3 style={{ marginBottom: '1rem', color: i === 1 ? 'var(--accent)' : 'var(--text)', fontSize: 'clamp(1.2rem, 4vw, 1.5rem)' }}>{item.title}</h3>
            <p style={{ color: 'var(--muted)', fontSize: 'clamp(0.85rem, 2.5vw, 0.95rem)', lineHeight: '1.6', marginBottom: '1.5rem' }}>{item.desc}</p>
            
            {/* Detailed breakdown */}
            {item.details && (
              <div style={{ 
                textAlign: 'left', 
                background: i === 0 ? 'rgba(239, 68, 68, 0.05)' : 'rgba(34, 197, 94, 0.05)',
                border: `1px solid ${i === 0 ? 'rgba(239, 68, 68, 0.2)' : 'rgba(34, 197, 94, 0.2)'}`,
                borderRadius: '8px',
                padding: '1rem',
                marginBottom: '1rem',
                fontFamily: 'ui-monospace, monospace',
                fontSize: '0.8rem',
                lineHeight: '1.6'
              }}>
                {item.details.map((line: string, j: number) => (
                  <div key={j} style={{ 
                    color: line.startsWith('•') ? 'var(--muted)' : (i === 0 ? '#ef4444' : 'var(--accent)'),
                    fontWeight: line.startsWith('•') ? 400 : 600,
                    marginTop: line === '' ? '0.5rem' : 0
                  }}>
                    {line || '\u00A0'}
                  </div>
                ))}
              </div>
            )}
            
            {/* Features list for ternary */}
            {item.features && (
              <ul style={{ 
                textAlign: 'left', 
                listStyle: 'none', 
                padding: 0, 
                margin: 0,
                display: 'flex',
                flexDirection: 'column',
                gap: '0.5rem'
              }}>
                {item.features.map((feature: string, j: number) => (
                  <li key={j} style={{ 
                    fontSize: '0.85rem', 
                    color: 'var(--text)',
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: '0.5rem'
                  }}>
                    <span style={{ color: 'var(--accent)', flexShrink: 0 }}>✓</span>
                    {feature}
                  </li>
                ))}
              </ul>
            )}
          </motion.div>
        ))}
      </div>

      {/* Detailed comparison table */}
      {binaryItem?.examples && (
        <motion.div 
          className="fade"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          style={{ marginTop: '3rem', maxWidth: '900px', margin: '3rem auto 0' }}
        >
          <h3 style={{ textAlign: 'center', marginBottom: '1.5rem', color: 'var(--text)', fontSize: '1.1rem' }}>
            {cl.tableTitle}
          </h3>
          
          <div className="premium-card" style={{ padding: 0, overflow: 'hidden' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
              <thead>
                <tr style={{ background: 'rgba(0, 229, 153, 0.1)' }}>
                  {cl.tableHeaders?.map((header: string, i: number) => (
                    <th key={i} style={{ 
                      padding: '1rem', 
                      textAlign: 'left', 
                      color: 'var(--accent)',
                      fontWeight: 600,
                      borderBottom: '1px solid var(--border)'
                    }}>
                      {header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {binaryItem.examples.map((ex: Example, i: number) => (
                  <tr key={i} style={{ borderBottom: '1px solid var(--border)' }}>
                    <td style={{ padding: '0.8rem 1rem', color: 'var(--text)', fontWeight: 500 }}>
                      {ex.op}
                    </td>
                    <td style={{ padding: '0.8rem 1rem', color: 'var(--muted)' }}>
                      {ex.binary}
                    </td>
                    <td style={{ padding: '0.8rem 1rem', color: 'var(--accent)' }}>
                      {ex.ternary}
                    </td>
                    <td style={{ padding: '0.8rem 1rem' }}>
                      <span style={{ 
                        background: 'rgba(34, 197, 94, 0.2)', 
                        color: '#22c55e',
                        padding: '0.25rem 0.5rem',
                        borderRadius: '4px',
                        fontWeight: 600,
                        fontSize: '0.8rem'
                      }}>
                        {ex.savings}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </motion.div>
      )}

      {/* Quote */}
      <div className="fade" style={{ marginTop: '3rem', maxWidth: '600px', margin: '3rem auto 0' }}>
        <p style={{ fontSize: '1.1rem', fontStyle: 'italic', color: 'var(--text)', textAlign: 'center' }}>{cl.quote}</p>
      </div>
    </Section>
  )
}
