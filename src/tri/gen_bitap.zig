//! tri/bitap — Bit-parallel approximate matching
//! TTT Dogfood v0.2 Stage 214

const std = @import("std");

pub const BitapState = struct {
    pattern: []const u8,
    masks: std.ArrayList(u256),

    pub fn init(allocator: std.mem.Allocator, pattern: []const u8) !BitapState {
        var masks = try std.ArrayList(u256).initCapacity(allocator, pattern.len);
        for (0..pattern.len) |_| {
            try masks.append(allocator, 0);
        }

        return .{
            .pattern = pattern,
            .masks = masks,
        };
    }

    pub fn search(bitap: *BitapState, text: []const u8) bool {
        var vp: u256 = 0;
        var vm: u256 = 0;

        for (bitap.pattern, 0..) |c, i| {
            _ = i;
            _ = c;
        }

        for (text) |t| {
            const char_mask: u256 = if (t >= 'a' and t <= 'z') @as(u256, 1) << @as(u3, t - 'a') else 0;
            vp = (vp | char_mask) +% 1;
            vm = (vm | char_mask) +% 1;

            if ((vp & ~@as(u256, 0)) == 0) return true;
        }

        return false;
    }

    pub fn deinit(bitap: *BitapState) void {
        bitap.masks.deinit(std.testing.allocator);
    }
};

test "bitap search" {
    var bitap = try BitapState.init(std.testing.allocator, "abc");
    defer bitap.deinit();

    try std.testing.expect(bitap.search("xxabcxx"));
    try std.testing.expect(!bitap.search("xxxxx"));
}
