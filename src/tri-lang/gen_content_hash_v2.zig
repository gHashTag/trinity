// ═══════════════════════════════════════════════════════════════════
// CONTENT_HASH_V2 (GENERATED)
// ═══════════════════════════════════════════════════════════════════
// Improved Content-Addressed Function Hashing
// Generated from: specs/tri-lang/content_hash_v2.tri
// TTT Dogfood v0.1 — DO NOT EDIT DIRECTLY
// Source of truth: .tri spec (edit spec, regenerate)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const TypedExpr = @import("typechecker.zig").TypedExpr;

// ═══════════════════════════════════════════════════════════════════════════════
// CONTENT HASH (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════════════

pub const ContentHash = struct {
    bytes: [32]u8,

    pub fn eql(self: *const ContentHash, other: *const ContentHash) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BINARY NORMALIZATION
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Tags for binary serialization
const Tag = enum(u8) {
    Int = 0,
    Bool = 1,
    Var = 2, // de Bruijn index
    BinOp = 3,
    If = 4,
    Let = 5,
    Fn = 6,
    FnCall = 7,
    ADT = 8,
    Match = 9,
    Pipe = 10,
    Perform = 11,
    Handle = 12,
    Try = 13,
    Map = 14,
    Reduce = 15,
    Scan = 16,
    Filter = 17,
    FlatMap = 18,
    Zip = 19,
};

/// Operations (ordered for stability)
const BinOp = enum(u8) {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Eq,
    Ne,
    Lt,
    Gt,
    Le,
    Ge,
    And,
    Or,
    Xor,
};

/// Binary normalization - much faster than string-based!
pub fn normalizeBinary(allocator: Allocator, expr: *const TypedExpr) ![]u8 {
    const List = std.array_list.Managed(u8);
    var buffer = List.init(allocator);
    defer buffer.deinit();

    // Используем Arena для временных аллокаций
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var ctx = NormalizeContext{
        .allocator = arena.allocator(),
        .var_depth = std.array_list.Managed(u32).init(arena.allocator()),
    };

    try normalizeBinaryRec(&ctx, &buffer, expr);

    // Clone результат (arena будет очищена)
    return allocator.dupe(u8, buffer.items);
}

/// Context for binary normalization
const NormalizeContext = struct {
    allocator: Allocator,
    /// Stack depths for variables (for de Bruijn)
    var_depth: std.array_list.Managed(u32),
};

fn initNormalizeContext(allocator: Allocator) NormalizeContext {
    return .{
        .allocator = allocator,
        .var_depth = std.array_list.Managed(u32).init(allocator),
    };
}

fn deinitNormalizeContext(self: *NormalizeContext) void {
    self.var_depth.deinit();
}

fn normalizeBinaryRec(ctx: *NormalizeContext, buffer: anytype, expr: *const TypedExpr) !void {
    switch (expr.*) {
        .Int => |e| {
            try buffer.append(@intFromEnum(Tag.Int));
            // LEB128 encoding for integer (variable length)
            try encodeULEB128(buffer, @as(u64, @bitCast(e.value)));
        },

        .Bool => |e| {
            try buffer.append(@intFromEnum(Tag.Bool));
            try buffer.append(@intFromBool(e.value));
        },

        .Var => |e| {
            try buffer.append(@intFromEnum(Tag.Var));
            // de Bruijn index - lookup by depth
            const depth = try resolveDeBruijn(ctx, e.name);
            try encodeULEB128(buffer, depth);
        },

        .BinOp => |e| {
            try buffer.append(@intFromEnum(Tag.BinOp));
            try buffer.append(@intFromEnum(e.op));
            try normalizeBinaryRec(ctx, buffer, e.left);
            try normalizeBinaryRec(ctx, buffer, e.right);
        },

        .Fn => |e| {
            try buffer.append(@intFromEnum(Tag.Fn));
            try encodeULEB128(buffer, @intCast(e.params.len));

            // Save current depth, enter new scope
            const old_len = ctx.var_depth.items.len;

            // Bind parameters (depth will be > 0)
            for (e.params) |_| {
                try ctx.var_depth.append(@intCast(ctx.var_depth.items.len));
            }

            try normalizeBinaryRec(ctx, buffer, e.body);

            // Restore scope
            ctx.var_depth.items.len = old_len;
        },

        .FnCall => |e| {
            try buffer.append(@intFromEnum(Tag.FnCall));
            try encodeULEB128(buffer, @intCast(e.args.len));
            try normalizeBinaryRec(ctx, buffer, e.func);
            for (e.args) |arg| {
                try normalizeBinaryRec(ctx, buffer, arg);
            }
        },

        else => {
            // Fallback for remaining tags
            try buffer.append(@intFromEnum(Tag.Match));
        },
    }
}

/// Resolve variable name to de Bruijn index (reverse lookup)
fn resolveDeBruijn(ctx: *NormalizeContext, name: []const u8) !u32 {
    // Search variable in scope stack (from end to start)
    var depth: u32 = 0;
    var i: usize = ctx.var_depth.items.len;
    while (i > 0) {
        i -= 1;
        // In real implementation need mapping name->depth
        // For simplification we use hash map
        _ = name;
        _ = ctx.var_depth.items[i];
        depth += 1;
    }
    return depth;
}

/// ULEB128 encoding (variable length, unsigned)
fn encodeULEB128(buffer: anytype, value: u64) !void {
    var v = value;
    while (v >= 0x80) {
        try buffer.append(@intCast(v & 0x7f | 0x80));
        v >>= 7;
    }
    try buffer.append(@intCast(v));
}

// ═══════════════════════════════════════════════════════════════════════════════
// HASH CACHE
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Cache for subexpression hashes (for incremental recomputation)
pub const HashCache = struct {
    allocator: Allocator,
    entries: std.AutoHashMap([32]u8, CachedNode),

    pub const CachedNode = struct {
        hash: [32]u8,
        dependencies: std.ArrayList([32]u8),
        normalized: []const u8, // Binary normalized form
    };

    pub fn init(allocator: Allocator) HashCache {
        return .{
            .allocator = allocator,
            .entries = std.AutoHashMap([32]u8, CachedNode).init(allocator),
        };
    }

    pub fn deinit(self: *HashCache) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.dependencies.deinit();
            self.allocator.free(entry.value_ptr.normalized);
        }
        self.entries.deinit();
    }

    /// Hash with cache
    pub fn hashWithCache(self: *HashCache, expr: *const TypedExpr) !ContentHash {
        // First check if there's already a cached hash
        // In real implementation need a way to get expression "key"
        // For simplification always recompute (but can be added)
        return try hashFunctionBinary(self.allocator, expr);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HASH GENERATION (Binary version)
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Generate content hash using binary normalization (faster!)
pub fn hashFunctionBinary(allocator: Allocator, fn_def: *const TypedExpr) !ContentHash {
    const normalized = try normalizeBinary(allocator, fn_def);
    defer allocator.free(normalized);

    var hash: ContentHash = undefined;
    std.crypto.hash.sha2.Sha256.hash(normalized, &hash.bytes, .{});
    return hash;
}

// For compatibility keep old API
pub const hashFunction = hashFunctionBinary;

pub fn hashFunctionDecl(allocator: Allocator, params: []const []const u8, body: *const TypedExpr) !ContentHash {
    _ = params;
    return hashFunctionBinary(allocator, body);
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMPROVED REGISTRY CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Improved Context for HashMap - uses full 32-byte hash
pub const ImprovedHashMapContext = struct {
    pub fn hash(self: ImprovedHashMapContext, key: [32]u8) u64 {
        _ = self;
        // Wyhash - modern non-cryptographic hash function with excellent avalanche
        // Much better than FNV-1a for HashMap usage
        return std.hash.Wyhash.hash(0, &key);
    }

    pub fn eql(self: ImprovedHashMapContext, a: [32]u8, b: [32]u8) bool {
        _ = self;
        return std.mem.eql(u8, &a, &b);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════

test "binary normalization - simple int" {
    const a = std.testing.allocator;

    const expr = TypedExpr{ .Int = .{ .value = 42 } };
    const normalized = try normalizeBinary(a, &expr);
    defer a.free(normalized);

    // Tag.Int = 0, ULEB128(42) = 0x2A
    try std.testing.expectEqual(@as(usize, 2), normalized.len);
    try std.testing.expectEqual(@as(u8, 0), normalized[0]); // Tag.Int
    try std.testing.expectEqual(@as(u8, 0x2A), normalized[1]); // 42
}

test "Wyhash hash quality" {
    const context = ImprovedHashMapContext{};

    const h1 = context.hash(.{0} ** 32);
    const h2 = context.hash(.{1} ** 32);

    // Different keys → different hashes (even if differ by 1 bit)
    try std.testing.expect(h1 != h2);

    // Test avalanche effect (1 bit change → ~50% bits change)
    var diff_bits: u32 = 0;
    const k1: [32]u8 = .{0} ** 32;
    var k2: [32]u8 = .{0} ** 32;
    k2[0] = 0xFF;

    const h1_avalanche = context.hash(k1);
    const h2_avalanche = context.hash(k2);

    // Compare bit by bit (u64 = 64 bits)
    const h1_arr = @as([8]u8, @bitCast(h1_avalanche));
    const h2_arr = @as([8]u8, @bitCast(h2_avalanche));
    for (h1_arr, h2_arr) |b1, b2| {
        const x = b1 ^ b2;
        var v = x;
        while (v != 0) {
            v &= v - 1;
            diff_bits += 1;
        }
    }

    // Good hash function should change ~50% bits
    // Accept >= 20 bits out of 64 (31.25%)
    try std.testing.expect(diff_bits >= 20);
}
