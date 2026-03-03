// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Structural Editor Core (Tier 0 + Tier 1)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Core types and configuration for NEEDLE structural code editor.
// Provides Tier 0 (fuzzy text fallback) and Tier 1 (AST-based) matching.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Safety level for edit operations
pub const SafetyLevel = enum {
    low,    // Minimal checks, fast edits
    medium, // Standard safety gates
    high,   // Full validation with preview

    pub fn label(self: SafetyLevel) []const u8 {
        return switch (self) {
            .low => "LOW",
            .medium => "MEDIUM",
            .high => "HIGH",
        };
    }
};

/// Edit mode for structural replacement
pub const EditMode = enum {
    structural,    // Use tree-sitter AST edit API
    semantic,      // Use VSA semantic search (Tier 2, future)
    text_fallback, // Use text-based diff
    auto,          // Auto-select based on availability

    pub fn label(self: EditMode) []const u8 {
        return switch (self) {
            .structural => "STRUCTURAL",
            .semantic => "SEMANTIC",
            .text_fallback => "TEXT_FALLBACK",
            .auto => "AUTO",
        };
    }
};

/// Kind of match result
pub const MatchKind = enum {
    exact_ast,        // Tree-sitter AST node match (confidence 1.0)
    semantic_symbol,  // VSA semantic similarity (Tier 2, future)
    fuzzy_text,       // Fuzzy text matching (confidence < 1.0)

    pub fn label(self: MatchKind) []const u8 {
        return switch (self) {
            .exact_ast => "EXACT_AST",
            .semantic_symbol => "SEMANTIC_SYMBOL",
            .fuzzy_text => "FUZZY_TEXT",
        };
    }

    pub fn baseConfidence(self: MatchKind) f32 {
        return switch (self) {
            .exact_ast => 1.0,
            .semantic_symbol => 0.9,
            .fuzzy_text => 0.6,
        };
    }
};

/// Violation severity (compatible with idiom_analyzer.Severity)
pub const Severity = enum {
    low,
    medium,
    high,
    critical,

    pub fn label(self: Severity) []const u8 {
        return switch (self) {
            .low => "LOW",
            .medium => "MEDIUM",
            .high => "HIGH",
            .critical => "CRITICAL",
        };
    }

    pub fn score(self: Severity) u32 {
        return switch (self) {
            .low => 1,
            .medium => 2,
            .high => 3,
            .critical => 4,
        };
    }
};

/// Violation kind (compatible with idiom_analyzer.ViolationKind)
pub const ViolationKind = enum {
    // From idiom_analyzer (string-based, Cycle 77)
    duplicate_param,
    unused_allocator,
    empty_struct,
    missing_errdefer,
    // From treesitter_analyzer (AST-based, Cycle 78)
    variable_shadowing,
    scope_aware_defer,
    comptime_misuse,
    missing_return_path,
    type_annotation_missing,
    // NEEDLE-specific
    parse_error,
    test_failure,
    compilation_error,
    no_matches_found,
    edit_conflict,

    pub fn label(self: ViolationKind) []const u8 {
        return switch (self) {
            .duplicate_param => "DUPLICATE_PARAM",
            .unused_allocator => "UNUSED_ALLOCATOR",
            .empty_struct => "EMPTY_STRUCT",
            .missing_errdefer => "MISSING_ERRDEFER",
            .variable_shadowing => "VARIABLE_SHADOWING",
            .scope_aware_defer => "SCOPE_AWARE_DEFER",
            .comptime_misuse => "COMPTIME_MISUSE",
            .missing_return_path => "MISSING_RETURN_PATH",
            .type_annotation_missing => "TYPE_ANNOTATION_MISSING",
            .parse_error => "PARSE_ERROR",
            .test_failure => "TEST_FAILURE",
            .compilation_error => "COMPILATION_ERROR",
            .no_matches_found => "NO_MATCHES_FOUND",
            .edit_conflict => "EDIT_CONFLICT",
        };
    }

    pub fn defaultSeverity(self: ViolationKind) Severity {
        return switch (self) {
            .duplicate_param, .parse_error, .compilation_error => .critical,
            .unused_allocator, .comptime_misuse => .high,
            .empty_struct, .missing_errdefer, .scope_aware_defer, .missing_return_path => .medium,
            .variable_shadowing, .type_annotation_missing, .test_failure => .medium,
            .no_matches_found, .edit_conflict => .low,
        };
    }
};

