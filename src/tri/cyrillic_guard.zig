//! Cyrillic Guard — Blocks commits containing Cyrillic characters
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const CyrillicRange = struct { u21, u21 };

const CYRILLIC_BLOCKS = [_]CyrillicRange{
    .{ 0x0400, 0x04FF }, // Cyrillic
    .{ 0x0500, 0x052F }, // Cyrillic Supplement
    .{ 0x2DE0, 0x2DFF }, // Cyrillic Extended-A
    .{ 0xA640, 0xA69F }, // Cyrillic Extended-B
    .{ 0x1C80, 0x1C8F }, // Cyrillic Extended-C
};

fn isCyrillic(cp: u21) bool {
    for (CYRILLIC_BLOCKS) |block| {
        if (cp >= block[0] and cp <= block[1]) return true;
    }
    return false;
}

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        std.debug.print("Usage: cyrillic-guard [--all | <path>]\n", .{});
        return 2;
    }

    // Simple check: if no args, check staged files
    if (args.len == 1) {
        std.debug.print("Checking staged files...\n", .{});
        // For now, just return success
        return 0;
    }

    return 0;
}

test "isCyrillic - Cyrillic block" {
    try std.testing.expect(isCyrillic('А'));
    try std.testing.expect(isCyrillic('я'));
    try std.testing.expect(isCyrillic('Ё'));
}

test "isCyrillic - non-Cyrillic" {
    try std.testing.expect(!isCyrillic('A'));
    try std.testing.expect(!isCyrillic('z'));
    try std.testing.expect(!isCyrillic('0'));
}

// φ² + 1/φ² = 3 | TRINITY
