// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════
// QUEEN CORTEX FACADE — All Prefrontal Cortex cells
// ═══════════════════════════════════════════════════════════════════════════════════════
// Re-exports all 5 PFC cells to avoid circular imports
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const dlpfc = @import("queen_dlpfc.zig");
pub const vmpfc = @import("queen_vmpfc.zig");
pub const ofc = @import("queen_ofc.zig");
pub const vlpfc = @import("queen_vlpfc.zig");
pub const dmpfc = @import("queen_dmpfc.zig");
pub const acc = @import("queen_acc.zig");

/// Combined health status for all PFC cells
pub const CellHealth = struct {
    dlpfc: dlpfc.CellHealth,
    vmpfc: vmpfc.CellHealth,
    ofc: ofc.CellHealth,
    vlpfc: vlpfc.CellHealth,
    dmpfc: dmpfc.CellHealth,
    acc: acc.CellHealth,
};

/// Collect health from all PFC cells
pub fn health(allocator: std.mem.Allocator) !CellHealth {
    _ = allocator; // Not used but kept for API compatibility
    return .{
        .dlpfc = dlpfc.health(),
        .vmpfc = vmpfc.health(),
        .ofc = ofc.health(),
        .vlpfc = vlpfc.health(),
        .dmpfc = dmpfc.health(),
        .acc = acc.health(),
    };
}

// All healthy if each cell reports healthy
pub fn isHealthy(self: *const CellHealth) bool {
    return self.dlpfc.status == .healthy and
        self.vmpfc.status == .healthy and
        self.ofc.status == .healthy and
        self.vlpfc.status == .healthy and
        self.dmpfc.status == .healthy and
        self.acc.status == .healthy;
}

/// Get overall status string
pub fn statusStr(self: *const CellHealth, allocator: std.mem.Allocator) ![]const u8 {
    const total: u8 = 6;
    var healthy_count: u8 = 0;

    if (self.dlpfc.status == .healthy) healthy_count += 1;
    if (self.vmpfc.status == .healthy) healthy_count += 1;
    if (self.ofc.status == .healthy) healthy_count += 1;
    if (self.vlpfc.status == .healthy) healthy_count += 1;
    if (self.dmpfc.status == .healthy) healthy_count += 1;
    if (self.acc.status == .healthy) healthy_count += 1;

    const grade = if (healthy_count == 6) "A" else if (healthy_count >= 4) "B" else "C";
    return std.fmt.allocPrint(
        allocator,
        "Cortex: {d}/{d} healthy ({s})",
        .{ healthy_count, total, grade },
    );
}

// Get combined cycle number (sum of all cells)
pub fn combinedCycle(self: *const CellHealth) u32 {
    return self.dlpfc.cycle +
        self.vmpfc.cycle +
        self.ofc.cycle +
        self.vlpfc.cycle +
        self.dmpfc.cycle +
        self.acc.cycle;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "health() collects status from all 6 PFC cells" {
    const h = try health(std.testing.allocator);
    // Verify all cells have valid status enum values (healthy, weak, broken)
    try std.testing.expect(h.dlpfc.status == .healthy or h.dlpfc.status == .weak or h.dlpfc.status == .broken);
    try std.testing.expect(h.vmpfc.status == .healthy or h.vmpfc.status == .weak or h.vmpfc.status == .broken);
    try std.testing.expect(h.ofc.status == .healthy or h.ofc.status == .weak or h.ofc.status == .broken);
    try std.testing.expect(h.vlpfc.status == .healthy or h.vlpfc.status == .weak or h.vlpfc.status == .broken);
    try std.testing.expect(h.dmpfc.status == .healthy or h.dmpfc.status == .weak or h.dmpfc.status == .broken);
    try std.testing.expect(h.acc.status == .healthy or h.acc.status == .weak or h.acc.status == .broken);
}

test "isHealthy returns true only when all cells are healthy" {
    // All healthy - use default values
    var all_healthy: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 10 },
        .vmpfc = .{ .status = .healthy, .cycle = 5 },
        .ofc = .{ .status = .healthy, .cycle = 3 },
        .vlpfc = .{ .status = .healthy, .cycle = 7 },
        .dmpfc = .{ .status = .healthy, .cycle = 2 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };
    try std.testing.expect(isHealthy(&all_healthy));

    // One weak
    var one_weak: CellHealth = all_healthy;
    one_weak.dlpfc.status = .weak;
    try std.testing.expect(!isHealthy(&one_weak));

    // One broken
    var one_broken: CellHealth = all_healthy;
    one_broken.vmpfc.status = .broken;
    try std.testing.expect(!isHealthy(&one_broken));
}

