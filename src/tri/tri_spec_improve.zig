// @origin(manual) @regen(pending)
// Trinity Spec Improve — tri spec improve
// Migrated from scripts/golden_seed_loop.sh, test_generated_code.sh, test_generated_code_parallel.sh
//
// Fill rate calculation, iterative improvement, backup/rollback, parallel test execution

const std = @import("std");

// Improvement configuration
pub const ImproveConfig = struct {
    max_iterations: u32 = 10,
    target_fill_rate: f64 = 0.85,
    backup_enabled: bool = true,
    parallel_jobs: u32 = 0, // 0 = auto (CPU count)
    output_dir: []const u8 = "var/trinity/output",
    specs_dir: []const u8 = "specs",
};

// Test result for a single .zig file
pub const TestResult = struct {
    file: []const u8,
    passed: bool,
    test_count: u32,
    elapsed_ms: u64,
    error_message: ?[]const u8,
};

// Test report summary
pub const TestReport = struct {
    total_files: u32,
    passed_files: u32,
    failed_files: u32,
    total_tests: u32,
    total_elapsed_ms: u64,

    pub fn passRate(self: TestReport) f64 {
        if (self.total_files == 0) return 0.0;
        return @as(f64, @floatFromInt(self.passed_files)) /
            @as(f64, @floatFromInt(self.total_files));
    }

    pub fn grade(self: TestReport) []const u8 {
        const rate = self.passRate() * 100.0;
        if (rate >= 100.0) return "EXCELLENT";
        if (rate >= 90.0) return "GOOD";
        if (rate >= 70.0) return "SATISFACTORY";
        return "POOR";
    }
};

/// Calculate fill rate for a spec file
pub fn calculateFillRate(content: []const u8) f64 {
    var total_impls: u64 = 0;
    var filled_impls: u64 = 0;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        // Count function/behavior declarations
        if (std.mem.startsWith(u8, trimmed, "pub fn ") or
            std.mem.startsWith(u8, trimmed, "fn "))
        {
            total_impls += 1;
            // Check if next lines have actual implementation (not just TODO/stub)
            if (!std.mem.endsWith(u8, trimmed, "{}") and
                !std.mem.endsWith(u8, trimmed, "{ }"))
            {
                filled_impls += 1;
            }
        }
    }

    if (total_impls == 0) return 1.0;
    return @as(f64, @floatFromInt(filled_impls)) /
        @as(f64, @floatFromInt(total_impls));
}

/// Check if all specs exceed target fill rate
pub fn checkConvergence(fill_rates: []const f64, target: f64) bool {
    for (fill_rates) |rate| {
        if (rate < target) return false;
    }
    return true;
}

/// Get CPU count for parallel execution
pub fn getCpuCount() u32 {
    return @intCast(std.Thread.getCpuCount() catch 4);
}

// Tests
test "fill rate - empty file" {
    try std.testing.expectEqual(@as(f64, 1.0), calculateFillRate(""));
}

test "fill rate - all filled" {
    const content =
        \\pub fn foo() void {
        \\    doSomething();
        \\}
        \\pub fn bar() i32 {
        \\    return 42;
        \\}
    ;
    try std.testing.expect(calculateFillRate(content) > 0.9);
}

test "convergence check" {
    const rates = [_]f64{ 0.90, 0.85, 0.95, 1.0 };
    try std.testing.expect(checkConvergence(&rates, 0.85));
    try std.testing.expect(!checkConvergence(&rates, 0.95));
}

test "test report grade" {
    const report = TestReport{
        .total_files = 10,
        .passed_files = 10,
        .failed_files = 0,
        .total_tests = 50,
        .total_elapsed_ms = 1000,
    };
    try std.testing.expectEqualStrings("EXCELLENT", report.grade());
    try std.testing.expectEqual(@as(f64, 1.0), report.passRate());
}

test "test report grade - satisfactory" {
    const report = TestReport{
        .total_files = 10,
        .passed_files = 8,
        .failed_files = 2,
        .total_tests = 40,
        .total_elapsed_ms = 1000,
    };
    try std.testing.expectEqualStrings("SATISFACTORY", report.grade());
}

test "cpu count" {
    const count = getCpuCount();
    try std.testing.expect(count > 0);
}

test "default config" {
    const config = ImproveConfig{};
    try std.testing.expectEqual(@as(u32, 10), config.max_iterations);
    try std.testing.expectApproxEqAbs(@as(f64, 0.85), config.target_fill_rate, 0.01);
}
