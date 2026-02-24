import { useState, useEffect, useRef, memo } from 'react';
import { motion, useAnimation } from 'framer-motion';
import type { SacredConstantResult, SingleFitResponse } from '../services/chatApi';

// ─── Types ────────────────────────────────────────────────────────────────────

interface StargateDrumProps {
  constants: SacredConstantResult[];
  isDecomposing: boolean;
  result: SingleFitResponse | null;
  highlightedConstant: string | null;
}

type Phase = 'idle' | 'spinning' | 'locking' | 'revealing' | 'complete';

// ─── Layout Constants (viewBox 0 0 600 600) ──────────────────────────────────

const CX = 300;
const CY = 300;
const RING_R = 215;        // glyph orbit radius (slightly tighter for 27 glyphs)
const GLYPH_R = 18;        // glyph circle radius
const CHEVRON_R = 272;     // chevron orbit radius — pushed out for bigger chevrons
const CHEVRON_SIZE = 48;   // chevron V size — 2x bigger!
const INNER_RING = 190;    // inner decorative ring
const OUTER_RING = 248;    // outer decorative ring
const TRACK_WIDTH = 38;    // ring track stroke width

const CATEGORY_COLORS: Record<string, string> = {
  particle_physics: '#ffd700',
  quantum: '#00ccff',
  cosmology: '#aa66ff',
  quantum_gravity: '#00FF88',
};

// 27 Coptic Glyphs — 3³ = 27, the cube of trinity
// First 25 are main Coptic letters (Ⲁ–Ⲱ), last 2 are Demotic-derived (Ϣ, Ϥ)
const COPTIC_GLYPHS = [
  '\u2C80', '\u2C82', '\u2C84', '\u2C86', '\u2C88', '\u2C8A', '\u2C8C', '\u2C8E', '\u2C90',
  '\u2C92', '\u2C94', '\u2C96', '\u2C98', '\u2C9A', '\u2C9C', '\u2C9E', '\u2CA0', '\u2CA2',
  '\u2CA4', '\u2CA6', '\u2CA8', '\u2CAA', '\u2CAC', '\u2CAE', '\u2CB0', '\u03E2', '\u03E4',
];

