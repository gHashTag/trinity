---
title: Trinity Storage Network v1.2
sidebar_label: Storage Network v1.2
---

# Trinity Storage Network v1.2 — CLI Commands, LRU Eviction, XOR Parity, Peer Discovery

Build on v1.1 (disk persistence, lazy loading, rewards) with 4 new features: CLI store/retrieve, LRU memory eviction, XOR parity fault tolerance, and storage peer discovery.

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| CLI `--store=<file>` | One-shot file store with manifest persistence | Implemented |
| CLI `--retrieve=<id>` | One-shot file retrieval with output to disk | Implemented |
| LRU eviction | Evict oldest shards from memory when over limit | Implemented |
| `max_memory_shards` config | Default 1000, configurable per node | Implemented |
| XOR parity | Single-shard fault tolerance via XOR parity | Implemented |
| Parity recovery | Recover 1 missing shard from parity + remaining | Implemented |
| FileManifest v1.2 | Backward-compatible: adds 32-byte `parity_hash` | Implemented |
| StoragePeerRegistry | Track peers with available storage capacity | Implemented |
| Peer discovery integration | Registry populated from StorageAnnounce messages | Implemented |
| Stale peer pruning | Auto-remove peers not seen in 60 seconds | Implemented |
| storage.zig tests | 30/30 pass (17 original + 4 new LRU) | Pass |
| shard_manager.zig tests | 46/46 pass (38 original + 4 new XOR + 4 transitive) | Pass |
| storage_discovery.zig tests | 10/10 pass (3 registry + 7 transitive) | Pass |
| Full suite | All tests pass, zero memory leaks | Pass |

## Architecture

```
USER FILE
  |
  v
[FileEncoder] binary -> 6 balanced trits/byte
  |
  v
[PackTrits] 5 trits -> 1 byte (5x compression)
  |
  v
[RLE Compress] run-length encoding on packed bytes
  |
  v
[AES-256-GCM Encrypt] per-file key, random nonce
  |
  v
[Shard] split into 64KB chunks
  |
  +---> [XOR Parity] XOR all shards -> parity shard              <- NEW v1.2
  |
  v
[Distribute] round-robin across peers with replication
  |
  +---> [In-Memory Cache] fast retrieval
  |       |
  |       +---> [LRU Eviction] evict oldest when over limit       <- NEW v1.2
  |
  +---> [Disk Persistence] ~/.trinity/storage/shards/{hash}.shard
         |
         +---> [Lazy Loading] loaded on-demand, cached in memory
  |
  v
[FileManifest] shard hashes + parity_hash + encryption params
  |
  +---> [Manifest Persistence] ~/.trinity/storage/manifests/{id}.manifest

[StoragePeerRegistry] tracks peers with available capacity          <- NEW v1.2
  |
  +---> Populated from StorageAnnounce messages
  +---> Auto-prune stale peers (60s timeout)
  +---> findPeersWithCapacity(min_bytes)
```

## What Changed from v1.1

| Component | v1.1 (Production) | v1.2 (CLI + Parity + LRU + Discovery) |
|-----------|-------------------|---------------------------------------|
| CLI | Daemon mode only | `--store=<file>`, `--retrieve=<id>`, `--output=<dir>` |
| Memory management | Unlimited growth | LRU eviction with `max_memory_shards` |
| Fault tolerance | None (shard lost = file lost) | XOR parity recovers 1 missing shard |
| FileManifest | 342-byte header | 374-byte header (+32 parity_hash, backward compat) |
| Peer tracking | Passive announce | StoragePeerRegistry with capacity search |
| Network poll | Prune dead peers | Also prune stale storage peers |

## Files Created

| File | Purpose |
|------|---------|
| `specs/tri/storage_network_v1_2.vibee` | VIBEE spec (source of truth) |
| `src/trinity_node/storage_discovery.zig` | StoragePeerRegistry — tracks peers with available storage |

## Files Modified

| File | Changes |
|------|---------|
| `src/trinity_node/storage.zig` | Added `max_memory_shards` config, `access_times` HashMap, `access_counter`, `touchShard()`, `evictLruIfNeeded()`, `getMemoryShardCount()`, `parity_hash` in FileManifest, `hasParity()`, backward-compatible serialize/deserialize, 4 new LRU tests |
| `src/trinity_node/shard_manager.zig` | Added `computeXorParity()`, `recoverFromParity()`, parity shard in `storeFile()`, parity recovery in `retrieveFile()`, 4 new XOR parity tests |
| `src/trinity_node/network.zig` | Added `storage_discovery` import, `storage_peer_registry` field, registry population from StorageAnnounce, stale prune in `poll()`, `findStoragePeers()` |
| `src/trinity_node/main.zig` | Added `--store=`, `--retrieve=`, `--output=` args, `runStoreFile()`, `runRetrieveFile()`, StoragePeerRegistry init, shard_manager import |
| `build.zig` | Added test target for `storage_discovery.zig` |

