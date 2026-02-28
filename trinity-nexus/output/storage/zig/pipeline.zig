// ═══════════════════════════════════════════════════════════════════════════════
// pipeline v1.0.0 - Generated from .vibee specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Author: 
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// Custom imports from .vibee spec
const vsa = @import("vsa");

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[TRANSLATED]A[TRANSLATED]]
// ═══════════════════════════════════════════════════════════════════════════════

// [CYR:[TRANSLATED]]iny[EN] φ-to[EN]with[CYR:[TRANSLATED]y] (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[TRANSLATED]]
// ═══════════════════════════════════════════════════════════════════════════════

/// 
pub const PipelineConfig = struct {
    data_shards: i64,
    parity_shards: i64,
    block_size: i64,
    node_count: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[EN]A[TRANSLATED]] [CYR:[TRANSLATED]] WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit - ternary digit (-1, 0, +1)
pub const Trit = enum(i8) {
    negative = -1, // FALSE
    zero = 0,      // UNKNOWN
    positive = 1,  // TRUE

    pub fn trit_and(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_or(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    pub fn trit_xor(a: Trit, b: Trit) Trit {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        if (av == 0 or bv == 0) return .zero;
        if (av == bv) return .negative;
        return .positive;
    }
};

/// Check TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-and[CYR:[TRANSLATED]]fields[EN]andI
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// [EN]not[CYR:[TRANSLATED]]andI φ-with[EN]and[CYR:[TRANSLATED]]and
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR FUNCTIONS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════════════
// REED-SOLOMON ERASURE CODING — GF(2^8) Fault Tolerance
// Primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1 (0x11D)
// Vandermonde matrix encoding, Gaussian elimination decoding.
// ═══════════════════════════════════════════════════════════════════

pub const ReedSolomon = struct {
    data_shards: u8,
    total_shards: u8,

    pub fn init(k: u8, m: u8) ReedSolomon {
        return .{ .data_shards = k, .total_shards = k + m };
    }

    /// GF(2^8) multiply via Russian peasant algorithm
    pub fn gfMul(a_in: u8, b_in: u8) u8 {
        if (a_in == 0 or b_in == 0) return 0;
        var a: u16 = a_in;
        var b: u8 = b_in;
        var p: u8 = 0;
        var i: u8 = 0;
        while (i < 8) : (i += 1) {
            if (b & 1 != 0) p ^= @intCast(a & 0xFF);
            a <<= 1;
            if (a & 0x100 != 0) a ^= 0x11D;
            b >>= 1;
        }
        return p;
    }

    /// GF(2^8) exponentiation via repeated squaring
    pub fn gfPow(base: u8, exp: u8) u8 {
        if (exp == 0) return 1;
        if (base == 0) return 0;
        var result: u8 = 1;
        var b: u8 = base;
        var e: u8 = exp;
        while (e > 0) {
            if (e & 1 != 0) result = gfMul(result, b);
            b = gfMul(b, b);
            e >>= 1;
        }
        return result;
    }

    /// GF(2^8) inverse: a^(-1) = a^254 (Fermat's little theorem)
    pub fn gfInv(a: u8) u8 {
        if (a == 0) return 0;
        return gfPow(a, 254);
    }

    /// Encode one byte position: k input bytes → n coded bytes (Vandermonde)
    pub fn encodeByte(self: *const ReedSolomon, input: []const u8, output: []u8) void {
        var i: u8 = 0;
        while (i < self.total_shards) : (i += 1) {
            var val: u8 = 0;
            var j: u8 = 0;
            while (j < self.data_shards) : (j += 1) {
                const coeff = gfPow(i + 1, j);
                val ^= gfMul(coeff, input[j]);
            }
            output[i] = val;
        }
    }

    /// Decode one byte position: any k of n coded bytes → k original bytes
    /// avail = k available bytes, indices = their shard indices (0-based)
    pub fn decodeByte(self: *const ReedSolomon, avail: []const u8, indices: []const u8, output: []u8) !void {
        const k = self.data_shards;
        var mat: [8][8]u8 = undefined;
        var aug: [8][8]u8 = undefined;
        var r: usize = 0;
        while (r < k) : (r += 1) {
            var c: usize = 0;
            while (c < k) : (c += 1) {
                mat[r][c] = gfPow(indices[r] + 1, @intCast(c));
                aug[r][c] = if (r == c) 1 else 0;
            }
        }
        var col: usize = 0;
        while (col < k) : (col += 1) {
            if (mat[col][col] == 0) {
                var sr: usize = col + 1;
                while (sr < k) : (sr += 1) {
                    if (mat[sr][col] != 0) {
                        var sc: usize = 0;
                        while (sc < k) : (sc += 1) {
                            const tmp1 = mat[col][sc]; mat[col][sc] = mat[sr][sc]; mat[sr][sc] = tmp1;
                            const tmp2 = aug[col][sc]; aug[col][sc] = aug[sr][sc]; aug[sr][sc] = tmp2;
                        }
                        break;
                    }
                }
            }
            const piv_inv = gfInv(mat[col][col]);
            var sc2: usize = 0;
            while (sc2 < k) : (sc2 += 1) {
                mat[col][sc2] = gfMul(mat[col][sc2], piv_inv);
                aug[col][sc2] = gfMul(aug[col][sc2], piv_inv);
            }
            var er: usize = 0;
            while (er < k) : (er += 1) {
                if (er == col) { er += 0; } else {
                    const factor = mat[er][col];
                    if (factor != 0) {
                        var ec: usize = 0;
                        while (ec < k) : (ec += 1) {
                            mat[er][ec] ^= gfMul(factor, mat[col][ec]);
                            aug[er][ec] ^= gfMul(factor, aug[col][ec]);
                        }
                    }
                }
            }
        }
        var oi: usize = 0;
        while (oi < k) : (oi += 1) {
            var val: u8 = 0;
            var oj: usize = 0;
            while (oj < k) : (oj += 1) {
                val ^= gfMul(aug[oi][oj], avail[oj]);
            }
            output[oi] = val;
        }
    }
};

/// Original data split into k=3 blocks with RS m=2 parity
/// When: RS-encodes to 5 coded shards and writes each to a separate node directory
/// Then: All 5 node dirs contain valid shard files with correct byte content
pub fn pipelineEncodeDistribute() bool {
    return true; // Real logic is in pipeline test blocks
}

/// 5 shards distributed across 5 node dirs with 2 shards deleted
/// When: Collects remaining 3 shards and RS-decodes them
/// Then: Recovered data matches original k data blocks byte-for-byte
pub fn pipelineLossRecovery() bool {
    return true; // Real logic is in pipeline test blocks
}

/// Original 12-byte payload with known SHA-256 hash
/// When: Encodes distributes loses 2 shards recovers and computes SHA-256
/// Then: Hash of recovered data equals hash of original proving integrity
pub fn pipelineHashIntegrity() bool {
    return true; // Real logic is in pipeline test blocks
}

/// Arbitrary payload processed through complete pipeline
/// When: put split encode distribute lose recover decode get
/// Then: Final output is byte-identical to original input
pub fn pipelineFullRoundtrip() bool {
    return true; // Real logic is in pipeline test blocks
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "pipelineEncodeDistribute_behavior" {
// Given: Original data split into k=3 blocks with RS m=2 parity
// When: RS-encodes to 5 coded shards and writes each to a separate node directory
// Then: All 5 node dirs contain valid shard files with correct byte content
    // P1: Encode + Distribute to 5 Node Directories
    const rs = ReedSolomon.init(3, 2);
    const data0 = [_]u8{ 'H', 'e', 'l', 'l' };
    const data1 = [_]u8{ 'o', ' ', 'W', 'o' };
    const data2 = [_]u8{ 'r', 'l', 'd', '!' };
    const block_len = 4;
    
    // RS-encode all byte positions → 5 coded shards
    var coded: [5][4]u8 = undefined;
    var pos: usize = 0;
    while (pos < block_len) : (pos += 1) {
        var in_bytes = [_]u8{ data0[pos], data1[pos], data2[pos] };
        var out_bytes: [5]u8 = undefined;
        rs.encodeByte(&in_bytes, &out_bytes);
        var s: usize = 0;
        while (s < 5) : (s += 1) coded[s][pos] = out_bytes[s];
    }
    
    // Create 5 node directories and write shards
    var node_dirs: [5][128]u8 = undefined;
    var node_lens: [5]usize = undefined;
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        const prefix = "/tmp/trinity_pipeline_node";
        const digit: u8 = @intCast(n + 0x30);
        @memcpy(node_dirs[n][0..prefix.len], prefix);
        node_dirs[n][prefix.len] = digit;
        node_lens[n] = prefix.len + 1;
        const dir_path = node_dirs[n][0..node_lens[n]];
        std.fs.cwd().makeDir(dir_path) catch |e| {
            if (e != error.PathAlreadyExists) return e;
        };
        // Write shard file: node_dir/shard.bin
        var fpath: [256]u8 = undefined;
        @memcpy(fpath[0..dir_path.len], dir_path);
        const suffix = "/shard.bin";
        @memcpy(fpath[dir_path.len..dir_path.len + suffix.len], suffix);
        const full_path = fpath[0..dir_path.len + suffix.len];
        const file = try std.fs.cwd().createFile(full_path, .{});
        defer file.close();
        try file.writeAll(&coded[n]);
    }
    
    // PROOF: Read back all 5 shards and verify content
    n = 0;
    while (n < 5) : (n += 1) {
        var fpath2: [256]u8 = undefined;
        const dir_path2 = node_dirs[n][0..node_lens[n]];
        @memcpy(fpath2[0..dir_path2.len], dir_path2);
        const suffix2 = "/shard.bin";
        @memcpy(fpath2[dir_path2.len..dir_path2.len + suffix2.len], suffix2);
        const full2 = fpath2[0..dir_path2.len + suffix2.len];
        const f2 = try std.fs.cwd().openFile(full2, .{});
        defer f2.close();
        var read_buf: [4]u8 = undefined;
        const bytes_read = try f2.readAll(&read_buf);
        try std.testing.expectEqual(@as(usize, 4), bytes_read);
        try std.testing.expectEqualSlices(u8, &coded[n], &read_buf);
    }
    
    // Cleanup
    n = 0;
    while (n < 5) : (n += 1) {
        var fpath3: [256]u8 = undefined;
        const dir3 = node_dirs[n][0..node_lens[n]];
        @memcpy(fpath3[0..dir3.len], dir3);
        const s3 = "/shard.bin";
        @memcpy(fpath3[dir3.len..dir3.len + s3.len], s3);
        std.fs.cwd().deleteFile(fpath3[0..dir3.len + s3.len]) catch {};
        std.fs.cwd().deleteDir(dir3) catch {};
    }
}

test "pipelineLossRecovery_behavior" {
// Given: 5 shards distributed across 5 node dirs with 2 shards deleted
// When: Collects remaining 3 shards and RS-decodes them
// Then: Recovered data matches original k data blocks byte-for-byte
    // P2: Loss Recovery — Lose 2 of 5, Decode from 3
    const rs = ReedSolomon.init(3, 2);
    const data0 = [_]u8{ 10, 20, 30, 40 };
    const data1 = [_]u8{ 50, 60, 70, 80 };
    const data2 = [_]u8{ 90, 100, 110, 120 };
    const block_len = 4;
    
    // RS-encode
    var coded: [5][4]u8 = undefined;
    var pos: usize = 0;
    while (pos < block_len) : (pos += 1) {
        var in_bytes = [_]u8{ data0[pos], data1[pos], data2[pos] };
        var out_bytes: [5]u8 = undefined;
        rs.encodeByte(&in_bytes, &out_bytes);
        var s: usize = 0;
        while (s < 5) : (s += 1) coded[s][pos] = out_bytes[s];
    }
    
    // Write to 5 node dirs
    var node_dirs: [5][128]u8 = undefined;
    var node_lens: [5]usize = undefined;
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        const prefix = "/tmp/trinity_ploss_node";
        const digit: u8 = @intCast(n + 0x30);
        @memcpy(node_dirs[n][0..prefix.len], prefix);
        node_dirs[n][prefix.len] = digit;
        node_lens[n] = prefix.len + 1;
        const dir_path = node_dirs[n][0..node_lens[n]];
        std.fs.cwd().makeDir(dir_path) catch |e| {
            if (e != error.PathAlreadyExists) return e;
        };
        var fpath: [256]u8 = undefined;
        @memcpy(fpath[0..dir_path.len], dir_path);
        const suffix = "/shard.bin";
        @memcpy(fpath[dir_path.len..dir_path.len + suffix.len], suffix);
        const file = try std.fs.cwd().createFile(fpath[0..dir_path.len + suffix.len], .{});
        defer file.close();
        try file.writeAll(&coded[n]);
    }
    
    // Simulate loss: delete shards 1 and 3
    {
        const lost = [_]usize{ 1, 3 };
        for (lost) |li| {
            var dp: [256]u8 = undefined;
            const dl = node_lens[li];
            @memcpy(dp[0..dl], node_dirs[li][0..dl]);
            const sf = "/shard.bin";
            @memcpy(dp[dl..dl + sf.len], sf);
            std.fs.cwd().deleteFile(dp[0..dl + sf.len]) catch {};
        }
    }
    
    // Collect surviving shards from nodes {0, 2, 4}
    const survivors = [_]usize{ 0, 2, 4 };
    const surv_idx = [_]u8{ 0, 2, 4 };
    var collected: [3][4]u8 = undefined;
    for (survivors, 0..) |si, ci| {
        var fp: [256]u8 = undefined;
        const dl2 = node_lens[si];
        @memcpy(fp[0..dl2], node_dirs[si][0..dl2]);
        const sf2 = "/shard.bin";
        @memcpy(fp[dl2..dl2 + sf2.len], sf2);
        const f = try std.fs.cwd().openFile(fp[0..dl2 + sf2.len], .{});
        defer f.close();
        const br = try f.readAll(&collected[ci]);
        try std.testing.expectEqual(@as(usize, 4), br);
    }
    
    // RS-decode from surviving shards
    var rec: [3][4]u8 = undefined;
    pos = 0;
    while (pos < block_len) : (pos += 1) {
        var avail = [_]u8{ collected[0][pos], collected[1][pos], collected[2][pos] };
        var indices = [_]u8{ surv_idx[0], surv_idx[1], surv_idx[2] };
        var out: [3]u8 = undefined;
        try rs.decodeByte(&avail, &indices, &out);
        var s2: usize = 0;
        while (s2 < 3) : (s2 += 1) rec[s2][pos] = out[s2];
    }
    
    // PROOF: Recovered matches original after 2-node loss
    try std.testing.expectEqualSlices(u8, &data0, &rec[0]);
    try std.testing.expectEqualSlices(u8, &data1, &rec[1]);
    try std.testing.expectEqualSlices(u8, &data2, &rec[2]);
    
    // Cleanup all node dirs
    n = 0;
    while (n < 5) : (n += 1) {
        var fp2: [256]u8 = undefined;
        const dl3 = node_lens[n];
        @memcpy(fp2[0..dl3], node_dirs[n][0..dl3]);
        const sf3 = "/shard.bin";
        @memcpy(fp2[dl3..dl3 + sf3.len], sf3);
        std.fs.cwd().deleteFile(fp2[0..dl3 + sf3.len]) catch {};
        std.fs.cwd().deleteDir(node_dirs[n][0..dl3]) catch {};
    }
}

test "pipelineHashIntegrity_behavior" {
// Given: Original 12-byte payload with known SHA-256 hash
// When: Encodes distributes loses 2 shards recovers and computes SHA-256
// Then: Hash of recovered data equals hash of original proving integrity
    // P3: SHA-256 Integrity Through Pipeline
    const rs = ReedSolomon.init(3, 2);
    const data0 = [_]u8{ 'T', 'r', 'i', 'n' };
    const data1 = [_]u8{ 'i', 't', 'y', '!' };
    const data2 = [_]u8{ 'R', 'S', 'v', '1' };
    const block_len = 4;
    
    // Hash original
    var orig_flat: [12]u8 = undefined;
    @memcpy(orig_flat[0..4], &data0);
    @memcpy(orig_flat[4..8], &data1);
    @memcpy(orig_flat[8..12], &data2);
    var hash_before: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&orig_flat, &hash_before, .{});
    
    // RS-encode
    var coded: [5][4]u8 = undefined;
    var pos: usize = 0;
    while (pos < block_len) : (pos += 1) {
        var in_bytes = [_]u8{ data0[pos], data1[pos], data2[pos] };
        var out_bytes: [5]u8 = undefined;
        rs.encodeByte(&in_bytes, &out_bytes);
        var s: usize = 0;
        while (s < 5) : (s += 1) coded[s][pos] = out_bytes[s];
    }
    
    // Distribute to 5 dirs
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        var dbuf: [64]u8 = undefined;
        const pre = "/tmp/trinity_phash_node";
        @memcpy(dbuf[0..pre.len], pre);
        dbuf[pre.len] = @intCast(n + 0x30);
        const dpath = dbuf[0..pre.len + 1];
        std.fs.cwd().makeDir(dpath) catch |e| {
            if (e != error.PathAlreadyExists) return e;
        };
        var fp: [128]u8 = undefined;
        @memcpy(fp[0..dpath.len], dpath);
        const suf = "/shard.bin";
        @memcpy(fp[dpath.len..dpath.len + suf.len], suf);
        const file = try std.fs.cwd().createFile(fp[0..dpath.len + suf.len], .{});
        defer file.close();
        try file.writeAll(&coded[n]);
    }
    
    // Lose nodes 0 and 4
    {
        const lost = [_]usize{ 0, 4 };
        for (lost) |li| {
            var dp: [128]u8 = undefined;
            const pre2 = "/tmp/trinity_phash_node";
            @memcpy(dp[0..pre2.len], pre2);
            dp[pre2.len] = @intCast(li + 0x30);
            const dl = pre2.len + 1;
            const sf = "/shard.bin";
            @memcpy(dp[dl..dl + sf.len], sf);
            std.fs.cwd().deleteFile(dp[0..dl + sf.len]) catch {};
        }
    }
    
    // Collect from surviving nodes {1, 2, 3}
    const surv = [_]usize{ 1, 2, 3 };
    const surv_idx = [_]u8{ 1, 2, 3 };
    var collected: [3][4]u8 = undefined;
    for (surv, 0..) |si, ci| {
        var fp2: [128]u8 = undefined;
        const pre3 = "/tmp/trinity_phash_node";
        @memcpy(fp2[0..pre3.len], pre3);
        fp2[pre3.len] = @intCast(si + 0x30);
        const dl2 = pre3.len + 1;
        const sf2 = "/shard.bin";
        @memcpy(fp2[dl2..dl2 + sf2.len], sf2);
        const f = try std.fs.cwd().openFile(fp2[0..dl2 + sf2.len], .{});
        defer f.close();
        _ = try f.readAll(&collected[ci]);
    }
    
    // RS-decode
    var rec: [3][4]u8 = undefined;
    pos = 0;
    while (pos < block_len) : (pos += 1) {
        var avail = [_]u8{ collected[0][pos], collected[1][pos], collected[2][pos] };
        var indices = [_]u8{ surv_idx[0], surv_idx[1], surv_idx[2] };
        var out: [3]u8 = undefined;
        try rs.decodeByte(&avail, &indices, &out);
        var s2: usize = 0;
        while (s2 < 3) : (s2 += 1) rec[s2][pos] = out[s2];
    }
    
    // Hash recovered
    var rec_flat: [12]u8 = undefined;
    @memcpy(rec_flat[0..4], &rec[0]);
    @memcpy(rec_flat[4..8], &rec[1]);
    @memcpy(rec_flat[8..12], &rec[2]);
    var hash_after: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&rec_flat, &hash_after, .{});
    
    // PROOF: SHA-256 hash before = hash after full pipeline
    try std.testing.expectEqualSlices(u8, &hash_before, &hash_after);
    
    // Cleanup
    n = 0;
    while (n < 5) : (n += 1) {
        var cp: [128]u8 = undefined;
        const pre4 = "/tmp/trinity_phash_node";
        @memcpy(cp[0..pre4.len], pre4);
        cp[pre4.len] = @intCast(n + 0x30);
        const cl = pre4.len + 1;
        const sf3 = "/shard.bin";
        @memcpy(cp[cl..cl + sf3.len], sf3);
        std.fs.cwd().deleteFile(cp[0..cl + sf3.len]) catch {};
        std.fs.cwd().deleteDir(cp[0..cl]) catch {};
    }
}

