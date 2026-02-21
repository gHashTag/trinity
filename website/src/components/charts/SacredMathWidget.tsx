"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { fetchAgentMuSacredMath, type SacredMathData } from "@/services/chatApi";

const FONT = "'Outfit', system-ui, sans-serif";
const MONO = "'JetBrains Mono', 'Fira Code', monospace";

const GOLD = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';

const glassStyle = (borderColor = 'rgba(255,255,255,0.08)'): React.CSSProperties => ({
  background: 'rgba(0,0,0,0.3)',
  backdropFilter: 'blur(12px)',
  border: `1px solid ${borderColor}`,
  borderRadius: 14,
});

interface Props {
  width?: number;
  height?: number;
}

/**
 * Sacred Math Dashboard Widget v8.19
 *
 * Real-time display of AGENT MU's sacred constants:
 * - μ (mu) = 0.0382 per successful fix
 * - φ (phi) = 1.6180339887498948482 (golden ratio)
 * - L(10) = 123 (10th Lucas number)
 * - Trinity score = φ² + 1/φ² = 3
 */
export default function SacredMathWidget({ width = 340, height = 200 }: Props) {
  const [data, setData] = useState<SacredMathData | null>(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const result = await fetchAgentMuSacredMath();
        setData(result);
      } catch (error) {
        console.error("Failed to fetch sacred math:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 5000); // Update every 5s
    return () => clearInterval(interval);
  }, []);

  const formatNumber = (n: number, decimals: number = 4) =>
    n.toFixed(decimals);

  if (loading || !data) {
    return (
      <div style={{
        width,
        height,
        ...glassStyle('rgba(255,215,0,0.15)'),
        padding: '12px',
        fontFamily: FONT,
        color: GOLD,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: '10px'
      }}>
        <motion.div
          animate={{ opacity: [0.3, 1, 0.3] }}
          transition={{ duration: 1.5, repeat: Infinity }}
        >
          Loading Sacred Math...
        </motion.div>
      </div>
    );
  }

  const uptimeMinutes = Math.floor(data.uptime_seconds / 60);
  const uptimeHours = Math.floor(uptimeMinutes / 60);
  const uptimeDisplay = uptimeHours > 0
    ? `${uptimeHours}h ${uptimeMinutes % 60}m`
    : `${uptimeMinutes}m`;

  return (
    <div
      style={{
        width,
        ...glassStyle('rgba(255,215,0,0.15)'),
        padding: '12px',
        fontFamily: FONT,
        color: GOLD,
        transition: 'height 0.3s ease'
      }}
    >
      {/* Header */}
      <div
        style={{
          fontSize: '12px',
          fontWeight: 'bold',
          marginBottom: '10px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          cursor: 'pointer',
        }}
        onClick={() => setExpanded(!expanded)}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <motion.span
            animate={{ rotate: expanded ? 90 : 0 }}
            transition={{ duration: 0.2 }}
          >
            ▸
          </motion.span>
          SACRED MATH v8.19
        </span>
        <span style={{ fontSize: '8px', opacity: 0.7 }}>
          {uptimeDisplay} uptime
        </span>
      </div>

      {/* μ (Mu) - Intelligence Gain */}
      <motion.div
        style={{ marginBottom: '8px' }}
        initial={false}
        animate={{ opacity: expanded ? 1 : 1 }}
      >
        <div style={{ fontSize: '8px', opacity: 0.7, marginBottom: '2px' }}>
          μ (Intelligence Gain)
        </div>
        <div style={{
          fontSize: expanded ? '18px' : '16px',
          fontFamily: MONO,
          color: CYAN,
          fontWeight: 'bold'
        }}>
          {formatNumber(data.mu, 4)} ×
        </div>
        <div style={{ fontSize: '7px', opacity: 0.5 }}>
          per fix = 1/φ²/10
        </div>
      </motion.div>

      {/* φ (Phi) - Golden Ratio */}
      <div style={{ marginBottom: '8px' }}>
        <div style={{ fontSize: '8px', opacity: 0.7, marginBottom: '2px' }}>
          φ (Golden Ratio)
        </div>
        <div style={{
          fontSize: expanded ? '15px' : '13px',
          fontFamily: MONO,
          color: GOLD
        }}>
          {formatNumber(data.phi, 10)}
        </div>
      </motion.div>

      {/* Expanded section with more details */}
      {expanded && (
        <motion.div
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: 'auto', opacity: 1 }}
          exit={{ height: 0, opacity: 0 }}
          style={{ fontSize: '10px' }}
        >
          {/* Sacred Constants Grid */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: '8px',
              marginTop: '10px',
              paddingTop: '10px',
              borderTop: '1px solid rgba(255,215,0,0.2)'
            }}
          >
            {/* L(10) */}
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '7px', opacity: 0.5, marginBottom: '2px' }}>
                L(10)
              </div>
              <div style={{ fontFamily: MONO, color: PURPLE, fontWeight: 'bold' }}>
                {data.lucas_10}
              </div>
              <div style={{ fontSize: '6px', opacity: 0.4 }}>
                Lucas №10
              </div>
            </div>

            {/* Trinity */}
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '7px', opacity: 0.5, marginBottom: '2px' }}>
                Trinity
              </div>
              <div style={{ fontFamily: MONO, color: GOLD, fontWeight: 'bold' }}>
                {formatNumber(data.trinity_score, 2)}
              </div>
              <div style={{ fontSize: '6px', opacity: 0.4 }}>
                φ² + 1/φ²
              </div>
            </div>

            {/* Current Intelligence */}
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '7px', opacity: 0.5, marginBottom: '2px' }}>
                I(t)
              </div>
              <div style={{ fontFamily: MONO, color: CYAN, fontWeight: 'bold' }}>
                ×{data.current_intelligence.toFixed(1)}
              </div>
              <div style={{ fontSize: '6px', opacity: 0.4 }}>
                Intelligence
              </div>
            </div>
          </div>

          {/* Additional sacred formulas */}
          <div
            style={{
              marginTop: '10px',
              padding: '6px',
              background: 'rgba(255,215,0,0.05)',
              borderRadius: '6px',
              fontSize: '7px',
              fontFamily: MONO,
              opacity: 0.8
            }}
          >
            <div>φ² = {formatNumber(data.phi * data.phi, 6)}</div>
            <div>1/φ² = {formatNumber(1 / (data.phi * data.phi), 6)}</div>
            <div style={{ marginTop: '4px', color: CYAN }}>
              φ² + 1/φ² = {formatNumber(data.phi * data.phi + 1 / (data.phi * data.phi), 2)} = 3
            </div>
          </div>

          {/* Version info */}
          <div
            style={{
              marginTop: '8px',
              fontSize: '6px',
              opacity: 0.4,
              textAlign: 'center'
            }}
          >
            AGENT MU {data.version}
          </div>
        </motion.div>
      )}

      {/* Collapsed footer with key metrics */}
      {!expanded && (
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            fontSize: '10px',
            marginTop: '6px'
          }}
        >
          <div>
            <div style={{ fontSize: '7px', opacity: 0.5 }}>L(10)</div>
            <div style={{ fontFamily: MONO, color: PURPLE }}>
              {data.lucas_10}
            </div>
          </div>
          <div>
            <div style={{ fontSize: '7px', opacity: 0.5 }}>Trinity</div>
            <div style={{ fontFamily: MONO, color: GOLD }}>
              {formatNumber(data.trinity_score, 2)}
            </div>
          </div>
          <div>
            <div style={{ fontSize: '7px', opacity: 0.5 }}>I(t)</div>
            <div style={{ fontFamily: MONO, color: CYAN }}>
              ×{data.current_intelligence.toFixed(1)}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
