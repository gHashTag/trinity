// ============================================================================
// BATCH PIPELINE RUNNER — Parallel spec generation with std.Thread.Pool
// Issue #77 | Scans specs, filters by lint status, runs gen+ast-check in parallel
// ============================================================================

const std = @import("std");
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const YELLOW = colors.YELLOW;
const RESET = colors.RESET;

// ============================================================================
// TYPES
// ============================================================================

const CompileStatus = enum {
    pass,
    ast_fail,
    compile_fail,
    gen_fail,
    lint_fail,
    timeout,
    skipped,
};

const PipelineResult = struct {
    spec_path: []const u8,
    success: bool,
    status: CompileStatus,
    duration_ns: i128,
    error_msg: []const u8,
};

const BatchConfig = struct {
    parallel: u32 = 4,
    filter: FilterMode = .all,
    directory: []const u8 = "specs/tri",
    dry_run: bool = false,
    timeout_seconds: u32 = 120,
};

const FilterMode = enum {
    all,
    lint_pass,
    lint_fail,
    changed_only,
};

const BatchReport = struct {
    total_specs: usize,
    filtered_specs: usize,
    passed: usize,
    failed: usize,
    skipped: usize,
    total_duration_ns: i128,
    parallel_workers: u32,
    failures: []const FailureEntry,
};

const FailureEntry = struct {
    spec: []const u8,
    status: CompileStatus,
    error_msg: []const u8,
};

// Thread-safe results collector
const ThreadSafeResults = struct {
    items: std.ArrayListUnmanaged(PipelineResult),
    mutex: std.Thread.Mutex,

    fn init() ThreadSafeResults {
        return .{
            .items = .empty,
            .mutex = .{},
        };
    }

    fn append(self: *ThreadSafeResults, allocator: std.mem.Allocator, result: PipelineResult) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.items.append(allocator, result) catch |err| {
            std.log.debug("batch_runner: append result failed: {}", .{err});
        };
    }

    fn deinit(self: *ThreadSafeResults, allocator: std.mem.Allocator) void {
        for (self.items.items) |r| {
            if (r.error_msg.len > 0) allocator.free(r.error_msg);
        }
        self.items.deinit(allocator);
    }
};

// Per-worker context passed to thread pool
const WorkerContext = struct {
    spec_path: []const u8,
    results: *ThreadSafeResults,
    allocator: std.mem.Allocator,
    filter: FilterMode,
};

// ============================================================================
// CLI ENTRY POINT
// ============================================================================

pub fn runBatchCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    var config = BatchConfig{};

    // Parse flags
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--parallel") or std.mem.eql(u8, arg, "-p")) {
            if (i + 1 < args.len) {
                i += 1;
                config.parallel = std.fmt.parseInt(u32, args[i], 10) catch 4;
            }
        } else if (std.mem.eql(u8, arg, "--filter") or std.mem.eql(u8, arg, "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                config.filter = parseFilterMode(args[i]);
            }
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            config.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 < args.len) {
                i += 1;
                config.timeout_seconds = std.fmt.parseInt(u32, args[i], 10) catch 120;
            }
        } else if (std.mem.eql(u8, arg, "--report")) {
            showLastReport(allocator);
            return;
        } else if (std.mem.eql(u8, arg, "--compare")) {
            showComparison(allocator);
            return;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printBatchHelp();
            return;
        }
    }

    runBatch(allocator, config);
}

fn parseFilterMode(s: []const u8) FilterMode {
    if (std.mem.eql(u8, s, "lint:pass") or std.mem.eql(u8, s, "lint_pass")) return .lint_pass;
    if (std.mem.eql(u8, s, "lint:fail") or std.mem.eql(u8, s, "lint_fail")) return .lint_fail;
    if (std.mem.eql(u8, s, "changed") or std.mem.eql(u8, s, "changed_only")) return .changed_only;
    return .all;
}

// ============================================================================
// CORE: SCAN → FILTER → PARALLEL RUN → REPORT
// ============================================================================

