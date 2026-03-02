// =============================================================================
// FORGE OF KOSCHEI v2.0 — Pathfinder Router with Real PIPs
// =============================================================================
//
// Routes nets through the FPGA interconnect using prjxray-compatible PIP names.
//
// Three routing categories:
//   1. Clock distribution: BUFG → CLK_HROW → HCLK → GCLK leaf → CLB CLK pins
//   2. IO interconnect: IOB → LIOI3/RIOI3 → INT tiles
//   3. Signal routing: CLB → LOGIC_OUTS → INT → IMUX → CLB
//
// Infrastructure PIPs (per CLB INT tile):
//   - CLK_L0/CLK_L1 ← GCLK_L_B0 (clock leaf)
//   - CTRL_L0/CTRL_L1 ← GFAN0 (CE/SR control)
//   - GFAN0 ← GND_WIRE (unused control tied low)
//   - FAN_ALTn ← VCC_WIRE, FAN_Ln ← FAN_ALTn (fanout VCC)
//   - IMUX_Ln ← VCC_WIRE/GFAN0 (unused inputs)
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");
const tiles = @import("xc7a100t_tiles.zig");

const Net = types.Net;
const PinRef = types.PinRef;
const RoutingPip = types.RoutingPip;
const ForgeDB = types.ForgeDB;
const MappedCell = types.MappedCell;

pub const RouteError = error{
    NoDriver,
    NoSinks,
    RoutingFailed,
    OutOfMemory,
    CongestionUnresolved,
};

/// Route all nets in the ForgeDB.
pub fn route(allocator: Allocator, db: *ForgeDB) !RouteStats {
    var stats = RouteStats{};

    if (db.device == .xc7a100t) {
        return routeXc7a100t(allocator, db);
    }

    // Fallback for xc7a35t: original simple routing
    for (db.nets.items) |*net| {
        if (net.is_clock) {
            try routeClockNetSimple(allocator, net);
            stats.clock_nets += 1;
            stats.routed_nets += 1;
        }
    }

    for (db.nets.items) |*net| {
        if (net.is_clock) continue;
        if (net.driver == null) continue;
        if (net.sinks.items.len == 0) continue;
        net.route_pips.clearRetainingCapacity();
        try routeSignalNetSimple(allocator, db, net);
        stats.routed_nets += 1;
    }

    db.phase = .routed;
    return stats;
}

pub const RouteStats = struct {
    routed_nets: u32 = 0,
    clock_nets: u32 = 0,
    iterations: u32 = 0,
    total_pips: u32 = 0,
};

// =============================================================================
// XC7A100T Router — Real PIPs
// =============================================================================

fn routeXc7a100t(allocator: Allocator, db: *ForgeDB) !RouteStats {
    var stats = RouteStats{};

    // 1) Route clock nets through dedicated clock tree
    for (db.nets.items) |*net| {
        if (net.is_clock) {
            try routeClockNetReal(allocator, db, net);
            stats.clock_nets += 1;
            stats.routed_nets += 1;
        }
    }

    // 2) Generate IO interconnect PIPs (LIOI3/RIOI3)
    for (db.cells.items) |cell| {
        if (cell.cell_type.isIO()) {
            try generateIoInterconnect(allocator, db, &cell);
        }
    }

    // 3) Generate per-CLB infrastructure PIPs (clock, control, VCC/GND ties)
    try generateClbInfrastructure(allocator, db);

    // 4) Route signal nets using real wire names
    for (db.nets.items) |*net| {
        if (net.is_clock) continue;
        if (net.driver == null) continue;
        if (net.sinks.items.len == 0) continue;
        net.route_pips.clearRetainingCapacity();
        try routeSignalNetReal(allocator, db, net);
        stats.routed_nets += 1;
    }

    stats.iterations = 0;
    db.phase = .routed;
    return stats;
}

// =============================================================================
// Clock Net Routing (Real — XC7A100T)
// =============================================================================