/// Single match result from search
pub const MatchResult = struct {
    node_id: u64,
    start_line: u32,
    end_line: u32,
    start_column: u32,
    end_column: u32,
    start_byte: usize = 0,   // AST byte offset (Tier 1)
    end_byte: usize = 0,     // AST byte offset (Tier 1)
    matched_text: []const u8,
    confidence: f32,
    kind: MatchKind,

    /// Create a new match result
    pub fn init(
        allocator: std.mem.Allocator,
        start_line: u32,
        end_line: u32,
        matched_text: []const u8,
        confidence: f32,
        kind: MatchKind,
    ) !MatchResult {
        return MatchResult{
            .node_id = 0, // Will be assigned by caller
            .start_line = start_line,
            .end_line = end_line,
            .start_column = 0,
            .end_column = 0,
            .matched_text = try allocator.dupe(u8, matched_text),
            .confidence = confidence,
            .kind = kind,
        };
    }

    /// Get match range as string "line:col"
    pub fn rangeString(self: MatchResult, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{d}:{d}-{d}:{d}", .{
            self.start_line, self.start_column,
            self.end_line, self.end_column,
        });
    }

    /// Check if confidence meets threshold
    pub fn meetsThreshold(self: MatchResult, threshold: f32) bool {
        return self.confidence >= threshold;
    }
};

