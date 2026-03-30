"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

interface ComparisonRow {
  capability: string;
  trinity: string;
  claudeCode: string;
  cursor: string;
  devin: string;
}

export default function ComparisonSection() {
  const { t } = useI18n();

  const comparisons: ComparisonRow[] = [
    {
      capability: 'Persistent memory',
      trinity: '✅ .trinity/experience',
      claudeCode: '❌ 200K context',
      cursor: '❌ session-only',
      devin: '❌ thinking log',
    },
    {
      capability: 'Learning from mistakes',
      trinity: '✅ .trinity/mistakes/',
      claudeCode: '❌',
      cursor: '❌',
      devin: '❌',
    },
    {
      capability: 'Multi-agent shared',
      trinity: '✅ 27 agents (Coptic)',
      claudeCode: '❌ single',
      cursor: '❌',
      devin: '❌',
    },
    {
      capability: 'Immutable trace',
      trinity: '✅ GitHub issues',
      claudeCode: '❌',
      cursor: '❌',
      devin: '❌ partial',
    },
    {
      capability: 'Evolution strategy',
      trinity: '✅ ASHA+PBT',
      claudeCode: '❌',
      cursor: '❌',
      devin: '❌',
    },
    {
      capability: 'Open source',
      trinity: '✅ MIT',
      claudeCode: '❌ proprietary',
      cursor: '❌ proprietary',
      devin: '❌ proprietary',
    },
    {
      capability: 'Self-hosting',
      trinity: '✅ full',
      claudeCode: '❌ cloud only',
      cursor: '❌ cloud only',
      devin: '❌ cloud only',
    },
  ];

  return (
    <section id="comparison" aria-labelledby="comparison-heading" style={{
      padding: 'clamp(3rem, 8vw, 6rem) 1rem',
      maxWidth: '1000px',
      margin: '0 auto',
    }}>
      <motion.h2
        id="comparison-heading"
        className="fade"
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6 }}
        style={{
          textAlign: 'center',
          fontSize: 'clamp(1.5rem, 4vw, 2.25rem)',
          marginBottom: '1rem',
          color: 'var(--text)',
        }}
      >
        {t.comparison?.title || 'How <span class="grad">Trinity</span> Compares'}
      </motion.h2>

      <motion.p
        className="fade"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6, delay: 0.2 }}
        style={{
          textAlign: 'center',
          color: 'var(--text-secondary)',
          marginBottom: '3rem',
          fontSize: 'clamp(0.9rem, 2vw, 1rem)',
        }}
      >
        {t.comparison?.subtitle || 'AI agent platforms compared. Trinity is the only one with persistent learning.'}
      </motion.p>

      {/* Comparison Table - Desktop */}
      <motion.div
        className="fade"
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.7, delay: 0.3 }}
        style={{
          overflowX: 'auto',
          borderRadius: '12px',
          border: '1px solid rgba(0,255,136,0.2)',
          background: 'rgba(0,0,0,0.3)',
        }}
      >
        <table style={{
          width: '100%',
          borderCollapse: 'collapse',
          minWidth: '600px',
        }}>
          <thead>
            <tr style={{ background: 'rgba(0,255,136,0.1)' }}>
              <th style={{
                padding: '1rem',
                textAlign: 'left',
                color: 'var(--text)',
                fontWeight: 600,
                borderBottom: '1px solid rgba(0,255,136,0.2)',
              }}>
                Capability
              </th>
              <th style={{
                padding: '1rem',
                textAlign: 'center',
                color: 'var(--accent)',
                fontWeight: 700,
                borderBottom: '1px solid rgba(0,255,136,0.2)',
                background: 'rgba(0,255,136,0.15)',
              }}>
                Trinity
              </th>
              <th style={{
                padding: '1rem',
                textAlign: 'center',
                color: 'var(--text-secondary)',
                fontWeight: 600,
                borderBottom: '1px solid rgba(255,255,255,0.1)',
              }}>
                Claude Code
              </th>
              <th style={{
                padding: '1rem',
                textAlign: 'center',
                color: 'var(--text-secondary)',
                fontWeight: 600,
                borderBottom: '1px solid rgba(255,255,255,0.1)',
              }}>
                Cursor
              </th>
              <th style={{
                padding: '1rem',
                textAlign: 'center',
                color: 'var(--text-secondary)',
                fontWeight: 600,
                borderBottom: '1px solid rgba(255,255,255,0.1)',
              }}>
                Devin
              </th>
            </tr>
          </thead>
          <tbody>
            {comparisons.map((row, i) => (
              <motion.tr
                key={i}
                initial={{ opacity: 0, x: -20 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: 0.5 + i * 0.05 }}
                style={{
                  borderBottom: i < comparisons.length - 1 ? '1px solid rgba(255,255,255,0.05)' : undefined,
                }}
              >
                <td style={{
                  padding: '1rem',
                  color: 'var(--text)',
                  fontWeight: 500,
                }}>
                  {row.capability}
                </td>
                <td style={{
                  padding: '1rem',
                  textAlign: 'center',
                  background: 'rgba(0,255,136,0.05)',
                  fontWeight: 600,
                  color: row.trinity.includes('✅') ? '#00ff88' : 'var(--text)',
                }}>
                  {row.trinity}
                </td>
                <td style={{
                  padding: '1rem',
                  textAlign: 'center',
                  color: 'var(--text-secondary)',
                }}>
                  {row.claudeCode}
                </td>
                <td style={{
                  padding: '1rem',
                  textAlign: 'center',
                  color: 'var(--text-secondary)',
                }}>
                  {row.cursor}
                </td>
                <td style={{
                  padding: '1rem',
                  textAlign: 'center',
                  color: 'var(--text-secondary)',
                }}>
                  {row.devin}
                </td>
              </motion.tr>
            ))}
          </tbody>
        </table>
      </motion.div>

      {/* Legend */}
      <motion.div
        className="fade"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6, delay: 1 }}
        style={{
          marginTop: '2rem',
          display: 'flex',
          gap: '2rem',
          justifyContent: 'center',
          flexWrap: 'wrap',
          fontSize: '0.875rem',
          color: 'var(--text-secondary)',
        }}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ color: '#00ff88' }}>✅</span> Supported
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span>❌</span> Not supported
        </span>
      </motion.div>
    </section>
  );
}
