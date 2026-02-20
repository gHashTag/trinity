//! Memory Store - Consult SUCCESS_HISTORY and REGRESSION_PATTERNS
//! Loads and searches historical patterns to avoid repeating mistakes

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");

pub const MemoryStore = struct {
    success_patterns: []parser.SuccessPattern,
    regression_patterns: []parser.RegressionPattern,
    benchmark_baseline: BenchmarkBaseline,
    ralph_path: []const u8,

    pub fn deinit(self: *MemoryStore, allocator: Allocator) void {
        for (self.success_patterns) |*p| p.deinit(allocator);
        allocator.free(self.success_patterns);

        for (self.regression_patterns) |*p| p.deinit(allocator);
        allocator.free(self.regression_patterns);

        self.benchmark_baseline.deinit(allocator);
        allocator.free(self.ralph_path);
    }
};

pub const BenchmarkBaseline = struct {
    timestamp: i64,
    build_time_ms: f64,
    test_time_ms: f64,
    metrics: std.StringHashMap(f64),

    pub fn init() BenchmarkBaseline {
        return .{
            .timestamp = 0,
            .build_time_ms = 0,
            .test_time_ms = 0,
            .metrics = std.StringHashMap(f64).init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *BenchmarkBaseline, allocator: Allocator) void {
        var iter = self.metrics.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        self.metrics.deinit(allocator);
    }
};

pub const SearchResult = struct {
    pattern: []const u8,
    relevance: f64,
    context: []const u8,
};

/// Initialize MemoryStore from .ralph directory
pub fn init(allocator: Allocator, ralph_path: []const u8) !MemoryStore {
    const ralph_path_owned = try allocator.dupe(u8, ralph_path);

    // Load success patterns
    var success_patterns = try std.ArrayList(parser.SuccessPattern).initCapacity(allocator, 0);
    errdefer {
        for (success_patterns.items) |*p| p.deinit(allocator);
        success_patterns.deinit(allocator);
    }

    {
        const success_file = std.fs.cwd().openFile(
            try std.fmt.allocPrint(allocator, "{s}/SUCCESS_HISTORY.md", .{ralph_path}),
            .{},
        ) catch |err| {
            if (err == error.FileNotFound) {
                // File doesn't exist yet - continue with empty patterns
            } else {
                return err;
            }
        };
        defer if (success_file) |f| f.close();

        if (success_file) |file| {
            const content = try file.readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(content);

            const parsed = try parser.parseSuccessHistory(allocator, content);
            success_patterns.items = parsed;
        }
    }

    // Load regression patterns
    var regression_patterns = try std.ArrayList(parser.RegressionPattern).initCapacity(allocator, 0);
    errdefer {
        for (regression_patterns.items) |*p| p.deinit(allocator);
        regression_patterns.deinit(allocator);
    }

    {
        const regression_file = std.fs.cwd().openFile(
            try std.fmt.allocPrint(allocator, "{s}/REGRESSION_PATTERNS.md", .{ralph_path}),
            .{},
        ) catch |err| {
            if (err == error.FileNotFound) {
                // File doesn't exist yet - continue with empty patterns
            } else {
                return err;
            }
        };
        defer if (regression_file) |f| f.close();

        if (regression_file) |file| {
            const content = try file.readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(content);

            const parsed = try parser.parseRegressionPatterns(allocator, content);
            regression_patterns.items = parsed;
        }
    }

    // Load benchmark baseline
    const baseline = BenchmarkBaseline.init();
    {
        const baseline_file = std.fs.cwd().openFile(
            try std.fmt.allocPrint(allocator, "{s}/internal/.benchmark_baseline", .{ralph_path}),
            .{},
        ) catch |err| {
            if (err == error.FileNotFound) {
                // File doesn't exist - use default baseline
            } else {
                return err;
            }
        };
        defer if (baseline_file) |f| f.close();

        if (baseline_file) |file| {
            _ = file;
            // TODO: Parse JSON baseline
        }
    }

    return MemoryStore{
        .success_patterns = try success_patterns.toOwnedSlice(allocator),
        .regression_patterns = try regression_patterns.toOwnedSlice(allocator),
        .benchmark_baseline = baseline,
        .ralph_path = ralph_path_owned,
    };
}

/// Search success patterns by keywords
pub fn searchSuccess(memory: MemoryStore, allocator: Allocator, keywords: []const []const u8) ![]SearchResult {
    var results = try std.ArrayList(SearchResult).initCapacity(allocator, 0);
    errdefer {
        for (results.items) |*r| {
            allocator.free(r.pattern);
            allocator.free(r.context);
        }
        results.deinit(allocator);
    }

    for (memory.success_patterns) |pattern| {
        var relevance: f64 = 0;
        var matched = false;

        for (keywords) |keyword| {
            if (std.mem.indexOf(u8, pattern.commit_sha, keyword) != null) {
                relevance += 1.0;
                matched = true;
            }

            const desc_lower = try std.ascii.allocLowerString(allocator, pattern.description);
            defer allocator.free(desc_lower);
            const keyword_lower = try std.ascii.allocLowerString(allocator, keyword);
            defer allocator.free(keyword_lower);

            if (std.mem.indexOf(u8, desc_lower, keyword_lower) != null) {
                relevance += 0.5;
                matched = true;
            }
        }

        if (matched) {
            try results.append(allocator, SearchResult{
                .pattern = try allocator.dupe(u8, pattern.commit_sha),
                .relevance = relevance,
                .context = try allocator.dupe(u8, pattern.description),
            });
        }
    }

    std.sort.insertion(SearchResult, results.items, {}, struct {
        fn getLessThan(_: void, a: SearchResult, b: SearchResult) bool {
            return a.relevance > b.relevance;
        }
    }.getLessThan);

    return try results.toOwnedSlice(allocator);
}

/// Search regression patterns by keywords
pub fn searchRegression(memory: MemoryStore, allocator: Allocator, keywords: []const []const u8) ![]SearchResult {
    var results = try std.ArrayList(SearchResult).initCapacity(allocator, 0);
    errdefer {
        for (results.items) |*r| {
            allocator.free(r.pattern);
            allocator.free(r.context);
        }
        results.deinit(allocator);
    }

    for (memory.regression_patterns) |pattern| {
        var relevance: f64 = 0;
        var matched = false;

        for (keywords) |keyword| {
            const name_lower = try std.ascii.allocLowerString(allocator, pattern.pattern_name);
            defer allocator.free(name_lower);
            const keyword_lower = try std.ascii.allocLowerString(allocator, keyword);
            defer allocator.free(keyword_lower);

            if (std.mem.indexOf(u8, name_lower, keyword_lower) != null) {
                relevance += 1.0;
                matched = true;
            }

            const desc_lower = try std.ascii.allocLowerString(allocator, pattern.description);
            defer allocator.free(desc_lower);

            if (std.mem.indexOf(u8, desc_lower, keyword_lower) != null) {
                relevance += 0.5;
                matched = true;
            }

            const cause_lower = try std.ascii.allocLowerString(allocator, pattern.root_cause);
            defer allocator.free(cause_lower);

            if (std.mem.indexOf(u8, cause_lower, keyword_lower) != null) {
                relevance += 0.8;
                matched = true;
            }
        }

        if (matched) {
            const context = try std.fmt.allocPrint(allocator,
                \\Root cause: {s}
                \\Solution: {s}
            , .{ pattern.root_cause, pattern.solution });

            try results.append(allocator, SearchResult{
                .pattern = try allocator.dupe(u8, pattern.pattern_name),
                .relevance = relevance,
                .context = context,
            });
        }
    }

    std.sort.insertion(SearchResult, results.items, {}, struct {
        fn getLessThan(_: void, a: SearchResult, b: SearchResult) bool {
            return a.relevance > b.relevance;
        }
    }.getLessThan);

    return try results.toOwnedSlice(allocator);
}

/// Extract keywords from a task description for memory search
pub fn extractKeywords(allocator: Allocator, description: []const u8) ![][]const u8 {
    var keywords = try std.ArrayList([]const u8).initCapacity(allocator, 0);

    const technical_terms = [_][]const u8{
        "memory",   "leak",    "alloc",   "free",     "segfault",
        "compile",  "build",   "link",    "error",    "warning",
        "test",     "spec",    "vibee",   "codegen",  "parser",
        "git",      "branch",  "commit",  "merge",    "conflict",
        "circuit",  "breaker", "gate",    "quality",  "format",
        "zig",      "rust",    "python",  "typescript",
        "vsa",      "trit",    "ternary", "bind",     "bundle",
        "simd",     "vector",  "optimiz", "parallel", "async",
    };

    const desc_lower = try std.ascii.allocLowerString(allocator, description);
    defer allocator.free(desc_lower);

    for (technical_terms) |term| {
        const term_lower = try std.ascii.allocLowerString(allocator, term);
        defer allocator.free(term_lower);

        if (std.mem.indexOf(u8, desc_lower, term_lower) != null) {
            try keywords.append(allocator, try allocator.dupe(u8, term));
        }
    }

    return try keywords.toOwnedSlice(allocator);
}

/// Consult memory before starting a task
pub fn consult(memory: MemoryStore, allocator: Allocator, task_description: []const u8) !struct {
    success: []SearchResult,
    regression: []SearchResult,
    keywords: [][]const u8,
} {
    const keywords = try extractKeywords(allocator, task_description);
    errdefer {
        for (keywords) |k| allocator.free(k);
        allocator.free(keywords);
    }

    const success_results = if (keywords.len > 0)
        try searchSuccess(memory, allocator, keywords)
    else
        &.{};

    const regression_results = if (keywords.len > 0)
        try searchRegression(memory, allocator, keywords)
    else
        &.{};

    return .{
        .success = success_results,
        .regression = regression_results,
        .keywords = keywords,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "memory: extract keywords" {
    const allocator = std.testing.allocator;

    const keywords = try extractKeywords(allocator, "Fix memory leak in zig parser");
    defer {
        for (keywords) |k| allocator.free(k);
        allocator.free(keywords);
    }

    try std.testing.expect(keywords.len > 0);
}

test "memory: search with empty patterns" {
    const allocator = std.testing.allocator;

    const memory = MemoryStore{
        .success_patterns = &.{},
        .regression_patterns = &.{},
        .benchmark_baseline = BenchmarkBaseline.init(),
        .ralph_path = "",
    };

    const results = try searchSuccess(memory, allocator, &[_][]const u8{"test"});
    defer {
        for (results) |*r| {
            allocator.free(r.pattern);
            allocator.free(r.context);
        }
        allocator.free(results);
    }

    try std.testing.expectEqual(@as(usize, 0), results.len);
}
