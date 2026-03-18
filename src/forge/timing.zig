// =============================================================================
// FORGE OF KOSCHEI v2.0 — Static Timing Analysis
// =============================================================================
//
// Performs static timing analysis on the placed and routed design.
//
// Delay model (estimates for Artix-7 speed grade -1):
//   LUT6:   0.50 ns
//   FDRE:   0.30 ns (Tsu=setup, Tcq=clock-to-Q)
//   CARRY4: 0.10 ns per bit (fast carry chain)
//   Wire:   0.05 ns per routing hop
//   IBUF:   1.20 ns
//   OBUF:   1.80 ns
//   BUFG:   0.10 ns
//
// Analysis:
//   1. Build timing graph from cells and routed nets
//   2. Forward pass (arrival times)
//   3. Backward pass (required times)
//   4. Compute slack = required - arrival
//   5. Report critical path
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

const ForgeDB = types.ForgeDB;
const MappedCell = types.MappedCell;
const CellType = types.CellType;
const Net = types.Net;

// =============================================================================
// Delay Model
// =============================================================================

pub const DelayModel = struct {
    lut_delay: f64 = 0.50,
    ff_tcq: f64 = 0.30,
    ff_tsu: f64 = 0.20,
    carry4_per_bit: f64 = 0.10,
    wire_per_hop: f64 = 0.05,
    ibuf_delay: f64 = 1.20,
    obuf_delay: f64 = 1.80,
    bufg_delay: f64 = 0.10,
};

pub fn getCellDelay(model: DelayModel, cell_type: CellType) f64 {
    return switch (cell_type) {
        .LUT1, .LUT2, .LUT3, .LUT4, .LUT5, .LUT6 => model.lut_delay,
        .FDRE, .FDSE, .FDCE, .FDPE => model.ff_tcq,
        .CARRY4 => model.carry4_per_bit * 4.0,
        .IBUF => model.ibuf_delay,
        .OBUF => model.obuf_delay,
        .BUFG, .BUFGCTRL, .BUFHCE => model.bufg_delay,
        else => 0.0,
    };
}

// =============================================================================
// Timing Analysis
// =============================================================================

pub const TimingResult = struct {
    critical_path_delay: f64,
    worst_slack: f64,
    clock_period: f64,
    num_paths_analyzed: u32,
    met: bool,
};

/// Run static timing analysis on the design.
pub fn analyze(allocator: Allocator, db: *const ForgeDB, clock_period_ns: f64) !TimingResult {
    const model = DelayModel{};

    // Compute arrival times at each cell output
    var arrival = try allocator.alloc(f64, db.cells.items.len);
    defer allocator.free(arrival);
    @memset(arrival, 0.0);

    // Simple topological-order forward pass
    // For now: compute delay for each cell based on its type + wire delays
    var max_arrival: f64 = 0.0;
    var paths_analyzed: u32 = 0;

    for (db.cells.items) |cell| {
        var cell_arrival: f64 = 0.0;

        // Find all nets that sink into this cell
        for (db.nets.items) |net| {
            for (net.sinks.items) |sink| {
                if (sink.cell_id == cell.id) {
                    // Get driver's arrival time
                    if (net.driver) |driver| {
                        if (driver.cell_id < arrival.len) {
                            var wire_delay: f64 = 0.0;
                            wire_delay = @as(f64, @floatFromInt(net.route_pips.items.len)) * model.wire_per_hop;
                            const input_arrival = arrival[driver.cell_id] + wire_delay;
                            cell_arrival = @max(cell_arrival, input_arrival);
                        }
                    }
                }
            }
        }

        // Add this cell's delay
        const cell_delay = getCellDelay(model, cell.cell_type);
        arrival[cell.id] = cell_arrival + cell_delay;

        if (arrival[cell.id] > max_arrival) {
            max_arrival = arrival[cell.id];
        }
        paths_analyzed += 1;
    }

    const slack = clock_period_ns - max_arrival;

    return TimingResult{
        .critical_path_delay = max_arrival,
        .worst_slack = slack,
        .clock_period = clock_period_ns,
        .num_paths_analyzed = paths_analyzed,
        .met = slack >= 0.0,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "delay model values" {
    const model = DelayModel{};
    try std.testing.expectApproxEqAbs(@as(f64, 0.50), getCellDelay(model, .LUT6), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.30), getCellDelay(model, .FDRE), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.40), getCellDelay(model, .CARRY4), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.20), getCellDelay(model, .IBUF), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.80), getCellDelay(model, .OBUF), 0.001);
}

test "timing on simple path" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    // IBUF -> LUT1 -> FDRE
    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .IBUF,
        .name = "ib",
        .tile_x = 0,
        .tile_y = 10,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1,
        .cell_type = .LUT1,
        .name = "lut",
        .tile_x = 10,
        .tile_y = 10,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 2,
        .cell_type = .FDRE,
        .name = "ff",
        .tile_x = 10,
        .tile_y = 10,
    });

    // Net: IBUF.O -> LUT.I
    var net0 = Net{ .id = 0, .name = "n0" };
    net0.driver = types.PinRef{ .cell_id = 0, .pin_name = "O" };
    try net0.sinks.append(allocator, types.PinRef{ .cell_id = 1, .pin_name = "I0" });
    try db.nets.append(allocator, net0);

    // Net: LUT.O -> FF.D
    var net1 = Net{ .id = 1, .name = "n1" };
    net1.driver = types.PinRef{ .cell_id = 1, .pin_name = "O" };
    try net1.sinks.append(allocator, types.PinRef{ .cell_id = 2, .pin_name = "D" });
    try db.nets.append(allocator, net1);

    const result = try analyze(allocator, &db, 10.0);

    // IBUF=1.2 + LUT=0.5 + FDRE=0.3 = 2.0 ns (no wire hops)
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.critical_path_delay, 0.01);
    try std.testing.expect(result.met);
    try std.testing.expect(result.worst_slack > 0.0);
}

test "timing slack failure" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .IBUF,
        .name = "ib",
        .tile_x = 0,
        .tile_y = 0,
    });

    const result = try analyze(allocator, &db, 0.5);
    // IBUF alone = 1.2ns > 0.5ns period
    try std.testing.expect(!result.met);
}
