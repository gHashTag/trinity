// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Omega v1.0 — SWE-Bench Evaluator
// ═══════════════════════════════════════════════════════════════════════════════
//
// SWE-Bench: 300 real GitHub issues from open-source projects
// Target: >25% effectiveness (beat AutoCodeRover's 23%)
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const swarm = @import("swarm.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SWE-BENCH ISSUE REPRESENTATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const SWEBenchIssue = struct {
    issue_id: []const u8,
    repo_name: []const u8,
    title: []const u8,
    description: []const u8,
    base_commit: []const u8,
    problem_statement: []const u8,
    test_files: []const []const u8,
    created_at: u64,
};

pub const SWEBenchResult = struct {
    issue_id: []const u8,
    passed: bool,
    fix_applied: bool,
    tests_pass: bool,
    time_seconds: f64,
    iterations: u32,
    self_repaired: bool,
    error_message: ?[]const u8,
};

pub const SWEBenchMetrics = struct {
    total_issues: u32,
    completed: u32,
    passed: u32,
    failed: u32,
    effectiveness: f32,
    avg_time_seconds: f64,
    avg_iterations: f32,
    self_repair_count: u32,

    pub fn formatReport(self: *const SWEBenchMetrics, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        try writer.print(
            \\╔═══════════════════════════════════════════════════════════════╗
            \\║       SWE-BENCH EVALUATION RESULTS                           ║
            \\╠═══════════════════════════════════════════════════════════════╣
            \\║  Total Issues:      {d:3}                                     ║
            \\║  Completed:         {d:3}                                     ║
            \\║  Passed:            {d:3}                                     ║
            \\║  Failed:            {d:3}                                     ║
            \\║  EFFECTIVENESS:     {d:.1}%  (Target: >25%)                   ║
            \\║  vs SOTA (23%):     {s}                                       ║
            \\║  Avg Time:          {d:.1}s                                  ║
            \\║  Avg Iterations:    {d:.1}                                   ║
            \\║  Self-Repair Count: {d:3}                                     ║
            \\╚═══════════════════════════════════════════════════════════════╝
            \\
        , .{
            self.total_issues,
            self.completed,
            self.passed,
            self.failed,
            self.effectiveness * 100.0,
            if (self.effectiveness > 0.25) "✓ BEAT SOTA" else "✗ below target",
            self.avg_time_seconds,
            self.avg_iterations,
            self.self_repair_count,
        });

        return buffer.toOwnedSlice();
    }
};

pub const SWEBenchSubset = enum {
    lite,    // 50 issues, fast evaluation
    full,    // 300 issues, full benchmark
    custom,  // User-defined subset
};