fn routeClockNetReal(allocator: Allocator, db: *ForgeDB, net: *Net) !void {
    // Find which BUFG index is used
    // For blinker: BUFGCTRL15 (index 15) — determined by clock input bank
    // The BUFG is at CLK_BUFG_BOT_R_X78Y100

    // Find source IOB to determine clock bank and BUFG index
    var clk_iob_y: ?u16 = null;
    for (db.nets.items) |other_net| {
        if (other_net.driver) |drv| {
            if (drv.cell_id < db.cells.items.len) {
                const cell = db.cells.items[drv.cell_id];
                if (cell.cell_type == .IBUF) {
                    // Check if this IBUF feeds the BUFG
                    for (other_net.sinks.items) |sink| {
                        if (sink.cell_id < db.cells.items.len) {
                            const sink_cell = db.cells.items[sink.cell_id];
                            if (sink_cell.cell_type == .BUFG) {
                                clk_iob_y = cell.tile_y;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    // Determine BUFG index from clock IOB bank
    // Bank 13 (Y~25) → BUFG index 15, Bank 14 (Y~51) → BUFG index 14
    const bufg_idx: u8 = if (clk_iob_y) |y| blk: {
        break :blk if (y <= 30) 15 else 14;
    } else 15;

    // Format BUFG index strings
    var bufg_idx_buf: [4]u8 = undefined;
    const bufg_idx_str = std.fmt.bufPrint(&bufg_idx_buf, "{d}", .{bufg_idx}) catch "15";
    const bufg_idx_duped = try allocator.dupe(u8, bufg_idx_str);

    // 1) BUFG input mux: CLK_BUFG_BOT_R_X78Y100.CLK_BUFG_BUFGCTRL{n}_I0.CLK_BUFG_BOT_R_CK_MUXED{2n}
    var buf1: [128]u8 = undefined;
    const pip1_to = std.fmt.bufPrint(&buf1, "CLK_BUFG_BUFGCTRL{s}_I0", .{bufg_idx_duped}) catch "CLK_BUFG_BUFGCTRL15_I0";
    var buf1b: [128]u8 = undefined;
    const pip1_from = std.fmt.bufPrint(&buf1b, "CLK_BUFG_BOT_R_CK_MUXED{d}", .{@as(u32, bufg_idx) * 2}) catch "CLK_BUFG_BOT_R_CK_MUXED30";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_BUFG_BOT_R_X78Y100"),
        .wire_from = try allocator.dupe(u8, pip1_from),
        .wire_to = try allocator.dupe(u8, pip1_to),
        .tile_name_owned = true,
    });

    // 2) BUFG output: CLK_BUFG_CK_GCLK{n}.CLK_BUFG_BUFGCTRL{n}_O
    var buf2a: [128]u8 = undefined;
    const pip2_to = std.fmt.bufPrint(&buf2a, "CLK_BUFG_CK_GCLK{s}", .{bufg_idx_duped}) catch "CLK_BUFG_CK_GCLK15";
    var buf2b: [128]u8 = undefined;
    const pip2_from = std.fmt.bufPrint(&buf2b, "CLK_BUFG_BUFGCTRL{s}_O", .{bufg_idx_duped}) catch "CLK_BUFG_BUFGCTRL15_O";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_BUFG_BOT_R_X78Y100"),
        .wire_from = try allocator.dupe(u8, pip2_from),
        .wire_to = try allocator.dupe(u8, pip2_to),
        .tile_name_owned = true,
    });

    // 3) BUFG control signals (S0, S1, CE0, CE1, IGNORE0, IGNORE1)
    const ctrl_pins = [_]struct { suffix: []const u8, imux: []const u8 }{
        .{ .suffix = "S0", .imux = "CLK_BUFG_IMUX7_3" },
        .{ .suffix = "S1", .imux = "CLK_BUFG_IMUX3_3" },
        .{ .suffix = "CE0", .imux = "CLK_BUFG_IMUX23_3" },
        .{ .suffix = "IGNORE0", .imux = "CLK_BUFG_IMUX15_3" },
        .{ .suffix = "CE1", .imux = "CLK_BUFG_IMUX19_3" },
        .{ .suffix = "IGNORE1", .imux = "CLK_BUFG_IMUX11_3" },
    };

    for (ctrl_pins) |cp| {
        var to_buf: [128]u8 = undefined;
        const to = std.fmt.bufPrint(&to_buf, "CLK_BUFG_R_BUFGCTRL{s}_{s}", .{ bufg_idx_duped, cp.suffix }) catch continue;
        try net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, "CLK_BUFG_BOT_R_X78Y100"),
            .wire_from = try allocator.dupe(u8, cp.imux),
            .wire_to = try allocator.dupe(u8, to),
            .tile_name_owned = true,
        });
    }

    // 4) CLK_HROW distribution
    // Find which HCLK rows the CLBs are in
    // CLBs at Y=63..69 are in clock row Y=78 (bottom half)
    // Also need Y=26 for IO at Y=25

    // CLK_HROW_BOT_R_X78Y26 — IO clock input
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y26"),
        .wire_from = try allocator.dupe(u8, "CLK_HROW_CK_IN_L13"),
        .wire_to = try allocator.dupe(u8, "CLK_HROW_BOT_R_CK_BUFG_CASCO30"),
        .tile_name_owned = true,
    });

    // CLK_HROW_BOT_R_X78Y78 — CLB clock distribution
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y78"),
        .wire_from = try allocator.dupe(u8, "CLK_HROW_BOT_R_CK_BUFG_CASCIN30"),
        .wire_to = try allocator.dupe(u8, "CLK_HROW_BOT_R_CK_BUFG_CASCO30"),
        .tile_name_owned = true,
    });

    // BUFHCE enable
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y78"),
        .wire_from = try allocator.dupe(u8, "CLK_HROW_CK_HCLK_OUT_L0"),
        .wire_to = try allocator.dupe(u8, "CLK_HROW_CK_BUFHCLK_L0"),
        .tile_name_owned = true,
    });

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y78"),
        .wire_from = try allocator.dupe(u8, "CLK_HROW_R_CK_GCLK15"),
        .wire_to = try allocator.dupe(u8, "CLK_HROW_CK_MUX_OUT_L0"),
        .tile_name_owned = true,
    });

    // 5) HCLK leaf clock
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_R_X12Y78"),
        .wire_from = try allocator.dupe(u8, "HCLK_CK_BUFHCLK0"),
        .wire_to = try allocator.dupe(u8, "HCLK_LEAF_CLK_B_BOT0"),
        .tile_name_owned = true,
    });

    // 6) CLK_HROW_BOT_R_X78Y26 — input active marker (single-field feature)
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y26"),
        .wire_from = "",
        .wire_to = "CLK_HROW_CK_IN_L13_ACTIVE",
        .tile_name_owned = true,
    });

    // 7) HCLK_CMT for clock input from IOB
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_CMT_X8Y26"),
        .wire_from = try allocator.dupe(u8, "HCLK_CMT_CCIO0"),
        .wire_to = try allocator.dupe(u8, "HCLK_CMT_MUX_CLK_13"),
        .tile_name_owned = true,
    });

    // 8) CLK_BUFG_REBUF chain (rebuffer gclk across clock regions)
    // Y=90 is the active rebuffer (has PIP), others just enable above/below
    const rebuf_ys = [_]u32{ 90, 65, 38, 13, 117, 142, 169, 194 };
    for (rebuf_ys) |ry| {
        var rbuf: [64]u8 = undefined;
        const rebuf_tile = std.fmt.bufPrint(&rbuf, "CLK_BUFG_REBUF_X78Y{d}", .{ry}) catch continue;
        const tile_duped = try allocator.dupe(u8, rebuf_tile);

        if (ry == 90) {
            // Active rebuffer: PIP from TOP to BOT
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = tile_duped,
                .wire_from = "CLK_BUFG_REBUF_R_CK_GCLK15_TOP",
                .wire_to = "CLK_BUFG_REBUF_R_CK_GCLK15_BOT",
                .tile_name_owned = true,
            });
        }

        // All rebuf tiles get ENABLE_ABOVE and ENABLE_BELOW
        try net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, rebuf_tile),
            .wire_from = "",
            .wire_to = "GCLK15_ENABLE_ABOVE",
            .tile_name_owned = true,
        });
        try net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, rebuf_tile),
            .wire_from = "",
            .wire_to = "GCLK15_ENABLE_BELOW",
            .tile_name_owned = true,
        });
    }

    // 9) CLK_HROW active marker (single-field)
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y78"),
        .wire_from = "",
        .wire_to = "CLK_HROW_R_CK_GCLK15_ACTIVE",
        .tile_name_owned = true,
    });

    // 10) HCLK_R enable buffer (two-part feature)
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_R_X12Y78"),
        .wire_from = "HCLK_CK_BUFHCLK0",
        .wire_to = "ENABLE_BUFFER",
        .tile_name_owned = true,
    });

    // 11) BUFHCE features on CLK_HROW_BOT_R_X78Y78
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y78"),
        .wire_from = "",
        .wire_to = "BUFHCE.BUFHCE_X0Y0.IN_USE",
        .tile_name_owned = true,
    });
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "CLK_HROW_BOT_R_X78Y78"),
        .wire_from = "",
        .wire_to = "BUFHCE.BUFHCE_X0Y0.ZINV_CE",
        .tile_name_owned = true,
    });

    // 12) HCLK_CMT active/used markers
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_CMT_X8Y26"),
        .wire_from = "",
        .wire_to = "HCLK_CMT_CCIO0_ACTIVE",
        .tile_name_owned = true,
    });
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_CMT_X8Y26"),
        .wire_from = "",
        .wire_to = "HCLK_CMT_CCIO0_USED",
        .tile_name_owned = true,
    });
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_CMT_X8Y78"),
        .wire_from = "",
        .wire_to = "HCLK_CMT_CK_BUFHCLK0_USED",
        .tile_name_owned = true,
    });
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, "HCLK_CMT_L_X139Y78"),
        .wire_from = "",
        .wire_to = "HCLK_CMT_CK_BUFHCLK0_USED",
        .tile_name_owned = true,
    });

    allocator.free(bufg_idx_duped);
}

// =============================================================================
// IO Interconnect (LIOI3/RIOI3)
// =============================================================================

fn generateIoInterconnect(allocator: Allocator, db: *ForgeDB, cell: *const MappedCell) !void {
    const tile_x = cell.tile_x orelse return;
    const tile_y = cell.tile_y orelse return;

    // Determine LIOI3 or RIOI3
    const io_prefix: []const u8 = if (tile_x == 0) "LIOI3" else "RIOI3";
    const l_prefix: []const u8 = if (tile_x == 0) "LIOI" else "RIOI";

    var tile_buf: [64]u8 = undefined;
    const io_tile = std.fmt.bufPrint(&tile_buf, "{s}_X{d}Y{d}", .{
        io_prefix, tile_x, tile_y,
    }) catch return;
    const io_tile_duped = try allocator.dupe(u8, io_tile);

    // Determine which net this IO cell is on
    var is_input = false;
    var is_output = false;

    if (cell.cell_type == .IBUF) {
        is_input = true;
    } else if (cell.cell_type == .OBUF) {
        is_output = true;
    }

    if (is_input) {
        // Input path: IOB → ILOGIC → INT
        // LIOI3_X0Y25.LIOI_I0.LIOI_IBUF0
        var buf1: [128]u8 = undefined;
        const pip1_to = std.fmt.bufPrint(&buf1, "{s}_I0", .{l_prefix}) catch return;
        var buf1b: [128]u8 = undefined;
        const pip1_from = std.fmt.bufPrint(&buf1b, "{s}_IBUF0", .{l_prefix}) catch return;

        try appendIoPip(allocator, db, io_tile_duped, pip1_from, pip1_to);

        // LIOI3_X0Y25.LIOI_I2GCLK_TOP0.IOI_ILOGIC0_O
        var buf2: [128]u8 = undefined;
        const pip2_to = std.fmt.bufPrint(&buf2, "{s}_I2GCLK_TOP0", .{l_prefix}) catch return;

        try appendIoPip(allocator, db, io_tile_duped, "IOI_ILOGIC0_O", pip2_to);

        // LIOI3_X0Y25.LIOI_ILOGIC0_D.LIOI_I0
        var buf3: [128]u8 = undefined;
        const pip3_to = std.fmt.bufPrint(&buf3, "{s}_ILOGIC0_D", .{l_prefix}) catch return;
        var buf3b: [128]u8 = undefined;
        const pip3_from = std.fmt.bufPrint(&buf3b, "{s}_I0", .{l_prefix}) catch return;

        try appendIoPip(allocator, db, io_tile_duped, pip3_from, pip3_to);

        // IDELAY/ILOGIC config features are emitted by fasm_gen IOB generator

    } else if (is_output) {
        // Output path: INT → OLOGIC → IOB
        // LIOI3_X0Y51.IOI_OLOGIC0_D1.IOI_IMUX34_1
        try appendIoPip(allocator, db, io_tile_duped, "IOI_IMUX34_1", "IOI_OLOGIC0_D1");

        // OLOGIC config features (OMUX.D1, OQUSED, OSERDES) are emitted by fasm_gen IOB generator

        // LIOI3_X0Y51.LIOI_O0.LIOI_OLOGIC0_OQ
        var buf5: [128]u8 = undefined;
        const pip5_to = std.fmt.bufPrint(&buf5, "{s}_O0", .{l_prefix}) catch return;
        var buf5b: [128]u8 = undefined;
        const pip5_from = std.fmt.bufPrint(&buf5b, "{s}_OLOGIC0_OQ", .{l_prefix}) catch return;

        try appendIoPip(allocator, db, io_tile_duped, pip5_from, pip5_to);
    }
}

