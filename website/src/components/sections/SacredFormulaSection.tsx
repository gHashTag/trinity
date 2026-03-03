"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import StargateDrum from '../StargateDrum';
import { useI18n } from '../../i18n/context';
import { fetchSacredFormula, fitSingleValue, fetchGematria, computeFromParams, findBestMatch, generateRandomFormula, PARAM_BOUNDS, type SacredFormulaResponse, type SacredConstantResult, type SingleFitResponse, type GematriaResponse } from '../../services/chatApi';

type Category = 'all' | 'particle_physics' | 'quantum' | 'cosmology' | 'quantum_gravity';
const CATEGORY_KEYS: Category[] = ['all', 'particle_physics', 'quantum', 'cosmology', 'quantum_gravity'];

type InputMode = 'formula' | 'manual' | 'gematria';
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
        marginBottom: '0.75rem',
      }}>
        {(['formula', 'manual', 'gematria'] as InputMode[]).map(mode => (
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
            }}
            style={{
              background: inputMode === mode ? 'rgba(255,215,0,0.15)' : 'transparent',
              border: `1px solid ${inputMode === mode ? 'rgba(255,215,0,0.5)' : 'rgba(255,255,255,0.1)'}`,
              borderRadius: '20px',
              padding: '0.35rem 1.2rem',
              color: inputMode === mode ? '#ffd700' : 'var(--muted)',
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
                : (msg.modeGematria || 'Gematria')}
          </button>
        ))}
      </div>

      {/* Action buttons: Random, Reset, Find Best */}
      <div className="fade" style={{
        display: 'flex', gap: '0.5rem', justifyContent: 'center',
        marginBottom: '1rem',
      }}>
        <button
          onClick={() => {
            const random = generateRandomFormula();
            setParams({ n: String(random.n), k: String(random.k), m: String(random.m), p: String(random.p), q: String(random.q) });
            setInputMode('manual');
            setCustomResult({ fit: { n: random.n, k: random.k, m: random.m, p: random.p, q: random.q }, computed: random.value, error_pct: 0 });
            setCustomValue('');
            setGematriaResult(null);
            setHighlightedGlyphs([]);
            setFormulaError(null);
            setParamErrors({ n: null, k: null, m: null, p: null, q: null });
            setHighlightedConstant(null);
          }}
          style={{
            background: 'rgba(0,229,153,0.1)',
            border: '1px solid rgba(0,229,153,0.3)',
            borderRadius: '20px',
            padding: '0.35rem 1.2rem',
            color: '#00e599',
            fontSize: '0.8rem',
            cursor: 'pointer',
            transition: 'all 0.2s',
            fontFamily: 'monospace',
          }}
        >
          {msg.random || 'Random'}
        </button>
        <button
          onClick={() => {
            setParams({ n: '1', k: '0', m: '0', p: '0', q: '0' });
            setCustomResult(null);
            setCustomValue('');
            setGematriaResult(null);
            setHighlightedGlyphs([]);
            setFormulaError(null);
            setParamErrors({ n: null, k: null, m: null, p: null, q: null });
            setHighlightedConstant(null);
          }}
          style={{
            background: 'rgba(255,107,107,0.1)',
            border: '1px solid rgba(255,107,107,0.3)',
            borderRadius: '20px',
            padding: '0.35rem 1.2rem',
            color: '#ff6b6b',
            fontSize: '0.8rem',
            cursor: 'pointer',
            transition: 'all 0.2s',
            fontFamily: 'monospace',
          }}
        >
          {msg.reset || 'Reset'}
        </button>
        {customResult && customResult.computed > 0 && (
          <button
            onClick={() => {
              const match = findBestMatch(customResult.computed);
              if (match) {
                setHighlightedConstant(match.symbol);
              }
            }}
            style={{
              background: 'rgba(255,215,0,0.1)',
              border: '1px solid rgba(255,215,0,0.3)',
              borderRadius: '20px',
              padding: '0.35rem 1.2rem',
              color: '#ffd700',
              fontSize: '0.8rem',
              cursor: 'pointer',
              transition: 'all 0.2s',
              fontFamily: 'monospace',
            }}
          >
            {msg.findBest || 'Find Best'}
          </button>
        )}
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
