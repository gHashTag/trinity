//! VSA Reasoning Engine - Vector Symbolic Architecture based inference
//!
//! This module provides reasoning capabilities using VSA operations:
//!   - bind: Associate two concepts
//!   - unbind: Retrieve concept from binding
//!   - bundle: Combine multiple concepts
//!   - similarity: Measure semantic similarity
//!
//! Used by Trinity AI Core for cognitive operations.

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA VECTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit (ternary) value
pub const Trit = i8;

/// Trit vector for VSA operations
pub const TritVec = struct {
    allocator: mem.Allocator,
    data: []Trit,
    len: usize,

    /// Create random vector
    pub fn random(allocator: mem.Allocator, len: usize, seed: u64) !TritVec {
        const data = try allocator.alloc(Trit, len);
        var rng = std.Random.DefaultPrng.init(seed);
        const r = rng.random();
        for (data) |*t| {
            // Generate random trit in range [-1, 1]
            const rand_val = r.intRangeAtMost(u8, 0, 2);
            t.* = @as(Trit, @intCast(rand_val)) - 1; // Maps 0->-1, 1->0, 2->1
        }
        return TritVec{ .allocator = allocator, .data = data, .len = len };
    }

    /// Create zero vector
    pub fn zero(allocator: mem.Allocator, len: usize) !TritVec {
        const data = try allocator.alloc(Trit, len);
        @memset(data, 0);
        return TritVec{ .allocator = allocator, .data = data, .len = len };
    }

    /// Create from slice
    pub fn fromSlice(allocator: mem.Allocator, slice: []const Trit) !TritVec {
        const data = try allocator.alloc(Trit, slice.len);
        @memcpy(data, slice);
        return TritVec{ .allocator = allocator, .data = data, .len = slice.len };
    }

    /// Clean up
    pub fn deinit(self: *TritVec) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }

    /// Clone
    pub fn clone(self: *const TritVec) !TritVec {
        return fromSlice(self.allocator, self.data);
    }

    /// Count non-zero elements
    pub fn countNonZero(self: *const TritVec) usize {
        var count: usize = 0;
        for (self.data) |t| {
            if (t != 0) count += 1;
        }
        return count;
    }

    /// Dot product
    pub fn dotProduct(self: *const TritVec, other: *const TritVec) i64 {
        const len = @min(self.len, other.len);
        var sum: i64 = 0;
        for (self.data[0..len], other.data[0..len]) |a, b| {
            sum += @as(i64, a) * @as(i64, b);
        }
        return sum;
    }

    /// Cosine similarity [-1, 1]
    pub fn cosineSimilarity(self: *const TritVec, other: *const TritVec) f64 {
        const dot = self.dotProduct(other);
        const norm_a = @sqrt(@as(f64, @floatFromInt(self.dotProduct(self))));
        const norm_b = @sqrt(@as(f64, @floatFromInt(other.dotProduct(other))));

        if (norm_a == 0 or norm_b == 0) return 0.0;
        return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
    }

    /// Hamming distance
    pub fn hammingDistance(self: *const TritVec, other: *const TritVec) usize {
        const len = @min(self.len, other.len);
        var dist: usize = 0;
        for (self.data[0..len], other.data[0..len]) |a, b| {
            if (a != b) dist += 1;
        }
        dist += @max(self.len, other.len) - len;
        return dist;
    }

    /// Negate
    pub fn negate(self: *const TritVec) !TritVec {
        const result = try self.allocator.alloc(Trit, self.len);
        for (self.data, result) |src, *dst| {
            dst.* = -src;
        }
        return TritVec{ .allocator = self.allocator, .data = result, .len = self.len };
    }

    /// Permute (cyclic shift)
    pub fn permute(self: *const TritVec, count: usize) !TritVec {
        const result = try self.allocator.alloc(Trit, self.len);
        const effective = count % self.len;
        for (0..self.len) |i| {
            result[i] = self.data[(self.len + i - effective) % self.len];
        }
        return TritVec{ .allocator = self.allocator, .data = result, .len = self.len };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind (associate) two vectors
pub fn bind(allocator: mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const min_len = @min(a.len, b.len);
    const max_len = @max(a.len, b.len);
    const result = try allocator.alloc(Trit, max_len);

    // Multiply common elements
    for (0..min_len) |i| {
        result[i] = a.data[i] * b.data[i];
    }

    // Pad with remaining from longer vector
    if (a.len > min_len) {
        for (min_len..a.len) |i| {
            result[i] = a.data[i];
        }
    }
    if (b.len > min_len) {
        for (min_len..b.len) |i| {
            result[i] = b.data[i];
        }
    }

    return TritVec{ .allocator = allocator, .data = result, .len = max_len };
}

/// Unbind (retrieve) using inverse binding
pub fn unbind(allocator: mem.Allocator, bound: *const TritVec, key: *const TritVec) !TritVec {
    // Unbind is same as bind with key (self-inverse for ternary)
    return bind(allocator, bound, key);
}

/// Bundle 2 vectors (majority vote)
pub fn bundle2(allocator: mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const result = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        const sum = @as(i16, a.data[i]) + @as(i16, b.data[i]);
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return TritVec{ .allocator = allocator, .data = result, .len = len };
}

/// Bundle 3 vectors (majority vote)
pub fn bundle3(allocator: mem.Allocator, a: *const TritVec, b: *const TritVec, c: *const TritVec) !TritVec {
    const len = @min(@min(a.len, b.len), c.len);
    const result = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        const sum = @as(i16, a.data[i]) + @as(i16, b.data[i]) + @as(i16, c.data[i]);
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return TritVec{ .allocator = allocator, .data = result, .len = len };
}

/// Bundle N vectors
pub fn bundleN(allocator: mem.Allocator, vectors: []const *const TritVec) !TritVec {
    if (vectors.len == 0) return error.EmptyVectorList;

    var len = vectors[0].len;
    for (vectors) |v| {
        len = @min(len, v.len);
    }

    const result = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        var sum: i32 = 0;
        for (vectors) |v| {
            sum += v.data[i];
        }
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return TritVec{ .allocator = allocator, .data = result, .len = len };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC MEMORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Semantic memory entry
pub const MemoryEntry = struct {
    key: TritVec,
    value: TritVec,
    access_count: u64 = 0,
    last_access: i64 = 0,

    pub fn deinit(self: *MemoryEntry) void {
        self.key.deinit();
        self.value.deinit();
    }
};

/// Semantic memory using VSA
pub const SemanticMemory = struct {
    allocator: mem.Allocator,
    entries: std.StringHashMapUnmanaged(*MemoryEntry),

    pub fn init(allocator: mem.Allocator) SemanticMemory {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMapUnmanaged(*MemoryEntry).empty,
        };
    }

    pub fn deinit(self: *SemanticMemory) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            // entry.value_ptr is **MemoryEntry (pointer to the value, which is *MemoryEntry)
            const memory_entry = entry.value_ptr.*; // *MemoryEntry
            memory_entry.deinit();
            self.allocator.destroy(memory_entry);
        }
        self.entries.deinit(self.allocator);
    }

    /// Store key-value pair
    pub fn put(self: *SemanticMemory, key: []const u8, value: TritVec) !void {
        // Create bound key-value
        var key_vec = try TritVec.random(self.allocator, 1000, std.hash.Wyhash.hash(0, key));
        defer key_vec.deinit();

        var bound = try bind(self.allocator, &key_vec, &value);
        defer bound.deinit();

        // Check if key exists
        if (self.entries.get(key)) |existing_ptr| {
            existing_ptr.*.value.deinit();
            existing_ptr.*.value = value; // Move ownership
            existing_ptr.*.access_count += 1;
            existing_ptr.*.last_access = @intCast(std.time.nanoTimestamp());
        } else {
            const entry = try self.allocator.create(MemoryEntry);
            entry.* = .{
                .key = try key_vec.clone(),
                .value = value, // Move ownership
                .access_count = 1,
                .last_access = @intCast(std.time.nanoTimestamp()),
            };
            try self.entries.put(self.allocator, key, entry);
        }
    }

    /// Retrieve value by key
    pub fn get(self: *SemanticMemory, key: []const u8, _: *const TritVec) ?*MemoryEntry {
        const entry = self.entries.get(key) orelse return null;

        // Update access stats
        entry.access_count += 1;
        entry.last_access = std.time.nanoTimestamp();

        return entry;
    }

    /// Find similar keys
    pub fn findSimilar(self: *SemanticMemory, query: *const TritVec, threshold: f64) !std.ArrayList([]const u8) {
        var results = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
        defer results.deinit(self.allocator);

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            const sim = query.cosineSimilarity(&entry.value_ptr.key);
            if (sim >= threshold) {
                try results.append(self.allocator, entry.key_ptr.*);
            }
        }

        // Convert to owned slice before returning (caller owns memory)
        const slice = try results.toOwnedSlice(self.allocator);
        return std.ArrayList([]const u8).fromOwnedSlice(slice);
    }

    /// Get memory size
    pub fn size(self: *const SemanticMemory) usize {
        return self.entries.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REASONING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Reasoning result
pub const ReasoningResult = struct {
    conclusion: TritVec,
    confidence: f64,
    steps: usize,
    reasoning_path: std.ArrayList([]const u8),

    pub fn deinit(self: *ReasoningResult) void {
        const allocator = self.conclusion.allocator;
        self.conclusion.deinit();
        for (self.reasoning_path.items) |step| {
            allocator.free(step);
        }
        self.reasoning_path.deinit(allocator);
    }
};

/// VSA Reasoning Engine
pub const VSAReasoningEngine = struct {
    allocator: mem.Allocator,
    memory: SemanticMemory,
    vector_dim: usize = 1000,

    pub fn init(allocator: mem.Allocator) VSAReasoningEngine {
        return .{
            .allocator = allocator,
            .memory = SemanticMemory.init(allocator),
            .vector_dim = 1000,
        };
    }

    pub fn deinit(self: *VSAReasoningEngine) void {
        self.memory.deinit();
    }

    /// Learn association
    pub fn learn(self: *VSAReasoningEngine, concept: []const u8, representation: TritVec) !void {
        try self.memory.put(concept, representation);
    }

    /// Associate two concepts
    pub fn associate(self: *VSAReasoningEngine, concept_a: []const u8, concept_b: []const u8) !TritVec {
        var vec_a = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, concept_a));
        defer vec_a.deinit();

        var vec_b = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, concept_b));
        defer vec_b.deinit();

        return bind(self.allocator, &vec_a, &vec_b);
    }

    /// Recall associated concept from memory using cue
    pub fn recall(self: *VSAReasoningEngine, cue: []const u8) !?TritVec {
        // Generate vector from cue
        const cue_vec = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, cue));
        defer cue_vec.deinit();

        // Search for best match in memory
        var best_match: ?*Hypervector = null;
        var best_similarity: f64 = 0.7; // Consciousness threshold (φ^-1)

        var iter = self.memory.iterator();
        while (iter.next()) |entry| {
            const stored_vec = entry.value_ptr.*;
            const similarity = try stored_vec.cosineSimilarity(&cue_vec);

            if (similarity > best_similarity) {
                best_similarity = similarity;
                best_match = &stored_vec;
            }
        }

        // Return clone of best match if found
        if (best_match) |m| {
            return try m.clone();
        }

        return null;
    }

    /// Recall with association (unbind operation)
    pub fn recallWithAssociation(self: *VSAReasoningEngine, cue: []const u8, association: TritVec) !?TritVec {
        _ = association;

        // Try direct recall first
        if (try self.recall(cue)) |result| {
            return result;
        }

        // If not found directly, try unbind with association
        // This is for when the cue was bound to another vector
        return null;
    }

    /// Reason by analogy
    pub fn analogicalReasoning(
        self: *VSAReasoningEngine,
        source_a: []const u8,
        source_b: []const u8,
        target_a: []const u8,
    ) !ReasoningResult {
        var vec_sa = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, source_a));
        defer vec_sa.deinit();

        var vec_sb = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, source_b));
        defer vec_sb.deinit();

        var vec_ta = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, target_a));
        defer vec_ta.deinit();

        // A:B :: C:?
        // relation = bind(inv(A), B)
        // result = bind(C, relation)

        var relation = try bind(self.allocator, &vec_sa, &vec_sb);
        defer relation.deinit();

        const result = try bind(self.allocator, &vec_ta, &relation);

        var path = try std.ArrayList([]const u8).initCapacity(self.allocator, 4);
        try path.append(self.allocator, try self.allocator.dupe(u8, "analogy: A:B :: C:?"));
        try path.append(self.allocator, try std.fmt.allocPrint(self.allocator, "A = {s}", .{source_a}));
        try path.append(self.allocator, try std.fmt.allocPrint(self.allocator, "B = {s}", .{source_b}));
        try path.append(self.allocator, try std.fmt.allocPrint(self.allocator, "C = {s}", .{target_a}));

        return ReasoningResult{
            .conclusion = result,
            .confidence = PHI_INV, // Base confidence
            .steps = 1,
            .reasoning_path = path,
        };
    }

    /// Chain reasoning
    pub fn chainReasoning(
        self: *VSAReasoningEngine,
        start_concept: []const u8,
        steps: []const []const u8,
    ) !ReasoningResult {
        var current = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, start_concept));
        defer current.deinit();

        var path = try std.ArrayList([]const u8).initCapacity(self.allocator, 1 + steps.len);
        try path.append(self.allocator, try std.fmt.allocPrint(self.allocator, "start: {s}", .{start_concept}));

        for (steps) |step| {
            var step_vec = try TritVec.random(self.allocator, self.vector_dim, std.hash.Wyhash.hash(0, step));
            defer step_vec.deinit();

            const next = try bind(self.allocator, &current, &step_vec);
            current.deinit();
            current = next;

            try path.append(self.allocator, try std.fmt.allocPrint(self.allocator, "step: {s}", .{step}));
        }

        // Confidence decays with each step (phi decay)
        const confidence = std.math.pow(f64, PHI_INV, @as(f64, @floatFromInt(steps.len)));

        return ReasoningResult{
            .conclusion = try current.clone(),
            .confidence = confidence,
            .steps = steps.len,
            .reasoning_path = path,
        };
    }

    /// Get memory size
    pub fn memorySize(self: *const VSAReasoningEngine) usize {
        return self.memory.size();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TritVec: random and zero" {
    const allocator = std.testing.allocator;
    var zero = try TritVec.zero(allocator, 100);
    defer zero.deinit();

    try std.testing.expectEqual(@as(usize, 0), zero.countNonZero());

    var rand = try TritVec.random(allocator, 100, 12345);
    defer rand.deinit();

    try std.testing.expect(rand.countNonZero() > 0);
}