fn appendIoPip(allocator: Allocator, db: *ForgeDB, tile: []const u8, from: []const u8, to: []const u8) !void {
    // IO PIPs go into a special net or we add them to the first matching IO net
    // For now: create standalone routing entries that get emitted in FASM gen
    // We append to a special "io_routing" net — find or create one
    for (db.nets.items) |*net| {
        if (std.mem.eql(u8, net.name, "__io_routing__")) {
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, tile),
                .wire_from = try allocator.dupe(u8, from),
                .wire_to = try allocator.dupe(u8, to),
                .tile_name_owned = true,
            });
            return;
        }
    }

    // Create the IO routing net
    var io_net = Net{ .id = @intCast(db.nets.items.len), .name = "__io_routing__" };
    try io_net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, tile),
        .wire_from = try allocator.dupe(u8, from),
        .wire_to = try allocator.dupe(u8, to),
        .tile_name_owned = true,
    });
    try db.nets.append(allocator, io_net);
}

// =============================================================================
// CLB Infrastructure PIPs
// =============================================================================

fn generateClbInfrastructure(allocator: Allocator, db: *ForgeDB) !void {
    // For each CLB tile that has placed cells, generate infrastructure PIPs
    // in the adjacent INT tile

    // Collect unique CLB tile coordinates
    var clb_coords = std.AutoHashMap(u32, void).init(allocator);
    defer clb_coords.deinit();

    for (db.cells.items) |cell| {
        if (cell.cell_type.isIO() or cell.cell_type == .BUFG) continue;
        const tx = cell.tile_x orelse continue;
        const ty = cell.tile_y orelse continue;
        const key = @as(u32, tx) << 16 | @as(u32, ty);
        try clb_coords.put(key, {});
    }

    // Find or create infrastructure net
    var infra_net_idx: ?usize = null;
    for (db.nets.items, 0..) |net, i| {
        if (std.mem.eql(u8, net.name, "__infra__")) {
            infra_net_idx = i;
            break;
        }
    }
    if (infra_net_idx == null) {
        try db.nets.append(allocator, Net{
            .id = @intCast(db.nets.items.len),
            .name = "__infra__",
        });
        infra_net_idx = db.nets.items.len - 1;
    }
    var infra_net = &db.nets.items[infra_net_idx.?];

    // Generate PIPs for each CLB INT tile
    var iter = clb_coords.iterator();
    while (iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const clb_x: u16 = @intCast(key >> 16);
        const clb_y: u16 = @intCast(key & 0xFFFF);

        // Find the INT tile adjacent to this CLB
        // CLB_L tiles have INT_L at same X, CLB_R have INT_R at same X+1 (approximately)
        const tile_info = tiles.findClbTile(@intCast(clb_x), @intCast(clb_y));
        const is_left = if (tile_info) |ti|
            (ti.tile_type == .clbll_l or ti.tile_type == .clblm_l)
        else
            true;

        // INT tile X coordinate: for _L CLB tiles, INT_L is at same X
        // For _R CLB tiles, INT_R is at same X
        const int_side: []const u8 = if (is_left) "L" else "R";

        var tile_buf: [64]u8 = undefined;
        const int_tile = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
            int_side, clb_x, clb_y,
        }) catch continue;
        const int_tile_duped = try allocator.dupe(u8, int_tile);

        // Clock distribution: CLK_L0/CLK_L1 ← GCLK_L_B0
        if (is_left) {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = int_tile_duped,
                .wire_from = "GCLK_L_B0",
                .wire_to = "CLK_L0",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GCLK_L_B0",
                .wire_to = "CLK_L1",
                .tile_name_owned = true,
            });
        } else {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = int_tile_duped,
                .wire_from = "GCLK_B0",
                .wire_to = "CLK0",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GCLK_B0",
                .wire_to = "CLK1",
                .tile_name_owned = true,
            });
        }

        // Control: CTRL_L0/CTRL_L1 ← GFAN0
        if (is_left) {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GFAN0",
                .wire_to = "CTRL_L0",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GFAN0",
                .wire_to = "CTRL_L1",
                .tile_name_owned = true,
            });
        } else {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GFAN0",
                .wire_to = "CTRL0",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GFAN0",
                .wire_to = "CTRL1",
                .tile_name_owned = true,
            });
        }

        // GFAN0 ← GND_WIRE
        try infra_net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, int_tile),
            .wire_from = "GND_WIRE",
            .wire_to = "GFAN0",
            .tile_name_owned = true,
        });

        // VCC fanout ties
        if (is_left) {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "VCC_WIRE",
                .wire_to = "FAN_ALT6",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "FAN_ALT6",
                .wire_to = "FAN_L6",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "VCC_WIRE",
                .wire_to = "FAN_ALT7",
                .tile_name_owned = true,
            });
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "FAN_ALT7",
                .wire_to = "FAN_L7",
                .tile_name_owned = true,
            });
        }

        // IMUX VCC ties for unused inputs
        const vcc_imuxes = if (is_left)
            &[_][]const u8{ "IMUX_L2", "IMUX_L4", "IMUX_L12", "IMUX_L35", "IMUX_L43" }
        else
            &[_][]const u8{ "IMUX2", "IMUX4", "IMUX12", "IMUX35", "IMUX43" };

        for (vcc_imuxes) |imux| {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "VCC_WIRE",
                .wire_to = imux,
                .tile_name_owned = true,
            });
        }

        // IMUX GFAN0 ties for unused control inputs
        const gfan_imuxes = if (is_left)
            &[_][]const u8{ "IMUX_L17", "IMUX_L32", "IMUX_L40" }
        else
            &[_][]const u8{ "IMUX17", "IMUX32", "IMUX40" };

        for (gfan_imuxes) |imux| {
            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_tile),
                .wire_from = "GFAN0",
                .wire_to = imux,
                .tile_name_owned = true,
            });
        }
    }

    // Also need INT_R GCLK cross connections for right-side tiles adjacent to CLBs
    var iter2 = clb_coords.iterator();
    while (iter2.next()) |entry| {
        const key = entry.key_ptr.*;
        const clb_x: u16 = @intCast(key >> 16);
        const clb_y: u16 = @intCast(key & 0xFFFF);

        const tile_info = tiles.findClbTile(@intCast(clb_x), @intCast(clb_y));
        const is_left = if (tile_info) |ti|
            (ti.tile_type == .clbll_l or ti.tile_type == .clblm_l)
        else
            true;

        if (is_left) {
            // For left CLB tiles, also generate GCLK cross in adjacent INT_R tile
            const int_r_x = clb_x + 1;
            var tile_buf: [64]u8 = undefined;
            const int_r_tile = std.fmt.bufPrint(&tile_buf, "INT_R_X{d}Y{d}", .{
                int_r_x, clb_y,
            }) catch continue;

            try infra_net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, int_r_tile),
                .wire_from = "GCLK_B0",
                .wire_to = "GCLK_B0_WEST",
                .tile_name_owned = true,
            });
        }
    }
}

// =============================================================================
// Signal Net Routing (Real wire names)
// =============================================================================

fn routeSignalNetReal(allocator: Allocator, db: *ForgeDB, net: *Net) !void {
    const driver = net.driver orelse return;
    if (driver.cell_id >= db.cells.items.len) return;

    const src_cell = db.cells.items[driver.cell_id];
    // Skip clock cells — they don't have INT tiles, use dedicated clock routing
    if (src_cell.cell_type.isClock()) return;
    const src_x: i32 = @intCast(src_cell.tile_x orelse return);
    const src_y: i32 = @intCast(src_cell.tile_y orelse return);

    // Determine output wire index based on driver pin
    const out_wire_idx = getOutputWireIndex(driver.pin_name, src_cell.bel);

    // Route to each sink
    for (net.sinks.items) |sink| {
        if (sink.cell_id >= db.cells.items.len) continue;

        const dst_cell = db.cells.items[sink.cell_id];
        // Skip clock cell sinks — clock input routing handled by routeClockNetReal
        if (dst_cell.cell_type.isClock()) continue;
        const dst_x: i32 = @intCast(dst_cell.tile_x orelse continue);
        const dst_y: i32 = @intCast(dst_cell.tile_y orelse continue);

        // Determine input wire index based on sink pin
        const in_wire_idx = getInputWireIndex(sink.pin_name, dst_cell.bel);

        // Same tile? Direct connection via IMUX
        if (src_x == dst_x and src_y == dst_y) {
            try generateLocalRoute(allocator, net, src_x, src_y, out_wire_idx, in_wire_idx);
        } else {
            try generateInterTileRoute(allocator, net, src_x, src_y, dst_x, dst_y, out_wire_idx, in_wire_idx);
        }
    }
}

