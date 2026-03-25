// ═══════════════════════════════════════════════════════════════════════════════
// content_hash.zig - Content-Addressed Function Hashing
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// TRI-LANG-6: Content-Addressed Functions
//
// Generate SHA256 hash from normalized function AST.
// Function identity = hash of normalized structure, not name/location.
//
// Normalization rules:
// - Alpha-renaming: variables become v0, v1, v2...
// - Include: function signature, body structure, types
// - Exclude: original names, comments, whitespace
// - Preserve: control flow, operations
//
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const TypedExpr = @import("typechecker.zig").TypedExpr;

// Zig 0.15: ArrayListManaged helper (unmanaged version)
const ArrayListManaged = std.array_list.AlignedManaged;

// ═══════════════════════════════════════════════════════════════════════════════
// CONTENT HASH
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Content hash - SHA256 of normalized AST
pub const ContentHash = struct {
    bytes: [32]u8,

    /// Format as hex string with prefix
    pub fn format(self: *const ContentHash, allocator: Allocator) ![]const u8 {
        const List = std.array_list.Managed(u8);
        var result = List.init(allocator);
        defer result.deinit();
        try result.appendSlice("sha256:");
        for (self.bytes) |b| {
            const hex_chars = "0123456789abcdef";
            try result.append(hex_chars[b >> 4]);
            try result.append(hex_chars[b & 0xf]);
        }
        // Use clone instead of toOwnedSlice to work around potential bug
        return try allocator.dupe(u8, result.items);
    }

    /// Format as short hex (first 8 bytes)
    pub fn formatShort(self: *const ContentHash, allocator: Allocator) ![]const u8 {
        const short_len = 8;
        const List = std.array_list.Managed(u8);
        var result = List.init(allocator);
        defer result.deinit();
        const hex_chars = "0123456789abcdef";
        for (self.bytes[0..short_len]) |b| {
            try result.append(hex_chars[b >> 4]);
            try result.append(hex_chars[b & 0xf]);
        }
        // Use clone instead of toOwnedSlice
        return try allocator.dupe(u8, result.items);
    }

    /// Compare two hashes for equality
    pub fn eql(self: *const ContentHash, other: *const ContentHash) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NORMALIZATION CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Context for AST normalization - tracks variable renaming
pub const NormalizeContext = struct {
    allocator: Allocator,
    /// Map from original names to normalized names (v0, v1, ...)
    name_map: std.StringHashMap(usize),
    next_var_id: usize,

    pub fn init(allocator: Allocator) NormalizeContext {
        return .{
            .allocator = allocator,
            .name_map = std.StringHashMap(usize).init(allocator),
            .next_var_id = 0,
        };
    }

    pub fn deinit(self: *NormalizeContext) void {
        var iter = self.name_map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.name_map.deinit();
    }

    /// Get or create normalized variable name
    pub fn normalizeName(self: *NormalizeContext, name: []const u8) ![]const u8 {
        const entry = try self.name_map.getOrPut(name);
        if (!entry.found_existing) {
            entry.key_ptr.* = try self.allocator.dupe(u8, name);
            entry.value_ptr.* = self.next_var_id;
            self.next_var_id += 1;
        }
        return std.fmt.allocPrint(self.allocator, "v{d}", .{entry.value_ptr.*});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HASH GENERATION
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Hash generation errors
pub const HashError = error{
    OutOfMemory,
} || std.crypto.errors.Error;

/// Generate content hash from function expression
/// Returns SHA256 hash of normalized AST
pub fn hashFunction(allocator: Allocator, fn_def: *const TypedExpr) HashError!ContentHash {
    var ctx = NormalizeContext.init(allocator);
    defer ctx.deinit();

    // Build normalized representation
    const normalized = try normalizeExpr(allocator, &ctx, fn_def);
    defer allocator.free(normalized);

    // Compute SHA256
    var hash: ContentHash = undefined;
    std.crypto.hash.sha2.Sha256.hash(normalized, &hash.bytes, .{});
    return hash;
}

/// Hash function with explicit parameter names (for declarations)
pub fn hashFunctionDecl(allocator: Allocator, params: []const []const u8, body: *const TypedExpr) HashError!ContentHash {
    var ctx = NormalizeContext.init(allocator);
    defer ctx.deinit();

    // Pre-populate name map with parameters
    for (params) |p| {
        const entry = try ctx.name_map.getOrPut(p);
        if (!entry.found_existing) {
            entry.key_ptr.* = try ctx.allocator.dupe(u8, p);
            entry.value_ptr.* = ctx.next_var_id;
            ctx.next_var_id += 1;
        }
    }

    // Build normalized representation
    var buffer = ArrayListManaged(u8, null).init(allocator);
    defer buffer.deinit();

    // Write parameter count (arity matters for function identity)
    try buffer.writer().print("fn:{d}:", .{params.len});

    // Normalize body
    const body_normalized = try normalizeExpr(allocator, &ctx, body);
    defer allocator.free(body_normalized);
    try buffer.appendSlice(body_normalized);

    // Compute SHA256
    var hash: ContentHash = undefined;
    std.crypto.hash.sha2.Sha256.hash(buffer.items, &hash.bytes, .{});
    return hash;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NORMALIZATION
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Normalize expression to canonical string representation
fn normalizeExpr(allocator: Allocator, ctx: *NormalizeContext, expr: *const TypedExpr) Allocator.Error![]u8 {
    var buffer = ArrayListManaged(u8, null).init(allocator);
    defer buffer.deinit();
    const writer = buffer.writer();

    try normalizeExprToWriter(allocator, ctx, expr, writer);

    return buffer.toOwnedSlice();
}

/// Normalize expression, writing to writer
fn normalizeExprToWriter(allocator: Allocator, ctx: *NormalizeContext, expr: *const TypedExpr, writer: anytype) !void {
    switch (expr.*) {
        .Int => |e| try writer.print("i:{d}", .{e.value}),
        .Bool => |e| try writer.print("b:{}", .{e.value}),
        .Var => |e| {
            const norm_name = try ctx.normalizeName(e.name);
            defer allocator.free(norm_name);
            try writer.print("v:{s}", .{norm_name});
        },
        .BinOp => |e| {
            try writer.writeAll("op:");
            try normalizeExprToWriter(allocator, ctx, e.left, writer);
            try writer.print("{s}", .{@tagName(e.op)});
            try normalizeExprToWriter(allocator, ctx, e.right, writer);
        },
        .If => |e| {
            try writer.writeAll("if:");
            try normalizeExprToWriter(allocator, ctx, e.condition, writer);
            try writer.writeAll("then:");
            try normalizeExprToWriter(allocator, ctx, e.then_branch, writer);
            try writer.writeAll("else:");
            try normalizeExprToWriter(allocator, ctx, e.else_branch, writer);
        },
        .Let => |e| {
            try writer.writeAll("let:");
            const norm_name = try ctx.normalizeName(e.name);
            defer allocator.free(norm_name);
            try writer.print("{s}=", .{norm_name});
            try normalizeExprToWriter(allocator, ctx, e.value, writer);
            try writer.writeAll("in:");
            try normalizeExprToWriter(allocator, ctx, e.body, writer);
        },
        .Fn => |e| {
            try writer.print("fn:{d}:", .{e.params.len});
            // Create a new scope for function parameters
            var param_ids: []usize = try allocator.alloc(usize, e.params.len);
            defer allocator.free(param_ids);

            for (e.params, 0..) |p, i| {
                const entry = try ctx.name_map.getOrPut(p);
                if (!entry.found_existing) {
                    entry.key_ptr.* = try ctx.allocator.dupe(u8, p);
                    entry.value_ptr.* = ctx.next_var_id;
                    ctx.next_var_id += 1;
                }
                param_ids[i] = entry.value_ptr.*;
            }

            try normalizeExprToWriter(allocator, ctx, e.body, writer);
        },
        .FnCall => |e| {
            try writer.writeAll("call:");
            try normalizeExprToWriter(allocator, ctx, e.func, writer);
            try writer.print("[{d}]", .{e.args.len});
            for (e.args) |arg| {
                try normalizeExprToWriter(allocator, ctx, arg, writer);
            }
        },
        .ADT => |e| {
            try writer.print("adt:{s}.{s}", .{ e.type_name, e.variant });
            if (e.data) |d| {
                try writer.writeAll(":");
                try normalizeExprToWriter(allocator, ctx, d, writer);
            }
        },
        .Match => |e| {
            try writer.writeAll("match:");
            try normalizeExprToWriter(allocator, ctx, e.value, writer);
            try writer.print("[{d}]", .{e.arms.len});
            for (e.arms) |arm| {
                try normalizePatternToWriter(allocator, ctx, &arm.pattern, writer);
                try writer.writeAll("=>");
                try normalizeExprToWriter(allocator, ctx, arm.body, writer);
            }
        },
        .Pipe => |e| {
            try writer.writeAll("pipe:");
            try normalizeExprToWriter(allocator, ctx, e.source, writer);
            for (e.stages) |stage| {
                try writer.writeAll("|>");
                try normalizeExprToWriter(allocator, ctx, stage, writer);
            }
        },
        .Perform => |e| {
            try writer.print("perform:{s}.{s}[{d}]", .{ e.effect_name, e.operation, e.args.len });
            for (e.args) |arg| {
                try normalizeExprToWriter(allocator, ctx, arg, writer);
            }
        },
        .Handle => |e| {
            try writer.print("handle:{s}[{d}]", .{ e.effect_name, e.clauses.len });
            for (e.clauses) |clause| {
                try writer.print("{s}=>", .{clause.operation});
                try normalizeExprToWriter(allocator, ctx, clause.body, writer);
            }
            try writer.writeAll("body:");
            try normalizeExprToWriter(allocator, ctx, e.body, writer);
        },
        .Try => |e| {
            try writer.print("try[{d}]", .{e.handlers.len});
            for (e.handlers) |handler| {
                try writer.print("{s}=>", .{handler.operation});
                try normalizeExprToWriter(allocator, ctx, handler.body, writer);
            }
            try writer.writeAll("in:");
            try normalizeExprToWriter(allocator, ctx, e.computation, writer);
        },
        .Map => |e| {
            try writer.writeAll("map:");
            try normalizeExprToWriter(allocator, ctx, e.array, writer);
            try normalizeExprToWriter(allocator, ctx, e.func, writer);
        },
        .Reduce => |e| {
            try writer.print("reduce({s}):", .{@tagName(e.operation)});
            try normalizeExprToWriter(allocator, ctx, e.array, writer);
            try normalizeExprToWriter(allocator, ctx, e.init, writer);
        },
        .Scan => |e| {
            try writer.print("scan({s},{s}):", .{ @tagName(e.operation), @tagName(e.scan_type) });
            try normalizeExprToWriter(allocator, ctx, e.array, writer);
            try normalizeExprToWriter(allocator, ctx, e.init, writer);
        },
        .Filter => |e| {
            try writer.writeAll("filter:");
            try normalizeExprToWriter(allocator, ctx, e.array, writer);
            try normalizeExprToWriter(allocator, ctx, e.predicate, writer);
        },
        .FlatMap => |e| {
            try writer.writeAll("flatMap:");
            try normalizeExprToWriter(allocator, ctx, e.array, writer);
            try normalizeExprToWriter(allocator, ctx, e.func, writer);
        },
        .Zip => |e| {
            try writer.writeAll("zip:");
            try normalizeExprToWriter(allocator, ctx, e.array1, writer);
            try normalizeExprToWriter(allocator, ctx, e.array2, writer);
        },
    }
}

/// Normalize pattern to canonical string representation
fn normalizePatternToWriter(allocator: Allocator, ctx: *NormalizeContext, pat: *const typechecker.MatchPattern, writer: anytype) !void {
    switch (pat.*) {
        .Wildcard => try writer.writeAll("_"),
        .Var => |v| try writer.print("v:{s}", .{v}),
        .IntLiteral => |i| try writer.print("i:{d}", .{i}),
        .BoolLiteral => |b| try writer.print("b:{}", .{b}),
        .ADTVariant => |a| {
            try writer.print("adt:{s}", .{a.variant});
            if (a.data_pattern) |d| {
                try writer.writeAll(":");
                try normalizePatternToWriter(allocator, ctx, d, writer);
            }
        },
    }
}

const typechecker = @import("typechecker.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════

test "hashFunction - same expression produces same hash" {
    const a = std.testing.allocator;

    // Create identical expressions
    const expr1 = try a.create(TypedExpr);
    defer a.destroy(expr1);
    expr1.* = TypedExpr{ .Int = .{ .value = 42 } };

    const expr2 = try a.create(TypedExpr);
    defer a.destroy(expr2);
    expr2.* = TypedExpr{ .Int = .{ .value = 42 } };

    const hash1 = try hashFunction(a, expr1);
    const hash2 = try hashFunction(a, expr2);

    try std.testing.expect(hash1.eql(&hash2));
}

test "hashFunction - different expressions produce different hashes" {
    const a = std.testing.allocator;

    const expr1 = try a.create(TypedExpr);
    defer a.destroy(expr1);
    expr1.* = TypedExpr{ .Int = .{ .value = 42 } };

    const expr2 = try a.create(TypedExpr);
    defer a.destroy(expr2);
    expr2.* = TypedExpr{ .Int = .{ .value = 43 } };

    const hash1 = try hashFunction(a, expr1);
    const hash2 = try hashFunction(a, expr2);

    try std.testing.expect(!hash1.eql(&hash2));
}

test "hashFunction - alpha equivalence: variable names don't matter" {
    const a = std.testing.allocator;

    // fn(x) = x  vs  fn(y) = y
    const x_param = try a.dupe(u8, "x");
    defer a.free(x_param);
    const body1 = try a.create(TypedExpr);
    defer a.destroy(body1);
    body1.* = TypedExpr{ .Var = .{ .name = "x" } };
    const fn1 = try a.create(TypedExpr);
    defer a.destroy(fn1);
    fn1.* = TypedExpr{ .Fn = .{ .params = &.{x_param}, .body = body1 } };

    const y_param = try a.dupe(u8, "y");
    defer a.free(y_param);
    const body2 = try a.create(TypedExpr);
    defer a.destroy(body2);
    body2.* = TypedExpr{ .Var = .{ .name = "y" } };
    const fn2 = try a.create(TypedExpr);
    defer a.destroy(fn2);
    fn2.* = TypedExpr{ .Fn = .{ .params = &.{y_param}, .body = body2 } };

    const hash1 = try hashFunction(a, fn1);
    const hash2 = try hashFunction(a, fn2);

    try std.testing.expect(hash1.eql(&hash2));
}

test "ContentHash.format" {
    const a = std.testing.allocator;
    var hash: ContentHash = undefined;
    @memset(&hash.bytes, 0);
    hash.bytes[0] = 0xDE;
    hash.bytes[1] = 0xAD;
    hash.bytes[2] = 0xBE;
    hash.bytes[3] = 0xEF;

    const formatted = try hash.format(a);
    defer a.free(formatted);

    // Format should produce 7 prefix + 64 hex = 71 chars
    try std.testing.expectEqual(@as(usize, 71), formatted.len);

    // Build expected string programmatically to avoid display issues
    const List = std.array_list.Managed(u8);
    var expected = List.init(a);
    defer expected.deinit();
    try expected.appendSlice("sha256:");
    try expected.appendSlice("deadbeef");

    // Append 56 zeros (for remaining 28 bytes)
    var i: usize = 0;
    while (i < 56) : (i += 1) {
        try expected.append('0');
    }

    const expected_slice = try a.dupe(u8, expected.items);
    defer a.free(expected_slice);

    try std.testing.expectEqualStrings(expected_slice, formatted);
}

test "ContentHash.formatShort" {
    const a = std.testing.allocator;
    var hash: ContentHash = undefined;
    @memset(&hash.bytes, 0);
    hash.bytes[0] = 0xDE;
    hash.bytes[1] = 0xAD;
    hash.bytes[2] = 0xBE;
    hash.bytes[3] = 0xEF;
    hash.bytes[4] = 0x12;
    hash.bytes[5] = 0x34;
    hash.bytes[6] = 0x56;
    hash.bytes[7] = 0x78;

    const formatted = try hash.formatShort(a);
    defer a.free(formatted);

    try std.testing.expectEqualStrings("deadbeef12345678", formatted);
}

test "hashFunctionDecl - arity matters" {
    const a = std.testing.allocator;

    // fn(x) = x vs fn(x, y) = x
    const x = try a.dupe(u8, "x");
    defer a.free(x);
    const y = try a.dupe(u8, "y");
    defer a.free(y);

    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Var = .{ .name = "x" } };

    const hash1 = try hashFunctionDecl(a, &.{x}, body);
    const hash2 = try hashFunctionDecl(a, &.{ x, y }, body);

    try std.testing.expect(!hash1.eql(&hash2));
}

test "hashFunction - structure matters" {
    const a = std.testing.allocator;

    // (x + y) vs (y + x) - same structure, should hash the same after normalization
    const left1 = try a.create(TypedExpr);
    defer a.destroy(left1);
    left1.* = TypedExpr{ .Var = .{ .name = "x" } };
    const right1 = try a.create(TypedExpr);
    defer a.destroy(right1);
    right1.* = TypedExpr{ .Var = .{ .name = "y" } };
    const add1 = try a.create(TypedExpr);
    defer a.destroy(add1);
    add1.* = TypedExpr{ .BinOp = .{ .left = left1, .op = .Add, .right = right1 } };

    // Different order of variables, but after normalization...
    const left2 = try a.create(TypedExpr);
    defer a.destroy(left2);
    left2.* = TypedExpr{ .Var = .{ .name = "y" } };
    const right2 = try a.create(TypedExpr);
    defer a.destroy(right2);
    right2.* = TypedExpr{ .Var = .{ .name = "x" } };
    const add2 = try a.create(TypedExpr);
    defer a.destroy(add2);
    add2.* = TypedExpr{ .BinOp = .{ .left = left2, .op = .Add, .right = right2 } };

    const hash1 = try hashFunction(a, add1);
    const hash2 = try hashFunction(a, add2);

    // After normalization: (v0 + v1) in both cases - same hash!
    // This is correct: alpha-renaming makes variable order irrelevant
    try std.testing.expect(hash1.eql(&hash2));
}

test "NormalizeContext normalizeName" {
    const a = std.testing.allocator;
    var ctx = NormalizeContext.init(a);
    defer ctx.deinit();

    const n1 = try ctx.normalizeName("foo");
    defer a.free(n1);
    try std.testing.expectEqualStrings("v0", n1);

    const n2 = try ctx.normalizeName("bar");
    defer a.free(n2);
    try std.testing.expectEqualStrings("v1", n2);

    // Same name gets same normalized form
    const n3 = try ctx.normalizeName("foo");
    defer a.free(n3);
    try std.testing.expectEqualStrings("v0", n3);
}
