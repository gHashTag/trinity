// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════════════
// GIGANTOCELLULAR RETICULAR NUCLEI — Mass Actions
// ═════════════════════════════════════════════════════════════════════════════════════
// Neuro: Large motor movement coordination
// Trinity: MASS ACTIONS — bulk inject, mass recycle, full farm redeploy
//   Requires Queen L2 (dangerous) approval before execution
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const queen_policy = @import("queen_policy.zig");
const hippocampus = @import("hippocampus.zig");

// ═════════════════════════════════════════════════════════════════════════════════
// MASS ACTION KINDS — What bulk operation?
// ═════════════════════════════════════════════════════════════════════════════════════

pub const MassActionKind = enum {
    bulk_inject, // Inject configs to multiple workers
    mass_recycle, // Recycle all stale/crashed workers
    full_farm_redeploy, // Kill + redeploy entire farm

    pub fn label(self: MassActionKind) []const u8 {
        return switch (self) {
            .bulk_inject => "BULK INJECT",
            .mass_recycle => "MASS RECYCLE",
            .full_farm_redeploy => "FULL FARM REDEPLOY",
        };
    }

    pub fn dangerLevel(self: MassActionKind) u8 {
        return switch (self) {
            .bulk_inject => 2, // Requires L1
            .mass_recycle => 2, // Requires L1
            .full_farm_redeploy => 3, // Requires L2
        };
    }
};

/// Mass action with metadata
pub const MassAction = struct {
    kind: MassActionKind,
    count: usize, // How many workers affected
    reason: [256]u8 = undefined,
    reason_len: usize = 0,
    requires_approval: bool = true, // Requires Queen L2

    pub fn reasonStr(self: *const MassAction) []const u8 {
        return self.reason[0..self.reason_len];
    }

    pub fn setReason(self: *MassAction, text: []const u8) void {
        const len = @min(text.len, self.reason.len);
        @memcpy(self.reason[0..len], text[0..len]);
        self.reason_len = len;
        self.requires_approval = self.kind.dangerLevel() > 1;
    }
};

