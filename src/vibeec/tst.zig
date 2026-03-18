//! TRINITY SPECS TRANSMUTER (TST) V1.0
//! Transmutes YAML-like .tri specs into native .tri knowledge blobs
//! φ² + 1/φ² = 3

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: tst <dir_or_file>\n", .{});
        return;
    }

    const target = args[1];
    const stat = try std.fs.cwd().statFile(target);
    if (stat.kind == .file) {
        try transmuteFile(target, allocator);
    } else {
        // Batch directory processing
        var dir = try std.fs.cwd().openDir(target, .{ .iterate = true });
        defer dir.close();
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
                const path = try std.fs.path.join(allocator, &.{ target, entry.name });
                defer allocator.free(path);
                try transmuteFile(path, allocator);
            }
        }
    }
}

fn transmuteFile(path: []const u8, allocator: std.mem.Allocator) !void {
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(source);

    std.debug.print("💎 TRANSMUTING SPEC: {s} -> .tri\n", .{path});

    var triads = std.ArrayListUnmanaged(u21){};
    defer triads.deinit(allocator);

    var i: usize = 0;
    while (i < source.len) : (i += 3) {
        const remaining = source.len - i;
        const chunk_size = @min(remaining, @as(usize, 3));
        const chunk = source[i .. i + chunk_size];
        var hash: u32 = 0;
        for (chunk) |c| hash += c;

        // and on 27 toin (CIS range: 0x2C80 - 0x2C9A)
        const op_idx: u21 = @intCast(hash % 27);
        try triads.append(allocator, @as(u21, 0x2C80) + op_idx);
    }

    const output_path = try std.mem.concat(allocator, u8, &.{ path[0 .. path.len - 6], ".tri" });
    defer allocator.free(output_path);

    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    for (triads.items) |op| {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(op, &buf);
        try file.writeAll(buf[0..len]);
    }

    std.debug.print("   ✅ Created knowledge-triad: {s} ({d} units)\n", .{ output_path, triads.items.len });
}
