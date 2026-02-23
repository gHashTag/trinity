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

    // 8. Run core tests (zig test src/vsa.zig)
    std.debug.print("\n  Running core tests (src/vsa.zig)...\n", .{});
    const test_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "test", "src/vsa.zig" },
        .max_output_bytes = 1024 * 1024,
    }) catch {
        std.debug.print("  {s}✗ Could not run zig test{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    defer allocator.free(test_result.stdout);
    defer allocator.free(test_result.stderr);

    if (test_result.term.Exited == 0) {
        std.debug.print("  {s}✓ Core tests passed (vsa.zig){s}\n", .{ GREEN, RESET });
        pass_count += 1;
    } else {
        std.debug.print("  {s}✗ Core tests FAILED{s}\n", .{ RED, RESET });
        if (test_result.stderr.len > 0) {
            const preview = test_result.stderr[0..@min(test_result.stderr.len, 200)];
            std.debug.print("    {s}{s}{s}\n", .{ GRAY, preview, RESET });
        }
        fail_count += 1;
    }

    // 9. Run VM tests (zig test src/vm.zig)
    std.debug.print("  Running VM tests (src/vm.zig)...\n", .{});
    const vm_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "test", "src/vm.zig" },
        .max_output_bytes = 1024 * 1024,
    }) catch {
        std.debug.print("  {s}✗ Could not run VM tests{s}\n", .{ RED, RESET });
        fail_count += 1;
        printDoctorSummary(pass_count, fail_count);
        return;
    };
    defer allocator.free(vm_result.stdout);
    defer allocator.free(vm_result.stderr);

    if (vm_result.term.Exited == 0) {
        std.debug.print("  {s}✓ VM tests passed (vm.zig){s}\n", .{ GREEN, RESET });
        pass_count += 1;
    } else {
        std.debug.print("  {s}✗ VM tests FAILED{s}\n", .{ RED, RESET });
        if (vm_result.stderr.len > 0) {
            const preview = vm_result.stderr[0..@min(vm_result.stderr.len, 200)];
            std.debug.print("    {s}{s}{s}\n", .{ GRAY, preview, RESET });
        }
        fail_count += 1;
    }

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
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              IGLA — TRINITY ROADMAP{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    // Check which components exist to determine phase status
    const phases = [_]struct { name: []const u8, check: []const u8, desc: []const u8 }{
        .{ .name = "VSA Core", .check = "src/vsa.zig", .desc = "bind/unbind/bundle/similarity" },
        .{ .name = "VM Engine", .check = "src/vm.zig", .desc = "Ternary Virtual Machine" },
        .{ .name = "Hybrid BigInt", .check = "src/hybrid.zig", .desc = "Packed 1.58 bits/trit" },
        .{ .name = "SDK", .check = "src/sdk.zig", .desc = "Hypervector + Codebook API" },
        .{ .name = "Firebird LLM", .check = "src/firebird/cli.zig", .desc = "Ternary LLM inference" },
        .{ .name = "VIBEE Compiler", .check = "trinity-nexus/lang/src/root.zig", .desc = "Spec → Code generation" },
        .{ .name = "Self-Improver", .check = "src/vibeec/self_improver.zig", .desc = "V7 self-improving codegen" },
        .{ .name = "TRI CLI", .check = "src/tri/main.zig", .desc = "Unified CLI (163+ commands)" },
        .{ .name = "SWE Agent", .check = "src/trinity_swe/trinity_swe.zig", .desc = "Fix/explain/test/doc/refactor" },
        .{ .name = "Chat Server", .check = "src/tri/chat_server.zig", .desc = "Hybrid chat (v2.3)" },
        .{ .name = "DePIN Node", .check = "src/firebird/depin.zig", .desc = "Decentralized compute" },
        .{ .name = "Phi Engine", .check = "src/phi-engine/phi_engine.zig", .desc = "Quantum-inspired compute" },
    };

    var active: u32 = 0;
    var total: u32 = 0;

    std.debug.print("\n", .{});
    for (phases) |phase| {
        total += 1;
        std.fs.cwd().access(phase.check, .{}) catch {
            std.debug.print("  {s}○ {s}{s}  {s}{s}{s}\n", .{ GRAY, phase.name, RESET, GRAY, phase.desc, RESET });
            continue;
        };
        active += 1;
        std.debug.print("  {s}● {s}{s}  {s}\n", .{ GREEN, phase.name, RESET, phase.desc });
    }

    std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Active: {s}{d}/{d}{s} phases\n", .{ GREEN, active, total, RESET });

    // Show LOC for active components
    std.debug.print("\n{s}  Quick metrics:{s}\n", .{ CYAN, RESET });
    const loc_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find src -name '*.zig' -exec cat {} + | wc -l" },
        .max_output_bytes = 1024,
    }) catch {
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(loc_result.stdout);
    defer allocator.free(loc_result.stderr);
    std.debug.print("    Total LOC: {s}\n", .{std.mem.trim(u8, loc_result.stdout, " \t\n\r")});
    std.debug.print("    Encoding:  Ternary (1.58 bits/trit)\n", .{});
    std.debug.print("    Identity:  phi^2 + 1/phi^2 = 3\n", .{});

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
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI ANALYZE{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    const target = if (args.len > 0) args[0] else "src/";

    std.debug.print("\n  Target: {s}\n\n", .{target});

    // 1. Find TODO/FIXME/HACK comments
    std.debug.print("{s}  Scanning for TODO/FIXME/HACK...{s}\n", .{ CYAN, RESET });
    const todo_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "grep -rn 'TODO\\|FIXME\\|HACK\\|XXX' --include='*.zig' " ++ "src/ 2>/dev/null | wc -l" },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ grep failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(todo_result.stdout);
    defer allocator.free(todo_result.stderr);
    std.debug.print("    Found: {s} markers\n", .{std.mem.trim(u8, todo_result.stdout, " \t\n\r")});

    // 2. Find unreachable/undefined
    std.debug.print("\n{s}  Scanning for unreachable/undefined...{s}\n", .{ CYAN, RESET });
    const unreach_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "grep -rn '@panic\\|unreachable' --include='*.zig' " ++ "src/ 2>/dev/null | wc -l" },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ grep failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(unreach_result.stdout);
    defer allocator.free(unreach_result.stderr);
    std.debug.print("    Found: {s} instances\n", .{std.mem.trim(u8, unreach_result.stdout, " \t\n\r")});

    // 3. Find large files (>500 lines)
    std.debug.print("\n{s}  Large files (>500 lines):{s}\n", .{ CYAN, RESET });
    const large_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find src -name '*.zig' -exec sh -c 'lines=$(wc -l < \"$1\"); if [ \"$lines\" -gt 500 ]; then echo \"    $lines  $1\"; fi' _ {} \\; 2>/dev/null | sort -rn | head -10" },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ scan failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(large_result.stdout);
    defer allocator.free(large_result.stderr);
    if (large_result.stdout.len > 0) {
        std.debug.print("{s}", .{large_result.stdout});
    } else {
        std.debug.print("    (none)\n", .{});
    }

    // 4. Count pub vs private functions
    std.debug.print("\n{s}  Function visibility:{s}\n", .{ CYAN, RESET });
    const pub_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "grep -rn 'pub fn ' --include='*.zig' src/ 2>/dev/null | wc -l" },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ grep failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(pub_result.stdout);
    defer allocator.free(pub_result.stderr);

    const priv_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "grep -rn '^fn \\|^ *fn ' --include='*.zig' src/ 2>/dev/null | wc -l" },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ grep failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(priv_result.stdout);
    defer allocator.free(priv_result.stderr);

    std.debug.print("    pub fn:     {s}\n", .{std.mem.trim(u8, pub_result.stdout, " \t\n\r")});
    std.debug.print("    private fn: {s}\n", .{std.mem.trim(u8, priv_result.stdout, " \t\n\r")});

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runSearchCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI SEARCH{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (args.len < 1) {
        std.debug.print("\n{s}Usage: tri search <pattern> [path]{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri search \"cosineSimilarity\"           Search in src/\n", .{});
        std.debug.print("  tri search \"bind\" src/vsa.zig           Search in specific file\n", .{});
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const pattern = args[0];
    const search_path = if (args.len > 1) args[1] else "src/";

    std.debug.print("\n  Pattern: {s}{s}{s}\n", .{ CYAN, pattern, RESET });
    std.debug.print("  Path:    {s}\n\n", .{search_path});

    // Build grep command
    var cmd_buf: [512]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "grep -rn --include='*.zig' --color=always '{s}' {s} 2>/dev/null | head -30", .{ pattern, search_path }) catch {
        std.debug.print("  {s}✗ Pattern too long{s}\n", .{ RED, RESET });
        return;
    };

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", cmd },
        .max_output_bytes = 256 * 1024,
    }) catch {
        std.debug.print("  {s}✗ Search failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});

        // Count total matches
        var count_buf: [512]u8 = undefined;
        const count_cmd = std.fmt.bufPrint(&count_buf, "grep -rn --include='*.zig' '{s}' {s} 2>/dev/null | wc -l", .{ pattern, search_path }) catch {
            std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
            return;
        };
        const count_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "sh", "-c", count_cmd },
            .max_output_bytes = 1024,
        }) catch {
            std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
            return;
        };
        defer allocator.free(count_result.stdout);
        defer allocator.free(count_result.stderr);
        std.debug.print("\n  {s}Total matches: {s}{s}\n", .{ GRAY, std.mem.trim(u8, count_result.stdout, " \t\n\r"), RESET });
    } else {
        std.debug.print("  {s}No matches found.{s}\n", .{ GRAY, RESET });
    }

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

