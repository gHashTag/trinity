//! Pattern matching for AGENT MU
//!
//! Searches REGRESSION_PATTERNS.md for similar past errors and their solutions.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;
const diagnostic = @import("diagnostic.zig");

/// Match result from REGRESSION_PATTERNS.md
pub const PatternMatch = struct {
    found: bool,
    anti_pattern: []const u8,
    correct_approach: []const u8,
    files: [][]const u8,
    attempted_fixes: [][]const u8,
    confidence: f64 = 0.0, // 0.0 to 1.0 similarity score
    pattern_id: []const u8 = "", // Identifier for the matched pattern

    /// Free allocated memory
    pub fn deinit(self: *const PatternMatch, allocator: std.mem.Allocator) void {
        if (self.anti_pattern.len > 0) allocator.free(self.anti_pattern);
        if (self.correct_approach.len > 0) allocator.free(self.correct_approach);
        for (self.files) |f| allocator.free(f);
        allocator.free(self.files);
        for (self.attempted_fixes) |f| allocator.free(f);
        allocator.free(self.attempted_fixes);
        if (self.pattern_id.len > 0) allocator.free(self.pattern_id);
    }
};

/// Search REGRESSION_PATTERNS.md for matching error patterns
///
/// Parameters:
///   - allocator: Memory allocator
///   - error_type: The FixType of the current error
///   - error_message: The error message to match against
///
/// Returns: PatternMatch with found solution or empty if no match
pub fn searchRegressionPatterns(
    allocator: std.mem.Allocator,
    error_type: diagnostic.FixType,
    error_message: []const u8,
) !PatternMatch {
    const patterns_file = ".ralph/memory/REGRESSION_PATTERNS.md";

    // Try to open the file
    const file = std.fs.cwd().openFile(patterns_file, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // File doesn't exist yet - return empty match
            return PatternMatch{
                .found = false,
                .anti_pattern = "",
                .correct_approach = "",
                .files = &[_][]const u8{},
                .attempted_fixes = &[_][]const u8{},
            };
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
    defer allocator.free(content);

    // Search for pattern entries
    var entries = std.mem.splitSequence(u8, content, "---");

    while (entries.next()) |entry| {
        if (entry.len < 10) continue; // Skip empty entries

        // Check if this entry matches our error
        if (entryMatchesError(entry, error_type, error_message)) {
            // Extract the solution from this entry
            return try extractSolution(allocator, entry);
        }
    }

    // No match found
    return PatternMatch{
        .found = false,
        .anti_pattern = "",
        .correct_approach = "",
        .files = &[_][]const u8{},
        .attempted_fixes = &[_][]const u8{},
    };
}

/// Check if a pattern entry matches the current error
fn entryMatchesError(
    entry: []const u8,
    error_type: diagnostic.FixType,
    error_message: []const u8,
) bool {
    // Convert entry to lowercase for case-insensitive matching
    const entry_lower = toLowerAlloc(std.heap.page_allocator, entry) catch return false;
    defer std.heap.page_allocator.free(entry_lower);

    const msg_lower = toLowerAlloc(std.heap.page_allocator, error_message) catch return false;
    defer std.heap.page_allocator.free(msg_lower);

    // Check for error type keywords
    const type_keyword = switch (error_type) {
        .IMPORT_FIX => "import",
        .TYPE_FIX => "type",
        .SYNTAX_FIX => "syntax",
        .TEMPLATE_FIX => "template",
        .SPEC_FIX => "spec",
        .GENERATOR_PATCH => "generator",
        .UNKNOWN => "error",
        // Zig-specific (v8.10)
        .ALLOCATOR_FIX => "allocator",
        .ERROR_UNION_FIX => "error",
        .COMPTIME_FIX => "comptime",
        .VSA_FIX => "vsa",
        .MEM_FIX => "memory",
        // Zig 0.15 specific (v8.11)
        .IOPATTERN_FIX => "io",
        .COMPTIME_QUOTA_FIX => "quota",
        .UNMANAGED_FIX => "unmanaged",
        .TYPEFUNCTION_FIX => "typefunction",
        .INLINE_FIX => "inline",
    };

    // Check if entry contains relevant keywords
    if (std.mem.indexOf(u8, entry_lower, type_keyword) == null) {
        return false;
    }

    // Check for common error message patterns
    if (std.mem.indexOf(u8, msg_lower, "expected type") != null) {
        return std.mem.indexOf(u8, entry_lower, "expected type") != null or
            std.mem.indexOf(u8, entry_lower, "type mismatch") != null;
    }

    if (std.mem.indexOf(u8, msg_lower, "undeclared") != null) {
        return std.mem.indexOf(u8, entry_lower, "undeclared") != null or
            std.mem.indexOf(u8, entry_lower, "identifier") != null;
    }

    if (std.mem.indexOf(u8, msg_lower, "semicolon") != null) {
        return std.mem.indexOf(u8, entry_lower, "semicolon") != null or
            std.mem.indexOf(u8, entry_lower, "syntax") != null;
    }

    // Generic keyword matching
    var iter = std.mem.splitScalar(u8, msg_lower, ' ');
    while (iter.next()) |word| {
        if (word.len > 4) { // Only match significant words
            if (std.mem.indexOf(u8, entry_lower, word) != null) {
                return true;
            }
        }
    }

    return false;
}

/// Extract solution information from a pattern entry
fn extractSolution(allocator: std.mem.Allocator, entry: []const u8) !PatternMatch {
    var lines = std.mem.splitScalar(u8, entry, '\n');

    var anti_pattern: []const u8 = "";
    var correct_approach: []const u8 = "";
    var files_list = ArrayListManaged([]const u8).init(allocator);
    var fixes_list = ArrayListManaged([]const u8).init(allocator);

    errdefer {
        if (files_list.items.len > 0) {
            for (files_list.items) |f| allocator.free(f);
        }
        if (fixes_list.items.len > 0) {
            for (fixes_list.items) |f| allocator.free(f);
        }
    }

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.startsWith(u8, trimmed, "- **Anti-pattern:**")) {
            const start = trimmed["- **Anti-pattern:**".len..];
            anti_pattern = std.mem.trim(u8, start, &std.ascii.whitespace);
        } else if (std.mem.startsWith(u8, trimmed, "- **Correct approach:**")) {
            const start = trimmed["- **Correct approach:**".len..];
            correct_approach = std.mem.trim(u8, start, &std.ascii.whitespace);
        } else if (std.mem.startsWith(u8, trimmed, "- **Files:**")) {
            // Parse file list (format: `file1.zig`, `file2.zig`)
            // TODO: Implement proper parsing
            _ = trimmed["- **Files:**".len..];
        } else if (std.mem.indexOf(u8, trimmed, "**") != null) {
            // Store other lines as attempted fixes
            try fixes_list.append(try allocator.dupe(u8, trimmed));
        }
    }

    return PatternMatch{
        .found = true,
        .anti_pattern = try allocator.dupe(u8, anti_pattern),
        .correct_approach = try allocator.dupe(u8, correct_approach),
        .files = try files_list.toOwnedSlice(),
        .attempted_fixes = try fixes_list.toOwnedSlice(),
    };
}

