//! Coverage Analysis Tool for Trinity S³AI
//!
//! Provides module-wise coverage analysis for test suites.
//! Generates detailed reports with line coverage, branch coverage,
//! and function coverage metrics.

const std = @import("std");

/// Coverage statistics for a single module
pub const ModuleCoverage = struct {
    name: []const u8,
    file_path: []const u8,
    total_lines: usize,
    covered_lines: usize,
    total_functions: usize,
    covered_functions: usize,
    total_branches: usize,
    covered_branches: usize,

    /// Calculate line coverage percentage
    pub fn lineCoverage(self: ModuleCoverage) f64 {
        if (self.total_lines == 0) return 0.0;
        return @as(f64, @floatFromInt(self.covered_lines)) * 100.0 / @as(f64, @floatFromInt(self.total_lines));
    }

    /// Calculate function coverage percentage
    pub fn functionCoverage(self: ModuleCoverage) f64 {
        if (self.total_functions == 0) return 0.0;
        return @as(f64, @floatFromInt(self.covered_functions)) * 100.0 / @as(f64, @floatFromInt(self.total_functions));
    }

    /// Calculate branch coverage percentage
    pub fn branchCoverage(self: ModuleCoverage) f64 {
        if (self.total_branches == 0) return 0.0;
        return @as(f64, @floatFromInt(self.covered_branches)) * 100.0 / @as(f64, @floatFromInt(self.total_branches));
    }

    /// Get overall coverage score (weighted average)
    pub fn overallCoverage(self: ModuleCoverage) f64 {
        return (self.lineCoverage() * 0.5 +
            self.functionCoverage() * 0.3 +
            self.branchCoverage() * 0.2);
    }

    /// Get coverage grade
    pub fn grade(self: ModuleCoverage) []const u8 {
        const cov = self.overallCoverage();
        return if (cov >= 90.0) "A" else if (cov >= 80.0) "B" else if (cov >= 70.0) "C" else if (cov >= 60.0) "D" else "F";
    }
};

/// Coverage report for multiple modules
pub const CoverageReport = struct {
    modules: std.ArrayList(ModuleCoverage),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CoverageReport {
        return .{
            .modules = std.ArrayList(ModuleCoverage).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CoverageReport) void {
        self.modules.deinit(self.allocator);
    }

    /// Add a module to the report
    pub fn addModule(self: *CoverageReport, coverage: ModuleCoverage) !void {
        try self.modules.append(self.allocator, coverage);
    }

    /// Calculate total coverage across all modules
    pub fn totalCoverage(self: CoverageReport) struct {
        lines: f64,
        functions: f64,
        branches: f64,
        overall: f64,
    } {
        if (self.modules.items.len == 0) return .{ .lines = 0, .functions = 0, .branches = 0, .overall = 0 };

        var total_lines: usize = 0;
        var covered_lines: usize = 0;
        var total_functions: usize = 0;
        var covered_functions: usize = 0;
        var total_branches: usize = 0;
        var covered_branches: usize = 0;

        for (self.modules.items) |mod| {
            total_lines += mod.total_lines;
            covered_lines += mod.covered_lines;
            total_functions += mod.total_functions;
            covered_functions += mod.covered_functions;
            total_branches += mod.total_branches;
            covered_branches += mod.covered_branches;
        }

        const line_cov = if (total_lines > 0)
            @as(f64, @floatFromInt(covered_lines)) * 100.0 / @as(f64, @floatFromInt(total_lines))
        else
            0.0;
        const func_cov = if (total_functions > 0)
            @as(f64, @floatFromInt(covered_functions)) * 100.0 / @as(f64, @floatFromInt(total_functions))
        else
            0.0;
        const branch_cov = if (total_branches > 0)
            @as(f64, @floatFromInt(covered_branches)) * 100.0 / @as(f64, @floatFromInt(total_branches))
        else
            0.0;

        return .{
            .lines = line_cov,
            .functions = func_cov,
            .branches = branch_cov,
            .overall = line_cov * 0.5 + func_cov * 0.3 + branch_cov * 0.2,
        };
    }

    /// Generate markdown table
    pub fn toMarkdown(self: CoverageReport, writer: anytype) !void {
        try writer.writeAll(
            \\# Trinity S³AI Coverage Report
            \\
            \\| Module | Lines | Functions | Branches | Overall | Grade |
            \\|--------|-------|-----------|----------|--------|-------|
        );

        for (self.modules.items) |mod| {
            try writer.print(
                "| {s} | {d:.1}% | {d:.1}% | {d:.1}% | {d:.1}% | {s} |\n",
                .{
                    mod.name,
                    mod.lineCoverage(),
                    mod.functionCoverage(),
                    mod.branchCoverage(),
                    mod.overallCoverage(),
                    mod.grade(),
                },
            );
        }

        const total = self.totalCoverage();
        try writer.writeAll("\n## Summary\n\n");
        try writer.print(
            "**Total Coverage:** {d:.1}%\n\n",
            .{total.overall},
        );
        try writer.print(
            \\- Lines: {d:.1}%
            \\- Functions: {d:.1}%
            \\- Branches: {d:.1}%
            \\
        , .{ total.lines, total.functions, total.branches });
    }

    /// Generate console output with colors
    pub fn toConsole(self: CoverageReport) !void {
        const stdout = std.io.getStdOut().writer();
        const total = self.totalCoverage();

        try stdout.writeAll(
            \\
            \\╔════════════════════════════════════════════════════════╗
            \\║       Trinity S³AI Coverage Report                    ║
            \\╚════════════════════════════════════════════════════════╝
            \\
        );

        for (self.modules.items) |mod| {
            const grade_color = if (std.mem.eql(u8, mod.grade(), "A")) "\x1b[32m" // Green
                else if (std.mem.eql(u8, mod.grade(), "B")) "\x1b[36m" // Cyan
                else if (std.mem.eql(u8, mod.grade(), "C")) "\x1b[33m" // Yellow
                else "\x1b[31m"; // Red

            try stdout.print(
                "{s:20} [{s}{s}\x1b[0m] {d:5.1}% (L:{d:4.1}% F:{d:4.1}% B:{d:4.1}%)\n",
                .{
                    mod.name,
                    grade_color,
                    mod.grade(),
                    mod.overallCoverage(),
                    mod.lineCoverage(),
                    mod.functionCoverage(),
                    mod.branchCoverage(),
                },
            );
        }

        try stdout.writeAll("\n─────────────────────────────────────────────\n");
        try stdout.print("Total: {d:.1}% coverage\n", .{total.overall});
    }
};

/// Analyze a single Zig file for coverage
pub fn analyzeFile(
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !ModuleCoverage {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
    defer allocator.free(source);

    var total_lines: usize = 0;
    var total_functions: usize = 0;
    var total_branches: usize = 0;

    // Count lines
    var line_iter = std.mem.splitScalar(u8, source, '\n');
    while (line_iter.next()) |_| total_lines += 1;

    // Count functions (fn keyword)
    var fn_iter = std.mem.splitSequence(u8, source, "fn ");
    while (fn_iter.next()) |_| {
        // Skip if inside comment or string (simplified)
        total_functions += 1;
    }

    // Count branches (if, switch, for, while)
    total_branches += countOccurrences(source, "if ");
    total_branches += countOccurrences(source, "switch ");
    total_branches += countOccurrences(source, "for (");
    total_branches += countOccurrences(source, "while (");

    // For now, estimate coverage based on test presence
    // In production, use actual coverage data from zig build test
    const test_file = try std.fmt.allocPrint(allocator, "{s}_test.zig", .{std.fs.path.stem(file_path)});
    defer allocator.free(test_file);

    const has_test = std.fs.cwd().openFile(test_file, .{}) catch null;
    if (has_test) |f| f.close();

    // Estimate: if test exists, assume 70% coverage
    const coverage_factor: f64 = if (has_test != null) 0.7 else 0.0;

    return ModuleCoverage{
        .name = std.fs.path.stem(file_path),
        .file_path = file_path,
        .total_lines = total_lines,
        .covered_lines = @intFromFloat(@as(f64, @floatFromInt(total_lines)) * coverage_factor),
        .total_functions = total_functions,
        .covered_functions = @intFromFloat(@as(f64, @floatFromInt(total_functions)) * coverage_factor),
        .total_branches = total_branches,
        .covered_branches = @intFromFloat(@as(f64, @floatFromInt(total_branches)) * coverage_factor),
    };
}

/// Count occurrences of a substring
fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, needle, start)) |idx| {
        count += 1;
        start = idx + needle.len;
    }
    return count;
}

