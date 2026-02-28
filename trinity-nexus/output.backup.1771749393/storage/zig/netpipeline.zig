// ═══════════════════════════════════════════════════════════════════════════════
// netpipeline v1.0.0 - Generated from .vibee specification
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
// [CYR:КОНСТАНТЫ]
// ═══════════════════════════════════════════════════════════════════════════════

// [CYR:Базо]inые φ-toонwith[CYR:танты] (Sacred Formula)
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
// [CYR:ТИПЫ]
// ═══════════════════════════════════════════════════════════════════════════════

/// 
pub const NetPipelineConfig = struct {
    data_shards: i64,
    parity_shards: i64,
    base_port: i64,
    node_count: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:ПАМЯТЬ] [CYR:ДЛЯ] WASM
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

/// φ-and[CYR:нтер]fieldsцandя
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Геnot[CYR:рац]andя φ-withпand[CYR:рал]and
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
// SHARD NETWORK — TCP Transfer Protocol (generated from .vibee)
// Wire protocol: [64 bytes hex hash][4 bytes data len LE u32][data]
// ═══════════════════════════════════════════════════════════════════

pub const ShardNetwork = struct {
    root_buf: [256]u8,
    root_len: usize,
    port: u16,

    const hex_chars = "0123456789abcdef";

    /// Create network node with storage directories
    pub fn init(root: []const u8, port: u16) !ShardNetwork {
        var node = ShardNetwork{
            .root_buf = undefined,
            .root_len = root.len,
            .port = port,
        };
        @memcpy(node.root_buf[0..root.len], root);
        std.fs.makeDirAbsolute(root) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => return e,
        };
        var sbuf: [280]u8 = undefined;
        const sdir = std.fmt.bufPrint(&sbuf, "{s}/shards", .{root}) catch unreachable;
        std.fs.makeDirAbsolute(sdir) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => return e,
        };
        return node;
    }

    fn rootPath(self: *const ShardNetwork) []const u8 {
        return self.root_buf[0..self.root_len];
    }

    fn hashToHex(hash: [32]u8) [64]u8 {
        var result: [64]u8 = undefined;
        for (hash, 0..) |byte, i| {
            result[i * 2] = hex_chars[byte >> 4];
            result[i * 2 + 1] = hex_chars[byte & 0x0F];
        }
        return result;
    }

    /// Bind TCP listener on port (use port 0 for OS-assigned)
    pub fn listen(self: *const ShardNetwork) !std.net.Server {
        const addr = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, self.port);
        return addr.listen(.{ .reuse_address = true });
    }

    /// Accept one connection, read protocol, store shard to disk
    pub fn receiveOne(self: *const ShardNetwork, server: *std.net.Server) !void {
        const conn = try server.accept();
        defer conn.stream.close();
        var hash_buf: [64]u8 = undefined;
        const hn = try conn.stream.readAtLeast(&hash_buf, 64);
        if (hn != 64) return error.ProtocolError;
        var len_buf: [4]u8 = undefined;
        const ln = try conn.stream.readAtLeast(&len_buf, 4);
        if (ln != 4) return error.ProtocolError;
        const data_len = std.mem.readInt(u32, &len_buf, .little);
        var data_buf: [8192]u8 = undefined;
        const dn = try conn.stream.readAtLeast(data_buf[0..data_len], data_len);
        if (dn != data_len) return error.ProtocolError;
        var pbuf: [350]u8 = undefined;
        const spath = std.fmt.bufPrint(&pbuf, "{s}/shards/{s}.shard", .{ self.rootPath(), hash_buf }) catch unreachable;
        const file = try std.fs.createFileAbsolute(spath, .{});
        defer file.close();
        try file.writeAll(data_buf[0..dn]);
    }

    /// Connect to peer and send shard via TCP wire protocol
    pub fn sendShard(_: *const ShardNetwork, peer_port: u16, hex: *const [64]u8, data: []const u8) !void {
        const addr = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, peer_port);
        const stream = try std.net.tcpConnectToAddress(addr);
        defer stream.close();
        stream.writeAll(hex) catch return error.SendFailed;
        var len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &len_buf, @intCast(data.len), .little);
        stream.writeAll(&len_buf) catch return error.SendFailed;
        stream.writeAll(data) catch return error.SendFailed;
    }

    /// Remove all storage (for testing)
    pub fn cleanup(self: *const ShardNetwork) void {
        std.fs.deleteTreeAbsolute(self.rootPath()) catch {};
    }
};


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

