// ═══════════════════════════════════════════════════════════════════════════════
// TVC GATE — Golden Chain Link 0: Mandatory First Check
// ═══════════════════════════════════════════════════════════════════════════════
//
// All queries → TVC Gate → Search corpus → HIT? → Return cached
//                                        → MISS? → Continue pipeline → Store result
//
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL | TVC DISTRIBUTED
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const golden_chain = @import("golden_chain.zig");
const tvc_corpus = @import("tvc_corpus");

const TVCCorpus = tvc_corpus.TVCCorpus;
const TVCSearchResult = tvc_corpus.TVCSearchResult;
const LinkMetrics = golden_chain.LinkMetrics;
const ChainError = golden_chain.ChainError;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default similarity threshold (φ⁻¹ = Golden Ratio inverse)
pub const TVC_GATE_THRESHOLD: f64 = tvc_corpus.TVC_SIMILARITY_THRESHOLD;

/// Auto-save interval (every N stores)
pub const TVC_AUTOSAVE_INTERVAL: u32 = 10;

// ═══════════════════════════════════════════════════════════════════════════════
// TVC GATE RESULT
// ═══════════════════════════════════════════════════════════════════════════════

/// Result of TVC Gate execution
pub const TVCGateResult = union(enum) {
    /// Cache hit - return cached response
    hit: TVCHit,

    /// Cache miss - continue pipeline
    miss: void,

    pub const TVCHit = struct {
        /// Cached response text
        response: []const u8,

        /// Similarity score
        similarity: f64,

        /// Entry ID for tracking
        entry_id: u64,
    };

    pub fn isHit(self: TVCGateResult) bool {
        return self == .hit;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TVC GATE
// ═══════════════════════════════════════════════════════════════════════════════

/// TVC Gate: Mandatory first check in Golden Chain
pub const TVCGate = struct {
    /// TVC Corpus (shared reference)
    corpus: *TVCCorpus,

    /// Similarity threshold for retrieval
    similarity_threshold: f64,

    /// Auto-save path (null = disabled)
    autosave_path: ?[]const u8,

    /// Stores since last save
    stores_since_save: u32,

    /// Statistics
    total_hits: u64,
    total_misses: u64,
    total_stores: u64,

    /// Enable verbose logging
    verbose: bool,

    const Self = @This();

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize TVC Gate with corpus
    pub fn init(corpus: *TVCCorpus) Self {
        return Self{
            .corpus = corpus,
            .similarity_threshold = TVC_GATE_THRESHOLD,
            .autosave_path = null,
            .stores_since_save = 0,
            .total_hits = 0,
            .total_misses = 0,
            .total_stores = 0,
            .verbose = false,
        };
    }

    /// Initialize with custom threshold
    pub fn initWithThreshold(corpus: *TVCCorpus, threshold: f64) Self {
        var gate = init(corpus);
        gate.similarity_threshold = threshold;
        return gate;
    }

    /// Enable auto-save
    pub fn enableAutosave(self: *Self, path: []const u8) void {
        self.autosave_path = path;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CORE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute TVC Gate check
    /// Returns hit with cached response, or miss to continue pipeline
    pub fn execute(self: *Self, query: []const u8) TVCGateResult {
        if (query.len == 0) {
            return .miss;
        }

        // Search TVC corpus
        if (self.corpus.search(query, self.similarity_threshold)) |result| {
            self.total_hits += 1;

            if (self.verbose) {
                std.debug.print("[TVC GATE] HIT: similarity={d:.3}, entry_id={d}\n", .{
                    result.similarity,
                    result.entry_id,
                });
            }

            return TVCGateResult{
                .hit = .{
                    .response = result.response,
                    .similarity = result.similarity,
                    .entry_id = result.entry_id,
                },
            };
        }

        self.total_misses += 1;

        if (self.verbose) {
            std.debug.print("[TVC GATE] MISS: query=\"{s}\"\n", .{
                if (query.len > 50) query[0..50] else query,
            });
        }

        return .miss;
    }

    /// Store query/response pair after pipeline execution
    pub fn storeResponse(self: *Self, query: []const u8, response: []const u8) !u64 {
        const entry_id = try self.corpus.store(query, response);
        self.total_stores += 1;
        self.stores_since_save += 1;

        if (self.verbose) {
            std.debug.print("[TVC GATE] STORE: entry_id={d}, corpus_size={d}\n", .{
                entry_id,
                self.corpus.count,
            });
        }

        // Auto-save if enabled
        if (self.autosave_path) |path| {
            if (self.stores_since_save >= TVC_AUTOSAVE_INTERVAL) {
                self.corpus.save(path) catch |err| {
                    std.debug.print("[TVC GATE] Autosave failed: {}\n", .{err});
                };
                self.stores_since_save = 0;
            }
        }

        return entry_id;
    }

    /// Execute as Golden Chain link (returns LinkMetrics)
    pub fn executeAsLink(self: *Self, query: []const u8) ChainError!LinkMetrics {
        var metrics = LinkMetrics{};
        const start = std.time.milliTimestamp();

        const result = self.execute(query);
        metrics.duration_ms = @intCast(std.time.milliTimestamp() - start);

        switch (result) {
            .hit => |h| {
                // Hit - 100% improvement (skip entire pipeline)
                metrics.improvement_rate = 1.0;
                metrics.coverage_percent = h.similarity * 100.0;
            },
            .miss => {
                // Miss - continue pipeline
                metrics.improvement_rate = 0.0;
            },
        }

        return metrics;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get gate hit rate
    pub fn getHitRate(self: *const Self) f64 {
        const total = self.total_hits + self.total_misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_hits)) / @as(f64, @floatFromInt(total));
    }

    /// Get gate statistics
    pub fn getStats(self: *const Self) TVCGateStats {
        return TVCGateStats{
            .total_hits = self.total_hits,
            .total_misses = self.total_misses,
            .total_stores = self.total_stores,
            .hit_rate = self.getHitRate(),
            .corpus_size = self.corpus.count,
            .threshold = self.similarity_threshold,
        };
    }

    /// Print gate statistics
    pub fn printStats(self: *const Self) void {
        const stats = self.getStats();
        const GOLDEN = "\x1b[38;2;255;215;0m";
        const GREEN = "\x1b[38;2;0;229;153m";
        const RESET = "\x1b[0m";

        std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}                    TVC GATE STATISTICS{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("Hits:        {d}\n", .{stats.total_hits});
        std.debug.print("Misses:      {d}\n", .{stats.total_misses});
        std.debug.print("Stores:      {d}\n", .{stats.total_stores});
        std.debug.print("Hit Rate:    {s}{d:.1}%{s}\n", .{ GREEN, stats.hit_rate * 100, RESET });
        std.debug.print("Corpus Size: {d}\n", .{stats.corpus_size});
        std.debug.print("Threshold:   {d:.3} (phi^-1)\n", .{stats.threshold});
        std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PERSISTENCE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Save corpus to file
    pub fn save(self: *Self, path: []const u8) !void {
        try self.corpus.save(path);
        self.stores_since_save = 0;
    }

    /// Load corpus from file
    pub fn loadCorpus(path: []const u8) !TVCCorpus {
        return TVCCorpus.load(path);
    }
};

/// TVC Gate statistics
pub const TVCGateStats = struct {
    total_hits: u64,
    total_misses: u64,
    total_stores: u64,
    hit_rate: f64,
    corpus_size: usize,
    threshold: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TVCGate basic hit/miss" {
    var corpus = TVCCorpus.init();
    var gate = TVCGate.init(&corpus);

    // Initially should miss
    const result1 = gate.execute("What is VSA?");
    try std.testing.expect(!result1.isHit());

    // Store a response
    _ = try gate.storeResponse("What is VSA?", "VSA is Vector Symbolic Architecture.");

    // Now should hit on similar query
    const result2 = gate.execute("What is VSA?");
    try std.testing.expect(result2.isHit());
}

test "TVCGate statistics" {
    var corpus = TVCCorpus.init();
    var gate = TVCGate.init(&corpus);

    // Execute some queries
    _ = gate.execute("Query 1");
    _ = gate.execute("Query 2");
    _ = try gate.storeResponse("Query 1", "Response 1");
    _ = gate.execute("Query 1");

    const stats = gate.getStats();
    try std.testing.expect(stats.total_misses == 2);
    try std.testing.expect(stats.total_stores == 1);
    // Hit depends on similarity threshold
}

test "TVCGate as link" {
    var corpus = TVCCorpus.init();
    var gate = TVCGate.init(&corpus);

    const metrics = try gate.executeAsLink("Test query");
    try std.testing.expect(metrics.improvement_rate == 0.0); // Miss
}
