// ═══════════════════════════════════════════════════════════════════════════════
// tri_compile.zig - Tri Language Compiler CLI
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Wave 2: .tri → typecheck → emit_t27 → .t27
//
// Usage: tri compile <input.tri> [--target t27] [-o output.t27]
//
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_lang = @import("tri_lang");
const compileFile = tri_lang.compileFile;

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: tri compile <input.tri> [--target t27] [-o output.t27]\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --target t27    Compile to TRI-27 bytecode (default)\n", .{});
        std.debug.print("  -o <file>       Output file (default: input.t27)\n", .{});
        return;
    }

    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var target_t27 = false;

    var arg_idx: usize = 0;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        if (std.mem.eql(u8, arg, "--target")) {
            if (arg_idx + 1 >= args.len) {
                std.debug.print("Error: --target requires an argument\n", .{});
                return error.MissingArgument;
            }
            arg_idx += 1;
            const target = args[arg_idx];
            if (std.mem.eql(u8, target, "t27")) {
                target_t27 = true;
            } else {
                std.debug.print("Error: unknown target '{s}'\n", .{target});
                return error.UnknownTarget;
            }
        } else if (std.mem.eql(u8, arg, "-o")) {
            if (arg_idx + 1 >= args.len) {
                std.debug.print("Error: -o requires an argument\n", .{});
                return error.MissingArgument;
            }
            arg_idx += 1;
            output_path = args[arg_idx];
        } else if (arg[0] != '-') {
            // Input file (first non-flag argument)
            if (input_path == null) {
                input_path = arg;
            }
        }
    }

    if (input_path == null) {
        std.debug.print("Error: no input file specified\n", .{});
        return error.NoInputFile;
    }

    // Default output path
    if (output_path == null) {
        // Replace .tri extension with .t27
        const ext = std.fs.path.extension(input_path.?);
        if (std.mem.eql(u8, ext, ".tri")) {
            const stem = std.fs.path.stem(input_path.?);
            output_path = try std.fmt.allocPrint(allocator, "{s}.t27", .{stem});
        } else {
            output_path = try std.fmt.allocPrint(allocator, "{s}.t27", .{input_path.?});
        }
    }

    // Default target is t27
    if (!target_t27) {
        target_t27 = true;
    }

    std.debug.print("Compiling: {s} → {s}\n", .{ input_path.?, output_path.? });

    if (target_t27) {
        try compileFile(allocator, input_path.?, output_path.?);
        std.debug.print("✅ Compiled successfully\n", .{});
    }
}
