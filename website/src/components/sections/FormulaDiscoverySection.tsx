"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchFormulaDiscoveryHybrid, type FormulaDiscoveryHybridMode, type FormulaDiscoveryHybridResponse } from '../../services/chatApi';

const MODES = [
  { key: 'discover', label: 'Discover' },
  { key: 'parse', label: 'Parse AST' },
  { key: 'symbolic', label: 'Symbolic' },
  { key: 'numeric', label: 'Numeric' },
  { key: 'evaluate', label: 'Evaluate' },
  { key: 'equivalence', label: 'Equivalence' },
  { key: 'optimize', label: 'Optimize' },
];

const RAZUM_COLOR = '#ffd700';

const glass = {
  background: 'rgba(255, 215, 0, 0.1)',
  border: '1px solid rgba(255, 215, 0, 0.2)',
  borderRadius: '12px',
  backdropFilter: 'blur(8px)',
};

export default function FormulaDiscoverySection() {
  const { t } = useI18n();
  const [mode, setMode] = useState<keyof typeof MODES[number] | ''>('discover');
  const [data, setData] = useState<FormulaDiscoveryHybridMode | null>(null);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const loadData = async (m: keyof typeof MODES[number]) => {
    setLoading(true);
    try {
      const result = await fetchFormulaDiscoveryHybrid(m);
      setData(result.data);
    } catch {
      console.error('Failed to load formula discovery data:', m);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(mode); }, [mode]);

  return (
    <Section
      title="Formula Discovery Hybrid v3.5"
      version="3.5"
      icon="&#x1F4CA;"
      expanded={expanded}
      onToggle={() => setExpanded(!expanded)}
    >
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '16px' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h3 style={{ color: RAZUM_COLOR, fontSize: 28, fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 24 }}>
            {t('formulaDiscovery.title')}
          </h3>
          <p style={{ color: 'rgba(255, 255, 255, 0.7)', textAlign: 'center', fontSize: 12, marginBottom: 16 }}>
            {t('formulaDiscovery.description')}
          </p>

          {/* Mode Switcher */}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 24, flexWrap: 'wrap' }}>
            {MODES.map(m => (
              <button
                key={m.key}
                onClick={() => setMode(m.key)}
                style={{
                  padding: '6px 16px',
                  borderRadius: 8,
                  border: mode === m.key ? '1px solid #ffd700' : '1px solid rgba(255, 255, 255, 0.2)',
                  background: mode === m.key ? 'rgba(255, 215, 0, 0.15)' : 'rgba(0, 0, 0, 0)',
                  color: mode === m.key ? '#ffd700' : 'rgba(255, 255, 255, 0.7)',
                  cursor: 'pointer',
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono, monospace',
                  transition: 'all 0.2s',
                }}
              >
                {m.label}
              </button>
            ))}
          </div>

          {/* Content based on mode */}
          {loading ? (
            <div style={{ textAlign: 'center', padding: 40 }}>
              <span style={{ color: RAZUM_COLOR, fontSize: 12, fontFamily: 'JetBrains Mono, monospace' }}>Loading...</span>
            </div>
          ) : data && (
            <motion.div
              key={mode}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
              style={glass}
            >
              {mode === 'discover' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.hybridDiscovery')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16, marginBottom: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('formulaDiscovery.symbolic')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {data.data.symbolic_formula}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16, marginBottom: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('formulaDiscovery.numeric')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {data.data.numeric_approx}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('formulaDiscovery.confidence')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {(data.data.confidence * 100).toFixed(1)}%
                    </div>
                  </div>
                </>
              )}

              {mode === 'parse' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.astParse')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <pre style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', whiteSpace: 'pre-wrap', overflowX: 'auto' }}>
                      {JSON.stringify(data.data.ast, null, 2)}
                    </pre>
                  </div>
                </>
              )}

              {mode === 'symbolic' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.symbolicSimplify')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700' }}>
                      {data.data.simplified_formula}
                    </div>
                  </div>
                </>
              )}

              {mode === 'numeric' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.numericApprox')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('formulaDiscovery.error')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {data.data.approximation_error.toExponential(4)}
                    </div>
                  </div>
                </>
              )}

              {mode === 'evaluate' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.exactEval')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('formulaDiscovery.exactValue')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.exact_value}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('formulaDiscovery.decimal')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.decimal_value}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'equivalence' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.equivalence')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700' }}>
                      {data.data.equivalent_formulas.join(' ≡ ')}
                    </div>
                  </div>
                </>
              )}

              {mode === 'optimize' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('formulaDiscovery.optimize')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('formulaDiscovery.before')}
                      </div>
                      <div style={{ fontSize: 14, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.before_optimization}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('formulaDiscovery.after')}
                      </div>
                      <div style={{ fontSize: 14, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.after_optimization}
                      </div>
                    </div>
                  </div>
                  <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('formulaDiscovery.complexityBefore')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.complexity_before}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('formulaDiscovery.complexityAfter')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.complexity_after}
                      </div>
                    </div>
                  </div>
                </>
              )}
            </motion.div>
          )}

          {/* Status Bar */}
          <div style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 11, color: data?.data.sacred_check === '✓' ? '#00cc00' : 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {t('formulaDiscovery.sacred')}
            </span>
            <span style={{ fontSize: 11, color: 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {data?.data.phimath_formula || 'φ² + 1/φ² = 3'}
            </span>
          </div>
        </motion.h2>

        {/* Footer */}
        <div style={{ marginTop: 16, borderTop: '1px solid rgba(255, 215, 0, 0.1)', paddingTop: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, fontSize: 10, color: 'rgba(255, 255, 255, 0.5)' }}>
            <span>φ ≈ 1.618</span>
            <span>•</span>
            <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>{(1.618033988749895).toFixed(6)}</span>
            <span>•</span>
            <span>{t('formulaDiscovery.hybrid')}</span>
          </div>
        </div>
      </div>
    </Section>
  );
}
