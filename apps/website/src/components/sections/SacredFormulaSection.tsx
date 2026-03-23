"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import StargateDrum from '../StargateDrum';
import { useI18n } from '../../i18n/context';
import { fetchSacredFormula, fitSingleValue, fetchGematria, computeFromParams, computeSacredFormula, PARAM_BOUNDS, type SacredFormulaResponse, type SacredConstantResult, type SingleFitResponse, type GematriaResponse } from '../../services/chatApi';

type Category = 'all' | 'particle_physics' | 'quantum' | 'cosmology' | 'quantum_gravity' | 'sacred_geometry';
const CATEGORY_KEYS: Category[] = ['all', 'particle_physics', 'quantum', 'cosmology', 'quantum_gravity', 'sacred_geometry'];

type InputMode = 'formula' | 'manual' | 'gematria' | 'time';
type ParamKey = 'n' | 'k' | 'm' | 'p' | 'q';
const PARAM_KEYS: ParamKey[] = ['n', 'k', 'm', 'p', 'q'];

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
  const [inputMode, setInputMode] = useState<InputMode>('formula');
  const [gematriaResult, setGematriaResult] = useState<GematriaResponse | null>(null);
  const [highlightedGlyphs, setHighlightedGlyphs] = useState<number[]>([]);
  const [params, setParams] = useState<Record<ParamKey, string>>({ n: '1', k: '0', m: '0', p: '0', q: '0' });
  const [paramErrors, setParamErrors] = useState<Record<ParamKey, string | null>>({ n: null, k: null, m: null, p: null, q: null });
  const [formulaError, setFormulaError] = useState<string | null>(null);
  const [heartbeatActive, setHeartbeatActive] = useState(false);
  const [heartbeatPhase, setHeartbeatPhase] = useState(0);
  const [timeVtResult, setTimeVtResult] = useState<number | null>(null);

  // Sacred temporal constants (pure math, no backend)
  const PHI = 1.6180339887498948482;
  const PHI_SQ = PHI * PHI;           // 2.618033988749895
  const INV_PHI_SQ = 1 / PHI_SQ;     // 0.381966011250105
  const PHI_4 = PHI_SQ * PHI_SQ;     // 6.854101966249685
  const OMEGA_M = 1 / Math.PI;        // 0.31831 (experiment: 0.315)
  const OMEGA_L = (Math.PI - 1) / Math.PI; // 0.68169 (experiment: 0.685)

  function validateParam(key: ParamKey, value: string): string | null {
    if (value.trim() === '') return msg.validationRequired || 'Required';
    const num = Number(value);
    if (!Number.isInteger(num)) return msg.validationInteger || 'Must be integer';
    const bounds = PARAM_BOUNDS[key];
    if (num < bounds.min || num > bounds.max) {
      return msg[`validationRange_${key}` as keyof typeof msg] as string || `Range: [${bounds.min}, ${bounds.max}]`;
    }
    return null;
  }

  const hasParamErrors = Object.values(paramErrors).some(e => e !== null);

  const handleParamChange = (key: ParamKey, value: string) => {
    setParams(prev => ({ ...prev, [key]: value }));
    setParamErrors(prev => ({ ...prev, [key]: validateParam(key, value) }));
  };

  useEffect(() => {
    fetchSacredFormula().then(setData);
  }, []);

  const filteredConstants = data?.constants.filter(
    c => category === 'all' || c.category === category
  ) ?? [];

  const handleDecompose = async () => {
    setCustomResult(null);
    setGematriaResult(null);
    setHighlightedGlyphs([]);
    setFormulaError(null);

    if (inputMode === 'gematria') {
      if (!customValue.trim()) return;
      setLoading(true);
      try {
        const result = await fetchGematria(customValue.trim());
        setGematriaResult(result);
        setHighlightedGlyphs(result.glyphs.map(g => g.index));
      } finally {
        setLoading(false);
      }
    } else if (inputMode === 'manual') {
      // Validate all params
      const errors: Record<string, string | null> = {};
      let hasError = false;
      for (const key of PARAM_KEYS) {
        const err = validateParam(key, params[key]);
        errors[key] = err;
        if (err) hasError = true;
      }
      setParamErrors(errors as Record<ParamKey, string | null>);
      if (hasError) return;

      setLoading(true);
      const result = computeFromParams(
        parseInt(params.n), parseInt(params.k), parseInt(params.m),
        parseInt(params.p), parseInt(params.q)
      );
      // Delay result until Stargate finishes spinning (~2.5s), then allow locking + reveal
      setTimeout(() => {
        setCustomResult(result);
      }, 2500);
      setTimeout(() => {
        setLoading(false);
      }, 3500);
    } else {
      // formula mode — auto-search
      if (!customValue.trim()) return;
      const val = parseFloat(customValue);
      if (isNaN(val) || val <= 0) {
        setFormulaError(msg.validationPositive || 'Enter a positive number');
        return;
      }
      setLoading(true);
      try {
        const result = await fitSingleValue(val);
        setCustomResult(result);
      } finally {
        setLoading(false);
      }
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
          maxWidth: 'min(500px, 90vw)', margin: '0 auto 1rem',
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

      {/* Mode switcher */}
      <div className="fade" style={{
        display: 'flex', gap: '0.5rem', justifyContent: 'center',
        marginBottom: '0.75rem', flexWrap: 'wrap',
      }}>
        {(['formula', 'manual', 'gematria', 'time'] as InputMode[]).map(mode => (
          <button
            key={mode}
            onClick={() => {
              setInputMode(mode);
              setCustomValue('');
              setCustomResult(null);
              setGematriaResult(null);
              setHighlightedGlyphs([]);
              setFormulaError(null);
              setParamErrors({ n: null, k: null, m: null, p: null, q: null });
              setHeartbeatActive(false);
              setTimeVtResult(null);
            }}
            style={{
              background: inputMode === mode
                ? mode === 'time' ? 'rgba(170,102,255,0.2)' : 'rgba(255,215,0,0.15)'
                : 'transparent',
              border: `1px solid ${inputMode === mode
                ? mode === 'time' ? 'rgba(170,102,255,0.6)' : 'rgba(255,215,0,0.5)'
                : 'rgba(255,255,255,0.1)'}`,
              borderRadius: '20px',
              padding: '0.35rem 1.2rem',
              color: inputMode === mode
                ? mode === 'time' ? '#aa66ff' : '#ffd700'
                : 'var(--muted)',
              fontSize: '0.8rem',
              cursor: 'pointer',
              transition: 'all 0.2s',
              fontFamily: 'monospace',
            }}
          >
            {mode === 'formula'
              ? (msg.modeFormula || 'Number \u2192 Formula')
              : mode === 'manual'
                ? (msg.modeManual || 'Parameters \u2192 Value')
                : mode === 'gematria'
                  ? (msg.modeGematria || 'Gematria')
                  : (msg.modeTime || '\u231B Trinity Time')}
          </button>
        ))}
      </div>

      {/* Input area — formula mode */}
      {inputMode === 'formula' && (
        <div className="fade" style={{ marginBottom: '0.5rem' }}>
          <div style={{
            display: 'flex', gap: '0.75rem', justifyContent: 'center',
            alignItems: 'center', flexWrap: 'wrap',
          }}>
            <input
              type="number"
              placeholder={msg.inputPlaceholder || 'Enter any positive number...'}
              value={customValue}
              onChange={e => {
                setCustomValue(e.target.value);
                setFormulaError(null);
                if (!e.target.value) { setCustomResult(null); }
              }}
              onKeyDown={e => e.key === 'Enter' && handleDecompose()}
              style={{
                background: 'rgba(255,255,255,0.05)',
                border: `1px solid ${formulaError ? 'rgba(255,80,80,0.7)' : 'rgba(255,215,0,0.3)'}`,
                borderRadius: '8px',
                padding: '0.6rem 1rem',
                color: 'var(--text)',
                fontSize: '1rem',
                width: '100%',
                maxWidth: '220px',
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
          {formulaError && (
            <div style={{ color: '#ff5050', fontSize: '0.75rem', fontFamily: 'monospace', textAlign: 'center', marginTop: '0.4rem' }}>
              {formulaError}
            </div>
          )}
        </div>
      )}

      {/* Input area — manual mode (5 parameter inputs) */}
      {inputMode === 'manual' && (
        <div className="fade" style={{ marginBottom: '0.5rem' }}>
          <div style={{
            display: 'flex', gap: '0.5rem', justifyContent: 'center',
            alignItems: 'flex-start', flexWrap: 'wrap',
          }}>
            {PARAM_KEYS.map(key => {
              const bounds = PARAM_BOUNDS[key];
              const error = paramErrors[key];
              return (
                <div key={key} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: '1 1 60px', maxWidth: '80px' }}>
                  <label style={{
                    color: '#ffd700', fontSize: '0.8rem', fontFamily: 'monospace',
                    marginBottom: '0.25rem', textAlign: 'center',
                  }}>
                    {key === 'n' ? 'n' : key === 'k' ? '3^k' : key === 'm' ? '\u03C0^m' : key === 'p' ? '\u03C6^p' : 'e^q'}
                    <span style={{ opacity: 0.4, fontSize: '0.65rem', display: 'block' }}>
                      [{bounds.min}, {bounds.max}]
                    </span>
                  </label>
                  <input
                    type="number"
                    value={params[key]}
                    onChange={e => handleParamChange(key, e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && handleDecompose()}
                    style={{
                      background: 'rgba(255,255,255,0.05)',
                      border: `1px solid ${error ? 'rgba(255,80,80,0.7)' : 'rgba(255,215,0,0.3)'}`,
                      borderRadius: '6px',
                      padding: '0.4rem 0.3rem',
                      color: 'var(--text)',
                      fontSize: '0.95rem',
                      width: '100%',
                      fontFamily: 'monospace',
                      outline: 'none',
                      textAlign: 'center',
                    }}
                  />
                  {error && (
                    <span style={{
                      color: '#ff5050', fontSize: '0.6rem', fontFamily: 'monospace',
                      marginTop: '0.2rem', textAlign: 'center', lineHeight: 1.2,
                    }}>
                      {error}
                    </span>
                  )}
                </div>
              );
            })}
          </div>
          <div style={{ textAlign: 'center', marginTop: '0.5rem' }}>
            <button
              onClick={handleDecompose}
              disabled={loading || hasParamErrors}
              style={{
                background: hasParamErrors
                  ? 'rgba(255,80,80,0.1)'
                  : 'linear-gradient(135deg, rgba(255,215,0,0.2), rgba(0,229,153,0.2))',
                border: `1px solid ${hasParamErrors ? 'rgba(255,80,80,0.4)' : 'rgba(255,215,0,0.4)'}`,
                borderRadius: '8px',
                padding: '0.6rem 2rem',
                color: hasParamErrors ? '#ff5050' : '#ffd700',
                fontSize: '0.9rem',
                cursor: (loading || hasParamErrors) ? 'not-allowed' : 'pointer',
                fontFamily: 'monospace',
                opacity: hasParamErrors ? 0.5 : 1,
              }}
            >
              {loading ? (msg.computing || 'Computing...') : (msg.compute || 'Compute')}
            </button>
          </div>
        </div>
      )}

      {/* Input area — gematria mode */}
      {inputMode === 'gematria' && (
        <div className="fade" style={{
          display: 'flex', gap: '0.75rem', justifyContent: 'center',
          alignItems: 'center', marginBottom: '0.5rem', flexWrap: 'wrap',
        }}>
          <input
            type="text"
            placeholder={msg.gematriaPlaceholder || 'Number or Coptic text...'}
            value={customValue}
            onChange={e => {
              setCustomValue(e.target.value);
              if (!e.target.value) { setGematriaResult(null); setHighlightedGlyphs([]); }
            }}
            onKeyDown={e => e.key === 'Enter' && handleDecompose()}
            style={{
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(0,229,153,0.3)',
              borderRadius: '8px',
              padding: '0.6rem 1rem',
              color: 'var(--text)',
              fontSize: '1rem',
              width: '100%',
              maxWidth: '220px',
              fontFamily: 'monospace',
              outline: 'none',
            }}
          />
          <button
            onClick={handleDecompose}
            disabled={loading}
            style={{
              background: 'linear-gradient(135deg, rgba(0,229,153,0.2), rgba(255,215,0,0.2))',
              border: '1px solid rgba(0,229,153,0.4)',
              borderRadius: '8px',
              padding: '0.6rem 1.5rem',
              color: '#00e599',
              fontSize: '0.9rem',
              cursor: loading ? 'wait' : 'pointer',
              fontFamily: 'monospace',
            }}
          >
            {loading ? (msg.computing || 'Computing...') : (msg.gematriaDecompose || 'Decode')}
          </button>
        </div>
      )}

      {/* Gematria result card */}
      {gematriaResult && gematriaResult.glyphs.length > 0 && (
        <motion.div
          className="fade"
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          style={{
            maxWidth: 'min(500px, 90vw)', margin: '0 auto 0.5rem',
            background: 'rgba(0,229,153,0.04)',
            border: '1px solid rgba(0,229,153,0.15)',
            borderRadius: '12px', padding: '1rem 1.5rem',
            fontFamily: 'monospace', fontSize: '0.85rem',
            textAlign: 'center',
          }}
        >
          <div style={{ color: '#00e599', marginBottom: '0.5rem', fontSize: '1.1rem' }}>
            {gematriaResult.glyphs.map((g, i) => (
              <span key={i}>
                {i > 0 && <span style={{ opacity: 0.4 }}> + </span>}
                <span style={{ color: '#fff' }}>{g.glyph}</span>
                <span style={{ opacity: 0.5, fontSize: '0.75rem' }}>({g.value})</span>
              </span>
            ))}
          </div>
          <div style={{ color: '#00e599', fontSize: '1.2rem', fontWeight: 'bold' }}>
            = {gematriaResult.total}
          </div>
          {gematriaResult.sacred_fit && (
            <div style={{ marginTop: '0.5rem', opacity: 0.6, fontSize: '0.75rem' }}>
              {msg.sacredFit || 'Sacred fit'}: {formatFormula(gematriaResult.sacred_fit)}
              {' \u2248 '}{gematriaResult.sacred_computed?.toFixed(4)}
              {' ('}{gematriaResult.sacred_error_pct?.toFixed(3)}{'%)'}
            </div>
          )}

          {/* Coptic 3x3x3 Lattice Mini-Viz */}
          <div style={{ marginTop: '0.75rem', borderTop: '1px solid rgba(0,229,153,0.1)', paddingTop: '0.75rem' }}>
            <div style={{ fontSize: '0.7rem', opacity: 0.4, marginBottom: '0.4rem' }}>
              {msg.copticMatter || 'Matter (1-9)'} | {msg.copticEnergy || 'Energy (10-90)'} | {msg.copticInfo || 'Info (100-900)'}
            </div>
            <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'center', flexWrap: 'wrap' }}>
              {[
                { label: msg.copticMatter || 'Matter', color: '#00ccff', range: [0, 9] },
                { label: msg.copticEnergy || 'Energy', color: '#00e599', range: [9, 18] },
                { label: msg.copticInfo || 'Info', color: '#ffd700', range: [18, 27] },
              ].map((layer) => (
                <div key={layer.label} style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: '0.6rem', color: layer.color, marginBottom: '0.2rem', opacity: 0.6 }}>{layer.label}</div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2px' }}>
                    {Array.from({ length: 9 }, (_, i) => {
                      const idx = layer.range[0] + i;
                      const active = highlightedGlyphs.includes(idx);
                      return (
                        <div key={idx} style={{
                          width: '18px', height: '18px',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontSize: '0.55rem',
                          background: active ? `${layer.color}33` : 'rgba(255,255,255,0.03)',
                          border: `1px solid ${active ? layer.color : 'rgba(255,255,255,0.06)'}`,
                          borderRadius: '2px',
                          color: active ? layer.color : 'rgba(255,255,255,0.15)',
                          transition: 'all 0.3s',
                        }}>
                          {idx + 1}
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      )}

      {/* ═══ TRINITY TIME TAB ═══ */}
      {inputMode === 'time' && (
        <motion.div
          className="fade"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          style={{
            maxWidth: 'min(650px, 92vw)', margin: '0 auto 1.5rem',
          }}
        >
          {/* Time Triad Visualization */}
          <div style={{
            background: 'rgba(170,102,255,0.04)',
            border: '1px solid rgba(170,102,255,0.15)',
            borderRadius: '14px', padding: '1.5rem',
            fontFamily: 'monospace', textAlign: 'center',
            marginBottom: '1rem',
          }}>
            <div style={{ color: '#aa66ff', fontSize: '0.9rem', fontWeight: 'bold', marginBottom: '1rem' }}>
              {msg.timeTriadTitle || 'TEMPORAL TRINITY THEOREM v1.0'}
            </div>

            {/* SVG Time Triad */}
            <svg viewBox="0 0 300 220" style={{ width: '100%', maxWidth: '320px', height: 'auto' }}>
              {/* Vertical axis */}
              <line x1="150" y1="30" x2="150" y2="190" stroke="rgba(170,102,255,0.3)" strokeWidth="1" />
              {/* Horizontal axis */}
              <line x1="40" y1="110" x2="260" y2="110" stroke="rgba(170,102,255,0.3)" strokeWidth="1" />

              {/* Center: Present = 0 */}
              <circle cx="150" cy="110" r="6" fill="rgba(170,102,255,0.6)" />
              <text x="165" y="115" fill="rgba(255,255,255,0.5)" fontSize="10" fontFamily="monospace">0</text>

              {/* Top: Future = phi^2 (creation) */}
              <motion.circle
                cx={150} cy={40} r={8}
                fill="#ffd700"
                animate={{ r: heartbeatActive ? [8, 12, 8] : 8, opacity: heartbeatActive ? [1, 0.6, 1] : 1 }}
                transition={{ duration: 1.618, repeat: heartbeatActive ? Infinity : 0 }}
              />
              <text x="150" y="25" fill="#ffd700" fontSize="11" fontFamily="monospace" textAnchor="middle">
                {'\u03C6\u00B2 = '}{PHI_SQ.toFixed(4)}
              </text>
              <text x="150" y="65" fill="rgba(255,215,0,0.6)" fontSize="8" fontFamily="monospace" textAnchor="middle">
                {msg.timeCreation || 'CREATION (future)'}
              </text>

              {/* Bottom: Past = 1/phi^2 (destruction) */}
              <circle cx="150" cy="180" r="5" fill="#00ccff" />
              <text x="150" y="210" fill="#00ccff" fontSize="11" fontFamily="monospace" textAnchor="middle">
                {'1/\u03C6\u00B2 = '}{INV_PHI_SQ.toFixed(4)}
              </text>
              <text x="150" y="170" fill="rgba(0,204,255,0.6)" fontSize="8" fontFamily="monospace" textAnchor="middle">
                {msg.timeDestruction || 'ENTROPY (past)'}
              </text>

              {/* Right arrow: phi^2 dominance */}
              <line x1="170" y1="95" x2="250" y2="55" stroke="rgba(255,215,0,0.4)" strokeWidth="1" strokeDasharray="4,3" />
              <text x="250" y="50" fill="rgba(255,215,0,0.7)" fontSize="8" fontFamily="monospace" textAnchor="middle">
                {'\u03C6\u2074 \u2248 '}{PHI_4.toFixed(3)}
              </text>

              {/* Left label */}
              <text x="35" y="115" fill="rgba(0,204,255,0.5)" fontSize="9" fontFamily="monospace">
                {INV_PHI_SQ.toFixed(3)}
              </text>
              {/* Right label */}
              <text x="265" y="115" fill="rgba(255,215,0,0.5)" fontSize="9" fontFamily="monospace" textAnchor="end">
                {PHI_SQ.toFixed(3)}
              </text>
            </svg>
          </div>

          {/* phi^4 Asymmetry — big number */}
          <motion.div
            style={{
              background: 'rgba(255,215,0,0.04)',
              border: '1px solid rgba(255,215,0,0.12)',
              borderRadius: '12px', padding: '1rem 1.5rem',
              textAlign: 'center', marginBottom: '1rem',
            }}
            animate={heartbeatActive ? {
              borderColor: ['rgba(255,215,0,0.12)', 'rgba(255,215,0,0.5)', 'rgba(255,215,0,0.12)'],
            } : {}}
            transition={{ duration: 1.618, repeat: heartbeatActive ? Infinity : 0 }}
          >
            <div style={{ fontFamily: 'monospace', fontSize: '0.75rem', opacity: 0.5, marginBottom: '0.3rem' }}>
              {msg.timeArrowTitle || 'Time Arrow Asymmetry'}
            </div>
            <div style={{
              fontFamily: 'monospace', fontSize: '2rem', fontWeight: 'bold',
              color: '#ffd700', letterSpacing: '0.05em',
            }}>
              {'\u03C6\u2074 = '}{PHI_4.toFixed(9)}
            </div>
            <div style={{ fontFamily: 'monospace', fontSize: '0.75rem', opacity: 0.6, marginTop: '0.3rem' }}>
              {msg.timeArrowDesc || 'Creation dominates destruction by 6.854\u00D7 \u2192 time flows forward'}
            </div>
          </motion.div>

          {/* Omega Predictions Table */}
          <div style={{
            background: 'rgba(0,229,153,0.04)',
            border: '1px solid rgba(0,229,153,0.12)',
            borderRadius: '12px', padding: '1rem 1.5rem',
            fontFamily: 'monospace', marginBottom: '1rem',
          }}>
            <div style={{ color: '#00e599', fontSize: '0.85rem', fontWeight: 'bold', marginBottom: '0.75rem', textAlign: 'center' }}>
              {msg.omegaTitle || '\u03A9 Predictions (from \u03C0)'}
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '0.5rem', fontSize: '0.75rem' }}>
              {/* Header */}
              <div style={{ opacity: 0.4 }}>{msg.omegaParam || 'Parameter'}</div>
              <div style={{ opacity: 0.4, textAlign: 'center' }}>{msg.omegaPredicted || 'Predicted'}</div>
              <div style={{ opacity: 0.4, textAlign: 'right' }}>{msg.omegaExperiment || 'Experiment'}</div>
              {/* Omega_m */}
              <div style={{ color: '#00ccff' }}>{'\u03A9_m'} <span style={{ opacity: 0.4, fontSize: '0.65rem' }}>({msg.omegaDarkMatter || 'matter'})</span></div>
              <div style={{ textAlign: 'center', color: '#fff' }}>{'1/\u03C0 \u2248 '}{OMEGA_M.toFixed(5)}</div>
              <div style={{ textAlign: 'right', color: '#00e599' }}>0.315</div>
              {/* Omega_Lambda */}
              <div style={{ color: '#aa66ff' }}>{'\u03A9_\u039B'} <span style={{ opacity: 0.4, fontSize: '0.65rem' }}>({msg.omegaDarkEnergy || 'energy'})</span></div>
              <div style={{ textAlign: 'center', color: '#fff' }}>{'(\u03C0\u22121)/\u03C0 \u2248 '}{OMEGA_L.toFixed(5)}</div>
              <div style={{ textAlign: 'right', color: '#00e599' }}>0.685</div>
              {/* Sum */}
              <div style={{ color: '#ffd700', fontWeight: 'bold' }}>{'\u03A3'}</div>
              <div style={{ textAlign: 'center', color: '#ffd700', fontWeight: 'bold' }}>{(OMEGA_M + OMEGA_L).toFixed(5)}</div>
              <div style={{ textAlign: 'right', color: '#ffd700', fontWeight: 'bold' }}>1.000</div>
              {/* Age of Universe */}
              <div style={{ color: '#ffd700' }}>{msg.omegaAge || 'Age'} <span style={{ opacity: 0.4, fontSize: '0.65rem' }}>(Gyr)</span></div>
              <div style={{ textAlign: 'center', color: '#fff' }}>{(Math.PI * PHI * Math.E).toFixed(3)}</div>
              <div style={{ textAlign: 'right', color: '#00e599' }}>13.787</div>
            </div>
          </div>

          {/* Action Buttons */}
          <div style={{
            display: 'flex', gap: '0.5rem', justifyContent: 'center',
            flexWrap: 'wrap', marginBottom: '1rem',
          }}>
            {/* Temporal Engine Heartbeat */}
            <button
              onClick={() => {
                if (heartbeatActive) {
                  setHeartbeatActive(false);
                } else {
                  setHeartbeatActive(true);
                  setHeartbeatPhase(0);
                  // Auto-stop after 10 cycles (~16s)
                  setTimeout(() => setHeartbeatActive(false), 16180);
                }
              }}
              style={{
                background: heartbeatActive
                  ? 'linear-gradient(135deg, rgba(170,102,255,0.3), rgba(255,215,0,0.2))'
                  : 'linear-gradient(135deg, rgba(170,102,255,0.15), rgba(255,215,0,0.1))',
                border: `1px solid ${heartbeatActive ? 'rgba(170,102,255,0.6)' : 'rgba(170,102,255,0.3)'}`,
                borderRadius: '8px',
                padding: '0.5rem 1.2rem',
                color: heartbeatActive ? '#ffd700' : '#aa66ff',
                fontSize: '0.8rem',
                cursor: 'pointer',
                fontFamily: 'monospace',
                transition: 'all 0.3s',
              }}
            >
              {heartbeatActive
                ? (msg.timeEngineStop || '\u23F8 Stop Heartbeat')
                : (msg.timeEngineStart || '\u23F5 Temporal Engine (\u03C6 = 1.618s)')}
            </button>

            {/* Compute V(t) */}
            <button
              onClick={() => {
                const n = parseInt(params.n) || 1;
                const k = parseInt(params.k) || 0;
                const m = parseInt(params.m) || 0;
                const p = parseInt(params.p) || 0;
                const q = parseInt(params.q) || 0;
                setTimeVtResult(computeSacredFormula(n, k, m, p, q));
              }}
              style={{
                background: 'linear-gradient(135deg, rgba(255,215,0,0.15), rgba(0,229,153,0.1))',
                border: '1px solid rgba(255,215,0,0.3)',
                borderRadius: '8px',
                padding: '0.5rem 1.2rem',
                color: '#ffd700',
                fontSize: '0.8rem',
                cursor: 'pointer',
                fontFamily: 'monospace',
              }}
            >
              {msg.timeShowVt || 'Compute V(t)'}
            </button>
          </div>

          {/* V(t) mini-params */}
          <div style={{
            display: 'flex', gap: '0.3rem', justifyContent: 'center',
            alignItems: 'center', marginBottom: '0.5rem', flexWrap: 'wrap',
          }}>
            {PARAM_KEYS.map(key => (
              <div key={key} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <label style={{ color: '#aa66ff', fontSize: '0.65rem', fontFamily: 'monospace' }}>
                  {key === 'n' ? 'n' : key === 'k' ? '3^k' : key === 'm' ? '\u03C0^m' : key === 'p' ? '\u03C6^p' : 'e^q'}
                </label>
                <input
                  type="number"
                  value={params[key]}
                  onChange={e => handleParamChange(key, e.target.value)}
                  style={{
                    background: 'rgba(170,102,255,0.06)',
                    border: '1px solid rgba(170,102,255,0.2)',
                    borderRadius: '4px',
                    padding: '0.25rem 0.2rem',
                    color: 'var(--text)',
                    fontSize: '0.8rem',
                    width: '45px',
                    fontFamily: 'monospace',
                    outline: 'none',
                    textAlign: 'center',
                  }}
                />
              </div>
            ))}
          </div>

          {/* V(t) Result */}
          {timeVtResult !== null && (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              style={{
                textAlign: 'center', fontFamily: 'monospace',
                marginBottom: '1rem', padding: '0.5rem',
                background: 'rgba(255,215,0,0.06)',
                borderRadius: '8px',
                border: '1px solid rgba(255,215,0,0.15)',
              }}
            >
              <div style={{ fontSize: '0.7rem', opacity: 0.5 }}>V(t) = {formatFormula({ n: parseInt(params.n) || 1, k: parseInt(params.k) || 0, m: parseInt(params.m) || 0, p: parseInt(params.p) || 0, q: parseInt(params.q) || 0 })}</div>
              <div style={{ fontSize: '1.3rem', color: '#ffd700', fontWeight: 'bold' }}>
                = {Math.abs(timeVtResult) < 0.001 || Math.abs(timeVtResult) > 100000
                  ? timeVtResult.toExponential(6)
                  : timeVtResult.toFixed(6)}
              </div>
            </motion.div>
          )}

          {/* Temporal Coptic Cube */}
          <div style={{
            background: 'rgba(170,102,255,0.04)',
            border: '1px solid rgba(170,102,255,0.1)',
            borderRadius: '12px', padding: '1rem',
            textAlign: 'center',
          }}>
            <div style={{ fontSize: '0.7rem', opacity: 0.5, fontFamily: 'monospace', marginBottom: '0.5rem' }}>
              {msg.timeCopticTitle || '27 = 3\u00B3 Coptic Temporal Cube'}
            </div>
            <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center', flexWrap: 'wrap' }}>
              {[
                { label: msg.timePast || 'Past', color: '#00ccff', range: [0, 9], symbol: '-1' },
                { label: msg.timePresent || 'Present', color: '#00e599', range: [9, 18], symbol: '0' },
                { label: msg.timeFuture || 'Future', color: '#ffd700', range: [18, 27], symbol: '+1' },
              ].map((layer, li) => (
                <div key={layer.label} style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: '0.6rem', color: layer.color, marginBottom: '0.15rem' }}>{layer.label}</div>
                  <div style={{ fontSize: '0.55rem', opacity: 0.4, marginBottom: '0.2rem', fontFamily: 'monospace' }}>trit = {layer.symbol}</div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2px' }}>
                    {Array.from({ length: 9 }, (_, i) => {
                      const idx = layer.range[0] + i;
                      // Heartbeat: light up cells sequentially when active
                      const active = heartbeatActive && (Math.floor(heartbeatPhase / 3) % 3 === li);
                      return (
                        <motion.div
                          key={idx}
                          animate={heartbeatActive ? {
                            opacity: [0.3, 1, 0.3],
                            borderColor: [
                              'rgba(255,255,255,0.06)',
                              layer.color,
                              'rgba(255,255,255,0.06)',
                            ],
                          } : {}}
                          transition={{
                            duration: 1.618,
                            delay: (li * 0.54) + (i * 0.06),
                            repeat: heartbeatActive ? Infinity : 0,
                          }}
                          style={{
                            width: '20px', height: '20px',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            fontSize: '0.55rem',
                            background: 'rgba(255,255,255,0.03)',
                            border: `1px solid rgba(255,255,255,0.06)`,
                            borderRadius: '2px',
                            color: `${layer.color}88`,
                            fontFamily: 'monospace',
                          }}
                        >
                          {idx + 1}
                        </motion.div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
            <div style={{ marginTop: '0.5rem', opacity: 0.3, fontSize: '0.65rem', fontFamily: 'monospace' }}>
              {msg.timeDisclaimer || 'Experimental mathematics \u2014 pattern exploration, not proven physics'}
            </div>
          </div>
        </motion.div>
      )}

      {/* Stargate Drum */}
      <StargateDrum
        constants={data?.constants ?? []}
        isDecomposing={loading && (inputMode === 'formula' || inputMode === 'manual')}
        result={customResult}
        highlightedConstant={highlightedConstant}
        highlightedGlyphs={highlightedGlyphs}
      />

      {/* Category filter */}
      <div className="fade" style={{
        display: 'flex', gap: '0.5rem', justifyContent: 'center',
        marginBottom: '1rem', flexWrap: 'wrap'
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
        <button
          onClick={() => {
            const pool = filteredConstants.length > 0 ? filteredConstants : (data?.constants ?? []);
            if (pool.length === 0) return;
            const pick = pool[Math.floor(Math.random() * pool.length)];
            setInputMode('formula');
            setCustomValue(pick.target);
            setCustomResult(null);
            setGematriaResult(null);
            setHighlightedGlyphs([]);
            setFormulaError(null);
            setTimeout(async () => {
              const val = parseFloat(pick.target);
              if (!isNaN(val) && val > 0) {
                setLoading(true);
                try {
                  const result = await fitSingleValue(val);
                  setCustomResult(result);
                } finally {
                  setLoading(false);
                }
              }
            }, 50);
          }}
          style={{
            background: 'linear-gradient(135deg, rgba(255,215,0,0.25), rgba(255,165,0,0.15))',
            border: '1px solid rgba(255,215,0,0.5)',
            borderRadius: '20px',
            padding: '0.4rem 1rem',
            color: '#ffd700',
            fontSize: '0.8rem',
            cursor: 'pointer',
            transition: 'all 0.2s',
            fontWeight: 'bold',
          }}
        >
          {msg.randomSacred || '\u2728 Random'}
        </button>
      </div>

      {/* Sacred Geometry Info Panel — shown when sacred_geometry category is active */}
      {category === 'sacred_geometry' && (
        <motion.div
          className="fade"
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          style={{
            maxWidth: 'min(600px, 90vw)', margin: '0 auto 1.5rem',
            background: 'rgba(255,215,0,0.04)',
            border: '1px solid rgba(255,215,0,0.12)',
            borderRadius: '12px', padding: '1rem 1.5rem',
            fontFamily: 'monospace', fontSize: '0.8rem',
            lineHeight: 1.8,
          }}
        >
          <div style={{ color: '#ffd700', marginBottom: '0.5rem', fontSize: '0.85rem', fontWeight: 'bold' }}>
            {msg.geomInfoTitle || 'Sacred Geometry Bridge v2.0'}
          </div>
          <div style={{ opacity: 0.7 }}>
            <div style={{ marginBottom: '0.4rem' }}>
              <span style={{ color: '#ffd700' }}>{'\u2728'} </span>
              {msg.goldenSpiral || 'Golden Spiral: r(\u03B8) = a \u00D7 \u03C6^(2\u03B8/\u03C0)'}
              <span style={{ opacity: 0.4, fontSize: '0.7rem' }}> — growth = \u03C6 per 90\u00B0</span>
            </div>
            <div style={{ marginBottom: '0.4rem' }}>
              <span style={{ color: '#00e599' }}>{'\u2B22'} </span>
              {msg.copticCube || 'Coptic Cube: 27 = 3\u00B3 = 1 tryte'}
              <span style={{ opacity: 0.4, fontSize: '0.7rem' }}> — {msg.copticSum || '\u03A3 = 4995'}</span>
            </div>
            <div style={{ marginBottom: '0.4rem' }}>
              <span style={{ color: '#aa66ff' }}>{'\u0394'} </span>
              {msg.trinityIdentity || '\u03C6\u00B2 + 1/\u03C6\u00B2 = 3 = TRINITY'}
            </div>
          </div>
          <div style={{ marginTop: '0.5rem', opacity: 0.3, fontSize: '0.7rem' }}>
            {msg.cliHint || "Run 'tri geom sacred' for CLI version"}
          </div>
        </motion.div>
      )}

      {/* Constants grid */}
      <div className="fade" style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(min(300px, 100%), 1fr))',
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
