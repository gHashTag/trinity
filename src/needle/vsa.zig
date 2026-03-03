// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3 — Semantic VSA (Vector Symbolic Architecture)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Semantic embeddings for code symbols using VSA operations
// Cosine similarity search for intent-aware refactoring
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const trinity_vsa = @import("vsa");
const graph = @import("graph.zig");

// Re-export core VSA operations
pub const Hypervector = trinity_vsa.Hypervector;
pub const Codebook = trinity_vsa.Codebook;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_EMBEDDING_DIM: usize = 384;
pub const DEFAULT_SIMILARITY_THRESHOLD: f32 = 0.85;
pub const DEFAULT_TOP_K: usize = 10;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Semantic vector for code symbol
pub const SemanticVector = struct {
    symbol_id: []const u8,
    embedding: []const f32,
    context_hash: u64,
    symbol_type: graph.SymbolKind,
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
    allowed_transforms: std.ArrayList([]const u8),
    forbidden_transforms: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, pattern_id: []const u8) VSARule {
        return .{
            .pattern_id = pattern_id,
            .semantic_pattern = "",
            .similarity_threshold = DEFAULT_SIMILARITY_THRESHOLD,
            .safety_level = .medium,
            .allowed_transforms = std.ArrayList([]const u8).init(allocator),
            .forbidden_transforms = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VSARule) void {
        var iter = self.allowed_transforms.iterator();
        while (iter.next()) |item| {
            self.allocator.free(item.*);
        }
        self.allowed_transforms.deinit();

        iter = self.forbidden_transforms.iterator();
        while (iter.next()) |item| {
            self.allocator.free(item.*);
        }
        self.forbidden_transforms.deinit();
    }
};

/// VSA match result
pub const VSAMatch = struct {
    symbol: graph.Symbol,
    similarity: f32,
    context_match: f32,
    confidence: f32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, symbol: graph.Symbol) VSAMatch {
        return .{
            .symbol = symbol,
            .similarity = 0.0,
            .context_match = 0.0,
            .confidence = 0.0,
            .allocator = allocator,
        };
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
    vsa_rules: std.ArrayList(VSARule),
    embedding_dim: usize,
    index_type: IndexType,
    codebook: Codebook,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, embedding_dim: usize) !SemanticIndex {
        // Initialize VSA codebook
        var codebook = try Codebook.init(allocator, 10000); // 10K slots
        errdefer codebook.deinit();

        return .{
            .vectors = std.StringHashMap(SemanticVector).init(allocator),
            .vsa_rules = std.ArrayList(VSARule).init(allocator),
            .embedding_dim = embedding_dim,
            .index_type = .flat,
            .codebook = codebook,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SemanticIndex) void {
        var vec_iter = self.vectors.valueIterator();
        while (vec_iter.next()) |vec| {
            vec.deinit();
        }
        self.vectors.deinit();

        var rule_iter = self.vsa_rules.iterator();
        while (rule_iter.next()) |rule| {
            rule.deinit();
        }
        self.vsa_rules.deinit();

        self.codebook.deinit();
    }

    /// Add a semantic vector to the index
    pub fn addVector(self: *SemanticIndex, vec: SemanticVector) !void {
        const cloned = try vec.clone();
        try self.vectors.put(cloned.symbol_id, cloned);
    }

    /// Search for similar vectors
    pub fn search(self: *SemanticIndex, query: []const f32, top_k: usize, min_similarity: f32) !std.ArrayList(VSAMatch) {
        var results = std.ArrayList(VSAMatch).init(self.allocator);
        errdefer {
            for (results.items) |*r| {
                r.allocator.free(r.symbol.name);
                r.allocator.free(r.symbol.file);
                r.allocator.free(r.symbol.signature);
            }
            results.deinit();
        }

        var iter = self.vectors.iterator();
        while (iter.next()) |entry| {
            const vec = entry.value_ptr.*;
            const similarity = cosineSimilarity(query, vec.embedding);

            if (similarity >= min_similarity) {
                var match = VSAMatch.init(self.allocator, .{
                    .name = try self.allocator.dupe(u8, vec.symbol_id),
                    .kind = vec.symbol_type,
                    .file = try self.allocator.dupe(u8, vec.file),
                    .line = vec.line,
                    .column = 0,
                    .signature = try self.allocator.dupe(u8, ""),
                });
                match.similarity = similarity;
                match.context_match = similarity; // Simplified for now
                match.computeConfidence();
                try results.append(match);
            }
        }

        // Sort by confidence descending
        sortMatches(results.items);

        // Keep top_k results
        if (results.items.len > top_k) {
            // Free excess results
            for (results.items[top_k..]) |*r| {
                self.allocator.free(r.symbol.name);
                self.allocator.free(r.symbol.file);
                self.allocator.free(r.symbol.signature);
            }
            try results.resize(top_k);
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

/// Generate VSA-based embedding using Hypervector operations
pub fn generateVSAEmbedding(
    allocator: std.mem.Allocator,
    codebook: *Codebook,
    symbol_id: []const u8,
    context: []const u8,
) !Hypervector {
    _ = context;

    // Get symbol hypervector from codebook
    const symbol_hv = try codebook.getOrBind(symbol_id);

    // For now, return the symbol hypervector directly
    // Future: bind with context, permute, etc.
    return symbol_hv.clone(allocator);
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

/// Bind two vectors (association)
pub fn bind(allocator: std.mem.Allocator, a: Hypervector, b: Hypervector) !Hypervector {
    return trinity_vsa.bind(allocator, a, b);
}

/// Unbind a vector (retrieval)
pub fn unbind(allocator: std.mem.Allocator, bound: Hypervector, key: Hypervector) !Hypervector {
    return trinity_vsa.unbind(allocator, bound, key);
}

/// Bundle multiple vectors (majority vote)
pub fn bundle(allocator: std.mem.Allocator, vectors: []const Hypervector) !Hypervector {
    return trinity_vsa.bundleN(allocator, vectors);
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

/// Build semantic index from call graph
pub fn buildSemanticIndex(
    allocator: std.mem.Allocator,
    call_graph: *graph.CallGraph,
    embedding_dim: usize,
) !SemanticIndex {
    var index = try SemanticIndex.init(allocator, embedding_dim);
    errdefer index.deinit();

    // Iterate through all symbols in the call graph
    var symbol_iter = call_graph.symbol_table.iterator();
    while (symbol_iter.next()) |entry| {
        const symbol = entry.value_ptr.*;

        // Generate embedding for this symbol
        const embedding = try generateHashEmbedding(
            allocator,
            symbol.name,
            symbol.signature,
            symbol.file,
            embedding_dim,
        );
        errdefer allocator.free(embedding);

        // Create semantic vector
        var sem_vec = try SemanticVector.init(allocator, symbol.name, embedding_dim);
        errdefer sem_vec.deinit();

        @memcpy(sem_vec.embedding, embedding);
        sem_vec.symbol_type = symbol.kind;
        sem_vec.file = try allocator.dupe(u8, symbol.file);
        sem_vec.line = symbol.line;

        // Compute context hash
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(symbol.signature);
        sem_vec.context_hash = hasher.final();

        // Add to index
        try index.addVector(sem_vec);
        allocator.free(embedding);
    }

    return index;
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
