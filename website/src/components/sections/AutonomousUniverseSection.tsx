"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchAutonomousUniverse, type AutonomousUniverseResponse, type AutonomousUniverseMode } from '../../services/chatApi';

const MODES = [
  { key: 'autonomous', label: 'Autonomous' },
  { key: 'tune', label: 'Auto-Tune' },
  { key: 'evolve', label: 'Evolve' },
  { key: 'discover', label: 'Discover' },
  { key: 'snapshot', label: 'Snapshot' },
  { key: 'converge', label: 'Converge' },
  { key: 'reset', label: 'Reset' },
];

const MATERIYA_COLOR = '#00ccff';

const glass = {
  background: 'rgba(0, 204, 255, 0.1)',
  border: '1px solid rgba(0, 204, 255, 0.2)',
  borderRadius: '12px',
  backdropFilter: 'blur(8px)',
};

export default function AutonomousUniverseSection() {
  const { t } = useI18n();
  const [mode, setMode] = useState<keyof typeof MODES[number] | ''>('autonomous');
  const [data, setData] = useState<AutonomousUniverseMode | null>(null);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const loadData = async (m: keyof typeof MODES[number]) => {
    setLoading(true);
    try {
      const result = await fetchAutonomousUniverse(m);
      setData(result.data);
    } catch {
      console.error('Failed to load autonomous universe data:', m);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(mode); }, [mode]);

  return (
    <Section
      title="Autonomous Universe v3.5"
      version="3.5"
      icon="&#x1F9BE;"
      expanded={expanded}
      onToggle={() => setExpanded(!expanded)}
    >
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '16px' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          style={{ color: MATERIYA_COLOR, fontSize: 28, fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 24 }}
        >
          {t('autonomousUniverse.title')}
        </motion.h2>
        <p style={{ color: 'rgba(255, 255, 255, 0.7)', textAlign: 'center', fontSize: 12, marginBottom: 16 }}>
          {t('autonomousUniverse.description')}
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
                border: mode === m.key ? '1px solid #00ccff' : '1px solid rgba(255, 255, 255, 0.2)',
                background: mode === m.key ? 'rgba(0, 204, 255, 0.15)' : 'rgba(0, 0, 0, 0)',
                color: mode === m.key ? '#00ccff' : 'rgba(255, 255, 255, 0.7)',
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
            <span style={{ color: MATERIYA_COLOR, fontSize: 12, fontFamily: 'JetBrains Mono, monospace' }}>Loading...</span>
          </div>
        ) : data && (
          <motion.div
            key={mode}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.3 }}
            style={glass}
          >
            {mode === 'autonomous' && (
              <>
                {/* Autonomous Bubbles */}
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.bubblesTitle')}
                </h4>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12 }}>
                  {Array.from({ length: data.data.bubbles_count }, (_, i) => (
                    <motion.div
                      key={i}
                      initial={{ opacity: 0, scale: 0.8 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{ delay: i * 0.05, duration: 0.4 }}
                      style={{
                        background: 'rgba(0, 204, 255, 0.08)',
                        border: `2px solid ${MATERIYA_COLOR}`,
                        borderRadius: 10,
                        padding: 12,
                        position: 'relative',
                      }}
                    >
                      <div style={{
                        position: 'absolute',
                        top: '50%',
                        left: '50%',
                        transform: 'translate(-50%, -50%)',
                        color: '#00ccff',
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono, monospace',
                      }}>
                        {'🫧'}
                      </div>
                    </motion.div>
                  ))}
                </div>

                {/* Metrics Grid */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginTop: 20 }}>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.mutationRate')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {data.data.mutation_rate.toFixed(4)}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.crossoverCount')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {data.data.crossover_count}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.novelDiscoveries')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {data.data.novel_discoveries}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.convergenceScore')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {data.data.convergence_score.toFixed(3)}
                    </div>
                  </div>
                </div>

                <div style={{ marginTop: 20, color: '#00ccff', fontSize: 12, fontFamily: 'JetBrains Mono, monospace' }}>
                  <strong>{data.data.auto_tuned_params}</strong>
                </div>
              </>
            )}

            {mode === 'tune' && (
              <>
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.autoTune')}
                </h4>
                <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                  <div style={{ fontSize: 12, color: '#00ccff' }}>
                    {t('autonomousUniverse.muAdjusted')}
                  </div>
                  <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                    {(parseFloat(data.data.auto_tuned_params.match(/mu: ([\d.]+)/)?.[1] || 0) * 1000).toFixed(2)}
                  </div>
                </div>
              </>
            )}

            {mode === 'evolve' && (
              <>
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.evolution')}
                </h4>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12, marginTop: 16 }}>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.generation')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {data.data.auto_tuned_params.match(/generation: (\d+)/)?.[1] || 0}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.fitness')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {parseFloat(data.data.auto_tuned_params.match(/fitness: ([\d.]+)/)?.[1] || 0).toFixed(4)}
                    </div>
                  </div>
                </div>
              </>
            )}

            {mode === 'discover' && (
              <>
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.discovery')}
                </h4>
                <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                  <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#00ccff' }}>
                    {data.data.best_formula}
                  </div>
                </div>
              </>
            )}

            {mode === 'snapshot' && (
              <>
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.snapshot')}
                </h4>
                <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16, marginBottom: 20 }}>
                  <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                    {t('autonomousUniverse.snapshotTs')}
                  </div>
                  <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                    {new Date(parseInt(data.data.auto_tuned_params.match(/snapshot_ts: '(\d+)'/)?.[1] || '0')).toLocaleString()}
                  </div>
                </div>
                <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                  <div style={{ fontSize: 12, color: '#00ccff' }}>
                      {t('autonomousUniverse.phiAlignment')}
                    </div>
                  <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
                      {data.data.phi_alignment.toFixed(4)}
                    </div>
                </div>
              </>
            )}

            {mode === 'converge' && (
              <>
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.convergeStatus')}
                </h4>
                <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                  <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#00ccff' }}>
                    {data.data.auto_tuned_params}
                  </div>
                </div>
              </>
            )}

            {mode === 'reset' && (
              <>
                <h4 style={{ color: '#00ccff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                  {t('autonomousUniverse.reset')}
                </h4>
                <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                  <p style={{ fontSize: 14, color: 'rgba(255, 255, 255, 0.7)' }}>
                    {t('autonomousUniverse.resetConfirm')}
                  </p>
                </div>
              </>
            )}
          </motion.div>
        )}

        {/* Status Bar */}
        <div style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, color: data?.trinity_check === '✓' ? '#00cc00' : 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
            {t('autonomousUniverse.trinity')}
          </span>
          <span style={{ fontSize: 11, color: 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace', marginLeft: 16 }}>
            {data?.status || 'ready'}
          </span>
        </div>

      {/* Footer */}
      <div style={{ marginTop: 16, borderTop: '1px solid rgba(0, 204, 255, 0.1)', paddingTop: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 8, fontSize: 10, color: 'rgba(255, 255, 255, 0.5)' }}>
          <span>φ² + 1/φ² = 3</span>
          <span>•</span>
          <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>{data?.data.phi_alignment.toFixed(3)} φ</span>
          <span>•</span>
          <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>{(1.0 / data?.data.phi_alignment).toFixed(2)}</span>
        </div>
      </div>
      </div>
    </Section>
  );
}
