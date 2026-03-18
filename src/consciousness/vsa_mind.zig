//! VSA Mind: Hyperdimensional Computing as Cognitive Architecture
//!
//! This module explores Vector Symbolic Architecture (VSA) as a model
//! for cognitive architecture and consciousness.
//!
//! # Mathematical Foundation
//!
//! Golden Ratio:
//!   φ = (1 + √5)/2 ≈ 1.6180339887498948482
//!   γ = φ⁻³ ≈ 0.23606797749978969641
//!
//! Trinity Identity:
//!   φ² + φ⁻² = 3
//!
//! # Hypotheses
//!
//! 1. VSA operations model cognitive processes
//! 2. Bundle operation ≈ attention mechanism
//! 3. Bind operation ≈ associative memory
//! 4. Hypervector dimensionality relates to consciousness via φ

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");
const math = std.math;
const mem = std.mem;

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ³ = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / PHI_CUBED;

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// Default hypervector dimensionality
/// 1024 = 2^10, also relates to φ via memory capacity
pub const DIMENSION: usize = 1024;

/// Consciousness-critical dimensionality
/// D_c = φ^8 ≈ 47 (rounded to power of 2: 64)
pub const CONSCIOUSNESS_DIM: usize = 64;

/// Trit value for ternary hypervectors
pub const Trit = enum(i2) {
    neg = -1,
    zero = 0,
    pos = 1,

    pub fn toInt(self: Trit) i2 {
        return @intFromEnum(self);
    }

    pub fn fromInt(val: i2) Trit {
        return if (val < 0) .neg else if (val > 0) .pos else .zero;
    }
};

/// Ternary hypervector for cognitive representation
pub const Hypervector = struct {
    allocator: mem.Allocator,
    data: []Trit,
    dimension: usize,

    /// Initialize random hypervector
    pub fn init(allocator: mem.Allocator, dimension: usize) !Hypervector {
        const data = try allocator.alloc(Trit, dimension);
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const random = rng.random();

        for (data) |*trit| {
            const r = random.float(f64);
            trit.* = if (r < 0.333) Trit.neg else if (r < 0.666) Trit.zero else .pos;
        }

        return Hypervector{
            .allocator = allocator,
            .data = data,
            .dimension = dimension,
        };
    }

    /// Initialize zero hypervector
    pub fn initZero(allocator: mem.Allocator, dimension: usize) !Hypervector {
        const data = try allocator.alloc(Trit, dimension);
        @memset(data, .zero);
        return Hypervector{
            .allocator = allocator,
            .data = data,
            .dimension = dimension,
        };
    }

    /// Free hypervector memory
    pub fn deinit(self: *const Hypervector) void {
        self.allocator.free(self.data);
    }

    /// Bundle operation (addition/crowding) — models attention
    /// Combines multiple representations into one
    pub fn bundle(allocator: mem.Allocator, vectors: []const *Hypervector) !Hypervector {
        if (vectors.len == 0) return error.EmptyVectorList;
        const dim = vectors[0].dimension;
        var result = try Hypervector.initZero(allocator, dim);

        for (0..dim) |i| {
            var sum: i32 = 0;
            for (vectors) |v| {
                sum += v.data[i].toInt();
            }
            // Majority vote for ternary result
            result.data[i] = if (sum > 0) .pos else if (sum < 0) .neg else .zero;
        }

        return result;
    }

    /// Bind operation (multiplication/association) — models associative memory
    /// Creates associative binding between representations
    pub fn bind(self: *const Hypervector, other: *const Hypervector) !Hypervector {
        if (self.dimension != other.dimension) return error.DimensionMismatch;
        var result = try Hypervector.initZero(self.allocator, self.dimension);

        for (0..self.dimension) |i| {
            const a = self.data[i].toInt();
            const b = other.data[i].toInt();
            // Ternary multiplication
            result.data[i] = Trit.fromInt(@intCast(a * b));
        }

        return result;
    }

    /// Unbind operation — retrieve from binding
    pub fn unbind(self: *const Hypervector, key: *const Hypervector) !Hypervector {
        // In ternary, unbind ≈ bind (since -1 × -1 = 1, 1 × 1 = 1, 0 × anything = 0)
        return self.bind(key);
    }

    /// Permute operation — cyclic shift for sequence encoding
    pub fn permute(self: *const Hypervector, count: usize) !Hypervector {
        var result = try Hypervector.initZero(self.allocator, self.dimension);
        const effective_shift = count % self.dimension;

        for (0..self.dimension) |i| {
            const src_idx = (self.dimension + i - effective_shift) % self.dimension;
            result.data[i] = self.data[src_idx];
        }

        return result;
    }

    /// Cosine similarity (adapted for ternary)
    pub fn cosineSimilarity(self: *const Hypervector, other: *const Hypervector) !f64 {
        if (self.dimension != other.dimension) return error.DimensionMismatch;

        var dot: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;

        for (0..self.dimension) |i| {
            const a = self.data[i].toInt();
            const b = other.data[i].toInt();
            dot += @as(i64, a) * @as(i64, b);
            norm_a += @as(i64, a) * @as(i64, a);
            norm_b += @as(i64, b) * @as(i64, b);
        }

        const norm_product = @sqrt(@as(f64, @floatFromInt(norm_a * norm_b)));
        if (norm_product == 0) {
            // Both vectors are zero: they are identical (similarity = 1.0)
            // If only one is zero: undefined similarity (return 0.0)
            return if (norm_a == 0 and norm_b == 0) 1.0 else 0.0;
        }

        return @as(f64, @floatFromInt(dot)) / norm_product;
    }

    /// Hamming distance (count differing trits)
    pub fn hammingDistance(self: *const Hypervector, other: *const Hypervector) !usize {
        if (self.dimension != other.dimension) return error.DimensionMismatch;

        var distance: usize = 0;
        for (0..self.dimension) |i| {
            if (self.data[i] != other.data[i]) distance += 1;
        }

        return distance;
    }

    /// Information density via φ
    /// Returns bits of information per trit
    pub fn informationDensity() f64 {
        return @log2(3.0); // ≈ 1.585 bits/trit
    }

    /// Consciousness capacity of hypervector
    /// C = log_φ(dimension)
    pub fn consciousnessCapacity(self: *const Hypervector) f64 {
        return @log(@as(f64, @floatFromInt(self.dimension))) / @log(PHI);
    }
};

