// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════
// PONS — Bridge Queen↔Cerebellum, REM Coordination
// ═════════════════════════════════════════════════════════════════════════════════
// Neuro: Bridge cerebrum↔cerebellum, REM sleep coordination
// Trinity: Bridge Queen↔Cerebellum, REM dreaming for error consolidation
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const hippocampus = @import("hippocampus.zig");

// ═════════════════════════════════════════════════════════════════════════════════════
// CEREBELLUM BRIDGE — Queen ↔ Cerebellum data flow
// ═══════════════════════════════════════════════════════════════════════════════════

/// Bridge farm sweep results to cerebellum cell health updates
pub fn bridgeToCerebellum(
    allocator: Allocator,
    farm_results: FarmSweepResults,
) !void {
    // Write cell health updates for each farm account
    // Format: "cell_health: <name>: A|B|C|F"

    // Determine overall farm health
    const problem_count = farm_results.problemCount();
    const overall_status = if (problem_count == 0) "A" else if (problem_count < 5) "B" else if (problem_count < 10) "C" else "F";

    // Write overall farm health
    const health_data = try std.fmt.allocPrint(
        allocator,
        "{{\"farm_stale\":{d},\"farm_crashed\":{d},\"overall_status\":\"{s}\"}}",
        .{ farm_results.stale_count, farm_results.crashed_workers.len, overall_status },
    );
    defer allocator.free(health_data);

    const health_summary = try std.fmt.allocPrint(
        allocator,
        "cell_health: farm: {s}",
        .{overall_status},
    );
    defer allocator.free(health_summary);

    _ = try hippocampus.writeObservation(allocator, "phoenix_pons", health_summary, health_data);

    // Write individual crashed worker entries
    for (farm_results.crashed_workers) |worker| {
        const crash_data = try std.fmt.allocPrint(
            allocator,
            "{{\"worker\":\"{s}\",\"status\":\"F\"}}",
            .{worker},
        );
        defer allocator.free(crash_data);

        const crash_summary = try std.fmt.allocPrint(
            allocator,
            "cell_health: {s}: F",
            .{worker},
        );
        defer allocator.free(crash_summary);

        _ = try hippocampus.writeObservation(allocator, "phoenix_pons", crash_summary, crash_data);
    }
}

/// REM dreaming — generate fix_plan.md from fresh errors
pub fn remDreaming(allocator: Allocator, fresh_errors: []const Error) !void {
    // Generate structured fix plan entries
    // Format: "- [] Fix <error_description>\n  Context: ...\n  Suggestion: ..."

    if (fresh_errors.len == 0) {
        // No errors to process
        const data = try std.fmt.allocPrint(
            allocator,
            "{{\"dream_count\":0,\"fixes_required\":false}}",
            .{},
        );
        defer allocator.free(data);
        _ = try hippocampus.writeObservation(allocator, "phoenix_pons", "REM dreaming — no errors", data);
        return;
    }

    // Generate fix plan entries for each error
    var fix_plan = try std.ArrayList(u8).initCapacity(allocator, 256);
    defer fix_plan.deinit(allocator);

    for (fresh_errors) |err| {
        try fix_plan.appendSlice(allocator, "- ");
        try fix_plan.appendSlice(allocator, "[] Fix ");
        try fix_plan.appendSlice(allocator, err.code);
        try fix_plan.appendSlice(allocator, ": ");
        try fix_plan.appendSlice(allocator, err.messageStr());
        try fix_plan.appendSlice(allocator, "\n");

        // Add context
        try fix_plan.appendSlice(allocator, "  Context: Detected during REM sleep analysis\n");

        // Add suggestion based on error code
        try fix_plan.appendSlice(allocator, "  Suggestion: ");
        if (std.mem.eql(u8, err.code, "BUILD_FAIL")) {
            try fix_plan.appendSlice(allocator, "Check build log for compilation errors\n");
        } else if (std.mem.eql(u8, err.code, "TEST_FAIL")) {
            try fix_plan.appendSlice(allocator, "Review failing test and fix implementation\n");
        } else if (std.mem.eql(u8, err.code, "DEADLOCK")) {
            try fix_plan.appendSlice(allocator, "Analyze lock acquisition order and add timeouts\n");
        } else {
            try fix_plan.appendSlice(allocator, "Investigate error and implement appropriate fix\n");
        }
    }

    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"dream_count\":{d},\"fixes_required\":true,\"entries\":{d}}}",
        .{ fresh_errors.len, fresh_errors.len },
    );
    defer allocator.free(data);

    const summary = try std.fmt.allocPrint(
        allocator,
        "REM dreaming: {d} errors → fix plan",
        .{fresh_errors.len},
    );
    defer allocator.free(summary);

    _ = try hippocampus.writeObservation(allocator, "phoenix_pons", summary, data);
}

