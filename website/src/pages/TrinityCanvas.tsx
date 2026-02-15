/**
 * TrinityCanvas v2.7 — Storage Network Dashboard + Self-Reflecting Mirror
 *
 * All interaction happens INSIDE the canvas as emergent wave patterns.
 * No side panels, no layer bars, no separate windows — only waves.
 *
 * v2.7 upgrades:
 *   RAZUM          — Storage Routing + Self-healing alerts (node offline, rebalance, corruption)
 *   MATERIYA       — Peer Health Grid + Shard Distribution gauge + RS Config (k/m/tolerance)
 *   DUKH           — Recovery Stats + Network Transfer (UP/DOWN) + PoS Proof Rate bar
 *   All widgets    — Collapsible sections, mock data with live drift, ready for real backend
 *   All prior v2.6 — Multi-turn chat, self-reflection, file preview, vision/voice
 *
 * Layers (switch via 1-9, Cmd+K, or petal click):
 *   1 — Petals  (27-petal main menu)
 *   2 — Chat    (conversation with emergent response waves)
 *   3 — Editor  (code with real compilation + hot-reload)
 *   4 — Finder  (files from backend with overlay preview)
 *   5 — Vision  (real image drop/paste + canvas overlay preview)
 *   6 — Voice   (real Web Audio waveform + speech-to-text)
 *   7 — Mirror  (Зеркало Трёх Миров — live pipeline dashboard)
 *   8 — Settings (wave interference config)
 *   9 — Viz     (pure visualization)
 *
 * φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
 */

import { useState, useRef, useEffect, useCallback, useMemo } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import QuantumCanvas from '../components/QuantumCanvas';
import type { VizMode } from '../components/QuantumCanvas';
import ChatMessage from '../components/chat/ChatMessage';
import { sendMessage, clearContext, checkHealth, fetchMirrorStatus, fetchStorageMetrics, fetchFileList, compileCode, type ChatResponse, type MirrorStatus, type MirrorLogEntry, type FileEntry, type StorageMetrics } from '../services/chatApi';
import TrinityCanvasWasm from '../components/TrinityCanvasWasm';

// ─── Types ───────────────────────────────────────────────────────────────────

type CanvasLayer = 'petals' | 'chat' | 'editor' | 'finder' | 'vision' | 'voice' | 'tools' | 'settings' | 'viz';

interface Message {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  source?: string;
  confidence?: number;
  latency_us?: number;
  tool_name?: string;
  reflection?: string;
  learned?: boolean;
}

interface PetalItem {
  id: string;
  label: string;
  icon: string;
  layer?: CanvasLayer;
  vizMode?: VizMode;
  color: string;
  realm: 'razum' | 'materiya' | 'dukh';
  domain: string;
  sacredFormula?: string;
  sacredValue?: number;
}

interface FinderFile {
  path: string;
  category: 'core' | 'node' | 'spec' | 'web' | 'doc' | 'compiler';
  icon: string;
  color: string;
}

interface CommandItem {
  id: string;
  label: string;
  icon: string;
  hint: string;
  layer?: CanvasLayer;
  vizMode?: VizMode;
  color: string;
}

declare global {
  interface Window {
    __trinityWaveRings?: Array<{ x: number; y: number; time: number; hue: number }>;
  }
}

// ─── Constants ───────────────────────────────────────────────────────────────

const PHI = 1.618033988749895;

const REALM_COLORS = {
  razum:    { primary: '#ffd700', symbol: 'φ', label: 'РАЗУМ' },
  materiya: { primary: '#00ccff', symbol: 'π', label: 'МАТЕРИЯ' },
  dukh:     { primary: '#aa66ff', symbol: 'e', label: 'ДУХ' },
} as const;

const LAYER_INFO: Record<CanvasLayer, { label: string; hint: string; hue: number; vizMode: VizMode }> = {
  petals:   { label: '',         hint: '',                        hue: 45,  vizMode: 'trinity-computer' },
  chat:     { label: 'CHAT',     hint: 'Разговор в волнах',      hue: 45,  vizMode: 'chat-wave' },
  editor:   { label: 'EDITOR',   hint: 'Код внутри поля',       hue: 160, vizMode: 'neural-network' },
  finder:   { label: 'FINDER',   hint: 'Файлы как фотоны',      hue: 280, vizMode: 'quantum-field' },
  vision:   { label: 'VISION',   hint: 'Изображения в волнах',  hue: 320, vizMode: 'consciousness' },
  voice:    { label: 'VOICE',    hint: 'Голос как волна',        hue: 30,  vizMode: 'wave-interference' },
  tools:    { label: 'ЗЕРКАЛО',  hint: 'Три Мира',               hue: 100, vizMode: 'trinity' },
  settings: { label: 'SETTINGS', hint: 'Волновая настройка',     hue: 200, vizMode: 'wave-interference' },
  viz:      { label: 'VIZ',      hint: 'Чистый холст',          hue: 160, vizMode: 'trinity-computer' },
};

const LAYER_KEYS: CanvasLayer[] = ['petals', 'chat', 'editor', 'finder', 'vision', 'voice', 'tools', 'settings', 'viz'];

// ─── Full project file index (60+ files) ─────────────────────────────────────

