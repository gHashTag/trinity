const std = @import("std");
const ReticularLoader = @import("emu/reticular_loader.zig").ReticularLoader;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var loader = ReticularLoader.init(allocator);

    // Load reticular_raphe.t27 program
    const source = @embedFile("reticular_raphe.t27");
    const bytecode = try loader.loadFromSource(source);
    defer allocator.free(bytecode);

    std.debug.print("✓ reticular_raphe.t27 assembled: {} bytes, {} instructions\n", .{ bytecode.len, bytecode.len / 4 });

    // Don't execute for now - the program may have infinite loop issues
    // TODO: Fix reticular_raphe.t27 to properly terminate
}