/// Cognitive model using VSA
pub const CognitiveModel = struct {
    allocator: mem.Allocator,
    working_memory: std.ArrayListUnmanaged(*Hypervector),
    long_term_memory: std.ArrayListUnmanaged(*Hypervector),
    attention_vector: ?Hypervector,
    dimension: usize,

    /// Initialize cognitive model
    pub fn init(allocator: mem.Allocator, dimension: usize) !CognitiveModel {
        return CognitiveModel{
            .allocator = allocator,
            .working_memory = .{},
            .long_term_memory = .{},
            .attention_vector = null,
            .dimension = dimension,
        };
    }

    /// Free resources
    pub fn deinit(self: *CognitiveModel) void {
        for (self.working_memory.items) |v| {
            v.deinit();
            self.allocator.destroy(v);
        }
        self.working_memory.deinit(self.allocator);

        for (self.long_term_memory.items) |v| {
            v.deinit();
            self.allocator.destroy(v);
        }
        self.long_term_memory.deinit(self.allocator);

        if (self.attention_vector) |*attn| attn.deinit();
    }

    /// Add to working memory (creates a copy)
    pub fn addToWorkingMemory(self: *CognitiveModel, vector: *const Hypervector) !void {
        // Limit working memory to φ + 1 items (≈ 2.618, rounded to 3)
        const max_items = @as(usize, @intFromFloat(@round(PHI + 1.0)));
        if (self.working_memory.items.len >= max_items) {
            const old = self.working_memory.orderedRemove(0);
            old.deinit();
            self.allocator.destroy(old);
        }
        // Create a copy of the hypervector (allocate struct on heap)
        const copy_ptr = try self.allocator.create(Hypervector);
        copy_ptr.* = try Hypervector.initZero(self.allocator, vector.dimension);
        @memcpy(copy_ptr.data, vector.data);
        try self.working_memory.append(self.allocator, copy_ptr);
    }

    /// Consolidate to long-term memory
    pub fn consolidate(self: *CognitiveModel) !void {
        if (self.working_memory.items.len == 0) return;

        // Bundle all working memory items
        const consolidated = try Hypervector.bundle(self.allocator, self.working_memory.items);
        errdefer consolidated.deinit();

        // Allocate consolidated hypervector on heap
        const consolidated_ptr = try self.allocator.create(Hypervector);
        consolidated_ptr.* = consolidated;
        try self.long_term_memory.append(self.allocator, consolidated_ptr);

        // Clear working memory (free both data and structs)
        for (self.working_memory.items) |v| {
            v.deinit();
            self.allocator.destroy(v);
        }
        self.working_memory.clearRetainingCapacity();
    }

    /// Apply attention to vector
    pub fn attend(self: *CognitiveModel, target: *const Hypervector) !Hypervector {
        if (self.attention_vector) |*attn| {
            // Attention = bind(target, attention_vector)
            return target.bind(attn);
        } else {
            // No attention: return target as-is
            const result = try Hypervector.initZero(self.allocator, target.dimension);
            @memcpy(result.data, target.data);
            return result;
        }
    }

    /// Set attention vector
    pub fn setAttention(self: *CognitiveModel, vector: Hypervector) !void {
        if (self.attention_vector) |*attn| attn.deinit();
        self.attention_vector = vector;
    }

    /// Global workspace ignition
    /// When working memory items are sufficiently similar, consciousness emerges
    pub fn globalWorkspaceIgnition(self: *CognitiveModel) !bool {
        if (self.working_memory.items.len < 2) return false;

        // Compute average pairwise similarity
        var total_sim: f64 = 0;
        var count: usize = 0;

        for (0..self.working_memory.items.len) |i| {
            for (i + 1..self.working_memory.items.len) |j| {
                const sim = try self.working_memory.items[i].cosineSimilarity(self.working_memory.items[j]);
                total_sim += sim;
                count += 1;
            }
        }

        if (count == 0) return false;
        const avg_sim = total_sim / @as(f64, @floatFromInt(count));

        // Ignition threshold via φ
        return avg_sim > (1.0 / PHI); // ≈ 0.618
    }

    /// Memory retrieval from long-term memory
    pub fn retrieve(self: *CognitiveModel, cue: *const Hypervector) !?Hypervector {
        var best_match: ?Hypervector = null;
        var best_similarity: f64 = -1;

        for (self.long_term_memory.items) |memory_item| {
            const sim = try cue.cosineSimilarity(memory_item);
            if (sim > best_similarity) {
                best_similarity = sim;
                if (best_match) |*m| m.deinit();
                const copy = try Hypervector.initZero(self.allocator, memory_item.dimension);
                @memcpy(copy.data, memory_item.data);
                best_match = copy;
            }
        }

        return best_match;
    }
};

