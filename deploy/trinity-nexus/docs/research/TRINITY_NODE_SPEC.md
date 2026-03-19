# Trinity Node - Technical Specification

## Overview

Trinity Node is a cross-platform application that enables users to contribute CPU compute to the Trinity Network for decentralized LLM inference. Node operators earn $TRI tokens proportional to their compute contribution.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRINITY NODE ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    USER INTERFACE                         │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │  │
│  │  │Dashboard│ │Settings │ │ Wallet  │ │  Logs   │         │  │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘         │  │
│  └───────┼──────────┼──────────┼──────────┼─────────────────┘  │
│          │          │          │          │                     │
│  ┌───────┴──────────┴──────────┴──────────┴─────────────────┐  │
│  │                    NODE CORE                              │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │  │
│  │  │   Inference  │  │   Network    │  │   Compute    │    │  │
│  │  │    Engine    │  │    Client    │  │   Metering   │    │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │  │
│  │         │                 │                 │             │  │
│  │  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐    │  │
│  │  │   Wallet     │  │   Config     │  │   Health     │    │  │
│  │  │   Manager    │  │   Store      │  │   Monitor    │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    NATIVE LAYER                           │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐            │  │
│  │  │libtrinityv │ │   libp2p   │ │   SQLite   │            │  │
│  │  │    sa      │ │            │ │            │            │  │
│  │  └────────────┘ └────────────┘ └────────────┘            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Inference Engine

Processes LLM inference requests using ternary-quantized models.

**Responsibilities:**
- Load and manage BitNet/Trinity models (7B, 13B, 70B)
- Execute inference using CPU-optimized ternary operations
- Detect and utilize SIMD capabilities (AVX2, AVX-512, NEON)
- Manage memory and batch processing

**Interface:**
```
InferenceEngine
├── load_model(model_id: string) → Result<void>
├── infer(request: InferenceRequest) → Result<InferenceResponse>
├── get_throughput() → float (tokens/sec)
├── get_loaded_models() → List<ModelInfo>
└── unload_model(model_id: string) → Result<void>
```

**Supported Models:**
| Model | Size | RAM Required | Status |
|-------|------|--------------|--------|
| BitNet-7B | 2.1 GB | 4 GB | Available |
| BitNet-13B | 4.8 GB | 8 GB | Available |
| BitNet-70B | 14 GB | 24 GB | Coming Q3 2025 |

### 2. Network Client

Handles communication with Trinity Network coordinators and peers.

**Responsibilities:**
- Connect to Trinity Network via libp2p
- Register node capabilities with scheduler
- Receive inference jobs from job queue
- Submit completed results
- Send periodic heartbeats

**Interface:**
```
NetworkClient
├── connect(network: NetworkConfig) → Result<void>
├── register_node(capabilities: NodeCapabilities) → Result<NodeId>
├── receive_job() → Result<InferenceJob>
├── submit_result(job_id: string, result: InferenceResult) → Result<void>
├── heartbeat(stats: NodeStats) → Result<void>
└── disconnect() → Result<void>
```

**Protocol:**
- Transport: libp2p with QUIC/TCP
- Discovery: DHT + Bootstrap nodes
- Messaging: Protocol Buffers
- Encryption: TLS 1.3

### 3. Compute Metering

Tracks and reports compute contribution for $TRI rewards.

**Responsibilities:**
- Count processed tokens per job
- Track CPU time and resource usage
- Calculate contribution score
- Generate signed attestations

**Interface:**
```
ComputeMetering
├── start_job(job_id: string) → void
├── record_tokens(count: int) → void
├── end_job(job_id: string) → JobMetrics
├── get_session_stats() → SessionStats
└── generate_attestation() → SignedAttestation
```

**Metrics Tracked:**
| Metric | Description | Weight |
|--------|-------------|--------|
| tokens_processed | Total tokens generated | 1.0x |
| cpu_time_ms | CPU time consumed | 0.5x |
| latency_p50 | Median response latency | Bonus |
| uptime_percent | Node availability | Multiplier |

### 4. Wallet Manager

Manages $TRI wallet for receiving rewards.

**Responsibilities:**
- Generate or import wallet keypair
- Display $TRI balance
- Sign transactions
- Export/backup seed phrase

**Interface:**
```
WalletManager
├── create() → Result<Wallet>
├── from_mnemonic(phrase: string) → Result<Wallet>
├── get_address() → string
├── get_balance() → Result<Balance>
├── withdraw(to: string, amount: u64) → Result<TxHash>
└── export_mnemonic(password: string) → Result<EncryptedMnemonic>
```