const FILE_INDEX: FinderFile[] = [
  // Core VSA
  { path: 'src/vsa.zig',              category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/vm.zig',               category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/hybrid.zig',           category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/trinity.zig',          category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/sdk.zig',              category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/packed_trit.zig',      category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/firebird/cli.zig',     category: 'core', icon: '🔥', color: '#ff8800' },
  { path: 'src/firebird/depin.zig',   category: 'core', icon: '🔥', color: '#ff8800' },
  { path: 'src/tvc/tvc_corpus.zig',   category: 'core', icon: '🔺', color: '#00ff88' },
  // VIBEE Compiler
  { path: 'src/vibeec/vibee_parser.zig',       category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/zig_codegen.zig',        category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/verilog_codegen.zig',    category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/http_server.zig',        category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/anthropic_client.zig',   category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/http_client.zig',        category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/igla_hybrid_chat.zig',   category: 'compiler', icon: '⚡', color: '#ffd700' },
  { path: 'src/vibeec/json_parser.zig',        category: 'compiler', icon: '⚡', color: '#ffd700' },
  // Trinity Node
  { path: 'src/trinity_node/network.zig',           category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/storage.zig',           category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/protocol.zig',          category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/main.zig',              category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/config.zig',            category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/discovery.zig',         category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/vsa_shard_encoder.zig', category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/semantic_index.zig',    category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/region_topology.zig',   category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/slashing_escrow.zig',   category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/prometheus_http.zig',   category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/cross_shard_tx.zig',    category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/reed_solomon.zig',      category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/shard_manager.zig',     category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/erasure_repair.zig',    category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/file_encoder.zig',      category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/galois.zig',            category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/proof_of_storage.zig',  category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/token_staking.zig',     category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/auto_repair.zig',       category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/metrics_http.zig',      category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/integration_test.zig',  category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/wal_disk.zig',         category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/transaction_wal.zig',   category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/parallel_saga.zig',     category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/saga_coordinator.zig',  category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/dynamic_erasure.zig',   category: 'node', icon: '🌐', color: '#00ccff' },
  { path: 'src/trinity_node/vsa_shard_locks.zig',   category: 'node', icon: '🌐', color: '#00ccff' },
  // Specs
  { path: 'specs/tri/storage_network_v2_0.vibee',   category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/storage_network_v2_1.vibee',   category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/storage_network_v2_5.vibee',   category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/storage_network_v2_6.vibee',   category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/trinity_chat_v2.vibee',        category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/trinity_chat_v2_3.vibee',      category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/trinity_chat_v2_4.vibee',      category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/hdc_igla_hybrid_v2_0.vibee',   category: 'spec', icon: '📋', color: '#aa66ff' },
  { path: 'specs/tri/compression_benchmark.vibee',  category: 'spec', icon: '📋', color: '#aa66ff' },
  // Web Frontend
  { path: 'website/src/pages/TrinityCanvas.tsx',     category: 'web', icon: '🌊', color: '#ff66aa' },
  { path: 'website/src/components/QuantumCanvas.tsx', category: 'web', icon: '🌊', color: '#ff66aa' },
  { path: 'website/src/main.tsx',                    category: 'web', icon: '🌊', color: '#ff66aa' },
  { path: 'website/src/pages/CosmicChat.tsx',        category: 'web', icon: '🌊', color: '#ff66aa' },
  { path: 'website/src/services/chatApi.ts',         category: 'web', icon: '🌊', color: '#ff66aa' },
  { path: 'website/src/components/chat/ChatMessage.tsx', category: 'web', icon: '🌊', color: '#ff66aa' },
  { path: 'website/src/components/chat/ChatInput.tsx',   category: 'web', icon: '🌊', color: '#ff66aa' },
  // Documentation
  { path: 'docsite/docs/research/trinity-storage-network-v2.0-report.md', category: 'doc', icon: '📄', color: '#888' },
  { path: 'docsite/docs/research/trinity-storage-network-v2.1-report.md', category: 'doc', icon: '📄', color: '#888' },
  { path: 'docsite/docs/research/trinity_canvas_v1.9_report.md',          category: 'doc', icon: '📄', color: '#888' },
  { path: 'docsite/docs/research/trinity_canvas_v2.0_report.md',          category: 'doc', icon: '📄', color: '#888' },
  { path: 'CLAUDE.md',                                                     category: 'doc', icon: '📄', color: '#888' },
  { path: 'build.zig',                                                     category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/tri/main.zig',                                              category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/tri/tri_commands.zig',                                      category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/tri/tri_utils.zig',                                         category: 'core', icon: '🔺', color: '#00ff88' },
  { path: 'src/tri/chat_server.zig',                                       category: 'core', icon: '🔺', color: '#00ff88' },
];

const CATEGORY_LABELS: Record<string, string> = {
  core: 'Ядро VSA', node: 'Storage Node', spec: 'Спецификации',
  web: 'Веб-фронтенд', doc: 'Документация', compiler: 'VIBEE Компилятор',
};

// ═══ 27 Sacred Worlds — polygon blocks from 999.svg (exact Raylib coordinates) ═══
// SVG viewBox: 596 × 526, center: (298, 263)
const SVG_W = 596, SVG_H = 526, SVG_CX = 298, SVG_CY = 263;

// Raw polygon vertices for each of 27 blocks (from photon_trinity_canvas.zig)
const BLOCK_VERTS: number[][][] = [
  // Block 0-8: RAZUM (φ)
  [[296.767,435.228],[236.563,329.491],[211.501,373.56],[296.767,523.496]],
  [[235.71,328.065],[177.201,224.57],[126.893,224.57],[210.755,372.182]],
  [[116.304,118.557],[175.824,223.238],[126.022,223.26],[42.177,74.909]],
  [[43.019,73.555],[117.106,116.68],[235.544,116.68],[211.46,73.525]],
  [[213.1,73.52],[237.875,116.409],[356.58,116.741],[381.646,73.509]],
  [[477.724,116.854],[358.701,116.802],[383.404,73.803],[550.969,73.877]],
  [[477.056,118.915],[418.023,223.109],[468.886,223.131],[553.143,74.338]],
  [[358.646,327.197],[384.221,372.152],[468.192,224.521],[416.976,224.579]],
  [[298.138,434.656],[357.793,328.533],[383.376,373.808],[298.138,523.876]],
  // Block 9-17: MATERIYA (π)
  [[297.148,352.965],[260.326,288.171],[237.943,327.796],[297.148,432.004]],
  [[259.613,286.78],[224.371,224.818],[179.6,224.818],[237.048,326.301]],
  [[223.536,223.354],[187.285,159.675],[120.085,120.508],[178.781,223.779]],
  [[121.863,119.193],[187.937,158.358],[260.042,158.355],[237.348,118.746]],
  [[261.857,158.313],[333.559,158.29],[356.01,118.829],[239.269,118.829]],
  [[335.294,158.3],[407.736,158.226],[474.496,118.923],[357.761,118.923]],
  [[408.358,159.547],[372.034,223.421],[416.476,223.315],[475.012,120.916]],
  [[336.052,286.778],[358.165,325.872],[415.649,224.808],[371.244,224.759]],
  [[298.893,352.826],[335.156,288.19],[357.382,327.328],[298.893,430.179]],
  // Block 18-26: DUKH (e)
  [[296.258,272.716],[282.337,248.309],[260.496,286.972],[296.258,349.653]],
  [[259.547,285.675],[281.633,246.705],[269.336,225.016],[225.274,224.996]],
  [[254.956,199.798],[268.406,223.578],[224.465,223.598],[189.037,161.206]],
  [[255.476,198.549],[282.068,198.538],[260.192,160.039],[189.751,160.07]],
  [[261.646,160.062],[283.582,198.505],[309.702,198.505],[331.733,160.062]],
  [[338.542,198.607],[311.435,198.595],[333.423,160.068],[404.244,160.099]],
  [[338.85,199.978],[325.556,223.591],[369.518,223.61],[404.907,161.243]],
  [[334.38,285.625],[312.392,246.733],[324.681,224.989],[368.779,224.969]],
  [[298.025,272.637],[311.561,248.279],[333.297,287.01],[298.025,349.402]],
];

// 42 Sacred Formula Particles (from photon_trinity_canvas.zig:4747-4786)
const FORMULA_PARTICLES: { text: string; desc: string }[] = [
  // 27 world formulas
  { text: 'φ = 1.618', desc: 'Golden ratio — nature\'s proportion' },
  { text: 'π·φ·e = 13.82', desc: 'Product of transcendentals' },
  { text: 'L(10) = 123', desc: '10th Lucas number' },
  { text: '1/α = 137.036', desc: 'Fine structure constant inverse' },
  { text: 'φ² = 2.618', desc: 'Golden ratio squared' },
  { text: 'Feigenbaum = 4.669', desc: 'Feigenbaum chaos constant' },
  { text: 'F(7) = 13', desc: '7th Fibonacci number' },
  { text: '√5 = 2.236', desc: 'Square root of five' },
  { text: '999 = 37 × 27', desc: 'Sacred number 999' },
  { text: 'π = 3.14159', desc: 'Circle ratio' },
  { text: '27 = 3³', desc: 'Cube of trinity' },
  { text: 'CHSH = 2√2', desc: 'Quantum Bell bound' },
  { text: 'mₚ/mₑ = 1836', desc: 'Proton-electron mass ratio' },
  { text: 'π² = 9.87', desc: 'Basel problem result' },
  { text: 'eᵖⁱ = 23.14', desc: 'Euler to pi' },
  { text: 'E8 = 248 dim', desc: 'E8 Lie group dimension' },
  { text: '603 = 67×9', desc: 'Energy efficiency' },
  { text: '76 photons', desc: 'Quantum advantage' },
  { text: 'φ²+1/φ² = 3', desc: 'TRINITY IDENTITY' },
  { text: 'τ = 6.283', desc: 'Full turn tau' },
  { text: 'Menger = 2.727', desc: 'Menger sponge fractal' },
  { text: 'μ = 0.0382', desc: 'Mutation rate from phi' },
  { text: 'χ = 0.0618', desc: 'Crossover rate from phi' },
  { text: 'σ = φ', desc: 'Selection = phi' },
  { text: 'e = 2.71828', desc: 'Euler\'s number' },
  { text: '13.82 Gyr', desc: 'Age of universe' },
  { text: 'H₀ = 70.74', desc: 'Hubble constant' },
  // 15 extra sacred formulas
  { text: 'V = n·3ᵏ·πᵐ·φᵖ·eᵠ', desc: 'Trinity value formula' },
  { text: '1.58 bits/trit', desc: 'Ternary information density' },
  { text: 'φ = (1+√5)/2', desc: 'Golden ratio definition' },
  { text: 'eⁱᵖ + 1 = 0', desc: 'Euler\'s identity' },
  { text: '3 = φ²+1/φ²', desc: 'Trinity identity' },
  { text: 'F(n) = F(n-1)+F(n-2)', desc: 'Fibonacci recurrence' },
  { text: 'ℏ = 1.054e-34', desc: 'Reduced Planck constant' },
  { text: 'c = 299792458 m/s', desc: 'Speed of light' },
  { text: 'G = 6.674e-11', desc: 'Gravitational constant' },
  { text: 'L(n): 2,1,3,4,7,11,18…', desc: 'Lucas sequence' },
  { text: 'τ/φ = 3.883', desc: 'Tau over phi' },
  { text: 'π·e = 8.539', desc: 'Pi times e' },
  { text: 'φᵠ = 2.390', desc: 'Phi to phi power' },
  { text: '3³³ = 7.6T', desc: 'Tower of threes' },
  { text: '√2 = 1.414', desc: 'Pythagoras\' constant' },
];
const GOLDEN_ANGLE = 2 * Math.PI / (PHI * PHI); // ≈ 2.399 rad (137.5°)

// 27 Sacred Worlds data (from sacred_worlds.zig — exact 1:1 match)
const PETALS: PetalItem[] = [
  // ═══ RAZUM (φ / gold) — blocks 0-8 ═══
  { id: 'chat',      label: 'CHAT',      icon: '💬', layer: 'chat',    color: '#ffd700', realm: 'razum', domain: 'ai_chat',   sacredFormula: 'phi = 1.618',           sacredValue: 1.618 },
  { id: 'code',      label: 'CODE',      icon: '⚡', layer: 'editor',  color: '#ffd700', realm: 'razum', domain: 'ai_chat',   sacredFormula: 'pi*phi*e = 13.82',      sacredValue: 13.82 },
  { id: 'explain',   label: 'EXPLAIN',   icon: '📖', layer: 'chat',    color: '#ffd700', realm: 'razum', domain: 'ai_chat',   sacredFormula: 'L(10) = 123',           sacredValue: 123 },
  { id: 'debug',     label: 'DEBUG',     icon: '🐛', layer: 'chat',    color: '#ffd700', realm: 'razum', domain: 'ai_code',   sacredFormula: '1/a = 137.036',         sacredValue: 137.036 },
  { id: 'review',    label: 'REVIEW',    icon: '🔍', layer: 'chat',    color: '#ffd700', realm: 'razum', domain: 'ai_code',   sacredFormula: 'phi2 = phi+1 = 2.618',  sacredValue: 2.618 },
  { id: 'translate', label: 'TRANSLATE', icon: '🌐', layer: 'chat',    color: '#ffd700', realm: 'razum', domain: 'ai_code',   sacredFormula: 'Feigenbaum d = 4.669',  sacredValue: 4.669 },
  { id: 'vibee',     label: 'VIBEE',     icon: '✨', layer: 'editor',  color: '#ffd700', realm: 'razum', domain: 'ai_create', sacredFormula: 'F(7) = 13',             sacredValue: 13 },
  { id: 'voice',     label: 'VOICE',     icon: '🎙️', layer: 'voice',   color: '#ffd700', realm: 'razum', domain: 'ai_create', sacredFormula: 'sqrt(5) = 2.236',       sacredValue: 2.236 },
  { id: 'compose',   label: 'COMPOSE',   icon: '🎼', layer: 'chat',    color: '#ffd700', realm: 'razum', domain: 'ai_create', sacredFormula: '999 = 37 x 27',         sacredValue: 999 },
  // ═══ MATERIYA (π / cyan) — blocks 9-17 ═══
  { id: 'files',     label: 'FILES',     icon: '📁', layer: 'finder',  color: '#50fafa', realm: 'materiya', domain: 'filesystem',      sacredFormula: 'pi = 3.14159',     sacredValue: 3.14159 },
  { id: 'editor',    label: 'EDITOR',    icon: '📝', layer: 'editor',  color: '#50fafa', realm: 'materiya', domain: 'filesystem',      sacredFormula: '27 = 3^3',         sacredValue: 27 },
  { id: 'build',     label: 'BUILD',     icon: '🔨', layer: 'tools',   color: '#50fafa', realm: 'materiya', domain: 'filesystem',      sacredFormula: 'CHSH = 2*sqrt(2)', sacredValue: 2.828 },
  { id: 'test',      label: 'TEST',      icon: '🧪', layer: 'tools',   color: '#50fafa', realm: 'materiya', domain: 'devtools',        sacredFormula: 'm_p/m_e = 1836',   sacredValue: 1836 },
  { id: 'terminal',  label: 'TERMINAL',  icon: '💻', layer: 'tools',   color: '#50fafa', realm: 'materiya', domain: 'devtools',        sacredFormula: 'pi2 = 9.87',       sacredValue: 9.87 },
  { id: 'git',       label: 'GIT',       icon: '🔀', layer: 'tools',   color: '#50fafa', realm: 'materiya', domain: 'devtools',        sacredFormula: 'e^pi = 23.14',     sacredValue: 23.14 },
  { id: 'deploy',    label: 'DEPLOY',    icon: '🚀', layer: 'tools',   color: '#50fafa', realm: 'materiya', domain: 'infrastructure',  sacredFormula: 'E8 dim = 248',     sacredValue: 248 },
  { id: 'network',   label: 'NETWORK',   icon: '🌐', layer: 'tools',   color: '#50fafa', realm: 'materiya', domain: 'infrastructure',  sacredFormula: '603x pipeline',    sacredValue: 603 },
  { id: 'settings',  label: 'SETTINGS',  icon: '⚙️', layer: 'settings', color: '#50fafa', realm: 'materiya', domain: 'infrastructure',  sacredFormula: '76 photons',       sacredValue: 76 },
  // ═══ DUKH (e / purple) — blocks 18-26 ═══
  { id: 'docs',       label: 'DOCS',       icon: '📖', layer: 'chat',   color: '#bd93f9', realm: 'dukh', domain: 'knowledge',  sacredFormula: 'phi2+1/phi2 = 3',     sacredValue: 3.0 },
  { id: 'reels',      label: 'REELS',      icon: '🎬', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'knowledge',  sacredFormula: 'tau = 2*pi = 6.283',  sacredValue: 6.283, vizMode: 'cinema4d' },
  { id: 'feed',       label: 'FEED',       icon: '📰', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'knowledge',  sacredFormula: 'Menger D = 2.727',    sacredValue: 2.727, vizMode: 'vortex' },
  { id: 'roadmap',    label: 'ROADMAP',    icon: '🗺️', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'content',    sacredFormula: 'mu = 0.0382',         sacredValue: 0.0382, vizMode: 'quantum-life' },
  { id: 'benchmarks', label: 'BENCHMARKS', icon: '📊', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'content',    sacredFormula: 'chi = 0.0618',        sacredValue: 0.0618, vizMode: 'quantum-biology' },
  { id: 'research',   label: 'RESEARCH',   icon: '🔬', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'content',    sacredFormula: 'sigma = phi = 1.618', sacredValue: 1.618, vizMode: 'bogatyri' },
  { id: 'formulas',   label: 'FORMULAS',   icon: '🧮', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'community',  sacredFormula: 'e = 2.71828',         sacredValue: 2.718, vizMode: 'transcendence' },
  { id: 'community',  label: 'COMMUNITY',  icon: '👥', layer: 'vision', color: '#bd93f9', realm: 'dukh', domain: 'community',  sacredFormula: '13.82 Gyr',           sacredValue: 13.82 },
  { id: 'about',      label: 'ABOUT',      icon: '🔮', layer: 'viz',    color: '#bd93f9', realm: 'dukh', domain: 'community',  sacredFormula: 'H0 = 70.74',          sacredValue: 70.74, vizMode: 'matryoshka' },
];

// Convert SVG coords to polygon points string centered at origin
function blockToPoints(blockIdx: number, scale: number, cx: number, cy: number): string {
  return BLOCK_VERTS[blockIdx].map(([x, y]) =>
    `${cx + (x - SVG_CX) * scale},${cy + (y - SVG_CY) * scale}`
  ).join(' ');
}

// Block center for label placement
function blockCenter(blockIdx: number, scale: number, cx: number, cy: number): [number, number] {
  const verts = BLOCK_VERTS[blockIdx];
  const mx = verts.reduce((s, v) => s + v[0], 0) / verts.length;
  const my = verts.reduce((s, v) => s + v[1], 0) / verts.length;
  return [cx + (mx - SVG_CX) * scale, cy + (my - SVG_CY) * scale];
}

// ─── Command palette items ─────────────────────────────────────────────────

const COMMAND_ITEMS: CommandItem[] = [
  // Layers
  ...LAYER_KEYS.map((l, i) => ({
    id: `layer-${l}`, label: LAYER_INFO[l].label, icon: String(i + 1),
    hint: LAYER_INFO[l].hint, layer: l as CanvasLayer, color: `hsl(${LAYER_INFO[l].hue}, 80%, 60%)`,
  })),
  // Sacred worlds from petals
  ...PETALS.filter(p => p.vizMode).map(p => ({
    id: `viz-${p.id}`, label: p.label, icon: p.icon,
    hint: `${REALM_COLORS[p.realm].label} | ${p.sacredFormula ?? p.vizMode}`, layer: 'viz' as CanvasLayer, vizMode: p.vizMode, color: p.color,
  })),
  // Layer petals (non-viz)
  ...PETALS.filter(p => p.layer && p.layer !== 'viz' && !LAYER_KEYS.includes(p.layer as never)).map(p => ({
    id: `world-${p.id}`, label: p.label, icon: p.icon,
    hint: `${REALM_COLORS[p.realm].label} | ${p.sacredFormula ?? ''}`, layer: p.layer as CanvasLayer, color: p.color,
  })),
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

function triggerWave(hue: number, x?: number, y?: number) {
  if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
  window.__trinityWaveRings.push({
    x: x ?? window.innerWidth / 2,
    y: y ?? window.innerHeight / 2,
    time: Date.now(), hue,
  });
}

const FONT = "'Outfit', system-ui, sans-serif";
const MONO = "'JetBrains Mono', 'Fira Code', monospace";

const glassStyle = (borderColor = 'rgba(255,255,255,0.08)'): React.CSSProperties => ({
  background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(12px)',
  border: `1px solid ${borderColor}`, borderRadius: 14,
});

// Editor language presets
const EDITOR_PRESETS: Record<string, { label: string; code: string; color: string }> = {
  js: {
    label: 'JavaScript', color: '#ffd700',
    code: `// Trinity Editor v2.6 — JavaScript\nconst PHI = 1.618033988749895;\nconst TRINITY = PHI ** 2 + PHI ** -2;\nconsole.log("phi^2 + 1/phi^2 =", TRINITY);\nconsole.log("Golden Ratio phi =", PHI);\nconsole.log("KOSCHEI IS IMMORTAL");`,
  },
  vibee: {
    label: 'VIBEE', color: '#aa66ff',
    code: `name: trinity_canvas\nversion: "2.6.0"\nlanguage: zig\nmodule: canvas\n\ntypes:\n  CanvasLayer:\n    values:\n      - petals\n      - chat\n      - editor\n      - finder\n      - vision\n      - voice\n      - tools\n      - settings\n      - viz\n  Message:\n    fields:\n      id: Int\n      role: String\n      content: String\n      source: Option<String>\n      confidence: Option<Float>\n\nbehaviors:\n  - name: switch_layer\n    given: User presses key 1-9\n    when: Layer state machine receives input\n    then: Canvas transitions to new wave mode\n  - name: send_message\n    given: User types in chat input\n    when: Enter pressed or Send clicked\n    then: Message sent to IglaHybridChat v2.6 API\n  - name: compile_code\n    given: User clicks COMPILE in editor\n    when: VIBEE or Zig code present\n    then: Code sent to POST /api/compile for real backend analysis\n  - name: open_command_bar\n    given: User presses Cmd+K or /\n    when: Not in text input\n    then: Universal command palette opens`,
  },
  zig: {
    label: 'Zig', color: '#ff8800',
    code: `// Trinity Zig Example\nconst std = @import("std");\n\npub fn main() !void {\n    const phi: f64 = 1.618033988749895;\n    const trinity = phi * phi + 1.0 / (phi * phi);\n    std.debug.print("phi^2 + 1/phi^2 = {d:.10}\\n", .{trinity});\n}`,
  },
};

// ─── Component ───────────────────────────────────────────────────────────────

export default function TrinityCanvas() {
  const [wasmMode, setWasmMode] = useState(false);
  const [layer, setLayer] = useState<CanvasLayer>('petals');
  const [vizMode, setVizMode] = useState<VizMode>('trinity-computer');

  // Wave transition state
  const [transitioning, setTransitioning] = useState(false);
  const [transitionKey, setTransitionKey] = useState(0);

  // Command bar state
  const [cmdOpen, setCmdOpen] = useState(false);
  const [cmdQuery, setCmdQuery] = useState('');
  const [cmdSelectedIdx, setCmdSelectedIdx] = useState(0);
  const cmdInputRef = useRef<HTMLInputElement>(null);

  // Emergent dot nav state
  const [dotsVisible, setDotsVisible] = useState(false);
  const dotsTimerRef = useRef<ReturnType<typeof setTimeout>>();

  // Chat state
  const [messages, setMessages] = useState<Message[]>([]);
  const [chatLoading, setChatLoading] = useState(false);
  const [chatText, setChatText] = useState('');
  const [chatImagePath, setChatImagePath] = useState('');
  const [chatAudioPath, setChatAudioPath] = useState('');
  const [showChatAttach, setShowChatAttach] = useState(false);
  const [nextId, setNextId] = useState(1);

  // Petals hover state (1:1 Raylib match)
  const [hoveredBlock, setHoveredBlock] = useState(-1);
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });

  // Formula particles animation (Fibonacci golden angle spiral — 1:1 Raylib match)
  const [formulaTime, setFormulaTime] = useState(0);
  const [expandedFormula, setExpandedFormula] = useState(-1);
  const formulaRafRef = useRef<number>(0);
  const formulaLastRef = useRef<number>(0);
  const scrollRef = useRef<HTMLDivElement>(null);
  const [connected, setConnected] = useState(false);

  // Editor state
  const [editorLang, setEditorLang] = useState<string>('js');
  const [editorCode, setEditorCode] = useState(EDITOR_PRESETS.js.code);
  const [editorOutput, setEditorOutput] = useState('');

  // Finder state
  const [finderQuery, setFinderQuery] = useState('');
  const [finderResults, setFinderResults] = useState<FinderFile[]>([]);
  const [selectedFile, setSelectedFile] = useState<FinderFile | null>(null);
  const [filePreview, setFilePreview] = useState('');
  const [filePreviewLoading, setFilePreviewLoading] = useState(false);
  const [finderCategoryFilter, setFinderCategoryFilter] = useState<string | null>(null);
  const [backendFiles, setBackendFiles] = useState<FinderFile[] | null>(null);

  // Vision state — real drag-drop + paste
  const [visionUrl, setVisionUrl] = useState('');
  const [visionAnalysis, setVisionAnalysis] = useState('');
  const [visionLoading, setVisionLoading] = useState(false);
  const [visionPreviewSrc, setVisionPreviewSrc] = useState('');
  const [isDragOver, setIsDragOver] = useState(false);
  const visionDropRef = useRef<HTMLDivElement>(null);

  // Voice state — real Web Audio API
  const [voiceActive, setVoiceActive] = useState(false);
  const [voiceBars, setVoiceBars] = useState<number[]>(new Array(32).fill(0));
  const [voiceTranscript, setVoiceTranscript] = useState('');
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const voiceRafRef = useRef<number>(0);
  const recognitionRef = useRef<SpeechRecognition | null>(null);

  // Mirror of Three Worlds state
  const [mirrorStatus, setMirrorStatus] = useState<MirrorStatus | null>(null);
  const [mirrorLoading, setMirrorLoading] = useState(false);
  const [mirrorLogs, setMirrorLogs] = useState<MirrorLogEntry[]>([]);
  const mirrorLogRef = useRef<HTMLDivElement>(null);

  // Mirror RAZUM: inline chat with history (v2.6)
  const [mChatInput, setMChatInput] = useState('');
  const [mChatReply, setMChatReply] = useState<{ text: string; source: string; conf: number; lat: number } | null>(null);
  const [mChatSending, setMChatSending] = useState(false);
  const [mChatHistory, setMChatHistory] = useState<{ role: 'user' | 'assistant'; text: string; source?: string; conf?: number; lat?: number; reflection?: string }[]>([]);

  // Mirror MATERIYA: inline file search + preview (v2.6)
  const [mFinderQuery, setMFinderQuery] = useState('');
  const [mFilePreview, setMFilePreview] = useState<{ path: string; content: string } | null>(null);
  const [mPreviewLoading, setMPreviewLoading] = useState(false);

  // Mirror DUKH: inline tool outputs + vision/voice (v2.6)
  const [mToolOutput, setMToolOutput] = useState('');
  const [mVisionDrop, setMVisionDrop] = useState(false);
  const [mVisionResult, setMVisionResult] = useState('');
  const [mVoiceActive, setMVoiceActive] = useState(false);
  const [mVoiceText, setMVoiceText] = useState('');
  const mVoiceRecRef = useRef<SpeechRecognition | null>(null);

  // Self-reflection state (v2.6)
  const [selfReflection, setSelfReflection] = useState<string | null>(null);

  // Storage Network metrics (v2.7)
  const [storageMetrics, setStorageMetrics] = useState<StorageMetrics | null>(null);
  const [storageCollapsed, setStorageCollapsed] = useState<Record<string, boolean>>({});

  // UI
  const [showLayerHint, setShowLayerHint] = useState(true);

  // ─── Command bar filtered results ─────────────────────────────────────────

  const cmdResults = useMemo(() => {
    const q = cmdQuery.toLowerCase();
    if (!q) return COMMAND_ITEMS.slice(0, 9);
    return COMMAND_ITEMS.filter(item =>
      item.label.toLowerCase().includes(q) ||
      item.hint.toLowerCase().includes(q) ||
      item.id.toLowerCase().includes(q)
    ).slice(0, 9);
  }, [cmdQuery]);

  // ─── Connection status (global) ─────────────────────────────────────────

  useEffect(() => {
    const check = () => checkHealth().then(setConnected);
    check();
    const interval = setInterval(check, 10000);
    return () => clearInterval(interval);
  }, []);

  // ─── Formula particles animation (Fibonacci spiral orbit) ───────────────

  useEffect(() => {
    if (layer !== 'petals') {
      cancelAnimationFrame(formulaRafRef.current);
      return;
    }
    const tick = (now: number) => {
      if (formulaLastRef.current === 0) formulaLastRef.current = now;
      const dt = (now - formulaLastRef.current) / 1000;
      formulaLastRef.current = now;
      setFormulaTime(t => t + dt);
      formulaRafRef.current = requestAnimationFrame(tick);
    };
    formulaLastRef.current = 0;
    formulaRafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(formulaRafRef.current);
  }, [layer]);

  // ─── Layer switching with wave transition ────────────────────────────────

  const switchLayer = useCallback((newLayer: CanvasLayer, newVizMode?: VizMode) => {
    if (transitioning) return;
    setTransitioning(true);
    triggerWave(LAYER_INFO[newLayer].hue);

    // Phase 1: fade out current (200ms)
    setTimeout(() => {
      setLayer(newLayer);
      setVizMode(newVizMode || LAYER_INFO[newLayer].vizMode);
      setTransitionKey(k => k + 1);
      setShowLayerHint(true);
      setTimeout(() => setShowLayerHint(false), 1800);
      // Phase 2: fade in new (200ms)
      setTimeout(() => setTransitioning(false), 200);
    }, 200);
  }, [transitioning]);

  // ─── Command bar actions ───────────────────────────────────────────────

  const openCommandBar = useCallback(() => {
    setCmdOpen(true);
    setCmdQuery('');
    setCmdSelectedIdx(0);
    setTimeout(() => cmdInputRef.current?.focus(), 50);
  }, []);

  const closeCommandBar = useCallback(() => {
    setCmdOpen(false);
    setCmdQuery('');
  }, []);

  const executeCommand = useCallback((item: CommandItem) => {
    closeCommandBar();
    if (item.layer) switchLayer(item.layer, item.vizMode);
  }, [closeCommandBar, switchLayer]);

  // ─── Emergent dots hover zone ─────────────────────────────────────────

  const handleDotsEnter = useCallback(() => {
    if (dotsTimerRef.current) clearTimeout(dotsTimerRef.current);
    setDotsVisible(true);
  }, []);

  const handleDotsLeave = useCallback(() => {
    dotsTimerRef.current = setTimeout(() => setDotsVisible(false), 2000);
  }, []);

  // ─── Keyboard shortcuts ──────────────────────────────────────────────────

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Command bar: Cmd+K or / (when not in input)
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        if (cmdOpen) closeCommandBar(); else openCommandBar();
        return;
      }

      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;

      if (e.key === '/' && !cmdOpen) {
        e.preventDefault();
        openCommandBar();
        return;
      }

      // Command bar navigation
      if (cmdOpen) {
        if (e.key === 'Escape') { e.preventDefault(); closeCommandBar(); return; }
        if (e.key === 'ArrowDown') { e.preventDefault(); setCmdSelectedIdx(i => Math.min(i + 1, cmdResults.length - 1)); return; }
        if (e.key === 'ArrowUp') { e.preventDefault(); setCmdSelectedIdx(i => Math.max(i - 1, 0)); return; }
        if (e.key === 'Enter' && cmdResults[cmdSelectedIdx]) { e.preventDefault(); executeCommand(cmdResults[cmdSelectedIdx]); return; }
        return;
      }

      const num = parseInt(e.key);
      if (num >= 1 && num <= 9) { e.preventDefault(); switchLayer(LAYER_KEYS[num - 1]); }
      if (e.key === 'Escape') {
        e.preventDefault();
        if (selectedFile) { setSelectedFile(null); setFilePreview(''); }
        else switchLayer('petals');
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [switchLayer, cmdOpen, openCommandBar, closeCommandBar, cmdResults, cmdSelectedIdx, executeCommand, selectedFile]);

  // ─── Chat ────────────────────────────────────────────────────────────────

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages]);

  const handleChatSend = useCallback(async () => {
    const trimmed = chatText.trim();
    if (!trimmed || chatLoading) return;
    const userId = nextId;
    setNextId(n => n + 2);
    setChatText('');

    const imgPath = chatImagePath.trim() || undefined;
    const audPath = chatAudioPath.trim() || undefined;

    setMessages(prev => [...prev, {
      id: userId, role: 'user',
      content: trimmed + (imgPath ? `\n[image: ${imgPath}]` : '') + (audPath ? `\n[audio: ${audPath}]` : ''),
    }]);
    triggerWave(45, window.innerWidth * 0.7, window.innerHeight * 0.5);
    setChatLoading(true);

    try {
      const res: ChatResponse = await sendMessage({
        message: trimmed,
        image_path: imgPath,
        audio_path: audPath,
      });
      setMessages(prev => [...prev, {
        id: userId + 1, role: 'assistant', content: res.response,
        source: res.source, confidence: res.confidence, latency_us: res.latency_us,
        tool_name: res.tool_name, reflection: res.reflection, learned: res.learned,
      }]);
      triggerWave(150, window.innerWidth * 0.3, window.innerHeight * 0.5);
      if (res.learned) setTimeout(() => triggerWave(120), 300);
      setChatImagePath('');
      setChatAudioPath('');
    } catch {
      setMessages(prev => [...prev, {
        id: userId + 1, role: 'assistant',
        content: 'Connection error. Start backend: zig build tri -- serve --chat --port 8080',
        source: 'Error', confidence: 0,
      }]);
    } finally {
      setChatLoading(false);
    }
  }, [chatText, chatLoading, nextId, chatImagePath, chatAudioPath]);

  // ─── Finder (v2.5: real file listing from backend with fallback) ─────────

  // Fetch real file list from backend when finder opens
  useEffect(() => {
    if (layer !== 'finder' || backendFiles !== null) return;
    fetchFileList().then(files => {
      if (files.length > 0) {
        // Convert backend FileEntry to FinderFile format
        const mapped: FinderFile[] = files.map(f => ({
          path: f.path,
          category: (f.category as FinderFile['category']) || 'core',
          icon: f.icon || '🔺',
          color: f.color || '#00ff88',
        }));
        setBackendFiles(mapped);
      }
    });
  }, [layer, backendFiles]);

  // Use backend files if available, otherwise fallback to static FILE_INDEX
  const activeFileIndex = backendFiles && backendFiles.length > 0 ? backendFiles : FILE_INDEX;

  useEffect(() => {
    const q = finderQuery.toLowerCase();
    let results = activeFileIndex;
    if (q) results = results.filter(f => f.path.toLowerCase().includes(q));
    if (finderCategoryFilter) results = results.filter(f => f.category === finderCategoryFilter);
    setFinderResults(q || finderCategoryFilter ? results : []);
  }, [finderQuery, finderCategoryFilter, activeFileIndex]);

  // File content preview via chat API tool
  const handleFilePreview = useCallback(async (file: FinderFile) => {
    setSelectedFile(file);
    setFilePreview('');
    setFilePreviewLoading(true);
    triggerWave(280);
    try {
      const res = await sendMessage({ message: `read file ${file.path}` });
      setFilePreview(res.response);
    } catch {
      setFilePreview(`Cannot preview: backend offline.\nPath: ${file.path}`);
    } finally {
      setFilePreviewLoading(false);
    }
  }, []);

  // ─── Editor ──────────────────────────────────────────────────────────────

  const [editorCompiling, setEditorCompiling] = useState(false);

  const handleEditorRun = useCallback(async () => {
    if (editorLang === 'js') {
      try {
        const logs: string[] = [];
        const fc = { log: (...a: unknown[]) => logs.push(a.map(String).join(' ')) };
        new Function('console', editorCode)(fc);
        setEditorOutput(logs.join('\n') || '(no output)');
      } catch (err) {
        setEditorOutput(`Error: ${err}`);
      }
    } else if (editorLang === 'vibee' || editorLang === 'zig') {
      // v2.5: Real backend compilation
      setEditorCompiling(true);
      setEditorOutput(`Compiling ${editorLang === 'vibee' ? 'VIBEE' : 'Zig'}...`);
      try {
        const result = await compileCode(editorCode, editorLang);
        setEditorOutput(result.output);
      } catch {
        setEditorOutput(`Compilation error. Backend offline.\nStart: zig build tri -- serve --chat --port 8080`);
      } finally {
        setEditorCompiling(false);
      }
    }
    triggerWave(120, window.innerWidth / 2, window.innerHeight * 0.3);
  }, [editorCode, editorLang]);

  const handleLangSwitch = useCallback((lang: string) => {
    setEditorLang(lang);
    setEditorCode(EDITOR_PRESETS[lang].code);
    setEditorOutput('');
  }, []);

  // ─── Vision (real drag-drop + paste + preview) ────────────────────────────

  const processImageFile = useCallback((file: File) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target?.result as string;
      setVisionPreviewSrc(dataUrl);
      setVisionUrl(file.name);
      triggerWave(320);
    };
    reader.readAsDataURL(file);
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault(); e.stopPropagation(); setIsDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault(); e.stopPropagation(); setIsDragOver(false);
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault(); e.stopPropagation(); setIsDragOver(false);
    const files = e.dataTransfer.files;
    if (files.length > 0 && files[0].type.startsWith('image/')) processImageFile(files[0]);
  }, [processImageFile]);

  useEffect(() => {
    if (layer !== 'vision') return;
    const handlePaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;
      for (const item of items) {
        if (item.type.startsWith('image/')) {
          const file = item.getAsFile();
          if (file) processImageFile(file);
          break;
        }
      }
    };
    window.addEventListener('paste', handlePaste);
    return () => window.removeEventListener('paste', handlePaste);
  }, [layer, processImageFile]);

  const handleVisionAnalyze = useCallback(async () => {
    if (!visionUrl && !visionPreviewSrc) return;
    setVisionLoading(true);
    setVisionAnalysis('Анализ через волновое поле...');
    triggerWave(320);
    try {
      const res = await sendMessage({ message: `analyze image: ${visionUrl}`, image_path: visionUrl || undefined });
      setVisionAnalysis(
        `Vision Analysis Complete\n${'━'.repeat(40)}\n` +
        `Source:      ${res.source}\nConfidence:  ${((res.confidence || 0) * 100).toFixed(0)}%\n` +
        `Latency:     ${res.latency_us ? (res.latency_us < 1000 ? `${res.latency_us}us` : `${(res.latency_us / 1000).toFixed(1)}ms`) : 'N/A'}\n` +
        `${'━'.repeat(40)}\n${res.response}`
      );
      triggerWave(120);
    } catch {
      setVisionAnalysis(
        `Vision Analysis — Offline Mode\n${'━'.repeat(40)}\n` +
        `Source:  ${visionUrl.substring(0, 50)}${visionUrl.length > 50 ? '...' : ''}\n` +
        `Status:  Backend offline\nNote:    Start backend: zig build tri -- serve --chat --port 8080`
      );
    } finally { setVisionLoading(false); }
  }, [visionUrl, visionPreviewSrc]);

  // ─── Voice (real Web Audio API + Speech-to-Text) ──────────────────────────

  const startVoice = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;
      const audioCtx = new AudioContext();
      audioContextRef.current = audioCtx;
      const source = audioCtx.createMediaStreamSource(stream);
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 64; analyser.smoothingTimeConstant = 0.8;
      source.connect(analyser);
      analyserRef.current = analyser;
      const dataArray = new Uint8Array(analyser.frequencyBinCount);
      const animate = () => {
        analyser.getByteFrequencyData(dataArray);
        const bars = Array.from(dataArray).map(v => v / 255);
        setVoiceBars(bars);
        const max = Math.max(...bars);
        if (max > 0.3) triggerWave(30 + max * 40, window.innerWidth * (0.3 + Math.random() * 0.4), window.innerHeight * 0.5);
        voiceRafRef.current = requestAnimationFrame(animate);
      };
      animate();
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (SpeechRecognition) {
        const recognition = new SpeechRecognition();
        recognition.continuous = true; recognition.interimResults = true; recognition.lang = 'ru-RU';
        recognition.onresult = (event: SpeechRecognitionEvent) => {
          let transcript = '';
          for (let i = event.resultIndex; i < event.results.length; i++) transcript += event.results[i][0].transcript;
          setVoiceTranscript(transcript);
        };
        recognition.start();
        recognitionRef.current = recognition;
      }
      setVoiceActive(true);
    } catch (err) { setVoiceTranscript(`Microphone access denied: ${err}`); }
  }, []);

  const stopVoice = useCallback(() => {
    if (voiceRafRef.current) cancelAnimationFrame(voiceRafRef.current);
    if (recognitionRef.current) { recognitionRef.current.stop(); recognitionRef.current = null; }
    if (mediaStreamRef.current) { mediaStreamRef.current.getTracks().forEach(t => t.stop()); mediaStreamRef.current = null; }
    if (audioContextRef.current) { audioContextRef.current.close(); audioContextRef.current = null; }
    analyserRef.current = null;
    setVoiceActive(false); setVoiceBars(new Array(32).fill(0));
  }, []);

  const toggleVoice = useCallback(() => { if (voiceActive) stopVoice(); else startVoice(); }, [voiceActive, stopVoice, startVoice]);
  useEffect(() => () => { stopVoice(); }, [stopVoice]);

  const handleVoiceSend = useCallback(async () => {
    if (!voiceTranscript.trim()) return;
    stopVoice(); switchLayer('chat'); setChatText(voiceTranscript.trim()); setVoiceTranscript('');
  }, [voiceTranscript, stopVoice, switchLayer]);

  // ─── Mirror of Three Worlds (auto-polling 2s) ──────────────────────────────

  const lastLogTsRef = useRef(0);

  const refreshMirror = useCallback(async () => {
    setMirrorLoading(true);
    try {
      const [status, storage] = await Promise.all([
        fetchMirrorStatus(),
        fetchStorageMetrics(),
      ]);
      setMirrorStatus(status);
      setStorageMetrics(storage);
      // Merge new log entries (deduplicate by timestamp)
      if (status.logs && status.logs.length > 0) {
        setMirrorLogs(prev => {
          const newEntries = status.logs!.filter(l => l.ts > lastLogTsRef.current);
          if (newEntries.length === 0) return prev;
          lastLogTsRef.current = Math.max(...newEntries.map(l => l.ts));
          const merged = [...prev, ...newEntries];
          return merged.slice(-50); // keep last 50
        });
      }
    } finally { setMirrorLoading(false); }
  }, []);

  useEffect(() => {
    if (layer !== 'tools') return;
    refreshMirror();
    const id = setInterval(refreshMirror, 2000);
    return () => clearInterval(id);
  }, [layer, refreshMirror]);

  // Auto-scroll logs
  useEffect(() => {
    if (mirrorLogRef.current) {
      mirrorLogRef.current.scrollTop = mirrorLogRef.current.scrollHeight;
    }
  }, [mirrorLogs]);

  // ─── Mirror RAZUM: send chat with history + self-reflection (v2.6) ────────
  const handleMirrorChat = useCallback(async () => {
    if (!mChatInput.trim() || mChatSending) return;
    const userMsg = mChatInput.trim();
    setMChatSending(true); setMChatReply(null); setSelfReflection(null); triggerWave(45);
    setMChatHistory(prev => [...prev.slice(-4), { role: 'user', text: userMsg }]);
    try {
      const res = await sendMessage({ message: userMsg });
      const reply = { text: res.response, source: res.source, conf: res.confidence, lat: res.latency_us };
      setMChatReply(reply);
      setMChatHistory(prev => [...prev.slice(-4), { role: 'assistant', text: res.response, source: res.source, conf: res.confidence, lat: res.latency_us, reflection: res.reflection }]);
      setMChatInput('');
      // Self-reflection: show if backend returned it
      if (res.reflection) {
        setSelfReflection(res.reflection);
      } else {
        // Generate local reflection based on routing
        const route = res.source || 'Unknown';
        const energy = route.includes('Symbolic') ? '0.1mWh' : route.includes('TVC') ? '1mWh' : route.includes('Local') ? '50mWh' : '100mWh';
        setSelfReflection(`Route: ${route} | Energy: ${energy} | Confidence: ${(res.confidence * 100).toFixed(0)}% | ${res.learned ? 'Learned for next time' : 'Not cached'}`);
      }
      setTimeout(refreshMirror, 500);
    } catch {
      setMChatReply({ text: 'Connection error. Start backend.', source: 'Error', conf: 0, lat: 0 });
    } finally { setMChatSending(false); }
  }, [mChatInput, mChatSending, refreshMirror]);

  // ─── Mirror MATERIYA: file search + inline preview (v2.6) ─────────────────
  const mFinderResults = useMemo(() => {
    if (!mFinderQuery.trim()) return activeFileIndex.slice(0, 8);
    const q = mFinderQuery.toLowerCase();
    return activeFileIndex.filter(f =>
      f.path.toLowerCase().includes(q) || f.category.toLowerCase().includes(q)
    ).slice(0, 8);
  }, [mFinderQuery, activeFileIndex]);

  const handleMirrorFilePreview = useCallback(async (file: FinderFile) => {
    setMPreviewLoading(true);
    setMFilePreview({ path: file.path, content: 'Loading...' });
    triggerWave(180);
    try {
      const res = await sendMessage({ message: `read file ${file.path}` });
      setMFilePreview({ path: file.path, content: res.response.slice(0, 500) });
    } catch {
      setMFilePreview({ path: file.path, content: `Preview unavailable (backend offline)` });
    } finally { setMPreviewLoading(false); }
  }, []);

  // ─── Mirror DUKH: tools + vision + voice (v2.6) ──────────────────────────
  const handleMirrorTool = useCallback(async (cmd: string) => {
    setMToolOutput(`Running ${cmd}...`); triggerWave(280);
    try {
      const res = await sendMessage({ message: cmd });
      setMToolOutput(`${res.source} (${(res.confidence * 100).toFixed(0)}%) ${res.latency_us ? `${(res.latency_us / 1000).toFixed(1)}ms` : ''}\n${res.response}`);
      setTimeout(refreshMirror, 500);
    } catch {
      setMToolOutput(`${cmd} — offline. Start backend:\nzig build tri -- serve --chat --port 8080`);
    }
  }, [refreshMirror]);

  // Mirror DUKH: vision drop handler (v2.6)
  const handleMirrorVisionDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault(); setMVisionDrop(false);
    const file = e.dataTransfer.files[0];
    if (!file || !file.type.startsWith('image/')) return;
    triggerWave(320);
    setMVisionResult('Analyzing image...');
    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const res = await sendMessage({ message: 'analyze this image', image_path: reader.result as string });
        setMVisionResult(`${res.source}: ${res.response.slice(0, 200)}`);
        setTimeout(refreshMirror, 500);
      } catch {
        setMVisionResult('Vision offline. Start backend.');
      }
    };
    reader.readAsDataURL(file);
  }, [refreshMirror]);

  // Mirror DUKH: voice record toggle (v2.6)
  const toggleMirrorVoice = useCallback(() => {
    if (mVoiceActive && mVoiceRecRef.current) {
      mVoiceRecRef.current.stop();
      setMVoiceActive(false);
      return;
    }
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) { setMVoiceText('Speech API not supported'); return; }
    const rec = new SR();
    rec.continuous = false; rec.interimResults = false; rec.lang = 'en-US';
    rec.onresult = (ev: SpeechRecognitionEvent) => {
      const text = ev.results[0][0].transcript;
      setMVoiceText(text);
      // Auto-send voice transcript as chat
      setMChatInput(text);
    };
    rec.onerror = () => { setMVoiceActive(false); setMVoiceText('Voice error'); };
    rec.onend = () => setMVoiceActive(false);
    mVoiceRecRef.current = rec;
    rec.start();
    setMVoiceActive(true);
    setMVoiceText('Listening...');
    triggerWave(200);
  }, [mVoiceActive]);

  // ─── Petal click ─────────────────────────────────────────────────────────

  const handlePetalClick = useCallback((p: PetalItem) => {
    if (p.layer) switchLayer(p.layer, p.vizMode);
  }, [switchLayer]);

  // ─── Render ──────────────────────────────────────────────────────────────

  // WASM mode — render native Raylib canvas via iframe
  if (wasmMode) {
    return (
      <>
        <TrinityCanvasWasm onFallback={() => setWasmMode(false)} />
        <button
          onClick={() => setWasmMode(false)}
          style={{
            position: 'fixed', top: 10, right: 10, zIndex: 9999,
            background: 'rgba(0,0,0,0.7)', border: '1px solid rgba(255,255,255,0.15)',
            color: '#888', padding: '4px 10px', borderRadius: 4, cursor: 'pointer',
            fontSize: 10, fontFamily: 'monospace', letterSpacing: 1,
          }}
        >
          SVG
        </button>
      </>
    );
  }

  const info = LAYER_INFO[layer];
  const particles = layer === 'chat' ? 800 : layer === 'petals' ? 1200 : layer === 'voice' ? 2000 : 1500;

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', overflow: 'hidden', fontFamily: FONT }}>
      {/* Background Canvas */}
      <QuantumCanvas mode={vizMode} particleCount={particles} interactive={true} />

      {/* WASM toggle (top right) */}
      <button
        onClick={() => setWasmMode(true)}
        style={{
          position: 'absolute', top: 10, right: 10, zIndex: 150,
          background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
          color: '#555', padding: '4px 10px', borderRadius: 4, cursor: 'pointer',
          fontSize: 10, fontFamily: 'monospace', letterSpacing: 1,
        }}
      >
        WASM
      </button>

      {/* Connection indicator (top left) — minimal */}
      <div style={{ position: 'absolute', top: 12, left: 14, zIndex: 110, display: 'flex', alignItems: 'center', gap: 6 }}>
        <div style={{ width: 6, height: 6, borderRadius: '50%', background: connected ? '#00e599' : '#ff4444', boxShadow: `0 0 6px ${connected ? '#00e599' : '#ff4444'}` }} />
        <span style={{ color: connected ? '#00e599' : '#ff4444', fontSize: 8, fontFamily: MONO, letterSpacing: 1, opacity: 0.5 }}>
          {connected ? 'LIVE' : 'OFFLINE'}
        </span>
      </div>

      {/* ═══ EMERGENT WAVE DOTS (replaces layer bar) ═══ */}
      {layer !== 'petals' && (
        <div
          onMouseEnter={handleDotsEnter}
          onMouseLeave={handleDotsLeave}
          style={{ position: 'absolute', top: 0, left: '50%', transform: 'translateX(-50%)', zIndex: 120, padding: '8px 20px', cursor: 'default' }}
        >
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: dotsVisible ? 1 : 0.08 }}
            transition={{ duration: 0.4 }}
            style={{ display: 'flex', gap: 8, alignItems: 'center' }}
          >
            {LAYER_KEYS.map((l, i) => {
              const isActive = layer === l;
              const hue = LAYER_INFO[l].hue;
              return (
                <motion.button key={l} onClick={() => switchLayer(l)}
                  whileHover={{ scale: 1.5 }}
                  style={{
                    width: isActive ? 10 : 6, height: isActive ? 10 : 6,
                    borderRadius: '50%', border: 'none', padding: 0,
                    background: isActive ? `hsl(${hue}, 80%, 60%)` : 'rgba(255,255,255,0.2)',
                    boxShadow: isActive ? `0 0 10px hsla(${hue}, 80%, 60%, 0.6)` : 'none',
                    cursor: 'pointer', transition: 'all 0.3s',
                  }}
                  title={`${i + 1} ${LAYER_INFO[l].label}`}
                />
              );
            })}
          </motion.div>
        </div>
      )}

      {/* Cmd+K hint (top right) — minimal */}
      <div style={{ position: 'absolute', top: 12, right: 14, zIndex: 110, opacity: 0.15 }}>
        <span style={{ color: '#fff', fontSize: 9, fontFamily: MONO, letterSpacing: 1 }}>
          {navigator.platform.includes('Mac') ? '⌘' : 'Ctrl+'}K
        </span>
      </div>

      {/* ═══ COMMAND BAR (Cmd+K / /) ═══ */}
      <AnimatePresence>
        {cmdOpen && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            transition={{ duration: 0.15 }}
            onClick={closeCommandBar}
            style={{ position: 'fixed', inset: 0, zIndex: 500, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'flex-start', justifyContent: 'center', paddingTop: '18vh' }}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: -10 }} animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: -10 }} transition={{ duration: 0.2 }}
              onClick={e => e.stopPropagation()}
              style={{ width: '90%', maxWidth: 520, ...glassStyle('rgba(255,215,0,0.15)'), overflow: 'hidden' }}
            >
              {/* Search input */}
              <div style={{ display: 'flex', gap: 10, padding: '14px 18px', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
                <span style={{ color: '#ffd700', fontSize: 14, opacity: 0.5 }}>/</span>
                <input ref={cmdInputRef} type="text" value={cmdQuery} onChange={e => { setCmdQuery(e.target.value); setCmdSelectedIdx(0); }}
                  placeholder="Поиск слоя, визуализации, команды..."
                  style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: '#fff', fontSize: 15, fontFamily: FONT }} />
                <span style={{ color: 'rgba(255,255,255,0.15)', fontSize: 10, fontFamily: MONO, alignSelf: 'center' }}>ESC</span>
              </div>
              {/* Results */}
              <div style={{ maxHeight: 360, overflowY: 'auto' }}>
                {cmdResults.map((item, i) => (
                  <motion.div key={item.id}
                    initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.02 }}
                    onClick={() => executeCommand(item)}
                    onMouseEnter={() => setCmdSelectedIdx(i)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 12,
                      padding: '10px 18px', cursor: 'pointer',
                      background: i === cmdSelectedIdx ? 'rgba(255,215,0,0.08)' : 'transparent',
                      borderLeft: i === cmdSelectedIdx ? `2px solid ${item.color}` : '2px solid transparent',
                      transition: 'all 0.15s',
                    }}>
                    <span style={{ fontSize: 16, width: 24, textAlign: 'center' }}>{item.icon}</span>
                    <div style={{ flex: 1 }}>
                      <div style={{ color: item.color, fontSize: 13, fontFamily: FONT, fontWeight: 500 }}>{item.label}</div>
                      <div style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10, fontFamily: FONT }}>{item.hint}</div>
                    </div>
                    {item.layer && <span style={{ color: 'rgba(255,255,255,0.1)', fontSize: 9, fontFamily: MONO }}>
                      {LAYER_KEYS.indexOf(item.layer) + 1 || ''}
                    </span>}
                  </motion.div>
                ))}
                {cmdResults.length === 0 && (
                  <div style={{ padding: '20px 18px', color: 'rgba(255,255,255,0.15)', fontSize: 12, fontFamily: FONT, textAlign: 'center' }}>
                    Ничего не найдено
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Layer Hint (center, wave transition) — hidden on petals */}
      <AnimatePresence>
        {showLayerHint && layer !== 'petals' && info.label && (
          <motion.div
            initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.9 }} transition={{ duration: 0.35, type: 'spring', damping: 20 }}
            style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', zIndex: 200, textAlign: 'center', pointerEvents: 'none' }}
          >
            <div style={{ fontSize: 48, color: `hsl(${info.hue}, 80%, 60%)`, fontWeight: 700, fontFamily: FONT, textShadow: `0 0 40px hsla(${info.hue}, 80%, 60%, 0.3)` }}>{info.label}</div>
            <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.3)', marginTop: 8, fontFamily: FONT }}>{info.hint}</div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ═══ LAYER CONTENT (with wave transition) ═══ */}
      <AnimatePresence mode="wait">
        <motion.div key={`layer-${layer}-${transitionKey}`}
          initial={{ opacity: 0, scale: 0.97 }} animate={{ opacity: transitioning ? 0 : 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.97 }} transition={{ duration: 0.25 }}
          style={{ position: 'absolute', inset: 0 }}
        >

      {/* ═══ PETALS — 27 polygon blocks from 999.svg (1:1 Raylib match) ═══ */}
      {layer === 'petals' && (() => {
        const viewW = 600, viewH = 530;
        const logoScale = Math.min(viewW / SVG_W, viewH / SVG_H) * 0.95;
        const cx = viewW / 2, cy = viewH / 2;
        return (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50 }}>
          <motion.svg width={viewW} height={viewH} viewBox={`0 0 ${viewW} ${viewH}`}
            style={{ overflow: 'visible' }}
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.3 }}
            onMouseMove={e => { const r = (e.currentTarget as SVGSVGElement).getBoundingClientRect(); setMousePos({ x: e.clientX - r.left, y: e.clientY - r.top }); }}
            onMouseLeave={() => setHoveredBlock(-1)}
          >
            {PETALS.map((petal, i) => {
              const pts = blockToPoints(i, logoScale, cx, cy);
              const [lx, ly] = blockCenter(i, logoScale, cx, cy);
              const realmColor = REALM_COLORS[petal.realm].primary;
              const isHovered = hoveredBlock === i;
              // Fly-in: each block flies from its own direction
              const verts = BLOCK_VERTS[i];
              const bmx = verts.reduce((s, v) => s + v[0], 0) / verts.length - SVG_CX;
              const bmy = verts.reduce((s, v) => s + v[1], 0) / verts.length - SVG_CY;
              const dist = Math.sqrt(bmx * bmx + bmy * bmy) || 1;
              const flyX = (bmx / dist) * 800 * logoScale;
              const flyY = (bmy / dist) * 800 * logoScale;
              return (
                <motion.g key={petal.id}
                  initial={{ opacity: 0, x: flyX, y: flyY }}
                  animate={{ opacity: 1, x: 0, y: 0 }}
                  transition={{ delay: 0, duration: 0.8, type: 'spring', damping: 12, stiffness: 80 }}
                  onClick={() => handlePetalClick(petal)}
                  onMouseEnter={() => setHoveredBlock(i)}
                  style={{ cursor: 'pointer' }}
                >
                  <polygon
                    points={pts}
                    fill={isHovered ? '#ffffff' : '#000000'}
                    stroke='#ffffff'
                    strokeWidth={isHovered ? 1.5 : 1}
                    style={{ transition: 'fill 0.12s' }}
                  />
                </motion.g>
              );
            })}
            {/* Formula particles — Fibonacci golden angle spiral (1:1 Raylib match) */}
            {FORMULA_PARTICLES.map((fp, i) => {
              const fLayer = Math.floor(i / 9);
              const direction = fLayer % 2 === 0 ? 1 : -1;
              const speed = direction * (0.03 - i * 0.0003);
              const angle = i * GOLDEN_ANGLE + formulaTime * speed;
              const radius = (240 + i * 14) * logoScale;
              const fx = cx + Math.cos(angle) * radius;
              const fy = cy + Math.sin(angle) * radius;
              const isExpanded = expandedFormula === i;
              return (
                <g key={`fp-${i}`} onClick={() => setExpandedFormula(isExpanded ? -1 : i)}
                   style={{ cursor: 'pointer' }}>
                  <text x={fx} y={fy} textAnchor="middle" dominantBaseline="middle"
                    fill="rgba(255,255,255,0.63)" fontSize={14} fontFamily={MONO}>
                    {fp.text}
                  </text>
                  {isExpanded && (
                    <text x={fx} y={fy + 16} textAnchor="middle" dominantBaseline="middle"
                      fill="rgba(255,255,255,0.45)" fontSize={12} fontFamily={MONO}>
                      {fp.desc}
                    </text>
                  )}
                </g>
              );
            })}
            {/* Tooltip — follows cursor like Raylib (DrawRectangleRounded + text) */}
            {hoveredBlock >= 0 && (() => {
              const hp = PETALS[hoveredBlock];
              const rc = REALM_COLORS[hp.realm].primary;
              const tx = mousePos.x + 15, ty = mousePos.y - 28;
              const tw = hp.label.length * 9 + 30;
              return (
                <g pointerEvents="none">
                  <rect x={tx} y={ty} width={tw} height={24} rx={6} ry={6}
                    fill="rgba(255,255,255,0.94)" />
                  <circle cx={tx + 10} cy={ty + 12} r={4} fill={rc} />
                  <text x={tx + 20} y={ty + 13} dominantBaseline="middle"
                    fill="#000000" fontSize={11} fontFamily={FONT} fontWeight={500}
                  >{hp.label}</text>
                </g>
              );
            })()}
          </motion.svg>
        </div>
        );
      })()}

      {/* ═══ CHAT (v2.4 full integration) ═══ */}
      {layer === 'chat' && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '36px 24px 8px', maxWidth: 720, width: '100%', margin: '0 auto' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ color: '#ffd700', fontSize: 11, fontFamily: FONT, letterSpacing: 2, opacity: 0.5 }}>TRINITY CHAT v2.6</div>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: connected ? '#00e599' : '#ff4444', boxShadow: `0 0 4px ${connected ? '#00e599' : '#ff4444'}` }} />
            </div>
            <button onClick={async () => { await clearContext(); setMessages([]); }} style={{ ...glassStyle(), padding: '3px 10px', color: 'rgba(255,255,255,0.3)', cursor: 'pointer', fontSize: 10, fontFamily: FONT, letterSpacing: 1 }}>CLEAR</button>
          </div>
          <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '12px 24px', maxWidth: 720, width: '100%', margin: '0 auto' }}>
            {messages.length === 0 && (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '55vh', opacity: 0.15 }}>
                <div style={{ fontSize: 64, color: '#ffd700', fontFamily: 'serif' }}>&phi;</div>
                <div style={{ color: '#888', fontFamily: FONT, fontSize: 13, marginTop: 10 }}>Введите сообщение в волновое поле</div>
              </div>
            )}
            <AnimatePresence>
              {messages.map(msg => <ChatMessage key={msg.id} {...msg} />)}
            </AnimatePresence>
            {chatLoading && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: 12 }}>
                <div style={{ padding: '10px 14px', borderRadius: '14px 14px 14px 4px', background: 'rgba(0,229,153,0.08)', border: '1px solid rgba(0,229,153,0.15)', display: 'flex', gap: 4, alignItems: 'center' }}>
                  {[0, 1, 2].map(i => (
                    <motion.span key={i} animate={{ opacity: [0.3, 1, 0.3] }}
                      transition={{ duration: 1.2, repeat: Infinity, delay: i * 0.2 }}
                      style={{ width: 6, height: 6, borderRadius: '50%', background: '#00e599', display: 'inline-block' }} />
                  ))}
                </div>
              </motion.div>
            )}
          </div>
          <div style={{ padding: '12px 24px 20px', maxWidth: 720, width: '100%', margin: '0 auto' }}>
            {showChatAttach && (
              <div style={{ display: 'flex', gap: 8, padding: '8px 16px', marginBottom: 6, ...glassStyle('rgba(255,215,0,0.1)') }}>
                <input type="text" value={chatImagePath} onChange={e => setChatImagePath(e.target.value)}
                  placeholder="image_path (optional)" disabled={chatLoading}
                  style={{ flex: 1, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6, padding: '4px 8px', outline: 'none', color: '#aaa', fontSize: 11, fontFamily: MONO }} />
                <input type="text" value={chatAudioPath} onChange={e => setChatAudioPath(e.target.value)}
                  placeholder="audio_path (optional)" disabled={chatLoading}
                  style={{ flex: 1, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6, padding: '4px 8px', outline: 'none', color: '#aaa', fontSize: 11, fontFamily: MONO }} />
              </div>
            )}
            <div style={{ display: 'flex', gap: 8, ...glassStyle('rgba(255,215,0,0.15)'), padding: '12px 16px' }}>
              <button onClick={() => setShowChatAttach(!showChatAttach)} style={{
                background: showChatAttach ? 'rgba(255,215,0,0.15)' : 'rgba(255,255,255,0.05)',
                border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6, padding: '4px 8px',
                color: showChatAttach ? '#ffd700' : '#666', cursor: 'pointer', fontFamily: MONO, fontSize: 14,
              }} title="Attach image/audio path">+</button>
              <input type="text" value={chatText} onChange={e => setChatText(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleChatSend()} disabled={chatLoading}
                placeholder="Сообщение в волновое поле..." autoFocus
                style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: '#fff', fontSize: 14, fontFamily: FONT }} />
              <span style={{ color: 'rgba(255,255,255,0.12)', fontSize: 10, alignSelf: 'center', fontFamily: FONT }}>enter</span>
            </div>
          </div>
        </div>
      )}

      {/* ═══ EDITOR ═══ */}
      {layer === 'editor' && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 36 }}>
          <div style={{ width: '92%', maxWidth: 850, flex: 1, display: 'flex', flexDirection: 'column', gap: 10, padding: '8px 0' }}>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              {Object.entries(EDITOR_PRESETS).map(([k, v]) => (
                <button key={k} onClick={() => handleLangSwitch(k)} style={{
                  padding: '5px 14px', borderRadius: 10,
                  background: editorLang === k ? `${v.color}25` : 'rgba(255,255,255,0.03)',
                  border: `1px solid ${editorLang === k ? v.color + '50' : 'rgba(255,255,255,0.06)'}`,
                  color: editorLang === k ? v.color : 'rgba(255,255,255,0.3)',
                  cursor: 'pointer', fontSize: 11, fontFamily: FONT, fontWeight: 500,
                }}>{v.label}</button>
              ))}
              <div style={{ flex: 1 }} />
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: connected ? '#00e599' : '#ff4444' }} />
              <span style={{ color: 'rgba(255,255,255,0.2)', fontSize: 9, fontFamily: MONO }}>{connected ? 'backend' : 'offline'}</span>
            </div>
            <div style={{ flex: 1 }}>
              <textarea value={editorCode} onChange={e => setEditorCode(e.target.value)} spellCheck={false}
                style={{ width: '100%', height: '100%', ...glassStyle(`${EDITOR_PRESETS[editorLang]?.color || '#0f8'}20`), padding: 18, color: EDITOR_PRESETS[editorLang]?.color || '#0f8', fontSize: 13, fontFamily: MONO, resize: 'none', outline: 'none', lineHeight: 1.7 }} />
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <button onClick={handleEditorRun} disabled={editorCompiling} style={{ padding: '7px 22px', borderRadius: 10, background: editorCompiling ? 'rgba(255,255,255,0.05)' : 'rgba(0,255,136,0.15)', border: '1px solid rgba(0,255,136,0.3)', color: editorCompiling ? '#666' : '#00ff88', cursor: editorCompiling ? 'default' : 'pointer', fontSize: 12, fontFamily: FONT, fontWeight: 600, letterSpacing: 1 }}>
                {editorCompiling ? '...' : editorLang === 'vibee' ? 'COMPILE' : editorLang === 'zig' ? 'ANALYZE' : 'RUN'}
              </button>
              <div style={{ flex: 1, color: 'rgba(255,255,255,0.15)', fontSize: 10, fontFamily: FONT }}>
                {editorLang === 'js' ? 'Hot-reload' : editorLang === 'vibee' ? 'Real VIBEE Parse (backend)' : 'AI Analysis (backend)'}
              </div>
            </div>
            {editorOutput && (
              <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
                style={{ ...glassStyle('rgba(255,215,0,0.12)'), padding: 14, fontFamily: MONO, fontSize: 12, color: editorOutput.startsWith('Error') ? '#ff4444' : '#ffd700', whiteSpace: 'pre-wrap', maxHeight: 200, overflowY: 'auto', lineHeight: 1.6 }}>
                {editorOutput}
              </motion.div>
            )}
          </div>
        </div>
      )}

      {/* ═══ FINDER (live search + category filter + OVERLAY preview) ═══ */}
      {layer === 'finder' && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 36 }}>
          <div style={{ width: '92%', maxWidth: 600, display: 'flex', flexDirection: 'column', gap: 10, padding: '16px 0', maxHeight: 'calc(100vh - 80px)', overflow: 'hidden' }}>
            {/* Search */}
            <div style={{ display: 'flex', gap: 8, ...glassStyle('rgba(0,200,255,0.15)'), padding: '12px 16px' }}>
              <span style={{ fontSize: 16, opacity: 0.4 }}>🔍</span>
              <input type="text" value={finderQuery} onChange={e => setFinderQuery(e.target.value)} placeholder="Поиск файлов..." autoFocus
                style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: '#fff', fontSize: 14, fontFamily: FONT }} />
              {(finderQuery || finderCategoryFilter) && <span style={{ color: 'rgba(255,255,255,0.2)', fontSize: 11, fontFamily: FONT, alignSelf: 'center' }}>{finderResults.length}</span>}
            </div>
            {/* Category filter pills */}
            <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
              {Object.entries(CATEGORY_LABELS).map(([cat, label]) => {
                const count = activeFileIndex.filter(f => f.category === cat && (!finderQuery || f.path.toLowerCase().includes(finderQuery.toLowerCase()))).length;
                if (count === 0) return null;
                const active = finderCategoryFilter === cat;
                return (
                  <button key={cat} onClick={() => setFinderCategoryFilter(active ? null : cat)} style={{
                    fontSize: 10, padding: '3px 8px', borderRadius: 8,
                    background: active ? 'rgba(0,200,255,0.15)' : 'rgba(255,255,255,0.04)',
                    border: `1px solid ${active ? 'rgba(0,200,255,0.4)' : 'rgba(255,255,255,0.06)'}`,
                    color: active ? '#00ccff' : 'rgba(255,255,255,0.4)',
                    fontFamily: FONT, cursor: 'pointer',
                  }}>
                    {label}: {count}
                  </button>
                );
              })}
            </div>
            {/* Results — full width, no side panel */}
            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 5 }}>
              <AnimatePresence>
                {finderResults.map((file, i) => (
                  <motion.div key={file.path} initial={{ opacity: 0, x: -15 }} animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: 15 }} transition={{ delay: i * 0.02 }}
                    onClick={() => handleFilePreview(file)}
                    style={{
                      ...glassStyle(`${file.color}20`), padding: '9px 12px', cursor: 'pointer',
                      display: 'flex', alignItems: 'center', gap: 10,
                      background: selectedFile?.path === file.path ? `${file.color}12` : 'rgba(0,0,0,0.2)',
                    }}>
                    <span style={{ fontSize: 13 }}>{file.icon}</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ color: file.color, fontSize: 11, fontFamily: MONO, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{file.path}</div>
                      <div style={{ color: 'rgba(255,255,255,0.15)', fontSize: 9, fontFamily: FONT }}>{CATEGORY_LABELS[file.category]}</div>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
              {!finderQuery && !finderCategoryFilter && (
                <div style={{ textAlign: 'center', color: 'rgba(255,255,255,0.1)', fontSize: 12, marginTop: 30, fontFamily: FONT }}>
                  {backendFiles ? `${backendFiles.length} files from backend` : `${FILE_INDEX.length} files (static)`} — введите запрос или выберите категорию
                </div>
              )}
            </div>
          </div>

          {/* ═══ FILE PREVIEW OVERLAY (centered, no side panel) ═══ */}
          <AnimatePresence>
            {selectedFile && (
              <motion.div
                initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                onClick={() => { setSelectedFile(null); setFilePreview(''); }}
                style={{ position: 'fixed', inset: 0, zIndex: 300, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
              >
                <motion.div
                  initial={{ opacity: 0, scale: 0.9, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.9 }}
                  transition={{ type: 'spring', damping: 25 }}
                  onClick={e => e.stopPropagation()}
                  style={{ width: '88%', maxWidth: 700, maxHeight: '70vh', ...glassStyle(`${selectedFile.color}20`), padding: 20, display: 'flex', flexDirection: 'column', gap: 10, overflow: 'hidden' }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ color: selectedFile.color, fontSize: 13, fontFamily: MONO, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {selectedFile.icon} {selectedFile.path}
                    </span>
                    <button onClick={() => { setSelectedFile(null); setFilePreview(''); }} style={{
                      background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
                      borderRadius: 6, color: 'rgba(255,255,255,0.4)', cursor: 'pointer', fontSize: 11, padding: '2px 8px', fontFamily: MONO,
                    }}>ESC</button>
                  </div>
                  <div style={{ color: 'rgba(255,255,255,0.15)', fontSize: 9, fontFamily: FONT }}>{CATEGORY_LABELS[selectedFile.category]}</div>
                  <div style={{ flex: 1, overflowY: 'auto', fontFamily: MONO, fontSize: 11, color: 'rgba(255,255,255,0.55)', whiteSpace: 'pre-wrap', lineHeight: 1.6, padding: '8px 0' }}>
                    {filePreviewLoading ? 'Loading...' : filePreview || 'Loading preview...'}
                  </div>
                </motion.div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      )}

      {/* ═══ VISION (real drag-drop + paste + preview) ═══ */}
      {layer === 'vision' && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 36 }}>
          <div style={{ width: '92%', maxWidth: 600, display: 'flex', flexDirection: 'column', gap: 16, padding: '24px 0' }}>
            <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, letterSpacing: 2, fontFamily: FONT, textAlign: 'center' }}>VISION ANALYSIS</div>
            <div style={{ display: 'flex', gap: 8, ...glassStyle('rgba(255,102,170,0.15)'), padding: '12px 16px' }}>
              <span style={{ fontSize: 16, opacity: 0.4 }}>👁️</span>
              <input type="text" value={visionUrl} onChange={e => { setVisionUrl(e.target.value); setVisionPreviewSrc(''); }}
                onKeyDown={e => e.key === 'Enter' && handleVisionAnalyze()}
                placeholder="URL изображения, путь, или drag-and-drop..."
                style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: '#fff', fontSize: 14, fontFamily: FONT }} />
              <button onClick={handleVisionAnalyze} disabled={visionLoading}
                style={{ padding: '4px 14px', borderRadius: 8, background: 'rgba(255,102,170,0.15)', border: '1px solid rgba(255,102,170,0.3)', color: visionLoading ? '#666' : '#ff66aa', cursor: visionLoading ? 'default' : 'pointer', fontSize: 11, fontFamily: FONT, fontWeight: 600 }}>
                {visionLoading ? '...' : 'ANALYZE'}
              </button>
            </div>
            <div ref={visionDropRef} onDragOver={handleDragOver} onDragLeave={handleDragLeave} onDrop={handleDrop}
              style={{
                ...glassStyle(isDragOver ? 'rgba(255,102,170,0.4)' : 'rgba(255,102,170,0.1)'),
                padding: visionPreviewSrc ? 10 : 40, textAlign: 'center', minHeight: 200,
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', transition: 'border-color 0.3s',
              }}>
              {visionPreviewSrc ? (
                <img src={visionPreviewSrc} alt="Preview" style={{ maxWidth: '100%', maxHeight: 250, borderRadius: 10, objectFit: 'contain' }} />
              ) : (
                <>
                  <div style={{ fontSize: 48, opacity: isDragOver ? 0.5 : 0.2, marginBottom: 12, transition: 'opacity 0.3s' }}>👁️</div>
                  <div style={{ color: isDragOver ? '#ff66aa' : 'rgba(255,255,255,0.2)', fontSize: 13, fontFamily: FONT, transition: 'color 0.3s' }}>
                    {isDragOver ? 'Отпустите изображение' : 'Drag & drop, Ctrl+V, или введите URL'}
                  </div>
                  <div style={{ color: 'rgba(255,255,255,0.1)', fontSize: 11, fontFamily: FONT, marginTop: 6 }}>Анализ через волновое поле сознания</div>
                </>
              )}
            </div>
            {visionAnalysis && (
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
                style={{ ...glassStyle('rgba(255,102,170,0.12)'), padding: 18, fontFamily: MONO, fontSize: 12, color: '#ff66aa', whiteSpace: 'pre-wrap', lineHeight: 1.7 }}>
                {visionAnalysis}
              </motion.div>
            )}
          </div>
        </div>
      )}

      {/* ═══ VOICE (real Web Audio API + Speech-to-Text) ═══ */}
      {layer === 'voice' && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28, width: '90%', maxWidth: 500 }}>
            <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, letterSpacing: 2, fontFamily: FONT }}>VOICE WAVE FIELD</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 3, height: 120 }}>
              {voiceBars.map((v, i) => (
                <motion.div key={i} animate={{ height: voiceActive ? v * 100 + 4 : 4 }}
                  transition={{ duration: 0.05 }}
                  style={{ width: 6, borderRadius: 3, minHeight: 4, background: voiceActive ? `hsl(${30 + i * 3}, 80%, ${50 + v * 30}%)` : 'rgba(255,255,255,0.08)' }} />
              ))}
            </div>
            <motion.button onClick={toggleVoice} whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}
              style={{
                width: 80, height: 80, borderRadius: '50%',
                background: voiceActive ? 'rgba(255,136,0,0.25)' : 'rgba(255,255,255,0.05)',
                border: `2px solid ${voiceActive ? '#ff8800' : 'rgba(255,255,255,0.1)'}`,
                color: voiceActive ? '#ff8800' : 'rgba(255,255,255,0.3)',
                cursor: 'pointer', fontSize: 28, display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: voiceActive ? '0 0 30px rgba(255,136,0,0.3)' : 'none', transition: 'all 0.3s',
              }}>🎙️</motion.button>
            <div style={{ color: 'rgba(255,255,255,0.2)', fontSize: 12, fontFamily: FONT }}>
              {voiceActive ? 'Слушаю... нажмите для остановки' : 'Нажмите — реальный микрофон (Web Audio API)'}
            </div>
            {voiceTranscript && (
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
                style={{ ...glassStyle('rgba(255,136,0,0.15)'), padding: '12px 16px', width: '100%' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <span style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontFamily: FONT, letterSpacing: 1 }}>TRANSCRIPT</span>
                  <button onClick={handleVoiceSend} style={{ padding: '4px 12px', borderRadius: 8, background: 'rgba(255,215,0,0.15)', border: '1px solid rgba(255,215,0,0.3)', color: '#ffd700', cursor: 'pointer', fontSize: 10, fontFamily: FONT, fontWeight: 600 }}>SEND TO CHAT</button>
                </div>
                <div style={{ color: '#ff8800', fontSize: 14, fontFamily: FONT, lineHeight: 1.6 }}>{voiceTranscript}</div>
              </motion.div>
            )}
          </div>
        </div>
      )}

      {/* ═══ MIRROR OF THREE WORLDS (Зеркало Трёх Миров) v2.7 — Storage Network Dashboard ═══ */}
      {layer === 'tools' && (() => {
        const srcColor = (src: string) =>
          src === 'Symbolic' ? '#ffd700' : src === 'TVCCorpus' ? '#00ccff' :
          src === 'GroqAPI' ? '#aa66ff' : src === 'ClaudeAPI' ? '#cc66ff' :
          src === 'Tool' ? '#00ff88' : src === 'LocalLLM' ? '#ff8800' : '#ff4444';
        const srcIcon = (src: string) =>
          src === 'Symbolic' ? '⚡' : src === 'TVCCorpus' ? '💎' :
          src === 'GroqAPI' ? '🌀' : src === 'ClaudeAPI' ? '🧠' :
          src === 'Tool' ? '🔧' : src === 'LocalLLM' ? '🔥' : '❌';
        const fmtUptime = (s: number) => {
          const h = Math.floor(s / 3600); const m = Math.floor((s % 3600) / 60);
          return h > 0 ? `${h}h ${m}m` : m > 0 ? `${m}m ${s % 60}s` : `${s}s`;
        };
        const fmtLat = (us: number) => us < 1000 ? `${us}us` : us < 1_000_000 ? `${(us / 1000).toFixed(1)}ms` : `${(us / 1_000_000).toFixed(2)}s`;
        const fmtTs = (ts: number) => { const d = new Date(ts * 1000); return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}:${String(d.getSeconds()).padStart(2,'0')}`; };
        const inputStyle: React.CSSProperties = { width: '100%', padding: '6px 8px', borderRadius: 8, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff', fontSize: 11, fontFamily: MONO, outline: 'none' };
        // Storage helpers (v2.7)
        const fmtBytes = (b: number) => {
          if (b >= 1_073_741_824) return `${(b / 1_073_741_824).toFixed(1)} GB`;
          if (b >= 1_048_576) return `${(b / 1_048_576).toFixed(1)} MB`;
          if (b >= 1024) return `${(b / 1024).toFixed(1)} KB`;
          return `${b} B`;
        };
        const storagePercent = storageMetrics
          ? (storageMetrics.total_bytes_used / (storageMetrics.total_bytes_used + storageMetrics.total_bytes_available) * 100)
          : 0;
        const posPassRate = storageMetrics && storageMetrics.pos_challenges_issued > 0
          ? (storageMetrics.pos_challenges_passed / storageMetrics.pos_challenges_issued * 100)
          : 0;
        const toggleStorageSection = (key: string) =>
          setStorageCollapsed(prev => ({ ...prev, [key]: !prev[key] }));
        const sectionHeader = (key: string, label: string, color: string) => (
          <div onClick={() => toggleStorageSection(key)}
            style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer', padding: '2px 0' }}>
            <span style={{ color, fontSize: 8, fontFamily: MONO, fontWeight: 600, letterSpacing: 1 }}>{label}</span>
            <span style={{ color: 'rgba(255,255,255,0.2)', fontSize: 8, fontFamily: MONO }}>
              {storageCollapsed[key] ? '+' : '-'}
            </span>
          </div>
        );
        return (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 28 }}>
          <div style={{ width: '96%', maxWidth: 1100, display: 'flex', flexDirection: 'column', gap: 8, padding: '8px 0', height: 'calc(100vh - 50px)', overflow: 'hidden' }}>
            {/* Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 4px', flexShrink: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ color: 'rgba(255,255,255,0.35)', fontSize: 11, letterSpacing: 2, fontFamily: FONT }}>ЗЕРКАЛО ТРЁХ МИРОВ v2.8</div>
                {mirrorStatus?.uptime_s != null && (
                  <span style={{ color: 'rgba(255,255,255,0.15)', fontSize: 9, fontFamily: MONO }}>uptime {fmtUptime(mirrorStatus.uptime_s)}</span>
                )}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                {mirrorStatus?.dukh && (
                  <span style={{ color: 'rgba(255,255,255,0.15)', fontSize: 9, fontFamily: MONO }}>
                    {mirrorStatus.dukh.total_queries} queries | {mirrorStatus.dukh.energy_saved_wh.toFixed(4)} Wh saved
                  </span>
                )}
                <motion.div animate={{ scale: mirrorLoading ? [1, 1.3, 1] : 1 }} transition={{ repeat: mirrorLoading ? Infinity : 0, duration: 0.8 }}
                  style={{ width: 6, height: 6, borderRadius: '50%', background: mirrorStatus?.status === 'ok' ? '#00e599' : '#ff4444' }} />
                <span style={{ color: 'rgba(255,255,255,0.2)', fontSize: 9, fontFamily: MONO }}>
                  {mirrorStatus?.status === 'ok' ? (mirrorStatus.razum ? 'LIVE' : 'INIT') : 'OFFLINE'}
                </span>
                {storageMetrics && (
                  <span style={{ color: 'rgba(255,255,255,0.15)', fontSize: 9, fontFamily: MONO }}>
                    | {storageMetrics.nodes_alive} nodes | {storageMetrics.total_shards} shards
                  </span>
                )}
              </div>
            </div>

            {/* Three columns */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, flex: 1, minHeight: 0 }}>

              {/* ═══ RAZUM (Mind) — Multi-turn Chat + Reflection + Logs (v2.6) ═══ */}
              <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.05 }}
                style={{ ...glassStyle('rgba(255,215,0,0.08)'), padding: 12, display: 'flex', flexDirection: 'column', gap: 5, borderTop: '2px solid rgba(255,215,0,0.4)', overflow: 'hidden' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ color: '#ffd700', fontSize: 12, fontFamily: FONT, fontWeight: 700, letterSpacing: 1 }}>РАЗУМ</div>
                  <span style={{ color: 'rgba(255,215,0,0.3)', fontSize: 8, fontFamily: MONO }}>Chat + Reflection + φ</span>
                </div>

                {/* Chat history (last 5 messages) */}
                <div style={{ flex: 1, minHeight: 40, maxHeight: 140, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 3 }}>
                  {mChatHistory.length === 0 ? (
                    <div style={{ color: 'rgba(255,215,0,0.15)', fontSize: 8, fontFamily: MONO, padding: 8, textAlign: 'center' }}>Ask Trinity anything. Chat history appears here.</div>
                  ) : mChatHistory.slice(-5).map((m, i) => (
                    <motion.div key={`mh-${i}`} initial={{ opacity: 0, x: m.role === 'user' ? 8 : -8 }} animate={{ opacity: 1, x: 0 }}
                      style={{ padding: '3px 6px', borderRadius: 6, background: m.role === 'user' ? 'rgba(255,215,0,0.06)' : 'rgba(255,215,0,0.03)', alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start', maxWidth: '90%' }}>
                      {m.role === 'assistant' && m.source && (
                        <div style={{ fontSize: 7, fontFamily: MONO, color: srcColor(m.source), marginBottom: 1 }}>{srcIcon(m.source)} {m.source} {m.conf ? `${(m.conf * 100).toFixed(0)}%` : ''} {m.lat ? fmtLat(m.lat) : ''}</div>
                      )}
                      <div style={{ fontSize: 9, fontFamily: MONO, color: m.role === 'user' ? '#ffd700' : 'rgba(255,215,0,0.7)', lineHeight: 1.3, whiteSpace: 'pre-wrap' }}>
                        {m.text.slice(0, 150)}{m.text.length > 150 ? '...' : ''}
                      </div>
                    </motion.div>
                  ))}
                </div>

                {/* Chat input */}
                <form onSubmit={e => { e.preventDefault(); handleMirrorChat(); }} style={{ display: 'flex', gap: 4 }}>
                  <input value={mChatInput} onChange={e => setMChatInput(e.target.value)} placeholder="Ask Trinity..."
                    style={{ ...inputStyle, borderColor: 'rgba(255,215,0,0.2)' }} />
                  <button type="submit" disabled={mChatSending} style={{ padding: '4px 10px', borderRadius: 8, background: 'rgba(255,215,0,0.15)', border: '1px solid rgba(255,215,0,0.3)', color: mChatSending ? '#666' : '#ffd700', cursor: mChatSending ? 'default' : 'pointer', fontSize: 10, fontFamily: MONO, flexShrink: 0 }}>
                    {mChatSending ? '...' : '->'}
                  </button>
                </form>

                {/* Self-reflection wave (v2.6) */}
                {selfReflection && (
                  <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
                    style={{ padding: '4px 8px', borderRadius: 6, background: 'linear-gradient(135deg, rgba(255,215,0,0.08), rgba(170,100,255,0.06))', border: '1px solid rgba(255,215,0,0.15)' }}>
                    <div style={{ fontSize: 7, fontFamily: MONO, color: 'rgba(255,215,0,0.5)', letterSpacing: 1, marginBottom: 2 }}>SELF-REFLECTION</div>
                    <div style={{ fontSize: 8, fontFamily: MONO, color: 'rgba(255,215,0,0.6)', lineHeight: 1.3 }}>{selfReflection}</div>
                  </motion.div>
                )}

                {/* Query path */}
                {mirrorStatus?.razum && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 3, fontSize: 8, fontFamily: MONO, padding: '2px 0' }}>
                    <span style={{ color: '#ffd700' }}>⚡Sym</span>
                    <span style={{ color: 'rgba(255,255,255,0.12)' }}>→</span>
                    <span style={{ color: '#00ccff', opacity: ['RouteTVC', 'RouteMemory'].includes(mirrorStatus.razum.last_routing) ? 1 : 0.3 }}>💎TVC</span>
                    <span style={{ color: 'rgba(255,255,255,0.12)' }}>→</span>
                    <span style={{ color: '#aa66ff', opacity: ['RouteGroq', 'RouteClaude', 'RouteLocalLLM', 'RouteFallback'].includes(mirrorStatus.razum.last_routing) ? 1 : 0.3 }}>🧠LLM</span>
                    <span style={{ color: 'rgba(255,215,0,0.3)', marginLeft: 'auto' }}>{mirrorStatus.razum.last_routing.replace('Route', '')}</span>
                  </div>
                )}

                {/* Metrics row */}
                {mirrorStatus?.razum && (
                  <div style={{ display: 'flex', gap: 6, fontSize: 8, fontFamily: MONO, flexWrap: 'wrap' }}>
                    <span style={{ color: mirrorStatus.razum.symbolic_hits > 0 ? '#ffd700' : 'rgba(255,215,0,0.3)' }}>Hits:{mirrorStatus.razum.symbolic_hits}</span>
                    <span style={{ color: mirrorStatus.razum.symbolic_hit_rate > 0 ? '#ffd700' : 'rgba(255,215,0,0.3)' }}>Rate:{(mirrorStatus.razum.symbolic_hit_rate * 100).toFixed(0)}%</span>
                    <span style={{ color: mirrorStatus.razum.memory_entries > 0 ? '#ffd700' : 'rgba(255,215,0,0.3)' }}>Mem:{mirrorStatus.razum.memory_entries}/256</span>
                    <span style={{ color: mirrorStatus.razum.llm_loaded ? '#00e599' : 'rgba(255,215,0,0.3)' }}>LLM:{mirrorStatus.razum.llm_loaded ? 'ON' : 'OFF'}</span>
                  </div>
                )}

                {/* ── Storage Routing + Self-healing (v2.7) ── */}
                {storageMetrics && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '2px 0', borderTop: '1px solid rgba(255,215,0,0.1)' }}>
                    {sectionHeader('routing', 'STORAGE ROUTING', '#ffd700')}
                    {!storageCollapsed['routing'] && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                        <div style={{ display: 'flex', gap: 4, fontSize: 8, fontFamily: MONO }}>
                          <span style={{ color: '#ffd700' }}>Rep x{storageMetrics.target_replication}</span>
                          <span style={{ color: storageMetrics.nodes_alive === storageMetrics.node_count ? '#00e599' : '#ffd700' }}>
                            Nodes:{storageMetrics.nodes_alive}/{storageMetrics.node_count}
                          </span>
                          <span style={{ color: 'rgba(255,215,0,0.5)' }}>
                            Avg:{storageMetrics.reputation_avg.toFixed(2)}
                          </span>
                        </div>
                        {storageMetrics.scrub_corruptions > 0 && (
                          <div style={{ fontSize: 7, fontFamily: MONO, color: '#ff8800', padding: '1px 3px' }}>
                            Self-heal: {storageMetrics.scrub_corruptions} corruption(s), {storageMetrics.recoveries_successful} recovered
                          </div>
                        )}
                        {storageMetrics.shards_rebalanced > 0 && (
                          <div style={{ fontSize: 7, fontFamily: MONO, color: '#00e599', padding: '1px 3px' }}>
                            Rebalancer: {storageMetrics.shards_rebalanced} shards across {storageMetrics.nodes_alive} nodes
                          </div>
                        )}
                        {storageMetrics.nodes_dead > 0 && (
                          <div style={{ fontSize: 7, fontFamily: MONO, color: '#ff4444', padding: '1px 3px' }}>
                            Alert: {storageMetrics.nodes_dead} node(s) offline
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )}

                {/* ── DHT Kademlia Routing (v2.8) ── */}
                {storageMetrics && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '2px 0', borderTop: '1px solid rgba(255,215,0,0.1)' }}>
                    {sectionHeader('dht', 'DHT KADEMLIA', '#ffd700')}
                    {!storageCollapsed['dht'] && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                        <div style={{ display: 'flex', gap: 4, fontSize: 8, fontFamily: MONO }}>
                          <span style={{ color: '#ffd700' }}>Peers:{storageMetrics.dht_peers}</span>
                          <span style={{ color: '#00e599' }}>Buckets:{storageMetrics.dht_buckets_used}/256</span>
                          <span style={{ color: 'rgba(255,215,0,0.5)' }}>Entries:{storageMetrics.dht_entries_stored}</span>
                        </div>
                        <div style={{ display: 'flex', gap: 4, fontSize: 8, fontFamily: MONO }}>
                          <span style={{ color: '#ffd700' }}>Lookups:{storageMetrics.dht_lookups}</span>
                          <span style={{ color: storageMetrics.dht_lookup_avg_hops < 4 ? '#00e599' : '#ff8800' }}>
                            Avg hops:{storageMetrics.dht_lookup_avg_hops.toFixed(1)}
                          </span>
                        </div>
                        {/* XOR routing health bar */}
                        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                          <span style={{ fontSize: 7, fontFamily: MONO, color: 'rgba(255,215,0,0.4)' }}>XOR:</span>
                          <div style={{ flex: 1, height: 3, background: 'rgba(255,215,0,0.1)', borderRadius: 2, overflow: 'hidden' }}>
                            <div style={{ width: `${Math.min(100, (storageMetrics.dht_buckets_used / 256) * 100 * 8)}%`, height: '100%', background: 'linear-gradient(90deg, #ffd700, #00e599)', borderRadius: 2 }} />
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {/* Live log */}
                <div style={{ minHeight: 30, maxHeight: 60, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 1 }}>
                  <div style={{ color: 'rgba(255,255,255,0.12)', fontSize: 7, fontFamily: MONO, letterSpacing: 1, position: 'sticky', top: 0, background: 'rgba(0,0,0,0.4)', padding: '1px 0' }}>LIVE LOG</div>
                  {mirrorLogs.filter(l => l.src === 'Symbolic' || l.src === 'TVCCorpus').length === 0 ? (
                    <div style={{ color: 'rgba(255,215,0,0.15)', fontSize: 8, fontFamily: MONO, padding: 4, textAlign: 'center' }}>Waiting for routing events...</div>
                  ) : mirrorLogs.filter(l => l.src === 'Symbolic' || l.src === 'TVCCorpus').slice(-8).map((l, i) => (
                    <div key={`r-${l.ts}-${i}`} style={{ fontSize: 8, fontFamily: MONO, color: srcColor(l.src), lineHeight: 1.3, padding: '1px 3px' }}>
                      <span style={{ color: 'rgba(255,255,255,0.2)' }}>{fmtTs(l.ts)}</span> {srcIcon(l.src)} {l.q.slice(0, 20)}{l.q.length > 20 ? '..' : ''} {(l.conf * 100).toFixed(0)}% {fmtLat(l.lat)}
                    </div>
                  ))}
                </div>
              </motion.div>

              {/* ═══ MATERIYA (Matter) — Finder + Preview + Corpus (v2.6) ═══ */}
              <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}
                style={{ ...glassStyle('rgba(0,200,255,0.08)'), padding: 12, display: 'flex', flexDirection: 'column', gap: 5, borderTop: '2px solid rgba(0,200,255,0.4)', overflow: 'hidden' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ color: '#00ccff', fontSize: 12, fontFamily: FONT, fontWeight: 700, letterSpacing: 1 }}>МАТЕРИЯ</div>
                  <span style={{ color: 'rgba(0,200,255,0.3)', fontSize: 8, fontFamily: MONO }}>Finder + Preview + π</span>
                </div>

                {/* File search */}
                <input value={mFinderQuery} onChange={e => { setMFinderQuery(e.target.value); setMFilePreview(null); }} placeholder="Search files..."
                  style={{ ...inputStyle, borderColor: 'rgba(0,200,255,0.2)' }} />

                {/* Inline file preview (v2.6) */}
                {mFilePreview ? (
                  <motion.div initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }}
                    style={{ ...glassStyle('rgba(0,200,255,0.06)'), padding: '6px 8px', borderRadius: 8, maxHeight: 100, overflowY: 'auto', position: 'relative' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 3 }}>
                      <span style={{ color: '#00ccff', fontSize: 8, fontFamily: MONO }}>{mFilePreview.path.split('/').pop()}</span>
                      <div style={{ display: 'flex', gap: 4 }}>
                        <button onClick={() => { setFinderQuery(mFilePreview!.path); setSelectedFile({ path: mFilePreview!.path, category: 'core', icon: '📄', color: '#00ccff' } as FinderFile); switchLayer('finder'); }}
                          style={{ padding: '2px 6px', borderRadius: 4, background: 'rgba(0,200,255,0.15)', border: '1px solid rgba(0,200,255,0.3)', color: '#00ccff', cursor: 'pointer', fontSize: 7, fontFamily: MONO }}>Open</button>
                        <button onClick={() => setMFilePreview(null)}
                          style={{ padding: '2px 6px', borderRadius: 4, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.4)', cursor: 'pointer', fontSize: 7, fontFamily: MONO }}>×</button>
                      </div>
                    </div>
                    <pre style={{ fontSize: 8, fontFamily: MONO, color: 'rgba(0,200,255,0.6)', lineHeight: 1.3, whiteSpace: 'pre-wrap', margin: 0 }}>
                      {mPreviewLoading ? 'Loading...' : mFilePreview.content}
                    </pre>
                  </motion.div>
                ) : (
                  /* File results */
                  <div style={{ flex: 1, minHeight: 40, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {mFinderResults.map((f, i) => (
                      <motion.div key={f.path} initial={{ opacity: 0, x: -4 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.02 }}
                        style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '3px 6px', borderRadius: 6, background: 'rgba(0,200,255,0.03)', cursor: 'pointer' }}
                        onClick={() => handleMirrorFilePreview(f)}>
                        <span style={{ fontSize: 10 }}>{f.icon}</span>
                        <span style={{ color: f.color, fontSize: 9, fontFamily: MONO, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.path}</span>
                        <span style={{ color: 'rgba(255,255,255,0.15)', fontSize: 7, fontFamily: MONO }}>{f.category}</span>
                      </motion.div>
                    ))}
                  </div>
                )}

                {/* Corpus metrics */}
                {mirrorStatus?.materiya && (
                  <div style={{ display: 'flex', gap: 6, fontSize: 8, fontFamily: MONO, flexWrap: 'wrap', padding: '2px 0', borderTop: '1px solid rgba(0,200,255,0.1)' }}>
                    <span style={{ color: mirrorStatus.materiya.tvc_enabled ? '#00ccff' : 'rgba(0,200,255,0.3)' }}>TVC:{mirrorStatus.materiya.tvc_enabled ? 'ON' : 'OFF'}</span>
                    <span style={{ color: mirrorStatus.materiya.tvc_corpus_size > 0 ? '#00ccff' : 'rgba(0,200,255,0.3)' }}>Corpus:{mirrorStatus.materiya.tvc_corpus_size}</span>
                    <span style={{ color: mirrorStatus.materiya.cache_hit_rate > 0 ? '#00ccff' : 'rgba(0,200,255,0.3)' }}>Cache:{(mirrorStatus.materiya.cache_hit_rate * 100).toFixed(0)}%</span>
                    <span style={{ color: 'rgba(0,200,255,0.3)' }}>{activeFileIndex.length} files{backendFiles ? ' (live)' : ''}</span>
                  </div>
                )}

                {/* ── Storage Network: Peers + Shards + RS (v2.7) ── */}
                {storageMetrics && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 3, padding: '4px 0', borderTop: '1px solid rgba(0,200,255,0.1)' }}>
                    {sectionHeader('peers', 'PEER HEALTH', '#00ccff')}
                    {!storageCollapsed['peers'] && (
                      <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
                        <div style={{ display: 'flex', gap: 2, flex: 1 }}>
                          {Array.from({ length: storageMetrics.node_count }, (_, i) => (
                            <div key={i} style={{
                              width: 8, height: 8, borderRadius: 2,
                              background: i < storageMetrics.nodes_alive ? '#00e599' : '#ff4444',
                              opacity: i < storageMetrics.nodes_alive ? 0.8 : 0.5,
                            }} />
                          ))}
                        </div>
                        <span style={{ color: '#00ccff', fontSize: 8, fontFamily: MONO }}>
                          {storageMetrics.nodes_alive}/{storageMetrics.node_count}
                        </span>
                      </div>
                    )}

                    {sectionHeader('shards', 'SHARD DISTRIBUTION', '#00ccff')}
                    {!storageCollapsed['shards'] && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                        <div style={{ display: 'flex', gap: 6, fontSize: 8, fontFamily: MONO }}>
                          <span style={{ color: '#00ccff' }}>Shards:{storageMetrics.total_shards}</span>
                          <span style={{ color: 'rgba(0,200,255,0.6)' }}>Tracked:{storageMetrics.shards_tracked}</span>
                          <span style={{ color: 'rgba(0,200,255,0.4)' }}>Rebal:{storageMetrics.shards_rebalanced}</span>
                        </div>
                        <div style={{ position: 'relative', height: 6, borderRadius: 3, background: 'rgba(0,200,255,0.1)', overflow: 'hidden' }}>
                          <motion.div
                            animate={{ width: `${storagePercent}%` }}
                            transition={{ duration: 0.5 }}
                            style={{
                              height: '100%', borderRadius: 3,
                              background: storagePercent > 80 ? '#ff4444' : storagePercent > 60 ? '#ffd700' : '#00e599',
                            }}
                          />
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 7, fontFamily: MONO }}>
                          <span style={{ color: 'rgba(0,200,255,0.5)' }}>{fmtBytes(storageMetrics.total_bytes_used)} used</span>
                          <span style={{ color: 'rgba(0,200,255,0.3)' }}>{fmtBytes(storageMetrics.total_bytes_available)} avail</span>
                        </div>
                      </div>
                    )}

                    {sectionHeader('rs', 'RS CONFIG', '#00ccff')}
                    {!storageCollapsed['rs'] && (
                      <div style={{ display: 'flex', gap: 6, fontSize: 8, fontFamily: MONO }}>
                        <span style={{ color: '#00ccff' }}>k={storageMetrics.rs_data_shards}</span>
                        <span style={{ color: 'rgba(0,200,255,0.6)' }}>m={storageMetrics.rs_parity_shards}</span>
                        <span style={{ color: 'rgba(0,200,255,0.4)' }}>
                          Tol: {storageMetrics.rs_parity_shards}/{storageMetrics.rs_data_shards + storageMetrics.rs_parity_shards}
                        </span>
                        <span style={{ color: '#00e599' }}>Rep x{storageMetrics.target_replication}</span>
                      </div>
                    )}
                  </div>
                )}

                {/* Energy pipeline */}
                <div style={{ display: 'flex', gap: 4, fontSize: 7, fontFamily: MONO }}>
                  {[
                    { l: 'Sym', c: '0.1mWh', clr: '#ffd700' }, { l: 'TVC', c: '1mWh', clr: '#00ccff' },
                    { l: 'LLM', c: '50mWh', clr: '#ff8800' }, { l: 'Cloud', c: '100mWh', clr: '#aa66ff' },
                  ].map(p => <span key={p.l} style={{ color: p.clr }}>{p.l}:{p.c}</span>)}
                </div>

                {/* Corpus live log */}
                <div style={{ maxHeight: 60, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 1 }}>
                  <div style={{ color: 'rgba(255,255,255,0.12)', fontSize: 7, fontFamily: MONO, letterSpacing: 1, position: 'sticky', top: 0, background: 'rgba(0,0,0,0.4)', padding: '1px 0' }}>CORPUS LOG</div>
                  {mirrorLogs.filter(l => l.learned || l.src === 'TVCCorpus').length === 0 ? (
                    <div style={{ color: 'rgba(0,200,255,0.15)', fontSize: 8, fontFamily: MONO, padding: 4, textAlign: 'center' }}>Waiting for corpus writes...</div>
                  ) : mirrorLogs.filter(l => l.learned || l.src === 'TVCCorpus').slice(-6).map((l, i) => (
                    <div key={`m-${l.ts}-${i}`} style={{ fontSize: 8, fontFamily: MONO, color: l.learned ? '#00ff88' : '#00ccff', lineHeight: 1.3, padding: '1px 3px' }}>
                      <span style={{ color: 'rgba(255,255,255,0.2)' }}>{fmtTs(l.ts)}</span> {l.learned ? '💾' : '💎'} {l.q.slice(0, 18)}{l.q.length > 18 ? '..' : ''} {l.learned ? 'saved' : `${(l.conf * 100).toFixed(0)}%`}
                    </div>
                  ))}
                </div>
              </motion.div>

              {/* ═══ DUKH (Spirit) — Tools + Vision + Voice + Logs (v2.6) ═══ */}
              <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.15 }}
                style={{ ...glassStyle('rgba(170,100,255,0.08)'), padding: 12, display: 'flex', flexDirection: 'column', gap: 5, borderTop: '2px solid rgba(170,100,255,0.4)', overflow: 'hidden' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ color: '#aa66ff', fontSize: 12, fontFamily: FONT, fontWeight: 700, letterSpacing: 1 }}>ДУХ</div>
                  <span style={{ color: 'rgba(170,100,255,0.3)', fontSize: 8, fontFamily: MONO }}>Tools + Vision + Voice + e</span>
                </div>

                {/* Tool buttons row */}
                <div style={{ display: 'flex', gap: 3 }}>
                  {[
                    { label: 'Build', cmd: 'zig build', clr: '#00ff88' },
                    { label: 'Test', cmd: 'zig test', clr: '#00ccff' },
                    { label: 'Health', cmd: 'health check', clr: '#ffd700' },
                  ].map(t => (
                    <button key={t.label} onClick={() => handleMirrorTool(t.cmd)}
                      style={{ flex: 1, padding: '4px 0', borderRadius: 6, background: `${t.clr}10`, border: `1px solid ${t.clr}30`, color: t.clr, cursor: 'pointer', fontSize: 9, fontFamily: MONO, fontWeight: 600 }}>
                      {t.label}
                    </button>
                  ))}
                </div>

                {/* Vision drop zone + Voice record (v2.6) */}
                <div style={{ display: 'flex', gap: 4 }}>
                  <div
                    onDragOver={e => { e.preventDefault(); setMVisionDrop(true); }}
                    onDragLeave={() => setMVisionDrop(false)}
                    onDrop={handleMirrorVisionDrop}
                    style={{ flex: 1, padding: '6px 4px', borderRadius: 6, border: `1px dashed ${mVisionDrop ? '#ff66aa' : 'rgba(170,100,255,0.2)'}`, background: mVisionDrop ? 'rgba(255,100,170,0.08)' : 'rgba(170,100,255,0.03)', textAlign: 'center', cursor: 'default', transition: 'all 0.2s' }}>
                    <div style={{ fontSize: 8, fontFamily: MONO, color: mVisionDrop ? '#ff66aa' : 'rgba(170,100,255,0.4)' }}>
                      {mVisionDrop ? 'Drop image here' : '📷 Drop image'}
                    </div>
                  </div>
                  <button onClick={toggleMirrorVoice}
                    style={{ padding: '4px 10px', borderRadius: 6, background: mVoiceActive ? 'rgba(255,136,0,0.2)' : 'rgba(170,100,255,0.08)', border: `1px solid ${mVoiceActive ? 'rgba(255,136,0,0.4)' : 'rgba(170,100,255,0.2)'}`, color: mVoiceActive ? '#ff8800' : 'rgba(170,100,255,0.6)', cursor: 'pointer', fontSize: 9, fontFamily: MONO }}>
                    {mVoiceActive ? '🔴 Stop' : '🎤 Voice'}
                  </button>
                </div>

                {/* Vision/Voice output (v2.6) */}
                {(mVisionResult || mVoiceText) && (
                  <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
                    style={{ padding: '3px 6px', borderRadius: 6, background: 'rgba(170,100,255,0.04)', fontSize: 8, fontFamily: MONO, lineHeight: 1.3 }}>
                    {mVisionResult && <div style={{ color: '#ff66aa' }}>📷 {mVisionResult.slice(0, 100)}{mVisionResult.length > 100 ? '...' : ''}</div>}
                    {mVoiceText && <div style={{ color: '#ff8800' }}>🎤 {mVoiceText}</div>}
                  </motion.div>
                )}

                {/* Tool output */}
                {mToolOutput && (
                  <motion.div initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }}
                    style={{ ...glassStyle('rgba(170,100,255,0.06)'), padding: '6px 8px', borderRadius: 8, maxHeight: 60, overflowY: 'auto', fontSize: 8, fontFamily: MONO, color: '#aa66ff', whiteSpace: 'pre-wrap', lineHeight: 1.4 }}>
                    {mToolOutput.slice(0, 250)}{mToolOutput.length > 250 ? '...' : ''}
                  </motion.div>
                )}

                {/* Provider health */}
                {mirrorStatus?.dukh && (
                  <div style={{ display: 'flex', gap: 4 }}>
                    {[
                      { name: 'Groq', rate: mirrorStatus.dukh.groq_success_rate, calls: mirrorStatus.dukh.groq_calls },
                      { name: 'Claude', rate: mirrorStatus.dukh.claude_success_rate, calls: mirrorStatus.dukh.claude_calls },
                    ].map(p => (
                      <div key={p.name} style={{ flex: 1, textAlign: 'center', ...glassStyle('rgba(170,100,255,0.04)'), padding: '3px', borderRadius: 6 }}>
                        <div style={{ color: p.rate > 0.8 ? '#00e599' : p.rate > 0.5 ? '#ffd700' : '#ff4444', fontSize: 11, fontFamily: MONO, fontWeight: 700 }}>
                          {(p.rate * 100).toFixed(0)}%
                        </div>
                        <div style={{ color: 'rgba(255,255,255,0.2)', fontSize: 7, fontFamily: MONO }}>{p.name} ({p.calls})</div>
                      </div>
                    ))}
                  </div>
                )}

                {/* ── Storage Network: Recovery + Transfer + PoS (v2.7) ── */}
                {storageMetrics && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 3, padding: '4px 0', borderTop: '1px solid rgba(170,100,255,0.1)' }}>
                    {sectionHeader('recovery', 'RECOVERY', '#aa66ff')}
                    {!storageCollapsed['recovery'] && (
                      <div style={{ display: 'flex', gap: 6, fontSize: 8, fontFamily: MONO }}>
                        <span style={{ color: storageMetrics.scrub_corruptions > 0 ? '#ff4444' : '#00e599' }}>
                          Scrubs:{storageMetrics.scrub_total}
                        </span>
                        <span style={{ color: storageMetrics.scrub_corruptions > 0 ? '#ff4444' : 'rgba(170,100,255,0.4)' }}>
                          Corrupt:{storageMetrics.scrub_corruptions}
                        </span>
                        <span style={{ color: '#00e599' }}>
                          Rec:{storageMetrics.recoveries_successful} ({fmtBytes(storageMetrics.bytes_recovered)})
                        </span>
                      </div>
                    )}

                    {sectionHeader('bandwidth', 'NETWORK TRANSFER', '#aa66ff')}
                    {!storageCollapsed['bandwidth'] && (
                      <div style={{ display: 'flex', gap: 4 }}>
                        {[
                          { label: 'UP', value: storageMetrics.total_upload, color: '#00ff88' },
                          { label: 'DOWN', value: storageMetrics.total_download, color: '#00ccff' },
                        ].map(t => (
                          <div key={t.label} style={{ flex: 1, textAlign: 'center', background: 'rgba(170,100,255,0.04)', backdropFilter: 'blur(8px)', padding: '3px', borderRadius: 6, border: '1px solid rgba(170,100,255,0.08)' }}>
                            <div style={{ color: t.color, fontSize: 11, fontFamily: MONO, fontWeight: 700 }}>
                              {fmtBytes(t.value)}
                            </div>
                            <div style={{ color: 'rgba(255,255,255,0.2)', fontSize: 7, fontFamily: MONO }}>{t.label}</div>
                          </div>
                        ))}
                      </div>
                    )}

                    {sectionHeader('pos', 'PoS PROOF RATE', '#aa66ff')}
                    {!storageCollapsed['pos'] && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                        <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
                          <div style={{ position: 'relative', flex: 1, height: 6, borderRadius: 3, background: 'rgba(170,100,255,0.1)', overflow: 'hidden' }}>
                            <motion.div
                              animate={{ width: `${posPassRate}%` }}
                              transition={{ duration: 0.5 }}
                              style={{
                                height: '100%', borderRadius: 3,
                                background: posPassRate > 95 ? '#00e599' : posPassRate > 80 ? '#ffd700' : '#ff4444',
                              }}
                            />
                          </div>
                          <span style={{
                            color: posPassRate > 95 ? '#00e599' : posPassRate > 80 ? '#ffd700' : '#ff4444',
                            fontSize: 9, fontFamily: MONO, fontWeight: 700,
                          }}>
                            {posPassRate.toFixed(1)}%
                          </span>
                        </div>
                        <div style={{ display: 'flex', gap: 6, fontSize: 7, fontFamily: MONO }}>
                          <span style={{ color: 'rgba(170,100,255,0.5)' }}>Issued:{storageMetrics.pos_challenges_issued}</span>
                          <span style={{ color: '#00e599' }}>Pass:{storageMetrics.pos_challenges_passed}</span>
                          <span style={{ color: storageMetrics.pos_challenges_failed > 0 ? '#ff4444' : 'rgba(170,100,255,0.3)' }}>
                            Fail:{storageMetrics.pos_challenges_failed}
                          </span>
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {/* Metrics row */}
                {mirrorStatus?.dukh && (
                  <div style={{ display: 'flex', gap: 5, fontSize: 8, fontFamily: MONO, flexWrap: 'wrap' }}>
                    <span style={{ color: mirrorStatus.dukh.total_queries > 0 ? '#aa66ff' : 'rgba(170,100,255,0.3)' }}>Q:{mirrorStatus.dukh.total_queries}</span>
                    <span style={{ color: mirrorStatus.dukh.energy_saved_wh > 0 ? '#00e599' : 'rgba(170,100,255,0.3)' }}>{mirrorStatus.dukh.energy_saved_wh.toFixed(3)}Wh</span>
                    <span style={{ color: mirrorStatus.dukh.tool_hits > 0 ? '#00ff88' : 'rgba(170,100,255,0.3)' }}>Tools:{mirrorStatus.dukh.tool_hits}</span>
                    <span style={{ color: mirrorStatus.dukh.context_enabled ? '#aa66ff' : 'rgba(170,100,255,0.3)' }}>Ctx:{mirrorStatus.dukh.context_messages || 0}</span>
                  </div>
                )}

                {/* All-events live log */}
                <div ref={mirrorLogRef} style={{ flex: 1, minHeight: 30, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 1 }}>
                  <div style={{ color: 'rgba(255,255,255,0.12)', fontSize: 7, fontFamily: MONO, letterSpacing: 1, position: 'sticky', top: 0, background: 'rgba(0,0,0,0.4)', padding: '1px 0' }}>ALL EVENTS</div>
                  {mirrorLogs.length === 0 ? (
                    <div style={{ color: 'rgba(170,100,255,0.15)', fontSize: 8, fontFamily: MONO, padding: 4, textAlign: 'center' }}>Use Chat, Tools, Vision, or Voice</div>
                  ) : mirrorLogs.slice(-10).map((l, i) => (
                    <div key={`d-${l.ts}-${i}`} style={{ fontSize: 8, fontFamily: MONO, color: srcColor(l.src), lineHeight: 1.3, padding: '1px 3px' }}>
                      <span style={{ color: 'rgba(255,255,255,0.2)' }}>{fmtTs(l.ts)}</span> {srcIcon(l.src)} {l.src} "{l.q.slice(0, 14)}{l.q.length > 14 ? '..' : ''}" {(l.conf * 100).toFixed(0)}% {fmtLat(l.lat)}{l.learned ? ' 💾' : ''}
                    </div>
                  ))}
                </div>
              </motion.div>
            </div>

            {/* Footer */}
            <div style={{ textAlign: 'center', color: 'rgba(255,255,255,0.08)', fontSize: 8, fontFamily: MONO, flexShrink: 0 }}>
              φ² + 1/φ² = {(PHI * PHI + 1 / (PHI * PHI)).toFixed(10)} = 3 = TRINITY | live: 2s
            </div>
          </div>
        </div>
        );
      })()}

      {/* ═══ SETTINGS ═══ */}
      {layer === 'settings' && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 50, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 36 }}>
          <div style={{ width: '92%', maxWidth: 500, display: 'flex', flexDirection: 'column', gap: 12, padding: '16px 0' }}>
            <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, letterSpacing: 2, fontFamily: FONT, textAlign: 'center' }}>WAVE SETTINGS</div>
            {[
              { label: 'Версия', value: 'Trinity Canvas v2.6', color: '#ffd700' },
              { label: 'Интерфейс', value: 'Emergent Wave (no panels)', color: '#00ff88' },
              { label: 'Слои', value: '9 layers + 27 sacred worlds (3×9 = РАЗУМ·МАТЕРИЯ·ДУХ)', color: '#00ff88' },
              { label: 'Command Bar', value: 'Cmd+K / / (universal search)', color: '#ffd700' },
              { label: 'Навигация', value: 'Wave dots (auto-hide)', color: '#00ccff' },
              { label: 'Частицы', value: particles.toString(), color: '#ffd700' },
              { label: 'Backend', value: connected ? 'CONNECTED (localhost:8080)' : 'OFFLINE', color: connected ? '#00e599' : '#ff4444' },
              { label: 'Chat API', value: 'IglaHybridChat v2.6 (5-level + reflection)', color: '#00ccff' },
              { label: 'Vision', value: 'Drag-drop + Paste + URL', color: '#ff66aa' },
              { label: 'Voice', value: 'Web Audio API + Speech-to-Text', color: '#ff8800' },
              { label: 'Editor', value: 'Real VIBEE compile + Zig AI analysis', color: '#00ff88' },
              { label: 'Файлов', value: `${activeFileIndex.length} indexed${backendFiles ? ' (live)' : ''}`, color: '#aa66ff' },
              { label: 'Шрифт', value: 'Outfit + JetBrains Mono', color: '#00ff88' },
              { label: 'φ²+1/φ²', value: (PHI * PHI + 1 / (PHI * PHI)).toFixed(10), color: '#ffd700' },
            ].map((item, i) => (
              <motion.div key={item.label} initial={{ opacity: 0, scale: 0.95, y: 12 }} animate={{ opacity: 1, scale: 1, y: 0 }}
                transition={{ delay: i * 0.04, type: 'spring', damping: 20 }}
                style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', ...glassStyle(), padding: '11px 16px' }}>
                <span style={{ color: 'rgba(255,255,255,0.35)', fontSize: 12, fontFamily: FONT }}>{item.label}</span>
                <span style={{ color: item.color, fontSize: 12, fontFamily: MONO }}>{item.value}</span>
              </motion.div>
            ))}
          </div>
        </div>
      )}

      {/* ═══ VIZ ═══ */}
      {layer === 'viz' && (
        <motion.div key={vizMode} initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}
          style={{ position: 'absolute', bottom: 28, left: '50%', transform: 'translateX(-50%)', zIndex: 100, textAlign: 'center', ...glassStyle(), padding: '10px 22px' }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: '#fff', fontFamily: FONT }}>{vizMode.replace(/-/g, ' ').toUpperCase()}</div>
          <div style={{ color: 'rgba(255,255,255,0.25)', fontSize: 10, marginTop: 3, fontFamily: FONT }}>
            Курсор для взаимодействия &middot; <span style={{ color: '#ffd700' }}>φ² + 1/φ² = 3</span>
          </div>
        </motion.div>
      )}

        </motion.div>
      </AnimatePresence>

      {/* ═══ Footer — hidden on petals ═══ */}
      {layer !== 'petals' && (
      <div style={{ position: 'absolute', bottom: 5, right: 10, zIndex: 10, color: 'rgba(255,215,0,0.10)', fontSize: 8, fontFamily: FONT, letterSpacing: 1 }}>
        TRINITY CANVAS v2.6 &middot; φ² + 1/φ² = 3 &middot; KOSCHEI IS IMMORTAL
      </div>
      )}
    </div>
  );
}
