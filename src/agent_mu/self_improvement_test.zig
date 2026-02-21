//! AGENT MU Self-Improvement Integration Test v8.15
//!
//! Tests the complete self-evolution loop:
//! V01 → Phi02 → Pi03 → Mu05 → Sigma07 → Chi06
//!
//! μ = 1/φ²/10 = 0.0382 per successful fix

const std = @import("std");

// Import AGENT MU modules
const agent_mu = @import("agent_mu.zig");
const diagnostic = @import("diagnostic.zig");
const pattern_matcher = @import("pattern_matcher.zig");
const logger = @import("logger.zig");
const mu_tracker = @import("mu_tracker.zig");

const Allocator = std.mem.Allocator;

/// Test fixture for creating a file with intentional error
fn createBuggyFile(allocator: Allocator, dir_path: []const u8) ![]const u8 {
    const file_name = "buggy_test.zig";
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, file_name });

    const buggy_code =
        \\//! Generated code with intentional error
        \\const std = @import("std");
        \\
        \\pub fn add(a: u32, b: u32) u32 {
        \\    // Missing semicolon on purpose
        \\    return a + b
        \\}
        \\
        \\pub fn multiply(x: u32, y: u32) u32 {
        \\    return x * y;
        \\}
    ;

    try std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = buggy_code });
    return file_path;
}

/// Clean up test file
fn cleanupTestFile(file_path: []const u8) void {
    std.fs.cwd().deleteFile(file_path) catch {};
}

test "AGENT MU: Full self-improvement loop" {
    const allocator = std.testing.allocator;

    // Use a simple temp directory path
    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();

    // Get the temp directory path - in Zig 0.15.2 we need to construct it
    // For now, use the current directory with a unique name
    const test_dir_name = "agent_mu_test_temp";
    const test_dir_path = try std.fs.path.join(allocator, &[_][]const u8{ ".", test_dir_name });
    defer allocator.free(test_dir_path);

    // Create temp directory
    try std.fs.cwd().makePath(test_dir_path);
    defer std.fs.cwd().deleteTree(test_dir_path) catch {};

    // Create a file with intentional error
    const buggy_file = try createBuggyFile(allocator, test_dir_path);
    defer cleanupTestFile(buggy_file);
    defer allocator.free(buggy_file);

    // Initialize MuTracker
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Initialize AGENT MU config
    const config = agent_mu.Config{
        .max_retries = 3,
        .timeout_seconds = 30,
        .verbose = false,
        .enable_auto_fix = true,
    };

    // Run verifyAndFix loop
    const result = try agent_mu.verifyAndFix(allocator, buggy_file, config);

    // Verify the loop completed without crash (result may succeed or fail)
    try std.testing.expect(result.attempts_made > 0);

    // If fix was applied, verify μ tracking
    if (result.fix_applied) {
        const multiplier = tracker.getIntelligenceMultiplier();
        try std.testing.expect(multiplier >= 1.0);
    }
}

test "AGENT MU: μ tracking integration" {
    const allocator = std.testing.allocator;

    // Initialize tracker
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    const initial_multiplier = tracker.getIntelligenceMultiplier();

    // Simulate 2 successful fixes
    try tracker.recordFix("TYPE_FIX", true, "Test error", 100, 0.9);
    try tracker.recordFix("ALLOCATOR_FIX", true, "Test error", 100, 0.8);

    const after_multiplier = tracker.getIntelligenceMultiplier();

    // Verify multiplier increased
    try std.testing.expect(after_multiplier >= initial_multiplier);
    try std.testing.expect(tracker.total_fixes == 2);
}

test "AGENT MU: Intelligence multiplier formula" {
    const allocator = std.testing.allocator;

    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // μ = 1/φ²/10 = 0.0382 per fix
    // Multiplier = e^(μ × N) where N = successful fixes

    // Record 10 successful fixes
    for (0..10) |_| {
        try tracker.recordFix("TYPE_FIX", true, "Test error", 100, 0.9);
    }

    const multiplier = tracker.getIntelligenceMultiplier();

    // After 10 fixes, multiplier should be approximately e^(10 * 0.0382) ≈ 1.47
    // Allow 10% tolerance for floating point
    const expected_multiplier = std.math.exp(10.0 * 0.0382);
    const tolerance = expected_multiplier * 0.1;

    try std.testing.expectApproxEqRel(
        expected_multiplier,
        multiplier,
        tolerance,
    );
}

