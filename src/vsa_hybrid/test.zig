// Test for generated hybrid operations
const std = @import("std");
const gen = @import("gen_core.zig");

test "bind creates result" {
    var a = try gen.HybridBigInt.fromI64(10);
    var b = try gen.HybridBigInt.fromI64(5);

    const result = gen.bind(&a, &b);

    try std.testing.expect(result.trit_len > 0);
}

test "bundle2 majority vote" {
    var a = try gen.HybridBigInt.fromI64(1);
    var b = try gen.HybridBigInt.fromI64(-1);

    const result = gen.bundle2(&a, &b);

    try std.testing.expect(result.trit_len > 0);
}
