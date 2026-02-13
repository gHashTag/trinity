/**
 * TrinityCanvas v1.9 — The Canvas IS the Interface
 *
 * All interaction (chat, editor, finder, settings) happens INSIDE the canvas
 * as emergent wave patterns. No side panels, no separate windows.
 *
 * Layers (switch via 1-6 or Shift+1-6):
 *   1 — Petals (27-petal main menu)
 *   2 — Chat (conversation inside wave field)
 *   3 — Editor (code hot-reload inside canvas)
 *   4 — Finder (file search as particle convergence)
 *   5 — Settings (config as wave interference)
 *   6 — Viz (pure visualization mode)
 *
 * φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
 */

import { useState, useRef, useEffect, useCallback } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import QuantumCanvas from '../components/QuantumCanvas';
import type { VizMode } from '../components/QuantumCanvas';
import ChatMessage from '../components/chat/ChatMessage';
import { sendMessage, clearContext, type ChatResponse } from '../services/chatApi';

// ─── Types ───────────────────────────────────────────────────────────────────

type CanvasLayer = 'petals' | 'chat' | 'editor' | 'finder' | 'settings' | 'viz';

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
}

declare global {
  interface Window {
    __trinityWaveRings?: Array<{ x: number; y: number; time: number; hue: number }>;
  }
}

// ─── Constants ───────────────────────────────────────────────────────────────

const PHI = 1.618033988749895;

const LAYER_INFO: Record<CanvasLayer, { label: string; hint: string; hue: number; vizMode: VizMode }> = {
  petals:   { label: 'PETALS',   hint: '27 лепестков',      hue: 45,  vizMode: 'trinity-computer' },
  chat:     { label: 'CHAT',     hint: 'Разговор в волнах',  hue: 45,  vizMode: 'chat-wave' },
  editor:   { label: 'EDITOR',   hint: 'Код внутри поля',   hue: 160, vizMode: 'neural-network' },
  finder:   { label: 'FINDER',   hint: 'Поиск частиц',      hue: 280, vizMode: 'quantum-field' },
  settings: { label: 'SETTINGS', hint: 'Волновая настройка', hue: 200, vizMode: 'wave-interference' },
  viz:      { label: 'VIZ',      hint: 'Чистый холст',      hue: 160, vizMode: 'trinity-computer' },
};

const LAYER_KEYS: CanvasLayer[] = ['petals', 'chat', 'editor', 'finder', 'settings', 'viz'];

