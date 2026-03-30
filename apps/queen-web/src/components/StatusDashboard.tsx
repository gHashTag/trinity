import { useQuery } from '@tanstack/react-query';

interface SystemStatus {
  trinity_identity: number;
  env_status: 'active' | 'degraded' | 'maintenance';
  swarm_active: boolean;
  last_improve?: {
    success: boolean;
    timestamp: number;
    message: string;
  };
}

interface HealthResponse {
  status: string;
  trinity_signature: number;
  improve_cycles: number;
  uptime_seconds: number;
}

export function StatusDashboard() {
  const { data: health } = useQuery<HealthResponse>({
    queryKey: ['health'],
    queryFn: async () => {
      const res = await fetch('/health');
      return res.json();
    },
    refetchInterval: 5000,
  });

  const { data: status } = useQuery<SystemStatus>({
    queryKey: ['status'],
    queryFn: async () => {
      const res = await fetch('/api/status');
      return res.json();
    },
    refetchInterval: 10000,
  });

  return (
    <div className="status-dashboard">
      <h2>👑 Queen Trinity Status</h2>
      <div className="metrics-grid">
        <MetricCard
          label="Trinity Signature"
          value={`φ² + 1/φ² = ${health?.trinity_signature ?? '...'}`}
        />
        <MetricCard
          label="Uptime"
          value={`${formatUptime(health?.uptime_seconds ?? 0)}`}
        />
        <MetricCard
          label="Improve Cycles"
          value={health?.improve_cycles ?? 0}
        />
        <MetricCard
          label="Environment"
          value={status?.env_status ?? 'unknown'}
          status={status?.env_status}
        />
        <MetricCard
          label="Swarm Active"
          value={status?.swarm_active ? 'Yes' : 'No'}
        />
      </div>
    </div>
  );
}

function MetricCard({ label, value, status }: {
  label: string;
  value: string | number;
  status?: string;
}) {
  const statusColor = status === 'active' ? '#4caf50' : status === 'degraded' ? '#ff9800' : '#9e9e9e';

  return (
    <div className="metric-card" style={{ borderColor: status ? statusColor : '#333' }}>
      <span className="metric-label">{label}</span>
      <span className="metric-value">{value}</span>
    </div>
  );
}

function formatUptime(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
  return `${Math.floor(seconds / 86400)}d`;
}
