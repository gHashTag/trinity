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
// DEV UTILITIES: doctor, clean, fmt, stats, igla
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDoctorCommand(allocator: std.mem.Allocator) void {
    std.debug.print("\n{s}═══ TRI DOCTOR — Project Health Check ═══{s}\n\n", .{ GOLDEN, RESET });

    // 1. Zig version
    std.debug.print("{s}[1/5]{s} Zig version: ", .{ CYAN, RESET });
    const zig_ver = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "version" },
    }) catch |err| {
        std.debug.print("{s}ERROR: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(zig_ver.stdout);
    defer allocator.free(zig_ver.stderr);
    if (zig_ver.stdout.len > 0) {
        std.debug.print("{s}{s}{s}", .{ GREEN, std.mem.trim(u8, zig_ver.stdout, "\n\r "), RESET });
    }
    std.debug.print("\n", .{});

    // 2. Git branch
    std.debug.print("{s}[2/5]{s} Git branch:  ", .{ CYAN, RESET });
    const git_branch = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "branch", "--show-current" },
    }) catch |err| {
        std.debug.print("{s}ERROR: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(git_branch.stdout);
    defer allocator.free(git_branch.stderr);
    std.debug.print("{s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, git_branch.stdout, "\n\r "), RESET });

    // 3. Git status (dirty files)
    std.debug.print("{s}[3/5]{s} Working tree: ", .{ CYAN, RESET });
    const git_status = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "status", "--porcelain" },
    }) catch |err| {
        std.debug.print("{s}ERROR: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(git_status.stdout);
    defer allocator.free(git_status.stderr);
    if (git_status.stdout.len == 0) {
        std.debug.print("{s}clean{s}\n", .{ GREEN, RESET });
    } else {
        // Count dirty files
        var dirty_count: usize = 0;
        var it = std.mem.splitScalar(u8, std.mem.trim(u8, git_status.stdout, "\n\r "), '\n');
        while (it.next()) |_| dirty_count += 1;
        std.debug.print("{s}{d} modified files{s}\n", .{ GOLDEN, dirty_count, RESET });
    }

    // 4. Build check
    std.debug.print("{s}[4/5]{s} Build:       ", .{ CYAN, RESET });
    const build_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "build" },
        .max_output_bytes = 10 * 1024 * 1024,
    }) catch |err| {
        std.debug.print("{s}ERROR: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(build_result.stdout);
    defer allocator.free(build_result.stderr);
    if (build_result.term.Exited == 0) {
        std.debug.print("{s}OK{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}FAILED{s}\n", .{ RED, RESET });
        if (build_result.stderr.len > 0) {
            // Show first 3 lines of error
            var lines_it = std.mem.splitScalar(u8, build_result.stderr, '\n');
            var line_count: usize = 0;
            while (lines_it.next()) |line| {
                if (line_count >= 3) break;
                std.debug.print("         {s}{s}{s}\n", .{ RED, line, RESET });
                line_count += 1;
            }
        }
    }

    // 5. Critical files check
    std.debug.print("{s}[5/5]{s} Critical files:\n", .{ CYAN, RESET });
    const critical_files = [_][]const u8{
        "src/vsa.zig",
        "src/vm.zig",
        "src/vibeec/vibee_parser.zig",
        "src/vibeec/parser_types.zig",
        "src/vibeec/parser_sections.zig",
        "src/vibeec/parser_utils.zig",
        "build.zig",
    };
    for (critical_files) |path| {
        std.fs.cwd().access(path, .{}) catch {
            std.debug.print("         {s}MISSING: {s}{s}\n", .{ RED, path, RESET });
            continue;
        };
        std.debug.print("         {s}OK{s} {s}\n", .{ GREEN, RESET, path });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runCleanCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}TRI CLEAN — Removing build artifacts{s}\n\n", .{ GOLDEN, RESET });

    // Remove .zig-cache
    std.debug.print("  Removing .zig-cache... ", .{});
    const rm_cache = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "rm", "-rf", ".zig-cache" },
    }) catch |err| {
        std.debug.print("{s}ERROR: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(rm_cache.stdout);
    defer allocator.free(rm_cache.stderr);
    std.debug.print("{s}done{s}\n", .{ GREEN, RESET });

    // Remove zig-out
    std.debug.print("  Removing zig-out...    ", .{});
    const rm_out = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "rm", "-rf", "zig-out" },
    }) catch |err| {
        std.debug.print("{s}ERROR: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(rm_out.stdout);
    defer allocator.free(rm_out.stderr);
    std.debug.print("{s}done{s}\n", .{ GREEN, RESET });

    std.debug.print("\n{s}Clean complete.{s}\n", .{ GREEN, RESET });
}

pub fn runFmtCommand(allocator: std.mem.Allocator) void {
    std.debug.print("{s}TRI FMT — Formatting Zig source{s}\n\n", .{ GOLDEN, RESET });

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "fmt", "src/" },
        .max_output_bytes = 1 * 1024 * 1024,
    }) catch |err| {
        std.debug.print("{s}Error running zig fmt: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0 and result.stderr.len == 0) {
        std.debug.print("  {s}All files already formatted.{s}\n", .{ GREEN, RESET });
    } else {
        if (result.stdout.len > 0) {
            // Count formatted files
            var count: usize = 0;
            var it = std.mem.splitScalar(u8, std.mem.trim(u8, result.stdout, "\n\r "), '\n');
            while (it.next()) |line| {
                if (line.len > 0) count += 1;
            }
            std.debug.print("  {s}Formatted {d} files{s}\n", .{ GREEN, count, RESET });
            std.debug.print("{s}{s}{s}", .{ GRAY, result.stdout, RESET });
        }
        if (result.stderr.len > 0) {
            std.debug.print("{s}{s}{s}\n", .{ RED, result.stderr, RESET });
        }
    }
}

