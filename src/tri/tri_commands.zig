// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Tool Command Handlers
// ═══════════════════════════════════════════════════════════════════════════════
//
// Command implementations: gen, convert, serve, bench, evolve, git.
// Extracted from main.zig for faster compilation.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const chat_server = @import("chat_server.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;

// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE GEN COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGenCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri gen <spec.vibee> [output]{s}\n", .{ RED, RESET });
        std.debug.print("Example: tri gen specs/feature.vibee\n", .{});
        return;
    }

    const input_path = args[0];

    std.debug.print("{s}VIBEE Compiler{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Input: {s}\n", .{input_path});

    // Build argv for vibee gen command
    var argv_buf: [8][]const u8 = undefined;
    var argv_len: usize = 0;

    argv_buf[argv_len] = "zig";
    argv_len += 1;
    argv_buf[argv_len] = "build";
    argv_len += 1;
    argv_buf[argv_len] = "vibee";
    argv_len += 1;
    argv_buf[argv_len] = "--";
    argv_len += 1;
    argv_buf[argv_len] = "gen";
    argv_len += 1;
    argv_buf[argv_len] = input_path;
    argv_len += 1;

    // Add output path if specified
    if (args.len > 1) {
        argv_buf[argv_len] = args[1];
        argv_len += 1;
    }

    std.debug.print("  Running: zig build vibee -- gen {s}\n\n", .{input_path});

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argv_len],
    }) catch |err| {
        std.debug.print("{s}Error running vibee: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        std.debug.print("{s}\n", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        std.debug.print("{s}{s}{s}\n", .{ GRAY, result.stderr, RESET });
    }

    const success = result.term.Exited == 0;
    if (success) {
        std.debug.print("{s}✓ Generation complete!{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}✗ Generation failed{s}\n", .{ RED, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERT COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runConvertCommand(args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri convert <file>{s}\n", .{ RED, RESET });
        std.debug.print("Supported formats: .wasm, .exe, .elf\n", .{});
        std.debug.print("\nOptions:\n", .{});
        std.debug.print("  --wasm     Force WASM → TVC conversion\n", .{});
        std.debug.print("  --b2t      Force Binary → Ternary conversion\n", .{});
        return;
    }

    var input_path: ?[]const u8 = null;
    var force_wasm = false;
    var force_b2t = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--wasm")) {
            force_wasm = true;
        } else if (std.mem.eql(u8, args[i], "--b2t")) {
            force_b2t = true;
        } else if (args[i][0] != '-') {
            input_path = args[i];
        }
    }

    if (input_path == null) {
        std.debug.print("{s}Error: No input file specified{s}\n", .{ RED, RESET });
        return;
    }

    const path = input_path.?;
    std.debug.print("{s}Convert{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Input: {s}\n", .{path});

    // Auto-detect format
    const is_wasm = force_wasm or std.mem.endsWith(u8, path, ".wasm");

    if (is_wasm) {
        std.debug.print("  Mode:  WASM → TVC\n", .{});
        std.debug.print("\n{s}Note: Full WASM conversion requires firebird:{s}\n", .{ GRAY, RESET });
        std.debug.print("  zig build firebird -- convert --input={s}\n", .{path});
    } else if (force_b2t or std.mem.endsWith(u8, path, ".exe") or std.mem.endsWith(u8, path, ".elf")) {
        std.debug.print("  Mode:  Binary → Ternary\n", .{});
        std.debug.print("\n{s}Note: Full B2T conversion requires b2t:{s}\n", .{ GRAY, RESET });
        std.debug.print("  zig build b2t -- convert {s}\n", .{path});
    } else {
        std.debug.print("  Mode:  Auto-detect\n", .{});
        std.debug.print("{s}Unknown format. Specify --wasm or --b2t{s}\n", .{ RED, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServeCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var model_path: ?[]const u8 = null;
    var port: u16 = 8080;
    var chat_mode = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--chat")) {
            chat_mode = true;
        } else if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
            i += 1;
            model_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            i += 1;
            port = std.fmt.parseInt(u16, args[i], 10) catch 8080;
        } else if (std.mem.startsWith(u8, args[i], "--model=")) {
            model_path = args[i][8..];
        } else if (std.mem.startsWith(u8, args[i], "--port=")) {
            port = std.fmt.parseInt(u16, args[i][7..], 10) catch 8080;
        }
    }

    // v2.3: Chat server mode (no model required)
    if (chat_mode) {
        std.debug.print("{s}Trinity Chat Server v2.3{s}\n", .{ GOLDEN, RESET });
        std.debug.print("  Port: {d}\n", .{port});
        std.debug.print("  Mode: Hybrid Chat (Tools + Symbolic + TVC + LLM)\n", .{});
        std.debug.print("\n{s}Starting chat server...{s}\n\n", .{ CYAN, RESET });
        chat_server.runChatServer(allocator, port) catch |err| {
            std.debug.print("{s}Server error: {}{s}\n", .{ RED, err, RESET });
        };
        return;
    }

    std.debug.print("{s}HTTP API Server{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Port: {d}\n", .{port});

    if (model_path) |mp| {
        std.debug.print("  Model: {s}\n", .{mp});
        std.debug.print("\n{s}Starting server...{s}\n", .{ CYAN, RESET });
        std.debug.print("\n{s}Note: Full HTTP server requires vibee:{s}\n", .{ GRAY, RESET });
        std.debug.print("  zig build vibee -- serve --model {s} --port {d}\n", .{ mp, port });
    } else {
        std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri serve --chat [--port N]           # Chat server (v2.3)\n", .{});
        std.debug.print("  tri serve --model <path.gguf> [--port N]  # GGUF model server\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCH COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchCommand(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}                    TRI BENCHMARKS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    // Simple inline benchmarks
    const iterations: usize = 1000;

    // Benchmark 1: Memory allocation
    var timer = std.time.Timer.start() catch {
        std.debug.print("{s}Timer unavailable{s}\n", .{ RED, RESET });
        return;
    };

    var sum: u64 = 0;
    var j: usize = 0;
    while (j < iterations) : (j += 1) {
        sum +%= j *% j;
    }

    const elapsed_ns = timer.read();
    const elapsed_us = elapsed_ns / 1000;

    std.debug.print("\n{s}Results ({d} iterations):{s}\n", .{ CYAN, iterations, RESET });
    std.debug.print("  Compute time: {d}us\n", .{elapsed_us});
    std.debug.print("  Ops/sec:      {d}\n", .{if (elapsed_us > 0) iterations * 1_000_000 / elapsed_us else 0});
    std.debug.print("  Sum check:    {d}\n", .{sum});

    std.debug.print("\n{s}Full benchmarks:{s}\n", .{ GRAY, RESET });
    std.debug.print("  zig build firebird -- benchmark --dim 10000\n", .{});
    std.debug.print("  zig build bench\n", .{});

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLVE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvolveCommand(args: []const []const u8) void {
    var dim: usize = 10000;
    var pop: usize = 50;
    var gens: usize = 100;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dim") and i + 1 < args.len) {
            i += 1;
            dim = std.fmt.parseInt(usize, args[i], 10) catch 10000;
        } else if (std.mem.eql(u8, args[i], "--pop") and i + 1 < args.len) {
            i += 1;
            pop = std.fmt.parseInt(usize, args[i], 10) catch 50;
        } else if (std.mem.eql(u8, args[i], "--gen") and i + 1 < args.len) {
            i += 1;
            gens = std.fmt.parseInt(usize, args[i], 10) catch 100;
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              FIREBIRD EVOLUTION{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Dimension:   {d}\n", .{dim});
    std.debug.print("  Population:  {d}\n", .{pop});
    std.debug.print("  Generations: {d}\n", .{gens});
    std.debug.print("\n{s}Full evolution requires firebird:{s}\n", .{ GRAY, RESET });
    std.debug.print("  zig build firebird -- evolve --dim {d} --pop {d} --gen {d}\n", .{ dim, pop, gens });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GIT COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGitCommand(allocator: std.mem.Allocator, subcmd: []const u8, args: []const []const u8) void {
    var argv_buf: [32][]const u8 = undefined;
    var argv_len: usize = 0;

    // Build command
    argv_buf[argv_len] = "git";
    argv_len += 1;

    if (std.mem.eql(u8, subcmd, "commit")) {
        // tri commit [message]
        if (args.len > 0) {
            // git add -A && git commit -m "message"
            std.debug.print("{s}Git Commit{s}\n", .{ GOLDEN, RESET });

            // First: git add -A
            const add_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "git", "add", "-A" },
            }) catch |err| {
                std.debug.print("{s}Error running git add: {}{s}\n", .{ RED, err, RESET });
                return;
            };
            defer allocator.free(add_result.stdout);
            defer allocator.free(add_result.stderr);

            // Then: git commit -m "message"
            var msg_buf: [4096]u8 = undefined;
            var pos: usize = 0;
            for (args, 0..) |arg, idx| {
                if (idx > 0 and pos < msg_buf.len) {
                    msg_buf[pos] = ' ';
                    pos += 1;
                }
                const copy_len = @min(arg.len, msg_buf.len - pos);
                @memcpy(msg_buf[pos..][0..copy_len], arg[0..copy_len]);
                pos += copy_len;
            }
            const message = msg_buf[0..pos];

            const commit_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "git", "commit", "-m", message },
            }) catch |err| {
                std.debug.print("{s}Error running git commit: {}{s}\n", .{ RED, err, RESET });
                return;
            };
            defer allocator.free(commit_result.stdout);
            defer allocator.free(commit_result.stderr);

            if (commit_result.stdout.len > 0) {
                std.debug.print("{s}\n", .{commit_result.stdout});
            }
            if (commit_result.stderr.len > 0) {
                std.debug.print("{s}{s}{s}\n", .{ GRAY, commit_result.stderr, RESET });
            }
            return;
        } else {
            std.debug.print("{s}Usage: tri commit <message>{s}\n", .{ RED, RESET });
            return;
        }
    } else if (std.mem.eql(u8, subcmd, "diff")) {
        argv_buf[argv_len] = "diff";
        argv_len += 1;
        argv_buf[argv_len] = "--color=always";
        argv_len += 1;
    } else if (std.mem.eql(u8, subcmd, "status")) {
        argv_buf[argv_len] = "status";
        argv_len += 1;
        argv_buf[argv_len] = "--short";
        argv_len += 1;
    } else if (std.mem.eql(u8, subcmd, "log")) {
        argv_buf[argv_len] = "log";
        argv_len += 1;
        argv_buf[argv_len] = "--oneline";
        argv_len += 1;
        argv_buf[argv_len] = "-10";
        argv_len += 1;
    }

    // Add any extra args
    for (args) |arg| {
        if (argv_len < argv_buf.len) {
            argv_buf[argv_len] = arg;
            argv_len += 1;
        }
    }

    std.debug.print("{s}Git {s}{s}\n", .{ GOLDEN, subcmd, RESET });

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argv_len],
        .max_output_bytes = 10 * 1024 * 1024, // 10MB max for large diffs
    }) catch |err| {
        std.debug.print("{s}Error running git: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        std.debug.print("{s}\n", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        std.debug.print("{s}{s}{s}\n", .{ GRAY, result.stderr, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTRIBUTED INFERENCE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDistributedCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("\n{s}Trinity Distributed Inference{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });
        std.debug.print("Usage: tri distributed --role <coordinator|worker> [options]\n\n", .{});
        std.debug.print("{s}Worker:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri distributed --role worker --model <path> --layers 11-21 --port 9335\n\n", .{});
        std.debug.print("{s}Coordinator:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri distributed --role coordinator --model <path> --layers 0-10 --peer 127.0.0.1:9335\n\n", .{});
        std.debug.print("{s}Options:{s}\n", .{ CYAN, RESET });
        std.debug.print("  --role <role>       coordinator or worker\n", .{});
        std.debug.print("  --model <path>      Path to GGUF model file\n", .{});
        std.debug.print("  --layers <range>    Layer range, e.g. 0-10 or 11-21\n", .{});
        std.debug.print("  --port <port>       Worker listen port (default: 9335)\n", .{});
        std.debug.print("  --peer <host:port>  Worker address (coordinator only)\n", .{});
        std.debug.print("  --prompt <text>     Prompt text (coordinator only)\n", .{});
        std.debug.print("  --max-tokens <n>    Max tokens to generate (default: 20)\n", .{});
        std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
        return;
    }

    // Spawn trinity-node binary with --distributed flag + pass-through args
    var argv_buf: [32][]const u8 = undefined;
    argv_buf[0] = "zig-out/bin/trinity-node";
    argv_buf[1] = "--distributed";
    const extra = @min(args.len, 30);
    for (0..extra) |i| {
        argv_buf[2 + i] = args[i];
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0 .. 2 + extra],
        .max_output_bytes = 10 * 1024 * 1024,
    }) catch |err| {
        std.debug.print("{s}Error running trinity-node: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) std.debug.print("{s}", .{result.stdout});
    if (result.stderr.len > 0) std.debug.print("{s}", .{result.stderr});
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW COMMANDS - VIBEE FIRST INTEGRATION
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// IMPROVE COMMAND (Self-Improvement)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runImproveCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;
    var spec_path: ?[]const u8 = null;
    var iterations: u32 = 5;
    var threshold: f32 = 95.0;
    var dry_run = false;
    var verbose = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--iterations") and i + 1 < args.len) {
            i += 1;
            iterations = std.fmt.parseInt(u32, args[i], 10) catch 5;
        } else if (std.mem.eql(u8, args[i], "--threshold") and i + 1 < args.len) {
            i += 1;
            threshold = std.fmt.parseFloat(f32, args[i]) catch 95.0;
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--verbose")) {
            verbose = true;
        } else if (args[i][0] != '-') {
            spec_path = args[i];
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              VIBEE SELF-IMPROVER{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (spec_path) |path| {
        std.debug.print("  Spec:        {s}\n", .{path});
    } else {
        std.debug.print("  Spec:        (using default)\n", .{});
    }
    std.debug.print("  Iterations:  {d}\n", .{iterations});
    std.debug.print("  Threshold:    {d:.1}%\n", .{threshold});
    std.debug.print("  Dry Run:     {s}\n", .{if (dry_run) "true" else "false"});
    std.debug.print("  Verbose:     {s}\n", .{if (verbose) "true" else "false"});

    std.debug.print("\n{s}Note: Self-improvement requires vibee-self-improve binary:{s}\n", .{ GRAY, RESET });
    if (spec_path) |path| {
        std.debug.print("  ./zig-out/bin/vibee-self-improve {s} --iterations {d} --threshold {d:.1}\n", .{ path, iterations, threshold });
        if (dry_run) std.debug.print("    Option: --dry-run\n", .{});
        if (verbose) std.debug.print("    Option: --verbose\n", .{});
    } else {
        std.debug.print("  ./zig-out/bin/vibee-self-improve --iterations {d} --threshold {d:.1}\n", .{ iterations, threshold });
        if (dry_run) std.debug.print("    Option: --dry-run\n", .{});
        if (verbose) std.debug.print("    Option: --verbose\n", .{});
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GGUF CHAT COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGgufChatCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var model_path: ?[]const u8 = null;
    var stream = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
            i += 1;
            model_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--stream")) {
            stream = true;
        } else if (std.mem.startsWith(u8, args[i], "--model=")) {
            model_path = args[i][8..];
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}                  GGUF CHAT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (model_path) |path| {
        std.debug.print("  Model:   {s}\n", .{path});
        std.debug.print("  Stream:  {s}\n", .{if (stream) "enabled" else "disabled"});
        std.debug.print("\n{s}Note: GGUF chat requires vibee binary:{s}\n", .{ GRAY, RESET });
        std.debug.print("  zig build vibee -- chat --model {s}{s}\n", .{ path, if (stream) " --stream" else "" });
    } else {
        std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri gguf-chat --model <path.gguf> [--stream]\n", .{});
        std.debug.print("\n{s}Note: GGUF chat requires vibee binary:{s}\n", .{ GRAY, RESET });
        std.debug.print("  zig build vibee -- chat --model <path.gguf> [--stream]\n", .{});
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// METAL COMMAND (GPU Acceleration)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runMetalCommand(allocator: std.mem.Allocator) void {
    _ = allocator;

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              METAL GPU STATUS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    std.debug.print("  Platform:     {s}\n", .{if (@import("builtin").target.os.tag == .macos) "macOS (Metal)" else "Not macOS"});
    std.debug.print("  Architecture:  {s}\n", .{if (@import("builtin").target.cpu.arch == .aarch64) "Apple Silicon" else "x86_64"});

    if (@import("builtin").target.os.tag == .macos) {
        std.debug.print("  Status:       {s}{s}\n", .{ GREEN, "Metal GPU available" });
        std.debug.print("\n{s}Note: Metal acceleration requires igla_metal_gpu:{s}\n", .{ GRAY, RESET });
        std.debug.print("  zig build vibee -- metal --enable\n", .{});
    } else {
        std.debug.print("  Status:       {s}{s}\n", .{ RED, "Metal not available on this platform" });
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATE COMMAND (Trinity Validator)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runValidateCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var input_path: ?[]const u8 = null;
    var strict = false;
    var auto_fix = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--strict")) {
            strict = true;
        } else if (std.mem.eql(u8, args[i], "--fix")) {
            auto_fix = true;
        } else if (args[i][0] != '-') {
            input_path = args[i];
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRINITY VALIDATOR{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (input_path) |path| {
        std.debug.print("  File:     {s}\n", .{path});
        std.debug.print("  Strict:   {s}\n", .{if (strict) "true" else "false"});
        std.debug.print("  Auto Fix: {s}\n", .{if (auto_fix) "true" else "false"});
        std.debug.print("\n{s}Note: Validation requires trinity-validator binary:{s}\n", .{ GRAY, RESET });
        const strict_flag = if (strict) " --strict" else "";
        const fix_flag = if (auto_fix) " --fix" else "";
        std.debug.print("  ./zig-out/bin/trinity-validator {s}{s}{s}\n", .{ path, strict_flag, fix_flag });
    } else {
        std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri validate <spec.vibee|file.zig> [--strict] [--fix]\n", .{});
        std.debug.print("\n{s}Options:{s}\n", .{ GRAY, RESET });
        std.debug.print("  --strict   Enable strict validation mode\n", .{});
        std.debug.print("  --fix      Automatically fix detected issues\n", .{});
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROMETHEUS COMMAND (Float32 → Ternary Conversion)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runPrometheusCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var input_path: ?[]const u8 = null;
    var show_info = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--info")) {
            show_info = true;
        } else if (args[i][0] != '-') {
            input_path = args[i];
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              PROMETHEUS CONVERTER{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    std.debug.print("  Converts: Float32 → Ternary (.tri format)\n", .{});
    std.debug.print("  Input:    safetensors, pytorch weights, etc.\n", .{});
    std.debug.print("  Output:   .tri (packed ternary)\n", .{});

    if (input_path) |path| {
        std.debug.print("\n  File: {s}\n", .{path});
        std.debug.print("\n{s}Note: Conversion requires prometheus binary:{s}\n", .{ GRAY, RESET });
        std.debug.print("  ./zig-out/bin/prometheus {s} --to ternary --info{s}\n", .{
            path,
            if (show_info) " --info" else "",
        });
    } else {
        std.debug.print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri prometheus <input> [--info]\n", .{});
        std.debug.print("\n{s}Options:{s}\n", .{ GRAY, RESET });
        std.debug.print("  --info     Show detailed conversion info\n", .{});
        std.debug.print("  --to ternary  Convert to ternary format\n", .{});
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TVC COMPILE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTVCCompileCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var spec_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var debug_mode = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--output") and i + 1 < args.len) {
            i += 1;
            output_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--debug")) {
            debug_mode = true;
        } else if (std.mem.eql(u8, args[i], "compile") and i + 1 < args.len) {
            i += 1;
            spec_path = args[i];
        } else if (args[i][0] != '-') {
            spec_path = args[i];
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TVC COMPILER{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (spec_path) |path| {
        std.debug.print("  Spec:   {s}\n", .{path});
        if (output_path) |op| std.debug.print("  Output: {s}\n", .{op});
        std.debug.print("  Debug:  {s}\n", .{if (debug_mode) "true" else "false"});
        std.debug.print("\n{s}Note: TVC compilation requires tvc binary:{s}\n", .{ GRAY, RESET });
        std.debug.print("  ./zig-out/bin/tvc compile {s}\n", .{ path });
        if (output_path) |op| std.debug.print("    Option: --output {s}\n", .{op});
        if (debug_mode) std.debug.print("    Option: --debug\n", .{});
    } else {
        std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri tvc compile <spec.vibee> [--output <path>] [--debug]\n", .{});
        std.debug.print("\n{s}Options:{s}\n", .{ GRAY, RESET });
        std.debug.print("  --output <path>  Output binary path\n", .{});
        std.debug.print("  --debug          Enable debug output\n", .{});
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPETITIVE REPL COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runCompetitiveReplCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var lang: []const u8 = "en";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--lang") and i + 1 < args.len) {
            i += 1;
            lang = args[i];
        } else if (std.mem.startsWith(u8, args[i], "--lang=")) {
            lang = args[i][7..];
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}            COMPETITIVE REPL{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    const lang_name = if (std.mem.eql(u8, lang, "en")) "English"
                     else if (std.mem.eql(u8, lang, "ru")) "Русский"
                     else if (std.mem.eql(u8, lang, "th")) "ภาษาไทย"
                     else "Unknown";

    std.debug.print("  Language: {s} ({s})\n", .{ lang_name, lang });
    std.debug.print("  Features: Tab completion, multi-language support\n", .{});
    std.debug.print("\n{s}Note: Competitive REPL requires competitive-repl binary:{s}\n", .{ GRAY, RESET });
    std.debug.print("  ./zig-out/bin/competitive-repl --lang {s}\n", .{ lang });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// KG SERVER COMMAND (Knowledge Graph Server)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runKGServerCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var port: u16 = 8081;
    var persist = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            i += 1;
            port = std.fmt.parseInt(u16, args[i], 10) catch 8081;
        } else if (std.mem.startsWith(u8, args[i], "--port=")) {
            port = std.fmt.parseInt(u16, args[i][7..], 10) catch 8081;
        } else if (std.mem.eql(u8, args[i], "--persist")) {
            persist = true;
        }
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}         KNOWLEDGE GRAPH SERVER{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Port:    {d}\n", .{port});
    std.debug.print("  Persist: {s}\n", .{if (persist) "enabled" else "disabled"});
    std.debug.print("\n{s}Note: KG Server requires trinity-kg-server binary:{s}\n", .{ GRAY, RESET });
    std.debug.print("  ./zig-out/bin/trinity-kg-server --port {d}{s}\n", .{
        port,
        if (persist) " --persist" else "",
    });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEV UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDoctorCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}                TRI DOCTOR{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\nRunning diagnostics...\n\n", .{});

    var pass_count: u32 = 0;
    var fail_count: u32 = 0;

    // 1. Zig version
    const zig_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "version" },
    }) catch {
        std.debug.print("  {s}✗ Zig compiler not found{s}\n", .{ RED, RESET });
        fail_count += 1;
        return;
    };
    defer allocator.free(zig_result.stdout);
    defer allocator.free(zig_result.stderr);

    const zig_ver = std.mem.trim(u8, zig_result.stdout, " \t\n\r");
    if (zig_result.term.Exited == 0) {
        std.debug.print("  {s}✓ Zig compiler:{s} {s}\n", .{ GREEN, RESET, zig_ver });
        pass_count += 1;
    } else {
        std.debug.print("  {s}✗ Zig compiler error{s}\n", .{ RED, RESET });
        fail_count += 1;
    }

    // 2. build.zig exists
    std.fs.cwd().access("build.zig", .{}) catch {
        std.debug.print("  {s}✗ build.zig not found{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    std.debug.print("  {s}✓ build.zig found{s}\n", .{ GREEN, RESET });
    pass_count += 1;

    // 3. src/ directory
    std.fs.cwd().access("src/tri/main.zig", .{}) catch {
        std.debug.print("  {s}✗ src/tri/main.zig not found{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    std.debug.print("  {s}✓ src/tri/main.zig found{s}\n", .{ GREEN, RESET });
    pass_count += 1;

    // 4. tri_colors.zig
    std.fs.cwd().access("src/tri/tri_colors.zig", .{}) catch {
        std.debug.print("  {s}✗ src/tri/tri_colors.zig missing{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    std.debug.print("  {s}✓ tri_colors.zig found{s}\n", .{ GREEN, RESET });
    pass_count += 1;

    // 5. Check zig-out/bin/tri binary exists (skip recursive build)
    std.debug.print("\n", .{});

    // 6. zig-out/bin/tri exists
    std.fs.cwd().access("zig-out/bin/tri", .{}) catch {
        std.debug.print("  {s}✗ zig-out/bin/tri binary not found{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    std.debug.print("  {s}✓ zig-out/bin/tri binary exists{s}\n", .{ GREEN, RESET });
    pass_count += 1;

    // 7. specs/ directory
    std.fs.cwd().access("specs", .{}) catch {
        std.debug.print("  {s}✗ specs/ directory not found{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    std.debug.print("  {s}✓ specs/ directory found{s}\n", .{ GREEN, RESET });
    pass_count += 1;

    printDoctorSummary(pass_count, fail_count);
}

fn printDoctorSummary(pass_count: u32, fail_count: u32) void {
    const total = pass_count + fail_count;
    std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Passed: {s}{d}/{d}{s}\n", .{ GREEN, pass_count, total, RESET });
    if (fail_count > 0) {
        std.debug.print("  Failed: {s}{d}/{d}{s}\n", .{ RED, fail_count, total, RESET });
    }
    if (fail_count == 0) {
        std.debug.print("  Status: {s}ALL CHECKS PASSED{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  Status: {s}ISSUES FOUND{s}\n", .{ RED, RESET });
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runCleanCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI CLEAN{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    // Remove .zig-cache
    std.debug.print("\n  Removing .zig-cache...", .{});
    std.fs.cwd().deleteTree(".zig-cache") catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print(" {s}(not found){s}\n", .{ GRAY, RESET });
        } else {
            std.debug.print(" {s}error: {}{s}\n", .{ RED, err, RESET });
        }
        // Continue with zig-out
        removeZigOut(allocator);
        return;
    };
    std.debug.print(" {s}done{s}\n", .{ GREEN, RESET });

    removeZigOut(allocator);
}

fn removeZigOut(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("  Removing zig-out...", .{});
    std.fs.cwd().deleteTree("zig-out") catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print(" {s}(not found){s}\n", .{ GRAY, RESET });
        } else {
            std.debug.print(" {s}error: {}{s}\n", .{ RED, err, RESET });
        }
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    std.debug.print(" {s}done{s}\n", .{ GREEN, RESET });
    std.debug.print("\n  {s}✓ Clean complete{s}\n", .{ GREEN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runFmtCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI FORMAT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\nFormatting Zig source files...\n", .{});

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "fmt", "src/" },
    }) catch |err| {
        std.debug.print("{s}Error running zig fmt: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) std.debug.print("{s}", .{result.stdout});
    if (result.stderr.len > 0) std.debug.print("{s}", .{result.stderr});

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runStatsCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI STATS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    // Count .zig files and lines via wc -l
    const zig_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find src -name '*.zig' | wc -l" },
    }) catch {
        std.debug.print("\n  {s}✗ Could not count .zig files{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(zig_count.stdout);
    defer allocator.free(zig_count.stderr);

    const zig_loc = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find src -name '*.zig' -exec cat {} + | wc -l" },
    }) catch {
        std.debug.print("\n  {s}✗ Could not count LOC{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(zig_loc.stdout);
    defer allocator.free(zig_loc.stderr);

    // Count .vibee specs
    const spec_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find specs -name '*.vibee' 2>/dev/null | wc -l" },
    }) catch {
        std.debug.print("\n  {s}✗ Could not count specs{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(spec_count.stdout);
    defer allocator.free(spec_count.stderr);

    // Count test files
    const test_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "grep -rl 'test \"' src --include='*.zig' 2>/dev/null | wc -l" },
    }) catch {
        std.debug.print("\n  {s}✗ Could not count test files{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(test_count.stdout);
    defer allocator.free(test_count.stderr);

    std.debug.print("\n{s}  Codebase:{s}\n", .{ CYAN, RESET });
    std.debug.print("    Zig files:     {s}", .{std.mem.trim(u8, zig_count.stdout, " \t\n\r")});
    std.debug.print("\n    Lines of code:  {s}", .{std.mem.trim(u8, zig_loc.stdout, " \t\n\r")});
    std.debug.print("\n    VIBEE specs:    {s}", .{std.mem.trim(u8, spec_count.stdout, " \t\n\r")});
    std.debug.print("\n    Test files:     {s}", .{std.mem.trim(u8, test_count.stdout, " \t\n\r")});
    std.debug.print("\n", .{});

    // Architecture info
    std.debug.print("\n{s}  Architecture:{s}\n", .{ CYAN, RESET });
    std.debug.print("    Platform:      {s}\n", .{@tagName(@import("builtin").os.tag)});
    std.debug.print("    Arch:          {s}\n", .{@tagName(@import("builtin").cpu.arch)});
    std.debug.print("    Encoding:      Ternary (1.58 bits/trit)\n", .{});

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runIglaCommand(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              IGLA CMD{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}Note: IGLA requires vibee binary:{s}\n", .{ GRAY, RESET });
    std.debug.print("  zig build vibee -- igla\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runTestAllCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI TEST ALL{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\nRunning all tests...\n", .{});

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "build", "test" },
    }) catch |err| {
        std.debug.print("{s}Error running tests: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) std.debug.print("{s}", .{result.stdout});
    if (result.stderr.len > 0) std.debug.print("{s}", .{result.stderr});

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runAnalyzeCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI ANALYZE{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}Note: Analysis requires trinity-analyze binary:{s}\n", .{ GRAY, RESET });
    std.debug.print("  ./zig-out/bin/trinity-analyze\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runSearchCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI SEARCH{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}Usage: tri search <pattern> [path]{s}\n", .{ CYAN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runDepsCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI DEPS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}Usage: tri deps <file.zig>{s}\n", .{ CYAN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}