// 27 Petals — the main menu rendered as a flower inside the canvas
const PETALS: PetalItem[] = [
  // Ring 1 — Core (inner 3)
  { id: 'chat',     label: 'Чат',       icon: '💬', layer: 'chat',     color: '#ffd700' },
  { id: 'editor',   label: 'Редактор',  icon: '⚡', layer: 'editor',   color: '#00ff88' },
  { id: 'finder',   label: 'Поиск',     icon: '🔍', layer: 'finder',   color: '#00ccff' },
  // Ring 2 — Modes (middle 9)
  { id: 'settings', label: 'Настройки', icon: '⚙️', layer: 'settings', color: '#a366ff' },
  { id: 'trinity',  label: 'Trinity',   icon: '🔮', vizMode: 'trinity-computer', layer: 'viz', color: '#ffd700' },
  { id: 'quantum',  label: 'Квант',     icon: '⚛️', vizMode: 'quantum-field',    layer: 'viz', color: '#00ff88' },
  { id: 'neural',   label: 'Нейро',     icon: '🧠', vizMode: 'neural-network',   layer: 'viz', color: '#0088ff' },
  { id: 'vortex',   label: 'Вихрь',     icon: '🌀', vizMode: 'vortex',           layer: 'viz', color: '#ff8800' },
  { id: 'cosmic',   label: 'Космос',    icon: '🌌', vizMode: 'multiverse',       layer: 'viz', color: '#4488ff' },
  { id: 'encrypt',  label: 'Шифр',      icon: '🔐', vizMode: 'encryption',       layer: 'viz', color: '#00ccff' },
  { id: 'life',     label: 'Жизнь',     icon: '🌱', vizMode: 'living',           layer: 'viz', color: '#44ff44' },
  { id: 'mind',     label: 'Сознание',  icon: '👁️', vizMode: 'consciousness',    layer: 'viz', color: '#aa66ff' },
  // Ring 3 — Extended (outer 15)
  { id: 'photon',   label: 'Фотон',     icon: '💫', vizMode: 'photon-beam',      layer: 'viz', color: '#ffff00' },
  { id: 'entangle', label: 'Запутан',   icon: '🔗', vizMode: 'entanglement',     layer: 'viz', color: '#ff66ff' },
  { id: 'supreme',  label: 'Квант+',    icon: '⚡', vizMode: 'supremacy',        layer: 'viz', color: '#ff4444' },
  { id: 'neuro2',   label: 'Нейроморф', icon: '🧬', vizMode: 'neuromorphic',     layer: 'viz', color: '#cc44ff' },
  { id: 'llm',      label: 'LLM',       icon: '🏗️', vizMode: 'llm-architecture', layer: 'viz', color: '#4488ff' },
  { id: 'trans',    label: 'Трансцен',  icon: '✨', vizMode: 'transcendence',    layer: 'viz', color: '#ffff00' },
  { id: 'beings',   label: 'Существа',  icon: '👾', vizMode: 'beings',           layer: 'viz', color: '#ff44aa' },
  { id: 'qlife',    label: 'КвЖизнь',   icon: '🦠', vizMode: 'quantum-life',     layer: 'viz', color: '#00ffaa' },
  { id: 'qbio',     label: 'КвБио',     icon: '🧬', vizMode: 'quantum-biology',  layer: 'viz', color: '#00ffaa' },
  { id: 'matr',     label: 'Матрёшка',  icon: '🪆', vizMode: 'matryoshka',       layer: 'viz', color: '#ee44aa' },
  { id: 'zhar',     label: 'Жар-Птица', icon: '🔥', vizMode: 'zhar-ptitsa',      layer: 'viz', color: '#ff8800' },
  { id: 'bogat',    label: 'Богатыри',  icon: '⚔️', vizMode: 'bogatyri',         layer: 'viz', color: '#4488ff' },
  { id: 'agents',   label: 'Агенты',    icon: '🤖', vizMode: 'quantum-agents',   layer: 'viz', color: '#44aaff' },
  { id: 'spin',     label: 'Спинтрон',  icon: '🔄', vizMode: 'spintronic',       layer: 'viz', color: '#ff44aa' },
  { id: 'cinema',   label: 'Cinema4D',  icon: '🎬', vizMode: 'cinema4d',         layer: 'viz', color: '#ff44aa' },
];

// ─── Helper ──────────────────────────────────────────────────────────────────

function triggerWave(role: 'user' | 'assistant') {
  if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
  const x = role === 'user' ? window.innerWidth * 0.7 : window.innerWidth * 0.3;
  const y = window.innerHeight * 0.5;
  const hue = role === 'user' ? 45 : 150;
  window.__trinityWaveRings.push({ x, y, time: Date.now(), hue });
}

// ─── Component ───────────────────────────────────────────────────────────────

