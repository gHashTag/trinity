// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE v2.0 - VSA Shard Encoder
// Encode data chunks as ternary hypervectors using VSA bind/bundle/permute
// Content-addressable semantic fingerprints for similarity search
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY HYPERVECTOR (self-contained VSA core for storage network)
// Balanced ternary {-1, 0, +1} vectors with bind/bundle/permute/similarity
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_DIM: usize = 1024;
pub const Trit = i8;

pub const Hypervector = struct {
    trits: [MAX_DIM]Trit = [_]Trit{0} ** MAX_DIM,
    dim: usize = 256,

    /// Create zero vector
    pub fn zero(dim: usize) Hypervector {
        return .{ .dim = dim };
    }

    /// Create random {-1, 0, +1} vector from seed
    pub fn random(dim: usize, seed: u64) Hypervector {
        var hv = Hypervector{ .dim = dim };
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        for (0..dim) |i| {
            hv.trits[i] = rand.intRangeAtMost(Trit, -1, 1);
        }
        return hv;
    }

    /// Bind: element-wise multiply (ternary multiplication)
    pub fn bind(a: *const Hypervector, b: *const Hypervector) Hypervector {
        var result = Hypervector{ .dim = a.dim };
        for (0..a.dim) |i| {
            result.trits[i] = a.trits[i] * b.trits[i];
        }
        return result;
    }

    /// Bundle2: majority vote of 2 vectors (sum + threshold)
    pub fn bundle2(a: *const Hypervector, b: *const Hypervector) Hypervector {
        var result = Hypervector{ .dim = a.dim };
        for (0..a.dim) |i| {
            const sum: i16 = @as(i16, a.trits[i]) + @as(i16, b.trits[i]);
            if (sum > 0) {
                result.trits[i] = 1;
            } else if (sum < 0) {
                result.trits[i] = -1;
            } else {
                result.trits[i] = 0;
            }
        }
        return result;
    }

    /// Permute: cyclic right shift by k positions
    pub fn permute(v: *const Hypervector, k: usize) Hypervector {
        var result = Hypervector{ .dim = v.dim };
        for (0..v.dim) |i| {
            const new_pos = (i + k) % v.dim;
            result.trits[new_pos] = v.trits[i];
        }
        return result;
    }

    /// Cosine similarity: dot_product / (norm_a * norm_b)
    pub fn cosineSimilarity(a: *const Hypervector, b: *const Hypervector) f64 {
        var dot: i64 = 0;
        var norm_a_sq: i64 = 0;
        var norm_b_sq: i64 = 0;
        for (0..a.dim) |i| {
            dot += @as(i64, a.trits[i]) * @as(i64, b.trits[i]);
            norm_a_sq += @as(i64, a.trits[i]) * @as(i64, a.trits[i]);
            norm_b_sq += @as(i64, b.trits[i]) * @as(i64, b.trits[i]);
        }
        const na = @sqrt(@as(f64, @floatFromInt(norm_a_sq)));
        const nb = @sqrt(@as(f64, @floatFromInt(norm_b_sq)));
        if (na == 0 or nb == 0) return 0;
        return @as(f64, @floatFromInt(dot)) / (na * nb);
    }

    /// Count non-zero trits
    pub fn countNonZero(self: *const Hypervector) usize {
        var count: usize = 0;
        for (0..self.dim) |i| {
            if (self.trits[i] != 0) count += 1;
        }
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA SHARD ENCODER
// ═══════════════════════════════════════════════════════════════════════════════

pub const EncoderConfig = struct {
    dimension: usize = 256,
    codebook_seed: u64 = 0x5452495F53454544, // "TRI_SEED"
};

pub const EncoderStats = struct {
    shards_encoded: u64,
    total_bytes_encoded: u64,
    similarity_queries: u64,
};

pub const VsaShardEncoder = struct {
    allocator: std.mem.Allocator,
    dimension: usize,
    codebook: [256]Hypervector,
    shards_encoded: u64,
    total_bytes_encoded: u64,
    similarity_queries: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) VsaShardEncoder {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: EncoderConfig) VsaShardEncoder {
        var encoder = VsaShardEncoder{
            .allocator = allocator,
            .dimension = config.dimension,
            .codebook = undefined,
            .shards_encoded = 0,
            .total_bytes_encoded = 0,
            .similarity_queries = 0,
            .mutex = .{},
        };

        // Initialize codebook: each byte value (0-255) gets a unique random hypervector
        // Seed is deterministic so same byte always maps to same vector
        for (0..256) |byte_val| {
            const seed = config.codebook_seed +% @as(u64, @intCast(byte_val)) *% 2654435761;
            encoder.codebook[byte_val] = Hypervector.random(config.dimension, seed);
        }

        return encoder;
    }

    pub fn deinit(self: *VsaShardEncoder) void {
        _ = self;
    }

    /// Encode raw bytes as a hypervector fingerprint
    /// Algorithm:
    ///   1. For each byte at position i:
    ///      a. Get codebook vector for byte value
    ///      b. Permute by position (positional encoding)
    ///   2. Accumulate all position-encoded vectors via iterative bundling
    ///   3. Result: single hypervector capturing content + position info
    pub fn encode(self: *VsaShardEncoder, data: []const u8) Hypervector {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (data.len == 0) {
            self.shards_encoded += 1;
            return Hypervector.zero(self.dimension);
        }

        // Start with first byte's codebook vector (no permute needed for pos 0)
        var accumulator = self.codebook[data[0]];

        // For each subsequent byte, permute codebook vector by position and bundle
        var i: usize = 1;
        while (i < data.len) : (i += 1) {
            const byte_vec = self.codebook[data[i]];
            // Positional encoding: permute by position index
            const pos = i % self.dimension;
            if (pos > 0) {
                const permuted = Hypervector.permute(&byte_vec, pos);
                accumulator = Hypervector.bundle2(&accumulator, &permuted);
            } else {
                accumulator = Hypervector.bundle2(&accumulator, &byte_vec);
            }
        }

        self.shards_encoded += 1;
        self.total_bytes_encoded += data.len;

        return accumulator;
    }

    /// Compute cosine similarity between two fingerprints
    pub fn similarity(self: *VsaShardEncoder, a: *const Hypervector, b: *const Hypervector) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.similarity_queries += 1;
        return Hypervector.cosineSimilarity(a, b);
    }

    /// Get encoder statistics
    pub fn getStats(self: *VsaShardEncoder) EncoderStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .shards_encoded = self.shards_encoded,
            .total_bytes_encoded = self.total_bytes_encoded,
            .similarity_queries = self.similarity_queries,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "encode same data produces same fingerprint" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const data = "Hello, Trinity Storage!";
    const fp1 = encoder.encode(data);
    const fp2 = encoder.encode(data);

    const sim = Hypervector.cosineSimilarity(&fp1, &fp2);
    try std.testing.expectEqual(@as(f64, 1.0), sim);
}