### 5. Config Store

Persists node configuration and state.

**Responsibilities:**
- Store user preferences
- Cache network configuration
- Persist wallet (encrypted)
- Track historical earnings

**Storage:**
- Format: SQLite database
- Location: `~/.trinity-node/data.db`
- Encryption: AES-256 for sensitive data

### 6. Health Monitor

Monitors node health and system resources.

**Responsibilities:**
- Track CPU/RAM usage
- Monitor network connectivity
- Detect and report errors
- Auto-restart on failure

---

## Network Protocol

### Job Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFERENCE JOB FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐    ┌─────────────┐    ┌─────────────┐             │
│  │  User   │───▶│  Scheduler  │───▶│ Trinity Node│             │
│  │  (API)  │    │  (Network)  │    │  (Operator) │             │
│  └─────────┘    └─────────────┘    └─────────────┘             │
│       │               │                   │                     │
│       │  1. Request   │                   │                     │
│       │──────────────▶│                   │                     │
│       │               │  2. Assign Job    │                     │
│       │               │──────────────────▶│                     │
│       │               │                   │  3. Process         │
│       │               │                   │  (Inference)        │
│       │               │  4. Submit Result │                     │
│       │               │◀──────────────────│                     │
│       │  5. Response  │                   │                     │
│       │◀──────────────│                   │                     │
│       │               │  6. Record        │                     │
│       │               │  Contribution     │                     │
│       │               │──────────────────▶│                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Message Types

| Message | Direction | Description |
|---------|-----------|-------------|
| `NodeRegister` | Node → Scheduler | Register node capabilities |
| `NodeHeartbeat` | Node → Scheduler | Periodic status update |
| `JobAssign` | Scheduler → Node | Assign inference job |
| `JobResult` | Node → Scheduler | Submit completed result |
| `RewardNotify` | Scheduler → Node | Notify of $TRI reward |

### Job Assignment Algorithm

Scheduler selects nodes based on:
1. **Capability match** - Node has required model loaded
2. **Stake tier** - Higher stake = priority allocation
3. **Performance score** - Historical throughput/latency
4. **Geographic proximity** - Minimize network latency
5. **Current load** - Balance across available nodes

---

## Compute Contribution Model

### Reward Formula

```
reward = base_rate × tokens_processed × multipliers

Where:
  base_rate = 0.9 $TRI per 1M tokens (90% to node)
  
  multipliers:
    uptime_bonus = 1.0 + (uptime% - 95%) × 0.1  (max +10%)
    latency_bonus = 1.0 + (target_latency - actual) / target × 0.05  (max +5%)
    throughput_bonus = 1.0 + (actual - baseline) / baseline × 0.05  (max +5%)
```

### Staking Tiers

| Tier | Stake Required | Job Priority | APY Bonus |
|------|----------------|--------------|-----------|
| Bronze | 10,000 $TRI | Standard | 8% |
| Silver | 100,000 $TRI | +20% | 12% |
| Gold | 1,000,000 $TRI | +50% | 16% |
| Platinum | 10,000,000 $TRI | +100% | 20% |

### Slashing Conditions

| Violation | Penalty |
|-----------|---------|
| Invalid result | 1% of stake |
| Prolonged downtime (>24h) | 0.5% of stake |
| Malicious behavior | 100% of stake |

---

## System Requirements

### Minimum Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores, 2.0 GHz | 8+ cores, 3.0+ GHz |
| RAM | 8 GB | 16+ GB |
| Storage | 10 GB SSD | 50+ GB SSD |
| Network | 10 Mbps | 100+ Mbps |
| OS | Windows 10, macOS 12, Ubuntu 20.04 | Latest versions |

### CPU Feature Detection

Node automatically detects and utilizes:
- **AVX2** - 2x speedup (most modern CPUs)
- **AVX-512** - 4x speedup (Intel Xeon, AMD Zen 4)
- **ARM NEON** - 2x speedup (Apple Silicon, ARM servers)

---

## Security

### Wallet Security

- Private keys stored encrypted (AES-256-GCM)
- Seed phrase never transmitted
- Optional hardware wallet support (future)

### Network Security

- All connections TLS 1.3 encrypted
- Node identity via ed25519 keypair
- Job results signed for verification

### Data Privacy

- Inference inputs/outputs not logged
- Only aggregate metrics reported
- No PII collected

---

## API Endpoints

### Local REST API (for UI)

