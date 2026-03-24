// TTT Temple Guard — PreToolUse Hook Implementation
// Blocks writes to src/temple/** without TEMPLE_RITUAL
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub fn checkTempleAccess(file_path: []const u8, ritual_flag: ?[]const u8) !bool {
    const sacred_path = "src/temple/";

    // Check if path is in TTT
    if (std.mem.indexOf(u8, file_path, sacred_path) == null) {
        return true; // Not in TTT, allow
    }

    // Check for TEMPLE_RITUAL
    const has_ritual = if (ritual_flag) |flag|
        std.mem.eql(u8, flag, "1")
    else
        false;

    if (has_ritual) {
        std.log.warn("TTT: TEMPLE_RITUAL active - modifying sacred layer", .{});
        return true;
    }

    std.log.err("TTT: Access denied to {s}. Use TEMPLE_RITUAL=1.", .{file_path});
    return error.TempleAccessDenied;
}

pub const TempleAccessError = error{
    TempleAccessDenied,
};

test "TTT guard blocks without ritual" {
    const result = checkTempleAccess("src/temple/sacred_math.zig", null);
    try std.testing.expectError(error.TempleAccessDenied, result);
}

test "TTT guard allows with ritual" {
    const result = checkTempleAccess("src/temple/sacred_math.zig", "1");
    try std.testing.expect(result);
}

test "TTT guard allows outside temple" {
    const result = checkTempleAccess("src/tri/main.zig", null);
    try std.testing.expect(result);
}
