// ═══════════════════════════════════════════════════════════════════════════════
// FORGE OF KOSCHEI v2.0 — Yosys JSON Netlist Parser
// ═══════════════════════════════════════════════════════════════════════════════
//
// Parses Yosys JSON output (from `synth_xilinx -abc9 -arch xc7; write_json`)
// into YosysModule data structures for downstream technology mapping.
//
// Sacred Formula: φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

const NetBit = types.NetBit;
const YosysCell = types.YosysCell;
const YosysPort = types.YosysPort;
const YosysModule = types.YosysModule;
const PortDir = types.PortDir;

pub const ParseError = error{
    NoModulesFound,
    NoTopModuleFound,
    InvalidJsonStructure,
    MissingPorts,
    MissingCells,
    OutOfMemory,
    InvalidBitValue,
};

pub const ParseResult = struct {
    module: YosysModule,
    allocator: Allocator,

    pub fn deinit(self: *ParseResult) void {
        const gpa = self.allocator;

        // Free module name (duped string)
        gpa.free(self.module.name);

        // Free ports
        for (self.module.ports) |port| {
            gpa.free(port.name);
            gpa.free(port.bits);
        }
        if (self.module.ports.len > 0) {
            gpa.free(self.module.ports);
        }

        // Free cells
        for (self.module.cells) |cell| {
            gpa.free(cell.name);
            gpa.free(cell.cell_type);

            for (cell.port_directions) |pd| {
                gpa.free(pd.name);
            }
            if (cell.port_directions.len > 0) gpa.free(cell.port_directions);

            for (cell.connections) |conn| {
                gpa.free(conn.name);
                gpa.free(conn.bits);
            }
            if (cell.connections.len > 0) gpa.free(cell.connections);

            for (cell.parameters) |param| {
                gpa.free(param.name);
                gpa.free(param.value);
            }
            if (cell.parameters.len > 0) gpa.free(cell.parameters);
        }
        if (self.module.cells.len > 0) {
            gpa.free(self.module.cells);
        }
    }
};

/// Parse a Yosys JSON netlist file and return the top-level module.
pub fn parseYosysJson(allocator: Allocator, file_path: []const u8) !ParseResult {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 256 * 1024 * 1024);
    defer allocator.free(content);

    return parseYosysJsonFromSlice(allocator, content);
}

/// Parse Yosys JSON from a memory slice.
pub fn parseYosysJsonFromSlice(allocator: Allocator, json_data: []const u8) !ParseResult {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_data, .{
        .allocate = .alloc_always,
        .max_value_len = null,
    });
    defer parsed.deinit();

    return parseFromValue(allocator, parsed.value);
}

/// Duplicate a string using allocator (so it survives JSON tree dealloc).
fn dupeStr(allocator: Allocator, s: []const u8) ![]const u8 {
    return allocator.dupe(u8, s);
}

/// Parse from an already-parsed std.json.Value.
/// All strings are duplicated so they survive JSON tree deallocation.
fn parseFromValue(allocator: Allocator, root: std.json.Value) !ParseResult {
    const root_obj = switch (root) {
        .object => |o| o,
        else => return ParseError.InvalidJsonStructure,
    };

    const modules_val = root_obj.get("modules") orelse return ParseError.NoModulesFound;
    const modules = switch (modules_val) {
        .object => |o| o,
        else => return ParseError.InvalidJsonStructure,
    };

    // Find top module (attributes.top ending in "1")
    var top_module_name: ?[]const u8 = null;
    var top_module_obj: ?std.json.ObjectMap = null;

    var mod_iter = modules.iterator();
    while (mod_iter.next()) |entry| {
        const mod_obj = switch (entry.value_ptr.*) {
            .object => |o| o,
            else => continue,
        };

        if (mod_obj.get("attributes")) |attrs_val| {
            const attrs = switch (attrs_val) {
                .object => |o| o,
                else => continue,
            };
            if (attrs.get("top")) |top_val| {
                const top_str = switch (top_val) {
                    .string => |s| s,
                    else => continue,
                };
                if (top_str.len > 0 and top_str[top_str.len - 1] == '1') {
                    var is_top = true;
                    for (top_str[0 .. top_str.len - 1]) |c| {
                        if (c != '0') {
                            is_top = false;
                            break;
                        }
                    }
                    if (is_top) {
                        top_module_name = entry.key_ptr.*;
                        top_module_obj = mod_obj;
                        break;
                    }
                }
            }
        }
    }

    const mod_name_raw = top_module_name orelse return ParseError.NoTopModuleFound;
    const mod_obj = top_module_obj orelse return ParseError.NoTopModuleFound;

    const mod_name = try dupeStr(allocator, mod_name_raw);

    const ports = try parsePorts(allocator, mod_obj);
    const cells = try parseCells(allocator, mod_obj);

    return ParseResult{
        .module = YosysModule{
            .name = mod_name,
            .ports = ports,
            .cells = cells,
        },
        .allocator = allocator,
    };
}

