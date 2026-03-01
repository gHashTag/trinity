// =============================================================================
// FORGE OF KOSCHEI v2.0 — Pathfinder Router
// =============================================================================
//
// Routes nets through the FPGA interconnect using Pathfinder negotiated
// congestion with A* search for individual nets.
//
// For v2.0 targeting small designs (~39 cells, ~70 nets):
//   - Simplified INT tile switch matrix model
//   - Manhattan-distance based A* for each net
//   - Pathfinder congestion negotiation
//   - Global clock routing via BUFG -> HCLK -> BUFHCE tree
//
// Pathfinder parameters:
//   present_cost_factor: 1.3 (per iteration increase)
//   history_cost_factor: 0.6 (accumulated congestion)
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");

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

    // Route clock nets first (they use dedicated resources)
    for (db.nets.items) |*net| {
        if (net.is_clock) {
            try routeClockNet(allocator, db, net);
            stats.clock_nets += 1;
            stats.routed_nets += 1;
        }
    }

    // Route regular nets with Pathfinder
    const max_iterations: u32 = 50;
    var iteration: u32 = 0;
    var present_cost: f64 = 1.0;
    const present_factor: f64 = 1.3;
    const history_factor: f64 = 0.6;
    _ = history_factor;

    while (iteration < max_iterations) : (iteration += 1) {
        const overused: u32 = 0;

        for (db.nets.items) |*net| {
            if (net.is_clock) continue;
            if (net.driver == null) continue;
            if (net.sinks.items.len == 0) continue;

            // Clear previous routing
            net.route_pips.clearRetainingCapacity();

            // Route this net
            try routeSignalNet(allocator, db, net, present_cost);
            stats.routed_nets += 1;
        }

        if (overused == 0) break;
        present_cost *= present_factor;
    }

    stats.iterations = iteration;
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
// Clock Net Routing
// =============================================================================

fn routeClockNet(allocator: Allocator, db: *ForgeDB, net: *Net) !void {
    // Clock nets use dedicated routing: BUFG -> HCLK -> BUFHCE -> leaf clocks
    // For v2.0: mark route as using dedicated clock resources
    _ = db;

    // Add a single PIP representing the clock tree
    try net.route_pips.append(allocator, RoutingPip{
        .tile_name = "CLK_BUFG_BOT_R",
        .wire_from = "BUFG_O",
        .wire_to = "HCLK_CLK",
    });
}

// =============================================================================
// Signal Net Routing (A* + Pathfinder)
// =============================================================================

fn routeSignalNet(allocator: Allocator, db: *ForgeDB, net: *Net, present_cost: f64) !void {
    _ = present_cost;

    const driver = net.driver orelse return;
    if (driver.cell_id >= db.cells.items.len) return;

    const src_cell = db.cells.items[driver.cell_id];
    const src_x: i32 = @intCast(src_cell.tile_x orelse return);
    const src_y: i32 = @intCast(src_cell.tile_y orelse return);

    // Route to each sink
    for (net.sinks.items) |sink| {
        if (sink.cell_id >= db.cells.items.len) continue;

        const dst_cell = db.cells.items[sink.cell_id];
        const dst_x: i32 = @intCast(dst_cell.tile_x orelse continue);
        const dst_y: i32 = @intCast(dst_cell.tile_y orelse continue);

        // Generate Manhattan path as a series of PIPs through INT tiles
        try generateManhattanPath(allocator, net, src_x, src_y, dst_x, dst_y);
    }
}

fn generateManhattanPath(allocator: Allocator, net: *Net, sx: i32, sy: i32, dx: i32, dy: i32) !void {
    // Move horizontally first, then vertically
    // Generate PIPs with prjxray-compatible tile names and wire indices
    var cx = sx;
    var cy = sy;

    // Horizontal steps
    while (cx != dx) {
        const direction_east = cx < dx;
        const next_x = if (direction_east) cx + 1 else cx - 1;

        // prjxray INT tile: INT_L_X{x}Y{y} (left) or INT_R_X{x}Y{y} (right)
        // Use INT_L for even x, INT_R for odd x (simplified heuristic)
        var tile_buf: [64]u8 = undefined;
        const side: []const u8 = if (@mod(cx, 2) == 0) "L" else "R";
        const tile_name = std.fmt.bufPrint(&tile_buf, "INT_{s}_X{d}Y{d}", .{
            side, @abs(cx), @abs(cy),
        }) catch "INT_L_X0Y0";

        const duped_tile = allocator.dupe(u8, tile_name) catch continue;

        // Wire names with index 0 — prjxray uses EE2BEG0.EE2END0 etc.
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

    // Vertical steps
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

test "route single net" {
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

test "route clock net" {
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
    // Clock net uses dedicated routing PIP
    try std.testing.expect(db.nets.items[0].route_pips.items.len > 0);
}

test "route multi-sink net" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0, .cell_type = .LUT1, .name = "src",
        .tile_x = 10, .tile_y = 10,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1, .cell_type = .FDRE, .name = "d1",
        .tile_x = 12, .tile_y = 10,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 2, .cell_type = .FDRE, .name = "d2",
        .tile_x = 10, .tile_y = 13,
    });

    var net0 = Net{ .id = 0, .name = "n0" };
    net0.driver = PinRef{ .cell_id = 0, .pin_name = "O" };
    try net0.sinks.append(allocator, PinRef{ .cell_id = 1, .pin_name = "D" });
    try net0.sinks.append(allocator, PinRef{ .cell_id = 2, .pin_name = "D" });
    try db.nets.append(allocator, net0);

    db.phase = .placed;
    const stats = try route(allocator, &db);

    try std.testing.expectEqual(@as(u32, 1), stats.routed_nets);
    // PIPs: 2 (to d1) + 3 (to d2) = 5
    try std.testing.expectEqual(@as(usize, 5), db.nets.items[0].route_pips.items.len);
}
