const std = @import("std");
const crypto = std.crypto;

pub const ContentHash = [32]u8;

pub const FunctionAst = struct {
    name: []const u8,
    params: []const Param,
    return_type: []const u8,
    body_hash: ContentHash,
};

pub const Param = struct {
    name: []const u8,
    type_expr: []const u8,
};

pub fn hashFunction(allocator: std.mem.Allocator, func: FunctionAst) !ContentHash {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice("fn:");
    try buf.appendSlice(func.return_type);
    try buf.appendSlice("(");

    for (func.params, 0..) |p, i| {
        if (i > 0) try buf.appendSlice(",");
        try buf.appendSlice("_:");
        try buf.appendSlice(p.type_expr);
    }

    try buf.appendSlice("):");
    try buf.appendSlice(&func.body_hash);

    var result: ContentHash = undefined;
    crypto.hash.sha2.Sha256.hash(buf.items, &result, .{});
    return result;
}

pub fn normalizeParams(params: []const Param, allocator: std.mem.Allocator) ![]NormalizedParam {
    var result = try std.ArrayList(NormalizedParam).initCapacity(allocator, params.len);
    for (params, 0..) |p, i| {
        result.appendAssumeCapacity(.{
            .canonical_name = try std.fmt.allocPrint(allocator, "_p{d}", .{i}),
            .type_expr = p.type_expr,
        });
    }
    return result.toOwnedSlice();
}

pub const NormalizedParam = struct {
    canonical_name: []const u8,
    type_expr: []const u8,
};

pub fn alphaEquivalent(a: FunctionAst, b: FunctionAst) bool {
    if (a.params.len != b.params.len) return false;
    if (!std.mem.eql(u8, a.return_type, b.return_type)) return false;

    for (a.params, b.params) |pa, pb| {
        if (!std.mem.eql(u8, pa.type_expr, pb.type_expr)) return false;
    }

    return std.mem.eql(u8, &a.body_hash, &b.body_hash);
}

pub fn hashToString(hash: ContentHash) [64]u8 {
    var buf: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{s}", .{std.fmt.fmtSliceHexLower(&hash)}) catch unreachable;
    return buf;
}

test "hash function produces consistent results" {
    const allocator = std.testing.allocator;
    const body_hash: ContentHash = [_]u8{0xAA} ** 32;

    const func = FunctionAst{
        .name = "add",
        .params = &.{
            .{ .name = "x", .type_expr = "i32" },
            .{ .name = "y", .type_expr = "i32" },
        },
        .return_type = "i32",
        .body_hash = body_hash,
    };

    const h1 = try hashFunction(allocator, func);
    const h2 = try hashFunction(allocator, func);
    try std.testing.expectEqualSlices(u8, &h1, &h2);
}

test "alpha equivalence ignores param names" {
    const body_hash: ContentHash = [_]u8{0xBB} ** 32;

    const a = FunctionAst{
        .name = "add",
        .params = &.{
            .{ .name = "x", .type_expr = "i32" },
            .{ .name = "y", .type_expr = "i32" },
        },
        .return_type = "i32",
        .body_hash = body_hash,
    };

    const b = FunctionAst{
        .name = "add",
        .params = &.{
            .{ .name = "a", .type_expr = "i32" },
            .{ .name = "b", .type_expr = "i32" },
        },
        .return_type = "i32",
        .body_hash = body_hash,
    };

    try std.testing.expect(alphaEquivalent(a, b));
}

test "different types are not alpha equivalent" {
    const body_hash: ContentHash = [_]u8{0xCC} ** 32;

    const a = FunctionAst{
        .name = "f",
        .params = &.{.{ .name = "x", .type_expr = "i32" }},
        .return_type = "i32",
        .body_hash = body_hash,
    };

    const b = FunctionAst{
        .name = "f",
        .params = &.{.{ .name = "x", .type_expr = "f64" }},
        .return_type = "i32",
        .body_hash = body_hash,
    };

    try std.testing.expect(!alphaEquivalent(a, b));
}

test "different param count not alpha equivalent" {
    const body_hash: ContentHash = [_]u8{0xDD} ** 32;

    const a = FunctionAst{
        .name = "f",
        .params = &.{.{ .name = "x", .type_expr = "i32" }},
        .return_type = "i32",
        .body_hash = body_hash,
    };

    const b = FunctionAst{
        .name = "f",
        .params = &.{
            .{ .name = "x", .type_expr = "i32" },
            .{ .name = "y", .type_expr = "i32" },
        },
        .return_type = "i32",
        .body_hash = body_hash,
    };

    try std.testing.expect(!alphaEquivalent(a, b));
}

test "hash to string produces 64 hex chars" {
    const hash: ContentHash = [_]u8{0} ** 32;
    const s = hashToString(hash);
    try std.testing.expectEqual(@as(usize, 64), s.len);
}

test "normalize params canonicalizes names" {
    const allocator = std.testing.allocator;
    const params = [_]Param{
        .{ .name = "foo", .type_expr = "i32" },
        .{ .name = "bar", .type_expr = "f64" },
    };
    const normalized = try normalizeParams(&params, allocator);
    defer allocator.free(normalized);

    try std.testing.expectEqualStrings("_p0", normalized[0].canonical_name);
    try std.testing.expectEqualStrings("_p1", normalized[1].canonical_name);
    try std.testing.expectEqualStrings("i32", normalized[0].type_expr);
    try std.testing.expectEqualStrings("f64", normalized[1].type_expr);
}
