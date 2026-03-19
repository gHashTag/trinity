const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: vibeec <input.vibee>\n", .{});
        return;
    }

    const input_path = args[1];
    std.debug.print("Input: {s}\n", .{input_path});

    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    std.debug.print("Parsed: {s} v{s}\n", .{spec.name, spec.version});
}
