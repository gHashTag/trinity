"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchSacredEconomyWeb3, type SacredEconomyWeb3Mode, type SacredEconomyWeb3Response } from '../../services/chatApi';

const MODES = [
  { key: 'connect', label: 'Connect' },
  { key: 'oracle', label: 'Oracle' },
  { key: 'proposal', label: 'Proposal' },
  { key: 'stake', label: 'Stake' },
  { key: 'listing', label: 'Listing' },
  { key: 'metrics', label: 'Metrics' },
];

const DUKH_COLOR = '#aa66ff';

const glass = {
  background: 'rgba(170, 102, 255, 0.1)',
  border: '1px solid rgba(170, 102, 255, 0.2)',
  borderRadius: '12px',
  backdropFilter: 'blur(8px)',
};

export default function SacredEconomySection() {
  const { t } = useI18n();
  const [mode, setMode] = useState<keyof typeof MODES[number] | ''>('connect');
  const [data, setData] = useState<SacredEconomyWeb3Mode | null>(null);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const loadData = async (m: keyof typeof MODES[number]) => {
    setLoading(true);
    try {
      const result = await fetchSacredEconomyWeb3(m);
      setData(result.data);
    } catch {
      console.error('Failed to load sacred economy data:', m);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(mode); }, [mode]);

  return (
    <Section
      title="Sacred Economy Web3 v3.5"
      version="3.5"
      icon="&#x1F4B0;"
      expanded={expanded}
      onToggle={() => setExpanded(!expanded)}
    >
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '16px' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h3 style={{ color: DUKH_COLOR, fontSize: 'clamp(20px, 6vw, 28px)', fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 24 }}>
            {t('sacredEconomy.title')}
          </h3>
          <p style={{ color: 'rgba(255, 255, 255, 0.7)', textAlign: 'center', fontSize: 12, marginBottom: 16 }}>
            {t('sacredEconomy.description')}
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
                  border: mode === m.key ? '1px solid #aa66ff' : '1px solid rgba(255, 255, 255, 0.2)',
                  background: mode === m.key ? 'rgba(170, 102, 255, 0.15)' : 'rgba(0, 0, 0, 0)',
                  color: mode === m.key ? '#aa66ff' : 'rgba(255, 255, 255, 0.7)',
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
              <span style={{ color: DUKH_COLOR, fontSize: 12, fontFamily: 'JetBrains Mono, monospace' }}>Loading...</span>
            </div>
          ) : data && (
            <motion.div
              key={mode}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
              style={glass}
            >
              {mode === 'connect' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('sacredEconomy.wallet')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12}}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.address')}
                      </div>
                      <div style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4, wordBreak: 'break-all' }}>
                        {data.data.wallet_address}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.balance')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {data.data.tri_balance.toFixed(4)} $TRI
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'oracle' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('sacredEconomy.oracle')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16, marginBottom: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('sacredEconomy.phiPrice')}
                    </div>
                    <div style={{ fontSize: 24, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                      ${data.data.phi_price.toFixed(6)}
                    </div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 12}}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.gas')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {data.data.gas_price} gwei
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.block')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        #{data.data.block_number}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.timestamp')}
                      </div>
                      <div style={{ fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {new Date(data.data.timestamp).toLocaleString()}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'proposal' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('sacredEconomy.proposal')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16, marginBottom: 16 }}>
                    <div style={{ fontSize: 14, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff' }}>
                      {data.data.proposal_id}
                    </div>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)', marginTop: 8 }}>
                      {data.data.proposal_description}
                    </div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12}}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.votesFor')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#00cc00', marginTop: 4 }}>
                        {data.data.votes_for}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.votesAgainst')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#cc0000', marginTop: 4 }}>
                        {data.data.votes_against}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'stake' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('sacredEconomy.stake')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12}}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.staked')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {data.data.staked_amount.toFixed(4)} $TRI
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.apy')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {(data.data.apy * 100).toFixed(2)}%
                      </div>
                    </div>
                  </div>
                  <div style={{ marginTop: 16, background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('sacredEconomy.rewards')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                      {data.data.pending_rewards.toFixed(6)} $TRI
                    </div>
                  </div>
                </>
              )}

              {mode === 'listing' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('sacredEconomy.listing')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('sacredEconomy.listingId')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                      {data.data.listing_id}
                    </div>
                  </div>
                </>
              )}

              {mode === 'metrics' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('sacredEconomy.metrics')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 12}}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.tvl')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        ${(data.data.tvl / 1e6).toFixed(2)}M
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.volume24h')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        ${(data.data.volume_24h / 1e3).toFixed(1)}K
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('sacredEconomy.transactions')}
                      </div>
                      <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {data.data.transactions_24h}
                      </div>
                    </div>
                  </div>
                </>
              )}
            </motion.div>
          )}

          {/* Status Bar */}
          <div style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 11, color: data?.data.web3_connected ? '#00cc00' : 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {t('sacredEconomy.web3')}
            </span>
            <span style={{ fontSize: 11, color: 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {data?.status || 'ready'}
            </span>
          </div>
        </motion.h2>

        {/* Footer */}
        <div style={{ marginTop: 16, borderTop: '1px solid rgba(170, 102, 255, 0.1)', paddingTop: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, fontSize: 10, color: 'rgba(255, 255, 255, 0.5)' }}>
            <span>$TRI Token</span>
            <span>•</span>
            <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>{(data?.data.tri_balance || 0).toFixed(4)}</span>
            <span>•</span>
            <span>Web3 Bridge</span>
          </div>
        </div>
      </div>
    </Section>
  );
}
