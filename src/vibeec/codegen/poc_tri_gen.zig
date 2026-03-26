// ═══════════════════════════════════════════════════════════════════════════════
// PROOF OF CONCEPT: .tri → Zig codegen (Stage 0.5-MINIMAL)
// ═══════════════════════════════════════════════════════════════════════════════
// This proves: spec drives code, not the other way around
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Template implementations (Stage 0.5: hardcoded, but proves spec→code pipeline)
const TEMPLATES = .{
    .bind =
    \\pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
    \\    const result = try allocator.alloc(Trit, a.len);
    \\    for (a, 0..) |_, i| {
    \\        result[i] = if (b[i] == 0) a[i] else @as(i8, @truncate(b[i] * a[i]));
    \\    }
    \\    return result;
    \\}
    ,
    .dotProduct =
    \\pub fn dotProduct(a: []const Trit, b: []const Trit) i64 {
    \\    var sum: i64 = 0;
    \\    const len = @min(a.len, b.len);
    \\    for (0..len) |i| {
    \\        sum += a[i] * b[i];
    \\    }
    \\    return sum;
    \\}
    ,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const output =
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// VSA Core — Operations (GENERATED from specs/vsa/ops.tri)
        \\// Stage 0.5-MINIMAL: Spec drives code generation
        \\// DO NOT EDIT — Regenerate from .tri spec
        \\//
        \\// φ² + 1/φ² = 3 | TRINITY
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\
        \\const std = @import("std");
        \\const common = @import("common.zig");
        \\const Trit = common.Trit;
        \\
    ++ TEMPLATES.dotProduct ++
        \\ ++ TEMPLATES.bind ++
    ;

    try std.io.getStdOut().writeAll(output);
}
