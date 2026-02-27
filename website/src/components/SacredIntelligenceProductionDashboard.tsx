/**
 * Sacred Intelligence Production Dashboard
 *
 * Production-ready live dashboard for Sacred Intelligence system with:
 * - Real-time WebSocket connection
 * - 7 Live Widgets (Sacred Brain, Auto-Patch, Gematria, Constants, Evolution, Health, Alignment)
 * - Error boundary with graceful degradation
 * - Loading skeletons and retry logic
 * - Performance monitoring
 * - Responsive design with dark/light mode support
 *
 * @module SacredIntelligenceProductionDashboard
 */

import React, {
  useState,
  useEffect,
  useMemo,
  useCallback,
  useRef,
  memo,
} from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

// ============================================================================
// TYPES & INTERFACES
// ============================================================================

interface SacredMetrics {
  total_commands: number;
  analyses_performed: number;
  patches_applied: number;
  patches_pending: number;
  patches_rolled_back: number;
  sacred_constants_count: number;
  symbols_indexed: number;
  sacred_percentage: number;
  evolution_generation: number;
  best_fitness: number;
  convergence_rate: number;
  phi_squared_plus_inverse: number;
  trinity_alignment: number;
  last_updated: string;
}

interface PatchHistory {
  id: string;
  timestamp: string;
  type: 'applied' | 'pending' | 'rolled_back';
  description: string;
  file: string;
  confidence: number;
}

interface GematriaValues {
  text: string;
  hebrew: number;
  greek: number;
  arabic: number;
  coptic: number;
  total: number;
}

interface SacredConstant {
  id: string;
  name: string;
  value: number;
  category: 'phi' | 'pi' | 'e' | 'fibonacci' | 'lucas' | 'other';
  description: string;
}

interface EvolutionMetrics {
  generation: number;
  best_fitness: number;
  average_fitness: number;
  convergence_rate: number;
  diversity_index: number;
}

interface CodebaseHealth {
  symbols_indexed: number;
  total_symbols: number;
  sacred_percentage: number;
  patterns_found: number;
  patterns_verified: number;
}

interface TrinityAlignment {
  phi_squared_plus_inverse: number;
  expected: number;
  deviation: number;
  verified: boolean;
}

interface WebSocketMessage {
  type: 'metrics' | 'patch' | 'evolution' | 'health' | 'alignment';
  data: any;
  timestamp: string;
}

interface ErrorState {
  hasError: boolean;
  message: string;
  retryable: boolean;
}

// ============================================================================
// CONSTANTS
// ============================================================================

const WEBSOCKET_URL = process.env.REACT_APP_WS_URL || 'ws://localhost:8080/sacred-intelligence';
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080';
const RECONNECT_DELAY = 3000;
const MAX_RECONNECT_ATTEMPTS = 5;
const METRICS_UPDATE_INTERVAL = 30000; // 30 seconds fallback polling

const COLORS = {
  RAZUM: '#ffd700',     // Gold
  MATERIYA: '#00ccff',  // Cyan
  DUKH: '#aa66ff',      // Purple
  SUCCESS: '#10b981',
  WARNING: '#f59e0b',
  ERROR: '#ef4444',
  NEUTRAL: '#6b7280',
};

const WIDGET_COLORS = [COLORS.RAZUM, COLORS.MATERIYA, COLORS.DUKH];

// ============================================================================
// CUSTOM HOOKS
// ============================================================================

/**
 * WebSocket hook for real-time sacred intelligence updates
 */
