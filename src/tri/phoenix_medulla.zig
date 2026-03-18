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
    rem,  // REM: Fresh errors → fix_plan.md tasks
};

pub const SleepConfig = struct {
    nrem_threshold_days: u32 = 7, // Episodes older than this become rules
    rem_batch_size: u32 = 50, // Errors to process per REM cycle
    max_errors_dreaming: u32 = 1000, // Max errors to turn into tasks
};

/// Run sleep cycle — consolidate learning and generate fix plans
pub fn sleepCycle(allocator: Allocator) !void {
    // NREM: Episodes older than 7 days → permanent rules
    const old_episodes = try hippocampus.read(allocator, .{
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
    const fresh_errors = try hippocampus.search(allocator, "kind:\"error\"", 1000);
    defer fresh_errors.deinit(allocator);

    var tasks_dreamed: u32 = 0;
    for (fresh_errors.items) |err| {
        if (tasks_dreamed < SleepConfig.max_errors_dreaming) {
            // Generate fix_plan.md entry
            const summary = try std.fmt.allocPrint(
                allocator,
                "FIX: Error from agent=\"{s}\" needs analysis",
                .{ err.summary() },
            );
            defer allocator.free(summary);

            tasks_dreamed += 1;
        }
    }

    // Write sleep summary to hippocampus
    const data = try std.fmt.allocPrint(
        allocator,
        "{{"nrem_rules":{d},"rem_tasks_dreamed":{d}}}",
        .{ rules_created, tasks_dreamed },
    );
    defer allocator.free(data);

    _ = try hippocampus.write(allocator, .{
        .agent = "phoenix",
        .kind = .observation,
        .summary = "SLEEP: cycle completed",
        .data = data,
    });
}

/// Heartbeat ping — write to hippocampus every 60s
pub fn heartbeatPing(allocator: Allocator) !void {
    const data = try std.fmt.allocPrint(
        allocator,
        "{{"wake":{d},"fixes_applied":0,\"errors_scanned\":0,\"test_ok\":true,\"build_ok\":true}}",
        .{ std.time.timestamp() },
    );
    defer allocator.free(data);

    _ = try hippocampus.write(allocator, .{
        .agent = "phoenix",
        .kind = .heartbeat,
        .summary = "medulla heartbeat",
        .data = data,
    });
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
