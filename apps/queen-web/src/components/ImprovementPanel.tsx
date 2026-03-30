import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';

interface ImproveRequest {
  force?: boolean;
  episode_window?: number;
}

interface ImproveResponse {
  success: boolean;
  message: string;
  applied_deltas: number;
  quality_score: number;
}

export function ImprovementPanel() {
  const [isImproving, setIsImproving] = useState(false);
  const [result, setResult] = useState<ImproveResponse | null>(null);
  const queryClient = useQueryClient();

  const improveMutation = useMutation({
    mutationFn: async (data: ImproveRequest) => {
      setIsImproving(true);
      setResult(null);

      const res = await fetch('/api/improve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      const data = await res.json();
      setResult(data);
      setIsImproving(false);

      // Invalidate health and status queries
      queryClient.invalidateQueries({ queryKey: ['health'] });
      queryClient.invalidateQueries({ queryKey: ['status'] });
    },
  });

  const handleImprove = () => {
    improveMutation.mutate({});
  };

  return (
    <div className="improvement-panel">
      <h2>🔄 Self-Improvement</h2>
      <p>Trigger autonomous improvement cycle using .tri pipeline + .t27 algorithms</p>

      <button
        onClick={handleImprove}
        disabled={isImproving}
        className={`improve-button ${isImproving ? 'running' : ''}`}
      >
        {isImproving ? '⏳ Running...' : '🚀 Trigger Improvement'}
      </button>

      {result && (
        <div className={`improve-result ${result.success ? 'success' : 'failure'}`}>
          <div className="result-header">
            <span className={`status-icon ${result.success ? 'success' : 'failure'}`}>
              {result.success ? '✓' : '✗'}
            </span>
            <span className="result-message">{result.message}</span>
          </div>

          {result.applied_deltas > 0 && (
            <div className="result-metric">
              <span className="metric-label">Applied Deltas:</span>
              <span className="metric-value">{result.applied_deltas}</span>
            </div>
          )}

          {result.quality_score > 0 && (
            <div className="result-metric">
              <span className="metric-label">Quality Score:</span>
              <span className="metric-value">{(result.quality_score * 100).toFixed(0)}%</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
