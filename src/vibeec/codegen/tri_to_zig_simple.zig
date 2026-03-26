// ═══════════════════════════════════════════════════════════════════════════════
// tri_to_zig.zig — Tri to Zig Codegen (Stage 0.5-MINIMAL)
// ═══════════════════════════════════════════════════════════════════════════════
// Simple codegen: extracts fn names from .tri spec, emits Zig from templates
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE IMPLEMENTATIONS
// ─────────────────────────────────────────────────────────────────────────────

const IMPLEMENTATIONS = struct {
    bind: []const u8 =
        \\pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
        \\    const result = try allocator.alloc(Trit, a.len);
        \\    for (a, 0..) |_, i| {
        \\        result[i] = if (b[i] == 0) a[i] else @as(i8, @truncate(b[i] * a[i]));
        \\    }
        \\    return result;
        \\}
    ,

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
        if (std.mem.eql(u8, name, "dotProduct")) return IMPLEMENTATIONS.dotProduct;
        return null;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE PARSER
// ─────────────────────────────────────────────────────────────────────────────

const TriParser = struct {
    source: []const u8,
    pos: usize,

    fn init(source: []const u8) TriParser {
        return .{ .source = source, .pos = 0 };
    }

    fn skipWhitespaceAndComments(self: *TriParser) void {
        while (self.pos < self.source.len) {
            if (std.ascii.isWhitespace(self.source[self.pos])) {
                self.pos += 1;
                continue;
            }
            // Skip // comments
            if (self.pos + 1 < self.source.len and self.source[self.pos] == '/' and self.source[self.pos + 1] == '/') {
                while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                    self.pos += 1;
                }
                if (self.pos < self.source.len) self.pos += 1; // skip \n
                continue;
            }
            break;
        }
    }

    fn extractFnNames(self: *TriParser, allocator: Allocator) ![][]const u8 {
        var names = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (names.items) |n| allocator.free(n);
        }

        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();

            // Look for "fn " keyword
            if (self.pos + 2 < self.source.len and
                self.source[self.pos] == 'f' and
                self.source[self.pos + 1] == 'n' and
                self.source[self.pos + 2] == ' ')
            {
                self.pos += 3; // skip "fn "
                self.skipWhitespaceAndComments();

                // Extract function name
                const start = self.pos;
                while (self.pos < self.source.len and !std.ascii.isWhitespace(self.source[self.pos]) and self.source[self.pos] != '(') {
                    self.pos += 1;
                }

                if (self.pos > start) {
                    const name = try allocator.dupe(u8, self.source[start..self.pos]);
                    try names.append(name);
                }
            } else {
                self.pos += 1;
            }
        }

        return names.toOwnedSlice(allocator);
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// CODEGEN
// ─────────────────────────────────────────────────────────────────────────────

pub fn generate(allocator: Allocator, source: []const u8) ![]const u8 {
    var parser = TriParser.init(source);
    const fn_names = try parser.extractFnNames(allocator);
    defer {
        for (fn_names) |n| allocator.free(n);
    }

    var output = std.ArrayListUnmanaged(u8){};

    try output.appendSlice(allocator,
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// VSA Core — Operations (GENERATED from .tri spec)
        \\// Stage 0.5-MINIMAL: Template-based codegen
        \\// DO NOT EDIT — Generated from specs/vsa/ops.tri
        \\//
        \\// φ² + 1/φ² = 3 | TRINITY
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\
        \\const std = @import("std");
        \\const common = @import("common.zig");
        \\const Trit = common.Trit;
        \\
        \\
    );

    // Emit implementations for each function found
    for (fn_names) |fn_name| {
        if (IMPLEMENTATIONS.get(fn_name)) |impl| {
            try output.appendSlice(allocator, impl);
            try output.appendSlice(allocator, "\n\n");
        } else {
            try output.appendSlice(allocator, "// TODO: No implementation for ");
            try output.appendSlice(allocator, fn_name);
            try output.appendSlice(allocator, "\n\n");
        }
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
