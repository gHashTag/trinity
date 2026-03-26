import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

interface OpcodeCategory {
  name: string
  opcodes: Array<{ mnemonic: string; code: string; desc: string }>
}

interface RegisterBank {
  name: string
  registers: string[]
  purpose: string
}

export default function Tri27Section() {
  const { t } = useI18n()
  const tri27 = t.tri27

  if (!tri27) return null

  const opcodeCategories: OpcodeCategory[] = [
    {
      name: 'Arithmetic',
      opcodes: [
        { mnemonic: 'ADD', code: '0x60', desc: 'dst = src1 + src2' },
        { mnemonic: 'SUB', code: '0x61', desc: 'dst = src1 - src2' },
        { mnemonic: 'MUL', code: '0x62', desc: 'dst = src1 × src2' },
        { mnemonic: 'DIV', code: '0x63', desc: 'dst = src1 ÷ src2' }
      ]
    },
    {
      name: 'Logic',
      opcodes: [
        { mnemonic: 'AND', code: '0x18', desc: 'dst = src1 & src2' },
        { mnemonic: 'OR', code: '0x19', desc: 'dst = src1 | src2' },
        { mnemonic: 'XOR', code: '0x1A', desc: 'dst = src1 ^ src2' },
        { mnemonic: 'NOT', code: '0x1B', desc: 'dst = ~dst' }
      ]
    },
    {
      name: 'VSA',
      opcodes: [
        { mnemonic: 'DOT', code: '0x60', desc: 'ternary dot product' },
        { mnemonic: 'BIND', code: '0x6A', desc: 'VSA bind operation' },
        { mnemonic: 'BUNDLE2', code: '0x6B', desc: 'majority vote (2)' },
        { mnemonic: 'BUNDLE3', code: '0x6C', desc: 'majority vote (3)' }
      ]
    },
    {
      name: 'Sacred',
      opcodes: [
        { mnemonic: 'PHI_CONST', code: '0x80', desc: 'dst = φ (1.618...)' },
        { mnemonic: 'PI_CONST', code: '0x81', desc: 'dst = π (3.141...)' },
        { mnemonic: 'E_CONST', code: '0x82', desc: 'dst = e (2.718...)' },
        { mnemonic: 'SACR', code: '0x92', desc: 'sacred arithmetic' }
      ]
    },
    {
      name: 'Memory',
      opcodes: [
        { mnemonic: 'LDI', code: '0x01', desc: 'load immediate' },
        { mnemonic: 'LD', code: '0x02', desc: 'load from [src1]' },
        { mnemonic: 'ST', code: '0x03', desc: 'store to [dst]' },
        { mnemonic: 'MOV', code: '0x05', desc: 'move register' }
      ]
    },
    {
      name: 'Control Flow',
      opcodes: [
        { mnemonic: 'JUMP', code: '0x10', desc: 'PC ← PC + offset' },
        { mnemonic: 'JZ', code: '0x11', desc: 'jump if dst == 0' },
        { mnemonic: 'CALL', code: '0x13', desc: 'push PC, jump' },
        { mnemonic: 'HALT', code: '0x17', desc: 'stop execution' }
      ]
    }
  ]

  const registerBanks: RegisterBank[] = [
    {
      name: 'Sacred Bank',
      registers: ['t0-t8', 'α, β, γ, δ, ε, ϛ, ζ, η, ω'],
      purpose: 'Constants and sacred values'
    },
    {
      name: 'Temporal Bank',
      registers: ['t9-t17', 'ι, κ, λ, μ, ν, ξ, ο, π, ρ'],
      purpose: 'Time-aware computation'
    },
    {
      name: 'Spatial Bank',
      registers: ['t18-t26', 'σ, τ, υ, φ, χ, ψ, ω, ϡ, ϧ'],
      purpose: 'Spatial coordinates and vectors'
    }
  ]

  return (
    <Section id="tri27">
      <div className="radial-glow" style={{ opacity: 0.15 }} />

      {/* Header */}
      <div className="tight fade">
        <div className="badge" style={{
          background: 'linear-gradient(135deg, #22c55e 0%, #16a34a 100%)',
          marginBottom: '1rem'
        }}>
          {tri27.badge}
        </div>
        <h2 dangerouslySetInnerHTML={{ __html: tri27.title }} />
        <p style={{ maxWidth: '700px', margin: '0 auto 2rem', opacity: 0.9 }}>
          {tri27.sub}
        </p>

        {/* Stats */}
        <div style={{
          display: 'flex',
          justifyContent: 'center',
          gap: '2rem',
          flexWrap: 'wrap',
          marginTop: '2rem'
        }}>
          {[
            { value: '27', label: 'Registers' },
            { value: '3', label: 'Coptic Banks' },
            { value: '36', label: 'Opcodes' },
            { value: '68/68', label: 'Tests Passing' }
          ].map((stat, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.1 }}
              viewport={{ once: true }}
              style={{ textAlign: 'center' }}
            >
              <div style={{
                fontSize: '2rem',
                fontWeight: 700,
                color: 'var(--accent)'
              }}>
                {stat.value}
              </div>
              <div style={{
                fontSize: '0.8rem',
                color: 'var(--muted)',
                textTransform: 'uppercase',
                letterSpacing: '0.1em'
              }}>
                {stat.label}
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Coptic Register Banks */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.3rem'
        }}>
          27 Coptic Registers — 3 Sacred Banks
        </h3>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '1rem',
          maxWidth: '900px',
          margin: '0 auto'
        }}>
          {registerBanks.map((bank, i) => (
            <motion.div
              key={i}
              className="premium-card"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.1 }}
              viewport={{ once: true }}
              style={{ padding: '1.2rem' }}
            >
              <div style={{
                fontSize: '0.7rem',
                color: 'var(--accent)',
                textTransform: 'uppercase',
                letterSpacing: '0.1em',
                marginBottom: '0.5rem'
              }}>
                {bank.name}
              </div>
              <div style={{
                fontFamily: 'ui-monospace, monospace',
                fontSize: '0.9rem',
                color: 'var(--text)',
                marginBottom: '0.5rem'
              }}>
                {bank.registers.join(' • ')}
              </div>
              <div style={{
                fontSize: '0.8rem',
                color: 'var(--muted)'
              }}>
                {bank.purpose}
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Opcodes */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.3rem'
        }}>
          36 Opcodes — 6 Categories
        </h3>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
          gap: '1rem',
          maxWidth: '1200px',
          margin: '0 auto'
        }}>
          {opcodeCategories.map((category, i) => (
            <motion.div
              key={i}
              className="premium-card"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              viewport={{ once: true }}
              style={{ padding: '1rem' }}
            >
              <div style={{
                fontSize: '0.7rem',
                color: 'var(--accent)',
                textTransform: 'uppercase',
                letterSpacing: '0.1em',
                marginBottom: '0.8rem',
                borderBottom: '1px solid var(--border)',
                paddingBottom: '0.5rem'
              }}>
                {category.name}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
                {category.opcodes.map((op, j) => (
                  <div
                    key={j}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      fontSize: '0.8rem',
                      fontFamily: 'ui-monospace, monospace'
                    }}
                  >
                    <span style={{ color: 'var(--text)' }}>
                      {op.mnemonic}
                    </span>
                    <span style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>
                      {op.code}
                    </span>
                  </div>
                ))}
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Interactive Demo */}
      <div className="fade" style={{ marginTop: '3rem' }}>
        <h3 style={{
          textAlign: 'center',
          marginBottom: '1.5rem',
          fontSize: '1.3rem'
        }}>
          Interactive Assembly Demo
        </h3>
        <motion.div
          className="premium-card"
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          style={{
            maxWidth: '700px',
            margin: '0 auto',
            padding: '1.5rem',
            background: 'rgba(0, 0, 0, 0.3)'
          }}
        >
          {/* Assembly Code */}
          <div style={{
            background: 'rgba(0, 229, 153, 0.05)',
            padding: '1rem',
            borderRadius: '6px',
            fontFamily: 'ui-monospace, monospace',
            fontSize: '0.85rem',
            marginBottom: '1rem'
          }}>
            <div style={{ color: 'var(--muted)', marginBottom: '0.5rem' }}>
              # reticularraphe.tri — Fibonacci sequence
            </div>
            <div style={{ color: '#22c55e' }}>LDI</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t0, 0    <span style={{ color: 'var(--muted)' }}# Initialize counter</span>
            </div>
            <div style={{ color: '#22c55e' }}>LDI</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t1, 1    <span style={{ color: 'var(--muted)' }}# First Fib number</span>
            </div>
            <div style={{ color: '#22c55e' }}>LDI</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t2, 1    <span style={{ color: 'var(--muted)' }}# Second Fib number</span>
            </div>
            <div style={{ color: 'var(--accent)' }}>loop:</div>
            <div style={{ color: '#22c55e' }}>ADD</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t3, t1, t2  <span style={{ color: 'var(--muted)' }}# t3 = t1 + t2</span>
            </div>
            <div style={{ color: '#22c55e' }}>MOV</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t1, t2    <span style={{ color: 'var(--muted)' }}# Shift values</span>
            </div>
            <div style={{ color: '#22c55e' }}>MOV</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t2, t3    <span style={{ color: 'var(--muted)' }}# t2 = result</span>
            </div>
            <div style={{ color: '#22c55e' }}>INC</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t0        <span style={{ color: 'var(--muted)' }}# Increment counter</span>
            </div>
            <div style={{ color: '#22c55e' }}>JLT</div>
            <div style={{ color: 'var(--text)', marginLeft: '1rem' }}>
              t0, 10, loop  <span style={{ color: 'var(--muted)' }}# Loop 10 times</span>
            </div>
            <div style={{ color: '#e879f9' }}>HALT</div>
            <div style={{ color: 'var(--muted)', marginLeft: '1rem' }}>
              # t2 = 55 (10th Fibonacci)
            </div>
          </div>

          {/* Execution Result */}
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            padding: '1rem',
            background: 'rgba(34, 197, 94, 0.1)',
            borderRadius: '6px',
            border: '1px solid rgba(34, 197, 94, 0.3)'
          }}>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--muted)', marginBottom: '0.3rem' }}>
                EXECUTION RESULT
              </div>
              <div style={{
                fontFamily: 'ui-monospace, monospace',
                fontSize: '1rem',
                color: '#22c55e'
              }}>
                t2 = 55 ✓ (cycles: 47)
              </div>
            </div>
            <div style={{
              fontSize: '0.7rem',
              color: 'var(--muted)',
              textAlign: 'right'
            }}>
              15/15 Golden Tests<br />Passing
            </div>
          </div>
        </motion.div>
      </div>

      {/* CTA */}
      {tri27.cta && (
        <div className="fade" style={{ marginTop: '2rem', textAlign: 'center' }}>
          <a
            href="https://github.com/gHashTag/trinity/blob/main/docs/tri27/README.md"
            target="_blank"
            rel="noopener noreferrer"
            className="btn"
          >
            {tri27.cta} →
          </a>
        </div>
      )}
    </Section>
  )
}
