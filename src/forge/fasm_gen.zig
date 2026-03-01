// =============================================================================
// FORGE OF KOSCHEI v2.0 — FASM Generator
// =============================================================================
//
// Generates FASM (FPGA Assembly) features from a placed and routed design.
//
// FASM feature categories:
//   - CLB: LUT INIT values, FF configuration, CARRY4, muxes
//   - IOB: IOSTANDARD, input/output enables, pull type
//   - Clock: BUFGCTRL enables, BUFHCE, HCLK_LEAF
//   - Routing: INT tile PIPs (e.g., INT_L_X2Y148.SS6BEG0.LOGIC_OUTS_L12)
//
// Output format matches prjxray FASM:
//   TILE_TYPE_XCOORD_YCOORD.FEATURE[BIT_RANGE] = VALUE
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");

const ForgeDB = types.ForgeDB;
const MappedCell = types.MappedCell;
const CellType = types.CellType;
const Net = types.Net;
const FasmFeature = types.FasmFeature;
const Constraints = types.Constraints;

pub const FasmError = error{
    OutOfMemory,
    UnplacedCell,
};

pub const FasmResult = struct {
    features: std.ArrayList(FasmFeature),
    allocator: Allocator,

    pub fn deinit(self: *FasmResult) void {
        for (self.features.items) |feature| {
            self.allocator.free(feature.line);
        }
        self.features.deinit(self.allocator);
    }

    pub fn lineCount(self: *const FasmResult) usize {
        return self.features.items.len;
    }
};

/// Generate FASM features from a placed and routed design.
pub fn generate(allocator: Allocator, db: *const ForgeDB) !FasmResult {
    var result = FasmResult{
        .features = .{},
        .allocator = allocator,
    };
    errdefer result.deinit();

    // Generate CLB features (LUTs, FFs, CARRY4)
    try generateClbFeatures(allocator, db, &result);

    // Generate IOB features
    try generateIobFeatures(allocator, db, &result);

    // Generate clock features
    try generateClockFeatures(allocator, db, &result);

    // Generate routing PIPs
    try generateRoutingPips(allocator, db, &result);

    return result;
}

// =============================================================================
// CLB Feature Generation
// =============================================================================

fn generateClbFeatures(allocator: Allocator, db: *const ForgeDB, result: *FasmResult) !void {
    for (db.cells.items) |cell| {
        if (cell.cell_type.isLUT()) {
            try generateLutFeature(allocator, cell, result);
        } else if (cell.cell_type.isFF()) {
            try generateFfFeature(allocator, cell, result);
        } else if (cell.cell_type == .CARRY4) {
            try generateCarry4Feature(allocator, cell, result);
        }
    }
}

fn generateLutFeature(allocator: Allocator, cell: MappedCell, result: *FasmResult) !void {
    const x = cell.tile_x orelse return;
    const y = cell.tile_y orelse return;

    // Determine slice (A-D based on bel_index)
    const slice_letter: u8 = if (cell.bel) |bel| switch (bel.bel_index % 4) {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        else => 'A',
    } else 'A';

    // prjxray format: one FASM feature per LUT INIT bit that is set
    // e.g., CLBLL_L_X2Y148.SLICEL_X0.ALUT.INIT[00]
    const lut_size: u8 = switch (cell.cell_type) {
        .LUT1 => 2, // LUT1 uses 2 INIT bits
        .LUT2 => 4,
        .LUT3 => 8,
        .LUT4 => 16,
        .LUT5 => 32,
        .LUT6 => 64,
        else => 64,
    };

    var bit_idx: u7 = 0;
    while (bit_idx < lut_size) : (bit_idx += 1) {
        const shift: u6 = @intCast(bit_idx);
        if ((cell.lut_init >> shift) & 1 == 1) {
            var buf: [256]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "CLBLL_L_X{d}Y{d}.SLICEL_X0.{c}LUT.INIT[{d:0>2}]", .{
                x, y, slice_letter, bit_idx,
            }) catch continue;
            const duped = try allocator.dupe(u8, line);
            try result.features.append(allocator, FasmFeature{ .line = duped });
        }
    }
}

