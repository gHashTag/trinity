// =============================================================================
// FORGE OF KOSCHEI v2.0 — Artix-7 Device Database
// =============================================================================
//
// Hardcoded device model for Artix-7 FPGAs. Contains:
//   - Tile grid layout (CLB, IOB, INT, clock tiles)
//   - Package pin -> tile/BEL mapping for CSG324 (Arty A7-35T)
//   - Frame address calculation
//   - BEL definitions per tile type
//
// Primary target: XC7A35T-1CSG324C (Arty A7-35T)
// Secondary:      XC7A100T-1FGG676 (QMTECH board)
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const types = @import("types.zig");
const tiles = @import("xc7a100t_tiles.zig");

const DeviceId = types.DeviceId;
const TileType = types.TileType;
const CellType = types.CellType;

// =============================================================================
// Device Parameters
// =============================================================================

pub const DeviceParams = struct {
    idcode: u32,
    frame_count: u32,
    frame_words: u32,
    num_rows: u16,
    num_cols: u16,
    num_clb_cols: u16,
    num_io_cols: u16,
    num_bram_cols: u16,
    num_dsp_cols: u16,
    num_slices: u32,
    num_luts: u32,
    num_ffs: u32,
    num_bram: u32,
    num_dsp: u32,
    num_bufg: u8,
};

pub fn getDeviceParams(device: DeviceId) DeviceParams {
    return switch (device) {
        .xc7a35t => .{
            .idcode = 0x0362D093,
            .frame_count = 16620,
            .frame_words = 101,
            .num_rows = 200,
            .num_cols = 65,
            .num_clb_cols = 28,
            .num_io_cols = 4,
            .num_bram_cols = 5,
            .num_dsp_cols = 3,
            .num_slices = 5200,
            .num_luts = 20800,
            .num_ffs = 41600,
            .num_bram = 50,
            .num_dsp = 90,
            .num_bufg = 32,
        },
        .xc7a100t => .{
            .idcode = 0x03631093,
            .frame_count = 9448,
            .frame_words = 101,
            .num_rows = 200, // Y range 0..199
            .num_cols = 131, // grid columns (from tilegrid)
            .num_clb_cols = 45, // real CLB X columns
            .num_io_cols = 6,
            .num_bram_cols = 10,
            .num_dsp_cols = 6,
            .num_slices = 15850,
            .num_luts = 63400,
            .num_ffs = 126800,
            .num_bram = 135,
            .num_dsp = 240,
            .num_bufg = 32,
        },
    };
}

// =============================================================================
// Package Pin Mapping (CSG324 for XC7A35T / Arty A7)
// =============================================================================

pub const PinLocation = struct {
    pin: []const u8,
    tile_x: u16,
    tile_y: u16,
    bel_index: u16,
    iob_site: []const u8,
};

/// Get the tile location for a package pin on the given device.
pub fn getPinLocation(device: DeviceId, pin: []const u8) ?PinLocation {
    switch (device) {
        .xc7a35t => {
            for (&arty_a7_pins) |entry| {
                if (std.mem.eql(u8, entry.pin, pin)) {
                    return entry;
                }
            }
        },
        .xc7a100t => {
            // Use real package pin data from prjxray-db
            const pp = tiles.findPackagePin(pin) orelse return null;
            return PinLocation{
                .pin = pp.pin,
                .tile_x = pp.tile_x,
                .tile_y = pp.tile_y,
                .bel_index = if (pp.iob_site_y % 2 == 0) 0 else 1,
                .iob_site = pp.pin, // We'll format properly in FASM gen
            };
        },
    }
    return null;
}

