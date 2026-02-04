"use client";
import { motion, useInView } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import ComparisonChart from '../charts/ComparisonChart'
import { useRef, useEffect, useState } from 'react'

// Animated counter component
function AnimatedValue({ value, delay }: { value: string; delay: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const isInView = useInView(ref, { once: true })
  const [displayValue, setDisplayValue] = useState('0')
  
  useEffect(() => {
    if (!isInView) return
    
    // Extract numeric part and suffix (e.g., "8x" -> 8, "x")
    const match = value.match(/^([\d.]+)(.*)$/)
    if (!match) {
      setDisplayValue(value)
      return
    }
    
    const targetNum = parseFloat(match[1])
    const suffix = match[2]
    const duration = 1500
    const startTime = Date.now() + delay * 1000
    
    const animate = () => {
      const now = Date.now()
      if (now < startTime) {
        requestAnimationFrame(animate)
        return
      }
      
      const elapsed = now - startTime
      const progress = Math.min(elapsed / duration, 1)
      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      const current = targetNum * eased
      
      if (Number.isInteger(targetNum)) {
        setDisplayValue(Math.round(current) + suffix)
      } else {
        setDisplayValue(current.toFixed(1) + suffix)
      }
      
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    
    requestAnimationFrame(animate)
  }, [isInView, value, delay])
  
  return (
    <div ref={ref} style={{ 
      fontSize: 'clamp(1.8rem, 4vw, 2.5rem)', 
      fontWeight: 600, 
      color: 'var(--accent)', 
      marginBottom: '0.5rem',
      background: 'linear-gradient(135deg, var(--accent), #00b377)',
      WebkitBackgroundClip: 'text',
      WebkitTextFillColor: 'transparent',
      backgroundClip: 'text'
    }}>
      {displayValue}
    </div>
  )
}

export default function BenchmarksSection() {
  const { t } = useI18n()
  const b = t.benchmarks

  if (!b) return null

  return (
    <Section id="benchmarks">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: b.title }} />
        <p>{b.sub}</p>
      </div>
      
      {/* GPU Verification Badge */}
      {b.gpuVerified && (
        <motion.div 
          className="fade"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          viewport={{ once: true }}
          style={{
            background: 'linear-gradient(135deg, rgba(0, 229, 153, 0.1), rgba(0, 179, 119, 0.05))',
            border: '1px solid var(--accent)',
            borderRadius: '12px',
            padding: '1.5rem',
            marginTop: '2rem',
            marginBottom: '2rem',
            maxWidth: '800px',
            margin: '2rem auto'
          }}
        >
          <div style={{ textAlign: 'center', marginBottom: '1rem' }}>
            <span style={{ 
              background: 'var(--accent)', 
              color: '#000', 
              padding: '0.3rem 1rem', 
              borderRadius: '20px',
              fontSize: '0.85rem',
              fontWeight: 600
            }}>
              {b.gpuVerified.badge}
            </span>
          </div>
          <p style={{ textAlign: 'center', color: 'var(--muted)', fontSize: '0.85rem', marginBottom: '1rem' }}>
            {b.gpuVerified.note}
          </p>
          <div style={{ 
            display: 'grid', 
            gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', 
            gap: '1rem' 
          }}>
            {b.gpuVerified.gpus?.map((gpu: { name: string; tokens: string; noise: string; power: string }, i: number) => (
              <div key={i} style={{ 
                background: 'rgba(0, 0, 0, 0.3)', 
                padding: '1rem', 
                borderRadius: '8px',
                textAlign: 'center'
              }}>
                <div style={{ fontWeight: 600, color: 'var(--accent)', marginBottom: '0.5rem' }}>{gpu.name}</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text)' }}>{gpu.tokens}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>tokens/s</div>
                <div style={{ fontSize: '0.8rem', color: 'var(--muted)', marginTop: '0.5rem' }}>
                  Noise: {gpu.noise} | {gpu.power}
                </div>
              </div>
            ))}
          </div>
        </motion.div>
      )}
      
      <div className="fade" style={{ 
        marginTop: '3rem', 
        marginBottom: '4rem',
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: '1rem',
        maxWidth: '1000px',
        margin: '3rem auto 4rem'
      }}>
        {b.metrics?.map((item: { value: string; label: string; desc: string }, i: number) => (
          <motion.div 
            key={i} 
            className="premium-card" 
            style={{ textAlign: 'center', padding: '1.5rem 1rem' }}
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            transition={{ delay: i * 0.1, duration: 0.5 }}
            viewport={{ once: true }}
          >
            <AnimatedValue value={item.value} delay={i * 0.15} />
            <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text)', marginBottom: '0.3rem' }}>{item.label}</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--muted)', lineHeight: 1.4 }}>{item.desc}</div>
          </motion.div>
        ))}
      </div>

      <ComparisonChart 
        data={b.comparison?.rows || []} 
        title={t.charts?.comparisonTitle} 
        note={t.charts?.comparisonNote} 
      />

      <div className="fade" style={{ textAlign: 'center', marginTop: '3rem' }}>
        <a 
          href={b.url || "https://github.com/gHashTag/trinity"} 
          target="_blank" 
          rel="noopener noreferrer"
          style={{
            display: 'inline-block',
            padding: '0.8rem 2rem',
            border: '1px solid var(--accent)',
            borderRadius: '4px',
            color: 'var(--accent)',
            textDecoration: 'none',
            fontSize: '0.9rem',
            transition: 'all 0.2s ease',
            background: 'rgba(0, 229, 153, 0.05)'
          }}
          onMouseOver={(e) => e.currentTarget.style.background = 'rgba(0, 229, 153, 0.1)'}
          onMouseOut={(e) => e.currentTarget.style.background = 'rgba(0, 229, 153, 0.05)'}
        >
          {b.verifyLink || "Verify on GitHub"}
        </a>
      </div>
    </Section>
  )
}
