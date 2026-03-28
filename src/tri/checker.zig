//! Type Checker — Semantic analysis for Tri language
//! v0.2 — Validates type safety and constraints

const std = @import("std");
const Node = @import("ast.zig").Node;
const Type = @import("ast.zig").Type;

pub const TypeChecker = struct {
    symbol_table: std.StringHashMap(Type),
};

pub fn typecheck(node: *const Node) !void {
    _ = node;
    return error.NotImplemented; // TODO: implement type checking
}