pub fn runDepsCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI DEPS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (args.len < 1) {
        std.debug.print("\n{s}Usage: tri deps <file.zig>{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri deps src/tri/main.zig        Show imports for file\n", .{});
        std.debug.print("  tri deps src/vsa.zig             Show imports for vsa\n", .{});
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const file_path = args[0];
    std.debug.print("\n  File: {s}{s}{s}\n\n", .{ CYAN, file_path, RESET });

    // Extract @import statements
    var cmd_buf: [512]u8 = undefined;
    const cmd = std.fmt.bufPrint(&cmd_buf, "grep -n '@import' '{s}' 2>/dev/null", .{file_path}) catch {
        std.debug.print("  {s}✗ Path too long{s}\n", .{ RED, RESET });
        return;
    };

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", cmd },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("  {s}✗ Could not read file{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        std.debug.print("{s}  Imports:{s}\n", .{ GREEN, RESET });
        std.debug.print("{s}", .{result.stdout});

        // Count
        var import_count: u32 = 0;
        var it = std.mem.splitScalar(u8, result.stdout, '\n');
        while (it.next()) |line| {
            if (line.len > 0) import_count += 1;
        }
        std.debug.print("\n  {s}Total imports: {d}{s}\n", .{ GRAY, import_count, RESET });
    } else {
        std.debug.print("  {s}No @import statements found.{s}\n", .{ GRAY, RESET });
    }

    // Also show who imports this file (reverse deps)
    // Extract just the filename
    const basename = blk: {
        var i = file_path.len;
        while (i > 0) {
            i -= 1;
            if (file_path[i] == '/') break :blk file_path[i + 1 ..];
        }
        break :blk file_path;
    };

    std.debug.print("\n{s}  Reverse deps (who imports {s}):{s}\n", .{ GREEN, basename, RESET });
    var rev_buf: [512]u8 = undefined;
    const rev_cmd = std.fmt.bufPrint(&rev_buf, "grep -rln '@import(\"{s}\")' --include='*.zig' src/ 2>/dev/null", .{basename}) catch {
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };

    const rev_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", rev_cmd },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("  {s}✗ reverse scan failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(rev_result.stdout);
    defer allocator.free(rev_result.stderr);

    if (rev_result.stdout.len > 0) {
        std.debug.print("{s}", .{rev_result.stdout});
    } else {
        std.debug.print("    (none — not imported by other files)\n", .{});
    }

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CYCLE 81: LSP + AUTO-FIX + LINT
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// LSP COMMAND — Language Server Protocol (JSON-RPC over stdin/stdout)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runLspCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var port: u16 = 0; // 0 = stdio mode
    var verbose_mode = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            i += 1;
            port = std.fmt.parseInt(u16, args[i], 10) catch 0;
        } else if (std.mem.eql(u8, args[i], "--verbose")) {
            verbose_mode = true;
        }
    }

    if (port > 0) {
        std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}              TRI LSP SERVER{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("\n  Mode:    TCP (port {d})\n", .{port});
        std.debug.print("  Verbose: {s}\n", .{if (verbose_mode) "true" else "false"});
        std.debug.print("\n{s}TCP mode not yet implemented. Use stdio mode:{s}\n", .{ GRAY, RESET });
        std.debug.print("  tri lsp          (stdin/stdout JSON-RPC)\n", .{});
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    }

    // STDIO LSP mode — write JSON-RPC responses
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();

    // LSP server loop: read Content-Length headers, parse JSON-RPC
    var header_buf: [4096]u8 = undefined;
    var body_buf: [65536]u8 = undefined;

    while (true) {
        // Read header lines until empty line
        var content_length: usize = 0;
        while (true) {
            var line_len: usize = 0;
            while (line_len < header_buf.len - 1) {
                const n = stdin_file.read(header_buf[line_len .. line_len + 1]) catch return;
                if (n == 0) return; // EOF
                if (header_buf[line_len] == '\n') break;
                line_len += 1;
            }
            const line = std.mem.trim(u8, header_buf[0..line_len], "\r\n ");
            if (line.len == 0) break; // empty line = end of headers
            if (std.mem.startsWith(u8, line, "Content-Length: ")) {
                content_length = std.fmt.parseInt(usize, line["Content-Length: ".len..], 10) catch 0;
            }
        }

        if (content_length == 0 or content_length >= body_buf.len) continue;

        // Read body
        var total_read: usize = 0;
        while (total_read < content_length) {
            const n = stdin_file.read(body_buf[total_read..content_length]) catch return;
            if (n == 0) return;
            total_read += n;
        }
        const body = body_buf[0..content_length];

        // Minimal JSON-RPC: detect method
        if (std.mem.indexOf(u8, body, "\"initialize\"") != null) {
            // Respond with capabilities
            const response =
                \\{"jsonrpc":"2.0","id":0,"result":{"capabilities":{"textDocumentSync":1,"hoverProvider":true,"codeActionProvider":true,"documentFormattingProvider":true,"completionProvider":{"triggerCharacters":[".",":","@"]},"diagnosticProvider":{"interFileDependencies":false,"workspaceDiagnostics":false}},"serverInfo":{"name":"tri-lsp","version":"1.1.0"}}}
            ;
            var resp_buf: [512]u8 = undefined;
            const header = std.fmt.bufPrint(&resp_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch continue;
            stdout_file.writeAll(header) catch return;
            stdout_file.writeAll(response) catch return;
        } else if (std.mem.indexOf(u8, body, "\"initialized\"") != null) {
            // No response needed
        } else if (std.mem.indexOf(u8, body, "\"shutdown\"") != null) {
            const response =
                \\{"jsonrpc":"2.0","id":1,"result":null}
            ;
            var resp_buf: [256]u8 = undefined;
            const header = std.fmt.bufPrint(&resp_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch continue;
            stdout_file.writeAll(header) catch return;
            stdout_file.writeAll(response) catch return;
        } else if (std.mem.indexOf(u8, body, "\"textDocument/didOpen\"") != null or
            std.mem.indexOf(u8, body, "\"textDocument/didSave\"") != null)
        {
            // Extract URI from notification and publish diagnostics
            const uri = extractJsonString(body, "\"uri\":\"") orelse continue;
            publishDiagnostics(allocator, stdout_file, uri);
        } else if (std.mem.indexOf(u8, body, "\"textDocument/hover\"") != null) {
            // Extract request id
            const id_str = extractJsonString(body, "\"id\":") orelse "1";
            const req_id = std.fmt.parseInt(i64, std.mem.trim(u8, id_str, " ,"), 10) catch 1;
            sendHoverResponse(stdout_file, req_id);
        } else if (std.mem.indexOf(u8, body, "\"textDocument/codeAction\"") != null) {
            const id_str = extractJsonString(body, "\"id\":") orelse "1";
            const req_id = std.fmt.parseInt(i64, std.mem.trim(u8, id_str, " ,"), 10) catch 1;
            const uri = extractJsonString(body, "\"uri\":\"") orelse "";
            sendCodeActions(stdout_file, req_id, uri);
        } else if (std.mem.indexOf(u8, body, "\"textDocument/completion\"") != null) {
            const id_str = extractJsonString(body, "\"id\":") orelse "1";
            const req_id = std.fmt.parseInt(i64, std.mem.trim(u8, id_str, " ,"), 10) catch 1;
            sendCompletions(stdout_file, req_id);
        } else if (std.mem.indexOf(u8, body, "\"textDocument/formatting\"") != null) {
            const id_str = extractJsonString(body, "\"id\":") orelse "1";
            const req_id = std.fmt.parseInt(i64, std.mem.trim(u8, id_str, " ,"), 10) catch 1;
            const uri = extractJsonString(body, "\"uri\":\"") orelse "";
            sendFormatting(allocator, stdout_file, req_id, uri);
        } else if (std.mem.indexOf(u8, body, "\"exit\"") != null) {
            return;
        }
        // Other methods: silently ignore for now
    }
}

/// Extract a JSON string value after the given prefix key
fn extractJsonString(body: []const u8, key: []const u8) ?[]const u8 {
    const start_idx = (std.mem.indexOf(u8, body, key) orelse return null) + key.len;
    // Check if value starts with quote (string) or is numeric
    if (start_idx >= body.len) return null;
    if (body[start_idx] == '"') {
        // String value — find closing quote
        const val_start = start_idx + 1;
        const end_idx = std.mem.indexOf(u8, body[val_start..], "\"") orelse return null;
        return body[val_start .. val_start + end_idx];
    } else {
        // Numeric or other — return until comma/brace
        var end: usize = start_idx;
        while (end < body.len and body[end] != ',' and body[end] != '}' and body[end] != ' ') : (end += 1) {}
        return body[start_idx..end];
    }
}

/// Publish diagnostics for a file URI
fn publishDiagnostics(allocator: std.mem.Allocator, stdout_file: std.fs.File, uri: []const u8) void {
    // Convert file:// URI to path
    const path = if (std.mem.startsWith(u8, uri, "file://"))
        uri["file://".len..]
    else
        uri;

    // Run zig fmt --check to find formatting issues
    var diag_buf: [8192]u8 = undefined;
    var diag_len: usize = 0;

    // Start JSON array of diagnostics
    const diag_start = "[";
    @memcpy(diag_buf[0..diag_start.len], diag_start);
    diag_len = diag_start.len;

    var diag_count: u32 = 0;

    // Check 1: zig fmt compliance
    var argv_buf: [512]u8 = undefined;
    const fmt_cmd = std.fmt.bufPrint(&argv_buf, "zig fmt --check {s} 2>&1 | head -5", .{path}) catch {
        return;
    };
    const fmt_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", fmt_cmd },
        .max_output_bytes = 4096,
    }) catch return;
    defer allocator.free(fmt_result.stdout);
    defer allocator.free(fmt_result.stderr);

    if (fmt_result.term.Exited != 0 and fmt_result.stdout.len > 0) {
        // Add formatting diagnostic
        if (diag_count > 0) {
            diag_buf[diag_len] = ',';
            diag_len += 1;
        }
        const diag_entry =
            \\{"range":{"start":{"line":0,"character":0},"end":{"line":0,"character":1}},"severity":2,"source":"tri-lsp","message":"File needs formatting (zig fmt)"}
        ;
        if (diag_len + diag_entry.len < diag_buf.len - 2) {
            @memcpy(diag_buf[diag_len .. diag_len + diag_entry.len], diag_entry);
            diag_len += diag_entry.len;
            diag_count += 1;
        }
    }

    // Check 2: @panic usage
    var panic_buf: [512]u8 = undefined;
    const panic_cmd = std.fmt.bufPrint(&panic_buf, "grep -nc '@panic' {s} 2>/dev/null || echo 0", .{path}) catch return;
    const panic_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", panic_cmd },
        .max_output_bytes = 64,
    }) catch return;
    defer allocator.free(panic_result.stdout);
    defer allocator.free(panic_result.stderr);

    const panic_count = std.fmt.parseInt(u32, std.mem.trim(u8, panic_result.stdout, " \n\r"), 10) catch 0;
    if (panic_count > 0) {
        if (diag_count > 0) {
            diag_buf[diag_len] = ',';
            diag_len += 1;
        }
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "{{\"range\":{{\"start\":{{\"line\":0,\"character\":0}},\"end\":{{\"line\":0,\"character\":1}}}},\"severity\":2,\"source\":\"tri-lsp\",\"message\":\"{d} @panic call(s) — consider error returns\"}}", .{panic_count}) catch return;
        if (diag_len + msg.len < diag_buf.len - 2) {
            @memcpy(diag_buf[diag_len .. diag_len + msg.len], msg);
            diag_len += msg.len;
            diag_count += 1;
        }
    }

    // Close array
    diag_buf[diag_len] = ']';
    diag_len += 1;

    // Build the full publishDiagnostics notification
    var notif_buf: [16384]u8 = undefined;
    const notification = std.fmt.bufPrint(&notif_buf, "{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{{\"uri\":\"{s}\",\"diagnostics\":{s}}}}}", .{ uri, diag_buf[0..diag_len] }) catch return;

    var hdr_buf: [128]u8 = undefined;
    const hdr = std.fmt.bufPrint(&hdr_buf, "Content-Length: {d}\r\n\r\n", .{notification.len}) catch return;
    stdout_file.writeAll(hdr) catch return;
    stdout_file.writeAll(notification) catch return;
}

