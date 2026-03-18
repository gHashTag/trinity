"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import {
  fetchSacredFormula,
  fetchGematria,
  fetchAgentMuStatus,
  fetchAgentMuSacredMath,
  fitSingleValue,
  type SacredFormulaResponse,
  type SacredConstantResult,
  type GematriaResponse,
  type AgentMuStatus,
  type SacredMathData,
} from '../../services/chatApi';

// Style constants
const GOLDEN = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';

const GLASS_STYLE: React.CSSProperties = {
  background: 'rgba(255, 255, 255, 0.05)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  border: '1px solid rgba(255, 215, 0, 0.2)',
  borderRadius: '8px',
};

const GLASS_STYLE_CYAN: React.CSSProperties = {
  ...GLASS_STYLE,
  borderColor: 'rgba(0, 204, 255, 0.2)',
};

const GLASS_STYLE_PURPLE: React.CSSProperties = {
  ...GLASS_STYLE,
  borderColor: 'rgba(170, 102, 255, 0.2)',
};

// Live polling interval (500ms)
const POLL_INTERVAL = 500;

// Widget component wrapper
function Widget({
  title,
  color,
  children,
  className = '',
}: {
  title: string;
  color: string;
  children: React.ReactNode;
  className?: string;
}) {
  const glassColor = color === GOLDEN ? GLASS_STYLE : color === CYAN ? GLASS_STYLE_CYAN : GLASS_STYLE_PURPLE;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className={`sacred-widget ${className}`}
      style={{
        ...glassColor,
        padding: '1rem',
        marginBottom: '1rem',
      }}
    >
      <h3
        style={{
          color,
          fontSize: '0.9rem',
          fontWeight: 600,
          marginBottom: '0.75rem',
          fontFamily: 'Outfit, sans-serif',
          textTransform: 'uppercase',
          letterSpacing: '0.05em',
        }}
      >
        {title}
      </h3>
      {children}
    </motion.div>
  );
}

// Metric display component
function Metric({
  label,
  value,
  unit = '',
  color = GOLDEN,
  size = 'normal',
}: {
  label: string;
  value: string | number;
  unit?: string;
  color?: string;
  size?: 'small' | 'normal' | 'large';
}) {
  const fontSize = size === 'small' ? '0.75rem' : size === 'large' ? '1.5rem' : '1rem';

  return (
    <div style={{ marginBottom: '0.5rem' }}>
      <div
        style={{
          fontSize: '0.7rem',
          color: 'rgba(255, 255, 255, 0.5)',
          marginBottom: '0.25rem',
          fontFamily: 'Outfit, sans-serif',
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize,
          fontWeight: 700,
          color,
          fontFamily: 'JetBrains Mono, monospace',
        }}
      >
        {value}
        {unit && <span style={{ fontSize: '0.8em', marginLeft: '0.2em', opacity: 0.7 }}>{unit}</span>}
      </div>
    </div>
  );
}