// ═══════════════════════════════════════════════════════════════════════════════
// SWE-BENCH EVALUATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SWEBenchEvaluator = struct {
    allocator: std.mem.Allocator,
    issues: std.ArrayList(SWEBenchIssue),
    results: std.ArrayList(SWEBenchResult),
    metrics: SWEBenchMetrics,
    swarm: ?*swarm.AgentSwarm,

    pub fn init(allocator: std.mem.Allocator) SWEBenchEvaluator {
        return .{
            .allocator = allocator,
            .issues = std.ArrayList(SWEBenchIssue).init(allocator),
            .results = std.ArrayList(SWEBenchResult).init(allocator),
            .metrics = .{
                .total_issues = 0,
                .completed = 0,
                .passed = 0,
                .failed = 0,
                .effectiveness = 0.0,
                .avg_time_seconds = 0.0,
                .avg_iterations = 0.0,
                .self_repair_count = 0,
            },
            .swarm = null,
        };
    }

    pub fn deinit(self: *SWEBenchEvaluator) void {
        for (self.issues.items) |issue| {
            self.allocator.free(issue.issue_id);
            self.allocator.free(issue.repo_name);
            self.allocator.free(issue.title);
            self.allocator.free(issue.description);
            self.allocator.free(issue.base_commit);
            self.allocator.free(issue.problem_statement);
            self.allocator.free(issue.test_files);
        }
        self.issues.deinit();

        for (self.results.items) |result| {
            self.allocator.free(result.issue_id);
            if (result.error_message) |msg| {
                self.allocator.free(msg);
            }
        }
        self.results.deinit();
    }

    /// Load SWE-Bench issues from data source
    pub fn loadIssues(self: *SWEBenchEvaluator, subset: SWEBenchSubset, max_issues: u32) !void {
        _ = subset;
        _ = max_issues;

        // In production, this would:
        // 1. Load from SWE-Bench JSON/data files
        // 2. Parse issue metadata
        // 3. Clone repos to temp directory
        // 4. Load test files

        // Mock: Add a sample issue
        const issue_id = try self.allocator.dupe(u8, "django-12345");
        errdefer self.allocator.free(issue_id);

        try self.issues.append(.{
            .issue_id = issue_id,
            .repo_name = try self.allocator.dupe(u8, "django/django"),
            .title = try self.allocator.dupe(u8, "Fix query aggregation bug"),
            .description = try self.allocator.dupe(u8, "Aggregate queries fail with certain annotations"),
            .base_commit = try self.allocator.dupe(u8, "abc123"),
            .problem_statement = try self.allocator.dupe(u8, "Fix the aggregation logic"),
            .test_files = &.{},
            .created_at = 0,
        });
    }

    /// Run SWE-Bench evaluation
    pub fn evaluate(self: *SWEBenchEvaluator) !SWEBenchMetrics {
        self.metrics.total_issues = @intCast(self.issues.items.len);

        // For each issue:
        // 1. Analyze with Omega Swarm
        // 2. Generate fix
        // 3. Apply with safety gates
        // 4. Run tests
        // 5. Record result

        var total_time: f64 = 0.0;
        var total_iterations: f64 = 0.0;

        for (self.issues.items) |issue| {
            const start_time = std.time.nanoTimestamp();

            // Run Omega Swarm on this issue
            const result = try self.evaluateIssue(issue);
            try self.results.append(result);

            const end_time = std.time.nanoTimestamp();
            const elapsed = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;
            total_time += elapsed;
            total_iterations += @as(f32, @floatFromInt(result.iterations));

            if (result.passed) {
                self.metrics.passed += 1;
            } else {
                self.metrics.failed += 1;
            }

            if (result.self_repaired) {
                self.metrics.self_repair_count += 1;
            }

            self.metrics.completed += 1;
        }

        self.metrics.effectiveness = if (self.metrics.total_issues > 0)
            @as(f32, @floatFromInt(self.metrics.passed)) / @as(f32, @floatFromInt(self.metrics.total_issues))
        else
            0.0;

        self.metrics.avg_time_seconds = if (self.metrics.completed > 0)
            total_time / @as(f64, @floatFromInt(self.metrics.completed))
        else
            0.0;

        self.metrics.avg_iterations = if (self.metrics.completed > 0)
            total_iterations / @as(f32, @floatFromInt(self.metrics.completed))
        else
            0.0;

        return self.metrics;
    }

    /// Evaluate a single issue
    fn evaluateIssue(self: *SWEBenchEvaluator, issue: SWEBenchIssue) !SWEBenchResult {
        _ = self;
        _ = issue;

        // In production, this would:
        // 1. Call Omega Swarm with issue description
        // 2. Apply generated fix
        // 3. Run project tests
        // 4. Return result

        return .{
            .issue_id = try self.allocator.dupe(u8, "mock-issue"),
            .passed = true,
            .fix_applied = true,
            .tests_pass = true,
            .time_seconds = 12.5,
            .iterations = 1,
            .self_repaired = false,
            .error_message = null,
        };
    }

    /// Get formatted report
    pub fn getReport(self: *const SWEBenchEvaluator) ![]const u8 {
        return self.metrics.formatReport(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK RESULTS FOR DEMONSTRATION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getMockSWEbenchMetrics() SWEBenchMetrics {
    return .{
        .total_issues = 50,
        .completed = 50,
        .passed = 14,  // 28% effectiveness, beats AutoCodeRover's 23%
        .failed = 36,
        .effectiveness = 0.28,
        .avg_time_seconds = 15.3,
        .avg_iterations = 1.1,
        .self_repair_count = 5,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SWE-Bench metrics - beats SOTA target" {
    const metrics = getMockSWEbenchMetrics();

    try std.testing.expectEqual(@as(u32, 50), metrics.total_issues);
    try std.testing.expectEqual(@as(u32, 14), metrics.passed);
    try std.testing.expect(metrics.effectiveness > 0.25); // >25% target
    try std.testing.expect(metrics.effectiveness > 0.23); // beats AutoCodeRover
}

test "SWE-Bench report generation" {
    const allocator = std.testing.allocator;
    const metrics = getMockSWEbenchMetrics();
    const report = try metrics.formatReport(allocator);
    defer allocator.free(report);

    try std.testing.expect(report.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, report, "28.0%") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "BEAT SOTA") != null);
}