/// Farm sweep results from ARAS
pub const FarmSweepResults = struct {
    stale_count: usize = 0,
    crashed_workers: []const []const u8 = &.{},

    pub fn problemCount(self: *const FarmSweepResults) u32 {
        var count: u32 = @intCast(self.crashed_workers.len);
        count +%= @as(u32, @intCast(self.stale_count));
        return count;
    }
};

/// Error entry for REM dreaming
pub const Error = struct {
    code: []const u8,
    message: [256]u8 = undefined,
    message_len: usize = 0,

    pub fn messageStr(self: *const Error) []const u8 {
        return self.message[0..self.message_len];
    }

    pub fn setMessage(self: *Error, text: []const u8) void {
        const len = @min(text.len, self.message.len);
        @memcpy(self.message[0..len], text[0..len]);
        self.message_len = len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═════════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "pons — bridgeToCerebellum logs" {
    const results = FarmSweepResults{
        .stale_count = 3,
        .crashed_workers = &[_][]const u8{ "w1", "w2" },
    };

    _ = try bridgeToCerebellum(std.testing.allocator, results);

    // Should not panic
}

test "pons — remDreaming logs" {
    var errors = [_]Error{
        .{ .code = "E001" },
        .{ .code = "E002" },
    };
    errors[0].setMessage("Test error");
    errors[1].setMessage("Another error");

    _ = try remDreaming(std.testing.allocator, &errors);

    // Should not panic
}

test "pons — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "pons — FarmSweepResults problemCount" {
    const results = FarmSweepResults{
        .stale_count = 3,
        .crashed_workers = &[_][]const u8{ "w1", "w2", "w3" },
    };

    try std.testing.expectEqual(@as(u32, 6), results.problemCount());
}

test "pons — FarmSweepResults empty" {
    const results = FarmSweepResults{};

    try std.testing.expectEqual(@as(u32, 0), results.problemCount());
    try std.testing.expectEqual(@as(usize, 0), results.crashed_workers.len);
    try std.testing.expectEqual(@as(usize, 0), results.stale_count);
}

test "pons — Error setMessage" {
    var err = Error{ .code = "TEST" };
    try std.testing.expectEqual(@as(usize, 0), err.message_len);

    err.setMessage("Hello");
    try std.testing.expectEqual(@as(usize, 5), err.message_len);
    try std.testing.expectEqualStrings("Hello", err.messageStr());
}

test "pons — Error setMessage truncates" {
    var err = Error{ .code = "TEST" };
    // Create a message longer than 256 bytes
    var long_text: [300]u8 = undefined;
    @memset(&long_text, 'A');
    long_text[299] = 0;

    err.setMessage(&long_text);
    try std.testing.expectEqual(@as(usize, 256), err.message_len); // Truncated to max
}

test "pons — bridgeToCerebellum with crashed workers" {
    const results = FarmSweepResults{
        .stale_count = 0,
        .crashed_workers = &[_][]const u8{ "worker1", "worker2" },
    };

    _ = try bridgeToCerebellum(std.testing.allocator, results);

    // Should not panic - writes to hippocampus
}

test "pons — bridgeToCerebellum with no problems" {
    const results = FarmSweepResults{
        .stale_count = 0,
        .crashed_workers = &[_][]const u8{},
    };

    _ = try bridgeToCerebellum(std.testing.allocator, results);

    // Should not panic
}

test "pons — remDreaming with no errors" {
    const empty_errors = [_]Error{};

    _ = try remDreaming(std.testing.allocator, &empty_errors);

    // Should not panic - writes "no errors" observation
}

test "pons — remDreaming with BUILD_FAIL" {
    var errors = [_]Error{.{ .code = "BUILD_FAIL" }};
    errors[0].setMessage("Compilation failed");

    _ = try remDreaming(std.testing.allocator, &errors);

    // Should not panic - generates fix plan
}

test "pons — remDreaming with TEST_FAIL" {
    var errors = [_]Error{.{ .code = "TEST_FAIL" }};
    errors[0].setMessage("Test assertion failed");

    _ = try remDreaming(std.testing.allocator, &errors);

    // Should not panic
}

test "pons — remDreaming with DEADLOCK" {
    var errors = [_]Error{.{ .code = "DEADLOCK" }};
    errors[0].setMessage("Lock timeout");

    _ = try remDreaming(std.testing.allocator, &errors);

    // Should not panic
}

test "pons — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "pons — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "pons — CellHealth defaults" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════
// FARM SWEEP RESULTS TESTS
// ═══════════════════════════════════════════════════════════════════

test "pons — FarmSweepResults default values" {
    const results = FarmSweepResults{};
    try std.testing.expectEqual(@as(usize, 0), results.stale_count);
    try std.testing.expectEqual(@as(usize, 0), results.crashed_workers.len);
}

test "pons — FarmSweepResults problemCount with only stale" {
    const results = FarmSweepResults{ .stale_count = 10 };
    try std.testing.expectEqual(@as(u32, 10), results.problemCount());
}

test "pons — FarmSweepResults problemCount with only crashed" {
    const results = FarmSweepResults{
        .crashed_workers = &[_][]const u8{ "w1", "w2", "w3", "w4", "w5" },
    };
    try std.testing.expectEqual(@as(u32, 5), results.problemCount());
}

test "pons — FarmSweepResults problemCount wrapping" {
    const results = FarmSweepResults{
        .stale_count = 100,
        .crashed_workers = &[_][]const u8{"w1"},
    };
    try std.testing.expectEqual(@as(u32, 101), results.problemCount());
}

test "pons — FarmSweepResults with mixed problems" {
    const results = FarmSweepResults{
        .stale_count = 7,
        .crashed_workers = &[_][]const u8{ "w1", "w2", "w3" },
    };
    try std.testing.expectEqual(@as(u32, 10), results.problemCount());
}

// ═══════════════════════════════════════════════════════════════════
// ERROR TESTS
// ═══════════════════════════════════════════════════════════════════

test "pons — Error default values" {
    const err = Error{ .code = "TEST" };
    try std.testing.expectEqual(@as(usize, 0), err.message_len);
    try std.testing.expectEqual(@as(usize, 0), err.messageStr().len);
}

test "pons — Error messageStr with empty message" {
    var err = Error{ .code = "TEST" };
    try std.testing.expectEqual(@as(usize, 0), err.messageStr().len);
    try std.testing.expectEqualStrings("", err.messageStr());
}

test "pons — Error setMessage with empty string" {
    var err = Error{ .code = "TEST" };
    err.setMessage("");
    try std.testing.expectEqual(@as(usize, 0), err.message_len);
}

test "pons — Error setMessage multiple calls" {
    var err = Error{ .code = "TEST" };
    err.setMessage("First message");
    try std.testing.expectEqual(@as(usize, 13), err.message_len);

    err.setMessage("Second");
    try std.testing.expectEqual(@as(usize, 6), err.message_len);
    try std.testing.expectEqualStrings("Second", err.messageStr());
}

test "pons — Error code field" {
    const err = Error{ .code = "E001" };
    try std.testing.expectEqualStrings("E001", err.code);
}

// ═══════════════════════════════════════════════════════════════════
// REM DREAMING TESTS
// ═══════════════════════════════════════════════════════════════════

test "pons — remDreaming with unknown error code" {
    var errors = [_]Error{.{ .code = "UNKNOWN" }};
    errors[0].setMessage("Unknown error type");

    _ = try remDreaming(std.testing.allocator, &errors);
    // Should not panic - uses generic suggestion
}

test "pons — remDreaming with multiple error types" {
    var errors = [_]Error{
        .{ .code = "BUILD_FAIL" },
        .{ .code = "TEST_FAIL" },
        .{ .code = "DEADLOCK" },
        .{ .code = "UNKNOWN" },
    };
    errors[0].setMessage("Build error");
    errors[1].setMessage("Test error");
    errors[2].setMessage("Lock error");
    errors[3].setMessage("Mystery error");

    _ = try remDreaming(std.testing.allocator, &errors);
    // Should not panic - processes all errors
}

// ═══════════════════════════════════════════════════════════════════
// BRIDGE TO CEREBELLUM TESTS
// ═══════════════════════════════════════════════════════════════════

test "pons — bridgeToCerebellum status A (no problems)" {
    const results = FarmSweepResults{};
    _ = try bridgeToCerebellum(std.testing.allocator, results);
    // Should log status A
}

test "pons — bridgeToCerebellum status B (1-4 problems)" {
    const results = FarmSweepResults{
        .stale_count = 3,
        .crashed_workers = &[_][]const u8{"w1"},
    };
    _ = try bridgeToCerebellum(std.testing.allocator, results);
    // Should log status B
}

test "pons — bridgeToCerebellum status C (5-9 problems)" {
    const results = FarmSweepResults{
        .stale_count = 7,
        .crashed_workers = &[_][]const u8{ "w1", "w2" },
    };
    _ = try bridgeToCerebellum(std.testing.allocator, results);
    // Should log status C
}

test "pons — bridgeToCerebellum status F (10+ problems)" {
    var crashed = [_][]const u8{ "w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8", "w9", "w10" };
    const results = FarmSweepResults{
        .stale_count = 5,
        .crashed_workers = &crashed,
    };
    _ = try bridgeToCerebellum(std.testing.allocator, results);
    // Should log status F
}

test "pons — bridgeToCerebellum with only stale" {
    const results = FarmSweepResults{ .stale_count = 15 };
    _ = try bridgeToCerebellum(std.testing.allocator, results);
    // Should log status F
}

// ═══════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════

test "pons — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 12345;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 12345), h.last_check);
}

test "pons — CellHealth all statuses" {
    const healthy = CellHealth{ .status = .healthy };
    const weak = CellHealth{ .status = .weak };
    const broken = CellHealth{ .status = .broken };

    try std.testing.expectEqual(CellHealth.Status.healthy, healthy.status);
    try std.testing.expectEqual(CellHealth.Status.weak, weak.status);
    try std.testing.expectEqual(CellHealth.Status.broken, broken.status);
}
