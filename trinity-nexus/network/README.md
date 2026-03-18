# trinity-network

**P2P Network Module** — DHT, sharding, consensus, distributed storage

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

`trinity-network` provides **decentralized P2P networking**:

- **DHT Routing** — Distributed hash table for content discovery
- **Sharding** — Automatic data partitioning and rebalancing
- **Consensus** — Reputation-based consensus algorithm
- **Distributed Transactions** — Cross-shard ACID transactions
- **Erasure Coding** — Reed-Solomon repair, auto-repair
- **Token Economics** — Staking, delegation, slashing
- **Storage** — Remote storage with VSA encoding

---

## Quick Start

```zig
const network = @import("trinity-network");

// Start a network node
var node = try network.main_node.init(allocator, .{
    .listen_addr = "0.0.0.0:8333",
    .bootstrap_nodes = &[_][]const u8{"bootstrap.trinity.network:8333"},
});
defer node.deinit(allocator);

try node.start();

// Put value to DHT
try node.dht.put(allocator, "my_key", "my_value");

// Get value from DHT
const value = try node.dht.get(allocator, "my_key");
```

---

## Module Structure

```
trinity-nexus/network/src/
├── root.zig                    # Module exports
│
├── Core P2P
├── network.zig                 # P2P network core
├── protocol.zig                # Network protocol
├── discovery.zig               # Peer discovery
├── connection_pool.zig         # Connection management
│
├── DHT
├── manifest_dht.zig            # DHT implementation
│
├── Sharding
├── shard_manager.zig           # Shard management
├── shard_rebalancer.zig        # Automatic rebalancing
├── shard_scrubber.zig          # Data scrubbing
├── auto_shard.zig              # Auto-sharding
├── vsa_shard_encoder.zig       # VSA-based encoding
├── vsa_shard_locks.zig         # Distributed locks
│
├── Consensus & Reputation
├── reputation_consensus.zig    # Reputation-based consensus
├── node_reputation.zig         # Node reputation tracking
│
├── Distributed Transactions
├── cross_shard_tx.zig          # Cross-shard transactions
├── parallel_saga.zig           # Saga pattern
├── saga_coordinator.zig        # Saga coordinator
├── transaction_wal.zig         # Write-ahead log
├── wal_disk.zig                # Disk WAL
│
├── Repair & Erasure Coding
├── auto_repair.zig             # Automatic repair
├── erasure_repair.zig          # Erasure coding repair
├── dynamic_erasure.zig         # Dynamic erasure
├── rs_repair.zig               # Reed-Solomon repair
├── reed_solomon.zig            # Reed-Solomon codec
├── galois.zig                  # Galois field arithmetic
├── repair_rate_limiter.zig     # Repair rate limiting
│
├── Routing & Topology
├── region_router.zig           # Region-based routing
├── region_topology.zig         # Topology management
├── peer_latency.zig            # Latency measurement
│
├── Storage
├── storage.zig                 # Storage interface
├── remote_storage.zig          # Remote storage client
├── storage_discovery.zig       # Storage node discovery
├── file_encoder.zig            # File encoding
│
├── Crypto & Token Economics
├── crypto.zig                  # Cryptographic primitives
├── wallet.zig                  # Wallet management
├── token_staking.zig           # Staking mechanism
├── stake_delegation.zig        # Stake delegation
├── slashing_escrow.zig         # Slashing escrow
├── incentive_slashing.zig      # Incentive slashing
├── proof_of_storage.zig        # Proof of storage
│
├── Monitoring & Metrics
├── network_stats.zig           # Network statistics
├── bandwidth_aggregator.zig    # Bandwidth tracking
├── prometheus_metrics.zig      # Prometheus metrics
├── prometheus_http.zig         # Prometheus HTTP server
├── metrics_http.zig            # Metrics HTTP endpoint
│
└── Node Entry & Config
├── main.zig                    # Node entry point
├── config.zig                  # Configuration
├── http_api.zig                # HTTP API
├── inference.zig               # Inference API
├── semantic_index.zig          # Semantic indexing
├── graceful_shutdown.zig       # Graceful shutdown
└── integration_test.zig        # Integration tests
```

---

## API Reference

### DHT Operations

```zig
pub const DHT = struct {
    pub fn put(
        self: *DHT,
        allocator: Allocator,
        key: []const u8,
        value: []const u8
    ) !void

    pub fn get(
        self: *DHT,
        allocator: Allocator,
        key: []const u8
    ) !?[]const u8

    pub fn remove(
        self: *DHT,
        key: []const u8
    ) !void
};
```

### Shard Manager