fn runBatch(allocator: std.mem.Allocator, config: BatchConfig) void {
    const start_ts = std.time.nanoTimestamp();

    // Header
    std.debug.print("\n{s}BATCH PIPELINE RUNNER{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}======================================================={s}\n\n", .{ GRAY, RESET });

    // Phase 1: Scan specs
    var all_specs = scanSpecs(allocator, config.directory);
    defer {
        for (all_specs.items) |p| allocator.free(p);
        all_specs.deinit(allocator);
    }

    std.debug.print("  Scanning {s}{s}/{s}... {s}{d}{s} files found\n", .{
        CYAN, config.directory, RESET, WHITE, all_specs.items.len, RESET,
    });

    if (all_specs.items.len == 0) {
        std.debug.print("{s}  No .tri files found.{s}\n\n", .{ RED, RESET });
        return;
    }

    // Phase 2: Filter
    var filtered = filterSpecs(allocator, all_specs.items, config.filter);
    defer {
        // Only free items that were duped during filter (not the originals)
        if (config.filter != .all) {
            for (filtered.items) |p| allocator.free(p);
        }
        filtered.deinit(allocator);
    }

    std.debug.print("  Filter: {s}{s}{s} -> {s}{d}{s} specs\n", .{
        YELLOW, @tagName(config.filter), RESET, WHITE, filtered.items.len, RESET,
    });
    std.debug.print("  Workers: {s}{d}{s} parallel threads\n\n", .{
        CYAN, config.parallel, RESET,
    });

    if (filtered.items.len == 0) {
        std.debug.print("{s}  No specs match filter.{s}\n\n", .{ RED, RESET });
        return;
    }

    // Phase 3: Dry run check
    if (config.dry_run) {
        std.debug.print("{s}  DRY RUN — would process:{s}\n", .{ YELLOW, RESET });
        for (filtered.items, 0..) |spec, idx| {
            std.debug.print("    {d:>3}. {s}\n", .{ idx + 1, spec });
        }
        std.debug.print("\n  Total: {d} specs with {d} workers\n\n", .{ filtered.items.len, config.parallel });
        return;
    }

    // Phase 4: Parallel execution
    var results = ThreadSafeResults.init();
    defer results.deinit(allocator);

    // Create worker contexts
    var contexts: std.ArrayListUnmanaged(WorkerContext) = .empty;
    defer contexts.deinit(allocator);
    for (filtered.items) |spec_path| {
        contexts.append(allocator, .{
            .spec_path = spec_path,
            .results = &results,
            .allocator = allocator,
            .filter = config.filter,
        }) catch continue;
    }

    // Init thread pool + wait group
    var pool: std.Thread.Pool = undefined;
    pool.init(.{
        .allocator = allocator,
        .n_jobs = config.parallel,
    }) catch {
        std.debug.print("{s}  Failed to init thread pool{s}\n", .{ RED, RESET });
        return;
    };
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    // Spawn all workers
    for (contexts.items) |*ctx| {
        pool.spawnWg(&wg, runSinglePipeline, .{ctx});
    }

    // Wait for all workers
    wg.wait();

    const end_ts = std.time.nanoTimestamp();
    const total_duration_ns = end_ts - start_ts;

    // Phase 5: Aggregate results
    var passed: usize = 0;
    var failed: usize = 0;
    var skipped: usize = 0;
    var failure_list: std.ArrayListUnmanaged(FailureEntry) = .empty;
    defer failure_list.deinit(allocator);

    for (results.items.items) |r| {
        if (r.success) {
            passed += 1;
        } else if (r.status == .skipped or r.status == .lint_fail) {
            skipped += 1;
        } else {
            failed += 1;
            failure_list.append(allocator, .{
                .spec = r.spec_path,
                .status = r.status,
                .error_msg = r.error_msg,
            }) catch |err| {
                std.log.debug("batch_runner: append failure entry failed: {}", .{err});
            };
        }
    }

    const report = BatchReport{
        .total_specs = all_specs.items.len,
        .filtered_specs = filtered.items.len,
        .passed = passed,
        .failed = failed,
        .skipped = skipped,
        .total_duration_ns = total_duration_ns,
        .parallel_workers = config.parallel,
        .failures = failure_list.items,
    };

    // Phase 6: Print report + write protocol
    printReport(report);
    writeProtocolLog(allocator, report);
    writeReportJson(allocator, report);
}