// Gematria Live Widget
function GematriaLiveWidget({ gematriaResult }: { gematriaResult: GematriaResponse | null }) {
  const [input, setInput] = useState('');
  const [result, setResult] = useState<GematriaResponse | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (gematriaResult) {
      setResult(gematriaResult);
    }
  }, [gematriaResult]);

  const handleDecompose = async () => {
    if (!input.trim()) return;
    setLoading(true);
    try {
      const res = await fetchGematria(input);
      setResult(res);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Widget title="Coptic Gematria Live" color={GOLDEN}>
      <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem' }}>
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Enter text or number..."
          onKeyPress={(e) => e.key === 'Enter' && handleDecompose()}
          style={{
            flex: 1,
            background: 'rgba(255, 255, 255, 0.1)',
            border: '1px solid rgba(255, 215, 0, 0.3)',
            borderRadius: '4px',
            padding: '0.5rem',
            color: '#fff',
            fontFamily: 'JetBrains Mono, monospace',
            fontSize: '0.85rem',
          }}
        />
        <button
          onClick={handleDecompose}
          disabled={loading}
          style={{
            background: loading ? 'rgba(255, 215, 0, 0.3)' : 'rgba(255, 215, 0, 0.2)',
            border: '1px solid rgba(255, 215, 0, 0.5)',
            borderRadius: '4px',
            padding: '0.5rem 1rem',
            color: GOLDEN,
            fontFamily: 'Outfit, sans-serif',
            fontWeight: 600,
            fontSize: '0.8rem',
            cursor: loading ? 'wait' : 'pointer',
            transition: 'all 0.2s',
          }}
        >
          {loading ? '...' : 'GO'}
        </button>
      </div>

      {result && result.glyphs.length > 0 && (
        <div>
          <Metric label="Total Value" value={result.total} color={GOLDEN} size="large" />
          <div style={{ marginBottom: '0.5rem' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255, 255, 255, 0.5)', marginBottom: '0.25rem' }}>
              Glyph Decomposition
            </div>
            <div
              style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: '0.25rem',
                fontFamily: 'monospace',
              }}
            >
              {result.glyphs.map((g, i) => (
                <span
                  key={i}
                  style={{
                    background: 'rgba(255, 215, 0, 0.1)',
                    border: '1px solid rgba(255, 215, 0, 0.3)',
                    borderRadius: '4px',
                    padding: '0.25rem 0.5rem',
                    fontSize: '1rem',
                    color: GOLDEN,
                  }}
                  title={`Value: ${g.value}`}
                >
                  {g.glyph}
                </span>
              ))}
            </div>
          </div>

          {result.sacred_fit && (
            <div>
              <Metric
                label="Sacred Formula Fit"
                value={`V = ${result.sacred_fit.n} × 3^${result.sacred_fit.k} × π^${result.sacred_fit.m} × φ^${result.sacred_fit.p} × e^${result.sacred_fit.q}`}
                color={CYAN}
                size="small"
              />
              <Metric
                label="Computed"
                value={result.sacred_computed?.toFixed(6) || 'N/A'}
                color={CYAN}
              />
              <Metric
                label="Error"
                value={result.sacred_error_pct?.toFixed(4) || 'N/A'}
                unit="%"
                color={result.sacred_error_pct && result.sacred_error_pct < 1 ? GOLDEN : PURPLE}
              />
            </div>
          )}
        </div>
      )}

      {result && result.glyphs.length === 0 && (
        <div style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.5)' }}>
          No valid glyphs found
        </div>
      )}
    </Widget>
  );
}

// Formula Decomposition Widget
function FormulaDecompositionWidget({ constants }: { constants: SacredConstantResult[] }) {
  const [selected, setSelected] = useState<SacredConstantResult | null>(null);

  useEffect(() => {
    if (constants.length > 0 && !selected) {
      setSelected(constants[0]);
    }
  }, [constants, selected]);

  return (
    <Widget title="Formula Decomposition" color={CYAN}>
      <div style={{ marginBottom: '0.75rem' }}>
        <select
          value={selected?.name || ''}
          onChange={(e) => {
            const found = constants.find((c) => c.name === e.target.value);
            if (found) setSelected(found);
          }}
          style={{
            width: '100%',
            background: 'rgba(0, 204, 255, 0.1)',
            border: '1px solid rgba(0, 204, 255, 0.3)',
            borderRadius: '4px',
            padding: '0.5rem',
            color: CYAN,
            fontFamily: 'JetBrains Mono, monospace',
            fontSize: '0.8rem',
          }}
        >
          {constants.map((c) => (
            <option key={c.symbol} value={c.name}>
              {c.name}
            </option>
          ))}
        </select>
      </div>

      {selected && (
        <div>
          <Metric label="Target" value={selected.target} color={CYAN} />
          <Metric
            label="Decomposition"
            value={`V = ${selected.fit.n} × 3^${selected.fit.k} × π^${selected.fit.m} × φ^${selected.fit.p} × e^${selected.fit.q}`}
            color={GOLDEN}
            size="small"
          />
          <Metric label="Computed" value={selected.computed.toFixed(6)} color={CYAN} />
          <Metric
            label="Error"
            value={selected.error_pct.toFixed(4)}
            unit="%"
            color={selected.error_pct < 0.1 ? GOLDEN : selected.error_pct < 1 ? CYAN : PURPLE}
          />
        </div>
      )}
    </Widget>
  );
}