// Arty A7-35T (CSG324) pin -> tile mapping
// Derived from prjxray-db artix7/xc7a35tcsg324-1/package_pins.csv
const arty_a7_pins = [_]PinLocation{
    // Clock
    .{ .pin = "E3", .tile_x = 0, .tile_y = 148, .bel_index = 0, .iob_site = "IOB_X0Y148" },
    // Reset
    .{ .pin = "C12", .tile_x = 0, .tile_y = 100, .bel_index = 0, .iob_site = "IOB_X0Y100" },
    // LEDs
    .{ .pin = "R5", .tile_x = 64, .tile_y = 40, .bel_index = 0, .iob_site = "IOB_X1Y40" },
    .{ .pin = "T5", .tile_x = 64, .tile_y = 41, .bel_index = 0, .iob_site = "IOB_X1Y41" },
    .{ .pin = "T8", .tile_x = 64, .tile_y = 56, .bel_index = 0, .iob_site = "IOB_X1Y56" },
    .{ .pin = "T9", .tile_x = 64, .tile_y = 57, .bel_index = 0, .iob_site = "IOB_X1Y57" },
    // Switches
    .{ .pin = "A15", .tile_x = 0, .tile_y = 124, .bel_index = 0, .iob_site = "IOB_X0Y124" },
    .{ .pin = "C16", .tile_x = 0, .tile_y = 130, .bel_index = 0, .iob_site = "IOB_X0Y130" },
    .{ .pin = "C15", .tile_x = 0, .tile_y = 128, .bel_index = 0, .iob_site = "IOB_X0Y128" },
    .{ .pin = "P15", .tile_x = 64, .tile_y = 100, .bel_index = 0, .iob_site = "IOB_X1Y100" },
    // Buttons
    .{ .pin = "D9", .tile_x = 0, .tile_y = 62, .bel_index = 0, .iob_site = "IOB_X0Y62" },
    .{ .pin = "C9", .tile_x = 0, .tile_y = 60, .bel_index = 0, .iob_site = "IOB_X0Y60" },
    .{ .pin = "B9", .tile_x = 0, .tile_y = 58, .bel_index = 0, .iob_site = "IOB_X0Y58" },
    .{ .pin = "B8", .tile_x = 0, .tile_y = 54, .bel_index = 0, .iob_site = "IOB_X0Y54" },
    // UART
    .{ .pin = "A9", .tile_x = 0, .tile_y = 59, .bel_index = 0, .iob_site = "IOB_X0Y59" },
    .{ .pin = "D10", .tile_x = 0, .tile_y = 64, .bel_index = 0, .iob_site = "IOB_X0Y64" },
    // Pmod JA
    .{ .pin = "J1", .tile_x = 64, .tile_y = 0, .bel_index = 0, .iob_site = "IOB_X1Y0" },
    .{ .pin = "L1", .tile_x = 64, .tile_y = 2, .bel_index = 0, .iob_site = "IOB_X1Y2" },
    .{ .pin = "M1", .tile_x = 64, .tile_y = 4, .bel_index = 0, .iob_site = "IOB_X1Y4" },
    .{ .pin = "N1", .tile_x = 64, .tile_y = 6, .bel_index = 0, .iob_site = "IOB_X1Y6" },
};

// QMTECH XC7A100T (FGG676) — pin table no longer used for xc7a100t.
// getPinLocation() uses xc7a100t_tiles.findPackagePin() instead.
// Keeping as fallback for reference only.
const qmtech_pins = [_]PinLocation{};

// =============================================================================
// CLB Tile BEL Definitions
// =============================================================================

/// Number of BELs in a CLB tile (8 LUT + 16 FF + 2 CARRY4 in a tile with 2 slices)
pub const BELS_PER_CLB: u16 = 26;

/// BEL types within a CLB slice
pub const SliceBel = enum {
    A_LUT, // A6LUT
    B_LUT, // B6LUT
    C_LUT, // C6LUT
    D_LUT, // D6LUT
    A_FF, // AFF
    B_FF, // BFF
    C_FF, // CFF
    D_FF, // DFF
    A_FF2, // AFF2 (in SLICEM only, or second FF in 7-series)
    B_FF2,
    C_FF2,
    D_FF2,
    CARRY4, // One per slice

    pub fn isLUT(self: SliceBel) bool {
        return switch (self) {
            .A_LUT, .B_LUT, .C_LUT, .D_LUT => true,
            else => false,
        };
    }

    pub fn isFF(self: SliceBel) bool {
        return switch (self) {
            .A_FF, .B_FF, .C_FF, .D_FF,
            .A_FF2, .B_FF2, .C_FF2, .D_FF2,
            => true,
            else => false,
        };
    }
};

