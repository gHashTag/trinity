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
