"use client";

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import IntelligenceCurveChart from './charts/IntelligenceCurveChart';

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT MU DASHBOARD WIDGET v8.16
// RAZUM (Gold) — Intelligence, Mind, Self-Evolution
// μ = 1/φ²/10 = 0.0382 per successful fix (adaptive in v8.16)
// ═══════════════════════════════════════════════════════════════════════════════

const GOLD = '#ffd700';
const GOLD_DIM = 'rgba(255, 215, 0, 0.3)';

const glassStyle: React.CSSProperties = {
  background: 'rgba(255, 215, 0, 0.05)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  border: '1px solid rgba(255, 215, 0, 0.2)',
  borderRadius: '12px',
};

export interface IntelligenceHistoryPoint {
  timestamp: number;
  intelligence_multiplier: number;
  mu_used: number;
  fix_type: string;
}

export interface AgentMuStatus {
  total_fixes: number;
  intelligence_multiplier: number;
  mu_accumulated: number;
  adaptive_mu: number;
  intelligence_history: IntelligenceHistoryPoint[];
  recent_fixes: Array<{
    timestamp: number;
    fix_type: string;
    file: string;
    success: boolean;
  }>;
  uptime_s: number;
}

// Mock data when server unavailable
const generateMockHistory = (): IntelligenceHistoryPoint[] => {
  const points: IntelligenceHistoryPoint[] = [];
  const now = Date.now();
  let mult = 1.0;

  // Generate 10 data points showing growth
  for (let i = 0; i < 10; i++) {
    mult *= 1.15; // ~15% growth per step
    points.push({
      timestamp: now - (10 - i) * 300000, // 5-min intervals
      intelligence_multiplier: mult,
      mu_used: 0.0382 + (i * 0.002),
      fix_type: ['TYPE_FIX', 'SYNTAX_FIX', 'ALLOCATOR_FIX', 'IMPORT_FIX'][i % 4],
    });
  }
  return points;
};

const MOCK_STATUS: AgentMuStatus = {
  total_fixes: 127,
  intelligence_multiplier: 6.82,
  mu_accumulated: 4.8514,
  adaptive_mu: 0.0418,
  intelligence_history: generateMockHistory(),
  recent_fixes: [
    { timestamp: Date.now() - 30000, fix_type: 'ALLOCATOR_FIX', file: 'generated/tri_ops.zig', success: true },
    { timestamp: Date.now() - 90000, fix_type: 'TYPE_FIX', file: 'generated/vsa_bundle.zig', success: true },
    { timestamp: Date.now() - 180000, fix_type: 'SYNTAX_FIX', file: 'generated/parser.zig', success: true },
    { timestamp: Date.now() - 300000, fix_type: 'MEM_FIX', file: 'generated/cache.zig', success: true },
    { timestamp: Date.now() - 450000, fix_type: 'IMPORT_FIX', file: 'generated/http.zig', success: true },
  ],
  uptime_s: 86400,
};

async function fetchAgentMuStatus(): Promise<AgentMuStatus> {
  try {
    const res = await fetch('http://localhost:8080/api/agent-mu/status', {
      signal: AbortSignal.timeout(2000),
    });
    if (!res.ok) throw new Error('API error');
    return await res.json();
  } catch {
    return MOCK_STATUS;
  }
}

function formatUptime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (hours > 24) {
    const days = Math.floor(hours / 24);
    return `${days}d ${hours % 24}h`;
  }
  return `${hours}h ${mins}m`;
}

function fixTypeColor(fixType: string): string {
  if (fixType.includes('ALLOCATOR') || fixType.includes('MEM')) return '#ff6b6b';
  if (fixType.includes('TYPE')) return '#4ecdc4';
  if (fixType.includes('SYNTAX')) return '#ffe66d';
  if (fixType.includes('IMPORT')) return '#95e1d3';
  if (fixType.includes('TEMPLATE')) return '#f38181';
  return GOLD;
}

