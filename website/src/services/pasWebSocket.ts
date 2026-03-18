// ═══════════════════════════════════════════════════════════════════════════════
// PAS WEBSOCKET CLIENT v8.21
// Real-time connection to Production Autonomy System (PAS) daemon
// φ² + 1/φ² = 3 | TRINITY IDENTITY
// ═══════════════════════════════════════════════════════════════════════════════

import { useState, useEffect } from 'react';

const WS_URL = 'ws://localhost:8080/ws/pas';

// ─── PAS WebSocket Message Types ───────────────────────────────────────────────

export type PasMessageType =
  | 'connected'      // Initial connection confirmation
  | 'status'         // PAS daemon status update
  | 'recommendation' // New PAS recommendation
  | 'progress'       // Task execution progress
  | 'alert'          // System alert (warning, error)
  | 'heartbeat';     // Keep-alive signal

export interface PasWsMessage {
  type: PasMessageType;
  timestamp: number;
  // Connected message
  endpoint?: string;
  message?: string;
  // Status message
  pas_active?: boolean;
  analyses?: number;
  energy?: number;
  berry_phase?: number;
  // Recommendation message
  id?: string;
  action?: string;
  priority?: number;
  rationale?: string;
  impact_estimate?: number;
  // Progress message
  task?: string;
  baseline?: number;
  pas?: number;
  attempts?: number;
  // Alert message
  level?: 'info' | 'warning' | 'error' | 'critical';
}

// ─── PAS WebSocket Client ───────────────────────────────────────────────────────

export interface PasWsCallbacks {
  onConnected?: (message: PasWsMessage) => void;
  onStatus?: (status: PasWsMessage) => void;
  onRecommendation?: (rec: PasWsMessage) => void;
  onProgress?: (progress: PasWsMessage) => void;
  onAlert?: (alert: PasWsMessage) => void;
  onError?: (error: Event | Error) => void;
  onDisconnected?: () => void;
}

export class PasWebSocketClient {
  private ws: WebSocket | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempts = 0;
  private readonly maxReconnectAttempts = 10;
  private readonly reconnectDelay = 2000; // 2 seconds
  private callbacks: PasWsCallbacks = {};
  private isManualClose = false;

  constructor(private url: string = WS_URL) {}

