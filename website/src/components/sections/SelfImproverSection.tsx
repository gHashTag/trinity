"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchSelfImproverAdam, type SelfImproverAdamMode, type SelfImproverAdamResponse } from '../../services/chatApi';

const MODES = [
  { key: 'adam', label: 'Adam' },
  { key: 'ewc', label: 'EWC' },
  { key: 'gradient', label: 'Gradient' },
  { key: 'momentum', label: 'Momentum' },
  { key: 'trajectory', label: 'Trajectory' },
  { key: 'clip', label: 'Clip' },
  { key: 'consolidate', label: 'Consolidate' },
];

const RAZUM_COLOR = '#ffd700';

const glass = {
  background: 'rgba(255, 215, 0, 0.1)',
  border: '1px solid rgba(255, 215, 0, 0.2)',
  borderRadius: '12px',
  backdropFilter: 'blur(8px)',
};

export default function SelfImproverSection() {
  const { t } = useI18n();
  const [mode, setMode] = useState<keyof typeof MODES[number] | ''>('adam');
  const [data, setData] = useState<SelfImproverAdamMode | null>(null);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const loadData = async (m: keyof typeof MODES[number]) => {
    setLoading(true);
    try {
      const result = await fetchSelfImproverAdam(m);
      setData(result.data);
    } catch {
      console.error('Failed to load self improver data:', m);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(mode); }, [mode]);

  return (
    <Section
      title="Self Improver Adam v3.5"
      version="3.5"
      icon="&#x1F3AF;"
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
            {t('selfImprover.title')}
          </h3>
          <p style={{ color: 'rgba(255, 255, 255, 0.7)', textAlign: 'center', fontSize: 12, marginBottom: 16 }}>
            {t('selfImprover.description')}
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
              {mode === 'adam' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.adamOptimizer')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.learningRate')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.learning_rate.toExponential(2)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.iteration')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.iteration}
                      </div>
                    </div>
                  </div>
                  <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        β₁
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.beta1.toFixed(4)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        β₂
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.beta2.toFixed(4)}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'ewc' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.ewcConsolidation')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.fisherInfo')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.fisher_information.toExponential(2)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.lambda')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.lambda.toExponential(2)}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'gradient' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.gradient')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.gradientNorm')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.gradient_norm.toFixed(6)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.loss')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.loss.toExponential(4)}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'momentum' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.momentum')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.velocity')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        [{data.data.velocity.map(v => v.toFixed(4)).join(', ')}]
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.decay')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.decay_rate.toFixed(4)}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'trajectory' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.trajectory')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('selfImprover.trajectoryId')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {data.data.trajectory_id}
                    </div>
                  </div>
                  <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.steps')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.steps}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.successRate')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {(data.data.success_rate * 100).toFixed(1)}%
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'clip' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.gradientClip')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.clipThreshold')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        {data.data.clip_threshold.toFixed(4)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('selfImprover.clipped')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: data.data.clipped ? '#ff6600' : '#00cc00', marginTop: 4 }}>
                        {data.data.clipped ? 'YES' : 'NO'}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'consolidate' && (
                <>
                  <h4 style={{ color: '#ffd700', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('selfImprover.consolidate')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16, marginBottom: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('selfImprover.ewcLoss')}
                    </div>
                    <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {data.data.ewc_loss.toExponential(4)}
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('selfImprover.parameters')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                      {data.data.consolidated_params}
                    </div>
                  </div>
                </>
              )}
            </motion.div>
          )}

          {/* Status Bar */}
          <div style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 11, color: data?.data.converged ? '#00cc00' : 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {data?.data.converged ? 'CONVERGED' : 'TRAINING'}
            </span>
            <span style={{ fontSize: 11, color: 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {t('selfImprover.optimizer')}: Adam
            </span>
          </div>
        </motion.h2>

        {/* Footer */}
        <div style={{ marginTop: 16, borderTop: '1px solid rgba(255, 215, 0, 0.1)', paddingTop: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, fontSize: 10, color: 'rgba(255, 255, 255, 0.5)' }}>
            <span>β₁=0.9</span>
            <span>β₂=0.999</span>
            <span>•</span>
            <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>ε=1e-8</span>
            <span>•</span>
            <span>{t('selfImprover.adam')}</span>
          </div>
        </div>
      </div>
    </Section>
  );
}