/// Original data RS-encoded into 5 coded shards with k=3 m=2
/// When: Sends each shard via TCP to 5 concurrent receiver threads on localhost
/// Then: All 5 receiver nodes store correct shard data to their directories
pub fn netpipelineTcpDistribute() bool {
    return true; // Real logic is in netpipeline test blocks
}

/// 5 shards distributed via TCP to 5 nodes with 2 nodes failed
/// When: Collects surviving 3 shards from disk and RS-decodes
/// Then: Recovered data matches original byte-for-byte after network loss
pub fn netpipelineTcpLossRecovery() bool {
    return true; // Real logic is in netpipeline test blocks
}

/// Original payload with known SHA-256 hash sent through TCP pipeline
/// When: Encodes distributes via TCP loses 2 nodes recovers and hashes
/// Then: SHA-256 of recovered data equals SHA-256 of original
pub fn netpipelineTcpHashIntegrity() bool {
    return true; // Real logic is in netpipeline test blocks
}

/// 12-byte payload put into full TCP pipeline
/// When: Split encode TCP-distribute lose-2 collect-3 decode get
/// Then: Final output byte-identical to original input through network
pub fn netpipelineTcpFullRoundtrip() bool {
    return true; // Real logic is in netpipeline test blocks
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "netpipelineTcpDistribute_behavior" {
// Given: Original data RS-encoded into 5 coded shards with k=3 m=2
// When: Sends each shard via TCP to 5 concurrent receiver threads on localhost
// Then: All 5 receiver nodes store correct shard data to their directories
    // NP1: RS Encode + TCP Distribute to 5 Node Threads
    const rs = ReedSolomon.init(3, 2);
    const data0 = [_]u8{ 'H', 'e', 'l', 'l' };
    const data1 = [_]u8{ 'o', ' ', 'W', 'o' };
    const data2 = [_]u8{ 'r', 'l', 'd', '!' };
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
    
    // Create 5 ShardNetwork nodes with port 0 (OS-assigned)
    var nodes: [5]ShardNetwork = undefined;
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        var rbuf: [64]u8 = undefined;
        const pre = "/tmp/trinity_np1_node";
        @memcpy(rbuf[0..pre.len], pre);
        rbuf[pre.len] = @intCast(n + 0x30);
        nodes[n] = try ShardNetwork.init(rbuf[0..pre.len + 1], 0);
    }
    
    // Start listeners and get actual ports
    var servers: [5]std.net.Server = undefined;
    var ports: [5]u16 = undefined;
    n = 0;
    while (n < 5) : (n += 1) {
        servers[n] = try nodes[n].listen();
        ports[n] = servers[n].listen_address.getPort();
    }
    
    // Spawn receiver threads
    const RecvCtx = struct { node: *const ShardNetwork, server: *std.net.Server };
    var ctxs: [5]RecvCtx = undefined;
    var threads: [5]std.Thread = undefined;
    n = 0;
    while (n < 5) : (n += 1) {
        ctxs[n] = .{ .node = &nodes[n], .server = &servers[n] };
        threads[n] = try std.Thread.spawn(.{}, struct {
            fn run(ctx: *RecvCtx) void {
                ctx.node.receiveOne(ctx.server) catch {};
            }
        }.run, .{&ctxs[n]});
    }
    
    // Small delay for listeners to be ready
    std.Thread.sleep(10 * std.time.ns_per_ms);
    
    // TCP-send each shard with a unique hex hash
    n = 0;
    while (n < 5) : (n += 1) {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&coded[n], &hash, .{});
        const hex = ShardNetwork.hashToHex(hash);
        try nodes[0].sendShard(ports[n], &hex, &coded[n]);
    }
    
    // Join all receiver threads
    n = 0;
    while (n < 5) : (n += 1) threads[n].join();
    
    // Close servers
    n = 0;
    while (n < 5) : (n += 1) servers[n].deinit();
    
    // PROOF: verify shard files exist in each node dir
    n = 0;
    while (n < 5) : (n += 1) {
        var rbuf2: [64]u8 = undefined;
        const pre2 = "/tmp/trinity_np1_node";
        @memcpy(rbuf2[0..pre2.len], pre2);
        rbuf2[pre2.len] = @intCast(n + 0x30);
        var sbuf: [280]u8 = undefined;
        const sdir = std.fmt.bufPrint(&sbuf, "{s}/shards", .{rbuf2[0..pre2.len + 1]}) catch unreachable;
        var dir = std.fs.openDirAbsolute(sdir, .{ .iterate = true }) catch {
            return error.NodeDirMissing;
        };
        defer dir.close();
        // Count files
        var iter = dir.iterate();
        var count: usize = 0;
        while (try iter.next()) |_| count += 1;
        try std.testing.expect(count >= 1);
    }
    
    // Cleanup
    n = 0;
    while (n < 5) : (n += 1) nodes[n].cleanup();
}

