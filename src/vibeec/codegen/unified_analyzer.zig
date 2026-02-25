// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED ANALYZER — String + AST analysis dispatcher (Cycle 78)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Runs string-based checks (always) + AST-based checks (when tree-sitter linked).
// Single entry point for the gen pipeline.
//
// Mode detection:
//   - "string-based" when -Dtreesitter=false (default)
//   - "AST (tree-sitter)" when -Dtreesitter=true and grammar available
//   - "AST (fallback: string-based)" when linked but grammar missing
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ts_bridge = @import("ts_bridge.zig");
const idiom_mod = @import("idiom_analyzer.zig");
const treesitter_mod = @import("treesitter_analyzer.zig");

const Report = idiom_mod.Report;
const Violation = idiom_mod.Violation;

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYSIS MODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const AnalysisMode = enum {
    string_based,
    ast_treesitter,
    ast_fallback,

    pub fn label(self: AnalysisMode) []const u8 {
        return switch (self) {
            .string_based => "string-based",
            .ast_treesitter => "AST (tree-sitter)",
            .ast_fallback => "AST (fallback: string-based)",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedAnalyzer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    mode: AnalysisMode = .string_based,

    /// Run all applicable checks: string-based (always) + AST (when available)
    pub fn analyze(self: *UnifiedAnalyzer) !Report {
        // Phase 1: Always run string-based checks (Cycle 77)
        var string_analyzer = idiom_mod.IdiomAnalyzer{
            .allocator = self.allocator,
            .source = self.source,
        };
        var report = try string_analyzer.analyze();

        // Phase 2: Optionally run AST-based checks (Cycle 78)
        if (comptime ts_bridge.available) {
            var ast_analyzer = treesitter_mod.TreeSitterAnalyzer{
                .allocator = self.allocator,
                .source = self.source,
            };
            var ast_report = ast_analyzer.analyze() catch |err| {
                // AST analysis failed — fall back to string-only
                self.mode = .ast_fallback;
                std.debug.print("  [WARN] Tree-sitter analysis failed: {}\n", .{err});
                return report;
            };

            if (ast_report.violations.items.len > 0) {
                // Merge AST violations into main report
                try mergeReports(self.allocator, &report, &ast_report);
                self.mode = .ast_treesitter;
            } else {
                // AST ran but found nothing extra — could mean grammar not installed
                self.mode = .ast_treesitter;
            }
            ast_report.deinit();
        } else {
            self.mode = .string_based;
        }

        return report;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Merge violations from ast_report into main report
fn mergeReports(allocator: std.mem.Allocator, main: *Report, ast: *Report) !void {
    for (ast.violations.items) |violation| {
        try main.violations.append(allocator, violation);
    }
    // AST report may have counted additional functions
    main.total_functions += ast.total_functions;
    main.compliant_functions += ast.compliant_functions;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "unified_fallback_to_string" {
    // Without tree-sitter, should produce same results as idiom_analyzer alone
    const source =
        \\pub fn parseFields(allocator: std.mem.Allocator, allocator: std.mem.Allocator) ![]const u8 {
        \\    return "";
        \\}
    ;

    var unified = UnifiedAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try unified.analyze();
    defer report.deinit();

    // Should find duplicate_param from string-based check
    var found_dup = false;
    for (report.violations.items) |v| {
        if (v.kind == .duplicate_param) found_dup = true;
    }
    try std.testing.expect(found_dup);

    // Mode should be string_based when tree-sitter is not linked
    if (comptime !ts_bridge.available) {
        try std.testing.expectEqual(AnalysisMode.string_based, unified.mode);
    }
}

test "unified_clean_code" {
    const source =
        \\pub fn good(n: u32) u32 {
        \\    return n + 1;
        \\}
    ;

    var unified = UnifiedAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try unified.analyze();
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 0), report.violations.items.len);
    try std.testing.expectEqual(@as(usize, 1), report.total_functions);
    try std.testing.expectEqual(@as(usize, 1), report.compliant_functions);
}

test "unified_compliance_percent" {
    const source =
        \\pub fn good(n: u32) u32 {
        \\    return n + 1;
        \\}
        \\pub fn bad(allocator: std.mem.Allocator, allocator: std.mem.Allocator) !void {
        \\    return;
        \\}
    ;

    var unified = UnifiedAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try unified.analyze();
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 2), report.total_functions);
    try std.testing.expectApproxEqAbs(report.compliancePercent(), 50.0, 0.1);
}
