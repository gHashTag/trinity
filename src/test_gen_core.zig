// Test generated hybrid core operations
const std = @import("std");
const gen_core = @import("vsa/gen_core.zig");

test "bind creates result" {
    var a = try gen_core.HybridBigInt.fromI64(10);
    var b = try gen_core.HybridBigInt.fromI64(5);

    const result = gen_core.bind(&a, &b);

    try std.testing.expectEqual(@as(usize, @min(a.trit_len, b.trit_len)), result.trit_len);
}

test "bundle2 majority vote" {
    var a = try gen_core.HybridBigInt.fromI64(1);
    var b = try gen_core.HybridBigInt.fromI64(1);

    const result = gen_core.bundle2(&a, &b);

    try std.testing.expect(result.trit_len > 0);
}
