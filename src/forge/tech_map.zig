// =============================================================================
// FORGE OF KOSCHEI v2.0 — Technology Mapping
// =============================================================================
//
// Converts Yosys JSON cells into MappedCells and builds the net graph.
//
// Transformations:
//   - INV -> LUT1 with INIT=0b01
//   - All other Xilinx primitives: direct mapping
//   - Builds Net list: each signal ID -> Net { driver, sinks, is_clock }
//   - Identifies clock nets (driven by BUFG/BUFGCTRL/BUFHCE)
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const json_parser = @import("json_parser.zig");

const NetBit = types.NetBit;
const YosysCell = types.YosysCell;
const YosysModule = types.YosysModule;
const CellType = types.CellType;
const MappedCell = types.MappedCell;
const Net = types.Net;
const PinRef = types.PinRef;
const ForgeDB = types.ForgeDB;
const DeviceId = types.DeviceId;
const PortDir = types.PortDir;

pub const TechMapError = error{
    UnknownCellType,
    OutOfMemory,
    DuplicateDriver,
};

/// Map a parsed Yosys module into a ForgeDB with cells and nets.
pub fn mapModule(allocator: Allocator, module: YosysModule, device: DeviceId) !ForgeDB {
    var db = ForgeDB.init(allocator, device);
    errdefer db.deinit();

    // Phase 1: Convert all YosysCells -> MappedCells
    try mapCells(allocator, module, &db);

    // Phase 2: Build net graph from cell connections
    try buildNetGraph(allocator, module, &db);

    // Phase 3: Mark clock nets
    markClockNets(&db);

    db.phase = .mapped;
    return db;
}

// =============================================================================
// Phase 1: Cell Mapping
// =============================================================================

fn mapCells(allocator: Allocator, module: YosysModule, db: *ForgeDB) !void {
    for (module.cells, 0..) |cell, idx| {
        const mapped = try mapSingleCell(cell, @intCast(idx));
        try db.cells.append(allocator, mapped);
    }
}

fn mapSingleCell(cell: YosysCell, id: u32) !MappedCell {
    // Get the cell type — INV maps to LUT1
    const cell_type = mapCellType(cell.cell_type) orelse return TechMapError.UnknownCellType;

    var mapped = MappedCell{
        .id = id,
        .cell_type = cell_type,
        .name = cell.name,
    };

    // Apply cell-specific configuration
    switch (cell_type) {
        .LUT1 => {
            if (isInvCell(cell.cell_type)) {
                // INV -> LUT1 with INIT = 2'b01 (inverts input)
                mapped.lut_init = 0b01;
            } else {
                mapped.lut_init = parseLutInit(cell);
            }
        },
        .LUT2, .LUT3, .LUT4, .LUT5, .LUT6 => {
            if (isMuxF7Cell(cell.cell_type)) {
                // MUXF7/MUXF8 -> LUT3 with INIT = 0xCA (S ? I1 : I0)
                mapped.lut_init = 0xCA;
            } else {
                mapped.lut_init = parseLutInit(cell);
            }
        },
        .FDRE, .FDSE, .FDCE, .FDPE => {
            mapped.ff_init = parseFFInit(cell);
        },
        .CARRY4 => {
            mapped.carry_cyinit_const = parseCyinitConst(cell);
        },
        else => {},
    }

    return mapped;
}

fn mapCellType(type_str: []const u8) ?CellType {
    // INV is mapped to LUT1 in Xilinx architecture
    if (std.mem.eql(u8, type_str, "INV")) return .LUT1;
    // MUXF7 is a 2:1 mux (S ? I1 : I0), map to LUT3
    if (std.mem.eql(u8, type_str, "MUXF7")) return .LUT3;
    // MUXF8 is a 2:1 mux between two MUXF7 outputs, map to LUT3
    if (std.mem.eql(u8, type_str, "MUXF8")) return .LUT3;
    // SRL16E is a 16-bit shift register implemented in a LUT
    // Map to FDRE for placement/routing (uses same CLB resources)
    if (std.mem.eql(u8, type_str, "SRL16E")) return .FDRE;
    return CellType.fromString(type_str);
}

