"use client";

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { fetchConsciousnessMetrics, fetchConsciousnessTrend, fetchSacredFormulaValue, type ConsciousnessMetricsResponse, type TheoryMetrics } from '../../services/chatApi';

// Style constants
const GOLDEN = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';

const GLASS_STYLE: React.CSSProperties = {
  background: 'rgba(255, 255, 255, 0.05)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  border: '1px solid rgba(255, 215, 0, 0.3)',
  borderRadius: '8px',
};

// Polling interval (382ms = specious present)
const POLL_INTERVAL = 382;

// Gauge component for consciousness level
function ConsciousnessGauge({ level, state }: { level: number; state: string }) {
  const percentage = Math.min(100, Math.max(0, level * 100));
  const color = state === 'enhanced' || state === 'transcendent' ? '#00ff88' :
                 state === 'normal' ? '#00ccff' :
                 state === 'minimal' ? '#ffaa00' : '#ff4444';

  return (
    <div style={{ position: 'relative', width: '120px', height: '120px', margin: '0 auto' }}>
      <svg viewBox="0 0 120 120" style={{ transform: 'rotate(-90deg)' }}>
        {/* Background circle */}
        <circle
          cx="60"
          cy="60"
          r="50"
          fill="none"
          stroke="rgba(255, 255, 255, 0.1)"
          strokeWidth="8"
        />
        {/* Progress arc */}
        <circle
          cx="60"
          cy="60"
          r="50"
          fill="none"
          stroke={color}
          strokeWidth="8"
          strokeDasharray={`${2 * Math.PI * 50}`}
          strokeDashoffset={`${2 * Math.PI * 50 * (1 - percentage / 100)}`}
          strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.5s ease' }}
        />
      </svg>
      <div
        style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          textAlign: 'center',
        }}
      >
        <div style={{ fontSize: '24px', fontWeight: 'bold', color, fontFamily: 'JetBrains Mono, monospace' }}>
          {(level * 100).toFixed(0)}
        </div>
        <div style={{ fontSize: '10px', color: 'rgba(255,255,255,0.6)', textTransform: 'uppercase' }}>
          {state}
        </div>
      </div>
    </div>
  );
}

