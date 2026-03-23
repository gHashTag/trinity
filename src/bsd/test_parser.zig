const std = @import("std");

pub fn main() !void {
    const path = "/Users/playra/trinity-w1/data/ecdata/allbsd/allbsd.00000-09999";
    const db = try std.fs.cwd().openFile(path, .{});
    defer db.close();

    const stat_info = try db.stat();
    const content = try std.heap.page_allocator.alloc(u8, @as(usize, @intCast(stat_info.size)));
    defer std.heap.page_allocator.free(content);

    _ = try db.readAll(content);

    var line_iter = std.mem.tokenizeScalar(u8, content, '\n');
    const first_line = line_iter.next() orelse return error.NoLine;

    std.debug.print("First line: {s}\n", .{first_line});
    std.debug.print("First line bytes: ", .{});
    for (first_line) |b| {
        std.debug.print("{x} ", .{b});
    }
    std.debug.print("\n", .{});

    // Test tokenization
    std.debug.print("\nTokenization:\n", .{});
    var iter = std.mem.tokenizeScalar(u8, first_line, ' ');
    var field_num: usize = 0;
    while (iter.next()) |field| {
        field_num += 1;
        std.debug.print("Field {d}: [{s}] len={d}\n", .{ field_num, field, field.len });
    }

    // Try parsing root_number directly
    std.debug.print("\nParsing root_number:\n", .{});
    iter.reset(); // Reset to beginning
    var idx: usize = 0;
    while (iter.next()) |field| : (idx += 1) {
        if (idx == 10) { // 11th field (0-indexed)
            std.debug.print("Raw field: [{s}]\n", .{field});
            const trimmed = std.mem.trim(u8, field, " \t\r\n");
            std.debug.print("Trimmed: [{s}] len={d}\n", .{ trimmed, trimmed.len });
            const root_number = std.fmt.parseInt(i8, trimmed, 10);
            std.debug.print("Parsed: {!}\n", .{root_number});
        }
    }
}
