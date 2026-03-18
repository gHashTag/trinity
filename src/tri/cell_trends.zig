const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test args
    var args = std.process.argsAlloc(allocator) catch {
        allocator.free(args);
        std.debug.print("Usage: tri cell trends --days N --format text|json|markdown\n", .{});
        return;
    }
}
