"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchNFTMarketplace, type NFTMarketplaceMode, type NFTMarketplaceResponse } from '../../services/chatApi';

const MODES = [
  { key: 'browse', label: 'Browse' },
  { key: 'bid', label: 'Bid' },
  { key: 'create', label: 'Create' },
  { key: 'accept', label: 'Accept' },
  { key: 'cancel', label: 'Cancel' },
  { key: 'trade', label: 'Trade' },
];

const DUKH_COLOR = '#aa66ff';

const glass = {
  background: 'rgba(170, 102, 255, 0.1)',
  border: '1px solid rgba(170, 102, 255, 0.2)',
  borderRadius: '12px',
  backdropFilter: 'blur(8px)',
};

export default function NFTMarketplaceSection() {
  const { t } = useI18n();
  const [mode, setMode] = useState<keyof typeof MODES[number] | ''>('browse');
  const [data, setData] = useState<NFTMarketplaceMode | null>(null);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const loadData = async (m: keyof typeof MODES[number]) => {
    setLoading(true);
    try {
      const result = await fetchNFTMarketplace(m);
      setData(result.data);
    } catch {
      console.error('Failed to load NFT marketplace data:', m);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(mode); }, [mode]);

  return (
    <Section
      title="NFT Marketplace v3.5"
      version="3.5"
      icon="&#x1F5BC;"
      expanded={expanded}
      onToggle={() => setExpanded(!expanded)}
    >
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '16px' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h3 style={{ color: DUKH_COLOR, fontSize: 28, fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 24 }}>
            {t('nftMarketplace.title')}
          </h3>
          <p style={{ color: 'rgba(255, 255, 255, 0.7)', textAlign: 'center', fontSize: 12, marginBottom: 16 }}>
            {t('nftMarketplace.description')}
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
              {mode === 'browse' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('nftMarketplace.listings')}
                  </h4>
                  <div style={{ display: 'grid', gap: 12 }}>
                    {data.data.listings.slice(0, 4).map((listing, i) => (
                      <motion.div
                        key={i}
                        initial={{ opacity: 0, x: -10 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: i * 0.1, duration: 0.3 }}
                        style={{
                          background: glass.background,
                          border: glass.border,
                          borderRadius: glass.borderRadius,
                          padding: 12,
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <div>
                          <div style={{ fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff' }}>
                            {listing.token_id}
                          </div>
                          <div style={{ fontSize: 10, color: 'rgba(255, 255, 255, 0.7)', marginTop: 4 }}>
                            {listing.creator}
                          </div>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <div style={{ fontSize: 14, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700' }}>
                            ${listing.ask_price.toFixed(2)}
                          </div>
                          <div style={{ fontSize: 10, color: 'rgba(255, 255, 255, 0.7)' }}>
                            {listing.royalty}% royalty
                          </div>
                        </div>
                      </motion.div>
                    ))}
                  </div>
                </>
              )}

              {mode === 'bid' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('nftMarketplace.placeBid')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.bidAmount')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        ${data.data.current_bid.toFixed(2)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.minIncrement')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        ${data.data.min_increment.toFixed(2)}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'create' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('nftMarketplace.createListing')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.listingFee')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {(data.data.marketplace_fee * 100).toFixed(1)}%
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.royaltyRate')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {(data.data.royalty_rate * 100).toFixed(1)}%
                      </div>
                    </div>
                  </div>
                  <div style={{ marginTop: 16, background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('nftMarketplace.listingId')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                      {data.data.listing_id}
                    </div>
                  </div>
                </>
              )}

              {mode === 'accept' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('nftMarketplace.acceptOffer')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.offerAmount')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        ${data.data.offer_amount.toFixed(2)}
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.buyer')}
                      </div>
                      <div style={{ fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {data.data.buyer}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {mode === 'cancel' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('nftMarketplace.cancelListing')}
                  </h4>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                      {t('nftMarketplace.listingId')}
                    </div>
                    <div style={{ fontSize: 16, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                      {data.data.listing_id}
                    </div>
                  </div>
                </>
              )}

              {mode === 'trade' && (
                <>
                  <h4 style={{ color: '#aa66ff', fontSize: 14, marginBottom: 16, marginTop: 24 }}>
                    {t('nftMarketplace.tradeHistory')}
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12, marginBottom: 16 }}>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.totalVolume')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700', marginTop: 4 }}>
                        ${(data.data.total_volume / 1e6).toFixed(2)}M
                      </div>
                    </div>
                    <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 12 }}>
                      <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)' }}>
                        {t('nftMarketplace.totalTrades')}
                      </div>
                      <div style={{ fontSize: 20, fontFamily: 'JetBrains Mono, monospace', color: '#aa66ff', marginTop: 4 }}>
                        {data.data.total_trades}
                      </div>
                    </div>
                  </div>
                  <div style={{ background: glass.background, border: glass.border, borderRadius: glass.borderRadius, padding: 16 }}>
                    <div style={{ fontSize: 12, color: 'rgba(255, 255, 255, 0.7)', marginBottom: 8 }}>
                      {t('nftMarketplace.recentTrades')}
                    </div>
                    {data.data.recent_trades.slice(0, 3).map((trade, i) => (
                      <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid rgba(170, 102, 255, 0.1)' }}>
                        <span style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace' }}>{trade.token_id}</span>
                        <span style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', color: '#ffd700' }}>${trade.price.toFixed(2)}</span>
                      </div>
                    ))}
                  </div>
                </>
              )}
            </motion.div>
          )}

          {/* Status Bar */}
          <div style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 11, color: data?.data.marketplace_active ? '#00cc00' : 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {data?.data.marketplace_active ? 'LIVE' : 'OFFLINE'}
            </span>
            <span style={{ fontSize: 11, color: 'rgba(255, 255, 255, 0.5)', fontFamily: 'JetBrains Mono, monospace' }}>
              {data?.data.listings.length || 0} {t('nftMarketplace.listings')}
            </span>
          </div>
        </motion.h2>

        {/* Footer */}
        <div style={{ marginTop: 16, borderTop: '1px solid rgba(170, 102, 255, 0.1)', paddingTop: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, fontSize: 10, color: 'rgba(255, 255, 255, 0.5)' }}>
            <span>$TRI</span>
            <span>•</span>
            <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>{data?.data.avg_price.toFixed(2) || '0.00'}</span>
            <span>•</span>
            <span>{(data?.data.marketplace_fee || 0.025) * 100}% fee</span>
          </div>
        </div>
      </div>
    </Section>
  );
}
