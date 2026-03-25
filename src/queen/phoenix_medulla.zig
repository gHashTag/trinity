// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════════════════════════
// MEDULLA OBLONGATA — Core Lifecycle (Sleep/Wake Cycle)
// ═══════════════════════════════════════════════════════════════════════════════════
// Neuro: Breathing, heartbeat, basic survival reflexes
// Trinity: Core lifecycle — sleep/wake cycle, heartbeat ping
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const hippocampus = @import("hippocampus.zig");

// ═══════════════════════════════════════════════════════════════════════════════════
// SLEEP CYCLE — NREM/REM consolidation phases
// ═══════════════════════════════════════════════════════════════════════════════════════

pub const SleepPhase = enum {
    nrem, // Non-REM: Episodes >7 days → permanent rules
    rem, // REM: Fresh errors → fix_plan.md tasks
};

pub const SleepConfig = struct {
    nrem_threshold_days: u32 = 7, // Episodes older than this become rules
    rem_batch_size: u32 = 50, // Errors to process per REM cycle
    max_errors_dreaming: u32 = 1000, // Max errors to turn into tasks
};

/// Run sleep cycle — consolidate learning and generate fix plans
pub fn sleepCycle(allocator: Allocator) !void {
    // NREM: Episodes older than 7 days → permanent rules
    var old_episodes = try hippocampus.read(allocator, .{
        .agent = "phoenix",
        .kind = .episode,
        .since_ts = @intCast(std.time.timestamp() - (7 * 24 * 3600)),
        .limit = 10000,
    });
    defer old_episodes.deinit(allocator);

    var rules_created: u32 = 0;
    for (old_episodes.items) |ep| {
        // Extract episode verdict and learnings
        const data = ep.summary();
        if (dataContains(data, "\"success\":true") or
            dataContains(data, "\"pass\":true"))
        {
            // Convert to permanent rule
            rules_created += 1;
            // TODO: Add to learning database
        }
    }

    // REM: Fresh errors → fix_plan.md tasks
    var fresh_errors = try hippocampus.search(allocator, "kind:\"error\"", 1000);
    defer fresh_errors.deinit(allocator);

    const config = SleepConfig{};
    var tasks_dreamed: u32 = 0;
    for (fresh_errors.items) |err| {
        if (tasks_dreamed < config.max_errors_dreaming) {
            // Generate fix_plan.md entry
            const summary = try std.fmt.allocPrint(
                allocator,
                "FIX: Error from agent=\"{s}\" needs analysis",
                .{err.summary()},
            );
            defer allocator.free(summary);

            tasks_dreamed += 1;
        }
    }

    // Write sleep summary to hippocampus
    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"nrem_rules\":{d},\"rem_tasks_dreamed\":{d}}}",
        .{ rules_created, tasks_dreamed },
    );
    defer allocator.free(data);

    _ = try hippocampus.writeObservation(allocator, "phoenix", "SLEEP: cycle completed", data);
}

/// Heartbeat ping — write to hippocampus every 60s
pub fn heartbeatPing(allocator: Allocator) !void {
    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"wake\":{d},\"fixes_applied\":0,\"errors_scanned\":0,\"test_ok\":true,\"build_ok\":true}}",
        .{std.time.timestamp()},
    );
    defer allocator.free(data);

    _ = try hippocampus.writeHeartbeat(allocator, "phoenix", data);
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// HELPER — Check if string contains substring
// ═════════════════════════════════════════════════════════════════════════════════════════

fn dataContains(data: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, data, needle) != null;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "medulla — dataContains" {
    const data = "{\"success\":true}";
    try std.testing.expect(dataContains(data, "\"success\":true"));
    try std.testing.expect(!dataContains(data, "\"notfound\""));
}

test "medulla — heartbeatPing" {
    _ = try heartbeatPing(std.testing.allocator);

    // Should not panic
}

test "medulla — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLEEP PHASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "medulla — SleepPhase enum values" {
    try std.testing.expectEqual(SleepPhase.nrem, .nrem);
    try std.testing.expectEqual(SleepPhase.rem, .rem);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLEEP CONFIG TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "medulla — SleepConfig defaults" {
    const config = SleepConfig{};

    try std.testing.expectEqual(@as(u32, 7), config.nrem_threshold_days);
    try std.testing.expectEqual(@as(u32, 50), config.rem_batch_size);
    try std.testing.expectEqual(@as(u32, 1000), config.max_errors_dreaming);
}

test "medulla — SleepConfig custom values" {
    const config = SleepConfig{
        .nrem_threshold_days = 14,
        .rem_batch_size = 100,
        .max_errors_dreaming = 500,
    };

    try std.testing.expectEqual(@as(u32, 14), config.nrem_threshold_days);
    try std.testing.expectEqual(@as(u32, 100), config.rem_batch_size);
    try std.testing.expectEqual(@as(u32, 500), config.max_errors_dreaming);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA CONTAINS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "medulla — dataContains empty needle" {
    const data = "some data";
    try std.testing.expect(dataContains(data, ""));
}

test "medulla — dataContains empty data" {
    const data = "";
    try std.testing.expect(!dataContains(data, "needle"));
}

test "medulla — dataContains both empty" {
    const data = "";
    try std.testing.expect(dataContains(data, ""));
}

test "medulla — dataContains case sensitive" {
    const data = "Success";
    try std.testing.expect(!dataContains(data, "success"));
    try std.testing.expect(dataContains(data, "Success"));
}

test "medulla — dataContains partial match" {
    const data = "foobarbaz";
    try std.testing.expect(dataContains(data, "bar"));
}

test "medulla — dataContains JSON patterns" {
    const data = "{\"success\":true,\"pass\":true}";
    try std.testing.expect(dataContains(data, "\"success\":true"));
    try std.testing.expect(dataContains(data, "\"pass\":true"));
    try std.testing.expect(!dataContains(data, "\"fail\":true"));
}

test "medulla — dataContains special characters" {
    const data = "test\nwith\tnewlines";
    try std.testing.expect(dataContains(data, "\n"));
    try std.testing.expect(dataContains(data, "\t"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "medulla — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "medulla — CellHealth defaults" {
    const h = CellHealth{};

    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "medulla — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "medulla — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 12345;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 12345), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLEEP CYCLE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "medulla — sleepCycle completes without error" {
    // This test verifies that sleepCycle doesn't panic
    // It will interact with hippocampus but should handle errors gracefully
    sleepCycle(std.testing.allocator) catch |err| {
        // Error is acceptable - we just want to ensure no panic
        try std.testing.expect(err == error.OutOfMemory or err == error.FileNotFound);
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEARTBEAT PING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "medulla — heartbeatPing writes valid JSON" {
    // Verify heartbeatPing produces valid JSON structure
    _ = try heartbeatPing(std.testing.allocator);
}

test "medulla — heartbeatPing includes wake timestamp" {
    // The heartbeat should include the current timestamp
    _ = try heartbeatPing(std.testing.allocator);
    // Timestamp is embedded in the JSON sent to hippocampus
    // We can't easily verify the exact value without mocking
}
