# DePIN Hardware Bootstrap — Protocol Specification

## Overview

Trinity DePIN (Decentralized Physical Infrastructure Network) enables hardware nodes to self-organize into a compute cluster via UDP discovery and gossip-based state synchronization.

## Bootstrap Sequence

```
1. NODE STARTUP
   ├─ Load config (port, role, discovery settings)
   ├─ Bind HTTP port (tri serve --port XXXX)
   └─ Bind UDP discovery port (default: 7999)

2. DISCOVERY PHASE
   ├─ Broadcast presence packet to 255.255.255.255:7999
   ├─ Listen for responses from other nodes
   └─ Build initial node list

3. CLUSTER FORMATION
   ├─ If first node: become PRIMARY
   ├─ If joining existing cluster: register as SECONDARY/WORKER
   └─ Sync cluster state via gossip

4. OPERATIONAL PHASE
   ├─ Accept HTTP/API traffic on bound port
   ├─ Respond to health checks (/cluster)
   ├─ Participate in primary election if needed
   └─ Gossip state changes every 30 seconds
```

## Configuration

```yaml
# tri-depin.yaml
node:
  id: "auto"  # Auto-generate UUID if "auto"
  host: "0.0.0.0"
  port: 9001
  role: "auto"  # auto | primary | secondary | worker

discovery:
  enabled: true
  port: 7999
  broadcast_interval: 5000  # ms
  response_timeout: 2000  # ms

cluster:
  quorum: 2  # Minimum nodes for election
  sync_interval: 30000  # ms
  election_timeout: 10000  # ms

api:
  routes:
    - /health
    - /cluster
    - /cluster/join
    - /cluster/nodes
```

## Node Roles

### Primary
- Cluster coordinator
- Maintains authoritative state
- Handles cluster membership changes
- Serves as state sync source

### Secondary
- Backup primary (automatic failover)
- Participates in quorum
- Syncs state from primary

### Worker
- Executes compute tasks
- Reports health to primary
- No voting rights

## Discovery Protocol

### Broadcast Packet
```json
{
  "type": "discovery",
  "node_id": "550e8400-e29b-41d4-a716-446655440000",
  "port": 9001,
  "role": "primary",
  "capabilities": ["compute", "storage"],
  "timestamp": 1709424000,
  "version": "1.0.0"
}
```

### Response Packet
```json
{
  "type": "announce",
  "node_id": "550e8400-e29b-41d4-a716-446655440001",
  "port": 9002,
  "role": "secondary",
  "cluster_id": "trinity-cluster-1",
  "epoch": 1,
  "primary": "550e8400-e29b-41d4-a716-446655440000",
  "nodes_count": 3
}
```

## Primary Election

1. Trigger: Primary timeout (no heartbeat for 30s)
2. Quorum check: Must have >= quorum nodes online
3. Selection: Highest node_id (lexicographic) becomes primary
4. Broadcast: New primary announces to all nodes
5. Confirmation: Nodes acknowledge new primary

## Health Check Response

```json
{
  "status": "ok",
  "node_id": "550e8400-e29b-41d4-a716-446655440000",
  "role": "primary",
  "cluster": {
    "id": "trinity-cluster-1",
    "epoch": 1,
    "nodes": 3,
    "primary": "550e8400-e29b-41d4-a716-446655440000",
    "quorum": 2
  },
  "uptime": 3600,
  "capabilities": ["compute", "storage"]
}
```

## φ² + 1/φ² = 3 = TRINITY

## Hardware Bootstrap Checklist

- [ ] Node config loaded
- [ ] HTTP server bound
- [ ] UDP discovery bound
- [ ] Initial broadcast sent
- [ ] Cluster state initialized
- [ ] Role assigned
- [ ] Health endpoint responding
- [ ] Ready for compute tasks