  /**
   * Connect to PAS WebSocket server
   */
  connect(callbacks: PasWsCallbacks): void {
    this.callbacks = callbacks;
    this.isManualClose = false;

    try {
      this.ws = new WebSocket(this.url);

      this.ws.onopen = () => {
        console.log('[PAS WS] Connected to', this.url);
        this.reconnectAttempts = 0;
      };

      this.ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data) as PasWsMessage;
          this.handleMessage(message);
        } catch (err) {
          console.error('[PAS WS] Failed to parse message:', err, event.data);
        }
      };

      this.ws.onerror = (error) => {
        console.error('[PAS WS] Error:', error);
        this.callbacks.onError?.(error);
      };

      this.ws.onclose = () => {
        console.log('[PAS WS] Disconnected');
        this.callbacks.onDisconnected?.();

        // Auto-reconnect if not manual close
        if (!this.isManualClose && this.reconnectAttempts < this.maxReconnectAttempts) {
          this.scheduleReconnect();
        }
      };
    } catch (err) {
      console.error('[PAS WS] Connection failed:', err);
      this.callbacks.onError?.(err as Error);
    }
  }

  /**
   * Disconnect from PAS WebSocket server
   */
  disconnect(): void {
    this.isManualClose = true;

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  /**
   * Send a message to PAS server (if needed for future bidirectional comms)
   */
  send(data: Record<string, unknown>): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    } else {
      console.warn('[PAS WS] Cannot send - not connected');
    }
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  /**
   * Handle incoming message based on type
   */
  private handleMessage(message: PasWsMessage): void {
    switch (message.type) {
      case 'connected':
        console.log('[PAS WS]', message.message);
        this.callbacks.onConnected?.(message);
        break;

      case 'status':
        this.callbacks.onStatus?.(message);
        break;

      case 'recommendation':
        console.log('[PAS WS] Recommendation:', message.action, '(priority:', message.priority, ')');
        this.callbacks.onRecommendation?.(message);
        break;

      case 'progress':
        this.callbacks.onProgress?.(message);
        break;

      case 'alert':
        console.log('[PAS WS] Alert', message.level, ':', message.message);
        this.callbacks.onAlert?.(message);
        break;

      default:
        console.warn('[PAS WS] Unknown message type:', message.type);
    }
  }

  /**
   * Schedule reconnection attempt
   */
  private scheduleReconnect(): void {
    this.reconnectAttempts++;

    const delay = this.reconnectDelay * Math.pow(1.5, this.reconnectAttempts - 1);
    console.log(`[PAS WS] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    this.reconnectTimer = setTimeout(() => {
      this.connect(this.callbacks);
    }, delay);
  }
}

// ─── Singleton Instance ─────────────────────────────────────────────────────────

let pasWsInstance: PasWebSocketClient | null = null;

/**
 * Get the singleton PAS WebSocket client instance
 */
export function getPasWebSocket(): PasWebSocketClient {
  if (!pasWsInstance) {
    pasWsInstance = new PasWebSocketClient();
  }
  return pasWsInstance;
}

/**
 * Connect the PAS WebSocket with callbacks
 */
export function connectPasWebSocket(callbacks: PasWsCallbacks): PasWebSocketClient {
  const client = getPasWebSocket();
  client.connect(callbacks);
  return client;
}

/**
 * Disconnect the PAS WebSocket
 */
export function disconnectPasWebSocket(): void {
  if (pasWsInstance) {
    pasWsInstance.disconnect();
  }
}

// ─── React Hook ─────────────────────────────────────────────────────────────────

/**
 * React hook for PAS WebSocket connection
 * Usage:
 *   const pasWs = usePasWebSocket({
 *     onRecommendation: (rec) => console.log('New recommendation:', rec),
 *     onStatus: (status) => console.log('Status:', status),
 *   });
 */
export function usePasWebSocket(callbacks: PasWsCallbacks, deps: unknown[] = []): PasWebSocketClient | null {
  const [client, setClient] = useState<PasWebSocketClient | null>(null);

  useEffect(() => {
    const pasClient = getPasWebSocket();
    pasClient.connect(callbacks);
    setClient(pasClient);

    return () => {
      pasClient.disconnect();
    };
  }, deps);

  return client;
}

// ─── Mock Data Generator (for testing without backend) ─────────────────────────

export function generateMockPasMessage(type: PasMessageType = 'status'): PasWsMessage {
  const base = {
    timestamp: Date.now(),
  };

  switch (type) {
    case 'connected':
      return {
        ...base,
        type: 'connected',
        endpoint: '/ws/pas',
        message: 'PAS WebSocket connected',
      };

    case 'status':
      return {
        ...base,
        type: 'status',
        pas_active: true,
        analyses: Math.floor(Math.random() * 100),
        energy: Math.random() * 1000,
        berry_phase: Math.random() * 2 * Math.PI,
      };

    case 'recommendation':
      const actions = ['increase_mu', 'decrease_mu', 'switch_fixtype', 'explore_random', 'maintain_current'];
      const action = actions[Math.floor(Math.random() * actions.length)];
      return {
        ...base,
        type: 'recommendation',
        id: crypto.randomUUID(),
        action,
        priority: Math.floor(Math.random() * 10),
        rationale: `Berry phase indicates ${action} would improve intelligence convergence`,
        impact_estimate: Math.random(),
      };

    case 'progress':
      return {
        ...base,
        type: 'progress',
        task: `CODEGEN-${Math.floor(Math.random() * 100)}`,
        baseline: Math.floor(Math.random() * 100),
        pas: Math.floor(Math.random() * 100),
        attempts: Math.floor(Math.random() * 10),
      };

    case 'alert':
      const levels: Array<'info' | 'warning' | 'error' | 'critical'> = ['info', 'warning', 'error', 'critical'];
      return {
        ...base,
        type: 'alert',
        level: levels[Math.floor(Math.random() * levels.length)],
        message: 'PAS daemon detected pattern convergence anomaly',
      };

    default:
      return { ...base, type: 'status' };
  }
}