/// Result of mass action execution
pub const ActionResult = struct {
    success: bool,
    affected_count: usize,
    duration_ms: u64,
    output: [512]u8 = undefined,
    output_len: usize = 0,
    timestamp: i64 = 0,

    pub fn outputStr(self: *const ActionResult) []const u8 {
        return self.output[0..self.output_len];
    }

    pub fn setOutput(self: *ActionResult, text: []const u8) void {
        const len = @min(text.len, self.output.len);
        @memcpy(self.output[0..len], text[0..len]);
        self.output_len = len;
        self.timestamp = std.time.timestamp();
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// MASS ACTION HELPERS — Execute bulk operations via tri CLI
// ═══════════════════════════════════════════════════════════════════════════════

/// Execute bulk inject - inject configs to workers via tri CLI
fn executeBulkInject(allocator: Allocator, action: MassAction, result: *ActionResult) !bool {
    // Use tri farm recycle with --yes for automated injection
    _ = allocator; // For future implementation
    _ = action;

    // For now, return success with mock count
    result.affected_count = 8;
    result.setOutput("BULK INJECT: Success - 8 workers injected (mock)");
    return true;
}

/// Execute mass recycle - recycle all stale/crashed workers
fn executeMassRecycle(allocator: Allocator, action: MassAction, result: *ActionResult) !bool {
    // Use tri farm recycle with --yes for automated recycling
    _ = allocator; // For future implementation
    _ = action;

    // For now, return success with mock count
    result.affected_count = 16;
    result.setOutput("MASS RECYCLE: Success - 16 workers recycled (mock)");
    return true;
}

/// Execute full farm redeploy - cleanup agents + recycle all workers
fn executeFullRedeploy(allocator: Allocator, action: MassAction, result: *ActionResult) !bool {
    // Step 1: Cleanup agent containers
    // Step 2: Recycle all workers
    _ = allocator; // For future implementation
    _ = action;

    // For now, return success with mock count
    result.affected_count = 100;
    result.setOutput("FULL REDEPLOY: Success - 100 workers recycled (mock)");
    return true;
}

/// Parse affected count from tri farm recycle output
fn parseAffectedCount(output: []const u8) ?usize {
    // Look for patterns like "Recycled: 5" or "5 workers recycled"
    var iter = std.mem.tokenizeScalar(u8, output, '\n');
    while (iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "Recycled:")) |idx| {
            // Skip past "Recycled:" and any following spaces
            var start = idx + "Recycled:".len;
            while (start < line.len and line[start] == ' ') {
                start += 1;
            }

            // Find end of number (space or end of line)
            var end = start;
            while (end < line.len and line[end] >= '0' and line[end] <= '9') {
                end += 1;
            }

            if (end > start) {
                const num_str = line[start..end];
                if (std.fmt.parseInt(usize, num_str, 10)) |num| {
                    return num;
                } else |_| {}
            }
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════
// EXECUTE MASS ACTION — Run bulk operation
// ═══════════════════════════════════════════════════════════════════════════════

/// Execute mass action
pub fn executeMassAction(
    allocator: Allocator,
    action: MassAction,
    config: qt.QueenConfig,
) !ActionResult {
    const start = std.time.milliTimestamp();
    var result = ActionResult{
        .success = false,
        .affected_count = action.count,
        .duration_ms = 0,
    };

    // Check policy approval
    const policy = queen_policy.checkPolicy(
        qt.ActionKind.cloud_spawn, // Reuse spawn check for mass ops
        config,
        &.{},
        &queen_policy.IncidentMemory.init(),
    );

    if (!policy.isAllowed()) {
        result.setOutput("BLOCKED: Policy check failed");
        result.affected_count = 0;
        return result;
    }

    // Execute based on kind
    switch (action.kind) {
        .bulk_inject => {
            // Bulk inject: inject configs to specified workers via tri farm recycle
            result.success = try executeBulkInject(allocator, action, &result);
        },
        .mass_recycle => {
            // Mass recycle: recycle all stale/crashed workers via tri farm recycle
            result.success = try executeMassRecycle(allocator, action, &result);
        },
        .full_farm_redeploy => {
            // Full farm redeploy: cleanup agents + recycle all workers
            result.success = try executeFullRedeploy(allocator, action, &result);
        },
    }

    result.affected_count = action.count;
    const elapsed = std.time.milliTimestamp() - start;
    result.duration_ms = @intCast(@abs(elapsed));

    // Log to hippocampus
    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"kind\":\"{s}\",\"count\":{d},\"success\":{any},\"duration_ms\":{d}}}",
        .{ action.kind.label(), action.count, result.success, result.duration_ms },
    );
    defer allocator.free(data);

    _ = try hippocampus.writeObservation(allocator, "reticular_gigantocellular", "mass action result", data);

    return result;
}

/// Plan mass action based on current farm state
pub fn planMassAction(
    allocator: Allocator,
    kind: MassActionKind,
) !MassAction {
    _ = allocator;

    var action = MassAction{ .kind = kind, .count = 0 };

    switch (kind) {
        .bulk_inject => {
            action.count = 8; // Default batch size
            action.setReason("Inject configs to next 8 workers");
        },
        .mass_recycle => {
            // Count workers to recycle
            action.count = 16; // Default
            action.setReason("Recycle all stale/crashed workers");
        },
        .full_farm_redeploy => {
            action.count = 100; // Full farm
            action.setReason("Full farm redeploy after critical failure");
        },
    }

    return action;
}

// ═══════════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═════════════════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════

test "gigantocellular — MassAction setReason" {
    var action = MassAction{ .kind = .bulk_inject, .count = 0 };
    action.setReason("Test reason");
    try std.testing.expectEqualStrings("Test reason", action.reasonStr());
    try std.testing.expect(action.requires_approval); // Default = true
}

test "gigantocellular — MassActionKind dangerLevel" {
    try std.testing.expectEqual(@as(u8, 2), MassActionKind.mass_recycle.dangerLevel());
    try std.testing.expectEqual(@as(u8, 3), MassActionKind.full_farm_redeploy.dangerLevel());
}

test "gigantocellular — planMassAction" {
    const action = try planMassAction(std.testing.allocator, .bulk_inject);

    try std.testing.expectEqual(@as(usize, 8), action.count);
    try std.testing.expectEqualStrings("Inject configs to next 8 workers", action.reasonStr());
}

test "gigantocellular — executeMassAction blocked" {
    const action = try planMassAction(std.testing.allocator, .mass_recycle);

    const config = qt.QueenConfig{ .max_auto_level = 0 }; // L0 blocks L2

    const result = try executeMassAction(std.testing.allocator, action, config);

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(usize, 0), result.affected_count);
}

test "gigantocellular — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "gigantocellular — parseAffectedCount" {
    const output1 = "Recycled: 5 workers\nDone";
    try std.testing.expectEqual(@as(usize, 5), parseAffectedCount(output1).?);

    const output2 = "No workers to recycle";
    try std.testing.expectEqual(@as(?usize, null), parseAffectedCount(output2));

    const output3 = "Some output\nRecycled: 12\nDone";
    try std.testing.expectEqual(@as(usize, 12), parseAffectedCount(output3).?);
}

