// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 LOADER — Minimal Stub Implementation

const std = @import("std");
const Memory = @import("tri_memory.zig").Memory;

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

pub fn loadBinary(path: []const u8, mem: *Memory, allocator: std.mem.Allocator) !LoadResult {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > 65536) return LoadError.FileTooLarge;

    const data = try file.readToEndAlloc(allocator, 65536);
    defer allocator.free(data);

    // Read entry point (little-endian)
    const entry: u32 = std.mem.readInt(u32, data[0..4], .little);

    // Copy data to memory (byte-by-byte for compatibility with MemoryView
    for (data[4..], 0..) |_, i| {
        const word: u32 = @intCast(i);
        try mem.writeWord(@intCast(i * 4), word);
    }

    return .{
        .entry_point = entry,
        .instruction_count = 0,
        .code_size = @intCast(data.len - 4),
        .data_size = 0,
    };
}
