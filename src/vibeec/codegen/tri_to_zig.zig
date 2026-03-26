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

fn getTemplate(comptime name: []const u8) ?[]const u8 {
    const templates = .{
        .{ "bind", @embedFile("templates/bind.zig.tpl") },
        .{ "unbind", @embedFile("templates/unbind.zig.tpl") },
        .{ "bundle2", @embedFile("templates/bundle2.zig.tpl") },
        .{ "cosineSimilarity", @embedFile("templates/cosineSimilarity.zig.tpl") },
        .{ "hammingDistance", @embedFile("templates/hammingDistance.zig.tpl") },
        .{ "hammingSimilarity", @embedFile("templates/hammingSimilarity.zig.tpl") },
        .{ "dotSimilarity", @embedFile("templates/dotSimilarity.zig.tpl") },
        .{ "vectorNorm", @embedFile("templates/vectorNorm.zig.tpl") },
        .{ "countNonZero", @embedFile("templates/countNonZero.zig.tpl") },
        .{ "dotProduct", @embedFile("templates/dotProduct.zig.tpl") },
    };

    inline for (templates) |tpl| {
        if (std.mem.eql(u8, name, tpl[0])) return tpl[1];
    }
    return null;
}

// For now, use hardcoded templates inline (Stage 0.5-MINIMAL)
const IMPLEMENTATIONS = struct {
    pub fn get(name: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, name, "bind")) return 
        \\pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
        \\    const result = try allocator.alloc(Trit, a.len);
        \\    for (a, 0..) |_, i| {
        \\        result[i] = if (b[i] == 0) a[i] else @as(i8, @truncate(b[i] * a[i]));
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "dotProduct")) return 
        \\pub fn dotProduct(a: []const Trit, b: []const Trit) i64 {
        \\    var sum: i64 = 0;
        \\    const len = @min(a.len, b.len);
        \\    for (0..len) |i| {
        \\        sum += a[i] * b[i];
        \\    }
        \\    return sum;
        \\}
        ;

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

            const param_result = self.parseFnParam(allocator) catch |err| return err;
            if (param_result) |param| {
                if (std.mem.eql(u8, param.name, "allocator")) {
                    has_allocator = true;
                }
                try params.append(allocator, param);
            }
        }

        // Parse return type (format: ") type;" not "-> type")
        self.skipComments();
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
    while (true) {
        const sig_result = parser.parseFnSignature(allocator) catch break;
        const sig = sig_result orelse break;
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
    }

    return output.toOwnedSlice(allocator);
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI
// ─────────────────────────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const args = try std.process.argsAlloc(arena_alloc);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.tri>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_path = args[1];
    const source = try std.fs.cwd().readFileAlloc(arena_alloc, input_path, 1024 * 1024);

    const output = try generate(arena_alloc, source);

    try std.fs.File.stdout().writeAll(output);
}
