"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

interface MysticismItem {
  title: string;
  description: string;
  formula: string;
}

export default function MysticismSection() {
  const { t } = useI18n();
  const m = t.mysticism;
  
  // Fallback items if translations not loaded
  const defaultItems: MysticismItem[] = [
    {
      title: 'SU(3) Gauge Symmetry',
      description: 'Ternary states {-1, 0, +1} map to color charge in quantum chromodynamics.',
      formula: 'SU(3) → 8 generators → ternary stability'
    },
    {
      title: 'Chern-Simons Invariants',
      description: 'Topological protection of quantum states through Chern-Simons theory.',
      formula: 'CS(A) = k/4π ∫ Tr(A∧dA + ⅔A∧A∧A)'
    },
    {
      title: 'Golden Ratio Identity',
      description: 'The sacred formula φ² + 1/φ² = 3 connects golden ratio to ternary.',
      formula: 'φ² + 1/φ² = 3 = TRINITY'
    },
    {
      title: 'Phoenix Number',
      description: 'The self-referential constant that emerges from ternary recursion.',
      formula: 'Φ = lim(n→∞) T(n)/T(n-1) ≈ 1.618...'
    }
  ];
  
  const items: MysticismItem[] = m?.items || defaultItems;

  return (
    <section id="mysticism" style={{ padding: '4rem 2rem', background: 'rgba(0,0,0,0.3)' }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        <motion.h2 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          style={{ textAlign: 'center', marginBottom: '3rem', fontSize: '2rem' }}
        >
          {m?.title || 'Mathematical Foundations'}
        </motion.h2>
        
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', 
          gap: '1.5rem' 
        }}>
          {items.map((item: MysticismItem, index: number) => (
            <motion.div
              key={item.title}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1 }}
              style={{
                background: 'rgba(255,255,255,0.02)',
                border: '1px solid var(--border)',
                borderRadius: '8px',
                padding: '1.5rem',
                transition: 'border-color 0.3s'
              }}
              whileHover={{ borderColor: 'var(--accent)' }}
            >
              <h3 style={{ 
                color: 'var(--accent)', 
                marginBottom: '0.75rem',
                fontSize: '1.1rem'
              }}>
                {item.title}
              </h3>
              <p style={{ 
                color: 'var(--muted)', 
                fontSize: '0.9rem',
                lineHeight: 1.6,
                marginBottom: '1rem'
              }}>
                {item.description}
              </p>
              <code style={{
                display: 'block',
                background: 'rgba(0,0,0,0.3)',
                padding: '0.5rem',
                borderRadius: '4px',
                fontSize: '0.8rem',
                color: 'var(--accent)',
                fontFamily: 'monospace'
              }}>
                {item.formula}
              </code>
            </motion.div>
          ))}
        </div>
        
        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 0.5 }}
          viewport={{ once: true }}
          style={{ 
            textAlign: 'center', 
            marginTop: '2rem', 
            fontSize: '0.85rem',
            fontStyle: 'italic'
          }}
        >
          {m?.subtitle || 'These mathematical structures provide theoretical grounding for ternary computing advantages.'}
        </motion.p>
      </div>
    </section>
  );
}