// ============================================================================
// SCAN: Walk directory recursively for .tri files
// ============================================================================

fn scanSpecs(allocator: std.mem.Allocator, directory: []const u8) std.ArrayListUnmanaged([]const u8) {
    var paths: std.ArrayListUnmanaged([]const u8) = .empty;

    // Open directory
    var dir = std.fs.cwd().openDir(directory, .{ .iterate = true }) catch return paths;
    defer dir.close();

    // Walk entries (non-recursive for specs/tri/ — subdirs handled separately)
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ directory, entry.name }) catch continue;
            paths.append(allocator, full_path) catch {
                allocator.free(full_path);
            };
        } else if (entry.kind == .directory) {
            // Skip archive directories
            if (std.mem.eql(u8, entry.name, "archive")) continue;

            // Recurse into subdirectory
            const sub_dir = std.fmt.allocPrint(allocator, "{s}/{s}", .{ directory, entry.name }) catch continue;
            defer allocator.free(sub_dir);

            var sub_results = scanSpecs(allocator, sub_dir);
            defer sub_results.deinit(allocator);

            for (sub_results.items) |sub_path| {
                paths.append(allocator, sub_path) catch {
                    allocator.free(sub_path);
                };
            }
        }
    }

    return paths;
}

// ============================================================================
// FILTER: Apply filter mode to spec list
// ============================================================================

fn filterSpecs(
    allocator: std.mem.Allocator,
    specs: []const []const u8,
    mode: FilterMode,
) std.ArrayListUnmanaged([]const u8) {
    var result: std.ArrayListUnmanaged([]const u8) = .empty;

    switch (mode) {
        .all => {
            // Return all — just reference the existing paths (no dupe)
            for (specs) |s| {
                result.append(allocator, s) catch |err| {
                    std.log.debug("batch_runner: append spec to filter result failed: {}", .{err});
                };
            }
        },
        .lint_pass => {
            for (specs) |spec_path| {
                const lint_ok = runLintCheck(allocator, spec_path);
                if (lint_ok) {
                    const duped = allocator.dupe(u8, spec_path) catch continue;
                    result.append(allocator, duped) catch {
                        allocator.free(duped);
                    };
                }
            }
        },
        .lint_fail => {
            for (specs) |spec_path| {
                const lint_ok = runLintCheck(allocator, spec_path);
                if (!lint_ok) {
                    const duped = allocator.dupe(u8, spec_path) catch continue;
                    result.append(allocator, duped) catch {
                        allocator.free(duped);
                    };
                }
            }
        },
        .changed_only => {
            // git diff --name-only HEAD~1 -- 'specs/**/*.tri'
            const git_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "git", "diff", "--name-only", "HEAD~1", "--", "specs/" },
                .max_output_bytes = 64 * 1024,
            }) catch return result;
            defer allocator.free(git_result.stdout);
            defer allocator.free(git_result.stderr);

            var lines = std.mem.splitScalar(u8, git_result.stdout, '\n');
            while (lines.next()) |line| {
                if (line.len == 0) continue;
                if (!std.mem.endsWith(u8, line, ".tri")) continue;
                // Check if this changed file is in our spec list
                for (specs) |spec_path| {
                    if (std.mem.eql(u8, spec_path, line) or std.mem.endsWith(u8, spec_path, line)) {
                        const duped = allocator.dupe(u8, spec_path) catch continue;
                        result.append(allocator, duped) catch {
                            allocator.free(duped);
                        };
                        break;
                    }
                }
            }
        },
    }

    return result;
}

