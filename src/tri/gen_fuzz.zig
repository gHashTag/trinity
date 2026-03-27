//! tri/fuzz — Fuzzing utilities
//! TTT Dogfood v0.2 Stage 303

const std = @import("std");

pub const Fuzzer = struct {
    rng: std.Random.DefaultPrng,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, seed: u64) Fuzzer {
        return .{
            .rng = std.Random.DefaultPrng.init(seed),
            .allocator = allocator,
        };
    }

    pub fn randomBytes(fuzzer: *Fuzzer, len: usize) ![]u8 {
        const bytes = try fuzzer.allocator.alloc(u8, len);
        var i: usize = 0;
        while (i < len) : (i += 1) {
            bytes[i] = fuzzer.rng.random().int(u8);
        }
        return bytes;
    }

    pub fn randomInt(fuzzer: *Fuzzer, min: i32, max: i32) i32 {
        return fuzzer.rng.random().intRangeAtMost(i32, min, max);
    }
};

test "fuzzer" {
    var fuzzer = Fuzzer.init(std.testing.allocator, 42);
    const bytes = try fuzzer.randomBytes(10);
    defer fuzzer.allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 10), bytes.len);
}