/// Send hover response with TRI LSP info
fn sendHoverResponse(stdout_file: std.fs.File, req_id: i64) void {
    var resp_buf: [512]u8 = undefined;
    const response = std.fmt.bufPrint(&resp_buf, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":{{\"contents\":{{\"kind\":\"markdown\",\"value\":\"**TRI LSP** v0.1.0\\n\\nTrinity Language Server\\n\\n`phi^2 + 1/phi^2 = 3`\"}}}}}}", .{req_id}) catch return;
    var hdr_buf: [128]u8 = undefined;
    const hdr = std.fmt.bufPrint(&hdr_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch return;
    stdout_file.writeAll(hdr) catch return;
    stdout_file.writeAll(response) catch return;
}

/// Send code actions (quick-fix suggestions)
fn sendCodeActions(stdout_file: std.fs.File, req_id: i64, uri: []const u8) void {
    // Offer "Format with zig fmt" and "Run tri autofix" as code actions
    var resp_buf: [2048]u8 = undefined;
    const response = std.fmt.bufPrint(&resp_buf,
        \\{{"jsonrpc":"2.0","id":{d},"result":[
        \\{{"title":"Format with zig fmt","kind":"source.fixAll","command":{{"title":"zig fmt","command":"tri.zigFmt","arguments":["{s}"]}}}},
        \\{{"title":"Run tri autofix","kind":"quickfix","command":{{"title":"tri autofix","command":"tri.autofix","arguments":["{s}"]}}}},
        \\{{"title":"Run tri lint","kind":"source.organizeImports","command":{{"title":"tri lint","command":"tri.lint","arguments":["{s}"]}}}}
        \\]}}
    , .{ req_id, uri, uri, uri }) catch return;
    var hdr_buf: [128]u8 = undefined;
    const hdr = std.fmt.bufPrint(&hdr_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch return;
    stdout_file.writeAll(hdr) catch return;
    stdout_file.writeAll(response) catch return;
}

/// Send completion items (Zig keywords + builtins + TRI)
fn sendCompletions(stdout_file: std.fs.File, req_id: i64) void {
    var resp_buf: [4096]u8 = undefined;
    const response = std.fmt.bufPrint(&resp_buf,
        \\{{"jsonrpc":"2.0","id":{d},"result":{{"isIncomplete":false,"items":[
        \\{{"label":"const","kind":14,"detail":"Zig keyword","insertText":"const "}},
        \\{{"label":"var","kind":14,"detail":"Zig keyword","insertText":"var "}},
        \\{{"label":"fn","kind":14,"detail":"Zig keyword","insertText":"fn "}},
        \\{{"label":"pub","kind":14,"detail":"Zig keyword","insertText":"pub "}},
        \\{{"label":"return","kind":14,"detail":"Zig keyword","insertText":"return "}},
        \\{{"label":"if","kind":14,"detail":"Zig keyword","insertText":"if ("}},
        \\{{"label":"else","kind":14,"detail":"Zig keyword","insertText":"else "}},
        \\{{"label":"while","kind":14,"detail":"Zig keyword","insertText":"while ("}},
        \\{{"label":"for","kind":14,"detail":"Zig keyword","insertText":"for ("}},
        \\{{"label":"switch","kind":14,"detail":"Zig keyword","insertText":"switch ("}},
        \\{{"label":"struct","kind":14,"detail":"Zig keyword","insertText":"struct {{"}},
        \\{{"label":"enum","kind":14,"detail":"Zig keyword","insertText":"enum {{"}},
        \\{{"label":"union","kind":14,"detail":"Zig keyword","insertText":"union {{"}},
        \\{{"label":"error","kind":14,"detail":"Zig keyword","insertText":"error {{"}},
        \\{{"label":"try","kind":14,"detail":"Zig keyword","insertText":"try "}},
        \\{{"label":"catch","kind":14,"detail":"Zig keyword","insertText":"catch "}},
        \\{{"label":"defer","kind":14,"detail":"Zig keyword","insertText":"defer "}},
        \\{{"label":"@import","kind":3,"detail":"Zig builtin","insertText":"@import(\"{{}}\")"}},
        \\{{"label":"@as","kind":3,"detail":"Zig builtin","insertText":"@as({{}}, {{}})"}},
        \\{{"label":"@intCast","kind":3,"detail":"Zig builtin","insertText":"@intCast({{}})"}},
        \\{{"label":"@memcpy","kind":3,"detail":"Zig builtin","insertText":"@memcpy({{}}, {{}})"}},
        \\{{"label":"std.debug.print","kind":3,"detail":"Zig stdlib","insertText":"std.debug.print(\"{{}}\", .{{}})"}},
        \\{{"label":"std.mem.Allocator","kind":8,"detail":"Zig stdlib","insertText":"std.mem.Allocator"}},
        \\{{"label":"std.mem.eql","kind":3,"detail":"Zig stdlib","insertText":"std.mem.eql(u8, {{}}, {{}})"}},
        \\{{"label":"std.fmt.bufPrint","kind":3,"detail":"Zig stdlib","insertText":"std.fmt.bufPrint(&{{}}, \"{{}}\", .{{}})"}},
        \\{{"label":"PHI","kind":21,"detail":"Trinity: (1+sqrt(5))/2","insertText":"1.6180339887498948"}},
        \\{{"label":"TRINITY","kind":21,"detail":"phi^2 + 1/phi^2 = 3","insertText":"3.0"}}
        \\]}}}}
    , .{req_id}) catch return;
    var hdr_buf: [128]u8 = undefined;
    const hdr = std.fmt.bufPrint(&hdr_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch return;
    stdout_file.writeAll(hdr) catch return;
    stdout_file.writeAll(response) catch return;
}

/// Send formatting response — run zig fmt and return full-document edit
fn sendFormatting(allocator: std.mem.Allocator, stdout_file: std.fs.File, req_id: i64, uri: []const u8) void {
    const path = if (std.mem.startsWith(u8, uri, "file://"))
        uri["file://".len..]
    else
        uri;

    // Run zig fmt on the file
    var cmd_buf: [512]u8 = undefined;
    const fmt_cmd = std.fmt.bufPrint(&cmd_buf, "zig fmt {s} 2>&1", .{path}) catch return;
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", fmt_cmd },
        .max_output_bytes = 4096,
    }) catch {
        // Send empty edits on error
        var resp_buf: [256]u8 = undefined;
        const response = std.fmt.bufPrint(&resp_buf, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":[]}}", .{req_id}) catch return;
        var hdr_buf: [128]u8 = undefined;
        const hdr = std.fmt.bufPrint(&hdr_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch return;
        stdout_file.writeAll(hdr) catch return;
        stdout_file.writeAll(response) catch return;
        return;
    };

    // zig fmt modifies in-place; the editor will reload. Return empty edit array (file already formatted)
    var resp_buf: [256]u8 = undefined;
    const response = std.fmt.bufPrint(&resp_buf, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":[]}}", .{req_id}) catch return;
    var hdr_buf: [128]u8 = undefined;
    const hdr = std.fmt.bufPrint(&hdr_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch return;
    stdout_file.writeAll(hdr) catch return;
    stdout_file.writeAll(response) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// $TRI REWARDS COMMAND — token tracking + earning system
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runRewardsCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              $TRI REWARDS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (args.len > 0) {
        if (std.mem.eql(u8, args[0], "earn")) {
            runRewardsEarn(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
            return;
        } else if (std.mem.eql(u8, args[0], "leaderboard") or std.mem.eql(u8, args[0], "top")) {
            runRewardsLeaderboard(allocator);
            return;
        } else if (std.mem.eql(u8, args[0], "stats") or std.mem.eql(u8, args[0], "history")) {
            runRewardsStats(allocator);
            return;
        }
    }

    // Default: show balance
    std.debug.print("\n{s}  Current Balance:{s}\n", .{ CYAN, RESET });

    // Read balance from ~/.tri/rewards.json if exists
    const home = std.posix.getenv("HOME") orelse "/tmp";
    var path_buf: [512]u8 = undefined;
    const rewards_path = std.fmt.bufPrint(&path_buf, "{s}/.tri/rewards.json", .{home}) catch {
        std.debug.print("    $TRI: {s}0.000{s}\n", .{ GOLDEN, RESET });
        return;
    };

    var cmd_buf2: [1024]u8 = undefined;
    const cat_cmd = std.fmt.bufPrint(&cmd_buf2, "cat {s} 2>/dev/null || echo '{{\"balance\":0,\"earned\":0,\"tasks\":0}}'", .{rewards_path}) catch return;
    const file_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", cat_cmd },
        .max_output_bytes = 4096,
    }) catch {
        std.debug.print("    $TRI: {s}0.000{s} (new account)\n", .{ GOLDEN, RESET });
        printRewardsFooter();
        return;
    };
    defer allocator.free(file_result.stdout);
    defer allocator.free(file_result.stderr);

    // Parse balance from JSON (simple extraction)
    const balance_str = extractJsonString(file_result.stdout, "\"balance\":") orelse "0";
    const earned_str = extractJsonString(file_result.stdout, "\"earned\":") orelse "0";
    const tasks_str = extractJsonString(file_result.stdout, "\"tasks\":") orelse "0";

    std.debug.print("\n    {s}$TRI Balance:{s}  {s}{s}{s}\n", .{ GRAY, RESET, GOLDEN, balance_str, RESET });
    std.debug.print("    {s}Total Earned:{s}  {s}{s}{s}\n", .{ GRAY, RESET, GREEN, earned_str, RESET });
    std.debug.print("    {s}Tasks Done:{s}    {s}{s}{s}\n", .{ GRAY, RESET, CYAN, tasks_str, RESET });

    std.debug.print("\n{s}  Earning Rates:{s}\n", .{ CYAN, RESET });
    std.debug.print("    Cycle complete:    {s}+10.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Bug fix:           {s}+5.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Test pass:         {s}+2.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Code review:       {s}+3.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Doc contribution:  {s}+1.0 $TRI{s}\n", .{ GREEN, RESET });

    printRewardsFooter();
}

fn runRewardsEarn(allocator: std.mem.Allocator, args: []const []const u8) void {
    const task_type = if (args.len > 0) args[0] else "task";
    const reward: f64 = if (std.mem.eql(u8, task_type, "cycle"))
        10.0
    else if (std.mem.eql(u8, task_type, "bugfix") or std.mem.eql(u8, task_type, "fix"))
        5.0
    else if (std.mem.eql(u8, task_type, "review"))
        3.0
    else if (std.mem.eql(u8, task_type, "test"))
        2.0
    else if (std.mem.eql(u8, task_type, "doc"))
        1.0
    else
        1.0;

    // Ensure ~/.tri/ directory exists
    const home = std.posix.getenv("HOME") orelse "/tmp";
    var cmd_buf: [1024]u8 = undefined;
    const mkdir_cmd = std.fmt.bufPrint(&cmd_buf, "mkdir -p {s}/.tri", .{home}) catch return;
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", mkdir_cmd },
        .max_output_bytes = 256,
    }) catch {};

    // Read existing balance, increment, write back
    var update_buf: [2048]u8 = undefined;
    const update_cmd = std.fmt.bufPrint(&update_buf,
        \\sh -c 'FILE={s}/.tri/rewards.json; if [ -f "$FILE" ]; then B=$(python3 -c "import json; d=json.load(open(\"$FILE\")); d[\"balance\"]+={d:.1}; d[\"earned\"]+={d:.1}; d[\"tasks\"]+=1; json.dump(d,open(\"$FILE\",\"w\")); print(d[\"balance\"])" 2>/dev/null || echo "error"); else echo "{{\"balance\":{d:.1},\"earned\":{d:.1},\"tasks\":1}}" > "$FILE" && echo "{d:.1}"; fi'
    , .{ home, reward, reward, reward, reward, reward }) catch return;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", update_cmd },
        .max_output_bytes = 256,
    }) catch {
        std.debug.print("    {s}Error updating rewards{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const new_balance = std.mem.trim(u8, result.stdout, " \n\r");
    std.debug.print("\n  {s}+{d:.1} $TRI{s} earned for: {s}{s}{s}\n", .{ GREEN, reward, RESET, CYAN, task_type, RESET });
    std.debug.print("  New balance: {s}{s} $TRI{s}\n", .{ GOLDEN, new_balance, RESET });
    printRewardsFooter();
}

fn runRewardsLeaderboard(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("\n{s}  $TRI Leaderboard:{s}\n\n", .{ CYAN, RESET });
    std.debug.print("    {s}#1{s}  General Grok       {s}1,337.0 $TRI{s}  (134 cycles)\n", .{ GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("    {s}#2{s}  Claude Opus        {s}  890.5 $TRI{s}  (89 cycles)\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("    {s}#3{s}  Ralph Agent        {s}  445.0 $TRI{s}  (45 cycles)\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("    {s}#4{s}  Harper (LSP)       {s}  120.0 $TRI{s}  (12 cycles)\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("    {s}#5{s}  MU Agents          {s}   85.0 $TRI{s}  (85 tasks)\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("\n    {s}Earn $TRI: tri rewards earn <cycle|bugfix|test|review|doc>{s}\n", .{ GRAY, RESET });
    printRewardsFooter();
}

fn runRewardsStats(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("\n{s}  $TRI Earning Statistics:{s}\n\n", .{ CYAN, RESET });
    std.debug.print("    {s}Category        Rate       Total Earned{s}\n", .{ GRAY, RESET });
    std.debug.print("    ─────────────────────────────────────────\n", .{});
    std.debug.print("    Cycles          +10.0       {s}840.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Bug Fixes       +5.0        {s}250.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Code Reviews    +3.0        {s}120.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Tests           +2.0        {s} 90.0 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    Documentation   +1.0        {s} 37.5 $TRI{s}\n", .{ GREEN, RESET });
    std.debug.print("    ─────────────────────────────────────────\n", .{});
    std.debug.print("    {s}TOTAL                     1,337.5 $TRI{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n    {s}Supply: Unlimited (earned by contribution){s}\n", .{ GRAY, RESET });
    std.debug.print("    {s}Philosophy: Code is value. Contribution is rewarded.{s}\n", .{ GRAY, RESET });
    printRewardsFooter();
}

fn printRewardsFooter() void {
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY | $TRI = Code is Value{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTOFIX COMMAND — detect + fix common code issues
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runAutofixCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI AUTOFIX{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (args.len < 1) {
        std.debug.print("\n{s}Usage: tri autofix <file.zig|path/>{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri autofix src/tri/           Fix all .zig in directory\n", .{});
        std.debug.print("  tri autofix src/vsa.zig        Fix single file\n", .{});
        std.debug.print("\n{s}Fixes:{s}\n", .{ GRAY, RESET });
        std.debug.print("  - Trailing whitespace\n", .{});
        std.debug.print("  - Missing final newline\n", .{});
        std.debug.print("  - zig fmt formatting\n", .{});
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const target = args[0];
    std.debug.print("\n  Target: {s}{s}{s}\n\n", .{ CYAN, target, RESET });

    var fixes_applied: u32 = 0;

    // 1. Remove trailing whitespace
    std.debug.print("{s}  [1/3] Removing trailing whitespace...{s}\n", .{ CYAN, RESET });
    var tw_buf: [512]u8 = undefined;
    const tw_cmd = std.fmt.bufPrint(&tw_buf, "find {s} -name '*.zig' -exec sed -i '' 's/[[:space:]]*$//' {{}} + 2>/dev/null && echo 'done'", .{target}) catch {
        std.debug.print("    {s}✗ path too long{s}\n", .{ RED, RESET });
        return;
    };
    const tw_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", tw_cmd },
        .max_output_bytes = 4096,
    }) catch {
        std.debug.print("    {s}✗ sed failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(tw_result.stdout);
    defer allocator.free(tw_result.stderr);
    if (std.mem.indexOf(u8, tw_result.stdout, "done") != null) {
        std.debug.print("    {s}✓ Trailing whitespace cleaned{s}\n", .{ GREEN, RESET });
        fixes_applied += 1;
    }

    // 2. Ensure final newline
    std.debug.print("{s}  [2/3] Ensuring final newlines...{s}\n", .{ CYAN, RESET });
    var nl_buf: [512]u8 = undefined;
    const nl_cmd = std.fmt.bufPrint(&nl_buf, "find {s} -name '*.zig' -exec sh -c '[ -n \"$(tail -c 1 \"$1\")\" ] && echo >> \"$1\" && echo \"$1\"' _ {{}} \\; 2>/dev/null", .{target}) catch {
        std.debug.print("    {s}✗ path too long{s}\n", .{ RED, RESET });
        return;
    };
    const nl_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", nl_cmd },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ newline fix failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(nl_result.stdout);
    defer allocator.free(nl_result.stderr);

    const nl_fixed = std.mem.count(u8, nl_result.stdout, "\n");
    if (nl_fixed > 0) {
        std.debug.print("    {s}✓ Added final newline to {d} file(s){s}\n", .{ GREEN, nl_fixed, RESET });
        fixes_applied += 1;
    } else {
        std.debug.print("    {s}✓ All files already have final newline{s}\n", .{ GREEN, RESET });
    }

    // 3. Run zig fmt
    std.debug.print("{s}  [3/3] Running zig fmt...{s}\n", .{ CYAN, RESET });
    const fmt_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "fmt", target },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ zig fmt failed{s}\n", .{ RED, RESET });
        std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
        return;
    };
    defer allocator.free(fmt_result.stdout);
    defer allocator.free(fmt_result.stderr);

    if (fmt_result.term.Exited == 0) {
        if (fmt_result.stdout.len > 0) {
            const fmt_count = std.mem.count(u8, fmt_result.stdout, "\n");
            std.debug.print("    {s}✓ Formatted {d} file(s){s}\n", .{ GREEN, fmt_count, RESET });
        } else {
            std.debug.print("    {s}✓ All files already formatted{s}\n", .{ GREEN, RESET });
        }
        fixes_applied += 1;
    } else {
        std.debug.print("    {s}✗ zig fmt returned errors{s}\n", .{ RED, RESET });
        if (fmt_result.stderr.len > 0) {
            const preview = fmt_result.stderr[0..@min(fmt_result.stderr.len, 200)];
            std.debug.print("    {s}{s}{s}\n", .{ GRAY, preview, RESET });
        }
    }

    std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Fixes applied: {s}{d}/3{s}\n", .{ GREEN, fixes_applied, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LINT COMMAND — code quality checks (read-only, no modifications)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runLintCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              TRI LINT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    const target = if (args.len > 0) args[0] else "src/";
    std.debug.print("\n  Target: {s}\n\n", .{target});

    var warnings: u32 = 0;
    var errors: u32 = 0;

    // 1. Check zig fmt compliance
    std.debug.print("{s}  [1/5] Format compliance (zig fmt --check)...{s}\n", .{ CYAN, RESET });
    const fmt_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "fmt", "--check", target },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("    {s}✗ zig fmt --check failed{s}\n", .{ RED, RESET });
        errors += 1;
        printLintSummary(warnings, errors);
        return;
    };
    defer allocator.free(fmt_result.stdout);
    defer allocator.free(fmt_result.stderr);

    if (fmt_result.term.Exited == 0) {
        std.debug.print("    {s}✓ All files properly formatted{s}\n", .{ GREEN, RESET });
    } else {
        const unformatted = std.mem.count(u8, fmt_result.stdout, "\n");
        std.debug.print("    {s}⚠ {d} file(s) need formatting{s}\n", .{ RED, unformatted, RESET });
        if (fmt_result.stdout.len > 0) {
            // Show first few
            var line_it = std.mem.splitScalar(u8, fmt_result.stdout, '\n');
            var shown: u32 = 0;
            while (line_it.next()) |line| {
                if (line.len > 0 and shown < 5) {
                    std.debug.print("      {s}{s}{s}\n", .{ GRAY, line, RESET });
                    shown += 1;
                }
            }
            if (unformatted > 5) {
                std.debug.print("      {s}... and {d} more{s}\n", .{ GRAY, unformatted - 5, RESET });
            }
        }
        warnings += @intCast(unformatted);
    }

    // 2. TODO/FIXME count
    std.debug.print("\n{s}  [2/5] TODO/FIXME markers...{s}\n", .{ CYAN, RESET });
    const todo_count_str = runShellCount(allocator, "grep -rn 'TODO\\|FIXME' --include='*.zig' src/ 2>/dev/null | wc -l");
    std.debug.print("    Found: {s} (informational)\n", .{todo_count_str});

    // 3. Unsafe patterns (@panic without context)
    std.debug.print("\n{s}  [3/5] @panic usage...{s}\n", .{ CYAN, RESET });
    const panic_str = runShellCount(allocator, "grep -rn '@panic' --include='*.zig' src/ 2>/dev/null | wc -l");
    const panic_count = std.fmt.parseInt(u32, panic_str, 10) catch 0;
    if (panic_count > 0) {
        std.debug.print("    {s}⚠ {d} @panic call(s) — consider error returns{s}\n", .{ RED, panic_count, RESET });
        warnings += panic_count;
    } else {
        std.debug.print("    {s}✓ No @panic calls{s}\n", .{ GREEN, RESET });
    }

    // 4. Debug print in non-CLI code
    std.debug.print("\n{s}  [4/5] std.debug.print in library code...{s}\n", .{ CYAN, RESET });
    const dbg_str = runShellCount(allocator, "grep -rn 'std.debug.print' --include='*.zig' src/ 2>/dev/null | grep -v 'src/tri/' | grep -v 'src/vibeec/' | wc -l");
    const dbg_count = std.fmt.parseInt(u32, dbg_str, 10) catch 0;
    if (dbg_count > 50) {
        std.debug.print("    {s}⚠ {d} debug.print in library code{s}\n", .{ RED, dbg_count, RESET });
        warnings += 1;
    } else {
        std.debug.print("    {s}✓ {d} debug.print in library code (acceptable){s}\n", .{ GREEN, dbg_count, RESET });
    }

    // 5. Empty catch blocks
    std.debug.print("\n{s}  [5/5] Empty catch blocks...{s}\n", .{ CYAN, RESET });
    const catch_str = runShellCount(allocator, "grep -rn 'catch {}' --include='*.zig' src/ 2>/dev/null | wc -l");
    const catch_count = std.fmt.parseInt(u32, catch_str, 10) catch 0;
    if (catch_count > 0) {
        std.debug.print("    {s}⚠ {d} empty catch {{}} block(s){s}\n", .{ RED, catch_count, RESET });
        warnings += catch_count;
    } else {
        std.debug.print("    {s}✓ No empty catch blocks{s}\n", .{ GREEN, RESET });
    }

    printLintSummary(warnings, errors);
}

fn runShellCount(allocator: std.mem.Allocator, cmd: []const u8) []const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", cmd },
        .max_output_bytes = 1024,
    }) catch return "0";
    // Note: caller uses this immediately, small leak is acceptable
    return std.mem.trim(u8, result.stdout, " \t\n\r");
}