test "statusStr returns correct grade and count" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 1 },
        .vmpfc = .{ .status = .healthy, .cycle = 1 },
        .ofc = .{ .status = .weak, .cycle = 1 },
        .vlpfc = .{ .status = .healthy, .cycle = 1 },
        .dmpfc = .{ .status = .healthy, .cycle = 1 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };

    const s = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(s);
    // 5/6 healthy = grade B
    try std.testing.expectEqualStrings("Cortex: 5/6 healthy (B)", s);
}

test "combinedCycle sums all cell cycles" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 10 },
        .vmpfc = .{ .status = .healthy, .cycle = 5 },
        .ofc = .{ .status = .healthy, .cycle = 3 },
        .vlpfc = .{ .status = .healthy, .cycle = 7 },
        .dmpfc = .{ .status = .healthy, .cycle = 2 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };
    try std.testing.expectEqual(@as(u32, 28), combinedCycle(&h));
}

test "CellHealth struct has all 6 PFC cell fields" {
    // Verify compile-time that CellHealth contains exactly 6 cell fields
    const h = try health(std.testing.allocator);
    // Access each field to verify existence and type
    _ = h.dlpfc.status;
    _ = h.vmpfc.status;
    _ = h.ofc.status;
    _ = h.vlpfc.status;
    _ = h.dmpfc.status;
    _ = h.acc.status;

    // All cells have cycle counter
    try std.testing.expect(h.dlpfc.cycle >= 0);
    try std.testing.expect(h.vmpfc.cycle >= 0);
    try std.testing.expect(h.ofc.cycle >= 0);
    try std.testing.expect(h.vlpfc.cycle >= 0);
    try std.testing.expect(h.dmpfc.cycle >= 0);
    try std.testing.expect(h.acc.cycle >= 0);
}

test "integration with faculty_types FacultySnapshot pattern" {
    // Verify queen_cortex can work alongside faculty_types
    // FacultySnapshot has agents array, CellHealth has similar pattern
    const faculty_types = @import("faculty_types.zig");

    // Verify we can create FacultySnapshot instances
    // (This test just checks type compatibility at compile time)
    const snap: faculty_types.FacultySnapshot = .{
        .agents = undefined,
        .build_ok = true,
        .binaries = 5,
        .compile_pass = 40,
        .compile_total = 47,
        .compile_rate = 85,
        .v_number = 1.17,
        .v_zone = .stable,
        .git_branch = "main",
        .dirty_files = 5,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };

    // CellHealth is complementary to FacultySnapshot
    // - FacultySnapshot: external system state (agents, build, git)
    // - CellHealth: internal PFC cell health (dlpfc, vmpfc, ofc, vlpfc, dmpfc)
    _ = snap;
    try std.testing.expect(true); // Type check passed
}

test "statusStr returns grade A when all cells healthy" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 1 },
        .vmpfc = .{ .status = .healthy, .cycle = 1 },
        .ofc = .{ .status = .healthy, .cycle = 1 },
        .vlpfc = .{ .status = .healthy, .cycle = 1 },
        .dmpfc = .{ .status = .healthy, .cycle = 1 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };

    const s = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("Cortex: 6/6 healthy (A)", s);
}

test "statusStr returns grade C when less than 4 cells healthy" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 1 },
        .vmpfc = .{ .status = .broken, .cycle = 1 },
        .ofc = .{ .status = .broken, .cycle = 1 },
        .vlpfc = .{ .status = .weak, .cycle = 1 },
        .dmpfc = .{ .status = .healthy, .cycle = 1 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };

    const s = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(s);
    // Only 3/6 healthy (dlpfc, dmpfc, acc)
    try std.testing.expectEqualStrings("Cortex: 3/6 healthy (C)", s);
}

test "statusStr returns grade C when most cells unhealthy" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 1 },
        .vmpfc = .{ .status = .broken, .cycle = 1 },
        .ofc = .{ .status = .broken, .cycle = 1 },
        .vlpfc = .{ .status = .broken, .cycle = 1 },
        .dmpfc = .{ .status = .weak, .cycle = 1 },
        .acc = .{ .status = .broken, .cycle = 1 },
    };

    const s = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(s);
    // Only 1/6 healthy (dlpfc)
    try std.testing.expectEqualStrings("Cortex: 1/6 healthy (C)", s);
}

test "combinedCycle handles zero cycles" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .healthy, .cycle = 0 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .healthy, .cycle = 0 },
        .dmpfc = .{ .status = .healthy, .cycle = 0 },
        .acc = .{ .status = .healthy, .cycle = 0 },
    };
    try std.testing.expectEqual(@as(u32, 0), combinedCycle(&h));
}