// Sacred Constants Widget
function SacredConstantsWidget({ constants }: { constants: SacredConstantResult[] }) {
  const [filter, setFilter] = useState<'all' | 'best' | 'all_exact'>('all');

  const filtered = constants.filter((c) => {
    if (filter === 'best') return c.error_pct < 0.1;
    if (filter === 'all_exact') return c.error_pct < 0.01;
    return true;
  });

  const matchRate = ((filtered.length / constants.length) * 100).toFixed(1);

  return (
    <Widget title="Sacred Constants (42 Total)" color={PURPLE}>
      <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem', flexWrap: 'wrap' }}>
        {[
          { key: 'all', label: 'All', color: PURPLE },
          { key: 'best', label: '< 0.1%', color: GOLDEN },
          { key: 'all_exact', label: '< 0.01%', color: CYAN },
        ].map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key as typeof filter)}
            style={{
              background: filter === f.key ? `${f.color}33` : 'rgba(255, 255, 255, 0.05)',
              border: `1px solid ${filter === f.key ? f.color : 'rgba(255, 255, 255, 0.2)'}`,
              borderRadius: '4px',
              padding: '0.3rem 0.6rem',
              color: filter === f.key ? f.color : 'rgba(255, 255, 255, 0.7)',
              fontFamily: 'Outfit, sans-serif',
              fontWeight: 600,
              fontSize: '0.7rem',
              cursor: 'pointer',
              transition: 'all 0.2s',
            }}
          >
            {f.label}
          </button>
        ))}
      </div>

      <Metric label="Matches" value={`${filtered.length} / ${constants.length}`} unit={`(${matchRate}%)`} color={PURPLE} />

      <div
        style={{
          maxHeight: '200px',
          overflowY: 'auto',
          paddingRight: '0.5rem',
        }}
      >
        {filtered.slice(0, 15).map((c) => (
          <div
            key={c.symbol}
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '0.4rem 0',
              borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
              fontSize: '0.75rem',
            }}
          >
            <span style={{ color: 'rgba(255, 255, 255, 0.8)', fontFamily: 'Outfit, sans-serif' }}>
              {c.name}
            </span>
            <span
              style={{
                color: c.error_pct < 0.01 ? CYAN : c.error_pct < 0.1 ? GOLDEN : PURPLE,
                fontFamily: 'JetBrains Mono, monospace',
                fontWeight: 600,
              }}
            >
              {c.error_pct < 0.01 ? 'EXACT' : `${c.error_pct.toFixed(3)}%`}
            </span>
          </div>
        ))}
      </div>
    </Widget>
  );
}

// Phi Score Widget
function PhiScoreWidget({ sacredMath }: { sacredMath: SacredMathData | null }) {
  if (!sacredMath) {
    return (
      <Widget title="Phi Score" color={GOLDEN}>
        <div style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.5)' }}>Loading...</div>
      </Widget>
    );
  }

  const phiScore = (sacredMath.phi * sacredMath.trinity_score).toFixed(6);

  return (
    <Widget title="Phi Score" color={GOLDEN}>
      <Metric label="φ (Phi)" value={sacredMath.phi.toFixed(15)} color={GOLDEN} />
      <Metric label="Trinity Score" value={sacredMath.trinity_score.toFixed(6)} color={CYAN} />
      <Metric label="φ × Trinity" value={phiScore} color={PURPLE} size="large" />
      <Metric label="μ (Mu)" value={sacredMath.mu.toFixed(6)} color={GOLDEN} />
      <Metric label="Lucas L(10)" value={sacredMath.lucas_10} color={CYAN} />
    </Widget>
  );
}