pub fn runStatsCommand(allocator: std.mem.Allocator) void {
    std.debug.print("\n{s}═══ TRI STATS — Project Statistics ═══{s}\n\n", .{ GOLDEN, RESET });

    // Count .zig files
    std.debug.print("{s}Zig source:{s}\n", .{ CYAN, RESET });
    const zig_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find src -name '*.zig' | wc -l" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(zig_count.stdout);
    defer allocator.free(zig_count.stderr);
    std.debug.print("  .zig files:    {s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, zig_count.stdout, " \n\r\t"), RESET });

    // Count LOC
    const zig_loc = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find src -name '*.zig' -exec cat {} + | wc -l" },
    }) catch |err| {
        std.debug.print("  LOC ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(zig_loc.stdout);
    defer allocator.free(zig_loc.stderr);
    std.debug.print("  Total LOC:     {s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, zig_loc.stdout, " \n\r\t"), RESET });

    // Count specs
    std.debug.print("\n{s}Specifications:{s}\n", .{ CYAN, RESET });
    const vibee_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find specs -name '*.vibee' 2>/dev/null | wc -l" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(vibee_count.stdout);
    defer allocator.free(vibee_count.stderr);
    std.debug.print("  .vibee specs:  {s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, vibee_count.stdout, " \n\r\t"), RESET });

    const tri_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find specs -name '*.tri' 2>/dev/null | wc -l" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(tri_count.stdout);
    defer allocator.free(tri_count.stderr);
    std.debug.print("  .tri specs:    {s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, tri_count.stdout, " \n\r\t"), RESET });

    // Count generated output files
    std.debug.print("\n{s}Generated output:{s}\n", .{ CYAN, RESET });
    const gen_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "find trinity-nexus/output -name '*.zig' 2>/dev/null | wc -l" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(gen_count.stdout);
    defer allocator.free(gen_count.stderr);
    std.debug.print("  Output .zig:   {s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, gen_count.stdout, " \n\r\t"), RESET });

    // Count test declarations
    std.debug.print("\n{s}Tests:{s}\n", .{ CYAN, RESET });
    const test_count = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "grep -r '^test ' src/ --include='*.zig' | wc -l" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(test_count.stdout);
    defer allocator.free(test_count.stderr);
    std.debug.print("  test blocks:   {s}{s}{s}\n", .{ GREEN, std.mem.trim(u8, test_count.stdout, " \n\r\t"), RESET });

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runIglaCommand(allocator: std.mem.Allocator) void {
    std.debug.print("\n{s}═══ IGLA STATUS — Parser Module Coverage ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}IGLA (Igla) — ukolov, ubivayushchiy ruchnoy kod{s}\n\n", .{ GRAY, RESET });

    // Parser modules with line counts
    const modules = [_]struct { path: []const u8, name: []const u8 }{
        .{ .path = "src/vibeec/parser_types.zig", .name = "parser_types.zig" },
        .{ .path = "src/vibeec/parser_utils.zig", .name = "parser_utils.zig" },
        .{ .path = "src/vibeec/parser_sections.zig", .name = "parser_sections.zig" },
        .{ .path = "src/vibeec/vibee_parser.zig", .name = "vibee_parser.zig (orchestrator)" },
    };

    var total_lines: usize = 0;
    std.debug.print("{s}Parser modules:{s}\n", .{ CYAN, RESET });
    for (modules) |m| {
        var cmd_buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "wc -l < {s}", .{m.path}) catch continue;
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "sh", "-c", cmd },
        }) catch continue;
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
        const lines = std.fmt.parseInt(usize, trimmed, 10) catch 0;
        total_lines += lines;
        std.debug.print("  {s}{s: <40}{s} {d} lines\n", .{ GREEN, m.name, RESET, lines });
    }
    std.debug.print("  {s}{s: <40}{s} {d} lines total\n", .{ GOLDEN, "TOTAL", RESET, total_lines });

    // List .tri specs
    std.debug.print("\n{s}IGLA specs (.tri):{s}\n", .{ CYAN, RESET });
    const specs_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "ls -1 specs/tri/igla_*.tri 2>/dev/null" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(specs_result.stdout);
    defer allocator.free(specs_result.stderr);
    if (specs_result.stdout.len > 0) {
        var it = std.mem.splitScalar(u8, std.mem.trim(u8, specs_result.stdout, "\n\r "), '\n');
        while (it.next()) |line| {
            if (line.len > 0) {
                std.debug.print("  {s}OK{s} {s}\n", .{ GREEN, RESET, line });
            }
        }
    } else {
        std.debug.print("  (none found)\n", .{});
    }

    // List generated output
    std.debug.print("\n{s}Generated output:{s}\n", .{ CYAN, RESET });
    const output_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "ls -1 trinity-nexus/output/lang/zig/igla_*.zig 2>/dev/null" },
    }) catch |err| {
        std.debug.print("  ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(output_result.stdout);
    defer allocator.free(output_result.stderr);
    if (output_result.stdout.len > 0) {
        var it = std.mem.splitScalar(u8, std.mem.trim(u8, output_result.stdout, "\n\r "), '\n');
        while (it.next()) |line| {
            if (line.len > 0) {
                std.debug.print("  {s}GEN{s} {s}\n", .{ GREEN, RESET, line });
            }
        }
    } else {
        std.debug.print("  (none found)\n", .{});
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
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
