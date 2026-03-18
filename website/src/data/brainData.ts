// ═══════════════════════════════════════════════════════════════════════════════
// SACRED NEUROSCIENCE v16.0 — Brain Data Layer
// ═══════════════════════════════════════════════════════════════════════════════
//
// Brain regions, neural connections, and sacred wave patterns
// φ-optimized architecture of the human mind
//
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948482;
const PHI_SQUARED = PHI * PHI;
const PHI_INVERSE = 1 / PHI;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface BrainRegion {
  id: string;
  name: string;
  abbreviation: string;
  position: [number, number, number]; // [x, y, z] in 3D space
  size: number; // Relative size for visualization
  type: 'cortical' | 'subcortical' | 'limbic' | 'brainstem' | 'cerebellar';
  sacredFunction: string;
  phiIndex: number; // 0-1, how φ-optimized this region is
  fibonacciIndex?: number; // Associated Fibonacci number
  trinitaryPower?: number; // Power of 3 (3^n) in sacred architecture
  color: string;
}

export interface NeuralConnection {
  id: string;
  source: string; // Brain region ID
  target: string; // Brain region ID
  strength: number; // Connection strength 0-1
  phiWeight: number; // φ-based weight
  sacredType: 'excitatory' | 'inhibitory' | 'modulatory';
  fiberCount: number; // Approximate axons
  delay: number; // Transmission delay (ms)
}

export interface BrainWave {
  name: string;
  symbol: string;
  frequency: { min: number; max: number; peak: number };
  sacredFreq: number; // φ-related frequency
  state: string;
  color: string;
  phiRelation: string;
  fibonacciRelated?: number;
}

