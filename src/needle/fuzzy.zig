// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Tier 0: Fuzzy Text Matcher (Aider-style layered matching)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Three-layer matching fallback when Tree-sitter is unavailable:
// 1. Exact match (confidence = 1.0)
// 2. Word-level match (confidence = 0.8)
// 3. Fuzzy SequenceMatcher ratio (confidence = ratio * 0.6)
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const needle = @import("needle.zig");
const MatchResult = needle.MatchResult;
const MatchResultList = needle.MatchResultList;
const MatchKind = needle.MatchKind;

// ═══════════════════════════════════════════════════════════════════════════════
// FUZZY MATCHER
// ═══════════════════════════════════════════════════════════════════════════════

/// Fuzzy text matcher with three-layer approach
pub const FuzzyMatcher = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    lines: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !FuzzyMatcher {
        var lines = std.ArrayList([]const u8).init(allocator);
        errdefer lines.deinit();

        var iter = std.mem.splitScalar(u8, source, '\n');
        while (iter.next()) |line| {
            try lines.append(line);
        }

        return .{
            .allocator = allocator,
            .source = source,
            .lines = lines,
        };
    }

    pub fn deinit(self: *FuzzyMatcher) void {
        self.lines.deinit();
    }

    /// Find all matches using three-layer approach
    pub fn findMatches(self: *FuzzyMatcher, query: []const u8) !MatchResultList {
        var results = MatchResultList.init(self.allocator);
        errdefer results.deinit();

        const trimmed_query = std.mem.trim(u8, query, " \t\n");

        for (self.lines.items, 0..) |line, line_idx| {
            const line_num: u32 = @intCast(line_idx + 1);
            const trimmed_line = std.mem.trim(u8, line, " \t");

            // Layer 1: Exact match
            if (self.exactMatch(trimmed_line, trimmed_query)) {
                try results.append(try MatchResult.init(
                    self.allocator,
                    line_num,
                    line_num,
                    line,
                    1.0,
                    .fuzzy_text,
                ));
                continue;
            }

            // Layer 2: Word-level match
            if (self.wordLevelMatch(trimmed_line, trimmed_query)) |conf| {
                try results.append(try MatchResult.init(
                    self.allocator,
                    line_num,
                    line_num,
                    line,
                    conf,
                    .fuzzy_text,
                ));
                continue;
            }

            // Layer 3: Fuzzy ratio match
            if (self.fuzzyMatch(trimmed_line, trimmed_query)) |conf| {
                if (conf >= 0.3) { // Minimum threshold for fuzzy
                    try results.append(try MatchResult.init(
                        self.allocator,
                        line_num,
                        line_num,
                        line,
                        conf,
                        .fuzzy_text,
                    ));
                }
            }
        }

        return results;
    }

    /// Layer 1: Exact match
    fn exactMatch(self: *FuzzyMatcher, line: []const u8, query: []const u8) bool {
        _ = self;
        return std.mem.eql(u8, line, query) or
            std.mem.indexOf(u8, line, query) != null;
    }

    /// Layer 2: Word-level match (order-agnostic)
    fn wordLevelMatch(self: *FuzzyMatcher, line: []const u8, query: []const u8) ?f32 {
        // Tokenize query into words
        var query_words = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (query_words.items) |w| {
                self.allocator.free(w);
            }
            query_words.deinit();
        }

        var query_iter = std.mem.tokenizeScalar(u8, query, ' ');
        while (query_iter.next()) |word| {
            const trimmed = std.mem.trim(u8, word, " \t");
            if (trimmed.len > 0) {
                try query_words.append(try self.allocator.dupe(u8, trimmed));
            }
        }

        if (query_words.items.len == 0) return null;

        // Check if all query words are in line
        var all_found: bool = true;
        var found_count: usize = 0;

        for (query_words.items) |qword| {
            if (std.mem.indexOf(u8, line, qword) != null) {
                found_count += 1;
            } else {
                all_found = false;
            }
        }

        if (all_found) {
            // Bonus for exact order match
            var order_match: bool = true;
            var search_pos: usize = 0;
            for (query_words.items) |qword| {
                const idx = std.mem.indexOfPos(u8, line, search_pos, qword) orelse {
                    order_match = false;
                    break;
                };
                search_pos = idx + qword.len;
            }

            if (order_match) {
                return 0.85; // Higher confidence for ordered match
            }
            return 0.8; // Standard word-level confidence
        }

        // Partial match: some words found
        if (found_count > 0) {
            const ratio = @as(f32, @floatFromInt(found_count)) / @as(f32, @floatFromInt(query_words.items.len));
            return ratio * 0.6;
        }

        return null;
    }

    /// Layer 3: Fuzzy SequenceMatcher-style ratio
    fn fuzzyMatch(self: *FuzzyMatcher, line: []const u8, query: []const u8) ?f32 {
        if (query.len == 0 or line.len == 0) return null;

        // Use simple character-level matching
        // Similar to Python's difflib.SequenceMatcher.ratio()
        const hits = self.countHits(line, query);
        const total = line.len + query.len;

        if (total == 0) return null;

        const ratio = @as(f32, @floatFromInt(2 * hits)) / @as(f32, @floatFromInt(total));
        return ratio * 0.6; // Scale for fuzzy layer
    }

    /// Count matching character pairs (simplified longest common subsequence)
    fn countHits(self: *FuzzyMatcher, s1: []const u8, s2: []const u8) usize {
        if (s1.len == 0 or s2.len == 0) return 0;

        // Use a simple LCS approximation
        var matrix = std.ArrayList(usize).init(self.allocator);
        defer matrix.deinit();

        const rows = s1.len + 1;
        const cols = s2.len + 1;

        try matrix.resize(rows * cols);

        // Fill DP table
        for (0..s1.len) |i| {
            for (0..s2.len) |j| {
                const idx = i * cols + j;
                if (s1[i] == s2[j]) {
                    matrix.items[idx] = if (i > 0 and j > 0)
                        matrix.items[(i - 1) * cols + (j - 1)] + 1
                    else
                        1;
                } else {
                    const up = if (i > 0) matrix.items[(i - 1) * cols + j] else 0;
                    const left = if (j > 0) matrix.items[i * cols + (j - 1)] else 0;
                    matrix.items[idx] = @max(up, left);
                }
            }
        }

        return matrix.items[s1.len * cols + s2.len - 1];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FuzzyMatcher exact match" {
    const source =
        \\pub fn add(a: i32, b: i32) i32
        \\pub fn subtract(x: i32, y: i32) i32
    ;

    var matcher = try FuzzyMatcher.init(std.testing.allocator, source);
    defer matcher.deinit();

    var results = try matcher.findMatches("pub fn add");
    defer results.deinit();

    try std.testing.expect(results.len() > 0);
    const first_match = results.items[0];
    try std.testing.expectEqual(@as(u32, 1), first_match.start_line);
    try std.testing.expectEqual(@as(f32, 1.0), first_match.confidence);
}

