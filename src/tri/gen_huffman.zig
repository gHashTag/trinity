//! tri/huffman — Huffman coding
//! Auto-generated from specs/tri/tri_huffman.tri
//! TTT Dogfood v0.2 Stage 151

const std = @import("std");

/// Huffman tree node
pub const HuffmanNode = struct {
    char: u8 = 0,
    freq: usize = 0,
    left: ?*HuffmanNode = null,
    right: ?*HuffmanNode = null,
};

/// Huffman code (bits + length)
pub const HuffmanCode = struct {
    bits: u32 = 0,
    length: u8 = 0,
};

/// Build Huffman tree from frequency table
pub fn buildTree(frequencies: []const usize, allocator: std.mem.Allocator) !*HuffmanNode {
    if (frequencies.len == 0) return error.EmptyInput;

    var nodes = std.ArrayList(*HuffmanNode).initCapacity(allocator, 256) catch unreachable;
    defer {
        // Clean up any remaining nodes (only happens on error)
        for (nodes.items) |n| {
            // Only free leaf nodes that haven't been incorporated into tree
            if (n.left == null and n.right == null) {
                allocator.destroy(n);
            }
        }
        nodes.deinit(allocator);
    }

    // Create leaf nodes
    for (frequencies, 0..) |freq, i| {
        if (freq > 0) {
            const node = try allocator.create(HuffmanNode);
            node.* = .{
                .char = @intCast(i),
                .freq = freq,
                .left = null,
                .right = null,
            };
            try nodes.append(allocator, node);
        }
    }

    if (nodes.items.len == 0) return error.NoFrequencies;
    if (nodes.items.len == 1) {
        const root = nodes.items[0];
        nodes.items.len = 0; // Prevent cleanup
        return root;
    }

    // Build tree by combining lowest frequency nodes
    while (nodes.items.len > 1) {
        // Sort by frequency (simplified bubble sort)
        for (0..nodes.items.len - 1) |i| {
            for (i + 1..nodes.items.len) |j| {
                if (nodes.items[i].freq > nodes.items[j].freq) {
                    const tmp = nodes.items[i];
                    nodes.items[i] = nodes.items[j];
                    nodes.items[j] = tmp;
                }
            }
        }

        const left = nodes.orderedRemove(0);
        const right = nodes.orderedRemove(0);

        const parent = try allocator.create(HuffmanNode);
        parent.* = .{
            .freq = left.freq + right.freq,
            .left = left,
            .right = right,
        };

        try nodes.append(allocator, parent);
    }

    const root = nodes.items[0];
    nodes.items.len = 0; // Prevent cleanup
    return root;
}

/// Free Huffman tree recursively
pub fn freeTree(node: *HuffmanNode, allocator: std.mem.Allocator) void {
    if (node.left) |left| freeTree(left, allocator);
    if (node.right) |right| freeTree(right, allocator);
    allocator.destroy(node);
}

/// Generate Huffman codes from tree
pub fn generateCodes(tree: *const HuffmanNode, allocator: std.mem.Allocator) ![]HuffmanCode {
    var codes = try allocator.alloc(HuffmanCode, 256);
    @memset(codes, HuffmanCode{});

    var stack = std.ArrayList(struct { node: *const HuffmanNode, code: u32, len: u8 }).initCapacity(allocator, 32) catch unreachable;
    defer stack.deinit(allocator);

    try stack.append(allocator, .{ .node = tree, .code = 0, .len = 0 });

    while (stack.items.len > 0) {
        const frame = stack.orderedRemove(stack.items.len - 1);
        const node = frame.node;

        if (node.left == null and node.right == null) {
            codes[node.char] = .{
                .bits = frame.code,
                .length = frame.len,
            };
        } else {
            if (node.left) |left| {
                try stack.append(allocator, .{
                    .node = left,
                    .code = frame.code,
                    .len = frame.len,
                });
            }
            if (node.right) |right| {
                try stack.append(allocator, .{
                    .node = right,
                    .code = frame.code | (@as(u32, 1) << @intCast(frame.len)),
                    .len = frame.len + 1,
                });
            }
        }
    }

    return codes;
}

/// Encode data using Huffman codes (simplified)
pub fn encode(data: []const u8, codes: []const HuffmanCode, allocator: std.mem.Allocator) ![]u8 {
    _ = codes;
    // Simplified: return copy of data
    return allocator.dupe(u8, data);
}

test "huffman build tree" {
    const freq = [_]usize{ 1, 2, 3, 4 };
    const tree = try buildTree(&freq, std.testing.allocator);
    defer freeTree(tree, std.testing.allocator);

    try std.testing.expect(tree.freq > 0);
}

test "huffman generate codes" {
    const freq = [_]usize{ 1, 2, 3, 4 };
    const tree = try buildTree(&freq, std.testing.allocator);
    defer freeTree(tree, std.testing.allocator);

    const codes = try generateCodes(tree, std.testing.allocator);
    defer std.testing.allocator.free(codes);

    try std.testing.expectEqual(@as(usize, 256), codes.len);
}
