// ═══════════════════════════════════════════════════════════════════════════════
// TVC CORPUS — Ternary Vector Corpus for Distributed Continual Learning
// ═══════════════════════════════════════════════════════════════════════════════
//
// All queries → save to TVC, retrieve similar patterns for reasoning.
// Each query/response = new pattern (bind → bundle to memory).
// No forgetting — continuous learning.
// Distributed — shared base across nodes.
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa");

const HybridBigInt = vsa.HybridBigInt;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum corpus entries (100x TextCorpus)
pub const TVC_MAX_ENTRIES: usize = 10000;

/// Vector dimension for text encoding
pub const TVC_VECTOR_DIM: usize = vsa.TEXT_VECTOR_DIM;

/// Similarity threshold for retrieval (φ⁻¹ = Golden Ratio inverse)
pub const TVC_SIMILARITY_THRESHOLD: f64 = 0.618;

/// Maximum query text length
pub const TVC_MAX_QUERY_LEN: usize = 512;

/// Maximum response text length
pub const TVC_MAX_RESPONSE_LEN: usize = 2048;

/// File format magic bytes
pub const TVC_MAGIC: [4]u8 = .{ 'T', 'V', 'C', '1' };

/// File format version
pub const TVC_VERSION: u32 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Single TVC entry: query + response + bound vector
pub const TVCEntry = struct {
    /// Encoded query vector (1000 trits)
    query_vec: HybridBigInt,

    /// Encoded response vector (1000 trits)
    response_vec: HybridBigInt,

    /// Bound vector: bind(query, response) for association
    bound_vec: HybridBigInt,

    /// Original query text
    query_text: [TVC_MAX_QUERY_LEN]u8,
    query_len: u16,

    /// Original response text
    response_text: [TVC_MAX_RESPONSE_LEN]u8,
    response_len: u16,

    /// Entry metadata
    entry_id: u64,
    timestamp: i64,
    usage_count: u32,
    avg_similarity: f32,

    /// Source node for distributed sync
    source_node: [16]u8,

    /// Get query text as slice
    pub fn getQuery(self: *const TVCEntry) []const u8 {
        return self.query_text[0..self.query_len];
    }

    /// Get response text as slice
    pub fn getResponse(self: *const TVCEntry) []const u8 {
        return self.response_text[0..self.response_len];
    }
};

/// Search result from TVC query
pub const TVCSearchResult = struct {
    /// Index of matching entry
    index: usize,

    /// Cosine similarity score [-1, 1]
    similarity: f64,

    /// Response text
    response: []const u8,

    /// Entry ID for tracking
    entry_id: u64,
};