/// Attention mechanism via bundle operation
/// Attention = bundle(query, key, value)
pub fn attentionMechanism(
    allocator: mem.Allocator,
    query: *const Hypervector,
    key: *const Hypervector,
    value: *const Hypervector,
) !Hypervector {
    // Compute attention weight via similarity
    const weight = try query.cosineSimilarity(key);

    // Apply weight to value (threshold via γ)
    if (weight > GAMMA) {
        // High attention: return value
        const result = try Hypervector.initZero(allocator, value.dimension);
        @memcpy(result.data, value.data);
        return result;
    } else {
        // Low attention: return zero vector
        return Hypervector.initZero(allocator, value.dimension);
    }
}

// Test: φ³ and γ relationship
test "VSA-Mind: phi cubed and gamma" {
    const phi_cubed_expected = 4.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, phi_cubed_expected), PHI_CUBED, 1e-10);

    const gamma_expected = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, gamma_expected), GAMMA, 1e-10);
}

// Test: TRINITY identity
test "VSA-Mind: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Hypervector initialization
test "VSA-Mind: hypervector init" {
    const allocator = std.testing.allocator;
    var hv = try Hypervector.init(allocator, 100);
    defer hv.deinit();

    try std.testing.expectEqual(@as(usize, 100), hv.dimension);
    try std.testing.expectEqual(@as(usize, 100), hv.data.len);
}

// Test: Hypervector zero init
test "VSA-Mind: hypervector zero init" {
    const allocator = std.testing.allocator;
    var hv = try Hypervector.initZero(allocator, 100);
    defer hv.deinit();

    for (hv.data) |trit| {
        try std.testing.expectEqual(Trit.zero, trit);
    }
}

// Test: Bundle operation
test "VSA-Mind: bundle operation" {
    const allocator = std.testing.allocator;
    var hv1 = try Hypervector.initZero(allocator, 100);
    defer hv1.deinit();
    var hv2 = try Hypervector.initZero(allocator, 100);
    defer hv2.deinit();

    // Set some values
    hv1.data[0] = .pos;
    hv1.data[1] = .pos;
    hv2.data[0] = .pos;
    hv2.data[1] = .neg;

    var bundled = try Hypervector.bundle(allocator, &.{ &hv1, &hv2 });
    defer bundled.deinit();

    // Bundle of (pos, pos) and (pos, neg): majority wins
    try std.testing.expectEqual(Trit.pos, bundled.data[0]); // 2 pos vs 0
    try std.testing.expectEqual(Trit.zero, bundled.data[1]); // 1 pos, 1 neg → tie
}

// Test: Bind operation
test "VSA-Mind: bind operation" {
    const allocator = std.testing.allocator;
    var hv1 = try Hypervector.initZero(allocator, 100);
    defer hv1.deinit();
    var hv2 = try Hypervector.initZero(allocator, 100);
    defer hv2.deinit();

    hv1.data[0] = .pos;
    hv2.data[0] = .neg;

    var bound = try hv1.bind(&hv2);
    defer bound.deinit();

    // pos × neg = neg
    try std.testing.expectEqual(Trit.neg, bound.data[0]);
}