```zig
pub const ShardManager = struct {
    pub fn init(allocator: Allocator, config: Config) !ShardManager
    pub fn deinit(self: *ShardManager, allocator: Allocator) void

    pub fn getShardForKey(self: *ShardManager, key: []const u8) !Shard
    pub fn rebalance(self: *ShardManager) !void
    pub fn addNode(self: *ShardManager, node: NodeID) !void
    pub fn removeNode(self: *ShardManager, node: NodeID) !void
};
```

### Cross-Shard Transactions

```zig
pub const CrossShardTx = struct {
    pub fn begin(self: *CrossShardTx, shards: []ShardID) !Transaction
    pub fn commit(tx: *Transaction) !void
    pub fn rollback(tx: *Transaction) !void

    pub fn transfer(
        tx: *Transaction,
        from: ShardID,
        to: ShardID,
        amount: u64
    ) !void
};
```

### Erasure Coding

```zig
pub const ReedSolomon = struct {
    pub fn init(data_shards: u8, parity_shards: u8) ReedSolomon
    pub fn encode(
        self: *ReedSolomon,
        allocator: Allocator,
        data: []const u8
    ) ![][]const u8

    pub fn decode(
        self: *ReedSolomon,
        allocator: Allocator,
        shards: [][]const u8,
        shard_present: []bool
    ) ![]const u8
};
```

---

## Examples

### Basic DHT Usage

```zig
const network = @import("trinity-network");

var dht = try network.manifest_dht.init(allocator, .{
    .k = 16, // 16 replicas per key
});
defer dht.deinit(allocator);

// Store value
try dht.put(allocator, "user:alice", "127.0.0.1:8080");

// Retrieve value
const addr = try dht.get(allocator, "user:alice");
std.debug.print("Alice is at {s}\n", .{addr.?});
```

### Sharded Storage

```zig
const network = @import("trinity-network");

var shard_mgr = try network.shard_manager.init(allocator, .{
    .num_shards = 32,
    .replication_factor = 3,
});
defer shard_mgr.deinit(allocator);

// Get shard for a key
const shard = try shard_mgr.getShardForKey("my_document");

// Store data on specific shard
try shard.store(allocator, "my_document", document_data);
```

### Erasure Coding

```zig
const network = @import("trinity-network");

// Create 10 data shards + 4 parity shards (can lose any 4)
var rs = network.reed_solomon.ReedSolomon.init(10, 4);

const data = "Important data that needs redundancy";
const shards = try rs.encode(allocator, data);
defer {
    for (shards) |shard| allocator.free(shard);
    allocator.free(shards);
}

// shards[0..9] = data, shards[10..13] = parity
// Can reconstruct even if 4 shards are lost!
```

---

## Build & Test

```bash
# From workspace root
cd trinity-nexus

# Build network library
zig build trinity-network

# Run network tests
zig build test-network

# Run a network node
zig build trinity-network -- run --config config/node.toml
```

---

## Dependencies

- **trinity-core** — VSA operations, core types
- **trinity-symb** — Knowledge graphs, TVC

---

## Protocol

### Network Protocol

```
┌─────────────────────────────────────────────────────────────┐
│                    Trinity Network Protocol                 │
├─────────────────────────────────────────────────────────────┤
│  Version: 1.0                                              │
│  Transport: TCP                                            │
│  Serialization: MessagePack                                │
└─────────────────────────────────────────────────────────────┘

Message Types:
  - DHT_PUT      (0x01) — Store key-value
  - DHT_GET      (0x02) — Retrieve value
  - DHT_FIND     (0x03) — Find nodes for key
  - SHARD_MOVE   (0x10) — Move shard between nodes
  - TX_BEGIN     (0x20) — Begin transaction
  - TX_COMMIT    (0x21) — Commit transaction
  - REPAIR_REQ   (0x30) — Request repair
  - REPAIR_RESP  (0x31) — Repair response
```

---

## Performance

| Operation | Latency | Throughput |
|-----------|---------|------------|
| DHT put | ~50ms | 1000 ops/sec |
| DHT get | ~30ms | 2000 ops/sec |
| Cross-shard tx | ~200ms | 50 tx/sec |
| Erasure encode | O(n) | 100 MB/sec |
| Erasure decode | O(n²) | 50 MB/sec |

---

## Configuration

```toml
# config/node.toml
[network]
listen_addr = "0.0.0.0:8333"
bootstrap_nodes = ["bootstrap.trinity.network:8333"]

[dht]
k = 16
alpha = 3

[sharding]
num_shards = 32
replication_factor = 3
auto_rebalance = true

[repair]
enabled = true
interval_hours = 24

[metrics]
prometheus_port = 9090
```

---

## Version

```
trinity-network v0.6.0
```

---

**φ² + 1/phi² = 3**
