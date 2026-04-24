// VSA Core — Simple Test Operations (no HybridBigInt)
// For testing codegen pipeline

const std = @import("std");

pub const Trit = i8;

pub fn bindSimple(a: []const Trit, b: []const Trit) ![]Trit {
    const allocator = std.heap.page_allocator;
    const len = @max(a.len, b.len);
    var result = try allocator.alloc(Trit, len);
    for (0..len) |i| {
        const a_val = if (i < a.len) a[i] else 0;
        const b_val = if (i < b.len) b[i] else 0;
        result[i] = if (b_val == 0) a_val else b_val * a_val;
    }
    return result;
}

test "bindSimple works" {
    const a = [_]Trit{ 1, -1, 0 };
    const b = [_]Trit{ -1, 1, 0 };

    const result = try bindSimple(&a, &b);
    defer std.heap.page_allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(Trit, -1), result[0]);
}