// Test: Cosine similarity
test "VSA-Mind: cosine similarity" {
    const allocator = std.testing.allocator;
    var hv1 = try Hypervector.initZero(allocator, 100);
    defer hv1.deinit();
    var hv2 = try Hypervector.initZero(allocator, 100);
    defer hv2.deinit();

    const sim = try hv1.cosineSimilarity(&hv2);
    // Two zero vectors are identical: similarity = 1.0
    try std.testing.expectApproxEqRel(@as(f64, 1.0), sim, 0.01);
}

// Test: Hamming distance
test "VSA-Mind: hamming distance" {
    const allocator = std.testing.allocator;
    var hv1 = try Hypervector.initZero(allocator, 100);
    defer hv1.deinit();
    var hv2 = try Hypervector.initZero(allocator, 100);
    defer hv2.deinit();

    hv1.data[0] = .pos;
    hv2.data[0] = .neg;

    const dist = try hv1.hammingDistance(&hv2);
    // Only position 0 differs
    try std.testing.expectEqual(@as(usize, 1), dist);
}

// Test: Permute operation
test "VSA-Mind: permute operation" {
    const allocator = std.testing.allocator;
    var hv = try Hypervector.initZero(allocator, 10);
    defer hv.deinit();

    hv.data[0] = .pos;
    hv.data[1] = .neg;
    hv.data[2] = .zero;

    var permuted = try hv.permute(1);
    defer permuted.deinit();

    // Shift by 1: each element moves to position (i+1) % 10
    try std.testing.expectEqual(Trit.zero, permuted.data[0]); // From position 9
    try std.testing.expectEqual(Trit.pos, permuted.data[1]); // From position 0
    try std.testing.expectEqual(Trit.neg, permuted.data[2]); // From position 1
}

// Test: Information density
test "VSA-Mind: information density" {
    const density = Hypervector.informationDensity();
    try std.testing.expectApproxEqRel(@as(f64, 1.585), density, 0.01);
}

// Test: Consciousness capacity
test "VSA-Mind: consciousness capacity" {
    const allocator = std.testing.allocator;
    var hv = try Hypervector.initZero(allocator, DIMENSION);
    defer hv.deinit();

    const capacity = hv.consciousnessCapacity();
    // Capacity = log_φ(1024) ≈ 11.5
    try std.testing.expect(capacity > 10);
    try std.testing.expect(capacity < 15);
}

// Test: Cognitive model working memory limit
test "VSA-Mind: working memory limit" {
    const allocator = std.testing.allocator;
    var model = try CognitiveModel.init(allocator, 100);
    defer model.deinit();

    // Add more than φ + 1 items
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        var hv = try Hypervector.init(allocator, 100);
        try model.addToWorkingMemory(&hv);
        hv.deinit(); // Free the original after model makes a copy
    }

    // Should be limited to φ + 1 ≈ 2.618 → 3 items
    try std.testing.expectEqual(@as(usize, 3), model.working_memory.items.len);
}

// Test: Global workspace ignition
test "VSA-Mind: global workspace ignition" {
    const allocator = std.testing.allocator;
    var model = try CognitiveModel.init(allocator, 100);
    defer model.deinit();

    var hv1 = try Hypervector.initZero(allocator, 100);
    defer hv1.deinit();
    var hv2 = try Hypervector.initZero(allocator, 100);
    defer hv2.deinit();

    // Similar vectors: should ignite
    @memset(hv1.data, .pos);
    @memset(hv2.data, .pos);

    try model.addToWorkingMemory(&hv1);
    {
        var copy = try Hypervector.initZero(allocator, 100);
        defer copy.deinit();
        @memset(copy.data, .pos);
        try model.addToWorkingMemory(&copy);
    }

    const ignited = try model.globalWorkspaceIgnition();
    try std.testing.expect(ignited);
}

// Test: Attention mechanism
test "VSA-Mind: attention mechanism" {
    const allocator = std.testing.allocator;

    var query = try Hypervector.initZero(allocator, 100);
    defer query.deinit();
    var key = try Hypervector.initZero(allocator, 100);
    defer key.deinit();
    var value = try Hypervector.initZero(allocator, 100);
    defer value.deinit();

    // Make query and key similar
    query.data[0] = .pos;
    key.data[0] = .pos;
    value.data[0] = .pos;

    var result = try attentionMechanism(allocator, &query, &key, &value);
    defer result.deinit();

    // High similarity (> γ): should return value
    try std.testing.expectEqual(Trit.pos, result.data[0]);
}