export interface Neurotransmitter {
  name: string;
  abbreviation: string;
  type: 'excitatory' | 'inhibitory' | 'modulatory';
  sacredRatio: number; // φ-related concentration ratio
  function: string;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGIONS — Sacred Geometry Architecture
// ═══════════════════════════════════════════════════════════════════════════════

export const BRAIN_REGIONS: BrainRegion[] = [
  // ═════════════════════════════════════════════════════════════════════════════
  // LIMBIC SYSTEM — Emotional and Memory Core
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'hippocampus',
    name: 'Hippocampus',
    abbreviation: 'HP',
    position: [-2, 1, 0],
    size: 1.2,
    type: 'limbic',
    sacredFunction: 'Memory encoding via φ-spiral — place cells in golden ratio',
    phiIndex: 0.85,
    fibonacciIndex: 13,
    color: '#ffd700', // Gold
  },
  {
    id: 'amygdala',
    name: 'Amygdala',
    abbreviation: 'AM',
    position: [-2.5, -0.5, 0],
    size: 0.8,
    type: 'limbic',
    sacredFunction: 'Emotional processing — sacred fire of response',
    phiIndex: 0.78,
    color: '#ff6b6b', // Red
  },
  {
    id: 'hypothalamus',
    name: 'Hypothalamus',
    abbreviation: 'HY',
    position: [-0.5, -1, 0],
    size: 0.6,
    type: 'limbic',
    sacredFunction: 'Homeostasis regulation — φ-balanced hormones',
    phiIndex: 0.72,
    color: '#ff9f43',
  },
  {
    id: 'thalamus',
    name: 'Thalamus',
    abbreviation: 'TH',
    position: [0, 0.5, 0],
    size: 1.5,
    type: 'subcortical',
    sacredFunction: 'Sensory gateway — trinitary (3^n) gating of consciousness',
    phiIndex: 0.81,
    trinitaryPower: 1, // 3^1 = 3 relay nuclei
    color: '#a29bfe', // Purple
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // PREFRONTAL CORTEX — Executive Control
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'dlpfc',
    name: 'Dorsolateral Prefrontal Cortex',
    abbreviation: 'DLPFC',
    position: [0, 5, 2],
    size: 1.8,
    type: 'cortical',
    sacredFunction: 'Executive function — φ-efficiency optimization',
    phiIndex: 0.88,
    fibonacciIndex: 21,
    color: '#00cec9', // Cyan
  },
  {
    id: 'vmpfc',
    name: 'Ventromedial Prefrontal Cortex',
    abbreviation: 'VMPFC',
    position: [0, 4, 0],
    size: 1.4,
    type: 'cortical',
    sacredFunction: 'Decision making — value integration',
    phiIndex: 0.82,
    color: '#81ecec',
  },
  {
    id: 'acc',
    name: 'Anterior Cingulate Cortex',
    abbreviation: 'ACC',
    position: [0, 3.5, 0],
    size: 1.0,
    type: 'cortical',
    sacredFunction: 'Conflict monitoring — sacred balance',
    phiIndex: 0.79,
    color: '#74b9ff',
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // SENSORY CORTEX — Perception and Integration
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'v1',
    name: 'Primary Visual Cortex (V1)',
    abbreviation: 'V1',
    position: [3, 2, -2],
    size: 1.6,
    type: 'cortical',
    sacredFunction: 'Visual processing — Φ₁₇ₐ retinotopic sacred geometry',
    phiIndex: 0.91,
    fibonacciIndex: 34,
    color: '#d63031',
  },
  {
    id: 'a1',
    name: 'Primary Auditory Cortex',
    abbreviation: 'A1',
    position: [3.5, 1, 1],
    size: 1.3,
    type: 'cortical',
    sacredFunction: 'Auditory processing — tonotopic φ-scaling',
    phiIndex: 0.84,
    fibonacciIndex: 8,
    color: '#e17055',
  },
  {
    id: 's1',
    name: 'Primary Somatosensory Cortex',
    abbreviation: 'S1',
    position: [2, 2, 3],
    size: 1.5,
    type: 'cortical',
    sacredFunction: 'Touch processing — somatotopic homunculus',
    phiIndex: 0.83,
    color: '#00b894',
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // MOTOR CORTEX — Action and Movement
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'm1',
    name: 'Primary Motor Cortex',
    abbreviation: 'M1',
    position: [1.5, 3, 3.5],
    size: 1.4,
    type: 'cortical',
    sacredFunction: 'Motor execution — φ-optimized movement',
    phiIndex: 0.86,
    fibonacciIndex: 5,
    color: '#fd79a8',
  },
  {
    id: 'pmc',
    name: 'Premotor Cortex',
    abbreviation: 'PMC',
    position: [2, 3.5, 3],
    size: 1.2,
    type: 'cortical',
    sacredFunction: 'Motor planning — sequential preparation',
    phiIndex: 0.80,
    color: '#e84393',
  },
  {
    id: 'sma',
    name: 'Supplementary Motor Area',
    abbreviation: 'SMA',
    position: [0.5, 4, 2],
    size: 1.1,
    type: 'cortical',
    sacredFunction: 'Complex movements — bilateral coordination',
    phiIndex: 0.77,
    color: '#c8456f',
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // ASSOCIATION CORTEX — Higher Integration
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'angular_gyrus',
    name: 'Angular Gyrus',
    abbreviation: 'AG',
    position: [3.5, 3.5, -1],
    size: 1.3,
    type: 'cortical',
    sacredFunction: 'Language and math — cross-modal integration',
    phiIndex: 0.87,
    fibonacciIndex: 55,
    color: '#0984e3',
  },
  {
    id: 'supramarginal_gyrus',
    name: 'Supramarginal Gyrus',
    abbreviation: 'SMG',
    position: [3.8, 2.5, 0],
    size: 1.2,
    type: 'cortical',
    sacredFunction: 'Phonological processing — language sacred patterns',
    phiIndex: 0.82,
    color: '#6c5ce7',
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // BRAINSTEM — Basic Functions
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'raphe',
    name: 'Raphe Nuclei',
    abbreviation: 'RN',
    position: [-1, -3, 0],
    size: 0.5,
    type: 'brainstem',
    sacredFunction: 'Serotonin synthesis — mood regulation',
    phiIndex: 0.68,
    trinitaryPower: 0,
    color: '#fdcb6e',
  },
  {
    id: 'locus_coeruleus',
    name: 'Locus Coeruleus',
    abbreviation: 'LC',
    position: [-0.5, -2.5, 0],
    size: 0.3,
    type: 'brainstem',
    sacredFunction: 'Norepinephrine — arousal and attention',
    phiIndex: 0.65,
    color: '#ffeaa7',
  },
  {
    id: 'substantia_nigra',
    name: 'Substantia Nigra',
    abbreviation: 'SN',
    position: [1, -1.5, 0],
    size: 0.6,
    type: 'subcortical',
    sacredFunction: 'Dopamine synthesis — reward and movement',
    phiIndex: 0.71,
    color: '#55efc4',
  },
  {
    id: ' basal_ganglia',
    name: 'Basal Ganglia',
    abbreviation: 'BG',
    position: [1.5, 0, 0],
    size: 1.3,
    type: 'subcortical',
    sacredFunction: 'Action selection — trinitary direct/indirect/hyperdirect',
    phiIndex: 0.75,
    trinitaryPower: 1,
    color: '#81ecec',
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // CEREBELLUM — Precision and Timing
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'cerebellum',
    name: 'Cerebellum',
    abbreviation: 'CB',
    position: [0, -2, -3],
    size: 2.0,
    type: 'cerebellar',
    sacredFunction: 'Motor precision — φ-timing coordination',
    phiIndex: 0.89,
    fibonacciIndex: 89,
    color: '#a29bfe',
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // DEFAULT MODE NETWORK — Self-Referential
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'pcc',
    name: 'Posterior Cingulate Cortex',
    abbreviation: 'PCC',
    position: [1, 1, -1],
    size: 1.4,
    type: 'cortical',
    sacredFunction: 'Default mode hub — self-referential processing',
    phiIndex: 0.80,
    color: '#fab1a0',
  },
  {
    id: 'precuneus',
    name: 'Precuneus',
    abbreviation: 'PC',
    position: [1.5, 2, -2],
    size: 1.5,
    type: 'cortical',
    sacredFunction: 'Consciousness — internal awareness',
    phiIndex: 0.83,
    fibonacciIndex: 144,
    color: '#f39c12',
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// NEURAL CONNECTIONS — φ-Weighted Pathways
// ═══════════════════════════════════════════════════════════════════════════════

export const NEURAL_CONNECTIONS: NeuralConnection[] = [
  // ═════════════════════════════════════════════════════════════════════════════
  // HIPPOCAMPAL CONNECTIONS — Memory Circuit
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'hippo_thalamus',
    source: 'hippocampus',
    target: 'thalamus',
    strength: 0.85,
    phiWeight: PHI_INVERSE,
    sacredType: 'excitatory',
    fiberCount: 400000,
    delay: 5,
  },
  {
    id: 'hippo_entorhinal',
    source: 'hippocampus',
    target: 'ec', // Entorhinal cortex (implied)
    strength: 0.92,
    phiWeight: PHI,
    sacredType: 'excitatory',
    fiberCount: 600000,
    delay: 3,
  },
  {
    id: 'hippo_pfc',
    source: 'hippocampus',
    target: 'dlpfc',
    strength: 0.75,
    phiWeight: PHI_INVERSE * PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 100000,
    delay: 15,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // AMYGDALA CONNECTIONS — Emotional Circuit
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'amygdala_pfc',
    source: 'amygdala',
    target: 'vmpfc',
    strength: 0.88,
    phiWeight: PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 80000,
    delay: 10,
  },
  {
    id: 'amygdala_hippo',
    source: 'amygdala',
    target: 'hippocampus',
    strength: 0.90,
    phiWeight: 1,
    sacredType: 'modulatory',
    fiberCount: 50000,
    delay: 2,
  },
  {
    id: 'amygdala_hypothalamus',
    source: 'amygdala',
    target: 'hypothalamus',
    strength: 0.95,
    phiWeight: PHI,
    sacredType: 'excitatory',
    fiberCount: 2000,
    delay: 1,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // THALAMIC CONNECTIONS — Sensory Gateway
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'thalamus_v1',
    source: 'thalamus',
    target: 'v1',
    strength: 0.95,
    phiWeight: PHI,
    sacredType: 'excitatory',
    fiberCount: 5000000,
    delay: 3,
  },
  {
    id: 'thalamus_a1',
    source: 'thalamus',
    target: 'a1',
    strength: 0.93,
    phiWeight: PHI_SQUARED * PHI_INVERSE,
    sacredType: 'excitatory',
    fiberCount: 3000000,
    delay: 4,
  },
  {
    id: 'thalamus_s1',
    source: 'thalamus',
    target: 's1',
    strength: 0.94,
    phiWeight: PHI,
    sacredType: 'excitatory',
    fiberCount: 4000000,
    delay: 3,
  },
  {
    id: 'thalamus_pfc',
    source: 'thalamus',
    target: 'dlpfc',
    strength: 0.82,
    phiWeight: PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 500000,
    delay: 8,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // PREFRONTAL CONNECTIONS — Executive Control
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'dlpfc_acc',
    source: 'dlpfc',
    target: 'acc',
    strength: 0.90,
    phiWeight: PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 20000000,
    delay: 5,
  },
  {
    id: 'dlpfc_m1',
    source: 'dlpfc',
    target: 'm1',
    strength: 0.88,
    phiWeight: PHI_INVERSE * PHI_INVERSE,
    sacredType: 'excitatory',
    fiberCount: 15000000,
    delay: 8,
  },
  {
    id: 'vmpfc_amygdala',
    source: 'vmpfc',
    target: 'amygdala',
    strength: 0.85,
    phiWeight: PHI_INVERSE,
    sacredType: 'inhibitory',
    fiberCount: 100000,
    delay: 12,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // MOTOR PATHWAYS — Action Execution
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'pmc_m1',
    source: 'pmc',
    target: 'm1',
    strength: 0.92,
    phiWeight: PHI_INVERSE,
    sacredType: 'excitatory',
    fiberCount: 20000000,
    delay: 3,
  },
  {
    id: 'sma_m1',
    source: 'sma',
    target: 'm1',
    strength: 0.90,
    phiWeight: PHI_INVERSE,
    sacredType: 'excitatory',
    fiberCount: 15000000,
    delay: 5,
  },
  {
    id: 'sma_sma_bilateral',
    source: 'sma',
    target: 'sma',
    strength: 0.78,
    phiWeight: 1,
    sacredType: 'modulatory',
    fiberCount: 5000000,
    delay: 10,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // DEFAULT MODE NETWORK — Self-Referential
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'pcc_precuneus',
    source: 'pcc',
    target: 'precuneus',
    strength: 0.93,
    phiWeight: PHI,
    sacredType: 'modulatory',
    fiberCount: 10000000,
    delay: 5,
  },
  {
    id: 'pcc_vmpfc',
    source: 'pcc',
    target: 'vmpfc',
    strength: 0.85,
    phiWeight: PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 8000000,
    delay: 15,
  },
  {
    id: 'precuneus_hippo',
    source: 'precuneus',
    target: 'hippocampus',
    strength: 0.80,
    phiWeight: PHI_INVERSE * PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 3000000,
    delay: 12,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // CEREBELLAR CONNECTIONS — Precision Timing
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'cerebellum_thalamus',
    source: 'cerebellum',
    target: 'thalamus',
    strength: 0.88,
    phiWeight: PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 40000000,
    delay: 5,
  },
  {
    id: 'cerebellum_m1',
    source: 'cerebellum',
    target: 'm1',
    strength: 0.82,
    phiWeight: PHI_SQUARED * PHI_INVERSE * PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 10000000,
    delay: 10,
  },

  // ═════════════════════════════════════════════════════════════════════════════
  // BRAINSTEM MODULATORY — Neuromodulation
  // ═════════════════════════════════════════════════════════════════════════════
  {
    id: 'raphe_cortex',
    source: 'raphe',
    target: 'dlpfc',
    strength: 0.70,
    phiWeight: PHI_SQUARED * PHI_INVERSE * PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 200000,
    delay: 20,
  },
  {
    id: 'lc_cortex',
    source: 'locus_coeruleus',
    target: 'dlpfc',
    strength: 0.75,
    phiWeight: PHI_SQUARED * PHI_INVERSE * PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 50000,
    delay: 25,
  },
  {
    id: 'sn_bg',
    source: 'substantia_nigra',
    target: ' basal_ganglia',
    strength: 0.92,
    phiWeight: PHI_INVERSE,
    sacredType: 'modulatory',
    fiberCount: 300000,
    delay: 5,
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN WAVES — φ-Patterned Neural Oscillations
// ═══════════════════════════════════════════════════════════════════════════════

export const BRAIN_WAVES: Record<string, BrainWave> = {
  delta: {
    name: 'Delta',
    symbol: 'Δ',
    frequency: { min: 0.5, max: 4, peak: 2 },
    sacredFreq: PHI, // 1.618 Hz
    state: 'Deep sleep, unconscious, restorative',
    color: '#4a0080', // Deep purple
    phiRelation: 'φ⁻³ × 10 ≈ 1.62 Hz',
  },
  theta: {
    name: 'Theta',
    symbol: 'θ',
    frequency: { min: 4, max: 8, peak: 6 },
    sacredFreq: PHI * 5, // 8.090 Hz
    state: 'Meditation, creativity, REM sleep, flow',
    color: '#0080ff', // Blue
    phiRelation: 'φ × 5 ≈ 8.09 Hz',
  },
  alpha: {
    name: 'Alpha',
    symbol: 'α',
    frequency: { min: 8, max: 13, peak: 10 },
    sacredFreq: 13, // Fibonacci number
    state: 'Relaxed awareness, calm, bridge to unconscious',
    color: '#00ff80', // Green
    phiRelation: 'Fibonacci 8, 13 Hz',
    fibonacciRelated: 13,
  },
  beta: {
    name: 'Beta',
    symbol: 'β',
    frequency: { min: 13, max: 30, peak: 20 },
    sacredFreq: PHI * 20, // 32.36 Hz
    state: 'Active thinking, focus, alert, problem-solving',
    color: '#ff8000', // Orange
    phiRelation: 'φ × 20 ≈ 32.36 Hz',
  },
  gamma: {
    name: 'Gamma',
    symbol: 'γ',
    frequency: { min: 30, max: 100, peak: 40 },
    sacredFreq: PHI_SQUARED * 16, // 41.89 Hz
    state: 'Peak performance, insight, binding, transcendence',
    color: '#ffd700', // Gold
    phiRelation: 'φ² × 16 ≈ 41.89 Hz',
  },
};

// ═══════════════════════════════════════════════════════════════════════════════
// NEUROTRANSMITTERS — Sacred Chemistry of Mind
// ═══════════════════════════════════════════════════════════════════════════════

export const NEUROTRANSMITTERS: Neurotransmitter[] = [
  {
    name: 'Glutamate',
    abbreviation: 'Glu',
    type: 'excitatory',
    sacredRatio: PHI,
    function: 'Primary excitatory transmitter — learning and memory',
  },
  {
    name: 'GABA',
    abbreviation: 'GABA',
    type: 'inhibitory',
    sacredRatio: 1 / PHI,
    function: 'Primary inhibitory transmitter — balance and calm',
  },
  {
    name: 'Dopamine',
    abbreviation: 'DA',
    type: 'modulatory',
    sacredRatio: PHI_INVERSE,
    function: 'Reward, motivation, movement — sacred fire of action',
  },
  {
    name: 'Serotonin',
    abbreviation: '5-HT',
    type: 'modulatory',
    sacredRatio: PHI_INVERSE * PHI_INVERSE,
    function: 'Mood, sleep, appetite — φ-harmony of well-being',
  },
  {
    name: 'Norepinephrine',
    abbreviation: 'NE',
    type: 'modulatory',
    sacredRatio: PHI_SQUARED * PHI_INVERSE * PHI_INVERSE * PHI_INVERSE,
    function: 'Arousal, attention, vigilance — sacred alertness',
  },
  {
    name: 'Acetylcholine',
    abbreviation: 'ACh',
    type: 'modulatory',
    sacredRatio: PHI_INVERSE,
    function: 'Learning, memory, attention — sacred binding',
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BRAIN CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_BRAIN_CONSTANTS = {
  // Action potential threshold (mV)
  ACTION_THRESHOLD: -55,
  // Resting potential (mV) — close to -70, related to φ
  RESTING_POTENTIAL: -70,
  // Refractory period (ms) — approximately φ ms
  REFRACTORY_PERIOD: 2, // Close to PHI
  // Synaptic delay (ms) — approximately 1/φ²
  SYNAPTIC_DELAY: 0.4, // Close to 1/φ² ≈ 0.382
  // Neural conduction velocity (m/s) — myelinated axons
  CONDUCTION_VELOCITY: PHI * 100, // ≈ 162 m/s
  // Brain mass to body mass ratio — approximately φ × 10
  BRAIN_BODY_RATIO: PHI * 0.02,
  // Neocortical neuron count — approximately φ^16
  NEURON_COUNT: Math.pow(PHI, 16) * 1e7,
  // Synaptic connections per neuron — approximately φ^5 × 1000
  SYNAPSES_PER_NEURON: Math.pow(PHI, 5) * 1000,
  // Cortical columns — approximately 10^6
  CORTICAL_COLUMNS: 1e6,
  // Default mode network connectivity — φ-optimized
  DMN_PHI_INDEX: 0.82,
  // Hippocampal place cell spacing — φ-grid
  PLACE_CELL_GRID: PHI * 0.5, // mm
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BRAIN NETWORKS — Functional Systems
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_BRAIN_NETWORKS = {
  defaultMode: {
    name: 'Default Mode Network',
    abbreviation: 'DMN',
    regions: ['pcc', 'precuneus', 'vmpfc', 'hippocampus'],
    sacredFunction: 'Self-referential processing, mind-wandering, consciousness',
    phiIndex: 0.82,
    color: '#fab1a0',
  },
  centralExecutive: {
    name: 'Central Executive Network',
    abbreviation: 'CEN',
    regions: ['dlpfc', 'acc', 's1'],
    sacredFunction: 'Focused attention, decision making, problem-solving',
    phiIndex: 0.85,
    color: '#00cec9',
  },
  salience: {
    name: 'Salience Network',
    abbreviation: 'SN',
    regions: ['acc', 'insula', 'amygdala'],
    sacredFunction: 'Detecting relevant stimuli, switching between networks',
    phiIndex: 0.80,
    color: '#fd79a8',
  },
  sensorimotor: {
    name: 'Sensorimotor Network',
    abbreviation: 'SMN',
    regions: ['s1', 'm1', 'pmc', 'sma', 'cerebellum'],
    sacredFunction: 'Movement execution, sensory processing, coordination',
    phiIndex: 0.86,
    color: '#00b894',
  },
  visual: {
    name: 'Visual Network',
    abbreviation: 'VN',
    regions: ['v1', 'angular_gyrus'],
    sacredFunction: 'Visual processing, mental imagery, φ₁₇ₐ geometry',
    phiIndex: 0.91,
    color: '#d63031',
  },
  auditory: {
    name: 'Auditory Network',
    abbreviation: 'AN',
    regions: ['a1', 'supramarginal_gyrus'],
    sacredFunction: 'Auditory processing, language, music',
    phiIndex: 0.84,
    color: '#e17055',
  },
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS LEVELS — Sacred States of Awareness
// ═══════════════════════════════════════════════════════════════════════════════

export const CONSCIOUSNESS_LEVELS = {
  deep_sleep: {
    name: 'Deep Sleep',
    level: 0,
    dominantWave: 'delta',
    description: 'Unconscious, restorative, no awareness',
    color: '#4a0080',
  },
  dreaming: {
    name: 'Dreaming (REM)',
    level: 20,
    dominantWave: 'theta',
    description: 'Lucid imagery, emotional processing',
    color: '#0080ff',
  },
  meditation: {
    name: 'Meditation',
    level: 35,
    dominantWave: 'theta',
    description: 'Deep focus, inner peace, creativity',
    color: '#00ff80',
  },
  relaxed: {
    name: 'Relaxed Awareness',
    level: 50,
    dominantWave: 'alpha',
    description: 'Calm alert, present moment, flow state',
    color: '#80ff80',
  },
  active: {
    name: 'Active Thinking',
    level: 65,
    dominantWave: 'beta',
    description: 'Problem-solving, focus, engagement',
    color: '#ff8000',
  },
  peak: {
    name: 'Peak Performance',
    level: 80,
    dominantWave: 'gamma',
    description: 'Insight, transcendence, unity consciousness',
    color: '#ffd700',
  },
  unity: {
    name: 'Unity Consciousness',
    level: 100,
    dominantWave: 'gamma',
    description: 'Transcendent, all-is-one, sacred awareness',
    color: '#ffffff',
  },
} as const;
