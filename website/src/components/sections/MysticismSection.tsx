"use client";
import { motion } from 'framer-motion';

const mysticismItems = [
  {
    title: 'SU(3) Gauge Symmetry',
    description: 'Ternary states {-1, 0, +1} map to color charge in quantum chromodynamics. The 8 gluon generators of SU(3) provide natural error correction.',
    formula: 'SU(3) → 8 generators → ternary stability'
  },
  {
    title: 'Chern-Simons Invariants',
    description: 'Topological protection of quantum states through Chern-Simons theory. The invariant k=3 corresponds to ternary logic depth.',
    formula: 'CS(A) = k/4π ∫ Tr(A∧dA + ⅔A∧A∧A)'
  },
  {
    title: 'Golden Ratio Identity',
    description: 'The sacred formula φ² + 1/φ² = 3 connects golden ratio to ternary. This identity underlies optimal information encoding.',
    formula: 'φ² + 1/φ² = 3 = TRINITY'
  },
  {
    title: 'Phoenix Number',
    description: 'The self-referential constant that emerges from ternary recursion. Related to Feigenbaum constants in chaos theory.',
    formula: 'Φ = lim(n→∞) T(n)/T(n-1) ≈ 1.618...'
  }
];

export default function MysticismSection() {
  return (
    <section id="mysticism" style={{ padding: '4rem 2rem', background: 'rgba(0,0,0,0.3)' }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        <motion.h2 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          style={{ textAlign: 'center', marginBottom: '3rem', fontSize: '2rem' }}
        >
          Mathematical Foundations
        </motion.h2>
        
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', 
          gap: '1.5rem' 
        }}>
          {mysticismItems.map((item, index) => (
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
                color: 'var(--text-secondary)', 
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
          These mathematical structures provide theoretical grounding for ternary computing advantages.
        </motion.p>
      </div>
    </section>
  );
}
