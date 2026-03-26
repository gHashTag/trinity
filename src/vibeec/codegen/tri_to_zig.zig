// ═══════════════════════════════════════════════════════════════════════════════
// tri_to_zig.zig — Tri to Zig Codegen (Stage 0.5)
// ═══════════════════════════════════════════════════════════════════════════════
// Template-based codegen: parses .tri spec, emits Zig code
// This is NOT a full compiler — it maps signatures to template implementations
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ─────────────────────────────────────────────────────────────────────────────
// AST for .tri spec
// ─────────────────────────────────────────────────────────────────────────────

const TriType = enum {
    I8,
    I16,
    I64,
    F64,
    Usize,
    U64,
    Bool,
    Vector,
    Slice,
    Pointer,

    pub fn parse(str: []const u8) ?TriType {
        if (std.mem.eql(u8, str, "i8")) return .I8;
        if (std.mem.eql(u8, str, "i16")) return .I16;
        if (std.mem.eql(u8, str, "i64")) return .I64;
        if (std.mem.eql(u8, str, "f64")) return .F64;
        if (std.mem.eql(u8, str, "usize")) return .Usize;
        if (std.mem.eql(u8, str, "u64")) return .U64;
        if (std.mem.eql(u8, str, "bool")) return .Bool;
        if (std.mem.startsWith(u8, str, "@Vector")) return .Vector;
        if (std.mem.endsWith(u8, str, "Trit")) return .Slice;
        if (std.mem.indexOfScalar(u8, str, '[') != null) return .Slice;
        if (std.mem.indexOfScalar(u8, str, '*') != null) return .Pointer;
        return null;
    }
};

const FnParam = struct {
    name: []const u8,
    type_str: []const u8,

    pub fn formatZig(self: FnParam, allocator: Allocator) ![]u8 {
        // Convert .tri type to Zig type
        if (std.mem.eql(u8, self.type_str, "[]const Trit")) {
            return allocator.dupe(u8, "[]const Trit");
        }
        if (std.mem.eql(u8, self.type_str, "[]Trit")) {
            return allocator.dupe(u8, "[]Trit");
        }
        if (std.mem.eql(u8, self.type_str, "std.mem.Allocator")) {
            return allocator.dupe(u8, "std.mem.Allocator");
        }
        if (std.mem.eql(u8, self.type_str, "usize")) {
            return allocator.dupe(u8, "usize");
        }
        if (std.mem.eql(u8, self.type_str, "i64")) {
            return allocator.dupe(u8, "i64");
        }
        if (std.mem.eql(u8, self.type_str, "f64")) {
            return allocator.dupe(u8, "f64");
        }
        if (std.mem.eql(u8, self.type_str, "u64")) {
            return allocator.dupe(u8, "u64");
        }
        return allocator.dupe(u8, self.type_str);
    }
};