fn isInvCell(type_str: []const u8) bool {
    return std.mem.eql(u8, type_str, "INV");
}

fn isMuxF7Cell(type_str: []const u8) bool {
    return std.mem.eql(u8, type_str, "MUXF7") or std.mem.eql(u8, type_str, "MUXF8");
}

fn isSRL16ECell(type_str: []const u8) bool {
    return std.mem.eql(u8, type_str, "SRL16E");
}

fn parseLutInit(cell: YosysCell) u64 {
    const init_str = json_parser.getCellParam(cell, "INIT") orelse return 0;
    // INIT can be a binary string like "01" or hex like "DEADBEEF"
    // Yosys usually outputs binary for small LUTs
    var val: u64 = 0;
    for (init_str) |c| {
        val = val << 1;
        if (c == '1') val |= 1;
    }
    return val;
}

fn parseFFInit(cell: YosysCell) u1 {
    const init_str = json_parser.getCellParam(cell, "INIT") orelse return 0;
    if (init_str.len > 0 and init_str[init_str.len - 1] == '1') return 1;
    return 0;
}

fn parseCyinitConst(cell: YosysCell) ?u1 {
    // Check if CYINIT is connected to a constant
    const cyinit_bits = json_parser.getCellConnection(cell, "CYINIT") orelse return null;
    if (cyinit_bits.len == 0) return null;

    return switch (cyinit_bits[0]) {
        .constant_zero => @as(u1, 0),
        .constant_one => @as(u1, 1),
        else => null,
    };
}

// =============================================================================
// Phase 2: Net Graph Construction
// =============================================================================

/// Build net graph: for each unique signal ID, create a Net with driver/sinks.
fn buildNetGraph(allocator: Allocator, module: YosysModule, db: *ForgeDB) !void {
    // Signal ID -> Net index mapping
    var sig_to_net = std.AutoHashMap(u32, u32).init(allocator);
    defer sig_to_net.deinit();

    // First pass: collect all unique signal IDs and create nets
    for (module.cells, 0..) |cell, cell_idx| {
        for (cell.connections) |conn| {
            for (conn.bits) |bit| {
                const sig_id = bit.signalId() orelse continue;
                if (!sig_to_net.contains(sig_id)) {
                    const net_id: u32 = @intCast(db.nets.items.len);
                    try sig_to_net.put(sig_id, net_id);
                    try db.nets.append(allocator, Net{
                        .id = net_id,
                        .name = conn.name,
                    });
                }
            }
        }
        _ = cell_idx;
    }

    // Also handle port-level signals (top-level module IO)
    // Port names are the user-visible names that match XDC constraints (e.g. "clk", "led")
    for (module.ports) |port| {
        for (port.bits) |bit| {
            const sig_id = bit.signalId() orelse continue;
            if (sig_to_net.get(sig_id)) |existing_net_idx| {
                // Net already exists — rename to port name (port names match XDC constraints)
                db.nets.items[existing_net_idx].name = port.name;
            } else {
                const net_id: u32 = @intCast(db.nets.items.len);
                try sig_to_net.put(sig_id, net_id);
                try db.nets.append(allocator, Net{
                    .id = net_id,
                    .name = port.name,
                });
            }
        }
    }

    // Second pass: wire up drivers and sinks
    for (module.cells, 0..) |cell, cell_idx| {
        const cid: u32 = @intCast(cell_idx);

        for (cell.connections) |conn| {
            const dir = json_parser.getCellPortDir(cell, conn.name);
            const is_output = if (dir) |d| d == .output else false;

            for (conn.bits) |bit| {
                const sig_id = bit.signalId() orelse continue;
                const net_idx = sig_to_net.get(sig_id) orelse continue;
                var net = &db.nets.items[net_idx];

                if (is_output) {
                    // This cell drives this net
                    net.driver = PinRef{
                        .cell_id = cid,
                        .pin_name = conn.name,
                    };
                } else {
                    // This cell is a sink on this net
                    try net.sinks.append(allocator, PinRef{
                        .cell_id = cid,
                        .pin_name = conn.name,
                    });
                }
            }
        }
    }
}

