import { useState, useRef, useEffect } from 'react';

interface Props {
  onSend: (message: string, imagePath?: string, audioPath?: string) => void;
  disabled: boolean;
  labels?: Labels;
}

export interface Labels {
  region: string;
  attachmentOptions: string;
  imagePlaceholder: string;
  audioPlaceholder: string;
  imageAria: string;
  audioAria: string;
  attachTitle: string;
  hideAttachments: string;
  showAttachments: string;
  messagePlaceholder: string;
  messageAria: string;
  sendAria: string;
  send: string;
  instructions: string;
}

const DEFAULT_LABELS: Labels = {
  region: 'Chat input',
  attachmentOptions: 'Attachment options',
  imagePlaceholder: 'image_path (optional)',
  audioPlaceholder: 'audio_path (optional)',
  imageAria: 'Image file path',
  audioAria: 'Audio file path',
  attachTitle: 'Attach image/audio path',
  hideAttachments: 'Hide attachment options',
  showAttachments: 'Show attachment options',
  messagePlaceholder: 'Message Trinity...',
  messageAria: 'Type your message',
  sendAria: 'Send message',
  send: 'SEND',
  instructions: 'Press Enter to send, Shift+Enter for new line',
};

export default function ChatInput({ onSend, disabled, labels = DEFAULT_LABELS }: Props) {
  const [text, setText] = useState('');
  const [showAttach, setShowAttach] = useState(false);
  const [imagePath, setImagePath] = useState('');
  const [audioPath, setAudioPath] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  // Focus input when attachment panel closes
  useEffect(() => {
    if (!showAttach) {
      inputRef.current?.focus();
    }
  }, [showAttach]);

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

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div
      style={{
        background: 'rgba(0,0,0,0.4)',
        backdropFilter: 'blur(10px)',
        borderRadius: 12,
        border: '1px solid rgba(255,215,0,0.2)',
      }}
      role="region"
      aria-label={labels.region}
    >
      {showAttach && (
        <div
          style={{
            padding: '8px 16px',
            display: 'flex',
            gap: 8,
            borderBottom: '1px solid rgba(255,215,0,0.1)',
          }}
          role="group"
          aria-label={labels.attachmentOptions}
        >
          <input
            type="text"
            value={imagePath}
            onChange={e => setImagePath(e.target.value)}
            placeholder={labels.imagePlaceholder}
            disabled={disabled}
            style={{
              flex: 1,
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: 6,
              padding: '4px 8px',
              outline: 'none',
              color: '#aaa',
              fontSize: 11,
              fontFamily: 'monospace',
            }}
            aria-label={labels.imageAria}
            id="chat-image-input"
          />
          <input
            type="text"
            value={audioPath}
            onChange={e => setAudioPath(e.target.value)}
            placeholder={labels.audioPlaceholder}
            disabled={disabled}
            style={{
              flex: 1,
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: 6,
              padding: '4px 8px',
              outline: 'none',
              color: '#aaa',
              fontSize: 11,
              fontFamily: 'monospace',
            }}
            aria-label={labels.audioAria}
            id="chat-audio-input"
          />
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, padding: '12px 16px' }}>
        <button
          onClick={() => setShowAttach(!showAttach)}
          style={{
            background: showAttach ? 'rgba(255,215,0,0.15)' : 'rgba(255,255,255,0.05)',
            border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: 6,
            padding: '4px 8px',
            color: showAttach ? '#ffd700' : '#666',
            cursor: 'pointer',
            fontFamily: 'monospace',
            fontSize: 14,
          }}
          title={labels.attachTitle}
          aria-label={showAttach ? labels.hideAttachments : labels.showAttachments}
          aria-pressed={showAttach}
          aria-expanded={showAttach}
          aria-controls="chat-image-input chat-audio-input"
          type="button"
        >
          +
        </button>
        <input
          ref={inputRef}
          type="text"
          value={text}
          onChange={e => setText(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={disabled}
          placeholder={labels.messagePlaceholder}
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: '#fff',
            fontSize: 14,
            fontFamily: 'monospace',
          }}
          aria-label={labels.messageAria}
          aria-describedby="chat-instructions"
          id="chat-input-field"
        />
        <button
          onClick={handleSend}
          disabled={disabled || !text.trim()}
          style={{
            background: disabled ? 'rgba(255,215,0,0.1)' : 'rgba(255,215,0,0.2)',
            border: '1px solid rgba(255,215,0,0.3)',
            borderRadius: 8,
            padding: '6px 16px',
            color: disabled ? '#666' : '#ffd700',
            cursor: disabled ? 'default' : 'pointer',
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 1,
          }}
          aria-label={labels.sendAria}
          aria-describedby="chat-instructions"
          type="submit"
          id="chat-send-button"
        >
          {labels.send}
        </button>
        <span id="chat-instructions" className="visually-hidden">
          {labels.instructions}
        </span>
      </div>
    </div>
  );
}