const FnSignature = struct {
    name: []const u8,
    params: []FnParam,
    return_type: []const u8,
    has_allocator: bool,

    pub fn formatZig(self: FnSignature, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice("pub fn ");
        try buffer.appendSlice(self.name);
        try buffer.appendSlice("(");

        for (self.params, 0..) |param, i| {
            const zig_type = try param.formatZig(allocator);
            defer allocator.free(zig_type);

            try buffer.appendSlice(param.name);
            try buffer.appendSlice(": ");
            try buffer.appendSlice(zig_type);

            if (i < self.params.len - 1) {
                try buffer.appendSlice(", ");
            }
        }

        try buffer.appendSlice(") ");

        if (std.mem.eql(u8, self.return_type, "void")) {
            try buffer.appendSlice("void");
        } else {
            try buffer.appendSlice(self.return_type);
        }

        return buffer.toOwnedSlice();
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE IMPLEMENTATIONS
// ─────────────────────────────────────────────────────────────────────────────
// Stage 0.5: Template-based codegen. These are the actual implementations.
// ─────────────────────────────────────────────────────────────────────────────

const IMPLEMENTATIONS = struct {
    // Bind: XOR-like binding
    bind: []const u8 =
        \\pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
        \\    const result = try allocator.alloc(Trit, a.len);
        \\    for (a, 0..) |_, i| {
        \\        result[i] = if (b[i] == 0) a[i] else @as(i8, @truncate(b[i] * a[i]));
        \\    }
        \\    return result;
        \\}
    ,

    // Unbind: Inverse of bind
    unbind: []const u8 =
        \\pub fn unbind(allocator: std.mem.Allocator, bound: []const Trit, key: []const Trit) ![]Trit {
        \\    const result = try allocator.alloc(Trit, bound.len);
        \\    for (bound, 0..) |_, i| {
        \\        result[i] = if (key[i] == 0) bound[i] else @as(i8, @truncate(key[i] * bound[i]));
        \\    }
        \\    return result;
        \\}
    ,

    // Bundle2: Majority vote for 2
    bundle2: []const u8 =
        \\pub fn bundle2(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
        \\    const result = try allocator.alloc(Trit, a.len);
        \\    for (a, 0..) |_, i| {
        \\        result[i] = if (a[i] == b[i]) a[i] else 0;
        \\    }
        \\    return result;
        \\}
    ,

    // CosineSimilarity
    cosineSimilarity: []const u8 =
        \\pub fn cosineSimilarity(a: []const Trit, b: []const Trit) f64 {
        \\    if (a.len != b.len) return 0.0;
        \\    var dot: i64 = 0;
        \\    var norm_a: f64 = 0.0;
        \\    var norm_b: f64 = 0.0;
        \\    for (a, 0..) |ai, i| {
        \\        dot += ai * b[i];
        \\        norm_a += @as(f64, @floatFromInt(ai)) * @as(f64, @floatFromInt(ai));
        \\        norm_b += @as(f64, @floatFromInt(b[i])) * @as(f64, @floatFromInt(b[i]));
        \\    }
        \\    const denom = @sqrt(norm_a) * @sqrt(norm_b);
        \\    if (denom == 0.0) return 0.0;
        \\    return @as(f64, @floatFromInt(dot)) / denom;
        \\}
    ,

    // HammingDistance
    hammingDistance: []const u8 =
        \\pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {
        \\    var count: usize = 0;
        \\    const len = @min(a.len, b.len);
        \\    for (0..len) |i| {
        \\        if (a[i] != b[i]) count += 1;
        \\    }
        \\    return count;
        \\}
    ,

    // HammingSimilarity
    hammingSimilarity: []const u8 =
        \\pub fn hammingSimilarity(a: []const Trit, b: []const Trit) f64 {
        \\    const dist = hammingDistance(a, b);
        \\    const max_len = @max(a.len, b.len);
        \\    if (max_len == 0) return 1.0;
        \\    return 1.0 - (@as(f64, @floatFromInt(dist)) / @as(f64, @floatFromInt(max_len)));
        \\}
    ,

    // DotSimilarity
    dotSimilarity: []const u8 =
        \\pub fn dotSimilarity(a: []const Trit, b: []const Trit) i64 {
        \\    var sum: i64 = 0;
        \\    const len = @min(a.len, b.len);
        \\    for (0..len) |i| {
        \\        sum += a[i] * b[i];
        \\    }
        \\    return sum;
        \\}
    ,

    // VectorNorm
    vectorNorm: []const u8 =
        \\pub fn vectorNorm(v: []const Trit) f64 {
        \\    var sum: f64 = 0.0;
        \\    for (v) |x| {
        \\        sum += @as(f64, @floatFromInt(x)) * @as(f64, @floatFromInt(x));
        \\    }
        \\    return @sqrt(sum);
        \\}
    ,

    // CountNonZero
    countNonZero: []const u8 =
        \\pub fn countNonZero(v: []const Trit) usize {
        \\    var count: usize = 0;
        \\    for (v) |x| {
        \\        if (x != 0) count += 1;
        \\    }
        \\    return count;
        \\}
    ,

    // DotProduct (NEW - to prove codegen works)
    dotProduct: []const u8 =
        \\pub fn dotProduct(a: []const Trit, b: []const Trit) i64 {
        \\    var sum: i64 = 0;
        \\    const len = @min(a.len, b.len);
        \\    for (0..len) |i| {
        \\        sum += a[i] * b[i];
        \\    }
        \\    return sum;
        \\}
    ,

    fn get(name: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, name, "bind")) return IMPLEMENTATIONS.bind;
        if (std.mem.eql(u8, name, "unbind")) return IMPLEMENTATIONS.unbind;
        if (std.mem.eql(u8, name, "bundle2")) return IMPLEMENTATIONS.bundle2;
        if (std.mem.eql(u8, name, "cosineSimilarity")) return IMPLEMENTATIONS.cosineSimilarity;
        if (std.mem.eql(u8, name, "hammingDistance")) return IMPLEMENTATIONS.hammingDistance;
        if (std.mem.eql(u8, name, "hammingSimilarity")) return IMPLEMENTATIONS.hammingSimilarity;
        if (std.mem.eql(u8, name, "dotSimilarity")) return IMPLEMENTATIONS.dotSimilarity;
        if (std.mem.eql(u8, name, "vectorNorm")) return IMPLEMENTATIONS.vectorNorm;
        if (std.mem.eql(u8, name, "countNonZero")) return IMPLEMENTATIONS.countNonZero;
        if (std.mem.eql(u8, name, "dotProduct")) return IMPLEMENTATIONS.dotProduct;
        return null;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// PARSER
// ─────────────────────────────────────────────────────────────────────────────

const TriParser = struct {
    source: []const u8,
    pos: usize,

    fn init(source: []const u8) TriParser {
        return .{ .source = source, .pos = 0 };
    }

    fn skipWhitespace(self: *TriParser) void {
        while (self.pos < self.source.len and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }
    }

    fn skipLine(self: *TriParser) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) self.pos += 1; // skip \n
    }

    fn skipComments(self: *TriParser) void {
        while (true) {
            self.skipWhitespace();
            if (self.pos >= self.source.len) break;

            // Skip // comments
            if (self.pos + 1 < self.source.len and self.source[self.pos] == '/' and self.source[self.pos + 1] == '/') {
                self.skipLine();
                continue;
            }

            // Skip /* */ comments
            if (self.pos + 1 < self.source.len and self.source[self.pos] == '/' and self.source[self.pos + 1] == '*') {
                self.pos += 2;
                while (self.pos < self.source.len - 1) : (self.pos += 1) {
                    if (self.source[self.pos] == '*' and self.source[self.pos + 1] == '/') {
                        self.pos += 2;
                        break;
                    }
                }
                continue;
            }

            break;
        }
    }

    fn parseIdentifier(self: *TriParser) ?[]const u8 {
        self.skipComments();
        if (self.pos >= self.source.len) return null;

        const start = self.pos;
        while (self.pos < self.source.len and (std.ascii.isAlphanumeric(self.source[self.pos]) or self.source[self.pos] == '_')) {
            self.pos += 1;
        }

        if (self.pos == start) return null;
        return self.source[start..self.pos];
    }

    fn parseType(self: *TriParser) ?[]const u8 {
        self.skipComments();
        if (self.pos >= self.source.len) return null;

        const start = self.pos;
        while (self.pos < self.source.len and !std.ascii.isWhitespace(self.source[self.pos]) and self.source[self.pos] != ',' and self.source[self.pos] != ')' and self.source[self.pos] != ':') {
            if (self.source[self.pos] == '[') {
                // Parse slice/array type
                while (self.pos < self.source.len and self.source[self.pos] != ']') {
                    self.pos += 1;
                }
                if (self.pos < self.source.len) self.pos += 1; // skip ]
            } else {
                self.pos += 1;
            }
        }

        if (self.pos == start) return null;
        return self.source[start..self.pos];
    }

    fn expect(self: *TriParser, char: u8) bool {
        self.skipComments();
        if (self.pos >= self.source.len) return false;
        if (self.source[self.pos] == char) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn parseFnParam(self: *TriParser, allocator: Allocator) !?FnParam {
        const name = self.parseIdentifier() orelse return null;
        _ = self.expect(':');

        const type_str = self.parseType() orelse return null;

        return FnParam{
            .name = try allocator.dupe(u8, name),
            .type_str = try allocator.dupe(u8, type_str),
        };
    }

    fn parseFnSignature(self: *TriParser, allocator: Allocator) !?FnSignature {
        const name = self.parseIdentifier() orelse return null;

        if (!self.expect('(')) return null;

        var params = std.ArrayListUnmanaged(FnParam){};
        defer {
            for (params.items) |p| {
                allocator.free(p.name);
                allocator.free(p.type_str);
            }
        }

        var has_allocator = false;

        // Parse parameters
        while (true) {
            self.skipComments();
            if (self.expect(')')) break;

            if (params.items.len > 0) _ = self.expect(',');

            if (try self.parseFnParam(allocator)) |param| {
                if (std.mem.eql(u8, param.name, "allocator")) {
                    has_allocator = true;
                }
                try params.append(param);
            } else |err| {
                return err;
            }
        }

        // Parse return type
        _ = self.expect('-');
        _ = self.expect('>');
        const return_type = self.parseType() orelse return null;

        // Copy params for return value
        const owned_params = try allocator.dupe(FnParam, params.items);

        return FnSignature{
            .name = try allocator.dupe(u8, name),
            .params = owned_params,
            .return_type = try allocator.dupe(u8, return_type),
            .has_allocator = has_allocator,
        };
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// CODEGEN
// ─────────────────────────────────────────────────────────────────────────────

pub fn generate(allocator: Allocator, source: []const u8) ![]const u8 {
    var parser = TriParser.init(source);

    // Emit Zig code directly - no need to store parsed functions
    var output = std.ArrayListUnmanaged(u8){};

    try output.appendSlice(allocator,
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// VSA Core — Operations (GENERATED from .tri spec)
        \\// Stage 0.5: Template-based codegen
        \\// DO NOT EDIT — Generated from specs/vsa/ops.tri
        \\//
        \\// φ² + 1/φ² = 3 | TRINITY
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\
        \\const std = @import("std");
        \\const common = @import("common.zig");
        \\const Allocator = std.mem.Allocator;
        \\const Trit = common.Trit;
        \\const Vec32i8 = common.Vec32i8;
        \\const Vec32i16 = common.Vec32i16;
        \\const SIMD_WIDTH = common.SIMD_WIDTH;
        \\
        \\
    );

    // Parse and emit each function
    while (try parser.parseFnSignature(allocator)) |sig| {
        defer {
            allocator.free(sig.name);
            allocator.free(sig.return_type);
            for (sig.params) |p| {
                allocator.free(p.name);
                allocator.free(p.type_str);
            }
            allocator.free(sig.params);
        }

        // Get implementation from template
        const impl = IMPLEMENTATIONS.get(sig.name) orelse {
            // No template implementation - emit stub
            try output.appendSlice(allocator, "// TODO: No implementation for ");
            try output.appendSlice(allocator, sig.name);
            try output.appendSlice(allocator, "\n");
            continue;
        };

        try output.appendSlice(allocator, impl);
        try output.appendSlice(allocator, "\n\n");
    } else |_| {}

    return output.toOwnedSlice(allocator);
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI
// ─────────────────────────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.tri>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_path = args[1];
    const source = try std.fs.cwd().readFileAlloc(allocator, input_path, 1024 * 1024);
    defer allocator.free(source);

    const output = try generate(allocator, source);
    defer allocator.free(output);

    try std.io.getStdOut().writeAll(output);
}
