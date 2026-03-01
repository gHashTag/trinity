// =============================================================================
// FORGE OF KOSCHEI v2.0 — Simulated Annealing Placer
// =============================================================================
//
// Places mapped cells onto FPGA BEL locations using simulated annealing.
//
// Placement strategy:
//   1. Lock IO cells to XDC pin locations
//   2. Place BUFG in clock tile
//   3. Place CARRY4 chains in vertical columns
//   4. Initial random placement for remaining cells
//   5. SA optimization with phi-based cooling schedule
//
// Cost function: Half-Perimeter Wire Length (HPWL)
// Cooling: T *= 0.618034 (golden ratio cooling)
// Initial T: 1618.034 (phi * 1000)
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");
const json_parser = @import("json_parser.zig");

const MappedCell = types.MappedCell;
const CellType = types.CellType;
const Net = types.Net;
const ForgeDB = types.ForgeDB;
const Constraints = types.Constraints;
const IOConstraint = types.IOConstraint;
const DeviceId = types.DeviceId;

const PHI: f64 = types.PHI;

pub const PlaceError = error{
    NoCellsToPlace,
    PinNotFound,
    NoAvailableBEL,
    OutOfMemory,
    BELConflict,
};

/// Place all cells in the ForgeDB.
pub fn place(db: *ForgeDB) !void {
    if (db.cells.items.len == 0) return PlaceError.NoCellsToPlace;

    // Step 1: Lock IO cells from constraints
    try placeIOCells(db);

    // Step 2: Place BUFG cells
    placeBufgCells(db);

    // Step 3: Place CARRY4 chains vertically
    placeCarryChains(db);

    // Step 4: Initial placement for remaining cells
    placeRemainingCells(db);

    // Step 5: SA optimization
    try saOptimize(db);

    db.phase = .placed;
}

// =============================================================================
// IO Placement
// =============================================================================

fn placeIOCells(db: *ForgeDB) !void {
    for (db.cells.items) |*cell| {
        if (!cell.cell_type.isIO()) continue;

        // Find the constraint for this IO cell's port
        const pin_loc = findIOPin(db, cell) orelse continue;

        cell.tile_x = pin_loc.tile_x;
        cell.tile_y = pin_loc.tile_y;
        cell.bel = types.BelId{
            .tile_x = pin_loc.tile_x,
            .tile_y = pin_loc.tile_y,
            .bel_index = pin_loc.bel_index,
        };
        cell.locked = true;
    }
}

fn findIOPin(db: *const ForgeDB, cell: *const MappedCell) ?device_db.PinLocation {
    // Find which port this IO cell connects to
    for (db.nets.items) |net| {
        // Check if this cell drives or sinks this net
        if (net.driver) |driver| {
            if (driver.cell_id == cell.id) {
                // This cell drives this net — find which port it connects to
                return findPinForNet(db, &net);
            }
        }
        for (net.sinks.items) |sink| {
            if (sink.cell_id == cell.id) {
                return findPinForNet(db, &net);
            }
        }
    }
    return null;
}

fn findPinForNet(db: *const ForgeDB, net: *const Net) ?device_db.PinLocation {
    // Check constraints for a matching port name
    for (db.constraints.io.items) |io_constr| {
        // Match by net name (which is often the port name)
        if (std.mem.eql(u8, net.name, io_constr.port_name) or
            containsPortRef(net, io_constr.port_name, db))
        {
            return device_db.getPinLocation(db.device, io_constr.package_pin);
        }
    }
    return null;
}

fn containsPortRef(net: *const Net, port_name: []const u8, db: *const ForgeDB) bool {
    _ = net;
    _ = port_name;
    _ = db;
    // Extended matching — for now, simple name match suffices
    return false;
}

// =============================================================================
// BUFG Placement
// =============================================================================

fn placeBufgCells(db: *ForgeDB) void {
    const bufg_locs = device_db.getBufgLocations(db.device);
    var bufg_idx: usize = 0;

    for (db.cells.items) |*cell| {
        if (!cell.cell_type.isClock()) continue;
        if (cell.locked) continue;

        if (bufg_idx < bufg_locs.len) {
            const loc = bufg_locs[bufg_idx];
            cell.tile_x = loc.tile_x;
            cell.tile_y = loc.tile_y;
            cell.bel = types.BelId{
                .tile_x = loc.tile_x,
                .tile_y = loc.tile_y,
                .bel_index = loc.bufg_index,
            };
            cell.locked = true;
            bufg_idx += 1;
        }
    }
}

// =============================================================================
// CARRY4 Chain Placement
// =============================================================================

fn placeCarryChains(db: *ForgeDB) void {
    const clb_cols = device_db.getClbColumns(db.device);
    if (clb_cols.len == 0) return;

    // Place CARRY4 cells vertically in the first available CLB column
    const carry_col = clb_cols[clb_cols.len / 2]; // Use middle column
    var carry_y: u16 = 10; // Start Y offset

    for (db.cells.items) |*cell| {
        if (cell.cell_type != .CARRY4) continue;
        if (cell.locked) continue;

        cell.tile_x = carry_col;
        cell.tile_y = carry_y;
        cell.bel = types.BelId{
            .tile_x = carry_col,
            .tile_y = carry_y,
            .bel_index = 12, // CARRY4 BEL index in slice
        };
        cell.locked = true; // CARRY4 chains must stay vertical
        carry_y += 1; // Next row for chain continuity
    }
}

