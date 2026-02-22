"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  fetchAgentMuSacredMath,
  type SacredMathData,
  subscribeToPatternEvents,
  type PatternEvent,
  EXPLANATIONS,
} from "@/services/chatApi";

const FONT = "'Outfit', system-ui, sans-serif";
const MONO = "'JetBrains Mono', 'Fira Code', monospace";

const GOLD = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';
const GREEN = '#00ff88';
const RED = '#ff4444';

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
 * Sacred Math Dashboard Widget v8.20
 *
 * Real-time display of AGENT MU's sacred constants:
 * - μ (mu) = 0.0382 per successful fix
 * - φ (phi) = 1.6180339887498948482 (golden ratio)
 * - L(10) = 123 (10th Lucas number)
 * - Trinity score = φ² + 1/φ² = 3
 *
 * v8.20 Features:
 * - Live self-modification visualization (SSE events)
 * - Interactive sacred math explanations (click to learn)
 * - Visual feedback for pattern proposal, validation, application
 */
export default function SacredMathWidget({ width = 340, height = 200 }: Props) {
  const [data, setData] = useState<SacredMathData | null>(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);
  const [selectedConstant, setSelectedConstant] = useState<string | null>(null);
  const [liveEvent, setLiveEvent] = useState<PatternEvent | null>(null);
  const [eventHistory, setEventHistory] = useState<PatternEvent[]>([]);
  const cleanupRef = useRef<(() => void) | null>(null);

  // Fetch initial data
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
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  // Subscribe to live pattern events
  useEffect(() => {
    const cleanup = subscribeToPatternEvents(
      (event) => {
        setLiveEvent(event);
        setEventHistory((prev) => [event, ...prev].slice(0, 10)); // Keep last 10

        // Auto-clear event after animation
        setTimeout(() => setLiveEvent(null), 3000);
      },
      (error) => {
        console.error('Pattern event stream error:', error);
      }
    );

    cleanupRef.current = cleanup;
    return () => cleanup();
  }, []);

  const formatNumber = (n: number, decimals: number = 4) =>
    n.toFixed(decimals);

  const handleConstantClick = useCallback((constant: string) => {
    setSelectedConstant((prev) => (prev === constant ? null : constant));
  }, []);

  const getEventColor = useCallback((eventType?: PatternEventType) => {
    switch (eventType) {
      case 'proposing': return GOLD;
      case 'validating': return PURPLE;
      case 'applied': return GREEN;
      case 'rejected': return RED;
      case 'rollback': return RED;
      default: return GOLD;
    }
  }, []);

  const getEventIcon = useCallback((eventType?: PatternEventType) => {
    switch (eventType) {
      case 'proposing': return '⏳';
      case 'validating': return '🔍';
      case 'applied': return '✅';
      case 'rejected': return '❌';
      case 'rollback': return '↩️';
      default: return '●';
    }
  }, []);

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

  // Animation variants for live events
  const pulseAnimation = liveEvent ? {
    scale: [1, 1.03, 1],
    boxShadow: liveEvent.type === 'applied'
      ? ['0 0 0 rgba(0,255,136,0)', '0 0 25px rgba(0,255,136,0.6)', '0 0 0 rgba(0,255,136,0)']
      : liveEvent.type === 'rejected' || liveEvent.type === 'rollback'
      ? ['0 0 0 rgba(255,68,68,0)', '0 0 25px rgba(255,68,68,0.6)', '0 0 0 rgba(255,68,68,0)']
      : ['0 0 0 rgba(255,215,0,0)', '0 0 15px rgba(255,215,0,0.4)', '0 0 0 rgba(255,215,0,0)'],
  } : {};

  const shakeAnimation = liveEvent?.type === 'rejected' || liveEvent?.type === 'rollback' ? {
    x: [0, -4, 4, -4, 4, 0],
  } : {};

  return (
    <motion.div
      style={{
        width,
        ...glassStyle('rgba(255,215,0,0.15)'),
        padding: '12px',
        fontFamily: FONT,
        color: GOLD,
        transition: 'height 0.3s ease',
        position: 'relative',
      }}
      animate={Object.keys(pulseAnimation).length > 0 ? pulseAnimation : {}}
      transition={{ duration: 0.5 }}
    >
      {/* Live Event Overlay */}
      <AnimatePresence>
        {liveEvent && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            style={{
              position: 'absolute',
              top: -30,
              left: 0,
              right: 0,
              background: `rgba(0,0,0,0.8)`,
              border: `1px solid ${getEventColor(liveEvent.type)}`,
              borderRadius: '8px',
              padding: '6px 10px',
              fontSize: '9px',
              zIndex: 100,
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
          >
            <span style={{ fontSize: '12px' }}>{getEventIcon(liveEvent.type)}</span>
            <span style={{ color: getEventColor(liveEvent.type), fontWeight: 'bold' }}>
              {liveEvent.type.toUpperCase()}
            </span>
            {liveEvent.pattern_id && (
              <span style={{ opacity: 0.7 }}>
                #{liveEvent.pattern_id.split('_').pop()}
              </span>
            )}
            {liveEvent.confidence !== undefined && (
              <span style={{ opacity: 0.7, marginLeft: 'auto' }}>
                {(liveEvent.confidence * 100).toFixed(0)}%
              </span>
            )}
          </motion.div>
        )}
      </AnimatePresence>

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
          SACRED MATH v8.20
        </span>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {/* Live indicator */}
          {cleanupRef.current && (
            <motion.div
              animate={{ opacity: [0.4, 1, 0.4] }}
              transition={{ duration: 2, repeat: Infinity }}
              style={{
                fontSize: '8px',
                color: GREEN,
                display: 'flex',
                alignItems: 'center',
                gap: '3px',
              }}
            >
              <span style={{ fontSize: '6px' }}>●</span>
              LIVE
            </motion.div>
          )}
          <span style={{ fontSize: '8px', opacity: 0.7 }}>
            {uptimeDisplay}
          </span>
        </div>
      </div>

      {/* μ (Mu) - Intelligence Gain */}
      <motion.div
        style={{ marginBottom: '8px' }}
        animate={shakeAnimation}
        transition={{ duration: 0.4 }}
      >
        <div
          onClick={() => handleConstantClick('mu')}
          style={{
            fontSize: '8px',
            opacity: 0.7,
            marginBottom: '2px',
            cursor: 'pointer',
            transition: 'opacity 0.2s',
          }}
          onMouseEnter={(e) => e.currentTarget.style.opacity = '1'}
          onMouseLeave={(e) => e.currentTarget.style.opacity = '0.7'}
        >
          μ (Intelligence Gain) {selectedConstant === null && '(click for info)'}
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

        {/* μ Explanation Panel */}
        <AnimatePresence>
          {selectedConstant === 'mu' && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              style={{
                marginTop: '8px',
                padding: '8px',
                background: 'rgba(0,204,255,0.08)',
                border: '1px solid rgba(0,204,255,0.2)',
                borderRadius: '6px',
                fontSize: '8px',
              }}
            >
              <div style={{ color: CYAN, fontWeight: 'bold', marginBottom: '4px' }}>
                {EXPLANATIONS.mu.constant}
              </div>
              <code style={{ fontSize: '7px', color: GOLD }}>
                {EXPLANATIONS.mu.formula}
              </code>
              <div style={{ marginTop: '4px', opacity: 0.8 }}>
                {EXPLANATIONS.mu.description}
              </div>
              <div style={{ marginTop: '4px', fontSize: '7px', opacity: 0.6 }}>
                {EXPLANATIONS.mu.impact_on_intelligence}
              </div>
              {EXPLANATIONS.mu.proof && (
                <div style={{ marginTop: '4px', fontSize: '7px', fontFamily: MONO, opacity: 0.5 }}>
                  Proof: {EXPLANATIONS.mu.proof}
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>

      {/* φ (Phi) - Golden Ratio */}
      <div style={{ marginBottom: '8px' }}>
        <div
          onClick={() => handleConstantClick('phi')}
          style={{
            fontSize: '8px',
            opacity: 0.7,
            marginBottom: '2px',
            cursor: 'pointer',
          }}
          onMouseEnter={(e) => e.currentTarget.style.opacity = '1'}
          onMouseLeave={(e) => e.currentTarget.style.opacity = '0.7'}
        >
          φ (Golden Ratio)
        </div>
        <div style={{
          fontSize: expanded ? '15px' : '13px',
          fontFamily: MONO,
          color: GOLD
        }}>
          {formatNumber(data.phi, 10)}
        </div>

        {/* φ Explanation Panel */}
        <AnimatePresence>
          {selectedConstant === 'phi' && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              style={{
                marginTop: '8px',
                padding: '8px',
                background: 'rgba(255,215,0,0.08)',
                border: '1px solid rgba(255,215,0,0.2)',
                borderRadius: '6px',
                fontSize: '8px',
              }}
            >
              <div style={{ color: GOLD, fontWeight: 'bold', marginBottom: '4px' }}>
                {EXPLANATIONS.phi.constant}
              </div>
              <code style={{ fontSize: '7px', color: CYAN }}>
                {EXPLANATIONS.phi.formula}
              </code>
              <div style={{ marginTop: '4px', opacity: 0.8 }}>
                {EXPLANATIONS.phi.description}
              </div>
              {EXPLANATIONS.phi.proof && (
                <div style={{ marginTop: '4px', fontSize: '7px', fontFamily: MONO, opacity: 0.5 }}>
                  Proof: {EXPLANATIONS.phi.proof}
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>

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
            <div
              onClick={() => handleConstantClick('lucas_10')}
              style={{
                textAlign: 'center',
                cursor: 'pointer',
                padding: '4px',
                borderRadius: '4px',
                transition: 'background 0.2s',
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(170,102,255,0.1)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
            >
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
            <div
              onClick={() => handleConstantClick('trinity')}
              style={{
                textAlign: 'center',
                cursor: 'pointer',
                padding: '4px',
                borderRadius: '4px',
                transition: 'background 0.2s',
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(255,215,0,0.1)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
            >
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

          {/* L(10) Explanation */}
          <AnimatePresence>
            {selectedConstant === 'lucas_10' && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                style={{
                  marginTop: '8px',
                  padding: '8px',
                  background: 'rgba(170,102,255,0.08)',
                  border: '1px solid rgba(170,102,255,0.2)',
                  borderRadius: '6px',
                  fontSize: '8px',
                }}
              >
                <div style={{ color: PURPLE, fontWeight: 'bold', marginBottom: '4px' }}>
                  {EXPLANATIONS.lucas_10.constant}
                </div>
                <code style={{ fontSize: '7px', color: GOLD }}>
                  {EXPLANATIONS.lucas_10.formula}
                </code>
                <div style={{ marginTop: '4px', opacity: 0.8 }}>
                  {EXPLANATIONS.lucas_10.description}
                </div>
                <div style={{ marginTop: '4px', fontSize: '7px', opacity: 0.6 }}>
                  {EXPLANATIONS.lucas_10.impact_on_intelligence}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Trinity Explanation */}
          <AnimatePresence>
            {selectedConstant === 'trinity' && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                style={{
                  marginTop: '8px',
                  padding: '8px',
                  background: 'rgba(255,215,0,0.08)',
                  border: '1px solid rgba(255,215,0,0.2)',
                  borderRadius: '6px',
                  fontSize: '8px',
                }}
              >
                <div style={{ color: GOLD, fontWeight: 'bold', marginBottom: '4px' }}>
                  {EXPLANATIONS.trinity.constant}
                </div>
                <code style={{ fontSize: '7px', color: CYAN }}>
                  {EXPLANATIONS.trinity.formula}
                </code>
                <div style={{ marginTop: '4px', opacity: 0.8 }}>
                  {EXPLANATIONS.trinity.description}
                </div>
                <div style={{ marginTop: '4px', fontSize: '7px', opacity: 0.6 }}>
                  {EXPLANATIONS.trinity.impact_on_intelligence}
                </div>
                {EXPLANATIONS.trinity.proof && (
                  <div style={{ marginTop: '4px', fontSize: '7px', fontFamily: MONO, opacity: 0.5 }}>
                    Proof: {EXPLANATIONS.trinity.proof}
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>

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

          {/* Live Event History */}
          {eventHistory.length > 0 && (
            <div
              style={{
                marginTop: '10px',
                padding: '6px',
                background: 'rgba(0,0,0,0.3)',
                borderRadius: '6px',
                fontSize: '7px',
              }}
            >
              <div style={{ opacity: 0.6, marginBottom: '4px' }}>
                Recent Events
              </div>
              {eventHistory.slice(0, 5).map((event, idx) => (
                <div
                  key={`${event.timestamp}-${idx}`}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '2px 0',
                    opacity: 1 - idx * 0.15,
                  }}
                >
                  <span style={{ color: getEventColor(event.type) }}>
                    {getEventIcon(event.type)}
                  </span>
                  <span style={{ opacity: 0.7 }}>
                    {event.type.toUpperCase()}
                  </span>
                  {event.pattern_id && (
                    <span style={{ opacity: 0.5, fontFamily: MONO }}>
                      #{event.pattern_id.split('_').pop()}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}

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
          <div
            onClick={() => handleConstantClick('lucas_10')}
            style={{ cursor: 'pointer' }}
          >
            <div style={{ fontSize: '7px', opacity: 0.5 }}>L(10)</div>
            <div style={{ fontFamily: MONO, color: PURPLE }}>
              {data.lucas_10}
            </div>
          </div>
          <div
            onClick={() => handleConstantClick('trinity')}
            style={{ cursor: 'pointer' }}
          >
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
    </motion.div>
  );
}