test "netpipelineTcpLossRecovery_behavior" {
// Given: 5 shards distributed via TCP to 5 nodes with 2 nodes failed
// When: Collects surviving 3 shards from disk and RS-decodes
// Then: Recovered data matches original byte-for-byte after network loss
    // NP2: TCP Loss Recovery — Lose 2 Nodes, Decode from 3
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
    
    // Create 5 nodes, listen, get ports
    var nodes: [5]ShardNetwork = undefined;
    var servers: [5]std.net.Server = undefined;
    var ports: [5]u16 = undefined;
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        var rbuf: [64]u8 = undefined;
        const pre = "/tmp/trinity_np2_node";
        @memcpy(rbuf[0..pre.len], pre);
        rbuf[pre.len] = @intCast(n + 0x30);
        nodes[n] = try ShardNetwork.init(rbuf[0..pre.len + 1], 0);
        servers[n] = try nodes[n].listen();
        ports[n] = servers[n].listen_address.getPort();
    }
    
    // Spawn receiver threads
    const RecvCtx = struct { node: *const ShardNetwork, server: *std.net.Server };
    var ctxs: [5]RecvCtx = undefined;
    var threads: [5]std.Thread = undefined;
    n = 0;
    while (n < 5) : (n += 1) {
        ctxs[n] = .{ .node = &nodes[n], .server = &servers[n] };
        threads[n] = try std.Thread.spawn(.{}, struct {
            fn run(ctx: *RecvCtx) void {
                ctx.node.receiveOne(ctx.server) catch {};
            }
        }.run, .{&ctxs[n]});
    }
    std.Thread.sleep(10 * std.time.ns_per_ms);
    
    // TCP-send shards with shard-index-based deterministic hash
    var shard_hexes: [5][64]u8 = undefined;
    n = 0;
    while (n < 5) : (n += 1) {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&coded[n], &hash, .{});
        shard_hexes[n] = ShardNetwork.hashToHex(hash);
        try nodes[0].sendShard(ports[n], &shard_hexes[n], &coded[n]);
    }
    
    // Join + close
    n = 0;
    while (n < 5) : (n += 1) threads[n].join();
    n = 0;
    while (n < 5) : (n += 1) servers[n].deinit();
    
    // Simulate loss: delete nodes 1 and 3 storage
    {
        const lost = [_]usize{ 1, 3 };
        for (lost) |li| nodes[li].cleanup();
    }
    
    // Collect surviving shards from nodes {0, 2, 4}
    const survivors = [_]usize{ 0, 2, 4 };
    const surv_idx = [_]u8{ 0, 2, 4 };
    var collected: [3][4]u8 = undefined;
    for (survivors, 0..) |si, ci| {
        var pbuf: [350]u8 = undefined;
        const spath = std.fmt.bufPrint(&pbuf, "{s}/shards/{s}.shard", .{ nodes[si].rootPath(), shard_hexes[si] }) catch unreachable;
        const f = try std.fs.openFileAbsolute(spath, .{});
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
    
    // PROOF: Recovered matches original after TCP + 2-node loss
    try std.testing.expectEqualSlices(u8, &data0, &rec[0]);
    try std.testing.expectEqualSlices(u8, &data1, &rec[1]);
    try std.testing.expectEqualSlices(u8, &data2, &rec[2]);
    
    // Cleanup remaining nodes
    for (survivors) |si| nodes[si].cleanup();
}