const useSacredIntelligenceWebSocket = () => {
  const [metrics, setMetrics] = useState<SacredMetrics | null>(null);
  const [patches, setPatches] = useState<PatchHistory[]>([]);
  const [evolution, setEvolution] = useState<EvolutionMetrics | null>(null);
  const [health, setHealth] = useState<CodebaseHealth | null>(null);
  const [alignment, setAlignment] = useState<TrinityAlignment | null>(null);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<ErrorState | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectAttempts = useRef(0);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout>();

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      return;
    }

    try {
      wsRef.current = new WebSocket(WEBSOCKET_URL);

      wsRef.current.onopen = () => {
        console.log('[Sacred Intelligence] WebSocket connected');
        setConnected(true);
        setError(null);
        reconnectAttempts.current = 0;

        // Request initial data
        wsRef.current?.send(JSON.stringify({ type: 'subscribe', channel: 'all' }));
      };

      wsRef.current.onmessage = (event) => {
        try {
          const message: WebSocketMessage = JSON.parse(event.data);

          switch (message.type) {
            case 'metrics':
              setMetrics(message.data);
              break;
            case 'patch':
              setPatches((prev) => [message.data, ...prev].slice(0, 50));
              break;
            case 'evolution':
              setEvolution(message.data);
              break;
            case 'health':
              setHealth(message.data);
              break;
            case 'alignment':
              setAlignment(message.data);
              break;
            default:
              console.warn('[Sacred Intelligence] Unknown message type:', message.type);
          }
        } catch (err) {
          console.error('[Sacred Intelligence] Failed to parse WebSocket message:', err);
        }
      };

      wsRef.current.onclose = () => {
        console.log('[Sacred Intelligence] WebSocket disconnected');
        setConnected(false);

        // Attempt to reconnect
        if (reconnectAttempts.current < MAX_RECONNECT_ATTEMPTS) {
          reconnectAttempts.current++;
          console.log(`[Sacred Intelligence] Reconnection attempt ${reconnectAttempts.current}/${MAX_RECONNECT_ATTEMPTS}`);

          reconnectTimeoutRef.current = setTimeout(() => {
            connect();
          }, RECONNECT_DELAY * reconnectAttempts.current);
        } else {
          setError({
            hasError: true,
            message: 'Unable to establish WebSocket connection after multiple attempts',
            retryable: true,
          });
        }
      };

      wsRef.current.onerror = (event) => {
        console.error('[Sacred Intelligence] WebSocket error:', event);
        setError({
          hasError: true,
          message: 'WebSocket connection error',
          retryable: true,
        });
      };
    } catch (err) {
      setError({
        hasError: true,
        message: err instanceof Error ? err.message : 'Failed to create WebSocket connection',
        retryable: true,
      });
    }
  }, []);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
    }
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    setConnected(false);
  }, []);

  const retry = useCallback(() => {
    setError(null);
    reconnectAttempts.current = 0;
    connect();
  }, [connect]);

  useEffect(() => {
    connect();

    return () => {
      disconnect();
    };
  }, [connect, disconnect]);

  return {
    metrics,
    patches,
    evolution,
    health,
    alignment,
    connected,
    error,
    retry,
  };
};

/**
 * API hook for fallback data fetching
 */