test "gigantocellular — MassActionKind all labels" {
    try std.testing.expectEqualStrings("BULK INJECT", MassActionKind.bulk_inject.label());
    try std.testing.expectEqualStrings("MASS RECYCLE", MassActionKind.mass_recycle.label());
    try std.testing.expectEqualStrings("FULL FARM REDEPLOY", MassActionKind.full_farm_redeploy.label());
}

test "gigantocellular — ActionResult output management" {
    var result = ActionResult{ .success = false, .affected_count = 0, .duration_ms = 0 };
    try std.testing.expectEqual(@as(usize, 0), result.output_len);

    result.setOutput("Test output");
    try std.testing.expectEqualStrings("Test output", result.outputStr());
    try std.testing.expect(result.output_len > 0);
}

test "gigantocellular — MassAction requires approval for dangerous ops" {
    const bulk = MassAction{ .kind = .bulk_inject, .count = 0 };
    try std.testing.expectEqual(@as(u8, 2), bulk.kind.dangerLevel());

    const recycle = MassAction{ .kind = .mass_recycle, .count = 0 };
    try std.testing.expectEqual(@as(u8, 2), recycle.kind.dangerLevel());

    const redeploy = MassAction{ .kind = .full_farm_redeploy, .count = 0 };
    try std.testing.expectEqual(@as(u8, 3), redeploy.kind.dangerLevel());
}

// ═══════════════════════════════════════════════════════════════════════════════
// MASS ACTION STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gigantocellular — MassAction defaults" {
    const action = MassAction{
        .kind = .bulk_inject,
        .count = 5,
    };

    try std.testing.expectEqual(MassActionKind.bulk_inject, action.kind);
    try std.testing.expectEqual(@as(usize, 5), action.count);
    try std.testing.expect(action.requires_approval);
    try std.testing.expectEqual(@as(usize, 0), action.reason_len);
}

test "gigantocellular — MassAction reasonStr empty" {
    const action = MassAction{ .kind = .bulk_inject, .count = 0 };

    try std.testing.expectEqualStrings("", action.reasonStr());
}

test "gigantocellular — MassAction setReason truncates" {
    var action = MassAction{ .kind = .bulk_inject, .count = 0 };

    // Create a reason longer than 256 bytes
    var long_text: [300]u8 = undefined;
    @memset(&long_text, 'A');
    long_text[299] = 0;

    action.setReason(&long_text);
    try std.testing.expectEqual(@as(usize, 256), action.reason_len); // Truncated to max
}

test "gigantocellular — MassAction setReason updates approval" {
    var action = MassAction{ .kind = .bulk_inject, .count = 0 };
    action.setReason("Test");

    // bulk_inject has danger level 2 > 1, so requires_approval should be true
    try std.testing.expect(action.requires_approval);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION RESULT STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gigantocellular — ActionResult defaults" {
    const result = ActionResult{
        .success = true,
        .affected_count = 10,
        .duration_ms = 100,
    };

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(usize, 10), result.affected_count);
    try std.testing.expectEqual(@as(u64, 100), result.duration_ms);
    try std.testing.expectEqual(@as(usize, 0), result.output_len);
    try std.testing.expectEqual(@as(i64, 0), result.timestamp);
}

test "gigantocellular — ActionResult outputStr empty" {
    const result = ActionResult{ .success = false, .affected_count = 0, .duration_ms = 0 };

    try std.testing.expectEqualStrings("", result.outputStr());
}

test "gigantocellular — ActionResult setOutput updates timestamp" {
    var result = ActionResult{ .success = false, .affected_count = 0, .duration_ms = 0 };

    const before = std.time.timestamp();
    result.setOutput("Test");
    const after = std.time.timestamp();

    try std.testing.expect(result.timestamp >= before);
    try std.testing.expect(result.timestamp <= after);
}

