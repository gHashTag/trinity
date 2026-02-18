import { motion } from 'framer-motion';

interface Props {
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

const SOURCE_COLORS: Record<string, string> = {
  Tool: '#4488ff',
  Symbolic: '#ffd700',
  TVCCorpus: '#00e599',
  LocalLLM: '#ff8844',
  GroqAPI: '#ff8844',
  ClaudeAPI: '#b366ff',
  Vision: '#ff66aa',
  Error: '#ff4444',
};

export default function ChatMessage({ role, content, source, confidence, latency_us, tool_name, reflection, learned }: Props) {
  const isUser = role === 'user';

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', damping: 25, stiffness: 300 }}
      style={{
        display: 'flex',
        justifyContent: isUser ? 'flex-end' : 'flex-start',
        marginBottom: 12,
      }}
    >
      <div style={{
        maxWidth: '75%',
        padding: '10px 14px',
        borderRadius: isUser ? '14px 14px 4px 14px' : '14px 14px 14px 4px',
        background: isUser ? 'rgba(255,215,0,0.12)' : 'rgba(0,229,153,0.08)',
        backdropFilter: 'blur(10px)',
        border: `1px solid ${isUser ? 'rgba(255,215,0,0.2)' : 'rgba(0,229,153,0.15)'}`,
      }}>
        <div style={{
          color: '#e0e0e0', fontSize: 14, lineHeight: 1.5,
          fontFamily: 'monospace', whiteSpace: 'pre-wrap', wordBreak: 'break-word',
        }}>
          {content}
        </div>
        {!isUser && source && (
          <div style={{ marginTop: 6, display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            <span style={{
              fontSize: 10, padding: '2px 6px', borderRadius: 4,
              background: `${SOURCE_COLORS[source] || '#666'}22`,
              color: SOURCE_COLORS[source] || '#888',
              border: `1px solid ${SOURCE_COLORS[source] || '#666'}44`,
              fontFamily: 'monospace', letterSpacing: 0.5,
            }}>
              {source}
            </span>
            {confidence !== undefined && (
              <span style={{ fontSize: 10, color: '#666', fontFamily: 'monospace' }}>
                {(confidence * 100).toFixed(0)}%
              </span>
            )}
            {latency_us !== undefined && (
              <span style={{ fontSize: 10, color: '#555', fontFamily: 'monospace' }}>
                {latency_us < 1000 ? `${latency_us}us` : `${(latency_us / 1000).toFixed(1)}ms`}
              </span>
            )}
            {tool_name && (
              <span style={{
                fontSize: 10, padding: '2px 6px', borderRadius: 4,
                background: 'rgba(68,136,255,0.15)',
                color: '#4488ff',
                border: '1px solid rgba(68,136,255,0.3)',
                fontFamily: 'monospace', letterSpacing: 0.5,
              }}>
                {tool_name}
              </span>
            )}
            {learned === true && (
              <motion.span
                animate={{ boxShadow: ['0 0 4px rgba(0,229,153,0.2)', '0 0 12px rgba(0,229,153,0.5)', '0 0 4px rgba(0,229,153,0.2)'] }}
                transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
                style={{
                  fontSize: 10, padding: '2px 6px', borderRadius: 4,
                  background: 'rgba(0,229,153,0.15)',
                  color: '#00e599',
                  border: '1px solid rgba(0,229,153,0.3)',
                  fontFamily: 'monospace', letterSpacing: 0.5,
                  textShadow: '0 0 6px rgba(0,229,153,0.4)',
                  display: 'inline-block',
                }}>
                LEARNED
              </motion.span>
            )}
            {reflection && reflection !== 'NotApplicable' && reflection !== 'Saved' && reflection !== 'Disabled' && (
              <span style={{
                fontSize: 10, padding: '2px 6px', borderRadius: 4,
                background: 'rgba(255,255,255,0.05)',
                color: '#555',
                border: '1px solid rgba(255,255,255,0.1)',
                fontFamily: 'monospace', letterSpacing: 0.5,
              }}>
                FILTERED: {reflection.replace('Filtered', '')}
              </span>
            )}
          </div>
        )}
      </div>
    </motion.div>
  );
}
