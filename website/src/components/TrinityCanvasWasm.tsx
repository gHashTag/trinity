/**
 * TrinityCanvasWasm — Native Raylib canvas running via Emscripten WASM
 *
 * Embeds the compiled WASM binary in an iframe.
 * Falls back to a loading/error state if WASM is not yet built.
 */

import { useState, useRef, useCallback } from 'react';

const WASM_URL = `${import.meta.env.BASE_URL}wasm/index.html`;

interface Props {
  onFallback?: () => void;
}

export default function TrinityCanvasWasm({ onFallback }: Props) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const iframeRef = useRef<HTMLIFrameElement>(null);

  const handleLoad = useCallback(() => {
    setLoading(false);
  }, []);

  const handleError = useCallback(() => {
    setLoading(false);
    setError(true);
  }, []);

  if (error) {
    return (
      <div style={{
        position: 'fixed', inset: 0, background: '#000',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'monospace', color: '#888',
      }}>
        <div style={{ fontSize: 'clamp(32px, 10vw, 48px)', marginBottom: 16, opacity: 0.3 }}>&#x26A0;</div>
        <div style={{ fontSize: 14, marginBottom: 8 }}>WASM build not available</div>
        <div style={{ fontSize: 11, color: '#555', marginBottom: 24 }}>
          Run: zig build trinity-canvas-wasm -Dtarget=wasm32-emscripten
        </div>
        {onFallback && (
          <button
            onClick={onFallback}
            style={{
              background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.15)',
              color: '#aaa', padding: '8px 20px', borderRadius: 6, cursor: 'pointer',
              fontSize: 12, fontFamily: 'monospace',
            }}
          >
            Switch to SVG mode
          </button>
        )}
      </div>
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      {loading && (
        <div style={{
          position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', zIndex: 10,
          fontFamily: 'monospace', color: '#666',
        }}>
          <div style={{
            width: 32, height: 32, border: '2px solid rgba(255,255,255,0.1)',
            borderTopColor: '#E8D44D', borderRadius: '50%',
            animation: 'spin 1s linear infinite',
          }} />
          <div style={{ marginTop: 12, fontSize: 11, letterSpacing: 2 }}>
            LOADING WASM...
          </div>
          <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
        </div>
      )}
      <iframe
        ref={iframeRef}
        src={WASM_URL}
        onLoad={handleLoad}
        onError={handleError}
        style={{
          width: '100%', height: '100%', border: 'none',
          opacity: loading ? 0 : 1,
          transition: 'opacity 0.3s ease-in',
        }}
        title="Trinity Canvas WASM"
        allow="cross-origin-isolated"
      />
    </div>
  );
}
