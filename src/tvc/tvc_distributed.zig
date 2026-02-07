// ═══════════════════════════════════════════════════════════════════════════════
// TVC DISTRIBUTED — File-Based Distributed Corpus Sharing
// ═══════════════════════════════════════════════════════════════════════════════
//
// Simple file-based distributed learning:
// - Export corpus to .tvc file
// - Import from peer corpus files
// - Merge without duplicates
// - Sync between nodes
//
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL | TVC DISTRIBUTED
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tvc_corpus = @import("tvc_corpus");

const TVCCorpus = tvc_corpus.TVCCorpus;
const TVCStats = tvc_corpus.TVCStats;

// ═══════════════════════════════════════════════════════════════════════════════
// TVC DISTRIBUTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const TVCDistributor = struct {
    /// Primary corpus
    corpus: *TVCCorpus,

    /// Sync directory for peer files
    sync_dir: ?[]const u8,

    /// Auto-sync enabled
    auto_sync: bool,

    /// Last sync timestamp
    last_sync: i64,

    /// Sync statistics
    total_syncs: u64,
    total_imported: u64,
    total_exported: u64,

    const Self = @This();

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize distributor with corpus
    pub fn init(corpus: *TVCCorpus) Self {
        return Self{
            .corpus = corpus,
            .sync_dir = null,
            .auto_sync = false,
            .last_sync = 0,
            .total_syncs = 0,
            .total_imported = 0,
            .total_exported = 0,
        };
    }

    /// Set sync directory
    pub fn setSyncDir(self: *Self, dir: []const u8) void {
        self.sync_dir = dir;
    }

    /// Enable auto-sync
    pub fn enableAutoSync(self: *Self) void {
        self.auto_sync = true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXPORT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Export corpus to file
    pub fn exportToFile(self: *Self, path: []const u8) !void {
        try self.corpus.save(path);
        self.total_exported += 1;
        self.last_sync = std.time.timestamp();
    }

    /// Export to sync directory with node ID filename
    pub fn exportToSyncDir(self: *Self) !void {
        if (self.sync_dir == null) {
            return error.NoSyncDir;
        }

        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/node_{x}.tvc", .{
            self.sync_dir.?,
            std.mem.readInt(u64, self.corpus.node_id[0..8], .little),
        });

        try self.exportToFile(path);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // IMPORT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Import corpus from file and merge
    pub fn importFromFile(self: *Self, path: []const u8) !usize {
        var other = try TVCCorpus.load(path);
        const added = try self.corpus.merge(&other);
        self.total_imported += added;
        self.last_sync = std.time.timestamp();
        return added;
    }

    /// Import all .tvc files from sync directory
    pub fn importFromSyncDir(self: *Self) !usize {
        if (self.sync_dir == null) {
            return error.NoSyncDir;
        }

        var total_added: usize = 0;

        var dir = try std.fs.cwd().openDir(self.sync_dir.?, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;

            // Check for .tvc extension
            if (std.mem.endsWith(u8, entry.name, ".tvc")) {
                // Skip own node file
                var own_filename_buf: [64]u8 = undefined;
                const own_filename = std.fmt.bufPrint(&own_filename_buf, "node_{x}.tvc", .{
                    std.mem.readInt(u64, self.corpus.node_id[0..8], .little),
                }) catch continue;

                if (std.mem.eql(u8, entry.name, own_filename)) continue;

                // Build full path
                var path_buf: [512]u8 = undefined;
                const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{
                    self.sync_dir.?,
                    entry.name,
                }) catch continue;

                // Import and merge
                const added = self.importFromFile(full_path) catch continue;
                total_added += added;
            }
        }

        self.total_syncs += 1;
        return total_added;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SYNC
    // ═══════════════════════════════════════════════════════════════════════════

    /// Full sync: export own, import all peers
    pub fn sync(self: *Self) !SyncResult {
        const start_count = self.corpus.count;

        // Export own corpus
        try self.exportToSyncDir();

        // Import from peers
        const imported = try self.importFromSyncDir();

        return SyncResult{
            .entries_before = start_count,
            .entries_after = self.corpus.count,
            .imported = imported,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Sync with specific peer file
    pub fn syncWithPeer(self: *Self, peer_path: []const u8) !SyncResult {
        const start_count = self.corpus.count;
        const imported = try self.importFromFile(peer_path);

        return SyncResult{
            .entries_before = start_count,
            .entries_after = self.corpus.count,
            .imported = imported,
            .timestamp = std.time.timestamp(),
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get distributor statistics
    pub fn getStats(self: *const Self) DistributorStats {
        return DistributorStats{
            .corpus_stats = self.corpus.getStats(),
            .total_syncs = self.total_syncs,
            .total_imported = self.total_imported,
            .total_exported = self.total_exported,
            .last_sync = self.last_sync,
            .auto_sync_enabled = self.auto_sync,
        };
    }

    /// Print distributor statistics
    pub fn printStats(self: *const Self) void {
        const stats = self.getStats();
        const GOLDEN = "\x1b[38;2;255;215;0m";
        const GREEN = "\x1b[38;2;0;229;153m";
        const RESET = "\x1b[0m";

        std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}                TVC DISTRIBUTED STATISTICS{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("Corpus entries:    {d}\n", .{stats.corpus_stats.entry_count});
        std.debug.print("Total syncs:       {d}\n", .{stats.total_syncs});
        std.debug.print("Total imported:    {s}{d}{s}\n", .{ GREEN, stats.total_imported, RESET });
        std.debug.print("Total exported:    {d}\n", .{stats.total_exported});
        std.debug.print("Auto-sync:         {s}\n", .{if (stats.auto_sync_enabled) "Enabled" else "Disabled"});
        std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
    }
};

/// Sync result
pub const SyncResult = struct {
    entries_before: usize,
    entries_after: usize,
    imported: usize,
    timestamp: i64,

    pub fn print(self: *const SyncResult) void {
        const GREEN = "\x1b[38;2;0;229;153m";
        const RESET = "\x1b[0m";

        std.debug.print("\n[TVC SYNC] {s}+{d}{s} entries imported ({d} -> {d})\n", .{
            GREEN,
            self.imported,
            RESET,
            self.entries_before,
            self.entries_after,
        });
    }
};

/// Distributor statistics
pub const DistributorStats = struct {
    corpus_stats: TVCStats,
    total_syncs: u64,
    total_imported: u64,
    total_exported: u64,
    last_sync: i64,
    auto_sync_enabled: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEMO: Two Node Simulation
// ═══════════════════════════════════════════════════════════════════════════════

/// Simulate distributed learning between two nodes
pub fn simulateTwoNodes() !void {
    const GOLDEN = "\x1b[38;2;255;215;0m";
    const GREEN = "\x1b[38;2;0;229;153m";
    const CYAN = "\x1b[38;2;0;255;255m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}           TVC DISTRIBUTED DEMO: TWO NODES{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Create two nodes with different IDs
    var node1 = TVCCorpus.initWithNodeId(.{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 });
    var node2 = TVCCorpus.initWithNodeId(.{ 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2 });

    // Node 1 stores some patterns
    std.debug.print("{s}[Node 1]{s} Storing patterns...\n", .{ CYAN, RESET });
    _ = try node1.store("What is VSA?", "VSA is Vector Symbolic Architecture for hyperdimensional computing.");
    _ = try node1.store("How does bind work?", "Bind creates associations between vectors via element-wise multiplication.");
    std.debug.print("  Stored 2 entries\n", .{});

    // Node 2 stores different patterns
    std.debug.print("{s}[Node 2]{s} Storing patterns...\n", .{ CYAN, RESET });
    _ = try node2.store("What is bundle?", "Bundle combines multiple vectors using majority vote.");
    _ = try node2.store("What is similarity?", "Cosine similarity measures alignment between vectors.");
    std.debug.print("  Stored 2 entries\n", .{});

    // Node 1 exports
    std.debug.print("\n{s}[Node 1]{s} Exporting to node1.tvc...\n", .{ CYAN, RESET });
    try node1.save("node1.tvc");

    // Node 2 exports
    std.debug.print("{s}[Node 2]{s} Exporting to node2.tvc...\n", .{ CYAN, RESET });
    try node2.save("node2.tvc");

    // Node 1 imports from Node 2
    std.debug.print("\n{s}[Node 1]{s} Importing from node2.tvc...\n", .{ CYAN, RESET });
    var node2_copy = try TVCCorpus.load("node2.tvc");
    const added1 = try node1.merge(&node2_copy);
    std.debug.print("  {s}+{d}{s} entries imported (now {d} total)\n", .{ GREEN, added1, RESET, node1.count });

    // Node 2 imports from Node 1
    std.debug.print("{s}[Node 2]{s} Importing from node1.tvc...\n", .{ CYAN, RESET });
    var node1_copy = try TVCCorpus.load("node1.tvc");
    const added2 = try node2.merge(&node1_copy);
    std.debug.print("  {s}+{d}{s} entries imported (now {d} total)\n", .{ GREEN, added2, RESET, node2.count });

    // Test retrieval on both nodes
    std.debug.print("\n{s}[TEST]{s} Query on Node 1: \"What is VSA?\"\n", .{ GOLDEN, RESET });
    if (node1.searchDefault("What is VSA?")) |result| {
        std.debug.print("  HIT: similarity={d:.3}\n", .{result.similarity});
        std.debug.print("  Response: {s}\n", .{result.response});
    }

    std.debug.print("\n{s}[TEST]{s} Query on Node 2: \"What is bundle?\"\n", .{ GOLDEN, RESET });
    if (node2.searchDefault("What is bundle?")) |result| {
        std.debug.print("  HIT: similarity={d:.3}\n", .{result.similarity});
        std.debug.print("  Response: {s}\n", .{result.response});
    }

    // Cross-node query (pattern learned from other node)
    std.debug.print("\n{s}[CROSS-NODE]{s} Query on Node 2: \"How does bind work?\"\n", .{ GOLDEN, RESET });
    if (node2.searchDefault("How does bind work?")) |result| {
        std.debug.print("  {s}HIT{s}: similarity={d:.3}\n", .{ GREEN, RESET, result.similarity });
        std.debug.print("  Response: {s}\n", .{result.response});
        std.debug.print("  {s}(Pattern learned from Node 1!){s}\n", .{ GREEN, RESET });
    }

    // Cleanup
    std.fs.cwd().deleteFile("node1.tvc") catch {};
    std.fs.cwd().deleteFile("node2.tvc") catch {};

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}           DISTRIBUTED DEMO COMPLETE{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY | TVC DISTRIBUTED{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TVCDistributor export and import" {
    var corpus1 = TVCCorpus.init();
    var dist1 = TVCDistributor.init(&corpus1);

    _ = try corpus1.store("Test query", "Test response");
    try dist1.exportToFile("test_dist.tvc");

    var corpus2 = TVCCorpus.init();
    var dist2 = TVCDistributor.init(&corpus2);

    const added = try dist2.importFromFile("test_dist.tvc");
    try std.testing.expect(added == 1);
    try std.testing.expect(corpus2.count == 1);

    std.fs.cwd().deleteFile("test_dist.tvc") catch {};
}

test "TVCDistributor sync" {
    var corpus1 = TVCCorpus.initWithNodeId(.{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 });
    var corpus2 = TVCCorpus.initWithNodeId(.{ 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2 });

    _ = try corpus1.store("Query A", "Response A");
    _ = try corpus2.store("Query B", "Response B");

    // Export both
    try corpus1.save("sync_test1.tvc");
    try corpus2.save("sync_test2.tvc");

    // Cross-import
    var loaded2 = try TVCCorpus.load("sync_test2.tvc");
    const added1 = try corpus1.merge(&loaded2);

    var loaded1 = try TVCCorpus.load("sync_test1.tvc");
    const added2 = try corpus2.merge(&loaded1);

    try std.testing.expect(added1 == 1);
    try std.testing.expect(added2 == 1);
    try std.testing.expect(corpus1.count == 2);
    try std.testing.expect(corpus2.count == 2);

    std.fs.cwd().deleteFile("sync_test1.tvc") catch {};
    std.fs.cwd().deleteFile("sync_test2.tvc") catch {};
}
