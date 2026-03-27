// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY SHARD MANAGER - Full Store/Retrieve Pipeline Orchestrator
// Binary -> Ternary -> Compress -> Shard -> Encrypt -> Distribute -> Retrieve
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const crypto = @import("crypto.zig");
const protocol = @import("protocol.zig");
const storage_mod = @import("storage.zig");
const file_encoder = @import("file_encoder.zig");
const remote_storage = @import("remote_storage.zig");
const reed_solomon = @import("reed_solomon.zig");

const Trit = file_encoder.Trit;

const DecompressResult = struct {
    data: []u8,
    len: usize,
    needs_free: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// XOR PARITY — Fault Tolerance (v1.2)
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute XOR parity of all data shards.
/// All shards are padded to max_len with zeros for XOR.
/// Returns a newly allocated parity buffer.
pub fn computeXorParity(shards: []const []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (shards.len == 0) return error.EmptyShards;

    // Find max shard length
    var max_len: usize = 0;
    for (shards) |shard| {
        if (shard.len > max_len) max_len = shard.len;
    }

    const parity = try allocator.alloc(u8, max_len);
    @memset(parity, 0);

    for (shards) |shard| {
        for (shard, 0..) |byte, i| {
            parity[i] ^= byte;
        }
    }

    return parity;
}

/// Recover a missing shard from the remaining shards + parity.
/// `shards` contains null for the missing shard, non-null for present shards.
/// XOR parity with all present shards to recover the missing one.
pub fn recoverFromParity(
    shards: []const ?[]const u8,
    parity: []const u8,
    missing_idx: usize,
    allocator: std.mem.Allocator,
) ![]u8 {
    if (missing_idx >= shards.len) return error.InvalidIndex;
    if (shards[missing_idx] != null) return error.ShardNotMissing;

    // XOR parity with all present shards → recovers missing
    const recovered = try allocator.alloc(u8, parity.len);
    @memcpy(recovered, parity);

    for (shards, 0..) |maybe_shard, i| {
        if (i == missing_idx) continue;
        if (maybe_shard) |shard| {
            for (shard, 0..) |byte, j| {
                if (j < recovered.len) {
                    recovered[j] ^= byte;
                }
            }
        }
    }

    return recovered;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARD MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardManager = struct {
    allocator: std.mem.Allocator,
    config: storage_mod.StorageConfig,
    // v1.3: Optional remote distributor for network shard distribution
    remote_distributor: ?*remote_storage.NetworkShardDistributor = null,

    pub fn init(allocator: std.mem.Allocator, config: storage_mod.StorageConfig) ShardManager {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// v1.3: Init with remote distributor for network shard distribution
    pub fn initWithRemote(
        allocator: std.mem.Allocator,
        config: storage_mod.StorageConfig,
        distributor: *remote_storage.NetworkShardDistributor,
    ) ShardManager {
        return .{
            .allocator = allocator,
            .config = config,
            .remote_distributor = distributor,
        };
    }

    /// Full store pipeline: binary -> ternary -> pack -> shard -> encrypt -> distribute
    /// Returns a FileManifest describing the stored file.
    pub fn storeFile(
        self: *const ShardManager,
        file_data: []const u8,
        file_name: []const u8,
        encryption_key: [32]u8,
        peers: []*storage_mod.StorageProvider,
    ) !storage_mod.FileManifest {
        // 1. Compute file hash
        const file_id = crypto.sha256(file_data);

        // 2. Binary -> Ternary encoding
        const encoder = file_encoder.FileEncoder.init(self.allocator);
        const trits = try encoder.encodeBinaryToTernary(file_data);
        defer self.allocator.free(trits);

        // 3. Pack trits (5 trits -> 1 byte)
        const pack_size = (trits.len + 4) / 5;
        const pack_buf = try self.allocator.alloc(u8, pack_size);
        defer self.allocator.free(pack_buf);
        const actual_pack_len = file_encoder.packTrits(trits, pack_buf);

        // 4. RLE compression
        const rle_buf = try self.allocator.alloc(u8, actual_pack_len * 2);
        defer self.allocator.free(rle_buf);
        const compressed_data = blk: {
            const rle_len = rleEncode(pack_buf[0..actual_pack_len], rle_buf);
            if (rle_len) |len| {
                if (len < actual_pack_len) {
                    break :blk rle_buf[0..len];
                }
            }
            // RLE didn't help, use packed data
            break :blk pack_buf[0..actual_pack_len];
        };

        // 5. Encrypt entire compressed payload
        var nonce: [12]u8 = undefined;
        std.crypto.random.bytes(&nonce);
        const ciphertext = try self.allocator.alloc(u8, compressed_data.len);
        defer self.allocator.free(ciphertext);
        var tag: [16]u8 = undefined;
        std.crypto.aead.aes_gcm.Aes256Gcm.encrypt(ciphertext, &tag, compressed_data, "", nonce, encryption_key);

        // 6. Shard the encrypted data
        const shard_size: usize = self.config.shard_size;
        const shard_count: u32 = @intCast((ciphertext.len + shard_size - 1) / shard_size);

        const shard_hashes = try self.allocator.alloc([32]u8, shard_count);
        errdefer self.allocator.free(shard_hashes);

        // 7. Distribute shards to peers and collect shard data for parity
        const shard_slices = try self.allocator.alloc([]const u8, shard_count);
        defer self.allocator.free(shard_slices);

        for (0..shard_count) |si| {
            const start = si * shard_size;
            const end = @min(start + shard_size, ciphertext.len);
            const shard_data = ciphertext[start..end];
            const shard_hash = crypto.sha256(shard_data);
            shard_hashes[si] = shard_hash;
            shard_slices[si] = shard_data;

            // Distribute to peers (round-robin with replication)
            var stored_count: u8 = 0;
            for (0..peers.len) |pi| {
                const peer_idx = (si + pi) % peers.len;
                const ok = peers[peer_idx].storeShard(shard_hash, shard_data) catch false;

                if (ok) {
                    stored_count += 1;
                    if (stored_count >= self.config.replication_factor) break;
                }
            }
        }

        // 7b. v1.3: Distribute to remote peers if available
        if (self.remote_distributor) |distributor| {
            for (0..shard_count) |si| {
                _ = distributor.distributeToRemotePeers(shard_hashes[si], shard_slices[si]) catch 0;
            }
        }

        // 8. Compute XOR parity shard and store it
        var parity_hash: [32]u8 = [_]u8{0} ** 32;
        if (shard_count > 1) {
            const parity_data = try computeXorParity(shard_slices, self.allocator);
            defer self.allocator.free(parity_data);
            parity_hash = crypto.sha256(parity_data);

            // Distribute parity shard to peers (same replication)
            var stored_count: u8 = 0;
            for (0..peers.len) |pi| {
                const ok = peers[pi].storeShard(parity_hash, parity_data) catch false;
                if (ok) {
                    stored_count += 1;
                    if (stored_count >= self.config.replication_factor) break;
                }
            }
        }

        // 9. v1.4: Reed-Solomon erasure coding (if enabled and enough shards)
        var rs_data_shards: u32 = 0;
        var rs_parity_shards: u32 = 0;
        var rs_last_shard_len: u32 = 0;
        var final_shard_hashes = shard_hashes;

        if (shard_count >= 2 and self.config.rs_parity_ratio > 0) {
            // Calculate RS parity count
            const parity_count_f: f32 = @as(f32, @floatFromInt(shard_count)) * self.config.rs_parity_ratio;
            const rs_parity_count: u32 = @intCast(@max(1, @as(u32, @intFromFloat(@ceil(parity_count_f)))));

            // Record last shard length before padding
            const last_shard = shard_slices[shard_count - 1];
            rs_last_shard_len = @intCast(last_shard.len);

            // Pad last shard to shard_size if needed (RS requires equal-length shards)
            var padded_last: ?[]u8 = null;
            defer if (padded_last) |p| self.allocator.free(p);

            var rs_data_slices = try self.allocator.alloc([]const u8, shard_count);
            defer self.allocator.free(rs_data_slices);
            for (0..shard_count) |si| {
                if (si == shard_count - 1 and last_shard.len < shard_size) {
                    padded_last = try self.allocator.alloc(u8, shard_size);
                    @memset(padded_last.?, 0);
                    @memcpy(padded_last.?[0..last_shard.len], last_shard);
                    rs_data_slices[si] = padded_last.?;
                } else {
                    rs_data_slices[si] = shard_slices[si];
                }
            }

            // Allocate parity shard buffers
            const rs_parity_bufs = try self.allocator.alloc([]u8, rs_parity_count);
            defer {
                for (rs_parity_bufs) |buf| self.allocator.free(buf);
                self.allocator.free(rs_parity_bufs);
            }
            for (0..rs_parity_count) |pi| {
                rs_parity_bufs[pi] = try self.allocator.alloc(u8, shard_size);
            }

            // Encode
            const rs = reed_solomon.ReedSolomon.init(shard_count, rs_parity_count);
            rs.encode(rs_data_slices, rs_parity_bufs);

            // Hash and distribute RS parity shards
            const total_shards = shard_count + rs_parity_count;
            const all_hashes = try self.allocator.alloc([32]u8, total_shards);
            @memcpy(all_hashes[0..shard_count], shard_hashes);

            for (0..rs_parity_count) |pi| {
                const rs_hash = crypto.sha256(rs_parity_bufs[pi]);
                all_hashes[shard_count + pi] = rs_hash;

                // Distribute RS parity to peers
                var stored_count: u8 = 0;
                for (0..peers.len) |peer_i| {
                    const peer_idx = (pi + peer_i) % peers.len;
                    const ok = peers[peer_idx].storeShard(rs_hash, rs_parity_bufs[pi]) catch false;
                    if (ok) {
                        stored_count += 1;
                        if (stored_count >= self.config.replication_factor) break;
                    }
                }
            }

            // Free old shard_hashes, use new all_hashes
            self.allocator.free(shard_hashes);
            final_shard_hashes = all_hashes;

            rs_data_shards = shard_count;
            rs_parity_shards = rs_parity_count;
        }

        // 10. Build manifest
        var name_buf: [256]u8 = [_]u8{0} ** 256;
        const name_len: u16 = @intCast(@min(file_name.len, 256));
        @memcpy(name_buf[0..name_len], file_name[0..name_len]);

        const final_shard_count: u32 = if (rs_data_shards > 0) rs_data_shards + rs_parity_shards else shard_count;

        return storage_mod.FileManifest{
            .file_id = file_id,
            .file_name = name_buf,
            .file_name_len = name_len,
            .original_size = file_data.len,
            .shard_count = final_shard_count,
            .shard_size = @intCast(shard_size),
            .encryption_nonce = nonce,
            .encryption_tag = tag,
            .created_at = std.time.timestamp(),
            .parity_hash = parity_hash,
            .rs_data_shards = rs_data_shards,
            .rs_parity_shards = rs_parity_shards,
            .rs_last_shard_len = rs_last_shard_len,
            .shard_hashes = final_shard_hashes,
        };
    }

    /// Full retrieve pipeline: fetch shards -> reassemble -> decrypt -> unpack -> ternary-to-binary
    /// If exactly 1 shard is missing and parity is available, recovers via XOR parity.
    pub fn retrieveFile(
        self: *const ShardManager,
        manifest: *const storage_mod.FileManifest,
        encryption_key: [32]u8,
        peers: []*storage_mod.StorageProvider,
    ) ![]u8 {
        // Determine data shard count (RS or legacy)
        const data_shard_count: u32 = if (manifest.hasReedSolomon()) manifest.rs_data_shards else manifest.shard_count;

        // 1. Collect all shards (data + parity) from peers, track missing
        var missing_count: u32 = 0;
        var missing_idx: usize = 0;

        const found_shards = try self.allocator.alloc(?[]const u8, manifest.shard_count);
        defer self.allocator.free(found_shards);

        for (0..manifest.shard_count) |si| {
            if (self.findShard(manifest.shard_hashes[si], peers)) |shard| {
                found_shards[si] = shard;
            } else {
                found_shards[si] = null;
                missing_count += 1;
                missing_idx = si;
            }
        }

        // v1.4: Try RS recovery if enough shards present
        var rs_recovered_bufs: ?[][]u8 = null;
        defer if (rs_recovered_bufs) |bufs| {
            for (bufs) |buf| self.allocator.free(buf);
            self.allocator.free(bufs);
        };

        // Padded shards must live until reassembly (after RS decode block)
        var rs_padded_shards = std.ArrayListUnmanaged([]u8){};
        defer {
            for (rs_padded_shards.items) |p| self.allocator.free(p);
            rs_padded_shards.deinit(self.allocator);
        }

        if (manifest.hasReedSolomon() and missing_count > 0) {
            const present_count = manifest.shard_count - missing_count;
            const rs = reed_solomon.ReedSolomon.init(manifest.rs_data_shards, manifest.rs_parity_shards);

            if (rs.canRecover(present_count)) {
                // Collect missing indices
                var missing_indices = try self.allocator.alloc(u32, missing_count);
                defer self.allocator.free(missing_indices);
                var mi: u32 = 0;
                for (0..manifest.shard_count) |si| {
                    if (found_shards[si] == null) {
                        missing_indices[mi] = @intCast(si);
                        mi += 1;
                    }
                }

                // RS shard length = shard_size (all RS-encoded shards are padded to this)
                const rs_shard_len: usize = manifest.shard_size;

                for (0..manifest.shard_count) |si| {
                    if (found_shards[si]) |s| {
                        if (s.len < rs_shard_len) {
                            const padded = try self.allocator.alloc(u8, rs_shard_len);
                            @memset(padded, 0);
                            @memcpy(padded[0..s.len], s);
                            found_shards[si] = padded;
                            try rs_padded_shards.append(self.allocator, padded);
                        }
                    }
                }

                // Allocate recovery buffers
                rs_recovered_bufs = try self.allocator.alloc([]u8, missing_count);
                for (0..missing_count) |ri| {
                    rs_recovered_bufs.?[ri] = try self.allocator.alloc(u8, rs_shard_len);
                }

                rs.decode(found_shards, rs_shard_len, rs_recovered_bufs.?, missing_indices, self.allocator) catch {
                    // RS decode failed, fall through to XOR or error
                    for (rs_recovered_bufs.?) |buf| self.allocator.free(buf);
                    self.allocator.free(rs_recovered_bufs.?);
                    rs_recovered_bufs = null;
                };

                if (rs_recovered_bufs != null) {
                    // Place recovered shards
                    for (0..missing_count) |ri| {
                        found_shards[missing_indices[ri]] = rs_recovered_bufs.?[ri];
                    }
                    missing_count = 0;
                }
            }
        }

        // Legacy: Try XOR parity recovery if exactly 1 data shard missing (pre-v1.4 files)
        var xor_recovered_shard: ?[]u8 = null;
        defer if (xor_recovered_shard) |xrs| self.allocator.free(xrs);

        if (missing_count == 1 and manifest.hasParity() and !manifest.hasReedSolomon()) {
            if (self.findShard(manifest.parity_hash, peers)) |parity_data| {
                xor_recovered_shard = recoverFromParity(found_shards[0..data_shard_count], parity_data, missing_idx, self.allocator) catch null;
                if (xor_recovered_shard) |xrs| {
                    found_shards[missing_idx] = xrs;
                    missing_count = 0;
                }
            }
        }

        if (missing_count > 0) return error.ShardNotFound;

        // Reassemble ciphertext from data shards only
        var total_cipher_len: usize = 0;
        for (0..data_shard_count) |si| {
            const shard = found_shards[si].?;
            if (manifest.hasReedSolomon() and si == data_shard_count - 1 and manifest.rs_last_shard_len > 0) {
                total_cipher_len += manifest.rs_last_shard_len;
            } else {
                total_cipher_len += shard.len;
            }
        }

        const ciphertext = try self.allocator.alloc(u8, total_cipher_len);
        defer self.allocator.free(ciphertext);

        var offset: usize = 0;
        for (0..data_shard_count) |si| {
            const shard = found_shards[si].?;
            if (manifest.hasReedSolomon() and si == data_shard_count - 1 and manifest.rs_last_shard_len > 0) {
                // Trim last shard to original length (remove RS padding)
                const trim_len = manifest.rs_last_shard_len;
                @memcpy(ciphertext[offset..][0..trim_len], shard[0..trim_len]);
                offset += trim_len;
            } else {
                @memcpy(ciphertext[offset..][0..shard.len], shard);
                offset += shard.len;
            }
        }

        // 2. Decrypt
        const plaintext = try self.allocator.alloc(u8, ciphertext.len);
        defer self.allocator.free(plaintext);
        std.crypto.aead.aes_gcm.Aes256Gcm.decrypt(
            plaintext,
            ciphertext,
            manifest.encryption_tag,
            "",
            manifest.encryption_nonce,
            encryption_key,
        ) catch return error.DecryptionFailed;

        // 3. RLE decompress (try, if data was RLE-compressed)
        const decompressed: DecompressResult = blk: {
            const dec_buf = try self.allocator.alloc(u8, manifest.original_size * 2);
            errdefer self.allocator.free(dec_buf);
            if (rleDecode(plaintext, dec_buf)) |dec_len| {
                // Verify decoded packed size matches expected
                const expected_trit_count = manifest.original_size * file_encoder.TRITS_PER_BYTE;
                const expected_pack = (expected_trit_count + 4) / 5;
                if (dec_len == expected_pack) {
                    break :blk DecompressResult{ .data = dec_buf, .len = dec_len, .needs_free = true };
                }
            }
            self.allocator.free(dec_buf);
            // Not RLE-compressed, use plaintext directly
            break :blk DecompressResult{ .data = plaintext, .len = plaintext.len, .needs_free = false };
        };
        defer if (decompressed.needs_free) self.allocator.free(decompressed.data);

        // 4. Unpack trits
        const trit_count = manifest.original_size * file_encoder.TRITS_PER_BYTE;
        const trits = try self.allocator.alloc(Trit, trit_count);
        defer self.allocator.free(trits);
        file_encoder.unpackTrits(decompressed.data[0..decompressed.len], trits, trit_count);

        // 5. Ternary -> Binary
        const enc = file_encoder.FileEncoder.init(self.allocator);
        const result = try enc.decodeTernaryToBinary(trits);

        return result;
    }

    /// Find a shard across local peers, then try remote peers as fallback (v1.3)
    fn findShard(self: *const ShardManager, shard_hash: [32]u8, peers: []*storage_mod.StorageProvider) ?[]const u8 {
        // Check local peers first
        for (peers) |peer| {
            if (peer.retrieveShard(shard_hash)) |data| {
                return data;
            }
        }

        // v1.3: Try remote peers if available
        if (self.remote_distributor) |distributor| {
            const data = distributor.retrieveFromRemotePeers(shard_hash) catch return null;
            return data;
        }

        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RLE COMPRESSION (inline, same algorithm as bench_compression.zig)
// ═══════════════════════════════════════════════════════════════════════════════

fn rleEncode(input: []const u8, output: []u8) ?usize {
    if (input.len == 0) return 0;
    var oi: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const current = input[i];
        var count: u8 = 1;
        while (i + count < input.len and input[i + count] == current and count < 255) {
            count += 1;
        }
        if (oi + 2 > output.len) return null;
        output[oi] = count;
        output[oi + 1] = current;
        oi += 2;
        i += count;
    }
    return oi;
}

fn rleDecode(input: []const u8, output: []u8) ?usize {
    var oi: usize = 0;
    var i: usize = 0;
    while (i + 1 < input.len) {
        const count = input[i];
        const value = input[i + 1];
        for (0..count) |_| {
            if (oi >= output.len) return null;
            output[oi] = value;
            oi += 1;
        }
        i += 2;
    }
    return oi;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "full pipeline roundtrip - small file" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 256,
        .replication_factor = 1,
    };

    const sm = ShardManager.init(allocator, config);

    var peer1 = storage_mod.StorageProvider.init(allocator, config);
    defer peer1.deinit();
    var peer2 = storage_mod.StorageProvider.init(allocator, config);
    defer peer2.deinit();
    var peer3 = storage_mod.StorageProvider.init(allocator, config);
    defer peer3.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{ &peer1, &peer2, &peer3 };
    const key = [_]u8{0x42} ** 32;

    const file_data = "Hello, Trinity Decentralized Storage Network!";
    const manifest = try sm.storeFile(file_data, "hello.txt", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    try std.testing.expectEqual(@as(u64, file_data.len), manifest.original_size);
    try std.testing.expect(manifest.shard_count >= 1);
    try std.testing.expectEqualSlices(u8, "hello.txt", manifest.getFileName());

    var read_peers = [_]*storage_mod.StorageProvider{ &peer1, &peer2, &peer3 };
    const recovered = try sm.retrieveFile(&manifest, key, &read_peers);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, file_data, recovered);
}

test "full pipeline roundtrip - binary data" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 128,
        .replication_factor = 1,
    };

    const sm = ShardManager.init(allocator, config);

    var peer1 = storage_mod.StorageProvider.init(allocator, config);
    defer peer1.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{&peer1};
    const key = [_]u8{0xAA} ** 32;

    var file_data: [256]u8 = undefined;
    for (0..256) |i| file_data[i] = @intCast(i);

    const manifest = try sm.storeFile(&file_data, "binary.bin", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    var read_peers = [_]*storage_mod.StorageProvider{&peer1};
    const recovered = try sm.retrieveFile(&manifest, key, &read_peers);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, &file_data, recovered);
}

test "encryption verification - wrong key fails" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 65536,
        .replication_factor = 1,
    };

    const sm = ShardManager.init(allocator, config);

    var peer = storage_mod.StorageProvider.init(allocator, config);
    defer peer.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{&peer};
    const correct_key = [_]u8{0x42} ** 32;
    const wrong_key = [_]u8{0xFF} ** 32;

    const file_data = "Secret data that should be encrypted";
    const manifest = try sm.storeFile(file_data, "secret.txt", correct_key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    var read_peers = [_]*storage_mod.StorageProvider{&peer};
    const result = sm.retrieveFile(&manifest, wrong_key, &read_peers);
    try std.testing.expectError(error.DecryptionFailed, result);
}

