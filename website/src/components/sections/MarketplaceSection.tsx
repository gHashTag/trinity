"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchMarketplace, type MarketplaceResponse, type MarketplaceMode } from '../../services/chatApi';

const glass = {
  background: 'rgba(0,0,0,0.5)',
  border: '1px solid rgba(170,102,255,0.2)',
  borderRadius: '12px',
  padding: '16px',
  backdropFilter: 'blur(8px)',
};

const TABS: { key: MarketplaceMode; label: string }[] = [
  { key: 'dashboard', label: 'Dashboard' },
  { key: 'staking', label: 'Staking' },
  { key: 'proof', label: 'Proof System' },
  { key: 'tokenomics', label: 'Tokenomics' },
];

function formatTRI(n: number): string {
  return n.toLocaleString('en-US', { maximumFractionDigits: 0 });
}

export default function MarketplaceSection() {
  const { t } = useI18n();
  const msg = (t as any).marketplace || {};

  const [tab, setTab] = useState<MarketplaceMode>('dashboard');
  const [data, setData] = useState<MarketplaceResponse | null>(null);
  const [loading, setLoading] = useState(false);

  const loadData = async (m: MarketplaceMode) => {
    setLoading(true);
    try {
      const result = await fetchMarketplace(m);
      setData(result);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(tab); }, [tab]);

  return (
    <Section id="marketplace">
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '40px 20px' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          style={{ color: '#aa66ff', fontSize: 28, fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 8 }}
        >
          {msg.title || '$TRI Sacred Computation Marketplace'}
        </motion.h2>
        <p style={{ color: 'rgba(170,102,255,0.5)', textAlign: 'center', fontSize: 13, marginBottom: 24, fontFamily: 'JetBrains Mono, monospace' }}>
          {msg.subtitle || 'Generated from: specs/tri/tri_marketplace.vibee'}
        </p>

        {/* Tab switcher */}
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 24, flexWrap: 'wrap' }}>
          {TABS.map(t => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              style={{
                padding: '6px 16px', borderRadius: 8, fontSize: 12, cursor: 'pointer',
                fontFamily: 'JetBrains Mono, monospace', transition: 'all 0.2s',
                border: tab === t.key ? '1px solid #aa66ff' : '1px solid rgba(170,102,255,0.2)',
                background: tab === t.key ? 'rgba(170,102,255,0.15)' : 'rgba(0,0,0,0.3)',
                color: tab === t.key ? '#aa66ff' : 'rgba(255,255,255,0.5)',
              }}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <motion.div key={tab} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.3 }} style={glass}>
          {loading && <p style={{ color: 'rgba(170,102,255,0.5)', textAlign: 'center' }}>Loading...</p>}

          {/* Dashboard */}
          {tab === 'dashboard' && data?.dashboard && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                <span style={{ color: '#fff', fontSize: 13 }}>{msg.network || 'Network'}:</span>
                <span style={{ color: '#00e599', fontSize: 13, fontFamily: 'JetBrains Mono, monospace' }}>
                  ● {data.dashboard.network_active ? 'ACTIVE' : 'OFFLINE'}
                </span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: 10, marginBottom: 20 }}>
                {[
                  { label: msg.totalSupply || 'Total Supply', value: `${formatTRI(data.dashboard.total_supply)} $TRI`, color: '#ffd700' },
                  { label: msg.circulating || 'Circulating', value: `${formatTRI(data.dashboard.circulating)} $TRI`, color: '#00e599' },
                  { label: msg.staked || 'Staked', value: `${formatTRI(data.dashboard.staked)} $TRI`, color: '#00ccff' },
                  { label: msg.constants || 'Constants', value: String(data.dashboard.total_constants), color: '#aa66ff' },
                  { label: msg.formulaFits || 'Formula Fits', value: `${data.dashboard.formula_fits} (${data.dashboard.exact_fits} exact)`, color: '#ffd700' },
                  { label: msg.verified || 'Verified', value: `${data.dashboard.verify_passing}/${data.dashboard.verify_total}`, color: '#00e599' },
                ].map((item, i) => (
                  <div key={i} style={{ background: 'rgba(255,255,255,0.03)', borderRadius: 8, padding: '10px 12px', border: `1px solid ${item.color}20` }}>
                    <div style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontFamily: 'JetBrains Mono, monospace', marginBottom: 4 }}>{item.label}</div>
                    <div style={{ color: item.color, fontSize: 13, fontFamily: 'JetBrains Mono, monospace' }}>{item.value}</div>
                  </div>
                ))}
              </div>
              {data.top_computations && (
                <div>
                  <h3 style={{ color: '#ffd700', fontSize: 13, marginBottom: 8 }}>{msg.topComputations || 'Top Sacred Computations'}</h3>
                  {data.top_computations.map(c => (
                    <div key={c.rank} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', borderBottom: '1px solid rgba(170,102,255,0.08)', fontSize: 11, fontFamily: 'JetBrains Mono, monospace' }}>
                      <span style={{ color: 'rgba(255,255,255,0.6)' }}>#{c.rank} {c.formula}</span>
                      <span style={{ color: '#00e599' }}>{c.accuracy_pct}%</span>
                      <span style={{ color: '#ffd700' }}>φ^{c.reward_phi_power} = {c.reward_value.toFixed(2)} $TRI</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Staking */}
          {tab === 'staking' && data?.staking_tiers && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 12 }}>
                {msg.stakingTitle || 'Staking Tiers (Fibonacci × phi)'}
              </h3>
              {data.staking_tiers.map(tier => (
                <div key={tier.tier} style={{ marginBottom: 10 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, fontFamily: 'JetBrains Mono, monospace', marginBottom: 2 }}>
                    <span style={{ color: '#ffd700' }}>Tier {tier.tier}</span>
                    <span style={{ color: 'rgba(255,255,255,0.6)' }}>{tier.stake_amount} $TRI</span>
                    <span style={{ color: '#00ccff' }}>φ^{tier.tier} = {tier.multiplier.toFixed(3)}x</span>
                    <span style={{ color: '#00e599' }}>{tier.annual_yield_pct.toFixed(1)}%/yr</span>
                    <span style={{ color: 'rgba(255,255,255,0.4)' }}>{tier.lock_days}d</span>
                  </div>
                  <div style={{ width: '100%', height: 6, background: 'rgba(255,255,255,0.05)', borderRadius: 3 }}>
                    <div style={{
                      width: `${Math.min(tier.multiplier * 3, 100)}%`,
                      height: '100%',
                      background: 'linear-gradient(90deg, #aa66ff, #ffd700)',
                      borderRadius: 3,
                    }} />
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Proof System */}
          {tab === 'proof' && data?.accuracy_tiers && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 12 }}>
                {msg.proofTitle || 'Proof-of-Sacred-Computation'}
              </h3>
              <table style={{ width: '100%', fontSize: 11, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '4px 8px' }}>Tier</th>
                    <th style={{ textAlign: 'right', padding: '4px 8px' }}>Max Error</th>
                    <th style={{ textAlign: 'right', padding: '4px 8px' }}>Multiplier</th>
                    <th style={{ textAlign: 'right', padding: '4px 8px' }}>Label</th>
                  </tr>
                </thead>
                <tbody>
                  {data.accuracy_tiers.map(tier => {
                    const clr = tier.name === 'EXACT' ? '#ffd700' : tier.name === 'CLOSE' ? '#00e599' : tier.name === 'NEAR' ? '#00ccff' : tier.name === 'APPROXIMATE' ? '#888' : '#ff6b6b';
                    return (
                      <tr key={tier.name} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(170,102,255,0.1)' }}>
                        <td style={{ padding: '3px 8px', color: clr, fontWeight: 'bold' }}>{tier.name}</td>
                        <td style={{ padding: '3px 8px', textAlign: 'right' }}>&lt; {tier.max_error_pct}%</td>
                        <td style={{ padding: '3px 8px', textAlign: 'right', color: clr }}>{tier.reward_multiplier.toFixed(3)}x</td>
                        <td style={{ padding: '3px 8px', textAlign: 'right' }}>{tier.label}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
              {data.difficulty_base && (
                <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 10, marginTop: 12, fontFamily: 'JetBrains Mono, monospace' }}>
                  Difficulty base: {data.difficulty_base} = 3³ | Each tier: difficulty × 27 | EXACT: 27⁴ = 531,441
                </p>
              )}
            </div>
          )}

          {/* Tokenomics */}
          {tab === 'tokenomics' && data?.tokenomics && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 12 }}>
                {msg.tokenomicsTitle || '$TRI Tokenomics (phi-deflation model)'}
              </h3>
              <table style={{ width: '100%', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '3px 6px' }}>Epoch</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Supply</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Inflation</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Staked %</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Burned</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Net</th>
                  </tr>
                </thead>
                <tbody>
                  {data.tokenomics.map(e => (
                    <tr key={e.epoch} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(170,102,255,0.1)' }}>
                      <td style={{ padding: '2px 6px' }}>{e.epoch}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{formatTRI(e.supply)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{e.inflation.toFixed(1)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{e.staked_pct.toFixed(1)}%</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: '#ff6b6b' }}>{e.burned.toFixed(1)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: e.net_change > 0 ? '#00e599' : '#ff6b6b' }}>
                        {e.net_change > 0 ? '+' : ''}{e.net_change.toFixed(1)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Trinity Check */}
          {data && (
            <p style={{ color: '#aa66ff', textAlign: 'center', fontSize: 11, marginTop: 16, fontFamily: 'JetBrains Mono, monospace', opacity: 0.6 }}>
              φ² + 1/φ² = {data.trinity_check.toFixed(6)} = TRINITY
            </p>
          )}
        </motion.div>
      </div>
    </Section>
  );
}
