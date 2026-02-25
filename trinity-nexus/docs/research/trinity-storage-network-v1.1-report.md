---
title: Trinity Storage Network v1.1
sidebar_label: Storage Network v1.1
---

# Trinity Storage Network v1.1 — Production Disk Persistence & Rewards

Upgrade from in-memory MVP to production: disk-backed shards, lazy loading, reward tracking, startup recovery, 5-node simulation.

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Disk persistence | Shards saved as `{hash_hex}.shard` files | Implemented |
| Lazy disk loading | Load shard from disk only on retrieve | Implemented |
| Startup recovery | Scan directory, rebuild index without loading data | Implemented |
| Manifest persistence | FileManifest serialize to `.manifest` files | Implemented |
| Reward tracker | $TRI earned from hosting + retrievals | Implemented |
| 5-node simulation | Full pipeline roundtrip across 5 disk-backed nodes | Pass |
| Storage stats in CLI | Shards, used/available bytes, retrievals, earned $TRI | Implemented |
| Periodic announce | broadcastStorageAnnounce every 60s to peers | Implemented |
| Total tests | 38 shard_manager + 26 storage (all pass, zero memory leaks) | Pass |

## Architecture

```
USER FILE
  │
  v
[FileEncoder] binary -> 6 balanced trits/byte
  │
  v
[PackTrits] 5 trits -> 1 byte (5x compression)
  │
  v
[RLE Compress] run-length encoding on packed bytes
  │
  v
[AES-256-GCM Encrypt] per-file key, random nonce
  │
  v
[Shard] split into 64KB chunks
  │
  v
[Distribute] round-robin across peers with replication
  │
  ├──> [In-Memory Cache] fast retrieval
  │
  └──> [Disk Persistence] ~/.trinity/storage/shards/{hash}.shard    ← NEW v1.1
       │
       └──> [Lazy Loading] loaded on-demand, cached in memory       ← NEW v1.1
  │
  v
[FileManifest] shard hashes + encryption params + metadata
  │
  └──> [Manifest Persistence] ~/.trinity/storage/manifests/{id}.manifest  ← NEW v1.1
```

## What Changed from v1.0

| Component | v1.0 (MVP) | v1.1 (Production) |
|-----------|------------|-------------------|
| Shard storage | In-memory only | In-memory cache + disk persistence |
| Recovery | None (data lost on restart) | Scan disk directory, rebuild index |
| Loading | Eager (all in memory) | Lazy (load from disk on retrieve) |
| Manifests | In-memory only | Persisted to `.manifest` files |
| Rewards | Constants defined | Full RewardTracker with math |
| Stats | Basic shard count | Shards, bytes, retrievals, earned $TRI |
| Announce | Passive | Active broadcast every 60s |
| Test nodes | 3 | 5 with disk persistence + restart simulation |

## Files Modified

| File | Changes |
|------|---------|
| `src/trinity_node/config.zig` | Added `DEFAULT_STORAGE_DIR`, `DEFAULT_SHARDS_DIR`, `DEFAULT_MANIFESTS_DIR`, path helpers `getStorageDir()`, `getShardsDir()`, `getManifestsDir()`, `ensureStorageDirectories()` |
| `src/trinity_node/storage.zig` | Added `storage_dir` to StorageConfig, `disk_index` HashMap, `RewardTracker` struct, `hashToHex()`/`hexToHash()`, `persistShardToDisk()`/`loadShardFromDisk()`, `loadFromDisk()` recovery, `persistManifest()`/`loadManifest()`, changed `retrieveShard` to mutable self for lazy loading, 6 new tests |
| `src/trinity_node/shard_manager.zig` | Changed `retrieveFile`/`findShard` peers from `[]*const` to `[]*` for lazy loading, added 5-node simulation test |
| `src/trinity_node/network.zig` | Added `broadcastStorageAnnounce()` method |
| `src/trinity_node/main.zig` | Added startup recovery (`loadFromDisk`), storage dir from config, periodic storage announce (60s), storage stats in dashboard |

## Files Created

| File | Purpose |
|------|---------|
| `specs/tri/storage_network_v1_1.vibee` | VIBEE spec (source of truth) |

## Technical Details

### Disk Persistence

Shards are stored as individual files with SHA-256 hex filenames:

```
~/.trinity/storage/
├── shards/
│   ├── a1b2c3d4...{64 hex chars}.shard
│   ├── e5f6a7b8...{64 hex chars}.shard
│   └── ...
└── manifests/
    ├── {file_id_hex}.manifest
    └── ...
```