test "encode different data produces different fingerprints" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const fp1 = encoder.encode("Hello, World!");
    const fp2 = encoder.encode("Goodbye, World!");

    const sim = Hypervector.cosineSimilarity(&fp1, &fp2);
    try std.testing.expect(sim < 1.0);
}

test "similar data has higher similarity than random data" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const fp_a = encoder.encode("The quick brown fox jumps over the lazy dog");
    const fp_b = encoder.encode("The quick brown fox jumps over the lazy cat");
    const sim_similar = Hypervector.cosineSimilarity(&fp_a, &fp_b);

    const fp_c = encoder.encode("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    const sim_different = Hypervector.cosineSimilarity(&fp_a, &fp_c);

    try std.testing.expect(sim_similar > sim_different);
}

test "encode empty data returns zero vector" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const fp = encoder.encode("");
    try std.testing.expectEqual(@as(usize, 0), fp.countNonZero());
}

test "dimension configurable" {
    var encoder = VsaShardEncoder.initWithConfig(std.testing.allocator, .{
        .dimension = 512,
    });
    defer encoder.deinit();

    try std.testing.expectEqual(@as(usize, 512), encoder.dimension);

    const fp = encoder.encode("test data");
    try std.testing.expectEqual(@as(usize, 512), fp.dim);
}

test "codebook deterministic with same seed" {
    var enc1 = VsaShardEncoder.initWithConfig(std.testing.allocator, .{
        .codebook_seed = 42,
    });
    defer enc1.deinit();

    var enc2 = VsaShardEncoder.initWithConfig(std.testing.allocator, .{
        .codebook_seed = 42,
    });
    defer enc2.deinit();

    const fp1 = enc1.encode("deterministic test");
    const fp2 = enc2.encode("deterministic test");

    const sim = Hypervector.cosineSimilarity(&fp1, &fp2);
    try std.testing.expect(sim > 0.999);
}

test "different seeds produce different codebooks" {
    var enc1 = VsaShardEncoder.initWithConfig(std.testing.allocator, .{
        .codebook_seed = 42,
    });
    defer enc1.deinit();

    var enc2 = VsaShardEncoder.initWithConfig(std.testing.allocator, .{
        .codebook_seed = 99,
    });
    defer enc2.deinit();

    const fp1 = enc1.encode("same data");
    const fp2 = enc2.encode("same data");

    const sim = Hypervector.cosineSimilarity(&fp1, &fp2);
    try std.testing.expect(sim < 1.0);
}

test "stats tracking" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    _ = encoder.encode("first shard");
    _ = encoder.encode("second shard");
    _ = encoder.encode("third shard data that is longer");

    const stats = encoder.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.shards_encoded);
    try std.testing.expect(stats.total_bytes_encoded > 0);
}
