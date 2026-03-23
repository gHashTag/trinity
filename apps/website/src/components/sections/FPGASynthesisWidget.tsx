import React, { useState, useEffect } from 'react';

interface FPGASynthesisMetrics {
  // Consciousness analysis
  iit_phi: number;
  gwt_active: number;
  hot_meta: number;
  selected_strategy: 'AggressiveTiming' | 'Conservative' | 'Balanced';
  strategy_rationale: string;

  // FORGE execution
  current_phase: string;
  phase_progress: number;  // 0-100
  runtime_ms: number;

  // Results
  verdict: 'PASS' | 'FAIL' | 'IN_PROGRESS';
  timing_slack_ns: number;
  resource_usage: {
    lut: { used: number; total: number };
    ff: { used: number; total: number };
    iob: { used: number; total: number };
  };

  // Learning
  hebbian_delta: number;
  novelty: number;
  improvement_rate: number;
}

export const FPGASynthesisWidget: React.FC = () => {
  const [metrics, setMetrics] = useState<FPGASynthesisMetrics | null>(null);
  const [expanded, setExpanded] = useState(true);

  useEffect(() => {
    // Poll at specious present interval (382ms)
    const interval = setInterval(async () => {
      try {
        const response = await fetch('/api/fpga/synthesis');
        if (response.ok) {
          const data = await response.json();
          setMetrics(data);
        } else {
          // Use mock data if API not available
          setMetrics(getMockMetrics());
        }
      } catch {
        // Use mock data on error
        setMetrics(getMockMetrics());
      }
    }, 382);

    return () => clearInterval(interval);
  }, []);

  // Mock data for development
  const getMockMetrics = (): FPGASynthesisMetrics => ({
    iit_phi: 0.723,
    gwt_active: 0.856,
    hot_meta: 0.612,
    selected_strategy: 'AggressiveTiming',
    strategy_rationale: 'High integration (IIT) + active workspace (GWT)',
    current_phase: 'Routing',
    phase_progress: 67,
    runtime_ms: 1523,
    verdict: 'IN_PROGRESS',
    timing_slack_ns: 0.0,
    resource_usage: {
      lut: { used: 2453, total: 63400 },
      ff: { used: 1024, total: 126800 },
      iob: { used: 8, total: 210 },
    },
    hebbian_delta: 0.015,
    novelty: 0.342,
    improvement_rate: 73.2,
  });

  if (!metrics) return null;

  const glassStyle = {
    background: 'rgba(0, 204, 255, 0.05)',
    backdropFilter: 'blur(10px)',
    border: '1px solid rgba(0, 204, 255, 0.2)',
    borderRadius: '12px',
    color: '#00ccff',
  };

  const cyan = '#00ccff';
  const green = metrics.verdict === 'PASS' ? '#00e676' :
                metrics.verdict === 'FAIL' ? '#ff5252' : '#ffa726';
  const bgColor = metrics.verdict === 'PASS' ? 'rgba(0, 230, 118, 0.1)' :
                  metrics.verdict === 'FAIL' ? 'rgba(255, 82, 82, 0.1)' :
                  'rgba(255, 167, 38, 0.1)';

  return (
    <div style={glassStyle} className="p-4 mb-4">
      <div
        className="flex justify-between items-center cursor-pointer"
        onClick={() => setExpanded(!expanded)}
      >
        <h3 className="font-bold text-sm" style={{ color: cyan }}>
          ⚡ FPGA SYNTHESIS (Consciousness-Guided)
        </h3>
        <span className="text-xs">{expanded ? '▼' : '▶'}</span>
      </div>

      {expanded && (
        <div className="mt-3 space-y-3">
          {/* Consciousness Analysis */}
          <div>
            <div className="text-xs text-gray-400 mb-1">CONSCIOUSNESS ANALYSIS</div>
            <div className="grid grid-cols-3 gap-2 text-xs">
              <div>
                <div className="font-mono" style={{ color: cyan }}>
                  IIT Φ = {metrics.iit_phi.toFixed(3)}
                </div>
              </div>
              <div>
                <div className="font-mono" style={{ color: cyan }}>
                  GWT = {metrics.gwt_active.toFixed(3)}
                </div>
              </div>
              <div>
                <div className="font-mono" style={{ color: cyan }}>
                  HOT = {metrics.hot_meta.toFixed(3)}
                </div>
              </div>
            </div>
            <div className="text-xs mt-1" style={{ color: '#ffd700' }}>
              Strategy: {metrics.selected_strategy}
            </div>
            <div className="text-xs text-gray-500">
              {metrics.strategy_rationale}
            </div>
          </div>

          {/* FORGE Progress */}
          <div>
            <div className="text-xs text-gray-400 mb-1">
              FORGE: {metrics.current_phase} ({metrics.phase_progress}%)
            </div>
            <div className="w-full bg-gray-800 rounded-full h-2">
              <div
                className="h-2 rounded-full transition-all"
                style={{
                  width: `${metrics.phase_progress}%`,
                  background: cyan,
                  opacity: 0.8,
                }}
              />
            </div>
            <div className="text-xs text-gray-500 mt-1">
              Runtime: {metrics.runtime_ms}ms
            </div>
          </div>

          {/* Verdict */}
          <div style={{ background: bgColor, borderRadius: '8px', padding: '8px' }}>
            <div className="text-xs text-gray-400 mb-1">VERDICT</div>
            <div
              className="text-sm font-bold"
              style={{ color: green }}
            >
              {metrics.verdict}
            </div>
            {metrics.verdict === 'PASS' && (
              <>
                <div className="text-xs text-gray-400 mt-1">
                  Timing Slack: {metrics.timing_slack_ns.toFixed(2)}ns
                </div>
                <div className="grid grid-cols-3 gap-2 text-xs mt-1">
                  <div>LUT: {metrics.resource_usage.lut.used}/{metrics.resource_usage.lut.total}</div>
                  <div>FF: {metrics.resource_usage.ff.used}/{metrics.resource_usage.ff.total}</div>
                  <div>IOB: {metrics.resource_usage.iob.used}/{metrics.resource_usage.iob.total}</div>
                </div>
              </>
            )}
          </div>

          {/* Learning */}
          <div>
            <div className="text-xs text-gray-400 mb-1">LEARNING (Hebbian)</div>
            <div className="grid grid-cols-3 gap-2 text-xs">
              <div>
                <div className="font-mono" style={{ color: cyan }}>
                  Δ = {metrics.hebbian_delta > 0 ? '+' : ''}{metrics.hebbian_delta.toFixed(3)}
                </div>
              </div>
              <div>
                <div className="font-mono" style={{ color: cyan }}>
                  Novelty = {metrics.novelty.toFixed(3)}
                </div>
              </div>
              <div>
                <div className="font-mono" style={{ color: metrics.improvement_rate > 61.8 ? '#00e676' : cyan }}>
                  {metrics.improvement_rate.toFixed(1)}% {metrics.improvement_rate > 61.8 && '✓'}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default FPGASynthesisWidget;
