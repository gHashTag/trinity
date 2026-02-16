"use client";
import { useState, useRef, useEffect } from 'react'
import { motion, useInView } from 'framer-motion'
import Section from '../Section'

// Animated counter that counts up when scrolled into view
function AnimatedCounter({ target, prefix = '', suffix = '', decimals = 0, delay = 0, color = '#00ccff' }: {
  target: number
  prefix?: string
  suffix?: string
  decimals?: number
  delay?: number
  color?: string
}) {
  const ref = useRef<HTMLDivElement>(null)
  const isInView = useInView(ref, { once: true })
  const [display, setDisplay] = useState('0')

  useEffect(() => {
    if (!isInView) return

    const duration = 2000
    const startTime = Date.now() + delay

    const animate = () => {
      const now = Date.now()
      if (now < startTime) {
        requestAnimationFrame(animate)
        return
      }

      const elapsed = now - startTime
      const progress = Math.min(elapsed / duration, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      const current = target * eased

      if (decimals > 0) {
        setDisplay(current.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals }))
      } else {
        setDisplay(Math.round(current).toLocaleString())
      }

      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }

    requestAnimationFrame(animate)
  }, [isInView, target, delay, decimals])

  return (
    <div ref={ref} style={{
      fontSize: 'clamp(1.8rem, 4vw, 2.5rem)',
      fontWeight: 700,
      color,
      marginBottom: '0.5rem',
      fontFamily: 'JetBrains Mono, monospace'
    }}>
      {prefix}{display}{suffix}
    </div>
  )
}

// Rewards data
const REWARDS = [
  { operation: 'VSA Evolution',      reward: '0.001 $TRI/gen',        proof: 'Proof-of-Useful-Work' },
  { operation: 'Navigation',         reward: '0.0001 $TRI/step',      proof: 'Proof-of-Useful-Work' },
  { operation: 'WASM Conversion',    reward: '0.01 $TRI/conv',        proof: 'Proof-of-Useful-Work' },
  { operation: 'Benchmark',          reward: '0.005 $TRI/run',        proof: 'Proof-of-Useful-Work' },
  { operation: 'Storage Hosting',    reward: '0.00005 $TRI/shard/hr', proof: 'Proof-of-Storage' },
  { operation: 'Storage Retrieval',  reward: '0.0005 $TRI/retrieval', proof: 'Proof-of-Storage' },
]

// Glass morphism style
const glassStyle: React.CSSProperties = {
  background: 'rgba(255, 255, 255, 0.05)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  border: '1px solid rgba(255, 255, 255, 0.1)',
  borderRadius: '12px',
}

