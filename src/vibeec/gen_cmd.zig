const std = @import("std");

// VIBEE compiler — single source of truth in src/vibeec/
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");
const verilog_codegen = @import("verilog_codegen.zig");
const lang_generators = @import("lang_generators.zig");

// CLI-specific tools (remain local in src/vibeec/)
const gguf_chat = @import("gguf_chat.zig");
const http_server = @import("http_server.zig");

// V10.2: Spec Intelligence
const golden_db = @import("golden_db.zig");
const reasoning_engine = @import("reasoning_engine.zig");
const spec_improver = @import("spec_improver.zig");

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
    } else if (std.mem.eql(u8, command, "improve-spec")) {
        // V10.2: Improve spec by filling empty implementations
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            printUsage();
            return;
        }

        const spec_path = args[2];
        var dry_run: bool = false;
        var min_confidence: f32 = 0.7;

        // Parse optional flags
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--dry-run")) {
                dry_run = true;
            } else if (std.mem.eql(u8, args[i], "--min-confidence") and i + 1 < args.len) {
                min_confidence = std.fmt.parseFloat(f32, args[i + 1]) catch 0.7;
                i += 1;
            }
        }

        try improveSpec(allocator, spec_path, dry_run, min_confidence);
    } else if (std.mem.eql(u8, command, "import-seeds")) {
        // V10.3: Import seeds from generated directory
        if (args.len < 3) {
            std.debug.print("Error: Missing directory\n", .{});
            printUsage();
            return;
        }

        const dir = args[2];
        try importSeeds(allocator, dir);
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
        \\                    VIBEEC - VIBEE Compiler v10.3
        \\                    φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\USAGE:
        \\  vibeec gen <input.vibee> [output.zig]       Generate Zig code from .vibee spec
        \\  vibeec improve-spec <file.vibee> [options]  Fill empty implementations using Golden DB
        \\    --dry-run                                 Show what would be filled without writing
        \\    --min-confidence F                        Minimum confidence threshold (default: 0.7)
        \\  vibeec import-seeds <dir>                   Import seeds from generated/*.zig files
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
    else if (std.mem.eql(u8, language, "python"))
        "py"
    else if (std.mem.eql(u8, language, "typescript"))
        "ts"
    else if (std.mem.eql(u8, language, "rust"))
        "rs"
    else if (std.mem.eql(u8, language, "go"))
        "go"
    else if (std.mem.eql(u8, language, "java"))
        "java"
    else if (std.mem.eql(u8, language, "swift"))
        "swift"
    else if (std.mem.eql(u8, language, "kotlin"))
        "kt"
    else if (std.mem.eql(u8, language, "c"))
        "h"
    else if (std.mem.eql(u8, language, "sql"))
        "sql"
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
    // Note: source is now owned by the spec via spec.source_content
    // Don't free here - spec.deinit() will handle it

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
    } else if (isMultiLangTarget(spec.language)) {
        const output = try generateMultiLang(allocator, &spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
    } else {
        var codegen = zig_codegen.ZigCodeGen.init(allocator);
        const output = try codegen.generate(&spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
    }
}

fn isMultiLangTarget(language: []const u8) bool {
    const targets = [_][]const u8{
        "python", "typescript", "rust",   "go",
        "java",   "swift",      "kotlin", "c",
        "sql",
    };
    for (targets) |t| {
        if (std.mem.eql(u8, language, t)) return true;
    }
    return false;
}

fn generateMultiLang(allocator: std.mem.Allocator, spec: *vibee_parser.VibeeSpec) ![]const u8 {
    var types_buf = try allocator.alloc(lang_generators.TypeDef, spec.types.items.len);
    defer allocator.free(types_buf);

    var fields_bufs = try allocator.alloc([]const lang_generators.Field, spec.types.items.len);
    defer {
        for (fields_bufs) |fb| allocator.free(fb);
        allocator.free(fields_bufs);
    }

    for (spec.types.items, 0..) |t, i| {
        var fields = try allocator.alloc(lang_generators.Field, t.fields.items.len);
        for (t.fields.items, 0..) |f, j| {
            fields[j] = .{ .name = f.name, .type_name = f.type_name };
        }
        fields_bufs[i] = fields;
        types_buf[i] = .{ .name = t.name, .fields = fields };
    }

    var behaviors_buf = try allocator.alloc(lang_generators.Behavior, spec.behaviors.items.len);
    defer allocator.free(behaviors_buf);

    for (spec.behaviors.items, 0..) |b, i| {
        behaviors_buf[i] = .{
            .name = b.name,
            .given = b.given,
            .when = b.when,
            .then = b.then,
            .implementation = b.implementation,
        };
    }

    const parsed = lang_generators.ParsedSpec{
        .name = spec.name,
        .version = spec.version,
        .types = types_buf,
        .behaviors = behaviors_buf,
    };

    return lang_generators.generateForLanguage(allocator, parsed, spec.language);
}

/// V10.2: Improve a spec file by filling empty implementations
fn improveSpec(allocator: std.mem.Allocator, spec_path: []const u8, dry_run: bool, min_confidence: f32) !void {
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.2: Spec Improver                                 ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("  Spec: {s}\n", .{spec_path});
    std.debug.print("  Dry run: {any}\n", .{dry_run});
    std.debug.print("  Min confidence: {d:.1}\n\n", .{min_confidence});

    var improver = try spec_improver.SpecImprover.init(allocator);
    defer improver.deinit();

    const result = try improver.improveSpecFile(spec_path);

    std.debug.print("\n  Results:\n", .{});
    std.debug.print("    Behaviors filled:  {d}\n", .{result.behaviors_filled});
    std.debug.print("    Behaviors skipped: {d}\n", .{result.behaviors_skipped});
    std.debug.print("    Total behaviors:   {d}\n", .{result.behaviors_total});

    if (result.errors.items.len > 0) {
        std.debug.print("\n  Errors:\n", .{});
        for (result.errors.items) |err| {
            std.debug.print("    - {s}: {s}\n", .{err.behavior_name, err.reason});
        }
    }

    std.debug.print("\n", .{});

    // Clean up duplicated error strings
    for (result.errors.items) |err| {
        allocator.free(err.behavior_name);
        allocator.free(err.reason);
    }
    // Cast away const for cleanup - we own this data
    @constCast(&result.errors).deinit(allocator);
}

/// V10.3: Import seeds from generated directory
fn importSeeds(allocator: std.mem.Allocator, dir: []const u8) !void {
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.3: Import Seeds                                   ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("  Directory: {s}\n", .{dir});
    std.debug.print("  Scanning for .zig files...\n\n", .{});

    var golden_db = try golden_db.GoldenDB.init(allocator);
    defer golden_db.deinit();

    const count = try golden_db.importFromGenerated(dir);

    std.debug.print("\n  Results:\n", .{});
    std.debug.print("    Seeds imported: {d}\n", .{count});
    std.debug.print("    Total DB size:  {d}\n", .{golden_db.implementations.items.len});
    std.debug.print("\n", .{});
}
