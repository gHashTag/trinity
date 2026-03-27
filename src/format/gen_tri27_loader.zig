// TRI-27 Binary Loader — Generated from specs/format/tri27_loader.tri
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const MAX_FILE_SIZE: u32 = 65536;

pub const LoadError = error{
    InvalidMagic,
    FileTooLarge,
    OutOfBounds,
};

pub const LoadResult = struct {
    entry_point: u32,
    instruction_count: u32,
    code_size: u32,
    data_size: u32,
};

pub fn loadBinary(path: []const u8, comptime memType: type, allocator: std.mem.Allocator) !LoadResult {
    _ = memType;
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > MAX_FILE_SIZE) return LoadError.FileTooLarge;

    const data = try file.readToEndAlloc(allocator, MAX_FILE_SIZE);
    defer allocator.free(data);

    // Read entry point (little-endian)
    const entry: u32 = std.mem.readInt(u32, data[0..4], .little);

    return .{
        .entry_point = entry,
        .instruction_count = 0,
        .code_size = @intCast(data.len - 4),
        .data_size = 0,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "MAX_FILE_SIZE is 64KB" {
    try std.testing.expectEqual(@as(u32, 65536), MAX_FILE_SIZE);
}

test "LoadResult has correct fields" {
    const result = LoadResult{
        .entry_point = 0x1000,
        .instruction_count = 0,
        .code_size = 256,
        .data_size = 0,
    };
    try std.testing.expectEqual(@as(u32, 0x1000), result.entry_point);
}
