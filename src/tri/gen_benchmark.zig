//! tri/benchmark — Performance measurement
//! TTT Dogfood v0.2 Stage 307

const std = @import("std");

pub const Benchmark = struct {
    name: []const u8,
    iterations: usize,

    pub fn init(name: []const u8, iterations: usize) Benchmark {
        return .{
            .name = name,
            .iterations = iterations,
        };
    }

    pub fn run(bm: *const Benchmark, fn_ptr: *const fn () void) u64 {
        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < bm.iterations) : (i += 1) {
            fn_ptr();
        }
        const end = std.time.nanoTimestamp();
        return @intCast(end - start);
    }
};

test "benchmark" {
    var bm = Benchmark.init("test", 100);
    const ns = bm.run(struct {
        fn dummy() void {}
    }.dummy);
    try std.testing.expect(ns > 0);
}
