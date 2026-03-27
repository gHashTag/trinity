//! tri/property — Property-based testing
//! TTT Dogfood v0.2 Stage 304

const std = @import("std");

pub const PropertyTest = struct {
    name: []const u8,
    iterations: usize,

    pub fn init(name: []const u8, iterations: usize) PropertyTest {
        return .{
            .name = name,
            .iterations = iterations,
        };
    }

    pub fn check(pt: PropertyTest, fn_ptr: *const fn (i32) bool) bool {
        var i: usize = 0;
        while (i < pt.iterations) : (i += 1) {
            const input = @as(i32, @intCast(i));
            if (!fn_ptr(input)) return false;
        }
        return true;
    }
};

test "property" {
    var pt = PropertyTest.init("always_positive", 10);
    const result = pt.check(struct {
        fn isPositive(x: i32) bool { return x >= 0; }
    }.isPositive);
    try std.testing.expect(result);
}