test "FuzzyMatcher word-level match" {
    const source =
        \\pub fn calculateSum(x: i32, y: i32) i32
        \\pub fn helper()
    ;

    var matcher = try FuzzyMatcher.init(std.testing.allocator, source);
    defer matcher.deinit();

    var results = try matcher.findMatches("calculate x");
    defer results.deinit();

    try std.testing.expect(results.len() > 0);
    const first_match = results.items[0];
    try std.testing.expectEqual(@as(f32, 0.8), first_match.confidence);
}

test "FuzzyMatcher fuzzy match" {
    const source =
        \\pub fn addNumbers(a: i32, b: i32) i32
        \\pub fn subtract()
    ;

    var matcher = try FuzzyMatcher.init(std.testing.allocator, source);
    defer matcher.deinit();

    var results = try matcher.findMatches("addNums");
    defer results.deinit();

    // Should find partial match with lower confidence
    try std.testing.expect(results.len() > 0);
}

test "FuzzyMatcher no match" {
    const source =
        \\pub fn functionOne()
        \\pub fn functionTwo()
    ;

    var matcher = try FuzzyMatcher.init(std.testing.allocator, source);
    defer matcher.deinit();

    var results = try matcher.findMatches("xyzabc");
    defer results.deinit();

    try std.testing.expect(results.len() == 0);
}

test "FuzzyMatcher multi-line source" {
    const source =
        \\const MAX_ITEMS = 100;
        \\pub fn process(items: []Item) !void
        \\pub fn validate(item: Item) bool
        \\
        \\pub fn main() !void {
        \\    // Implementation
        \\}
    ;

    var matcher = try FuzzyMatcher.init(std.testing.allocator, source);
    defer matcher.deinit();

    var results = try matcher.findMatches("pub fn");
    defer results.deinit();

    // Should find all three function declarations
    try std.testing.expect(results.len() >= 3);
}

test "FuzzyMatcher empty query" {
    const source = "pub fn test() void";
    var matcher = try FuzzyMatcher.init(std.testing.allocator, source);
    defer matcher.deinit();

    var results = try matcher.findMatches("");
    defer results.deinit();

    try std.testing.expect(results.len() == 0);
}
