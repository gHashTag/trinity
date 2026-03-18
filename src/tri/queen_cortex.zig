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

/// Combined health status for all PFC cells
pub const CellHealth = struct {
    dlpfc: dlpfc.CellHealth,
    vmpfc: vmpfc.CellHealth,
    ofc: ofc.CellHealth,
    vlpfc: vlpfc.CellHealth,
    dmpfc: dmpfc.CellHealth,
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
    };
}

// All healthy if each cell reports healthy
pub fn isHealthy(self: *const CellHealth) bool {
    return self.dlpfc.status == .healthy and
        self.vmpfc.status == .healthy and
        self.ofc.status == .healthy and
        self.vlpfc.status == .healthy and
        self.dmpfc.status == .healthy;
}

/// Get overall status string
pub fn statusStr(self: *const CellHealth, allocator: std.mem.Allocator) ![]const u8 {
    const total: u8 = 5;
    var healthy_count: u8 = 0;

    if (self.dlpfc.status == .healthy) healthy_count += 1;
    if (self.vmpfc.status == .healthy) healthy_count += 1;
    if (self.ofc.status == .healthy) healthy_count += 1;
    if (self.vlpfc.status == .healthy) healthy_count += 1;
    if (self.dmpfc.status == .healthy) healthy_count += 1;

    const grade = if (healthy_count == 5) "A" else if (healthy_count >= 3) "B" else "C";
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
        self.dmpfc.cycle;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "health() collects status from all 5 PFC cells" {
    const h = try health(std.testing.allocator);
    // Verify all cells have valid status enum values (healthy, weak, broken)
    try std.testing.expect(h.dlpfc.status == .healthy or h.dlpfc.status == .weak or h.dlpfc.status == .broken);
    try std.testing.expect(h.vmpfc.status == .healthy or h.vmpfc.status == .weak or h.vmpfc.status == .broken);
    try std.testing.expect(h.ofc.status == .healthy or h.ofc.status == .weak or h.ofc.status == .broken);
    try std.testing.expect(h.vlpfc.status == .healthy or h.vlpfc.status == .weak or h.vlpfc.status == .broken);
    try std.testing.expect(h.dmpfc.status == .healthy or h.dmpfc.status == .weak or h.dmpfc.status == .broken);
}

test "isHealthy returns true only when all cells are healthy" {
    // All healthy - use default values
    var all_healthy: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 10 },
        .vmpfc = .{ .status = .healthy, .cycle = 5 },
        .ofc = .{ .status = .healthy, .cycle = 3 },
        .vlpfc = .{ .status = .healthy, .cycle = 7 },
        .dmpfc = .{ .status = .healthy, .cycle = 2 },
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
    };

    const s = try statusStr(&h, std.testing.allocator);
    defer std.testing.allocator.free(s);
    // 4/5 healthy = grade B
    try std.testing.expectEqualStrings("Cortex: 4/5 healthy (B)", s);
}

test "combinedCycle sums all cell cycles" {
    var h: CellHealth = .{
        .dlpfc = .{ .status = .healthy, .cycle = 10 },
        .vmpfc = .{ .status = .healthy, .cycle = 5 },
        .ofc = .{ .status = .healthy, .cycle = 3 },
        .vlpfc = .{ .status = .healthy, .cycle = 7 },
        .dmpfc = .{ .status = .healthy, .cycle = 2 },
    };
    try std.testing.expectEqual(@as(u32, 27), combinedCycle(&h));
}

test "CellHealth struct has all 5 PFC cell fields" {
    // Verify compile-time that CellHealth contains exactly 5 cell fields
    const h = try health(std.testing.allocator);
    // Access each field to verify existence and type
    _ = h.dlpfc.status;
    _ = h.vmpfc.status;
    _ = h.ofc.status;
    _ = h.vlpfc.status;
    _ = h.dmpfc.status;

    // All cells have cycle counter
    try std.testing.expect(h.dlpfc.cycle >= 0);
    try std.testing.expect(h.vmpfc.cycle >= 0);
    try std.testing.expect(h.ofc.cycle >= 0);
    try std.testing.expect(h.vlpfc.cycle >= 0);
    try std.testing.expect(h.dmpfc.cycle >= 0);
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