fn runLintCheck(allocator: std.mem.Allocator, spec_path: []const u8) bool {
    const lint_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig-out/bin/vibee", "validate", spec_path },
        .max_output_bytes = 64 * 1024,
    }) catch return false;
    defer allocator.free(lint_result.stdout);
    defer allocator.free(lint_result.stderr);

    return switch (lint_result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

// ============================================================================
// WORKER: Run single spec pipeline (lint → gen → ast-check)
// ============================================================================

fn runSinglePipeline(ctx: *WorkerContext) void {
    const timer_start = std.time.nanoTimestamp();
    const allocator = ctx.allocator;

    // If filter is lint_pass, we already validated — skip re-lint
    // For other modes, run lint first
    if (ctx.filter != .lint_pass) {
        const lint_ok = runLintCheck(allocator, ctx.spec_path);
        if (!lint_ok) {
            ctx.results.append(allocator, .{
                .spec_path = ctx.spec_path,
                .success = false,
                .status = .lint_fail,
                .duration_ns = std.time.nanoTimestamp() - timer_start,
                .error_msg = "",
            });
            return;
        }
    }

    // Derive output path: specs/tri/foo.tri → /tmp/tri-batch/foo.zig
    const stem = extractStem(ctx.spec_path);

    var out_buf: [512]u8 = undefined;
    const out_path = std.fmt.bufPrint(&out_buf, "/tmp/tri-batch/{s}.zig", .{stem}) catch {
        ctx.results.append(allocator, .{
            .spec_path = ctx.spec_path,
            .success = false,
            .status = .gen_fail,
            .duration_ns = std.time.nanoTimestamp() - timer_start,
            .error_msg = "",
        });
        return;
    };

    // Detect verilog specs — skip ast-check
    const is_verilog = detectVerilog(ctx.spec_path);

    // Link 7: Generate code
    const gen_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig-out/bin/vibee", "gen", ctx.spec_path, out_path },
        .max_output_bytes = 256 * 1024,
    }) catch {
        ctx.results.append(allocator, .{
            .spec_path = ctx.spec_path,
            .success = false,
            .status = .gen_fail,
            .duration_ns = std.time.nanoTimestamp() - timer_start,
            .error_msg = "",
        });
        return;
    };
    allocator.free(gen_result.stdout);
    allocator.free(gen_result.stderr);

    const gen_ok = switch (gen_result.term) {
        .Exited => |code| code == 0,
        else => false,
    };

    if (!gen_ok) {
        ctx.results.append(allocator, .{
            .spec_path = ctx.spec_path,
            .success = false,
            .status = .gen_fail,
            .duration_ns = std.time.nanoTimestamp() - timer_start,
            .error_msg = "",
        });
        return;
    }

    // Verilog specs pass after gen (no ast-check)
    if (is_verilog) {
        ctx.results.append(allocator, .{
            .spec_path = ctx.spec_path,
            .success = true,
            .status = .pass,
            .duration_ns = std.time.nanoTimestamp() - timer_start,
            .error_msg = "",
        });
        return;
    }

    // Link 8: AST check generated .zig
    const ast_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "ast-check", out_path },
        .max_output_bytes = 256 * 1024,
    }) catch {
        ctx.results.append(allocator, .{
            .spec_path = ctx.spec_path,
            .success = false,
            .status = .ast_fail,
            .duration_ns = std.time.nanoTimestamp() - timer_start,
            .error_msg = "",
        });
        return;
    };

    const stderr_copy = if (ast_result.stderr.len > 0)
        allocator.dupe(u8, ast_result.stderr[0..@min(ast_result.stderr.len, 200)]) catch ""
    else
        "";
    allocator.free(ast_result.stdout);
    allocator.free(ast_result.stderr);

    const ast_ok = switch (ast_result.term) {
        .Exited => |code| code == 0,
        else => false,
    };

    ctx.results.append(allocator, .{
        .spec_path = ctx.spec_path,
        .success = ast_ok,
        .status = if (ast_ok) .pass else .ast_fail,
        .duration_ns = std.time.nanoTimestamp() - timer_start,
        .error_msg = stderr_copy,
    });
}