// =============================================================================
// Initial Random Placement
// =============================================================================

fn placeRemainingCells(db: *ForgeDB) void {
    const clb_cols = device_db.getClbColumns(db.device);
    if (clb_cols.len == 0) return;

    var col_idx: usize = 0;
    var row_y: u16 = 20;
    var bel_idx: u16 = 0;

    for (db.cells.items) |*cell| {
        if (cell.locked) continue;
        if (cell.tile_x != null) continue;

        const col_x = clb_cols[col_idx % clb_cols.len];
        cell.tile_x = col_x;
        cell.tile_y = row_y;
        cell.bel = types.BelId{
            .tile_x = col_x,
            .tile_y = row_y,
            .bel_index = bel_idx,
        };

        bel_idx += 1;
        if (bel_idx >= 8) { // 8 BELs per CLB tile (4 LUT + 4 FF per slice, 2 slices)
            bel_idx = 0;
            row_y += 1;
            if (row_y >= 190) {
                row_y = 20;
                col_idx += 1;
            }
        }
    }
}

// =============================================================================
// SA Optimization
// =============================================================================

fn saOptimize(db: *ForgeDB) !void {
    const num_cells = db.cells.items.len;
    if (num_cells < 2) return;

    // Sacred cooling parameters
    var temperature: f64 = PHI * 1000.0; // T0 = 1618.034
    const cooling_rate: f64 = 1.0 / PHI; // alpha = 0.618034
    const min_temp: f64 = 0.01;
    const moves_per_temp: u32 = @intCast(@min(num_cells * 10, 1000));

    var current_cost = computeTotalHPWL(db);

    // Simple PRNG (xorshift) seeded from cell count
    var rng_state: u64 = @as(u64, @intCast(num_cells)) * 0xDEAD_BEEF + 0x1234;

    while (temperature > min_temp) {
        var accepted: u32 = 0;

        for (0..moves_per_temp) |_| {
            // Pick a random non-locked cell
            rng_state = xorshift(rng_state);
            const cell_idx = rng_state % num_cells;
            const cell = &db.cells.items[cell_idx];

            if (cell.locked) continue;

            // Save old position
            const old_x = cell.tile_x;
            const old_y = cell.tile_y;

            // Generate random move
            rng_state = xorshift(rng_state);
            const dx: i32 = @as(i32, @intCast(rng_state % 11)) - 5;
            rng_state = xorshift(rng_state);
            const dy: i32 = @as(i32, @intCast(rng_state % 11)) - 5;

            const new_x = @as(i32, @intCast(cell.tile_x orelse 30)) + dx;
            const new_y = @as(i32, @intCast(cell.tile_y orelse 30)) + dy;

            // Clamp to device bounds
            const params = device_db.getDeviceParams(db.device);
            cell.tile_x = @intCast(@max(1, @min(new_x, @as(i32, params.num_cols) - 2)));
            cell.tile_y = @intCast(@max(1, @min(new_y, @as(i32, params.num_rows) - 2)));

            const new_cost = computeTotalHPWL(db);
            const delta = new_cost - current_cost;

            // Accept or reject
            if (delta <= 0.0) {
                current_cost = new_cost;
                accepted += 1;
            } else {
                // Boltzmann criterion
                rng_state = xorshift(rng_state);
                const rand_f = @as(f64, @floatFromInt(rng_state & 0xFFFFFFFF)) / 4294967296.0;
                if (rand_f < @exp(-delta / temperature)) {
                    current_cost = new_cost;
                    accepted += 1;
                } else {
                    // Reject — revert
                    cell.tile_x = old_x;
                    cell.tile_y = old_y;
                }
            }
        }

        // Phi cooling
        temperature *= cooling_rate;

        // Early exit if no moves accepted
        if (accepted == 0) break;
    }
}

fn xorshift(state: u64) u64 {
    var s = state;
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    return s;
}

// =============================================================================
// HPWL Cost
// =============================================================================

/// Compute total HPWL (Half-Perimeter Wire Length) for all nets.
pub fn computeTotalHPWL(db: *const ForgeDB) f64 {
    var total: f64 = 0.0;
    for (db.nets.items) |net| {
        total += computeNetHPWL(db, &net);
    }
    return total;
}

