// ═══════════════════════════════════════════════════════════════════════
// QUEEN CORTEX FACADE — All Prefrontal Cortex cells
// ═══════════════════════════════════════════════════════════════════════════════════════
// Re-exports all 5 PFC cells to avoid circular imports
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

pub const dlpfc = @import("queen_dlpfc.zig");
pub const vmpfc = @import("queen_vmpfc.zig");
pub const ofc = @import("queen_ofc.zig");
pub const vlpfc = @import("queen_vlpfc.zig");
pub const dmpfc = @import("queen_dmpfc.zig");

// Re-export all health functions
pub fn health() struct {
    dlpfc: dlpfc.health(),
    vmpfc: vmpfc.health(),
    ofc: ofc.health(),
    vlpfc: vlpfc.health(),
    dmpfc: dmpfc.health(),
};

const CellHealth = struct {
    dlpfc: dlpfc.CellHealth,
    vmpfc: vmpfc.CellHealth,
    ofc: ofc.CellHealth,
    vlpfc: vlpfc.CellHealth,
    dmpfc: dmpfc.CellHealth,
};

// All healthy if each cell reports healthy
pub fn isHealthy(self: *const CellHealth) bool {
    return self.dlpfc.status == .healthy and
           self.vmpfc.status == .healthy and
           self.ofc.status == .healthy and
           self.vlpfc.status == .healthy and
           self.dmpfc.status == .healthy;
}

// Get overall status string
pub fn statusStr(self: *const CellHealth) []const u8 {
    const total: u8 = 5;
    var healthy_count: u8 = 0;

    if (self.dlpfc.status == .healthy) healthy_count += 1;
    if (self.vmpfc.status == .healthy) healthy_count += 1;
    if (self.ofc.status == .healthy) healthy_count += 1;
    if (self.vlpfc.status == .healthy) healthy_count += 1;
    if (self.dmpfc.status == .healthy) healthy_count += 1;

    const grade = if (healthy_count == 5) "A" else if (healthy_count >= 3) "B" else "C";
    return std.fmt.allocPrint(
        std.heap.page_allocator,
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