- **Store**: After in-memory store, shard is also written to disk
- **Retrieve**: Check memory first → if miss, check disk_index → lazy load from disk → verify hash → cache in memory
- **Recovery**: On startup, scan `shards/` directory, parse hex filenames → populate `disk_index` (no data loaded)

### Lazy Loading

The `disk_index: HashMap([32]u8, bool)` tracks which shards exist on disk without loading them. When a shard is needed:

1. Check `shards` HashMap (in-memory cache) — O(1)
2. If miss, check `disk_index` — O(1)
3. If in disk_index, read file from disk, verify SHA-256, cache in memory
4. Remove from `disk_index`, now in `shards`

This means a node with 100K shards on disk uses ~3.2 MB for the index (32 bytes × 100K) instead of ~6.4 GB for all shard data.

### hashToHex / hexToHash

Filesystem-safe conversion between 32-byte hashes and 64-character hex strings:

```zig
pub fn hashToHex(hash: [32]u8) [64]u8 { ... }
pub fn hexToHash(hex: [64]u8) ?[32]u8 { ... }  // returns null on invalid hex
```

### Reward Tracker

```zig
pub const RewardTracker = struct {
    shards_hosted: u64,
    retrievals_served: u64,
    hosting_start: i64,

    const REWARD_SHARD_HOUR: u128 = 50_000_000_000_000;    // 0.00005 TRI
    const REWARD_RETRIEVAL: u128 = 500_000_000_000_000;     // 0.0005 TRI
};
```

Reward formula:
```
earned = (shards_hosted × hours × 0.00005) + (retrievals_served × 0.0005) $TRI
```

Example: 100 shards hosted for 24 hours + 50 retrievals = 0.12 + 0.025 = **0.145 $TRI/day**

### 5-Node Simulation Test

The test creates 5 disk-backed StorageProviders with temporary directories, stores a 2KB file with replication factor 3, verifies distribution, then simulates a full restart:

1. Create 5 providers with `/tmp/trinity_test_5node/node{0-4}/`
2. Store 2KB file → sharded into ~32+ shards → distributed across 5 nodes
3. Verify shards on disk, retrieve file, verify roundtrip
4. Create 5 **new** providers pointed at same directories
5. Call `loadFromDisk()` on each → rebuild indexes
6. Retrieve file from new providers → lazy disk load → verify roundtrip

## Test Results

```
storage.zig:       26/26 pass (13 original + 13 with transitive deps)
shard_manager.zig: 38/38 pass (5 original + 33 transitive deps)
All tests: zero memory leaks

New v1.1 tests:
  ✓ hashToHex and hexToHash roundtrip
  ✓ reward tracker calculation
  ✓ disk persistence - store and recover
  ✓ lazy disk loading
  ✓ manifest persist and load
  ✓ loadFromDisk recovery with multiple shards
  ✓ 5-node simulation with disk persistence
```

### DePIN Rewards

| Operation | Reward | Example |
|-----------|--------|---------|
| Storage hosting | 0.00005 $TRI/shard/hour | 100 shards × 24h = 0.12 $TRI/day |
| Storage retrieval | 0.0005 $TRI/retrieval | 50 retrievals = 0.025 $TRI |

## CLI Usage

```bash
# Enable disk-backed storage provider
trinity-node --storage                     # 10 GB default, persists to ~/.trinity/storage/
trinity-node --storage --storage-max-gb=50 # 50 GB
trinity-node --headless --storage          # Daemon mode with storage

# On restart, shards are automatically recovered from disk
# Stats shown every 10 seconds include storage metrics
```

## What This Means

### For Users
- Files persist across node restarts — no more data loss
- Decentralized storage that survives reboots
- Manifests saved for file recovery

### For Node Operators
- Earn $TRI passively by providing disk space
- Automatic startup recovery — just restart the node
- Lazy loading keeps memory usage low even with large storage

### For the Network
- Production-ready storage layer
- 5-node tested and verified
- Foundation for peer discovery of storage capacity (via broadcastStorageAnnounce)

## Next Steps

1. **Peer storage discovery**: Use broadcastStorageAnnounce to find nodes with available space
2. **Erasure coding**: Reed-Solomon for k-of-n shard recovery
3. **Bandwidth metering**: Track upload/download for fair reward distribution
4. **CLI commands**: `trinity store <file>`, `trinity retrieve <file_id>`
5. **Shard eviction**: LRU eviction from memory cache when max_bytes reached
6. **Manifest DHT**: Distribute manifests across network instead of local storage
