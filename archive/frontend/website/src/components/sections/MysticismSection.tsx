"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';
import Section from '../Section';

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
      title: 'Optimal Radix Theorem',
      description: 'Information theory proves: optimal base is e ≈ 2.718, nearest integer = 3.',
      formula: 'Optimal base = e ≈ 2.718 → nearest integer = 3'
    }
  ];
  
  const items: MysticismItem[] = m?.items || defaultItems;

  return (
    <Section id="science">
      <div className="tight fade">
        <h2>{m?.title || 'Mathematical Foundations'}</h2>
        <p style={{ maxWidth: '800px', margin: '0 auto 3rem', opacity: 0.7, lineHeight: 1.7 }}>
          {m?.subtitle || 'Why 3? Inside every proton and neutron, quarks have exactly 3 colors — this is SU(3) symmetry that holds atoms together. Our ternary system {-1, 0, +1} mirrors this natural pattern.'}
        </p>
      </div>
      
      <div className="fade" style={{ 
        display: 'grid', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', 
        gap: '1.5rem',
        maxWidth: '1200px',
        margin: '0 auto'
      }}>
        {items.map((item: MysticismItem, index: number) => (
          <motion.div
            key={item.title}
            className="premium-card"
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: index * 0.1 }}
            style={{ padding: '1.5rem' }}
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
              background: 'rgba(0,229,153,0.08)',
              padding: '0.75rem',
              borderRadius: '6px',
              fontSize: '0.85rem',
              color: 'var(--accent)',
              fontFamily: 'monospace',
              border: '1px solid rgba(0,229,153,0.2)'
            }}>
              {item.formula}
            </code>
          </motion.div>
        ))}
      </div>
    </Section>
  );
}
