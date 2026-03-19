---
title: Trinity Storage Network v1.3
sidebar_label: Storage Network v1.3
---

# Trinity Storage Network v1.3 — Remote Storage, Bandwidth Metering, Shard Pinning, HKDF

Build on v1.2 (CLI, LRU eviction, XOR parity, peer discovery) with 4 new features: remote peer storage distribution, bandwidth metering rewards, shard pinning, and HKDF key derivation.

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Remote shard distribution | TCP client for store/retrieve to network peers | Implemented |
| Replication factor | Default 2 remote copies per shard | Implemented |
| Best-effort distribution | Graceful fallback to local-only if no peers | Implemented |
| Remote shard retrieval | Fallback to remote peers when shard not found locally | Implemented |
| Local caching | Retrieved remote shards cached locally for future access | Implemented |
| Bandwidth metering | Track bytes uploaded/downloaded per node | Implemented |
| Upload reward | 0.05 TRI/GB uploaded | Implemented |
| Download reward | 0.03 TRI/GB downloaded | Implemented |
| Shard pinning | Mark shards as non-evictable by LRU | Implemented |
| Pin/unpin CLI | `--pin=<hash>`, `--unpin=<hash>` | Implemented |
| HKDF-SHA256 key derivation | Replace SHA256(password) with HKDF | Implemented |
| Backward compatibility | `--legacy-key` flag for v1.2 files | Implemented |
| remote_storage.zig tests | 4/4 pass | Pass |
| storage.zig tests | 34/34 pass (30 original + 4 new v1.3) | Pass |
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
[AES-256-GCM Encrypt] HKDF-SHA256 derived key, random nonce    <- NEW v1.3
  |
  v
[Shard] split into 64KB chunks
  |
  +---> [XOR Parity] XOR all shards -> parity shard
  |
  v
[Distribute] round-robin across local peers with replication
  |
  +---> [Remote Distribution] TCP store to remote peers          <- NEW v1.3
  |       |
  |       +---> [Bandwidth Metering] track bytes up/down         <- NEW v1.3
  |
  +---> [In-Memory Cache] fast retrieval
  |       |
  |       +---> [LRU Eviction] evict oldest when over limit
  |       |
  |       +---> [Shard Pinning] pinned shards skip eviction      <- NEW v1.3
  |
  +---> [Disk Persistence] ~/.trinity/storage/shards/{hash}.shard
         |
         +---> [Lazy Loading] loaded on-demand, cached in memory
  |
  v
[FileManifest] shard hashes + parity_hash + encryption params
  |
  +---> [Manifest Persistence] ~/.trinity/storage/manifests/{id}.manifest

[RemotePeerClient] TCP client for shard store/retrieve           <- NEW v1.3
  |
  +---> storeShard() — send shard data via StoreRequest
  +---> retrieveShard() — fetch shard via RetrieveRequest

[NetworkShardDistributor] orchestrates remote distribution       <- NEW v1.3
  |
  +---> distributeToRemotePeers() — replicate to N peers
  +---> retrieveFromRemotePeers() — fallback retrieval
  +---> Records bandwidth via RewardTracker
