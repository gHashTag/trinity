/**
 * TRI Production Dashboard v2.0
 *
 * Sacred Intelligence Dashboard with:
 * - Trinity Sacred Mathematics (live calculations)
 * - DePIN Network status
 * - GitHub repository stats
 * - System health with Trinity branding
 */

import { useState, useEffect, useMemo } from 'react';
import { motion } from 'framer-motion';

// === Sacred Constants ===
const PHI = (1 + Math.sqrt(5)) / 2;
const MU = Math.pow(PHI, -4);
const CHI = 1 / PHI - MU;
const SIGMA = PHI;
const EPSILON = 1 / 3;

// Trinity colors
const GOLD = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';
const GREEN = '#00ff88';

function fibonacci(n: number): number {
  let a = 0, b = 1;
  for (let i = 0; i < n; i++) [a, b] = [b, a + b];
  return a;
}

function lucas(n: number): number {
  if (n === 0) return 2;
  if (n === 1) return 1;
  let a = 2, b = 1;
  for (let i = 2; i <= n; i++) [a, b] = [b, a + b];
  return b;
}

// === Components ===

function SacredMathSection() {
  const [n, setN] = useState(10);

  const data = useMemo(() => ({
    phi: PHI,
    phi2: PHI * PHI,
    inv_phi2: 1 / (PHI * PHI),
    trinity: PHI * PHI + 1 / (PHI * PHI),
    fib: Array.from({ length: n }, (_, i) => fibonacci(i)),
    lucas: Array.from({ length: n }, (_, i) => lucas(i)),
    info_density: Math.log2(3),
  }), [n]);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      style={{
        background: 'rgba(0,0,0,0.4)',
        border: `1px solid ${GOLD}33`,
        borderRadius: 12,
        padding: 24,
        marginBottom: 24,
      }}
    >
      <h2 style={{ color: GOLD, fontSize: 18, fontWeight: 700, marginBottom: 16, letterSpacing: 2 }}>
        SACRED MATHEMATICS
      </h2>

      {/* Trinity Identity */}
      <div style={{
        background: `linear-gradient(135deg, ${GOLD}11, ${GREEN}11)`,
        border: `1px solid ${GREEN}44`,
        borderRadius: 8,
        padding: 20,
        textAlign: 'center',
        marginBottom: 20,
      }}>
        <div style={{ color: GREEN, fontFamily: '"Times New Roman", serif', fontStyle: 'italic', fontSize: 'clamp(20px, 6vw, 28px)', marginBottom: 8 }}>
          &phi;&sup2; + 1/&phi;&sup2; = 3
        </div>
        <div style={{ color: '#888', fontSize: 12 }}>THE TRINITY IDENTITY</div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 32, marginTop: 16 }}>
          <div>
            <div style={{ color: '#666', fontSize: 10 }}>&phi;&sup2;</div>
            <div style={{ color: GOLD, fontSize: 20, fontFamily: 'JetBrains Mono, monospace' }}>{data.phi2.toFixed(6)}</div>
          </div>
          <div>
            <div style={{ color: '#666', fontSize: 10 }}>1/&phi;&sup2;</div>
            <div style={{ color: CYAN, fontSize: 20, fontFamily: 'JetBrains Mono, monospace' }}>{data.inv_phi2.toFixed(6)}</div>
          </div>
          <div>
            <div style={{ color: '#666', fontSize: 10 }}>SUM</div>
            <div style={{ color: GREEN, fontSize: 20, fontFamily: 'JetBrains Mono, monospace', fontWeight: 700 }}>{data.trinity.toFixed(10)}</div>
          </div>
        </div>
      </div>

      {/* Constants Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12, marginBottom: 20 }}>
        {[
          { label: '\u03C6 (phi)', value: PHI.toFixed(10), color: GOLD },
          { label: '\u03BC = \u03C6\u207B\u2074', value: MU.toFixed(6), color: CYAN },
          { label: '\u03C7', value: CHI.toFixed(6), color: PURPLE },
          { label: '\u03C3 = \u03C6', value: SIGMA.toFixed(6), color: GOLD },
          { label: '\u03B5 = 1/3', value: EPSILON.toFixed(6), color: GREEN },
          { label: 'log\u2082(3)', value: data.info_density.toFixed(6), color: CYAN },
        ].map((c) => (
          <div key={c.label} style={{
            background: 'rgba(255,255,255,0.03)',
            border: `1px solid ${c.color}22`,
            borderRadius: 8,
            padding: 12,
          }}>
            <div style={{ color: '#666', fontSize: 10, marginBottom: 4 }}>{c.label}</div>
            <div style={{ color: c.color, fontSize: 14, fontFamily: 'JetBrains Mono, monospace', fontWeight: 600 }}>{c.value}</div>
          </div>
        ))}
      </div>

      {/* Fibonacci & Lucas */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <div>
          <div style={{ color: GOLD, fontSize: 12, fontWeight: 600, marginBottom: 8 }}>FIBONACCI</div>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#aaa', lineHeight: 1.8 }}>
            {data.fib.map((v, i) => (
              <span key={i} style={{ color: i === n - 1 ? GOLD : '#888' }}>
                {v}{i < n - 1 ? ', ' : ''}
              </span>
            ))}
          </div>
        </div>
        <div>
          <div style={{ color: CYAN, fontSize: 12, fontWeight: 600, marginBottom: 8 }}>LUCAS</div>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#aaa', lineHeight: 1.8 }}>
            {data.lucas.map((v, i) => (
              <span key={i} style={{ color: v === 3 ? GREEN : i === n - 1 ? CYAN : '#888' }}>
                {v}{i < n - 1 ? ', ' : ''}
              </span>
            ))}
          </div>
          <div style={{ color: '#555', fontSize: 10, marginTop: 4 }}>L(2) = 3 = TRINITY</div>
        </div>
      </div>

      {/* Slider */}
      <div style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
        <span style={{ color: '#666', fontSize: 11 }}>Terms:</span>
        <input
          type="range" min={5} max={20} value={n}
          onChange={e => setN(+e.target.value)}
          style={{ flex: 1, accentColor: GOLD }}
        />
        <span style={{ color: GOLD, fontFamily: 'JetBrains Mono, monospace', fontSize: 12 }}>{n}</span>
      </div>
    </motion.div>
  );
}