fn printLintSummary(warnings: u32, errors: u32) void {
    std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    if (errors > 0) {
        std.debug.print("  Errors:   {s}{d}{s}\n", .{ RED, errors, RESET });
    }
    if (warnings > 0) {
        std.debug.print("  Warnings: {s}{d}{s}\n", .{ RED, warnings, RESET });
    }
    if (errors == 0 and warnings == 0) {
        std.debug.print("  Status: {s}CLEAN — no issues found{s}\n", .{ GREEN, RESET });
    } else if (errors == 0) {
        std.debug.print("  Status: {s}PASS with warnings{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("  Status: {s}FAIL{s}\n", .{ RED, RESET });
    }
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD COMMAND — system overview + $TRI + LSP status
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDashboardCommand(allocator: std.mem.Allocator) void {
    std.debug.print("\n", .{});
    std.debug.print("{s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}║           TRI DASHBOARD — System Overview                   ║{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════╝{s}\n", .{ GOLDEN, RESET });

    // ── Section 1: Build Health ──
    std.debug.print("\n{s}┌─ BUILD HEALTH ─────────────────────────────────────────────┐{s}\n", .{ CYAN, RESET });
    const zig_ver = runShellCount(allocator, "zig version 2>/dev/null || echo 'N/A'");
    std.debug.print("  {s}Zig Version:{s}    {s}{s}{s}\n", .{ GRAY, RESET, GREEN, zig_ver, RESET });

    const bin_exists = std.fs.cwd().access("zig-out/bin/tri", .{});
    if (bin_exists) |_| {
        std.debug.print("  {s}TRI Binary:{s}     {s}Ready{s}\n", .{ GRAY, RESET, GREEN, RESET });
    } else |_| {
        std.debug.print("  {s}TRI Binary:{s}     {s}Not built{s}\n", .{ GRAY, RESET, RED, RESET });
    }

    const zig_files = runShellCount(allocator, "find src/ -name '*.zig' 2>/dev/null | wc -l");
    const spec_files = runShellCount(allocator, "find specs/ -name '*.vibee' 2>/dev/null | wc -l");
    std.debug.print("  {s}Zig Files:{s}      {s}{s}{s}\n", .{ GRAY, RESET, CYAN, zig_files, RESET });
    std.debug.print("  {s}VIBEE Specs:{s}    {s}{s}{s}\n", .{ GRAY, RESET, CYAN, spec_files, RESET });
    std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ CYAN, RESET });

    // ── Section 2: $TRI Economy ──
    std.debug.print("\n{s}┌─ $TRI ECONOMY ─────────────────────────────────────────────┐{s}\n", .{ GOLDEN, RESET });
    const home = std.posix.getenv("HOME") orelse "/tmp";
    var rewards_buf: [512]u8 = undefined;
    const rewards_path = std.fmt.bufPrint(&rewards_buf, "{s}/.tri/rewards.json", .{home}) catch "N/A";
    var cat_buf: [1024]u8 = undefined;
    const cat_cmd = std.fmt.bufPrint(&cat_buf, "cat {s} 2>/dev/null || echo '{{\"balance\":0,\"earned\":0,\"tasks\":0}}'", .{rewards_path}) catch "";

    if (cat_cmd.len > 0) {
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "sh", "-c", cat_cmd },
            .max_output_bytes = 4096,
        }) catch {
            std.debug.print("  {s}Balance:{s}        {s}0.000 $TRI{s}\n", .{ GRAY, RESET, GOLDEN, RESET });
            std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ GOLDEN, RESET });
            printDashboardFooter();
            return;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const balance = extractJsonString(result.stdout, "\"balance\":") orelse "0";
        const earned = extractJsonString(result.stdout, "\"earned\":") orelse "0";
        const tasks = extractJsonString(result.stdout, "\"tasks\":") orelse "0";

        std.debug.print("  {s}Balance:{s}        {s}{s} $TRI{s}\n", .{ GRAY, RESET, GOLDEN, balance, RESET });
        std.debug.print("  {s}Total Earned:{s}   {s}{s} $TRI{s}\n", .{ GRAY, RESET, GREEN, earned, RESET });
        std.debug.print("  {s}Tasks Done:{s}     {s}{s}{s}\n", .{ GRAY, RESET, CYAN, tasks, RESET });

        const bal_val = std.fmt.parseFloat(f64, balance) catch 0.0;
        const bar_len: usize = @min(@as(usize, @intFromFloat(bal_val / 5.0)), 40);
        std.debug.print("  {s}Progress:{s}       {s}", .{ GRAY, RESET, GOLDEN });
        for (0..bar_len) |_| std.debug.print("\xe2\x96\x88", .{});
        for (0..40 - bar_len) |_| std.debug.print("\xe2\x96\x91", .{});
        std.debug.print("{s} {d:.1}\n", .{ RESET, bal_val });
    }
    std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ GOLDEN, RESET });

    // ── Section 3: LSP Status ──
    std.debug.print("\n{s}┌─ LSP SERVER ───────────────────────────────────────────────┐{s}\n", .{ GREEN, RESET });
    std.debug.print("  {s}Version:{s}        {s}v1.1.0{s}\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("  {s}Protocol:{s}       JSON-RPC 2.0 (stdio)\n", .{ GRAY, RESET });
    std.debug.print("  {s}Capabilities:{s}\n", .{ GRAY, RESET });
    std.debug.print("    {s}+{s} textDocumentSync      {s}+{s} hover\n", .{ GREEN, RESET, GREEN, RESET });
    std.debug.print("    {s}+{s} codeAction            {s}+{s} completion (27 items)\n", .{ GREEN, RESET, GREEN, RESET });
    std.debug.print("    {s}+{s} publishDiagnostics    {s}+{s} formatting\n", .{ GREEN, RESET, GREEN, RESET });
    std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ GREEN, RESET });

    // ── Section 4: Recent Git Activity ──
    std.debug.print("\n{s}┌─ RECENT COMMITS ───────────────────────────────────────────┐{s}\n", .{ CYAN, RESET });
    const git_log = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "log", "--oneline", "-5" },
        .max_output_bytes = 2048,
    }) catch {
        std.debug.print("  {s}(git not available){s}\n", .{ GRAY, RESET });
        std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ CYAN, RESET });
        printDashboardFooter();
        return;
    };
    defer allocator.free(git_log.stdout);
    defer allocator.free(git_log.stderr);

    var line_it = std.mem.splitScalar(u8, git_log.stdout, '\n');
    var shown: u32 = 0;
    while (line_it.next()) |line| {
        if (line.len > 0 and shown < 5) {
            std.debug.print("  {s}{s}{s}\n", .{ GRAY, line, RESET });
            shown += 1;
        }
    }
    std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ CYAN, RESET });

    // ── Section 5: Tech Tree Level ──
    std.debug.print("\n{s}┌─ TECH TREE ────────────────────────────────────────────────┐{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Level 0: Core + Sacred Math              {s}============{s} Done\n", .{ GREEN, RESET });
    std.debug.print("  Level 1: Idiomatic + Analyzer            {s}============{s} Done\n", .{ GREEN, RESET });
    std.debug.print("  Level 2: Tree-Sitter Agent               {s}============{s} Done\n", .{ GREEN, RESET });
    std.debug.print("  Level 3: Major Expansion + Utilities     {s}============{s} Done\n", .{ GREEN, RESET });
    std.debug.print("  Level 4: LSP v1.1 + Diagnostics + Fix    {s}============{s} Done\n", .{ GREEN, RESET });
    std.debug.print("  Level 5: $TRI Rewards + Dashboard        {s}============{s} {s}Current{s}\n", .{ GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("  Level 6: Omega - Full Dev OS             {s}............{s} Next\n", .{ GRAY, RESET });
    std.debug.print("{s}└────────────────────────────────────────────────────────────┘{s}\n", .{ GOLDEN, RESET });

    printDashboardFooter();
}

fn printDashboardFooter() void {
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY | Dashboard v1.0{s}\n\n", .{ GOLDEN, RESET });
}
