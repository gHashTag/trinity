"use client";

import { motion } from "framer-motion";

// ═══════════════════════════════════════════════════════════════════════════════
// INTELLIGENCE CURVE CHART v8.16
// RAZUM (Gold) — Intelligence, Mind, Self-Evolution
// Shows AGENT MU intelligence growth over time
// ═══════════════════════════════════════════════════════════════════════════════

const GOLD = '#ffd700';
const GOLD_DIM = 'rgba(255, 215, 0, 0.3)';

export interface IntelligencePoint {
  timestamp: number;
  intelligence_multiplier: number;
  mu_used: number;
  fix_type: string;
}

interface Props {
  data: IntelligencePoint[];
  currentMultiplier: number;
}

function formatTimestamp(ts: number): string {
  const seconds = Math.floor((Date.now() - ts) / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const mins = Math.floor(seconds / 60);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  return `${hours}h ago`;
}

function fixTypeColor(fixType: string): string {
  if (fixType.includes('ALLOCATOR') || fixType.includes('MEM')) return '#ff6b6b';
  if (fixType.includes('TYPE')) return '#4ecdc4';
  if (fixType.includes('SYNTAX')) return '#ffe66d';
  if (fixType.includes('IMPORT')) return '#95e1d3';
  return GOLD;
}

export default function IntelligenceCurveChart({ data, currentMultiplier }: Props) {
  // Chart dimensions
  const width = 600;
  const height = 200;
  const padding = { top: 20, right: 20, bottom: 30, left: 50 };

  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;

  // Find min/max for scaling
  const allMultipliers = data.length > 0
    ? [...data.map(d => d.intelligence_multiplier), currentMultiplier]
    : [currentMultiplier];

  const minMult = Math.min(...allMultipliers) * 0.9; // 10% padding
  const maxMult = Math.max(47, ...allMultipliers) * 1.1; // At least show 47× target

  // Calculate SVG path points
  const points = data.length > 0
    ? data.map((d, i) => {
        const x = padding.left + (i / (data.length - 1)) * chartWidth;
        // Log scale for Y axis
        const logY = Math.log10(d.intelligence_multiplier);
        const logMin = Math.log10(minMult);
        const logMax = Math.log10(maxMult);
        const y = padding.top + chartHeight - ((logY - logMin) / (logMax - logMin)) * chartHeight;
        return `${x},${y}`;
      }).join(" ")
    : "";

  // Current multiplier position
  const currentLogY = Math.log10(currentMultiplier);
  const logMin = Math.log10(minMult);
  const logMax = Math.log10(maxMult);
  const currentY = padding.top + chartHeight - ((currentLogY - logMin) / (logMax - logMin)) * chartHeight;
  const currentX = padding.left + chartWidth;

  // Target line (47×)
  const targetLogY = Math.log10(47);
  const targetY = padding.top + chartHeight - ((targetLogY - logMin) / (logMax - logMin)) * chartHeight;

  return (
    <div style={{ width: '100%', maxWidth: '100%' }}>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        style={{
          width: '100%',
          height: 'auto',
          display: 'block',
          fontFamily: 'JetBrains Mono, monospace',
          fontSize: '10px'
        }}
      >
        {/* Grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map((tick) => (
          <line
            key={`grid-${tick}`}
            x1={padding.left}
            y1={padding.top + tick * chartHeight}
            x2={width - padding.right}
            y2={padding.top + tick * chartHeight}
            stroke={GOLD_DIM}
            strokeDasharray="2 2"
            strokeWidth="0.5"
          />
        ))}

        {/* Y-axis labels */}
        {[0, 0.25, 0.5, 0.75, 1].map((tick) => {
          const logVal = Math.log10(minMult) + tick * (Math.log10(maxMult) - Math.log10(minMult));
          const val = Math.pow(10, logVal);
          return (
            <text
              key={`label-${tick}`}
              x={padding.left - 5}
              y={padding.top + tick * chartHeight}
              textAnchor="end"
              dominantBaseline="middle"
              fill={GOLD_DIM}
              fontSize="9"
            >
              {val >= 10 ? `${val.toFixed(0)}×` : `${val.toFixed(1)}×`}
            </text>
          );
        })}

        {/* Target line (47×) */}
        <line
          x1={padding.left}
          y1={targetY}
          x2={width - padding.right}
          y2={targetY}
          stroke="#4ade80"
          strokeWidth="1"
          strokeDasharray="4 4"
          opacity="0.5"
        />
        <text
          x={width - padding.right - 5}
          y={targetY - 5}
          textAnchor="end"
          fill="#4ade80"
          fontSize="9"
          opacity="0.7"
        >
          Target: 47×
        </text>

        {/* Area fill */}
        {points && (
          <motion.path
            initial={{ d: `M ${padding.left},${padding.top + chartHeight} L ${padding.left},${padding.top + chartHeight} ${width - padding.right},${padding.top + chartHeight} ${width - padding.right},${padding.top + chartHeight} Z` }}
            animate={{ d: points
              ? `M ${points} ${width - padding.right},${padding.top + chartHeight} ${padding.left},${padding.top + chartHeight} Z`
              : ""
            }}
            transition={{ duration: 0.5, ease: "easeInOut" }}
            fill={`url(#goldGradient)`}
            opacity="0.3"
          />
        )}

        {/* Line */}
        {points && (
          <motion.polyline
            fill="none"
            stroke={GOLD}
            strokeWidth="2"
            points={points}
            initial={{ pathLength: 0 }}
            whileInView={{ pathLength: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 1, ease: "easeInOut" }}
          />
        )}

        {/* Data points */}
        {data.map((d, i) => {
          const logY = Math.log10(d.intelligence_multiplier);
          const x = padding.left + (i / (data.length - 1)) * chartWidth;
          const y = padding.top + chartHeight - ((logY - logMin) / (logMax - logMin)) * chartHeight;

          return (
            <g key={i}>
              <motion.circle
                cx={x}
                cy={y}
                r="3"
                fill="#000"
                stroke={fixTypeColor(d.fix_type)}
                strokeWidth="2"
                initial={{ opacity: 0, r: 0 }}
                whileInView={{ opacity: 1, r: 3 }}
                transition={{ delay: i * 0.05, duration: 0.3 }}
                style={{ cursor: 'pointer' }}
              />
              {/* Tooltip shown on hover (simplified) */}
              <title>{`×${d.intelligence_multiplier.toFixed(2)} | ${d.fix_type} | ${formatTimestamp(d.timestamp)}`}</title>
            </g>
          );
        })}

        {/* Current value marker */}
        <motion.circle
          cx={currentX}
          cy={currentY}
          r="5"
          fill={GOLD}
          stroke="#fff"
          strokeWidth="2"
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ duration: 0.3 }}
        />
        <text
          x={currentX + 10}
          y={currentY}
          dominantBaseline="middle"
          fill={GOLD}
          fontSize="11"
          fontWeight="bold"
        >
          {currentMultiplier.toFixed(2)}×
        </text>

        {/* Gradient definition */}
        <defs>
          <linearGradient id="goldGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={GOLD} stopOpacity="0.4" />
            <stop offset="100%" stopColor={GOLD} stopOpacity="0" />
          </linearGradient>
        </defs>
      </svg>

      {/* Legend */}
      <div style={{
        display: 'flex',
        gap: '1rem',
        marginTop: '0.5rem',
        fontSize: '9px',
        color: GOLD_DIM,
        justifyContent: 'center'
      }}>
        <span>● Current</span>
        <span>Target: 47×</span>
        {data.length > 0 && (
          <span>{data.length} data points</span>
        )}
      </div>
    </div>
  );
}