/// Convert string to lowercase (allocator-allocated)
fn toLowerAlloc(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return result;
}

// ============================================================================
// SEMANTIC PATTERN SEARCH v8.12
// ============================================================================

/// Candidate pattern with confidence score
const PatternCandidate = struct {
    entry: []const u8,
    confidence: f64,
    pattern_id: []const u8,
};

/// Semantic pattern search with fuzzy matching and confidence scoring
///
/// Returns top-k matches with confidence scores > threshold
pub fn semanticPatternMatch(
    allocator: std.mem.Allocator,
    error_message: []const u8,
    error_type: diagnostic.FixType,
    top_k: usize,
    threshold: f64,
) ![]PatternMatch {
    const patterns_file = ".ralph/memory/REGRESSION_PATTERNS.md";

    // Try to open the file
    const file = std.fs.cwd().openFile(patterns_file, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // File doesn't exist yet - return empty array
            return &[_]PatternMatch{};
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
    defer allocator.free(content);

    // Collect all candidates with confidence scores
    var candidates = ArrayListManaged(PatternCandidate).init(allocator);
    defer {
        for (candidates.items) |c| {
            allocator.free(c.pattern_id);
        }
        candidates.deinit();
    }

    // Search for pattern entries and score them
    var entries = std.mem.splitSequence(u8, content, "---");
    var entry_idx: usize = 0;

    while (entries.next()) |entry| {
        if (entry.len < 10) continue; // Skip empty entries

        const confidence = try calculateConfidence(allocator, entry, error_message, error_type);
        if (confidence > threshold) {
            const pattern_id = try std.fmt.allocPrint(allocator, "pattern_{d}", .{entry_idx});
            try candidates.append(.{
                .entry = entry,
                .confidence = confidence,
                .pattern_id = pattern_id,
            });
        }
        entry_idx += 1;
    }

    // Sort by confidence (highest first)
    std.sort.insertion(PatternCandidate, candidates.items, {}, struct {
        fn lessThan(_: void, a: PatternCandidate, b: PatternCandidate) bool {
            return a.confidence > b.confidence;
        }
    }.lessThan);

    // Return top-k results
    const result_count = @min(top_k, candidates.items.len);
    const results = try allocator.alloc(PatternMatch, result_count);

    for (0..result_count) |i| {
        const candidate = candidates.items[i];
        var solution = try extractSolution(allocator, candidate.entry);
        solution.confidence = candidate.confidence;
        solution.pattern_id = try allocator.dupe(u8, candidate.pattern_id);
        results[i] = solution;
    }

    return results;
}

/// Calculate confidence score for a pattern entry (0.0 to 1.0)
fn calculateConfidence(
    allocator: std.mem.Allocator,
    entry: []const u8,
    error_message: []const u8,
    error_type: diagnostic.FixType,
) !f64 {
    var score: f64 = 0.0;

    // 1. Error type match: +0.3
    const type_keyword = switch (error_type) {
        .IMPORT_FIX => "import",
        .TYPE_FIX => "type",
        .SYNTAX_FIX => "syntax",
        .ALLOCATOR_FIX => "allocator",
        .ERROR_UNION_FIX => "error",
        .TEMPLATE_FIX => "template",
        else => "error",
    };

    const entry_lower = try toLowerAlloc(allocator, entry);
    defer allocator.free(entry_lower);

    if (std.mem.indexOf(u8, entry_lower, type_keyword) != null) {
        score += 0.3;
    }

    // 2. Keyword matching: +0.1 per matching keyword
    const msg_lower = try toLowerAlloc(allocator, error_message);
    defer allocator.free(msg_lower);

    const keywords = [_][]const u8{ "expected", "found", "undeclared", "identifier", "type", "syntax" };
    for (keywords) |kw| {
        if (std.mem.indexOf(u8, msg_lower, kw) != null and
            std.mem.indexOf(u8, entry_lower, kw) != null)
        {
            score += 0.1;
        }
    }

    // 3. Fuzzy similarity: up to +0.4
    const fuzzy_score = fuzzySimilarity(msg_lower, entry_lower);
    score += fuzzy_score * 0.4;

    // Cap at 1.0
    return if (score > 1.0) 1.0 else score;
}

/// Fuzzy string similarity using simple character matching (0.0 to 1.0)
fn fuzzySimilarity(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 or b.len == 0) return 0.0;

    // Count matching character bigrams
    var matches: usize = 0;
    const min_len = @min(a.len - 1, b.len - 1);

    for (0..@min(min_len, 100)) |i| { // Limit to 100 bigrams for performance
        if (i + 1 < a.len and i + 1 < b.len) {
            if (a[i] == b[i] and a[i + 1] == b[i + 1]) {
                matches += 1;
            }
        }
    }

    const max_possible = @min(a.len, b.len);
    if (max_possible == 0) return 0.0;

    return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(max_possible));
}

/// Simple semantic search - returns single best match or null
pub fn semanticPatternSearch(
    allocator: std.mem.Allocator,
    error_message: []const u8,
    error_type: diagnostic.FixType,
) !?PatternMatch {
    const results = try semanticPatternMatch(allocator, error_message, error_type, 1, 0.6);
    defer {
        for (results) |r| {
            r.deinit(allocator);
        }
        allocator.free(results);
    }

    if (results.len > 0) {
        // Return a copy of the first result
        const r = results[0];
        return PatternMatch{
            .found = r.found,
            .anti_pattern = try allocator.dupe(u8, r.anti_pattern),
            .correct_approach = try allocator.dupe(u8, r.correct_approach),
            .files = try allocator.dupe([]const u8, r.files),
            .attempted_fixes = try allocator.dupe([]const u8, r.attempted_fixes),
            .confidence = r.confidence,
            .pattern_id = try allocator.dupe(u8, r.pattern_id),
        };
    }

    return null;
}
