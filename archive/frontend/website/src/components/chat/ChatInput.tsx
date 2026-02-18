import { useState } from 'react';

interface Props {
  onSend: (message: string, imagePath?: string, audioPath?: string) => void;
  disabled: boolean;
}

export default function ChatInput({ onSend, disabled }: Props) {
  const [text, setText] = useState('');
  const [showAttach, setShowAttach] = useState(false);
  const [imagePath, setImagePath] = useState('');
  const [audioPath, setAudioPath] = useState('');

  const handleSend = () => {
    const trimmed = text.trim();
    if (!trimmed || disabled) return;
    onSend(
      trimmed,
      imagePath.trim() || undefined,
      audioPath.trim() || undefined,
    );
    setText('');
    setImagePath('');
    setAudioPath('');
  };

  return (
    <div style={{
      background: 'rgba(0,0,0,0.4)',
      backdropFilter: 'blur(10px)',
      borderRadius: 12,
      border: '1px solid rgba(255,215,0,0.2)',
    }}>
      {showAttach && (
        <div style={{
          padding: '8px 16px', display: 'flex', gap: 8,
          borderBottom: '1px solid rgba(255,215,0,0.1)',
        }}>
          <input
            type="text"
            value={imagePath}
            onChange={e => setImagePath(e.target.value)}
            placeholder="image_path (optional)"
            disabled={disabled}
            style={{
              flex: 1, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: 6, padding: '4px 8px', outline: 'none',
              color: '#aaa', fontSize: 11, fontFamily: 'monospace',
            }}
          />
          <input
            type="text"
            value={audioPath}
            onChange={e => setAudioPath(e.target.value)}
            placeholder="audio_path (optional)"
            disabled={disabled}
            style={{
              flex: 1, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: 6, padding: '4px 8px', outline: 'none',
              color: '#aaa', fontSize: 11, fontFamily: 'monospace',
            }}
          />
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, padding: '12px 16px' }}>
        <button
          onClick={() => setShowAttach(!showAttach)}
          style={{
            background: showAttach ? 'rgba(255,215,0,0.15)' : 'rgba(255,255,255,0.05)',
            border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: 6, padding: '4px 8px',
            color: showAttach ? '#ffd700' : '#666',
            cursor: 'pointer', fontFamily: 'monospace', fontSize: 14,
          }}
          title="Attach image/audio path"
        >
          +
        </button>
        <input
          type="text"
          value={text}
          onChange={e => setText(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleSend()}
          disabled={disabled}
          placeholder="Message Trinity..."
          style={{
            flex: 1, background: 'transparent', border: 'none', outline: 'none',
            color: '#fff', fontSize: 14, fontFamily: 'monospace',
          }}
        />
        <button
          onClick={handleSend}
          disabled={disabled || !text.trim()}
          style={{
            background: disabled ? 'rgba(255,215,0,0.1)' : 'rgba(255,215,0,0.2)',
            border: '1px solid rgba(255,215,0,0.3)',
            borderRadius: 8, padding: '6px 16px',
            color: disabled ? '#666' : '#ffd700',
            cursor: disabled ? 'default' : 'pointer',
            fontFamily: 'monospace', fontSize: 12, letterSpacing: 1,
          }}
        >
          SEND
        </button>
      </div>
    </div>
  );
}