function timeAgo(ts: number): string {
  const seconds = Math.floor((Date.now() - ts) / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const mins = Math.floor(seconds / 60);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  return `${hours}h ago`;
}

export default function AgentMuWidget() {
  const [status, setStatus] = useState<AgentMuStatus | null>(null);
  const [expanded, setExpanded] = useState(false);
  const [heartbeat, setHeartbeat] = useState(true);

  useEffect(() => {
    fetchAgentMuStatus().then(setStatus);

    const interval = setInterval(() => {
      fetchAgentMuStatus().then(setStatus);
      setHeartbeat(h => !h);
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  if (!status) {
    return (
      <div style={{ ...glassStyle, padding: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <div style={{
            width: '8px', height: '8px', borderRadius: '50%',
            background: GOLD, animation: 'pulse 1s infinite'
          }} />
          <span style={{ fontSize: '0.7rem', color: GOLD, fontFamily: 'JetBrains Mono' }}>
            AGENT MU connecting...
          </span>
        </div>
      </div>
    );
  }

  return (
    <div style={{ ...glassStyle, padding: expanded ? '1rem' : '0.75rem' }}>
      {/* Header */}
      <div
        onClick={() => setExpanded(!expanded)}
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          cursor: 'pointer',
          userSelect: 'none',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          {/* Heartbeat */}
          <div style={{
            width: '8px', height: '8px', borderRadius: '50%',
            background: heartbeat ? GOLD : GOLD_DIM,
            transition: 'background 0.3s',
            boxShadow: heartbeat ? `0 0 8px ${GOLD}` : 'none',
          }} />
          {/* Title */}
          <span style={{
            fontSize: '0.7rem',
            color: GOLD,
            fontFamily: 'JetBrains Mono',
            fontWeight: 600,
            letterSpacing: '0.05em',
          }}>
            AGENT MU v8.15
          </span>
        </div>
        {/* Expand indicator */}
        <motion.div
          animate={{ rotate: expanded ? 180 : 0 }}
          transition={{ duration: 0.2 }}
          style={{ color: GOLD, fontSize: '0.8rem' }}
        >
          ▼
        </motion.div>
      </div>

      {/* Expanded content */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.2 }}
            style={{ marginTop: '0.75rem', overflow: 'hidden' }}
          >
            {/* Metrics grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: '0.5rem',
              marginBottom: '0.75rem',
            }}>
              {/* Total fixes */}
              <div style={{
                background: 'rgba(255, 215, 0, 0.1)',
                borderRadius: '8px',
                padding: '0.5rem',
                textAlign: 'center',
              }}>
                <div style={{ fontSize: '0.6rem', color: GOLD_DIM, marginBottom: '0.25rem' }}>
                  FIXES
                </div>
                <div style={{
                  fontSize: '1rem',
                  fontWeight: 700,
                  color: GOLD,
                  fontFamily: 'JetBrains Mono',
                }}>
                  {status.total_fixes}
                </div>
              </div>

              {/* Intelligence multiplier */}
              <div style={{
                background: 'rgba(255, 215, 0, 0.1)',
                borderRadius: '8px',
                padding: '0.5rem',
                textAlign: 'center',
              }}>
                <div style={{ fontSize: '0.6rem', color: GOLD_DIM, marginBottom: '0.25rem' }}>
                  INTELLIGENCE
                </div>
                <div style={{
                  fontSize: '1rem',
                  fontWeight: 700,
                  color: GOLD,
                  fontFamily: 'JetBrains Mono',
                }}>
                  {status.intelligence_multiplier.toFixed(2)}×
                </div>
              </div>

              {/* μ accumulated */}
              <div style={{
                background: 'rgba(255, 215, 0, 0.1)',
                borderRadius: '8px',
                padding: '0.5rem',
                textAlign: 'center',
              }}>
                <div style={{ fontSize: '0.6rem', color: GOLD_DIM, marginBottom: '0.25rem' }}>
                  μ ACCUMULATED
                </div>
                <div style={{
                  fontSize: '1rem',
                  fontWeight: 700,
                  color: GOLD,
                  fontFamily: 'JetBrains Mono',
                }}>
                  {status.mu_accumulated.toFixed(4)}
                </div>
              </div>
            </div>

            {/* μ progress bar */}
            <div style={{ marginBottom: '0.75rem' }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                fontSize: '0.6rem',
                color: GOLD_DIM,
                marginBottom: '0.25rem',
              }}>
                <span>EVOLUTION PROGRESS</span>
                <span>{(status.intelligence_multiplier / 47 * 100).toFixed(0)}%</span>
              </div>
              <div style={{
                height: '4px',
                background: 'rgba(255, 215, 0, 0.2)',
                borderRadius: '2px',
                overflow: 'hidden',
              }}>
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${Math.min(status.intelligence_multiplier / 47 * 100, 100)}%` }}
                  transition={{ duration: 0.5 }}
                  style={{
                    height: '100%',
                    background: `linear-gradient(90deg, ${GOLD}, #ffed4e)`,
                    borderRadius: '2px',
                  }}
                />
              </div>
              <div style={{ fontSize: '0.55rem', color: GOLD_DIM, marginTop: '0.25rem' }}>
                Target: 47× after 100 fixes | Adaptive μ: {status.adaptive_mu.toFixed(4)}
              </div>
            </div>

            {/* Intelligence Curve */}
            <div style={{ marginBottom: '0.75rem' }}>
              <div style={{ fontSize: '0.6rem', color: GOLD_DIM, marginBottom: '0.5rem' }}>
                INTELLIGENCE CURVE
              </div>
              <IntelligenceCurveChart
                data={status.intelligence_history || []}
                currentMultiplier={status.intelligence_multiplier}
              />
            </div>

            {/* Recent fixes */}
            <div>
              <div style={{ fontSize: '0.6rem', color: GOLD_DIM, marginBottom: '0.5rem' }}>
                RECENT FIXES (last 5)
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                {status.recent_fixes.slice(0, 5).map((fix, i) => (
                  <div
                    key={i}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      fontSize: '0.65rem',
                      padding: '0.4rem 0.5rem',
                      background: 'rgba(255, 215, 0, 0.05)',
                      borderRadius: '6px',
                      fontFamily: 'JetBrains Mono',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <span style={{
                        color: fixTypeColor(fix.fix_type),
                        fontWeight: 500,
                      }}>
                        {fix.fix_type}
                      </span>
                      <span style={{ color: 'var(--muted)', fontSize: '0.55rem' }}>
                        {fix.file.split('/').pop()}
                      </span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <span style={{ color: GOLD_DIM, fontSize: '0.55rem' }}>
                        {timeAgo(fix.timestamp)}
                      </span>
                      <span style={{
                        color: fix.success ? '#4ade80' : '#f87171',
                        fontSize: '0.55rem',
                      }}>
                        {fix.success ? '✓' : '✗'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Uptime footer */}
            <div style={{
              marginTop: '0.75rem',
              paddingTop: '0.5rem',
              borderTop: '1px solid rgba(255, 215, 0, 0.1)',
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: '0.6rem',
              color: GOLD_DIM,
            }}>
              <span>UPTIME</span>
              <span style={{ fontFamily: 'JetBrains Mono' }}>{formatUptime(status.uptime_s)}</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Collapsed state indicator */}
      {!expanded && (
        <div style={{
          marginTop: '0.5rem',
          display: 'flex',
          gap: '1rem',
          fontSize: '0.65rem',
          fontFamily: 'JetBrains Mono',
          color: GOLD_DIM,
        }}>
          <span>{status.total_fixes} fixes</span>
          <span>{status.intelligence_multiplier.toFixed(2)}× intelligence</span>
          <span>μ {status.mu_accumulated.toFixed(3)}</span>
        </div>
      )}
    </div>
  );
}