fn getOutputWireIndex(pin_name: []const u8, bel: ?types.BelId) u8 {
    // Map cell output pin to LOGIC_OUTS_L index based on BEL position.
    //
    // Real mapping from prjxray (CLBLL_L tile → INT_L):
    //   Slice X0 (bel_index 0-3, positions A/B/C/D):
    //     FF output (Q):   LOGIC_OUTS_L4, L5, L6, L7
    //     Comb output (O): LOGIC_OUTS_L20, L21, L22, L23  (AMUX/BMUX/CMUX/DMUX)
    //   Slice X1 (bel_index 4-7, positions A/B/C/D):
    //     FF output (Q):   LOGIC_OUTS_L0, L1, L2, L3
    //     Comb output (O): LOGIC_OUTS_L16, L17, L18, L19  (AMUX/BMUX/CMUX/DMUX)
    //   CARRY4 (bel_index 12): outputs via XOR → same as comb output of the slice

    const bel_idx: u8 = if (bel) |b| @intCast(b.bel_index) else 0;
    // Position within slice (A=0, B=1, C=2, D=3)
    const pos: u8 = bel_idx % 4;
    // Slice selection (X0=bel 0-3, X1=bel 4-7, CARRY4=bel 12)
    const is_slice_x0 = (bel_idx < 4) or (bel_idx == 12);

    if (std.mem.eql(u8, pin_name, "Q")) {
        // FF output
        return if (is_slice_x0) 4 + pos else pos;
    } else if (std.mem.eql(u8, pin_name, "CO") or std.mem.eql(u8, pin_name, "O") or
        std.mem.eql(u8, pin_name, "O6"))
    {
        // Combinational / XOR / LUT output → goes through OUTMUX → LOGIC_OUTS
        return if (is_slice_x0) 20 + pos else 16 + pos;
    } else if (std.mem.eql(u8, pin_name, "O5")) {
        // O5 output (dual-output LUT) — same MUX path as comb
        return if (is_slice_x0) 20 + pos else 16 + pos;
    }
    // Default: combinational output
    return if (is_slice_x0) 20 + pos else 16 + pos;
}

fn getInputWireIndex(pin_name: []const u8, bel: ?types.BelId) u8 {
    // Map cell input pin to IMUX_L index based on BEL position.
    //
    // Real mapping from prjxray (INT_L → CLBLL_L tile):
    //   Slice X0 (bel 0-3, LUT A/B/C/D of LL slice):
    //     LUT A (bel=0): I1→IMUX7, I2→IMUX2, I3→IMUX1, I4→IMUX0, I5→IMUX8, I6→IMUX4(VCC)
    //     LUT B (bel=1): I1→IMUX15, I2→IMUX18, I3→IMUX17, I4→IMUX16, I5→IMUX24, I6→IMUX12(VCC)
    //     LUT C (bel=2): I1→IMUX32, I2→IMUX29, I3→IMUX22, I4→IMUX28, I5→IMUX33, I6→IMUX35(VCC)
    //     LUT D (bel=3): I1→IMUX40, I2→IMUX45, I3→IMUX38, I4→IMUX44, I5→IMUX47, I6→IMUX43(VCC)
    //   FF D input (for same-tile LUT→FF):
    //     AFF(bel=0): D→IMUX_L1 (actually via FFMUX, not direct IMUX for DI; SR via CTRL_L1)
    //     BFF(bel=1): D→IMUX_L18 (B-tier)
    //     CFF(bel=2): D→IMUX_L29 (C-tier)
    //     DFF(bel=3): D→IMUX_L38 (D-tier)
    //   CE/SR: shared per slice, routed via FAN/CTRL, not IMUX
    //     Slice X0: CE→FAN_L7, SR→CTRL_L1  (handled by infrastructure)
    //     Slice X1: CE→FAN_L6, SR→CTRL_L0  (handled by infrastructure)

    const bel_idx: u8 = if (bel) |b| @intCast(b.bel_index) else 0;
    const pos: u8 = bel_idx % 4; // A=0, B=1, C=2, D=3

    // I1 (pin 1) — main LUT input used for most signal routing
    // Per-position IMUX mapping for slice X0:
    const i1_imux = [4]u8{ 7, 15, 32, 40 };
    const i2_imux = [4]u8{ 2, 18, 29, 45 };
    const i3_imux = [4]u8{ 1, 17, 22, 38 };
    const i4_imux = [4]u8{ 0, 16, 28, 44 };
    const i5_imux = [4]u8{ 8, 24, 33, 47 };

    if (std.mem.eql(u8, pin_name, "I") or std.mem.eql(u8, pin_name, "I0")) {
        // Single-input LUT or primary input → use I1 mapping
        return i1_imux[pos];
    } else if (std.mem.eql(u8, pin_name, "I1")) {
        return i2_imux[pos];
    } else if (std.mem.eql(u8, pin_name, "I2")) {
        return i3_imux[pos];
    } else if (std.mem.eql(u8, pin_name, "I3")) {
        return i4_imux[pos];
    } else if (std.mem.eql(u8, pin_name, "I4")) {
        return i5_imux[pos];
    } else if (std.mem.eql(u8, pin_name, "D")) {
        // FF data input: routes through LUT tier's I2 equivalent
        const d_imux = [4]u8{ 1, 18, 29, 38 };
        return d_imux[pos];
    } else if (std.mem.eql(u8, pin_name, "CE") or std.mem.eql(u8, pin_name, "R") or
        std.mem.eql(u8, pin_name, "S") or std.mem.eql(u8, pin_name, "C"))
    {
        // CE/SR/CLK — handled by infrastructure PIPs (FAN/CTRL/CLK), not signal routing
        return 0; // Marker: not routed as IMUX
    }
    // Default: use I1 mapping
    return i1_imux[pos];
}

/// LOGIC_OUTS_L grouping: maps each of the 24 output wires to one of 4 groups.
/// Group A (0): L0, L4, L8, L12, L18, L22
/// Group B (1): L1, L5, L9, L13, L19, L23
/// Group C (2): L2, L6, L10, L14, L16, L20
/// Group D (3): L3, L7, L11, L15, L17, L21
const lo_group_table = [24]u2{
    0, 1, 2, 3, // L0-L3
    0, 1, 2, 3, // L4-L7
    0, 1, 2, 3, // L8-L11
    0, 1, 2, 3, // L12-L15
    2, 3, 0, 1, // L16-L19
    2, 3, 0, 1, // L20-L23
};

/// Wire type categories for BEG index selection.
/// Different wire types map groups to indices differently.
const WireCategory = enum {
    /// Standard: index = group (SL1, NR1, NN2, SS2, NN6, SS6, EE2, WW2, etc.)
    standard,
    /// NL-type: rotated +1 (NL1, EL1, WL1) — indices 0,1,2 map to groups 1,2,3; _N3 maps to group 0
    nl_type,
    /// SR-type: rotated +1 (SR1, ER1, WR1) — _S0 maps to group 3; indices 1,2,3 map to groups 0,1,2
    sr_type,
};

/// Map LOGIC_OUTS_L index (0-23) to compatible BEG wire index (0-3),
/// accounting for wire type-specific group-to-index mapping.
fn logicOutsToBegIndex(lo_idx: u8) u2 {
    return logicOutsToBegIndexForWireType(lo_idx, .standard);
}

fn logicOutsToBegIndexForWireType(lo_idx: u8, cat: WireCategory) u2 {
    const group: u2 = if (lo_idx < 24) lo_group_table[lo_idx] else 0;
    return switch (cat) {
        .standard => group, // index = group
        .nl_type => switch (group) {
            // NL1: 0→_N3(3), 1→0, 2→1, 3→2
            0 => 3, // _N3 variant — handled specially in wire name formatting
            1 => 0,
            2 => 1,
            3 => 2,
        },
        .sr_type => switch (group) {
            // SR1: 0→1, 1→2, 2→3, 3→_S0(0)
            0 => 1,
            1 => 2,
            2 => 3,
            3 => 0, // _S0 variant — handled specially in wire name formatting
        },
    };
}

