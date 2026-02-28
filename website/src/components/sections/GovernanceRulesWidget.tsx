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
  border: '1px solid rgba(255, 215, 0, 0.2)',
  borderRadius: '8px',
};

interface SacredRule {
  id: string;
  name: string;
  description: string;
  compliance: number;
  penalty_threshold: number;
  violations: number;
  status: 'compliant' | 'warning' | 'critical';
}

interface GovernanceData {
  rules: SacredRule[];
  overall_compliance: number;
  total_penalties: number;
  last_audit: number;
}

export default function GovernanceRulesWidget() {
  const { t } = useI18n();
  const [expanded, setExpanded] = useState(true);
  const [governanceData, setGovernanceData] = useState<GovernanceData | null>(null);
  const [lastUpdate, setLastUpdate] = useState<number>(Date.now());

  // Simulate real-time governance data
  useEffect(() => {
    const generateGovernanceData = (): GovernanceData => {
      const rules: SacredRule[] = [
        {
          id: '1',
          name: 'Trinity Identity',
          description: 'φ² + 1/φ² = 3 must hold in all calculations',
          compliance: 0.98 + Math.random() * 0.02,
          penalty_threshold: 0.95,
          violations: Math.floor(Math.random() * 3),
          status: 'compliant',
        },
        {
          id: '2',
          name: 'Sacred Mu',
          description: 'μ = φ^(-4) per self-fix operation',
          compliance: 0.92 + Math.random() * 0.08,
          penalty_threshold: 0.90,
          violations: Math.floor(Math.random() * 5),
          status: 'compliant',
        },
        {
          id: '3',
          name: 'Golden Ratio',
          description: 'All sacred constants must fit V = n × 3^k × π^m × φ^p × e^q',
          compliance: 0.85 + Math.random() * 0.15,
          penalty_threshold: 0.85,
          violations: Math.floor(Math.random() * 8),
          status: Math.random() > 0.5 ? 'compliant' : 'warning',
        },
        {
          id: '4',
          name: 'Ternary Balance',
          description: 'Trit distribution must maintain {-1, 0, +1} equilibrium',
          compliance: 0.88 + Math.random() * 0.12,
          penalty_threshold: 0.80,
          violations: Math.floor(Math.random() * 6),
          status: 'compliant',
        },
        {
          id: '5',
          name: 'Lucas Alignment',
          description: 'Lucas numbers must govern generation cycles',
          compliance: 0.94 + Math.random() * 0.06,
          penalty_threshold: 0.90,
          violations: Math.floor(Math.random() * 4),
          status: 'compliant',
        },
      ];

      const overall_compliance = rules.reduce((sum, r) => sum + r.compliance, 0) / rules.length;
      const total_penalties = rules.reduce((sum, r) => sum + r.violations, 0);

      return {
        rules,
        overall_compliance,
        total_penalties,
        last_audit: Date.now(),
      };
    };

    setGovernanceData(generateGovernanceData());

    // Update every 5 seconds
    const interval = setInterval(() => {
      setGovernanceData(generateGovernanceData());
      setLastUpdate(Date.now());
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status: SacredRule['status']) => {
    switch (status) {
      case 'compliant': return '#00e599';
      case 'warning': return GOLDEN;
      case 'critical': return '#ff6b6b';
      default: return 'rgba(255, 255, 255, 0.3)';
    }
  };

  const getComplianceColor = (compliance: number, threshold: number) => {
    if (compliance >= threshold + 0.05) return CYAN;
    if (compliance >= threshold) return GOLDEN;
    return '#ff6b6b';
  };

  return (
    <Section id="governance-rules-widget">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        style={{
          ...GLASS_STYLE,
          padding: '1.5rem',
          maxWidth: '800px',
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
              color: GOLDEN,
              fontSize: '1rem',
              fontWeight: 600,
              fontFamily: 'Outfit, sans-serif',
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              margin: 0,
            }}
          >
            Governance Rules
          </h3>
          <motion.span
            animate={{ rotate: expanded ? 180 : 0 }}
            transition={{ duration: 0.2 }}
            style={{ color: GOLDEN, fontSize: '0.8rem' }}
          >
            ▼
          </motion.span>
        </div>

        {/* Collapsible Content */}
        {expanded && governanceData && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            transition={{ duration: 0.3 }}
          >
            {/* Overall Compliance */}
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
                  Compliance
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: GOLDEN,
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {(governanceData.overall_compliance * 100).toFixed(1)}%
                </div>
              </div>

              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(255, 107, 107, 0.1)',
                  border: '1px solid rgba(255, 107, 107, 0.3)',
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
                  Penalties
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: '#ff6b6b',
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {governanceData.total_penalties}
                </div>
              </div>

              <div
                style={{
                  padding: '1rem',
                  background: 'rgba(0, 229, 153, 0.1)',
                  border: '1px solid rgba(0, 229, 153, 0.3)',
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
                  Rules
                </div>
                <div
                  style={{
                    fontSize: '1.5rem',
                    fontWeight: 700,
                    color: '#00e599',
                    fontFamily: 'JetBrains Mono, monospace',
                  }}
                >
                  {governanceData.rules.length}
                </div>
              </div>
            </div>

            {/* Rules List */}
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
                Sacred Rules
              </div>

              {governanceData.rules.map((rule, index) => (
                <motion.div
                  key={rule.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.1 }}
                  style={{
                    padding: '1rem',
                    marginBottom: '0.75rem',
                    background: 'rgba(0, 0, 0, 0.2)',
                    border: `1px solid ${getStatusColor(rule.status)}33`,
                    borderRadius: '8px',
                  }}
                >
                  {/* Rule Header */}
                  <div
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '0.5rem',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <div
                        style={{
                          width: '8px',
                          height: '8px',
                          borderRadius: '50%',
                          background: getStatusColor(rule.status),
                          boxShadow: `0 0 10px ${getStatusColor(rule.status)}`,
                        }}
                      />
                      <div
                        style={{
                          fontSize: '0.95rem',
                          color: '#fff',
                          fontFamily: 'Outfit, sans-serif',
                          fontWeight: 600,
                        }}
                      >
                        {rule.name}
                      </div>
                    </div>

                    <div
                      style={{
                    fontSize: '0.8rem',
                    padding: '2px 8px',
                    borderRadius: '4px',
                    background: `${getStatusColor(rule.status)}22`,
                    color: getStatusColor(rule.status),
                    fontFamily: 'JetBrains Mono, monospace',
                    fontWeight: 600,
                    textTransform: 'uppercase',
                  }}
                >
                  {rule.status}
                </div>
              </div>

              {/* Description */}
              <div
                style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.6)',
                  marginBottom: '0.75rem',
                  fontFamily: 'Outfit, sans-serif',
                  lineHeight: 1.4,
                }}
              >
                {rule.description}
              </div>

              {/* Compliance Bar */}
              <div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    marginBottom: '0.25rem',
                  }}
                >
                  <span
                    style={{
                      fontSize: '0.7rem',
                      color: 'rgba(255, 255, 255, 0.4)',
                      fontFamily: 'JetBrains Mono, monospace',
                    }}
                  >
                    Compliance
                  </span>
                  <span
                    style={{
                      fontSize: '0.7rem',
                      color: getComplianceColor(rule.compliance, rule.penalty_threshold),
                      fontFamily: 'JetBrains Mono, monospace',
                      fontWeight: 600,
                    }}
                  >
                    {(rule.compliance * 100).toFixed(1)}%
                  </span>
                </div>
                <div
                  style={{
                    width: '100%',
                    height: '6px',
                    background: 'rgba(255, 255, 255, 0.1)',
                    borderRadius: '3px',
                    overflow: 'hidden',
                  }}
                >
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${rule.compliance * 100}%` }}
                    transition={{ duration: 1 }}
                    style={{
                      height: '100%',
                      background: getComplianceColor(rule.compliance, rule.penalty_threshold),
                    }}
                  />
                </div>
              </div>

              {/* Violations */}
              <div
                style={{
                  marginTop: '0.5rem',
                  fontSize: '0.7rem',
                  color: 'rgba(255, 255, 255, 0.4)',
                  fontFamily: 'JetBrains Mono, monospace',
                  display: 'flex',
                  justifyContent: 'space-between',
                }}
              >
                <span>Violations: {rule.violations}</span>
                <span>Threshold: {(rule.penalty_threshold * 100).toFixed(0)}%</span>
              </div>
            </motion.div>
              ))}
            </div>

            {/* Last Update */}
            <div
              style={{
                marginTop: '1rem',
                fontSize: '0.7rem',
                color: 'rgba(255, 255, 255, 0.3)',
                fontFamily: 'JetBrains Mono, monospace',
                textAlign: 'center',
              }}
            >
              Last audit: {new Date(lastUpdate).toLocaleTimeString()}
            </div>
          </motion.div>
        )}
      </motion.div>
    </Section>
  );
}
