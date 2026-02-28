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
  border: '1px solid rgba(170, 102, 255, 0.2)',
  borderRadius: '8px',
};

interface FitnessPoint {
  generation: number;
  fitness: number;
  sacred_alignment: number;
}

interface EvolutionData {
  generation: number;
  fitness_history: FitnessPoint[];
  current_fitness: number;
  sacred_alignment: number;
  mutation_count: number;
  survival_rate: number;
}

export default function EvolutionMonitorWidget() {
  const { t } = useI18n();
  const [expanded, setExpanded] = useState(true);
  const [evolutionData, setEvolutionData] = useState<EvolutionData | null>(null);
  const [lastUpdate, setLastUpdate] = useState<number>(Date.now());

  // Simulate real-time evolution data
  useEffect(() => {
    const generateEvolutionData = (): EvolutionData => {
      const generation = Math.floor(Math.random() * 50) + 100;
      const fitness_history: FitnessPoint[] = [];

      for (let i = Math.max(0, generation - 20); i <= generation; i++) {
        fitness_history.push({
          generation: i,
          fitness: 0.5 + (i / generation) * 0.4 + Math.random() * 0.1,
          sacred_alignment: 0.6 + (i / generation) * 0.3 + Math.random() * 0.1,
        });
      }

      const current_fitness = fitness_history[fitness_history.length - 1].fitness;
      const sacred_alignment = fitness_history[fitness_history.length - 1].sacred_alignment;
      const mutation_count = Math.floor(Math.random() * 100) + 500;
      const survival_rate = 0.85 + Math.random() * 0.14;

      return {
        generation,
        fitness_history,
        current_fitness,
        sacred_alignment,
        mutation_count,
        survival_rate,
      };
    };

    setEvolutionData(generateEvolutionData());

    // Update every 3 seconds
    const interval = setInterval(() => {
      setEvolutionData(generateEvolutionData());
      setLastUpdate(Date.now());
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  const renderMiniGraph = (history: FitnessPoint[]) => {
    const maxGen = Math.max(...history.map(p => p.generation));
    const minGen = Math.min(...history.map(p => p.generation));
    const maxFit = Math.max(...history.map(p => p.fitness));
    const minFit = Math.min(...history.map(p => p.fitness));

    const points = history.map(p => {
      const x = ((p.generation - minGen) / (maxGen - minGen || 1)) * 100;
      const y = 100 - ((p.fitness - minFit) / (maxFit - minFit || 1)) * 100;
      return `${x},${y}`;
    }).join(' ');

    return (
      <div style={{ position: 'relative', width: '100%', height: '80px' }}>
        <svg
          width="100%"
          height="100%"
          style={{ background: 'rgba(0, 0, 0, 0.2)', borderRadius: '4px' }}
        >
          <polyline
            points={points}
            fill="none"
            stroke={CYAN}
            strokeWidth="2"
            vectorEffect="non-scaling-stroke"
          />
          {history.map((p, i) => {
            const x = ((p.generation - minGen) / (maxGen - minGen || 1)) * 100;
            const y = 100 - ((p.fitness - minFit) / (maxFit - minFit || 1)) * 100;
            return (
              <circle
                key={i}
                cx={`${x}%`}
                cy={`${y}%`}
                r="3"
                fill={GOLDEN}
                opacity={i === history.length - 1 ? 1 : 0.5}
              />
            );
          })}
        </svg>
      </div>
    );
  };

  return (
    <Section id="evolution-monitor-widget">
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
              color: PURPLE,
              fontSize: '1rem',
              fontWeight: 600,
              fontFamily: 'Outfit, sans-serif',
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              margin: 0,
            }}
          >
            Evolution Monitor
          </h3>
          <motion.span
            animate={{ rotate: expanded ? 180 : 0 }}
            transition={{ duration: 0.2 }}
            style={{ color: PURPLE, fontSize: '0.8rem' }}
          >
            ▼
          </motion.span>
        </div>

        {/* Collapsible Content */}
        {expanded && evolutionData && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            transition={{ duration: 0.3 }}
          >
            {/* Generation Counter */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(3, 1fr)',
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
                  Generation
                </div>
                <motion.div
                  key={evolutionData.generation}
                  initial={{ scale: 1.2 }}
                  animate={{ scale: 1 }}
                  style={{
                    fontSize: '1.8rem',
                    fontWeight: 700,
                    color: PURPLE,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  #{evolutionData.generation}
                </motion.div>
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
                  Fitness
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: CYAN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {(evolutionData.current_fitness * 100).toFixed(1)}%
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
                  Sacred Align
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: GOLDEN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {(evolutionData.sacred_alignment * 100).toFixed(1)}%
                </div>
              </div>
            </div>

            {/* Fitness Graph */}
            <div style={{ marginBottom: '1.5rem' }}>
              <div
                style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.5)',
                  marginBottom: '0.5rem',
                  fontFamily: 'Outfit, sans-serif',
                  textTransform: 'uppercase',
                  letterSpacing: '0.05em',
                }}
              >
                Fitness History (Last 20 Generations)
              </div>
              {renderMiniGraph(evolutionData.fitness_history)}
            </div>

            {/* Evolution Stats */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(2, 1fr)',
                gap: '1rem',
              }}
            >
              <div
                style={{
                  padding: '0.75rem',
                  background: 'rgba(0, 0, 0, 0.2)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '6px',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.4)',
                    marginBottom: '0.25rem',
                    fontFamily: 'Outfit, sans-serif',
                  }}
                >
                  Mutations
                </div>
                <div
                  style={{
                    fontSize: '1.1rem',
                    fontWeight: 700,
                    color: CYAN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {evolutionData.mutation_count}
                </div>
              </div>

              <div
                style={{
                  padding: '0.75rem',
                  background: 'rgba(0, 0, 0, 0.2)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '6px',
                }}
              >
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.4)',
                    marginBottom: '0.25rem',
                    fontFamily: 'Outfit, sans-serif',
                  }}
                >
                  Survival Rate
                </div>
                <div
                  style={{
                    fontSize: '1.1rem',
                    fontWeight: 700,
                    color: GOLDEN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {(evolutionData.survival_rate * 100).toFixed(1)}%
                </div>
              </div>
            </div>

            {/* Progress Bars */}
            <div style={{ marginTop: '1rem' }}>
              <div style={{ marginBottom: '0.5rem' }}>
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.25rem',
                    fontFamily: 'Outfit, sans-serif',
                  }}
                >
                  Fitness
                </div>
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
                    animate={{ width: `${evolutionData.current_fitness * 100}%` }}
                    transition={{ duration: 1 }}
                    style={{
                      height: '100%',
                      background: `linear-gradient(90deg, ${PURPLE}, ${CYAN})`,
                    }}
                  />
                </div>
              </div>

              <div>
                <div
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255, 255, 255, 0.5)',
                    marginBottom: '0.25rem',
                    fontFamily: 'Outfit, sans-serif',
                  }}
                >
                  Sacred Alignment
                </div>
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
                    animate={{ width: `${evolutionData.sacred_alignment * 100}%` }}
                    transition={{ duration: 1 }}
                    style={{
                      height: '100%',
                      background: `linear-gradient(90deg, ${CYAN}, ${GOLDEN})`,
                    }}
                  />
                </div>
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
