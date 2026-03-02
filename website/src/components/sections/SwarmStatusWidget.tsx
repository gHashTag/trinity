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

interface Agent {
  id: string;
  name: string;
  phi_score: number;
  status: 'active' | 'idle' | 'processing';
  tasks_completed: number;
}

interface SwarmData {
  agents: Agent[];
  harmony_percentage: number;
  total_phi: number;
  avg_phi: number;
}

export default function SwarmStatusWidget() {
  const { t } = useI18n();
  const [expanded, setExpanded] = useState(true);
  const [swarmData, setSwarmData] = useState<SwarmData | null>(null);
  const [lastUpdate, setLastUpdate] = useState<number>(Date.now());

  // Simulate real-time swarm data
  useEffect(() => {
    const generateSwarmData = (): SwarmData => {
      const agents: Agent[] = [
        { id: '1', name: 'Ralph', phi_score: 0.95, status: 'active', tasks_completed: 1247 },
        { id: '2', name: 'Vibee', phi_score: 0.88, status: 'processing', tasks_completed: 892 },
        { id: '3', name: 'Mu-Agent', phi_score: 0.92, status: 'active', tasks_completed: 1056 },
        { id: '4', name: 'Firebird', phi_score: 0.85, status: 'idle', tasks_completed: 734 },
        { id: '5', name: 'TVC-Node', phi_score: 0.90, status: 'active', tasks_completed: 945 },
        { id: '6', name: 'Sage', phi_score: 0.87, status: 'processing', tasks_completed: 812 },
      ];

      const total_phi = agents.reduce((sum, a) => sum + a.phi_score, 0);
      const avg_phi = total_phi / agents.length;
      const harmony_percentage = (avg_phi * 100);

      return { agents, harmony_percentage, total_phi, avg_phi };
    };

    setSwarmData(generateSwarmData());

    // Update every 2 seconds
    const interval = setInterval(() => {
      setSwarmData(generateSwarmData());
      setLastUpdate(Date.now());
    }, 2000);

    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status: Agent['status']) => {
    switch (status) {
      case 'active': return '#00e599';
      case 'processing': return GOLDEN;
      case 'idle': return 'rgba(255, 255, 255, 0.3)';
      default: return 'rgba(255, 255, 255, 0.3)';
    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 0.9) return CYAN;
    if (score >= 0.8) return GOLDEN;
    return PURPLE;
  };

  return (
    <Section id="swarm-status-widget">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        style={{
          ...GLASS_STYLE,
          padding: '1.5rem',
          maxWidth: 'min(700px, 90vw)',
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
            Swarm Status
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
        {expanded && swarmData && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            transition={{ duration: 0.3 }}
          >
            {/* Harmony Overview */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))',
                gap: '1rem',
                marginBottom: '1.5rem',
              }}
            >
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
                  Agents
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: CYAN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {swarmData.agents.length}
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
                  Harmony
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: GOLDEN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {swarmData.harmony_percentage.toFixed(1)}%
                </div>
              </div>

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
                  Avg φ
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: PURPLE,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {swarmData.avg_phi.toFixed(3)}
                </div>
              </div>
            </div>

            {/* Agents List */}
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
                Active Agents
              </div>

              {swarmData.agents.map((agent, index) => (
                <motion.div
                  key={agent.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.1 }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '0.75rem',
                    marginBottom: '0.5rem',
                    background: 'rgba(0, 0, 0, 0.2)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    borderRadius: '6px',
                  }}
                >
                  {/* Agent Name + Status */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <div
                      style={{
                        width: '8px',
                        height: '8px',
                        borderRadius: '50%',
                        background: getStatusColor(agent.status),
                        boxShadow: `0 0 10px ${getStatusColor(agent.status)}`,
                      }}
                    />
                    <div>
                      <div
                        style={{
                          fontSize: '0.9rem',
                          color: '#fff',
                          fontFamily: 'Outfit, sans-serif',
                          fontWeight: 600,
                        }}
                      >
                        {agent.name}
                      </div>
                      <div
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255, 255, 255, 0.4)',
                          fontFamily: 'JetBrains Mono, monospace',
                          textTransform: 'uppercase',
                        }}
                      >
                        {agent.status}
                      </div>
                    </div>
                  </div>

                  {/* φ Score + Tasks */}
                  <div style={{ textAlign: 'right' }}>
                    <div
                      style={{
                        fontSize: '1rem',
                        color: getScoreColor(agent.phi_score),
                        fontFamily: 'JetBrains Mono, monospace',
                        fontWeight: 700,
                      }}
                    >
                      φ {agent.phi_score.toFixed(2)}
                    </div>
                    <div
                      style={{
                        fontSize: '0.7rem',
                        color: 'rgba(255, 255, 255, 0.4)',
                        fontFamily: 'JetBrains Mono, monospace',
                      }}
                    >
                      {agent.tasks_completed} tasks
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>

            {/* Harmony Bar */}
            <div style={{ marginTop: '1rem' }}>
              <div
                style={{
                  width: '100%',
                  height: '8px',
                  background: 'rgba(255, 255, 255, 0.1)',
                  borderRadius: '4px',
                  overflow: 'hidden',
                }}
              >
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${swarmData.harmony_percentage}%` }}
                  transition={{ duration: 1 }}
                  style={{
                    height: '100%',
                    background: `linear-gradient(90deg, ${PURPLE}, ${GOLDEN}, ${CYAN})`,
                  }}
                />
              </div>
            </div>

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
