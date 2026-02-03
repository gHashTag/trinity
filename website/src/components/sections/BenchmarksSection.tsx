"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import ComparisonChart from '../charts/ComparisonChart'

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
      
      <div className="fade" style={{ 
        marginTop: '3rem', 
        marginBottom: '4rem',
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
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
            <div style={{ 
              fontSize: 'clamp(1.8rem, 4vw, 2.5rem)', 
              fontWeight: 600, 
              color: 'var(--accent)', 
              marginBottom: '0.5rem',
              background: 'linear-gradient(135deg, var(--accent), #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              backgroundClip: 'text'
            }}>{item.value}</div>
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
          href={b.url || "https://github.com/gHashTag/vibee-lang"} 
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