fn computeNetHPWL(db: *const ForgeDB, net: *const Net) f64 {
    var min_x: i32 = std.math.maxInt(i32);
    var max_x: i32 = std.math.minInt(i32);
    var min_y: i32 = std.math.maxInt(i32);
    var max_y: i32 = std.math.minInt(i32);
    var pin_count: u32 = 0;

    // Driver
    if (net.driver) |driver| {
        if (driver.cell_id < db.cells.items.len) {
            const cell = db.cells.items[driver.cell_id];
            if (cell.tile_x) |x| {
                const xi: i32 = @intCast(x);
                const yi: i32 = @intCast(cell.tile_y orelse 0);
                min_x = @min(min_x, xi);
                max_x = @max(max_x, xi);
                min_y = @min(min_y, yi);
                max_y = @max(max_y, yi);
                pin_count += 1;
            }
        }
    }

    // Sinks
    for (net.sinks.items) |sink| {
        if (sink.cell_id < db.cells.items.len) {
            const cell = db.cells.items[sink.cell_id];
            if (cell.tile_x) |x| {
                const xi: i32 = @intCast(x);
                const yi: i32 = @intCast(cell.tile_y orelse 0);
                min_x = @min(min_x, xi);
                max_x = @max(max_x, xi);
                min_y = @min(min_y, yi);
                max_y = @max(max_y, yi);
                pin_count += 1;
            }
        }
    }

    if (pin_count < 2) return 0.0;
    return @floatFromInt((max_x - min_x) + (max_y - min_y));
}

// =============================================================================
// Validation
// =============================================================================

/// Check that all cells are placed and there are no BEL conflicts.
pub fn validatePlacement(db: *const ForgeDB) !void {
    for (db.cells.items) |cell| {
        if (cell.tile_x == null or cell.tile_y == null) {
            return PlaceError.NoAvailableBEL;
        }
    }

    // Check for BEL conflicts (same tile_x, tile_y, bel_index)
    for (db.cells.items, 0..) |cell_a, i| {
        const bel_a = cell_a.bel orelse continue;
        for (db.cells.items[i + 1 ..]) |cell_b| {
            const bel_b = cell_b.bel orelse continue;
            if (bel_a.tile_x == bel_b.tile_x and
                bel_a.tile_y == bel_b.tile_y and
                bel_a.bel_index == bel_b.bel_index)
            {
                return PlaceError.BELConflict;
            }
        }
    }
}

// =============================================================================
// Tests
// =============================================================================

test "place simple design" {
    const allocator = std.testing.allocator;

    // Build a minimal ForgeDB with 2 cells and 1 net
    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .IBUF,
        .name = "ib",
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1,
        .cell_type = .OBUF,
        .name = "ob",
    });

    var net0 = Net{ .id = 0, .name = "n0" };
    net0.driver = types.PinRef{ .cell_id = 0, .pin_name = "O" };
    try net0.sinks.append(allocator, types.PinRef{ .cell_id = 1, .pin_name = "I" });
    try db.nets.append(allocator, net0);

    try place(&db);
    try std.testing.expectEqual(types.Phase.placed, db.phase);

    // All cells should be placed
    for (db.cells.items) |cell| {
        try std.testing.expect(cell.tile_x != null);
        try std.testing.expect(cell.tile_y != null);
    }
}

test "BUFG placement" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .BUFG,
        .name = "bufg0",
    });

    try place(&db);

    // BUFG should be placed at a known BUFG location
    const bufg = db.cells.items[0];
    try std.testing.expect(bufg.tile_x != null);
    try std.testing.expect(bufg.locked);
}

test "CARRY4 vertical placement" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{ .id = 0, .cell_type = .CARRY4, .name = "c0" });
    try db.cells.append(allocator, MappedCell{ .id = 1, .cell_type = .CARRY4, .name = "c1" });
    try db.cells.append(allocator, MappedCell{ .id = 2, .cell_type = .CARRY4, .name = "c2" });

    try place(&db);

    // CARRY4 cells should be in the same column, consecutive rows
    const c0 = db.cells.items[0];
    const c1 = db.cells.items[1];
    const c2 = db.cells.items[2];
    try std.testing.expectEqual(c0.tile_x, c1.tile_x);
    try std.testing.expectEqual(c1.tile_x, c2.tile_x);
    // Vertical chain
    try std.testing.expectEqual(c0.tile_y.? + 1, c1.tile_y.?);
    try std.testing.expectEqual(c1.tile_y.? + 1, c2.tile_y.?);
}

test "HPWL computation" {
    const allocator = std.testing.allocator;

    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    try db.cells.append(allocator, MappedCell{
        .id = 0, .cell_type = .LUT1, .name = "a",
        .tile_x = 10, .tile_y = 20,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1, .cell_type = .FDRE, .name = "b",
        .tile_x = 30, .tile_y = 50,
    });

    var net0 = Net{ .id = 0, .name = "n0" };
    net0.driver = types.PinRef{ .cell_id = 0, .pin_name = "O" };
    try net0.sinks.append(allocator, types.PinRef{ .cell_id = 1, .pin_name = "D" });
    try db.nets.append(allocator, net0);

    const hpwl = computeTotalHPWL(&db);
    // HPWL = (30-10) + (50-20) = 50
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), hpwl, 0.01);
}

test "xorshift PRNG" {
    var s: u64 = 12345;
    s = xorshift(s);
    try std.testing.expect(s != 12345);
    const s2 = xorshift(s);
    try std.testing.expect(s2 != s);
}
