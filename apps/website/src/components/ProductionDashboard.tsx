/**
 * TRI Production Dashboard v2.0
 *
 * Sacred Intelligence Dashboard with:
 * - Trinity Sacred Mathematics (live calculations)
 * - DePIN Network status
 * - GitHub repository stats
 * - System health with Trinity branding
 *
 * Bilingual since 2026-09-06. This route was in the RU audit's ROUTES list from
 * the start and had not one useI18n call, so a Russian reader got a wholly
 * English page. The audit was right every time it fired; what made it look
 * unreliable is that it joins page text and the offending run only exceeded its
 * length threshold when the line breaks happened to fall a certain way. A gate
 * that is correct but intermittent teaches people to ignore it, which is how
 * four permanent reds ended up on every PR in this repo.
 *
 * What deliberately stays in English: proper nouns and identifiers a Russian
 * reader would also write in Latin -- $TRI, DePIN, Ethereum Sepolia, Zig, MIT,
 * GitHub, Fibonacci/Lucas as sequence names, and the commit subjects, which are
 * real commit messages and English by project rule.
 */

import { useState, useEffect, useMemo } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../i18n/context';

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

const T = {
  en: {
    sacredMath: 'SACRED MATHEMATICS',
    trinityIdentity: 'THE TRINITY IDENTITY',
    sum: 'SUM',
    trinityIs: 'L(2) = 3 = TRINITY',
    terms: 'Terms:',
    depin: 'DePIN NETWORK',
    trinityToken: 'Trinity Token',
    totalSupply: 'Total Supply',
    activeNodes: 'Active Nodes',
    tps: 'TPS',
    notLive: 'not yet live',
    allocation: 'TOKEN ALLOCATION',
    nodeRewards: 'Node Rewards',
    founder: 'Founder',
    community: 'Community',
    treasury: 'Treasury',
    liquidity: 'Liquidity',
    stakingTiers: 'STAKING TIERS',
    tierFree: 'Free',
    tierStaker: 'Staker',
    tierPower: 'Power',
    tierWhale: 'Whale',
    perMin: 'req/min',
    unlimited: 'Unlimited',
    repository: 'GITHUB REPOSITORY',
    asOf: 'as of',
    cycles: 'Cycles',
    commits: 'Commits',
    language: 'Language',
    license: 'License',
    recentCommits: 'RECENT COMMITS',
    milestone: 'milestone',
    title: 'TRINITY DASHBOARD',
    operational: 'OPERATIONAL',
    navHome: 'Home',
    navDashboard: 'Dashboard',
    navDocs: 'Docs',
    infoDensity: 'INFORMATION DENSITY',
    bitsPerTrit: 'bits/trit',
    memorySavings: 'MEMORY SAVINGS',
    vsFloat32: '20x vs float32',
    compute: 'COMPUTE',
    addOnly: 'Add-only (no mul)',
    identityLabel: 'TRINITY IDENTITY',
  },
  ru: {
    sacredMath: 'САКРАЛЬНАЯ МАТЕМАТИКА',
    trinityIdentity: 'ТОЖДЕСТВО ТРОИЦЫ',
    sum: 'СУММА',
    trinityIs: 'L(2) = 3 = ТРОИЦА',
    terms: 'Членов:',
    depin: 'СЕТЬ DePIN',
    trinityToken: 'Токен Trinity',
    totalSupply: 'Общая эмиссия',
    activeNodes: 'Активные узлы',
    tps: 'TPS',
    notLive: 'ещё не запущено',
    allocation: 'РАСПРЕДЕЛЕНИЕ ТОКЕНОВ',
    nodeRewards: 'Награды узлам',
    founder: 'Основатель',
    community: 'Сообщество',
    treasury: 'Казна',
    liquidity: 'Ликвидность',
    stakingTiers: 'УРОВНИ СТЕЙКИНГА',
    tierFree: 'Бесплатный',
    tierStaker: 'Стейкер',
    tierPower: 'Продвинутый',
    tierWhale: 'Кит',
    perMin: 'запр/мин',
    unlimited: 'Без лимита',
    repository: 'РЕПОЗИТОРИЙ GITHUB',
    asOf: 'по состоянию на',
    cycles: 'Циклы',
    commits: 'Коммиты',
    language: 'Язык',
    license: 'Лицензия',
    recentCommits: 'ПОСЛЕДНИЕ КОММИТЫ',
    milestone: 'веха',
    title: 'ПАНЕЛЬ TRINITY',
    operational: 'В РАБОТЕ',
    navHome: 'Главная',
    navDashboard: 'Панель',
    navDocs: 'Документация',
    infoDensity: 'ПЛОТНОСТЬ ИНФОРМАЦИИ',
    bitsPerTrit: 'бит/трит',
    memorySavings: 'ЭКОНОМИЯ ПАМЯТИ',
    vsFloat32: 'в 20 раз против float32',
    compute: 'ВЫЧИСЛЕНИЯ',
    addOnly: 'Только сложение (без умножения)',
    identityLabel: 'ТОЖДЕСТВО ТРОИЦЫ',
  },
};

