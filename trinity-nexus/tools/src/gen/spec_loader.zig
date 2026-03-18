const std = @import("std");

/// Loads all .vibee specification files from the specs directory
/// Returns concatenated content as "Divine Mandate"
pub fn loadSpecs(allocator: std.mem.Allocator, base_path: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    // Header
    try result.appendSlice(allocator, "[DIVINE LAW - VIBEE SPECIFICATIONS]\n\n");

    // Walk specs directory
    var dir = std.fs.cwd().openDir(base_path, .{ .iterate = true }) catch |err| {
        std.debug.print("⚠️ Could not open specs directory: {any}\n", .{err});
        try result.appendSlice(allocator, "// No specifications found\n");
        return try result.toOwnedSlice(allocator);
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var file_count: usize = 0;
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".vibee")) continue;

        // Read file content
        const content = dir.readFileAlloc(allocator, entry.path, 1024 * 1024) catch |err| {
            std.debug.print("⚠️ Failed to read {s}: {any}\n", .{ entry.path, err });
            continue;
        };
        defer allocator.free(content);

        // Append to result
        try result.appendSlice(allocator, "// FILE: ");
        try result.appendSlice(allocator, entry.path);
        try result.appendSlice(allocator, "\n");
        try result.appendSlice(allocator, content);
        try result.appendSlice(allocator, "\n\n");

        file_count += 1;
    }

    try result.appendSlice(allocator, "[/DIVINE LAW]\n");

    std.debug.print("📜 [Spec Loader] Loaded {d} sacred texts.\n", .{file_count});

    return try result.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const specs = try loadSpecs(allocator, "../../specs");
    defer allocator.free(specs);

    std.debug.print("\n--- DIVINE MANDATE ---\n{s}\n", .{specs});
}