```
GET  /api/status          # Node status
GET  /api/stats           # Earnings and metrics
GET  /api/wallet/balance  # $TRI balance
POST /api/wallet/withdraw # Withdraw $TRI
GET  /api/config          # Current configuration
PUT  /api/config          # Update configuration
POST /api/node/start      # Start processing
POST /api/node/stop       # Stop processing
GET  /api/logs            # Recent logs
```

### Health Endpoint

```
GET /health
Response: {
  "status": "healthy|degraded|unhealthy",
  "uptime_seconds": 12345,
  "connected": true,
  "processing": true,
  "last_job_at": "2025-01-15T10:30:00Z"
}
```

---

## Configuration

### Config File Location

- Windows: `%APPDATA%\TrinityNode\config.toml`
- macOS: `~/Library/Application Support/TrinityNode/config.toml`
- Linux: `~/.config/trinity-node/config.toml`

### Config Schema

```toml
[node]
id = "auto"                    # Auto-generated or custom
name = "My Trinity Node"       # Display name

[resources]
cpu_limit_percent = 50         # Max CPU usage
ram_limit_mb = 8192            # Max RAM usage
active_hours_start = "09:00"   # Start time (local)
active_hours_end = "23:00"     # End time (local)
run_on_battery = false         # Laptop battery mode

[network]
profile = "mainnet"            # mainnet | testnet | devnet
bootstrap_nodes = []           # Custom bootstrap (optional)
upnp_enabled = true            # Auto port forwarding

[models]
enabled = ["bitnet-7b"]        # Models to serve
auto_download = true           # Download on demand

[wallet]
address = ""                   # Auto-created if empty

[startup]
auto_start = true              # Start with system
start_minimized = true         # Minimize to tray
```

---

## CLI Interface

For headless/server deployments:

```bash
# Installation
curl -sSL https://trinity.network/install.sh | bash

# Initialize node
trinity-node init --wallet <ADDRESS>

# Start node
trinity-node start

# Check status
trinity-node status

# View earnings
trinity-node earnings

# Stop node
trinity-node stop

# Export logs
trinity-node logs --export
```

### CLI Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize node configuration |
| `start` | Start node daemon |
| `stop` | Stop node daemon |
| `status` | Show current status |
| `earnings` | Show earnings summary |
| `withdraw` | Withdraw $TRI to address |
| `config` | View/edit configuration |
| `logs` | View or export logs |
| `update` | Update to latest version |

---

## Deployment Options

### Desktop App (Recommended)

- Tauri-based GUI application
- System tray integration
- Auto-updates

### CLI Daemon

- Headless operation
- Systemd/launchd integration
- Docker container available

### Docker

```bash
docker run -d \
  --name trinity-node \
  -v trinity-data:/data \
  -e WALLET_ADDRESS=<YOUR_ADDRESS> \
  trinitynetwork/node:latest
```

---

## Monitoring

### Metrics Exported

- Prometheus-compatible metrics at `/metrics`
- Grafana dashboard template provided

### Key Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `trinity_tokens_processed_total` | Counter | Total tokens processed |
| `trinity_jobs_completed_total` | Counter | Total jobs completed |
| `trinity_earnings_total` | Counter | Total $TRI earned |
| `trinity_throughput_tokens_per_sec` | Gauge | Current throughput |
| `trinity_cpu_usage_percent` | Gauge | CPU utilization |
| `trinity_connected` | Gauge | Network connection status |

---

## Error Handling

### Error Codes

| Code | Description | Action |
|------|-------------|--------|
| E001 | Network disconnected | Auto-reconnect |
| E002 | Model load failed | Check disk space |
| E003 | Inference timeout | Skip job, report |
| E004 | Wallet error | Check configuration |
| E005 | Resource exhausted | Reduce limits |

### Auto-Recovery

- Network: Exponential backoff reconnect
- Jobs: Timeout and skip after 60s
- Crashes: Auto-restart via service manager

---

## Versioning

- Semantic versioning (MAJOR.MINOR.PATCH)
- Auto-update with rollback capability
- Protocol version negotiation

---

## Open Questions

1. **Exact reward calculation** - Final formula pending tokenomics finalization
2. **DAO registration** - Process for node registration in governance
3. **API endpoints** - Final mainnet coordinator URLs
4. **Model distribution** - CDN/P2P model download mechanism
5. **Slashing implementation** - On-chain vs off-chain enforcement
6. **Hardware wallet** - Ledger/Trezor integration timeline

---

*Trinity Node - Your CPU, Your Earnings*