type Copy = typeof T.en;

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

function SacredMathSection({ t }: { t: Copy }) {
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
        {t.sacredMath}
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
        <div style={{ color: '#888', fontSize: 12 }}>{t.trinityIdentity}</div>
        {/* Wraps, and the gap shrinks with the viewport. Three fixed 32px gaps
            plus the ten-digit sum (144px in this mono face at 20px) come to more
            than a 375px screen holds, and without wrapping the third column ran
            13px past the right edge -- enough to make the whole page scroll
            sideways. Caught by qa/mobile_audit.mjs, not by eye. */}
        <div style={{
          display: 'flex', justifyContent: 'center', flexWrap: 'wrap',
          gap: 'clamp(12px, 5vw, 32px)', marginTop: 16,
        }}>
          <div>
            <div style={{ color: '#666', fontSize: 10 }}>&phi;&sup2;</div>
            <div style={{ color: GOLD, fontSize: 20, fontFamily: 'JetBrains Mono, monospace' }}>{data.phi2.toFixed(6)}</div>
          </div>
          <div>
            <div style={{ color: '#666', fontSize: 10 }}>1/&phi;&sup2;</div>
            <div style={{ color: CYAN, fontSize: 20, fontFamily: 'JetBrains Mono, monospace' }}>{data.inv_phi2.toFixed(6)}</div>
          </div>
          <div>
            <div style={{ color: '#666', fontSize: 10 }}>{t.sum}</div>
            <div style={{ color: GREEN, fontSize: 20, fontFamily: 'JetBrains Mono, monospace', fontWeight: 700 }}>{data.trinity.toFixed(10)}</div>
          </div>
        </div>
      </div>

      {/* Constants Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12, marginBottom: 20 }}>
        {[
          { label: 'φ (phi)', value: PHI.toFixed(10), color: GOLD },
          { label: 'μ = φ⁻⁴', value: MU.toFixed(6), color: CYAN },
          { label: 'χ', value: CHI.toFixed(6), color: PURPLE },
          { label: 'σ = φ', value: SIGMA.toFixed(6), color: GOLD },
          { label: 'ε = 1/3', value: EPSILON.toFixed(6), color: GREEN },
          { label: 'log₂(3)', value: data.info_density.toFixed(6), color: CYAN },
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

      {/* Fibonacci & Lucas -- sequence names, Latin in both locales */}
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
          <div style={{ color: '#555', fontSize: 10, marginTop: 4 }}>{t.trinityIs}</div>
        </div>
      </div>

      {/* Slider */}
      <div style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
        <span style={{ color: '#666', fontSize: 11 }}>{t.terms}</span>
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

function DePINSection({ t }: { t: Copy }) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => setTick(v => v + 1), 3000);
    return () => clearInterval(timer);
  }, []);
  void tick;

  // These were `12 + (tick % 3)` and `42 + Math.sin(tick) * 5` -- invented in
  // this component, animated on a 3s timer so they read as polled telemetry.
  // There is not one fetch() in this file. The landing page says the truth
  // about the same subject: DePINSection renders "Testnet Nodes / Launching
  // Soon". The dashboard contradicted its own home page. See A38.
  const nodes = null;
  const tps = null;

  const tiers = [
    { name: t.tierFree, staked: '0', limit: `10 ${t.perMin}`, mult: '1.0x', color: '#666' },
    { name: t.tierStaker, staked: '100+', limit: `60 ${t.perMin}`, mult: '1.5x', color: CYAN },
    { name: t.tierPower, staked: '1,000+', limit: `300 ${t.perMin}`, mult: '2.0x', color: GOLD },
    { name: t.tierWhale, staked: '10,000+', limit: t.unlimited, mult: '3.0x', color: PURPLE },
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
        {t.depin}
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
            <span style={{ color: '#666', fontSize: 12, marginLeft: 8 }}>{t.trinityToken}</span>
          </div>
          <div style={{ color: '#666', fontSize: 11 }}>Ethereum Sepolia</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))', gap: 12 }}>
          <div>
            <div style={{ color: '#555', fontSize: 10 }}>{t.totalSupply}</div>
            <div style={{ color: GOLD, fontSize: 14, fontFamily: 'JetBrains Mono, monospace' }}>3&sup2;&sup1;</div>
            <div style={{ color: '#444', fontSize: 10 }}>10,460,353,203</div>
          </div>
          <div>
            <div style={{ color: '#555', fontSize: 10 }}>{t.activeNodes}</div>
            <div style={{ color: '#666', fontSize: 14, fontFamily: 'JetBrains Mono, monospace' }}>{nodes ?? t.notLive}</div>
          </div>
          <div>
            <div style={{ color: '#555', fontSize: 10 }}>{t.tps}</div>
            <div style={{ color: '#666', fontSize: 14, fontFamily: 'JetBrains Mono, monospace' }}>{tps ?? t.notLive}</div>
          </div>
        </div>
      </div>

      {/* Allocation */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ color: '#888', fontSize: 11, marginBottom: 8, fontWeight: 600 }}>{t.allocation}</div>
        {[
          { label: t.nodeRewards, pct: 40, color: GREEN },
          { label: t.founder, pct: 20, color: GOLD },
          { label: t.community, pct: 20, color: CYAN },
          { label: t.treasury, pct: 10, color: PURPLE },
          { label: t.liquidity, pct: 10, color: '#ff6b6b' },
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
        <div style={{ color: '#888', fontSize: 11, marginBottom: 8, fontWeight: 600 }}>{t.stakingTiers}</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(70px, 1fr))', gap: 8 }}>
          {tiers.map(tier => (
            <div key={tier.name} style={{
              background: 'rgba(255,255,255,0.02)',
              border: `1px solid ${tier.color}33`,
              borderRadius: 8,
              padding: 10,
              textAlign: 'center',
            }}>
              <div style={{ color: tier.color, fontSize: 13, fontWeight: 700 }}>{tier.name}</div>
              <div style={{ color: '#666', fontSize: 9, marginTop: 4 }}>{tier.staked} $TRI</div>
              <div style={{ color: '#888', fontSize: 10, marginTop: 4 }}>{tier.limit}</div>
              <div style={{ color: tier.color, fontSize: 16, fontWeight: 700, marginTop: 4 }}>{tier.mult}</div>
            </div>
          ))}
        </div>
      </div>
    </motion.div>
  );
}