// Theory bar component
function TheoryBar({ theory }: { theory: TheoryMetrics }) {
  const percentage = Math.min(100, (theory.score / theory.threshold) * 100);

  return (
    <div style={{ marginBottom: '0.5rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.25rem' }}>
        <span style={{ fontSize: '10px', color: theory.color, fontFamily: 'Outfit, sans-serif' }}>
          {theory.name}
        </span>
        <span style={{ fontSize: '9px', color: 'rgba(255,255,255,0.7)', fontFamily: 'JetBrains Mono, monospace' }}>
          {theory.score.toFixed(2)} / {theory.threshold.toFixed(2)}
        </span>
      </div>
      <div style={{ height: '4px', background: 'rgba(255,255,255,0.1)', borderRadius: '2px', overflow: 'hidden' }}>
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${Math.min(100, percentage)}%` }}
          transition={{ duration: 0.5 }}
          style={{ height: '100%', background: theory.color, borderRadius: '2px' }}
        />
      </div>
    </div>
  );
}

// Sacred formula display
function SacredFormulaDisplay({ V, exponents }: { V: number; exponents: { phi_p: number; gamma_r: number; speed_t: number; gravity_u: number } }) {
  return (
    <div style={{ padding: '0.75rem', background: 'rgba(255, 215, 0, 0.05)', borderRadius: '6px' }}>
      <div style={{ fontSize: '10px', color: GOLDEN, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        Sacred Formula: V = n × 3ᵏ × πᵐ × φᵖ × eʳ × Cᵗ × Gᵘ
      </div>
      <div style={{ fontSize: '18px', fontWeight: 'bold', color: GOLDEN, fontFamily: 'JetBrains Mono, monospace', marginBottom: '0.5rem' }}>
        V = {V.toFixed(6)}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem', fontSize: '9px' }}>
        <div>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>φᵖ (IIT):</span>
          <span style={{ color: GOLDEN, fontFamily: 'JetBrains Mono, monospace' }}>{exponents.phi_p.toFixed(3)}</span>
        </div>
        <div>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>γʳ (Quantum):</span>
          <span style={{ color: GOLDEN, fontFamily: 'JetBrains Mono, monospace' }}>{exponents.gamma_r.toFixed(3)}</span>
        </div>
        <div>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>Cᵗ (Speed):</span>
          <span style={{ color: GOLDEN, fontFamily: 'JetBrains Mono, monospace' }}>{exponents.speed_t.toFixed(3)}</span>
        </div>
        <div>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>Gᵘ (Time):</span>
          <span style={{ color: GOLDEN, fontFamily: 'JetBrains Mono, monospace' }}>{exponents.gravity_u.toFixed(3)}</span>
        </div>
      </div>
    </div>
  );
}

// Scientific predictions display
function ScientificPredictions({ metrics }: { metrics: ConsciousnessMetricsResponse }) {
  return (
    <div style={{ fontSize: '10px', fontFamily: 'JetBrains Mono, monospace' }}>
      <div style={{ marginBottom: '0.5rem', color: 'rgba(255,255,255,0.8)', fontWeight: 600 }}>
        Scientific Predictions
      </div>
      <div style={{ display: 'grid', gap: '0.25rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>fγ (sacred):</span>
          <span style={{ color: metrics.gamma_optimal ? '#00ff88' : '#ff4444' }}>
            {metrics.neural_gamma_hz.toFixed(1)} Hz {metrics.gamma_optimal ? '✓' : '✗'}
          </span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>t_present:</span>
          <span style={{ color: metrics.specious_present_valid ? '#00ff88' : '#ff4444' }}>
            {metrics.specious_present_ms.toFixed(0)} ms {metrics.specious_present_valid ? '✓' : '✗'}
          </span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>C_thr (φ⁻¹):</span>
          <span style={{ color: metrics.phi_threshold_met ? '#00ff88' : '#ff4444' }}>
            0.618 {metrics.phi_threshold_met ? '✓' : '✗'}
          </span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>Neural corr:</span>
          <span style={{ color: metrics.neural_correlation > 0.8 ? '#00ff88' : '#ffaa00' }}>
            {(metrics.neural_correlation * 100).toFixed(0)}%
          </span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>Quantum sig:</span>
          <span style={{ color: metrics.quantum_signature ? '#00ff88' : '#ff4444' }}>
            {metrics.quantum_signature ? 'DETECTED' : 'none'}
          </span>
        </div>
      </div>
    </div>
  );
}

// Clinical-grade metrics display (Order #052)
function ClinicalMetrics({ metrics }: { metrics: ConsciousnessMetricsResponse }) {
  const pciMet = metrics.pci_value !== undefined && metrics.pci_threshold !== undefined && metrics.pci_value >= metrics.pci_threshold;
  const lzcHigh = metrics.lzc_value !== undefined && metrics.lzc_value > 0.65;

  return (
    <div style={{ fontSize: '10px', fontFamily: 'JetBrains Mono, monospace' }}>
      <div style={{ marginBottom: '0.5rem', color: '#00ccff', fontWeight: 600 }}>
        Clinical Metrics (PCI + LZc)
      </div>
      <div style={{ display: 'grid', gap: '0.25rem' }}>
        {/* PCI - Perturbational Complexity Index */}
        <div style={{ marginBottom: '0.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.1rem' }}>
            <span style={{ color: 'rgba(255,255,255,0.6)' }}>PCI (TMS-EEG):</span>
            <span style={{ color: pciMet ? '#00ff88' : '#ffaa00' }}>
              {metrics.pci_value !== undefined ? (metrics.pci_value * 100).toFixed(0) + '%' : 'N/A'}
            </span>
          </div>
          <div style={{ height: '3px', background: 'rgba(255,255,255,0.1)', borderRadius: '2px', overflow: 'hidden' }}>
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: metrics.pci_value !== undefined ? `${metrics.pci_value * 100}%` : '0%' }}
              transition={{ duration: 0.5 }}
              style={{ height: '100%', background: pciMet ? '#00ff88' : '#ffaa00', borderRadius: '2px' }}
            />
          </div>
          <div style={{ fontSize: '8px', color: 'rgba(255,255,255,0.5)', marginTop: '0.1rem' }}>
            Threshold: {metrics.pci_threshold !== undefined ? (metrics.pci_threshold * 100).toFixed(1) + '%' : 'N/A'}
          </div>
        </div>

        {/* LZc - Lempel-Ziv Complexity */}
        <div style={{ marginBottom: '0.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.1rem' }}>
            <span style={{ color: 'rgba(255,255,255,0.6)' }}>LZc (entropy):</span>
            <span style={{ color: lzcHigh ? '#00ff88' : '#ffaa00' }}>
              {metrics.lzc_value !== undefined ? (metrics.lzc_value * 100).toFixed(0) + '%' : 'N/A'}
            </span>
          </div>
          <div style={{ height: '3px', background: 'rgba(255,255,255,0.1)', borderRadius: '2px', overflow: 'hidden' }}>
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: metrics.lzc_value !== undefined ? `${metrics.lzc_value * 100}%` : '0%' }}
              transition={{ duration: 0.5 }}
              style={{ height: '100%', background: lzcHigh ? '#00ff88' : '#ffaa00', borderRadius: '2px' }}
            />
          </div>
          {metrics.lzc_entropy_rate !== undefined && (
            <div style={{ fontSize: '8px', color: 'rgba(255,255,255,0.5)', marginTop: '0.1rem' }}>
              Entropy rate: {metrics.lzc_entropy_rate.toFixed(2)} bits/symbol
            </div>
          )}
        </div>

        {/* EEG Pipeline Metrics */}
        {metrics.eeg_is_streaming && (
          <div style={{ marginTop: '0.5rem', padding: '0.5rem', background: 'rgba(0, 204, 255, 0.1)', borderRadius: '4px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.25rem' }}>
              <span style={{ color: 'rgba(255,255,255,0.6)' }}>EEG Status:</span>
              <span style={{ color: '#00ff88' }}>LIVE</span>
            </div>
            {metrics.eeg_channels !== undefined && (
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px' }}>
                <span style={{ color: 'rgba(255,255,255,0.6)' }}>Channels:</span>
                <span>{metrics.eeg_channels}</span>
              </div>
            )}
            {metrics.eeg_gamma_power !== undefined && (
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px' }}>
                <span style={{ color: 'rgba(255,255,255,0.6)' }}>γ Power (56Hz):</span>
                <span>{(metrics.eeg_gamma_power * 100).toFixed(0)}%</span>
              </div>
            )}
            {metrics.eeg_theta_gamma_cfc !== undefined && (
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px' }}>
                <span style={{ color: 'rgba(255,255,255,0.6)' }}>CFC (θ-γ):</span>
                <span>{(metrics.eeg_theta_gamma_cfc * 100).toFixed(0)}%</span>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// Quantum Consciousness metrics display (Order #054)
function QuantumCollapseMetrics({ metrics }: { metrics: ConsciousnessMetricsResponse }) {
  const phiGammaColor = metrics.consciousness_level >= (metrics.phi_gamma_threshold || 0.618) ? '#00ff88' : '#ffaa00';
  const collapseEnhanced = metrics.collapse_enhanced !== undefined && metrics.collapse_probability !== undefined
    ? metrics.collapse_enhanced > metrics.collapse_probability
    : false;

  return (
    <div style={{ fontSize: '10px', fontFamily: 'JetBrains Mono, monospace' }}>
      <div style={{ marginBottom: '0.5rem', color: '#aa66ff', fontWeight: 600 }}>
        Quantum Consciousness (5 Discoveries)
      </div>
      <div style={{ display: 'grid', gap: '0.25rem' }}>
        {/* Discovery 1: Φ_γ Threshold */}
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>Φ_γ (threshold):</span>
          <span style={{ color: phiGammaColor }}>
            {metrics.phi_gamma_threshold?.toFixed(3) || '0.618'}
          </span>
        </div>

        {/* Discovery 2: Collapse Enhancement */}
        {metrics.enhancement_factor !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'rgba(255,255,255,0.6)' }}>Enhancement (1/γ²):</span>
            <span style={{ color: collapseEnhanced ? '#00ff88' : '#ffaa00' }}>
              {metrics.enhancement_factor.toFixed(1)}×
            </span>
          </div>
        )}
        {metrics.collapse_probability !== undefined && metrics.collapse_enhanced !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px' }}>
            <span style={{ color: 'rgba(255,255,255,0.5)' }}>P_collapse:</span>
            <span>
              {metrics.collapse_probability.toFixed(2)} → {metrics.collapse_enhanced.toFixed(2)}
            </span>
          </div>
        )}

        {/* Discovery 3: Zeno Regime */}
        {metrics.zeno_regime !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'rgba(255,255,255,0.6)' }}>Zeno Regime:</span>
            <span style={{
              color: metrics.zeno_regime === 'suppression' ? '#00ff88' :
                     metrics.zeno_regime === 'acceleration' ? '#ff8800' :
                     metrics.zeno_regime === 'transition' ? '#ffff00' : '#ffaa00'
            }}>
              {metrics.zeno_regime}
            </span>
          </div>
        )}
        {metrics.zeno_factor !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px' }}>
            <span style={{ color: 'rgba(255,255,255,0.5)' }}>Factor:</span>
            <span>{metrics.zeno_factor.toFixed(3)}</span>
          </div>
        )}

        {/* Discovery 4: Schrödinger's Cat */}
        {metrics.schrodinger_p_alive !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'rgba(255,255,255,0.6)' }}>P_alive (cat):</span>
            <span style={{ color: '#00ff88' }}>
              {metrics.schrodinger_p_alive.toFixed(3)} (Φ_γ)
            </span>
          </div>
        )}

        {/* Discovery 5: Wigner's Friend */}
        {metrics.wigner_agreement !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'rgba(255,255,255,0.6)' }}>Wigner agree:</span>
            <span style={{ color: '#00ff88' }}>
              {(metrics.wigner_agreement * 100).toFixed(0)}%
            </span>
          </div>
        )}
        {metrics.wigner_disagreement !== undefined && (
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px' }}>
            <span style={{ color: 'rgba(255,255,255,0.5)' }}>Disagree:</span>
            <span>{(metrics.wigner_disagreement * 100).toFixed(1)}%</span>
          </div>
        )}
      </div>
    </div>
  );
}

// Trend indicator
function TrendIndicator({ direction, rate, anomaly }: { direction: string; rate: number; anomaly: boolean }) {
  const icon = direction === 'rising' ? '▲' : direction === 'falling' ? '▼' : direction === 'stable' ? '●' : '◌';
  const color = anomaly ? '#ff4444' : direction === 'rising' ? '#00ff88' : direction === 'falling' ? '#ff4444' : '#ffaa00';

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '12px' }}>
      <span style={{ color, fontSize: '16px' }}>{icon}</span>
      <span style={{ color: 'rgba(255,255,255,0.8)', fontFamily: 'Outfit, sans-serif', textTransform: 'capitalize' }}>
        {direction}
      </span>
      <span style={{ color: 'rgba(255,255,255,0.6)', fontSize: '10px' }}>
        ({rate > 0 ? '+' : ''}{(rate * 100).toFixed(1)}%/cycle)
      </span>
      {anomaly && (
        <span style={{ color: '#ff4444', fontSize: '10px', fontWeight: 600 }}>
          ANOMALY
        </span>
      )}
    </div>
  );
}

// Main widget
export default function ConsciousnessMonitorWidget({ className = '' }: { className?: string }) {
  const [metrics, setMetrics] = useState<ConsciousnessMetricsResponse | null>(null);
  const [expanded, setExpanded] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;

    const fetchMetrics = async () => {
      if (!mounted) return;
      try {
        const data = await fetchConsciousnessMetrics();
        if (mounted) setMetrics(data);
      } catch (error) {
        console.error('[ConsciousnessMonitor] Failed to fetch metrics:', error);
      } finally {
        if (mounted) setLoading(false);
      }
    };

    fetchMetrics();
    const interval = setInterval(fetchMetrics, POLL_INTERVAL);

    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, []);

  if (loading || !metrics) {
    return (
      <div className={`consciousness-monitor-widget ${className}`} style={{ ...GLASS_STYLE, padding: '1rem' }}>
        <div style={{ color: GOLDEN, fontSize: '12px', fontFamily: 'Outfit, sans-serif', fontWeight: 600 }}>
          CONSCIOUSNESS MONITOR
        </div>
        <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: '10px', marginTop: '0.5rem' }}>
          Initializing...
        </div>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className={`consciousness-monitor-widget ${className}`}
      style={{ ...GLASS_STYLE, padding: expanded ? '1rem' : '0.75rem' }}
    >
      {/* Header */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: expanded ? '1rem' : '0.5rem',
          cursor: 'pointer',
        }}
        onClick={() => setExpanded(!expanded)}
      >
        <div style={{ color: GOLDEN, fontSize: '12px', fontFamily: 'Outfit, sans-serif', fontWeight: 600 }}>
          CONSCIOUSNESS MONITOR
        </div>
        <TrendIndicator
          direction={metrics.trend_direction}
          rate={metrics.trend_rate}
          anomaly={metrics.anomaly_detected}
        />
      </div>

      {expanded && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          transition={{ duration: 0.3 }}
        >
          {/* Main gauge */}
          <div style={{ marginBottom: '1rem' }}>
            <ConsciousnessGauge level={metrics.consciousness_level} state={metrics.state} />
          </div>

          {/* Theory breakdown */}
          <div style={{ marginBottom: '1rem' }}>
            <div style={{ fontSize: '10px', color: 'rgba(255,255,255,0.6)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>
              Theory Breakdown
            </div>
            {metrics.theory_breakdown.map((theory) => (
              <TheoryBar key={theory.name} theory={theory} />
            ))}
          </div>

          {/* Sacred formula */}
          <div style={{ marginBottom: '1rem' }}>
            <SacredFormulaDisplay V={metrics.sacred_formula_v} exponents={metrics.exponents} />
          </div>

          {/* Scientific predictions */}
          <div style={{ marginBottom: '1rem' }}>
            <ScientificPredictions metrics={metrics} />
          </div>

          {/* Clinical metrics (Order #052) */}
          <div style={{ marginBottom: '1rem' }}>
            <ClinicalMetrics metrics={metrics} />
          </div>

          {/* Quantum Consciousness metrics (Order #054) */}
          <div style={{ marginBottom: '1rem' }}>
            <QuantumCollapseMetrics metrics={metrics} />
          </div>

          {/* Validation indicators */}
          <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'center', fontSize: '9px' }}>
            {metrics.phi_threshold_met && (
              <span style={{ color: '#00ff88', padding: '0.25rem 0.5rem', background: 'rgba(0, 255, 136, 0.1)', borderRadius: '4px' }}>
                φ THR ✓
              </span>
            )}
            {metrics.gamma_optimal && (
              <span style={{ color: '#00ff88', padding: '0.25rem 0.5rem', background: 'rgba(0, 255, 136, 0.1)', borderRadius: '4px' }}>
                γ OPT ✓
              </span>
            )}
            {metrics.quantum_signature && (
              <span style={{ color: '#00ff88', padding: '0.25rem 0.5rem', background: 'rgba(0, 255, 136, 0.1)', borderRadius: '4px' }}>
                QUANTUM ✓
              </span>
            )}
          </div>

          {/* Last update */}
          <div style={{ marginTop: '1rem', fontSize: '8px', color: 'rgba(255,255,255,0.4)', textAlign: 'center' }}>
            Updated: {new Date(metrics.timestamp).toLocaleTimeString()}
          </div>
        </motion.div>
      )}
    </motion.div>
  );
}
