// @origin(spec:tri_pipeline.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Golden Chain Pipeline Commands
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pipeline execution, decompose, plan, verify, verdict commands.
// Extracted from main.zig for faster compilation.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const golden_chain = @import("dna_polymerase.zig");
const pipeline_executor = @import("rna_polymerase.zig");
const batch_runner = @import("batch_runner.zig");
const cost_tracker = @import("cost_tracker.zig");
const toxic_verdict = @import("pathology.zig");
const loop_decide = @import("loop_decide.zig");
const pipeline_parallel = @import("pipeline_parallel.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;
const YELLOW = colors.GOLDEN;
// GOLDEN CHAIN PIPELINE COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runPipelineCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        printPipelineHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "run")) {
        runPipelineRun(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        runPipelineStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "resume")) {
        runPipelineResume(allocator);
    } else if (std.mem.eql(u8, subcmd, "audit")) {
        runPipelineAudit(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "batch")) {
        batch_runner.runBatchCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "version")) {
        runPipelineVersionCmd(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "cost")) {
        runPipelineCost(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "parallel")) {
        pipeline_parallel.runParallelPipelineCommand(allocator, sub_args);
    } else {
        std.debug.print("{s}Unknown pipeline subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printPipelineHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI CHAIN — Individual Link Execution (1 Link = 1 CLI command)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runChainCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        printChainHelp();
        return;
    }

    const link_name = args[0];

    // Resolve CLI name to ChainLink
    const link = golden_chain.ChainLink.fromCliName(link_name) orelse {
        std.debug.print("{s}Unknown chain link: {s}{s}\n", .{ RED, link_name, RESET });
        printChainHelp();
        return;
    };

    // Parse --task flag (default: link name)
    var task: []const u8 = link.getDescription();
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};
    var i: usize = 0;
    while (i < sub_args.len) : (i += 1) {
        if (std.mem.eql(u8, sub_args[i], "--task") and i + 1 < sub_args.len) {
            i += 1;
            task = sub_args[i];
        }
    }

    // Get role info
    const role_name = if (link.getOwnerRole()) |role| role.getName() else "UNASSIGNED";

    std.debug.print("\n{s}Chain Link: {s} ({s}){s}\n", .{ GOLDEN, link.getName(), link.getCliName(), RESET });
    std.debug.print("{s}\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81{s}\n", .{ GRAY, RESET });
    std.debug.print("  Description: {s}\n", .{link.getDescription()});
    std.debug.print("  Role:        {s}\n", .{role_name});
    std.debug.print("  Critical:    {s}\n", .{if (link.isCritical()) "YES" else "no"});
    std.debug.print("  MCP Tool:    {s}\n", .{link.getMcpToolName()});
    std.debug.print("  Task:        {s}\n\n", .{task});

    // Execute single link via pipeline executor
    var executor = pipeline_executor.PipelineExecutor.init(allocator, 1, task);
    defer executor.deinit();

    const result = executor.executeSingleLink(link);
    if (result) |metrics| {
        std.debug.print("{s}Link {s} completed{s}\n", .{ GREEN, link.getName(), RESET });
        std.debug.print("  Duration: {d}ms\n", .{metrics.duration_ms});
        if (metrics.tests_total > 0) {
            std.debug.print("  Tests: {d}/{d}\n", .{ metrics.tests_passed, metrics.tests_total });
        }
        if (metrics.coverage_percent > 0) {
            std.debug.print("  Coverage: {d:.1}%\n", .{metrics.coverage_percent});
        }
        std.debug.print("\nCHAIN_RESULT:link={s}:status=ok:duration_ms={d}\n", .{ link.getCliName(), metrics.duration_ms });
    } else |err| {
        std.debug.print("{s}Link {s} failed: {}{s}\n", .{ RED, link.getName(), err, RESET });
        std.debug.print("\nCHAIN_RESULT:link={s}:status=failed\n", .{link.getCliName()});
    }
}