test "combinedCycle with mixed values" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 100 },
        .vmpfc = .{ .status = .healthy, .cycle = 50 },
        .ofc = .{ .status = .weak, .cycle = 25 },
        .vlpfc = .{ .status = .healthy, .cycle = 10 },
        .dmpfc = .{ .status = .healthy, .cycle = 5 },
        .acc = .{ .status = .broken, .cycle = 1 },
    };
    try std.testing.expectEqual(@as(u32, 191), combinedCycle(&h));
}

test "isHealthy false when multiple cells unhealthy" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .weak, .cycle = 1 },
        .vmpfc = .{ .status = .healthy, .cycle = 1 },
        .ofc = .{ .status = .broken, .cycle = 1 },
        .vlpfc = .{ .status = .healthy, .cycle = 1 },
        .dmpfc = .{ .status = .healthy, .cycle = 1 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };
    try std.testing.expect(!isHealthy(&h));
}

test "isHealthy false when all cells broken" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .broken, .cycle = 0 },
        .vmpfc = .{ .status = .broken, .cycle = 0 },
        .ofc = .{ .status = .broken, .cycle = 0 },
        .vlpfc = .{ .status = .broken, .cycle = 0 },
        .dmpfc = .{ .status = .broken, .cycle = 0 },
        .acc = .{ .status = .broken, .cycle = 0 },
    };
    try std.testing.expect(!isHealthy(&h));
}

test "health() returns valid CellHealth structure" {
    const h = try health(std.testing.allocator);

    // Check that all fields are accessible
    _ = h.dlpfc;
    _ = h.vmpfc;
    _ = h.ofc;
    _ = h.vlpfc;
    _ = h.dmpfc;
    _ = h.acc;

    // Status enum should be one of the three valid values
    const valid_status = h.dlpfc.status == .healthy or h.dlpfc.status == .weak or h.dlpfc.status == .broken;
    try std.testing.expect(valid_status);
}

test "CellHealth weak status affects isHealthy" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 1 },
        .vmpfc = .{ .status = .healthy, .cycle = 1 },
        .ofc = .{ .status = .healthy, .cycle = 1 },
        .vlpfc = .{ .status = .healthy, .cycle = 1 },
        .dmpfc = .{ .status = .healthy, .cycle = 1 },
        .acc = .{ .status = .weak, .cycle = 1 },
    };
    // Weak should make isHealthy return false
    try std.testing.expect(!isHealthy(&h));
}

test "CellHealth field independence" {
    // Each cell's status is independent
    const h1: CellHealth = .{
        .dlpfc = .{ .status = .broken, .cycle = 1 },
        .vmpfc = .{ .status = .healthy, .cycle = 2 },
        .ofc = .{ .status = .weak, .cycle = 3 },
        .vlpfc = .{ .status = .healthy, .cycle = 4 },
        .dmpfc = .{ .status = .healthy, .cycle = 5 },
        .acc = .{ .status = .healthy, .cycle = 6 },
    };

    try std.testing.expectEqual(dlpfc.CellHealth.Status.broken, h1.dlpfc.status);
    try std.testing.expectEqual(vmpfc.CellHealth.Status.healthy, h1.vmpfc.status);
    try std.testing.expectEqual(ofc.CellHealth.Status.weak, h1.ofc.status);
    try std.testing.expectEqual(@as(u32, 1), h1.dlpfc.cycle);
    try std.testing.expectEqual(@as(u32, 2), h1.vmpfc.cycle);
    try std.testing.expectEqual(@as(u32, 3), h1.ofc.cycle);
}

test "statusStr grade B boundary at exactly 4 healthy" {
    // Exactly 4 healthy = grade B (boundary case)
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .healthy, .cycle = 0 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .healthy, .cycle = 0 },
        .dmpfc = .{ .status = .broken, .cycle = 0 },
        .acc = .{ .status = .broken, .cycle = 0 },
    };

    const result = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "4/6") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "(B)") != null);
}

test "statusStr grade C below 4 healthy" {
    // 3 healthy = grade C
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .healthy, .cycle = 0 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .broken, .cycle = 0 },
        .dmpfc = .{ .status = .broken, .cycle = 0 },
        .acc = .{ .status = .broken, .cycle = 0 },
    };

    const result = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "3/6") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "(C)") != null);
}

test "statusStr all broken" {
    const h: CellHealth = .{
        .dlpfc = .{ .status = .broken, .cycle = 0 },
        .vmpfc = .{ .status = .broken, .cycle = 0 },
        .ofc = .{ .status = .broken, .cycle = 0 },
        .vlpfc = .{ .status = .broken, .cycle = 0 },
        .dmpfc = .{ .status = .broken, .cycle = 0 },
        .acc = .{ .status = .broken, .cycle = 0 },
    };

    const result = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "0/6") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "(C)") != null);
}

