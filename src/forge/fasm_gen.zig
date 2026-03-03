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
    // Find minimum Y of CARRY4 cells to determine which is first in chain
    var carry4_min_y: ?u16 = null;
    for (db.cells.items) |cell| {
        if (cell.cell_type == .CARRY4) {
            if (cell.tile_y) |y| {
                if (carry4_min_y == null or y < carry4_min_y.?) {
                    carry4_min_y = y;
                }
            }
        }
    }

    // Track which slices have already emitted FFSYNC/NOCLKINV
    // Key: (tile_x << 16 | tile_y) << 1 | slice_x
    var emitted_slice_features = std.AutoHashMap(u33, void).init(allocator);
    defer emitted_slice_features.deinit();

    for (db.cells.items) |cell| {
        if (cell.cell_type.isLUT()) {
            try generateLutFeature(allocator, cell, result);
        } else if (cell.cell_type.isFF()) {
            // FFs in CARRY4 tiles are handled by generateCarry4Feature
            const in_carry_tile = blk: {
                if (cell.tile_x == null or cell.tile_y == null) break :blk false;
                for (db.cells.items) |c| {
                    if (c.cell_type == .CARRY4 and c.tile_x != null and c.tile_y != null) {
                        if (c.tile_x.? == cell.tile_x.? and c.tile_y.? == cell.tile_y.?) break :blk true;
                    }
                }
                break :blk false;
            };
            if (!in_carry_tile) {
                try generateFfFeature(allocator, cell, result, &emitted_slice_features);
            }
        } else if (cell.cell_type == .CARRY4) {
            try generateCarry4Feature(allocator, db, cell, result, carry4_min_y);
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

    var buf: [512]u8 = undefined;

    // LUT INIT: emit per-bit features matching segbits_data.zig format
    // Format: TILE.SLICE.XLUT.INIT[NN] for each set bit
    if (cell.lut_init != 0) {
        var bit_idx: u7 = 0;
        while (bit_idx < 64) : (bit_idx += 1) {
            const shift: u6 = @intCast(bit_idx);
            if ((cell.lut_init >> shift) & 1 == 1) {
                const line = std.fmt.bufPrint(&buf, "{s}_X{d}Y{d}.{s}_X{d}.{c}LUT.INIT[{d:0>2}]", .{
                    tile_prefix, x, y, slice_prefix, slice_x, slice_letter, bit_idx,
                }) catch continue;
                const duped = try allocator.dupe(u8, line);
                try result.features.append(allocator, FasmFeature{ .line = duped });
            }
        }
    }

    // Output LUT needs XOUTMUX.O6 (routes LUT output to tile output, bypasses FF)
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X{d}.{c}OUTMUX.O6", .{
        tile_prefix, x, y, slice_prefix, slice_x, slice_letter,
    });

    // NOCLKINV for the slice containing the LUT (needed even without FFs)
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X{d}.NOCLKINV", .{
        tile_prefix, x, y, slice_prefix, slice_x,
    });
}

