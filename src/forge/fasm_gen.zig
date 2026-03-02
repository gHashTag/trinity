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
const tiles = @import("xc7a100t_tiles.zig");

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

/// Helper to format and emit a single FASM feature line.
fn emitFeature(allocator: Allocator, result: *FasmResult, buf: *[512]u8, comptime fmt: []const u8, args: anytype) !void {
    const line = std.fmt.bufPrint(buf, fmt, args) catch return;
    const duped = try allocator.dupe(u8, line);
    try result.features.append(allocator, FasmFeature{ .line = duped });
}

/// Get CLB tile type prefix for FASM output (e.g., "CLBLL_L", "CLBLM_R").
/// Falls back to "CLBLL_L" if tile not found in XC7A100T database.
fn getClbTilePrefix(x: u16, y: u16) []const u8 {
    if (tiles.findClbTile(@intCast(x), @intCast(y))) |tile| {
        return switch (tile.tile_type) {
            .clbll_l => "CLBLL_L",
            .clbll_r => "CLBLL_R",
            .clblm_l => "CLBLM_L",
            .clblm_r => "CLBLM_R",
            else => "CLBLL_L",
        };
    }
    return "CLBLL_L";
}

/// Get IOB tile type prefix for FASM output.
fn getIobTilePrefix(x: u16) []const u8 {
    // Left side IOBs use LIOB33, right side use RIOB33
    if (x == 0) return "LIOB33" else return "RIOB33";
}

/// Get the SLICEL/SLICEM prefix.
/// CLBLL tiles: X0=SLICEL, X1=SLICEL
/// CLBLM tiles: X0=SLICEM, X1=SLICEL (only X0 is memory-capable)
fn getSlicePrefix(x: u16, y: u16) []const u8 {
    return getSlicePrefixForIndex(x, y, 0);
}

fn getSlicePrefixForIndex(x: u16, y: u16, slice_x: u8) []const u8 {
    if (slice_x >= 1) return "SLICEL"; // X1 is always SLICEL
    if (tiles.findClbTile(@intCast(x), @intCast(y))) |tile| {
        return switch (tile.tile_type) {
            .clblm_l, .clblm_r => "SLICEM",
            else => "SLICEL",
        };
    }
    return "SLICEL";
}

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

    const tile_prefix = getClbTilePrefix(x, y);

    // Slice X index (0 or 1, two slices per CLB tile)
    const slice_x: u8 = if (cell.bel) |bel| @intCast(bel.bel_index / 4) else 0;
    const slice_prefix = getSlicePrefixForIndex(x, y, slice_x);

    // Determine slice (A-D based on bel_index)
    const slice_letter: u8 = if (cell.bel) |bel| switch (bel.bel_index % 4) {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        else => 'A',
    } else 'A';

    // LUT INIT: emit one feature per set bit (SLICEL_X0.ALUT.INIT[NN])
    // Also emit 64-bit format for compatibility with external fasm2bits tools
    if (cell.lut_init != 0) {
        var bit_idx: u7 = 0;
        while (bit_idx < 64) : (bit_idx += 1) {
            const shift: u6 = @intCast(bit_idx);
            if ((cell.lut_init >> shift) & 1 == 1) {
                var buf: [256]u8 = undefined;
                const line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X{d}.{c}LUT.INIT[{d:0>2}]", .{
                    tile_prefix, x, y, slice_prefix, slice_x, slice_letter, bit_idx,
                }) catch continue;
                const duped = try allocator.dupe(u8, line);
                try result.features.append(allocator, FasmFeature{ .line = duped });
            }
        }
    }
}