/// TVC Corpus: main data structure for distributed continual learning
pub const TVCCorpus = struct {
    /// All entries (static allocation for determinism)
    entries: [TVC_MAX_ENTRIES]TVCEntry,

    /// Current entry count
    count: usize,

    /// Memory vector: bundled accumulation of all bound vectors (NO FORGETTING)
    memory_vector: HybridBigInt,

    /// Corpus version for sync
    version: u32,

    /// Unique node identifier
    node_id: [16]u8,

    /// Next entry ID
    next_entry_id: u64,

    /// Statistics
    total_queries: u64,
    total_hits: u64,
    total_stores: u64,

    const Self = @This();

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize empty TVC corpus
    pub fn init() Self {
        var corpus = Self{
            .entries = undefined,
            .count = 0,
            .memory_vector = HybridBigInt.zero(),
            .version = 1,
            .node_id = undefined,
            .next_entry_id = 1,
            .total_queries = 0,
            .total_hits = 0,
            .total_stores = 0,
        };

        // Generate random node ID
        var prng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        prng.fill(&corpus.node_id);

        return corpus;
    }

    /// Initialize with specific node ID
    pub fn initWithNodeId(node_id: [16]u8) Self {
        var corpus = init();
        corpus.node_id = node_id;
        return corpus;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CORE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Store query/response pair in TVC
    /// Returns entry ID on success
    pub fn store(self: *Self, query: []const u8, response: []const u8) !u64 {
        if (self.count >= TVC_MAX_ENTRIES) {
            return error.CorpusFull;
        }

        if (query.len == 0 or response.len == 0) {
            return error.EmptyInput;
        }

        // 1. Encode query and response to vectors
        var query_vec = vsa.encodeText(query);
        var response_vec = vsa.encodeText(response);

        // 2. Bind query and response (creates association)
        var bound_vec = vsa.bind(&query_vec, &response_vec);

        // 3. Create entry
        var entry = &self.entries[self.count];
        entry.query_vec = query_vec;
        entry.response_vec = response_vec;
        entry.bound_vec = bound_vec;

        // Copy text
        const query_copy_len = @min(query.len, TVC_MAX_QUERY_LEN);
        @memcpy(entry.query_text[0..query_copy_len], query[0..query_copy_len]);
        entry.query_len = @intCast(query_copy_len);

        const response_copy_len = @min(response.len, TVC_MAX_RESPONSE_LEN);
        @memcpy(entry.response_text[0..response_copy_len], response[0..response_copy_len]);
        entry.response_len = @intCast(response_copy_len);

        // Metadata
        entry.entry_id = self.next_entry_id;
        entry.timestamp = std.time.timestamp();
        entry.usage_count = 0;
        entry.avg_similarity = 0.0;
        entry.source_node = self.node_id;

        self.next_entry_id += 1;
        self.count += 1;

        // 4. Bundle into memory vector (NO FORGETTING)
        self.memory_vector = vsa.bundle2(&self.memory_vector, &bound_vec);

        // Update stats
        self.total_stores += 1;
        self.version += 1;

        return entry.entry_id;
    }

    /// Search TVC for similar query
    /// Returns result if similarity >= threshold
    pub fn search(self: *Self, query: []const u8, threshold: f64) ?TVCSearchResult {
        if (self.count == 0 or query.len == 0) return null;

        self.total_queries += 1;

        // Encode query
        var query_vec = vsa.encodeText(query);

        var best_idx: usize = 0;
        var best_sim: f64 = -2.0;

        // Linear search for best match
        for (0..self.count) |i| {
            const sim = vsa.cosineSimilarity(&query_vec, &self.entries[i].query_vec);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = i;
            }
        }

        // Check threshold
        if (best_sim >= threshold) {
            self.total_hits += 1;

            // Update usage count
            self.entries[best_idx].usage_count += 1;

            // Update running average similarity
            const entry = &self.entries[best_idx];
            const count_f: f32 = @floatFromInt(entry.usage_count);
            entry.avg_similarity = (entry.avg_similarity * (count_f - 1) + @as(f32, @floatCast(best_sim))) / count_f;

            return TVCSearchResult{
                .index = best_idx,
                .similarity = best_sim,
                .response = entry.getResponse(),
                .entry_id = entry.entry_id,
            };
        }

        return null;
    }

    /// Search with default threshold (φ⁻¹)
    pub fn searchDefault(self: *Self, query: []const u8) ?TVCSearchResult {
        return self.search(query, TVC_SIMILARITY_THRESHOLD);
    }

    /// Get hit rate (hits / total queries)
    pub fn getHitRate(self: *const Self) f64 {
        if (self.total_queries == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_hits)) / @as(f64, @floatFromInt(self.total_queries));
    }

    /// Get entry by index
    pub fn getEntry(self: *Self, index: usize) ?*TVCEntry {
        if (index >= self.count) return null;
        return &self.entries[index];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PERSISTENCE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Save corpus to file (.tvc format)
    pub fn save(self: *Self, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Header (64 bytes)
        try file.writeAll(&TVC_MAGIC);

        var buf4: [4]u8 = undefined;
        var buf8: [8]u8 = undefined;

        std.mem.writeInt(u32, &buf4, TVC_VERSION, .little);
        try file.writeAll(&buf4);

        std.mem.writeInt(u32, &buf4, @intCast(self.count), .little);
        try file.writeAll(&buf4);

        std.mem.writeInt(u32, &buf4, @intCast(self.memory_vector.trit_len), .little);
        try file.writeAll(&buf4);

        try file.writeAll(&self.node_id);

        std.mem.writeInt(u64, &buf8, self.next_entry_id, .little);
        try file.writeAll(&buf8);

        std.mem.writeInt(u64, &buf8, self.total_queries, .little);
        try file.writeAll(&buf8);

        std.mem.writeInt(u64, &buf8, self.total_hits, .little);
        try file.writeAll(&buf8);

        std.mem.writeInt(u64, &buf8, self.total_stores, .little);
        try file.writeAll(&buf8);

        // Memory vector (packed)
        self.memory_vector.ensureUnpacked();
        for (0..self.memory_vector.trit_len) |i| {
            const byte: [1]u8 = .{@bitCast(self.memory_vector.unpacked_cache[i])};
            try file.writeAll(&byte);
        }

        // Entries
        for (0..self.count) |i| {
            const entry = &self.entries[i];

            // Entry ID and metadata
            std.mem.writeInt(u64, &buf8, entry.entry_id, .little);
            try file.writeAll(&buf8);

            std.mem.writeInt(i64, @ptrCast(&buf8), entry.timestamp, .little);
            try file.writeAll(&buf8);

            std.mem.writeInt(u32, &buf4, entry.usage_count, .little);
            try file.writeAll(&buf4);

            try file.writeAll(std.mem.asBytes(&entry.avg_similarity));
            try file.writeAll(&entry.source_node);

            // Query vector
            entry.query_vec.ensureUnpacked();
            std.mem.writeInt(u32, &buf4, @intCast(entry.query_vec.trit_len), .little);
            try file.writeAll(&buf4);
            for (0..entry.query_vec.trit_len) |j| {
                const byte: [1]u8 = .{@bitCast(entry.query_vec.unpacked_cache[j])};
                try file.writeAll(&byte);
            }

            // Response vector
            entry.response_vec.ensureUnpacked();
            std.mem.writeInt(u32, &buf4, @intCast(entry.response_vec.trit_len), .little);
            try file.writeAll(&buf4);
            for (0..entry.response_vec.trit_len) |j| {
                const byte: [1]u8 = .{@bitCast(entry.response_vec.unpacked_cache[j])};
                try file.writeAll(&byte);
            }

            // Bound vector
            entry.bound_vec.ensureUnpacked();
            std.mem.writeInt(u32, &buf4, @intCast(entry.bound_vec.trit_len), .little);
            try file.writeAll(&buf4);
            for (0..entry.bound_vec.trit_len) |j| {
                const byte: [1]u8 = .{@bitCast(entry.bound_vec.unpacked_cache[j])};
                try file.writeAll(&byte);
            }

            // Query text
            var buf2: [2]u8 = undefined;
            std.mem.writeInt(u16, &buf2, entry.query_len, .little);
            try file.writeAll(&buf2);
            try file.writeAll(entry.query_text[0..entry.query_len]);

            // Response text
            std.mem.writeInt(u16, &buf2, entry.response_len, .little);
            try file.writeAll(&buf2);
            try file.writeAll(entry.response_text[0..entry.response_len]);
        }
    }

    /// Load corpus from file
    pub fn load(path: []const u8) !Self {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var corpus = Self.init();

        // Header
        var magic: [4]u8 = undefined;
        _ = try file.readAll(&magic);
        if (!std.mem.eql(u8, &magic, &TVC_MAGIC)) {
            return error.InvalidMagic;
        }

        var buf4: [4]u8 = undefined;
        var buf8: [8]u8 = undefined;
        var buf2: [2]u8 = undefined;

        _ = try file.readAll(&buf4);
        const version = std.mem.readInt(u32, &buf4, .little);
        if (version != TVC_VERSION) {
            return error.UnsupportedVersion;
        }

        _ = try file.readAll(&buf4);
        const count = std.mem.readInt(u32, &buf4, .little);
        if (count > TVC_MAX_ENTRIES) {
            return error.CorpusTooLarge;
        }

        _ = try file.readAll(&buf4);
        const mem_vec_len = std.mem.readInt(u32, &buf4, .little);

        _ = try file.readAll(&corpus.node_id);

        _ = try file.readAll(&buf8);
        corpus.next_entry_id = std.mem.readInt(u64, &buf8, .little);

        _ = try file.readAll(&buf8);
        corpus.total_queries = std.mem.readInt(u64, &buf8, .little);

        _ = try file.readAll(&buf8);
        corpus.total_hits = std.mem.readInt(u64, &buf8, .little);

        _ = try file.readAll(&buf8);
        corpus.total_stores = std.mem.readInt(u64, &buf8, .little);

        // Memory vector
        corpus.memory_vector = HybridBigInt.zero();
        corpus.memory_vector.mode = .unpacked_mode;
        corpus.memory_vector.trit_len = mem_vec_len;
        for (0..mem_vec_len) |i| {
            var byte: [1]u8 = undefined;
            _ = try file.readAll(&byte);
            corpus.memory_vector.unpacked_cache[i] = @bitCast(byte[0]);
        }

        // Entries
        for (0..count) |i| {
            var entry = &corpus.entries[i];

            // Metadata
            _ = try file.readAll(&buf8);
            entry.entry_id = std.mem.readInt(u64, &buf8, .little);

            _ = try file.readAll(&buf8);
            entry.timestamp = std.mem.readInt(i64, &buf8, .little);

            _ = try file.readAll(&buf4);
            entry.usage_count = std.mem.readInt(u32, &buf4, .little);

            var avg_sim_bytes: [4]u8 = undefined;
            _ = try file.readAll(&avg_sim_bytes);
            entry.avg_similarity = @bitCast(avg_sim_bytes);

            _ = try file.readAll(&entry.source_node);

            // Query vector
            _ = try file.readAll(&buf4);
            const q_len = std.mem.readInt(u32, &buf4, .little);
            entry.query_vec = HybridBigInt.zero();
            entry.query_vec.mode = .unpacked_mode;
            entry.query_vec.trit_len = q_len;
            for (0..q_len) |j| {
                var byte: [1]u8 = undefined;
                _ = try file.readAll(&byte);
                entry.query_vec.unpacked_cache[j] = @bitCast(byte[0]);
            }

            // Response vector
            _ = try file.readAll(&buf4);
            const r_len = std.mem.readInt(u32, &buf4, .little);
            entry.response_vec = HybridBigInt.zero();
            entry.response_vec.mode = .unpacked_mode;
            entry.response_vec.trit_len = r_len;
            for (0..r_len) |j| {
                var byte: [1]u8 = undefined;
                _ = try file.readAll(&byte);
                entry.response_vec.unpacked_cache[j] = @bitCast(byte[0]);
            }

            // Bound vector
            _ = try file.readAll(&buf4);
            const b_len = std.mem.readInt(u32, &buf4, .little);
            entry.bound_vec = HybridBigInt.zero();
            entry.bound_vec.mode = .unpacked_mode;
            entry.bound_vec.trit_len = b_len;
            for (0..b_len) |j| {
                var byte: [1]u8 = undefined;
                _ = try file.readAll(&byte);
                entry.bound_vec.unpacked_cache[j] = @bitCast(byte[0]);
            }

            // Query text
            _ = try file.readAll(&buf2);
            entry.query_len = std.mem.readInt(u16, &buf2, .little);
            _ = try file.readAll(entry.query_text[0..entry.query_len]);

            // Response text
            _ = try file.readAll(&buf2);
            entry.response_len = std.mem.readInt(u16, &buf2, .little);
            _ = try file.readAll(entry.response_text[0..entry.response_len]);
        }

        corpus.count = count;
        corpus.version = version;

        return corpus;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DISTRIBUTED SYNC
    // ═══════════════════════════════════════════════════════════════════════════

    /// Merge another corpus into this one (for distributed sync)
    /// Only adds entries not already present (by entry_id + source_node)
    pub fn merge(self: *Self, other: *Self) !usize {
        var added: usize = 0;

        for (0..other.count) |i| {
            const other_entry = &other.entries[i];

            // Check if entry already exists (same entry_id + source_node)
            var exists = false;
            for (0..self.count) |j| {
                const self_entry = &self.entries[j];
                if (self_entry.entry_id == other_entry.entry_id and
                    std.mem.eql(u8, &self_entry.source_node, &other_entry.source_node))
                {
                    exists = true;
                    break;
                }
            }

            if (!exists and self.count < TVC_MAX_ENTRIES) {
                // Copy entry
                self.entries[self.count] = other_entry.*;
                self.count += 1;
                added += 1;

                // Bundle into memory
                var bound_copy = other_entry.bound_vec;
                self.memory_vector = vsa.bundle2(&self.memory_vector, &bound_copy);
            }
        }

        if (added > 0) {
            self.version += 1;
        }

        return added;
    }

    /// Get corpus statistics
    pub fn getStats(self: *const Self) TVCStats {
        return TVCStats{
            .entry_count = self.count,
            .max_entries = TVC_MAX_ENTRIES,
            .total_queries = self.total_queries,
            .total_hits = self.total_hits,
            .total_stores = self.total_stores,
            .hit_rate = self.getHitRate(),
            .version = self.version,
            .memory_vec_len = self.memory_vector.trit_len,
        };
    }
};

/// TVC statistics
pub const TVCStats = struct {
    entry_count: usize,
    max_entries: usize,
    total_queries: u64,
    total_hits: u64,
    total_stores: u64,
    hit_rate: f64,
    version: u32,
    memory_vec_len: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TVCCorpus basic store and search" {
    var corpus = TVCCorpus.init();

    // Store some entries
    const id1 = try corpus.store("What is VSA?", "VSA is Vector Symbolic Architecture for hyperdimensional computing.");
    const id2 = try corpus.store("How does bind work?", "Bind creates associations between vectors via element-wise multiplication.");

    try std.testing.expect(id1 == 1);
    try std.testing.expect(id2 == 2);
    try std.testing.expect(corpus.count == 2);

    // Search for similar query
    if (corpus.searchDefault("What is Vector Symbolic Architecture?")) |result| {
        try std.testing.expect(result.similarity > 0.3);
        try std.testing.expect(std.mem.indexOf(u8, result.response, "VSA") != null);
    }
}

test "TVCCorpus save and load" {
    var corpus = TVCCorpus.init();

    _ = try corpus.store("Test query", "Test response");
    _ = try corpus.store("Another query", "Another response");

    // Save
    try corpus.save("test_corpus.tvc");

    // Load
    var loaded = try TVCCorpus.load("test_corpus.tvc");

    try std.testing.expect(loaded.count == 2);
    try std.testing.expect(std.mem.eql(u8, loaded.entries[0].getQuery(), "Test query"));
    try std.testing.expect(std.mem.eql(u8, loaded.entries[0].getResponse(), "Test response"));

    // Cleanup
    std.fs.cwd().deleteFile("test_corpus.tvc") catch {};
}

test "TVCCorpus merge" {
    var corpus1 = TVCCorpus.init();
    var corpus2 = TVCCorpus.initWithNodeId(.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 });

    _ = try corpus1.store("Query A", "Response A");
    _ = try corpus2.store("Query B", "Response B");

    const added = try corpus1.merge(&corpus2);
    try std.testing.expect(added == 1);
    try std.testing.expect(corpus1.count == 2);
}
