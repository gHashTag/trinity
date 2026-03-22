//! Verilog Backend — Code generation for FPGA target
//! v0.2 — Transpiles Tri AST to Verilog bitstream

const std = @import("std");
const Node = @import("ast.zig").Node;
const Allocator = std.mem.Allocator;

pub const VerilogEmitter = struct {
    allocator: Allocator,
    module_name: []const u8,
};

pub fn emitVerilog(allocator: Allocator, node: *const Node, module_name: []const u8) ![]const u8 {
    _ = allocator;
    _ = node;
    _ = module_name;
    unreachable; // TODO: implement
}
