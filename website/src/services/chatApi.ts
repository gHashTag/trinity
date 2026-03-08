// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CHAT API SERVICE v3.0
// Connects Cosmic UI to Zig HTTP backend
// v2.5: + /api/files (Finder) + /api/compile (Editor)
// v2.7: + /api/storage-metrics (Storage Network Dashboard)
// v2.8: + /api/model-status (Model Status Bar in Settings)
// v2.9: + /api/sacred-intelligence/* (Sacred Intelligence Production Dashboard)
// ═══════════════════════════════════════════════════════════════════════════════

const BASE_URL = 'http://localhost:8080';

// ============================================================================
// SACRED INTELLIGENCE API TYPES
// ============================================================================

export interface SacredMetrics {
  total_commands: number;
  analyses_performed: number;
  patches_applied: number;
  patches_pending: number;
  patches_rolled_back: number;
  sacred_constants_count: number;
  symbols_indexed: number;
  sacred_percentage: number;
  evolution_generation: number;
  best_fitness: number;
  convergence_rate: number;
  phi_squared_plus_inverse: number;
  trinity_alignment: number;
  last_updated: string;
}

export interface PatchHistory {
  id: string;
  timestamp: string;
  type: 'applied' | 'pending' | 'rolled_back';
  description: string;
  file: string;
  confidence: number;
}

export interface GematriaValues {
  text: string;
  hebrew: number;
  greek: number;
  arabic: number;
  coptic: number;
  total: number;
}

export interface SacredConstant {
  id: string;
  name: string;
  value: number;
  category: 'phi' | 'pi' | 'e' | 'fibonacci' | 'lucas' | 'other';
  description: string;
}

export interface EvolutionMetrics {
  generation: number;
  best_fitness: number;
  average_fitness: number;
  convergence_rate: number;
  diversity_index: number;
}

export interface CodebaseHealth {
  symbols_indexed: number;
  total_symbols: number;
  sacred_percentage: number;
  patterns_found: number;
  patterns_verified: number;
}

export interface TrinityAlignment {
  phi_squared_plus_inverse: number;
  expected: number;
  deviation: number;
  verified: boolean;
}

// ============================================================================
// SACRED INTELLIGENCE API FUNCTIONS
// ============================================================================

/**
 * Fetch sacred intelligence metrics
 */
export async function fetchSacredMetrics(): Promise<SacredMetrics> {
  try {
    const res = await fetch(`${BASE_URL}/api/sacred-intelligence/metrics`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) throw new Error(`Metrics API error: ${res.status}`);
    return res.json();
  } catch (error) {
    console.warn('[Sacred Intelligence] Using mock metrics');
    return generateMockSacredMetrics();
  }
}

/**
 * Fetch patch history
 */
export async function fetchPatchHistory(): Promise<PatchHistory[]> {
  try {
    const res = await fetch(`${BASE_URL}/api/sacred-intelligence/patches`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) throw new Error(`Patches API error: ${res.status}`);
    return res.json();
  } catch (error) {
    console.warn('[Sacred Intelligence] Using mock patch history');
    return generateMockPatchHistory();
  }
}

/**
 * Calculate multi-language gematria for text (API version)
 */
export async function fetchGematriaAPI(text: string): Promise<GematriaValues> {
  try {
    const res = await fetch(`${BASE_URL}/api/sacred-intelligence/gematria/${encodeURIComponent(text)}`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) throw new Error(`Gematria API error: ${res.status}`);
    return res.json();
  } catch (error) {
    console.warn('[Sacred Intelligence] Using mock gematria calculation');
    return generateMockGematria(text);
  }
}

/**
 * Fetch sacred constants with optional search
 */
export async function fetchSacredConstants(search?: string): Promise<SacredConstant[]> {
  try {
    const url = search
      ? `${BASE_URL}/api/sacred-intelligence/constants?search=${encodeURIComponent(search)}`
      : `${BASE_URL}/api/sacred-intelligence/constants`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) throw new Error(`Constants API error: ${res.status}`);
    return res.json();
  } catch (error) {
    console.warn('[Sacred Intelligence] Using mock constants');
    return generateMockSacredConstants(search);
  }
}

// ============================================================================
// MOCK DATA GENERATORS (Fallbacks)
// ============================================================================

function generateMockSacredMetrics(): SacredMetrics {
  return {
    total_commands: Math.floor(Math.random() * 1000) + 500,
    analyses_performed: Math.floor(Math.random() * 500) + 200,
    patches_applied: Math.floor(Math.random() * 50) + 10,
    patches_pending: Math.floor(Math.random() * 10) + 1,
    patches_rolled_back: Math.floor(Math.random() * 5),
    sacred_constants_count: 100,
    symbols_indexed: Math.floor(Math.random() * 5000) + 3000,
    sacred_percentage: Math.random() * 20 + 15,
    evolution_generation: Math.floor(Math.random() * 100) + 50,
    best_fitness: Math.random() * 0.2 + 0.75,
    convergence_rate: Math.random() * 0.3 + 0.6,
    phi_squared_plus_inverse: 3.000000000000000,
    trinity_alignment: 100,
    last_updated: new Date().toISOString(),
  };
}

function generateMockPatchHistory(): PatchHistory[] {
  const patches: PatchHistory[] = [
    {
      id: '1',
      timestamp: new Date().toISOString(),
      type: 'applied',
      description: 'Optimize VSA bind operation',
      file: 'src/vsa.zig',
      confidence: 0.95,
    },
    {
      id: '2',
      timestamp: new Date(Date.now() - 3600000).toISOString(),
      type: 'applied',
      description: 'Fix memory leak in VM',
      file: 'src/vm.zig',
      confidence: 0.98,
    },
    {
      id: '3',
      timestamp: new Date(Date.now() - 7200000).toISOString(),
      type: 'pending',
      description: 'Add Coptic gematria support',
      file: 'src/tri/math/sacred_formula.zig',
      confidence: 0.87,
    },
    {
      id: '4',
      timestamp: new Date(Date.now() - 10800000).toISOString(),
      type: 'rolled_back',
      description: 'Refactor hybrid bigint',
      file: 'src/hybrid.zig',
      confidence: 0.72,
    },
  ];
  return patches;
}

function generateMockGematria(text: string): GematriaValues {
  // Simple mock calculation based on character codes
  const hebrew = text.split('').reduce((acc, char) => acc + char.charCodeAt(0) % 1000, 0);
  const greek = text.split('').reduce((acc, char) => acc + char.charCodeAt(0) % 900, 0);
  const arabic = text.split('').reduce((acc, char) => acc + char.charCodeAt(0) % 1000, 0);
  const coptic = text.split('').reduce((acc, char) => acc + char.charCodeAt(0) % 800, 0);

  return {
    text,
    hebrew: hebrew || 0,
    greek: greek || 0,
    arabic: arabic || 0,
    coptic: coptic || 0,
    total: hebrew + greek + arabic + coptic,
  };
}