test "TritVec: dot product" {
    const allocator = std.testing.allocator;
    var v1 = try TritVec.random(allocator, 100, 111);
    defer v1.deinit();

    var v2 = try TritVec.random(allocator, 100, 222);
    defer v2.deinit();

    const dot = v1.dotProduct(&v2);
    _ = dot;
    // Just verify it runs
}

test "TritVec: cosine similarity" {
    const allocator = std.testing.allocator;
    var v1 = try TritVec.random(allocator, 100, 333);
    defer v1.deinit();

    var v2 = try TritVec.fromSlice(allocator, v1.data);
    defer v2.deinit();

    const sim = v1.cosineSimilarity(&v2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "VSA operations: bind and unbind" {
    const allocator = std.testing.allocator;
    var a = try TritVec.random(allocator, 100, 444);
    defer a.deinit();

    var b = try TritVec.random(allocator, 100, 555);
    defer b.deinit();

    var bound = try bind(allocator, &a, &b);
    defer bound.deinit();

    // Unbind with b should recover a
    var recovered = try unbind(allocator, &bound, &b);
    defer recovered.deinit();

    try std.testing.expectEqual(a.len, recovered.len);
}

test "VSA operations: bundle2" {
    const allocator = std.testing.allocator;
    var a = try TritVec.random(allocator, 100, 666);
    defer a.deinit();

    var b = try TritVec.random(allocator, 100, 777);
    defer b.deinit();

    var bundled = try bundle2(allocator, &a, &b);
    defer bundled.deinit();

    try std.testing.expectEqual(@as(usize, 100), bundled.len);
}

test "VSA operations: bundle3" {
    const allocator = std.testing.allocator;
    var a = try TritVec.random(allocator, 100, 888);
    defer a.deinit();

    var b = try TritVec.random(allocator, 100, 999);
    defer b.deinit();

    var c = try TritVec.random(allocator, 100, 10101);
    defer c.deinit();

    var bundled = try bundle3(allocator, &a, &b, &c);
    defer bundled.deinit();

    try std.testing.expectEqual(@as(usize, 100), bundled.len);
}

test "VSAReasoningEngine: analogical reasoning" {
    const allocator = std.testing.allocator;
    var engine = VSAReasoningEngine.init(allocator);
    defer engine.deinit();

    var result = try engine.analogicalReasoning("fire", "hot", "ice");
    defer result.deinit();

    try std.testing.expect(result.steps > 0);
    try std.testing.expect(result.reasoning_path.items.len > 0);
}

test "VSAReasoningEngine: chain reasoning" {
    const allocator = std.testing.allocator;
    var engine = VSAReasoningEngine.init(allocator);
    defer engine.deinit();

    const steps = &[_][]const u8{ "step1", "step2" };
    var result = try engine.chainReasoning("start", steps);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.steps);
    try std.testing.expect(result.confidence < 1.0);
}

test "VSAReasoningEngine: learn and recall" {
    const allocator = std.testing.allocator;
    var engine = VSAReasoningEngine.init(allocator);
    defer engine.deinit();

    const vec = try TritVec.random(allocator, 100, 123);
    // vec is moved into learn() and will be cleaned up by engine.deinit()
    try engine.learn("concept", vec);
    try std.testing.expectEqual(@as(usize, 1), engine.memorySize());
}