// =============================================================================
// Phase 3: Clock Identification
// =============================================================================

fn markClockNets(db: *ForgeDB) void {
    // A net is a clock net if it's driven by a BUFG/BUFGCTRL/BUFHCE
    for (db.nets.items) |*net| {
        if (net.driver) |driver| {
            if (driver.cell_id < db.cells.items.len) {
                const cell = db.cells.items[driver.cell_id];
                if (cell.cell_type.isClock()) {
                    net.is_clock = true;
                    net.is_global = true;
                }
            }
        }
    }
}

// =============================================================================
// Queries
// =============================================================================

/// Count how many cells were mapped as a given type.
pub fn countMappedType(db: *const ForgeDB, cell_type: CellType) u32 {
    return db.countCellsByType(cell_type);
}

/// Find the cell ID of the first cell with a given type.
pub fn findCellByType(db: *const ForgeDB, cell_type: CellType) ?u32 {
    for (db.cells.items) |cell| {
        if (cell.cell_type == cell_type) return cell.id;
    }
    return null;
}

/// Find the clock net (driven by BUFG).
pub fn findClockNet(db: *const ForgeDB) ?*const Net {
    for (db.nets.items) |*net| {
        if (net.is_clock) return net;
    }
    return null;
}

/// Get all nets that a given cell drives.
pub fn getCellOutputNets(db: *const ForgeDB, cell_id: u32) []const Net {
    _ = cell_id;
    _ = db;
    // For more complex queries — used by placer/router
    return &[0]Net{};
}

// =============================================================================
// Tests
// =============================================================================

test "map minimal design" {
    const allocator = std.testing.allocator;

    const json_data =
        \\{
        \\  "modules": {
        \\    "top": {
        \\      "attributes": { "top": "00000000000000000000000000000001" },
        \\      "ports": {
        \\        "clk": { "direction": "input", "bits": [ 2 ] },
        \\        "led": { "direction": "output", "bits": [ 4 ] }
        \\      },
        \\      "cells": {
        \\        "ib": {
        \\          "hide_name": 0, "type": "IBUF", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 2 ], "O": [ 10 ] }
        \\        },
        \\        "ob": {
        \\          "hide_name": 0, "type": "OBUF", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 10 ], "O": [ 4 ] }
        \\        }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var parse_result = try json_parser.parseYosysJsonFromSlice(allocator, json_data);
    defer parse_result.deinit();

    var db = try mapModule(allocator, parse_result.module, .xc7a35t);
    defer db.deinit();

    try std.testing.expectEqual(types.Phase.mapped, db.phase);
    try std.testing.expectEqual(@as(u32, 2), db.cellCount());
    try std.testing.expectEqual(@as(u32, 1), countMappedType(&db, .IBUF));
    try std.testing.expectEqual(@as(u32, 1), countMappedType(&db, .OBUF));

    // Net connecting IBUF.O -> OBUF.I (signal 10)
    try std.testing.expect(db.netCount() > 0);
}