fn parsePorts(allocator: Allocator, mod_obj: std.json.ObjectMap) ![]YosysPort {
    const ports_val = mod_obj.get("ports") orelse return ParseError.MissingPorts;
    const ports_obj = switch (ports_val) {
        .object => |o| o,
        else => return ParseError.InvalidJsonStructure,
    };

    var port_list: std.ArrayList(YosysPort) = .{};
    errdefer {
        for (port_list.items) |p| {
            allocator.free(p.name);
            allocator.free(p.bits);
        }
        port_list.deinit(allocator);
    }

    var iter = ports_obj.iterator();
    while (iter.next()) |entry| {
        const port_obj = switch (entry.value_ptr.*) {
            .object => |o| o,
            else => continue,
        };

        const dir_str = switch (port_obj.get("direction") orelse continue) {
            .string => |s| s,
            else => continue,
        };

        const bits_arr = switch (port_obj.get("bits") orelse continue) {
            .array => |a| a,
            else => continue,
        };

        const bits = try allocator.alloc(NetBit, bits_arr.items.len);
        for (bits_arr.items, 0..) |bit_val, i| {
            bits[i] = netBitFromJsonValue(bit_val);
        }

        const port_name = try dupeStr(allocator, entry.key_ptr.*);

        try port_list.append(allocator, YosysPort{
            .name = port_name,
            .direction = PortDir.fromString(dir_str),
            .bits = bits,
        });
    }

    return port_list.toOwnedSlice(allocator);
}

fn parseCells(allocator: Allocator, mod_obj: std.json.ObjectMap) ![]YosysCell {
    const cells_val = mod_obj.get("cells") orelse return ParseError.MissingCells;
    const cells_obj = switch (cells_val) {
        .object => |o| o,
        else => return ParseError.InvalidJsonStructure,
    };

    var cell_list: std.ArrayList(YosysCell) = .{};
    errdefer {
        for (cell_list.items) |cell| {
            allocator.free(cell.name);
            allocator.free(cell.cell_type);
            for (cell.port_directions) |pd| allocator.free(pd.name);
            if (cell.port_directions.len > 0) allocator.free(cell.port_directions);
            for (cell.connections) |conn| {
                allocator.free(conn.name);
                allocator.free(conn.bits);
            }
            if (cell.connections.len > 0) allocator.free(cell.connections);
            for (cell.parameters) |param| {
                allocator.free(param.name);
                allocator.free(param.value);
            }
            if (cell.parameters.len > 0) allocator.free(cell.parameters);
        }
        cell_list.deinit(allocator);
    }

    var iter = cells_obj.iterator();
    while (iter.next()) |entry| {
        const cell_obj = switch (entry.value_ptr.*) {
            .object => |o| o,
            else => continue,
        };

        const hide_name = blk: {
            if (cell_obj.get("hide_name")) |hn| {
                break :blk switch (hn) {
                    .integer => |i| i != 0,
                    else => false,
                };
            }
            break :blk false;
        };

        const cell_type_str = switch (cell_obj.get("type") orelse continue) {
            .string => |s| s,
            else => continue,
        };

        const cell_name = try dupeStr(allocator, entry.key_ptr.*);
        errdefer allocator.free(cell_name);
        const cell_type = try dupeStr(allocator, cell_type_str);
        errdefer allocator.free(cell_type);

        const port_dirs = try parsePortDirections(allocator, cell_obj);
        const connections = try parseConnections(allocator, cell_obj);
        const parameters = try parseParameters(allocator, cell_obj);

        try cell_list.append(allocator, YosysCell{
            .name = cell_name,
            .cell_type = cell_type,
            .hide_name = hide_name,
            .port_directions = port_dirs,
            .connections = connections,
            .parameters = parameters,
        });
    }

    return cell_list.toOwnedSlice(allocator);
}

