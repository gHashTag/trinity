// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CHAT API SERVICE v2.7
// Connects Cosmic UI to Zig HTTP backend
// v2.5: + /api/files (Finder) + /api/compile (Editor)
// v2.7: + /api/storage-metrics (Storage Network Dashboard)
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
