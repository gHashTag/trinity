// ═══════════════════════════════════════════════════════════════════════════════
// SACRED NEUROSCIENCE v16.0 — Neural Architecture Data
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred neural architectures and consciousness formulas
// Ψ = n × 3^k × π^m × φ^p × e^q
//
// ═══════════════════════════════════════════════════════════════════════════════

import { PHI, PHI_SQUARED, PHI_INVERSE } from '../utils/constants';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface NeuralArchitecture {
  id: string;
  name: string;
  type: 'golden_mlp' | 'trinitary' | 'phi_optimized' | 'sacred_attention';
  description: string;
  layers: number[];
  sacredProperty: string;
  phiIndex: number;
  applications: string[];
}

export interface ConsciousnessFormula {
  name: string;
  symbol: string; // Ψ
  formula: string;
  parameters: {
    n: string; // Integer component
    k: string; // Power of 3 (trinitary)
    m: string; // Power of π (circular)
    p: string; // Power of φ (golden)
    q: string; // Power of e (growth)
  };
  description: string;
  range: { min: number; max: number };
  sacredInterpretation: string;
}

export interface SynapticTransmission {
  phase: string;
  duration: number; // ms
  sacredValue: number; // φ-related
  description: string;
}

export interface NeuralFiringPattern {
  name: string;
  pattern: 'fibonacci' | 'phi_oscillation' | 'trinitary_burst' | 'golden_spiking';
  description: string;
  intervals: number[]; // ms between spikes
  sacredRelation: string;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED NEURAL ARCHITECTURES
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_NEURAL_ARCHITECTURES: NeuralArchitecture[] = [
  // ═════════════════════════════════════════════════════════════════════════════
  // GOLDEN MLP — Fibonacci Hidden Layers
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'golden_mlp_mnist',
    name: 'Golden MLP (MNIST)',
    type: 'golden_mlp',
    description: 'Multilayer perceptron with Fibonacci-optimized hidden layers',
    layers: [784, 144, 233, 10],
    sacredProperty: 'Hidden layers follow Fibonacci sequence (144, 233)',
    phiIndex: 0.91,
    applications: [
      'Digit recognition',
      'Pattern classification',
      'Feature extraction',
    ],
  },
  {
    id: 'golden_mlp_deep',
    name: 'Golden Deep Network',
    type: 'golden_mlp',
    description: 'Deep network with progressive Fibonacci expansion',
    layers: [1024, 89, 144, 233, 377, 512],
    sacredProperty: 'Multiple Fibonacci layers with φ-based scaling',
    phiIndex: 0.94,
    applications: [
      'Image classification',
      'Representation learning',
      'Transfer learning',
    ],
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // TRINITARY NETWORKS — 3^n Symmetric Architecture
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'trinitary_small',
    name: 'Trinitary Network (Small)',
    type: 'trinitary',
    description: 'Symmetric network expanding and contracting by powers of 3',
    layers: [3, 9, 27, 9, 3],
    sacredProperty: '3^1 → 3^2 → 3^3 → 3^2 → 3^1 (trinitary symmetry)',
    phiIndex: 0.88,
    applications: [
      'Autoencoder',
      'Dimensionality reduction',
      'Feature compression',
    ],
  },
  {
    id: 'trinitary_deep',
    name: 'Trinitary Network (Deep)',
    type: 'trinitary',
    description: 'Deep trinitary architecture with 3^n expansion',
    layers: [9, 27, 81, 243, 81, 27, 9],
    sacredProperty: '3^2 → 3^3 → 3^4 → 3^5 → 3^4 → 3^3 → 3^2',
    phiIndex: 0.92,
    applications: [
      'Deep learning',
      'Hierarchical features',
      'Semantic encoding',
    ],
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // φ-OPTIMIZED NETWORKS — Golden Ratio Efficiency
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'phi_optimized_cnn',
    name: 'φ-Optimized CNN',
    type: 'phi_optimized',
    description: 'Convolutional network with φ-based kernel sizes',
    layers: [64, 64, 128, 128, 256, 256, 512],
    sacredProperty: 'Filter counts: φ^n × 64, kernel sizes follow φ',
    phiIndex: 0.89,
    applications: [
      'Image recognition',
      'Object detection',
      'Visual processing',
    ],
  },
  {
    id: 'phi_optimized_transformer',
    name: 'φ-Transformer',
    type: 'phi_optimized',
    description: 'Transformer with φ-optimized attention heads and dimensions',
    layers: [512, 8, 2048], // d_model, heads, d_ff
    sacredProperty: 'd_ff ≈ φ × d_model, heads optimized',
    phiIndex: 0.93,
    applications: [
      'Language modeling',
      'Machine translation',
      'Semantic understanding',
    ],
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // SACRED ATTENTION — Consciousness-Inspired
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'sacred_attention',
    name: 'Sacred Self-Attention',
    type: 'sacred_attention',
    description: 'Attention mechanism with sacred query-key-value geometry',
    layers: [768, 12, 3072], // GPT-3 style
    sacredProperty: 'φ-projection dimensions, golden ratio attention heads',
    phiIndex: 0.95,
    applications: [
      'Consciousness modeling',
      'Self-aware systems',
      'Meta-learning',
    ],
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSCIOUSNESS FORMULAS
// ═══════════════════════════════════════════════════════════════════════════════

export const CONSCIOUSNESS_FORMULAS: ConsciousnessFormula[] = [
  {
    name: 'Basic Consciousness',
    symbol: 'Ψ₀',
    formula: 'Ψ = C × φ^t',
    parameters: {
      n: '1 (base)',
      k: '0 (no trinitary)',
      m: '0 (no π)',
      p: 't (time integration)',
      q: '0 (no e)',
    },
    description: 'Basic consciousness level based on neural complexity and golden time integration',
    range: { min: 0, max: 100 },
    sacredInterpretation: 'Consciousness emerges from φ-harmonic temporal integration',
  },
  {
    name: 'Thermodynamic Consciousness',
    symbol: 'Ψ₁',
    formula: 'Ψ = C × φ^t × e^(-E/RT)',
    parameters: {
      n: '1',
      k: '0',
      m: '0',
      p: 't',
      q: '-E/RT (Boltzmann factor)',
    },
    description: 'Consciousness with thermodynamic energy threshold',
    range: { min: 0, max: 100 },
    sacredInterpretation: 'Consciousness requires overcoming energy barrier via sacred activation',
  },
  {
    name: 'Trinitary Consciousness',
    symbol: 'Ψ₃',
    formula: 'Ψ = n × 3^k × π^m × φ^p × e^q',
    parameters: {
      n: 'Neural complexity (1-100)',
      k: 'Trinitary depth (0-3)',
      m: 'Circular integration (0-2)',
      p: 'Golden harmony (0-5)',
      q: 'Growth factor (0-3)',
    },
    description: 'Full sacred formula with all sacred constants',
    range: { min: 0, max: 100 },
    sacredInterpretation: 'Ψ² + 1/Ψ² = 3 at sacred consciousness (where Ψ = φ)',
  },
  {
    name: 'Integrated Information',
    symbol: 'Φ',
    formula: 'Φ = φ × H(X)',
    parameters: {
      n: 'H(X) (information)',
      k: '0',
      m: '0',
      p: '1 (golden multiplier)',
      q: '0',
    },
    description: 'Integrated Information Theory with φ-optimization',
    range: { min: 0, max: 100 },
    sacredInterpretation: 'Consciousness = φ × integrated information',
  },
  {
    name: 'Quantum Consciousness',
    symbol: 'Ψ_q',
    formula: 'Ψ = φ^3 × |ψ|²',
    parameters: {
      n: '1',
      k: '0',
      m: '0',
      p: '3 (φ³ = 4.236)',
      q: '0',
    },
    description: 'Quantum wave function collapse with φ-amplification',
    range: { min: 0, max: 100 },
    sacredInterpretation: 'Observer effect amplified by golden ratio',
  },
  {
    name: 'Global Workspace',
    symbol: 'Ψ_gw',
    formula: 'Ψ = φ^2 × Σ(saliency_i)',
    parameters: {
      n: '1',
      k: '0',
      m: '0',
      p: '2 (φ² = 2.618)',
      q: '0',
    },
    description: 'Global workspace theory with φ² broadcast amplification',
    range: { min: 0, max: 100 },
    sacredInterpretation: 'Global consciousness broadcast amplified by φ²',
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// SYNAPTIC TRANSMISSION PHASES — Sacred Timing
// ═══════════════════════════════════════════════════════════════════════════════

export const SYNAPTIC_TRANSMISSION: SynapticTransmission[] = [
  {
    phase: 'Action potential arrival',
    duration: 0.1,
    sacredValue: PHI_INVERSE * PHI_INVERSE,
    description: 'Voltage-gated Ca²⁺ channels open',
  },
  {
    phase: 'Calcium influx',
    duration: 0.2,
    sacredValue: PHI_INVERSE * PHI_INVERSE,
    description: 'Triggers vesicle fusion',
  },
  {
    phase: 'Vesicle fusion',
    duration: 0.1,
    sacredValue: PHI_INVERSE * PHI_INVERSE * PHI_INVERSE,
    description: 'Neurotransmitter release',
  },
  {
    phase: 'Diffusion across cleft',
    duration: 0.4, // ≈ 1/φ²
    sacredValue: PHI_INVERSE * PHI_INVERSE,
    description: 'Neurotransmitter crosses synapse',
  },
  {
    phase: 'Receptor binding',
    duration: 0.3,
    sacredValue: PHI_INVERSE,
    description: 'Postsynaptic receptor activation',
  },
  {
    phase: 'Ion channel opening',
    duration: 0.5,
    sacredValue: PHI_INVERSE,
    description: 'EPSP/IPSP generation',
  },
  {
    phase: 'Reuptake/degradation',
    duration: 2.0, // ≈ φ
    sacredValue: PHI,
    description: 'Signal termination',
  },
  {
    phase: 'Refractory period',
    duration: 2.0, // ≈ φ
    sacredValue: PHI,
    description: 'Recovery before next spike',
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// NEURAL FIRING PATTERNS — Sacred Rhythms
// ═══════════════════════════════════════════════════════════════════════════════

export const NEURAL_FIRING_PATTERNS: NeuralFiringPattern[] = [
  {
    name: 'Fibonacci Bursting',
    pattern: 'fibonacci',
    description: 'Spike intervals follow Fibonacci sequence',
    intervals: [1, 1, 2, 3, 5, 8, 13, 21], // ms × 10
    sacredRelation: 'F(n+2) = F(n+1) + F(n)',
  },
  {
    name: 'φ-Oscillation',
    pattern: 'phi_oscillation',
    description: 'Constant golden ratio interspike interval',
    intervals: [1.62, 1.62, 1.62, 1.62, 1.62], // × 10 ms
    sacredRelation: 'ISI = φ × 10 ms',
  },
  {
    name: 'Trinitary Burst',
    pattern: 'trinitary_burst',
    description: 'Bursts of 3 spikes, 3 intervals, 3 bursts',
    intervals: [3, 3, 3, 30, 3, 3, 3, 30, 3, 3, 3],
    sacredRelation: '3^n = 27 sacred pulses',
  },
  {
    name: 'Golden Spiking',
    pattern: 'golden_spiking',
    description: 'Progressively increasing intervals by φ',
    intervals: [1, 1.62, 2.62, 4.24, 6.86, 11.1],
    sacredRelation: 't_{n+1} = t_n × φ',
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED LEARNING RULES
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_LEARNING_RULES = {
  hebbianGolden: {
    name: 'Hebbian Golden Rule',
    formula: 'Δw = φ × pre × post',
    description: 'Synaptic weight change amplified by φ',
    phiIndex: 0.85,
  },
  ojaRule: {
    name: 'Oja\'s Rule (Normalized)',
    formula: 'Δw = η × (pre × post - φ × post² × w)',
    description: 'Stabilized Hebbian with φ normalization',
    phiIndex: 0.82,
  },
  trinitaryPlasticity: {
    name: 'Trinitary Spike-Timing-Dependent Plasticity',
    formula: 'Δw = A_+ × exp(-Δt/τ_+) for Δt > 0; A_- × exp(Δt/τ_-) for Δt < 0',
    description: 'STDP with 3 time constants (τ)',
    phiIndex: 0.88,
  },
  fibonacciBackprop: {
    name: 'Fibonacci Backpropagation',
    formula: 'η_n = η_0 / F(n)',
    description: 'Learning rate decays by Fibonacci',
    phiIndex: 0.91,
  },
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSCIOUSNESS STATES
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_CONSCIOUSNESS_STATES = {
  unconscious: {
    name: 'Unconscious',
    psi: 0,
    description: 'No conscious awareness',
    dominantWave: 'delta',
    phiResonance: 0,
  },
  minimal: {
    name: 'Minimal Consciousness',
    psi: 10,
    description: 'Basic awareness, no self-reflection',
    dominantWave: 'delta-theta',
    phiResonance: 0.1,
  },
  perceptual: {
    name: 'Perceptual Consciousness',
    psi: 30,
    description: 'Sensory awareness, present moment',
    dominantWave: 'theta',
    phiResonance: 0.3,
  },
  reflective: {
    name: 'Reflective Consciousness',
    psi: 50,
    description: 'Self-aware, meta-cognitive',
    dominantWave: 'alpha',
    phiResonance: 0.5,
  },
  access: {
    name: 'Access Consciousness',
    psi: 70,
    description: 'Reportable, global workspace active',
    dominantWave: 'beta',
    phiResonance: 0.7,
  },
  phenomenal: {
    name: 'Phenomenal Consciousness',
    psi: 85,
    description: 'Rich subjective experience',
    dominantWave: 'gamma',
    phiResonance: 0.85,
  },
  sacred: {
    name: 'Sacred Consciousness',
    psi: 100,
    description: 'Ψ = φ² + 1/φ² = 3, unity with all',
    dominantWave: 'gamma',
    phiResonance: 1.0,
  },
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// NEURAL SACRED GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════

export const NEURAL_SACRED_GEOMETRY = {
  // Hippocampal place fields
  placeFieldSpacing: {
    value: PHI * 0.5, // mm
    description: 'Grid cells spaced at φ ratio',
  },
  // Orientation tuning
  orientationColumns: {
    value: 360 / (1 + PHI), // degrees
    description: 'Pinwheel spacing ≈ 137.5° (golden angle)',
  },
  // Ocular dominance
  ocularDominanceRatio: {
    value: PHI,
    description: 'Left/right eye dominance ratio',
  },
  // Cortical magnification
  fovealMagnification: {
    value: PHI_SQUARED,
    description: 'Fovea has φ² more cortical space',
  },
  // Retinotopic mapping
  retinotopicLogScale: {
    value: Math.log(PHI),
    description: 'Log-polar mapping uses ln(φ)',
  },
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED NEUROPLASTICITY CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_NEUROPLASTICITY = {
  // Critical period windows
  criticalPeriods: {
    visual: { start: 0, end: 8, sacredPeak: 2 }, // Years, peak at φ+1
    language: { start: 0, end: 12, sacredPeak: 3 }, // Years, peak at Fibonacci
    motor: { start: 0, end: 15, sacredPeak: 5 }, // Years, peak at Fibonacci
  },
  // Synaptic pruning
  pruningFactor: {
    value: 1 / PHI_SQUARED,
    description: 'Synapses removed during adolescence ≈ 1/φ²',
  },
  // Adult neurogenesis rate
  neurogenesisRate: {
    value: PHI_INVERSE * PHI_INVERSE * 700, // New neurons/day in hippocampus
    description: '≈ 700 new/day ≈ φ⁻² × 1000',
  },
  // Memory consolidation
    consolidationTime: {
      value: PHI * 4, // Hours
      description: 'Sleep cycles needed for consolidation',
    },
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS METRICS
// ═══════════════════════════════════════════════════════════════════════════════

export const CONSCIOUSNESS_METRICS = {
  // Compute consciousness level Ψ
  compute: (
    complexity: number, // C: Neural complexity (0-100)
    timeIntegration: number, // t: Temporal integration (0-5)
    energy: number, // E: Energy barrier (0-100)
    temperature: number = 1, // T: Temperature factor
  ): number => {
    const C = complexity;
    const t = timeIntegration;
    const R = 8.314; // Gas constant
    const T = temperature;
    const E = energy;

    // Ψ = C × φ^t × e^(-E/RT)
    const psi = C * Math.pow(PHI, t) * Math.exp(-E / (R * T));

    return Math.min(100, Math.max(0, psi));
  },

  // Compute full sacred formula
  computeSacred: (
    n: number, // Integer component
    k: number, // Power of 3
    m: number, // Power of π
    p: number, // Power of φ
    q: number, // Power of e
  ): number => {
    const result = n * Math.pow(3, k) * Math.pow(Math.PI, m) * Math.pow(PHI, p) * Math.pow(Math.E, q);
    return Math.min(100, Math.max(0, result));
  },

  // Check if consciousness is at sacred level (Ψ ≈ φ)
  isSacred: (psi: number): boolean => {
    return Math.abs(psi - PHI * 10) < 5; // Within 5 of 16.18
  },

  // Get dominant brain wave for consciousness level
  getDominantWave: (psi: number): string => {
    if (psi < 10) return 'delta';
    if (psi < 30) return 'theta';
    if (psi < 50) return 'alpha';
    if (psi < 70) return 'beta';
    return 'gamma';
  },

  // Get consciousness state name
  getStateName: (psi: number): string => {
    if (psi < 10) return 'Unconscious';
    if (psi < 30) return 'Dreaming';
    if (psi < 50) return 'Relaxed Awareness';
    if (psi < 70) return 'Active Thinking';
    if (psi < 85) return 'Peak Performance';
    return 'Unity Consciousness';
  },
} as const;