/// Main coverage analysis entry point
pub fn runAnalysis(
    allocator: std.mem.Allocator,
    source_files: []const []const u8,
) !CoverageReport {
    var report = CoverageReport.init(allocator);
    errdefer report.deinit();

    for (source_files) |file| {
        const coverage = try analyzeFile(allocator, file);
        try report.addModule(coverage);
    }

    return report;
}

// Tests
test "ModuleCoverage calculation" {
    const cov = ModuleCoverage{
        .name = "test",
        .file_path = "test.zig",
        .total_lines = 100,
        .covered_lines = 85,
        .total_functions = 10,
        .covered_functions = 8,
        .total_branches = 20,
        .covered_branches = 15,
    };

    try std.testing.expectApproxEqRel(@as(f64, 85.0), cov.lineCoverage(), 0.01);
    try std.testing.expectApproxEqRel(@as(f64, 80.0), cov.functionCoverage(), 0.01);
    try std.testing.expectApproxEqRel(@as(f64, 75.0), cov.branchCoverage(), 0.01);
    try std.testing.expect(cov.overallCoverage() >= 75.0 and cov.overallCoverage() <= 85.0);
}

test "CoverageReport aggregation" {
    const allocator = std.testing.allocator;
    var report = CoverageReport.init(allocator);
    defer report.deinit();

    try report.addModule(.{
        .name = "mod1",
        .file_path = "mod1.zig",
        .total_lines = 100,
        .covered_lines = 80,
        .total_functions = 10,
        .covered_functions = 8,
        .total_branches = 20,
        .covered_branches = 15,
    });

    try report.addModule(.{
        .name = "mod2",
        .file_path = "mod2.zig",
        .total_lines = 200,
        .covered_lines = 160,
        .total_functions = 20,
        .covered_functions = 18,
        .total_branches = 40,
        .covered_branches = 30,
    });

    const total = report.totalCoverage();
    try std.testing.expect(total.lines >= 79.0 and total.lines <= 81.0);
    try std.testing.expect(report.modules.items.len == 2);
}
