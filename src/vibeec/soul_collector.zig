const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("📚 SOUL COLLECTOR: Gathering Sacred Texts...\n", .{});

    // Output file
    const corpus_file = try std.fs.cwd().createFile("trinity_corpus.txt", .{});
    defer corpus_file.close();

    // Walking the path of knowledge
    var dir = try std.fs.cwd().openDir("../..", .{ .iterate = true }); // Start at project root (trinity/)
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var file_count: usize = 0;
    var total_bytes: usize = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        // Sacred Filters
        const is_vibee = std.mem.endsWith(u8, entry.path, ".vibee");
        const is_zig = std.mem.endsWith(u8, entry.path, ".zig");

        // Exclude profane structures
        const is_git = std.mem.indexOf(u8, entry.path, ".git") != null;
        const is_cache = std.mem.indexOf(u8, entry.path, "zig-cache") != null;
        const is_temp = std.mem.indexOf(u8, entry.path, "temp_generated") != null;

        if ((is_vibee or is_zig) and !is_git and !is_cache and !is_temp) {
            std.debug.print("  - Absorbing: {s}\n", .{entry.path});

            // Read content
            // We need full path relative to cwd where we opened dir
            // Walker returns path relative to opened dir.
            // dir is ../..

            const content = dir.readFileAlloc(allocator, entry.path, 10 * 1024 * 1024) catch |err| {
                std.debug.print("    ⚠️ Failed to read: {any}\n", .{err});
                continue;
            };
            defer allocator.free(content);

            // Write to Corpus
            const header = try std.fmt.allocPrint(allocator, "\n--- FILE: {s} ---\n", .{entry.path});
            try corpus_file.writeAll(header);
            allocator.free(header);

            try corpus_file.writeAll(content);
            try corpus_file.writeAll("\n");

            file_count += 1;
            total_bytes += content.len;
        }
    }

    std.debug.print("\n✅ CORPUS GENERATED: trinity_corpus.txt\n", .{});
    std.debug.print("Files: {d}\n", .{file_count});
    std.debug.print("Knowledge Size: {d} bytes\n", .{total_bytes});
}
