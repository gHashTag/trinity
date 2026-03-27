//! tri/lz77 — LZ77 compression sliding window
//! TTT Dogfood v0.2 Stage 233

const std = @import("std");

pub const LZ77Match = struct {
    offset: usize,
    length: usize,
};

pub const LZ77Encoder = struct {
    window_size: usize,
    lookahead_size: usize,

    pub fn init(window_size: usize, lookahead_size: usize) LZ77Encoder {
        return .{
            .window_size = window_size,
            .lookahead_size = lookahead_size,
        };
    }

    pub fn findMatch(encoder: *const LZ77Encoder, data: []const u8, pos: usize) LZ77Match {
        _ = encoder;
        _ = data;
        _ = pos;
        return .{ .offset = 0, .length = 0 };
    }
};

test "lz77 init" {
    const encoder = LZ77Encoder.init(32768, 258);
    try std.testing.expectEqual(@as(usize, 32768), encoder.window_size);
}
