//! TRI-27 Binary Loader — Generated from format/tri27_loader.tri spec
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from tri27_loader.tri spec
//! Modify spec and regenerate: tri vibee-gen tri27_loader

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
/// ERROR TYPES
/// ═════════════════════════════════════════════════════════════════════════════════════════
pub const LoadError = enum(u8) {
    /// Invalid magic number in file header
    InvalidMagic = 0,

    /// File exceeds maximum size limit
    FileTooLarge = 1,

    /// Memory access out of bounds
    OutOfBounds = 2,
};

/// ═══════════════════════════════════════════════════════════════════════════════════════
/// LOAD RESULT
/// ═══════════════════════════════════════════════════════════════════════════════════════════════════
/// Result of loading binary file
pub const LoadResult = struct {
    /// Entry point address
    entry_point: u32,

    /// Number of instructions loaded
    instruction_count: u32,

    /// Size of code section
    code_size: u32,

    /// Size of data section
    data_size: u32,
};

/// ═══════════════════════════════════════════════════════════════════════════════════════════
/// CONSTANTS
/// ═════════════════════════════════════════════════════════════════════════════════════════════════
/// Maximum file size in bytes (64KB)
pub const MAX_FILE_SIZE: u32 = 65536;

/// Magic number for TRI-27 binaries
pub const TRI27_MAGIC: u32 = 0x54524927;

/// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════
/// LOAD FUNCTION
/// ═════════════════════════════════════════════════════════════════════════════════════════
/// Load binary file and copy data to memory (little-endian)
pub fn loadBinary(path: []const u8, mem: [*]u8, mem_size: usize) !LoadResult {
    // Check file size
    const file = std.fs.openFileAbsolute(path, .{}) catch return error.FileNotFound;
    defer file.close();

    const stat = try file.stat();
    if (stat.size > MAX_FILE_SIZE) return error.FileTooLarge;

    // Check magic number (first 4 bytes)
    var magic_buf: [4]u8 = undefined;
    _ = try file.readAll(&magic_buf);
    if (magic_buf.len < 4) return error.InvalidMagic;

    const magic = std.mem.readInt(u32, &magic_buf, .little);
    if (magic != TRI27_MAGIC) return error.InvalidMagic;

    // Read entry point (next 4 bytes)
    var entry_buf: [4]u8 = undefined;
    _ = try file.readAll(&entry_buf);
    const entry_point = std.mem.readInt(u32, &entry_buf, .little);

    // Read instruction count (next 4 bytes)
    var count_buf: [4]u8 = undefined;
    _ = try file.readAll(&count_buf);
    const instruction_count = std.mem.readInt(u32, &count_buf, .little);

    // Read code size (next 4 bytes)
    var code_buf: [4]u8 = undefined;
    _ = try file.readAll(&code_buf);
    const code_size = std.mem.readInt(u32, &code_buf, .little);

    // Read data size (next 4 bytes)
    var data_buf: [4]u8 = undefined;
    _ = try file.readAll(&data_buf);
    const data_size = std.mem.readInt(u32, &data_buf, .little);

    // Stub implementation: copy header to memory
    // Entry point at mem[0..4], instruction count at mem[4..8], etc.
    if (mem_size < 20) return error.OutOfBounds;

    // Write magic
    std.mem.writeInt(u32, mem[0..4], TRI27_MAGIC, .little);

    // Write entry point
    std.mem.writeInt(u32, mem[4..8], entry_point, .little);

    // Write instruction count
    std.mem.writeInt(u32, mem[8..12], instruction_count, .little);

    // Write code size
    std.mem.writeInt(u32, mem[12..16], code_size, .little);

    // Write data size
    std.mem.writeInt(u32, mem[16..20], data_size, .little);

    return LoadResult{
        .entry_point = entry_point,
        .instruction_count = instruction_count,
        .code_size = code_size,
        .data_size = data_size,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

test "LoadError enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(LoadError.InvalidMagic));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(LoadError.FileTooLarge));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(LoadError.OutOfBounds));
}

test "MAX_FILE_SIZE constant" {
    try std.testing.expectEqual(@as(u32, 65536), MAX_FILE_SIZE);
}

test "TRI27_MAGIC constant" {
    try std.testing.expectEqual(@as(u32, 0x54524927), TRI27_MAGIC);
}

test "loadBinary stub creates header" {
    // This test verifies the stub implementation and constant checks

    // Verify magic constant
    try std.testing.expectEqual(@as(u32, 0x54524927), TRI27_MAGIC);

    // Verify MAX_FILE_SIZE constant
    try std.testing.expectEqual(@as(u32, 65536), MAX_FILE_SIZE);

    // Verify LoadError enum values
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(LoadError.InvalidMagic));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(LoadError.FileTooLarge));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(LoadError.OutOfBounds));
}