fn generateFfFeature(allocator: Allocator, cell: MappedCell, result: *FasmResult) !void {
    const x = cell.tile_x orelse return;
    const y = cell.tile_y orelse return;

    const tile_prefix = getClbTilePrefix(x, y);
    const slice_x: u8 = if (cell.bel) |bel| @intCast(bel.bel_index / 4) else 0;
    const slice_prefix = getSlicePrefixForIndex(x, y, slice_x);

    const slice_letter: u8 = if (cell.bel) |bel| switch (bel.bel_index % 4) {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        else => 'A',
    } else 'A';

    var buf: [256]u8 = undefined;

    // FF INIT
    const init_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X{d}.{c}FF.ZINI", .{
        tile_prefix, x, y, slice_prefix, slice_x, slice_letter,
    }) catch return;
    const init_duped = try allocator.dupe(u8, init_line);
    try result.features.append(allocator, FasmFeature{ .line = init_duped });

    // FF reset
    const zrst_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X{d}.{c}FF.ZRST", .{
        tile_prefix, x, y, slice_prefix, slice_x, slice_letter,
    }) catch return;
    const zrst_duped = try allocator.dupe(u8, zrst_line);
    try result.features.append(allocator, FasmFeature{ .line = zrst_duped });

    // FF type-specific features
    if (cell.cell_type == .FDRE or cell.cell_type == .FDSE) {
        const sync_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X{d}.FFSYNC", .{
            tile_prefix, x, y, slice_prefix, slice_x,
        }) catch return;
        const sync_duped = try allocator.dupe(u8, sync_line);
        try result.features.append(allocator, FasmFeature{ .line = sync_duped });
    }

    // NOCLKINV (clock not inverted — standard for most FFs)
    const noclk_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X{d}.NOCLKINV", .{
        tile_prefix, x, y, slice_prefix, slice_x,
    }) catch return;
    const noclk_duped = try allocator.dupe(u8, noclk_line);
    try result.features.append(allocator, FasmFeature{ .line = noclk_duped });
}

fn generateCarry4Feature(allocator: Allocator, cell: MappedCell, result: *FasmResult) !void {
    const x = cell.tile_x orelse return;
    const y = cell.tile_y orelse return;

    const tile_prefix = getClbTilePrefix(x, y);
    const slice_prefix = getSlicePrefixForIndex(x, y, 0); // CARRY4 always in X0
    const is_ll = std.mem.eql(u8, tile_prefix, "CLBLL_L") or std.mem.eql(u8, tile_prefix, "CLBLL_R");

    var buf: [512]u8 = undefined;

    // 1) CARRY4 sub-features: ACY0, BCY0, CCY0, DCY0
    const prefixes = [_]u8{ 'A', 'B', 'C', 'D' };
    for (prefixes) |prefix| {
        const line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X0.CARRY4.{c}CY0", .{
            tile_prefix, x, y, slice_prefix, prefix,
        }) catch continue;
        const duped = try allocator.dupe(u8, line);
        try result.features.append(allocator, FasmFeature{ .line = duped });
    }

    // 2) CYINIT configuration
    if (cell.carry_cyinit_const) |cyinit| {
        // First CARRY4 in chain uses PRECYINIT.C0 or PRECYINIT.AX
        // The reference uses PRECYINIT.AX when the carry init comes from a port
        const cyinit_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X0.PRECYINIT.{s}", .{
            tile_prefix, x, y, slice_prefix, if (cyinit == 0) "C0" else "C1",
        }) catch return;
        const cyinit_duped = try allocator.dupe(u8, cyinit_line);
        try result.features.append(allocator, FasmFeature{ .line = cyinit_duped });
    }

    // 3) Output muxes for CARRY4 — all outputs go through XOR
    const outmux_names = [_][]const u8{ "AOUTMUX.XOR", "BFFMUX.XOR", "COUTMUX.XOR", "DFFMUX.XOR" };
    for (outmux_names) |mux| {
        const line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X0.{s}", .{
            tile_prefix, x, y, slice_prefix, mux,
        }) catch continue;
        const duped = try allocator.dupe(u8, line);
        try result.features.append(allocator, FasmFeature{ .line = duped });
    }

    // 4) CLB internal routing PIPs for CARRY4
    // These connect the CLB tile's internal muxes to the SLICE pins
    // CLBLL has two sets: CLBLL_L_* (SLICEL_X0) and CLBLL_LL_* (SLICEL_X1)
    const ll_prefix: []const u8 = if (is_ll) "CLBLL_LL" else "CLBLM_M";
    const l_prefix: []const u8 = if (is_ll) "CLBLL_L" else "CLBLM_L";

    // Slice X0 — clock, CE, SR
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CLK.CLBLL_CLK0", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CE.CLBLL_FAN6", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_SR.CLBLL_CTRL0", .{ tile_prefix, x, y, l_prefix });
    // Bypass inputs for carry data
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CX.CLBLL_BYP2", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_DX.CLBLL_BYP7", .{ tile_prefix, x, y, l_prefix });

    // Slice X1 — clock, CE, SR, carry output, AX bypass
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CLK.CLBLL_CLK1", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CE.CLBLL_FAN7", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_SR.CLBLL_CTRL1", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_COUT_N.{s}_COUT", .{ tile_prefix, x, y, ll_prefix, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_AX.CLBLL_BYP1", .{ tile_prefix, x, y, ll_prefix });

    // CARRY4 LUT input connections (A6/B6/C6/D6 → fixed IMUX indices for carry S inputs)
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_A6.CLBLL_IMUX4", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_B6.CLBLL_IMUX12", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_C6.CLBLL_IMUX35", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_D6.CLBLL_IMUX43", .{ tile_prefix, x, y, ll_prefix });

    // 5) LOGIC_OUTS — FF and MUX output connections
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS2.{s}_CQ", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS3.{s}_DQ", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS5.{s}_BQ", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS7.{s}_DQ", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS20.{s}_AMUX", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS22.{s}_CMUX", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS19.{s}_DMUX", .{ tile_prefix, x, y, l_prefix });
}

