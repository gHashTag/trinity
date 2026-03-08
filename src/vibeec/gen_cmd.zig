const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");
const verilog_codegen = @import("verilog_codegen.zig");
const lang_generators = @import("lang_generators.zig");
const gguf_chat = @import("gguf_chat.zig");
const http_server = @import("http_server.zig");
const agent_mu = @import("agent_mu");
const orchestrator = @import("orchestrator.zig");

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
    } else if (std.mem.eql(u8, command, "ralph")) {
        // Ralph autonomous development loop
        if (args.len < 3) {
            std.debug.print("Error: Missing ralph subcommand\n", .{});
            printRalphUsage();
            return;
        }

        const subcommand = args[2];

        if (std.mem.eql(u8, subcommand, "run")) {
            // Parse options
            var task_filter: ?[]const u8 = null;
            var max_iterations: u32 = 100;
            var verbose: bool = false;
            var auto_fix: bool = true;
            var create_branch: bool = false; // Default: no branch creation

            var i: usize = 3;
            while (i < args.len) : (i += 1) {
                if (std.mem.eql(u8, args[i], "--task") and i + 1 < args.len) {
                    task_filter = args[i + 1];
                    i += 1;
                } else if (std.mem.eql(u8, args[i], "--max-iterations") and i + 1 < args.len) {
                    max_iterations = std.fmt.parseInt(u32, args[i + 1], 10) catch 100;
                    i += 1;
                } else if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
                    verbose = true;
                } else if (std.mem.eql(u8, args[i], "--no-fix")) {
                    auto_fix = false;
                } else if (std.mem.eql(u8, args[i], "--branch")) {
                    create_branch = true;
                }
            }

            try ralphRun(allocator, task_filter, max_iterations, verbose, auto_fix, create_branch);
        } else if (std.mem.eql(u8, subcommand, "status")) {
            try ralphStatus(allocator);
        } else if (std.mem.eql(u8, subcommand, "help") or std.mem.eql(u8, subcommand, "--help")) {
            printRalphUsage();
        } else {
            std.debug.print("Unknown ralph subcommand: {s}\n", .{subcommand});
            printRalphUsage();
        }
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
        \\  vibeec ralph <subcommand> [options]        Ralph autonomous development (v8.11)
        \\    run [--task <name>]                      Run autonomous development cycle
        \\    status                                   Show current task status
        \\    help                                     Show Ralph commands
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

    // AGENT MU: Post-generation verification (Zig code only)
    if (std.mem.eql(u8, spec.language, "zig")) {
        try out_file.sync();

        const config = agent_mu.Config{
            .max_retries = 3,
            .timeout_seconds = 120,
            .verbose = false,
            .enable_auto_fix = true, // Phase 2-4: Auto-fix enabled
        };

        const result = agent_mu.verifyAndFix(allocator, output_path, config) catch |err| {
            std.debug.print("  AGENT MU: Verification failed with error: {}\n", .{err});
            return;
        };

        if (result.success) {
            std.debug.print("  AGENT MU: Verification PASSED\n", .{});
        } else {
            std.debug.print("  AGENT MU: Verification FAILED\n", .{});
            std.debug.print("    Error: {s}\n", .{result.error_message});
            std.debug.print("    Attempts: {d}\n", .{result.attempts_made});
        }
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

// ═══════════════════════════════════════════════════════════════════════════════
// RALPH AUTONOMOUS DEVELOPMENT COMMANDS (v8.11)
// ═══════════════════════════════════════════════════════════════════════════════

/// Run Ralph autonomous development loop
fn ralphRun(
    alloc: std.mem.Allocator,
    task_filter: ?[]const u8,
    max_iterations: u32,
    verbose: bool,
    auto_fix: bool,
    create_branch: bool,
) !void {
    std.debug.print("\n🤖 Ralph Autonomous Development Starting...\n", .{});

    const config = orchestrator.OrchestratorConfig{
        .max_iterations = max_iterations,
        .enable_circuit_breaker = true,
        .rate_limit_per_hour = 100,
        .auto_fix_enabled = auto_fix,
        .verbose = verbose,
        .create_branch = create_branch,
        .commit_on_success = false, // User confirmation required
    };

    var orch = try orchestrator.Orchestrator.init(alloc, config);
    defer orch.deinit();

    const report = try orch.run(task_filter);
    defer report.deinit(alloc);

    // Print report
    std.debug.print("\n═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("📊 Ralph Cycle Report\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("Result: {s}\n", .{report.result.toString()});

    if (report.task) |*task| {
        std.debug.print("Task: {s} {s}\n", .{ task.priority.toString(), task.name });
    }

    std.debug.print("Iteration: {d}/{}\n", .{ report.iteration, max_iterations });
    std.debug.print("Duration: {d}ms\n", .{report.duration_ms});

    if (report.tests_total > 0) {
        std.debug.print("Tests: {d}/{} passed\n", .{ report.tests_passed, report.tests_total });
    }

    if (report.errors_found > 0) {
        std.debug.print("Errors: {d} found, {d} fixed\n", .{ report.errors_found, report.errors_fixed });
    }

    if (report.message.len > 0) {
        std.debug.print("Message: {s}\n", .{report.message});
    }

    std.debug.print("═══════════════════════════════════════════════════════════════════\n\n", .{});

    // Exit with appropriate code
    std.process.exit(switch (report.result) {
        .success, .no_tasks => 0,
        else => 1,
    });
}

/// Show Ralph status
fn ralphStatus(alloc: std.mem.Allocator) !void {
    std.debug.print("\n📊 Ralph Status\n", .{});
    std.debug.print("─────────────────────────────────────────────────────────────\n", .{});

    // Try to read fix_plan.md
    const file = std.fs.cwd().openFile(".ralph/internal/fix_plan.md", .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("⚠️  fix_plan.md not found\n", .{});
            std.debug.print("   Run 'vibeec ralph help' for usage\n", .{});
            return;
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(content);

    // Count tasks
    var p1_count: u32 = 0;
    var p2_count: u32 = 0;
    var p3_count: u32 = 0;
    var completed_count: u32 = 0;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.startsWith(u8, trimmed, "- [x]")) {
            completed_count += 1;
        } else if (std.mem.startsWith(u8, trimmed, "- [ ] [P1]")) {
            p1_count += 1;
        } else if (std.mem.startsWith(u8, trimmed, "- [ ] [P2]")) {
            p2_count += 1;
        } else if (std.mem.startsWith(u8, trimmed, "- [ ] [P3]")) {
            p3_count += 1;
        }
    }

    std.debug.print("Tasks:\n", .{});
    std.debug.print("  [P1] High Priority: {d}\n", .{p1_count});
    std.debug.print("  [P2] Medium: {d}\n", .{p2_count});
    std.debug.print("  [P3] Low: {d}\n", .{p3_count});
    std.debug.print("  ✓ Completed: {d}\n", .{completed_count});
    std.debug.print("─────────────────────────────────────────────────────────────\n\n", .{});
}

/// Print Ralph usage
fn printRalphUsage() void {
    std.debug.print(
        \\
        \\RALPH AUTONOMOUS DEVELOPMENT COMMANDS:
        \\
        \\  vibeec ralph run [options]              Run autonomous development cycle
        \\    --task <name>                         Only work on matching task
        \\    --max-iterations <n>                  Max iterations (default: 100)
        \\    --verbose, -v                         Enable verbose logging
        \\    --no-fix                              Disable auto-fix
        \\    --branch                              Create git branch for work
        \\
        \\  vibeec ralph status                     Show current task status
        \\  vibeec ralph help                       Show this help
        \\
    , .{});
}
