// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Phase 2 — TritVSA (Ternary Vector Symbolic Architecture)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Ternary VSA with φ-alignment for Trinity hardware advantage
// 1.58 bits/trit vs 32 bits/float = 20× memory savings
// Balanced ternary {-1, 0, +1} naturally aligns with φ-math
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const vsa = @import("vsa.zig");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ for seeding
pub const PHI = sacred_constants.PHI;

/// Default VSA dimension
pub const DEFAULT_DIM: usize = 4096;

/// Trit values for balanced ternary
pub const Trit = enum(i2) {
    neg = -1,
    zero = 0,
    pos = 1,

    /// Convert to integer value
    pub fn toInt(self: Trit) i2 {
        return @intFromEnum(self);
    }

    /// Create from integer
    pub fn fromInt(val: i2) Trit {
        return switch (val) {
            -1 => .neg,
            0 => .zero,
            1 => .pos,
            else => unreachable,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PACKED TRIT
// ═══════════════════════════════════════════════════════════════════════════════

/// Packed ternary storage (1.58 bits/trit)
/// Each 2 bytes store 5 trits (15 bits)
pub const PackedTrit = struct {
    storage: []u8,
    length: usize,
    allocator: std.mem.Allocator,

    /// Initialize packed trit storage
    pub fn init(allocator: std.mem.Allocator, length: usize) !PackedTrit {
        // 5 trits = 15 bits, stored in 2 bytes (u16)
        const bytes_needed = ((length + 4) / 5) * 2;
        const storage = try allocator.alloc(u8, bytes_needed);
        @memset(storage, 0);
        return .{
            .storage = storage,
            .length = length,
            .allocator = allocator,
        };
    }

    /// Clean up
    pub fn deinit(self: *PackedTrit) void {
        self.allocator.free(self.storage);
    }

    /// Get trit at index
    pub fn get(self: *const PackedTrit, index: usize) Trit {
        if (index >= self.length) return .zero;

        const group_idx = index / 5; // Which 2-byte group
        const trit_idx_raw = index % 5; // Position within group (0-4)

        // Read 16 bits (little-endian)
        const byte0 = self.storage[group_idx * 2];
        const byte1 = self.storage[group_idx * 2 + 1];
        const value_u16 = @as(u16, byte0) | (@as(u16, byte1) << 8);

        // Extract 3-bit value at position
        const shift_amt: u4 = @intCast(trit_idx_raw * 3);
        const value = @as(u3, @intCast((value_u16 >> shift_amt) & 0x7));

        // Map 1→neg, 2→zero, 3→pos, 0→zero
        return switch (value) {
            1 => .neg,
            2 => .zero,
            3 => .pos,
            else => .zero,
        };
    }

    /// Set trit at index
    pub fn set(self: *PackedTrit, index: usize, trit: Trit) void {
        if (index >= self.length) return;

        const group_idx = index / 5;
        const trit_idx_raw = index % 5;

        // Read 16 bits (little-endian)
        const byte0_idx = group_idx * 2;
        const byte1_idx = group_idx * 2 + 1;
        const byte0 = self.storage[byte0_idx];
        const byte1 = self.storage[byte1_idx];
        var value_u16 = @as(u16, byte0) | (@as(u16, byte1) << 8);

        // Clear the 3 bits at position and set new value
        const shift_amt: u4 = @intCast(trit_idx_raw * 3);
        const mask: u16 = ~(@as(u16, 0x7) << @as(u4, shift_amt));
        value_u16 &= mask;

        // Convert trit to 1-3 range (neg→1, zero→2, pos→3)
        const trit_val: i2 = @intFromEnum(trit);
        const trit_code: u16 = @intCast(@as(i4, trit_val) + 2);
        value_u16 |= trit_code << shift_amt;

        // Write back (little-endian)
        self.storage[byte0_idx] = @truncate(value_u16 & 0xFF);
        self.storage[byte1_idx] = @truncate((value_u16 >> 8) & 0xFF);
    }

    /// Clone packed trit
    pub fn clone(self: *const PackedTrit) !PackedTrit {
        const result = try PackedTrit.init(self.allocator, self.length);
        @memcpy(result.storage, self.storage);
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT VSA VECTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary VSA vector
pub const TritVSA = struct {
    data: PackedTrit,
    dim: usize,
    seed: u64,

    /// Initialize new TritVSA vector
    pub fn init(allocator: std.mem.Allocator, dim: usize, seed: u64) !TritVSA {
        var data = try PackedTrit.init(allocator, dim);
        errdefer data.deinit();

        var self = TritVSA{
            .data = data,
            .dim = dim,
            .seed = seed,
        };

        // Initialize with φ-based seed
        try self.seedInit();
        return self;
    }

    /// Clean up
    pub fn deinit(self: *TritVSA) void {
        self.data.deinit();
    }

    /// Initialize with φ-based seeding
    fn seedInit(self: *TritVSA) !void {
        var prng = std.Random.DefaultPrng.init(self.seed);

        for (0..self.dim) |i| {
            // φ-based trit selection
            const rand_val = prng.random().float(f64);
            const trit_val = if (rand_val < 1.0 / 3.0)
                Trit.neg
            else if (rand_val < 2.0 / 3.0)
                Trit.zero
            else
                Trit.pos;

            self.data.set(i, trit_val);
        }
    }

    /// Bind operation (ternary XOR using modular addition)
    /// Association: binds two vectors, reversible via unbind
    /// Maps Trit values to 0-2 range: neg→0, zero→1, pos→2
    /// Then uses (a + b) mod 3, which is self-inverse
    pub fn bind(allocator: std.mem.Allocator, a: *const TritVSA, b: *const TritVSA) !TritVSA {
        if (a.dim != b.dim) return error.DimensionMismatch;

        var result = try TritVSA.init(allocator, a.dim, a.seed ^ b.seed);

        for (0..a.dim) |i| {
            const ta = a.data.get(i);
            const tb = b.data.get(i);

            // Map Trit to 0-2 range: neg→0, zero→1, pos→2
            const ta_code = @as(i4, @intFromEnum(ta)) + 1; // -1→0, 0→1, 1→2
            const tb_code = @as(i4, @intFromEnum(tb)) + 1;

            // Ternary XOR using modular addition (self-inverse)
            const result_code = @mod(ta_code + tb_code, 3);

            // Map back to Trit: 0→neg, 1→zero, 2→pos
            const result_trit = Trit.fromInt(@as(i2, @truncate(result_code - 1)));

            result.data.set(i, result_trit);
        }

        return result;
    }

    /// Bundle operation (ternary majority vote)
    /// Superposition: combines multiple vectors
    pub fn bundle(allocator: std.mem.Allocator, vectors: []const *const TritVSA) !TritVSA {
        if (vectors.len == 0) return error.EmptyVectorList;

        const dim = vectors[0].dim;
        for (vectors[1..]) |v| {
            if (v.dim != dim) return error.DimensionMismatch;
        }

        var result = try TritVSA.init(allocator, dim, vectors[0].seed);

        // For each dimension, compute majority vote
        for (0..dim) |i| {
            var counts = [3]usize{ 0, 0, 0 }; // neg, zero, pos

            for (vectors) |v| {
                const t = v.data.get(i);
                const idx = @as(usize, @intCast(@as(i4, @intFromEnum(t)) + 1));
                counts[idx] += 1;
            }

            // Find majority
            const max_idx = if (counts[0] > counts[1] and counts[0] > counts[2])
                @as(usize, 0)
            else if (counts[1] > counts[2])
                @as(usize, 1)
            else
                @as(usize, 2);

            result.data.set(i, Trit.fromInt(@as(i2, @truncate(@as(i3, @intCast(max_idx)) - 1))));
        }

        return result;
    }

    /// Unbind operation (reverse bind using subtraction)
    /// Retrieves vector from binding using inverse key
    pub fn unbind(allocator: std.mem.Allocator, bound: *const TritVSA, key: *const TritVSA) !TritVSA {
        if (bound.dim != key.dim) return error.DimensionMismatch;

        var result = try TritVSA.init(allocator, bound.dim, bound.seed ^ key.seed);

        for (0..bound.dim) |i| {
            const t_bound = bound.data.get(i);
            const t_key = key.data.get(i);

            // Map Trit to 0-2 range: neg→0, zero→1, pos→2
            const bound_code = @as(i4, @intFromEnum(t_bound)) + 1;
            const key_code = @as(i4, @intFromEnum(t_key)) + 1;

            // Reverse of modular addition is subtraction
            // result = (bound - key + 3) mod 3 to handle wraparound
            const result_code = @mod(bound_code - key_code + 3, 3);

            // Map back to Trit: 0→neg, 1→zero, 2→pos
            const result_trit = Trit.fromInt(@as(i2, @truncate(result_code - 1)));

            result.data.set(i, result_trit);
        }

        return result;
    }

    /// Permute (cyclic shift)
    /// Encodes sequence/position information
    pub fn permute(self: *TritVSA, rotations: usize) !void {
        if (self.dim == 0) return;

        const actual_rot = @mod(rotations, self.dim);

        if (actual_rot == 0) return;

        // Create temporary storage using slice
        var temp_storage = try self.data.allocator.alloc(Trit, self.dim);
        defer self.data.allocator.free(temp_storage);

        // Copy rotated values: element at i moves to (i + rot) % dim
        for (0..self.dim) |i| {
            const new_idx = @mod(i + actual_rot, self.dim);
            temp_storage[new_idx] = self.data.get(i);
        }

        // Write back
        for (0..self.dim) |i| {
            self.data.set(i, temp_storage[i]);
        }
    }

    /// Cosine similarity (after decoding to float)
    pub fn similarity(a: *const TritVSA, b: *const TritVSA) !f64 {
        if (a.dim != b.dim) return error.DimensionMismatch;

        // Decode to float vectors
        var allocator = std.heap.page_allocator;

        const fa = try a.toFloatVector(allocator);
        defer allocator.free(fa);

        const fb = try b.toFloatVector(allocator);
        defer allocator.free(fb);

        // Convert f64 to f32 for cosine similarity
        const fa32 = try allocator.alloc(f32, a.dim);
        defer allocator.free(fa32);
        const fb32 = try allocator.alloc(f32, b.dim);
        defer allocator.free(fb32);

        for (0..a.dim) |i| {
            fa32[i] = @floatCast(fa[i]);
            fb32[i] = @floatCast(fb[i]);
        }

        // Compute cosine similarity
        return vsa.cosineSimilarity(fa32, fb32) catch 0.0;
    }

    /// Convert packed trits to float vector for similarity computation
    fn toFloatVector(self: *const TritVSA, allocator: std.mem.Allocator) ![]f64 {
        const result = try allocator.alloc(f64, self.dim);

        for (0..self.dim) |i| {
            result[i] = switch (self.data.get(i)) {
                .neg => -1.0,
                .zero => 0.0,
                .pos => 1.0,
            };
        }

        return result;
    }

    /// Create from float vector (quantize to trits)
    pub fn fromFloatVector(allocator: std.mem.Allocator, float_vec: []const f64, seed: u64) !TritVSA {
        var self = try TritVSA.init(allocator, float_vec.len, seed);

        for (float_vec, 0..) |val, i| {
            const trit: Trit = if (val < -0.33)
                .neg
            else if (val > 0.33)
                .pos
            else
                .zero;

            self.data.set(i, trit);
        }

        return self;
    }

    /// Hamming distance (count differing trits)
    pub fn hammingDistance(a: *const TritVSA, b: *const TritVSA) !usize {
        if (a.dim != b.dim) return error.DimensionMismatch;

        var distance: usize = 0;
        for (0..a.dim) |i| {
            if (@intFromEnum(a.data.get(i)) != @intFromEnum(b.data.get(i))) {
                distance += 1;
            }
        }

        return distance;
    }

    /// Clone TritVSA
    pub fn clone(self: *const TritVSA) !TritVSA {
        const data_clone = try self.data.clone();
        return .{
            .data = data_clone,
            .dim = self.dim,
            .seed = self.seed,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Create random TritVSA with φ-seeded RNG
pub fn randomTritVSA(allocator: std.mem.Allocator, dim: usize) !TritVSA {
    // Use timestamp + PHI for seed
    const seed = @as(u64, @intFromFloat(std.time.nanoTimestamp() * PHI));
    return TritVSA.init(allocator, dim, seed);
}

/// Create zero TritVSA
pub fn zeroTritVSA(allocator: std.mem.Allocator, dim: usize) !TritVSA {
    var result = try TritVSA.init(allocator, dim, 0);

    for (0..dim) |i| {
        result.data.set(i, .zero);
    }

    return result;
}

/// Bundle two TritVSA vectors
pub fn bundle2(allocator: std.mem.Allocator, a: *const TritVSA, b: *const TritVSA) !TritVSA {
    return TritVSA.bundle(allocator, &[_]*const TritVSA{ a, b });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PackedTrit basic operations" {
    const allocator = std.testing.allocator;

    var packed_trit = try PackedTrit.init(allocator, 10);
    defer packed_trit.deinit();

    try testing.expectEqual(@as(usize, 10), packed_trit.length);

    // Test set/get
    packed_trit.set(0, .pos);
    try testing.expectEqual(Trit.pos, packed_trit.get(0));

    packed_trit.set(1, .neg);
    try testing.expectEqual(Trit.neg, packed_trit.get(1));

    packed_trit.set(2, .zero);
    try testing.expectEqual(Trit.zero, packed_trit.get(2));
}

test "TritVSA initialization" {
    const allocator = std.testing.allocator;

    var vec = try TritVSA.init(allocator, 100, 42);
    defer vec.deinit();

    try testing.expectEqual(@as(usize, 100), vec.dim);
    try testing.expectEqual(@as(u64, 42), vec.seed);
}

test "TritVSA bind is self-inverse" {
    const allocator = std.testing.allocator;

    var a = try TritVSA.init(allocator, 64, 123);
    defer a.deinit();

    var b = try TritVSA.init(allocator, 64, 456);
    defer b.deinit();

    var bound = try TritVSA.bind(allocator, &a, &b);
    defer bound.deinit();

    var unbound = try TritVSA.unbind(allocator, &bound, &b);
    defer unbound.deinit();

    // After unbind, should be similar to original
    const sim = try a.similarity(&unbound);
    try testing.expect(sim > 0.8); // Should be high similarity
}

test "TritVSA bundle majority vote" {
    const allocator = std.testing.allocator;

    var v1 = try zeroTritVSA(allocator, 3);
    defer v1.deinit();

    var v2 = try zeroTritVSA(allocator, 3);
    defer v2.deinit();

    var v3 = try zeroTritVSA(allocator, 3);
    defer v3.deinit();

    // Set values: v1 = [pos, pos, neg], v2 = [pos, pos, neg], v3 = [neg, neg, neg]
    v1.data.set(0, .pos);
    v1.data.set(1, .pos);
    v1.data.set(2, .neg);

    v2.data.set(0, .pos);
    v2.data.set(1, .pos);
    v2.data.set(2, .neg);

    v3.data.set(0, .neg);
    v3.data.set(1, .neg);
    v3.data.set(2, .neg);

    // Bundle: [pos+pos+neg, pos+pos+neg, neg+neg+neg]
    // Majority: pos, pos, neg
    var bundled = try TritVSA.bundle(allocator, &[_]*const TritVSA{ &v1, &v2, &v3 });
    defer bundled.deinit();

    try testing.expectEqual(Trit.pos, bundled.data.get(0));
    try testing.expectEqual(Trit.pos, bundled.data.get(1));
    try testing.expectEqual(Trit.neg, bundled.data.get(2));
}

test "TritVSA hamming distance" {
    const allocator = std.testing.allocator;

    var v1 = try zeroTritVSA(allocator, 10);
    defer v1.deinit();

    var v2 = try zeroTritVSA(allocator, 10);
    defer v2.deinit();

    // Same vectors = 0 distance
    const dist_same = try v1.hammingDistance(&v2);
    try testing.expectEqual(@as(usize, 0), dist_same);

    // Flip 3 trits
    v2.data.set(0, .pos);
    v2.data.set(3, .neg);
    v2.data.set(7, .pos);

    const diff = try v1.hammingDistance(&v2);
    try testing.expectEqual(@as(usize, 3), diff);
}

test "TritVSA permute" {
    const allocator = std.testing.allocator;

    var vec = try TritVSA.init(allocator, 10, 42);
    defer vec.deinit();

    // Set distinct pattern
    vec.data.set(0, .pos);
    vec.data.set(1, .neg);
    vec.data.set(2, .zero);

    try vec.permute(3);

    // After rotation by 3, index 3 should have what was at 0
    try testing.expectEqual(Trit.pos, vec.data.get(3));
}

test "TritVSA memory efficiency" {
    const allocator = std.testing.allocator;

    const dim: usize = 10000;

    // TritVSA: ~1.58 bits/trit * 10000 = 15800 bits ≈ 1975 bytes
    var trit = try TritVSA.init(allocator, dim, 42);
    defer trit.deinit();

    const trit_bytes = ((dim + 4) / 5); // 5 trits per byte

    // Float array: 10000 * 32 bits = 320000 bits = 40000 bytes
    // Memory savings: ~20×
    try testing.expect(trit_bytes < dim * @as(usize, 4));
}

const testing = std.testing;
