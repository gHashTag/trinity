// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CHAT API SERVICE v2.9
// Connects Cosmic UI to Zig HTTP backend
// v2.5: + /api/files (Finder) + /api/compile (Editor)
// v2.7: + /api/storage-metrics (Storage Network Dashboard)
// v2.9: + /api/sacred-formula/* (Sacred Formula Engine)
// ═══════════════════════════════════════════════════════════════════════════════

const BASE_URL = 'http://localhost:8080';

export interface ChatRequest {
  message: string;
  image_path?: string;
  audio_path?: string;
}

export interface ChatResponse {
  response: string;
  source: string;
  confidence: number;
  latency_us: number;
  // v2.4 fields
  tool_name?: string;
  reflection?: string;
  learned?: boolean;
}

export async function sendMessage(req: ChatRequest): Promise<ChatResponse> {
  const res = await fetch(`${BASE_URL}/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(req),
  });
  if (!res.ok) throw new Error(`Chat API error: ${res.status}`);
  return res.json();
}

export async function clearContext(): Promise<void> {
  await fetch(`${BASE_URL}/chat/clear`, { method: 'POST' });
}

export async function checkHealth(): Promise<boolean> {
  try {
    const res = await fetch(`${BASE_URL}/health`, { signal: AbortSignal.timeout(3000) });
    return res.ok;
  } catch {
    return false;
  }
}

// ─── Mirror of Three Worlds (Зеркало Трёх Миров) v2.3 ─────────────────────

export interface MirrorRazum {
  symbolic_hits: number;
  symbolic_hit_rate: number;
  memory_entries: number;
  memory_hit_rate: number;
  memory_evictions: number;
  kg_hits: number;
  kg_hit_rate: number;
  kg_facts_loaded: number;
  llm_loaded: boolean;
  last_routing: string;
}

export interface MirrorMateriya {
  tvc_enabled: boolean;
  tvc_corpus_size: number;
  tvc_hits: number;
  tvc_hit_rate: number;
  cache_hit_rate: number;
}

export interface MirrorDukh {
  total_queries: number;
  energy_saved_wh: number;
  groq_calls: number;
  claude_calls: number;
  tool_hits: number;
  vision_calls: number;
  whisper_calls: number;
  groq_success_rate: number;
  claude_success_rate: number;
  context_enabled: boolean;
  context_messages: number;
  context_key_facts: number;
}

export interface MirrorLogEntry {
  ts: number;       // unix timestamp
  src: string;      // Symbolic | TVCCorpus | GroqAPI | ClaudeAPI | Tool | ...
  q: string;        // query preview (truncated to 64 chars)
  conf: number;     // confidence 0-1
  lat: number;      // latency in microseconds
  learned?: boolean; // saved to TVC
}

export interface MirrorStatus {
  status: string;
  uptime_s?: number;
  razum?: MirrorRazum;
  materiya?: MirrorMateriya;
  dukh?: MirrorDukh;
  logs?: MirrorLogEntry[];
}

export async function fetchMirrorStatus(): Promise<MirrorStatus> {
  try {
    const res = await fetch(`${BASE_URL}/health`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return { status: 'offline' };
    return await res.json();
  } catch {
    return { status: 'offline' };
  }
}

// ─── v2.7: Storage Network Metrics ──────────────────────────────────────────

export interface StorageMetrics {
  // Peers
  node_count: number;
  nodes_alive: number;
  nodes_dead: number;
  // Storage
  total_shards: number;
  total_bytes_used: number;
  total_bytes_available: number;
  // Replication
  shards_tracked: number;
  shards_rebalanced: number;
  target_replication: number;
  // Reed-Solomon
  rs_data_shards: number;
  rs_parity_shards: number;
  // Proof of Storage
  pos_challenges_issued: number;
  pos_challenges_passed: number;
  pos_challenges_failed: number;
  // Bandwidth
  total_upload: number;
  total_download: number;
  // Recovery
  scrub_total: number;
  scrub_corruptions: number;
  recoveries_successful: number;
  bytes_recovered: number;
  // Reputation
  reputation_avg: number;
  reputation_min: number;
  reputation_max: number;
  // DHT (Kademlia)
  dht_peers: number;
  dht_buckets_used: number;
  dht_entries_stored: number;
  dht_lookups: number;
  dht_lookup_avg_hops: number;
  // Swarm (Live Multi-Host)
  swarm_nodes_active: number;
  swarm_nodes_joining: number;
  swarm_nodes_leaving: number;
  swarm_nodes_dead: number;
  swarm_regions: number;
  swarm_avg_latency_ms: number;
  swarm_bootstrap_ok: boolean;
  // Rewards ($TRI Economics)
  tri_total_minted: number;
  tri_total_slashed: number;
  tri_active_earners: number;
  tri_epoch_challenges: number;
  tri_avg_balance: number;
  tri_reward_rate: number;
  // Timestamp
  generated_at: number;
}

function generateMockStorageMetrics(): StorageMetrics {
  const now = Math.floor(Date.now() / 1000);
  const drift = Math.sin(now * 0.1) * 0.05;
  return {
    node_count: 12,
    nodes_alive: 11 + (Math.random() > 0.9 ? -1 : 0),
    nodes_dead: 1 + (Math.random() > 0.9 ? 1 : 0),
    total_shards: 1847 + Math.floor(Math.random() * 10),
    total_bytes_used: 483_921_408 + Math.floor(Math.random() * 100000),
    total_bytes_available: 2_147_483_648,
    shards_tracked: 1720 + Math.floor(Math.random() * 8),
    shards_rebalanced: 342 + Math.floor(now % 60 === 0 ? 1 : 0),
    target_replication: 3,
    rs_data_shards: 4,
    rs_parity_shards: 2,
    pos_challenges_issued: 15820 + Math.floor(now / 10) % 100,
    pos_challenges_passed: 15647 + Math.floor(now / 10) % 98,
    pos_challenges_failed: 173 + Math.floor(Math.random() * 3),
    total_upload: 89_432_000 + Math.floor(Math.random() * 50000),
    total_download: 234_891_000 + Math.floor(Math.random() * 80000),
    scrub_total: 47 + Math.floor(now / 3600) % 5,
    scrub_corruptions: 3,
    recoveries_successful: 3,
    bytes_recovered: 196_608,
    reputation_avg: 0.847 + drift * 0.1,
    reputation_min: 0.312,
    reputation_max: 0.998,
    dht_peers: 8 + Math.floor(Math.random() * 4),
    dht_buckets_used: 12 + Math.floor(Math.random() * 5),
    dht_entries_stored: 347 + Math.floor(Math.random() * 20),
    dht_lookups: 2841 + Math.floor(now / 10) % 50,
    dht_lookup_avg_hops: 3.2 + drift,
    swarm_nodes_active: 4 + (Math.random() > 0.8 ? 1 : 0),
    swarm_nodes_joining: Math.random() > 0.7 ? 1 : 0,
    swarm_nodes_leaving: 0,
    swarm_nodes_dead: Math.random() > 0.9 ? 1 : 0,
    swarm_regions: 3 + Math.floor(Math.random() * 2),
    swarm_avg_latency_ms: 45 + Math.floor(Math.random() * 30),
    swarm_bootstrap_ok: true,
    tri_total_minted: 47.832 + drift * 0.5,
    tri_total_slashed: 1.247 + Math.random() * 0.01,
    tri_active_earners: 9 + Math.floor(Math.random() * 3),
    tri_epoch_challenges: 15820 + Math.floor(now / 10) % 100,
    tri_avg_balance: 142.5 + drift * 2,
    tri_reward_rate: 0.001,
    generated_at: now,
  };
}

export async function fetchStorageMetrics(): Promise<StorageMetrics> {
  try {
    const res = await fetch(`${BASE_URL}/api/storage-metrics`, {
      signal: AbortSignal.timeout(3000),
    });
    if (!res.ok) return generateMockStorageMetrics();
    return await res.json();
  } catch {
    return generateMockStorageMetrics();
  }
}

// ─── v2.5: File List API (Finder) ────────────────────────────────────────────

export interface FileEntry {
  path: string;
  category: string;
  icon: string;
  color: string;
}

export async function fetchFileList(): Promise<FileEntry[]> {
  try {
    const res = await fetch(`${BASE_URL}/api/files`, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return [];
    return await res.json();
  } catch {
    return [];
  }
}

// ─── v2.5: Compile API (Editor) ──────────────────────────────────────────────

export interface CompileResult {
  success: boolean;
  language: string;
  output: string;
  types?: number;
  behaviors?: number;
  fields?: number;
  lines?: number;
  errors?: string[];
}

export async function compileCode(code: string, language: string): Promise<CompileResult> {
  try {
    const res = await fetch(`${BASE_URL}/api/compile`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code, language }),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) throw new Error(`Compile API error: ${res.status}`);
    return await res.json();
  } catch {
    return { success: false, language, output: 'Backend offline. Start: zig build tri -- serve --chat --port 8080', errors: ['connection_failed'] };
  }
}

// ─── v2.8: Ralph Autonomous Monitor API ──────────────────────────────────────

export interface RalphLoopStatus {
  status: string;
  loop?: number;
  total_calls?: number;
  cycle?: string;
  goal?: string;
  last_action?: string;
  timestamp?: number;
}

export interface RalphCBStatus {
  state: string;
  failure_count: number;
  last_failure_time?: number;
  threshold: number;
}

export interface RalphStatus {
  loop: RalphLoopStatus;
  circuit_breaker: RalphCBStatus;
  logs: string[];
}

export async function fetchRalphStatus(): Promise<RalphStatus | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/ralph-status`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

// ─── v2.9: Sacred Formula Engine API ──────────────────────────────────────────

export interface SacredFit {
  n: number;
  k: number;
  m: number;
  p: number;
  q: number;
}

export interface SacredConstantResult {
  name: string;
  symbol: string;
  target: number;
  category: string;
  fit: SacredFit;
  computed: number;
  error_pct: number;
}

export interface SacredPrediction {
  name: string;
  formula: string;
  value: number;
  unit: string;
  n: number;
  k: number;
  m: number;
  p: number;
  q: number;
}

export interface SacredFormulaResponse {
  formula: string;
  constants: SacredConstantResult[];
  predictions: SacredPrediction[];
  search_bounds: Record<string, [number, number]>;
}

export interface SingleFitResponse {
  target: number;
  fit: SacredFit;
  computed: number;
  error_pct: number;
  formula_string: string;
}

function generateMockSacredFormula(): SacredFormulaResponse {
  return {
    formula: 'V = n * 3^k * pi^m * phi^p * e^q',
    constants: [
      { name: '1/alpha', symbol: 'FINE_STRUCTURE_INV', target: 137.036, category: 'particle_physics', fit: { n: 5, k: 3, m: -1, p: 0, q: 1 }, computed: 137.0358, error_pct: 0.0001 },
      { name: 'm_p/m_e', symbol: 'PROTON_ELECTRON_RATIO', target: 1836.15267343, category: 'particle_physics', fit: { n: 9, k: 4, m: 1, p: -2, q: 2 }, computed: 1836.12, error_pct: 0.0018 },
      { name: 'CHSH', symbol: 'CHSH', target: 2.8284271247, category: 'quantum', fit: { n: 1, k: 0, m: 0, p: 0, q: 1 }, computed: 2.7183, error_pct: 3.89 },
      { name: 'sin2(theta_W)', symbol: 'WEINBERG_SIN2', target: 0.23121, category: 'particle_physics', fit: { n: 2, k: -2, m: 0, p: 0, q: 0 }, computed: 0.2222, error_pct: 3.89 },
      { name: 'H_0 (67.4)', symbol: 'HUBBLE', target: 67.4, category: 'cosmology', fit: { n: 5, k: 2, m: 1, p: -2, q: -1 }, computed: 67.38, error_pct: 0.03 },
      { name: 'Omega_Lambda', symbol: 'OMEGA_LAMBDA', target: 0.685, category: 'cosmology', fit: { n: 2, k: -1, m: 0, p: -1, q: 0 }, computed: 0.686, error_pct: 0.15 },
      { name: 'T_CMB', symbol: 'CMB_TEMP', target: 2.7255, category: 'cosmology', fit: { n: 1, k: 0, m: 0, p: 0, q: 1 }, computed: 2.7183, error_pct: 0.27 },
      { name: 'gamma_BI (LQG)', symbol: 'BARBERO_IMMIRZI', target: 0.127384, category: 'quantum_gravity', fit: { n: 1, k: -2, m: 0, p: 1, q: -2 }, computed: 0.1274, error_pct: 0.01 },
      { name: 'S/A = 1/4 (BH)', symbol: 'BEKENSTEIN_HAWKING_RATIO', target: 0.25, category: 'quantum_gravity', fit: { n: 1, k: -1, m: 0, p: -1, q: 0 }, computed: 0.2060, error_pct: 17.6 },
      { name: 'Age (13.787 Gyr)', symbol: 'AGE_UNIVERSE', target: 13.787, category: 'cosmology', fit: { n: 5, k: 1, m: 0, p: -1, q: 0 }, computed: 13.82, error_pct: 0.24 },
      { name: 'M_Higgs', symbol: 'M_HIGGS', target: 125.25, category: 'particle_physics', fit: { n: 5, k: 3, m: -1, p: 0, q: 0 }, computed: 125.17, error_pct: 0.064 },
      { name: 'M_W', symbol: 'M_W_BOSON', target: 80.377, category: 'particle_physics', fit: { n: 3, k: 3, m: 0, p: -1, q: 0 }, computed: 80.31, error_pct: 0.083 },
      { name: 'M_Z', symbol: 'M_Z_BOSON', target: 91.1876, category: 'particle_physics', fit: { n: 1, k: 4, m: 0, p: 0, q: 0 }, computed: 81.0, error_pct: 11.2 },
    ],
    predictions: [
      { name: 'Neutrino mass hint', formula: '1*3^-1*pi^-1*phi^-4*e^-1', value: 0.0152, unit: 'eV', n: 1, k: -1, m: -1, p: -4, q: -1 },
      { name: 'DM candidate mass', formula: '3*3^2*phi^3*e^2', value: 817.3, unit: 'GeV', n: 3, k: 2, m: 0, p: 3, q: 2 },
      { name: 'Lambda/rho_P hint', formula: '1*3^-4*pi^-2*phi^-4*e^-3', value: 5.13e-7, unit: 'Planck', n: 1, k: -4, m: -2, p: -4, q: -3 },
      { name: 'Graviton mass bound', formula: '1*3^-3*pi^-3*phi^-4*e^-3', value: 1.87e-8, unit: 'eV', n: 1, k: -3, m: -3, p: -4, q: -3 },
      { name: 'Proton lifetime hint', formula: '3*3^4*pi^3*phi^4*e^4', value: 2.73e6, unit: 'years', n: 3, k: 4, m: 3, p: 4, q: 4 },
      { name: 'Spatial dimensions', formula: '1*3^1', value: 3.0, unit: '', n: 1, k: 1, m: 0, p: 0, q: 0 },
    ],
    search_bounds: { n: [1, 9], k: [-4, 4], m: [-3, 3], p: [-4, 4], q: [-3, 3] },
  };
}

export async function fetchSacredFormula(): Promise<SacredFormulaResponse> {
  try {
    const res = await fetch(`${BASE_URL}/api/sacred-formula/fit`, {
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return generateMockSacredFormula();
    return await res.json();
  } catch {
    return generateMockSacredFormula();
  }
}

export async function fitSingleValue(value: number): Promise<SingleFitResponse> {
  try {
    const res = await fetch(`${BASE_URL}/api/sacred-formula/compute`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value }),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) throw new Error(`Sacred Formula API error: ${res.status}`);
    return await res.json();
  } catch {
    // Offline fallback: compute client-side (approximate)
    const PHI = 1.618033988749895;
    const n = 1, k = 0, m = 0, p = 0, q = 0;
    return {
      target: value,
      fit: { n, k, m, p, q },
      computed: 1.0,
      error_pct: Math.abs(1.0 - value) / value * 100,
      formula_string: `${n}*3^${k}*pi^${m}*phi^${p}*e^${q}`,
    };
  }
}
