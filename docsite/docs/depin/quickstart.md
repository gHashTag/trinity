---
sidebar_label: 'Quick Start'
title: 'Run a Trinity Node'
description: 'Start earning $TRI in 5 minutes'
---

# Run a Trinity Node in 5 Minutes

This guide gets you from zero to earning $TRI as fast as possible.

## Prerequisites

You need **one** of the following:

| Method | Requirement |
|--------|-------------|
| Docker (recommended) | Docker 20.10+ |
| Build from source | Zig 0.15.x |

**Minimum hardware:**

- 2 CPU cores
- 4 GB RAM
- 20 GB free disk space
- Stable internet connection

## Option A: Docker (Recommended)

### 1. Pull and Run

```bash
docker run -d --name trinity-node \
  -p 8080:8080 -p 9090:9090 -p 9333:9333/udp -p 9334:9334 \
  -v ~/.trinity:/data \
  ghcr.io/ghashtag/trinity-node:latest
```

**Port breakdown:**

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | TCP | HTTP API (REST endpoints) |
| 9090 | TCP | Prometheus metrics |
| 9333 | UDP | Peer discovery |
| 9334 | TCP | Job distribution |

The `-v ~/.trinity:/data` flag persists your node data (wallet, shards, logs) across container restarts.

### 2. Check Logs

```bash
docker logs -f trinity-node
```

You should see:

```
[TRINITY] Node starting...
[TRINITY] Wallet: 0x1a2b3c4d...
[TRINITY] Discovering peers on UDP 9333...
[TRINITY] Found 3 peers
[TRINITY] Status: ONLINE
[TRINITY] HTTP API listening on :8080
[TRINITY] Prometheus metrics on :9090
[TRINITY] Ready to earn $TRI
```

### 3. Stop / Restart

```bash
docker stop trinity-node    # Stop
docker start trinity-node   # Restart (keeps data)
docker rm trinity-node      # Remove (data persists in ~/.trinity)
```

## Option B: Build from Source

### 1. Clone the Repository

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

### 2. Build the Node

```bash
zig build              # Build all targets
zig build tri          # Build the unified Trinity CLI
```

### 3. Start the Node

```bash
# Using the unified TRI CLI (recommended)
zig build tri

# Or run the built binary directly
./zig-out/bin/tri node start --port 8080 --data-dir ~/.trinity
```

### 4. Build for Production

For production deployments, use the release build for maximum performance:

```bash
zig build release      # Cross-platform release builds
```

This produces optimized binaries for:

- Linux x86\_64
- macOS x86\_64
- macOS ARM64 (Apple Silicon)
- Windows x86\_64

## Verify Your Node

### Check Health

```bash
curl http://localhost:8080/health
```

Expected response:

```json
{
  "status": "ok",
  "model": "loaded"
}
```

### Check Server Info

```bash
curl http://localhost:8080/
```

Expected response:

```json
{
  "name": "TRINITY LLM",
  "version": "1.4.0",
  "endpoints": ["/v1/chat/completions", "/health", "/metrics"],
  "metrics": {
    "total_requests": 0,
    "active_requests": 0,
    "total_tokens": 0,
    "throughput_tok_s": 0.00
  }
}
```

### Check Prometheus Metrics

```bash
curl http://localhost:9090/metrics
```

## Check Your Earnings

### View Wallet Balance

```bash
curl http://localhost:8080/v1/node/stats
```

Example response:

```json
{
  "status": "earning",
  "operations": 1247,
  "earned_tri": 3.892,
  "pending_tri": 0.045,
  "uptime_hours": 72.5,
  "wallet": "0x1a2b3c4d5e6f..."
}
```

### Claim Pending Rewards

```bash
curl -X POST http://localhost:8080/v1/node/claim
```

## What Happens Next

Once your node is online, it automatically:

1. **Discovers peers** via UDP broadcast on port 9333
2. **Accepts jobs** from the job dispatcher on port 9334
3. **Performs useful work** -- VSA operations, storage hosting, benchmarks
4. **Earns $TRI** for every completed operation
5. **Reports metrics** to Prometheus on port 9090

Your node will transition through these states:

```
OFFLINE -> SYNCING -> ONLINE -> EARNING
```

The **EARNING** state means your node has successfully completed at least one paid operation.

## Troubleshooting

### Node stays in SYNCING state

Ensure UDP port 9333 is open in your firewall:

```bash
# Linux
sudo ufw allow 9333/udp

# macOS (no firewall by default)
# Check System Preferences > Security & Privacy > Firewall
```

### Cannot reach the API

Verify the container is running and ports are mapped:

```bash
docker ps --filter name=trinity-node
```

### Low earnings

Ensure your node has:

- Sufficient bandwidth for storage operations
- Enough RAM for VSA operations (4 GB minimum)
- A stable connection (intermittent disconnects lose job assignments)

See [Reward Rates](./rewards.md) for strategies to maximize earnings.

## Next Steps

- [Reward Rates](./rewards.md) -- understand how earnings are calculated
- [Tokenomics](./tokenomics.md) -- learn about $TRI supply and staking
- [API Reference](./api.md) -- interact with your node programmatically
- [Architecture](./architecture.md) -- understand the network internals