// Trinity Alignment Widget
function TrinityAlignmentWidget({ sacredMath }: { sacredMath: SacredMathData | null }) {
  if (!sacredMath) {
    return (
      <Widget title="Trinity Alignment" color={CYAN}>
        <div style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.5)' }}>Loading...</div>
      </Widget>
    );
  }

  const phiSq = Math.pow(sacredMath.phi, 2);
  const phiInvSq = Math.pow(1 / sacredMath.phi, 2);
  const sum = phiSq + phiInvSq;
  const diff = Math.abs(sum - sacredMath.trinity_score);
  const alignment = (1 - diff / sacredMath.trinity_score) * 100;

  return (
    <Widget title="Trinity Alignment" color={CYAN}>
      <div style={{ marginBottom: '1rem' }}>
        <div
          style={{
            fontSize: '0.7rem',
            color: 'rgba(255, 255, 255, 0.5)',
            marginBottom: '0.5rem',
            fontFamily: 'Outfit, sans-serif',
          }}
        >
          φ² + 1/φ² = 3
        </div>
        <div
          style={{
            fontSize: '0.85rem',
            color: 'rgba(255, 255, 255, 0.8)',
            fontFamily: 'JetBrains Mono, monospace',
            marginBottom: '0.25rem',
          }}
        >
          φ² = {phiSq.toFixed(15)}
        </div>
        <div
          style={{
            fontSize: '0.85rem',
            color: 'rgba(255, 255, 255, 0.8)',
            fontFamily: 'JetBrains Mono, monospace',
            marginBottom: '0.25rem',
          }}
        >
          1/φ² = {phiInvSq.toFixed(15)}
        </div>
        <div
          style={{
            fontSize: '1rem',
            fontWeight: 700,
            color: GOLDEN,
            fontFamily: 'JetBrains Mono, monospace',
          }}
        >
          Sum = {sum.toFixed(15)}
        </div>
      </div>

      <Metric label="Difference from 3" value={diff.toExponential(4)} color={PURPLE} />
      <Metric
        label="Alignment"
        value={alignment.toFixed(6)}
        unit="%"
        color={alignment > 99.9 ? CYAN : alignment > 99 ? GOLDEN : PURPLE}
      />

      {/* Visual bar */}
      <div style={{ marginTop: '0.75rem' }}>
        <div
          style={{
            width: '100%',
            height: '8px',
            background: 'rgba(255, 255, 255, 0.1)',
            borderRadius: '4px',
            overflow: 'hidden',
          }}
        >
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${alignment}%` }}
            transition={{ duration: 1 }}
            style={{
              height: '100%',
              background: `linear-gradient(90deg, ${PURPLE}, ${GOLDEN}, ${CYAN})`,
            }}
          />
        </div>
      </div>
    </Widget>
  );
}

// Evolution Progress Widget
function EvolutionProgressWidget({ agentStatus }: { agentStatus: AgentMuStatus | null }) {
  if (!agentStatus) {
    return (
      <Widget title="Self-Evolution Progress" color={PURPLE}>
        <div style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.5)' }}>Loading...</div>
      </Widget>
    );
  }

  const intelligencePercent = Math.min((agentStatus.intelligence_multiplier / 100) * 100, 100);
  const successPercent = agentStatus.success_rate * 100;

  return (
    <Widget title="Self-Evolution Progress" color={PURPLE}>
      <Metric label="Total Fixes" value={agentStatus.total_fixes} color={PURPLE} />
      <Metric label="Success Rate" value={successPercent.toFixed(2)} unit="%" color={CYAN} />
      <Metric
        label="Current μ"
        value={agentStatus.current_mu.toFixed(6)}
        color={GOLDEN}
      />
      <Metric
        label="Intelligence Multiplier"
        value={agentStatus.intelligence_multiplier.toFixed(4)}
        color={CYAN}
        size="large"
      />
      <Metric
        label="Fixes/Second"
        value={agentStatus.fixes_per_second.toFixed(4)}
        color={PURPLE}
      />
      <Metric label="Uptime" value={agentStatus.uptime_seconds} unit="s" color={GOLDEN} />

      {/* Progress bars */}
      <div style={{ marginTop: '0.75rem' }}>
        <div style={{ marginBottom: '0.5rem' }}>
          <div
            style={{
              fontSize: '0.7rem',
              color: 'rgba(255, 255, 255, 0.5)',
              marginBottom: '0.25rem',
              fontFamily: 'Outfit, sans-serif',
            }}
          >
            Intelligence Growth
          </div>
          <div
            style={{
              width: '100%',
              height: '8px',
              background: 'rgba(255, 255, 255, 0.1)',
              borderRadius: '4px',
              overflow: 'hidden',
            }}
          >
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${intelligencePercent}%` }}
              transition={{ duration: 1 }}
              style={{
                height: '100%',
                background: `linear-gradient(90deg, ${PURPLE}, ${CYAN})`,
              }}
            />
          </div>
        </div>

        <div>
          <div
            style={{
              fontSize: '0.7rem',
              color: 'rgba(255, 255, 255, 0.5)',
              marginBottom: '0.25rem',
              fontFamily: 'Outfit, sans-serif',
            }}
          >
            Success Rate
          </div>
          <div
            style={{
              width: '100%',
              height: '8px',
              background: 'rgba(255, 255, 255, 0.1)',
              borderRadius: '4px',
              overflow: 'hidden',
            }}
          >
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${successPercent}%` }}
              transition={{ duration: 1 }}
              style={{
                height: '100%',
                background: `linear-gradient(90deg, ${GOLDEN}, ${CYAN})`,
              }}
            />
          </div>
        </div>
      </div>
    </Widget>
  );
}

// Main Dashboard Component
export default function SacredIntelligenceDashboard() {
  const { t } = useI18n();
  const msg = (t as any).sacredIntelligence || {};

  const [formulaData, setFormulaData] = useState<SacredFormulaResponse | null>(null);
  const [gematriaResult, setGematriaResult] = useState<GematriaResponse | null>(null);
  const [agentStatus, setAgentStatus] = useState<AgentMuStatus | null>(null);
  const [sacredMath, setSacredMath] = useState<SacredMathData | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<number>(Date.now());

  // Initial data fetch
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const [formula, agent, math] = await Promise.all([
          fetchSacredFormula(),
          fetchAgentMuStatus(),
          fetchAgentMuSacredMath(),
        ]);

        setFormulaData(formula);
        setAgentStatus(agent);
        setSacredMath(math);

        // Initial gematria demo
        const demoGematria = await fetchGematria('TRINITY');
        setGematriaResult(demoGematria);
      } catch (error) {
        console.error('Failed to fetch sacred intelligence data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  // Live polling for updates
  useEffect(() => {
    if (loading) return;

    const interval = setInterval(async () => {
      try {
        const [agent, math] = await Promise.all([
          fetchAgentMuStatus(),
          fetchAgentMuSacredMath(),
        ]);

        setAgentStatus(agent);
        setSacredMath(math);
        setLastUpdate(Date.now());
      } catch (error) {
        console.error('Polling error:', error);
      }
    }, POLL_INTERVAL);

    return () => clearInterval(interval);
  }, [loading]);

  if (loading) {
    return (
      <Section id="sacred-intelligence-dashboard">
        <div style={{ textAlign: 'center', padding: 'clamp(1.5rem, 5vw, 3rem)' }}>
          <div style={{ color: GOLDEN, fontSize: 'clamp(1.2rem, 4vw, 1.5rem)', marginBottom: '1rem' }}>Loading Sacred Intelligence...</div>
          <div style={{ color: 'rgba(255, 255, 255, 0.5)', fontSize: '0.9rem' }}>Connecting to quantum field...</div>
        </div>
      </Section>
    );
  }

  return (
    <Section id="sacred-intelligence-dashboard">
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5 }}
        style={{
          maxWidth: '1400px',
          margin: '0 auto',
          padding: '2rem 1rem',
        }}
      >
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: '3rem' }}>
          <h2
            style={{
              fontSize: 'clamp(2rem, 5vw, 3.5rem)',
              fontWeight: 700,
              marginBottom: '1rem',
              background: `linear-gradient(135deg, ${GOLDEN}, ${CYAN}, ${PURPLE})`,
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              fontFamily: 'Outfit, sans-serif',
            }}
          >
            Sacred Intelligence Dashboard
          </h2>
          <p
            style={{
              fontSize: '1rem',
              color: 'rgba(255, 255, 255, 0.7)',
              fontFamily: 'Outfit, sans-serif',
              maxWidth: '600px',
              margin: '0 auto',
            }}
          >
            Real-time sacred mathematics, Coptic gematria, and self-evolution metrics
          </p>
          <div
            style={{
              marginTop: '1rem',
              fontSize: '0.75rem',
              color: 'rgba(255, 255, 255, 0.4)',
              fontFamily: 'JetBrains Mono, monospace',
            }}
          >
            Last update: {new Date(lastUpdate).toLocaleTimeString()} • Polling every {POLL_INTERVAL}ms
          </div>
        </div>

        {/* Dashboard Grid */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(min(320px, 100%), 1fr))',
            gap: '1.5rem',
          }}
        >
          {/* Row 1: Gematria + Formula Decomposition */}
          <GematriaLiveWidget gematriaResult={gematriaResult} />
          {formulaData && <FormulaDecompositionWidget constants={formulaData.constants} />}

          {/* Row 2: Sacred Constants + Phi Score */}
          {formulaData && <SacredConstantsWidget constants={formulaData.constants} />}
          <PhiScoreWidget sacredMath={sacredMath} />

          {/* Row 3: Trinity Alignment + Evolution Progress */}
          <TrinityAlignmentWidget sacredMath={sacredMath} />
          <EvolutionProgressWidget agentStatus={agentStatus} />
        </div>

        {/* Footer Info */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
          style={{
            marginTop: '3rem',
            padding: '1.5rem',
            ...GLASS_STYLE,
            textAlign: 'center',
          }}
        >
          <div style={{ fontSize: '0.85rem', color: 'rgba(255, 255, 255, 0.6)', fontFamily: 'Outfit, sans-serif' }}>
            <strong style={{ color: GOLDEN }}>Sacred Formula:</strong> V = n × 3^k × π^m × φ^p × e^q •{' '}
            <strong style={{ color: CYAN }}>Trinity Identity:</strong> φ² + 1/φ² = 3 •{' '}
            <strong style={{ color: PURPLE }}>μ (Mu):</strong> {sacredMath?.mu.toFixed(6)} per fix
          </div>
        </motion.div>
      </motion.div>
    </Section>
  );
}