export default function TrinityCanvas() {
  const [layer, setLayer] = useState<CanvasLayer>('petals');
  const [vizMode, setVizMode] = useState<VizMode>('trinity-computer');
  const [messages, setMessages] = useState<Message[]>([]);
  const [chatLoading, setChatLoading] = useState(false);
  const [chatText, setChatText] = useState('');
  const [nextId, setNextId] = useState(1);
  const [editorCode, setEditorCode] = useState(`// Trinity Editor v1.9\n// Hot-reload inside the wave field\n\nconst PHI = 1.618033988749895;\nconst TRINITY = PHI * PHI + 1 / (PHI * PHI);\n\nconsole.log("φ² + 1/φ² =", TRINITY); // 3\n`);
  const [finderQuery, setFinderQuery] = useState('');
  const [finderResults, setFinderResults] = useState<string[]>([]);
  const [showLayerHint, setShowLayerHint] = useState(true);
  const scrollRef = useRef<HTMLDivElement>(null);

  // ─── Layer switching ─────────────────────────────────────────────────────

  const switchLayer = useCallback((newLayer: CanvasLayer, newVizMode?: VizMode) => {
    setLayer(newLayer);
    const mode = newVizMode || LAYER_INFO[newLayer].vizMode;
    setVizMode(mode);
    setShowLayerHint(true);
    setTimeout(() => setShowLayerHint(false), 2000);
    // Trigger wave on layer switch
    if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
    window.__trinityWaveRings.push({
      x: window.innerWidth / 2,
      y: window.innerHeight / 2,
      time: Date.now(),
      hue: LAYER_INFO[newLayer].hue,
    });
  }, []);

  // ─── Keyboard shortcuts (1-6 or Shift+1-6) ──────────────────────────────

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Don't capture when typing in inputs
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      const num = parseInt(e.key);
      if (num >= 1 && num <= 6) {
        e.preventDefault();
        switchLayer(LAYER_KEYS[num - 1]);
      }
      // Escape → back to petals
      if (e.key === 'Escape') {
        e.preventDefault();
        switchLayer('petals');
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [switchLayer]);

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

    const userMsg: Message = { id: userId, role: 'user', content: trimmed };
    setMessages(prev => [...prev, userMsg]);
    triggerWave('user');
    setChatLoading(true);

    try {
      const res: ChatResponse = await sendMessage({ message: trimmed });
      const assistantMsg: Message = {
        id: userId + 1, role: 'assistant', content: res.response,
        source: res.source, confidence: res.confidence, latency_us: res.latency_us,
        tool_name: res.tool_name, reflection: res.reflection, learned: res.learned,
      };
      setMessages(prev => [...prev, assistantMsg]);
      triggerWave('assistant');
      if (res.learned) {
        setTimeout(() => {
          if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
          window.__trinityWaveRings.push({ x: window.innerWidth * 0.5, y: window.innerHeight * 0.5, time: Date.now(), hue: 120 });
        }, 300);
      }
    } catch {
      setMessages(prev => [...prev, {
        id: userId + 1, role: 'assistant',
        content: 'Connection error. Run: tri serve --chat', source: 'Error', confidence: 0,
      }]);
    } finally {
      setChatLoading(false);
    }
  }, [chatText, chatLoading, nextId]);

  const handleChatClear = useCallback(async () => {
    await clearContext();
    setMessages([]);
  }, []);

  // ─── Finder ──────────────────────────────────────────────────────────────

  const handleFinderSearch = useCallback(() => {
    const q = finderQuery.toLowerCase();
    if (!q) { setFinderResults([]); return; }
    // Simulated file search — in production, this would call the backend
    const files = [
      'src/vsa.zig', 'src/vm.zig', 'src/hybrid.zig', 'src/trinity.zig', 'src/sdk.zig',
      'src/packed_trit.zig', 'src/firebird/cli.zig', 'src/vibeec/vibee_parser.zig',
      'src/vibeec/zig_codegen.zig', 'src/trinity_node/network.zig', 'src/trinity_node/storage.zig',
      'src/trinity_node/protocol.zig', 'src/trinity_node/main.zig', 'src/trinity_node/discovery.zig',
      'src/trinity_node/config.zig', 'src/trinity_node/vsa_shard_encoder.zig',
      'src/trinity_node/semantic_index.zig', 'src/trinity_node/region_topology.zig',
      'src/trinity_node/slashing_escrow.zig', 'src/trinity_node/prometheus_http.zig',
      'specs/tri/storage_network_v2_0.vibee', 'specs/tri/trinity_chat_v2_4.vibee',
    ];
    setFinderResults(files.filter(f => f.toLowerCase().includes(q)));
  }, [finderQuery]);

  // ─── Editor eval ─────────────────────────────────────────────────────────

  const [editorOutput, setEditorOutput] = useState('');
  const handleEditorRun = useCallback(() => {
    try {
      const logs: string[] = [];
      const fakeConsole = { log: (...args: unknown[]) => logs.push(args.map(String).join(' ')) };
      const fn = new Function('console', editorCode);
      fn(fakeConsole);
      setEditorOutput(logs.join('\n') || '(no output)');
    } catch (err) {
      setEditorOutput(`Error: ${err}`);
    }
    // Trigger wave on code run
    if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
    window.__trinityWaveRings.push({ x: window.innerWidth / 2, y: window.innerHeight * 0.3, time: Date.now(), hue: 120 });
  }, [editorCode]);

  // ─── Petal click handler ─────────────────────────────────────────────────

  const handlePetalClick = useCallback((petal: PetalItem) => {
    if (petal.layer) {
      switchLayer(petal.layer, petal.vizMode);
    }
  }, [switchLayer]);

  // ─── Render ──────────────────────────────────────────────────────────────

  const info = LAYER_INFO[layer];
  const particleCount = layer === 'chat' ? 800 : layer === 'petals' ? 1200 : 1500;

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', overflow: 'hidden', fontFamily: "'Outfit', system-ui, sans-serif" }}>
      {/* ═══ Background Canvas — ALWAYS fullscreen ═══ */}
      <QuantumCanvas mode={vizMode} particleCount={particleCount} interactive={true} />

      {/* ═══ Layer Indicator (top center) ═══ */}
      <div style={{
        position: 'absolute', top: 12, left: '50%', transform: 'translateX(-50%)',
        zIndex: 100, display: 'flex', gap: 4,
      }}>
        {LAYER_KEYS.map((l, i) => (
          <button
            key={l}
            onClick={() => switchLayer(l)}
            style={{
              padding: '6px 14px', borderRadius: 20,
              background: layer === l ? `hsla(${LAYER_INFO[l].hue}, 80%, 50%, 0.25)` : 'rgba(255,255,255,0.04)',
              border: `1px solid ${layer === l ? `hsla(${LAYER_INFO[l].hue}, 80%, 60%, 0.5)` : 'rgba(255,255,255,0.08)'}`,
              color: layer === l ? '#fff' : 'rgba(255,255,255,0.35)',
              cursor: 'pointer', fontSize: 11, letterSpacing: 1,
              fontFamily: "'Outfit', sans-serif", fontWeight: layer === l ? 600 : 400,
              transition: 'all 0.3s',
            }}
          >
            <span style={{ opacity: 0.5, marginRight: 4, fontSize: 9 }}>{i + 1}</span>
            {LAYER_INFO[l].label}
          </button>
        ))}
      </div>

      {/* ═══ Layer hint (center, fades out) ═══ */}
      <AnimatePresence>
        {showLayerHint && (
          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.9 }}
            transition={{ duration: 0.4 }}
            style={{
              position: 'absolute', top: '50%', left: '50%',
              transform: 'translate(-50%, -50%)', zIndex: 200,
              textAlign: 'center', pointerEvents: 'none',
            }}
          >
            <div style={{ fontSize: 48, color: `hsl(${info.hue}, 80%, 60%)`, fontWeight: 700, fontFamily: "'Outfit', sans-serif" }}>
              {info.label}
            </div>
            <div style={{ fontSize: 14, color: 'rgba(255,255,255,0.4)', marginTop: 8, fontFamily: "'Outfit', sans-serif" }}>
              {info.hint}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ═══ LAYER: PETALS (27-petal flower menu) ═══ */}
      {layer === 'petals' && (
        <div style={{
          position: 'absolute', inset: 0, display: 'flex',
          alignItems: 'center', justifyContent: 'center', zIndex: 50,
        }}>
          <div style={{ position: 'relative', width: 600, height: 600 }}>
            {/* Center phi symbol */}
            <div style={{
              position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
              fontSize: 32, color: '#ffd700', fontFamily: 'serif',
              textShadow: '0 0 20px rgba(255,215,0,0.5)',
            }}>
              &phi;
            </div>
            {/* 27 petals in 3 rings */}
            {PETALS.map((petal, i) => {
              let ring: number, indexInRing: number, ringSize: number;
              if (i < 3) { ring = 0; indexInRing = i; ringSize = 3; }
              else if (i < 12) { ring = 1; indexInRing = i - 3; ringSize = 9; }
              else { ring = 2; indexInRing = i - 12; ringSize = 15; }

              const radius = 80 + ring * 90;
              const angle = (indexInRing / ringSize) * Math.PI * 2 - Math.PI / 2;
              const x = 300 + radius * Math.cos(angle);
              const y = 300 + radius * Math.sin(angle);

              return (
                <motion.button
                  key={petal.id}
                  onClick={() => handlePetalClick(petal)}
                  initial={{ opacity: 0, scale: 0 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: i * 0.03, type: 'spring', damping: 15 }}
                  whileHover={{ scale: 1.2, zIndex: 10 }}
                  whileTap={{ scale: 0.9 }}
                  style={{
                    position: 'absolute',
                    left: x - (ring === 0 ? 32 : ring === 1 ? 28 : 24),
                    top: y - (ring === 0 ? 32 : ring === 1 ? 28 : 24),
                    width: ring === 0 ? 64 : ring === 1 ? 56 : 48,
                    height: ring === 0 ? 64 : ring === 1 ? 56 : 48,
                    borderRadius: '50%',
                    background: `${petal.color}18`,
                    border: `1px solid ${petal.color}40`,
                    display: 'flex', flexDirection: 'column',
                    alignItems: 'center', justifyContent: 'center',
                    cursor: 'pointer',
                    backdropFilter: 'blur(8px)',
                    transition: 'box-shadow 0.3s',
                  }}
                  title={petal.label}
                >
                  <span style={{ fontSize: ring === 0 ? 20 : ring === 1 ? 16 : 14 }}>
                    {petal.icon}
                  </span>
                  {ring < 2 && (
                    <span style={{
                      fontSize: ring === 0 ? 8 : 7, color: petal.color,
                      marginTop: 2, fontFamily: "'Outfit', sans-serif", fontWeight: 500,
                    }}>
                      {petal.label}
                    </span>
                  )}
                </motion.button>
              );
            })}
          </div>
        </div>
      )}

      {/* ═══ LAYER: CHAT (inside the wave field) ═══ */}
      {layer === 'chat' && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 50,
          display: 'flex', flexDirection: 'column',
        }}>
          {/* Chat header — minimal, inside canvas */}
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '48px 24px 8px', maxWidth: 720, width: '100%', margin: '0 auto',
          }}>
            <div style={{ color: '#ffd700', fontSize: 11, fontFamily: "'Outfit', monospace", letterSpacing: 2, opacity: 0.6 }}>
              TRINITY CHAT v2.4
            </div>
            <button
              onClick={handleChatClear}
              style={{
                background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)',
                borderRadius: 6, padding: '3px 10px', color: 'rgba(255,255,255,0.3)', cursor: 'pointer',
                fontSize: 10, fontFamily: "'Outfit', monospace", letterSpacing: 1,
              }}
            >
              CLEAR
            </button>
          </div>

          {/* Messages — scrollable, centered */}
          <div ref={scrollRef} style={{
            flex: 1, overflowY: 'auto', padding: '12px 24px',
            maxWidth: 720, width: '100%', margin: '0 auto',
          }}>
            {messages.length === 0 && (
              <div style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center',
                justifyContent: 'center', height: '60vh', opacity: 0.2,
              }}>
                <div style={{ fontSize: 72, color: '#ffd700', fontFamily: 'serif' }}>&phi;</div>
                <div style={{ color: '#888', fontFamily: "'Outfit', sans-serif", fontSize: 13, marginTop: 12 }}>
                  Введите сообщение в волновое поле
                </div>
              </div>
            )}
            <AnimatePresence>
              {messages.map(msg => (
                <ChatMessage
                  key={msg.id} role={msg.role} content={msg.content}
                  source={msg.source} confidence={msg.confidence} latency_us={msg.latency_us}
                  tool_name={msg.tool_name} reflection={msg.reflection} learned={msg.learned}
                />
              ))}
            </AnimatePresence>
            {chatLoading && (
              <div style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: 12 }}>
                <div style={{
                  padding: '10px 14px', borderRadius: '14px 14px 14px 4px',
                  background: 'rgba(0,229,153,0.08)', border: '1px solid rgba(0,229,153,0.15)',
                }}>
                  <span style={{ color: '#00e599', fontFamily: 'monospace', fontSize: 14 }}>...</span>
                </div>
              </div>
            )}
          </div>

          {/* Input — bottom, inside canvas, no separate panel */}
          <div style={{
            padding: '12px 24px 24px', maxWidth: 720, width: '100%', margin: '0 auto',
          }}>
            <div style={{
              display: 'flex', gap: 8,
              background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(12px)',
              borderRadius: 14, border: '1px solid rgba(255,215,0,0.15)',
              padding: '12px 16px',
            }}>
              <input
                type="text"
                value={chatText}
                onChange={e => setChatText(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleChatSend()}
                disabled={chatLoading}
                placeholder="Сообщение в волновое поле..."
                autoFocus
                style={{
                  flex: 1, background: 'transparent', border: 'none', outline: 'none',
                  color: '#fff', fontSize: 14, fontFamily: "'Outfit', sans-serif",
                }}
              />
              <span style={{ color: 'rgba(255,255,255,0.15)', fontSize: 11, alignSelf: 'center', fontFamily: "'Outfit', sans-serif" }}>
                enter to send
              </span>
            </div>
          </div>
        </div>
      )}

      {/* ═══ LAYER: EDITOR (code inside the wave field) ═══ */}
      {layer === 'editor' && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 50,
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          paddingTop: 56,
        }}>
          <div style={{
            width: '90%', maxWidth: 800, flex: 1,
            display: 'flex', flexDirection: 'column', gap: 12, padding: '12px 0',
          }}>
            {/* Editor area */}
            <div style={{ flex: 1, position: 'relative' }}>
              <textarea
                value={editorCode}
                onChange={e => setEditorCode(e.target.value)}
                spellCheck={false}
                style={{
                  width: '100%', height: '100%',
                  background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(12px)',
                  border: '1px solid rgba(0,255,136,0.15)', borderRadius: 14,
                  padding: 20, color: '#00ff88', fontSize: 14,
                  fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
                  resize: 'none', outline: 'none', lineHeight: 1.6,
                }}
              />
            </div>
            {/* Controls */}
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <button
                onClick={handleEditorRun}
                style={{
                  padding: '8px 24px', borderRadius: 10,
                  background: 'rgba(0,255,136,0.15)', border: '1px solid rgba(0,255,136,0.3)',
                  color: '#00ff88', cursor: 'pointer', fontSize: 12,
                  fontFamily: "'Outfit', sans-serif", fontWeight: 600, letterSpacing: 1,
                }}
              >
                RUN
              </button>
              <div style={{ flex: 1, color: 'rgba(255,255,255,0.2)', fontSize: 11, fontFamily: "'Outfit', sans-serif" }}>
                Hot-reload внутри волнового поля
              </div>
            </div>
            {/* Output */}
            {editorOutput && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                style={{
                  background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(12px)',
                  border: '1px solid rgba(255,215,0,0.15)', borderRadius: 14,
                  padding: 16, fontFamily: 'monospace', fontSize: 13,
                  color: editorOutput.startsWith('Error') ? '#ff4444' : '#ffd700',
                  whiteSpace: 'pre-wrap', maxHeight: 150, overflowY: 'auto',
                }}
              >
                {editorOutput}
              </motion.div>
            )}
          </div>
        </div>
      )}

      {/* ═══ LAYER: FINDER (search as particle convergence) ═══ */}
      {layer === 'finder' && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 50,
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          paddingTop: 56,
        }}>
          <div style={{
            width: '90%', maxWidth: 600, display: 'flex', flexDirection: 'column', gap: 16,
            padding: '24px 0',
          }}>
            {/* Search input */}
            <div style={{
              display: 'flex', gap: 8,
              background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(12px)',
              borderRadius: 14, border: '1px solid rgba(0,200,255,0.15)',
              padding: '14px 18px',
            }}>
              <span style={{ fontSize: 18, opacity: 0.5 }}>🔍</span>
              <input
                type="text"
                value={finderQuery}
                onChange={e => { setFinderQuery(e.target.value); }}
                onKeyDown={e => e.key === 'Enter' && handleFinderSearch()}
                placeholder="Поиск файлов в проекте..."
                autoFocus
                style={{
                  flex: 1, background: 'transparent', border: 'none', outline: 'none',
                  color: '#fff', fontSize: 15, fontFamily: "'Outfit', sans-serif",
                }}
              />
            </div>

            {/* Results — emerge from the field */}
            <AnimatePresence>
              {finderResults.map((file, i) => (
                <motion.div
                  key={file}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  transition={{ delay: i * 0.05 }}
                  style={{
                    background: 'rgba(0,0,0,0.2)', backdropFilter: 'blur(10px)',
                    border: '1px solid rgba(0,200,255,0.1)', borderRadius: 10,
                    padding: '10px 16px', cursor: 'pointer',
                    color: '#00ccff', fontSize: 13, fontFamily: "'JetBrains Mono', monospace",
                  }}
                >
                  {file}
                </motion.div>
              ))}
            </AnimatePresence>

            {finderResults.length === 0 && finderQuery && (
              <div style={{ textAlign: 'center', color: 'rgba(255,255,255,0.15)', fontSize: 13, marginTop: 40, fontFamily: "'Outfit', sans-serif" }}>
                Нажмите Enter для поиска
              </div>
            )}
          </div>
        </div>
      )}

      {/* ═══ LAYER: SETTINGS (wave interference config) ═══ */}
      {layer === 'settings' && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 50,
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          paddingTop: 56,
        }}>
          <div style={{
            width: '90%', maxWidth: 500, display: 'flex', flexDirection: 'column', gap: 16,
            padding: '24px 0',
          }}>
            <div style={{
              color: 'rgba(255,255,255,0.3)', fontSize: 11, letterSpacing: 2,
              fontFamily: "'Outfit', sans-serif", textAlign: 'center',
            }}>
              WAVE SETTINGS
            </div>

            {[
              { label: 'Частицы', value: particleCount.toString(), color: '#ffd700' },
              { label: 'Шрифт', value: 'Outfit', color: '#00ff88' },
              { label: 'Тема', value: 'Dark Wave', color: '#00ccff' },
              { label: 'Язык', value: 'Русский', color: '#aa66ff' },
              { label: 'Backend', value: 'localhost:8080', color: '#ff8844' },
              { label: 'Версия', value: 'Trinity Canvas v1.9', color: '#ffd700' },
              { label: 'φ²+1/φ²', value: (PHI * PHI + 1 / (PHI * PHI)).toFixed(10), color: '#ffd700' },
            ].map((item, i) => (
              <motion.div
                key={item.label}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.06 }}
                style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  background: 'rgba(0,0,0,0.2)', backdropFilter: 'blur(10px)',
                  border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12,
                  padding: '12px 18px',
                }}
              >
                <span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontFamily: "'Outfit', sans-serif" }}>
                  {item.label}
                </span>
                <span style={{ color: item.color, fontSize: 13, fontFamily: "'JetBrains Mono', monospace" }}>
                  {item.value}
                </span>
              </motion.div>
            ))}
          </div>
        </div>
      )}

      {/* ═══ LAYER: VIZ (pure canvas, no overlays except mode info) ═══ */}
      {layer === 'viz' && (
        <motion.div
          key={vizMode}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          style={{
            position: 'absolute', bottom: 32, left: '50%', transform: 'translateX(-50%)',
            zIndex: 100, textAlign: 'center',
            padding: '12px 24px',
            background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(10px)',
            borderRadius: 14, border: '1px solid rgba(255,255,255,0.08)',
          }}
        >
          <div style={{ fontSize: 14, fontWeight: 600, color: '#fff', fontFamily: "'Outfit', sans-serif" }}>
            {vizMode.replace(/-/g, ' ').toUpperCase()}
          </div>
          <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, marginTop: 4, fontFamily: "'Outfit', sans-serif" }}>
            Курсор для взаимодействия &middot; <span style={{ color: '#ffd700' }}>φ² + 1/φ² = 3</span>
          </div>
        </motion.div>
      )}

      {/* ═══ Bottom formula bar ═══ */}
      <div style={{
        position: 'absolute', bottom: 6, right: 12, zIndex: 10,
        color: 'rgba(255,215,0,0.15)', fontSize: 9, fontFamily: "'Outfit', monospace",
        letterSpacing: 1,
      }}>
        TRINITY CANVAS v1.9 &middot; φ² + 1/φ² = 3 &middot; KOSCHEI IS IMMORTAL
      </div>
    </div>
  );
}