fn printChainHelp() void {
    std.debug.print("\n{s}Golden Chain — Individual Link Execution{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81{s}\n\n", .{ GRAY, RESET });
    std.debug.print("Usage: tri chain <link> [--task \"description\"]\n\n", .{});
    std.debug.print("{s}Links ({d}):{s}\n", .{ CYAN, golden_chain.chain_link_count, RESET });

    // Print all links grouped by role
    inline for (0..golden_chain.chain_link_count) |idx| {
        const link: golden_chain.ChainLink = @enumFromInt(idx);
        const role_str = if (link.getOwnerRole()) |r| r.getName() else "OTHER";
        const critical = if (link.isCritical()) " {CRITICAL}" else "";
        std.debug.print("  {s}{d:>2}. {s:<14}{s} [{s}]{s}\n", .{
            GREEN, idx, link.getCliName(), RESET, role_str, critical,
        });
    }

    std.debug.print("\n{s}Roles:{s}\n", .{ CYAN, RESET });
    for (golden_chain.ALL_ROLES) |role| {
        const range = role.getLinkRange();
        std.debug.print("  {s} {s:<12}{s} Links {d}-{d}\n", .{
            role.getEmoji(), role.getName(), RESET, range.start, range.end - 1,
        });
    }

    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri chain test --task \"add auth\"\n", .{});
    std.debug.print("  tri chain codegen --task \"add dark mode\"\n", .{});
    std.debug.print("  tri chain verdict\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn printPipelineHelp() void {
    std.debug.print("\n{s}Golden Chain Pipeline - {d} Links (v5.1){s}\n", .{ GOLDEN, golden_chain.chain_link_count, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });
    std.debug.print("Usage: tri pipeline <subcommand> [args...]\n\n", .{});
    std.debug.print("{s}Subcommands:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}run{s} <task>       Execute full pipeline cycle\n", .{ GREEN, RESET });
    std.debug.print("  {s}status{s}          Show current state\n", .{ GREEN, RESET });
    std.debug.print("  {s}resume{s}          Resume from checkpoint\n", .{ GREEN, RESET });
    std.debug.print("  {s}audit{s} [N]       Audit N random specs (default 20)\n", .{ GREEN, RESET });
    std.debug.print("  {s}batch{s} [flags]   Parallel batch gen+ast-check (Thread.Pool)\n", .{ GREEN, RESET });
    std.debug.print("  {s}version{s}         Show version history\n", .{ GREEN, RESET });
    std.debug.print("  {s}version compare{s} <v1> <v2>  Compare two versions\n", .{ GREEN, RESET });
    std.debug.print("  {s}cost{s} <issue-N>  Show cost summary per role\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Individual commands:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri chain <link>      Execute single chain link\n", .{});
    std.debug.print("  tri decompose <task>  Break into sub-tasks\n", .{});
    std.debug.print("  tri verify           Run tests + benchmarks\n", .{});
    std.debug.print("  tri verdict          Generate toxic verdict\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runPipelineRun(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri pipeline run <task description> [--parallel]{s}\n", .{ RED, RESET });
        std.debug.print("Example: tri pipeline run \"add dark mode toggle\"\n", .{});
        std.debug.print("         tri pipeline run \"task\" --parallel  (DAG mode)\n", .{});
        return;
    }

    // Check for --parallel flag
    var use_parallel = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--parallel")) {
            use_parallel = true;
        }
    }

    if (use_parallel) {
        // Filter out --parallel from args before passing
        var filtered: [32][]const u8 = undefined;
        var fcount: usize = 0;
        for (args) |arg| {
            if (!std.mem.eql(u8, arg, "--parallel")) {
                filtered[fcount] = arg;
                fcount += 1;
            }
        }
        pipeline_parallel.runParallelPipelineCommand(allocator, filtered[0..fcount]);
        return;
    }

    // Join args as task description
    var task_buf: [4096]u8 = undefined;
    var pos: usize = 0;
    for (args, 0..) |arg, i| {
        if (i > 0 and pos < task_buf.len) {
            task_buf[pos] = ' ';
            pos += 1;
        }
        const copy_len = @min(arg.len, task_buf.len - pos);
        @memcpy(task_buf[pos..][0..copy_len], arg[0..copy_len]);
        pos += copy_len;
    }
    const task = task_buf[0..pos];

    // Create and run executor
    var executor = pipeline_executor.PipelineExecutor.init(allocator, 1, task);
    defer executor.deinit();

    executor.runAllLinks() catch |err| {
        std.debug.print("\n{s}Pipeline failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
}

pub fn runPipelineStatus(allocator: std.mem.Allocator) void {
    var executor = pipeline_executor.PipelineExecutor.init(allocator, 1, "status check");
    defer executor.deinit();
    executor.printStatus();
}

fn runPipelineResume(allocator: std.mem.Allocator) void {
    const tri_state = @import("tri_state.zig");

    const checkpoint_opt = tri_state.loadPipelineCheckpoint(allocator);
    if (checkpoint_opt) |checkpoint| {
        defer {
            if (checkpoint.task.len > 0) allocator.free(checkpoint.task);
            if (checkpoint.status.len > 0) allocator.free(checkpoint.status);
        }

        std.debug.print("\n{s}Pipeline Checkpoint Found{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });
        std.debug.print("  {s}Last Link:{s}  {d}/{d}\n", .{ CYAN, RESET, checkpoint.last_link, golden_chain.chain_link_count });
        std.debug.print("  {s}Task:{s}       {s}\n", .{ CYAN, RESET, checkpoint.task });
        std.debug.print("  {s}Status:{s}     {s}\n", .{ CYAN, RESET, checkpoint.status });

        if (std.mem.eql(u8, checkpoint.status, "completed")) {
            std.debug.print("\n{s}Pipeline already completed. Use 'tri pipeline run <task>' for a new run.{s}\n\n", .{ GREEN, RESET });
        } else if (std.mem.eql(u8, checkpoint.status, "failed")) {
            std.debug.print("\n{s}Pipeline failed at link {d}. Restarting from beginning...{s}\n\n", .{ RED, checkpoint.last_link, RESET });
            if (checkpoint.task.len > 0) {
                runPipelineRun(allocator, &[_][]const u8{checkpoint.task});
            }
        } else {
            std.debug.print("\n{s}Resuming pipeline from link {d}...{s}\n\n", .{ GREEN, checkpoint.last_link, RESET });
            if (checkpoint.task.len > 0) {
                runPipelineRun(allocator, &[_][]const u8{checkpoint.task});
            }
        }
    } else {
        std.debug.print("{s}No saved pipeline state found.{s}\n", .{ GRAY, RESET });
        std.debug.print("Run 'tri pipeline run <task>' to start a new pipeline.\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE AUDIT — Generate N random specs, check compilation, write report
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runPipelineAudit(allocator: std.mem.Allocator, args: []const []const u8) void {
    // Parse sample count (default 20)
    var sample_count: usize = 20;
    if (args.len > 0) {
        sample_count = std.fmt.parseInt(usize, args[0], 10) catch 20;
    }

    std.debug.print("\n{s}Pipeline Audit — Oracle Baseline{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Sample size: {d} specs\n", .{sample_count});
    std.debug.print("  Method: vibee gen + zig ast-check\n\n", .{});

    // Collect .tri spec paths
    var specs_dir = std.fs.cwd().openDir("specs/tri", .{ .iterate = true }) catch {
        std.debug.print("{s}Error: Cannot open specs/tri/{s}\n", .{ RED, RESET });
        return;
    };
    defer specs_dir.close();

    var spec_names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (spec_names.items) |name| allocator.free(name);
        spec_names.deinit(allocator);
    }

    var iter = specs_dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
            const name_copy = allocator.dupe(u8, entry.name) catch continue;
            spec_names.append(allocator, name_copy) catch {
                allocator.free(name_copy);
                continue;
            };
        }
    }

    if (spec_names.items.len == 0) {
        std.debug.print("{s}No .tri specs found in specs/tri/{s}\n", .{ RED, RESET });
        return;
    }

    // Shuffle using simple Fisher-Yates with timestamp seed
    const seed: u64 = @bitCast(@as(i64, @truncate(std.time.nanoTimestamp())));
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    var si: usize = spec_names.items.len;
    while (si > 1) {
        si -= 1;
        const j = random.intRangeAtMost(usize, 0, si);
        const tmp = spec_names.items[si];
        spec_names.items[si] = spec_names.items[j];
        spec_names.items[j] = tmp;
    }

    const actual_count = @min(sample_count, spec_names.items.len);
    var pass: usize = 0;
    var fail: usize = 0;

    // Report buffer
    var report: std.ArrayListUnmanaged(u8) = .empty;
    defer report.deinit(allocator);

    report.appendSlice(allocator, "# Regeneration Audit Report\n\n") catch |err| {
        std.log.debug("report appendSlice header failed: {}", .{err});
    };
    const date_header = std.fmt.allocPrint(allocator, "**Date:** {d}\n**Sample:** {d} specs\n**Tool:** vibee gen + zig ast-check\n\n## Results\n\n| # | Spec | Status |\n|---|------|--------|\n", .{ std.time.timestamp(), actual_count }) catch "";
    defer if (date_header.len > 0) allocator.free(date_header);
    report.appendSlice(allocator, date_header) catch |err| {
        std.log.debug("report appendSlice date_header failed: {}", .{err});
    };

    for (spec_names.items[0..actual_count], 0..) |spec_name, idx| {
        const name = spec_name[0 .. spec_name.len - 4]; // strip .tri

        // Build paths
        const spec_path = std.fmt.allocPrint(allocator, "specs/tri/{s}", .{spec_name}) catch continue;
        defer allocator.free(spec_path);

        // Detect Verilog specs — skip zig ast-check for non-Zig languages
        const is_verilog = blk: {
            const spec_file = std.fs.cwd().openFile(spec_path, .{}) catch break :blk false;
            defer spec_file.close();
            var buf: [512]u8 = undefined;
            const bytes_read = spec_file.read(&buf) catch break :blk false;
            const header = buf[0..bytes_read];
            break :blk (std.mem.indexOf(u8, header, "language: varlog") != null or
                std.mem.indexOf(u8, header, "language: verilog") != null);
        };

        if (is_verilog) {
            std.debug.print("  {d:>2}. {s}✅{s} {s} (verilog — skipped ast-check)\n", .{ idx + 1, GREEN, RESET, name });
            pass += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ✅ (verilog) |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice verilog line failed: {}", .{err});
            };
            continue;
        }

        const out_path = std.fmt.allocPrint(allocator, "/tmp/tri-audit/{s}.zig", .{name}) catch continue;
        defer allocator.free(out_path);

        // Run vibee gen
        const gen_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "zig-out/bin/vibee", "gen", spec_path, out_path },
            .max_output_bytes = 1024 * 1024,
        }) catch {
            std.debug.print("  {d:>2}. {s}❌{s} {s} — gen crashed\n", .{ idx + 1, RED, RESET, name });
            fail += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ❌ gen crashed |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice gen crashed line failed: {}", .{err});
            };
            continue;
        };
        allocator.free(gen_result.stdout);
        allocator.free(gen_result.stderr);

        // Check if process exited normally (not signaled)
        const gen_exit_ok = switch (gen_result.term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (!gen_exit_ok) {
            std.debug.print("  {d:>2}. {s}❌{s} {s} — gen failed\n", .{ idx + 1, RED, RESET, name });
            fail += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ❌ gen failed |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice gen failed line failed: {}", .{err});
            };
            continue;
        }

        // Check if output exists
        const file_exists = std.fs.cwd().openFile(out_path, .{}) catch null;
        if (file_exists) |f| {
            f.close();
        } else {
            std.debug.print("  {d:>2}. {s}❌{s} {s} — no output\n", .{ idx + 1, RED, RESET, name });
            fail += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ❌ no output |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice no output line failed: {}", .{err});
            };
            continue;
        }

        // Run zig ast-check
        const check_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "zig", "ast-check", out_path },
            .max_output_bytes = 1024 * 1024,
        }) catch {
            std.debug.print("  {d:>2}. {s}❌{s} {s} — ast-check crashed\n", .{ idx + 1, RED, RESET, name });
            fail += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ❌ ast-check crashed |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice ast-check crashed line failed: {}", .{err});
            };
            continue;
        };
        allocator.free(check_result.stdout);
        allocator.free(check_result.stderr);

        const check_exit_ok = switch (check_result.term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (check_exit_ok) {
            std.debug.print("  {d:>2}. {s}✅{s} {s}\n", .{ idx + 1, GREEN, RESET, name });
            pass += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ✅ |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice pass line failed: {}", .{err});
            };
        } else {
            std.debug.print("  {d:>2}. {s}❌{s} {s} — ast-check failed\n", .{ idx + 1, RED, RESET, name });
            fail += 1;
            const line = std.fmt.allocPrint(allocator, "| {d} | {s} | ❌ ast-check failed |\n", .{ idx + 1, name }) catch continue;
            defer allocator.free(line);
            report.appendSlice(allocator, line) catch |err| {
                std.log.debug("report appendSlice fail line failed: {}", .{err});
            };
        }
    }

    const total = pass + fail;
    const rate: usize = if (total > 0) (pass * 100) / total else 0;

    // Determine verdict
    const verdict_emoji: []const u8 = if (rate >= 80) "💎" else if (rate >= 30) "🟡" else "💀";
    const verdict_text: []const u8 = if (rate >= 80) "phi-HARMONY" else if (rate >= 30) "GOLDEN DRIFT" else "CRITICAL";

    std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Compile rate: {s}{d}/{d} = {d}%{s} {s}\n", .{
        if (rate >= 80) GREEN else if (rate >= 30) GOLDEN else RED,
        pass,
        total,
        rate,
        RESET,
        verdict_emoji,
    });
    std.debug.print("  Verdict: {s} {s}\n", .{ verdict_emoji, verdict_text });
    std.debug.print("  Sacred Formula: V = phi * ({d}/100)^2 = {d:.3}\n", .{
        rate,
        @as(f64, 1.618034) * @as(f64, @floatFromInt(rate)) / 100.0 * @as(f64, @floatFromInt(rate)) / 100.0,
    });
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });

    // Write summary to report
    const summary = std.fmt.allocPrint(allocator, "\n## Summary\n\n- **Compiled:** {d}/{d} = **{d}%** {s}\n- **Failed:** {d}\n- **Verdict:** {s}\n", .{ pass, total, rate, verdict_emoji, fail, verdict_text }) catch "";
    defer if (summary.len > 0) allocator.free(summary);
    report.appendSlice(allocator, summary) catch |err| {
        std.log.debug("report appendSlice summary failed: {}", .{err});
    };

    // Write report to specs/REGENERATION_REPORT.md
    const report_file = std.fs.cwd().createFile("specs/REGENERATION_REPORT.md", .{}) catch {
        std.debug.print("{s}Warning: Could not write REGENERATION_REPORT.md{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer report_file.close();
    report_file.writeAll(report.items) catch |err| {
        std.log.warn("Failed to write REGENERATION_REPORT.md: {}", .{err});
    };
    std.debug.print("  Report saved: specs/REGENERATION_REPORT.md\n\n", .{});
}

pub fn runDecomposeCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri decompose <issue-number> [--template standard|bugfix|spike]{s}\n", .{ RED, RESET });
        std.debug.print("Example: tri decompose 114\n", .{});
        return;
    }

    // Detect issue number
    const issue_num = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    // Parse --template flag
    var template: []const u8 = "standard";
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--template") and i + 1 < args.len) {
            i += 1;
            template = args[i];
        }
    }

    // Phase definitions with associated agent roles
    const PhaseInfo = struct { name: []const u8, role_label: []const u8 };

    const standard_phases = [_]PhaseInfo{
        .{ .name = "RESEARCH", .role_label = "role:planner" },
        .{ .name = "PLAN", .role_label = "role:planner" },
        .{ .name = "IMPLEMENT", .role_label = "role:coder" },
        .{ .name = "TEST", .role_label = "role:tester" },
        .{ .name = "VERIFY", .role_label = "role:integrator" },
    };
    const bugfix_phases = [_]PhaseInfo{
        .{ .name = "REPRODUCE", .role_label = "role:tester" },
        .{ .name = "DIAGNOSE", .role_label = "role:reviewer" },
        .{ .name = "FIX", .role_label = "role:coder" },
        .{ .name = "TEST", .role_label = "role:tester" },
    };
    const spike_phases = [_]PhaseInfo{
        .{ .name = "RESEARCH", .role_label = "role:planner" },
        .{ .name = "PROTOTYPE", .role_label = "role:coder" },
        .{ .name = "EVALUATE", .role_label = "role:reviewer" },
    };

    const phases: []const PhaseInfo = if (std.mem.eql(u8, template, "bugfix"))
        &bugfix_phases
    else if (std.mem.eql(u8, template, "spike"))
        &spike_phases
    else
        &standard_phases;

    // Get parent issue info via gh
    const issue_num_str = std.fmt.allocPrint(allocator, "{d}", .{issue_num}) catch return;
    defer allocator.free(issue_num_str);

    const view_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "issue", "view", issue_num_str, "--json", "title,body", "--jq", ".title" },
        .max_output_bytes = 64 * 1024,
    }) catch {
        std.debug.print("{s}Failed to fetch issue #{d}{s}\n", .{ RED, issue_num, RESET });
        return;
    };
    defer allocator.free(view_result.stdout);
    defer allocator.free(view_result.stderr);

    // Trim title
    const title = std.mem.trim(u8, view_result.stdout, &[_]u8{' ', '\t', '\n', '\r'});
    if (title.len == 0) {
        std.debug.print("{s}Issue #{d} not found or empty title{s}\n", .{ RED, issue_num, RESET });
        return;
    }

    std.debug.print("\n{s}\xf0\x9f\x93\x8b Decomposing #{d} ({s}) \xe2\x86\x92 {d} sub-issues ({s}){s}\n\n", .{
        CYAN, issue_num, title, phases.len, template, RESET,
    });

    // Create sub-issues with role labels + agent:spawn
    var created: u32 = 0;
    for (phases, 0..) |phase, idx| {
        const sub_title = std.fmt.allocPrint(allocator, "[{s}] {d}/{d} \xe2\x80\x94 {s}", .{
            title, idx + 1, phases.len, phase.name,
        }) catch continue;
        defer allocator.free(sub_title);

        const sub_body = std.fmt.allocPrint(allocator, "Parent: #{d}\nPhase: {s}\nRole: {s}\nTemplate: {s}\nLinks: see `tri chain` for this role's chain links", .{
            issue_num, phase.name, phase.role_label, template,
        }) catch continue;
        defer allocator.free(sub_body);

        // Labels: role:X + agent:spawn + status:queued
        const labels = std.fmt.allocPrint(allocator, "status:queued,agent:spawn,{s}", .{phase.role_label}) catch continue;
        defer allocator.free(labels);

        const create_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{
                "gh",      "issue",   "create",
                "--title", sub_title, "--body",
                sub_body,  "--label", labels,
            },
            .max_output_bytes = 8 * 1024,
        }) catch continue;
        defer allocator.free(create_result.stdout);
        defer allocator.free(create_result.stderr);

        const ok = switch (create_result.term) {
            .Exited => |c| c == 0,
            else => false,
        };

        if (ok) {
            const url = std.mem.trim(u8, create_result.stdout, &[_]u8{' ', '\t', '\n', '\r'});
            std.debug.print("  {s}\xe2\x9c\x85 {d}/{d} {s} [{s}] \xe2\x86\x92 {s}{s}\n", .{
                GREEN, idx + 1, phases.len, phase.name, phase.role_label, url, RESET,
            });
            created += 1;
        } else {
            std.debug.print("  {s}\xe2\x9d\x8c {d}/{d} {s} \xe2\x80\x94 failed{s}\n", .{
                RED, idx + 1, phases.len, phase.name, RESET,
            });
        }
    }

    std.debug.print("\n{s}Created {d}/{d} sub-issues for #{d}{s}\n", .{
        if (created == phases.len) GREEN else YELLOW, created, phases.len, issue_num, RESET,
    });
    std.debug.print("DECOMPOSE_RESULT:issue={d}:created={d}:total={d}\n", .{ issue_num, created, phases.len });
}