test "shard distribution across peers" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 32,
        .replication_factor = 2,
    };

    const sm = ShardManager.init(allocator, config);

    var peer1 = storage_mod.StorageProvider.init(allocator, config);
    defer peer1.deinit();
    var peer2 = storage_mod.StorageProvider.init(allocator, config);
    defer peer2.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{ &peer1, &peer2 };
    const key = [_]u8{0x33} ** 32;

    const file_data = "Data distributed across multiple peers for redundancy!";
    const manifest = try sm.storeFile(file_data, "distributed.txt", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    try std.testing.expect(manifest.shard_count >= 2);
    try std.testing.expect(peer1.getStats().total_shards > 0);
    try std.testing.expect(peer2.getStats().total_shards > 0);
}

test "5-node simulation with disk persistence" {
    const allocator = std.testing.allocator;

    // Create 5 temp directories for 5 nodes
    const dirs = [_][]const u8{
        "/tmp/trinity_test_5node/node0",
        "/tmp/trinity_test_5node/node1",
        "/tmp/trinity_test_5node/node2",
        "/tmp/trinity_test_5node/node3",
        "/tmp/trinity_test_5node/node4",
    };

    // Clean up from previous run
    std.fs.cwd().deleteTree("/tmp/trinity_test_5node") catch |err| {
        std.log.debug("shard_manager: pre-test cleanup failed: {}", .{err});
    };
    for (dirs) |dir| {
        try std.fs.cwd().makePath(dir);
    }
    defer std.fs.cwd().deleteTree("/tmp/trinity_test_5node") catch |err| {
        std.log.debug("shard_manager: post-test cleanup failed: {}", .{err});
    };

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 64, // Small shards to distribute across 5 nodes
        .replication_factor = 3,
    };

    const sm = ShardManager.init(allocator, config);

    // Phase 1: Create 5 disk-backed providers, store a large file
    var peer0 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[0],
    });
    defer peer0.deinit();
    var peer1 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[1],
    });
    defer peer1.deinit();
    var peer2 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[2],
    });
    defer peer2.deinit();
    var peer3 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[3],
    });
    defer peer3.deinit();
    var peer4 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[4],
    });
    defer peer4.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{ &peer0, &peer1, &peer2, &peer3, &peer4 };
    const key = [_]u8{0x55} ** 32;

    // Create a 2KB+ file to generate many shards across 5 nodes
    var file_data: [2048]u8 = undefined;
    for (0..2048) |i| file_data[i] = @intCast(i % 256);

    const manifest = try sm.storeFile(&file_data, "big_5node.bin", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    // Verify file was sharded
    try std.testing.expect(manifest.shard_count >= 5);

    // Verify shards are distributed across peers (with replication=3, each shard on 3 nodes)
    var total_shards_across_nodes: u32 = 0;
    var nodes_with_shards: u32 = 0;
    const peers_arr = [_]*storage_mod.StorageProvider{ &peer0, &peer1, &peer2, &peer3, &peer4 };
    for (peers_arr) |p| {
        const s = p.getStats();
        total_shards_across_nodes += s.total_shards;
        if (s.total_shards > 0) nodes_with_shards += 1;
    }

    // With replication=3 and 5 nodes, shards should be on at least 3 nodes
    try std.testing.expect(nodes_with_shards >= 3);
    // Total stored shards should be >= shard_count * replication_factor
    // (or equal, since round-robin may not fill all replicas if fewer peers)
    try std.testing.expect(total_shards_across_nodes >= manifest.shard_count);

    // Phase 2: Retrieve from the same providers
    var read_peers = [_]*storage_mod.StorageProvider{ &peer0, &peer1, &peer2, &peer3, &peer4 };
    const recovered = try sm.retrieveFile(&manifest, key, &read_peers);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, &file_data, recovered);

    // Phase 3: Simulate restart — create 5 NEW providers, load from disk
    var new0 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[0],
    });
    defer new0.deinit();
    var new1 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[1],
    });
    defer new1.deinit();
    var new2 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[2],
    });
    defer new2.deinit();
    var new3 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[3],
    });
    defer new3.deinit();
    var new4 = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = config.max_bytes,
        .shard_size = config.shard_size,
        .replication_factor = config.replication_factor,
        .storage_dir = dirs[4],
    });
    defer new4.deinit();

    // Load from disk on all nodes
    _ = try new0.loadFromDisk();
    _ = try new1.loadFromDisk();
    _ = try new2.loadFromDisk();
    _ = try new3.loadFromDisk();
    _ = try new4.loadFromDisk();

    // Verify total recovered matches
    var total_recovered: u32 = 0;
    const new_peers_arr = [_]*storage_mod.StorageProvider{ &new0, &new1, &new2, &new3, &new4 };
    for (new_peers_arr) |p| {
        total_recovered += p.getStats().total_shards;
    }
    try std.testing.expect(total_recovered >= manifest.shard_count);

    // Phase 4: Retrieve from NEW providers (lazy disk load)
    var new_read_peers = [_]*storage_mod.StorageProvider{ &new0, &new1, &new2, &new3, &new4 };
    const recovered2 = try sm.retrieveFile(&manifest, key, &new_read_peers);
    defer allocator.free(recovered2);

    try std.testing.expectEqualSlices(u8, &file_data, recovered2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.2 TESTS - XOR Parity
// ═══════════════════════════════════════════════════════════════════════════════

test "XOR parity compute and recover" {
    const allocator = std.testing.allocator;

    // 4 shards of equal size
    const shard0 = [_]u8{ 0x10, 0x20, 0x30, 0x40 };
    const shard1 = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    const shard2 = [_]u8{ 0xFF, 0xEE, 0xDD, 0xCC };
    const shard3 = [_]u8{ 0xAA, 0xBB, 0x11, 0x22 };

    const shards = [_][]const u8{ &shard0, &shard1, &shard2, &shard3 };

    // Compute parity
    const parity = try computeXorParity(&shards, allocator);
    defer allocator.free(parity);

    try std.testing.expectEqual(@as(usize, 4), parity.len);

    // Verify: XOR of all shards + parity should be all zeros
    for (0..4) |i| {
        const xor = shard0[i] ^ shard1[i] ^ shard2[i] ^ shard3[i] ^ parity[i];
        try std.testing.expectEqual(@as(u8, 0), xor);
    }

    // Recover shard1 (index 1) using remaining shards + parity
    const maybe_shards = [_]?[]const u8{ &shard0, null, &shard2, &shard3 };
    const recovered = try recoverFromParity(&maybe_shards, parity, 1, allocator);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, &shard1, recovered[0..4]);
}

