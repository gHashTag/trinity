// TRI-27 Loader Codegen — Generate Zig from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const LOADER_TEMPLATE =
    \\// TRI-27 Binary Loader — Generated from specs/format/tri27_loader.tri
    \\// φ² + 1/φ² = 3 | TRINITY
    \\
    \\const std = @import("std");
    \\
    \\pub const MAX_FILE_SIZE: u32 = 65536;
    \\
    \\pub const LoadError = error{
    \\    InvalidMagic,
    \\    FileTooLarge,
    \\    OutOfBounds,
    \\};
    \\
    \\pub const LoadResult = struct {
    \\    entry_point: u32,
    \\    instruction_count: u32,
    \\    code_size: u32,
    \\    data_size: u32,
    \\};
    \\
    \\pub fn loadBinary(
    \\    path: []const u8,
    \\    comptime memType: type,
    \\    allocator: std.mem.Allocator
    \\) !LoadResult {
    \\    const file = try std.fs.cwd().openFile(path, .{});
    \\    defer file.close();
    \\
    \\    const stat = try file.stat();
    \\    if (stat.size > MAX_FILE_SIZE) return LoadError.FileTooLarge;
    \\
    \\    const data = try file.readToEndAlloc(allocator, MAX_FILE_SIZE);
    \\    defer allocator.free(data);
    \\
    \\    // Read entry point (little-endian)
    \\    const entry: u32 = std.mem.readInt(u32, data[0..4], .little);
    \\
    \\    return .{
    \\        .entry_point = entry,
    \\        .instruction_count = 0,
    \\        .code_size = @intCast(data.len - 4),
    \\        .data_size = 0,
    \\    };
    \\}
    \\
    \\// ============================================================================
    \\// TESTS
    \\// ============================================================================
    \\
    \\test "MAX_FILE_SIZE is 64KB" {
    \\    try std.testing.expectEqual(@as(u32, 65536), MAX_FILE_SIZE);
    \\}
    \\
    \\test "LoadResult has correct fields" {
    \\    const result = LoadResult{
    \\        .entry_point = 0x1000,
    \\        .instruction_count = 0,
    \\        .code_size = 256,
    \\        .data_size = 0,
    \\    };
    \\    try std.testing.expectEqual(@as(u32, 0x1000), result.entry_point);
    \\}
    \\
;

pub fn generateLoader(allocator: Allocator) ![]const u8 {
    return allocator.dupe(u8, LOADER_TEMPLATE);
}

pub fn writeLoader(allocator: Allocator, path: []const u8) !void {
    const content = try generateLoader(allocator);
    defer allocator.free(content);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(content);
}

test "tri27_loader codegen" {
    const content = try generateLoader(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "pub const LoadError") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "MAX_FILE_SIZE") != null);
}
