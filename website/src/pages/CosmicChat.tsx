import { useState, useRef, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { AnimatePresence } from 'framer-motion';
import QuantumCanvas from '../components/QuantumCanvas';
import ChatMessage from '../components/chat/ChatMessage';
import ChatInput from '../components/chat/ChatInput';
import ConnectionStatus from '../components/chat/ConnectionStatus';
import { sendMessage, clearContext, type ChatResponse } from '../services/chatApi';

interface Message {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  source?: string;
  confidence?: number;
  latency_us?: number;
  // v2.4 fields
  tool_name?: string;
  reflection?: string;
  learned?: boolean;
}

declare global {
  interface Window {
    __trinityWaveRings?: Array<{ x: number; y: number; time: number; hue: number }>;
  }
}

function triggerWave(role: 'user' | 'assistant') {
  if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
  const x = role === 'user' ? window.innerWidth * 0.7 : window.innerWidth * 0.3;
  const y = window.innerHeight * 0.5;
  const hue = role === 'user' ? 45 : 150;
  window.__trinityWaveRings.push({ x, y, time: Date.now(), hue });
}

export default function CosmicChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const [nextId, setNextId] = useState(1);
  const scrollRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = useCallback(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  const handleSend = useCallback(async (text: string, imagePath?: string, audioPath?: string) => {
    const userId = nextId;
    setNextId(n => n + 2);

    const userMsg: Message = { id: userId, role: 'user', content: text };
    setMessages(prev => [...prev, userMsg]);
    triggerWave('user');
    setLoading(true);

    try {
      const res: ChatResponse = await sendMessage({
        message: text,
        image_path: imagePath,
        audio_path: audioPath,
      });
      const assistantMsg: Message = {
        id: userId + 1,
        role: 'assistant',
        content: res.response,
        source: res.source,
        confidence: res.confidence,
        latency_us: res.latency_us,
        // v2.4 fields
        tool_name: res.tool_name,
        reflection: res.reflection,
        learned: res.learned,
      };
      setMessages(prev => [...prev, assistantMsg]);
      triggerWave('assistant');

      // v2.4: Extra reflection wave when response was learned
      if (res.learned) {
        setTimeout(() => {
          if (!window.__trinityWaveRings) window.__trinityWaveRings = [];
          window.__trinityWaveRings.push({
            x: window.innerWidth * 0.5,
            y: window.innerHeight * 0.5,
            time: Date.now(),
            hue: 120, // green reflection wave
          });
        }, 300);
      }
    } catch {
      setMessages(prev => [...prev, {
        id: userId + 1,
        role: 'assistant',
        content: 'Connection error. Is the Trinity chat server running? (tri serve --chat)',
        source: 'Error',
        confidence: 0,
      }]);
    } finally {
      setLoading(false);
    }
  }, [nextId]);

  const handleClear = useCallback(async () => {
    await clearContext();
    setMessages([]);
  }, []);

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', overflow: 'hidden' }}>
      {/* Background canvas */}
      <QuantumCanvas mode="chat-wave" particleCount={800} />

      {/* Header */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0,
        padding: '12px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8,
        background: 'linear-gradient(180deg, rgba(0,0,0,0.6) 0%, transparent 100%)',
        zIndex: 10,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <Link to="/" style={{ color: '#666', textDecoration: 'none', fontSize: 12, fontFamily: 'monospace' }}>
            &larr; HOME
          </Link>
          <ConnectionStatus />
        </div>
        <div style={{
          color: '#ffd700', fontSize: 13, fontFamily: 'monospace', letterSpacing: 2,
          textShadow: '0 0 10px rgba(255,215,0,0.3)',
        }}>
          COSMIC CHAT v2.4
        </div>
        <button
          onClick={handleClear}
          style={{
            background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: 6, padding: '4px 10px', color: '#666', cursor: 'pointer',
            fontSize: 10, fontFamily: 'monospace', letterSpacing: 1,
          }}
        >
          CLEAR
        </button>
      </div>

      {/* Messages area */}
      <div
        ref={scrollRef}
        style={{
          position: 'absolute', top: 48, bottom: 72, left: 0, right: 0,
          overflowY: 'auto', padding: '20px',
          display: 'flex', flexDirection: 'column',
        }}
      >
        <div style={{ maxWidth: 800, width: '100%', margin: '0 auto', flex: 1 }}>
          {messages.length === 0 && (
            <div style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center',
              justifyContent: 'center', height: '100%', opacity: 0.3,
            }}>
              <div style={{ fontSize: 'clamp(36px, 15vw, 64px)', color: '#ffd700', fontFamily: 'serif' }}>&phi;</div>
              <div style={{ color: '#666', fontFamily: 'monospace', fontSize: 12, marginTop: 8 }}>
                Trinity Chat v2.4 - Self-Reflection + Multi-Modal + Context
              </div>
            </div>
          )}
          <AnimatePresence>
            {messages.map(msg => (
              <ChatMessage
                key={msg.id}
                role={msg.role}
                content={msg.content}
                source={msg.source}
                confidence={msg.confidence}
                latency_us={msg.latency_us}
                tool_name={msg.tool_name}
                reflection={msg.reflection}
                learned={msg.learned}
              />
            ))}
          </AnimatePresence>
          {loading && (
            <div style={{
              display: 'flex', justifyContent: 'flex-start', marginBottom: 12,
            }}>
              <div style={{
                padding: '10px 14px', borderRadius: '14px 14px 14px 4px',
                background: 'rgba(0,229,153,0.08)',
                border: '1px solid rgba(0,229,153,0.15)',
              }}>
                <span style={{ color: '#00e599', fontFamily: 'monospace', fontSize: 14 }}>
                  {'...'}
                </span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Input area */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, padding: '12px 20px',
        background: 'linear-gradient(0deg, rgba(0,0,0,0.6) 0%, transparent 100%)',
        zIndex: 10,
      }}>
        <div style={{ maxWidth: 800, width: '100%', margin: '0 auto' }}>
          <ChatInput onSend={handleSend} disabled={loading} />
        </div>
      </div>
    </div>
  );
}