test "storeFile with parity produces non-zero parity hash" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 64, // Small shards to ensure multiple
        .replication_factor = 1,
        .rs_parity_ratio = 0, // Disable RS for legacy XOR parity test
    };

    const sm = ShardManager.init(allocator, config);

    var peer1 = storage_mod.StorageProvider.init(allocator, config);
    defer peer1.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{&peer1};
    const key = [_]u8{0x42} ** 32;

    // File large enough to produce multiple shards
    var file_data: [512]u8 = undefined;
    for (0..512) |i| file_data[i] = @intCast(i % 256);

    const manifest = try sm.storeFile(&file_data, "parity_test.bin", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    // Should have multiple shards
    try std.testing.expect(manifest.shard_count >= 2);

    // Parity hash should be non-zero
    try std.testing.expect(manifest.hasParity());

    // Normal retrieval should still work
    var read_peers = [_]*storage_mod.StorageProvider{&peer1};
    const recovered = try sm.retrieveFile(&manifest, key, &read_peers);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, &file_data, recovered);
}

test "retrieveFile with 1 missing shard recovers via parity" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0, // Disable RS for legacy XOR parity test
    };

    const sm = ShardManager.init(allocator, config);

    // Store across 2 peers so we can selectively remove from one
    var peer1 = storage_mod.StorageProvider.init(allocator, config);
    defer peer1.deinit();
    var peer2 = storage_mod.StorageProvider.init(allocator, config);
    defer peer2.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{ &peer1, &peer2 };
    const key = [_]u8{0x77} ** 32;

    var file_data: [512]u8 = undefined;
    for (0..512) |i| file_data[i] = @intCast(i % 256);

    const manifest = try sm.storeFile(&file_data, "recover_test.bin", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    try std.testing.expect(manifest.shard_count >= 2);
    try std.testing.expect(manifest.hasParity());

    // Delete the first data shard from all peers (free the data to avoid leak)
    const first_shard_hash = manifest.shard_hashes[0];
    if (peer1.shards.fetchRemove(first_shard_hash)) |kv| allocator.free(kv.value);
    if (peer2.shards.fetchRemove(first_shard_hash)) |kv| allocator.free(kv.value);

    // Retrieval should still work via parity recovery
    var read_peers = [_]*storage_mod.StorageProvider{ &peer1, &peer2 };
    const recovered = try sm.retrieveFile(&manifest, key, &read_peers);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, &file_data, recovered);
}

