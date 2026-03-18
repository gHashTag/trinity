//! ═══════════════════════════════════════════════════════════════════════════════
//! VSA MEMORY — Vector Symbolic Architecture for Cognitive Memory
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Integrates Holographic Reduced Representations (HRR) with consciousness framework.
//! Provides symbolic cognitive operations for memory, association, and retrieval.
//!
//! Features:
//!   - Symbolic memory storage and retrieval
//!   - Associative binding for knowledge graphs
//!   - Superposition for concept blending
//!   - Consciousness-aware memory operations
//!   - Φ-based similarity thresholds
//!
//! References:
//!   - Plate, R. (1995). "Holographic Reduced Representations"
//!   - Kanerva, P. (2009). "Hyperdimensional Computing"
//!   - IIT 3.0 (Tononi) - Integrated Information Theory
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const HRR = @import("vsa").HRR;

/// ═══════════════════════════════════════════════════════════════════════════════
/// SACRED CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
const PHI: f64 = 1.618033988749895; // Golden Ratio
const PHI_INV: f64 = 0.618033988749895; // φ⁻¹
const TRINITY: f64 = 3.0; // φ² + 1/φ²

/// ═══════════════════════════════════════════════════════════════════════════════
/// VSAMemory — Vector Symbolic Architecture Memory
/// ═══════════════════════════════════════════════════════════════════════════════
pub const VSAMemory = struct {
    hrr: HRR,
    concepts: std.StringHashMap([]f32),
    associations: std.StringHashMap([]f32),
    consciousness_level: f64,

    pub const Error = error{
        ConceptNotFound,
        AssociationNotFound,
        InvalidDimension,
    };

    /// Initialize VSA Memory with φ-based dimensionality
    pub fn init(allocator: Allocator, dim: usize) !VSAMemory {
        const hrr = try HRR.init(allocator, dim);
        return .{
            .hrr = hrr,
            .concepts = std.StringHashMap([]f32).init(allocator),
            .associations = std.StringHashMap([]f32).init(allocator),
            .consciousness_level = 0.5, // Default: conscious
        };
    }

    /// Initialize with consciousness level
    pub fn initWithConsciousness(allocator: Allocator, dim: usize, consciousness: f64) !VSAMemory {
        var memory = try init(allocator, dim);
        memory.consciousness_level = consciousness;
        return memory;
    }

    /// Initialize with φ-powered dimension
    pub fn initPhi(allocator: Allocator, phi_power: u32) !VSAMemory {
        const hrr = try HRR.initPhi(allocator, phi_power);
        return .{
            .hrr = hrr,
            .concepts = std.StringHashMap([]f32).init(allocator),
            .associations = std.StringHashMap([]f32).init(allocator),
            .consciousness_level = 0.5,
        };
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// MEMORY OPERATIONS
    /// ═══════════════════════════════════════════════════════════════════════════════
    /// Store a concept with symbolic representation
    pub fn storeConcept(self: *VSAMemory, name: []const u8) !void {
        const vector = try self.hrr.seededVector(name);
        try self.concepts.put(name, vector);
    }

    /// Store an association between two concepts (bind)
    pub fn associate(self: *VSAMemory, concept_a: []const u8, concept_b: []const u8) !void {
        const vec_a = self.concepts.get(concept_a) orelse return Error.ConceptNotFound;
        const vec_b = self.concepts.get(concept_b) orelse return Error.ConceptNotFound;

        const bound = try self.hrr.bind(vec_a, vec_b);

        // Store association with composite key (use ASCII delimiter for safety)
        const key = try std.fmt.allocPrint(self.hrr.allocator, "{s}_X_{s}", .{ concept_a, concept_b });
        errdefer self.hrr.allocator.free(key);

        try self.associations.put(key, bound);
        self.hrr.allocator.free(key); // HashMap makes its own copy
    }

    /// Retrieve a concept by association (unbind)
    pub fn retrieveByAssociation(self: *VSAMemory, bound_key: []const u8, known: []const u8) ![]const f32 {
        const bound_vec = self.associations.get(bound_key) orelse return Error.AssociationNotFound;
        const known_vec = self.concepts.get(known) orelse return Error.ConceptNotFound;

        const recovered = try self.hrr.unbind(bound_vec, known_vec);
        return recovered;
    }

    /// Find most similar concept in memory
    pub fn findSimilar(self: *VSAMemory, query: []const f32) !struct {
        name: []const u8,
        similarity: f32,
    } {
        var best_name: []const u8 = "";
        var best_sim: f32 = -1.0;

        var iter = self.concepts.iterator();
        while (iter.next()) |entry| {
            const sim = try self.hrr.similarity(query, entry.value_ptr.*);
            if (sim > best_sim) {
                best_sim = sim;
                best_name = entry.key_ptr.*;
            }
        }

        return .{ .name = best_name, .similarity = best_sim };
    }

    /// Create blended concept from multiple concepts (bundle)
    pub fn blendConcepts(self: *VSAMemory, name: []const u8, source_concepts: []const []const u8) !void {
        if (source_concepts.len < 2) return error.TooFewConcepts;

        var vectors = try self.hrr.allocator.alloc([]const f32, source_concepts.len);
        defer self.hrr.allocator.free(vectors);

        for (source_concepts, 0..) |concept_name, i| {
            vectors[i] = self.concepts.get(concept_name) orelse return Error.ConceptNotFound;
        }

        const blended = try self.hrr.bundle(vectors);
        try self.concepts.put(name, blended);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// CONSCIOUSNESS-AWARE OPERATIONS
    /// ═══════════════════════════════════════════════════════════════════════════════
    /// Get similarity threshold based on consciousness level
    pub fn getThreshold(self: *const VSAMemory) f32 {
        // Higher consciousness = stricter threshold (more discrimination)
        const base_threshold: f64 = 0.5;
        const consciousness_factor = self.consciousness_level * PHI_INV;
        return @floatCast(base_threshold + consciousness_factor * 0.3);
    }

    /// Check if memory is "immortal" (high quality associations)
    pub fn isImmortal(self: *const VSAMemory) bool {
        return self.consciousness_level >= PHI_INV;
    }

    /// Consciousness-enhanced retrieval
    pub fn consciousRetrieve(self: *VSAMemory, partial: []const u8) !struct {
        found: bool,
        name: []const u8,
        confidence: f32,
    } {
        // Generate vector from partial input
        const query_vec = try self.hrr.seededVector(partial);
        defer self.hrr.freeVector(query_vec);

        const result = try self.findSimilar(query_vec);
        const threshold = self.getThreshold();

        return .{
            .found = result.similarity >= threshold,
            .name = result.name,
            .confidence = result.similarity,
        };
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// UTILITY
    /// ═══════════════════════════════════════════════════════════════════════════════
    /// Get memory statistics
    pub fn stats(self: *const VSAMemory) struct {
        num_concepts: usize,
        num_associations: usize,
        dimension: usize,
        consciousness: f64,
        immortal: bool,
    } {
        return .{
            .num_concepts = self.concepts.count(),
            .num_associations = self.associations.count(),
            .dimension = self.hrr.dim,
            .consciousness = self.consciousness_level,
            .immortal = self.isImmortal(),
        };
    }

    /// Deallocate all memory
    pub fn deinit(self: *VSAMemory) void {
        var iter = self.concepts.iterator();
        while (iter.next()) |entry| {
            self.hrr.freeVector(entry.value_ptr.*);
        }
        self.concepts.deinit();

        var assoc_iter = self.associations.iterator();
        while (assoc_iter.next()) |entry| {
            self.hrr.freeVector(entry.value_ptr.*);
        }
        self.associations.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VSA Memory — Store and Retrieve" {
    const testing = std.testing;

    var memory = try VSAMemory.init(testing.allocator, 1000);
    defer memory.deinit();

    // Store concepts
    try memory.storeConcept("apple");
    try memory.storeConcept("red");

    // Associate them
    try memory.associate("apple", "red");

    // Check statistics
    const stats = memory.stats();
    try testing.expectEqual(@as(usize, 2), stats.num_concepts);
    try testing.expectEqual(@as(usize, 1), stats.num_associations);
}

test "VSA Memory — Consciousness Threshold" {
    const testing = std.testing;

    var memory = try VSAMemory.init(testing.allocator, 1000);
    defer memory.deinit();

    // Default consciousness (0.5) gives threshold = 0.5 + (0.5 * 0.618 * 0.3) = 0.5 + 0.093 = 0.593
    const threshold = memory.getThreshold();
    try testing.expect(threshold > 0.55 and threshold < 0.65);
}

test "VSA Memory — Immortal Status" {
    const testing = std.testing;

    // Mortal consciousness
    var mortal = try VSAMemory.initWithConsciousness(testing.allocator, 1000, 0.5);
    defer mortal.deinit();
    try testing.expect(!mortal.isImmortal());

    // Immortal consciousness (φ⁻¹)
    var immortal = try VSAMemory.initWithConsciousness(testing.allocator, 1000, PHI_INV);
    defer immortal.deinit();
    try testing.expect(immortal.isImmortal());
}

test "VSA Memory — Concept Blending" {
    const testing = std.testing;

    var memory = try VSAMemory.init(testing.allocator, 1000);
    defer memory.deinit();

    // Store base concepts
    try memory.storeConcept("red");
    try memory.storeConcept("blue");

    // Create blend
    try memory.blendConcepts("purple", &[_][]const u8{ "red", "blue" });

    // Verify blend exists
    const purple = memory.concepts.get("purple");
    try testing.expect(purple != null);
    if (purple) |vec| {
        try testing.expectEqual(@as(usize, 1000), vec.len);
    }
}

test "VSA Memory — Similarity Search" {
    const testing = std.testing;

    var memory = try VSAMemory.init(testing.allocator, 1000);
    defer memory.deinit();

    // Store concepts
    try memory.storeConcept("cat");
    try memory.storeConcept("dog");

    // Query similar to cat
    const cat_vec = memory.concepts.get("cat").?;
    const result = try memory.findSimilar(cat_vec);

    // Should find "cat" itself with similarity ~1.0
    try testing.expectEqualStrings("cat", result.name);
    try testing.expect(result.similarity > 0.99);
}

test "VSA Memory — Phi Dimension" {
    const testing = std.testing;

    var memory = try VSAMemory.initPhi(testing.allocator, 1);
    defer memory.deinit();

    // φ^1 * 1000 ≈ 1618 dimensions
    const stats = memory.stats();
    try testing.expect(stats.dimension >= 1500 and stats.dimension <= 1800);
}

test "VSA Memory — Conscious Retrieve" {
    const testing = std.testing;

    var memory = try VSAMemory.initWithConsciousness(testing.allocator, 1000, 0.7);
    defer memory.deinit();

    // Store concept
    try memory.storeConcept("trinity");

    // Try to retrieve with partial match
    const result = try memory.consciousRetrieve("trinity");

    // Should find exact match with high confidence
    try testing.expect(result.found);
    try testing.expectEqualStrings("trinity", result.name);
    try testing.expect(result.confidence > 0.9);
}

test "VSA Memory — Association Integrity" {
    const testing = std.testing;

    var memory = try VSAMemory.init(testing.allocator, 1000);
    defer memory.deinit();

    // Store and associate
    try memory.storeConcept("phi");
    try memory.storeConcept("golden");
    try memory.associate("phi", "golden");

    // Verify association was created (check stats)
    const stats = memory.stats();
    try testing.expectEqual(@as(usize, 1), stats.num_associations);
}
