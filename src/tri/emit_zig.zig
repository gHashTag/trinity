//! Zig Backend — Code generation for CPU target
//! v0.2 — Transpiles Tri AST to Zig source

const std = @import("std");
const Node = @import("ast.zig").Node;
const Allocator = std.mem.Allocator;

pub const ZigEmitter = struct {
    allocator: Allocator,
    indent: u8,
};

pub fn emitZig(allocator: Allocator, node: *const Node) ![]const u8 {
    _ = allocator;
    _ = node;
    unreachable; // TODO: implement
}
