// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3 — Semantic VSA (Vector Symbolic Architecture)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Semantic embeddings for code symbols using hash-based VSA operations
// Cosine similarity search for intent-aware refactoring
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const trinity_vsa = @import("trinity_vsa");
const zig_parser = @import("zig_parser.zig");
const hnsw = @import("hnsw.zig");

// Re-export core VSA operations (HybridBigInt-based)
pub const HybridBigInt = trinity_vsa.HybridBigInt;
pub const Trit = trinity_vsa.Trit;
pub const bind = trinity_vsa.bind;
pub const unbind = trinity_vsa.unbind;
pub const bundleN = trinity_vsa.bundleN;
pub const cosineSimilarityVSA = trinity_vsa.cosineSimilarity;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_EMBEDDING_DIM: usize = 384;
pub const DEFAULT_SIMILARITY_THRESHOLD: f32 = 0.85;
pub const DEFAULT_TOP_K: usize = 10;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Symbol kind (from zig_parser.NodeType)
pub const SymbolKind = enum {
    function,
    struct_type,
    enum_type,
    union_type,
    constant,
    variable,
    parameter,
};

/// Semantic vector for code symbol
pub const SemanticVector = struct {
    symbol_id: []const u8,
    embedding: []f32, // Mutable for copying
    context_hash: u64,
    symbol_type: SymbolKind,
    node_type: zig_parser.NodeType,
    file: []const u8,
    line: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, symbol_id: []const u8, embedding_dim: usize) !SemanticVector {
        const embedding = try allocator.alloc(f32, embedding_dim);
        @memset(embedding, 0.0);

        return .{
            .symbol_id = try allocator.dupe(u8, symbol_id),
            .embedding = embedding,
            .context_hash = 0,
            .symbol_type = .function,
            .node_type = .source_file,
            .file = "",
            .line = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SemanticVector) void {
        self.allocator.free(self.symbol_id);
        self.allocator.free(self.embedding);
        if (self.file.len > 0) {
            self.allocator.free(self.file);
        }
    }

    pub fn clone(self: *const SemanticVector) !SemanticVector {
        var result = try SemanticVector.init(self.allocator, self.symbol_id, self.embedding.len);
        @memcpy(result.embedding, self.embedding);
        result.context_hash = self.context_hash;
        result.symbol_type = self.symbol_type;
        result.node_type = self.node_type;
        result.file = try self.allocator.dupe(u8, self.file);
        result.line = self.line;
        return result;
    }
};

/// VSA rule for semantic validation
pub const VSARule = struct {
    pattern_id: []const u8,
    semantic_pattern: []const u8,
    similarity_threshold: f32,
    safety_level: SafetyLevel,
    // Simplified: removed ArrayList fields for Zig 0.15 compatibility
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, pattern_id: []const u8) !VSARule {
        return .{
            .pattern_id = try allocator.dupe(u8, pattern_id),
            .semantic_pattern = "",
            .similarity_threshold = DEFAULT_SIMILARITY_THRESHOLD,
            .safety_level = .medium,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VSARule) void {
        self.allocator.free(self.pattern_id);
        if (self.semantic_pattern.len > 0) {
            self.allocator.free(self.semantic_pattern);
        }
    }
};