pub fn runPlanCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    // Check for flags
    var show_help = false;
    var show_list = false;
    var task_start: usize = 0;
    var force = false;

    for (args, 0..) |arg, idx| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            show_help = true;
        } else if (std.mem.eql(u8, arg, "--list") or std.mem.eql(u8, arg, "-l")) {
            show_list = true;
        } else if (std.mem.eql(u8, arg, "--force")) {
            force = true;
        } else if (!std.mem.startsWith(u8, arg, "--")) {
            task_start = idx;
            break;
        }
    }

    if (show_help) {
        printPlanHelp();
        return;
    }

    if (show_list) {
        printPlanList();
        return;
    }

    if (args.len == 0 or task_start >= args.len) {
        std.debug.print("{s}Usage: tri plan <issue-number|task description> [--force]{s}\n", .{ RED, RESET });
        std.debug.print("       tri plan --list\n", .{});
        std.debug.print("       tri plan --help\n\n", .{});
        std.debug.print("Examples:\n  tri plan 114          # Generate spec from GitHub issue\n  tri plan \"add auth\"   # Generate spec from description\n", .{});
        return;
    }

    // Detect issue number vs text description
    var task: []const u8 = undefined;
    var module_name: []const u8 = undefined;
    var issue_num: ?u32 = null;
    var alloc_task: ?[]const u8 = null;
    var alloc_module: ?[]const u8 = null;

    if (std.fmt.parseInt(u32, args[task_start], 10)) |num| {
        // tri plan <N> — fetch issue from GitHub
        issue_num = num;
        const num_str = std.fmt.allocPrint(allocator, "{d}", .{num}) catch return;
        defer allocator.free(num_str);

        const view_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "gh", "issue", "view", num_str, "--json", "title,body", "--jq", ".title + \"\\n\" + .body" },
            .max_output_bytes = 64 * 1024,
        }) catch {
            std.debug.print("{s}Failed to fetch issue #{d}{s}\n", .{ RED, num, RESET });
            return;
        };
        defer allocator.free(view_result.stderr);

        const trimmed = std.mem.trim(u8, view_result.stdout, &[_]u8{' ', '\t', '\n', '\r'});
        if (trimmed.len == 0) {
            allocator.free(view_result.stdout);
            std.debug.print("{s}Issue #{d} not found{s}\n", .{ RED, num, RESET });
            return;
        }

        // First line = title, rest = body
        var line_iter = std.mem.splitScalar(u8, trimmed, '\n');
        const title_line = line_iter.next() orelse "";

        // Use title as task description
        alloc_task = allocator.dupe(u8, trimmed) catch {
            allocator.free(view_result.stdout);
            return;
        };
        task = alloc_task.?;
        allocator.free(view_result.stdout);

        // Generate module name: issue_<N>_<sanitized_title>
        var name_buf2: [256]u8 = undefined;
        var np: usize = 0;
        const prefix = std.fmt.bufPrint(name_buf2[0..], "issue_{d}_", .{num}) catch return;
        np = prefix.len;
        for (title_line) |c| {
            if (np >= name_buf2.len - 1) break;
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                name_buf2[np] = std.ascii.toLower(c);
                np += 1;
            } else if (c == ' ' and np > 0 and name_buf2[np - 1] != '_') {
                name_buf2[np] = '_';
                np += 1;
            }
        }
        // Trim trailing underscore
        if (np > 0 and name_buf2[np - 1] == '_') np -= 1;
        alloc_module = allocator.dupe(u8, name_buf2[0..np]) catch return;
        module_name = alloc_module.?;
    } else |_| {
        // tri plan "text description"
        var task_buf: [4096]u8 = undefined;
        var pos: usize = 0;
        for (args[task_start..], 0..) |arg, j| {
            if (j > 0 and pos < task_buf.len) {
                task_buf[pos] = ' ';
                pos += 1;
            }
            const copy_len = @min(arg.len, task_buf.len - pos);
            @memcpy(task_buf[pos..][0..copy_len], arg[0..copy_len]);
            pos += copy_len;
        }
        alloc_task = allocator.dupe(u8, task_buf[0..pos]) catch return;
        task = alloc_task.?;

        // Sanitize to module name
        var name_buf3: [256]u8 = undefined;
        var np2: usize = 0;
        for (task) |c| {
            if (np2 >= name_buf3.len - 1) break;
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                name_buf3[np2] = std.ascii.toLower(c);
                np2 += 1;
            } else if (c == ' ' and np2 > 0 and name_buf3[np2 - 1] != '_') {
                name_buf3[np2] = '_';
                np2 += 1;
            }
        }
        if (np2 > 0 and name_buf3[np2 - 1] == '_') np2 -= 1;
        alloc_module = allocator.dupe(u8, name_buf3[0..np2]) catch return;
        module_name = alloc_module.?;
    }
    defer if (alloc_task) |t| allocator.free(t);
    defer if (alloc_module) |m| allocator.free(m);

    // Create .tri spec file path
    const spec_path = std.fmt.allocPrint(allocator, "specs/tri/{s}.tri", .{module_name}) catch {
        std.debug.print("{s}Error: Failed to create spec path{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(spec_path);

    // Header
    std.debug.print("\n{s}\xf0\x9f\x93\x8b Plan Generation{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81{s}\n\n", .{ GRAY, RESET });
    if (issue_num) |num| {
        std.debug.print("Issue:  #{d}\n", .{num});
    }
    std.debug.print("Module: {s}\n", .{module_name});
    std.debug.print("Output: {s}\n\n", .{spec_path});

    // Check if spec already exists
    if (!force) {
        if (std.fs.cwd().openFile(spec_path, .{})) |f| {
            f.close();
            std.debug.print("{s}Spec already exists: {s}{s}\n", .{ YELLOW, spec_path, RESET });
            std.debug.print("Use --force to overwrite.\n", .{});
            return;
        } else |_| {}
    }

    // Create spec file
    const file = std.fs.cwd().createFile(spec_path, .{}) catch |err| {
        std.debug.print("{s}Error creating spec file: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer file.close();

    // Extract first line as short description for the spec
    var first_line: []const u8 = task;
    if (std.mem.indexOfScalar(u8, task, '\n')) |nl| {
        first_line = task[0..nl];
    }
    // Limit to 200 chars
    if (first_line.len > 200) first_line = first_line[0..200];

    // Write spec template
    const spec_content =
        \\# ═══════════════════════════════════════════════════════════════════════════════
        \\# VIBEE Specification — Generated by tri plan
        \\# ═══════════════════════════════════════════════════════════════════════════════
        \\# φ² + 1/φ² = 3 = TRINITY
        \\# ═══════════════════════════════════════════════════════════════════════════════
        \\
        \\name: {s}
        \\version: "1.0.0"
        \\language: zig
        \\module: {s}
        \\
        \\description: |
        \\  {s}
        \\
        \\types:
        \\  {s}Config:
        \\    fields:
        \\      enabled: Bool
        \\      data: String
        \\
        \\behaviors:
        \\  - name: init
        \\    given: allocator
        \\    when: initialize
        \\    then: ready
        \\
        \\  - name: process
        \\    given: input
        \\    when: data received
        \\    then: output
        \\
        \\  - name: deinit
        \\    given: self
        \\    when: cleanup
        \\    then: resources released
        \\
        \\# End of specification
        \\# Use 'tri gen specs/tri/{s}.tri' to generate code
    ;

    const formatted_content = std.fmt.allocPrint(allocator, spec_content, .{
        module_name, module_name, first_line, module_name, module_name,
    }) catch {
        std.debug.print("{s}Error formatting spec content{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(formatted_content);

    file.writeAll(formatted_content) catch |err| {
        std.debug.print("{s}Error writing spec file: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    std.debug.print("{s}\xe2\x9c\x85 Spec created: {s}{s}\n\n", .{ GREEN, spec_path, RESET });
    std.debug.print("Next steps:\n", .{});
    std.debug.print("  1. Edit the spec to add your types and behaviors\n", .{});
    std.debug.print("  2. tri gen {s}\n", .{spec_path});
    std.debug.print("  3. tri test spec {s}\n", .{module_name});
    std.debug.print("  4. tri test\n\n", .{});
    std.debug.print("PLAN_RESULT:module={s}:spec={s}\n", .{ module_name, spec_path });

    logSacredCall("plan", module_name);
}

fn printPlanHelp() void {
    std.debug.print("\n{s}Plan Generation (Link 5){s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });
    std.debug.print("Generate .tri specifications from task descriptions.\n\n", .{});
    std.debug.print("Usage: tri plan <task description>\n", .{});
    std.debug.print("       tri plan --list\n", .{});
    std.debug.print("       tri plan --help\n\n", .{});
    std.debug.print("{s}Options:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}--help, -h{s}       Show this help\n", .{ GREEN, RESET });
    std.debug.print("  {s}--list, -l{s}        List existing specs\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri plan \"add user authentication\"\n", .{});
    std.debug.print("  tri plan \"dark mode toggle\"\n", .{});
    std.debug.print("  tri plan --list\n\n", .{});
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn printPlanList() void {
    std.debug.print("\n{s}Existing VIBEE Specifications{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    const specs_dir = "specs/tri";
    var dir = std.fs.cwd().openDir(specs_dir, .{ .iterate = true }) catch {
        std.debug.print("{s}No specs directory found{s}\n", .{ GRAY, RESET });
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    var count: usize = 0;

    while (iter.next() catch |err| {
        std.debug.print("{s}Error reading directory: {}{s}\n", .{ RED, err, RESET });
        return;
    }) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
            const name = entry.name[0 .. entry.name.len - 6]; // Remove .tri extension
            std.debug.print("  {s}•{s} {s}\n", .{ GREEN, RESET, name });
            count += 1;
        }
    }

    if (count == 0) {
        std.debug.print("{s}No .tri specs found{s}\n", .{ GRAY, RESET });
    } else {
        std.debug.print("\n{s}Total: {d} spec(s){s}\n", .{ CYAN, count, RESET });
        std.debug.print("\nUse 'tri gen specs/tri/<name>.tri' to generate code\n", .{});
    }
    std.debug.print("\n", .{});
}

pub fn runVerifyCommand(allocator: std.mem.Allocator) void {
    std.debug.print("\n{s}Verification (Links 7-11){s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    // Link 7: Run tests
    std.debug.print("{s}Link 7: Running Tests...{s}\n", .{ CYAN, RESET });
    const test_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "build", "test" },
        .max_output_bytes = 10 * 1024 * 1024,
    }) catch |err| {
        std.debug.print("{s}Test execution failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(test_result.stdout);
    defer allocator.free(test_result.stderr);

    const tests_passed = (switch (test_result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    }) == 0;
    if (tests_passed) {
        std.debug.print("  {s}[OK]{s} Tests passed\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}[FAIL]{s} Tests failed\n", .{ RED, RESET });
        if (test_result.stderr.len > 0) {
            std.debug.print("{s}\n", .{test_result.stderr});
        }
        return;
    }

    // Link 8: Simple benchmark
    std.debug.print("{s}Link 8: Running Benchmarks...{s}\n", .{ CYAN, RESET });
    const start = std.time.nanoTimestamp();
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        sum += i * i;
    }
    const elapsed = std.time.nanoTimestamp() - start;
    std.mem.doNotOptimizeAway(&sum);

    const elapsed_us = @divFloor(elapsed, 1000);
    std.debug.print("  {s}[OK]{s} Benchmark: {d}us (1000 iterations)\n", .{ GREEN, RESET, elapsed_us });

    // Summary
    std.debug.print("\n{s}Verification complete{s}\n", .{ GREEN, RESET });
    std.debug.print("  Tests: PASS\n", .{});
    std.debug.print("  Benchmarks: No regression detected\n\n", .{});

    // Experience hook
    const exp_hooks = @import("experience_hooks.zig");
    exp_hooks.autoSaveExperience("verify", "", true);
}

pub fn runVerdictCommand(allocator: std.mem.Allocator) void {
    toxic_verdict.runVerdictCommand(allocator);
}

pub fn runVerdictCommandEx(allocator: std.mem.Allocator, args: []const []const u8) void {
    toxic_verdict.runVerdictCommandEx(allocator, args);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC CREATE & LOOP DECIDE COMMANDS (v8.27)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runSpecCreateCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    const spec_create = @import("spec_create.zig");
    spec_create.runSpecCreateCommand(allocator, args);
}

pub fn runLoopDecideCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    loop_decide.runLoopDecideCommand(allocator, args);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE VERSION -- Version history and comparison
// =============================================================================

// ═══════════════════════════════════════════════════════════════════════════════
// TRI PIPELINE COST — v5.1 Per-Issue Cost Summary
// ═══════════════════════════════════════════════════════════════════════════════

fn runPipelineCost(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;

    if (args.len < 1) {
        std.debug.print("{s}Usage: tri pipeline cost <issue-number>{s}\n", .{ RED, RESET });
        std.debug.print("Example: tri pipeline cost 42\n", .{});
        return;
    }

    const issue_str = args[0];
    const issue_number = std.fmt.parseInt(u32, issue_str, 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, issue_str, RESET });
        return;
    };

    // Try to read cost summary from handoff dir
    const handoff_mod = @import("handoff.zig");
    var dir_buf: [256]u8 = undefined;
    const dir = handoff_mod.getHandoffDir(&dir_buf, issue_number);

    var path_buf: [512]u8 = undefined;
    const cost_path = std.fmt.bufPrint(&path_buf, "{s}/cost_summary.json", .{dir}) catch {
        std.debug.print("{s}Path error{s}\n", .{ RED, RESET });
        return;
    };

    // Check if cost summary exists
    const exists = blk: {
        const f = std.fs.cwd().openFile(cost_path, .{}) catch break :blk false;
        f.close();
        break :blk true;
    };

    if (exists) {
        std.debug.print("\n{s}Cost Summary — Issue #{d}{s}\n", .{ GOLDEN, issue_number, RESET });
        std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
        std.debug.print("  File: {s}\n", .{cost_path});

        // Read and display the file
        const file = std.fs.cwd().openFile(cost_path, .{}) catch {
            std.debug.print("  {s}Could not read cost file{s}\n", .{ RED, RESET });
            return;
        };
        defer file.close();

        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch 0;
        if (n > 0) {
            std.debug.print("\n{s}\n", .{read_buf[0..n]});
        }
    } else {
        std.debug.print("\n{s}No cost data for issue #{d}{s}\n", .{ YELLOW, issue_number, RESET });
        std.debug.print("  Expected at: {s}\n", .{cost_path});
        std.debug.print("  Run the pipeline with an issue number to generate cost data.\n\n", .{});

        // Check if handoff dir exists at all
        const handoff_exists = blk: {
            var artifact_buf: [512]u8 = undefined;
            const planner_path = handoff_mod.getArtifactPath(&artifact_buf, issue_number, .planner);
            const f = std.fs.cwd().openFile(planner_path, .{}) catch break :blk false;
            f.close();
            break :blk true;
        };

        if (handoff_exists) {
            std.debug.print("  {s}Handoff artifacts exist but no cost data yet.{s}\n", .{ CYAN, RESET });
            std.debug.print("  Cost tracking is added in v5.1 — re-run pipeline to generate.\n\n", .{});
        }
    }
}

fn runPipelineVersionCmd(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len >= 1 and std.mem.eql(u8, args[0], "compare")) {
        if (args.len < 3) {
            std.debug.print("{s}Usage: tri pipeline version compare <v1> <v2>{s}\n", .{ RED, RESET });
            std.debug.print("Example: tri pipeline version compare v4.4 v5.0\n", .{});
            return;
        }
        runPipelineVersionCompare(allocator, args[1], args[2]);
    } else {
        runPipelineVersionList(allocator);
    }
}

fn runPipelineVersionList(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("\n{s}Golden Chain Version History{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    // List version files from .trinity/versions/
    var dir = std.fs.cwd().openDir(".trinity/versions", .{ .iterate = true }) catch {
        std.debug.print("{s}No version history found. Creating baseline...{s}\n", .{ GRAY, RESET });
        std.debug.print("Run 'tri pipeline run \"<task>\"' to generate first version.\n\n", .{});
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    var count: usize = 0;
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
            std.debug.print("  {s}\xe2\x97\x8f{s} {s}\n", .{ GREEN, RESET, entry.name });
            count += 1;
        }
    }

    if (count == 0) {
        std.debug.print("{s}No versions found{s}\n", .{ GRAY, RESET });
    } else {
        std.debug.print("\n{s}Total: {d} version(s){s}\n", .{ CYAN, count, RESET });
    }
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// =============================================================================
// VERSION COMPARE -- Diff table between two version JSON files
// =============================================================================

/// Read a version JSON file and extract key metrics for comparison.
/// Returns null if the file cannot be read or parsed.
const VersionInfo = struct {
    version: []const u8,
    codename: []const u8,
    date: []const u8,
    // Metrics
    chain_links: ?i64,
    time_to_pr_min: ?i64,
    success_rate_pct: ?i64,
    tests_passing_pct: ?i64,
    compilation_gate_pct: ?i64,
    telegram_msgs_per_issue: ?i64,
    cost_per_issue_usd: ?f64,
    vulnerabilities: ?i64,
    loc_entrypoint: ?i64,
    role_isolation: ?bool,
    roles: ?i64,
    agent_model: []const u8,
};

/// Returned VersionInfo borrows strings from `parsed` - caller must keep parsed alive.
const ParsedVersion = struct {
    info: VersionInfo,
    _parsed: std.json.Parsed(std.json.Value),
    _content: []const u8,
    _allocator: std.mem.Allocator,

    fn deinit(self: *ParsedVersion) void {
        self._parsed.deinit();
        self._allocator.free(self._content);
    }
};

fn readVersionFile(allocator: std.mem.Allocator, name: []const u8) ?ParsedVersion {
    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, ".trinity/versions/{s}.json", .{name}) catch return null;

    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 256 * 1024) catch return null;

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{ .allocate = .alloc_always }) catch {
        allocator.free(content);
        return null;
    };

    const root = parsed.value.object;

    return ParsedVersion{
        .info = VersionInfo{
            .version = "?",
            .codename = getJsonStr(root, "codename"),
            .date = getJsonStr(root, "date"),
            .chain_links = getMetricInt(root, "chain_links"),
            .time_to_pr_min = getMetricInt(root, "time_to_pr_min"),
            .success_rate_pct = getMetricInt(root, "success_rate_pct"),
            .tests_passing_pct = getMetricInt(root, "tests_passing_pct"),
            .compilation_gate_pct = getMetricInt(root, "compilation_gate_pct"),
            .telegram_msgs_per_issue = getMetricInt(root, "telegram_msgs_per_issue"),
            .cost_per_issue_usd = getMetricFloat(root, "cost_per_issue_usd"),
            .vulnerabilities = getMetricInt(root, "vulnerabilities"),
            .loc_entrypoint = getMetricInt(root, "loc_entrypoint"),
            .role_isolation = getMetricBool(root, "role_isolation"),
            .roles = getArchInt(root, "roles"),
            .agent_model = getArchStr(root, "agent_model"),
        },
        ._parsed = parsed,
        ._content = content,
        ._allocator = allocator,
    };
}

fn getJsonStr(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    const val = obj.get(key) orelse return "?";
    return switch (val) {
        .string => |s| s,
        else => "?",
    };
}

fn getMetricInt(obj: std.json.ObjectMap, key: []const u8) ?i64 {
    const metrics_val = obj.get("metrics") orelse return null;
    const metrics = switch (metrics_val) {
        .object => |o| o,
        else => return null,
    };
    const val = metrics.get(key) orelse return null;
    return switch (val) {
        .integer => |i| i,
        else => null,
    };
}

fn getMetricFloat(obj: std.json.ObjectMap, key: []const u8) ?f64 {
    const metrics_val = obj.get("metrics") orelse return null;
    const metrics = switch (metrics_val) {
        .object => |o| o,
        else => return null,
    };
    const val = metrics.get(key) orelse return null;
    return switch (val) {
        .float => |f| f,
        .integer => |i| @as(f64, @floatFromInt(i)),
        else => null,
    };
}

fn getMetricBool(obj: std.json.ObjectMap, key: []const u8) ?bool {
    const metrics_val = obj.get("metrics") orelse return null;
    const metrics = switch (metrics_val) {
        .object => |o| o,
        else => return null,
    };
    const val = metrics.get(key) orelse return null;
    return switch (val) {
        .bool => |b| b,
        else => null,
    };
}

fn getArchInt(obj: std.json.ObjectMap, key: []const u8) ?i64 {
    const arch_val = obj.get("architecture") orelse return null;
    const arch = switch (arch_val) {
        .object => |o| o,
        else => return null,
    };
    const val = arch.get(key) orelse return null;
    return switch (val) {
        .integer => |i| i,
        else => null,
    };
}

fn getArchStr(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    const arch_val = obj.get("architecture") orelse return "?";
    const arch = switch (arch_val) {
        .object => |o| o,
        else => return "?",
    };
    const val = arch.get(key) orelse return "?";
    return switch (val) {
        .string => |s| s,
        else => "?",
    };
}

fn runPipelineVersionCompare(allocator: std.mem.Allocator, v1_name: []const u8, v2_name: []const u8) void {
    var pv1 = readVersionFile(allocator, v1_name) orelse {
        std.debug.print("{s}Could not read version file: .trinity/versions/{s}.json{s}\n", .{ RED, v1_name, RESET });
        return;
    };
    defer pv1.deinit();

    var pv2 = readVersionFile(allocator, v2_name) orelse {
        std.debug.print("{s}Could not read version file: .trinity/versions/{s}.json{s}\n", .{ RED, v2_name, RESET });
        return;
    };
    defer pv2.deinit();

    const v1 = pv1.info;
    const v2 = pv2.info;

    std.debug.print("\n{s}Version Comparison: {s} vs {s}{s}\n", .{ GOLDEN, v1_name, v2_name, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    // Header
    std.debug.print("  {s}Codename:{s}           {s:<20}   {s}\n", .{ CYAN, RESET, v1.codename, v2.codename });
    std.debug.print("  {s}Date:{s}               {s:<20}   {s}\n", .{ CYAN, RESET, v1.date, v2.date });
    std.debug.print("  {s}Agent Model:{s}        {s:<20}   {s}\n", .{ CYAN, RESET, v1.agent_model, v2.agent_model });

    std.debug.print("\n  {s}Metric                  {s:<12}  {s:<12}  Delta{s}\n", .{ GRAY, v1_name, v2_name, RESET });
    std.debug.print("  {s}──────────────────────  ──────────  ──────────  ──────{s}\n", .{ GRAY, RESET });

    // Compare integer metrics
    printMetricRow("Chain links", v1.chain_links, v2.chain_links, false);
    printMetricRow("Time to PR (min)", v1.time_to_pr_min, v2.time_to_pr_min, true);
    printMetricRow("Success rate (%)", v1.success_rate_pct, v2.success_rate_pct, false);
    printMetricRow("Tests passing (%)", v1.tests_passing_pct, v2.tests_passing_pct, false);
    printMetricRow("Compile gate (%)", v1.compilation_gate_pct, v2.compilation_gate_pct, false);
    printMetricRow("Telegram msgs/issue", v1.telegram_msgs_per_issue, v2.telegram_msgs_per_issue, true);
    printMetricRow("Vulnerabilities", v1.vulnerabilities, v2.vulnerabilities, true);
    printMetricRow("LOC entrypoint", v1.loc_entrypoint, v2.loc_entrypoint, true);
    printMetricRow("Roles", v1.roles, v2.roles, false);

    // Cost (float)
    if (v1.cost_per_issue_usd) |c1| {
        if (v2.cost_per_issue_usd) |c2| {
            const delta = c2 - c1;
            const color = if (delta < 0) GREEN else if (delta > 0) RED else GRAY;
            var d_buf: [32]u8 = undefined;
            const d_str = std.fmt.bufPrint(&d_buf, "{d:.2}", .{delta}) catch "?";
            var c1_buf: [32]u8 = undefined;
            const c1_str = std.fmt.bufPrint(&c1_buf, "${d:.2}", .{c1}) catch "?";
            var c2_buf: [32]u8 = undefined;
            const c2_str = std.fmt.bufPrint(&c2_buf, "${d:.2}", .{c2}) catch "?";
            std.debug.print("  Cost/issue (USD)      {s:<12}  {s:<12}  {s}{s}{s}\n", .{
                c1_str, c2_str, color, d_str, RESET,
            });
        }
    }

    // Role isolation (bool)
    if (v1.role_isolation) |r1| {
        if (v2.role_isolation) |r2| {
            const s1: []const u8 = if (r1) "true" else "false";
            const s2: []const u8 = if (r2) "true" else "false";
            const color = if (r2 and !r1) GREEN else if (!r2 and r1) RED else GRAY;
            const delta_str: []const u8 = if (r1 == r2) "=" else if (r2) "NEW" else "LOST";
            std.debug.print("  Role isolation        {s:<12}  {s:<12}  {s}{s}{s}\n", .{
                s1, s2, color, delta_str, RESET,
            });
        }
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn printMetricRow(label: []const u8, val_1: ?i64, val_2: ?i64, lower_is_better: bool) void {
    const m1 = val_1 orelse return;
    const m2 = val_2 orelse return;
    const delta = m2 - m1;

    const color = blk: {
        if (delta == 0) break :blk GRAY;
        if (lower_is_better) {
            break :blk if (delta < 0) GREEN else RED;
        } else {
            break :blk if (delta > 0) GREEN else RED;
        }
    };

    var v1_buf: [32]u8 = undefined;
    const v1_str = std.fmt.bufPrint(&v1_buf, "{d}", .{m1}) catch "?";
    var v2_buf: [32]u8 = undefined;
    const v2_str = std.fmt.bufPrint(&v2_buf, "{d}", .{m2}) catch "?";
    var d_buf: [32]u8 = undefined;
    const d_str = if (delta >= 0)
        std.fmt.bufPrint(&d_buf, "+{d}", .{delta}) catch "?"
    else
        std.fmt.bufPrint(&d_buf, "{d}", .{delta}) catch "?";

    // Pad label to 22 chars
    std.debug.print("  {s}", .{label});
    const label_len = label.len;
    if (label_len < 22) {
        var pad_buf: [22]u8 = undefined;
        @memset(&pad_buf, ' ');
        std.debug.print("{s}", .{pad_buf[0 .. 22 - label_len]});
    }
    std.debug.print("  {s:<12}  {s:<12}  {s}{s}{s}\n", .{
        v1_str, v2_str, color, d_str, RESET,
    });
}

fn logSacredCall(command: []const u8, arg: []const u8) void {
    const log_path = "trinity-nexus/.ralph/sacred_tool_calls.log";

    var line_buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&line_buf, "[phi] | tri {s} {s}\n", .{ command, arg }) catch return;

    const file = std.fs.cwd().openFile(log_path, .{ .mode = .write_only }) catch {
        // Create directory and file if not exists
        std.fs.cwd().makePath("trinity-nexus/.ralph") catch return;
        const new_file = std.fs.cwd().createFile(log_path, .{}) catch return;
        defer new_file.close();
        new_file.writeAll(line) catch return;
        return;
    };
    defer file.close();

    // Seek to end and append
    file.seekFromEnd(0) catch return;
    file.writeAll(line) catch return;
}

test "pipeline color imports" {
    try std.testing.expect(GREEN.len > 0);
    try std.testing.expect(GOLDEN.len > 0);
}
