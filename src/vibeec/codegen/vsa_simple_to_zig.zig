// vsa_simple_to_zig.zig — VSA Simple Codegen
// Generates standalone VSA operations
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn generate(allocator: Allocator, source: []const u8) ![]const u8 {
    _ = source;
    var output = std.ArrayListUnmanaged(u8){};

    try output.appendSlice(allocator,
        \\// VSA Simple — Generated from specs/vsa_simple/vsa.tri
        \\// φ² + 1/φ² = 3 | TRINITY
        \\
        \\const std = @import("std");
        \\
        \\pub const Trit = i8;
        \\pub const Vec32i8 = @Vector(32, i8);
        \\pub const Vec32i16 = @Vector(32, i16);
        \\pub const SIMD_WIDTH: usize = 32;
        \\
        \\pub const Vector = struct {
        \\    data: []Trit,
        \\    len: usize,
        \\    allocator: std.mem.Allocator,
        \\
        \\    pub fn init(allocator: std.mem.Allocator, len: usize) !Vector {
        \\        const data = try allocator.alloc(Trit, len);
        \\        return .{ .data = data, .len = len, .allocator = allocator };
        \\    }
        \\
        \\    pub fn clone(self: Vector) !Vector {
        \\        const result = try self.allocator.alloc(Trit, self.len);
        \\        @memcpy(result, self.data);
        \\        return .{ .data = result, .len = self.len, .allocator = self.allocator };
        \\    }
        \\
        \\    pub fn deinit(self: Vector) void {
        \\        self.allocator.free(self.data);
        \\    }
        \\};
        \\
        \\pub fn bind(allocator: std.mem.Allocator, a: Vector, b: Vector) !Vector {
        \\    const len = @max(a.len, b.len);
        \\    const result = try Vector.init(allocator, len);
        \\
        \\    for (0..len) |i| {
        \\        const a_val = if (i < a.len) a.data[i] else 0;
        \\        const b_val = if (i < b.len) b.data[i] else 0;
        \\        result.data[i] = if (b_val == 0) a_val else b_val * a_val;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\pub fn bundle2(allocator: std.mem.Allocator, a: Vector, b: Vector) !Vector {
        \\    const len = @max(a.len, b.len);
        \\    const result = try Vector.init(allocator, len);
        \\
        \\    for (0..len) |i| {
        \\        const a_val = if (i < a.len) a.data[i] else 0;
        \\        const b_val = if (i < b.len) b.data[i] else 0;
        \\        const sum = @as(i16, a_val) + @as(i16, b_val);
        \\        result.data[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        \\    }
        \\
        \\    return result;
        \\}
        \\
        \\pub fn cosineSimilarity(a: Vector, b: Vector) f64 {
        \\    var dot: i64 = 0;
        \\    var norm_a: f64 = 0.0;
        \\    var norm_b: f64 = 0.0;
        \\    const len = @min(a.len, b.len);
        \\
        \\    for (0..len) |i| {
        \\        dot += @as(i64, a.data[i]) * @as(i64, b.data[i]);
        \\        norm_a += @as(f64, @floatFromInt(a.data[i])) * @as(f64, @floatFromInt(a.data[i]));
        \\        norm_b += @as(f64, @floatFromInt(b.data[i])) * @as(f64, @floatFromInt(b.data[i]));
        \\    }
        \\
        \\    const denom = @sqrt(norm_a) * @sqrt(norm_b);
        \\    if (denom == 0.0) return 0.0;
        \\    return @as(f64, @floatFromInt(dot)) / denom;
        \\}
        \\
    );

    return output.toOwnedSlice(allocator);
}

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
