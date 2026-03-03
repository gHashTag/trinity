# TECHNOLOGY TREE v2.6 — HARDWARE TRANSCENDENCE

## Architecture Overview

```
ROOT: Zig 0.15.2 + Ternary VSA + ENFORCED GOLDEN CHAIN
│
├── L1: CLI SUPREMACY ★ v2.6
│   ├── tri serve (fully generated via CLI Command Pattern)
│   ├── All flags: --help, --port, --daemon, positional
│   └── 16 routes + daemon lifecycle + hardware bootstrap
│
├── L4: SWARM FEDERATION
│   ├── Persistent state via CRDT
│   ├── Multi-node consensus
│   └── Gossip-based state sync
│
├── L5: DEPIN HARDWARE + REAL NETWORKING ★ v2.0 (NEW)
│   ├── UDP 9333 discovery on real hardware
│   ├── Primary election + automatic failover
│   ├── Hardware node bootstrap (Raspberry/Mac/Linux)
│   ├── $TRI rewards calculator (live)
│   └── KPI: 3+ real nodes in cluster, $TRI auto-claimed
│
└── L6: UNIFIED API ★ v3.2
    ├── REST + GraphQL + gRPC + WebSocket
    ├── /hardware — Hardware info endpoint
    ├── /rewards — $TRI balance and claim
    └── /cluster — Multi-cluster status
```

## Hardware Platforms

| Platform | Architecture | CPU | Min RAM | Status |
|----------|--------------|-----|---------|--------|
| Raspberry Pi 4 | arm64 | 4 cores | 4GB | ✅ Tested |
| Raspberry Pi 5 | arm64 | 4 cores | 8GB | ✅ Supported |
| Apple M1/M2/M3 | arm64 | 8+ cores | 8GB+ | ✅ Native |
| Intel/AMD Linux | x86_64 | 4+ cores | 8GB+ | ✅ Supported |

## Node Roles

| Role | Multiplier | Responsibilities |
|------|------------|------------------|
| Primary | 1.5x | Cluster coordinator, state authority |
| Secondary | 1.2x | Backup primary, participates in quorum |
| Worker | 1.0x | Compute tasks, no voting rights |

## $TRI Rewards Formula

```
$TRI = (uptime_seconds × 0.001 × role_multiplier) + (contributions × 0.01)

Where:
- uptime_seconds: Time node has been online
- role_multiplier: 1.5 (primary), 1.2 (secondary), 1.0 (worker)
- contributions: Number of completed tasks/transactions
```

### Examples

| Uptime | Role | Contributions | $TRI Earned |
|--------|------|---------------|-------------|
| 1 hour | Worker | 0 | 3.6 |
| 1 hour | Secondary | 10 | 5.2 |
| 1 hour | Primary | 20 | 7.4 |
| 24 hours | Worker | 100 | 99.0 |

## Discovery Protocol

```
UDP Broadcast: 255.255.255.255:9333
Interval: 5 seconds

Packet Format:
{
  "type": "discovery",
  "node_id": "<uuid>",
  "platform": "raspberry_pi|macos|linux",
  "arch": "arm64|x86_64",
  "port": 9001,
  "role": "primary|secondary|worker",
  "capabilities": {
    "compute": true,
    "storage": true,
    "network": true,
    "gpu": false
  },
  "timestamp": 1709424000
}
```

## Hardware Bootstrap Sequence

```
1. HARDWARE PROBE
   ├─ Detect platform (Pi/Mac/Linux)
   ├─ Detect architecture (arm64/x86_64)
   ├─ Detect CPU cores and memory
   └─ Generate unique node_id

2. NETWORK BIND
   ├─ Bind HTTP port (default 9001-9999)
   ├─ Bind UDP discovery port 9333
   └─ Configure firewall rules

3. DISCOVERY PHASE
   ├─ Send UDP broadcast to 255.255.255.255:9333
   ├─ Listen for responses from other nodes
   └─ Build initial cluster member list

4. CLUSTER JOIN
   ├─ If first node: become PRIMARY
   ├─ If joining existing cluster: request role assignment
   ├─ Sync cluster state via gossip
   └─ Start earning $TRI rewards

5. OPERATIONAL LOOP
   ├─ Accept HTTP/API traffic
   ├─ Send discovery heartbeat every 5s
   ├─ Calculate rewards every 60s
   └─ Participate in primary election if needed
```

## API Endpoints (Hardware)

| Route | Method | Description |
|-------|--------|-------------|
| /hardware | GET | Get hardware info (platform, CPU, memory) |
| /rewards | GET | Get $TRI balance (earned, claimed, pending) |
| /rewards/claim | POST | Claim pending $TRI to wallet |
| /cluster/nodes | GET | List all cluster nodes with roles |
| /cluster/elect | POST | Trigger primary election |

## Build & Deploy

```bash
# Generate hardware specs
zig build vibee -- gen specs/hardware/deployment-v1.tri
zig build vibee -- gen specs/integration/serve_full_hardware_v2.tri

# Build TRI binary
zig build tri

# Cross-compile for Raspberry Pi (arm64)
zig build -Dtarget=aarch64-linux-musl tri

# Deploy to hardware
scp zig-out/bin/tri pi@192.168.1.10:~/
ssh pi@192.168.1.10 "./tri serve --port 9001 --daemon"
```

## φ² + 1/φ² = 3 = TRINITY