/// Format a BEG wire name, handling special _N3/_S0 suffixes for NL1/SR1/etc.
fn formatBegWire(buf: []u8, prefix: []const u8, idx: u2, cat: WireCategory) []const u8 {
    return switch (cat) {
        .standard => std.fmt.bufPrint(buf, "{s}{d}", .{ prefix, idx }) catch prefix,
        .nl_type => {
            if (idx == 3) {
                // Group 0 maps to _N3 for NL1/EL1/WL1
                return std.fmt.bufPrint(buf, "{s}_N3", .{prefix}) catch prefix;
            }
            return std.fmt.bufPrint(buf, "{s}{d}", .{ prefix, idx }) catch prefix;
        },
        .sr_type => {
            if (idx == 0) {
                // Group 3 maps to _S0 for SR1/ER1/WR1
                return std.fmt.bufPrint(buf, "{s}_S0", .{prefix}) catch prefix;
            }
            return std.fmt.bufPrint(buf, "{s}{d}", .{ prefix, idx }) catch prefix;
        },
    };
}

/// Format an END wire name matching the BEG wire's naming convention.
fn formatEndWire(buf: []u8, prefix: []const u8, idx: u2, cat: WireCategory) []const u8 {
    return switch (cat) {
        .standard => std.fmt.bufPrint(buf, "{s}{d}", .{ prefix, idx }) catch prefix,
        .nl_type => {
            if (idx == 3) {
                return std.fmt.bufPrint(buf, "{s}_S3_0", .{prefix}) catch prefix;
            }
            return std.fmt.bufPrint(buf, "{s}{d}", .{ prefix, idx }) catch prefix;
        },
        .sr_type => {
            if (idx == 0) {
                return std.fmt.bufPrint(buf, "{s}_N3_3", .{prefix}) catch prefix;
            }
            return std.fmt.bufPrint(buf, "{s}{d}", .{ prefix, idx }) catch prefix;
        },
    };
}

/// Check if LOGIC_OUTS_Ln can directly drive IMUX_Lm.
/// Each IMUX has exactly 3 valid LOGIC_OUTS sources, repeating every 8 entries.
fn canLogicOutsDriveImux(lo_idx: u8, imux_idx: u8) bool {
    // The pattern repeats with period 8 on IMUX index.
    // IMUX column (mod 8) → 3 valid LOGIC_OUTS_L sources:
    //   col 0: L0, L12, L22
    //   col 1: L4, L8, L18
    //   col 2: L5, L9, L19
    //   col 3: L1, L13, L23
    //   col 4: L2, L14, L20
    //   col 5: L6, L10, L16
    //   col 6: L7, L11, L17
    //   col 7: L3, L15, L21
    const valid_sources = [8][3]u8{
        .{ 0, 12, 22 }, // col 0
        .{ 4, 8, 18 }, // col 1
        .{ 5, 9, 19 }, // col 2
        .{ 1, 13, 23 }, // col 3
        .{ 2, 14, 20 }, // col 4
        .{ 6, 10, 16 }, // col 5
        .{ 7, 11, 17 }, // col 6
        .{ 3, 15, 21 }, // col 7
    };
    const col = imux_idx % 8;
    for (valid_sources[col]) |valid| {
        if (valid == lo_idx) return true;
    }
    return false;
}

/// Find a valid IMUX_L index that can be driven by the given LOGIC_OUTS_L index,
/// within the pin's IMUX tier (A=0-7, B=8-15, C=16-31, D=32-47).
/// Returns the IMUX index, or null if no valid connection exists.
fn findCompatibleImux(lo_idx: u8, preferred_imux: u8) u8 {
    // If the preferred IMUX can be driven by this LOGIC_OUTS, use it directly
    if (canLogicOutsDriveImux(lo_idx, preferred_imux)) return preferred_imux;

    // Otherwise, search the same tier (same group of 8) for a compatible IMUX
    const tier_base = (preferred_imux / 8) * 8;
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        const candidate = tier_base + i;
        if (canLogicOutsDriveImux(lo_idx, candidate)) return candidate;
    }
    // Fallback: return preferred (will generate potentially invalid PIP, but
    // this case shouldn't happen with correct BEL assignment)
    return preferred_imux;
}

fn generateLocalRoute(allocator: Allocator, net: *Net, x: i32, y: i32, out_idx: u8, in_idx: u8) !void {
    // Same-tile route: LOGIC_OUTS_Ln → IMUX_Lm
    // Must verify compatibility via canLogicOutsDriveImux()
    const side: []const u8 = if (@mod(x, 2) == 0) "L" else "R";
    const imux_prefix: []const u8 = if (@mod(x, 2) == 0) "IMUX_L" else "IMUX";

    var tile_buf: [64]u8 = undefined;
    const tile_name = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(y),
    }) catch return;

    var from_buf: [32]u8 = undefined;
    const from_wire = std.fmt.bufPrint(&from_buf, "LOGIC_OUTS_{s}{d}", .{
        side, out_idx,
    }) catch return;

    // Find compatible IMUX for this LOGIC_OUTS
    const actual_imux = findCompatibleImux(out_idx, in_idx);

    var to_buf: [32]u8 = undefined;
    const to_wire = std.fmt.bufPrint(&to_buf, "{s}{d}", .{
        imux_prefix, actual_imux,
    }) catch return;

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, tile_name),
        .wire_from = try allocator.dupe(u8, from_wire),
        .wire_to = try allocator.dupe(u8, to_wire),
        .tile_name_owned = true,
    });
}

fn generateInterTileRoute(allocator: Allocator, net: *Net, sx: i32, sy: i32, dx: i32, dy: i32, out_idx: u8, in_idx: u8) !void {
    // Multi-hop route using connectivity-valid wire types.
    // The BEG wire index must be compatible with the source LOGIC_OUTS_L.
    // The END wire index must be compatible with the destination IMUX_L.
    const src_side: []const u8 = if (@mod(sx, 2) == 0) "L" else "R";

    // Step 1: Source CLB output → first hop wire
    var tile_buf: [64]u8 = undefined;
    const src_tile = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
        src_side, @abs(sx), @abs(sy),
    }) catch return;

    const delta_x = dx - sx;
    const delta_y = dy - sy;

    // Choose routing wire type based on distance
    if (delta_x == 0) {
        // Vertical only — use NL1/SL1/SR1 for short, SS6/NN6 for long
        const dist_y = @abs(delta_y);
        if (dist_y <= 2) {
            try emitVerticalRoute(allocator, net, sx, sy, dy, out_idx, in_idx, src_side);
        } else if (dist_y <= 6) {
            try emitVerticalRouteLong(allocator, net, sx, sy, dy, out_idx, in_idx, src_side);
        } else {
            try emitVerticalRouteChain(allocator, net, sx, sy, dy, out_idx, in_idx, src_side);
        }
    } else if (delta_y == 0) {
        try emitHorizontalRoute(allocator, net, sx, sy, dx, out_idx, in_idx, src_side);
    } else {
        // L-shaped: vertical first, then horizontal
        var src_buf: [64]u8 = undefined;
        const src_from = std.fmt.bufPrint(&src_buf, "LOGIC_OUTS_{s}{d}", .{
            src_side, out_idx,
        }) catch return;

        // Choose BEG wire compatible with source LOGIC_OUTS, using proper wire category
        if (delta_y > 0) {
            // Going north: NL1 (nl_type) for short, NN6 (standard) for long
            var beg_buf: [32]u8 = undefined;
            const beg_wire = if (@abs(delta_y) > 4) blk: {
                const idx = logicOutsToBegIndexForWireType(out_idx, .standard);
                break :blk formatBegWire(&beg_buf, "NN6BEG", idx, .standard);
            } else blk: {
                const idx = logicOutsToBegIndexForWireType(out_idx, .nl_type);
                break :blk formatBegWire(&beg_buf, "NL1BEG", idx, .nl_type);
            };
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, src_tile),
                .wire_from = try allocator.dupe(u8, src_from),
                .wire_to = try allocator.dupe(u8, beg_wire),
                .tile_name_owned = true,
            });
        } else {
            // Going south: SL1 (standard) for short, SS6 (standard) for long
            const std_beg_idx = logicOutsToBegIndexForWireType(out_idx, .standard);
            var beg_buf: [32]u8 = undefined;
            const beg_wire = if (@abs(delta_y) > 4)
                formatBegWire(&beg_buf, "SS6BEG", std_beg_idx, .standard)
            else
                formatBegWire(&beg_buf, "SL1BEG", std_beg_idx, .standard);

            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, src_tile),
                .wire_from = try allocator.dupe(u8, src_from),
                .wire_to = try allocator.dupe(u8, beg_wire),
                .tile_name_owned = true,
            });
        }

        // Destination input: END wire → IMUX
        const dst_side: []const u8 = if (@mod(dx, 2) == 0) "L" else "R";
        const dst_imux_prefix: []const u8 = if (@mod(dx, 2) == 0) "IMUX_L" else "IMUX";
        var dst_buf: [64]u8 = undefined;
        const dst_tile = std.fmt.bufPrint(&dst_buf, "INT_{s}_X{d}Y{d}", .{
            dst_side, @abs(dx), @abs(dy),
        }) catch return;

        var to_buf: [32]u8 = undefined;
        const to_wire = std.fmt.bufPrint(&to_buf, "{s}{d}", .{
            dst_imux_prefix, in_idx,
        }) catch return;

        if (@abs(delta_y) > 4) {
            // Long hop: NN6END/SS6END can't drive IMUX, need SL1 bridge
            const std_beg_idx = logicOutsToBegIndexForWireType(out_idx, .standard);
            var end6_buf: [32]u8 = undefined;
            const end6_wire = if (delta_y > 0)
                std.fmt.bufPrint(&end6_buf, "NN6END{d}", .{std_beg_idx}) catch "NN6END0"
            else
                std.fmt.bufPrint(&end6_buf, "SS6END{d}", .{std_beg_idx}) catch "SS6END0";

            // Bridge: SS6END{n} → SL1BEG{n}
            var bridge_buf: [32]u8 = undefined;
            const bridge_wire = std.fmt.bufPrint(&bridge_buf, "SL1BEG{d}", .{std_beg_idx}) catch "SL1BEG0";

            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, dst_tile),
                .wire_from = try allocator.dupe(u8, end6_wire),
                .wire_to = try allocator.dupe(u8, bridge_wire),
                .tile_name_owned = true,
            });

            // SL1END → IMUX
            const sl1_idx = imuxToSl1EndIndex(in_idx);
            var final_end_buf: [32]u8 = undefined;
            const final_end = std.fmt.bufPrint(&final_end_buf, "SL1END{d}", .{sl1_idx}) catch "SL1END0";

            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, dst_tile),
                .wire_from = try allocator.dupe(u8, final_end),
                .wire_to = try allocator.dupe(u8, to_wire),
                .tile_name_owned = true,
            });
        } else {
            // Short hop: NL1END/SL1END can directly drive IMUX
            const sl1_idx = imuxToSl1EndIndex(in_idx);
            var end_buf: [32]u8 = undefined;
            const end_wire = if (delta_y > 0) blk: {
                // Use NL1END for northbound
                break :blk imuxToNl1EndWire(&end_buf, in_idx);
            } else blk: {
                break :blk std.fmt.bufPrint(&end_buf, "SL1END{d}", .{sl1_idx}) catch "SL1END0";
            };

            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = try allocator.dupe(u8, dst_tile),
                .wire_from = try allocator.dupe(u8, end_wire),
                .wire_to = try allocator.dupe(u8, to_wire),
                .tile_name_owned = true,
            });
        }
    }
}