function DePINSection() {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setTick(v => v + 1), 3000);
    return () => clearInterval(t);
  }, []);

  const nodes = 12 + (tick % 3);
  const tps = (42 + Math.sin(tick) * 5).toFixed(1);

  const tiers = [
    { name: 'Free', staked: '0', limit: '10 req/min', mult: '1.0x', color: '#666' },
    { name: 'Staker', staked: '100+', limit: '60 req/min', mult: '1.5x', color: CYAN },
    { name: 'Power', staked: '1,000+', limit: '300 req/min', mult: '2.0x', color: GOLD },
    { name: 'Whale', staked: '10,000+', limit: 'Unlimited', mult: '3.0x', color: PURPLE },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.1 }}
      style={{
        background: 'rgba(0,0,0,0.4)',
        border: `1px solid ${PURPLE}33`,
        borderRadius: 12,
        padding: 24,
        marginBottom: 24,
      }}
    >
      <h2 style={{ color: PURPLE, fontSize: 18, fontWeight: 700, marginBottom: 16, letterSpacing: 2 }}>
        DePIN NETWORK
      </h2>

      {/* Token Info */}
      <div style={{
        background: `linear-gradient(135deg, ${PURPLE}11, ${GOLD}11)`,
        border: `1px solid ${PURPLE}33`,
        borderRadius: 8,
        padding: 16,
        marginBottom: 20,
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <div>
            <span style={{ color: GOLD, fontSize: 22, fontWeight: 700 }}>$TRI</span>
            <span style={{ color: '#666', fontSize: 12, marginLeft: 8 }}>Trinity Token</span>
          </div>
          <div style={{ color: '#666', fontSize: 11 }}>Ethereum Sepolia</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))', gap: 12 }}>
          <div>
            <div style={{ color: '#555', fontSize: 10 }}>Total Supply</div>
            <div style={{ color: GOLD, fontSize: 14, fontFamily: 'JetBrains Mono, monospace' }}>3&sup2;&sup1;</div>
            <div style={{ color: '#444', fontSize: 10 }}>10,460,353,203</div>
          </div>
          <div>
            <div style={{ color: '#555', fontSize: 10 }}>Active Nodes</div>
            <div style={{ color: GREEN, fontSize: 14, fontFamily: 'JetBrains Mono, monospace' }}>{nodes}</div>
          </div>
          <div>
            <div style={{ color: '#555', fontSize: 10 }}>TPS</div>
            <div style={{ color: CYAN, fontSize: 14, fontFamily: 'JetBrains Mono, monospace' }}>{tps}</div>
          </div>
        </div>
      </div>

      {/* Allocation */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ color: '#888', fontSize: 11, marginBottom: 8, fontWeight: 600 }}>TOKEN ALLOCATION</div>
        {[
          { label: 'Node Rewards', pct: 40, color: GREEN },
          { label: 'Founder', pct: 20, color: GOLD },
          { label: 'Community', pct: 20, color: CYAN },
          { label: 'Treasury', pct: 10, color: PURPLE },
          { label: 'Liquidity', pct: 10, color: '#ff6b6b' },
        ].map(a => (
          <div key={a.label} style={{ marginBottom: 6 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, marginBottom: 2 }}>
              <span style={{ color: '#aaa' }}>{a.label}</span>
              <span style={{ color: a.color, fontFamily: 'JetBrains Mono, monospace' }}>{a.pct}%</span>
            </div>
            <div style={{ height: 4, background: '#1a1a2e', borderRadius: 2, overflow: 'hidden' }}>
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${a.pct}%` }}
                transition={{ duration: 1, delay: 0.2 }}
                style={{ height: '100%', background: a.color, borderRadius: 2 }}
              />
            </div>
          </div>
        ))}
      </div>

      {/* Staking Tiers */}
      <div>
        <div style={{ color: '#888', fontSize: 11, marginBottom: 8, fontWeight: 600 }}>STAKING TIERS</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(70px, 1fr))', gap: 8 }}>
          {tiers.map(t => (
            <div key={t.name} style={{
              background: 'rgba(255,255,255,0.02)',
              border: `1px solid ${t.color}33`,
              borderRadius: 8,
              padding: 10,
              textAlign: 'center',
            }}>
              <div style={{ color: t.color, fontSize: 13, fontWeight: 700 }}>{t.name}</div>
              <div style={{ color: '#666', fontSize: 9, marginTop: 4 }}>{t.staked} $TRI</div>
              <div style={{ color: '#888', fontSize: 10, marginTop: 4 }}>{t.limit}</div>
              <div style={{ color: t.color, fontSize: 16, fontWeight: 700, marginTop: 4 }}>{t.mult}</div>
            </div>
          ))}
        </div>
      </div>
    </motion.div>
  );
}

function GitHubSection() {
  const repoData = {
    stars: 47,
    forks: 8,
    issues: 12,
    commits: 120,
    language: 'Zig',
    license: 'MIT',
    lastCommit: 'feat(forge): Fix routing PIPs for prjxray segbits',
    branch: 'main',
    cycles: 110,
  };

  const recentCommits = [
    { hash: '1f89423', msg: 'Fix routing PIPs for prjxray segbits', tag: '812/813 features' },
    { hash: 'f139d87', msg: 'FORGE OF KOSCHEI v2.0 — 100% Native Zig', tag: 'milestone' },
    { hash: 'b84ea4d', msg: 'Add multi-method flash pipeline', tag: 'Arty A7' },
    { hash: '0dd03ba', msg: 'FORGE OF KOSCHEI v1.0', tag: 'FPGA toolchain' },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.2 }}
      style={{
        background: 'rgba(0,0,0,0.4)',
        border: `1px solid ${CYAN}33`,
        borderRadius: 12,
        padding: 24,
        marginBottom: 24,
      }}
    >
      <h2 style={{ color: CYAN, fontSize: 18, fontWeight: 700, marginBottom: 16, letterSpacing: 2 }}>
        GITHUB REPOSITORY
      </h2>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 12, marginBottom: 20 }}>
        {[
          { label: 'Cycles', value: repoData.cycles, color: GOLD },
          { label: 'Commits', value: repoData.commits, color: CYAN },
          { label: 'Language', value: repoData.language, color: GREEN },
          { label: 'License', value: repoData.license, color: PURPLE },
        ].map(s => (
          <div key={s.label} style={{
            background: 'rgba(255,255,255,0.03)',
            border: `1px solid ${s.color}22`,
            borderRadius: 8,
            padding: 12,
            textAlign: 'center',
          }}>
            <div style={{ color: '#555', fontSize: 10 }}>{s.label}</div>
            <div style={{ color: s.color, fontSize: 18, fontWeight: 700, fontFamily: 'JetBrains Mono, monospace' }}>{s.value}</div>
          </div>
        ))}
      </div>

      {/* Recent Commits */}
      <div style={{ color: '#888', fontSize: 11, marginBottom: 8, fontWeight: 600 }}>RECENT COMMITS</div>
      {recentCommits.map(c => (
        <div key={c.hash} style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          padding: '8px 0',
          borderBottom: '1px solid #ffffff08',
        }}>
          <span style={{ color: CYAN, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, minWidth: 60 }}>{c.hash}</span>
          <span style={{ color: '#ccc', fontSize: 12, flex: 1 }}>{c.msg}</span>
          <span style={{
            color: c.tag === 'milestone' ? GOLD : '#666',
            fontSize: 10,
            background: c.tag === 'milestone' ? `${GOLD}15` : '#ffffff08',
            padding: '2px 8px',
            borderRadius: 4,
          }}>{c.tag}</span>
        </div>
      ))}

      {/* Link */}
      <div style={{ marginTop: 16, textAlign: 'center' }}>
        <a
          href="https://github.com/gHashTag/trinity"
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: CYAN, fontSize: 12, textDecoration: 'none', opacity: 0.7 }}
        >
          github.com/gHashTag/trinity
        </a>
      </div>
    </motion.div>
  );
}

export default function ProductionDashboard() {
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <div style={{
      minHeight: '100vh',
      background: '#0a0a12',
      color: '#fff',
      fontFamily: 'Outfit, Inter, sans-serif',
    }}>
      {/* Header */}
      <header style={{
        position: 'sticky',
        top: 0,
        zIndex: 50,
        background: 'rgba(10,10,18,0.95)',
        backdropFilter: 'blur(12px)',
        borderBottom: `1px solid ${GOLD}22`,
        padding: '16px 24px',
      }}>
        <div style={{ maxWidth: 1200, margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1 style={{
              fontSize: 24,
              fontWeight: 800,
              background: `linear-gradient(90deg, ${GOLD}, ${CYAN}, ${PURPLE})`,
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              letterSpacing: 2,
            }}>
              TRINITY DASHBOARD
            </h1>
            <div style={{ color: '#555', fontSize: 11, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
              {currentTime.toLocaleString()} | v2.0.0
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 8, height: 8, background: GREEN, borderRadius: '50%', boxShadow: `0 0 8px ${GREEN}` }} />
            <span style={{ color: GREEN, fontSize: 12 }}>OPERATIONAL</span>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <nav style={{
        maxWidth: 1200,
        margin: '0 auto',
        padding: '12px 24px',
        display: 'flex',
        gap: 8,
      }}>
        <a href={import.meta.env.BASE_URL} style={{
          color: '#888',
          fontSize: 12,
          textDecoration: 'none',
          padding: '6px 14px',
          borderRadius: 6,
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(255,255,255,0.08)',
        }}>Home</a>
        <span style={{
          color: GOLD,
          fontSize: 12,
          padding: '6px 14px',
          borderRadius: 6,
          background: `${GOLD}15`,
          border: `1px solid ${GOLD}33`,
        }}>Dashboard</span>
        <a href="https://t27.ai/docs/" target="_blank" rel="noopener noreferrer" style={{
          color: '#888',
          fontSize: 12,
          textDecoration: 'none',
          padding: '6px 14px',
          borderRadius: 6,
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(255,255,255,0.08)',
        }}>Docs</a>
      </nav>

      {/* Main */}
      <main style={{ maxWidth: 1200, margin: '0 auto', padding: '0 24px 48px' }}>
        {/* Top metrics */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 16, marginBottom: 24 }}>
          {[
            { label: 'INFORMATION DENSITY', value: `${Math.log2(3).toFixed(4)} bits/trit`, color: GOLD },
            { label: 'MEMORY SAVINGS', value: '20x vs float32', color: CYAN },
            { label: 'COMPUTE', value: 'Add-only (no mul)', color: GREEN },
            { label: 'TRINITY IDENTITY', value: '\u03C6\u00B2 + 1/\u03C6\u00B2 = 3', color: PURPLE },
          ].map(m => (
            <motion.div
              key={m.label}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              style={{
                background: 'rgba(0,0,0,0.4)',
                border: `1px solid ${m.color}33`,
                borderRadius: 10,
                padding: 16,
              }}
            >
              <div style={{ color: '#555', fontSize: 10, letterSpacing: 1, marginBottom: 6 }}>{m.label}</div>
              <div style={{ color: m.color, fontSize: 18, fontWeight: 700, fontFamily: 'JetBrains Mono, monospace' }}>{m.value}</div>
            </motion.div>
          ))}
        </div>

        {/* Sacred Math */}
        <SacredMathSection />

        {/* Two columns */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(300px, 100%), 1fr))', gap: 24 }}>
          <DePINSection />
          <GitHubSection />
        </div>
      </main>

      {/* Footer */}
      <footer style={{
        maxWidth: 1200,
        margin: '0 auto',
        padding: '24px',
        borderTop: `1px solid ${GOLD}15`,
        display: 'flex',
        justifyContent: 'space-between',
        fontSize: 11,
        color: '#444',
      }}>
        <span>TRINITY DASHBOARD v2.0.0</span>
        <span style={{ fontFamily: '"Times New Roman", serif', fontStyle: 'italic', color: GREEN }}>
          &phi;&sup2; + 1/&phi;&sup2; = 3
        </span>
      </footer>
    </div>
  );
}