// =============================================================================
// BUFG Tile Locations
// =============================================================================

pub const BufgLocation = struct {
    tile_x: u16,
    tile_y: u16,
    bufg_index: u8,
};

/// Get BUFG tile locations for the device.
/// XC7A35T has BUFGs at the center column.
pub fn getBufgLocations(device: DeviceId) []const BufgLocation {
    return switch (device) {
        .xc7a35t => &xc7a35t_bufg_locations,
        .xc7a100t => &xc7a100t_bufg_locations,
    };
}

const xc7a35t_bufg_locations = [_]BufgLocation{
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 0 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 1 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 2 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 3 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 4 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 5 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 6 },
    .{ .tile_x = 32, .tile_y = 0, .bufg_index = 7 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 8 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 9 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 10 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 11 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 12 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 13 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 14 },
    .{ .tile_x = 32, .tile_y = 100, .bufg_index = 15 },
};

// XC7A100T BUFG locations — real values from prjxray-db tilegrid.json
// CLK_BUFG_BOT_R_X78Y100 has 16 BUFGs (0-15)
// CLK_BUFG_TOP_R_X78Y105 has 16 BUFGs (16-31)
const xc7a100t_bufg_locations = [_]BufgLocation{
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 0 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 1 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 2 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 3 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 4 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 5 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 6 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 7 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 8 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 9 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 10 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 11 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 12 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 13 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 14 },
    .{ .tile_x = 78, .tile_y = 100, .bufg_index = 15 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 16 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 17 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 18 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 19 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 20 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 21 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 22 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 23 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 24 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 25 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 26 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 27 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 28 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 29 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 30 },
    .{ .tile_x = 78, .tile_y = 105, .bufg_index = 31 },
};

// =============================================================================
// Frame Address Encoding
// =============================================================================

/// Encode a Xilinx 7-series frame address.
///
/// Format: [25:23]=block_type, [22]=top/bot, [21:17]=row, [16:7]=col, [6:0]=minor
pub fn encodeFrameAddr(block_type: u3, top_bot: u1, row: u5, col: u10, minor: u7) u32 {
    return (@as(u32, block_type) << 23) |
        (@as(u32, top_bot) << 22) |
        (@as(u32, row) << 17) |
        (@as(u32, col) << 7) |
        @as(u32, minor);
}

/// Decode a frame address into components.
pub const FrameAddrComponents = struct {
    block_type: u3,
    top_bot: u1,
    row: u5,
    col: u10,
    minor: u7,
};

pub fn decodeFrameAddr(addr: u32) FrameAddrComponents {
    return .{
        .block_type = @intCast((addr >> 23) & 0x7),
        .top_bot = @intCast((addr >> 22) & 0x1),
        .row = @intCast((addr >> 17) & 0x1F),
        .col = @intCast((addr >> 7) & 0x3FF),
        .minor = @intCast(addr & 0x7F),
    };
}

// =============================================================================
// Column Type -> Frame Count Mapping
// =============================================================================

/// Number of minor frames per column type in 7-series
pub const ColumnFrameCount = struct {
    clb: u8 = 36,
    bram: u8 = 28,
    bram_content: u8 = 128,
    dsp: u8 = 28,
    io: u8 = 42,
    clk: u8 = 30,
};

pub fn getColumnFrameCount() ColumnFrameCount {
    return .{};
}

// =============================================================================
// CLB Column Layout
// =============================================================================

/// Get the column X coordinates of CLB tiles for a device.
pub fn getClbColumns(device: DeviceId) []const u16 {
    return switch (device) {
        .xc7a35t => &xc7a35t_clb_cols,
        .xc7a100t => &xc7a100t_clb_cols,
    };
}