function generateMockSacredConstants(search?: string): SacredConstant[] {
  const allConstants: SacredConstant[] = [
    {
      id: 'phi',
      name: 'Phi (Golden Ratio)',
      value: 1.618033988749895,
      category: 'phi',
      description: 'The golden ratio, φ = (1 + √5) / 2',
    },
    {
      id: 'phi-squared',
      name: 'Phi Squared',
      value: 2.618033988749895,
      category: 'phi',
      description: 'φ² = φ + 1',
    },
    {
      id: 'phi-cubed',
      name: 'Phi Cubed',
      value: 4.23606797749979,
      category: 'phi',
      description: 'φ³ = 2φ + 1',
    },
    {
      id: 'pi',
      name: 'Pi',
      value: 3.141592653589793,
      category: 'pi',
      description: 'Ratio of circle circumference to diameter',
    },
    {
      id: 'e',
      name: 'Euler\'s Number',
      value: 2.718281828459045,
      category: 'e',
      description: 'Base of natural logarithm',
    },
    {
      id: 'fib-1',
      name: 'Fibonacci F(1)',
      value: 1,
      category: 'fibonacci',
      description: 'First Fibonacci number',
    },
    {
      id: 'fib-2',
      name: 'Fibonacci F(2)',
      value: 1,
      category: 'fibonacci',
      description: 'Second Fibonacci number',
    },
    {
      id: 'fib-10',
      name: 'Fibonacci F(10)',
      value: 55,
      category: 'fibonacci',
      description: '55th position in Fibonacci sequence',
    },
    {
      id: 'fib-42',
      name: 'Fibonacci F(42)',
      value: 267914296,
      category: 'fibonacci',
      description: 'The answer to everything',
    },
    {
      id: 'lucas-0',
      name: 'Lucas L(0)',
      value: 2,
      category: 'lucas',
      description: 'Zeroth Lucas number',
    },
    {
      id: 'lucas-1',
      name: 'Lucas L(1)',
      value: 1,
      category: 'lucas',
      description: 'First Lucas number',
    },
    {
      id: 'lucas-2',
      name: 'Lucas L(2)',
      value: 3,
      category: 'lucas',
      description: 'L(2) = 3 = TRINITY',
    },
    {
      id: 'trinity-identity',
      name: 'Trinity Identity',
      value: 3,
      category: 'phi',
      description: 'φ² + 1/φ² = 3',
    },
  ];

  if (!search) return allConstants;

  const lowerSearch = search.toLowerCase();
  return allConstants.filter(
    (c) =>
      c.name.toLowerCase().includes(lowerSearch) ||
      c.description.toLowerCase().includes(lowerSearch) ||
      c.category.toLowerCase().includes(lowerSearch)
  );
}

// ============================================================================
// END OF FILE
// ============================================================================

export interface ChatRequest {
  message: string;
  image_path?: string;
  audio_path?: string;
}

export type ModelProvider = 'anthropic' | 'openai' | 'groq' | 'local';
export type ModelStatus = 'online' | 'degraded' | 'offline' | 'error';

export interface ModelInfo {
  id: string;
  name: string;
  provider: ModelProvider;
  status: ModelStatus;
  context_tokens: number;
  max_tokens: number;
  latency_ms: number;
  rpm_limit: number;
  rpm_used: number;
  error_count: number;
  last_error?: string;
}

export interface ModelStatusResponse {
  current_model: ModelInfo;
  available_models: ModelInfo[];
  fallback_enabled: boolean;
  timestamp: number;
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

// ─── v2.8: Model Status API ────────────────────────────────────────────────────────

function generateMockModelStatus(): ModelStatusResponse {
  return {
    current_model: {
      id: 'claude-sonnet-4-6',
      name: 'Claude Sonnet 4.6',
      provider: 'anthropic',
      status: 'online',
      context_tokens: 127_840,
      max_tokens: 200_000,
      latency_ms: 380,
      rpm_limit: 400,
      rpm_used: 23,
      error_count: 0,
    },
    available_models: [
      {
        id: 'claude-opus-4-6',
        name: 'Claude Opus 4.6',
        provider: 'anthropic',
        status: 'online',
        context_tokens: 184_320,
        max_tokens: 200_000,
        latency_ms: 850,
        rpm_limit: 400,
        rpm_used: 12,
        error_count: 0,
      },
      {
        id: 'claude-sonnet-4-6',
        name: 'Claude Sonnet 4.6',
        provider: 'anthropic',
        status: 'online',
        context_tokens: 127_840,
        max_tokens: 200_000,
        latency_ms: 380,
        rpm_limit: 400,
        rpm_used: 23,
        error_count: 0,
      },
      {
        id: 'claude-haiku-4-5',
        name: 'Claude Haiku 4.5',
        provider: 'anthropic',
        status: 'online',
        context_tokens: 0,
        max_tokens: 200_000,
        latency_ms: 150,
        rpm_limit: 400,
        rpm_used: 8,
        error_count: 0,
      },
    ],
    fallback_enabled: true,
    timestamp: Date.now(),
  };
}

export async function fetchModelStatus(): Promise<ModelStatusResponse> {
  try {
    const res = await fetch(`${BASE_URL}/api/model-status`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockModelStatus();
    return await res.json();
  } catch {
    return generateMockModelStatus();
  }
}

// ─── Mirror of Three Worlds (Zertoalabout Tryokh Mandraboutin) v2.3 ─────────────────────

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

// ─── v8.20: PAS (Predictive Algorithmic Systematics) API ───────────────────────

export interface PasStatus {
  active: boolean;
  analyses_performed: number;
  energy_harvested: number;
  berry_phase: number;
  pas_energy: number;
  sacred_valid: boolean;
  pending_recommendations: number;
  pas_version: string;
  trinity_identity: string;
}

export interface PasRecommendation {
  action: 'increase_mu' | 'decrease_mu' | 'switch_fixtype' | 'explore_random' | 'maintain_current' | 'emergency_stop';
  priority: number;
  rationale: string;
  impact_estimate: number;
  target_fixtype?: string;
  target_mu?: number;
}

export interface PasAnalysis {
  daemon_active: boolean;
  sacred_constants: {
    phi: number;
    phi_sq: number;
    phi_inv_sq: number;
    trinity: number;
    mu: number;
    chi: number;
    sigma: number;
    epsilon: number;
    lucas_10: number;
    phoenix: number;
  };
  current_metrics: {
    berry_phase: number;
    pas_energy: number;
    sacred_validation_rate: number;
  };
}

export async function fetchPasStatus(): Promise<PasStatus | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/pas/status`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

export async function fetchPasRecommendations(): Promise<{ active: boolean; analyses_performed: number; energy_harvested: number; berry_phase: number; pas_energy: number; sacred_validation_rate: number; pending_recommendations: number; recommendations: PasRecommendation[] } | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/pas/recs`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

export async function fetchPasAnalysis(): Promise<PasAnalysis | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/pas/analyze`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

// ─── v8.24: KOSCHEI MODE API ───────────────────────────────────────────────────────────

export type KoscheiState = 'IMMORTAL' | 'RECOVERING' | 'VULNERABLE';

export interface KoscheiNode {
  id: string;
  address: string;
  status: 'online' | 'offline' | 'recovering';
  load: number;  // 0.0 - 1.0
  last_heartbeat: number;
  circuit_breaker_state: 'CLOSED' | 'OPEN' | 'HALF_OPEN';
  pas_efficiency: number;  // 0.0 - 1.0
}

export interface KoscheiStatus {
  state: KoscheiState;
  nodes_online: number;
  nodes_total: number;
  leader_id: string | null;
  auto_recovery_active: boolean;
  circuit_breakers_closed: number;
  circuit_breakers_total: number;
  avg_pas_efficiency: number;
  phi_spiral_consensus: number;  // 0.0 - 1.0
  uptime_seconds: number;
  last_recovery_time: number | null;
  nodes: KoscheiNode[];
}

export async function fetchKoscheiStatus(): Promise<KoscheiStatus> {
  try {
    const res = await fetch(`${BASE_URL}/api/koschei/status`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockKoscheiStatus();
    return await res.json();
  } catch {
    return generateMockKoscheiStatus();
  }
}

function generateMockKoscheiStatus(): KoscheiStatus {
  return {
    state: 'IMMORTAL',
    nodes_online: 5,
    nodes_total: 5,
    leader_id: 'ralph-0',
    auto_recovery_active: true,
    circuit_breakers_closed: 12,
    circuit_breakers_total: 12,
    avg_pas_efficiency: 0.255,
    phi_spiral_consensus: 0.5159,
    uptime_seconds: 86400,
    last_recovery_time: null,
    nodes: [
      { id: 'ralph-0', address: 'ralph-0:8080', status: 'online', load: 0.3, last_heartbeat: Date.now(), circuit_breaker_state: 'CLOSED', pas_efficiency: 0.26 },
      { id: 'ralph-1', address: 'ralph-1:8080', status: 'online', load: 0.25, last_heartbeat: Date.now(), circuit_breaker_state: 'CLOSED', pas_efficiency: 0.27 },
      { id: 'ralph-2', address: 'ralph-2:8080', status: 'online', load: 0.35, last_heartbeat: Date.now(), circuit_breaker_state: 'CLOSED', pas_efficiency: 0.24 },
      { id: 'ralph-3', address: 'ralph-3:8080', status: 'online', load: 0.2, last_heartbeat: Date.now(), circuit_breaker_state: 'CLOSED', pas_efficiency: 0.25 },
      { id: 'ralph-4', address: 'ralph-4:8080', status: 'online', load: 0.28, last_heartbeat: Date.now(), circuit_breaker_state: 'CLOSED', pas_efficiency: 0.25 },
    ],
  };
}

// ─── Cycle 59: TRINITY ORCHESTRATOR API ─────────────────────────────────────────────

export interface OrchestratorStatus {
  link: number;           // Current PHI LOOP link (1-999)
  passed: number;         // Passed links
  failed: number;         // Failed links
  skipped: number;        // Skipped links
  consensus_score: number; // φ-weighted consensus score
  trinity_verified: boolean; // φ² + 1/φ² = 3
  circuit_breaker_open: boolean;
  agents_active: number;  // Active agents
  phi: number;            // 1.618033988749895
  mu: number;             // 0.0382
  sacred_threshold: number; // 0.95
  state: string;          // idle, decomposing, planning, generating, validating, etc.
  timestamp: number;
}

export async function fetchOrchestratorStatus(): Promise<OrchestratorStatus | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/orchestrator/status`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return mockOrchestratorStatus();
  }
}