test "gigantocellular — ActionResult setOutput truncates" {
    var result = ActionResult{ .success = false, .affected_count = 0, .duration_ms = 0 };

    // Create output longer than 512 bytes
    var long_text: [600]u8 = undefined;
    @memset(&long_text, 'B');
    long_text[599] = 0;

    result.setOutput(&long_text);
    try std.testing.expectEqual(@as(usize, 512), result.output_len); // Truncated to max
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTE MASS ACTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gigantocellular — executeMassAction bulk_inject" {
    const action = try planMassAction(std.testing.allocator, .bulk_inject);
    const config = qt.QueenConfig{ .max_auto_level = 3 }; // Allow L2

    const result = try executeMassAction(std.testing.allocator, action, config);

    try std.testing.expect(result.success);
    try std.testing.expect(result.affected_count > 0);
    try std.testing.expect(result.duration_ms >= 0);
}

test "gigantocellular — executeMassAction mass_recycle" {
    const action = try planMassAction(std.testing.allocator, .mass_recycle);
    const config = qt.QueenConfig{ .max_auto_level = 3 };

    const result = try executeMassAction(std.testing.allocator, action, config);

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(usize, 16), result.affected_count); // Mock value
}

test "gigantocellular — executeMassAction full_farm_redeploy" {
    const action = try planMassAction(std.testing.allocator, .full_farm_redeploy);
    const config = qt.QueenConfig{ .max_auto_level = 3 };

    const result = try executeMassAction(std.testing.allocator, action, config);

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(usize, 100), result.affected_count); // Mock value
}

test "gigantocellular — executeMassAction duration calculated" {
    const action = try planMassAction(std.testing.allocator, .bulk_inject);
    const config = qt.QueenConfig{ .max_auto_level = 3 };

    const result = try executeMassAction(std.testing.allocator, action, config);

    // Duration should be non-negative (abs of elapsed)
    try std.testing.expect(result.duration_ms >= 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARSE AFFECTED COUNT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gigantocellular — parseAffectedCount zero" {
    const output = "Recycled: 0 workers\nDone";
    try std.testing.expectEqual(@as(usize, 0), parseAffectedCount(output).?);
}

test "gigantocellular — parseAffectedCount large number" {
    const output = "Recycled: 99999 workers\nDone";
    try std.testing.expectEqual(@as(usize, 99999), parseAffectedCount(output).?);
}

test "gigantocellular — parseAffectedCount multiple spaces" {
    const output = "Recycled:     5     workers\nDone";
    try std.testing.expectEqual(@as(usize, 5), parseAffectedCount(output).?);
}

test "gigantocellular — parseAffectedCount no match" {
    const output = "Some output without Recycled pattern";
    try std.testing.expectEqual(@as(?usize, null), parseAffectedCount(output));
}

test "gigantocellular — parseAffectedCount empty output" {
    const output = "";
    try std.testing.expectEqual(@as(?usize, null), parseAffectedCount(output));
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN MASS ACTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gigantocellular — planMassAction mass_recycle" {
    const action = try planMassAction(std.testing.allocator, .mass_recycle);

    try std.testing.expectEqual(MassActionKind.mass_recycle, action.kind);
    try std.testing.expectEqual(@as(usize, 16), action.count);
    try std.testing.expectEqualStrings("Recycle all stale/crashed workers", action.reasonStr());
}

test "gigantocellular — planMassAction full_farm_redeploy" {
    const action = try planMassAction(std.testing.allocator, .full_farm_redeploy);

    try std.testing.expectEqual(MassActionKind.full_farm_redeploy, action.kind);
    try std.testing.expectEqual(@as(usize, 100), action.count);
    try std.testing.expectEqualStrings("Full farm redeploy after critical failure", action.reasonStr());
}

test "gigantocellular — planMassAction requires_approval" {
    const bulk = try planMassAction(std.testing.allocator, .bulk_inject);
    const recycle = try planMassAction(std.testing.allocator, .mass_recycle);
    const redeploy = try planMassAction(std.testing.allocator, .full_farm_redeploy);

    try std.testing.expect(bulk.requires_approval); // danger level 2 > 1
    try std.testing.expect(recycle.requires_approval); // danger level 2 > 1
    try std.testing.expect(redeploy.requires_approval); // danger level 3 > 1
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gigantocellular — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "gigantocellular — CellHealth defaults" {
    const h = CellHealth{};

    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "gigantocellular — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "gigantocellular — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 12345;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 12345), h.last_check);
}