// 5 chevrons evenly at 72° apart, starting from TOP (0°)
const CHEVRONS = [
  { label: 'n', angle: 0 },
  { label: '3', angle: 72, sup: 'k' },
  { label: '\u03C0', angle: 144, sup: 'm' },
  { label: '\u03C6', angle: 216, sup: 'p' },
  { label: 'e', angle: 288, sup: 'q' },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function polarToXY(angle: number, r: number) {
  const rad = (angle - 90) * Math.PI / 180;
  return { x: CX + r * Math.cos(rad), y: CY + r * Math.sin(rad) };
}

/** V-shaped chevron (like Stargate) — tip points toward center */
function chevronPath(cx: number, cy: number, _angleDeg: number, size: number): string {
  const toCenterRad = Math.atan2(CY - cy, CX - cx);
  const perpRad = toCenterRad + Math.PI / 2;

  // Tip of V — pointing toward center
  const tipX = cx + Math.cos(toCenterRad) * size * 0.6;
  const tipY = cy + Math.sin(toCenterRad) * size * 0.6;

  // Two wings of V — spread perpendicular, offset away from center
  const backX = cx - Math.cos(toCenterRad) * size * 0.3;
  const backY = cy - Math.sin(toCenterRad) * size * 0.3;

  const wing1X = backX + Math.cos(perpRad) * size * 0.5;
  const wing1Y = backY + Math.sin(perpRad) * size * 0.5;
  const wing2X = backX - Math.cos(perpRad) * size * 0.5;
  const wing2Y = backY - Math.sin(perpRad) * size * 0.5;

  return `M${wing1X},${wing1Y} L${tipX},${tipY} L${wing2X},${wing2Y} Z`;
}

function formatFormula(fit: { n: number; k: number; m: number; p: number; q: number }) {
  const parts: string[] = [`${fit.n}`];
  if (fit.k !== 0) parts.push(`3^${fit.k}`);
  if (fit.m !== 0) parts.push(`\u03C0^${fit.m}`);
  if (fit.p !== 0) parts.push(`\u03C6^${fit.p}`);
  if (fit.q !== 0) parts.push(`e^${fit.q}`);
  return parts.join(' \u00D7 ');
}

function errorBadge(pct: number) {
  if (pct < 0.01) return { label: 'EXACT', color: '#00e599' };
  if (pct < 1.0) return { label: 'CLOSE', color: '#ffd700' };
  return { label: 'APPROX', color: '#ff6b6b' };
}

// ─── Component ────────────────────────────────────────────────────────────────

function StargateDrum({ constants, isDecomposing, result, highlightedConstant }: StargateDrumProps) {
  const [phase, setPhase] = useState<Phase>('idle');
  const [locked, setLocked] = useState<boolean[]>([false, false, false, false, false]);
  const [spinAngle, setSpinAngle] = useState(0);
  const idleAngle = useRef(0);
  const ringControls = useAnimation();
  const prevDecomposing = useRef(false);

  // Idle rotation — continuous slow spin
  useEffect(() => {
    if (phase === 'idle' || phase === 'complete') {
      ringControls.start({
        rotate: [idleAngle.current, idleAngle.current + 360],
        transition: { duration: 60, ease: 'linear', repeat: Infinity },
      });
    }
  }, [phase, ringControls]);

  // Trigger spinning when decomposing starts
  useEffect(() => {
    if (isDecomposing && !prevDecomposing.current) {
      setPhase('spinning');
      setLocked([false, false, false, false, false]);
      const startAngle = idleAngle.current;
      setSpinAngle(startAngle);

      ringControls.start({
        rotate: startAngle + 720,
        transition: { duration: 2.5, ease: [0.4, 0, 0.2, 1] },
      });
    }
    prevDecomposing.current = isDecomposing;
  }, [isDecomposing, ringControls]);

  // When result arrives — lock chevrons sequentially
  useEffect(() => {
    if (!result || phase === 'complete') return;

    setPhase('locking');

    const timers: ReturnType<typeof setTimeout>[] = [];
    for (let i = 0; i < 5; i++) {
      timers.push(setTimeout(() => {
        setLocked(prev => {
          const next = [...prev];
          next[i] = true;
          return next;
        });
      }, i * 400));
    }

    timers.push(setTimeout(() => {
      setPhase('revealing');
    }, 2200));

    timers.push(setTimeout(() => {
      setPhase('complete');
      idleAngle.current = (idleAngle.current + 720) % 360;
    }, 3000));

    return () => timers.forEach(clearTimeout);
  }, [result]);

  // Reset when result clears
  useEffect(() => {
    if (!result && phase !== 'idle') {
      setPhase('idle');
      setLocked([false, false, false, false, false]);
    }
  }, [result, phase]);

  const exponents = result ? [result.fit.n, result.fit.k, result.fit.m, result.fit.p, result.fit.q] : [0, 0, 0, 0, 0];
  const horizonOpen = phase === 'revealing' || phase === 'complete';
  const badge = result ? errorBadge(result.error_pct) : null;

  return (
    <div style={{
      width: 'clamp(360px, 70vw, 620px)',
      aspectRatio: '1 / 1',
      margin: '0 auto 1.5rem',
      position: 'relative',
    }}>
      <svg viewBox="0 0 600 600" style={{ width: '100%', height: '100%' }}>
        <defs>
          <radialGradient id="sg-horizon-idle">
            <stop offset="0%" stopColor="#ffd700" stopOpacity="0.06" />
            <stop offset="60%" stopColor="#ffd700" stopOpacity="0.02" />
            <stop offset="100%" stopColor="#000" stopOpacity="0" />
          </radialGradient>
          <radialGradient id="sg-horizon-active">
            <stop offset="0%" stopColor="#ffd700" stopOpacity="0.35" />
            <stop offset="35%" stopColor="#ffd700" stopOpacity="0.12" />
            <stop offset="100%" stopColor="transparent" stopOpacity="0" />
          </radialGradient>
          <filter id="sg-glow">
            <feDropShadow dx="0" dy="0" stdDeviation="6" floodColor="#ffd700" floodOpacity="0.7" />
          </filter>
          <filter id="sg-glow-soft">
            <feDropShadow dx="0" dy="0" stdDeviation="3" floodColor="#ffd700" floodOpacity="0.4" />
          </filter>
        </defs>

        {/* Layer 1: Outer ring track */}
        <circle cx={CX} cy={CY} r={OUTER_RING} fill="none" stroke="rgba(255,215,0,0.12)" strokeWidth="1.5" />
        <circle cx={CX} cy={CY} r={RING_R} fill="none" stroke="rgba(255,215,0,0.04)" strokeWidth={TRACK_WIDTH} />
        <circle cx={CX} cy={CY} r={INNER_RING} fill="none" stroke="rgba(255,215,0,0.08)" strokeWidth="1" />

        {/* Layer 2: Rotating glyph ring — 27 Coptic glyphs */}
        <motion.g
          animate={ringControls}
          style={{ transformOrigin: `${CX}px ${CY}px` }}
        >
          {COPTIC_GLYPHS.map((glyph, i) => {
            const angle = (i / 27) * 360;
            const { x, y } = polarToXY(angle, RING_R);
            // First N glyphs map to actual constants (if loaded)
            const constant = i < constants.length ? constants[i] : null;
            const isActive = constant !== null;
            const isHighlighted = constant != null && highlightedConstant === constant.symbol;
            const catColor = constant ? (CATEGORY_COLORS[constant.category] || '#888') : 'rgba(255,215,0,0.2)';

            return (
              <g key={i}>
                {isHighlighted && (
                  <motion.circle
                    cx={x} cy={y} r={GLYPH_R + 5}
                    fill="none" stroke="#ffd700" strokeWidth="2"
                    animate={{ opacity: [0.3, 1, 0.3], r: [GLYPH_R + 4, GLYPH_R + 8, GLYPH_R + 4] }}
                    transition={{ duration: 1.5, repeat: Infinity }}
                  />
                )}
                <circle
                  cx={x} cy={y} r={GLYPH_R}
                  fill="rgba(0,0,0,0.7)"
                  stroke={catColor}
                  strokeWidth={isHighlighted ? 2.5 : isActive ? 1.5 : 0.5}
                  opacity={isHighlighted ? 1 : isActive ? 0.85 : 0.3}
                />
                <text
                  x={x} y={y + 1}
                  textAnchor="middle" dominantBaseline="central"
                  fill={isHighlighted ? '#ffd700' : isActive ? '#ddd' : 'rgba(255,215,0,0.15)'}
                  fontSize="14" fontFamily="serif"
                  fontWeight={isHighlighted ? 'bold' : 'normal'}
                >
                  {glyph}
                </text>
              </g>
            );
          })}
        </motion.g>

        {/* Layer 3: 5 Chevrons — 2x bigger, evenly spaced, tips pointing inward */}
        {CHEVRONS.map((chev, i) => {
          const { x, y } = polarToXY(chev.angle, CHEVRON_R);
          const isLocked = locked[i];

          return (
            <g key={chev.label + i}>
              <motion.path
                d={chevronPath(x, y, chev.angle, CHEVRON_SIZE)}
                fill={isLocked ? '#ffd700' : 'rgba(255,255,255,0.12)'}
                stroke={isLocked ? '#ffd700' : 'rgba(255,255,255,0.25)'}
                strokeWidth="2"
                strokeLinejoin="round"
                animate={isLocked ? {
                  scale: [1, 1.3, 1.05],
                  opacity: 1,
                } : { scale: 1, opacity: 0.5 }}
                transition={isLocked ? { type: 'spring', stiffness: 300, damping: 12 } : { duration: 0.3 }}
                style={{ transformOrigin: `${x}px ${y}px`, filter: isLocked ? 'url(#sg-glow)' : 'none' }}
              />
              {/* Chevron label — outside the ring */}
              {(() => {
                const labelR = CHEVRON_R + 38;
                const { x: lx, y: ly } = polarToXY(chev.angle, labelR);
                return (
                  <motion.text
                    x={lx} y={ly}
                    textAnchor="middle" dominantBaseline="central"
                    fill={isLocked ? '#ffd700' : 'rgba(255,255,255,0.3)'}
                    fontSize="18" fontFamily="monospace" fontWeight="bold"
                    animate={{ opacity: isLocked ? 1 : 0.3 }}
                    style={{ filter: isLocked ? 'url(#sg-glow-soft)' : 'none' }}
                  >
                    {chev.sup ? `${chev.label}^${chev.sup}` : chev.label}
                  </motion.text>
                );
              })()}
              {/* Exponent value inside chevron when locked */}
              {isLocked && (
                <motion.text
                  x={x} y={y}
                  textAnchor="middle" dominantBaseline="central"
                  fill="#000" fontSize="18" fontFamily="monospace" fontWeight="bold"
                  initial={{ opacity: 0, scale: 0 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ type: 'spring', stiffness: 400, damping: 20 }}
                >
                  {exponents[i]}
                </motion.text>
              )}
            </g>
          );
        })}

        {/* Layer 4: Event Horizon */}
        <circle cx={CX} cy={CY} r={150} fill="url(#sg-horizon-idle)" />

        {/* Idle ripple rings */}
        <circle cx={CX} cy={CY} r={100} fill="none" stroke="rgba(255,215,0,0.08)" strokeWidth="1" className="anim-pulse" />
        <circle cx={CX} cy={CY} r={125} fill="none" stroke="rgba(255,215,0,0.05)" strokeWidth="1" className="anim-pulse" style={{ animationDelay: '1.3s' }} />
        <circle cx={CX} cy={CY} r={75} fill="none" stroke="rgba(255,215,0,0.04)" strokeWidth="0.5" className="anim-pulse" style={{ animationDelay: '2.6s' }} />

        {/* Active horizon bloom */}
        <motion.circle
          cx={CX} cy={CY}
          fill="url(#sg-horizon-active)"
          animate={{ r: horizonOpen ? 160 : 0, opacity: horizonOpen ? 1 : 0 }}
          transition={{ duration: 0.6, ease: [0, 0.55, 0.45, 1] }}
        />

        {/* Center formula text (always visible but dim when idle) */}
        {!horizonOpen && (
          <text
            x={CX} y={CY}
            textAnchor="middle" dominantBaseline="central"
            fill="rgba(255,215,0,0.18)" fontSize="16" fontFamily="monospace"
          >
            V = n {'\u00D7'} 3{'\u207A'} {'\u00D7'} {'\u03C0'}{'\u207A'} {'\u00D7'} {'\u03C6'}{'\u207A'} {'\u00D7'} e{'\u207A'}
          </text>
        )}

        {/* Result text inside horizon */}
        {horizonOpen && result && (
          <motion.g
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.4, delay: 0.2 }}
          >
            <text
              x={CX} y={CY - 30}
              textAnchor="middle" dominantBaseline="central"
              fill="#ffd700" fontSize="18" fontFamily="monospace" fontWeight="bold"
              style={{ filter: 'url(#sg-glow-soft)' }}
            >
              {formatFormula(result.fit)}
            </text>
            <text
              x={CX} y={CY + 5}
              textAnchor="middle" dominantBaseline="central"
              fill="#fff" fontSize="22" fontFamily="monospace"
            >
              = {result.computed.toFixed(6)}
            </text>
            {badge && (
              <g>
                <rect
                  x={CX - 60} y={CY + 25}
                  width="120" height="26" rx="6"
                  fill={`${badge.color}22`}
                  stroke={`${badge.color}44`}
                  strokeWidth="1"
                />
                <text
                  x={CX} y={CY + 38}
                  textAnchor="middle" dominantBaseline="central"
                  fill={badge.color} fontSize="12" fontFamily="monospace"
                >
                  {badge.label} ({result.error_pct.toFixed(4)}%)
                </text>
              </g>
            )}
          </motion.g>
        )}
      </svg>
    </div>
  );
}

export default memo(StargateDrum);