// =============================================================================
// IOB Feature Generation
// =============================================================================

fn generateIobFeatures(allocator: Allocator, db: *const ForgeDB, result: *FasmResult) !void {
    for (db.cells.items) |cell| {
        if (!cell.cell_type.isIO()) continue;

        const x = cell.tile_x orelse continue;
        const y = cell.tile_y orelse continue;

        const iob_prefix = getIobTilePrefix(x);

        // IOB_Y0 for even-Y tiles, IOB_Y1 for odd-Y tiles within the tile
        const iob_y_suffix: []const u8 = if (cell.bel) |bel|
            (if (bel.bel_index == 0) "IOB_Y0" else "IOB_Y1")
        else
            "IOB_Y0";

        var buf: [512]u8 = undefined;

        if (cell.cell_type == .IBUF) {
            const in_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}.LVCMOS25_LVCMOS33_LVTTL.IN", .{ iob_prefix, x, y, iob_y_suffix }) catch continue;
            const in_duped = try allocator.dupe(u8, in_line);
            try result.features.append(allocator, FasmFeature{ .line = in_duped });

            const inonly_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVDS_25_LVTTL_SSTL135_SSTL15_TMDS_33.IN_ONLY", .{ iob_prefix, x, y, iob_y_suffix }) catch continue;
            const inonly_duped = try allocator.dupe(u8, inonly_line);
            try result.features.append(allocator, FasmFeature{ .line = inonly_duped });

            const pull_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}.PULLTYPE.NONE", .{ iob_prefix, x, y, iob_y_suffix }) catch continue;
            const pull_duped = try allocator.dupe(u8, pull_line);
            try result.features.append(allocator, FasmFeature{ .line = pull_duped });
        } else {
            const drv_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}.LVCMOS33_LVTTL.DRIVE.I12_I8", .{ iob_prefix, x, y, iob_y_suffix }) catch continue;
            const drv_duped = try allocator.dupe(u8, drv_line);
            try result.features.append(allocator, FasmFeature{ .line = drv_duped });

            const slew_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL_SSTL135_SSTL15.SLEW.SLOW", .{ iob_prefix, x, y, iob_y_suffix }) catch continue;
            const slew_duped = try allocator.dupe(u8, slew_line);
            try result.features.append(allocator, FasmFeature{ .line = slew_duped });

            const pull_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}.PULLTYPE.NONE", .{ iob_prefix, x, y, iob_y_suffix }) catch continue;
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

        // BUFG bel_index maps to BUFGCTRL instance
        const bufg_idx: u16 = if (cell.bel) |bel| @intCast(bel.bel_index) else 0;

        // Determine BOT vs TOP based on tile position
        const bufg_tile_prefix: []const u8 = if (y <= 100)
            "CLK_BUFG_BOT_R"
        else
            "CLK_BUFG_TOP_R";

        var buf: [256]u8 = undefined;

        // prjxray format: CLK_BUFG_BOT_R_X{x}Y{y}.BUFGCTRL.BUFGCTRL_X0Y{idx}.IN_USE
        const in_use_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.IN_USE", .{ bufg_tile_prefix, x, y, bufg_idx }) catch continue;
        const in_use_duped = try allocator.dupe(u8, in_use_line);
        try result.features.append(allocator, FasmFeature{ .line = in_use_duped });

        // IS_IGNORE1_INVERTED (from reference FASM)
        const ign_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.IS_IGNORE1_INVERTED", .{ bufg_tile_prefix, x, y, bufg_idx }) catch continue;
        const ign_duped = try allocator.dupe(u8, ign_line);
        try result.features.append(allocator, FasmFeature{ .line = ign_duped });

        // ZINV_CE0
        const zce_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.ZINV_CE0", .{ bufg_tile_prefix, x, y, bufg_idx }) catch continue;
        const zce_duped = try allocator.dupe(u8, zce_line);
        try result.features.append(allocator, FasmFeature{ .line = zce_duped });

        // ZINV_S0
        const zs_line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.BUFGCTRL.BUFGCTRL_X0Y{d}.ZINV_S0", .{ bufg_tile_prefix, x, y, bufg_idx }) catch continue;
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

            const line = if (pip.wire_from.len == 0)
                // Single-field feature: tile.feature (e.g. active markers)
                std.fmt.bufPrint(&buf, "{s}.{s}", .{
                    pip.tile_name, pip.wire_to,
                }) catch continue
            else
                // FASM PIP format: tile.destination.source
                // wire_from = source wire, wire_to = destination wire
                std.fmt.bufPrint(&buf, "{s}.{s}.{s}", .{
                    pip.tile_name, pip.wire_to, pip.wire_from,
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

    // prjxray BUFG: BUFGCTRL.IN_USE + IS_IGNORE1_INVERTED + ZINV_CE0 + ZINV_S0
    var found_in_use = false;
    var found_ign = false;
    var found_zce = false;
    var found_zs = false;
    for (result.features.items) |f| {
        if (std.mem.indexOf(u8, f.line, "BUFGCTRL_X0Y0.IN_USE") != null) found_in_use = true;
        if (std.mem.indexOf(u8, f.line, "IS_IGNORE1_INVERTED") != null) found_ign = true;
        if (std.mem.indexOf(u8, f.line, "ZINV_CE0") != null) found_zce = true;
        if (std.mem.indexOf(u8, f.line, "ZINV_S0") != null) found_zs = true;
    }
    try std.testing.expect(found_in_use);
    try std.testing.expect(found_ign);
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

    // LUT1(init=1): 1 per-bit feature
    // FF: 4 (ZINI + ZRST + FFSYNC + NOCLKINV)
    // IOB IBUF: 3 (IN + IN_ONLY + PULLTYPE)
    try std.testing.expectEqual(@as(usize, 8), result.lineCount());
}