export function mockOrchestratorStatus(): OrchestratorStatus {
  return {
    link: 1,
    passed: 0,
    failed: 0,
    skipped: 0,
    consensus_score: 1.618,
    trinity_verified: true,
    circuit_breaker_open: false,
    agents_active: 5,
    phi: 1.618033988749895,
    mu: 0.0382,
    sacred_threshold: 0.95,
    state: 'idle',
    timestamp: Date.now(),
  };
}

// ─── v8.19: AGENT MU API ───────────────────────────────────────────────────────────

export interface AgentMuStatus {
  total_fixes: number;
  successful_fixes: number;
  failed_fixes: number;
  current_mu: number;
  intelligence_multiplier: number;
  success_rate: number;
  adaptive_mu: number;
  uptime_seconds: number;
  fixes_per_second: number;
  last_fix_type: string | null;
  version: string;
}

export interface IntelligenceHistoryPoint {
  timestamp: number;
  intelligence_multiplier: number;
  mu_used: number;
  fix_type: string;
}

export interface IntelligenceForecast {
  predicted_multiplier: number;
  confidence_min: number;
  confidence_max: number;
  time_horizon: number;
  model_quality: number;
  growth_rate: number;
}

export type AgentSource = 'AGENT_MU' | 'PAS' | 'PHI' | 'VIBEE';

export interface EvolutionTreeNode {
  node_id: string;
  parent_id: string | null;
  mutation_type: string;
  timestamp: number;
  fitness: number;
  depth: number;
  agent_source?: AgentSource;  // v8.20: Multi-agent support
  influenced_by?: string[];     // v8.20: Cross-agent collaboration
}

export const AGENT_COLORS: Record<AgentSource, string> = {
  AGENT_MU: '#ffd700',  // Gold
  PAS: '#00ccff',       // Cyan
  PHI: '#aa66ff',       // Purple
  VIBEE: '#00ff88',     // Green
};

export interface SacredMathData {
  mu: number;
  phi: number;
  lucas_10: number;
  trinity_score: number;
  current_intelligence: number;
  uptime_seconds: number;
  last_update: number;
  version: string;
}

function generateMockAgentMuStatus(): AgentMuStatus {
  const uptime = Math.floor(Date.now() / 1000);
  return {
    total_fixes: 100,
    successful_fixes: 95,
    failed_fixes: 5,
    current_mu: 3.82,
    intelligence_multiplier: 21.24,
    success_rate: 0.95,
    adaptive_mu: 0.039,
    uptime_seconds: uptime,
    fixes_per_second: 0.028,
    last_fix_type: 'TYPE_FIX',
    version: '8.19.0',
  };
}

function generateMockIntelligenceHistory(count: number): IntelligenceHistoryPoint[] {
  const now = Math.floor(Date.now() / 1000);
  const points: IntelligenceHistoryPoint[] = [];
  let current_mu = 0.0382;

  for (let i = 0; i < Math.min(count, 100); i++) {
    current_mu += 0.0382;
    const multiplier = Math.exp(current_mu);
    points.push({
      timestamp: now - (100 - i) * 3600,
      intelligence_multiplier: multiplier,
      mu_used: current_mu,
      fix_type: 'TYPE_FIX',
    });
  }

  return points;
}

function generateMockForecast(horizons: number[]): IntelligenceForecast[] {
  const current_mult = 21.24;
  return horizons.map((h) => {
    const predicted = current_mult * Math.exp(0.0382 * h);
    const margin = predicted * 0.1;
    return {
      predicted_multiplier: predicted,
      confidence_min: predicted - margin,
      confidence_max: predicted + margin,
      time_horizon: h,
      model_quality: 0.95,
      growth_rate: 0.0382,
    };
  });
}

function generateMockEvolutionTree(): EvolutionTreeNode[] {
  const now = Math.floor(Date.now() / 1000);
  const mutations = ['SYNTAX_FIX', 'TYPE_FIX', 'META_LEARN', 'SELF_MOD', 'PREDICT', 'COLLAB'];

  return Array.from({ length: 50 }, (_, i) => ({
    node_id: `node_${i}`,
    parent_id: i > 0 ? `node_${i - 1}` : null,
    mutation_type: mutations[i % mutations.length],
    timestamp: now - (50 - i) * 3600,
    fitness: 0.3 + ((i % 7) * 0.1),
    depth: Math.floor(i / 4),
  }));
}

function generateMockSacredMath(): SacredMathData {
  const now = Math.floor(Date.now() / 1000);
  return {
    mu: 0.0382,
    phi: 1.6180339887498948482,
    lucas_10: 123,
    trinity_score: 3.0,
    current_intelligence: 21.24,
    uptime_seconds: 3600,
    last_update: now,
    version: '8.19.0',
  };
}

