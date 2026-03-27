//! tri/huffman — Huffman coding for compression
//! TTT Dogfood v0.2 Stage 231

const std = @import("std");

pub const HuffmanNode = struct {
    char: u8,
    freq: usize,
    left: ?*HuffmanNode,
    right: ?*HuffmanNode,
};

pub const HuffmanCode = struct {
    char: u8,
    code: []bool,
};

pub const HuffmanEncoder = struct {
    root: ?*HuffmanNode,
    codes: std.ArrayList(HuffmanCode),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HuffmanEncoder {
        return .{
            .root = null,
            .codes = std.ArrayList(HuffmanCode).initCapacity(allocator, 0),
            .allocator = allocator,
        };
    }

    pub fn buildTree(encoder: *HuffmanEncoder, freqs: []const usize) !void {
        _ = encoder;
        _ = freqs;
    }

    pub fn encode(encoder: *HuffmanEncoder, data: []const u8) ![]bool {
        _ = data;
        const empty = try encoder.allocator.alloc(bool, 0);
        return empty;
    }

    pub fn deinit(encoder: *HuffmanEncoder) void {
        encoder.codes.deinit(encoder.allocator);
    }
};

test "huffman init" {
    var encoder = HuffmanEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try std.testing.expect(encoder.root == null);
}