```

## What Changed from v1.2

| Component | v1.2 (CLI + Parity + LRU + Discovery) | v1.3 (Remote + Bandwidth + Pinning + HKDF) |
|-----------|---------------------------------------|---------------------------------------------|
| Key derivation | SHA256(password) | HKDF-SHA256 (salt + extract + expand) |
| Shard distribution | Local peers only | Local + remote TCP distribution |
| Shard retrieval | Local only | Local with remote fallback |
| Reward model | Storage + uptime only | Storage + uptime + bandwidth metering |
| LRU eviction | Evicts any shard | Skips pinned shards |
| CLI | store, retrieve, storage | + --remote, --pin, --unpin, --bandwidth, --legacy-key |

## Files Created

| File | Purpose |
|------|---------|
| `specs/tri/storage_network_v1_3.vibee` | VIBEE spec (source of truth) |
| `src/trinity_node/remote_storage.zig` | RemotePeerClient + NetworkShardDistributor |

## Files Modified

| File | Changes |
|------|---------|
| `src/trinity_node/storage.zig` | Shard pinning (`pinned_shards` HashMap, `pinShard()`, `unpinShard()`, `isShardPinned()`, `getPinnedShardCount()`, eviction skip), bandwidth metering in RewardTracker (`bytes_uploaded`, `bytes_downloaded`, `recordUpload()`, `recordDownload()`, `calculateBandwidthRewardWei()`), 4 new tests |
| `src/trinity_node/shard_manager.zig` | `remote_distributor` field, `initWithRemote()`, remote distribution in `storeFile()`, remote fallback in `findShard()` |
| `src/trinity_node/main.zig` | HKDF key derivation (`deriveEncryptionKeyHkdf()`), `getEncryptionKey()` with legacy flag, CLI args `--remote`, `--pin=`, `--unpin=`, `--bandwidth`, `--legacy-key`, bandwidth stats display, 2 HKDF tests |
| `src/trinity_node/network.zig` | `remote_storage` import, `remote_distributor` field wired into NetworkNode |
| `build.zig` | Test target for `remote_storage.zig` |

## Technical Details

### HKDF-SHA256 Key Derivation

Replaces raw SHA256(password) with a proper key derivation function:

```zig
fn deriveEncryptionKeyHkdf(password: []const u8) [32]u8 {
    const HkdfSha256 = std.crypto.hkdf.HkdfSha256;
    // Extract: salt + password -> PRK (pseudo-random key)
    const prk = HkdfSha256.extract("trinity-storage-v1.3", password);
    // Expand: PRK + info -> 32-byte encryption key
    var key: [32]u8 = undefined;
    HkdfSha256.expand(&key, "file-encryption-key", prk);
    return key;
}
```

Key properties:
- **Deterministic**: Same password always produces same key
- **Domain separation**: Salt (`trinity-storage-v1.3`) and info (`file-encryption-key`) prevent cross-protocol attacks
- **Backward compatible**: `--legacy-key` flag uses old SHA256(password) for v1.2 files
- **Uses Zig stdlib**: `std.crypto.hkdf.HkdfSha256` — no external dependencies

### Remote Peer Storage

TCP client for distributing and retrieving shards across the network:

```zig
pub const RemotePeerClient = struct {
    allocator: std.mem.Allocator,
    address: std.net.Address,
    timeout_ns: u64 = 5_000_000_000,

    pub fn storeShard(self, shard_hash, data, local_node_id) !void
    pub fn retrieveShard(self, shard_hash, local_node_id) ![]const u8
};
```

Protocol flow:
1. **Store**: Build `StoreRequest` -> serialize -> send `MessageHeader` + payload -> read `StoreResponse`
2. **Retrieve**: Build `RetrieveRequest` -> serialize -> send `MessageHeader` + payload -> read full response with streaming -> parse `RetrieveResponse`

Design decisions:
- **New TCP connection per operation** — simple, reliable. Connection pooling deferred to v1.4
- **Best-effort distribution** — if no peers available, shards stored locally only (not an error)
- **Replication factor = 2** — each shard sent to up to 2 remote peers + local storage

### Network Shard Distributor

Orchestrates remote shard distribution with peer selection:

```zig
pub const NetworkShardDistributor = struct {
    allocator: std.mem.Allocator,
    peer_registry: *StoragePeerRegistry,
    local_storage: *StorageProvider,
    reward_tracker: ?*RewardTracker,
    local_node_id: [32]u8,
    replication_factor: u32 = 2,

    pub fn distributeToRemotePeers(self, shard_hash, data) !u32
    pub fn retrieveFromRemotePeers(self, shard_hash) ![]const u8
};
```

Distribution logic:
1. Query `StoragePeerRegistry.findPeersWithCapacity()` for peers with enough space
2. Skip self (by `node_id` comparison)
3. Send shard to up to `replication_factor` peers
4. Record bandwidth via `RewardTracker.recordUpload()`
5. Return count of successful remote copies

Retrieval logic:
1. Query all known peers
2. Try each peer's `retrieveShard()` until one succeeds
3. Record download bandwidth
4. Cache retrieved shard locally for future access

### Shard Pinning

Pinned shards are protected from LRU eviction:

```zig
// In StorageProvider:
pinned_shards: std.AutoHashMap([32]u8, bool),

pub fn pinShard(self, hash) void     // Mark as non-evictable
pub fn unpinShard(self, hash) void   // Allow eviction again
pub fn isShardPinned(self, hash) bool

