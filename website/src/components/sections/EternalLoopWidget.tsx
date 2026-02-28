"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';

// Style constants
const GOLDEN = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';

const GLASS_STYLE: React.CSSProperties = {
  background: 'rgba(255, 255, 255, 0.05)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  border: '1px solid rgba(0, 204, 255, 0.2)',
  borderRadius: '8px',
};

interface DaemonAction {
  id: string;
  timestamp: number;
  action: string;
  status: 'success' | 'warning' | 'error';
  cycle_number: number;
}

interface EternalLoopData {
  daemon_status: 'running' | 'paused' | 'stopped';
  cycle_count: number;
  last_action: DaemonAction | null;
  actions_per_minute: number;
  uptime_seconds: number;
  memory_mb: number;
}

export default function EternalLoopWidget() {
  const { t } = useI18n();
  const [expanded, setExpanded] = useState(true);
  const [eternalLoopData, setEternalLoopData] = useState<EternalLoopData | null>(null);
  const [recentActions, setRecentActions] = useState<DaemonAction[]>([]);
  const [lastUpdate, setLastUpdate] = useState<number>(Date.now());

  // Simulate real-time eternal loop data
  useEffect(() => {
    const actions = [
      'Self-fix completed',
      'Generation evolved',
      'Sacred proof verified',
      'Governance check passed',
      'Swarm coordination',
      'Fitness optimized',
      'Mutation applied',
      'Alignment improved',
    ];

    const generateEternalLoopData = (): EternalLoopData => {
      const daemon_status: Array<'running' | 'paused' | 'stopped'> = ['running', 'running', 'running', 'paused', 'stopped'];
      const status = daemon_status[Math.floor(Math.random() * daemon_status.length)];

      const lastAction: DaemonAction = {
        id: Date.now().toString(),
        timestamp: Date.now(),
        action: actions[Math.floor(Math.random() * actions.length)],
        status: Math.random() > 0.1 ? 'success' : Math.random() > 0.5 ? 'warning' : 'error',
        cycle_number: Math.floor(Math.random() * 1000) + 100,
      };

      return {
        daemon_status: status,
        cycle_count: Math.floor(Math.random() * 50000) + 100000,
        last_action: lastAction,
        actions_per_minute: 20 + Math.floor(Math.random() * 30),
        uptime_seconds: Math.floor(Math.random() * 86400) + 3600,
        memory_mb: 100 + Math.floor(Math.random() * 200),
      };
    };

    setEternalLoopData(generateEternalLoopData());

    // Update actions every second
    const interval = setInterval(() => {
      const newData = generateEternalLoopData();

      if (newData.last_action) {
        setRecentActions(prev => [newData.last_action!, ...prev].slice(0, 10));
      }

      setEternalLoopData(newData);
      setLastUpdate(Date.now());
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'running':
      case 'success':
        return '#00e599';
      case 'paused':
      case 'warning':
        return GOLDEN;
      case 'stopped':
      case 'error':
        return '#ff6b6b';
      default:
        return 'rgba(255, 255, 255, 0.3)';
    }
  };

  const formatUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours}h ${minutes}m ${secs}s`;
  };

  return (
    <Section id="eternal-loop-widget">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        style={{
          ...GLASS_STYLE,
          padding: '1.5rem',
          maxWidth: '700px',
          margin: '0 auto',
        }}
      >
        {/* Header */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: expanded ? '1.5rem' : '0',
            cursor: 'pointer',
          }}
          onClick={() => setExpanded(!expanded)}
        >
          <h3
            style={{
              color: CYAN,
              fontSize: '1rem',
              fontWeight: 600,
              fontFamily: 'Outfit, sans-serif',
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              margin: 0,
            }}
          >
            Eternal Loop
          </h3>
          <motion.span
            animate={{ rotate: expanded ? 180 : 0 }}
            transition={{ duration: 0.2 }}
            style={{ color: CYAN, fontSize: '0.8rem' }}
          >
            ▼
          </motion.span>
        </div>

        {/* Collapsible Content */}
        {expanded && eternalLoopData && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            transition={{ duration: 0.3 }}
          >
            {/* Daemon Status */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '1rem',
                padding: '1rem',
                background: `rgba(${getStatusColor(eternalLoopData.daemon_status) === '#00e599' ? '0, 229, 153' : getStatusColor(eternalLoopData.daemon_status) === '#ffd700' ? '255, 215, 0' : '255, 107, 107'}, 0.1)`,
                border: `1px solid ${getStatusColor(eternalLoopData.daemon_status)}44`,
                borderRadius: '8px',
                marginBottom: '1.5rem',
              }}
            >
              {/* Animated Pulse */}
              <motion.div
                animate={{
                  scale: [1, 1.2, 1],
                  opacity: [1, 0.7, 1],
                }}
                transition={{
                  duration: 2,
                  repeat: Infinity,
                  ease: 'easeInOut',
                }}
                style={{
                  width: '12px',
                  height: '12px',
                  borderRadius: '50%',
                  background: getStatusColor(eternalLoopData.daemon_status),
                  boxShadow: `0 0 20px ${getStatusColor(eternalLoopData.daemon_status)}`,
                }}
              />

              <div>
                <div
                  style={{
                    fontSize: '1.2rem',
                    fontWeight: 700,
                    color: getStatusColor(eternalLoopData.daemon_status),
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                  }}
                >
                  {eternalLoopData.daemon_status}
                </div>
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  Daemon Process
                </div>
              </div>
            </div>

            {/* Stats Grid */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(2, 1fr)',
                gap: '1rem',
                marginBottom: '1.5rem',
              }}
            >
              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(170, 102, 255, 0.1)',
                  border: '1px solid rgba(170, 102, 255, 0.3)',
                  borderRadius: '8px',
                  textAlign: 'center',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.5rem',
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                  }}
                >
                  Cycles
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: PURPLE,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {eternalLoopData.cycle_count.toLocaleString()}
                </div>
              </div>

              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(0, 204, 255, 0.1)',
                  border: '1px solid rgba(0, 204, 255, 0.3)',
                  borderRadius: '8px',
                  textAlign: 'center',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.5rem',
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                  }}
                >
                  Actions/Min
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: CYAN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {eternalLoopData.actions_per_minute}
                </div>
              </div>

              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(255, 215, 0, 0.1)',
                  border: '1px solid rgba(255, 215, 0, 0.3)',
                  borderRadius: '8px',
                  textAlign: 'center',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.5rem',
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                  }}
                >
                  Uptime
                </div>
                <div
                  style={{
                    fontSize: '1rem',
                    fontWeight: 700,
                    color: GOLDEN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {formatUptime(eternalLoopData.uptime_seconds)}
                </div>
              </div>

              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '8px',
                  textAlign: 'center',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.5rem',
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                  }}
                >
                  Memory
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: '#fff',
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {eternalLoopData.memory_mb} MB
                </div>
              </div>
            </div>

            {/* Last Action */}
            {eternalLoopData.last_action && (
              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(0, 0, 0, 0.3)',
                  border: `1px solid ${getStatusColor(eternalLoopData.last_action.status)}44`,
                  borderRadius: '8px',
                  marginBottom: '1rem',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.4)',
                    marginBottom: '0.5rem',
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                  }}
                >
                  Last Action
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                  }}
                >
                  <div
                    style={{
                      fontSize: '0.95rem',
                      color: '#fff',
                      fontFamily: 'Outfit, sans-serif',
                      fontWeight: 600,
                    }}
                  >
                    {eternalLoopData.last_action.action}
                  </div>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.5rem',
                    }}
                  >
                    <span
                      style={{
                        fontSize: '0.8rem',
                        padding: '2px 8px',
                        borderRadius: '4px',
                        background: `${getStatusColor(eternalLoopData.last_action.status)}22`,
                        color: getStatusColor(eternalLoopData.last_action.status),
                        fontFamily: 'JetBrains Mono, monospace',
                        fontWeight: 600,
                        textTransform: 'uppercase',
                      }}
                    >
                      {eternalLoopData.last_action.status}
                    </span>
                    <span
                      style={{
                        fontSize: '0.75rem',
                        color: 'rgba(255, 255, 255, 0.4)',
                        fontFamily: 'JetBrains Mono, monospace',
                      }}
                    >
                      #{eternalLoopData.last_action.cycle_number}
                    </span>
                  </div>
                </div>
              </div>
            )}

            {/* Recent Actions */}
            {recentActions.length > 0 && (
              <div>
                <div
                  style={{
                    fontSize: '0.75rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.75rem',
                    fontFamily: 'Outfit, sans-serif',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                  }}
                >
                  Recent Actions
                </div>

                <div
                  style={{
                    maxHeight: '200px',
                    overflowY: 'auto',
                    paddingRight: '0.5rem',
                  }}
                >
                  {recentActions.map((action, index) => (
                    <motion.div
                      key={action.id}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: index * 0.05 }}
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        padding: '0.5rem 0.75rem',
                        marginBottom: '0.5rem',
                        background: 'rgba(0, 0, 0, 0.2)',
                        borderLeft: `2px solid ${getStatusColor(action.status)}`,
                        borderRadius: '4px',
                        fontSize: '0.75rem',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <span style={{ color: 'rgba(255, 255, 255, 0.8)', fontFamily: 'Outfit, sans-serif' }}>
                          {action.action}
                        </span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <span style={{ color: getStatusColor(action.status), fontFamily: 'JetBrains Mono, monospace', fontSize: '0.7rem' }}>
                          {action.status.toUpperCase()}
                        </span>
                        <span style={{ color: 'rgba(255, 255, 255, 0.3)', fontFamily: 'JetBrains Mono, monospace' }}>
                          #{action.cycle_number}
                        </span>
                      </div>
                    </motion.div>
                  ))}
                </div>
              </div>
            )}

            {/* Last Update */}
            <div
              style={{
                marginTop: '0.75rem',
                fontSize: '0.7rem',
                color: 'rgba(255, 255, 255, 0.3)',
                fontFamily: 'JetBrains Mono, monospace',
                textAlign: 'center',
              }}
            >
              Last update: {new Date(lastUpdate).toLocaleTimeString()}
            </div>
          </motion.div>
        )}
      </motion.div>
    </Section>
  );
}
