"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

interface AgentCard {
  coptic: string;
  name: string;
  domain: string;
  desc: string;
  capabilities?: string[];
  files?: string[];
  url?: string;
}

export default function FeaturesSection() {
  const { t } = useI18n();

  const agents: AgentCard[] = [
    { coptic: 'Ⲁⲁ', name: 'Alpha', domain: 'Core bootstrapping', desc: 'Agent lifecycle, initialization, and core orchestration' },
    { coptic: 'Ⲃⲃ', name: 'Beta', domain: 'Benchmarking', desc: 'Metrics collection, performance tracking, and evaluation' },
    { coptic: 'Ⲅⲅ', name: 'Gamma', domain: 'Git operations', desc: 'Version control, commit management, and repository sync' },
    { coptic: 'Ⲇⲇ', name: 'Delta', domain: 'Database', desc: 'Persistence layer, state management, and storage' },
    { coptic: 'Ⲉⲉ', name: 'Epsilon', domain: 'Error handling', desc: 'Recovery strategies, exception handling, and resilience' },
    { coptic: 'Ⲋⲋ', name: 'Zeta', domain: 'Zig compilation', desc: 'VIBEE pipeline, code generation, and build system' },
    { coptic: 'Ⲍⲍ', name: 'Eta', domain: 'Event orchestration', desc: 'Hooks system, event routing, and triggers' },
    { coptic: 'Ⲏⲏ', name: 'Theta', domain: 'Testing', desc: 'Validation, test suites, and quality assurance' },
    { coptic: 'Ⲑⲑ', name: 'Iota', domain: 'I18n', desc: 'Localization, translations, and multi-language support' },
    { coptic: 'Ⲓⲓ', name: 'Kappa', domain: 'Knowledge base', desc: 'VSA operations, semantic search, and retrieval' },
    { coptic: 'Ⲕⲕ', name: 'Lambda', domain: 'Learning', desc: 'Experience persistence, adaptation, and memory' },
    { coptic: 'Ⲗⲗ', name: 'Mu', domain: 'Memory', desc: 'Allocators, memory management, and optimization' },
    { coptic: 'Ⲙⲙ', name: 'Nu', domain: 'Notifications', desc: 'Telegram integration, alerts, and messaging' },
    { coptic: 'Ⲛⲛ', name: 'Xi', domain: 'MCP integration', desc: 'Model Context Protocol, server connections' },
    { coptic: 'Ⲝⲝ', name: 'Omicron', domain: 'Optimization', desc: 'ASHA+PBT, hyperparameter tuning, and evolution' },
    { coptic: 'Ⲟⲟ', name: 'Pi', domain: 'Pipeline', desc: 'Orchestration, workflows, and task execution' },
    { coptic: 'Ⲡⲡ', name: 'Koppa', domain: 'Compression', desc: 'GF16 format, ternary encoding, and storage' },
    { coptic: 'Ⲣⲣ', name: 'Rho', domain: 'Railway cloud', desc: 'Deployment, containers, and cloud management' },
    { coptic: 'Ⲥⲥ', name: 'Sigma', domain: 'Swarm intelligence', desc: 'Multi-agent coordination and emergent behavior' },
    { coptic: 'Ⲧⲧ', name: 'Tau', domain: 'Ternary VM', desc: 'Bytecode execution, stack operations, and runtime' },
    { coptic: 'Ⲩⲩ', name: 'Upsilon', domain: 'UI components', desc: 'Queen interface, TUI, and user experience' },
    { coptic: 'Ⲫⲫ', name: 'Phi', domain: 'Math', desc: 'φ² + 1/φ² = 3, golden ratio computations' },
    { coptic: 'Ⲭⲭ', name: 'Khi', domain: 'CLI commands', desc: '310+ commands, unified interface, and tooling' },
    { coptic: 'Ⲯⲯ', name: 'Psi', domain: 'Privacy', desc: 'PII detection, data protection, and security' },
    { coptic: 'Ⲱⲱ', name: 'Omega', domain: 'Orchestration', desc: 'Final assembly, integration, and coordination' },
    { coptic: 'Ϣⲳ', name: 'Sampi', domain: 'SACred intelligence', desc: 'Physics engine, sacred constants, and math' },
    { coptic: 'Ϥϥ', name: 'Sho', domain: 'FPGA synthesis', desc: 'Verilog generation, hardware compilation' },
  ];

  return (
    <section id="features" aria-labelledby="features-heading" style={{
      padding: 'clamp(3rem, 8vw, 6rem) 1rem',
      maxWidth: '1400px',
      margin: '0 auto',
    }}>
      {/* Problem Statement */}
      <motion.div
        className="fade"
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.7 }}
        style={{
          maxWidth: '800px',
          margin: '0 auto 4rem',
          textAlign: 'center',
        }}
      >
        <h2
          id="features-heading"
          style={{
            fontSize: 'clamp(1.5rem, 4vw, 2.25rem)',
            marginBottom: '1.5rem',
            color: 'var(--text)',
          }}
        >
          {t.features?.problemTitle || 'The Forgetting Problem'}
        </h2>
        <p style={{
          fontSize: 'clamp(1rem, 2.5vw, 1.15rem)',
          color: 'var(--text-secondary)',
          lineHeight: 1.7,
          fontStyle: 'italic',
        }}>
          {t.features?.problem || '"AI agents forget everything after each session. They repeat mistakes. They can\'t learn from each other."'}
        </p>
      </motion.div>

      {/* Solution Statement */}
      <motion.div
        className="fade"
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.7, delay: 0.2 }}
        style={{
          maxWidth: '800px',
          margin: '0 auto 5rem',
          textAlign: 'center',
          padding: '2rem',
          background: 'rgba(0,255,136,0.05)',
          borderRadius: '12px',
          border: '1px solid rgba(0,255,136,0.2)',
        }}
      >
        <p style={{
          fontSize: 'clamp(1rem, 2.5vw, 1.15rem)',
          color: 'var(--accent)',
          lineHeight: 1.7,
          fontWeight: 500,
        }}>
          {t.features?.solution || '"Trinity\'s 27 specialized agents (one per Coptic letter) share permanent memory via .trinity/experience/. Every mistake saved. Every lesson learned."'}
        </p>
      </motion.div>

      {/* 27 Agent Cards Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
        gap: '1.5rem',
      }}>
        {agents.map((agent, i) => (
          <motion.a
            key={i}
            href={agent.url || 'https://github.com/gHashTag/trinity'}
            target="_blank"
            rel="noopener noreferrer"
            className="fade"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.4, delay: (i % 9) * 0.05 }}
            whileHover={{ y: -4, boxShadow: '0 8px 24px rgba(0,255,136,0.15)' }}
            style={{
              display: 'block',
              padding: '1.5rem',
              background: 'rgba(0,0,0,0.3)',
              borderRadius: '12px',
              border: '1px solid rgba(0,255,136,0.15)',
              textDecoration: 'none',
              color: 'inherit',
              transition: 'all 0.3s ease',
            }}
          >
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '1rem',
              marginBottom: '1rem',
            }}>
              <span style={{
                fontSize: '2rem',
                lineHeight: 1,
              }}>{agent.coptic}</span>
              <div>
                <div style={{
                  fontSize: '1.1rem',
                  fontWeight: 600,
                  color: 'var(--text)',
                }}>{agent.name}</div>
                <div style={{
                  fontSize: '0.75rem',
                  color: 'var(--accent)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.05em',
                }}>{agent.domain}</div>
              </div>
            </div>
            <p style={{
              fontSize: '0.9rem',
              color: 'var(--text-secondary)',
              lineHeight: 1.5,
              margin: 0,
            }}>
              {agent.desc}
            </p>
          </motion.a>
        ))}
      </div>
    </section>
  );
}