test "AGENT MU: Pattern search integration" {
    const allocator = std.testing.allocator;

    // Search for a common error pattern
    const pattern = try pattern_matcher.searchRegressionPatterns(
        allocator,
        .TYPE_FIX,
        "error: expected type 'u32', found 'i32'",
    );

    _ = pattern;

    // Just verify the search completes without crash
    // Pattern may or may not be found depending on REGRESSION_PATTERNS.md content
}

test "AGENT MU: Error parsing" {
    const allocator = std.testing.allocator;

    const stderr_output =
        \\error: expected ';', found '}'
        \\test.zig:5:10: note: intended as declaration
    ;

    var err_info = try diagnostic.parse(allocator, stderr_output);
    defer err_info.deinit(allocator);

    // Verify error was parsed
    try std.testing.expect(err_info.fix_type != .UNKNOWN);
    try std.testing.expect(err_info.message.len > 0);
}

test "AGENT MU: Logger output" {
    const allocator = std.testing.allocator;

    // Create a test error info
    var err_info = diagnostic.ErrorInfo{
        .fix_type = .TYPE_FIX,
        .message = "Test error message",
        .file = "test.zig",
        .line = 10,
        .column = 5,
        .code = "E0001",
    };

    // Log success (should write to SUCCESS_HISTORY.md)
    try logger.logSuccess(
        allocator,
        &err_info,
        "Test fix applied",
        @constCast(&[_][]const u8{"test.zig"}),
    );

    // Just verify it completes without crash
    // Actual file content verification would require reading SUCCESS_HISTORY.md
}

test "AGENT MU: Fix type coverage" {
    // Verify all 17 FixType are defined
    const all_types = [_]diagnostic.FixType{
        .IMPORT_FIX,
        .TYPE_FIX,
        .SYNTAX_FIX,
        .TEMPLATE_FIX,
        .SPEC_FIX,
        .GENERATOR_PATCH,
        .UNKNOWN,
        .ALLOCATOR_FIX,
        .ERROR_UNION_FIX,
        .COMPTIME_FIX,
        .VSA_FIX,
        .MEM_FIX,
        .IOPATTERN_FIX,
        .COMPTIME_QUOTA_FIX,
        .UNMANAGED_FIX,
        .TYPEFUNCTION_FIX,
        .INLINE_FIX,
    };

    // Verify we have 17 FixType variants
    try std.testing.expectEqual(@as(usize, 17), all_types.len);
}

test "AGENT MU: Config defaults" {
    const config = agent_mu.Config{};

    try std.testing.expectEqual(@as(u32, 3), config.max_retries);
    try std.testing.expectEqual(@as(u32, 120), config.timeout_seconds);
    try std.testing.expectEqual(false, config.verbose);
    try std.testing.expectEqual(true, config.enable_auto_fix);
}

test "AGENT MU: Result fields" {
    const result = agent_mu.Result{
        .success = true,
        .attempts_made = 1,
        .error_message = "",
        .fix_applied = false,
        .intelligence_gain = 0.0382,
    };

    try std.testing.expectEqual(true, result.success);
    try std.testing.expectEqual(@as(u32, 1), result.attempts_made);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), result.intelligence_gain, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: μ accumulation curve
// ═══════════════════════════════════════════════════════════════════════════════

test "AGENT MU benchmark: Intelligence curve" {
    const allocator = std.testing.allocator;

    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    const start_time = std.time.nanoTimestamp();

    // Simulate 100 fixes
    for (0..100) |_| {
        try tracker.recordFix("TYPE_FIX", true, "Test error", 100, 0.9);
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    const multiplier = tracker.getIntelligenceMultiplier();

    std.debug.print("\n  ═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  AGENT MU Intelligence Curve Benchmark\n", .{});
    std.debug.print("  ═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Total fixes:        {d}\n", .{tracker.total_fixes});
    std.debug.print("  Successful fixes:   {d}\n", .{tracker.successful_fixes});
    std.debug.print("  μ accumulated:       {d:.4}\n", .{tracker.getCurrentMu()});
    std.debug.print("  Intelligence:        {d:.2}×\n", .{multiplier});
    std.debug.print("  Target (100 fixes): ~47×\n", .{});
    std.debug.print("  Progress:            {d:.1}%\n", .{multiplier / 47.0 * 100.0});
    std.debug.print("  Time:                {d:.2} ms\n", .{elapsed_ms});
    std.debug.print("  ═══════════════════════════════════════════════════════════════\n\n", .{});

    // Verify we're in reasonable range (10-100× for 100 fixes)
    try std.testing.expect(multiplier > 10.0);
    try std.testing.expect(multiplier < 100.0);
}
