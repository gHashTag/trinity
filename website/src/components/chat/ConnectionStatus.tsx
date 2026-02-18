import { useEffect, useState } from 'react';
import { checkHealth } from '../../services/chatApi';

export default function ConnectionStatus() {
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const check = () => checkHealth().then(setConnected);
    check();
    const interval = setInterval(check, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, letterSpacing: 1 }}>
      <div style={{
        width: 8, height: 8, borderRadius: '50%',
        background: connected ? '#00e599' : '#ff4444',
        boxShadow: connected ? '0 0 6px #00e599' : '0 0 6px #ff4444',
      }} />
      <span style={{ color: connected ? '#00e599' : '#ff4444', fontFamily: 'monospace' }}>
        {connected ? 'CONNECTED' : 'OFFLINE'}
      </span>
    </div>
  );
}