fn generateFfFeature(allocator: Allocator, cell: MappedCell, result: *FasmResult) !void {
    const x = cell.tile_x orelse return;
    const y = cell.tile_y orelse return;

    const slice_letter: u8 = if (cell.bel) |bel| switch (bel.bel_index % 4) {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        else => 'A',
    } else 'A';

    var buf: [256]u8 = undefined;

    // FF INIT
    const init_line = std.fmt.bufPrint(&buf, "CLBLL_L_X{d}Y{d}.SLICEL_X0.{c}FF.ZINI", .{ x, y, slice_letter }) catch return;
    const init_duped = try allocator.dupe(u8, init_line);
    try result.features.append(allocator, FasmFeature{ .line = init_duped });

    // FF type-specific features
    if (cell.cell_type == .FDRE or cell.cell_type == .FDSE) {
        const sync_line = std.fmt.bufPrint(&buf, "CLBLL_L_X{d}Y{d}.SLICEL_X0.FFSYNC", .{ x, y }) catch return;
        const sync_duped = try allocator.dupe(u8, sync_line);
        try result.features.append(allocator, FasmFeature{ .line = sync_duped });
    }
}

fn generateCarry4Feature(allocator: Allocator, cell: MappedCell, result: *FasmResult) !void {
    const x = cell.tile_x orelse return;
    const y = cell.tile_y orelse return;

    var buf: [256]u8 = undefined;

    // prjxray CARRY4 sub-features: ACY0, BCY0, CCY0, DCY0
    const prefixes = [_]u8{ 'A', 'B', 'C', 'D' };
    for (prefixes) |prefix| {
        const line = std.fmt.bufPrint(&buf, "CLBLL_L_X{d}Y{d}.SLICEL_X0.CARRY4.{c}CY0", .{ x, y, prefix }) catch continue;
        const duped = try allocator.dupe(u8, line);
        try result.features.append(allocator, FasmFeature{ .line = duped });
    }

    // CYINIT configuration — prjxray uses C0 (GND) or C1 (VCC), not GND/VCC
    if (cell.carry_cyinit_const) |cyinit| {
        const cyinit_line = std.fmt.bufPrint(&buf, "CLBLL_L_X{d}Y{d}.SLICEL_X0.PRECYINIT.{s}", .{
            x, y, if (cyinit == 0) "C0" else "C1",
        }) catch return;
        const cyinit_duped = try allocator.dupe(u8, cyinit_line);
        try result.features.append(allocator, FasmFeature{ .line = cyinit_duped });
    }
}

// =============================================================================
// IOB Feature Generation
// =============================================================================

fn generateIobFeatures(allocator: Allocator, db: *const ForgeDB, result: *FasmResult) !void {
    for (db.cells.items) |cell| {
        if (!cell.cell_type.isIO()) continue;

        const x = cell.tile_x orelse continue;
        const y = cell.tile_y orelse continue;

        var buf: [512]u8 = undefined;

        if (cell.cell_type == .IBUF) {
            // Input buffer — prjxray features for LVCMOS33 input:
            // 1. LVCMOS25_LVCMOS33_LVTTL.IN (input enable for LVCMOS33 group)
            const in_line = std.fmt.bufPrint(&buf, "LIOB33_X{d}Y{d}.IOB_Y0.LVCMOS25_LVCMOS33_LVTTL.IN", .{ x, y }) catch continue;
            const in_duped = try allocator.dupe(u8, in_line);
            try result.features.append(allocator, FasmFeature{ .line = in_duped });

            // 2. IN_ONLY (shared across many standards)
            const inonly_line = std.fmt.bufPrint(&buf, "LIOB33_X{d}Y{d}.IOB_Y0.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVDS_25_LVTTL_SSTL135_SSTL15_TMDS_33.IN_ONLY", .{ x, y }) catch continue;
            const inonly_duped = try allocator.dupe(u8, inonly_line);
            try result.features.append(allocator, FasmFeature{ .line = inonly_duped });

            // 3. PULLTYPE.NONE
            const pull_line = std.fmt.bufPrint(&buf, "LIOB33_X{d}Y{d}.IOB_Y0.PULLTYPE.NONE", .{ x, y }) catch continue;
            const pull_duped = try allocator.dupe(u8, pull_line);
            try result.features.append(allocator, FasmFeature{ .line = pull_duped });
        } else {
            // Output buffer — prjxray features for LVCMOS33 output:
            // 1. LVCMOS33_LVTTL.DRIVE.I12_I8 (default 12mA drive)
            const drv_line = std.fmt.bufPrint(&buf, "LIOB33_X{d}Y{d}.IOB_Y0.LVCMOS33_LVTTL.DRIVE.I12_I8", .{ x, y }) catch continue;
            const drv_duped = try allocator.dupe(u8, drv_line);
            try result.features.append(allocator, FasmFeature{ .line = drv_duped });

            // 2. SLEW.SLOW (default slow slew)
            const slew_line = std.fmt.bufPrint(&buf, "LIOB33_X{d}Y{d}.IOB_Y0.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL_SSTL135_SSTL15.SLEW.SLOW", .{ x, y }) catch continue;
            const slew_duped = try allocator.dupe(u8, slew_line);
            try result.features.append(allocator, FasmFeature{ .line = slew_duped });

            // 3. PULLTYPE.NONE
            const pull_line = std.fmt.bufPrint(&buf, "LIOB33_X{d}Y{d}.IOB_Y0.PULLTYPE.NONE", .{ x, y }) catch continue;
            const pull_duped = try allocator.dupe(u8, pull_line);
            try result.features.append(allocator, FasmFeature{ .line = pull_duped });
        }
    }
}