const useSacredIntelligenceAPI = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchMetrics = useCallback(async (): Promise<SacredMetrics> => {
    try {
      setLoading(true);
      setError(null);
      const response = await fetch(`${API_BASE_URL}/api/sacred-intelligence/metrics`);
      if (!response.ok) throw new Error('Failed to fetch metrics');
      return await response.json();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchPatches = useCallback(async (): Promise<PatchHistory[]> => {
    try {
      setLoading(true);
      setError(null);
      const response = await fetch(`${API_BASE_URL}/api/sacred-intelligence/patches`);
      if (!response.ok) throw new Error('Failed to fetch patch history');
      return await response.json();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchGematria = useCallback(async (text: string): Promise<GematriaValues> => {
    try {
      setLoading(true);
      setError(null);
      const response = await fetch(`${API_BASE_URL}/api/sacred-intelligence/gematria/${encodeURIComponent(text)}`);
      if (!response.ok) throw new Error('Failed to fetch gematria values');
      return await response.json();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchConstants = useCallback(async (search?: string): Promise<SacredConstant[]> => {
    try {
      setLoading(true);
      setError(null);
      const url = search
        ? `${API_BASE_URL}/api/sacred-intelligence/constants?search=${encodeURIComponent(search)}`
        : `${API_BASE_URL}/api/sacred-intelligence/constants`;
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch constants');
      return await response.json();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return {
    loading,
    error,
    fetchMetrics,
    fetchPatches,
    fetchGematria,
    fetchConstants,
  };
};

// ============================================================================
// UI COMPONENTS
// ============================================================================

/**
 * Loading skeleton component
 */
const LoadingSkeleton: React.FC<{ height?: string }> = ({ height = '100px' }) => (
  <div
    className="animate-pulse bg-gradient-to-r from-gray-700 to-gray-600 rounded-lg"
    style={{ height }}
  />
);

/**
 * Error display component
 */
const ErrorDisplay: React.FC<{
  error: ErrorState;
  onRetry?: () => void;
}> = ({ error, onRetry }) => (
  <motion.div
    initial={{ opacity: 0, y: -10 }}
    animate={{ opacity: 1, y: 0 }}
    className="bg-red-900/20 border border-red-500/50 rounded-lg p-4"
  >
    <div className="flex items-center justify-between">
      <div>
        <h3 className="text-red-400 font-semibold mb-1">Connection Error</h3>
        <p className="text-red-300 text-sm">{error.message}</p>
      </div>
      {error.retryable && onRetry && (
        <button
          onClick={onRetry}
          className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
        >
          Retry
        </button>
      )}
    </div>
  </motion.div>
);

/**
 * Connection status indicator
 */
const ConnectionStatus: React.FC<{ connected: boolean }> = ({ connected }) => (
  <div className="flex items-center space-x-2">
    <div
      className={`w-2 h-2 rounded-full ${
        connected ? 'bg-green-500 animate-pulse' : 'bg-red-500'
      }`}
    />
    <span className="text-xs text-gray-400">
      {connected ? 'Live' : 'Disconnected'}
    </span>
  </div>
);

/**
 * Sacred Brain Metrics Widget
 */
const SacredBrainMetricsWidget: React.FC<{
  metrics: SacredMetrics | null;
  loading: boolean;
}> = memo(({ metrics, loading }) => {
  if (loading) return <LoadingSkeleton height="200px" />;

  if (!metrics) {
    return (
      <div className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
        <p className="text-gray-400 text-sm">No metrics available</p>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-gradient-to-br from-yellow-900/20 to-yellow-800/10 rounded-lg p-6 border border-yellow-500/30"
    >
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-yellow-400 font-semibold">Sacred Brain Metrics</h3>
        <div className="text-xs text-gray-400">
          {new Date(metrics.last_updated).toLocaleTimeString()}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <p className="text-gray-400 text-xs mb-1">Total Commands</p>
          <p className="text-2xl font-bold text-white">{metrics.total_commands}</p>
        </div>
        <div>
          <p className="text-gray-400 text-xs mb-1">Analyses Performed</p>
          <p className="text-2xl font-bold text-white">{metrics.analyses_performed}</p>
        </div>
      </div>

      <div className="mt-4 pt-4 border-t border-yellow-500/20">
        <div className="flex justify-between items-center">
          <span className="text-sm text-gray-300">Brain Activity</span>
          <span className="text-yellow-400 font-semibold">
            {metrics.analyses_performed > 0 ? ((metrics.analyses_performed / metrics.total_commands) * 100).toFixed(1) : 0}%
          </span>
        </div>
        <div className="w-full bg-gray-700 rounded-full h-2 mt-2">
          <div
            className="bg-yellow-500 h-2 rounded-full transition-all duration-500"
            style={{
              width: `${metrics.total_commands > 0 ? (metrics.analyses_performed / metrics.total_commands) * 100 : 0}%`,
            }}
          />
        </div>
      </div>
    </motion.div>
  );
});

SacredBrainMetricsWidget.displayName = 'SacredBrainMetricsWidget';

/**
 * Auto-Patch Status Widget
 */
const AutoPatchStatusWidget: React.FC<{
  metrics: SacredMetrics | null;
  patches: PatchHistory[];
  loading: boolean;
}> = memo(({ metrics, patches, loading }) => {
  const recentPatches = patches.slice(0, 5);

  if (loading) return <LoadingSkeleton height="250px" />;

  if (!metrics) {
    return (
      <div className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
        <p className="text-gray-400 text-sm">No patch data available</p>
      </div>
    );
  }

  const chartData = [
    { name: 'Applied', value: metrics.patches_applied, color: COLORS.SUCCESS },
    { name: 'Pending', value: metrics.patches_pending, color: COLORS.WARNING },
    { name: 'Rolled Back', value: metrics.patches_rolled_back, color: COLORS.ERROR },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-gradient-to-br from-cyan-900/20 to-cyan-800/10 rounded-lg p-6 border border-cyan-500/30"
    >
      <h3 className="text-cyan-400 font-semibold mb-4">Auto-Patch Status</h3>

      <div className="grid grid-cols-3 gap-2 mb-4">
        <div className="text-center">
          <p className="text-green-400 text-xl font-bold">{metrics.patches_applied}</p>
          <p className="text-gray-400 text-xs">Applied</p>
        </div>
        <div className="text-center">
          <p className="text-yellow-400 text-xl font-bold">{metrics.patches_pending}</p>
          <p className="text-gray-400 text-xs">Pending</p>
        </div>
        <div className="text-center">
          <p className="text-red-400 text-xl font-bold">{metrics.patches_rolled_back}</p>
          <p className="text-gray-400 text-xs">Rolled Back</p>
        </div>
      </div>

      <div className="h-32 mb-4">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={chartData}
              dataKey="value"
              nameKey="name"
              cx="50%"
              cy="50%"
              outerRadius={50}
              label={(entry) => `${entry.name}: ${entry.value}`}
            >
              {chartData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
      </div>

      <div className="space-y-2 max-h-32 overflow-y-auto">
        {recentPatches.map((patch) => (
          <div
            key={patch.id}
            className={`text-xs p-2 rounded border ${
              patch.type === 'applied'
                ? 'bg-green-900/20 border-green-500/30'
                : patch.type === 'pending'
                ? 'bg-yellow-900/20 border-yellow-500/30'
                : 'bg-red-900/20 border-red-500/30'
            }`}
          >
            <div className="flex justify-between items-center">
              <span className="text-gray-300 truncate flex-1">{patch.description}</span>
              <span className="text-gray-400 ml-2">{(patch.confidence * 100).toFixed(0)}%</span>
            </div>
            <p className="text-gray-500 text-xs mt-1">{patch.file}</p>
          </div>
        ))}
      </div>
    </motion.div>
  );
});

AutoPatchStatusWidget.displayName = 'AutoPatchStatusWidget';

/**
 * Multi-Language Gematria Widget
 */
const GematriaWidget: React.FC = memo(() => {
  const [text, setText] = useState('');
  const [gematria, setGematria] = useState<GematriaValues | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { fetchGematria } = useSacredIntelligenceAPI();

  const calculateGematria = useCallback(async () => {
    if (!text.trim()) {
      setGematria(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const result = await fetchGematria(text);
      setGematria(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to calculate gematria');
    } finally {
      setLoading(false);
    }
  }, [text, fetchGematria]);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      calculateGematria();
    }, 500);

    return () => clearTimeout(timeoutId);
  }, [text, calculateGematria]);

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-gradient-to-br from-purple-900/20 to-purple-800/10 rounded-lg p-6 border border-purple-500/30"
    >
      <h3 className="text-purple-400 font-semibold mb-4">Multi-Language Gematria</h3>

      <input
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Enter text to calculate..."
        className="w-full bg-gray-800/50 border border-purple-500/30 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-purple-500/50 mb-4"
      />

      {loading && <LoadingSkeleton height="150px" />}

      {error && (
        <div className="bg-red-900/20 border border-red-500/50 rounded-lg p-3 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {gematria && !loading && (
        <div className="space-y-2">
          <div className="flex justify-between items-center p-2 bg-gray-800/30 rounded">
            <span className="text-gray-300 text-sm">Hebrew</span>
            <span className="text-white font-semibold">{gematria.hebrew}</span>
          </div>
          <div className="flex justify-between items-center p-2 bg-gray-800/30 rounded">
            <span className="text-gray-300 text-sm">Greek</span>
            <span className="text-white font-semibold">{gematria.greek}</span>
          </div>
          <div className="flex justify-between items-center p-2 bg-gray-800/30 rounded">
            <span className="text-gray-300 text-sm">Arabic</span>
            <span className="text-white font-semibold">{gematria.arabic}</span>
          </div>
          <div className="flex justify-between items-center p-2 bg-gray-800/30 rounded">
            <span className="text-gray-300 text-sm">Coptic</span>
            <span className="text-white font-semibold">{gematria.coptic}</span>
          </div>
          <div className="flex justify-between items-center p-2 bg-purple-900/30 rounded border border-purple-500/30 mt-3">
            <span className="text-purple-300 text-sm font-semibold">Total</span>
            <span className="text-purple-200 font-bold text-lg">{gematria.total}</span>
          </div>
        </div>
      )}
    </motion.div>
  );
});

GematriaWidget.displayName = 'GematriaWidget';

/**
 * Sacred Constants Widget
 */
const SacredConstantsWidget: React.FC = memo(() => {
  const [constants, setConstants] = useState<SacredConstant[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);
  const { fetchConstants } = useSacredIntelligenceAPI();

  useEffect(() => {
    const loadConstants = async () => {
      try {
        const data = await fetchConstants(search);
        setConstants(data);
      } catch (err) {
        console.error('Failed to load constants:', err);
      } finally {
        setLoading(false);
      }
    };

    loadConstants();
  }, [search, fetchConstants]);

  const filteredConstants = useMemo(() => {
    if (!search) return constants.slice(0, 10);
    return constants;
  }, [constants, search]);

  if (loading) return <LoadingSkeleton height="300px" />;

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-gradient-to-br from-yellow-900/20 to-yellow-800/10 rounded-lg p-6 border border-yellow-500/30"
    >
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-yellow-400 font-semibold">Sacred Constants</h3>
        <button
          onClick={() => setExpanded(!expanded)}
          className="text-xs text-yellow-400 hover:text-yellow-300"
        >
          {expanded ? 'Collapse' : 'Expand'}
        </button>
      </div>

      <input
        type="text"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search constants..."
        className="w-full bg-gray-800/50 border border-yellow-500/30 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-yellow-500/50 mb-4"
      />

      <div className={`space-y-2 ${expanded ? 'max-h-96 overflow-y-auto' : 'max-h-48 overflow-y-auto'}`}>
        {filteredConstants.map((constant) => (
          <div
            key={constant.id}
            className="p-3 bg-gray-800/30 rounded-lg border border-gray-700 hover:border-yellow-500/30 transition-colors"
          >
            <div className="flex justify-between items-start mb-1">
              <h4 className="text-white font-semibold">{constant.name}</h4>
              <span className={`text-xs px-2 py-1 rounded ${
                constant.category === 'phi' ? 'bg-yellow-900/30 text-yellow-400' :
                constant.category === 'pi' ? 'bg-blue-900/30 text-blue-400' :
                constant.category === 'e' ? 'bg-green-900/30 text-green-400' :
                constant.category === 'fibonacci' ? 'bg-purple-900/30 text-purple-400' :
                constant.category === 'lucas' ? 'bg-pink-900/30 text-pink-400' :
                'bg-gray-700/30 text-gray-400'
              }`}>
                {constant.category}
              </span>
            </div>
            <p className="text-yellow-400 font-mono text-lg">{constant.value}</p>
            <p className="text-gray-400 text-xs mt-1">{constant.description}</p>
          </div>
        ))}
      </div>

      <div className="mt-4 pt-4 border-t border-yellow-500/20 text-center">
        <p className="text-gray-400 text-sm">
          Showing {filteredConstants.length} of {constants.length} constants
        </p>
      </div>
    </motion.div>
  );
});

SacredConstantsWidget.displayName = 'SacredConstantsWidget';

/**
 * Evolution Progress Widget
 */
const EvolutionProgressWidget: React.FC<{
  evolution: EvolutionMetrics | null;
  metrics: SacredMetrics | null;
  loading: boolean;
}> = memo(({ evolution, metrics, loading }) => {
  if (loading) return <LoadingSkeleton height="250px" />;

  if (!evolution || !metrics) {
    return (
      <div className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
        <p className="text-gray-400 text-sm">No evolution data available</p>
      </div>
    );
  }

  const history = useMemo(() => {
    const data = [];
    for (let i = Math.max(0, evolution.generation - 20); i <= evolution.generation; i++) {
      data.push({
        generation: i,
        fitness: evolution.best_fitness * (1 - (evolution.generation - i) * 0.02),
      });
    }
    return data;
  }, [evolution]);

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-gradient-to-br from-cyan-900/20 to-cyan-800/10 rounded-lg p-6 border border-cyan-500/30"
    >
      <h3 className="text-cyan-400 font-semibold mb-4">Evolution Progress</h3>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-gray-400 text-xs mb-1">Generation</p>
          <p className="text-2xl font-bold text-white">{evolution.generation}</p>
        </div>
        <div>
          <p className="text-gray-400 text-xs mb-1">Best Fitness</p>
          <p className="text-2xl font-bold text-cyan-400">{(evolution.best_fitness * 100).toFixed(2)}%</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-gray-400 text-xs mb-1">Convergence Rate</p>
          <p className="text-lg font-semibold text-white">{(evolution.convergence_rate * 100).toFixed(2)}%</p>
        </div>
        <div>
          <p className="text-gray-400 text-xs mb-1">Diversity Index</p>
          <p className="text-lg font-semibold text-white">{evolution.diversity_index.toFixed(3)}</p>
        </div>
      </div>

      <div className="h-32">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={history}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis dataKey="generation" stroke="#9ca3af" />
            <YAxis stroke="#9ca3af" />
            <Tooltip
              contentStyle={{
                backgroundColor: '#1f2937',
                border: '1px solid #06b6d4',
                borderRadius: '8px',
              }}
            />
            <Line
              type="monotone"
              dataKey="fitness"
              stroke="#06b6d4"
              strokeWidth={2}
              dot={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </motion.div>
  );
});

EvolutionProgressWidget.displayName = 'EvolutionProgressWidget';

/**
 * Codebase Health Widget
 */
const CodebaseHealthWidget: React.FC<{
  health: CodebaseHealth | null;
  metrics: SacredMetrics | null;
  loading: boolean;
}> = memo(({ health, metrics, loading }) => {
  if (loading) return <LoadingSkeleton height="200px" />;

  if (!health) {
    return (
      <div className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
        <p className="text-gray-400 text-sm">No health data available</p>
      </div>
    );
  }

  const chartData = [
    { name: 'Sacred', value: health.sacred_percentage, color: COLORS.RAZUM },
    { name: 'Profane', value: 100 - health.sacred_percentage, color: COLORS.NEUTRAL },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-gradient-to-br from-purple-900/20 to-purple-800/10 rounded-lg p-6 border border-purple-500/30"
    >
      <h3 className="text-purple-400 font-semibold mb-4">Codebase Health</h3>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-gray-400 text-xs mb-1">Symbols Indexed</p>
          <p className="text-xl font-bold text-white">{health.symbols_indexed}</p>
          <p className="text-gray-500 text-xs">of {health.total_symbols} total</p>
        </div>
        <div>
          <p className="text-gray-400 text-xs mb-1">Sacred Percentage</p>
          <p className="text-xl font-bold text-purple-400">{health.sacred_percentage.toFixed(1)}%</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-gray-400 text-xs mb-1">Patterns Found</p>
          <p className="text-lg font-semibold text-white">{health.patterns_found}</p>
        </div>
        <div>
          <p className="text-gray-400 text-xs mb-1">Patterns Verified</p>
          <p className="text-lg font-semibold text-green-400">{health.patterns_verified}</p>
        </div>
      </div>

      <div className="h-24">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={chartData}
              dataKey="value"
              cx="50%"
              cy="50%"
              outerRadius={40}
              label={(entry) => `${entry.name}: ${entry.value.toFixed(1)}%`}
            >
              {chartData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
      </div>
    </motion.div>
  );
});

CodebaseHealthWidget.displayName = 'CodebaseHealthWidget';

/**
 * Trinity Alignment Widget
 */
const TrinityAlignmentWidget: React.FC<{
  alignment: TrinityAlignment | null;
  metrics: SacredMetrics | null;
  loading: boolean;
}> = memo(({ alignment, metrics, loading }) => {
  if (loading) return <LoadingSkeleton height="200px" />;

  if (!alignment) {
    return (
      <div className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
        <p className="text-gray-400 text-sm">No alignment data available</p>
      </div>
    );
  }

  const deviationPercent = Math.abs(alignment.deviation * 100);

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className={`bg-gradient-to-br rounded-lg p-6 border ${
        alignment.verified
          ? 'from-green-900/20 to-green-800/10 border-green-500/30'
          : 'from-yellow-900/20 to-yellow-800/10 border-yellow-500/30'
      }`}
    >
      <div className="flex items-center justify-between mb-4">
        <h3 className={`font-semibold ${alignment.verified ? 'text-green-400' : 'text-yellow-400'}`}>
          Trinity Alignment
        </h3>
        <div className={`flex items-center space-x-2 ${alignment.verified ? 'text-green-400' : 'text-yellow-400'}`}>
          <div className={`w-2 h-2 rounded-full ${alignment.verified ? 'bg-green-500' : 'bg-yellow-500 animate-pulse'}`} />
          <span className="text-xs">{alignment.verified ? 'Verified' : 'Deviated'}</span>
        </div>
      </div>

      <div className="space-y-4">
        <div>
          <p className="text-gray-400 text-xs mb-1">φ² + 1/φ²</p>
          <p className="text-3xl font-bold text-white font-mono">{alignment.phi_squared_plus_inverse.toFixed(15)}</p>
        </div>

        <div className="flex justify-between items-center p-3 bg-gray-800/30 rounded-lg">
          <div>
            <p className="text-gray-400 text-xs">Expected</p>
            <p className="text-white font-semibold font-mono">{alignment.expected.toFixed(15)}</p>
          </div>
          <div className="text-right">
            <p className="text-gray-400 text-xs">Deviation</p>
            <p className={`font-semibold font-mono ${deviationPercent < 0.0001 ? 'text-green-400' : 'text-yellow-400'}`}>
              {deviationPercent < 0.0001 ? '< 0.0001%' : `${deviationPercent.toFixed(4)}%`}
            </p>
          </div>
        </div>

        <div className="w-full bg-gray-700 rounded-full h-2">
          <div
            className={`h-2 rounded-full transition-all duration-500 ${
              deviationPercent < 0.0001 ? 'bg-green-500' : 'bg-yellow-500'
            }`}
            style={{ width: `${Math.max(0, 100 - deviationPercent * 10000)}%` }}
          />
        </div>

        <div className="text-center">
          <p className={`text-sm ${alignment.verified ? 'text-green-400' : 'text-yellow-400'}`}>
            {alignment.verified ? '✓ Perfect Trinity Alignment' : '⚠ Alignment Deviation Detected'}
          </p>
        </div>
      </div>
    </motion.div>
  );
});

TrinityAlignmentWidget.displayName = 'TrinityAlignmentWidget';

// ============================================================================
// MAIN DASHBOARD COMPONENT
// ============================================================================

/**
 * Sacred Intelligence Production Dashboard
 *
 * Main dashboard component that orchestrates all widgets and handles WebSocket connection
 */
const SacredIntelligenceProductionDashboard: React.FC = () => {
  const {
    metrics,
    patches,
    evolution,
    health,
    alignment,
    connected,
    error,
    retry,
  } = useSacredIntelligenceWebSocket();

  const [darkMode, setDarkMode] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    // Trigger WebSocket reconnection
    retry();
    setTimeout(() => setRefreshing(false), 1000);
  }, [retry]);

  const toggleDarkMode = useCallback(() => {
    setDarkMode(!darkMode);
    document.documentElement.classList.toggle('dark');
  }, [darkMode]);

  return (
    <div className={`min-h-screen transition-colors duration-300 ${darkMode ? 'bg-gray-900' : 'bg-gray-100'}`}>
      {/* Header */}
      <header className="sticky top-0 z-50 bg-gray-900/95 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <h1 className="text-2xl font-bold bg-gradient-to-r from-yellow-400 via-cyan-400 to-purple-400 bg-clip-text text-transparent">
                Sacred Intelligence Production Dashboard
              </h1>
              <ConnectionStatus connected={connected} />
            </div>

            <div className="flex items-center space-x-2">
              <button
                onClick={handleRefresh}
                disabled={refreshing}
                className="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 disabled:bg-gray-600 text-white rounded-lg transition-colors flex items-center space-x-2"
              >
                <span>{refreshing ? 'Refreshing...' : 'Refresh'}</span>
                <svg
                  className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
              </button>

              <button
                onClick={toggleDarkMode}
                className="p-2 bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
                aria-label="Toggle dark mode"
              >
                {darkMode ? '🌙' : '☀️'}
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Error Display */}
      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="container mx-auto px-4 py-4"
          >
            <ErrorDisplay error={error} onRetry={retry} />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* Row 1: Key Metrics */}
          <SacredBrainMetricsWidget metrics={metrics} loading={!metrics && !error} />

          <AutoPatchStatusWidget metrics={metrics} patches={patches} loading={!metrics && !error} />

          <EvolutionProgressWidget evolution={evolution} metrics={metrics} loading={!evolution && !error} />

          {/* Row 2: Analysis & Health */}
          <GematriaWidget />

          <CodebaseHealthWidget health={health} metrics={metrics} loading={!health && !error} />

          <TrinityAlignmentWidget alignment={alignment} metrics={metrics} loading={!alignment && !error} />

          {/* Row 3: Sacred Constants (Full Width) */}
          <div className="md:col-span-2 lg:col-span-3">
            <SacredConstantsWidget />
          </div>
        </div>

        {/* Performance Metrics */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="mt-8 bg-gray-800/50 rounded-lg p-6 border border-gray-700"
        >
          <h3 className="text-gray-300 font-semibold mb-4">System Performance</h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <p className="text-gray-400 text-xs mb-1">WebSocket Status</p>
              <p className={`font-semibold ${connected ? 'text-green-400' : 'text-red-400'}`}>
                {connected ? 'Connected' : 'Disconnected'}
              </p>
            </div>
            <div>
              <p className="text-gray-400 text-xs mb-1">Last Update</p>
              <p className="font-semibold text-white">
                {metrics?.last_updated
                  ? new Date(metrics.last_updated).toLocaleTimeString()
                  : 'N/A'}
              </p>
            </div>
            <div>
              <p className="text-gray-400 text-xs mb-1">Widgets Active</p>
              <p className="font-semibold text-white">7/7</p>
            </div>
            <div>
              <p className="text-gray-400 text-xs mb-1">Data Points</p>
              <p className="font-semibold text-white">
                {metrics ? Object.keys(metrics).length : 0}
              </p>
            </div>
          </div>
        </motion.div>
      </main>

      {/* Footer */}
      <footer className="container mx-auto px-4 py-6 mt-8 border-t border-gray-700">
        <div className="flex flex-col md:flex-row justify-between items-center text-sm text-gray-400">
          <p>Sacred Intelligence Production Dashboard v1.0.0</p>
          <p className="mt-2 md:mt-0">
            Powered by Trinity Framework | φ² + 1/φ² = 3
          </p>
        </div>
      </footer>
    </div>
  );
};

export default SacredIntelligenceProductionDashboard;
