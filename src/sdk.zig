// Trinity SDK - High-level API for Developers
// Simplified interface for hyperdimensional computing applications
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const trinity = @import("trinity.zig");
const vsa = @import("vsa.zig");

pub const HybridBigInt = trinity.HybridBigInt;
pub const Trit = trinity.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// HYPERVECTOR - Main abstraction for developers
// ═══════════════════════════════════════════════════════════════════════════════

/// Hypervector - high-level wrapper around HybridBigInt
/// Provides intuitive API for VSA operations
pub const Hypervector = struct {
    data: HybridBigInt,
    label: ?[]const u8 = null,

    const Self = @This();

    /// Create zero hypervector with given dimension
    pub fn init(dim: usize) Self {
        var hv = HybridBigInt.zero();
        hv.mode = .unpacked_mode;
        hv.trit_len = @min(dim, vsa.MAX_TRITS);
        return Self{ .data = hv };
    }

    /// Create random hypervector (for atomic symbols)
    pub fn random(dim: usize, seed: u64) Self {
        return Self{ .data = vsa.randomVector(dim, seed) };
    }

    /// Create random hypervector with label
    pub fn randomLabeled(dim: usize, seed: u64, label: []const u8) Self {
        return Self{
            .data = vsa.randomVector(dim, seed),
            .label = label,
        };
    }

    /// Create from existing HybridBigInt
    pub fn fromRaw(raw: HybridBigInt) Self {
        return Self{ .data = raw };
    }

    /// Get dimension (number of trits)
    pub fn getDimension(self: *Self) usize {
        return self.data.trit_len;
    }

    /// Get trit at position
    pub fn get(self: *Self, index: usize) Trit {
        self.data.ensureUnpacked();
        if (index >= self.data.trit_len) return 0;
        return self.data.unpacked_cache[index];
    }

    /// Set trit at position
    pub fn set(self: *Self, index: usize, value: Trit) void {
        self.data.ensureUnpacked();
        if (index < self.data.trit_len) {
            self.data.unpacked_cache[index] = value;
            self.data.dirty = true;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VSA OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Bind two hypervectors (creates association)
    /// bind(A, B) represents "A associated with B"
    /// Properties: self-inverse, preserves similarity
    pub fn bind(self: *Self, other: *Self) Self {
        return Self{ .data = vsa.bind(&self.data, &other.data) };
    }

    /// Unbind (inverse of bind)
    /// unbind(bind(A, B), B) = A
    pub fn unbind(self: *Self, key: *Self) Self {
        return Self{ .data = vsa.unbind(&self.data, &key.data) };
    }

    /// Bundle two hypervectors (creates superposition)
    /// bundle(A, B) is similar to both A and B
    pub fn bundle(self: *Self, other: *Self) Self {
        return Self{ .data = vsa.bundle2(&self.data, &other.data) };
    }

    /// Bundle three hypervectors
    pub fn bundle3(self: *Self, b: *Self, c: *Self) Self {
        return Self{ .data = vsa.bundle3(&self.data, &b.data, &c.data) };
    }

    /// Permute (cyclic shift) - for sequence encoding
    /// permute(A, k) shifts A by k positions
    pub fn permute(self: *Self, k: usize) Self {
        return Self{ .data = vsa.permute(&self.data, k) };
    }

    /// Inverse permute
    pub fn inversePermute(self: *Self, k: usize) Self {
        return Self{ .data = vsa.inversePermute(&self.data, k) };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SIMILARITY MEASURES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Cosine similarity [-1, 1]
    pub fn similarity(self: *Self, other: *Self) f64 {
        return vsa.cosineSimilarity(&self.data, &other.data);
    }

    /// Hamming distance (number of differing trits)
    pub fn hammingDistance(self: *Self, other: *Self) usize {
        return vsa.hammingDistance(&self.data, &other.data);
    }

    /// Hamming similarity [0, 1]
    pub fn hammingSimilarity(self: *Self, other: *Self) f64 {
        return vsa.hammingSimilarity(&self.data, &other.data);
    }

    /// Dot product similarity
    pub fn dotSimilarity(self: *Self, other: *Self) f64 {
        return vsa.dotSimilarity(&self.data, &other.data);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // UTILITY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Count non-zero trits (sparsity measure)
    pub fn countNonZero(self: *Self) usize {
        return vsa.countNonZero(&self.data);
    }

    /// Density (ratio of non-zero trits)
    pub fn density(self: *Self) f64 {
        if (self.data.trit_len == 0) return 0;
        return @as(f64, @floatFromInt(self.countNonZero())) /
            @as(f64, @floatFromInt(self.data.trit_len));
    }

    /// Clone hypervector
    pub fn clone(self: *Self) Self {
        self.data.ensureUnpacked();
        var result = HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.trit_len = self.data.trit_len;
        result.dirty = true;

        for (0..self.data.trit_len) |i| {
            result.unpacked_cache[i] = self.data.unpacked_cache[i];
        }

        return Self{ .data = result, .label = self.label };
    }

    /// Negate all trits
    pub fn negate(self: *Self) Self {
        self.data.ensureUnpacked();
        var result = HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.trit_len = self.data.trit_len;
        result.dirty = true;

        for (0..self.data.trit_len) |i| {
            result.unpacked_cache[i] = -self.data.unpacked_cache[i];
        }

        return Self{ .data = result };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODEBOOK - Symbol table for encoding/decoding
// ═══════════════════════════════════════════════════════════════════════════════

/// Codebook for mapping symbols to hypervectors
pub const Codebook = struct {
    entries: std.StringHashMap(Hypervector),
    dimension: usize,
    seed_counter: u64,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dimension: usize) Self {
        return Self{
            .entries = std.StringHashMap(Hypervector).init(allocator),
            .dimension = dimension,
            .seed_counter = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit();
    }

    /// Get or create hypervector for symbol
    pub fn encode(self: *Self, symbol: []const u8) !*Hypervector {
        if (self.entries.getPtr(symbol)) |hv| {
            return hv;
        }

        // Create new random hypervector for this symbol
        self.seed_counter += 1;
        const seed = std.hash.Wyhash.hash(self.seed_counter, symbol);
        const hv = Hypervector.randomLabeled(self.dimension, seed, symbol);

        try self.entries.put(symbol, hv);
        return self.entries.getPtr(symbol).?;
    }

    /// Decode hypervector to nearest symbol
    pub fn decode(self: *Self, query: *Hypervector) ?[]const u8 {
        var best_symbol: ?[]const u8 = null;
        var best_similarity: f64 = -2.0;

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            const hv = entry.value_ptr;
            const sim = query.similarity(hv);
            if (sim > best_similarity) {
                best_similarity = sim;
                best_symbol = entry.key_ptr.*;
            }
        }

        return best_symbol;
    }

    /// Decode with similarity threshold
    pub fn decodeWithThreshold(self: *Self, query: *Hypervector, threshold: f64) ?[]const u8 {
        var best_symbol: ?[]const u8 = null;
        var best_similarity: f64 = -2.0;

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            const hv = entry.value_ptr;
            const sim = query.similarity(hv);
            if (sim > best_similarity) {
                best_similarity = sim;
                best_symbol = entry.key_ptr.*;
            }
        }

        if (best_similarity >= threshold) {
            return best_symbol;
        }
        return null;
    }

    /// Get all symbols with similarity above threshold
    pub fn findSimilar(self: *Self, query: *Hypervector, threshold: f64, results: *std.ArrayList(SimilarityResult)) !void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            const hv = entry.value_ptr;
            const sim = query.similarity(hv);
            if (sim >= threshold) {
                try results.append(SimilarityResult{
                    .symbol = entry.key_ptr.*,
                    .similarity = sim,
                });
            }
        }
    }

    /// Number of symbols in codebook
    pub fn count(self: *Self) usize {
        return self.entries.count();
    }
};

pub const SimilarityResult = struct {
    symbol: []const u8,
    similarity: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY - Associative memory for storage and retrieval
// ═══════════════════════════════════════════════════════════════════════════════

/// Associative Memory using bundled hypervectors
pub const AssociativeMemory = struct {
    memory: Hypervector,
    item_count: usize,
    dimension: usize,

    const Self = @This();

    pub fn init(dimension: usize) Self {
        return Self{
            .memory = Hypervector.init(dimension),
            .item_count = 0,
            .dimension = dimension,
        };
    }

    /// Store key-value pair
    /// Internally: memory = bundle(memory, bind(key, value))
    pub fn store(self: *Self, key: *Hypervector, value: *Hypervector) void {
        var association = key.bind(value);
        self.memory = self.memory.bundle(&association);
        self.item_count += 1;
    }

    /// Retrieve value by key
    /// Returns hypervector similar to stored value
    pub fn retrieve(self: *Self, key: *Hypervector) Hypervector {
        return self.memory.unbind(key);
    }

    /// Check if key exists (similarity above threshold)
    pub fn contains(self: *Self, key: *Hypervector, threshold: f64) bool {
        var retrieved = self.retrieve(key);
        // Check if retrieved vector has significant structure
        return retrieved.density() > threshold;
    }

    /// Clear memory
    pub fn clear(self: *Self) void {
        self.memory = Hypervector.init(self.dimension);
        self.item_count = 0;
    }

    /// Number of stored items
    pub fn count(self: *Self) usize {
        return self.item_count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCE ENCODER - For ordered data
// ═══════════════════════════════════════════════════════════════════════════════

/// Sequence encoder using permutation
pub const SequenceEncoder = struct {
    dimension: usize,

    const Self = @This();

    pub fn init(dimension: usize) Self {
        return Self{ .dimension = dimension };
    }

    /// Encode sequence of hypervectors
    /// sequence([A, B, C]) = A + permute(B, 1) + permute(C, 2)
    pub fn encode(self: *Self, items: []Hypervector) Hypervector {
        _ = self;
        if (items.len == 0) return Hypervector.init(0);

        var result = items[0].clone();

        for (1..items.len) |i| {
            var permuted = items[i].permute(i);
            result = result.bundle(&permuted);
        }

        return result;
    }

    /// Probe sequence for element at position
    /// Returns similarity score
    pub fn probe(self: *Self, sequence: *Hypervector, candidate: *Hypervector, position: usize) f64 {
        _ = self;
        var permuted = candidate.permute(position);
        return sequence.similarity(&permuted);
    }

    /// Find position of element in sequence
    /// Returns position with highest similarity, or null if below threshold
    pub fn findPosition(self: *Self, sequence: *Hypervector, candidate: *Hypervector, max_length: usize, threshold: f64) ?usize {
        var best_pos: ?usize = null;
        var best_sim: f64 = threshold;

        for (0..max_length) |pos| {
            const sim = self.probe(sequence, candidate, pos);
            if (sim > best_sim) {
                best_sim = sim;
                best_pos = pos;
            }
        }

        return best_pos;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GRAPH ENCODER - For relational data
// ═══════════════════════════════════════════════════════════════════════════════

/// Graph encoder for relational structures
pub const GraphEncoder = struct {
    dimension: usize,
    role_subject: Hypervector,
    role_predicate: Hypervector,
    role_object: Hypervector,

    const Self = @This();

    pub fn init(dim: usize) Self {
        return Self{
            .dimension = dim,
            .role_subject = Hypervector.random(dim, 0x5B),
            .role_predicate = Hypervector.random(dim, 0x9D),
            .role_object = Hypervector.random(dim, 0x0B),
        };
    }

    /// Encode triple (subject, predicate, object)
    /// triple = bind(role_s, subject) + bind(role_p, predicate) + bind(role_o, object)
    pub fn encodeTriple(self: *Self, subject: *Hypervector, predicate: *Hypervector, object: *Hypervector) Hypervector {
        var s_bound = self.role_subject.bind(subject);
        var p_bound = self.role_predicate.bind(predicate);
        var o_bound = self.role_object.bind(object);

        var temp = s_bound.bundle(&p_bound);
        return temp.bundle(&o_bound);
    }

    /// Query subject from triple
    pub fn querySubject(self: *Self, triple: *Hypervector) Hypervector {
        return triple.unbind(&self.role_subject);
    }

    /// Query predicate from triple
    pub fn queryPredicate(self: *Self, triple: *Hypervector) Hypervector {
        return triple.unbind(&self.role_predicate);
    }

    /// Query object from triple
    pub fn queryObject(self: *Self, triple: *Hypervector) Hypervector {
        return triple.unbind(&self.role_object);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLASSIFIER - Simple HDC classifier
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple HDC classifier
pub const Classifier = struct {
    class_vectors: std.StringHashMap(Hypervector),
    dimension: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dimension: usize) Self {
        return Self{
            .class_vectors = std.StringHashMap(Hypervector).init(allocator),
            .dimension = dimension,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.class_vectors.deinit();
    }

    /// Train: add sample to class
    pub fn train(self: *Self, class_name: []const u8, sample: *Hypervector) !void {
        if (self.class_vectors.getPtr(class_name)) |class_hv| {
            class_hv.* = class_hv.bundle(sample);
        } else {
            try self.class_vectors.put(class_name, sample.clone());
        }
    }

    /// Predict class for sample
    pub fn predict(self: *Self, sample: *Hypervector) ?[]const u8 {
        var best_class: ?[]const u8 = null;
        var best_similarity: f64 = -2.0;

        var iter = self.class_vectors.iterator();
        while (iter.next()) |entry| {
            const class_hv = entry.value_ptr;
            const sim = sample.similarity(class_hv);
            if (sim > best_similarity) {
                best_similarity = sim;
                best_class = entry.key_ptr.*;
            }
        }

        return best_class;
    }

    /// Predict with confidence score
    pub fn predictWithConfidence(self: *Self, sample: *Hypervector) struct { class: ?[]const u8, confidence: f64 } {
        var best_class: ?[]const u8 = null;
        var best_similarity: f64 = -2.0;

        var iter = self.class_vectors.iterator();
        while (iter.next()) |entry| {
            const class_hv = entry.value_ptr;
            const sim = sample.similarity(class_hv);
            if (sim > best_similarity) {
                best_similarity = sim;
                best_class = entry.key_ptr.*;
            }
        }

        return .{ .class = best_class, .confidence = best_similarity };
    }

    /// Number of classes
    pub fn classCount(self: *Self) usize {
        return self.class_vectors.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Hypervector basic operations" {
    var a = Hypervector.random(256, 12345);
    var b = Hypervector.random(256, 67890);

    // Self-similarity should be 1.0
    const self_sim = a.similarity(&a);
    try std.testing.expect(self_sim > 0.99);

    // Random vectors should be nearly orthogonal
    const cross_sim = a.similarity(&b);
    try std.testing.expect(cross_sim < 0.3);
    try std.testing.expect(cross_sim > -0.3);
}

test "Hypervector bind/unbind" {
    var a = Hypervector.random(256, 11111);
    var b = Hypervector.random(256, 22222);

    // bind then unbind should recover original
    var bound = a.bind(&b);
    var recovered = bound.unbind(&b);

    const sim = a.similarity(&recovered);
    try std.testing.expect(sim > 0.99);
}

test "Hypervector bundle" {
    var a = Hypervector.random(256, 33333);
    var b = Hypervector.random(256, 44444);

    var bundled = a.bundle(&b);

    // Bundled should be similar to both inputs
    const sim_a = bundled.similarity(&a);
    const sim_b = bundled.similarity(&b);

    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "SequenceEncoder" {
    var encoder = SequenceEncoder.init(256);

    const a = Hypervector.random(256, 55555);
    const b = Hypervector.random(256, 66666);
    const c = Hypervector.random(256, 77777);

    var items = [_]Hypervector{ a, b, c };
    var sequence = encoder.encode(&items);

    // Probe should find elements at correct positions
    const sim_a_0 = encoder.probe(&sequence, &a, 0);
    const sim_a_1 = encoder.probe(&sequence, &a, 1);

    try std.testing.expect(sim_a_0 > sim_a_1);
}

test "AssociativeMemory" {
    var memory = AssociativeMemory.init(256);

    var key = Hypervector.random(256, 88888);
    var value = Hypervector.random(256, 99999);

    memory.store(&key, &value);

    var retrieved = memory.retrieve(&key);
    const sim = retrieved.similarity(&value);

    // Retrieved should be similar to stored value
    try std.testing.expect(sim > 0.2);
}