// IOB features are now emitted directly in generateIobFeatures using
// prjxray compound feature names (e.g., LVCMOS25_LVCMOS33_LVTTL.IN)

// =============================================================================
// Clock Feature Generation
// =============================================================================

fn generateClockFeatures(allocator: Allocator, db: *const ForgeDB, result: *FasmResult) !void {
    for (db.cells.items) |cell| {
        if (!cell.cell_type.isClock()) continue;

        const x = cell.tile_x orelse continue;
        const y = cell.tile_y orelse continue;

        // BUFG Y coordinate maps to BUFGCTRL instance: BUFGCTRL_X0Y{bel_index}
        const bufg_idx: u16 = if (cell.bel) |bel| @intCast(bel.bel_index) else 0;

        var buf: [256]u8 = undefined;

        // prjxray format: CLK_BUFG_BOT_R_X{x}Y{y}.BUFGCTRL.BUFGCTRL_X0Y{idx}.IN_USE
        const in_use_line = std.fmt.bufPrint(&buf, "CLK_BUFG_BOT_R_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.IN_USE", .{ x, y, bufg_idx }) catch continue;
        const in_use_duped = try allocator.dupe(u8, in_use_line);
        try result.features.append(allocator, FasmFeature{ .line = in_use_duped });

        // ZPRESELECT_I0 (select input 0)
        const zpre_line = std.fmt.bufPrint(&buf, "CLK_BUFG_BOT_R_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.ZPRESELECT_I0", .{ x, y, bufg_idx }) catch continue;
        const zpre_duped = try allocator.dupe(u8, zpre_line);
        try result.features.append(allocator, FasmFeature{ .line = zpre_duped });

        // ZINV_CE0 (clock enable not inverted)
        const zce_line = std.fmt.bufPrint(&buf, "CLK_BUFG_BOT_R_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.ZINV_CE0", .{ x, y, bufg_idx }) catch continue;
        const zce_duped = try allocator.dupe(u8, zce_line);
        try result.features.append(allocator, FasmFeature{ .line = zce_duped });

        // ZINV_S0 (select not inverted)
        const zs_line = std.fmt.bufPrint(&buf, "CLK_BUFG_BOT_R_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.ZINV_S0", .{ x, y, bufg_idx }) catch continue;
        const zs_duped = try allocator.dupe(u8, zs_line);
        try result.features.append(allocator, FasmFeature{ .line = zs_duped });
    }
}

// =============================================================================
// Routing PIP Generation
// =============================================================================

fn generateRoutingPips(allocator: Allocator, db: *const ForgeDB, result: *FasmResult) !void {
    for (db.nets.items) |net| {
        for (net.route_pips.items) |pip| {
            var buf: [256]u8 = undefined;

            const line = std.fmt.bufPrint(&buf, "{s}.{s}.{s}", .{
                pip.tile_name, pip.wire_from, pip.wire_to,
            }) catch continue;
            const duped = try allocator.dupe(u8, line);
            try result.features.append(allocator, FasmFeature{ .line = duped });
        }
    }
}

// =============================================================================
// FASM Output
// =============================================================================

/// Write FASM features to a file.
pub fn writeFasm(result: *const FasmResult, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    for (result.features.items) |feature| {
        try file.writeAll(feature.line);
        try file.writeAll("\n");
    }
}

// =============================================================================
// Tests
// =============================================================================

test "generate LUT FASM" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .LUT1,
        .name = "lut0",
        .tile_x = 2,
        .tile_y = 148,
        .lut_init = 0b01,
        .bel = types.BelId{ .tile_x = 2, .tile_y = 148, .bel_index = 0 },
    });

    var result = try generate(allocator, &db);
    defer result.deinit();

    try std.testing.expect(result.lineCount() > 0);
    // Should contain LUT INIT feature
    var found_lut = false;
    for (result.features.items) |f| {
        if (std.mem.indexOf(u8, f.line, "ALUT.INIT") != null) {
            found_lut = true;
            break;
        }
    }
    try std.testing.expect(found_lut);
}