// In evictLruIfNeeded():
if (self.pinned_shards.contains(key.*)) continue;  // Skip pinned
```

Properties:
- Pinned shards remain in memory indefinitely
- If all shards are pinned and memory is over limit, eviction stops (no infinite loop)
- Pin state is independent of shard data — can pin/unpin without touching shard content
- CLI: `--pin=<hex_hash>`, `--unpin=<hex_hash>`

### Bandwidth Metering

Nodes earn rewards for serving the network:

```zig
// In RewardTracker:
bytes_uploaded: u64 = 0,
bytes_downloaded: u64 = 0,

const REWARD_PER_GB_UPLOAD: u128 = 50_000_000_000_000_000;   // 0.05 TRI/GB
const REWARD_PER_GB_DOWNLOAD: u128 = 30_000_000_000_000_000; // 0.03 TRI/GB

pub fn recordUpload(self, bytes) void
pub fn recordDownload(self, bytes) void
pub fn calculateBandwidthRewardWei(self) u128
```

Reward formula:
```
bandwidth_reward = (bytes_uploaded * 0.05 TRI/GB) + (bytes_downloaded * 0.03 TRI/GB)
total_reward = storage_reward + uptime_reward + bandwidth_reward
```

Properties:
- Upload rewarded more than download (incentivizes serving data to the network)
- Metering is local-only — each node tracks its own bytes
- Network-wide aggregation deferred to v1.4

## Test Results

```
storage.zig:         34/34 pass (4 new v1.3 tests)
remote_storage.zig:   4/4 pass (all new)
shard_manager.zig:   46/46 pass (unchanged)
Full suite (zig build test): ALL PASS, zero memory leaks

New v1.3 tests:
  Shard Pinning:
    + pinned shard not evicted by LRU
    + unpin allows eviction

  Bandwidth Metering:
    + bandwidth metering tracks bytes
    + bandwidth reward calculation

  Remote Storage:
    + RemotePeerClient struct creation
    + NetworkShardDistributor with empty registry returns 0
    + NetworkShardDistributor records bandwidth on tracker
    + NetworkShardDistributor retrieve from empty registry fails

  HKDF Key Derivation:
    + HKDF key derivation is deterministic
    + HKDF differs from SHA256
```

## CLI Extensions

```bash
# Store with remote distribution
trinity-node --store=photo.jpg --password=mykey --remote

# Retrieve (falls back to remote peers if not found locally)
trinity-node --retrieve=abc123... --password=mykey

# Retrieve v1.2 file (backward compatibility)
trinity-node --retrieve=abc123... --password=mykey --legacy-key

# Pin a shard (prevent LRU eviction)
trinity-node --storage --pin=abc123...

# Unpin a shard
trinity-node --storage --unpin=abc123...

# Show bandwidth stats
trinity-node --storage --bandwidth
```

## What This Means

### For Users
- **Remote storage**: Files are distributed across the network, not just stored locally
- **Better security**: HKDF key derivation is significantly stronger than raw SHA256
- **Backward compatibility**: Old files encrypted with v1.2 still retrievable with `--legacy-key`
- **Shard pinning**: Critical data can be marked as non-evictable

### For Node Operators
- **Bandwidth rewards**: Earn TRI for serving shards to the network (0.05 TRI/GB upload, 0.03 TRI/GB download)
- **Shard pinning**: Control which data stays in memory on resource-constrained machines
- **Remote fallback**: Even if local data is evicted, it can be retrieved from remote peers

### For the Network
- **True distributed storage**: Shards now live on multiple nodes (replication factor 2)
- **Incentive alignment**: Bandwidth metering rewards nodes that actively serve the network
- **Resilience**: Remote retrieval means shard loss on one node doesn't mean data loss
- **Security upgrade**: HKDF is industry-standard key derivation (RFC 5869)

## Next Steps

1. **Reed-Solomon erasure coding**: k-of-n shard recovery (replaces XOR parity limitations)
2. **Connection pooling**: Reuse TCP connections to remote peers (reduce overhead)
3. **Manifest DHT**: Distribute file manifests across the network
4. **Network-wide bandwidth aggregation**: Aggregate bandwidth metrics for global reward distribution
5. **Argon2 key derivation**: Memory-hard KDF for even stronger password protection
6. **Shard rebalancing**: Automatically redistribute shards when peers join/leave
