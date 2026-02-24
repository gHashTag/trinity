"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import StargateDrum from '../StargateDrum';
import { useI18n } from '../../i18n/context';
import { fetchSacredFormula, fitSingleValue, type SacredFormulaResponse, type SacredConstantResult, type SingleFitResponse } from '../../services/chatApi';

type Category = 'all' | 'particle_physics' | 'quantum' | 'cosmology' | 'quantum_gravity';
const CATEGORY_KEYS: Category[] = ['all', 'particle_physics', 'quantum', 'cosmology', 'quantum_gravity'];

function errorBadge(pct: number, msg: any) {
  if (pct < 0.01) return { label: msg?.exact || 'EXACT', color: '#00e599' };
  if (pct < 1.0) return { label: msg?.close || 'CLOSE', color: '#ffd700' };
  return { label: msg?.approx || 'APPROX', color: '#ff6b6b' };
}

function formatFormula(fit: { n: number; k: number; m: number; p: number; q: number }) {
  const parts: string[] = [`${fit.n}`];
  if (fit.k !== 0) parts.push(`3^${fit.k}`);
  if (fit.m !== 0) parts.push(`\u03C0^${fit.m}`);
  if (fit.p !== 0) parts.push(`\u03C6^${fit.p}`);
  if (fit.q !== 0) parts.push(`e^${fit.q}`);
  return parts.join(' \u00D7 ');
}