export default function DePINSection() {
  const [hoursPerDay, setHoursPerDay] = useState(8)

  // Earnings calculation
  // base_rate: average across all operation types weighted by frequency
  const baseRate = 0.85 // $TRI per hour (blended average across all operations)
  const bonusMultiplier = 1.2 // Early adopter bonus
  const monthlyEarnings = baseRate * hoursPerDay * 30 * bonusMultiplier

  return (
    <Section id="depin">
      <div className="tight fade" style={{ textAlign: 'center', marginBottom: '3rem' }}>
        <h2 style={{
          fontSize: 'clamp(1.8rem, 5vw, 2.8rem)',
          fontWeight: 700,
          marginBottom: '1rem',
          background: 'linear-gradient(135deg, #ffd700, #00ccff)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text',
        }}>
          DePIN Network
        </h2>
        <p style={{ color: 'var(--muted)', fontSize: 'clamp(0.9rem, 2.5vw, 1.1rem)' }}>
          Earn <span style={{ color: '#ffd700', fontWeight: 600 }}>$TRI</span> by Running a Node
        </p>
      </div>

      {/* Stats Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
        gap: '1.5rem',
        maxWidth: '1000px',
        margin: '0 auto 4rem',
      }}>
        {/* Active Nodes */}
        <motion.div
          style={{ ...glassStyle, padding: '2rem 1.5rem', textAlign: 'center' }}
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0 }}
          viewport={{ once: true }}
        >
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.75rem' }}>
            Active Nodes
          </div>
          <AnimatedCounter target={1247} color="#00ccff" delay={0} />
          <div style={{ fontSize: '0.8rem', color: 'rgba(0, 204, 255, 0.6)' }}>worldwide</div>
        </motion.div>

        {/* Total $TRI Earned */}
        <motion.div
          style={{ ...glassStyle, padding: '2rem 1.5rem', textAlign: 'center' }}
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.15 }}
          viewport={{ once: true }}
        >
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.75rem' }}>
            Total $TRI Earned
          </div>
          <AnimatedCounter target={2847392} color="#ffd700" delay={200} />
          <div style={{ fontSize: '0.8rem', color: 'rgba(255, 215, 0, 0.6)' }}>by node operators</div>
        </motion.div>

        {/* Storage Hosted */}
        <motion.div
          style={{ ...glassStyle, padding: '2rem 1.5rem', textAlign: 'center' }}
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          viewport={{ once: true }}
        >
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.75rem' }}>
            Storage Hosted
          </div>
          <AnimatedCounter target={12.4} suffix=" TB" decimals={1} color="#00ccff" delay={400} />
          <div style={{ fontSize: '0.8rem', color: 'rgba(0, 204, 255, 0.6)' }}>distributed storage</div>
        </motion.div>
      </div>

      {/* Rewards Table */}
      <motion.div
        style={{
          ...glassStyle,
          maxWidth: '900px',
          margin: '0 auto 4rem',
          padding: 'clamp(1rem, 4vw, 2rem)',
          overflow: 'hidden',
        }}
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        viewport={{ once: true }}
      >
        <h3 style={{
          fontSize: 'clamp(1rem, 3vw, 1.3rem)',
          fontWeight: 600,
          color: 'var(--text)',
          marginBottom: '1.5rem',
          textAlign: 'center'
        }}>
          Node Reward Structure
        </h3>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 'clamp(0.75rem, 2vw, 0.9rem)' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.15)' }}>
                <th style={{ padding: '0.75rem 1rem', textAlign: 'left', color: 'var(--muted)', fontWeight: 500, textTransform: 'uppercase', fontSize: '0.7rem', letterSpacing: '0.1em' }}>
                  Operation
                </th>
                <th style={{ padding: '0.75rem 1rem', textAlign: 'left', color: 'var(--muted)', fontWeight: 500, textTransform: 'uppercase', fontSize: '0.7rem', letterSpacing: '0.1em' }}>
                  Reward
                </th>
                <th style={{ padding: '0.75rem 1rem', textAlign: 'left', color: 'var(--muted)', fontWeight: 500, textTransform: 'uppercase', fontSize: '0.7rem', letterSpacing: '0.1em' }}>
                  Proof Type
                </th>
              </tr>
            </thead>
            <tbody>
              {REWARDS.map((row, i) => (
                <motion.tr
                  key={row.operation}
                  style={{
                    borderBottom: i < REWARDS.length - 1 ? '1px solid rgba(255, 255, 255, 0.05)' : 'none',
                  }}
                  initial={{ opacity: 0, x: -20 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  transition={{ delay: i * 0.08, duration: 0.4 }}
                  viewport={{ once: true }}
                >
                  <td style={{ padding: '0.75rem 1rem', color: 'var(--text)', fontWeight: 500 }}>
                    {row.operation}
                  </td>
                  <td style={{ padding: '0.75rem 1rem', color: '#ffd700', fontWeight: 600, fontFamily: 'JetBrains Mono, monospace', fontSize: '0.85em' }}>
                    {row.reward}
                  </td>
                  <td style={{ padding: '0.75rem 1rem' }}>
                    <span style={{
                      color: row.proof === 'Proof-of-Storage' ? '#aa66ff' : '#aa66ff',
                      background: 'rgba(170, 102, 255, 0.1)',
                      padding: '0.2rem 0.6rem',
                      borderRadius: '4px',
                      fontSize: '0.8em',
                      fontWeight: 500,
                      whiteSpace: 'nowrap',
                    }}>
                      {row.proof}
                    </span>
                  </td>
                </motion.tr>
              ))}
            </tbody>
          </table>
        </div>
      </motion.div>

      {/* Earnings Calculator */}
      <motion.div
        style={{
          ...glassStyle,
          maxWidth: '600px',
          margin: '0 auto 3rem',
          padding: 'clamp(1.5rem, 4vw, 2.5rem)',
        }}
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        viewport={{ once: true }}
      >
        <h3 style={{
          fontSize: 'clamp(1rem, 3vw, 1.3rem)',
          fontWeight: 600,
          color: 'var(--text)',
          marginBottom: '1.5rem',
          textAlign: 'center'
        }}>
          Earnings Calculator
        </h3>

        {/* Slider */}
        <div style={{ marginBottom: '2rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--muted)' }}>Hours per day</span>
            <span style={{ fontSize: '0.85rem', color: '#00ccff', fontWeight: 600, fontFamily: 'JetBrains Mono, monospace' }}>
              {hoursPerDay}h
            </span>
          </div>
          <input
            type="range"
            min="1"
            max="24"
            value={hoursPerDay}
            onChange={(e) => setHoursPerDay(parseInt(e.target.value))}
            style={{
              width: '100%',
              accentColor: '#00ccff',
              cursor: 'pointer',
              height: '6px',
            }}
          />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '0.25rem' }}>
            <span style={{ fontSize: '0.7rem', color: 'var(--muted)', opacity: 0.5 }}>1h</span>
            <span style={{ fontSize: '0.7rem', color: 'var(--muted)', opacity: 0.5 }}>24h</span>
          </div>
        </div>

        {/* Result */}
        <div style={{
          textAlign: 'center',
          padding: '1.5rem',
          background: 'rgba(255, 215, 0, 0.05)',
          border: '1px solid rgba(255, 215, 0, 0.2)',
          borderRadius: '8px',
        }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.5rem' }}>
            Estimated Monthly Earnings
          </div>
          <div style={{
            fontSize: 'clamp(2rem, 8vw, 3rem)',
            fontWeight: 700,
            color: '#ffd700',
            fontFamily: 'JetBrains Mono, monospace',
            marginBottom: '0.5rem'
          }}>
            {monthlyEarnings.toLocaleString(undefined, { maximumFractionDigits: 0 })} <span style={{ fontSize: '0.5em', color: 'rgba(255, 215, 0, 0.7)' }}>$TRI</span>
          </div>
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', lineHeight: 1.6 }}>
            {hoursPerDay}h/day x 30 days x {bonusMultiplier}x early adopter bonus
          </div>
        </div>

        {/* Breakdown */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '1rem',
          marginTop: '1.5rem',
        }}>
          <div style={{
            padding: '1rem',
            background: 'rgba(0, 204, 255, 0.05)',
            borderRadius: '8px',
            textAlign: 'center',
          }}>
            <div style={{ fontSize: '0.7rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '0.3rem' }}>Daily</div>
            <div style={{ fontSize: '1.1rem', color: '#00ccff', fontWeight: 600, fontFamily: 'JetBrains Mono, monospace' }}>
              {(baseRate * hoursPerDay * bonusMultiplier).toLocaleString(undefined, { maximumFractionDigits: 1 })}
            </div>
            <div style={{ fontSize: '0.7rem', color: 'rgba(0, 204, 255, 0.5)' }}>$TRI</div>
          </div>
          <div style={{
            padding: '1rem',
            background: 'rgba(170, 102, 255, 0.05)',
            borderRadius: '8px',
            textAlign: 'center',
          }}>
            <div style={{ fontSize: '0.7rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '0.3rem' }}>Yearly</div>
            <div style={{ fontSize: '1.1rem', color: '#aa66ff', fontWeight: 600, fontFamily: 'JetBrains Mono, monospace' }}>
              {(monthlyEarnings * 12).toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
            <div style={{ fontSize: '0.7rem', color: 'rgba(170, 102, 255, 0.5)' }}>$TRI</div>
          </div>
        </div>
      </motion.div>

      {/* CTA Button */}
      <div className="fade" style={{ textAlign: 'center' }}>
        <motion.a
          href="/trinity/docs/depin/quickstart"
          style={{
            display: 'inline-block',
            padding: '1rem 2.5rem',
            background: 'linear-gradient(135deg, rgba(255, 215, 0, 0.15), rgba(0, 204, 255, 0.15))',
            border: '1px solid rgba(255, 215, 0, 0.4)',
            borderRadius: '8px',
            color: '#ffd700',
            textDecoration: 'none',
            fontSize: '1rem',
            fontWeight: 600,
            letterSpacing: '0.05em',
            transition: 'all 0.3s ease',
          }}
          whileHover={{
            scale: 1.05,
            boxShadow: '0 0 30px rgba(255, 215, 0, 0.2)',
          }}
          whileTap={{ scale: 0.98 }}
        >
          Run a Node
        </motion.a>
        <div style={{ fontSize: '0.75rem', color: 'var(--muted)', marginTop: '1rem', opacity: 0.6 }}>
          Minimum requirements: 4GB RAM, 50GB storage, stable internet
        </div>
      </div>
    </Section>
  )
}