test "netpipelineTcpHashIntegrity_behavior" {
// Given: Original payload with known SHA-256 hash sent through TCP pipeline
// When: Encodes distributes via TCP loses 2 nodes recovers and hashes
// Then: SHA-256 of recovered data equals SHA-256 of original
    // NP3: SHA-256 Integrity Through TCP Pipeline
    const rs = ReedSolomon.init(3, 2);
    const data0 = [_]u8{ 'T', 'r', 'i', 'n' };
    const data1 = [_]u8{ 'i', 't', 'y', '!' };
    const data2 = [_]u8{ 'R', 'S', 'v', '2' };
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
    
    // Create 5 nodes, listen, spawn receivers, send
    var nodes: [5]ShardNetwork = undefined;
    var servers: [5]std.net.Server = undefined;
    var ports: [5]u16 = undefined;
    var shard_hexes: [5][64]u8 = undefined;
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        var rbuf: [64]u8 = undefined;
        const pre = "/tmp/trinity_np3_node";
        @memcpy(rbuf[0..pre.len], pre);
        rbuf[pre.len] = @intCast(n + 0x30);
        nodes[n] = try ShardNetwork.init(rbuf[0..pre.len + 1], 0);
        servers[n] = try nodes[n].listen();
        ports[n] = servers[n].listen_address.getPort();
    }
    const RecvCtx = struct { node: *const ShardNetwork, server: *std.net.Server };
    var ctxs: [5]RecvCtx = undefined;
    var threads: [5]std.Thread = undefined;
    n = 0;
    while (n < 5) : (n += 1) {
        ctxs[n] = .{ .node = &nodes[n], .server = &servers[n] };
        threads[n] = try std.Thread.spawn(.{}, struct {
            fn run(ctx: *RecvCtx) void { ctx.node.receiveOne(ctx.server) catch {}; }
        }.run, .{&ctxs[n]});
    }
    std.Thread.sleep(10 * std.time.ns_per_ms);
    n = 0;
    while (n < 5) : (n += 1) {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&coded[n], &hash, .{});
        shard_hexes[n] = ShardNetwork.hashToHex(hash);
        try nodes[0].sendShard(ports[n], &shard_hexes[n], &coded[n]);
    }
    n = 0;
    while (n < 5) : (n += 1) threads[n].join();
    n = 0;
    while (n < 5) : (n += 1) servers[n].deinit();
    
    // Lose nodes 0 and 4
    nodes[0].cleanup();
    nodes[4].cleanup();
    
    // Collect from survivors {1, 2, 3}
    const surv = [_]usize{ 1, 2, 3 };
    const surv_idx = [_]u8{ 1, 2, 3 };
    var collected: [3][4]u8 = undefined;
    for (surv, 0..) |si, ci| {
        var pbuf: [350]u8 = undefined;
        const spath = std.fmt.bufPrint(&pbuf, "{s}/shards/{s}.shard", .{ nodes[si].rootPath(), shard_hexes[si] }) catch unreachable;
        const f = try std.fs.openFileAbsolute(spath, .{});
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
    
    // PROOF: SHA-256 before = after through TCP pipeline
    try std.testing.expectEqualSlices(u8, &hash_before, &hash_after);
    
    // Cleanup
    for (surv) |si| nodes[si].cleanup();
}