// XC7A35T CLB column X coordinates (representative — real values from tilegrid)
const xc7a35t_clb_cols = [_]u16{
    2,  4,  6,  8,  10, 12, 14, 16,
    18, 20, 22, 24, 26, 28,
    34, 36, 38, 40, 42, 44, 46, 48,
    50, 52, 54, 56, 58, 60,
};

// XC7A100T CLB column X coordinates — real values from prjxray-db tilegrid.json
const xc7a100t_clb_cols = [_]u16{
    2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17,
    19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    32, 33, 34, 36, 37, 39, 40, 41, 42, 43,
    45, 46, 47, 49, 50, 52, 53, 54, 55,
};

// =============================================================================
// Tile Naming
// =============================================================================

/// Generate tile name from coordinates and type (e.g., "CLBLL_L_X2Y148")
pub fn tileName(buf: []u8, tile_type: TileType, x: u16, y: u16) []const u8 {
    const type_str = tileTypeString(tile_type);
    const result = std.fmt.bufPrint(buf, "{s}_X{d}Y{d}", .{ type_str, x, y }) catch return "";
    return result;
}

fn tileTypeString(tt: TileType) []const u8 {
    return switch (tt) {
        .CLBLL_L => "CLBLL_L",
        .CLBLL_R => "CLBLL_R",
        .CLBLM_L => "CLBLM_L",
        .CLBLM_R => "CLBLM_R",
        .INT_L => "INT_L",
        .INT_R => "INT_R",
        .LIOB33 => "LIOB33",
        .RIOB33 => "RIOB33",
        .LIOI3 => "LIOI3",
        .RIOI3 => "RIOI3",
        .IO_INT_INTERFACE_L => "IO_INT_INTERFACE_L",
        .IO_INT_INTERFACE_R => "IO_INT_INTERFACE_R",
        .CLK_BUFG_BOT_R => "CLK_BUFG_BOT_R",
        .CLK_BUFG_TOP_R => "CLK_BUFG_TOP_R",
        .CLK_BUFG_REBUF => "CLK_BUFG_REBUF",
        .CLK_HROW_TOP_R => "CLK_HROW_TOP_R",
        .CLK_HROW_BOT_R => "CLK_HROW_BOT_R",
        .HCLK_L => "HCLK_L",
        .HCLK_R => "HCLK_R",
        .HCLK_CMT => "HCLK_CMT",
        .HCLK_CMT_L => "HCLK_CMT_L",
        .BRAM_L => "BRAM_L",
        .BRAM_R => "BRAM_R",
        .DSP_L => "DSP_L",
        .DSP_R => "DSP_R",
        .OTHER => "OTHER",
    };
}

// =============================================================================
// Tests
// =============================================================================

test "device params XC7A35T" {
    const params = getDeviceParams(.xc7a35t);
    try std.testing.expectEqual(@as(u32, 0x0362D093), params.idcode);
    try std.testing.expectEqual(@as(u32, 16620), params.frame_count);
    try std.testing.expectEqual(@as(u32, 101), params.frame_words);
    try std.testing.expectEqual(@as(u32, 5200), params.num_slices);
    try std.testing.expectEqual(@as(u8, 32), params.num_bufg);
}

test "device params XC7A100T" {
    const params = getDeviceParams(.xc7a100t);
    try std.testing.expectEqual(@as(u32, 0x03631093), params.idcode);
    try std.testing.expectEqual(@as(u32, 9448), params.frame_count);
}

test "pin lookup Arty A7" {
    const clk_pin = getPinLocation(.xc7a35t, "E3");
    try std.testing.expect(clk_pin != null);
    try std.testing.expectEqualStrings("IOB_X0Y148", clk_pin.?.iob_site);

    const led0 = getPinLocation(.xc7a35t, "R5");
    try std.testing.expect(led0 != null);
    try std.testing.expectEqualStrings("IOB_X1Y40", led0.?.iob_site);

    const rst = getPinLocation(.xc7a35t, "C12");
    try std.testing.expect(rst != null);

    // Unknown pin
    const unknown = getPinLocation(.xc7a35t, "ZZ99");
    try std.testing.expect(unknown == null);
}

