"use client";

import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  fetchKoscheiStatus,
  type KoscheiStatus,
  type KoscheiState,
} from "@/services/chatApi";

const FONT = "'Outfit', system-ui, sans-serif";
const MONO = "'JetBrains Mono', 'Fira Code', monospace";

const GOLD = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';
const GREEN = '#00ff88';
const RED = '#ff4444';
const ORANGE = '#ff8833';

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
 * KOSCHEI Status Dashboard Widget v8.24
 *
 * Real-time display of KOSCHEI MODE production swarm status:
 * - Overall state: IMMORTAL / RECOVERING / VULNERABLE
 * - Node health across all 5 nodes
 * - Circuit breaker status (CLOSED = healthy)
 * - PAS efficiency (target: >20%)
 * - Phi-spiral consensus (0.0 - 1.0)
 * - Auto-recovery status
 * - Uptime and last recovery time
 *
 * v8.24 Features:
 * - Multi-node cluster visualization
 * - Real-time status polling (3s interval)
 * - Color-coded health indicators
 * - Expandable node-by-node breakdown
 */
export default function KoscheiStatusWidget({ width = 360, height = 220 }: Props) {
  const [status, setStatus] = useState<KoscheiStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);

  // Fetch KOSCHEI status
  useEffect(() => {
    const fetchData = async () => {
      try {
        const result = await fetchKoscheiStatus();
        setStatus(result);
      } catch (error) {
        console.error("Failed to fetch KOSCHEI status:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 3000); // Poll every 3 seconds
    return () => clearInterval(interval);
  }, []);

  const formatUptime = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const formatTimestamp = (ts: number | null): string => {
    if (!ts) return 'Never';
    const date = new Date(ts);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return date.toLocaleDateString();
  };

  const getStateColor = useCallback((state: KoscheiState): string => {
    switch (state) {
      case 'IMMORTAL': return GOLD;
      case 'RECOVERING': return ORANGE;
      case 'VULNERABLE': return RED;
      default: return GOLD;
    }
  }, []);

  const getStateIcon = useCallback((state: KoscheiState): string => {
    switch (state) {
      case 'IMMORTAL': return '∞';
      case 'RECOVERING': return '⟳';
      case 'VULNERABLE': return '⚠';
      default: return '●';
    }
  }, []);

  const getNodeStatusColor = useCallback((nodeStatus: string): string => {
    switch (nodeStatus) {
      case 'online': return GREEN;
      case 'recovering': return ORANGE;
      case 'offline': return RED;
      default: return RED;
    }
  }, []);

  const getCircuitBreakerColor = useCallback((cbState: string): string => {
    switch (cbState) {
      case 'CLOSED': return GREEN;
      case 'HALF_OPEN': return ORANGE;
      case 'OPEN': return RED;
      default: return RED;
    }
  }, []);

  if (loading || !status) {
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
          Loading KOSCHEI Status...
        </motion.div>
      </div>
    );
  }

  const stateColor = getStateColor(status.state);
  const uptime = formatUptime(status.uptime_seconds);
  const circuitBreakerPercent = status.circuit_breakers_total > 0
    ? (status.circuit_breakers_closed / status.circuit_breakers_total) * 100
    : 100;

  return (
    <motion.div
      style={{
        width,
        ...glassStyle(`${stateColor}33`),
        padding: '12px',
        fontFamily: FONT,
        color: stateColor,
        transition: 'height 0.3s ease',
      }}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
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
          KOSCHEI v8.24
        </span>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <motion.div
            animate={{ opacity: [0.4, 1, 0.4] }}
            transition={{ duration: 2, repeat: Infinity }}
            style={{
              fontSize: '8px',
              color: status.state === 'IMMORTAL' ? GREEN : ORANGE,
              display: 'flex',
              alignItems: 'center',
              gap: '3px',
            }}
          >
            <span style={{ fontSize: '6px' }}>●</span>
            {status.state}
          </motion.div>
          <span style={{ fontSize: '8px', opacity: 0.7 }}>
            {uptime}
          </span>
        </div>
      </div>

      {/* Main Status Indicator */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          marginBottom: '10px',
          padding: '8px',
          background: `${stateColor}11`,
          borderRadius: '8px',
          border: `1px solid ${stateColor}44`,
        }}
      >
        <motion.div
          animate={status.state === 'RECOVERING' ? { rotate: 360 } : {}}
          transition={status.state === 'RECOVERING' ? { duration: 2, repeat: Infinity, ease: 'linear' } : {}}
          style={{
            fontSize: '24px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {getStateIcon(status.state)}
        </motion.div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: '14px', fontWeight: 'bold' }}>
            {status.state === 'IMMORTAL' && 'KOSCHEI IS IMMORTAL'}
            {status.state === 'RECOVERING' && 'AUTO-RECOVERY ACTIVE'}
            {status.state === 'VULNERABLE' && 'SYSTEM VULNERABLE'}
          </div>
          <div style={{ fontSize: '8px', opacity: 0.7 }}>
            {status.nodes_online}/{status.nodes_total} nodes online
          </div>
        </div>
      </div>

      {/* Key Metrics Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: '8px',
          marginBottom: '8px',
        }}
      >
        {/* Circuit Breaker Health */}
        <div
          style={{
            padding: '6px',
            background: 'rgba(0,0,0,0.3)',
            borderRadius: '6px',
          }}
        >
          <div style={{ fontSize: '7px', opacity: 0.6, marginBottom: '2px' }}>
            Circuit Breakers
          </div>
          <div style={{
            height: '4px',
            background: 'rgba(255,255,255,0.1)',
            borderRadius: '2px',
            overflow: 'hidden',
            marginBottom: '4px',
          }}>
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${circuitBreakerPercent}%` }}
              transition={{ duration: 0.5 }}
              style={{
                height: '100%',
                background: circuitBreakerPercent > 90 ? GREEN : circuitBreakerPercent > 50 ? ORANGE : RED,
              }}
            />
          </div>
          <div style={{ fontSize: '9px', fontFamily: MONO }}>
            {status.circuit_breakers_closed}/{status.circuit_breakers_total} CLOSED
          </div>
        </div>

        {/* PAS Efficiency */}
        <div
          style={{
            padding: '6px',
            background: 'rgba(0,0,0,0.3)',
            borderRadius: '6px',
          }}
        >
          <div style={{ fontSize: '7px', opacity: 0.6, marginBottom: '2px' }}>
            PAS Efficiency
          </div>
          <div style={{ fontSize: '14px', fontFamily: MONO, color: CYAN, fontWeight: 'bold' }}>
            {(status.avg_pas_efficiency * 100).toFixed(1)}%
          </div>
          <div style={{ fontSize: '7px', opacity: 0.5 }}>
            target: &gt;20%
          </div>
        </div>
      </div>

      {/* Phi-Spiral Consensus */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px',
          background: 'rgba(170,102,255,0.1)',
          borderRadius: '6px',
          border: '1px solid rgba(170,102,255,0.2)',
        }}
      >
        <div style={{ fontSize: '7px', opacity: 0.7 }}>
          φ-Spiral Consensus
        </div>
        <div style={{ flex: 1, height: '3px', background: 'rgba(255,255,255,0.1)', borderRadius: '2px' }}>
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${status.phi_spiral_consensus * 100}%` }}
            transition={{ duration: 0.5 }}
            style={{
              height: '100%',
              background: PURPLE,
              borderRadius: '2px',
            }}
          />
        </div>
        <div style={{ fontSize: '9px', fontFamily: MONO, color: PURPLE }}>
          {(status.phi_spiral_consensus * 100).toFixed(0)}%
        </div>
      </div>

      {/* Expanded Section: Node Details */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            style={{
              marginTop: '10px',
              paddingTop: '10px',
              borderTop: `1px solid ${stateColor}33`,
            }}
          >
            <div style={{ fontSize: '9px', opacity: 0.7, marginBottom: '8px' }}>
              NODE STATUS
            </div>

            {status.nodes.map((node, idx) => (
              <div
                key={node.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '6px',
                  marginBottom: '4px',
                  background: 'rgba(0,0,0,0.2)',
                  borderRadius: '4px',
                  fontSize: '8px',
                }}
              >
                <div
                  style={{
                    width: '6px',
                    height: '6px',
                    borderRadius: '50%',
                    background: getNodeStatusColor(node.status),
                  }}
                />
                <div style={{ flex: 1, fontFamily: MONO }}>
                  {node.id}
                </div>
                <div style={{ opacity: 0.7 }}>
                  {(node.load * 100).toFixed(0)}% load
                </div>
                <div
                  style={{
                    padding: '2px 4px',
                    borderRadius: '3px',
                    background: `${getCircuitBreakerColor(node.circuit_breaker_state)}22`,
                    color: getCircuitBreakerColor(node.circuit_breaker_state),
                    fontSize: '7px',
                    fontFamily: MONO,
                  }}
                >
                  {node.circuit_breaker_state}
                </div>
              </div>
            ))}

            {/* Auto-Recovery Status */}
            <div
              style={{
                marginTop: '8px',
                padding: '6px',
                background: status.auto_recovery_active ? 'rgba(0,255,136,0.1)' : 'rgba(255,255,255,0.05)',
                borderRadius: '6px',
                border: status.auto_recovery_active ? '1px solid rgba(0,255,136,0.3)' : '1px solid rgba(255,255,255,0.1)',
                fontSize: '8px',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
              }}
            >
              <span style={{ fontSize: '10px' }}>
                {status.auto_recovery_active ? '⟳' : '●'}
              </span>
              <span style={{ opacity: 0.8 }}>
                Auto-Recovery: {status.auto_recovery_active ? 'ACTIVE' : 'STANDBY'}
              </span>
            </div>

            {/* Leader Info */}
            {status.leader_id && (
              <div style={{ marginTop: '6px', fontSize: '7px', opacity: 0.5 }}>
                Leader: <span style={{ fontFamily: MONO, color: GOLD }}>{status.leader_id}</span>
              </div>
            )}

            {/* Last Recovery */}
            {status.last_recovery_time && (
              <div style={{ marginTop: '4px', fontSize: '7px', opacity: 0.5 }}>
                Last Recovery: {formatTimestamp(status.last_recovery_time)}
              </div>
            )}

            {/* Version */}
            <div
              style={{
                marginTop: '8px',
                fontSize: '6px',
                opacity: 0.4,
                textAlign: 'center',
              }}
            >
              φ² + 1/φ² = 3 | TRINITY
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