test "INV mapped to LUT1" {
    const allocator = std.testing.allocator;

    const json_data =
        \\{
        \\  "modules": {
        \\    "t": {
        \\      "attributes": { "top": "1" },
        \\      "ports": { "a": { "direction": "input", "bits": [ 2 ] } },
        \\      "cells": {
        \\        "inv0": {
        \\          "hide_name": 1, "type": "INV", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 5 ], "O": [ 6 ] }
        \\        }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var parse_result = try json_parser.parseYosysJsonFromSlice(allocator, json_data);
    defer parse_result.deinit();

    var db = try mapModule(allocator, parse_result.module, .xc7a35t);
    defer db.deinit();

    try std.testing.expectEqual(@as(u32, 1), db.cellCount());
    // INV should be mapped to LUT1
    try std.testing.expectEqual(CellType.LUT1, db.cells.items[0].cell_type);
    // With INIT = 0b01 (inverter truth table)
    try std.testing.expectEqual(@as(u64, 0b01), db.cells.items[0].lut_init);
}

test "clock net identification" {
    const allocator = std.testing.allocator;

    const json_data =
        \\{
        \\  "modules": {
        \\    "t": {
        \\      "attributes": { "top": "1" },
        \\      "ports": { "clk": { "direction": "input", "bits": [ 2 ] } },
        \\      "cells": {
        \\        "ibuf_clk": {
        \\          "hide_name": 0, "type": "IBUF", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 2 ], "O": [ 90 ] }
        \\        },
        \\        "bufg_clk": {
        \\          "hide_name": 0, "type": "BUFG", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 90 ], "O": [ 91 ] }
        \\        },
        \\        "ff0": {
        \\          "hide_name": 0, "type": "FDRE",
        \\          "parameters": { "INIT": "0" }, "attributes": {},
        \\          "port_directions": { "C": "input", "CE": "input", "D": "input", "Q": "output", "R": "input" },
        \\          "connections": { "C": [ 91 ], "CE": [ "1" ], "D": [ 8 ], "Q": [ 7 ], "R": [ "0" ] }
        \\        }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var parse_result = try json_parser.parseYosysJsonFromSlice(allocator, json_data);
    defer parse_result.deinit();

    var db = try mapModule(allocator, parse_result.module, .xc7a35t);
    defer db.deinit();

    try std.testing.expectEqual(@as(u32, 3), db.cellCount());
    try std.testing.expectEqual(@as(u32, 1), countMappedType(&db, .BUFG));

    // Signal 91 (BUFG output) should be a clock net
    const clk_net = findClockNet(&db);
    try std.testing.expect(clk_net != null);
    try std.testing.expect(clk_net.?.is_clock);
    try std.testing.expect(clk_net.?.is_global);

    // BUFG drives the clock net
    try std.testing.expect(clk_net.?.driver != null);
    const driver_cell = db.cells.items[clk_net.?.driver.?.cell_id];
    try std.testing.expectEqual(CellType.BUFG, driver_cell.cell_type);

    // FF0 is a sink on the clock net
    try std.testing.expect(clk_net.?.sinks.items.len >= 1);
}

test "CARRY4 with CYINIT constant" {
    const allocator = std.testing.allocator;

    const json_data =
        \\{
        \\  "modules": {
        \\    "t": {
        \\      "attributes": { "top": "1" },
        \\      "ports": { "clk": { "direction": "input", "bits": [ 2 ] } },
        \\      "cells": {
        \\        "c0": {
        \\          "hide_name": 1, "type": "CARRY4", "parameters": {}, "attributes": {},
        \\          "port_directions": { "CI": "input", "CO": "output", "CYINIT": "input", "DI": "input", "O": "output", "S": "input" },
        \\          "connections": { "CI": [ "0" ], "CO": [ 9, 10, 11, 12 ], "CYINIT": [ "0" ], "DI": [ "1", "0", "0", "0" ], "O": [ 13, 14, 15, 16 ], "S": [ 8, 17, 18, 19 ] }
        \\        }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var parse_result = try json_parser.parseYosysJsonFromSlice(allocator, json_data);
    defer parse_result.deinit();

    var db = try mapModule(allocator, parse_result.module, .xc7a35t);
    defer db.deinit();

    try std.testing.expectEqual(@as(u32, 1), db.cellCount());
    try std.testing.expectEqual(CellType.CARRY4, db.cells.items[0].cell_type);
    try std.testing.expectEqual(@as(?u1, 0), db.cells.items[0].carry_cyinit_const);
}

test "full counter design mapping" {
    const allocator = std.testing.allocator;

    const json_data =
        \\{
        \\  "modules": {
        \\    "counter_top": {
        \\      "attributes": { "top": "00000000000000000000000000000001" },
        \\      "ports": {
        \\        "clk": { "direction": "input", "bits": [ 2 ] },
        \\        "rst_n": { "direction": "input", "bits": [ 3 ] },
        \\        "led": { "direction": "output", "bits": [ 4 ] }
        \\      },
        \\      "cells": {
        \\        "inv0": { "hide_name": 1, "type": "INV", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 5 ], "O": [ 6 ] } },
        \\        "inv1": { "hide_name": 1, "type": "INV", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 7 ], "O": [ 8 ] } },
        \\        "c0": { "hide_name": 1, "type": "CARRY4", "parameters": {}, "attributes": {}, "port_directions": { "CI": "input", "CO": "output", "CYINIT": "input", "DI": "input", "O": "output", "S": "input" }, "connections": { "CI": [ "0" ], "CO": [ 9, 10, 11, 12 ], "CYINIT": [ "0" ], "DI": [ "1", "0", "0", "0" ], "O": [ 13, 14, 15, 16 ], "S": [ 20, 21, 22, 23 ] } },
        \\        "buf": { "hide_name": 1, "type": "BUFG", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 90 ], "O": [ 91 ] } },
        \\        "ff0": { "hide_name": 1, "type": "FDRE", "parameters": { "INIT": "0" }, "attributes": {}, "port_directions": { "C": "input", "CE": "input", "D": "input", "Q": "output", "R": "input" }, "connections": { "C": [ 91 ], "CE": [ "1" ], "D": [ 13 ], "Q": [ 20 ], "R": [ 6 ] } },
        \\        "ff1": { "hide_name": 1, "type": "FDRE", "parameters": { "INIT": "0" }, "attributes": {}, "port_directions": { "C": "input", "CE": "input", "D": "input", "Q": "output", "R": "input" }, "connections": { "C": [ 91 ], "CE": [ "1" ], "D": [ 14 ], "Q": [ 21 ], "R": [ 6 ] } },
        \\        "ib_clk": { "hide_name": 1, "type": "IBUF", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 2 ], "O": [ 90 ] } },
        \\        "ib_rst": { "hide_name": 1, "type": "IBUF", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 3 ], "O": [ 5 ] } },
        \\        "ob_led": { "hide_name": 1, "type": "OBUF", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 88 ], "O": [ 4 ] } }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var parse_result = try json_parser.parseYosysJsonFromSlice(allocator, json_data);
    defer parse_result.deinit();

    var db = try mapModule(allocator, parse_result.module, .xc7a35t);
    defer db.deinit();

    // 9 cells: 2 INV->LUT1, 1 CARRY4, 1 BUFG, 2 FDRE, 2 IBUF, 1 OBUF
    try std.testing.expectEqual(@as(u32, 9), db.cellCount());
    try std.testing.expectEqual(@as(u32, 2), countMappedType(&db, .LUT1)); // INV -> LUT1
    try std.testing.expectEqual(@as(u32, 0), countMappedType(&db, .INV)); // no raw INV
    try std.testing.expectEqual(@as(u32, 1), countMappedType(&db, .CARRY4));
    try std.testing.expectEqual(@as(u32, 1), countMappedType(&db, .BUFG));
    try std.testing.expectEqual(@as(u32, 2), countMappedType(&db, .FDRE));
    try std.testing.expectEqual(@as(u32, 2), countMappedType(&db, .IBUF));
    try std.testing.expectEqual(@as(u32, 1), countMappedType(&db, .OBUF));

    // Clock net exists
    const clk_net = findClockNet(&db);
    try std.testing.expect(clk_net != null);
    try std.testing.expect(clk_net.?.is_clock);

    // Net count should be > 0
    try std.testing.expect(db.netCount() > 0);
}