test "pin lookup QMTECH" {
    // U22 = clock 50MHz → LIOB33_X0Y25, IOB_X0Y26
    const clk_pin = getPinLocation(.xc7a100t, "U22");
    try std.testing.expect(clk_pin != null);
    try std.testing.expectEqual(@as(u16, 0), clk_pin.?.tile_x);
    try std.testing.expectEqual(@as(u16, 25), clk_pin.?.tile_y);

    // T23 = LED D6 → LIOB33_X0Y51, IOB_X0Y52
    const led = getPinLocation(.xc7a100t, "T23");
    try std.testing.expect(led != null);
    try std.testing.expectEqual(@as(u16, 0), led.?.tile_x);
    try std.testing.expectEqual(@as(u16, 51), led.?.tile_y);

    // M22 = old LED
    const m22 = getPinLocation(.xc7a100t, "M22");
    try std.testing.expect(m22 != null);
    try std.testing.expectEqual(@as(u16, 0), m22.?.tile_x);
    try std.testing.expectEqual(@as(u16, 75), m22.?.tile_y);

    // Unknown pin
    const unknown = getPinLocation(.xc7a100t, "ZZ99");
    try std.testing.expect(unknown == null);
}

test "frame address encoding" {
    // CLB block_type=0, top half, row=2, col=5, minor=3
    const addr = encodeFrameAddr(0, 0, 2, 5, 3);
    const decoded = decodeFrameAddr(addr);
    try std.testing.expectEqual(@as(u3, 0), decoded.block_type);
    try std.testing.expectEqual(@as(u1, 0), decoded.top_bot);
    try std.testing.expectEqual(@as(u5, 2), decoded.row);
    try std.testing.expectEqual(@as(u10, 5), decoded.col);
    try std.testing.expectEqual(@as(u7, 3), decoded.minor);
}

test "frame address roundtrip" {
    // Test various addresses
    const test_cases = [_]struct { bt: u3, tb: u1, row: u5, col: u10, minor: u7 }{
        .{ .bt = 0, .tb = 0, .row = 0, .col = 0, .minor = 0 },
        .{ .bt = 0, .tb = 1, .row = 3, .col = 10, .minor = 35 },
        .{ .bt = 1, .tb = 0, .row = 15, .col = 100, .minor = 127 },
        .{ .bt = 2, .tb = 1, .row = 31, .col = 511, .minor = 63 },
    };

    for (test_cases) |tc| {
        const addr = encodeFrameAddr(tc.bt, tc.tb, tc.row, tc.col, tc.minor);
        const dec = decodeFrameAddr(addr);
        try std.testing.expectEqual(tc.bt, dec.block_type);
        try std.testing.expectEqual(tc.tb, dec.top_bot);
        try std.testing.expectEqual(tc.row, dec.row);
        try std.testing.expectEqual(tc.col, dec.col);
        try std.testing.expectEqual(tc.minor, dec.minor);
    }
}

test "tile naming" {
    var buf: [64]u8 = undefined;

    const name1 = tileName(&buf, .CLBLL_L, 2, 148);
    try std.testing.expectEqualStrings("CLBLL_L_X2Y148", name1);
}

test "CLB columns exist" {
    const cols = getClbColumns(.xc7a35t);
    try std.testing.expectEqual(@as(usize, 28), cols.len);

    const cols100 = getClbColumns(.xc7a100t);
    try std.testing.expectEqual(@as(usize, 45), cols100.len);
    // First columns should be 2,3,4,5 (real from tilegrid)
    try std.testing.expectEqual(@as(u16, 2), cols100[0]);
    try std.testing.expectEqual(@as(u16, 3), cols100[1]);
}

test "BUFG locations" {
    const bufgs = getBufgLocations(.xc7a35t);
    try std.testing.expectEqual(@as(usize, 16), bufgs.len);
}

test "column frame counts" {
    const fc = getColumnFrameCount();
    try std.testing.expectEqual(@as(u8, 36), fc.clb);
    try std.testing.expectEqual(@as(u8, 128), fc.bram_content);
}