test "generate FF FASM" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .FDRE,
        .name = "ff0",
        .tile_x = 10,
        .tile_y = 50,
        .bel = types.BelId{ .tile_x = 10, .tile_y = 50, .bel_index = 0 },
    });

    var result = try generate(allocator, &db);
    defer result.deinit();

    // Should contain ZINI and FFSYNC features
    var found_zini = false;
    var found_sync = false;
    for (result.features.items) |f| {
        if (std.mem.indexOf(u8, f.line, "ZINI") != null) found_zini = true;
        if (std.mem.indexOf(u8, f.line, "FFSYNC") != null) found_sync = true;
    }
    try std.testing.expect(found_zini);
    try std.testing.expect(found_sync);
}

test "generate IOB FASM" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .IBUF,
        .name = "ibuf_clk",
        .tile_x = 0,
        .tile_y = 148,
        .bel = types.BelId{ .tile_x = 0, .tile_y = 148, .bel_index = 0 },
    });

    var result = try generate(allocator, &db);
    defer result.deinit();

    // prjxray IOB input: LVCMOS25_LVCMOS33_LVTTL.IN + IN_ONLY + PULLTYPE.NONE
    var found_in = false;
    var found_inonly = false;
    var found_pull = false;
    for (result.features.items) |f| {
        if (std.mem.indexOf(u8, f.line, "LVCMOS25_LVCMOS33_LVTTL.IN") != null) found_in = true;
        if (std.mem.indexOf(u8, f.line, ".IN_ONLY") != null) found_inonly = true;
        if (std.mem.indexOf(u8, f.line, "PULLTYPE.NONE") != null) found_pull = true;
    }
    try std.testing.expect(found_in);
    try std.testing.expect(found_inonly);
    try std.testing.expect(found_pull);
}

test "generate clock FASM" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .BUFG,
        .name = "bufg0",
        .tile_x = 32,
        .tile_y = 0,
        .bel = types.BelId{ .tile_x = 32, .tile_y = 0, .bel_index = 0 },
    });

    var result = try generate(allocator, &db);
    defer result.deinit();

    // prjxray BUFG: BUFGCTRL.BUFGCTRL_X0Y0.IN_USE + ZPRESELECT_I0 + ZINV_CE0 + ZINV_S0
    var found_in_use = false;
    var found_zpre = false;
    var found_zce = false;
    var found_zs = false;
    for (result.features.items) |f| {
        if (std.mem.indexOf(u8, f.line, "BUFGCTRL_X0Y0.IN_USE") != null) found_in_use = true;
        if (std.mem.indexOf(u8, f.line, "ZPRESELECT_I0") != null) found_zpre = true;
        if (std.mem.indexOf(u8, f.line, "ZINV_CE0") != null) found_zce = true;
        if (std.mem.indexOf(u8, f.line, "ZINV_S0") != null) found_zs = true;
    }
    try std.testing.expect(found_in_use);
    try std.testing.expect(found_zpre);
    try std.testing.expect(found_zce);
    try std.testing.expect(found_zs);
}

test "generate routing PIPs" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    var net0 = Net{ .id = 0, .name = "test_net" };
    try net0.route_pips.append(allocator, types.RoutingPip{
        .tile_name = "INT_L_X2Y148",
        .wire_from = "SS6BEG0",
        .wire_to = "LOGIC_OUTS_L12",
    });
    try db.nets.append(allocator, net0);

    var result = try generate(allocator, &db);
    defer result.deinit();

    var found_pip = false;
    for (result.features.items) |f| {
        if (std.mem.indexOf(u8, f.line, "INT_L_X2Y148") != null) found_pip = true;
    }
    try std.testing.expect(found_pip);
}

test "FASM feature count for mixed design" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0, .cell_type = .LUT1, .name = "lut",
        .tile_x = 10, .tile_y = 10, .lut_init = 1,
        .bel = types.BelId{ .tile_x = 10, .tile_y = 10, .bel_index = 0 },
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1, .cell_type = .FDRE, .name = "ff",
        .tile_x = 10, .tile_y = 10,
        .bel = types.BelId{ .tile_x = 10, .tile_y = 10, .bel_index = 4 },
    });
    try db.cells.append(allocator, MappedCell{
        .id = 2, .cell_type = .IBUF, .name = "ib",
        .tile_x = 0, .tile_y = 148,
        .bel = types.BelId{ .tile_x = 0, .tile_y = 148, .bel_index = 0 },
    });

    var result = try generate(allocator, &db);
    defer result.deinit();

    // LUT1(init=1): 1 per-bit feature, FF: 2 (ZINI+FFSYNC), IOB IBUF: 3 (IN+IN_ONLY+PULLTYPE)
    try std.testing.expectEqual(@as(usize, 6), result.lineCount());
}
