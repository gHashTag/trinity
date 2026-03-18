# TECHNOLOGY TREE v2.5 — SERVE SUPREMACY

## Architecture Overview

```
L1: CLI SUPREMACY ★ v2.5
├── tri serve (fully generated via CLI Command Pattern)
├── All flags working: --help, --port, --daemon, positional
└── 16 routes + daemon lifecycle verified

L6: UNIFIED API ★ v3.1
├── HTTP Server (TRINITY SERVE v3.1.0)
├── API Gateway (REST + GraphQL)
├── WebSocket support (/ws/pas)
└── Health endpoints (/health)

CODEGEN + STATE + FULL SERVE INTEGRATION
├── Golden Chain: .tri spec → tri gen → zig build → E2E → verdict
├── Single Source of Truth: trinity-nexus/output/lang/zig/full-serve-v1.zig
└── Zero manual edits to tri_commands.zig for serve functionality

DEPIN HARDWARE BOOTSTRAP ★ v1.0 (NEW)
├── UDP discovery (port 7999)
├── Multi-cluster support (3+ nodes)
├── Primary election via quorum
├── Cluster state gossip
└── Hardware node registration
```

## Node Types

| Role | Description | Port Range |
|------|-------------|------------|
| Primary | Cluster coordinator, state authority | 9001 |
| Secondary | Backup primary, handles failover | 9002-9010 |
| Worker | Compute nodes, task execution | 9011-9999 |

## Discovery Protocol

```
UDP Broadcast: 255.255.255.255:7999
Packet Format:
{
  "node_id": "<uuid>",
  "port": 9001,
  "role": "primary|secondary|worker",
  "capabilities": ["compute", "storage", "network"],
  "timestamp": 1709424000
}

Response:
{
  "node_id": "<responder_uuid>",
  "port": 9002,
  "role": "secondary",
  "cluster_epoch": 1,
  "primary": "<primary_node_id>"
}
```

## API Extensions (Hardware)

| Route | Method | Description |
|-------|--------|-------------|
| /cluster | GET | Get cluster state |
| /cluster/join | POST | Manual node join |
| /cluster/nodes | GET | List all nodes |
| /cluster/elect | POST | Trigger primary election |

## Build Commands

```bash
# Generate code from specs
zig build vibee -- gen specs/integration/full-serve-v1.tri
zig build vibee -- gen specs/integration/serve_full_hardware.tri
zig build vibee -- gen specs/serve/verification-v1.tri

# Build TRI binary
zig build tri

# Run tests
zig test trinity-nexus/output/lang/zig/verification-v1.zig

# E2E verification
./zig-out/bin/tri serve --help
./zig-out/bin/tri serve --daemon --port 8888
./zig-out/bin/tri serve --port 9001 &  # Start 3 nodes
./zig-out/bin/tri serve --port 9002 &
./zig-out/bin/tri serve --port 9003 &
```

## φ² + 1/φ² = 3 = TRINITY