fn parsePortDirections(allocator: Allocator, cell_obj: std.json.ObjectMap) ![]YosysCell.PortDirEntry {
    const pd_val = cell_obj.get("port_directions") orelse return &[0]YosysCell.PortDirEntry{};
    const pd_obj = switch (pd_val) {
        .object => |o| o,
        else => return &[0]YosysCell.PortDirEntry{},
    };

    var list: std.ArrayList(YosysCell.PortDirEntry) = .{};
    errdefer {
        for (list.items) |pd| allocator.free(pd.name);
        list.deinit(allocator);
    }

    var iter = pd_obj.iterator();
    while (iter.next()) |entry| {
        const dir_str = switch (entry.value_ptr.*) {
            .string => |s| s,
            else => continue,
        };
        const pd_name = try dupeStr(allocator, entry.key_ptr.*);
        try list.append(allocator, .{
            .name = pd_name,
            .dir = PortDir.fromString(dir_str),
        });
    }

    return list.toOwnedSlice(allocator);
}

fn parseConnections(allocator: Allocator, cell_obj: std.json.ObjectMap) ![]YosysCell.ConnectionEntry {
    const conn_val = cell_obj.get("connections") orelse return &[0]YosysCell.ConnectionEntry{};
    const conn_obj = switch (conn_val) {
        .object => |o| o,
        else => return &[0]YosysCell.ConnectionEntry{},
    };

    var list: std.ArrayList(YosysCell.ConnectionEntry) = .{};
    errdefer {
        for (list.items) |item| {
            allocator.free(item.name);
            allocator.free(item.bits);
        }
        list.deinit(allocator);
    }

    var iter = conn_obj.iterator();
    while (iter.next()) |entry| {
        const bits_arr = switch (entry.value_ptr.*) {
            .array => |a| a,
            else => continue,
        };

        const bits = try allocator.alloc(NetBit, bits_arr.items.len);
        for (bits_arr.items, 0..) |bit_val, i| {
            bits[i] = netBitFromJsonValue(bit_val);
        }

        const conn_name = try dupeStr(allocator, entry.key_ptr.*);

        try list.append(allocator, .{
            .name = conn_name,
            .bits = bits,
        });
    }

    return list.toOwnedSlice(allocator);
}

fn parseParameters(allocator: Allocator, cell_obj: std.json.ObjectMap) ![]YosysCell.ParamEntry {
    const param_val = cell_obj.get("parameters") orelse return &[0]YosysCell.ParamEntry{};
    const param_obj = switch (param_val) {
        .object => |o| o,
        else => return &[0]YosysCell.ParamEntry{},
    };

    var list: std.ArrayList(YosysCell.ParamEntry) = .{};
    errdefer {
        for (list.items) |param| {
            allocator.free(param.name);
            allocator.free(param.value);
        }
        list.deinit(allocator);
    }

    var iter = param_obj.iterator();
    while (iter.next()) |entry| {
        const val_str = switch (entry.value_ptr.*) {
            .string => |s| s,
            .integer => |_| "0",
            else => continue,
        };
        const param_name = try dupeStr(allocator, entry.key_ptr.*);
        errdefer allocator.free(param_name);
        const param_value = try dupeStr(allocator, val_str);
        try list.append(allocator, .{
            .name = param_name,
            .value = param_value,
        });
    }

    return list.toOwnedSlice(allocator);
}