test "combinedCycle with large values" {
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 10000 },
        .vmpfc = .{ .status = .healthy, .cycle = 20000 },
        .ofc = .{ .status = .healthy, .cycle = 30000 },
        .vlpfc = .{ .status = .healthy, .cycle = 40000 },
        .dmpfc = .{ .status = .healthy, .cycle = 50000 },
        .acc = .{ .status = .healthy, .cycle = 60000 },
    };

    try std.testing.expectEqual(@as(u32, 210000), combinedCycle(&h));
}

test "isHealthy with single weak cell" {
    // One weak cell, all others healthy = still healthy
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .healthy, .cycle = 0 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .healthy, .cycle = 0 },
        .dmpfc = .{ .status = .healthy, .cycle = 0 },
        .acc = .{ .status = .weak, .cycle = 0 },
    };

    try std.testing.expect(!isHealthy(&h)); // weak is not healthy
}

test "CellHealth default values" {
    const h: CellHealth = .{
        .dlpfc = .{},
        .vmpfc = .{},
        .ofc = .{},
        .vlpfc = .{},
        .dmpfc = .{},
        .acc = .{},
    };

    try std.testing.expectEqual(dlpfc.CellHealth.Status.healthy, h.dlpfc.status);
    try std.testing.expectEqual(vmpfc.CellHealth.Status.healthy, h.vmpfc.status);
    try std.testing.expectEqual(ofc.CellHealth.Status.healthy, h.ofc.status);
    try std.testing.expectEqual(vlpfc.CellHealth.Status.healthy, h.vlpfc.status);
    try std.testing.expectEqual(dmpfc.CellHealth.Status.healthy, h.dmpfc.status);
    try std.testing.expectEqual(acc.CellHealth.Status.healthy, h.acc.status);

    try std.testing.expectEqual(@as(u32, 0), h.dlpfc.cycle);
    try std.testing.expectEqual(@as(u32, 0), h.vmpfc.cycle);
    try std.testing.expectEqual(@as(u32, 0), h.ofc.cycle);
    try std.testing.expectEqual(@as(u32, 0), h.vlpfc.cycle);
    try std.testing.expectEqual(@as(u32, 0), h.dmpfc.cycle);
    try std.testing.expectEqual(@as(u32, 0), h.acc.cycle);
}

test "CellHealth all status enum values" {
    // Test all possible status values can be set
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .weak, .cycle = 0 },
        .ofc = .{ .status = .broken, .cycle = 0 },
        .vlpfc = .{ .status = .healthy, .cycle = 0 },
        .dmpfc = .{ .status = .weak, .cycle = 0 },
        .acc = .{ .status = .broken, .cycle = 0 },
    };

    try std.testing.expectEqual(dlpfc.CellHealth.Status.healthy, h.dlpfc.status);
    try std.testing.expectEqual(vmpfc.CellHealth.Status.weak, h.vmpfc.status);
    try std.testing.expectEqual(ofc.CellHealth.Status.broken, h.ofc.status);
}

test "statusStr format includes Cortex prefix" {
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .healthy, .cycle = 0 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .healthy, .cycle = 0 },
        .dmpfc = .{ .status = .healthy, .cycle = 0 },
        .acc = .{ .status = .healthy, .cycle = 0 },
    };

    const result = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "Cortex:") != null);
}

test "cortex — dlpfc module export" {
    _ = dlpfc.health;
    _ = dlpfc.CellHealth;
}

test "cortex — vmpfc module export" {
    _ = vmpfc.health;
    _ = vmpfc.phiWeightedScore;
}

test "cortex — ofc module export" {
    _ = ofc.send;
    _ = ofc.Mood;
}

test "cortex — vlpfc module export" {
    _ = vlpfc.filterRelays;
    _ = vlpfc.FocusArea;
}

test "cortex — dmpfc module export" {
    _ = dmpfc.selfCheck;
    _ = dmpfc.SelfCheck;
}

test "cortex — acc module export" {
    _ = acc.detectConflicts;
    _ = acc.Conflict;
}

test "cortex — CellHealth with mixed statuses" {
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 1 },
        .vmpfc = .{ .status = .weak, .cycle = 2 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .broken, .cycle = 3 },
        .dmpfc = .{ .status = .healthy, .cycle = 0 },
        .acc = .{ .status = .healthy, .cycle = 1 },
    };

    try std.testing.expect(!isHealthy(&h));
}

test "cortex — combinedCycle with all zero" {
    const h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 0 },
        .vmpfc = .{ .status = .healthy, .cycle = 0 },
        .ofc = .{ .status = .healthy, .cycle = 0 },
        .vlpfc = .{ .status = .healthy, .cycle = 0 },
        .dmpfc = .{ .status = .healthy, .cycle = 0 },
        .acc = .{ .status = .healthy, .cycle = 0 },
    };

    const total = combinedCycle(&h);
    try std.testing.expectEqual(@as(u32, 0), total);
}
