const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");
const verilog_codegen = @import("verilog_codegen.zig");
const gguf_chat = @import("gguf_chat.zig");
const http_server = @import("http_server.zig");

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
        var temperature: f32 = 0.7;
        var top_p: f32 = 0.9;
        var use_ternary: bool = false;

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
            } else if (std.mem.eql(u8, args[i], "--temperature") and i + 1 < args.len) {
                temperature = std.fmt.parseFloat(f32, args[i + 1]) catch 0.7;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--top-p") and i + 1 < args.len) {
                top_p = std.fmt.parseFloat(f32, args[i + 1]) catch 0.9;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--ternary")) {
                use_ternary = true;
            }
        }

        if (model_path == null) {
            std.debug.print("Error: --model required\n", .{});
            return;
        }

        try gguf_chat.runChatWithTernary(allocator, model_path.?, prompt, max_tokens, temperature, top_p, use_ternary);
    } else if (std.mem.eql(u8, command, "serve")) {
        // HTTP API server
        var model_path: ?[]const u8 = null;
        var port: u16 = 8080;

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
                model_path = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
                port = std.fmt.parseInt(u16, args[i + 1], 10) catch 8080;
                i += 1;
            }
        }

        if (model_path == null) {
            std.debug.print("Error: --model required\n", .{});
            return;
        }

        try http_server.runServer(allocator, model_path.?, port);
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
        \\    --temperature F                           Sampling temperature (default: 0.7)
        \\    --top-p F                                 Top-p nucleus sampling (default: 0.9)
        \\    --ternary                                 Enable BitNet ternary mode (16x memory savings)
        \\  vibeec serve --model <path.gguf> [options]  HTTP API server (OpenAI compatible)
        \\    --port N                                  Port to listen on (default: 8080)
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
