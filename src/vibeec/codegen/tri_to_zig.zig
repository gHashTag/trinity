// ═══════════════════════════════════════════════════════════════════════════════
// tri_to_zig.zig — Tri to Zig Codegen (Stage 1.0)
// ═══════════════════════════════════════════════════════════════════════════════
// Full template-based codegen for 17 VSA operations
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ─────────────────────────────────────────────────────────────────────────────
// FULL TEMPLATE IMPLEMENTATIONS (Stage 1.0)
// ─────────────────────────────────────────────────────────────────────────────

const IMPLEMENTATIONS = struct {
    pub fn get(name: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, name, "bind")) return 
        \\pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
        \\    const len = @max(a.len, b.len);
        \\    var result = try allocator.alloc(Trit, len);
        \\    for (0..len) |i| {
        \\        const a_val = if (i < a.len) a[i] else 0;
        \\        const b_val = if (i < b.len) b[i] else 0;
        \\        result[i] = if (b_val == 0) a_val else b_val * a_val;
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "unbind")) return 
        \\pub fn unbind(allocator: std.mem.Allocator, bound: []const Trit, key: []const Trit) ![]Trit {
        \\    const len = @max(bound.len, key.len);
        \\    var result = try allocator.alloc(Trit, len);
        \\    for (0..len) |i| {
        \\        const b_val = if (i < bound.len) bound[i] else 0;
        \\        const k_val = if (i < key.len) key[i] else 0;
        \\        result[i] = if (k_val == 0) b_val else k_val * b_val;
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "bundle2")) return 
        \\pub fn bundle2(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
        \\    const len = @max(a.len, b.len);
        \\    var result = try allocator.alloc(Trit, len);
        \\    for (0..len) |i| {
        \\        const a_val = if (i < a.len) a[i] else 0;
        \\        const b_val = if (i < b.len) b[i] else 0;
        \\        const sum = a_val + b_val;
        \\        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "bundle3")) return 
        \\pub fn bundle3(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit, c: []const Trit) ![]Trit {
        \\    const len = @max(@max(a.len, b.len), c.len);
        \\    var result = try allocator.alloc(Trit, len);
        \\    for (0..len) |i| {
        \\        const a_val = if (i < a.len) a[i] else 0;
        \\        const b_val = if (i < b.len) b[i] else 0;
        \\        const c_val = if (i < c.len) c[i] else 0;
        \\        const sum = a_val + b_val + c_val;
        \\        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "bundleN")) return 
        \\pub fn bundleN(allocator: std.mem.Allocator, vectors: []const []const Trit) ![]Trit {
        \\    if (vectors.len == 0) return error.EmptyVectorList;
        \\    var len: usize = 0;
        \\    for (vectors) |v| len = @max(len, v.len);
        \\    var result = try allocator.alloc(Trit, len);
        \\    for (0..len) |i| {
        \\        var sum: i32 = 0;
        \\        for (vectors) |v| {
        \\            const val = if (i < v.len) v[i] else 0;
        \\            sum += val;
        \\        }
        \\        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "permute")) return 
        \\pub fn permute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {
        \\    if (v.len == 0) return try allocator.alloc(Trit, 0);
        \\    const result = try allocator.alloc(Trit, v.len);
        \\    const rotate = @mod(n, v.len);
        \\    for (0..v.len) |i| {
        \\        const src_idx = if (i >= rotate) i - rotate else i + v.len - rotate;
        \\        result[i] = v[src_idx];
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "inversePermute")) return 
        \\pub fn inversePermute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {
        \\    if (v.len == 0) return try allocator.alloc(Trit, 0);
        \\    const result = try allocator.alloc(Trit, v.len);
        \\    const rotate = @mod(n, v.len);
        \\    for (0..v.len) |i| {
        \\        const src_idx = (i + rotate) % v.len;
        \\        result[i] = v[src_idx];
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "cosineSimilarity")) return 
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
        ;

        if (std.mem.eql(u8, name, "hammingDistance")) return 
        \\pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {
        \\    var count: usize = 0;
        \\    const len = @min(a.len, b.len);
        \\    for (0..len) |i| {
        \\        if (a[i] != b[i]) count += 1;
        \\    }
        \\    return count;
        \\}
        ;

        if (std.mem.eql(u8, name, "hammingSimilarity")) return 
        \\pub fn hammingSimilarity(a: []const Trit, b: []const Trit) f64 {
        \\    const dist = hammingDistance(a, b);
        \\    const max_len = @max(a.len, b.len);
        \\    if (max_len == 0) return 1.0;
        \\    return 1.0 - (@as(f64, @floatFromInt(dist)) / @as(f64, @floatFromInt(max_len)));
        \\}
        ;

        if (std.mem.eql(u8, name, "dotSimilarity")) return 
        \\pub fn dotSimilarity(a: []const Trit, b: []const Trit) i64 {
        \\    var sum: i64 = 0;
        \\    const len = @min(a.len, b.len);
        \\    for (0..len) |i| {
        \\        sum += a[i] * b[i];
        \\    }
        \\    return sum;
        \\}
        ;

        if (std.mem.eql(u8, name, "vectorNorm")) return 
        \\pub fn vectorNorm(v: []const Trit) f64 {
        \\    var sum: f64 = 0.0;
        \\    for (v) |x| {
        \\        sum += @as(f64, @floatFromInt(x)) * @as(f64, @floatFromInt(x));
        \\    }
        \\    return @sqrt(sum);
        \\}
        ;

        if (std.mem.eql(u8, name, "countNonZero")) return 
        \\pub fn countNonZero(v: []const Trit) usize {
        \\    var count: usize = 0;
        \\    for (v) |x| {
        \\        if (x != 0) count += 1;
        \\    }
        \\    return count;
        \\}
        ;

        if (std.mem.eql(u8, name, "randomVector")) return 
        \\pub fn randomVector(allocator: std.mem.Allocator, len: usize, seed: u64) ![]Trit {
        \\    if (len == 0) return try allocator.alloc(Trit, 0);
        \\    var result = try allocator.alloc(Trit, len);
        \\    var rng = std.rand.DefaultPrng.init(seed);
        \\    for (0..len) |i| {
        \\        const val = rng.random().int(i3) - 1;
        \\        result[i] = @as(Trit, @intCast(val));
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "encodeSequence")) return 
        \\pub fn encodeSequence(allocator: std.mem.Allocator, text: []const u8) ![]Trit {
        \\    const trits_per_byte: usize = 5;
        \\    const result_len = text.len * trits_per_byte;
        \\    var result = try allocator.alloc(Trit, result_len);
        \\    for (text, 0..) |byte, i| {
        \\        const base_idx = i * trits_per_byte;
        \\        const b = @as(i32, byte);
        \\        result[base_idx + 0] = @as(Trit, @intCast(@mod(b + 1, 3))) - 1;
        \\        result[base_idx + 1] = @as(Trit, @intCast(@mod(b + 2, 3))) - 1;
        \\        result[base_idx + 2] = @as(Trit, @intCast(@mod(b + 3, 3))) - 1;
        \\        result[base_idx + 3] = @as(Trit, @intCast(@mod(b + 4, 3))) - 1;
        \\        result[base_idx + 4] = @as(Trit, @intCast(@mod(b + 5, 3))) - 1;
        \\    }
        \\    return result;
        \\}
        ;

        if (std.mem.eql(u8, name, "probeSequence")) return 
        \\pub fn probeSequence(allocator: std.mem.Allocator, sequence: []const Trit, query: []const Trit) ![]f64 {
        \\    if (query.len == 0) {
        \\        const result = try allocator.alloc(f64, 1);
        \\        result[0] = 0.0;
        \\        return result;
        \\    }
        \\    if (sequence.len < query.len) {
        \\        const result = try allocator.alloc(f64, 1);
        \\        result[0] = 0.0;
        \\        return result;
        \\    }
        \\    const window_count = sequence.len - query.len + 1;
        \\    var result = try allocator.alloc(f64, window_count);
        \\    for (0..window_count) |i| {
        \\        const window = sequence[i..][0..query.len];
        \\        result[i] = cosineSimilarity(window, query);
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
        if (self.pos < self.source.len) self.pos += 1;
    }

    fn skipComments(self: *TriParser) void {
        while (true) {
            self.skipWhitespace();
            if (self.pos >= self.source.len) break;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '/' and self.source[self.pos + 1] == '/') {
                self.skipLine();
                continue;
            }

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
        while (self.pos < self.source.len and !std.ascii.isWhitespace(self.source[self.pos]) and self.source[self.pos] != ',' and self.source[self.pos] != ')' and self.source[self.pos] != ':' and self.source[self.pos] != ';') {
            if (self.source[self.pos] == '[') {
                while (self.pos < self.source.len and self.source[self.pos] != ']') {
                    self.pos += 1;
                }
                if (self.pos < self.source.len) self.pos += 1;
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

    fn parseFnSignature(self: *TriParser, allocator: Allocator) !?FnSignature {
        self.skipComments();

        if (self.pos + 1 >= self.source.len) return null;

        while (self.pos < self.source.len - 2) {
            if (self.source[self.pos] == 'f' and self.source[self.pos + 1] == 'n') {
                const next_char = if (self.pos + 2 < self.source.len)
                    self.source[self.pos + 2]
                else
                    ' ';

                if (std.ascii.isWhitespace(next_char) or next_char == '(') {
                    self.pos += 2;
                    self.skipComments();
                    break;
                }
            }
            self.pos += 1;
        }

        if (self.pos >= self.source.len - 2) return null;

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

        self.skipComments();
        const return_type = self.parseType() orelse return null;
        _ = self.expect(';');

        const owned_params = try allocator.dupe(FnParam, params.items);

        return FnSignature{
            .name = try allocator.dupe(u8, name),
            .params = owned_params,
            .return_type = try allocator.dupe(u8, return_type),
            .has_allocator = has_allocator,
        };
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
};

const FnParam = struct {
    name: []const u8,
    type_str: []const u8,
};

const FnSignature = struct {
    name: []const u8,
    params: []FnParam,
    return_type: []const u8,
    has_allocator: bool,
};

// ─────────────────────────────────────────────────────────────────────────────
// CODEGEN
// ─────────────────────────────────────────────────────────────────────────────

pub fn generate(allocator: Allocator, source: []const u8) ![]const u8 {
    var parser = TriParser.init(source);
    var output = std.ArrayListUnmanaged(u8){};

    try output.appendSlice(allocator,
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// VSA Core — Operations (GENERATED from .tri spec)
        \\// Stage 1.0: Full template codegen
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

        const impl = IMPLEMENTATIONS.get(sig.name) orelse {
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
