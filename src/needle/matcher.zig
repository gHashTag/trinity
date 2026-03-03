// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Matcher with Tier 0→1→2 Fallback Chain
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unified matcher that tries multiple approaches in order:
// - Tier 1: AST-based matching (tree-sitter) - highest accuracy
// - Tier 2: Semantic VSA search - future feature
// - Tier 0: Fuzzy text matching - fallback
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const needle = @import("needle.zig");
const fuzzy = @import("fuzzy.zig");

const MatchResult = needle.MatchResult;
const MatchResultList = needle.MatchResultList;
const MatchKind = needle.MatchKind;
const NeedleConfig = needle.NeedleConfig;
const Query = needle.Query;
const QueryKind = needle.QueryKind;

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED MATCHER
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified matcher with tier-based fallback
pub const Matcher = struct {
    allocator: std.mem.Allocator,
    config: NeedleConfig,
    source: []const u8,
    file_path: []const u8,

    /// Create a new matcher
    pub fn init(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8) Matcher {
        return .{
            .allocator = allocator,
            .config = NeedleConfig.default(),
            .source = source,
            .file_path = file_path,
        };
    }

    /// Create matcher with custom config
    pub fn withConfig(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8, config: NeedleConfig) Matcher {
        return .{
            .allocator = allocator,
            .config = config,
            .source = source,
            .file_path = file_path,
        };
    }

    /// Find matches using the tier-based fallback chain
    pub fn findMatches(self: *Matcher, pattern_query: []const u8) !MatchResultList {
        var all_results = MatchResultList.init(self.allocator);
        errdefer all_results.deinit();

        const query = Query.parse(pattern_query);

        // Try Tier 1: AST-based matching
        if (self.config.enable_tier1_structural and query.kind == .sexpr) {
            if (try self.tryAstMatch(query, &all_results)) {
                // Got good AST results, use them
                return self.finalizeResults(&all_results);
            }
        }

        // Try Tier 2: Semantic VSA search (future - placeholder)
        if (self.config.enable_tier2_semantic) {
            // TODO: Implement VSA semantic search
            // This is a placeholder for Tier 2
        }

        // Try Tier 0: Fuzzy text fallback
        if (self.config.enable_tier0_text) {
            try self.tryFuzzyMatch(pattern_query, &all_results);
        }

        return self.finalizeResults(&all_results);
    }

    /// Try AST-based matching (Tier 1)
    fn tryAstMatch(self: *Matcher, query: Query, results: *MatchResultList) !bool {
        _ = self;
        _ = query;
        _ = results;
        // Check if tree-sitter is available
        const ts_available = comptime blk: {
            // This will be true when tree-sitter is linked
            break :blk false;
        };

        if (!ts_available) return false;

        // TODO: Implement actual tree-sitter query
        // For now, return false to fallback to Tier 0
        _ = query;
        _ = results;
        return false;
    }

    /// Try fuzzy text matching (Tier 0)
    fn tryFuzzyMatch(self: *Matcher, pattern_query: []const u8, results: *MatchResultList) !void {
        var fuzzy_matcher = try fuzzy.FuzzyMatcher.init(self.allocator, self.source);
        defer fuzzy_matcher.deinit();

        var fuzzy_results = try fuzzy_matcher.findMatches(pattern_query);
        defer fuzzy_results.deinit();

        // Add fuzzy results to combined results
        for (fuzzy_results.items.items) |item| {
            // Clone the item since fuzzy_results will be freed
            const cloned = MatchResult{
                .node_id = item.node_id,
                .start_line = item.start_line,
                .end_line = item.end_line,
                .start_column = item.start_column,
                .end_column = item.end_column,
                .matched_text = try self.allocator.dupe(u8, item.matched_text),
                .confidence = item.confidence,
                .kind = item.kind,
            };
            try results.append(cloned);
        }
    }

    /// Finalize and process results
    fn finalizeResults(self: *Matcher, results: *MatchResultList) !MatchResultList {
        var final = MatchResultList.init(self.allocator);

        // Filter by confidence threshold
        try results.filter(self.config.confidence_threshold);

        // Sort by confidence
        results.sortByConfidence();

        // Limit to max matches
        results.limit(self.config.max_matches);

        // Assign node IDs
        for (results.items.items, 0..) |*item, i| {
            item.node_id = @intCast(i + 1);
        }

        final = results.*;
        return final;
    }

    /// Find a single best match
    pub fn findBestMatch(self: *Matcher, pattern_query: []const u8) !?MatchResult {
        var results = try self.findMatches(pattern_query);
        defer results.deinit();

        if (results.isEmpty()) return null;

        // Clone the first result
        const best = results.items[0];
        return MatchResult{
            .node_id = best.node_id,
            .start_line = best.start_line,
            .end_line = best.end_line,
            .start_column = best.start_column,
            .end_column = best.end_column,
            .matched_text = try self.allocator.dupe(u8, best.matched_text),
            .confidence = best.confidence,
            .kind = best.kind,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCHER (multi-file)
// ═══════════════════════════════════════════════════════════════════════════════

/// Multi-file searcher
pub const Searcher = struct {
    allocator: std.mem.Allocator,
    config: NeedleConfig,
    file_paths: std.ArrayListAligned([]const u8, null),

    pub fn init(allocator: std.mem.Allocator) Searcher {
        return .{
            .allocator = allocator,
            .config = NeedleConfig.default(),
            .file_paths = .{ .items = &.{}, .capacity = 0 },
        };
    }

    pub fn deinit(self: *Searcher) void {
        for (self.file_paths.items) |path| {
            self.allocator.free(path);
        }
        self.file_paths.deinit();
    }

    /// Add a file to search
    pub fn addFile(self: *Searcher, path: []const u8) !void {
        const dupe = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(dupe);
        try self.file_paths.append(dupe);
    }

    /// Add multiple files
    pub fn addFiles(self: *Searcher, paths: []const []const u8) !void {
        for (paths) |path| {
            try self.addFile(path);
        }
    }

    /// Search across all files
    pub fn search(self: *Searcher, pattern_query: []const u8) !MatchResultList {
        var all_results = MatchResultList.init(self.allocator);
        errdefer all_results.deinit();

        for (self.file_paths.items) |file_path| {
            const source = try std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000);
            defer self.allocator.free(source);

            var matcher = Matcher.withConfig(self.allocator, source, file_path, self.config);
            var file_results = try matcher.findMatches(pattern_query);
            defer file_results.deinit();

            // Add file path to each result (we could extend MatchResult for this)
            for (file_results.items) |item| {
                try all_results.append(item);
            }
        }

        // Sort all results by confidence
        all_results.sortByConfidence();
        all_results.limit(self.config.max_matches);

        // Transfer ownership to caller
        const final = all_results;
        all_results.items = .empty; // Prevent deinit
        return final;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Quick search in a single file
pub fn search(allocator: std.mem.Allocator, file_path: []const u8, pattern: []const u8) !MatchResultList {
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(source);

    var matcher = Matcher.init(allocator, source, file_path);
    return matcher.findMatches(pattern);
}

/// Quick search in source string
pub fn searchSource(allocator: std.mem.Allocator, source: []const u8, pattern: []const u8) !MatchResultList {
    var matcher = Matcher.init(allocator, source, "(memory)");
    return matcher.findMatches(pattern);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Matcher find matches" {
    const source =
        \\pub fn add(a: i32, b: i32) i32
        \\pub fn subtract(x: i32, y: i32) i32
    ;

    var matcher = Matcher.init(std.testing.allocator, source, "test.zig");
    var results = try matcher.findMatches("add");
    defer results.deinit();

    try std.testing.expect(results.len() > 0);
}

test "Matcher find best match" {
    const source =
        \\pub fn calculateSum(x: i32, y: i32) i32
        \\pub fn helper()
    ;

    var matcher = Matcher.init(std.testing.allocator, source, "test.zig");
    const best = try matcher.findBestMatch("calculate");

    try std.testing.expect(best != null);
    try std.testing.expectEqual(@as(f32, 0.8), best.?.confidence);
}

test "Matcher no matches" {
    const source =
        \\pub fn functionOne()
        \\pub fn functionTwo()
    ;

    var matcher = Matcher.init(std.testing.allocator, source, "test.zig");
    var results = try matcher.findMatches("nonexistent");
    defer results.deinit();

    try std.testing.expect(results.isEmpty());
}

test "Matcher confidence filter" {
    const source =
        \\pub fn add(a: i32, b: i32) i32
        \\pub fn helper()
    ;

    var config = NeedleConfig.default();
    config.confidence_threshold = 0.9;

    var matcher = Matcher.withConfig(std.testing.allocator, source, "test.zig", config);
    var results = try matcher.findMatches("add"); // Should match exactly
    defer results.deinit();

    try std.testing.expect(results.len() > 0);
    try std.testing.expect(results.items[0].confidence >= 0.9);
}

test "Searcher multi-file" {
    // Create temporary test files
    const tmp = std.testing.tmpDir;

    try tmp.writeFile("test1.zig",
        \\pub fn add(a: i32, b: i32) i32
    );
    defer {
        tmp.cleanup();
    }

    try tmp.writeFile("test2.zig",
        \\pub fn subtract(x: i32, y: i32) i32
    );

    var searcher = Searcher.init(std.testing.allocator);
    defer searcher.deinit();

    try searcher.addFile("test1.zig");
    try searcher.addFile("test2.zig");

    var results = try searcher.search("fn");
    defer results.deinit();

    // Should find both function declarations
    try std.testing.expect(results.len() >= 2);
}

test "searchSource convenience" {
    const source = "pub fn add(a: i32, b: i32) i32";

    var results = try searchSource(std.testing.allocator, source, "add");
    defer results.deinit();

    try std.testing.expect(results.len() > 0);
}