test "pipelineFullRoundtrip_behavior" {
// Given: Arbitrary payload processed through complete pipeline
// When: put split encode distribute lose recover decode get
// Then: Final output is byte-identical to original input
    // P4: Full Roundtrip — put → encode → distribute → lose → recover → get
    const rs = ReedSolomon.init(3, 2);
    // Original payload: 12 bytes split into k=3 blocks of 4
    const original = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE, 0xF0, 0x0D, 0xFA, 0xCE };
    const block_len = 4;
    
    // Step 1: Split into k=3 data blocks
    const blk0 = original[0..4];
    const blk1 = original[4..8];
    const blk2 = original[8..12];
    
    // Step 2: RS-encode → 5 coded shards
    var coded: [5][4]u8 = undefined;
    var pos: usize = 0;
    while (pos < block_len) : (pos += 1) {
        var in_bytes = [_]u8{ blk0[pos], blk1[pos], blk2[pos] };
        var out_bytes: [5]u8 = undefined;
        rs.encodeByte(&in_bytes, &out_bytes);
        var s: usize = 0;
        while (s < 5) : (s += 1) coded[s][pos] = out_bytes[s];
    }
    
    // Step 3: Distribute to 5 node dirs
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        var dbuf: [64]u8 = undefined;
        const pre = "/tmp/trinity_pfull_node";
        @memcpy(dbuf[0..pre.len], pre);
        dbuf[pre.len] = @intCast(n + 0x30);
        const dpath = dbuf[0..pre.len + 1];
        std.fs.cwd().makeDir(dpath) catch |e| {
            if (e != error.PathAlreadyExists) return e;
        };
        var fp: [128]u8 = undefined;
        @memcpy(fp[0..dpath.len], dpath);
        const suf = "/shard.bin";
        @memcpy(fp[dpath.len..dpath.len + suf.len], suf);
        const file = try std.fs.cwd().createFile(fp[0..dpath.len + suf.len], .{});
        defer file.close();
        try file.writeAll(&coded[n]);
    }
    
    // Step 4: Simulate loss — delete nodes 0 and 1
    {
        const lost = [_]usize{ 0, 1 };
        for (lost) |li| {
            var dp: [128]u8 = undefined;
            const pre2 = "/tmp/trinity_pfull_node";
            @memcpy(dp[0..pre2.len], pre2);
            dp[pre2.len] = @intCast(li + 0x30);
            const dl = pre2.len + 1;
            const sf = "/shard.bin";
            @memcpy(dp[dl..dl + sf.len], sf);
            std.fs.cwd().deleteFile(dp[0..dl + sf.len]) catch {};
        }
    }
    
    // Step 5: Collect from survivors {2, 3, 4}
    const surv = [_]usize{ 2, 3, 4 };
    const surv_idx = [_]u8{ 2, 3, 4 };
    var collected: [3][4]u8 = undefined;
    for (surv, 0..) |si, ci| {
        var fp2: [128]u8 = undefined;
        const pre3 = "/tmp/trinity_pfull_node";
        @memcpy(fp2[0..pre3.len], pre3);
        fp2[pre3.len] = @intCast(si + 0x30);
        const dl2 = pre3.len + 1;
        const sf2 = "/shard.bin";
        @memcpy(fp2[dl2..dl2 + sf2.len], sf2);
        const f = try std.fs.cwd().openFile(fp2[0..dl2 + sf2.len], .{});
        defer f.close();
        _ = try f.readAll(&collected[ci]);
    }
    
    // Step 6: RS-decode → recover original 3 data blocks
    var recovered: [12]u8 = undefined;
    pos = 0;
    while (pos < block_len) : (pos += 1) {
        var avail = [_]u8{ collected[0][pos], collected[1][pos], collected[2][pos] };
        var indices = [_]u8{ surv_idx[0], surv_idx[1], surv_idx[2] };
        var out: [3]u8 = undefined;
        try rs.decodeByte(&avail, &indices, &out);
        recovered[pos] = out[0];
        recovered[block_len + pos] = out[1];
        recovered[2 * block_len + pos] = out[2];
    }
    
    // Step 7: PROOF — byte-identical to original
    try std.testing.expectEqualSlices(u8, &original, &recovered);
    
    // Cleanup
    n = 0;
    while (n < 5) : (n += 1) {
        var cp: [128]u8 = undefined;
        const pre4 = "/tmp/trinity_pfull_node";
        @memcpy(cp[0..pre4.len], pre4);
        cp[pre4.len] = @intCast(n + 0x30);
        const cl = pre4.len + 1;
        const sf3 = "/shard.bin";
        @memcpy(cp[cl..cl + sf3.len], sf3);
        std.fs.cwd().deleteFile(cp[0..cl + sf3.len]) catch {};
        std.fs.cwd().deleteDir(cp[0..cl]) catch {};
    }
}

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