fn emitVerticalRoute(allocator: Allocator, net: *Net, x: i32, sy: i32, dy: i32, out_idx: u8, in_idx: u8, side: []const u8) !void {
    // Short vertical route using NL1 (north) / SL1 (south) wires.
    // NL1 uses nl_type category (shifted grouping), SL1 uses standard.
    const going_north = dy > sy;
    const cat: WireCategory = if (going_north) .nl_type else .standard;
    const beg_idx = logicOutsToBegIndexForWireType(out_idx, cat);

    var tile_buf: [64]u8 = undefined;
    const src_tile = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(sy),
    }) catch return;

    var from_buf: [32]u8 = undefined;
    const src_wire = std.fmt.bufPrint(&from_buf, "LOGIC_OUTS_{s}{d}", .{
        side, out_idx,
    }) catch return;

    var hop_buf: [32]u8 = undefined;
    const hop_wire = if (going_north)
        formatBegWire(&hop_buf, "NL1BEG", beg_idx, .nl_type)
    else
        formatBegWire(&hop_buf, "SL1BEG", beg_idx, .standard);

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, src_tile),
        .wire_from = try allocator.dupe(u8, src_wire),
        .wire_to = try allocator.dupe(u8, hop_wire),
        .tile_name_owned = true,
    });

    // Destination
    var dst_buf: [64]u8 = undefined;
    const dst_tile = std.fmt.bufPrint(&dst_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(dy),
    }) catch return;

    const imux_prefix: []const u8 = if (std.mem.eql(u8, side, "L")) "IMUX_L" else "IMUX";
    var to_buf: [32]u8 = undefined;
    const to_wire = std.fmt.bufPrint(&to_buf, "{s}{d}", .{
        imux_prefix, in_idx,
    }) catch return;

    var end_buf: [32]u8 = undefined;
    const end_wire = if (going_north)
        imuxToNl1EndWire(&end_buf, in_idx)
    else blk: {
        const sl1_idx = imuxToSl1EndIndex(in_idx);
        break :blk std.fmt.bufPrint(&end_buf, "SL1END{d}", .{sl1_idx}) catch "SL1END0";
    };

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, dst_tile),
        .wire_from = try allocator.dupe(u8, end_wire),
        .wire_to = try allocator.dupe(u8, to_wire),
        .tile_name_owned = true,
    });
}

/// Get the SL1END index that can drive a given IMUX_L.
/// Pattern: SL1END index = (IMUX % 8) / 2
fn imuxToSl1EndIndex(imux_idx: u8) u2 {
    return @intCast((imux_idx % 8) / 2);
}

/// Get the NL1END wire name that can drive a given IMUX_L.
/// Pattern: IMUX col 0→NL1END0, 1→NL1END1, 2→NL1END1, 3→NL1END2, 4→NL1END2, 7→NL1END_S3_0
fn imuxToNl1EndWire(buf: []u8, imux_idx: u8) []const u8 {
    const col = imux_idx % 8;
    // NL1END assignments per IMUX col: 0→0, 1→1, 2→1, 3→2, 4→2, 5→none, 6→none, 7→_S3_0
    return switch (col) {
        0 => std.fmt.bufPrint(buf, "NL1END0", .{}) catch "NL1END0",
        1, 2 => std.fmt.bufPrint(buf, "NL1END1", .{}) catch "NL1END1",
        3, 4 => std.fmt.bufPrint(buf, "NL1END2", .{}) catch "NL1END2",
        7 => std.fmt.bufPrint(buf, "NL1END_S3_0", .{}) catch "NL1END_S3_0",
        else => std.fmt.bufPrint(buf, "NL1END0", .{}) catch "NL1END0", // fallback
    };
}