export default function SacredFormulaSection() {
  const { t } = useI18n();
  const msg = (t as any).sacredFormula || {};

  const [data, setData] = useState<SacredFormulaResponse | null>(null);
  const [category, setCategory] = useState<Category>('all');
  const [customValue, setCustomValue] = useState('');
  const [customResult, setCustomResult] = useState<SingleFitResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [highlightedConstant, setHighlightedConstant] = useState<string | null>(null);

  useEffect(() => {
    fetchSacredFormula().then(setData);
  }, []);

  const filteredConstants = data?.constants.filter(
    c => category === 'all' || c.category === category
  ) ?? [];

  const handleDecompose = async () => {
    const val = parseFloat(customValue);
    if (isNaN(val) || val <= 0) return;
    setLoading(true);
    setCustomResult(null);
    try {
      const result = await fitSingleValue(val);
      setCustomResult(result);
    } finally {
      setLoading(false);
    }
  };

  const catLabels = msg.categories || {};

  return (
    <Section id="sacred-formula">
      <div className="tight fade">
        <h2 style={{ color: 'var(--accent)' }}>{msg.title || 'Sacred Formula Engine'}</h2>
        <p style={{
          fontFamily: 'monospace',
          fontSize: '1.3rem',
          color: '#ffd700',
          margin: '1rem 0 0.5rem',
          letterSpacing: '0.05em'
        }} dangerouslySetInnerHTML={{ __html: msg.formula || 'V = n &times; 3<sup>k</sup> &times; &pi;<sup>m</sup> &times; &phi;<sup>p</sup> &times; e<sup>q</sup>' }} />
        <p style={{ maxWidth: '700px', margin: '0 auto 1.5rem', opacity: 0.6, lineHeight: 1.6, fontSize: '0.9rem' }}>
          {msg.description || 'Integer Relation Detection'}
        </p>
      </div>

      {/* How it works — explanation */}
      <p className="fade" style={{
        maxWidth: '600px', margin: '0 auto 1.5rem', opacity: 0.55,
        lineHeight: 1.7, fontSize: '0.85rem', textAlign: 'center',
      }}>
        {msg.howItWorks || 'Enter any number and the Stargate decomposes it into fundamental mathematical constants.'}
      </p>

      {/* Custom input — ABOVE the Stargate */}
      <div className="fade" style={{
        display: 'flex', gap: '0.75rem', justifyContent: 'center',
        alignItems: 'center', marginBottom: '0.5rem', flexWrap: 'wrap'
      }}>
        <input
          type="number"
          placeholder={msg.inputPlaceholder || 'Enter any positive number...'}
          value={customValue}
          onChange={e => { setCustomValue(e.target.value); if (!e.target.value) setCustomResult(null); }}
          onKeyDown={e => e.key === 'Enter' && handleDecompose()}
          style={{
            background: 'rgba(255,255,255,0.05)',
            border: '1px solid rgba(255,215,0,0.3)',
            borderRadius: '8px',
            padding: '0.6rem 1rem',
            color: 'var(--text)',
            fontSize: '1rem',
            width: '220px',
            fontFamily: 'monospace',
            outline: 'none',
          }}
        />
        <button
          onClick={handleDecompose}
          disabled={loading}
          style={{
            background: 'linear-gradient(135deg, rgba(255,215,0,0.2), rgba(0,229,153,0.2))',
            border: '1px solid rgba(255,215,0,0.4)',
            borderRadius: '8px',
            padding: '0.6rem 1.5rem',
            color: '#ffd700',
            fontSize: '0.9rem',
            cursor: loading ? 'wait' : 'pointer',
            fontFamily: 'monospace',
          }}
        >
          {loading ? (msg.computing || 'Computing...') : (msg.decompose || 'Decompose')}
        </button>
      </div>

      {/* Hint text */}
      <p className="fade" style={{
        textAlign: 'center', fontSize: '0.75rem', opacity: 0.35,
        marginBottom: '1rem', fontFamily: 'monospace',
      }}>
        {msg.tryIt || 'Try a number \u2014 the Stargate will show its hidden structure'}
      </p>

      {/* Legend — how to read the Stargate chevrons */}
      <motion.div
        className="fade"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        style={{
          maxWidth: '500px', margin: '0 auto 1rem',
          background: 'rgba(255,215,0,0.04)',
          border: '1px solid rgba(255,215,0,0.12)',
          borderRadius: '12px', padding: '1rem 1.5rem',
          fontFamily: 'monospace', fontSize: '0.8rem',
          lineHeight: 1.8,
        }}
      >
        <div style={{ color: '#ffd700', marginBottom: '0.5rem', fontSize: '0.85rem' }}>
          {msg.legendTitle || 'How to read the Stargate:'}
        </div>
        <div style={{ opacity: 0.6 }}>
          <div><span style={{ color: '#ffd700' }}>n</span> — {msg.legendN || 'multiplier (1-9)'}</div>
          <div><span style={{ color: '#ffd700' }}>3^k</span> — {msg.legendK || 'ternary power'}</div>
          <div><span style={{ color: '#ffd700' }}>{'\u03C0'}^m</span> — {msg.legendM || 'geometry power'}</div>
          <div><span style={{ color: '#ffd700' }}>{'\u03C6'}^p</span> — {msg.legendP || 'golden ratio power'}</div>
          <div><span style={{ color: '#ffd700' }}>e^q</span> — {msg.legendQ || 'growth power'}</div>
        </div>
        <div style={{ marginTop: '0.5rem', opacity: 0.4, fontSize: '0.75rem' }}>
          {msg.legendExample || 'Example: 13 \u2248 1 \u00D7 3\u207B\u00B9 \u00D7 \u03C0\u00B9 \u00D7 \u03C6\u207B\u00B9 \u00D7 e\u00B3'}
        </div>
      </motion.div>

      {/* Stargate Drum */}
      <StargateDrum
        constants={data?.constants ?? []}
        isDecomposing={loading}
        result={customResult}
        highlightedConstant={highlightedConstant}
      />

      {/* Category filter */}
      <div className="fade" style={{
        display: 'flex', gap: '0.5rem', justifyContent: 'center',
        marginBottom: '2rem', flexWrap: 'wrap'
      }}>
        {CATEGORY_KEYS.map(key => {
          const label = catLabels[key] || key.replace('_', ' ');
          return (
            <button
              key={key}
              onClick={() => setCategory(key)}
              style={{
                background: category === key ? 'rgba(255,215,0,0.15)' : 'transparent',
                border: `1px solid ${category === key ? 'rgba(255,215,0,0.5)' : 'rgba(255,255,255,0.1)'}`,
                borderRadius: '20px',
                padding: '0.4rem 1rem',
                color: category === key ? '#ffd700' : 'var(--muted)',
                fontSize: '0.8rem',
                cursor: 'pointer',
                transition: 'all 0.2s',
              }}
            >
              {label}
            </button>
          );
        })}
      </div>

      {/* Constants grid */}
      <div className="fade" style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
        gap: '1rem',
        maxWidth: '1200px',
        margin: '0 auto 3rem',
      }}>
        {filteredConstants.map((c: SacredConstantResult, i: number) => {
          const badge = errorBadge(c.error_pct, msg);
          const isHighlighted = highlightedConstant === c.symbol;
          return (
            <motion.div
              key={c.symbol}
              className="premium-card"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.05 }}
              style={{
                padding: '1.25rem',
                cursor: 'pointer',
                borderColor: isHighlighted ? '#ffd700' : undefined,
              }}
              whileHover={{ borderColor: 'var(--accent)' }}
              onClick={() => setHighlightedConstant(isHighlighted ? null : c.symbol)}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
                <h3 style={{ color: 'var(--accent)', fontSize: '0.95rem', margin: 0 }}>
                  {c.name}
                </h3>
                <span style={{
                  fontSize: '0.65rem',
                  padding: '2px 6px',
                  borderRadius: '3px',
                  background: `${badge.color}22`,
                  color: badge.color,
                  border: `1px solid ${badge.color}44`,
                  fontFamily: 'monospace',
                }}>
                  {badge.label}
                </span>
              </div>
              <div style={{ fontFamily: 'monospace', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
                <span style={{ opacity: 0.5 }}>{msg.target || 'target'}: </span>
                <span style={{ color: 'var(--text)' }}>{c.target}</span>
              </div>
              <code style={{
                display: 'block',
                background: 'rgba(255,215,0,0.06)',
                padding: '0.5rem',
                borderRadius: '4px',
                fontSize: '0.8rem',
                color: '#ffd700',
                fontFamily: 'monospace',
                border: '1px solid rgba(255,215,0,0.15)',
                marginBottom: '0.4rem',
              }}>
                {formatFormula(c.fit)} = {c.computed.toFixed(6)}
              </code>
              <div style={{
                display: 'flex', justifyContent: 'space-between',
                fontSize: '0.7rem', opacity: 0.5, fontFamily: 'monospace'
              }}>
                <span>{catLabels[c.category] || c.category.replace('_', ' ')}</span>
                <span>{msg.error || 'err'}: {c.error_pct.toFixed(4)}%</span>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Predictions */}
      {data?.predictions && data.predictions.length > 0 && (
        <>
          <div className="tight fade" style={{ marginBottom: '1.5rem' }}>
            <h3 style={{ color: '#ffd700', fontSize: '1.1rem' }}>{msg.predictionsTitle || 'Sacred Extrapolations'}</h3>
            <p style={{ fontSize: '0.8rem', opacity: 0.5 }}>
              {msg.predictionsDisclaimer || 'NOT established physics \u2014 experimental mathematics only'}
            </p>
          </div>
          <div className="fade" style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
            gap: '1rem',
            maxWidth: '1000px',
            margin: '0 auto',
          }}>
            {data.predictions.map((p, i) => (
              <motion.div
                key={p.name}
                className="premium-card"
                initial={{ opacity: 0, y: 15 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08 }}
                style={{ padding: '1rem', borderColor: 'rgba(255,215,0,0.15)' }}
              >
                <div style={{ color: '#ffd700', fontSize: '0.85rem', marginBottom: '0.4rem' }}>
                  {p.name}
                </div>
                <code style={{
                  display: 'block',
                  fontSize: '0.8rem',
                  color: 'var(--accent)',
                  fontFamily: 'monospace',
                  marginBottom: '0.3rem',
                }}>
                  {p.formula}
                </code>
                <div style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                  = {typeof p.value === 'number' && Math.abs(p.value) < 0.001
                    ? p.value.toExponential(4)
                    : typeof p.value === 'number' && Math.abs(p.value) > 100000
                      ? p.value.toExponential(4)
                      : p.value?.toFixed?.(4) ?? p.value}
                  {p.unit ? ` ${p.unit}` : ''}
                </div>
              </motion.div>
            ))}
          </div>
        </>
      )}
    </Section>
  );
}
