import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

interface StackLevel {
  level: number
  name: string
  description: string
  color: string
  details: string[]
}

export default function StackSection() {
  const { t } = useI18n()
  const stack = t.stack

  if (!stack) return null

  const levels: StackLevel[] = [
    {
      level: 8,
      name: 'HSLM Training',
      description: 'Distributed LLM training farm',
      color: '#22c55e',
      details: ['152 Railway services', '8 accounts', 'HSLM 1.95M params']
    },
    {
      level: 7,
      name: 'Queen Lotus Cycle',
      description: 'Self-learning purification system',
      color: '#16a34a',
      details: ['5-state purification', '6 PFC cells', 'ARAS vigilance']
    },
    {
      level: 6,
      name: 'Sacred ALU',
      description: 'GF16/TF3 arithmetic unit',
      color: '#e879f9',
      details: ['FPGA backend', 'φ-structured constants', 'Zero DSP']
    },
    {
      level: 5,
      name: 'TRI-27 ISA',
      description: 'Ternary RISC processor',
      color: '#a855f7',
      details: ['27 registers', '36 opcodes', 'Coptic alphabet']
    },
    {
      level: 4,
      name: 'Tri Language',
      description: 'DSL for code generation',
      color: '#6366f1',
      details: ['ADT enums', 'Pattern matching', 'Linear types']
    },
    {
      level: 3,
      name: 'zig-half',
      description: '16-bit floating point',
      color: '#3b82f6',
      details: ['IEEE 754-like', 'CPU native', 'Fast conversion']
    },
    {
      level: 2,
      name: 'LLVM IR',
      description: 'Intermediate representation',
      color: '#0ea5e9',
      details: ['Planned', 'Cross-platform', 'Optimized']
    },
    {
      level: 1,
      name: 'FPGA Bitstream',
      description: 'Hardware implementation',
      color: '#06b6d4',
      details: ['XC7A100T', 'openXC7 toolchain', '63 tok/s @ 92MHz']
    }
  ]

  return (
    <Section id="stack">
      <div className="radial-glow" style={{ opacity: 0.15 }} />

      {/* Header */}
      <div className="tight fade">
        <div className="badge" style={{
          background: 'linear-gradient(135deg, #a855f7 0%, #6366f1 100%)',
          marginBottom: '1rem'
        }}>
          {stack.badge || 'EIGHT-LEVEL STACK'}
        </div>
        <h2 dangerouslySetInnerHTML={{ __html: stack.title || 'Trinity <span class="grad">Eight-Level</span> Stack' }} />
        <p style={{ maxWidth: '700px', margin: '0 auto 2rem', opacity: 0.9 }}>
          {stack.sub || 'From distributed training to FPGA hardware — complete AI stack in pure Zig'}
        </p>
      </div>

      {/* Stack Visualization */}
      <div className="fade" style={{
        maxWidth: '800px',
        margin: '3rem auto 0',
        padding: '0 1rem'
      }}>
        {/* Vertical Stack */}
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '0.5rem',
          position: 'relative'
        }}>
          {/* Connection Line */}
          <div style={{
            position: 'absolute',
            left: '50%',
            top: '10%',
            bottom: '10%',
            width: '2px',
            background: 'linear-gradient(to bottom, #22c55e, #06b6d4)',
            transform: 'translateX(-50%)',
            zIndex: 0
          }} />

          {levels.map((level, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, x: i % 2 === 0 ? -50 : 50 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.08 }}
              viewport={{ once: true }}
              style={{
                position: 'relative',
                zIndex: 1
              }}
            >
              <div
                className="premium-card"
                style={{
                  padding: '1rem 1.5rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '1rem',
                  background: `linear-gradient(135deg, ${level.color}15 0%, ${level.color}05 100%)`,
                  borderLeft: `4px solid ${level.color}`,
                  marginLeft: i % 2 === 0 ? '0' : 'auto',
                  marginRight: i % 2 === 0 ? 'auto' : '0',
                  maxWidth: '500px'
                }}
              >
                {/* Level Badge */}
                <div style={{
                  width: '40px',
                  height: '40px',
                  borderRadius: '50%',
                  background: level.color,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '0.9rem',
                  fontWeight: 700,
                  color: '#fff',
                  flexShrink: 0
                }}>
                  L{level.level}
                </div>

                {/* Content */}
                <div style={{ flex: 1 }}>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem',
                    marginBottom: '0.3rem'
                  }}>
                    <h4 style={{
                      margin: 0,
                      fontSize: '1rem',
                      color: 'var(--text)'
                    }}>
                      {level.name}
                    </h4>
                  </div>
                  <p style={{
                    margin: 0,
                    fontSize: '0.8rem',
                    color: 'var(--muted)'
                  }}>
                    {level.description}
                  </p>
                  <div style={{
                    display: 'flex',
                    gap: '0.5rem',
                    marginTop: '0.5rem',
                    flexWrap: 'wrap'
                  }}>
                    {level.details.map((detail, j) => (
                      <span
                        key={j}
                        style={{
                          fontSize: '0.7rem',
                          padding: '0.2rem 0.5rem',
                          background: `${level.color}20`,
                          borderRadius: '3px',
                          color: level.color
                        }}
                      >
                        {detail}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>

        {/* Stack Stats */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          style={{
            marginTop: '3rem',
            display: 'flex',
            justifyContent: 'center',
            gap: '2rem',
            flexWrap: 'wrap'
          }}
        >
          {[
            { value: '8', label: 'Levels', color: '#22c55e' },
            { value: '152', label: 'Training Services', color: '#16a34a' },
            { value: '27', label: 'TRI-27 Registers', color: '#a855f7' },
            { value: '36', label: 'Opcodes', color: '#e879f9' },
            { value: '0%', label: 'DSP Usage', color: '#06b6d4' }
          ].map((stat, i) => (
            <div
              key={i}
              style={{
                textAlign: 'center',
                padding: '1rem 1.5rem',
                background: 'rgba(255, 255, 255, 0.03)',
                borderRadius: '8px',
                border: '1px solid var(--border)'
              }}
            >
              <div style={{
                fontSize: '1.8rem',
                fontWeight: 700,
                color: stat.color
              }}>
                {stat.value}
              </div>
              <div style={{
                fontSize: '0.75rem',
                color: 'var(--muted)',
                textTransform: 'uppercase',
                letterSpacing: '0.05em'
              }}>
                {stat.label}
              </div>
            </div>
          ))}
        </motion.div>
      </div>

      {/* Flow Diagram */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.1rem',
          color: 'var(--muted)'
        }}>
          Data Flow: Training → Inference → Hardware
        </h3>
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          className="premium-card"
          style={{
            maxWidth: '900px',
            margin: '0 auto',
            padding: '1.5rem',
            background: 'rgba(0, 0, 0, 0.3)'
          }}
        >
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '1rem',
            flexWrap: 'wrap',
            fontSize: '0.85rem'
          }}>
            {[
              'Training Data',
              '→',
              'HSLM Train',
              '→',
              'Checkpoint',
              '→',
              'TRI-27 Compile',
              '→',
              'Verilog',
              '→',
              'FPGA Bitstream',
              '→',
              'Inference'
            ].map((item, i) => (
              <span
                key={i}
                style={{
                  color: item === '→' ? 'var(--muted)' : 'var(--text)',
                  fontWeight: item === '→' ? 'normal' : 600,
                  padding: item === '→' ? '0' : '0.4rem 0.8rem',
                  background: item === '→' ? 'transparent' : 'rgba(34, 197, 94, 0.1)',
                  borderRadius: item === '→' ? '0' : '4px',
                  fontSize: item === '→' ? '1.2rem' : '0.8rem'
                }}
              >
                {item}
              </span>
            ))}
          </div>
        </motion.div>
      </div>

      {/* CTA */}
      {stack.cta && (
        <div className="fade" style={{ marginTop: '2rem', textAlign: 'center' }}>
          <a
            href="https://github.com/gHashTag/trinity/blob/main/docs/ARCHITECTURE.md"
            target="_blank"
            rel="noopener noreferrer"
            className="btn"
          >
            {stack.cta} →
          </a>
        </div>
      )}
    </Section>
  )
}