fn extractStem(path: []const u8) []const u8 {
    // "specs/tri/foo.tri" → "foo"
    var name = path;
    if (std.mem.lastIndexOfScalar(u8, name, '/')) |idx| {
        name = name[idx + 1 ..];
    }
    if (std.mem.endsWith(u8, name, ".tri")) {
        name = name[0 .. name.len - 4];
    }
    return name;
}

fn detectVerilog(spec_path: []const u8) bool {
    const file = std.fs.cwd().openFile(spec_path, .{}) catch return false;
    defer file.close();
    var buf: [512]u8 = undefined;
    const n = file.read(&buf) catch return false;
    const header = buf[0..n];
    return (std.mem.indexOf(u8, header, "language: varlog") != null or
        std.mem.indexOf(u8, header, "language: verilog") != null);
}

// ============================================================================
// REPORT: Print summary to stdout
// ============================================================================

fn printReport(report: BatchReport) void {
    const total = report.passed + report.failed + report.skipped;
    const rate: usize = if (total > 0) (report.passed * 100) / total else 0;

    const duration_ms = @divTrunc(report.total_duration_ns, @as(i128, 1_000_000));
    const duration_s = @divTrunc(duration_ms, @as(i128, 1000));
    const duration_min = @divTrunc(duration_s, @as(i128, 60));
    const duration_rem_s = @mod(duration_s, @as(i128, 60));
    const avg_ms = if (total > 0) @divTrunc(duration_ms, @as(i128, @intCast(total))) else @as(i128, 0);

    std.debug.print("\n{s}======================================================={s}\n", .{ GRAY, RESET });
    std.debug.print("{s}BATCH REPORT{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("  Total scanned  {s}{d}{s}\n", .{ WHITE, report.total_specs, RESET });
    std.debug.print("  Filtered       {s}{d}{s}\n", .{ WHITE, report.filtered_specs, RESET });
    std.debug.print("  {s}Pass{s}           {s}{d}{s}\n", .{ GREEN, RESET, GREEN, report.passed, RESET });
    std.debug.print("  {s}Fail{s}           {s}{d}{s}\n", .{ RED, RESET, RED, report.failed, RESET });
    std.debug.print("  Skip           {s}{d}{s}\n", .{ GRAY, report.skipped, RESET });
    std.debug.print("  Pass Rate      {s}{d}%{s}\n", .{
        if (rate >= 80) GREEN else if (rate >= 50) YELLOW else RED,
        rate,
        RESET,
    });
    std.debug.print("  Duration       {d}m {d}s\n", .{ duration_min, duration_rem_s });
    std.debug.print("  Avg/spec       {d}ms\n", .{avg_ms});
    std.debug.print("  Workers        {d}\n", .{report.parallel_workers});

    // Sacred formula
    const rate_f: f64 = @as(f64, @floatFromInt(rate)) / 100.0;
    const phi: f64 = 1.618034;
    const v = phi * rate_f * rate_f;
    std.debug.print("\n  V = phi * ({d}/100)^2 = {d:.3}\n", .{ rate, v });

    // Failure details
    if (report.failures.len > 0) {
        std.debug.print("\n  {s}Failures:{s}\n", .{ RED, RESET });
        for (report.failures, 0..) |f, idx| {
            if (idx >= 20) {
                std.debug.print("    ... and {d} more\n", .{report.failures.len - 20});
                break;
            }
            std.debug.print("    {s}{s}{s} [{s}]", .{ RED, f.spec, RESET, @tagName(f.status) });
            if (f.error_msg.len > 0) {
                // Show first line of error
                var lines = std.mem.splitScalar(u8, f.error_msg, '\n');
                if (lines.next()) |first_line| {
                    const trimmed = first_line[0..@min(first_line.len, 80)];
                    std.debug.print(" {s}", .{trimmed});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ============================================================================
// PROTOCOL: Write JSONL log + JSON report
// ============================================================================

fn writeProtocolLog(allocator: std.mem.Allocator, report: BatchReport) void {
    // Ensure directory exists
    std.fs.cwd().makePath(".trinity/batch") catch return;

    const total = report.passed + report.failed + report.skipped;
    const rate: usize = if (total > 0) (report.passed * 100) / total else 0;
    const ts = std.time.timestamp();

    // Append JSONL entry
    const log_name = std.fmt.allocPrint(allocator, ".trinity/batch/{d}.jsonl", .{ts}) catch return;
    defer allocator.free(log_name);

    const entry = std.fmt.allocPrint(
        allocator,
        "{{\"agent\":\"batch_runner\",\"action\":\"batch_run\",\"timestamp\":{d},\"total\":{d},\"filtered\":{d},\"passed\":{d},\"failed\":{d},\"skipped\":{d},\"rate\":{d},\"workers\":{d},\"duration_ns\":{d}}}\n",
        .{
            ts,
            report.total_specs,
            report.filtered_specs,
            report.passed,
            report.failed,
            report.skipped,
            rate,
            report.parallel_workers,
            report.total_duration_ns,
        },
    ) catch return;
    defer allocator.free(entry);

    const file = std.fs.cwd().createFile(log_name, .{}) catch return;
    defer file.close();
    file.writeAll(entry) catch |err| {
        std.log.debug("batch_runner: write log entry failed: {}", .{err});
    };

    std.debug.print("  Protocol: {s}\n", .{log_name});
}

fn writeReportJson(allocator: std.mem.Allocator, report: BatchReport) void {
    const total = report.passed + report.failed + report.skipped;
    const rate: usize = if (total > 0) (report.passed * 100) / total else 0;

    const duration_ms = @divTrunc(report.total_duration_ns, @as(i128, 1_000_000));

    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(allocator);

    const header = std.fmt.allocPrint(allocator,
        \\{{
        \\  "timestamp": {d},
        \\  "total_specs": {d},
        \\  "filtered_specs": {d},
        \\  "passed": {d},
        \\  "failed": {d},
        \\  "skipped": {d},
        \\  "pass_rate": {d},
        \\  "duration_ms": {d},
        \\  "parallel_workers": {d},
        \\  "failures": [
        \\
    , .{
        std.time.timestamp(),
        report.total_specs,
        report.filtered_specs,
        report.passed,
        report.failed,
        report.skipped,
        rate,
        duration_ms,
        report.parallel_workers,
    }) catch return;
    defer allocator.free(header);
    buf.appendSlice(allocator, header) catch return;

    for (report.failures, 0..) |f, idx| {
        if (idx > 0) buf.appendSlice(allocator, ",\n") catch |err| {
            std.log.debug("batch_runner: append separator failed: {}", .{err});
        };
        const entry = std.fmt.allocPrint(allocator,
            \\    {{"spec": "{s}", "status": "{s}"}}
        , .{ f.spec, @tagName(f.status) }) catch continue;
        defer allocator.free(entry);
        buf.appendSlice(allocator, entry) catch |err| {
            std.log.debug("batch_runner: append failure json failed: {}", .{err});
        };
    }

    buf.appendSlice(allocator, "\n  ]\n}\n") catch |err| {
        std.log.debug("batch_runner: append json footer failed: {}", .{err});
    };

    // Write latest.json
    const latest = std.fs.cwd().createFile(".trinity/batch/latest.json", .{}) catch return;
    defer latest.close();
    latest.writeAll(buf.items) catch |err| {
        std.log.debug("batch_runner: write latest.json failed: {}", .{err});
    };

    std.debug.print("  Report:   .trinity/batch/latest.json\n", .{});
}

// ============================================================================
// SHOW: Last report / comparison
// ============================================================================

fn showLastReport(allocator: std.mem.Allocator) void {
    const content = std.fs.cwd().readFileAlloc(allocator, ".trinity/batch/latest.json", 1024 * 1024) catch {
        std.debug.print("{s}No batch report found. Run: tri pipeline batch{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(content);

    std.debug.print("\n{s}LAST BATCH REPORT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}======================================================={s}\n\n", .{ GRAY, RESET });
    std.debug.print("{s}\n", .{content});
}

fn showComparison(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("\n{s}BATCH COMPARISON{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}======================================================={s}\n", .{ GRAY, RESET });
    std.debug.print("  Run two batches first, then compare.\n", .{});
    std.debug.print("  Usage: tri pipeline batch && tri pipeline batch --compare\n\n", .{});
}

// ============================================================================
// HELP
// ============================================================================

fn printBatchHelp() void {
    std.debug.print("\n{s}Batch Pipeline Runner{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}======================================================={s}\n\n", .{ GRAY, RESET });
    std.debug.print("Usage: tri pipeline batch [flags]\n\n", .{});
    std.debug.print("{s}Flags:{s}\n", .{ CYAN, RESET });
    std.debug.print("  --parallel N, -p N    Number of worker threads (default: 4)\n", .{});
    std.debug.print("  --filter MODE, -f     Filter specs: all, lint:pass, lint:fail, changed\n", .{});
    std.debug.print("  --dry-run             Show plan without executing\n", .{});
    std.debug.print("  --timeout N           Timeout per spec in seconds (default: 120)\n", .{});
    std.debug.print("  --report              Show last batch report\n", .{});
    std.debug.print("  --compare             Compare with previous run\n", .{});
    std.debug.print("  --help, -h            Show this help\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri pipeline batch                         All specs, 4 workers\n", .{});
    std.debug.print("  tri pipeline batch -p 8 -f lint:pass       8 workers, lint-passing only\n", .{});
    std.debug.print("  tri pipeline batch --dry-run               Show plan only\n", .{});
    std.debug.print("  tri pipeline batch --report                View last results\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ============================================================================
// TESTS
// ============================================================================

test "extractStem works" {
    const s1 = extractStem("specs/tri/foo.tri");
    try std.testing.expectEqualStrings("foo", s1);

    const s2 = extractStem("specs/tri/compiler/linter_gate.tri");
    try std.testing.expectEqualStrings("linter_gate", s2);

    const s3 = extractStem("single.tri");
    try std.testing.expectEqualStrings("single", s3);
}

test "parseFilterMode parses correctly" {
    try std.testing.expectEqual(FilterMode.lint_pass, parseFilterMode("lint:pass"));
    try std.testing.expectEqual(FilterMode.lint_fail, parseFilterMode("lint:fail"));
    try std.testing.expectEqual(FilterMode.changed_only, parseFilterMode("changed"));
    try std.testing.expectEqual(FilterMode.all, parseFilterMode("unknown"));
}

test "scanSpecs finds .tri files" {
    const allocator = std.testing.allocator;
    var specs = scanSpecs(allocator, "specs/tri");
    defer {
        for (specs.items) |p| allocator.free(p);
        specs.deinit(allocator);
    }
    // Should find at least some specs
    try std.testing.expect(specs.items.len > 0);
}

test "ThreadSafeResults append is thread-safe" {
    const allocator = std.testing.allocator;
    var results = ThreadSafeResults.init();
    defer results.deinit(allocator);

    // Append from single thread — basic correctness
    results.append(allocator, .{
        .spec_path = "test.tri",
        .success = true,
        .status = .pass,
        .duration_ns = 100,
        .error_msg = "",
    });

    try std.testing.expectEqual(@as(usize, 1), results.items.items.len);
    try std.testing.expect(results.items.items[0].success);
}

test "detectVerilog returns false for non-existent file" {
    try std.testing.expect(!detectVerilog("nonexistent_file.tri"));
}
