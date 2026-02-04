"use client";
import { useState } from 'react'
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

// GPU pricing data ($/hour)
const GPU_OPTIONS = [
  { id: 'a100', name: 'NVIDIA A100 (80GB)', price: 2.0, tflops: 312 },
  { id: 'h100', name: 'NVIDIA H100 (80GB)', price: 3.5, tflops: 989 },
  { id: 'rtx4090', name: 'RTX 4090 (24GB)', price: 0.8, tflops: 82 },
  { id: 'l40s', name: 'NVIDIA L40S (48GB)', price: 1.5, tflops: 362 },
]

// Mining mode calculations
const MINING_EFFICIENCY = 578.8 // Trinity efficiency multiplier

export default function CalculatorSection() {
  const { t } = useI18n()
  const c = t.calculator
  const [nodes, setNodes] = useState(100)
  const [selectedGPU, setSelectedGPU] = useState(GPU_OPTIONS[0])
  const [mode, setMode] = useState<'inference' | 'mining'>('inference')

  const hoursPerMonth = 24 * 30
  const binaryCost = nodes * hoursPerMonth * selectedGPU.price
  const trinityCost = binaryCost / MINING_EFFICIENCY
  const savings = binaryCost - trinityCost
  
  // Mining mode calculations
  const miningRevenuePerTflop = 0.05 // $/hour per TFLOP (estimated)
  const binaryMiningRevenue = nodes * selectedGPU.tflops * miningRevenuePerTflop * hoursPerMonth
  const trinityMiningRevenue = binaryMiningRevenue * 8 // 8x efficiency from ternary
  const miningProfit = trinityMiningRevenue - trinityCost

  return (
    <Section id="calculator">
      <div className="radial-glow" style={{ opacity: 0.15 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: c?.title }} />
      
      <div className="premium-card fade" style={{ width: '100%', maxWidth: '900px', margin: '4rem auto', padding: 'clamp(1rem, 5vw, 3rem)' }}>
        
        {/* Mode Toggle */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', marginBottom: '2rem' }}>
          <button
            onClick={() => setMode('inference')}
            style={{
              padding: '0.6rem 1.5rem',
              background: mode === 'inference' ? 'var(--accent)' : 'transparent',
              border: '1px solid var(--accent)',
              borderRadius: '4px',
              color: mode === 'inference' ? '#000' : 'var(--accent)',
              cursor: 'pointer',
              fontSize: '0.85rem',
              fontWeight: 500,
              transition: 'all 0.2s'
            }}
          >
            {c?.modeInference || 'AI Inference'}
          </button>
          <button
            onClick={() => setMode('mining')}
            style={{
              padding: '0.6rem 1.5rem',
              background: mode === 'mining' ? 'var(--accent)' : 'transparent',
              border: '1px solid var(--accent)',
              borderRadius: '4px',
              color: mode === 'mining' ? '#000' : 'var(--accent)',
              cursor: 'pointer',
              fontSize: '0.85rem',
              fontWeight: 500,
              transition: 'all 0.2s'
            }}
          >
            {c?.modeMining || 'GPU Mining'}
          </button>
        </div>

        {/* GPU Selection */}
        <div style={{ marginBottom: '2rem' }}>
          <div style={{ fontSize: '0.8rem', color: 'var(--muted)', marginBottom: '0.75rem', textTransform: 'uppercase' }}>
            {c?.selectGPU || 'Select GPU Type'}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.5rem' }}>
            {GPU_OPTIONS.map((gpu) => (
              <motion.button
                key={gpu.id}
                onClick={() => setSelectedGPU(gpu)}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                style={{
                  padding: '0.75rem',
                  background: selectedGPU.id === gpu.id ? 'rgba(218,165,32,0.15)' : 'rgba(255,255,255,0.02)',
                  border: `1px solid ${selectedGPU.id === gpu.id ? 'var(--accent)' : 'var(--border)'}`,
                  borderRadius: '6px',
                  cursor: 'pointer',
                  textAlign: 'left',
                  transition: 'all 0.2s'
                }}
              >
                <div style={{ fontSize: '0.85rem', color: 'var(--text)', fontWeight: 500 }}>{gpu.name}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--muted)', marginTop: '0.25rem' }}>
                  ${gpu.price}/hr | {gpu.tflops} TFLOPS
                </div>
              </motion.button>
            ))}
          </div>
        </div>

        {/* Node Slider */}
        <div style={{ marginBottom: 'clamp(1.5rem, 4vw, 3rem)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem', fontSize: 'clamp(0.8rem, 2.5vw, 1rem)', fontWeight: 500 }}>
            <span>{c?.nodes}</span>
            <span style={{ color: 'var(--accent)' }}>{nodes}</span>
          </div>
          <input 
            type="range" min="1" max="1000" value={nodes} 
            onChange={(e) => setNodes(parseInt(e.target.value))}
            style={{ width: '100%', accentColor: 'var(--accent)', cursor: 'pointer' }}
          />
        </div>

        {/* Results Grid */}
        <div className="grid" style={{ marginTop: 0, gap: 'clamp(0.8rem, 2vw, 1.5rem)' }}>
          <motion.div 
            style={{ padding: 'clamp(1rem, 3vw, 1.5rem)', border: '1px solid var(--border)', borderRadius: '8px' }}
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
          >
            <div style={{ fontSize: '0.7rem', color: 'var(--muted)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>
              {mode === 'inference' ? (c?.current || 'Binary Cost') : 'Standard Mining Revenue'}
            </div>
            <div style={{ fontSize: 'clamp(1.2rem, 4vw, 1.5rem)', color: '#ff453a' }}>
              ${(mode === 'inference' ? binaryCost : binaryMiningRevenue).toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
          </motion.div>
          
          <motion.div 
            style={{ padding: 'clamp(1rem, 3vw, 1.5rem)', border: '1px solid var(--border)', borderRadius: '8px' }}
            initial={{ opacity: 0, x: 20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
          >
            <div style={{ fontSize: '0.7rem', color: 'var(--muted)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>
              {mode === 'inference' ? (c?.withTrinity || 'With TRINITY') : 'TRINITY Mining Revenue'}
            </div>
            <div style={{ fontSize: 'clamp(1.2rem, 4vw, 1.5rem)', color: 'var(--accent)' }}>
              ${(mode === 'inference' ? trinityCost : trinityMiningRevenue).toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
          </motion.div>
          
          <motion.div 
            style={{ 
              gridColumn: '1 / -1', 
              padding: 'clamp(1.5rem, 5vw, 2rem)', 
              background: 'rgba(255, 255, 255, 0.02)', 
              border: '1px solid var(--accent)', 
              borderRadius: '8px', 
              textAlign: 'center' 
            }}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
          >
            <div style={{ fontSize: '0.8rem', color: 'var(--accent)', marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
              {mode === 'inference' ? (c?.savings || 'Monthly Savings') : 'Monthly Profit'}
            </div>
            <div style={{ fontSize: 'clamp(2rem, 10vw, 3rem)', fontWeight: 500, color: 'var(--text)' }}>
              ${(mode === 'inference' ? savings : miningProfit).toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--muted)', marginTop: '0.5rem' }}>
              {mode === 'inference' 
                ? `${((savings / binaryCost) * 100).toFixed(1)}% reduction with ternary computing`
                : `${((trinityMiningRevenue / binaryMiningRevenue) * 100 - 100).toFixed(0)}% more efficient than binary`
              }
            </div>
          </motion.div>
        </div>

        {/* Efficiency Note */}
        <div style={{ marginTop: '1.5rem', textAlign: 'center', fontSize: '0.75rem', color: 'var(--muted)', opacity: 0.7 }}>
          Based on TRINITY Hyper-Singularity V5.0 efficiency factor: {MINING_EFFICIENCY}x
        </div>
      </div>
    </Section>
  )
}
