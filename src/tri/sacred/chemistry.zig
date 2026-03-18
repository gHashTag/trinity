// Stub chemistry module for compilation
const std = @import("std");

pub fn init(allocator: std.mem.Allocator) void {
    _ = allocator;
}

pub fn deinit(self: *anyerror!void) void {
    _ = self;
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

test "chemistry module compiles" {
    var allocator = std.testing.allocator;
    init(allocator);
    try std.testing.expect(true);
}

test "chemistry init accepts allocator" {
    init(std.testing.allocator);
}

test "chemistry deinit accepts error union" {
    var e: anyerror!void = {};
    deinit(&e);
}
