const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: vibeec <input.vibee> [output.zig]\n", .{});
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

    var codegen = zig_codegen.ZigCodeGen.init(allocator);
    const output = try codegen.generate(&spec);
    defer allocator.free(output);

    const output_path = if (args.len > 2) args[2] else "output.zig";
    
    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    try out_file.writeAll(output);
    
    std.debug.print("Generated: {s}\n", .{output_path});
}
