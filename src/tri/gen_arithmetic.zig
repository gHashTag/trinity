//! tri/arithmetic — Arithmetic coding
//! TTT Dogfood v0.2 Stage 232

const std = @import("std");

pub const ArithmeticCoder = struct {
    low: u32,
    high: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ArithmeticCoder {
        return .{
            .low = 0,
            .high = std.math.maxInt(u32),
            .allocator = allocator,
        };
    }

    pub fn encode(coder: *ArithmeticCoder, symbol: usize, cum_freq: []const usize, total: usize) !void {
        const range = coder.high - coder.low + 1;
        coder.high = coder.low + @as(u32, @intCast(range * cum_freq[symbol + 1] / total)) - 1;
        coder.low = coder.low + @as(u32, @intCast(range * cum_freq[symbol] / total));
    }

    pub fn deinit(coder: *ArithmeticCoder) void {
        _ = coder;
    }
};

test "arithmetic coder init" {
    const coder = ArithmeticCoder.init(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 0), coder.low);
}