## Technical Details

### LRU Eviction

Shards in memory are tracked with a monotonically increasing access counter:

```zig
access_times: std.AutoHashMap([32]u8, u64),  // hash -> access counter
access_counter: u64,                          // monotonically increasing

fn touchShard(self, hash) {
    self.access_counter += 1;
    self.access_times.put(hash, self.access_counter);
}

fn evictLruIfNeeded(self) {
    while (shards.count() > max_memory_shards) {
        // Only evict if disk-backed (to avoid data loss)
        if (storage_dir == null) return;
        // Find shard with lowest access counter
        // Remove from memory, add to disk_index
    }
}
```

Key properties:
- Uses monotonic counter (not timestamps) for correct ordering in tight loops
- Only evicts shards that are persisted on disk
- Eviction is a no-op for in-memory-only storage (data would be lost)
- Default limit: 1000 shards in memory

### XOR Parity

Single-shard fault tolerance using XOR:

```
Parity = Shard[0] XOR Shard[1] XOR ... XOR Shard[N-1]

Recovery: Missing[i] = Parity XOR (all other shards)
```

Properties:
- Can recover exactly 1 missing shard
- Parity shard stored on peers like data shards (with replication)
- `parity_hash` stored in FileManifest (all zeros = no parity)
- Shards zero-padded to max length for XOR alignment
- Only computed when shard_count > 1

### FileManifest v1.2 — Backward Compatibility

```
v1.1 header: 342 bytes (no parity_hash)
v1.2 header: 374 bytes (+ 32-byte parity_hash)

Deserialize logic:
  if data.len >= 374 + shard_count*32 -> v1.2 (read parity_hash)
  if data.len >= 342 + shard_count*32 -> v1.1 (parity_hash = zeros)
  else -> error
```

### StoragePeerRegistry

Thread-safe registry of peers that provide storage:

```zig
pub const StoragePeerInfo = struct {
    node_id: [32]u8,
    available_bytes: u64,
    total_bytes: u64,
    shard_count: u32,
    last_seen: i64,
    address: ?std.net.Address,
};

pub const StoragePeerRegistry = struct {
    peers: HashMap,
    mutex: Mutex,

    fn updateFromAnnounce(announce, addr)  // insert/update peer
    fn findPeersWithCapacity(min_bytes)    // query by capacity
    fn pruneStale()                         // remove peers not seen in 60s
    fn getPeerCount()                       // total tracked peers
};
```

### CLI Store/Retrieve

One-shot operations that exit immediately (not daemon mode):

```bash
# Store a file
trinity-node --store=photo.jpg --password=mykey
# Output: File ID: abc123... (64 hex chars)

# Retrieve a file
trinity-node --retrieve=abc123... --output=./recovered --password=mykey
# Output: File written to ./recovered/photo.jpg

# Encryption: SHA256(password) -> AES-256-GCM key
```

## Test Results

```
storage.zig:            30/30 pass (4 new LRU eviction tests)
shard_manager.zig:      46/46 pass (4 new XOR parity tests)
storage_discovery.zig:  10/10 pass (3 new registry tests)
Full suite (zig build test): ALL PASS, zero memory leaks

New v1.2 tests:
  LRU Eviction:
    + LRU eviction triggers when over limit
    + LRU evicts oldest accessed shard
    + evicted shard still retrievable from disk
    + LRU eviction skipped without disk storage

  XOR Parity:
    + XOR parity compute and recover
    + storeFile with parity produces non-zero parity hash
    + retrieveFile with 1 missing shard recovers via parity
    + retrieveFile with 2 missing shards fails

  Storage Discovery:
    + registry add and find peers
    + registry prune stale peers
    + registry update from announce
```

## What This Means

### For Users
- **CLI file management**: Store and retrieve files with simple commands
- **Fault tolerance**: 1 shard can go missing and your file is still recoverable
- **Low memory footprint**: LRU eviction keeps memory bounded even with millions of shards

### For Node Operators
- **Memory control**: `max_memory_shards` prevents OOM on resource-constrained machines
- **Peer discovery**: Know which peers have storage capacity for smart distribution
- **Resilient storage**: XOR parity means less data loss across the network

### For the Network
- **CLI is the first user-facing storage interface**
- **Parity foundation**: XOR parity is the first step toward full Reed-Solomon erasure coding
- **Peer registry enables intelligent shard placement** (capacity-aware distribution)

## Next Steps

1. **Reed-Solomon erasure coding**: k-of-n shard recovery (replaces XOR parity limitations)
2. **Proper key derivation**: Argon2/PBKDF2 instead of SHA256(password)
3. **Remote peer storage**: Distribute shards to network peers (not just local)
4. **Bandwidth metering**: Track upload/download for fair reward distribution
5. **Shard pinning**: Mark critical shards as non-evictable
6. **Manifest DHT**: Distribute manifests across network instead of local storage