test "netpipelineTcpFullRoundtrip_behavior" {
// Given: 12-byte payload put into full TCP pipeline
// When: Split encode TCP-distribute lose-2 collect-3 decode get
// Then: Final output byte-identical to original input through network
    // NP4: Full TCP Roundtrip — put → encode → TCP → lose → recover → get
    const rs = ReedSolomon.init(3, 2);
    const original = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE, 0xF0, 0x0D, 0xFA, 0xCE };
    const block_len = 4;
    const blk0 = original[0..4];
    const blk1 = original[4..8];
    const blk2 = original[8..12];
    
    // RS-encode → 5 coded shards
    var coded: [5][4]u8 = undefined;
    var pos: usize = 0;
    while (pos < block_len) : (pos += 1) {
        var in_bytes = [_]u8{ blk0[pos], blk1[pos], blk2[pos] };
        var out_bytes: [5]u8 = undefined;
        rs.encodeByte(&in_bytes, &out_bytes);
        var s: usize = 0;
        while (s < 5) : (s += 1) coded[s][pos] = out_bytes[s];
    }
    
    // 5 nodes, listeners, receiver threads
    var nodes: [5]ShardNetwork = undefined;
    var servers: [5]std.net.Server = undefined;
    var ports: [5]u16 = undefined;
    var shard_hexes: [5][64]u8 = undefined;
    var n: usize = 0;
    while (n < 5) : (n += 1) {
        var rbuf: [64]u8 = undefined;
        const pre = "/tmp/trinity_np4_node";
        @memcpy(rbuf[0..pre.len], pre);
        rbuf[pre.len] = @intCast(n + 0x30);
        nodes[n] = try ShardNetwork.init(rbuf[0..pre.len + 1], 0);
        servers[n] = try nodes[n].listen();
        ports[n] = servers[n].listen_address.getPort();
    }
    const RecvCtx = struct { node: *const ShardNetwork, server: *std.net.Server };
    var ctxs: [5]RecvCtx = undefined;
    var threads: [5]std.Thread = undefined;
    n = 0;
    while (n < 5) : (n += 1) {
        ctxs[n] = .{ .node = &nodes[n], .server = &servers[n] };
        threads[n] = try std.Thread.spawn(.{}, struct {
            fn run(ctx: *RecvCtx) void { ctx.node.receiveOne(ctx.server) catch {}; }
        }.run, .{&ctxs[n]});
    }
    std.Thread.sleep(10 * std.time.ns_per_ms);
    
    // TCP distribute
    n = 0;
    while (n < 5) : (n += 1) {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&coded[n], &hash, .{});
        shard_hexes[n] = ShardNetwork.hashToHex(hash);
        try nodes[0].sendShard(ports[n], &shard_hexes[n], &coded[n]);
    }
    n = 0;
    while (n < 5) : (n += 1) threads[n].join();
    n = 0;
    while (n < 5) : (n += 1) servers[n].deinit();
    
    // Lose nodes 0 and 1
    nodes[0].cleanup();
    nodes[1].cleanup();
    
    // Collect from survivors {2, 3, 4}
    const surv = [_]usize{ 2, 3, 4 };
    const surv_idx = [_]u8{ 2, 3, 4 };
    var collected: [3][4]u8 = undefined;
    for (surv, 0..) |si, ci| {
        var pbuf: [350]u8 = undefined;
        const spath = std.fmt.bufPrint(&pbuf, "{s}/shards/{s}.shard", .{ nodes[si].rootPath(), shard_hexes[si] }) catch unreachable;
        const f = try std.fs.openFileAbsolute(spath, .{});
        defer f.close();
        _ = try f.readAll(&collected[ci]);
    }
    
    // RS-decode → recover original
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
    
    // PROOF: byte-identical through TCP pipeline
    try std.testing.expectEqualSlices(u8, &original, &recovered);
    
    // Cleanup
    for (surv) |si| nodes[si].cleanup();
}

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
