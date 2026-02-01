const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");
const verilog_codegen = @import("verilog_codegen.zig");
const gguf_chat = @import("gguf_chat.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "gen")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing input file\n", .{});
            printUsage();
            return;
        }

        const input_path = args[2];
        const language = detectLanguage(allocator, input_path) catch "zig";

        var derived_path: ?[]const u8 = null;
        defer if (derived_path) |p| allocator.free(p);

        const output_path = if (args.len > 3) args[3] else blk: {
            derived_path = deriveOutputPath(allocator, input_path, language) catch {
                std.debug.print("Error: Could not derive output path\n", .{});
                return;
            };
            break :blk derived_path.?;
        };

        try generateCode(allocator, input_path, output_path);
    } else if (std.mem.eql(u8, command, "chat")) {
        // Chat with GGUF model
        var model_path: ?[]const u8 = null;
        var prompt: ?[]const u8 = null;
        var max_tokens: u32 = 100;

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
                model_path = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--prompt") and i + 1 < args.len) {
                prompt = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--max-tokens") and i + 1 < args.len) {
                max_tokens = std.fmt.parseInt(u32, args[i + 1], 10) catch 100;
                i += 1;
            }
        }

        if (model_path == null) {
            std.debug.print("Error: --model required\n", .{});
            return;
        }

        try gguf_chat.runChat(allocator, model_path.?, prompt, max_tokens);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\                    VIBEEC - VIBEE Compiler v24.φ
        \\                    φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\USAGE:
        \\  vibeec gen <input.vibee> [output.zig]       Generate Zig code from .vibee spec
        \\  vibeec chat --model <path.gguf> [options]   Chat with GGUF model (SIMD optimized)
        \\    --prompt "text"                           Initial prompt
        \\    --max-tokens N                            Max tokens to generate (default: 100)
        \\  vibeec help                                 Show this help
        \\
    , .{});
}

fn detectLanguage(allocator: std.mem.Allocator, input_path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 9 and std.mem.eql(u8, trimmed[0..9], "language:")) {
            const value = std.mem.trim(u8, trimmed[9..], " \t\"");
            if (value.len > 0) {
                return try allocator.dupe(u8, value);
            }
        }
    }
    return "zig";
}

fn deriveOutputPath(allocator: std.mem.Allocator, input_path: []const u8, language: []const u8) ![]const u8 {
    const basename = std.fs.path.basename(input_path);
    const stem = std.fs.path.stem(basename);

    const ext = if (std.mem.eql(u8, language, "verilog") or std.mem.eql(u8, language, "varlog"))
        "v"
    else
        "zig";

    const dir = if (std.mem.eql(u8, language, "verilog") or std.mem.eql(u8, language, "varlog"))
        "trinity/output/fpga"
    else
        "generated";

    return try std.fmt.allocPrint(allocator, "{s}/{s}.{s}", .{ dir, stem, ext });
}

fn generateCode(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("  Input:  {s}\n", .{input_path});
    std.debug.print("  Output: {s}\n", .{output_path});

    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    const dir_path = std.fs.path.dirname(output_path) orelse ".";
    std.fs.cwd().makePath(dir_path) catch {};

    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    if (std.mem.eql(u8, spec.language, "verilog") or std.mem.eql(u8, spec.language, "varlog")) {
        const output = try verilog_codegen.generateVerilog(allocator, &spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
    } else {
        var codegen = zig_codegen.ZigCodeGen.init(allocator);
        // defer codegen.deinit();
        const output = try codegen.generate(&spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
    }
}