fn emitVerticalRouteLong(allocator: Allocator, net: *Net, x: i32, sy: i32, dy: i32, out_idx: u8, in_idx: u8, side: []const u8) !void {
    // Medium vertical route: LOGIC_OUTS → NN6/SS6 → landing tile → SL1/NL1 short hop → IMUX
    // NN6/SS6 END wires can NOT directly drive IMUX. Need SL1/NL1 final hop.
    const beg_idx = logicOutsToBegIndexForWireType(out_idx, .standard);
    const going_north = dy > sy;

    // Step 1: Source LOGIC_OUTS → NN6/SS6 BEG
    var tile_buf: [64]u8 = undefined;
    const src_tile = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(sy),
    }) catch return;

    var from_buf: [32]u8 = undefined;
    const src_wire = std.fmt.bufPrint(&from_buf, "LOGIC_OUTS_{s}{d}", .{
        side, out_idx,
    }) catch return;

    var hop_buf: [32]u8 = undefined;
    const hop_wire = if (going_north)
        std.fmt.bufPrint(&hop_buf, "NN6BEG{d}", .{beg_idx}) catch "NN6BEG0"
    else
        std.fmt.bufPrint(&hop_buf, "SS6BEG{d}", .{beg_idx}) catch "SS6BEG0";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, src_tile),
        .wire_from = try allocator.dupe(u8, src_wire),
        .wire_to = try allocator.dupe(u8, hop_wire),
        .tile_name_owned = true,
    });

    // Step 2: At destination tile, NN6END/SS6END → SL1BEG/NL1BEG (same index)
    // SS6END{n} → SL1BEG{n}, NN6END{n} needs special NL1BEG mapping
    var dst_buf: [64]u8 = undefined;
    const dst_tile = std.fmt.bufPrint(&dst_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(dy),
    }) catch return;

    var end6_buf: [32]u8 = undefined;
    const end6_wire = if (going_north)
        std.fmt.bufPrint(&end6_buf, "NN6END{d}", .{beg_idx}) catch "NN6END0"
    else
        std.fmt.bufPrint(&end6_buf, "SS6END{d}", .{beg_idx}) catch "SS6END0";

    // Choose final short-hop wire: use SL1 for south approach, NL1 for north
    // SL1BEG accepts SS6END with same index
    const sl1_idx = imuxToSl1EndIndex(in_idx);
    var sl1_beg_buf: [32]u8 = undefined;
    const sl1_beg = std.fmt.bufPrint(&sl1_beg_buf, "SL1BEG{d}", .{sl1_idx}) catch "SL1BEG0";

    // For the NN6/SS6 → SL1 bridge, the SL1BEG index must match the SS6END index
    // If they don't match, we use the available path
    if (!going_north and beg_idx == sl1_idx) {
        // Direct bridge: SS6END{n} → SL1BEG{n} (same index, valid!)
        try net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, dst_tile),
            .wire_from = try allocator.dupe(u8, end6_wire),
            .wire_to = try allocator.dupe(u8, sl1_beg),
            .tile_name_owned = true,
        });
    } else {
        // Use the end wire directly as fallback — emit SS6END→SL1BEG or NN6END→IMUX path
        // The SL1BEG{n} is driven by SS6END{n}, so use that index
        var bridge_buf: [32]u8 = undefined;
        const bridge_wire = if (!going_north)
            std.fmt.bufPrint(&bridge_buf, "SL1BEG{d}", .{beg_idx}) catch "SL1BEG0"
        else blk: {
            // NN6END → NL1BEG: NN6END0→NL1BEG_N3, NN6END1→NL1BEG0, NN6END2→NL1BEG1, NN6END3→NL1BEG2
            const nl1_idx: u2 = switch (beg_idx) {
                0 => 3, // _N3
                1 => 0,
                2 => 1,
                3 => 2,
            };
            break :blk formatBegWire(&bridge_buf, "NL1BEG", nl1_idx, .nl_type);
        };
        try net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, dst_tile),
            .wire_from = try allocator.dupe(u8, end6_wire),
            .wire_to = try allocator.dupe(u8, bridge_wire),
            .tile_name_owned = true,
        });
    }

    // Step 3: SL1END/NL1END → IMUX (at the final destination)
    const imux_prefix: []const u8 = if (std.mem.eql(u8, side, "L")) "IMUX_L" else "IMUX";
    var to_buf: [32]u8 = undefined;
    const to_wire = std.fmt.bufPrint(&to_buf, "{s}{d}", .{
        imux_prefix, in_idx,
    }) catch return;

    // The SL1END/NL1END index must match what IMUX accepts
    var final_end_buf: [32]u8 = undefined;
    const final_end = std.fmt.bufPrint(&final_end_buf, "SL1END{d}", .{sl1_idx}) catch "SL1END0";

    // This pip is at the destination (could be 1 tile further due to SL1 span)
    // For simplicity, emit it at the same destination tile
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, dst_tile),
        .wire_from = try allocator.dupe(u8, final_end),
        .wire_to = try allocator.dupe(u8, to_wire),
        .tile_name_owned = true,
    });
}

fn emitVerticalRouteChain(allocator: Allocator, net: *Net, x: i32, sy: i32, dy: i32, out_idx: u8, in_idx: u8, side: []const u8) !void {
    // Long vertical: chain of 6-span hops, then short hop for final approach.
    // NN6/SS6 use standard category.
    const beg_idx = logicOutsToBegIndexForWireType(out_idx, .standard);

    var tile_buf: [64]u8 = undefined;
    const src_tile = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(sy),
    }) catch return;

    var from_buf: [32]u8 = undefined;
    const src_wire = std.fmt.bufPrint(&from_buf, "LOGIC_OUTS_{s}{d}", .{
        side, out_idx,
    }) catch return;

    // First hop — use NN6/SS6 with compatible BEG index
    const going_north = dy > sy;
    var hop_buf: [32]u8 = undefined;
    const hop_wire = if (going_north)
        std.fmt.bufPrint(&hop_buf, "NN6BEG{d}", .{beg_idx}) catch "NN6BEG0"
    else
        std.fmt.bufPrint(&hop_buf, "SS6BEG{d}", .{beg_idx}) catch "SS6BEG0";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, src_tile),
        .wire_from = try allocator.dupe(u8, src_wire),
        .wire_to = try allocator.dupe(u8, hop_wire),
        .tile_name_owned = true,
    });

    // Intermediate hops: chain NN6END/SS6END → NN6BEG/SS6BEG (same index)
    const cy: i32 = if (going_north) sy + 6 else sy - 6;
    const remaining = @abs(dy - cy);
    if (remaining > 6) {
        // Need additional 6-span hops
        var mid_buf: [64]u8 = undefined;
        const mid_tile = std.fmt.bufPrint(&mid_buf, "INT_{s}_X{d}Y{d}", .{
            side, @abs(x), @abs(cy),
        }) catch return;

        var end_buf: [32]u8 = undefined;
        const end_wire = if (going_north)
            std.fmt.bufPrint(&end_buf, "NN6END{d}", .{beg_idx}) catch "NN6END0"
        else
            std.fmt.bufPrint(&end_buf, "SS6END{d}", .{beg_idx}) catch "SS6END0";

        var next_hop_buf: [32]u8 = undefined;
        const next_hop = if (going_north)
            std.fmt.bufPrint(&next_hop_buf, "NN6BEG{d}", .{beg_idx}) catch "NN6BEG0"
        else
            std.fmt.bufPrint(&next_hop_buf, "SS6BEG{d}", .{beg_idx}) catch "SS6BEG0";

        try net.route_pips.append(allocator, RoutingPip{
            .tile_name = try allocator.dupe(u8, mid_tile),
            .wire_from = try allocator.dupe(u8, end_wire),
            .wire_to = try allocator.dupe(u8, next_hop),
            .tile_name_owned = true,
        });
    }

    // Final destination: NN6END/SS6END → SL1BEG → SL1END → IMUX
    // (NN6END/SS6END cannot directly drive IMUX)
    var dst_buf: [64]u8 = undefined;
    const dst_tile = std.fmt.bufPrint(&dst_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(x), @abs(dy),
    }) catch return;

    // Step A: NN6/SS6 END → SL1BEG (bridge to short hop)
    var end6_buf: [32]u8 = undefined;
    const end6_wire = if (going_north)
        std.fmt.bufPrint(&end6_buf, "NN6END{d}", .{beg_idx}) catch "NN6END0"
    else
        std.fmt.bufPrint(&end6_buf, "SS6END{d}", .{beg_idx}) catch "SS6END0";

    var bridge_buf: [32]u8 = undefined;
    const bridge_wire = if (!going_north)
        std.fmt.bufPrint(&bridge_buf, "SL1BEG{d}", .{beg_idx}) catch "SL1BEG0"
    else blk: {
        const nl1_idx: u2 = switch (beg_idx) {
            0 => 3,
            1 => 0,
            2 => 1,
            3 => 2,
        };
        break :blk formatBegWire(&bridge_buf, "NL1BEG", nl1_idx, .nl_type);
    };

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, dst_tile),
        .wire_from = try allocator.dupe(u8, end6_wire),
        .wire_to = try allocator.dupe(u8, bridge_wire),
        .tile_name_owned = true,
    });

    // Step B: SL1END/NL1END → IMUX
    const sl1_idx = imuxToSl1EndIndex(in_idx);
    const imux_prefix: []const u8 = if (std.mem.eql(u8, side, "L")) "IMUX_L" else "IMUX";
    var to_buf: [32]u8 = undefined;
    const to_wire = std.fmt.bufPrint(&to_buf, "{s}{d}", .{
        imux_prefix, in_idx,
    }) catch return;

    var final_end_buf: [32]u8 = undefined;
    const final_end = std.fmt.bufPrint(&final_end_buf, "SL1END{d}", .{sl1_idx}) catch "SL1END0";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, dst_tile),
        .wire_from = try allocator.dupe(u8, final_end),
        .wire_to = try allocator.dupe(u8, to_wire),
        .tile_name_owned = true,
    });
}

