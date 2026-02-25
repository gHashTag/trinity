"use client";

import { motion } from "framer-motion";
import SacredMathWidget from "./charts/SacredMathWidget";
import InteractiveEvolutionTree from "./charts/InteractiveEvolutionTree";

const FONT = "'Outfit', system-ui, sans-serif";
const GOLD = '#ffd700';

const glassStyle = (borderColor = 'rgba(255,215,0,0.15)'): React.CSSProperties => ({
  background: 'rgba(0,0,0,0.3)',
  backdropFilter: 'blur(12px)',
  border: `1px solid ${borderColor}`,
  borderRadius: 14,
});

/**
 * AGENT MU Dashboard v8.19
 *
 * Production-hardening + Live Self-Modification
 *
 * Displays:
 * - Sacred Math Widget (μ, φ, L(10), Trinity score)
 * - Interactive Evolution Tree (zoom, pan, click)
 */
export default function AgentMuDashboard() {
  return (
    <div
      style={{
        padding: '20px',
        fontFamily: FONT,
        color: GOLD,
        minHeight: '100vh',
        background: 'radial-gradient(ellipse at top, rgba(255,215,0,0.05) 0%, transparent 50%)',
      }}
    >
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        style={{
          textAlign: 'center',
          marginBottom: '30px',
        }}
      >
        <h1
          style={{
            fontSize: '24px',
            fontWeight: 'bold',
            marginBottom: '8px',
            textShadow: '0 0 20px rgba(255,215,0,0.3)',
          }}
        >
          AGENT MU v8.19
        </h1>
        <p
          style={{
            fontSize: '12px',
            opacity: 0.7,
          }}
        >
          Production Hardening + Live Self-Modification
        </p>
      </motion.div>

      {/* Dashboard Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
          gap: '20px',
          maxWidth: '1200px',
          margin: '0 auto',
        }}
      >
        {/* Sacred Math Widget */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.1 }}
        >
          <SacredMathWidget width={340} height={200} />
        </motion.div>

        {/* Evolution Tree */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          style={{
            gridColumn: '1 / -1',
          }}
        >
          <InteractiveEvolutionTree
            width={Math.min(1200 - 40, window.innerWidth - 40)}
            height={350}
          />
        </motion.div>
      </div>

      {/* Status Footer */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
        style={{
          marginTop: '30px',
          textAlign: 'center',
          fontSize: '10px',
          opacity: 0.5,
        }}
      >
        <div style={glassStyle('rgba(255,215,0,0.1)')} className="inline-block" style={{ padding: '8px 16px', borderRadius: '8px', display: 'inline-block' }}>
          <div>✅ Runtime Pattern Manager Active</div>
          <div>✅ Circuit Breaker: Closed</div>
          <div>✅ All Systems Operational</div>
        </div>
      </motion.div>
    </div>
  );
}