fn netBitFromJsonValue(value: std.json.Value) NetBit {
    return switch (value) {
        .integer => |i| NetBit{ .signal = @intCast(@as(u64, @bitCast(i))) },
        .string => |s| {
            if (std.mem.eql(u8, s, "0")) return .constant_zero;
            if (std.mem.eql(u8, s, "1")) return .constant_one;
            if (std.mem.eql(u8, s, "x")) return .constant_x;
            return .constant_x;
        },
        else => .constant_x,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getCellConnection(cell: YosysCell, pin_name: []const u8) ?[]const NetBit {
    for (cell.connections) |conn| {
        if (std.mem.eql(u8, conn.name, pin_name)) {
            return conn.bits;
        }
    }
    return null;
}

pub fn getCellParam(cell: YosysCell, param_name: []const u8) ?[]const u8 {
    for (cell.parameters) |param| {
        if (std.mem.eql(u8, param.name, param_name)) {
            return param.value;
        }
    }
    return null;
}

pub fn getCellPortDir(cell: YosysCell, pin_name: []const u8) ?PortDir {
    for (cell.port_directions) |pd| {
        if (std.mem.eql(u8, pd.name, pin_name)) {
            return pd.dir;
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Statistics
// ═══════════════════════════════════════════════════════════════════════════════

pub const CellStats = struct {
    total: u32,
    inv: u32,
    carry4: u32,
    bufg: u32,
    fdre: u32,
    fdse: u32,
    ibuf: u32,
    obuf: u32,
    lut: u32,
    other: u32,
};

pub fn countCells(module: YosysModule) CellStats {
    var stats = CellStats{
        .total = @intCast(module.cells.len),
        .inv = 0,
        .carry4 = 0,
        .bufg = 0,
        .fdre = 0,
        .fdse = 0,
        .ibuf = 0,
        .obuf = 0,
        .lut = 0,
        .other = 0,
    };

    for (module.cells) |cell| {
        if (std.mem.eql(u8, cell.cell_type, "INV")) {
            stats.inv += 1;
        } else if (std.mem.eql(u8, cell.cell_type, "CARRY4")) {
            stats.carry4 += 1;
        } else if (std.mem.eql(u8, cell.cell_type, "BUFG")) {
            stats.bufg += 1;
        } else if (std.mem.eql(u8, cell.cell_type, "FDRE")) {
            stats.fdre += 1;
        } else if (std.mem.eql(u8, cell.cell_type, "FDSE")) {
            stats.fdse += 1;
        } else if (std.mem.eql(u8, cell.cell_type, "IBUF")) {
            stats.ibuf += 1;
        } else if (std.mem.eql(u8, cell.cell_type, "OBUF")) {
            stats.obuf += 1;
        } else if (std.mem.startsWith(u8, cell.cell_type, "LUT")) {
            stats.lut += 1;
        } else {
            stats.other += 1;
        }
    }

    return stats;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parse minimal Yosys JSON" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "creator": "Yosys 0.45",
        \\  "modules": {
        \\    "test_top": {
        \\      "attributes": {
        \\        "top": "00000000000000000000000000000001",
        \\        "src": "test.v:1.1-10.10"
        \\      },
        \\      "ports": {
        \\        "clk": { "direction": "input", "bits": [ 2 ] },
        \\        "led": { "direction": "output", "bits": [ 3 ] }
        \\      },
        \\      "cells": {
        \\        "my_ibuf": {
        \\          "hide_name": 0, "type": "IBUF", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 2 ], "O": [ 10 ] }
        \\        },
        \\        "my_obuf": {
        \\          "hide_name": 0, "type": "OBUF", "parameters": {}, "attributes": {},
        \\          "port_directions": { "I": "input", "O": "output" },
        \\          "connections": { "I": [ 10 ], "O": [ 3 ] }
        \\        }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var result = try parseYosysJsonFromSlice(allocator, json);
    defer result.deinit();

    try std.testing.expectEqualStrings("test_top", result.module.name);
    try std.testing.expectEqual(@as(usize, 2), result.module.ports.len);
    try std.testing.expectEqual(@as(usize, 2), result.module.cells.len);

    const stats = countCells(result.module);
    try std.testing.expectEqual(@as(u32, 2), stats.total);
    try std.testing.expectEqual(@as(u32, 1), stats.ibuf);
    try std.testing.expectEqual(@as(u32, 1), stats.obuf);
}

test "parse FDRE with constants" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "modules": {
        \\    "bb": { "attributes": {}, "ports": {}, "cells": {}, "netnames": {} },
        \\    "real_top": {
        \\      "attributes": { "top": "00000000000000000000000000000001" },
        \\      "ports": {
        \\        "clk": { "direction": "input", "bits": [ 2 ] },
        \\        "out": { "direction": "output", "bits": [ 4 ] }
        \\      },
        \\      "cells": {
        \\        "ff0": {
        \\          "hide_name": 1, "type": "FDRE",
        \\          "parameters": { "INIT": "0" }, "attributes": {},
        \\          "port_directions": { "C": "input", "CE": "input", "D": "input", "Q": "output", "R": "input" },
        \\          "connections": { "C": [ 91 ], "CE": [ "1" ], "D": [ 8 ], "Q": [ 7 ], "R": [ 6 ] }
        \\        }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var result = try parseYosysJsonFromSlice(allocator, json);
    defer result.deinit();

    try std.testing.expectEqualStrings("real_top", result.module.name);
    try std.testing.expectEqual(@as(usize, 1), result.module.cells.len);

    const ff0 = result.module.cells[0];
    try std.testing.expectEqualStrings("FDRE", ff0.cell_type);
    try std.testing.expect(ff0.hide_name);

    const ce_bits = getCellConnection(ff0, "CE").?;
    try std.testing.expectEqual(@as(usize, 1), ce_bits.len);
    try std.testing.expect(!ce_bits[0].isSignal());

    const c_bits = getCellConnection(ff0, "C").?;
    try std.testing.expectEqual(@as(u32, 91), c_bits[0].signalId().?);

    const init_val = getCellParam(ff0, "INIT").?;
    try std.testing.expectEqualStrings("0", init_val);
}

test "parse CARRY4 with mixed connections" {
    const allocator = std.testing.allocator;

    const json =
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

    var result = try parseYosysJsonFromSlice(allocator, json);
    defer result.deinit();

    const carry = result.module.cells[0];
    try std.testing.expectEqualStrings("CARRY4", carry.cell_type);

    const ci = getCellConnection(carry, "CI").?;
    try std.testing.expect(!ci[0].isSignal());

    const co = getCellConnection(carry, "CO").?;
    try std.testing.expectEqual(@as(usize, 4), co.len);
    try std.testing.expectEqual(@as(u32, 9), co[0].signalId().?);
    try std.testing.expectEqual(@as(u32, 12), co[3].signalId().?);

    const di = getCellConnection(carry, "DI").?;
    try std.testing.expectEqual(@as(usize, 4), di.len);
    try std.testing.expect(!di[0].isSignal()); // "1"
    try std.testing.expect(!di[1].isSignal()); // "0"
}

test "cell stats counting" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "modules": {
        \\    "counter_top": {
        \\      "attributes": { "top": "00000000000000000000000000000001" },
        \\      "ports": { "clk": { "direction": "input", "bits": [ 2 ] }, "rst_n": { "direction": "input", "bits": [ 3 ] }, "led": { "direction": "output", "bits": [ 4 ] } },
        \\      "cells": {
        \\        "inv0": { "hide_name": 1, "type": "INV", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 5 ], "O": [ 6 ] } },
        \\        "inv1": { "hide_name": 1, "type": "INV", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 7 ], "O": [ 8 ] } },
        \\        "c0": { "hide_name": 1, "type": "CARRY4", "parameters": {}, "attributes": {}, "port_directions": { "CI": "input", "CO": "output" }, "connections": { "CI": [ "0" ], "CO": [ 9, 10, 11, 12 ] } },
        \\        "buf": { "hide_name": 1, "type": "BUFG", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 90 ], "O": [ 91 ] } },
        \\        "ff0": { "hide_name": 1, "type": "FDRE", "parameters": { "INIT": "0" }, "attributes": {}, "port_directions": { "C": "input", "Q": "output" }, "connections": { "C": [ 91 ], "Q": [ 7 ] } },
        \\        "ff1": { "hide_name": 1, "type": "FDRE", "parameters": { "INIT": "0" }, "attributes": {}, "port_directions": { "C": "input", "Q": "output" }, "connections": { "C": [ 91 ], "Q": [ 17 ] } },
        \\        "ib_clk": { "hide_name": 1, "type": "IBUF", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 2 ], "O": [ 90 ] } },
        \\        "ib_rst": { "hide_name": 1, "type": "IBUF", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 3 ], "O": [ 5 ] } },
        \\        "ob_led": { "hide_name": 1, "type": "OBUF", "parameters": {}, "attributes": {}, "port_directions": { "I": "input", "O": "output" }, "connections": { "I": [ 88 ], "O": [ 4 ] } }
        \\      },
        \\      "netnames": {}
        \\    }
        \\  }
        \\}
    ;

    var result = try parseYosysJsonFromSlice(allocator, json);
    defer result.deinit();

    const stats = countCells(result.module);
    try std.testing.expectEqual(@as(u32, 9), stats.total);
    try std.testing.expectEqual(@as(u32, 2), stats.inv);
    try std.testing.expectEqual(@as(u32, 1), stats.carry4);
    try std.testing.expectEqual(@as(u32, 1), stats.bufg);
    try std.testing.expectEqual(@as(u32, 2), stats.fdre);
    try std.testing.expectEqual(@as(u32, 2), stats.ibuf);
    try std.testing.expectEqual(@as(u32, 1), stats.obuf);
}