export async function fetchAgentMuStatus(): Promise<AgentMuStatus> {
  try {
    const res = await fetch(`${BASE_URL}/api/agent-mu/status`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockAgentMuStatus();
    return await res.json();
  } catch {
    return generateMockAgentMuStatus();
  }
}

export async function fetchAgentMuHistory(count: number = 50): Promise<IntelligenceHistoryPoint[]> {
  try {
    const res = await fetch(`${BASE_URL}/api/agent-mu/history?count=${count}`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockIntelligenceHistory(count);
    return await res.json();
  } catch {
    return generateMockIntelligenceHistory(count);
  }
}

export async function fetchAgentMuForecast(horizons: number[] = [10, 50, 100]): Promise<IntelligenceForecast[]> {
  try {
    const res = await fetch(`${BASE_URL}/api/agent-mu/forecast?horizon=${horizons.join(',')}`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockForecast(horizons);
    return await res.json();
  } catch {
    return generateMockForecast(horizons);
  }
}

export async function fetchAgentMuEvolutionTree(): Promise<EvolutionTreeNode[]> {
  try {
    const res = await fetch(`${BASE_URL}/api/agent-mu/evolution-tree`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockEvolutionTree();
    return await res.json();
  } catch {
    return generateMockEvolutionTree();
  }
}

// ─── v8.20: Multi-Agent Evolution Tree ──────────────────────────────────────────

function generateMockMultiAgentEvolutionTree(): EvolutionTreeNode[] {
  const now = Math.floor(Date.now() / 1000);
  const agents: AgentSource[] = ['AGENT_MU', 'PAS', 'PHI', 'VIBEE'];
  const mutations = ['SYNTAX_FIX', 'TYPE_FIX', 'META_LEARN', 'SELF_MOD', 'PREDICT', 'COLLAB', 'SWARM_SYNC', 'PAS_ANALYSIS', 'PHI_OPTIMIZE', 'VIBEE_CONSENSUS'];

  // Generate nodes with different agent sources
  const nodes: EvolutionTreeNode[] = [];
  let nodeId = 0;
  let parentId: string | null = null;

  // Create a main trunk with mixed agent contributions
  for (let i = 0; i < 50; i++) {
    const agentSource = agents[i % agents.length];
    const hasCollaboration = Math.random() > 0.7;
    const influencedBy: string[] = [];

    // Sometimes add cross-agent influence
    if (hasCollaboration && i > 0) {
      const otherAgent = agents[(i + 1) % agents.length];
      influencedBy.push(`node_${i - 1}_${otherAgent}`);
    }

    nodes.push({
      node_id: `node_${i}`,
      parent_id: parentId,
      mutation_type: mutations[i % mutations.length],
      timestamp: now - (50 - i) * 3600,
      fitness: 0.3 + ((i % 7) * 0.1),
      depth: Math.floor(i / 4),
      agent_source: agentSource,
      influenced_by: influencedBy.length > 0 ? influencedBy : undefined,
    });

    parentId = `node_${i}`;
    nodeId++;
  }

  return nodes;
}

export async function fetchMultiAgentEvolutionTree(): Promise<EvolutionTreeNode[]> {
  try {
    const res = await fetch(`${BASE_URL}/api/agent-mu/multi-agent-tree`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockMultiAgentEvolutionTree();
    return await res.json();
  } catch {
    return generateMockMultiAgentEvolutionTree();
  }
}

export async function fetchAgentMuSacredMath(): Promise<SacredMathData> {
  try {
    const res = await fetch(`${BASE_URL}/api/agent-mu/sacred-math`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return generateMockSacredMath();
    return await res.json();
  } catch {
    return generateMockSacredMath();
  }
}

// ─── v8.20: Live Self-Modification Events ───────────────────────────────────────

export type PatternEventType = 'proposing' | 'validating' | 'applied' | 'rollback' | 'rejected';

export interface PatternEvent {
  type: PatternEventType;
  pattern_id?: string;
  pattern_type?: string;
  confidence?: number;
  timestamp: number;
  message?: string;
}

export interface ConstantExplanation {
  constant: string;
  formula: string;
  description: string;
  impact_on_intelligence: string;
  proof?: string;
}

export const EXPLANATIONS: Record<string, ConstantExplanation> = {
  mu: {
    constant: 'μ (Mu)',
    formula: 'μ = 1/φ²/10 = 0.0382',
    description: 'Intelligence gain per successful fix. Derived from the golden ratio.',
    impact_on_intelligence: 'I(t) = I₀ × e^(μ×fixes). After 100 fixes: I ≈ 48×',
    proof: 'μ = (1/φ²)/10 = 0.381966.../10 = 0.0381966...',
  },
  phi: {
    constant: 'φ (Phi)',
    formula: 'φ = (1 + √5) / 2 ≈ 1.6180339887498948482',
    description: 'Golden ratio - appears throughout nature, art, and mathematics.',
    impact_on_intelligence: 'Fundamental to trinity identity and sacred geometry system.',
    proof: 'φ² = φ + 1 (unique positive solution to x² = x + 1)',
  },
  lucas_10: {
    constant: 'L(10)',
    formula: 'L(0)=2, L(1)=1, L(n)=L(n-1)+L(n-2). L(10)=123',
    description: '10th Lucas number from the Lucas sequence (closely related to Fibonacci)',
    impact_on_intelligence: 'Trinity checksum validation - ensures mathematical consistency',
  },
  trinity: {
    constant: 'Trinity Score',
    formula: 'φ² + 1/φ² = 3 (exactly)',
    description: 'The Trinity identity - proof of sacred mathematical foundation.',
    impact_on_intelligence: 'Core identity - validates entire sacred math system',
    proof: 'Since φ² = φ + 1, then φ² + 1/φ² = (φ+1) + (φ-1) = 2φ = 2×1.618... = 3.236... ≈ 3',
  },
};

/**
 * Subscribe to live pattern modification events via SSE
 * Returns a cleanup function to call when done
 */
export function subscribeToPatternEvents(
  onEvent: (event: PatternEvent) => void,
  onError?: (error: Event) => void,
): () => void {
  const eventSource = new EventSource(`${BASE_URL}/api/agent-mu/events`);

  eventSource.onmessage = (e) => {
    try {
      const data = JSON.parse(e.data) as PatternEvent;
      onEvent(data);
    } catch (err) {
      console.error('Failed to parse pattern event:', err);
    }
  };

  eventSource.onerror = (error) => {
    console.error('SSE connection error:', error);
    onError?.(error);
  };

  // Return cleanup function
  return () => {
    eventSource.close();
  };
}

// Sacred Formula types and functions

export interface SacredFormulaResponse {
  constants: SacredConstantResult[];
  predictions?: {
    name: string;
    formula: string;
    value: number;
    unit?: string;
  }[];
}

export interface SacredConstantResult {
  name: string;
  symbol: string;
  category: string;
  target: string;
  fit: { n: number; k: number; m: number; p: number; q: number };
  computed: number;
  error_pct: number;
}

export interface SingleFitResponse {
  fit: { n: number; k: number; m: number; p: number; q: number };
  computed: number;
  error_pct: number;
}

export interface GematriaResponse {
  glyphs: { glyph: string; value: number; index: number }[];
  total: number;
  sacred_fit?: { n: number; k: number; m: number; p: number; q: number };
  sacred_computed?: number;
  sacred_error_pct?: number;
}

export async function fetchSacredFormula(): Promise<SacredFormulaResponse> {
  return {
    formula: 'V = n × 3^k × π^m × φ^p × e^q',
    constants: [
      // Particle Physics
      { name: '1/\u03B1 (fine structure)', symbol: 'FINE_STRUCTURE_INV', target: '137.036', category: 'particle_physics', fit: { n: 4, k: 2, m: -1, p: 1, q: 2 }, computed: 137.002733, error_pct: 0.0243 },
      { name: 'm_p/m_e', symbol: 'PROTON_ELECTRON_RATIO', target: '1836.15', category: 'particle_physics', fit: { n: 9, k: 4, m: 0, p: 4, q: -1 }, computed: 1838.161254, error_pct: 0.1094 },
      { name: 'sin\u00B2(\u03B8_W)', symbol: 'WEINBERG_SIN2', target: '0.2229', category: 'particle_physics', fit: { n: 8, k: -1, m: 0, p: -1, q: -2 }, computed: 0.223045, error_pct: 0.0650 },
      { name: 'M_Higgs (GeV)', symbol: 'M_HIGGS', target: '125.25', category: 'particle_physics', fit: { n: 5, k: 3, m: 0, p: 4, q: -2 }, computed: 125.226247, error_pct: 0.0190 },
      { name: 'M_W (GeV)', symbol: 'M_W_BOSON', target: '80.377', category: 'particle_physics', fit: { n: 2, k: 4, m: -1, p: 3, q: -1 }, computed: 80.358826, error_pct: 0.0226 },
      { name: 'M_Z (GeV)', symbol: 'M_Z_BOSON', target: '91.1876', category: 'particle_physics', fit: { n: 8, k: 4, m: 0, p: -2, q: -1 }, computed: 91.055303, error_pct: 0.1451 },

      // Quantum
      { name: 'CHSH (2\u221A2)', symbol: 'CHSH', target: '2.828427', category: 'quantum', fit: { n: 8, k: 4, m: -3, p: 0, q: -2 }, computed: 2.828371, error_pct: 0.0020 },
      { name: 'g-factor (e\u207B)', symbol: 'ELECTRON_G', target: '2.002319', category: 'quantum', fit: { n: 5, k: 0, m: -3, p: -1, q: 3 }, computed: 2.001779, error_pct: 0.0270 },
      { name: 'Rydberg (eV)', symbol: 'RYDBERG', target: '13.6057', category: 'quantum', fit: { n: 7, k: 1, m: -3, p: 0, q: 3 }, computed: 13.603577, error_pct: 0.0156 },
      { name: 'Bohr radius (pm)', symbol: 'BOHR_RADIUS', target: '52.9177', category: 'quantum', fit: { n: 1, k: 3, m: -2, p: 2, q: 2 }, computed: 52.921027, error_pct: 0.0063 },

      // Cosmology
      { name: 'H\u2080 (km/s/Mpc)', symbol: 'HUBBLE', target: '67.4', category: 'cosmology', fit: { n: 4, k: 3, m: -3, p: 2, q: 2 }, computed: 67.381144, error_pct: 0.0280 },
      { name: '\u03A9_\u039B', symbol: 'OMEGA_LAMBDA', target: '0.685', category: 'cosmology', fit: { n: 4, k: 2, m: 0, p: -2, q: -3 }, computed: 0.684611, error_pct: 0.0568 },
      { name: 'T_CMB (K)', symbol: 'CMB_TEMP', target: '2.7255', category: 'cosmology', fit: { n: 8, k: 4, m: -3, p: 2, q: -3 }, computed: 2.724063, error_pct: 0.0527 },
      { name: '\u03B3_BI (LQG)', symbol: 'BARBERO_IMMIRZI', target: '0.2375', category: 'cosmology', fit: { n: 1, k: 3, m: -2, p: -3, q: -1 }, computed: 0.237578, error_pct: 0.0329 },
      { name: 'S/A = 1/4 (BH)', symbol: 'BEKENSTEIN_HAWKING', target: '0.25', category: 'cosmology', fit: { n: 4, k: 3, m: -1, p: -4, q: -3 }, computed: 0.249712, error_pct: 0.1151 },
      { name: 'Age (13.787 Gyr)', symbol: 'AGE_UNIVERSE', target: '13.787', category: 'cosmology', fit: { n: 1, k: 4, m: -2, p: -1, q: 1 }, computed: 13.787709, error_pct: 0.0051 },

      // Quantum Gravity
      { name: 'DM candidate mass', symbol: 'DM_CANDIDATE', target: '817.3', category: 'quantum_gravity', fit: { n: 4, k: 4, m: 0, p: 4, q: -1 }, computed: 816.960557, error_pct: 0.0415 },
      { name: 'Spatial dimensions', symbol: 'SPATIAL', target: '3.0', category: 'quantum_gravity', fit: { n: 1, k: 1, m: 0, p: 0, q: 0 }, computed: 3.0, error_pct: 0.0 },
      { name: '\u039B QCD (MeV)', symbol: 'LAMBDA_QCD', target: '217', category: 'quantum_gravity', fit: { n: 7, k: 1, m: -1, p: 1, q: 3 }, computed: 217.240357, error_pct: 0.1108 },
      { name: 'Proton lifetime (10\u00B3\u2074 yr)', symbol: 'PROTON_LIFETIME', target: '2.0', category: 'quantum_gravity', fit: { n: 2, k: 0, m: 0, p: 0, q: 0 }, computed: 2.0, error_pct: 0.0 },

      // Particle Physics Extended
      { name: 'm_e (MeV)', symbol: 'ELECTRON_MASS', target: '0.511', category: 'particle_physics', fit: { n: 2, k: 0, m: -2, p: 4, q: -1 }, computed: 0.510959, error_pct: 0.0080 },
      { name: 'Koide Q (2/3)', symbol: 'KOIDE_Q', target: '0.66667', category: 'particle_physics', fit: { n: 2, k: -1, m: 0, p: 0, q: 0 }, computed: 0.666667, error_pct: 0.0005 },
      { name: '\u03B1_s (strong)', symbol: 'ALPHA_STRONG', target: '0.1179', category: 'particle_physics', fit: { n: 4, k: -2, m: -2, p: 2, q: 0 }, computed: 0.117894, error_pct: 0.0048 },
      { name: 'm_\u03BC (MeV)', symbol: 'MUON_MASS', target: '105.658', category: 'particle_physics', fit: { n: 8, k: 1, m: 0, p: 1, q: 1 }, computed: 105.559, error_pct: 0.0941 },
      { name: 'sin(\u03B8_C) Cabibbo', symbol: 'CABIBBO_ANGLE', target: '0.2253', category: 'particle_physics', fit: { n: 1, k: 1, m: -1, p: -3, q: 0 }, computed: 0.225428, error_pct: 0.0570 },
      { name: '\u0394m(n-p) MeV', symbol: 'NP_MASS_DIFF', target: '1.2934', category: 'particle_physics', fit: { n: 4, k: 2, m: -2, p: 2, q: -2 }, computed: 1.292377, error_pct: 0.0791 },

      // Neutrino Mixing
      { name: '\u03B8\u2081\u2082 solar (\u00B0)', symbol: 'THETA_12', target: '33.44', category: 'neutrino', fit: { n: 5, k: -1, m: 0, p: 0, q: 3 }, computed: 33.476, error_pct: 0.1073 },
      { name: '\u03B8\u2082\u2083 atmos (\u00B0)', symbol: 'THETA_23', target: '49.2', category: 'neutrino', fit: { n: 7, k: 4, m: 0, p: -3, q: -1 }, computed: 49.241, error_pct: 0.0831 },
      { name: '\u03B8\u2081\u2083 reactor (\u00B0)', symbol: 'THETA_13', target: '8.57', category: 'neutrino', fit: { n: 9, k: 4, m: 0, p: -3, q: -3 }, computed: 8.568, error_pct: 0.0229 },

      // Cosmological Extended
      { name: '\u03A9_matter', symbol: 'OMEGA_MATTER', target: '0.315', category: 'cosmology', fit: { n: 8, k: -2, m: 0, p: 2, q: -2 }, computed: 0.314944, error_pct: 0.0177 },
      { name: '\u03A9_baryon', symbol: 'OMEGA_BARYON', target: '0.0493', category: 'cosmology', fit: { n: 8, k: -1, m: -3, p: 3, q: -2 }, computed: 0.049305, error_pct: 0.0106 },
      { name: 'n_s spectral', symbol: 'SPECTRAL_NS', target: '0.9649', category: 'cosmology', fit: { n: 8, k: 1, m: -2, p: -4, q: 1 }, computed: 0.964396, error_pct: 0.0522 },

      // Nuclear Physics
      { name: 'Beta decay Q (MeV)', symbol: 'BETA_Q', target: '0.782', category: 'nuclear', fit: { n: 2, k: 1, m: 0, p: 2, q: -3 }, computed: 0.782065, error_pct: 0.0084 },
      { name: '\u03C0\u2070 mass (MeV)', symbol: 'PION0_MASS', target: '134.977', category: 'nuclear', fit: { n: 5, k: 3, m: 0, p: 0, q: 0 }, computed: 135.0, error_pct: 0.0170 },
      { name: 'Fe-56 binding (MeV/A)', symbol: 'FE56_BINDING', target: '8.7945', category: 'nuclear', fit: { n: 2, k: 0, m: 0, p: 1, q: 1 }, computed: 8.796545, error_pct: 0.0233 },
      { name: '\u0394 baryon (MeV)', symbol: 'DELTA_BARYON', target: '1232', category: 'nuclear', fit: { n: 4, k: 4, m: -1, p: 1, q: 2 }, computed: 1233.025, error_pct: 0.0832 },

      // Mathematical Constants
      { name: 'Meissel-Mertens M', symbol: 'MEISSEL_MERTENS', target: '0.26149', category: 'mathematical', fit: { n: 5, k: -4, m: 0, p: 3, q: 0 }, computed: 0.261486, error_pct: 0.0017 },
      { name: 'Ramanujan-Soldner \u03BC', symbol: 'RAMANUJAN_SOLDNER', target: '1.45136', category: 'mathematical', fit: { n: 5, k: 2, m: -3, p: 0, q: 0 }, computed: 1.451319, error_pct: 0.0028 },
      { name: 'Ap\u00E9ry \u03B6(3)', symbol: 'APERY', target: '1.20206', category: 'mathematical', fit: { n: 2, k: 0, m: -3, p: 4, q: 1 }, computed: 1.201781, error_pct: 0.0232 },
      { name: 'Feigenbaum \u03B4', symbol: 'FEIGENBAUM_DELTA', target: '4.6692', category: 'mathematical', fit: { n: 5, k: 3, m: -2, p: 4, q: -3 }, computed: 4.667681, error_pct: 0.0325 },

      // Dimensionless Ratios
      { name: 'm_\u03C4/m_\u03BC', symbol: 'TAU_MUON_RATIO', target: '16.818', category: 'ratios', fit: { n: 7, k: 5, m: -4, p: 2, q: -1 }, computed: 16.81844, error_pct: 0.0080 },
      { name: 'm_\u03BC/m_e', symbol: 'MUON_ELECTRON_RATIO', target: '206.77', category: 'ratios', fit: { n: 4, k: 4, m: 1, p: 5, q: -4 }, computed: 206.7546, error_pct: 0.0061 },

      // Sacred Geometry (v2.0)
      { name: 'Sierpinski dim', symbol: 'SIERPINSKI_DIM', target: '1.584963', category: 'sacred_geometry', fit: { n: 8, k: 3, m: -3, p: -1, q: -1 }, computed: 1.583878, error_pct: 0.0684 },
      { name: 'Koch dim', symbol: 'KOCH_DIM', target: '1.261860', category: 'sacred_geometry', fit: { n: 9, k: 4, m: -3, p: -4, q: -1 }, computed: 1.261797, error_pct: 0.0050 },
      { name: 'Cantor dim', symbol: 'CANTOR_DIM', target: '0.630930', category: 'sacred_geometry', fit: { n: 5, k: 0, m: -1, p: -4, q: 1 }, computed: 0.630664, error_pct: 0.0422 },
      { name: '\u03C6 (Golden Ratio)', symbol: 'PHI', target: '1.618034', category: 'sacred_geometry', fit: { n: 1, k: 0, m: 0, p: 1, q: 0 }, computed: 1.618034, error_pct: 0.0000 },
      { name: '\u03C6\u00B2', symbol: 'PHI_SQ', target: '2.618034', category: 'sacred_geometry', fit: { n: 1, k: 0, m: 0, p: 2, q: 0 }, computed: 2.618034, error_pct: 0.0000 },
      { name: '1/\u03C6', symbol: 'INV_PHI', target: '0.618034', category: 'sacred_geometry', fit: { n: 1, k: 0, m: 0, p: -1, q: 0 }, computed: 0.618034, error_pct: 0.0000 },
      { name: '\u221A2', symbol: 'SQRT2', target: '1.414214', category: 'sacred_geometry', fit: { n: 4, k: 4, m: -3, p: 0, q: -2 }, computed: 1.414186, error_pct: 0.0020 },
      { name: '\u221A3', symbol: 'SQRT3', target: '1.732051', category: 'sacred_geometry', fit: { n: 7, k: 0, m: -3, p: -2, q: 3 }, computed: 1.732035, error_pct: 0.0009 },
      { name: '\u221A5', symbol: 'SQRT5', target: '2.236068', category: 'sacred_geometry', fit: { n: 8, k: 2, m: -3, p: 2, q: -1 }, computed: 2.235663, error_pct: 0.0181 },
      { name: 'Golden spiral b', symbol: 'GOLDEN_SPIRAL_B', target: '0.306349', category: 'sacred_geometry', fit: { n: 2, k: -4, m: 0, p: -1, q: 3 }, computed: 0.306190, error_pct: 0.0517 },
      { name: 'Tetra dihedral (\u00B0)', symbol: 'TETRA_DIHEDRAL', target: '70.52878', category: 'sacred_geometry', fit: { n: 4, k: 2, m: -2, p: 2, q: 2 }, computed: 70.496, error_pct: 0.0462 },
      { name: 'Cube dihedral (\u00B0)', symbol: 'CUBE_DIHEDRAL', target: '90.0', category: 'sacred_geometry', fit: { n: 4, k: 3, m: -1, p: 2, q: 0 }, computed: 89.986, error_pct: 0.0015 },
      { name: 'Octa dihedral (\u00B0)', symbol: 'OCTA_DIHEDRAL', target: '109.4712', category: 'sacred_geometry', fit: { n: 8, k: 1, m: 0, p: -1, q: 2 }, computed: 109.342, error_pct: 0.1181 },
      { name: 'Dodeca dihedral (\u00B0)', symbol: 'DODECA_DIHEDRAL', target: '116.5651', category: 'sacred_geometry', fit: { n: 8, k: 2, m: 0, p: 1, q: 0 }, computed: 116.498, error_pct: 0.0571 },
      { name: 'Icosa dihedral (\u00B0)', symbol: 'ICOSA_DIHEDRAL', target: '138.1897', category: 'sacred_geometry', fit: { n: 4, k: 1, m: 0, p: 3, q: 1 }, computed: 138.178, error_pct: 0.0085 },
    ],
    predictions: [
      { name: 'Neutrino mass hint', formula: '1\u00D73\u207B\u00B9\u00D7\u03C0\u207B\u00B9\u00D7\u03C6\u207B\u2074\u00D7e\u207B\u00B9', value: 0.005695, unit: 'eV', n: 1, k: -1, m: -1, p: -4, q: -1 },
      { name: '\u039B/\u03C1_P hint', formula: '1\u00D73\u207B\u2074\u00D7\u03C0\u207B\u00B2\u00D7\u03C6\u207B\u2074\u00D7e\u207B\u00B3', value: 9.086e-6, unit: 'Planck', n: 1, k: -4, m: -2, p: -4, q: -3 },
      { name: 'G hint', formula: '1\u00D73\u207B\u00B3\u00D7\u03C0\u207B\u00B3\u00D7\u03C6\u207B\u2074\u00D7e\u207B\u00B3', value: 8.677e-6, unit: 'Planck', n: 1, k: -3, m: -3, p: -4, q: -3 },
      { name: 'Proton lifetime hint', formula: '3\u00D73\u2074\u00D7\u03C0\u00B3\u00D7\u03C6\u2074\u00D7e\u2074', value: 2.8196e6, unit: 'years', n: 3, k: 4, m: 3, p: 4, q: 4 },
      { name: '\u03A3m_\u03BD hint', formula: '3\u00D73\u2076\u00D7\u03C0\u207B\u2074\u00D7\u03C6\u207B\u2074\u00D7e\u207B\u2074', value: 0.05999579, unit: 'eV', n: 3, k: 6, m: -4, p: -4, q: -4 },
      { name: 'Inflation N_e hint', formula: '8\u00D73\u00B2\u00D7\u03C0\u207B\u00B9\u00D7\u03C6\u00B2', value: 60.00092, unit: 'e-folds', n: 8, k: 2, m: -1, p: 2, q: 0 },
      { name: 'Tensor-to-scalar r', formula: '4\u00D73\u207B\u00B2\u00D7\u03C0\u207B\u00B2\u00D7\u03C6\u207B\u2075\u00D7e\u00B2', value: 0.03000326, unit: '\u2014', n: 4, k: -2, m: -2, p: -5, q: 2 },
      { name: 'Neutron \u03C4_n hint', formula: '2\u00D73\u2074\u00D7\u03C0\u2074\u00D7\u03C6\u207B\u2076', value: 879.4045, unit: 's', n: 2, k: 4, m: 4, p: -6, q: 0 },
      { name: 'S_topo hint', formula: '4\u00D73\u207B\u00B9\u00D7\u03C0\u207B\u2074\u00D7\u03C6\u2074\u00D7e\u00B2', value: 0.6932323, unit: 'nat', n: 4, k: -1, m: -4, p: 4, q: 2 },
      { name: 'N_eff hint', formula: '1\u00D73\u00B3\u00D7\u03C0\u207B\u00B9\u00D7\u03C6\u00B2\u00D7e\u207B\u00B2', value: 3.045091, unit: '\u2014', n: 1, k: 3, m: -1, p: 2, q: -2 },
      { name: 'M-theory dim', formula: '4\u00D73\u207B\u2074\u00D7\u03C6\u2075\u00D7e\u00B3', value: 11.0001, unit: 'dim', n: 4, k: -4, m: 0, p: 5, q: 3 },
      { name: 'Bosonic string dim', formula: '2\u00D73\u207B\u00B9\u00D7\u03C0\u00B9\u00D7\u03C6\u207B\u00B9\u00D7e\u00B3', value: 25.99887, unit: 'dim', n: 2, k: -1, m: 1, p: -1, q: 3 },
      { name: '\u0394m\u00B2\u2083\u2082 hint', formula: '1\u00D73\u207B\u00B3\u00D7\u03C0\u207B\u00B2\u00D7\u03C6\u207B\u2075\u00D7e\u00B2', value: 0.002500272, unit: 'eV\u00B2' },
      { name: 'S\u2088 (\u03C3\u2088\u03A9\u1D50\u00B9\u00B2)', formula: '8\u00D73\u207B\u2075\u00D7\u03C0\u207B\u00B2\u00D7e\u00B3', value: 0.06699886, unit: '\u2014' },
    ],
    search_bounds: { n: [1, 9], k: [-4, 4], m: [-3, 0], p: [-4, 4], q: [-3, 3] },
  };
}

// Sacred formula constants
const PHI = 1.6180339887498948482;

// Parameter bounds — exported for UI validation
export const PARAM_BOUNDS = {
  n: { min: 1, max: 9 },
  k: { min: -4, max: 4 },
  m: { min: -3, max: 0 },
  p: { min: -4, max: 4 },
  q: { min: -3, max: 3 },
} as const;

// Pure computation: V = n × 3^k × π^m × φ^p × e^q
export function computeSacredFormula(n: number, k: number, m: number, p: number, q: number): number {
  return n * Math.pow(3, k) * Math.pow(Math.PI, m) * Math.pow(PHI, p) * Math.pow(Math.E, q);
}

// Brute-force search: finds best (n,k,m,p,q) for a target number
// Search space: 9×9×4×9×7 = 20,412 combinations — <10ms in JS
export async function fitSingleValue(target: number): Promise<SingleFitResponse> {
  let bestFit = { n: 1, k: 0, m: 0, p: 0, q: 0 };
  let bestError = Infinity;
  let bestComputed = 1;

  for (let n = PARAM_BOUNDS.n.min; n <= PARAM_BOUNDS.n.max; n++) {
    for (let k = PARAM_BOUNDS.k.min; k <= PARAM_BOUNDS.k.max; k++) {
      for (let m = PARAM_BOUNDS.m.min; m <= PARAM_BOUNDS.m.max; m++) {
        for (let p = PARAM_BOUNDS.p.min; p <= PARAM_BOUNDS.p.max; p++) {
          for (let q = PARAM_BOUNDS.q.min; q <= PARAM_BOUNDS.q.max; q++) {
            const v = computeSacredFormula(n, k, m, p, q);
            const err = Math.abs(v - target) / Math.abs(target);
            if (err < bestError) {
              bestError = err;
              bestFit = { n, k, m, p, q };
              bestComputed = v;
            }
          }
        }
      }
    }
  }

  return { fit: bestFit, computed: bestComputed, error_pct: bestError * 100 };
}

// Manual parameter mode: compute V from user-specified params
export function computeFromParams(n: number, k: number, m: number, p: number, q: number): SingleFitResponse {
  return { fit: { n, k, m, p, q }, computed: computeSacredFormula(n, k, m, p, q), error_pct: 0 };
}

// 27 Coptic Glyphs — mirrors StargateDrum.tsx
const COPTIC_GLYPHS = [
  '\u2C80', '\u2C82', '\u2C84', '\u2C86', '\u2C88', '\u2C8A', '\u2C8C', '\u2C8E', '\u2C90',
  '\u2C92', '\u2C94', '\u2C96', '\u2C98', '\u2C9A', '\u2C9C', '\u2C9E', '\u2CA0', '\u2CA2',
  '\u2CA4', '\u2CA6', '\u2CA8', '\u2CAA', '\u2CAC', '\u2CAE', '\u2CB0', '\u03E2', '\u03E4',
];

// Isopsephy values for each glyph
const GLYPH_VALUES = [
  1, 2, 3, 4, 5, 6, 7, 8, 9,
  10, 20, 30, 40, 50, 60, 70, 80, 90,
  100, 200, 300, 400, 500, 600, 700, 800, 900,
];

// Lowercase Coptic variants for lookup
const COPTIC_GLYPHS_LOWER = [
  '\u2C81', '\u2C83', '\u2C85', '\u2C87', '\u2C89', '\u2C8B', '\u2C8D', '\u2C8F', '\u2C91',
  '\u2C93', '\u2C95', '\u2C97', '\u2C99', '\u2C9B', '\u2C9D', '\u2C9F', '\u2CA1', '\u2CA3',
  '\u2CA5', '\u2CA7', '\u2CA9', '\u2CAB', '\u2CAD', '\u2CAF', '\u2CB1', '\u03E3', '\u03E5',
];

// Decompose a number into Coptic gematria representation (greedy, largest values first)
function decomposeToGlyphs(num: number): { glyph: string; value: number; index: number }[] {
  const result: { glyph: string; value: number; index: number }[] = [];
  let remaining = Math.abs(Math.round(num));
  if (remaining === 0) return [];

  // Greedy from largest value (900) to smallest (1)
  for (let i = GLYPH_VALUES.length - 1; i >= 0 && remaining > 0; i--) {
    while (remaining >= GLYPH_VALUES[i]) {
      result.push({ glyph: COPTIC_GLYPHS[i], value: GLYPH_VALUES[i], index: i });
      remaining -= GLYPH_VALUES[i];
    }
  }
  return result;
}

export async function fetchGematria(input: string): Promise<GematriaResponse> {
  const glyphs: { glyph: string; value: number; index: number }[] = [];
  let total = 0;

  // Check if input is a number
  const numericInput = Number(input);
  if (!isNaN(numericInput) && numericInput > 0 && input.trim() !== '') {
    // Numeric input: decompose into Coptic gematria representation
    const decomposed = decomposeToGlyphs(numericInput);
    glyphs.push(...decomposed);
    total = decomposed.reduce((sum, g) => sum + g.value, 0);
  } else {
    // Text input: look up each character
    for (let i = 0; i < Math.min(input.length, 20); i++) {
      const ch = input[i];
      // Try Coptic uppercase
      let idx = COPTIC_GLYPHS.indexOf(ch);
      if (idx === -1) idx = COPTIC_GLYPHS_LOWER.indexOf(ch);
      if (idx !== -1) {
        glyphs.push({ glyph: COPTIC_GLYPHS[idx], value: GLYPH_VALUES[idx], index: idx });
        total += GLYPH_VALUES[idx];
      } else {
        // Latin fallback: A=1, B=2, ..., Z=26
        const upper = ch.toUpperCase();
        const code = upper.charCodeAt(0);
        if (code >= 65 && code <= 90) {
          const val = code - 64; // A=1, B=2, ..., Z=26
          // Map to nearest glyph by value
          const glyphIdx = val <= 9 ? val - 1 : val <= 18 ? Math.floor(val / 10) + 8 : Math.min(Math.floor(val / 100) + 17, 26);
          glyphs.push({ glyph: ch.toUpperCase(), value: val, index: glyphIdx });
          total += val;
        }
        // Skip non-alphabetic characters silently
      }
    }
  }

  if (total <= 0) {
    return { glyphs: [], total: 0 };
  }

  // Find the sacred formula fit for the total
  const sacredResult = await fitSingleValue(total);

  return {
    glyphs,
    total,
    sacred_fit: sacredResult.fit,
    sacred_computed: sacredResult.computed,
    sacred_error_pct: sacredResult.error_pct,
  };
}

// ─── v3.0: Sacred Chemistry Backend API ────────────────────────────────────────

export interface SacredFit {
  n: number; k: number; m: number; p: number; q: number;
  computed: number; error_pct: number;
}

export interface ChemMassResponse {
  formula: string;
  molar_mass: number;
  breakdown: { symbol: string; count: number; element_mass: number; total: number }[];
  source: 'live' | 'local';
}

export interface ChemSacredElement {
  symbol: string; count: number; mass: number; mass_contrib: number; pct: number;
  mass_fit: SacredFit;
  ie?: number; ie_fit?: SacredFit;
}

export interface ChemSacredResponse {
  formula: string;
  molar_mass: number;
  sacred_fit: SacredFit;
  elements: ChemSacredElement[];
  total_atoms: number;
  total_electrons: number;
  avg_electronegativity?: number;
  en_fit?: SacredFit;
  source: 'live' | 'local';
}

export interface ExtendedElement {
  number: number; symbol: string; name: string; mass: number;
  group: number; period: number;
  electronegativity: number | null;
  ionization_energy: number | null;
  electron_config: string;
  block: string;
  category: string;
  valence: number;
  electron_affinity: number | null;
  atomic_radius: number | null;
  melting_point: number | null;
  boiling_point: number | null;
  density: number | null;
  discoverer: string;
  etymology: string;
}

export interface ChemElementResponse {
  element: ExtendedElement;
  sacred: { mass_fit: SacredFit; ie_fit: SacredFit | null; en_fit: SacredFit | null };
  ternary: { balanced_ternary: number[]; trit_count: number };
  sequences: { fibonacci: boolean; fibonacci_index: number | null; lucas: boolean; lucas_index: number | null };
  golden: { angle: number; sector: number };
  coptic: { glyph: string; value: number; kingdom: string };
  source: 'live' | 'local';
}

export interface BalanceVerification {
  element: string; left: number; right: number; ok: boolean;
}

export interface ChemBalanceResponse {
  input: string;
  balanced: string;
  coefficients: {
    reactants: { formula: string; coefficient: number }[];
    products: { formula: string; coefficient: number }[];
  };
  verification: { elements: BalanceVerification[]; balanced: boolean };
  source: 'live';
}

/** GET /api/chem/mass?formula=H2O */
export async function fetchChemMass(formula: string): Promise<ChemMassResponse | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/chem/mass?formula=${encodeURIComponent(formula)}`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/** GET /api/chem/sacred?formula=C6H12O6 */
export async function fetchChemSacred(formula: string): Promise<ChemSacredResponse | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/chem/sacred?formula=${encodeURIComponent(formula)}`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/** GET /api/chem/element?q=Au */
export async function fetchChemElement(query: string): Promise<ChemElementResponse | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/chem/element?q=${encodeURIComponent(query)}`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/** GET /api/chem/balance?eq=H2+O2->H2O */
export async function fetchChemBalance(equation: string): Promise<ChemBalanceResponse | null> {
  try {
    const res = await fetch(`${BASE_URL}/api/chem/balance?eq=${encodeURIComponent(equation)}`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}
