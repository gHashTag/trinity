import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

interface PFCCell {
  id: string
  name: string
  fullName: string
  color: string
  description: string
}

interface LotusState {
  name: string
  description: string
  color: string
}

export default function BrainArchitectureSection() {
  const { t } = useI18n()
  const brain = t.brainArchitecture

  if (!brain) return null

  const pfcCells: PFCCell[] = [
    {
      id: 'dlpfc',
      name: 'dlpfc',
      fullName: 'Dorsolateral PFC',
      color: '#22c55e',
      description: 'Planning & task assignment — Episode orchestration'
    },
    {
      id: 'vmpfc',
      name: 'vmpfc',
      fullName: 'Ventromedial PFC',
      color: '#16a34a',
      description: 'Valuation & φ-weighted scoring — Value judgment'
    },
    {
      id: 'ofc',
      name: 'ofc',
      fullName: 'Orbitofrontal Cortex',
      color: '#e879f9',
      description: 'Mood inference & alerts — Emotional state'
    },
    {
      id: 'vlpfc',
      name: 'vlpfc',
      fullName: 'Ventrolateral PFC',
      color: '#a855f7',
      description: 'Focus area filtering — Attention control'
    },
    {
      id: 'dmpfc',
      name: 'dmpfc',
      fullName: 'Dorsomedial PFC',
      color: '#6366f1',
      description: 'Self-check & health grading — Meta-cognition'
    },
    {
      id: 'acc',
      name: 'acc',
      fullName: 'Anterior Cingulate',
      color: '#3b82f6',
      description: 'Conflict detection — Error monitoring'
    }
  ]

  const lotusStates: LotusState[] = [
    { name: 'Queued', description: 'Task waiting in queue', color: '#6b7280' },
    { name: 'Diagnosing', description: 'Analyzing task requirements', color: '#f59e0b' },
    { name: 'Refining', description: 'Executing purification', color: '#3b82f6' },
    { name: 'Verifying', description: 'Checking results', color: '#8b5cf6' },
    { name: 'Purified', description: 'Task complete', color: '#22c55e' },
    { name: 'Blocked', description: 'Error - needs intervention', color: '#ef4444' }
  ]

  return (
    <Section id="brain-architecture">
      <div className="radial-glow" style={{ opacity: 0.15 }} />

      {/* Header */}
      <div className="tight fade">
        <div className="badge" style={{
          background: 'linear-gradient(135deg, #e879f9 0%, #a855f7 100%)',
          marginBottom: '1rem'
        }}>
          {brain.badge || 'SELF-LEARNING SYSTEM'}
        </div>
        <h2 dangerouslySetInnerHTML={{ __html: brain.title || 'Trinity <span class="grad">S³AI</span> Brain Architecture' }} />
        <p style={{ maxWidth: '700px', margin: '0 auto 2rem', opacity: 0.9 }}>
          {brain.sub || 'Neuroanatomically-inspired AI with 6 PFC cells, Lotus Cycle purification, and ARAS vigilance'}
        </p>
      </div>

      {/* PFC Cells Grid */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.3rem'
        }}>
          Queen Prefrontal Cortex — 6 Cells
        </h3>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '1rem',
          maxWidth: '1000px',
          margin: '0 auto'
        }}>
          {pfcCells.map((cell, i) => (
            <motion.div
              key={i}
              className="premium-card"
              initial={{ opacity: 0, scale: 0.9 }}
              whileInView={{ opacity: 1, scale: 1 }}
              transition={{ delay: i * 0.08 }}
              viewport={{ once: true }}
              style={{
                padding: '1.2rem',
                borderLeft: `3px solid ${cell.color}`
              }}
            >
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                marginBottom: '0.5rem'
              }}>
                <div style={{
                  width: '8px',
                  height: '8px',
                  borderRadius: '50%',
                  background: cell.color,
                  animation: 'pulse 2s infinite'
                }} />
                <span style={{
                  fontSize: '0.7rem',
                  color: cell.color,
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em',
                  fontFamily: 'ui-monospace, monospace'
                }}>
                  {cell.name}
                </span>
              </div>
              <h4 style={{
                margin: '0 0 0.5rem 0',
                fontSize: '1rem',
                color: 'var(--text)'
              }}>
                {cell.fullName}
              </h4>
              <p style={{
                margin: 0,
                fontSize: '0.8rem',
                color: 'var(--muted)',
                lineHeight: 1.4
              }}>
                {cell.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Lotus Cycle */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.3rem'
        }}>
          Lotus Cycle — 5-State Purification
        </h3>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="premium-card"
          style={{
            maxWidth: '800px',
            margin: '0 auto',
            padding: '1.5rem',
            background: 'rgba(0, 0, 0, 0.3)'
          }}
        >
          {/* State Flow */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '0.5rem',
            flexWrap: 'wrap',
            marginBottom: '1.5rem'
          }}>
            {lotusStates.map((state, i) => (
              <div
                key={i}
                style={{
                  display: 'flex',
                  alignItems: 'center'
                }}
              >
                <div style={{
                  padding: '0.5rem 1rem',
                  background: `${state.color}20`,
                  border: `1px solid ${state.color}`,
                  borderRadius: '6px',
                  fontSize: '0.8rem',
                  color: state.color,
                  fontWeight: 600,
                  whiteSpace: 'nowrap'
                }}>
                  {state.name}
                </div>
                {i < lotusStates.length - 1 && (
                  <span style={{
                    color: 'var(--muted)',
                    margin: '0 0.3rem',
                    fontSize: '1.2rem'
                  }}>
                    →
                  </span>
                )}
              </div>
            ))}
          </div>

          {/* State Descriptions */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '0.8rem'
          }}>
            {lotusStates.map((state, i) => (
              <div
                key={i}
                style={{
                  padding: '0.8rem',
                  background: 'rgba(255, 255, 255, 0.03)',
                  borderRadius: '6px',
                  borderLeft: `2px solid ${state.color}`
                }}
              >
                <div style={{
                  fontSize: '0.75rem',
                  color: state.color,
                  fontWeight: 600,
                  marginBottom: '0.3rem'
                }}>
                  {state.name}
                </div>
                <div style={{
                  fontSize: '0.75rem',
                  color: 'var(--muted)'
                }}>
                  {state.description}
                </div>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* ARAS Vigilance */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.3rem'
        }}>
          ARAS Vigilance System
        </h3>
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          style={{
            maxWidth: '700px',
            margin: '0 auto',
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: '1rem'
          }}
        >
          {[
            { label: 'Sweep Interval', value: '5 min', color: '#22c55e' },
            { label: 'Health Check', value: '12 dims', color: '#3b82f6' },
            { label: 'φ-Structure', value: 'φ² + 1/φ² = 3', color: '#e879f9' }
          ].map((metric, i) => (
            <div
              key={i}
              className="premium-card"
              style={{
                padding: '1rem',
                textAlign: 'center',
                background: `linear-gradient(135deg, ${metric.color}15 0%, ${metric.color}05 100%)`
              }}
            >
              <div style={{
                fontSize: '0.7rem',
                color: 'var(--muted)',
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
                marginBottom: '0.5rem'
              }}>
                {metric.label}
              </div>
              <div style={{
                fontSize: '1.2rem',
                fontWeight: 700,
                color: metric.color
              }}>
                {metric.value}
              </div>
            </div>
          ))}
        </motion.div>
      </div>

      {/* Trinity Identity */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="premium-card"
          style={{
            maxWidth: '500px',
            margin: '0 auto',
            padding: '1.5rem',
            textAlign: 'center',
            background: 'linear-gradient(135deg, rgba(232, 121, 249, 0.1) 0%, rgba(168, 85, 247, 0.1) 100%)',
            border: '1px solid rgba(232, 121, 249, 0.3)'
          }}
        >
          <div style={{
            fontSize: '0.75rem',
            color: 'var(--muted)',
            textTransform: 'uppercase',
            letterSpacing: '0.1em',
            marginBottom: '0.5rem'
          }}>
            Trinity Identity
          </div>
          <div style={{
            fontFamily: 'ui-monospace, monospace',
            fontSize: '1.5rem',
            fontWeight: 700,
            color: 'var(--accent)',
            marginBottom: '0.5rem'
          }}>
            φ² + 1/φ² = 3
          </div>
          <div style={{
            fontSize: '0.85rem',
            color: 'var(--muted)'
          }}>
            Mathematical foundation of Trinity architecture
          </div>
        </motion.div>
      </div>

      {/* CTA */}
      {brain.cta && (
        <div className="fade" style={{ marginTop: '2rem', textAlign: 'center' }}>
          <a
            href="https://github.com/gHashTag/trinity/blob/main/docs/research/neuroanatomical_architecture.md"
            target="_blank"
            rel="noopener noreferrer"
            className="btn"
          >
            {brain.cta} →
          </a>
        </div>
      )}
    </Section>
  )
}
