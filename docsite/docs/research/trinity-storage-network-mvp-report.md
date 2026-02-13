---
title: Trinity Storage Network MVP
sidebar_label: Storage Network MVP
---

# Trinity Storage Network MVP Report

Decentralized free storage: binary file -> ternary encode -> compress -> shard -> encrypt -> distribute across peers -> retrieve.

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Pipeline stages | 6 (encode -> pack -> RLE -> shard -> encrypt -> distribute) | Implemented |
| File encoder roundtrip | All 256 byte values verified | Pass |
| Protocol messages | 5 new types (0x20-0x24) | Implemented |
| Storage provider | In-memory shard store with hash verification | Pass |
| Shard manager | Full store/retrieve pipeline | Pass |
| Encryption | AES-256-GCM per-file | Pass |
| Wrong key rejection | Verified | Pass |
| Multi-peer distribution | Round-robin with replication | Pass |
| Total tests | 31 (all pass, zero memory leaks) | Pass |

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
  v
[Distribute] round-robin across peers with replication
  |
  v
[FileManifest] shard hashes + encryption params + metadata
```

## Files Created

| File | Purpose | Tests |
|------|---------|-------|
| `src/trinity_node/file_encoder.zig` | Binary-to-ternary encoder/decoder + trit packing | 7 tests |
| `src/trinity_node/storage.zig` | StorageProvider (in-memory shard store) + FileManifest | 7 tests |
| `src/trinity_node/shard_manager.zig` | Full pipeline orchestrator (store/retrieve) | 4 tests |

## Files Modified

| File | Changes |
|------|---------|
| `src/trinity_node/protocol.zig` | Added 5 message types (0x20-0x24): StoreRequest, StoreResponse, RetrieveRequest, RetrieveResponse, StorageAnnounce. 4 new tests. |
| `src/trinity_node/network.zig` | Added `storage_provider` field to NetworkNode, routing for store_request, retrieve_request, storage_announce in handleConnection |
| `src/trinity_node/main.zig` | Added `--storage` and `--storage-max-gb=N` CLI flags, StorageProvider initialization |
| `src/firebird/depin.zig` | Added `storage_hosting` and `storage_retrieval` operation types, reward constants (0.00005 TRI/shard/hour, 0.0005 TRI/retrieval) |
| `build.zig` | Added test targets for file_encoder, protocol, storage, shard_manager, crypto |

## Technical Details

### Binary-to-Ternary Encoding

Each byte (0-255) is converted to 6 balanced ternary trits {-1, 0, +1}:
- 3^6 = 729 > 256, so every byte value has a unique 6-trit representation
- Roundtrip verified for all 256 byte values
- Expansion factor: 6 trits / 5 trits_per_packed_byte = 1.2x

### Trit Packing

5 balanced trits pack into 1 byte (3^5 = 243 <= 255):
- Mathematical 5x compression for trit data
- Lossless, deterministic, O(n) time

### RLE Compression

Run-length encoding on packed bytes:
- Effective when packed bytes have repetition (sparse/structured data)
- Falls back to packed data when RLE doesn't reduce size

### Encryption

AES-256-GCM per file:
- Random 12-byte nonce per file
- 16-byte authentication tag
- Key held by file owner only
- Wrong key correctly rejected with `DecryptionFailed` error

### Sharding

Fixed-size shards (default 64 KB):
- SHA-256 hash per shard for integrity verification
- Round-robin distribution across peers
- Configurable replication factor (default 3)

### DePIN Rewards

| Operation | Reward |
|-----------|--------|
| Storage hosting | 0.00005 $TRI per shard per hour |
| Storage retrieval | 0.0005 $TRI per retrieval |

### Protocol Messages

| Type | Code | Format |
|------|------|--------|
| store_request | 0x20 | shard_hash + file_id + index + total + data |
| store_response | 0x21 | shard_hash + success + node_id (65 bytes) |
| retrieve_request | 0x22 | shard_hash + requester_id (64 bytes) |
| retrieve_response | 0x23 | shard_hash + found + data |
| storage_announce | 0x24 | node_id + available + total + count + timestamp (60 bytes) |

## Test Results

```
All 31 tests passed. Zero memory leaks.

file_encoder:  7/7  pass
storage:       7/7  pass
shard_manager: 4/4  pass
protocol:      7/7  pass (including 4 new storage tests)
crypto:       6/6   pass
```

### Pipeline Tests Verified

1. **Small file roundtrip**: "Hello, Trinity..." -> encode -> pack -> RLE -> encrypt -> shard -> distribute (3 peers) -> retrieve -> decrypt -> decompress -> unpack -> decode -> verify identical
2. **Binary data roundtrip**: All 256 byte values -> full pipeline -> verify identical
3. **Encryption verification**: Correct key decrypts, wrong key returns `DecryptionFailed`
4. **Multi-peer distribution**: Shards distributed across 2 peers with replication factor 2, both peers have shards

## CLI Usage

```bash
# Enable storage provider on a node
trinity-node --storage                     # 10 GB default
trinity-node --storage --storage-max-gb=50 # 50 GB
trinity-node --headless --storage          # Daemon mode with storage
```

## What This Means

### For Users
- Store files for free on the Trinity decentralized network
- Files are encrypted (only you have the key), sharded, and replicated
- Retrieve files from any peer that has your shards

### For Node Operators
- Earn $TRI by providing disk space
- 0.00005 $TRI per shard per hour of hosting
- 0.0005 $TRI per retrieval served

### For the Network
- Decentralized storage with no single point of failure
- Ternary-native compression for efficient storage of trit data
- Extensible protocol (5 new message types integrated with existing P2P infrastructure)

## Next Steps

1. **Disk persistence**: Currently in-memory only. Add filesystem-backed storage to `~/.trinity/storage/shards/`
2. **Peer discovery for storage**: Announce storage capacity via UDP discovery
3. **Manifest distribution**: Store manifests on-chain or via DHT
4. **Erasure coding**: Reed-Solomon for k-of-n shard recovery
5. **Bandwidth metering**: Track upload/download for fair reward distribution
6. **CLI commands**: `trinity store <file>`, `trinity retrieve <file_id>`