function GitHubSection({ t }: { t: Copy }) {
  // Measured against the GitHub API and `git rev-list --count HEAD` on
  // 2026-08-10. The previous literals claimed 47 stars (real: 7), 8 forks
  // (real: 2), 12 open issues (real: 21) and 120 commits (real: 5681) --
  // numbers a reader can check in one click, overstating stars 6.7x. See A38.
  //
  // Dated rather than fetched: a stale number that says when it was taken is
  // honest; an invented one that moves is not. If this is ever wired to the
  // API, route the failure through sample()/SampleBadge like chatApi does.
  const AS_OF = '2026-08-10';
  const repoData = {
    stars: 7,
    forks: 2,
    issues: 21,
    commits: 5681,
    language: 'Zig',
    license: 'MIT',
    lastCommit: 'feat(forge): Fix routing PIPs for prjxray segbits',
    branch: 'main',
    cycles: null,
  };
  void repoData.stars; void repoData.forks; void repoData.issues;
  void repoData.lastCommit; void repoData.branch;

  // Commit subjects stay in English: they are the real messages, and this
  // project requires commits to be written in English.
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
        {t.repository}
        <span style={{ color: '#555', fontSize: 9, fontWeight: 400, marginLeft: 8 }}>
          {t.asOf} {AS_OF}
        </span>
      </h2>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 12, marginBottom: 20 }}>
        {[
          { label: t.cycles, value: repoData.cycles ?? '—', color: GOLD },
          { label: t.commits, value: repoData.commits, color: CYAN },
          { label: t.language, value: repoData.language, color: GREEN },
          { label: t.license, value: repoData.license, color: PURPLE },
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
      <div style={{ color: '#888', fontSize: 11, marginBottom: 8, fontWeight: 600 }}>{t.recentCommits}</div>
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
          }}>{c.tag === 'milestone' ? t.milestone : c.tag}</span>
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
  const { lang } = useI18n();
  const t: Copy = lang === 'ru' ? T.ru : T.en;
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
              {t.title}
            </h1>
            <div style={{ color: '#555', fontSize: 11, fontFamily: 'JetBrains Mono, monospace', marginTop: 4 }}>
              {/* Was toLocaleString() with no locale, so a Russian reader got
                  "9/6/2026, 9:58:14 AM" -- the browser default, not the page's
                  language. */}
              {currentTime.toLocaleString(lang === 'ru' ? 'ru-RU' : 'en-US')} | v2.0.0
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 8, height: 8, background: GREEN, borderRadius: '50%', boxShadow: `0 0 8px ${GREEN}` }} />
            <span style={{ color: GREEN, fontSize: 12 }}>{t.operational}</span>
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
        }}>{t.navHome}</a>
        <span style={{
          color: GOLD,
          fontSize: 12,
          padding: '6px 14px',
          borderRadius: 6,
          background: `${GOLD}15`,
          border: `1px solid ${GOLD}33`,
        }}>{t.navDashboard}</span>
        <a href="https://t27.ai/docs/" target="_blank" rel="noopener noreferrer" style={{
          color: '#888',
          fontSize: 12,
          textDecoration: 'none',
          padding: '6px 14px',
          borderRadius: 6,
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(255,255,255,0.08)',
        }}>{t.navDocs}</a>
      </nav>

      {/* Main */}
      <main style={{ maxWidth: 1200, margin: '0 auto', padding: '0 24px 48px' }}>
        {/* Top metrics */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 16, marginBottom: 24 }}>
          {[
            { label: t.infoDensity, value: `${Math.log2(3).toFixed(4)} ${t.bitsPerTrit}`, color: GOLD },
            { label: t.memorySavings, value: t.vsFloat32, color: CYAN },
            { label: t.compute, value: t.addOnly, color: GREEN },
            { label: t.identityLabel, value: 'φ² + 1/φ² = 3', color: PURPLE },
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
        <SacredMathSection t={t} />

        {/* Two columns */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(300px, 100%), 1fr))', gap: 24 }}>
          <DePINSection t={t} />
          <GitHubSection t={t} />
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
        <span>{t.title} v2.0.0</span>
        <span style={{ fontFamily: '"Times New Roman", serif', fontStyle: 'italic', color: GREEN }}>
          &phi;&sup2; + 1/&phi;&sup2; = 3
        </span>
      </footer>
    </div>
  );
}
