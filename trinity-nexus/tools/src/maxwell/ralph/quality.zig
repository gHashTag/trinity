//! Quality Gates Implementation
//! Implements the 4 mandatory gates: Build, Test, Format, Branch

const std = @import("std");
const Allocator = std.mem.Allocator;
const process = @import("process.zig");
const git_mod = @import("git.zig");

pub const GateResult = struct {
    passed: bool,
    duration_ns: u64,
    stdout: []const u8,
    stderr: []const u8,

    pub fn deinit(self: *GateResult, allocator: Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

pub const QualityGates = struct {
    build: GateResult,
    @"test": GateResult,
    format: GateResult,
    branch_valid: GateResult,

    pub fn deinit(self: *QualityGates, allocator: Allocator) void {
        self.build.deinit(allocator);
        self.@"test".deinit(allocator);
        self.format.deinit(allocator);
        self.branch_valid.deinit(allocator);
    }

    pub fn allPassed(self: QualityGates) bool {
        return self.build.passed and
            self.@"test".passed and
            self.format.passed and
            self.branch_valid.passed;
    }

    pub fn getFailedGate(self: QualityGates) ?[]const u8 {
        if (!self.build.passed) return "build";
        if (!self.@"test".passed) return "test";
        if (!self.format.passed) return "format";
        if (!self.branch_valid.passed) return "branch";
        return null;
    }
};

/// Run all 4 quality gates in strict sequential order
/// Stops at first failure
pub fn runQualityGates(allocator: Allocator) !QualityGates {
    var gates = QualityGates{
        .build = undefined,
        .@"test" = undefined,
        .format = undefined,
        .branch_valid = undefined,
    };

    // Gate 1: Branch Check (safety first - check before doing expensive work)
    gates.branch_valid = try checkBranch(allocator);
    if (!gates.branch_valid.passed) {
        gates.build = GateResult{
            .passed = false,
            .duration_ns = 0,
            .stdout = &.{},
            .stderr = &.{},
        };
        gates.@"test" = gates.build;
        gates.format = gates.build;
        return gates;
    }

    // Gate 2: Build Check
    gates.build = try checkBuild(allocator);
    if (!gates.build.passed) {
        gates.@"test" = GateResult{
            .passed = false,
            .duration_ns = 0,
            .stdout = &.{},
            .stderr = &.{},
        };
        gates.format = gates.@"test";
        return gates;
    }

    // Gate 3: Test Check (only runs if build passes)
    gates.@"test" = try checkTests(allocator);
    if (!gates.@"test".passed) {
        gates.format = GateResult{
            .passed = false,
            .duration_ns = 0,
            .stdout = &.{},
            .stderr = &.{},
        };
        return gates;
    }

    // Gate 4: Format Check
    gates.format = try checkFormat(allocator);

    return gates;
}

/// Gate 1: Branch Safety Check
/// Ensures not on main/master branch
pub fn checkBranch(allocator: Allocator) !GateResult {
    const start_time = try std.time.Instant.now();

    const result = git_mod.getCurrentBranch(allocator);
    const branch = result catch {
        const end_time = try std.time.Instant.now();
        return GateResult{
            .passed = false,
            .duration_ns = end_time.since(start_time),
            .stdout = &.{},
            .stderr = try allocator.dupe(u8, "Failed to get current branch"),
        };
    };
    defer allocator.free(branch);

    const is_main = std.mem.eql(u8, branch, "main") or std.mem.eql(u8, branch, "master");

    const end_time = try std.time.Instant.now();

    if (is_main) {
        return GateResult{
            .passed = false,
            .duration_ns = end_time.since(start_time),
            .stdout = try allocator.dupe(u8, branch),
            .stderr = try allocator.dupe(u8, "Cannot commit to main branch. Use ralph/<task-slug>."),
        };
    }

    return GateResult{
        .passed = true,
        .duration_ns = end_time.since(start_time),
        .stdout = try allocator.dupe(u8, branch),
        .stderr = &.{},
    };
}

/// Gate 2: Build Check
/// Runs `zig build` and ensures exit code 0
pub fn checkBuild(allocator: Allocator) !GateResult {
    const start_time = try std.time.Instant.now();

    const result = process.zigBuild(allocator, &[_][]const u8{}) catch |err| {
        const end_time = try std.time.Instant.now();
        return GateResult{
            .passed = false,
            .duration_ns = end_time.since(start_time),
            .stdout = &.{},
            .stderr = try allocator.dupe(u8, @errorName(err)),
        };
    };
    defer result.deinit(allocator);

    const end_time = try std.time.Instant.now();

    return GateResult{
        .passed = result.exit_code == 0,
        .duration_ns = end_time.since(start_time),
        .stdout = try allocator.dupe(u8, result.stdout),
        .stderr = try allocator.dupe(u8, result.stderr),
    };
}

/// Gate 3: Test Check
/// Runs `zig build test` and ensures all tests pass
pub fn checkTests(allocator: Allocator) !GateResult {
    const start_time = try std.time.Instant.now();

    const result = process.zigTest(allocator, &[_][]const u8{}) catch |err| {
        const end_time = try std.time.Instant.now();
        return GateResult{
            .passed = false,
            .duration_ns = end_time.since(start_time),
            .stdout = &.{},
            .stderr = try allocator.dupe(u8, @errorName(err)),
        };
    };
    defer result.deinit(allocator);

    const end_time = try std.time.Instant.now();

    return GateResult{
        .passed = result.exit_code == 0,
        .duration_ns = end_time.since(start_time),
        .stdout = try allocator.dupe(u8, result.stdout),
        .stderr = try allocator.dupe(u8, result.stderr),
    };
}

/// Gate 4: Format Check
/// Runs `zig fmt --check src/` and ensures formatting is clean
pub fn checkFormat(allocator: Allocator) !GateResult {
    const start_time = try std.time.Instant.now();

    const result = process.zigFmt(allocator, &[_][]const u8{ "--check", "src/" }) catch |err| {
        const end_time = try std.time.Instant.now();
        return GateResult{
            .passed = false,
            .duration_ns = end_time.since(start_time),
            .stdout = &.{},
            .stderr = try allocator.dupe(u8, @errorName(err)),
        };
    };
    defer result.deinit(allocator);

    const end_time = try std.time.Instant.now();

    return GateResult{
        .passed = result.exit_code == 0,
        .duration_ns = end_time.since(start_time),
        .stdout = try allocator.dupe(u8, result.stdout),
        .stderr = try allocator.dupe(u8, result.stderr),
    };
}

/// Circuit breaker state machine check
/// Transitions state based on progress/no-progress
pub fn circuitBreakerCheck(
    state: CircuitBreakerState,
    made_progress: bool,
    no_progress_count: u32,
    threshold: u32,
) !CircuitBreakerTransition {
    return switch (state) {
        .closed => if (made_progress)
            CircuitBreakerTransition{ .new_state = .closed, .no_progress_count = 0, .should_halt = false }
        else if (no_progress_count + 1 >= threshold)
            CircuitBreakerTransition{ .new_state = .open, .no_progress_count = no_progress_count + 1, .should_halt = true }
        else
            CircuitBreakerTransition{ .new_state = .closed, .no_progress_count = no_progress_count + 1, .should_halt = false },

        .half_open => if (made_progress)
            CircuitBreakerTransition{ .new_state = .closed, .no_progress_count = 0, .should_halt = false }
        else
            CircuitBreakerTransition{ .new_state = .open, .no_progress_count = 1, .should_halt = true },

        .open => CircuitBreakerTransition{
            .new_state = .open,
            .no_progress_count = no_progress_count,
            .should_halt = true,
        },
    };
}

pub const CircuitBreakerState = enum {
    closed, // Normal operation
    half_open, // Testing if recovery is possible
    open, // Stopped - waiting for human intervention
};

pub const CircuitBreakerTransition = struct {
    new_state: CircuitBreakerState,
    no_progress_count: u32,
    should_halt: bool,

    pub fn init(new_state: CircuitBreakerState, no_progress_count: u32) CircuitBreakerTransition {
        return .{
            .new_state = new_state,
            .no_progress_count = no_progress_count,
            .should_halt = new_state == .open,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "quality: check branch" {
    const allocator = std.testing.allocator;

    var result = try checkBranch(allocator);
    defer result.deinit(allocator);

    try std.testing.expect(result.duration_ns > 0);
}

test "quality: circuit breaker closed -> no progress -> closed" {
    const transition = try circuitBreakerCheck(.closed, false, 0, 3);

    try std.testing.expectEqual(CircuitBreakerState.closed, transition.new_state);
    try std.testing.expectEqual(@as(u32, 1), transition.no_progress_count);
    try std.testing.expect(false == transition.should_halt);
}

test "quality: circuit breaker closed -> no progress threshold -> open" {
    const transition = try circuitBreakerCheck(.closed, false, 2, 3);

    try std.testing.expectEqual(CircuitBreakerState.open, transition.new_state);
    try std.testing.expectEqual(@as(u32, 3), transition.no_progress_count);
    try std.testing.expect(true == transition.should_halt);
}

test "quality: circuit breaker closed -> progress -> closed" {
    const transition = try circuitBreakerCheck(.closed, true, 2, 3);

    try std.testing.expectEqual(CircuitBreakerState.closed, transition.new_state);
    try std.testing.expectEqual(@as(u32, 0), transition.no_progress_count);
    try std.testing.expect(false == transition.should_halt);
}
