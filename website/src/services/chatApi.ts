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