/// List of match results with filtering/sorting
pub const MatchResultList = struct {
    items: std.ArrayListAligned(MatchResult, null),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MatchResultList {
        return .{
            .items = .{ .items = &.{}, .capacity = 0 },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MatchResultList) void {
        for (self.items.items) |*item| {
            self.allocator.free(item.matched_text);
        }
        // Shrink the list to free capacity
        if (self.items.capacity > 0) {
            self.allocator.free(self.items.allocatedSlice());
        }
    }

    /// Filter results by confidence threshold
    pub fn filter(self: *MatchResultList, threshold: f32) !void {
        var filtered = MatchResultList.init(self.allocator);
        errdefer filtered.deinit();

        for (self.items.items) |item| {
            if (item.meetsThreshold(threshold)) {
                const copied = MatchResult{
                    .node_id = item.node_id,
                    .start_line = item.start_line,
                    .end_line = item.end_line,
                    .start_column = item.start_column,
                    .end_column = item.end_column,
                    .start_byte = item.start_byte,
                    .end_byte = item.end_byte,
                    .matched_text = try self.allocator.dupe(u8, item.matched_text),
                    .confidence = item.confidence,
                    .kind = item.kind,
                };
                // In Zig 0.15, ArrayList.append requires allocator
                try filtered.items.append(self.allocator, copied);
            }
        }

        // Clean up old items
        for (self.items.items) |*item| {
            self.allocator.free(item.matched_text);
        }
        if (self.items.capacity > 0) {
            self.allocator.free(self.items.allocatedSlice());
        }
        self.items = filtered.items;
    }

    /// Sort by confidence descending
    pub fn sortByConfidence(self: *MatchResultList) void {
        std.sort.insertion(MatchResult, self.items.items, {}, struct {
            fn lessThan(_: void, a: MatchResult, b: MatchResult) bool {
                return a.confidence > b.confidence;
            }
        }.lessThan);
    }

    /// Limit to max results
    pub fn limit(self: *MatchResultList, max_count: usize) void {
        if (self.items.items.len > max_count) {
            // Free truncated items
            for (self.items.items[max_count..]) |*item| {
                self.allocator.free(item.matched_text);
            }
            self.items.shrinkRetainingCapacity(max_count);
        }
    }

    /// Append a match result
    pub fn append(self: *MatchResultList, item: MatchResult) !void {
        try self.items.append(self.allocator, item);
    }

    /// Get length
    pub fn len(self: *const MatchResultList) usize {
        return self.items.items.len;
    }

    /// Check if empty
    pub fn isEmpty(self: *const MatchResultList) bool {
        return self.items.items.len == 0;
    }
};

/// Single violation from safety checks
pub const Violation = struct {
    kind: ViolationKind,
    line: u32,
    message: []const u8,
    severity: Severity,

    pub fn init(
        allocator: std.mem.Allocator,
        kind: ViolationKind,
        line: u32,
        message: []const u8,
    ) !Violation {
        return Violation{
            .kind = kind,
            .line = line,
            .message = try allocator.dupe(u8, message),
            .severity = kind.defaultSeverity(),
        };
    }

    pub fn deinit(self: *Violation, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }
};

/// Report from edit operation
pub const EditReport = struct {
    operations_applied: usize = 0,
    files_modified: usize = 0,
    tests_passed: bool = false,
    parse_ok: bool = false,
    compile_ok: bool = false,
    violations: std.ArrayListAligned(Violation, null),
    duration_ms: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EditReport {
        return .{
            .violations = .{ .items = &.{}, .capacity = 0 },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EditReport) void {
        for (self.violations.items) |*v| {
            v.deinit(self.allocator);
        }
        // Shrink the list to free capacity
        if (self.violations.capacity > 0) {
            self.allocator.free(self.violations.allocatedSlice());
        }
    }

    /// Check if edit was successful
    pub fn isSuccess(self: *const EditReport) bool {
        return self.tests_passed and
            self.parse_ok and
            (self.compile_ok or self.violations.items.len == 0);
    }

    /// Get overall safety score (0.0 - 1.0)
    pub fn safetyScore(self: *const EditReport) f32 {
        if (self.violations.items.len == 0) return 1.0;

        var penalty: f32 = 0;
        for (self.violations.items) |v| {
            penalty += @as(f32, @floatFromInt(v.severity.score())) / 4.0;
        }

        return @max(0.0, 1.0 - penalty / @as(f32, @floatFromInt(self.violations.items.len)));
    }

    /// Add a violation
    pub fn addViolation(self: *EditReport, violation: Violation) !void {
        try self.violations.append(self.allocator, violation);
    }

    /// Check if has critical violations
    pub fn hasCritical(self: *const EditReport) bool {
        for (self.violations.items) |v| {
            if (v.severity == .critical) return true;
        }
        return false;
    }
};

/// Configuration for NEEDLE operations
pub const NeedleConfig = struct {
    enable_tier0_text: bool = true,         // Aider-style layered matching
    enable_tier1_structural: bool = true,   // ast-grep-like queries
    enable_tier2_semantic: bool = false,    // VSA symbol similarity (future)
    confidence_threshold: f32 = 0.5,
    max_matches: usize = 100,
    preview: bool = true,                   // Show diff before applying
    safety_level: SafetyLevel = .medium,
    edit_mode: EditMode = .auto,

    /// Create default configuration
    pub fn default() NeedleConfig {
        return .{};
    }

    /// Create fast configuration (minimal checks)
    pub fn fast() NeedleConfig {
        return .{
            .enable_tier1_structural = true,
            .enable_tier0_text = true,
            .enable_tier2_semantic = false,
            .confidence_threshold = 0.3,
            .preview = false,
            .safety_level = .low,
        };
    }

    /// Create safe configuration (full validation)
    pub fn safe() NeedleConfig {
        return .{
            .enable_tier1_structural = true,
            .enable_tier0_text = true,
            .enable_tier2_semantic = false,
            .confidence_threshold = 0.7,
            .preview = true,
            .safety_level = .high,
        };
    }
};

/// Edit operation descriptor
pub const EditOperation = struct {
    file_path: []const u8,
    pattern_query: []const u8,
    replacement: []const u8,
    safety_level: SafetyLevel,
    preview: bool,
    edit_mode: EditMode,

    pub fn init(
        file_path: []const u8,
        pattern_query: []const u8,
        replacement: []const u8,
    ) EditOperation {
        return .{
            .file_path = file_path,
            .pattern_query = pattern_query,
            .replacement = replacement,
            .safety_level = .medium,
            .preview = true,
            .edit_mode = .auto,
        };
    }

    /// Create with custom safety level
    pub fn withSafety(
        file_path: []const u8,
        pattern_query: []const u8,
        replacement: []const u8,
        safety_level: SafetyLevel,
    ) EditOperation {
        var op = init(file_path, pattern_query, replacement);
        op.safety_level = safety_level;
        return op;
    }
};

/// Query kind for pattern matching
pub const QueryKind = enum {
    sexpr,      // Tree-sitter S-expression
    regex,      // Regular expression
    plain_text, // Plain text search

    pub fn detect(query: []const u8) QueryKind {
        // Check for S-expression
        if (query.len > 0 and query[0] == '(') {
            return .sexpr;
        }

        // Check for regex metacharacters
        const regex_chars = ".*+?^${}()|[]\\";
        for (query) |c| {
            if (std.mem.indexOfScalar(u8, regex_chars, c) != null) {
                return .regex;
            }
        }

        return .plain_text;
    }
};

/// Parsed query
pub const Query = struct {
    raw: []const u8,
    kind: QueryKind,

    pub fn parse(query: []const u8) Query {
        return .{
            .raw = query,
            .kind = QueryKind.detect(query),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Count line number (1-indexed) at a given byte offset
pub fn lineNumber(source: []const u8, offset: usize) u32 {
    var line: u32 = 1;
    const end = @min(offset, source.len);
    for (source[0..end]) |c| {
        if (c == '\n') line += 1;
    }
    return line;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MatchKind base confidence" {
    try std.testing.expectEqual(@as(f32, 1.0), MatchKind.exact_ast.baseConfidence());
    try std.testing.expectEqual(@as(f32, 0.9), MatchKind.semantic_symbol.baseConfidence());
    try std.testing.expectEqual(@as(f32, 0.6), MatchKind.fuzzy_text.baseConfidence());
}

test "QueryKind detection" {
    try std.testing.expectEqual(QueryKind.sexpr, QueryKind.detect("(function_declaration name: (identifier))"));
    try std.testing.expectEqual(QueryKind.regex, QueryKind.detect("fn\\s+\\w+"));
    try std.testing.expectEqual(QueryKind.plain_text, QueryKind.detect("add two numbers"));
}

test "NeedleConfig defaults" {
    const config = NeedleConfig.default();
    try std.testing.expect(config.enable_tier0_text);
    try std.testing.expect(config.enable_tier1_structural);
    try std.testing.expect(!config.enable_tier2_semantic);
    try std.testing.expectEqual(@as(f32, 0.5), config.confidence_threshold);
    try std.testing.expectEqual(@as(usize, 100), config.max_matches);
}

test "EditReport safety score" {
    var report = EditReport.init(std.testing.allocator);
    defer report.deinit();

    // No violations = perfect score
    try std.testing.expectEqual(@as(f32, 1.0), report.safetyScore());

    // Add some violations
    try report.addViolation(try Violation.init(
        std.testing.allocator,
        .unused_allocator,
        10,
        "Allocator not used",
    ));
    try report.addViolation(try Violation.init(
        std.testing.allocator,
        .parse_error,
        20,
        "Syntax error",
    ));

    // Score should be less than 1.0
    const score = report.safetyScore();
    try std.testing.expect(score > 0.0 and score < 1.0);
}

test "MatchResultList filter and limit" {
    var list = MatchResultList.init(std.testing.allocator);
    defer list.deinit();

    // Add some matches
    try list.append(try MatchResult.init(std.testing.allocator, 1, 1, "match1", 0.9, .exact_ast));
    try list.append(try MatchResult.init(std.testing.allocator, 2, 2, "match2", 0.4, .fuzzy_text));
    try list.append(try MatchResult.init(std.testing.allocator, 3, 3, "match3", 0.7, .fuzzy_text));

    try std.testing.expectEqual(@as(usize, 3), list.len());

    // Filter by threshold 0.5
    try list.filter(0.5);
    try std.testing.expectEqual(@as(usize, 2), list.len());

    // Limit to 1
    list.limit(1);
    try std.testing.expectEqual(@as(usize, 1), list.len());
}