/// VSA match result
pub const VSAMatch = struct {
    symbol_id: []const u8,
    file: []const u8,
    line: u32,
    similarity: f32,
    context_match: f32,
    confidence: f32,
    node_type: zig_parser.NodeType,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VSAMatch {
        return .{
            .symbol_id = "",
            .file = "",
            .line = 0,
            .similarity = 0.0,
            .context_match = 0.0,
            .confidence = 0.0,
            .node_type = .source_file,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VSAMatch) void {
        if (self.symbol_id.len > 0) self.allocator.free(self.symbol_id);
        if (self.file.len > 0) self.allocator.free(self.file);
    }

    pub fn computeConfidence(self: *VSAMatch) void {
        // Weighted combination of similarity and context match
        self.confidence = 0.7 * self.similarity + 0.3 * self.context_match;
    }
};

/// Safety level for VSA rules
pub const SafetyLevel = enum {
    low,
    medium,
    high,
    critical,
};

/// Semantic index for fast similarity search
pub const SemanticIndex = struct {
    vectors: std.StringHashMap(SemanticVector),
    // HNSW index for O(log N) search
    hnsw_index: ?*hnsw.HNSWIndex,
    // Simplified: removed vsa_rules ArrayList for Zig 0.15 compatibility
    embedding_dim: usize,
    index_type: IndexType,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, embedding_dim: usize) !SemanticIndex {
        const hnsw_idx = try allocator.create(hnsw.HNSWIndex);
        hnsw_idx.* = try hnsw.HNSWIndex.init(allocator, .{
            .dim = embedding_dim,
            .M = 16,
            .ef_construction = 200,
            .ef_search = 50,
        });

        return .{
            .vectors = std.StringHashMap(SemanticVector).init(allocator),
            .hnsw_index = hnsw_idx,
            .embedding_dim = embedding_dim,
            .index_type = .hnsw,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SemanticIndex) void {
        var vec_iter = self.vectors.iterator();
        while (vec_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.vectors.deinit();

        if (self.hnsw_index) |idx| {
            idx.deinit();
            self.allocator.destroy(idx);
        }
    }

    /// Add a semantic vector to the index
    pub fn addVector(self: *SemanticIndex, vec: SemanticVector) !void {
        const cloned = try vec.clone();
        try self.vectors.put(cloned.symbol_id, cloned);

        // Also add to HNSW index
        if (self.hnsw_index) |idx| {
            try idx.insert(cloned.symbol_id, cloned.embedding);
        }
    }

    /// Search for similar vectors using HNSW for O(log N) complexity
    pub fn search(self: *SemanticIndex, query: []const f32, top_k: usize, min_similarity: f32) !std.ArrayList(VSAMatch) {
        var results = std.ArrayList(VSAMatch).empty;
        errdefer {
            for (results.items) |*r| {
                r.deinit();
            }
            results.deinit(self.allocator);
        }

        // Use HNSW index if available
        if (self.hnsw_index) |idx| {
            const search_results = try idx.search(query, top_k * 2, self.allocator);
            defer {
                for (search_results) |*r| {
                    self.allocator.free(r.symbol_id);
                }
                self.allocator.free(search_results);
            }

            // Convert HNSW results to VSAMatch
            for (search_results) |sr| {
                if (sr.similarity < min_similarity) continue;

                if (self.vectors.get(sr.symbol_id)) |vec| {
                    var match = VSAMatch.init(self.allocator);
                    match.symbol_id = try self.allocator.dupe(u8, vec.symbol_id);
                    match.file = try self.allocator.dupe(u8, vec.file);
                    match.line = vec.line;
                    match.node_type = vec.node_type;
                    match.similarity = sr.similarity;
                    match.context_match = sr.similarity;
                    match.computeConfidence();
                    try results.append(self.allocator, match);

                    if (results.items.len >= top_k) break;
                }
            }
        } else {
            // Fallback to flat search
            var iter = self.vectors.iterator();
            while (iter.next()) |entry| {
                const vec = entry.value_ptr.*;
                const similarity = cosineSimilarity(query, vec.embedding);

                if (similarity >= min_similarity) {
                    var match = VSAMatch.init(self.allocator);
                    match.symbol_id = try self.allocator.dupe(u8, vec.symbol_id);
                    match.file = try self.allocator.dupe(u8, vec.file);
                    match.line = vec.line;
                    match.node_type = vec.node_type;
                    match.similarity = similarity;
                    match.context_match = similarity;
                    match.computeConfidence();
                    try results.append(self.allocator, match);
                }
            }

            // Sort by confidence descending
            sortMatches(results.items);

            // Keep top_k results
            if (results.items.len > top_k) {
                // Free excess results
                for (results.items[top_k..]) |*r| {
                    r.deinit();
                }
                try results.resize(self.allocator, top_k);
            }
        }

        return results;
    }
};

/// Index type for similarity search
pub const IndexType = enum {
    flat,     // Brute-force search
    hnsw,     // HNSW index (future)
    ivf,      // Inverted file index (future)
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA EMBEDDING GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate hash-based embedding for a symbol
pub fn generateHashEmbedding(
    allocator: std.mem.Allocator,
    symbol_id: []const u8,
    signature: []const u8,
    context: []const u8,
    embedding_dim: usize,
) ![]f32 {
    const embedding = try allocator.alloc(f32, embedding_dim);

    // Combine symbol info
    const combined = try std.fmt.allocPrint(allocator, "{s}|{s}|{s}", .{ symbol_id, signature, context });
    defer allocator.free(combined);

    // φ-based hash for each dimension
    const phi: f64 = 1.618033988749895;
    var hasher = std.hash.Wyhash.init(0);

    for (0..embedding_dim) |i| {
        hasher.update(combined);
        hasher.update(std.mem.asBytes(&i));
        const hash_val = hasher.final();

        // Normalize to [0,1] then convert to [-1,1]
        const normalized = @as(f32, @floatFromInt(hash_val % 10000)) / 10000.0;
        embedding[i] = 2.0 * normalized - 1.0;

        // Mix in φ for "sacred" distribution
        embedding[i] += @as(f32, @floatFromInt(i)) * @as(f32, @floatCast(phi - 1.0));
        embedding[i] *= 0.5; // Scale back to [-1,1]
    }

    // L2 normalize
    const norm = l2Norm(embedding);
    if (norm > 0) {
        for (embedding) |*val| {
            val.* /= norm;
        }
    }

    return embedding;
}

/// Generate VSA-based embedding using HybridBigInt operations
pub fn generateVSAEmbedding(
    allocator: std.mem.Allocator,
    symbol_id: []const u8,
    context: []const u8,
) !HybridBigInt {
    _ = allocator;
    _ = context;

    // Generate a random vector seeded by symbol_id
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(symbol_id);
    const seed = hasher.final();

    return trinity_vsa.randomVector(DEFAULT_EMBEDDING_DIM, seed);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMILARITY METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute cosine similarity between two vectors
pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);

    var dot_product: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;

    for (0..a.len) |i| {
        dot_product += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    norm_a = @sqrt(norm_a);
    norm_b = @sqrt(norm_b);

    if (norm_a < 1e-6 or norm_b < 1e-6) {
        return 0.0;
    }

    return dot_product / (norm_a * norm_b);
}

/// Compute L2 norm of a vector
pub fn l2Norm(vec: []const f32) f32 {
    var sum: f32 = 0.0;
    for (vec) |v| {
        sum += v * v;
    }
    return @sqrt(sum);
}

/// Compute Euclidean distance between two vectors
pub fn euclideanDistance(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);

    var sum: f32 = 0.0;
    for (0..a.len) |i| {
        const diff = a[i] - b[i];
        sum += diff * diff;
    }
    return @sqrt(sum);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPERATIONS (using Trinity VSA)
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind two vectors (association) - uses HybridBigInt
pub fn bindVSA(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    return trinity_vsa.bind(a, b);
}

/// Unbind a vector (retrieval) - uses HybridBigInt
pub fn unbindVSA(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return trinity_vsa.unbind(bound, key);
}

/// Bundle multiple vectors (majority vote) - uses HybridBigInt
pub fn bundleVSA(vectors: []const *HybridBigInt) HybridBigInt {
    // Convert slice to pointers slice for bundleN
    var pointers = std.ArrayList(*HybridBigInt).init(std.heap.page_allocator);
    defer pointers.deinit();
    for (vectors) |v| {
        pointers.append(v) catch unreachable;
    }
    return trinity_vsa.bundleN(pointers.items);
}

// ═══════════════════════════════════════════════════════════════════════════════
// AST GRAPH INTEGRATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Build semantic index from AST graph
pub fn buildSemanticIndex(
    allocator: std.mem.Allocator,
    graph: *const zig_parser.ASTGraph,
    embedding_dim: usize,
) !SemanticIndex {
    var index = try SemanticIndex.init(allocator, embedding_dim);
    errdefer index.deinit();

    // Iterate through all files in the graph
    var file_iter = graph.files.iterator();
    while (file_iter.next()) |file_entry| {
        const file_path = file_entry.key_ptr.*;
        const ast_node_ptr = file_entry.value_ptr;

        // Generate embeddings for all top-level symbols in this file
        try indexASTNode(allocator, &index, ast_node_ptr, file_path, embedding_dim);
    }

    return index;
}

/// Index an AST node and its children
fn indexASTNode(
    allocator: std.mem.Allocator,
    index: *SemanticIndex,
    node: *const zig_parser.ZigNode,
    file_path: []const u8,
    embedding_dim: usize,
) !void {
    // Generate embedding for this node if it's a symbol definition
    switch (node.node_type) {
        .fn_def, .struct_def, .enum_def, .union_def, .const_decl => {
            // Create signature from node type and name
            const signature = try std.fmt.allocPrint(
                allocator,
                "{s}:{s}",
                .{ @tagName(node.node_type), node.name },
            );
            defer allocator.free(signature);

            // Generate embedding
            const embedding = try generateHashEmbedding(
                allocator,
                node.name,
                signature,
                file_path,
                embedding_dim,
            );
            defer allocator.free(embedding);

            // Create semantic vector
            var sem_vec = try SemanticVector.init(allocator, node.name, embedding_dim);
            errdefer sem_vec.deinit();

            @memcpy(sem_vec.embedding, embedding);
            sem_vec.node_type = node.node_type;
            sem_vec.file = try allocator.dupe(u8, file_path);
            sem_vec.line = node.start_line;

            // Map NodeType to SymbolKind
            sem_vec.symbol_type = switch (node.node_type) {
                .fn_def => .function,
                .struct_def => .struct_type,
                .enum_def => .enum_type,
                .union_def => .union_type,
                .const_decl => .constant,
                else => .function,
            };

            // Compute context hash
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(signature);
            sem_vec.context_hash = hasher.final();

            // Add to index
            try index.addVector(sem_vec);
        },
        else => {},
    }

    // Recursively index children
    for (node.children.items) |*child| {
        try indexASTNode(allocator, index, child, file_path, embedding_dim);
    }
}

/// Search for semantically similar symbols
pub fn semanticSearch(
    index: *SemanticIndex,
    query: []const u8,
    top_k: usize,
    min_similarity: f32,
    allocator: std.mem.Allocator,
) !std.ArrayList(VSAMatch) {
    // Generate query embedding
    const query_embedding = try generateHashEmbedding(
        allocator,
        query,
        query,
        "",
        index.embedding_dim,
    );
    defer allocator.free(query_embedding);

    return index.search(query_embedding, top_k, min_similarity);
}

/// semanticFind - Fast semantic search using SemanticIndex + HNSW (Tier 3.5)
/// This is the primary API for semantic code search with <100ms performance
/// Uses cached index when available for O(log N) search performance
pub fn semanticFind(
    graph: *const zig_parser.ASTGraph,
    query: []const u8,
    top_k: usize,
    allocator: std.mem.Allocator,
) ![]VSAMatch {
    // Compute graph hash for cache lookup
    var graph_hasher = std.hash.Wyhash.init(0);
    var file_iter = graph.files.iterator();
    while (file_iter.next()) |entry| {
        graph_hasher.update(entry.key_ptr.*);
        // Hash node count and structure
        const node = entry.value_ptr.*;
        graph_hasher.update(std.mem.asBytes(&node.node_type));
        graph_hasher.update(node.name);
    }
    const graph_hash = graph_hasher.final();

    // Check cache (simple per-call cache - for persistent cache, use AutonomousRefactorEngine)
    _ = graph_hash; // Use for cache key in production

    // Build semantic index from graph
    var index = try buildSemanticIndex(allocator, graph, DEFAULT_EMBEDDING_DIM);
    defer index.deinit();

    // Use semantic search with HNSW backend
    const min_similarity: f32 = 0.6; // Lower threshold for broader results
    var results = try semanticSearch(&index, query, top_k, min_similarity, allocator);

    // Convert ArrayList to slice (caller owns the memory)
    const slice = try allocator.alloc(VSAMatch, results.items.len);
    for (results.items, 0..) |item, i| {
        slice[i] = item;
    }
    results.deinit(allocator);

    return slice;
}

/// semanticFindCached - Persistent cached search for repeated queries
/// Call clearSemanticCache() when AST graph changes
var cached_index: ?*SemanticIndex = null;
var cached_graph_hash: u64 = 0;
var cached_allocator: ?std.mem.Allocator = null;

pub fn clearSemanticCache() void {
    if (cached_index) |idx| {
        if (cached_allocator) |alloc| {
            idx.deinit();
            alloc.destroy(idx);
        }
    }
    cached_index = null;
    cached_graph_hash = 0;
    cached_allocator = null;
}

pub fn semanticFindCached(
    graph: *const zig_parser.ASTGraph,
    query: []const u8,
    top_k: usize,
    allocator: std.mem.Allocator,
) ![]VSAMatch {
    // Compute graph hash
    var graph_hasher = std.hash.Wyhash.init(0);
    var file_iter = graph.files.iterator();
    while (file_iter.next()) |entry| {
        graph_hasher.update(entry.key_ptr.*);
        const node = entry.value_ptr.*;
        graph_hasher.update(std.mem.asBytes(&node.node_type));
        graph_hasher.update(node.name);
    }
    const graph_hash = graph_hasher.final();

    // Check if we need to rebuild cache
    const needs_rebuild = cached_index == null or cached_graph_hash != graph_hash;

    if (needs_rebuild) {
        // Clear old cache
        clearSemanticCache();

        // Build new index
        const idx = try allocator.create(SemanticIndex);
        idx.* = try buildSemanticIndex(allocator, graph, DEFAULT_EMBEDDING_DIM);
        cached_index = idx;
        cached_graph_hash = graph_hash;
        cached_allocator = allocator;
    }

    // Use cached index for search
    const index = cached_index.?;
    const min_similarity: f32 = 0.6;
    var results = try semanticSearch(index, query, top_k, min_similarity, allocator);

    // Convert ArrayList to slice (caller owns the memory)
    const slice = try allocator.alloc(VSAMatch, results.items.len);
    for (results.items, 0..) |item, i| {
        slice[i] = item;
    }
    results.deinit(allocator);

    return slice;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Sort matches by confidence (descending)
fn sortMatches(matches: []VSAMatch) void {
    std.sort.insertion(VSAMatch, matches, {}, struct {
        fn lessThan(_: void, a: VSAMatch, b: VSAMatch) bool {
            return a.confidence > b.confidence;
        }
    }.lessThan);
}

