//! Parser tests
//! v0.1 — Tests for parse()

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenize = @import("lexer.zig").tokenize;
const parse = @import("parser.zig").parse;

test "parse empty input" {
    const tokens = try tokenize(std.testing.allocator, "");
    try std.testing.expectEqual(@as(usize, tokens.len), 0);
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expectEqual(@as(usize, ast.program.len), 0);
}

test "parse single trit literal" {
    const tokens = try tokenize(std.testing.allocator, "N");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

test "parse integer literal" {
    const tokens = try tokenize(std.testing.allocator, "42");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

test "parse simple function" {
    const tokens = try tokenize(std.testing.allocator, "fn add(a: trit, b: trit) trit");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

test "parse let variable" {
    const tokens = try tokenize(std.testing.allocator, "let x: trit = P");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

test "parse return statement" {
    const tokens = try tokenize(std.testing.allocator, "return P");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

test "parse binary operation" {
    const tokens = try tokenize(std.testing.allocator, "N + P");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

test "parse tilde operation" {
    const tokens = try tokenize(std.testing.allocator, "N ~ P");
    const ast = try parse(std.testing.allocator, tokens);
    try std.testing.expect(ast.program.len, 1);
}