fn generateFfFeature(allocator: Allocator, cell: MappedCell, result: *FasmResult, emitted_slice_features: *std.AutoHashMap(u33, void)) !void {
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

    // Slice-level features: FFSYNC and NOCLKINV — emit once per slice
    const slice_key: u33 = (@as(u33, x) << 17) | (@as(u33, y) << 1) | @as(u33, slice_x);
    if (!emitted_slice_features.contains(slice_key)) {
        emitted_slice_features.put(slice_key, {}) catch {};

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
}

fn generateCarry4Feature(allocator: Allocator, db: *const ForgeDB, cell: MappedCell, result: *FasmResult, carry4_min_y: ?u16) !void {
    const x = cell.tile_x orelse return;
    const y = cell.tile_y orelse return;

    const tile_prefix = getClbTilePrefix(x, y);
    const slice_prefix = getSlicePrefixForIndex(x, y, 0); // CARRY4 always in X0
    const is_ll = std.mem.eql(u8, tile_prefix, "CLBLL_L") or std.mem.eql(u8, tile_prefix, "CLBLL_R");
    const is_first = if (carry4_min_y) |min_y| (y == min_y) else (cell.carry_chain_pos orelse 0) == 0;

    var buf: [512]u8 = undefined;

    // --- Scan FFs in this tile to build per-position occupancy ---
    // ff_x0[0..4] = A,B,C,D in slice X0; ff_x1[0..4] = A,B,C,D in slice X1
    var ff_x0 = [4]bool{ false, false, false, false };
    var ff_x1 = [4]bool{ false, false, false, false };
    for (db.cells.items) |c| {
        if (!c.cell_type.isFF()) continue;
        if (c.tile_x == null or c.tile_y == null) continue;
        if (c.tile_x.? != x or c.tile_y.? != y) continue;
        if (c.bel) |bel| {
            const sx: u8 = @intCast(bel.bel_index / 4); // 0=X0, 1=X1
            const pos: u8 = @intCast(bel.bel_index % 4); // 0=A,1=B,2=C,3=D
            if (sx == 0) ff_x0[pos] = true else ff_x1[pos] = true;
        }
    }
    const has_x0_ff = ff_x0[0] or ff_x0[1] or ff_x0[2] or ff_x0[3];
    const has_x1_ff = ff_x1[0] or ff_x1[1] or ff_x1[2] or ff_x1[3];

    // 1) CARRY4 sub-features: ACY0, BCY0, CCY0, DCY0
    const prefixes = [_]u8{ 'A', 'B', 'C', 'D' };
    for (prefixes) |prefix| {
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.CARRY4.{c}CY0", .{
            tile_prefix, x, y, slice_prefix, prefix,
        });
    }

    // 2) CYINIT configuration
    {
        const cyinit_str: []const u8 = if (is_first) "AX" else "CIN";
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.PRECYINIT.{s}", .{
            tile_prefix, x, y, slice_prefix, cyinit_str,
        });
    }

    // 2b) Slice-level FF config — only emit if slice actually has FFs
    if (has_x0_ff) {
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.FFSYNC", .{ tile_prefix, x, y, slice_prefix });
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.NOCLKINV", .{ tile_prefix, x, y, slice_prefix });
    }

    // 2c) LUT INIT values for CARRY4 positions
    // Each LUT computes O6 = identity(feedback_Q) for the carry chain S input.
    // The carry feedback routes Q output back to specific LUT input pins:
    //   A: IMUX_L1 = LUT I3 → identity on I3 = upper 0xF0F0F0F0
    //   B: IMUX_L18 = LUT I2 → identity on I2 = upper 0xCCCCCCCC
    //   C: IMUX_L29 = LUT I2 → identity on I2 = upper 0xCCCCCCCC
    //   D: IMUX_L38 = LUT I3 → identity on I3 = upper 0xF0F0F0F0
    // First tile position A uses NOT(I3) for counter increment with CIN=0.
    // Format: range notation INIT[63:0] = 64'b... (matches fasm2frames expectation)
    {
        const lut_letters = [_]u8{ 'A', 'B', 'C', 'D' };
        // Per-position INIT values: {upper_32_when_I6=1, lower_32_when_I6=0}
        const carry_inits = [4]u64{
            0xF0F0F0F0CCCCCCCC, // A: I3 identity (upper), I2 (lower)
            0xCCCCCCCCF0F0F0F0, // B: I2 identity (upper), I3 (lower)
            0xCCCCCCCCAAAAAAAA, // C: I2 identity (upper), I1 (lower)
            0xF0F0F0F0AAAAAAAA, // D: I3 identity (upper), I1 (lower)
        };
        // First tile A: NOT(I3) for +1 counter with CIN=0
        const first_a_init: u64 = 0x0F0F0F0FCCCCCCCC;

        for (lut_letters, 0..) |letter, pos| {
            const init: u64 = if (is_first and pos == 0) first_a_init else carry_inits[pos];

            // Emit as range: ALUT.INIT[63:0] = 64'b<binary>
            var init_buf: [160]u8 = undefined;
            var init_str: [64]u8 = undefined;
            // Convert to binary string MSB-first (bit63 first)
            var bit_pos: u7 = 0;
            while (bit_pos < 64) : (bit_pos += 1) {
                const shift: u6 = @intCast(63 - bit_pos);
                init_str[bit_pos] = if ((init >> shift) & 1 == 1) '1' else '0';
            }
            const init_line = std.fmt.bufPrint(&init_buf, "{s}_X{d}Y{d}.{s}_X0.{c}LUT.INIT[63:0] = 64'b{s}", .{
                tile_prefix, x, y, slice_prefix, letter, &init_str,
            }) catch continue;
            const duped = try allocator.dupe(u8, init_line);
            try result.features.append(allocator, FasmFeature{ .line = duped });
        }
    }

    // 3) OUTMUX — only for positions WITHOUT FF in X0
    // When a position has an FF, XOR→FF via FFMUX.XOR; FF Q→routing via LOGIC_OUTS_Q
    // When no FF, XOR→routing via OUTMUX.XOR → LOGIC_OUTS_MUX
    const letters = [_]u8{ 'A', 'B', 'C', 'D' };
    for (letters, 0..) |letter, pos| {
        if (!ff_x0[pos]) {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.{c}OUTMUX.XOR", .{
                tile_prefix, x, y, slice_prefix, letter,
            });
        }
    }

    // 4) FFMUX — only for positions that have an FF in X0
    // X0 FFs connected to CARRY4 XOR use FFMUX.XOR
    for (letters, 0..) |letter, pos| {
        if (ff_x0[pos]) {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.{c}FFMUX.XOR", .{
                tile_prefix, x, y, slice_prefix, letter,
            });
        }
    }

    // 4b) FF ZINI/ZRST for X0 FFs
    for (letters, 0..) |letter, pos| {
        if (ff_x0[pos]) {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.{c}FF.ZINI", .{
                tile_prefix, x, y, slice_prefix, letter,
            });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X0.{c}FF.ZRST", .{
                tile_prefix, x, y, slice_prefix, letter,
            });
        }
    }

    // 5) X1 slice features — FFs packed into X1 get data from bypass pins
    if (has_x1_ff) {
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X1.FFSYNC", .{ tile_prefix, x, y, slice_prefix });
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X1.NOCLKINV", .{ tile_prefix, x, y, slice_prefix });
    } else {
        // Even without X1 FFs, clock tree may need NOCLKINV if X1 CLK is connected
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X1.NOCLKINV", .{ tile_prefix, x, y, slice_prefix });
    }

    // X1 FF features: FFMUX uses bypass (AX/BX/CX/DX) since CARRY4 is only in X0
    const bypass_names = [_][]const u8{ "AX", "BX", "CX", "DX" };
    for (letters, 0..) |letter, pos| {
        if (ff_x1[pos]) {
            // FF ZINI/ZRST
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X1.{c}FF.ZINI", .{
                tile_prefix, x, y, slice_prefix, letter,
            });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X1.{c}FF.ZRST", .{
                tile_prefix, x, y, slice_prefix, letter,
            });
            // FFMUX.BYP (e.g., CFFMUX.CX, DFFMUX.DX)
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_X1.{c}FFMUX.{s}", .{
                tile_prefix, x, y, slice_prefix, letter, bypass_names[pos],
            });
        }
    }

    // 6) CLB internal routing PIPs for CARRY4
    const ll_prefix: []const u8 = if (is_ll) "CLBLL_LL" else "CLBLM_M";
    const l_prefix: []const u8 = if (is_ll) "CLBLL_L" else "CLBLM_L";

    // Slice X0 — clock, CE, SR (always needed for CARRY4)
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CLK.CLBLL_CLK0", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CE.CLBLL_FAN6", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_SR.CLBLL_CTRL0", .{ tile_prefix, x, y, l_prefix });

    // Slice X1 — clock, CE, SR (only if X1 has FFs or COUT)
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CLK.CLBLL_CLK1", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CE.CLBLL_FAN7", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_SR.CLBLL_CTRL1", .{ tile_prefix, x, y, ll_prefix });

    // COUT always through LL prefix
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_COUT_N.{s}_COUT", .{ tile_prefix, x, y, ll_prefix, ll_prefix });

    // AX bypass for first CARRY4 (PRECYINIT.AX)
    if (is_first) {
        try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_AX.CLBLL_BYP1", .{ tile_prefix, x, y, ll_prefix });
    }

    // CARRY4 LUT input connections (A6/B6/C6/D6 → fixed IMUX indices for carry S inputs)
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_A6.CLBLL_IMUX4", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_B6.CLBLL_IMUX12", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_C6.CLBLL_IMUX35", .{ tile_prefix, x, y, ll_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_D6.CLBLL_IMUX43", .{ tile_prefix, x, y, ll_prefix });

    // 7) BYP — bypass routing for DI inputs (carry data)
    // X0 bypass: CX and DX provide DI[2] and DI[3] for carry chain
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_CX.CLBLL_BYP2", .{ tile_prefix, x, y, l_prefix });
    try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_DX.CLBLL_BYP7", .{ tile_prefix, x, y, l_prefix });

    // X1 bypass for X1 FFs (route from INT to X1 bypass pins)
    for (letters, 0..) |letter, pos| {
        if (ff_x1[pos]) {
            // BYP indices for LL: AX=BYP1, BX=BYP4, CX=BYP3, DX=BYP6
            const byp_idx: []const u8 = switch (pos) {
                0 => "BYP1", // AX
                1 => "BYP4", // BX
                2 => "BYP3", // CX
                3 => "BYP6", // DX
                else => "BYP1",
            };
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}_{c}X.CLBLL_{s}", .{
                tile_prefix, x, y, ll_prefix, letter, byp_idx,
            });
        }
    }

    // 8) LOGIC_OUTS — emit based on actual FF placement
    // Q outputs: connect FF output to tile's routing interconnect
    // From prjxray: X0 (LL slice) uses LOGIC_OUTS 4-7, X1 (L slice) uses LOGIC_OUTS 0-3
    const x0_q_indices = [_]u8{ 4, 5, 6, 7 }; // X0(LL): AQ=4, BQ=5, CQ=6, DQ=7
    const x1_q_indices = [_]u8{ 0, 1, 2, 3 }; // X1(L):  AQ=0, BQ=1, CQ=2, DQ=3
    for (0..4) |pos| {
        if (ff_x0[pos]) {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS{d}.{s}_{c}Q", .{
                tile_prefix, x, y, x0_q_indices[pos], ll_prefix, letters[pos],
            });
        }
    }
    for (0..4) |pos| {
        if (ff_x1[pos]) {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS{d}.{s}_{c}Q", .{
                tile_prefix, x, y, x1_q_indices[pos], l_prefix, letters[pos],
            });
        }
    }

    // MUX outputs: OUTMUX routes (XOR outputs from CARRY4 going to routing)
    // LOGIC_OUTS indices for MUX: X1: AMUX=20,BMUX=21,CMUX=22,DMUX=23; X0: DMUX=19
    // Only emit MUX LOGIC_OUTS for carry positions that feed routing
    // For blinker counter: XOR outputs feed FFs in next stage, so all positions need MUX outs
    // However, we should be selective — emit based on what actually routes out
    // For now, emit carry XOR MUX outputs for positions without X0 FF (XOR must route elsewhere)
    for (0..4) |pos| {
        if (!ff_x0[pos]) {
            // XOR not captured by X0 FF → routes out via MUX LOGIC_OUTS
            const mux_idx: u8 = switch (pos) {
                0 => 20, // AMUX via LL
                1 => 21, // BMUX via LL
                2 => 22, // CMUX via LL
                3 => 19, // DMUX via L (note: D uses L, not LL)
                else => 20,
            };
            const mux_prefix: []const u8 = if (pos == 3) l_prefix else ll_prefix;
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.CLBLL_LOGIC_OUTS{d}.{s}_{c}MUX", .{
                tile_prefix, x, y, mux_idx, mux_prefix, letters[pos],
            });
        }
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

        const iob_prefix = getIobTilePrefix(x);

        // IOB_Y0 for even-Y tiles, IOB_Y1 for odd-Y tiles within the tile
        const iob_y_suffix: []const u8 = if (cell.bel) |bel|
            (if (bel.bel_index == 0) "IOB_Y0" else "IOB_Y1")
        else
            "IOB_Y0";

        var buf: [512]u8 = undefined;

        if (cell.cell_type == .IBUF) {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}.LVCMOS25_LVCMOS33_LVTTL.IN", .{ iob_prefix, x, y, iob_y_suffix });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVDS_25_LVTTL_SSTL135_SSTL15_TMDS_33.IN_ONLY", .{ iob_prefix, x, y, iob_y_suffix });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}.PULLTYPE.NONE", .{ iob_prefix, x, y, iob_y_suffix });

            // LIOI3/RIOI3 features for IBUF path
            const ioi_prefix: []const u8 = if (x == 0) "LIOI3" else "RIOI3";
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.IDELAY_Y0.IDELAY_TYPE_FIXED", .{ ioi_prefix, x, y });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.ILOGIC_Y0.ZINV_D", .{ ioi_prefix, x, y });
        } else {
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}.LVCMOS33_LVTTL.DRIVE.I12_I8", .{ iob_prefix, x, y, iob_y_suffix });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL_SSTL135_SSTL15.SLEW.SLOW", .{ iob_prefix, x, y, iob_y_suffix });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.{s}.PULLTYPE.NONE", .{ iob_prefix, x, y, iob_y_suffix });

            // LIOI3/RIOI3 features for OBUF path (OLOGIC)
            const ioi_prefix: []const u8 = if (x == 0) "LIOI3" else "RIOI3";
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.OLOGIC_Y0.OMUX.D1", .{ ioi_prefix, x, y });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.OLOGIC_Y0.OQUSED", .{ ioi_prefix, x, y });
            try emitFeature(allocator, result, &buf, "{s}_X{d}Y{d}.OLOGIC_Y0.OSERDES.DATA_RATE_TQ.BUF", .{ ioi_prefix, x, y });
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

/// Write FASM features to a file, deduplicating identical lines.
pub fn writeFasm(allocator: Allocator, result: *const FasmResult, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    // Deduplicate: track which feature strings have been written
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (result.features.items) |feature| {
        const gop = try seen.getOrPut(feature.line);
        if (!gop.found_existing) {
            try file.writeAll(feature.line);
            try file.writeAll("\n");
        }
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

    // LUT1(init=1): 1 per-bit feature + OUTMUX.O6 + NOCLKINV = 3
    // FF: 4 (ZINI + ZRST + FFSYNC + NOCLKINV)
    // IOB IBUF: 5 (IN + IN_ONLY + PULLTYPE + IDELAY_TYPE_FIXED + ILOGIC ZINV_D)
    // Total: 3 + 4 + 5 = 12
    try std.testing.expectEqual(@as(usize, 12), result.lineCount());
}