test "retrieveFile with 2 missing shards fails" {
    const allocator = std.testing.allocator;

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0, // Disable RS for legacy XOR parity test
    };

    const sm = ShardManager.init(allocator, config);

    var peer1 = storage_mod.StorageProvider.init(allocator, config);
    defer peer1.deinit();

    var store_peers = [_]*storage_mod.StorageProvider{&peer1};
    const key = [_]u8{0x88} ** 32;

    var file_data: [512]u8 = undefined;
    for (0..512) |i| file_data[i] = @intCast(i % 256);

    const manifest = try sm.storeFile(&file_data, "fail_test.bin", key, &store_peers);
    defer allocator.free(manifest.shard_hashes);

    try std.testing.expect(manifest.shard_count >= 2);

    // Delete 2 data shards (free the data to avoid leak)
    if (peer1.shards.fetchRemove(manifest.shard_hashes[0])) |kv| allocator.free(kv.value);
    if (peer1.shards.fetchRemove(manifest.shard_hashes[1])) |kv| allocator.free(kv.value);

    // Should fail — XOR parity can only recover 1 missing shard
    var read_peers = [_]*storage_mod.StorageProvider{&peer1};
    const result = sm.retrieveFile(&manifest, key, &read_peers);
    try std.testing.expectError(error.ShardNotFound, result);
}