fn emitHorizontalRoute(allocator: Allocator, net: *Net, sx: i32, sy: i32, dx: i32, out_idx: u8, in_idx: u8, side: []const u8) !void {
    // Horizontal route using EE/WW wires — standard category
    const beg_idx = logicOutsToBegIndexForWireType(out_idx, .standard);

    var tile_buf: [64]u8 = undefined;
    const src_tile = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
        side, @abs(sx), @abs(sy),
    }) catch return;

    var from_buf: [32]u8 = undefined;
    const src_wire = std.fmt.bufPrint(&from_buf, "LOGIC_OUTS_{s}{d}", .{
        side, out_idx,
    }) catch return;

    var hop_buf: [32]u8 = undefined;
    const hop_wire = if (dx > sx)
        std.fmt.bufPrint(&hop_buf, "EE2BEG{d}", .{beg_idx}) catch "EE2BEG0"
    else
        std.fmt.bufPrint(&hop_buf, "WW2BEG{d}", .{beg_idx}) catch "WW2BEG0";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, src_tile),
        .wire_from = try allocator.dupe(u8, src_wire),
        .wire_to = try allocator.dupe(u8, hop_wire),
        .tile_name_owned = true,
    });

    // Destination
    const dst_side: []const u8 = if (@mod(dx, 2) == 0) "L" else "R";
    var dst_buf: [64]u8 = undefined;
    const dst_tile = std.fmt.bufPrint(&dst_buf, "INT_{s}_X{d}Y{d}", .{
        dst_side, @abs(dx), @abs(sy),
    }) catch return;

    const dst_imux_prefix: []const u8 = if (std.mem.eql(u8, dst_side, "L")) "IMUX_L" else "IMUX";
    var to_buf: [32]u8 = undefined;
    const to_wire = std.fmt.bufPrint(&to_buf, "{s}{d}", .{
        dst_imux_prefix, in_idx,
    }) catch return;

    var end_buf: [32]u8 = undefined;
    const end_wire = if (dx > sx)
        std.fmt.bufPrint(&end_buf, "EE2END{d}", .{beg_idx}) catch "EE2END0"
    else
        std.fmt.bufPrint(&end_buf, "WW2END{d}", .{beg_idx}) catch "WW2END0";

    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = try allocator.dupe(u8, dst_tile),
        .wire_from = try allocator.dupe(u8, end_wire),
        .wire_to = try allocator.dupe(u8, to_wire),
        .tile_name_owned = true,
    });
}

// =============================================================================
// Simple Router (xc7a35t fallback)
// =============================================================================

fn routeClockNetSimple(allocator: Allocator, net: *Net) !void {
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = "CLK_BUFG_BOT_R",
        .wire_from = "BUFG_O",
        .wire_to = "HCLK_CLK",
    });
}

fn routeSignalNetSimple(allocator: Allocator, db: *ForgeDB, net: *Net) !void {
    const driver = net.driver orelse return;
    if (driver.cell_id >= db.cells.items.len) return;

    const src_cell = db.cells.items[driver.cell_id];
    const src_x: i32 = @intCast(src_cell.tile_x orelse return);
    const src_y: i32 = @intCast(src_cell.tile_y orelse return);

    for (net.sinks.items) |sink| {
        if (sink.cell_id >= db.cells.items.len) continue;
        const dst_cell = db.cells.items[sink.cell_id];
        const dst_x: i32 = @intCast(dst_cell.tile_x orelse continue);
        const dst_y: i32 = @intCast(dst_cell.tile_y orelse continue);
        try generateManhattanPath(allocator, net, src_x, src_y, dst_x, dst_y);
    }
}

fn generateManhattanPath(allocator: Allocator, net: *Net, sx: i32, sy: i32, dx: i32, dy: i32) !void {
    var cx = sx;
    var cy = sy;

    while (cx != dx) {
        const direction_east = cx < dx;
        const next_x = if (direction_east) cx + 1 else cx - 1;

        var tile_buf: [64]u8 = undefined;
        const side: []const u8 = if (@mod(cx, 2) == 0) "L" else "R";
        const tile_name = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
            side, @abs(cx), @abs(cy),
        }) catch "INT_L_X0Y0";

        const duped_tile = allocator.dupe(u8, tile_name) catch continue;

        if (direction_east) {
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = duped_tile,
                .wire_from = "EE2BEG0",
                .wire_to = "EE2END0",
                .tile_name_owned = true,
            });
        } else {
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = duped_tile,
                .wire_from = "WW2BEG0",
                .wire_to = "WW2END0",
                .tile_name_owned = true,
            });
        }
        cx = next_x;
    }

    while (cy != dy) {
        const direction_north = cy < dy;
        const next_y = if (direction_north) cy + 1 else cy - 1;

        var tile_buf: [64]u8 = undefined;
        const side: []const u8 = if (@mod(cx, 2) == 0) "L" else "R";
        const tile_name = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
            side, @abs(cx), @abs(cy),
        }) catch "INT_L_X0Y0";

        const duped_tile = allocator.dupe(u8, tile_name) catch continue;

        if (direction_north) {
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = duped_tile,
                .wire_from = "NN2BEG0",
                .wire_to = "NN2END0",
                .tile_name_owned = true,
            });
        } else {
            try net.route_pips.append(allocator, RoutingPip{
                .tile_name = duped_tile,
                .wire_from = "SS2BEG0",
                .wire_to = "SS2END0",
                .tile_name_owned = true,
            });
        }
        cy = next_y;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "route empty design" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    db.phase = .placed;
    const stats = try route(allocator, &db);
    try std.testing.expectEqual(@as(u32, 0), stats.routed_nets);
    try std.testing.expectEqual(types.Phase.routed, db.phase);
}

test "route single net simple" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0, .cell_type = .LUT1, .name = "src",
        .tile_x = 10, .tile_y = 10,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1, .cell_type = .FDRE, .name = "dst",
        .tile_x = 13, .tile_y = 15,
    });

    var net0 = Net{ .id = 0, .name = "n0" };
    net0.driver = PinRef{ .cell_id = 0, .pin_name = "O" };
    try net0.sinks.append(allocator, PinRef{ .cell_id = 1, .pin_name = "D" });
    try db.nets.append(allocator, net0);

    db.phase = .placed;
    const stats = try route(allocator, &db);

    try std.testing.expectEqual(@as(u32, 1), stats.routed_nets);
    // Manhattan distance = |13-10| + |15-10| = 8 PIPs
    try std.testing.expectEqual(@as(usize, 8), db.nets.items[0].route_pips.items.len);
}

test "route clock net simple" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0, .cell_type = .BUFG, .name = "bufg",
        .tile_x = 32, .tile_y = 0,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1, .cell_type = .FDRE, .name = "ff",
        .tile_x = 10, .tile_y = 50,
    });

    var clk_net = Net{ .id = 0, .name = "clk_net", .is_clock = true, .is_global = true };
    clk_net.driver = PinRef{ .cell_id = 0, .pin_name = "O" };
    try clk_net.sinks.append(allocator, PinRef{ .cell_id = 1, .pin_name = "C" });
    try db.nets.append(allocator, clk_net);

    db.phase = .placed;
    const stats = try route(allocator, &db);

    try std.testing.expectEqual(@as(u32, 1), stats.clock_nets);
    try std.testing.expect(db.nets.items[0].route_pips.items.len > 0);
}

test "route xc7a100t clock net" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a100t);
    defer db.deinit();

    // IBUF at IOB (Y=25)
    try db.cells.append(allocator, MappedCell{
        .id = 0, .cell_type = .IBUF, .name = "ibuf",
        .tile_x = 0, .tile_y = 25,
    });
    // BUFG
    try db.cells.append(allocator, MappedCell{
        .id = 1, .cell_type = .BUFG, .name = "bufg",
        .tile_x = 78, .tile_y = 100,
    });
    // FF
    try db.cells.append(allocator, MappedCell{
        .id = 2, .cell_type = .FDRE, .name = "ff",
        .tile_x = 2, .tile_y = 63,
    });

    // ibuf → bufg net
    var ibuf_net = Net{ .id = 0, .name = "ibuf_out" };
    ibuf_net.driver = PinRef{ .cell_id = 0, .pin_name = "O" };
    try ibuf_net.sinks.append(allocator, PinRef{ .cell_id = 1, .pin_name = "I" });
    try db.nets.append(allocator, ibuf_net);

    // clock net (bufg → ff)
    var clk_net = Net{ .id = 1, .name = "clk", .is_clock = true, .is_global = true };
    clk_net.driver = PinRef{ .cell_id = 1, .pin_name = "O" };
    try clk_net.sinks.append(allocator, PinRef{ .cell_id = 2, .pin_name = "C" });
    try db.nets.append(allocator, clk_net);

    db.phase = .placed;
    const stats = try route(allocator, &db);

    try std.testing.expectEqual(@as(u32, 1), stats.clock_nets);

    // Check clock net has real PIPs (BUFG, CLK_HROW, HCLK, etc.)
    const clk_pips = db.nets.items[1].route_pips.items;
    try std.testing.expect(clk_pips.len >= 10);

    // First PIP should be BUFG input mux
    var has_bufg_pip = false;
    for (clk_pips) |pip| {
        if (std.mem.indexOf(u8, pip.tile_name, "CLK_BUFG_BOT_R_X78Y100") != null) {
            has_bufg_pip = true;
            break;
        }
    }
    try std.testing.expect(has_bufg_pip);
}
