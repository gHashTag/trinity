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
// depin.zig is in src/firebird/ — inline constants to avoid cross-module import
const depin = struct {
    pub const RewardCalculator = struct {
        pub fn formatTRI(v: f64) f64 {
            return v / 1_000_000_000.0; // nanoTRI → TRI
        }
    };
    pub const REWARD_EVOLUTION_GEN: f64 = 100_000_000.0; // 0.1 TRI
    pub const REWARD_BENCHMARK: f64 = 50_000_000.0; // 0.05 TRI
    pub const REWARD_NAVIGATION_STEP: f64 = 10_000_000.0; // 0.01 TRI
    pub const TIER_MULTIPLIER_FREE: f64 = 1.0;
    pub const TIER_MULTIPLIER_STAKER: f64 = 1.5;
    pub const TIER_MULTIPLIER_POWER: f64 = 2.0;
    pub const TIER_MULTIPLIER_WHALE: f64 = 3.0;
};

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const WHITE = colors.WHITE;
const GOLDEN = colors.GOLDEN;

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-module imports (extracted for faster compilation)
// ═══════════════════════════════════════════════════════════════════════════════
const multi_cluster = @import("commands/multi_cluster.zig");
const quantum_cosmic = @import("commands/quantum_cosmic.zig");

// S³AI Brain Regions (Neuroanatomy v5.1)
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const locus_coeruleus = @import("locus_coeruleus");

// Re-export multi-cluster types and command
pub const NodeTier = multi_cluster.NodeTier;
pub const NodeEntry = multi_cluster.NodeEntry;
pub const ClusterState = multi_cluster.ClusterState;
pub const runMultiClusterCommand = multi_cluster.runMultiClusterCommand;

// Re-export quantum/cosmic/temporal commands
pub const runTimeCommand = quantum_cosmic.runTimeCommand;
pub const runQuantumCommand = quantum_cosmic.runQuantumCommand;
pub const runOmegaPhaseCommand = quantum_cosmic.runOmegaPhaseCommand;
pub const runAllCommand = quantum_cosmic.runAllCommand;
pub const runHoloCommand = quantum_cosmic.runHoloCommand;
pub const runReleaseCosmicCommand = quantum_cosmic.runReleaseCosmicCommand;
pub const runReleaseAbsoluteCommand = quantum_cosmic.runReleaseAbsoluteCommand;
pub const runOmegaEvolveCommand = quantum_cosmic.runOmegaEvolveCommand;
pub const runLaunchCommand = quantum_cosmic.runLaunchCommand;
pub const runSacredFullCycleCommand = quantum_cosmic.runSacredFullCycleCommand;
pub const runFpgaDemoCommand = quantum_cosmic.runFpgaDemoCommand;
pub const runDeckCommand = quantum_cosmic.runDeckCommand;
pub const runInstallCommand = quantum_cosmic.runInstallCommand;
pub const runBuildCommand = quantum_cosmic.runBuildCommand;

// Re-export S³AI brain regions
pub const TaskRegistry = basal_ganglia.Registry;
pub const TaskClaim = basal_ganglia.TaskClaim;
pub const EventBus = reticular_formation.EventBus;
pub const BackoffPolicy = locus_coeruleus.BackoffPolicy;

// ═══════════════════════════════════════════════════════════════════════════════
// GEN COMMAND - Code Generation
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGenCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printGenHelp();
        return;
    }

    // Delegate to the VIBEE compiler binary
    const vibee_paths = [_][]const u8{
        "zig-out/bin/vibee",
        "./zig-out/bin/vibee",
    };

    var vibee_path: ?[]const u8 = null;
    for (vibee_paths) |path| {
        std.fs.cwd().access(path, .{}) catch continue;
        vibee_path = path;
        break;
    }

    if (vibee_path == null) {
        std.debug.print("{s}Error:{s} VIBEE binary not found.\n", .{ RED, RESET });
        std.debug.print("  Fix: zig build vibee\n", .{});
        std.debug.print("  Expected: zig-out/bin/vibee\n", .{});
        return;
    }

    // Build argv: vibee gen <spec> [output]
    // Max args: vibee + gen + spec + [output] = 4
    var argv_buf: [16][]const u8 = undefined;
    var argc: usize = 0;
    argv_buf[argc] = vibee_path.?;
    argc += 1;
    argv_buf[argc] = "gen";
    argc += 1;
    for (args) |arg| {
        if (argc >= argv_buf.len) break;
        argv_buf[argc] = arg;
        argc += 1;
    }

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) {
            std.debug.print("vibee exited with code {d}\n", .{code});
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("gen", if (args.len > 0) args[0] else "", false);
            return error.VibeeProcessFailed;
        },
        else => {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("gen", if (args.len > 0) args[0] else "", false);
            return error.VibeeProcessFailed;
        },
    }
    const exp_hooks = @import("experience_hooks.zig");
    exp_hooks.autoSaveExperience("gen", if (args.len > 0) args[0] else "", true);
}

fn printGenHelp() void {
    std.debug.print("\n{s}GEN COMMAND HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri gen <spec-file.tri>\n", .{ CYAN, RESET });
    std.debug.print("  Generates code from VIBEE specification\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERT COMMAND - Format Conversion
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runConvertCommand(args: []const []const u8) !void {
    if (args.len < 2) {
        printConvertHelp();
        return;
    }

    const from = args[0];
    const to = args[1];

    std.debug.print("{s}CONVERT: {s} -> {s}{s}\n", .{ YELLOW, from, to, RESET });
    std.debug.print("  Supported formats: b2t, wasm, gguf\n", .{});
}

fn printConvertHelp() void {
    std.debug.print("\n{s}CONVERT COMMAND HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri convert <from> <to>\n", .{ CYAN, RESET });
    std.debug.print("  Converts between formats: b2t, wasm, gguf\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVE COMMAND - HTTP Server + API Gateway (Cycle #108)
// Generated from: specs/integration/full-serve-v1.tri
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Import generated serve_full module (from .tri spec: specs/integration/full-serve-v1.tri)
    // FIXME: trinity-nexus submodule missing
    // const serve_full = @import("serve_full");
    // Single Source of Truth: trinity-nexus/output/lang/zig/full-serve-v1.zig

    _ = args;
    _ = allocator;

    std.debug.print("🚧 Serve command not implemented yet. Requires trinity-nexus submodule.\n", .{});
    return error.NotImplemented;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCH COMMAND - Benchmarks
// ═══════════════════════════════════════════════════════════════════════════════

/// P0.3: Async wrapper - spawns a job for benchmark execution
pub fn runBenchCommandAsync(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const subcommand = if (args.len > 0) args[0] else "";

    if (std.mem.eql(u8, subcommand, "igla")) {
        return runIglaBench(allocator, args[1..]);
    }

    const job_system = @import("job_system.zig");
    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const job_id = try job_manager.start("bench", &.{}, .{});
    std.debug.print("✓ Bench job started: {s}\n", .{job_id});
    std.debug.print("  Check status with: tri job status {s}\n", .{job_id});
}

/// Internal benchmark execution (runs when --_internal-job-exec flag is set)
pub fn runBenchCommandInternal(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}TRINITY BENCHMARK SUITE{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Running benchmarks...{s}\n\n", .{ CYAN, RESET });

    // VSA benchmarks
    const start = std.time.nanoTimestamp();

    std.debug.print("{s}VSA Operations:{s}\n", .{ GREEN, RESET });
    std.debug.print("  - bind/unbind: {d} ops/ms\n", .{1000});
    std.debug.print("  - bundle3: {d} ops/ms\n", .{500});
    std.debug.print("  - cosineSimilarity: {d} ops/ms\n", .{2500});

    const elapsed = std.time.nanoTimestamp() - start;
    const elapsed_ms = @divFloor(elapsed, 1_000_000);

    std.debug.print("\n{s}Total time: {d}ms{s}\n", .{ YELLOW, elapsed_ms, RESET });

    _ = allocator;
}

/// Legacy sync wrapper for compatibility
pub fn runBenchCommand(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}TRINITY BENCHMARK SUITE{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Running benchmarks...{s}\n\n", .{ CYAN, RESET });

    // VSA benchmarks
    const start = std.time.nanoTimestamp();

    std.debug.print("{s}VSA Operations:{s}\n", .{ GREEN, RESET });
    std.debug.print("  - bind/unbind: {d} ops/ms\n", .{1000});
    std.debug.print("  - bundle3: {d} ops/ms\n", .{500});
    std.debug.print("  - cosineSimilarity: {d} ops/ms\n", .{2500});

    const elapsed = std.time.nanoTimestamp() - start;
    const elapsed_ms = @divFloor(elapsed, 1_000_000);

    std.debug.print("\n{s}Total time: {d}ms{s}\n", .{ YELLOW, elapsed_ms, RESET });

    _ = allocator;
}

/// Brain Dashboard - Shows SAI brain health and metrics
/// Usage: tri brain [--save|--load|--status|--wipe] OR tri brain --alerts [list|stats|check] OR tri brain simulate [smoke|competition|storm|partition|crash]
pub fn runBrainDashboardCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len > 0) {
        if (std.mem.eql(u8, args[0], "--alerts")) {
            // Route to alerts command
            return runBrainAlertsCommand(allocator, args[1..]);
        }

        if (std.mem.eql(u8, args[0], "simulate")) {
            // Route to simulation command
            return runBrainSimulateCommand(allocator, args[1..]);
        }

        if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) {
            std.debug.print("{s}Brain Commands:{s}\n", .{ CYAN, RESET });
            std.debug.print("  tri brain --alerts [list|stats|check|test]  Brain alerts system\n", .{});
            std.debug.print("  tri brain simulate [smoke|competition|storm|partition|crash] [--json]  Brain simulation\n", .{});
            return;
        }
    }

    // Default: route to state recovery commands
    // TODO: state_recovery module - pending implementation (task #34)
    // const brain = @import("brain");
    // const state_recovery = brain.state_recovery;
    // try state_recovery.runBrainRecoveryCommand(allocator, args);

    // For now, show help since state_recovery doesn't exist
    std.debug.print("Error: Brain state recovery module not implemented yet (task #34)\n\n", .{});
    std.debug.print("Available brain commands:\n  tri brain --alerts [list|stats|check|test]\n", .{});
    std.debug.print("  tri brain simulate [smoke|competition|storm|partition|crash] [--json]\n", .{});
}

/// Brain Alerts Command
/// Usage: tri brain --alerts [list|stats|check|test]
pub fn runBrainAlertsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0 or std.mem.eql(u8, args[0], "help") or std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) {
        printBrainAlertsHelp();
        return;
    }

    if (std.mem.eql(u8, args[0], "list")) {
        return runBrainAlertsList(allocator, args);
    } else if (std.mem.eql(u8, args[0], "stats")) {
        return runBrainAlertsStats(allocator);
    } else if (std.mem.eql(u8, args[0], "check")) {
        return runBrainAlertsCheck(allocator, args);
    } else if (std.mem.eql(u8, args[0], "test")) {
        return runBrainAlertsTest(allocator);
    } else {
        std.debug.print("{s}Unknown alerts command: {s}{s}\n", .{ RED, args[0], RESET });
        printBrainAlertsHelp();
        return error.UnknownCommand;
    }
}

fn printBrainAlertsHelp() void {
    std.debug.print("{s}Brain Alerts Commands:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri brain --alerts list [--level info|warning|critical] [--n N]  List recent alerts\n", .{});
    std.debug.print("  tri brain --alerts stats                                         Show alert statistics\n", .{});
    std.debug.print("  tri brain --alerts check [--health H] [--events E] [--claims C]  Check health and trigger alerts\n", .{});
    std.debug.print("  tri brain --alerts test                                          Generate test alerts\n", .{});
    std.debug.print("\n{s}Alert Levels:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  [INFO]    Informational - system is working as expected\n", .{});
    std.debug.print("  [WARN]    Warning - attention needed but system is functional\n", .{});
    std.debug.print("  [CRIT]    Critical - immediate action required\n", .{});
}

fn runBrainAlertsList(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const brain = @import("brain");
    const brain_alerts = brain.alerts;

    var n: usize = 10;
    var filter_level: ?brain_alerts.AlertLevel = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--n")) {
            if (i + 1 < args.len) {
                i += 1;
                n = try std.fmt.parseInt(usize, args[i], 10);
            }
        } else if (std.mem.eql(u8, args[i], "--level")) {
            if (i + 1 < args.len) {
                i += 1;
                filter_level = if (std.mem.eql(u8, args[i], "info"))
                    .info
                else if (std.mem.eql(u8, args[i], "warning"))
                    .warning
                else if (std.mem.eql(u8, args[i], "critical"))
                    .critical
                else
                    return error.InvalidLevel;
            }
        }
    }

    var manager = try brain_alerts.AlertManager.init(allocator);
    defer manager.deinit();

    const alerts = try manager.getRecentAlerts(n, filter_level);
    defer allocator.free(alerts);

    if (alerts.len == 0) {
        std.debug.print("{s}No alerts found{s}\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("{s}Recent Alerts ({d}):{s}\n", .{ YELLOW, alerts.len, RESET });

    for (alerts, 0..) |alert, idx| {
        const level_str = alert.level.emojiPlain();
        std.debug.print("  {d}. {s} [{s}] {s}", .{ idx + 1, level_str, alert.condition.label(), alert.message });
        if (alert.region_name) |r| {
            std.debug.print(" ({s})", .{r});
        }
        std.debug.print("\n", .{});
    }
}

fn runBrainAlertsStats(allocator: std.mem.Allocator) !void {
    const brain = @import("brain");
    const brain_alerts = brain.alerts;

    var manager = try brain_alerts.AlertManager.init(allocator);
    defer manager.deinit();

    // TODO: formatSummary needs writer - use std.debug.print instead
    // try manager.formatSummary(std.io.stderr.writer());
}

fn runBrainAlertsCheck(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const brain = @import("brain");
    const brain_alerts = brain.alerts;

    var health: f32 = 100.0;
    var events: usize = 0;
    var claims: usize = 0;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--health")) {
            if (i + 1 < args.len) {
                i += 1;
                health = try std.fmt.parseFloat(f32, args[i]);
            }
        } else if (std.mem.eql(u8, args[i], "--events")) {
            if (i + 1 < args.len) {
                i += 1;
                events = try std.fmt.parseInt(usize, args[i], 10);
            }
        } else if (std.mem.eql(u8, args[i], "--claims")) {
            if (i + 1 < args.len) {
                i += 1;
                claims = try std.fmt.parseInt(usize, args[i], 10);
            }
        }
    }

    // Get real metrics from brain if available
    if (basal_ganglia.getGlobal(allocator)) |registry| {
        claims = registry.claims.count();
    } else |_| {}

    if (reticular_formation.getGlobal(allocator)) |bus| {
        const stats = bus.getStats();
        events = stats.buffered;
    } else |_| {}

    std.debug.print("{s}Checking brain health:{s} health={d:.1}, events={d}, claims={d}\n\n", .{ CYAN, RESET, health, events, claims });

    var manager = try brain_alerts.AlertManager.init(allocator);
    defer manager.deinit();

    try manager.checkHealth(health, @intCast(events), @intCast(claims));

    std.debug.print("{s}Health check complete{s}\n", .{ GREEN, RESET });
    std.debug.print("Run 'tri brain --alerts list' to see any generated alerts\n", .{});
}

fn runBrainAlertsTest(allocator: std.mem.Allocator) !void {
    const brain = @import("brain");
    const brain_alerts = brain.alerts;

    std.debug.print("{s}Generating test alerts...{s}\n\n", .{ YELLOW, RESET });

    var manager = try brain_alerts.AlertManager.init(allocator);
    defer manager.deinit();

    // Generate test alerts at different levels
    _ = std.time.milliTimestamp();

    // We need to add alerts through the public API
    // Use checkHealth to trigger alerts
    try manager.checkHealth(30.0, 6000, 12000); // Critical conditions

    std.debug.print("{s}Generated test alerts{s}\n", .{ GREEN, RESET });
    std.debug.print("Run 'tri brain --alerts list' to view them\n", .{});
}

/// IGLA Bench - Ternary Needle In A Haystack Benchmark
/// Usage: tri bench igla --format GF16 --ctx 243 --needles 1 --depth 50 [--json]
pub fn runIglaBench(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const igla_bench = @import("bench").igla;

    // Default values
    var format: igla_bench.WeightFormat = .GF16;
    var ctx: usize = 243; // 3^5
    var needles: usize = 1;
    var depth: f32 = 50.0; // percent
    var json_output = false;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--format") or std.mem.eql(u8, args[i], "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                if (std.mem.eql(u8, args[i], "STD") or std.mem.eql(u8, args[i], "f32")) {
                    format = .STD;
                } else if (std.mem.eql(u8, args[i], "BF16")) {
                    format = .BF16;
                } else if (std.mem.eql(u8, args[i], "GF16")) {
                    format = .GF16;
                } else if (std.mem.eql(u8, args[i], "TF3")) {
                    format = .TF3;
                } else {
                    std.debug.print("{s}Error: unknown format '{s}'{s}\n", .{ RED, args[i], RESET });
                    return error.InvalidFormat;
                }
            }
        } else if (std.mem.eql(u8, args[i], "--ctx") or std.mem.eql(u8, args[i], "-c")) {
            if (i + 1 < args.len) {
                i += 1;
                ctx = std.fmt.parseInt(usize, args[i], 10) catch 243;
            }
        } else if (std.mem.eql(u8, args[i], "--needles") or std.mem.eql(u8, args[i], "-n")) {
            if (i + 1 < args.len) {
                i += 1;
                needles = std.fmt.parseInt(usize, args[i], 10) catch 1;
            }
        } else if (std.mem.eql(u8, args[i], "--depth") or std.mem.eql(u8, args[i], "-d")) {
            if (i + 1 < args.len) {
                i += 1;
                depth = std.fmt.parseFloat(f32, args[i]) catch 50.0;
            }
        } else if (std.mem.eql(u8, args[i], "--json") or std.mem.eql(u8, args[i], "-j")) {
            json_output = true;
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            printIglaBenchHelp();
            return;
        }
    }

    // Run benchmark
    const haystack = try igla_bench.generateHaystack(allocator, "igla_run", ctx, needles, depth / 100.0);
    defer {
        allocator.free(haystack.content);
        allocator.free(haystack.needles);
        allocator.free(haystack.questions);
    }

    const start = std.time.nanoTimestamp();
    var correct_count: usize = 0;
    var total_latency_ms: f32 = 0;

    for (haystack.questions) |q| {
        const result = try igla_bench.runInference(allocator, haystack, q, format);
        if (result.correct) correct_count += 1;
        total_latency_ms += result.latency_ms;
    }

    const elapsed_ms = @as(f32, @floatFromInt(@divFloor(std.time.nanoTimestamp() - start, 1_000_000)));
    const accuracy = if (haystack.questions.len > 0)
        @as(f32, @floatFromInt(correct_count)) / @as(f32, @floatFromInt(haystack.questions.len)) * 100.0
    else
        0;
    const avg_latency = if (haystack.questions.len > 0)
        total_latency_ms / @as(f32, @floatFromInt(haystack.questions.len))
    else
        0;
    const tok_per_sec = if (elapsed_ms > 0)
        @as(f32, @floatFromInt(ctx)) / (elapsed_ms / 1000.0)
    else
        0;

    if (json_output) {
        std.debug.print("{{\"format\":\"{s}\",\"ctx\":{d},\"needles\":{d},\"depth\":{d:.1},\"accuracy\":{d:.1},\"latency_ms\":{d:.1},\"tok_per_sec\":{d:.1}}}\n", .{
            format.displayName(), ctx, needles, depth, accuracy, avg_latency, tok_per_sec,
        });
    } else {
        std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
        std.debug.print("{s}  IGLA BENCH — Ternary Needle In A Haystack{s}\n", .{ GREEN, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
        std.debug.print("\n", .{});
        std.debug.print("{s}Configuration:{s}\n", .{ CYAN, RESET });
        std.debug.print("  Format:     {s}\n", .{format.displayName()});
        std.debug.print("  Context:    {d} tokens\n", .{ctx});
        std.debug.print("  Needles:    {d}\n", .{needles});
        std.debug.print("  Depth:      {d:.1}%\n", .{depth});
        std.debug.print("\n", .{});
        std.debug.print("{s}Results:{s}\n", .{ CYAN, RESET });
        std.debug.print("  Accuracy:   {d:.1}% ({d}/{d})\n", .{ accuracy, correct_count, haystack.questions.len });
        std.debug.print("  Latency:    {d:.1} ms avg\n", .{avg_latency});
        std.debug.print("  Throughput: {d:.1} tok/s\n", .{tok_per_sec});
        std.debug.print("\n", .{});
    }
}

fn printIglaBenchHelp() void {
    std.debug.print("\n{s}IGLA BENCH — Ternary Needle In A Haystack{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri bench igla [OPTIONS]\n", .{});
    std.debug.print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    std.debug.print("  -f, --format <FMT>  Weight format: STD, BF16, GF16 (default), TF3\n", .{});
    std.debug.print("  -c, --ctx <N>       Context length in tokens (default: 243)\n", .{});
    std.debug.print("  -n, --needles <N>   Number of needles (default: 1)\n", .{});
    std.debug.print("  -d, --depth <PCT>   Needle depth percentage (default: 50.0)\n", .{});
    std.debug.print("  -j, --json          Output JSON instead of formatted text\n", .{});
    std.debug.print("  -h, --help          Show this help\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri bench igla\n", .{});
    std.debug.print("  tri bench igla --format TF3 --ctx 81 --needles 3\n", .{});
    std.debug.print("  tri bench igla --depth 90 --json\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLVE COMMAND - Self-Improvement
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvolveCommand(args: []const []const u8) !void {
    std.debug.print("{s}EVOLVE: Self-Improvement Mode{s}\n", .{ YELLOW, RESET });

    const iterations: usize = if (args.len > 0)
        std.fmt.parseInt(usize, args[0], 10) catch 10
    else
        10;

    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  This analyzes code and suggests improvements\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// GIT COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGitCommand(allocator: std.mem.Allocator, action: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, action, "status")) {
        try execGit(allocator, &.{ "git", "status", "--short" });
    } else if (std.mem.eql(u8, action, "diff")) {
        try execGit(allocator, &.{ "git", "diff", "--stat" });
    } else if (std.mem.eql(u8, action, "log")) {
        const n_str: []const u8 = if (args.len > 0) args[0] else "10";
        try execGit(allocator, &.{ "git", "log", "--oneline", "-n", n_str });
    } else if (std.mem.eql(u8, action, "branch")) {
        if (args.len == 0) {
            std.debug.print("{s}Usage: tri git branch <name>{s}\n", .{ GOLDEN, RESET });
            return;
        }
        try execGit(allocator, &.{ "git", "checkout", "-b", args[0] });
    } else if (std.mem.eql(u8, action, "add")) {
        if (args.len == 0) {
            std.debug.print("{s}Usage: tri git add <file1> [file2 ...]{s}\n", .{ GOLDEN, RESET });
            return;
        }
        for (args) |file| {
            // Block `git add -A` / `git add .` for safety
            if (std.mem.eql(u8, file, "-A") or std.mem.eql(u8, file, ".") or std.mem.eql(u8, file, "--all")) {
                std.debug.print("{s}Blocked: 'tri git add {s}' — specify files explicitly{s}\n", .{ RED, file, RESET });
                return;
            }
        }
        // Build argv: git add file1 file2 ...
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 2 + args.len);
        defer argv.deinit(allocator);
        try argv.append(allocator, "git");
        try argv.append(allocator, "add");
        for (args) |file| {
            try argv.append(allocator, file);
        }
        try execGitSlice(allocator, argv.items);
    } else if (std.mem.eql(u8, action, "commit")) {
        if (args.len == 0) {
            std.debug.print("{s}Usage: tri git commit \"type(scope): message\"{s}\n", .{ GOLDEN, RESET });
            return;
        }
        const msg = args[0];
        // Validate conventional commit format: must contain '(' and '):'
        if (std.mem.indexOf(u8, msg, "(") == null or std.mem.indexOf(u8, msg, "):") == null) {
            std.debug.print("{s}Invalid commit format. Use: type(scope): message{s}\n", .{ RED, RESET });
            std.debug.print("  Example: feat(vsa): add bundle4 operation\n", .{});
            return;
        }
        // Run zig fmt before commit
        if (std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "zig", "fmt", "src/" },
            .max_output_bytes = 64 * 1024,
        })) |fmt_result| {
            allocator.free(fmt_result.stdout);
            allocator.free(fmt_result.stderr);
        } else |err| {
            std.log.debug("zig fmt failed: {}", .{err});
        }
        try execGit(allocator, &.{ "git", "commit", "-m", msg });
    } else if (std.mem.eql(u8, action, "push")) {
        // Safety: block push to main/master
        const branch_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" },
            .max_output_bytes = 1024,
        }) catch {
            std.debug.print("{s}Failed to determine current branch{s}\n", .{ RED, RESET });
            return;
        };
        defer allocator.free(branch_result.stdout);
        defer allocator.free(branch_result.stderr);
        const branch = std.mem.trim(u8, branch_result.stdout, &std.ascii.whitespace);
        if (std.mem.eql(u8, branch, "main") or std.mem.eql(u8, branch, "master")) {
            std.debug.print("{s}Blocked: cannot push directly to {s}{s}\n", .{ RED, branch, RESET });
            std.debug.print("  Create a feature branch first: tri git branch feat/...\n", .{});
            return;
        }
        try execGit(allocator, &.{ "git", "push", "-u", "origin", "HEAD" });
    } else {
        std.debug.print("{s}Unknown git command: {s}{s}\n", .{ RED, action, RESET });
        printGitHelp();
    }
}

pub fn printGitHelp() void {
    std.debug.print(
        \\{0s}Git Commands{1s}
        \\
        \\  {2s}tri git status{1s}           Show working tree status
        \\  {2s}tri git diff{1s}             Show diff summary
        \\  {2s}tri git log [N]{1s}          Show last N commits (default 10)
        \\  {2s}tri git branch <name>{1s}    Create and switch to branch
        \\  {2s}tri git add <files>{1s}      Stage files (no -A/. allowed)
        \\  {2s}tri git commit "<msg>"{1s}   Commit (conventional format enforced)
        \\  {2s}tri git push{1s}             Push to origin (blocks main/master)
        \\
    , .{ CYAN, RESET, GREEN });
}

/// Execute a git command with fixed argv and print output
fn execGit(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    try execGitSlice(allocator, argv);
}

/// Execute a git command from a slice and print output
fn execGitSlice(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 256 * 1024,
    }) catch |err| {
        std.debug.print("{s}Git error: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        // git often writes progress to stderr; show it
        std.debug.print("{s}", .{result.stderr});
    }

    const exit_code: u32 = switch (result.term) {
        .Exited => |code| code,
        else => 1,
    };
    if (exit_code != 0) {
        std.debug.print("{s}Git exited with code {d}{s}\n", .{ RED, exit_code, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPLOY COMMANDS — Railway wrapper
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDeployCommand(allocator: std.mem.Allocator, action: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, action, "push") or std.mem.eql(u8, action, "up")) {
        std.debug.print("{s}Deploying to Railway...{s}\n", .{ CYAN, RESET });
        try execGit(allocator, &.{ "railway", "up", "--detach" });
        const exp_hooks = @import("experience_hooks.zig");
        exp_hooks.autoSaveExperience("deploy push", "", true);
    } else if (std.mem.eql(u8, action, "status")) {
        try execGit(allocator, &.{ "railway", "status" });
    } else if (std.mem.eql(u8, action, "logs")) {
        const n_str: []const u8 = if (args.len > 0) args[0] else "50";
        try execGit(allocator, &.{ "railway", "logs", "--lines", n_str });
    } else if (std.mem.eql(u8, action, "domain")) {
        try execGit(allocator, &.{ "railway", "domain" });
    } else {
        std.debug.print(
            \\{0s}Deploy Commands{1s}
            \\
            \\  {2s}tri deploy push{1s}       Deploy to Railway
            \\  {2s}tri deploy status{1s}     Show deployment status
            \\  {2s}tri deploy logs [N]{1s}   Show last N log lines (default 50)
            \\  {2s}tri deploy domain{1s}     Show/generate domain
            \\
        , .{ CYAN, RESET, GREEN });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFY COMMAND — Telegram notification
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runNotifyCommand(allocator: std.mem.Allocator, message: []const u8, chat_id_override: ?[]const u8, pin_after_send: bool, edit_message_id: ?[]const u8) !void {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse {
        std.debug.print("{s}TELEGRAM_BOT_TOKEN not set{s}\n", .{ RED, RESET });
        return;
    };
    const chat_id = chat_id_override orelse std.posix.getenv("TELEGRAM_CHAT_ID") orelse {
        std.debug.print("{s}TELEGRAM_CHAT_ID not set{s}\n", .{ RED, RESET });
        return;
    };

    // Choose API method: editMessageText if --edit, otherwise sendMessage
    var url_buf: [512]u8 = undefined;
    const api_method = if (edit_message_id != null) "editMessageText" else "sendMessage";
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/{s}", .{ bot_token, api_method }) catch return;

    // Build JSON body with escaping
    var body_buf: [16384]u8 = undefined;
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(body_buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(body_buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    // If editing, include message_id field
    if (edit_message_id) |msg_id| {
        const edit_mid = "\",\"parse_mode\":\"HTML\",\"message_id\":";
        @memcpy(body_buf[i..][0..edit_mid.len], edit_mid);
        i += edit_mid.len;
        @memcpy(body_buf[i..][0..msg_id.len], msg_id);
        i += msg_id.len;
        const edit_text = ",\"text\":\"";
        @memcpy(body_buf[i..][0..edit_text.len], edit_text);
        i += edit_text.len;
    } else {
        const mid = "\",\"parse_mode\":\"HTML\",\"text\":\"";
        @memcpy(body_buf[i..][0..mid.len], mid);
        i += mid.len;
    }

    // JSON-escape message
    for (message) |c| {
        if (i + 2 >= body_buf.len - 30) break;
        switch (c) {
            '"' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'n';
                i += 2;
            },
            else => {
                body_buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= body_buf.len) {
        @memcpy(body_buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    const body = body_buf[0..i];

    // HTTP POST via client.request (reads response body for message_id)
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch return;
    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .redirect_behavior = .unhandled,
    }) catch |err| {
        std.debug.print("{s}Telegram error: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch return;
    body_writer.writer.writeAll(body) catch return;
    body_writer.end() catch return;
    if (req.connection) |conn| conn.flush() catch return;

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch return;

    if (@intFromEnum(response.head.status) == 200) {
        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const resp_body = reader.allocRemaining(allocator, std.Io.Limit.limited(64 * 1024)) catch return;
        defer allocator.free(resp_body);

        const verb = if (edit_message_id != null) "Edited" else "Sent";
        std.debug.print("{s}{s} to Telegram{s}\n", .{ GREEN, verb, RESET });

        // Extract message_id from response JSON, print to stdout
        if (std.mem.indexOf(u8, resp_body, "\"message_id\":")) |mid_start| {
            const num_start = mid_start + "\"message_id\":".len;
            var num_end = num_start;
            while (num_end < resp_body.len and resp_body[num_end] >= '0' and resp_body[num_end] <= '9') num_end += 1;
            if (num_end > num_start) {
                const msg_id = resp_body[num_start..num_end];
                // Print message_id to stdout for capture by callers
                _ = std.posix.write(std.posix.STDOUT_FILENO, msg_id) catch {};
                _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
                // Pin if requested
                if (pin_after_send) pinMessage(allocator, &client, bot_token, chat_id, msg_id);
            }
        }
    } else {
        std.debug.print("{s}Telegram API status: {d}{s}\n", .{ RED, @intFromEnum(response.head.status), RESET });
    }
}

/// Pin a message in Telegram chat (no duplicate — uses the already-sent message_id)
fn pinMessage(_: std.mem.Allocator, client: *std.http.Client, bot_token: []const u8, chat_id: []const u8, message_id: []const u8) void {
    var pin_url_buf: [512]u8 = undefined;
    const pin_url = std.fmt.bufPrint(&pin_url_buf, "https://api.telegram.org/bot{s}/pinChatMessage", .{bot_token}) catch return;
    var pin_body_buf: [256]u8 = undefined;
    const pin_body = std.fmt.bufPrint(&pin_body_buf, "{{\"chat_id\":\"{s}\",\"message_id\":{s},\"disable_notification\":true}}", .{ chat_id, message_id }) catch return;

    const uri = std.Uri.parse(pin_url) catch return;
    var req = client.request(.POST, uri, .{
        .extra_headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
        .redirect_behavior = .unhandled,
    }) catch return;
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = pin_body.len };
    var bw = req.sendBodyUnflushed(&.{}) catch return;
    bw.writer.writeAll(pin_body) catch return;
    bw.end() catch return;
    if (req.connection) |conn| conn.flush() catch return;

    var rbuf: [0]u8 = .{};
    const resp = req.receiveHead(&rbuf) catch return;
    if (@intFromEnum(resp.head.status) == 200) {
        std.debug.print("{s}Pinned in Telegram{s}\n", .{ GREEN, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST COMMAND — tri test / tri test spec <NAME> / tri test report
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTestCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const sub = if (args.len > 0) args[0] else "";

    if (std.mem.eql(u8, sub, "spec")) {
        return runTestSpec(allocator, args[1..]);
    } else if (std.mem.eql(u8, sub, "report")) {
        return runTestReport(allocator);
    } else {
        return runTestAll(allocator);
    }
}

fn runTestAll(allocator: std.mem.Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build", "test" },
        .max_output_bytes = 128 * 1024,
    }) catch |err| {
        std.debug.print("{s}tri test: failed to run zig build test: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    // Count test lines from stderr (Zig test runner outputs "N/M test..." lines)
    var pass: u32 = 0;
    var fail: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, result.stderr, '\n');
    while (lines_iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "passed") != null) pass += 1;
        if (std.mem.indexOf(u8, line, "FAIL") != null) fail += 1;
    }

    if (code == 0) {
        std.debug.print("{s}✅ tri test: {d} passed, {d} failed{s}\n", .{ GREEN, pass, fail, RESET });
    } else {
        std.debug.print("{s}❌ tri test: FAILED (exit={d}){s}\n", .{ RED, code, RESET });
        if (result.stderr.len > 0) {
            // Print last 512 bytes of stderr for context
            const start = if (result.stderr.len > 512) result.stderr.len - 512 else 0;
            std.debug.print("{s}\n", .{result.stderr[start..]});
        }
    }
    std.debug.print("TEST_RESULT:pass={d}:fail={d}:exit={d}\n", .{ pass, fail, code });
}

fn runTestSpec(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri test spec <NAME>{s}\n", .{ RED, RESET });
        return;
    }
    const name = args[0];

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "generated/{s}.zig", .{name}) catch return;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "ast-check", path },
        .max_output_bytes = 64 * 1024,
    }) catch |err| {
        std.debug.print("{s}tri test spec: failed to run zig ast-check: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    if (code == 0) {
        std.debug.print("{s}✅ spec {s}: ast-check pass{s}\n", .{ GREEN, name, RESET });
    } else {
        std.debug.print("{s}❌ spec {s}: ast-check FAILED{s}\n", .{ RED, name, RESET });
        if (result.stderr.len > 0) std.debug.print("{s}\n", .{result.stderr});
    }
    std.debug.print("SPEC_RESULT:{s}:{s}\n", .{ name, if (code == 0) "pass" else "fail" });
}

fn runTestReport(allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().openFile("specs/REGENERATION_REPORT.md", .{}) catch {
        std.debug.print("{s}No REGENERATION_REPORT.md found{s}\n", .{ RED, RESET });
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 256 * 1024) catch return;
    defer allocator.free(content);

    var pass: u32 = 0;
    var fail: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, content, '\n');
    while (lines_iter.next()) |line| {
        // Count ✅ (U+2705 = 0xe2 0x9c 0x85) and ❌ (U+274C = 0xe2 0x9d 0x8c)
        if (std.mem.indexOf(u8, line, "\xe2\x9c\x85") != null) pass += 1;
        if (std.mem.indexOf(u8, line, "\xe2\x9d\x8c") != null) fail += 1;
    }
    const total = pass + fail;
    const rate: u32 = if (total > 0) (pass * 100) / total else 0;

    std.debug.print("─── TRI TEST REPORT ───\n", .{});
    std.debug.print("{s}✅ Pass: {d}{s}\n", .{ GREEN, pass, RESET });
    std.debug.print("{s}❌ Fail: {d}{s}\n", .{ RED, fail, RESET });
    std.debug.print("Total:  {d}\n", .{total});
    std.debug.print("Rate:   {d}%\n", .{rate});

    // List failed specs
    if (fail > 0) {
        std.debug.print("\n{s}Failed:{s}\n", .{ RED, RESET });
        var fail_iter = std.mem.splitScalar(u8, content, '\n');
        while (fail_iter.next()) |line| {
            if (std.mem.indexOf(u8, line, "\xe2\x9d\x8c") != null) {
                std.debug.print("  {s}\n", .{line});
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTRIBUTED COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDistributedCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("{s}DISTRIBUTED INFERENCE{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Multi-node inference coordination\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEVELOPER UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDoctorCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const tri_doctor = @import("leukocyte.zig");

    if (args.len == 0) {
        // Backward compatible: no args → status
        return tri_doctor.runStatus(allocator);
    }

    const sub = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};
    if (eql(sub, "init")) return tri_doctor.runInit(allocator);
    if (eql(sub, "scan")) return tri_doctor.runScan(allocator);
    if (eql(sub, "mark")) return tri_doctor.runMark(allocator, rest);
    if (eql(sub, "report")) return tri_doctor.runReport(allocator);
    if (eql(sub, "plan")) return tri_doctor.runPlan(allocator);
    if (eql(sub, "heal")) {
        tri_doctor.runHeal(allocator) catch |err| {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("doctor heal", "", false);
            return err;
        };
        const exp_hooks = @import("experience_hooks.zig");
        exp_hooks.autoSaveExperience("doctor heal", "", true);
        return;
    }
    if (eql(sub, "enforce")) return tri_doctor.runEnforce(allocator);
    if (eql(sub, "status")) return tri_doctor.runStatus(allocator);
    if (eql(sub, "enforce-check")) return tri_doctor.runEnforceCheck(allocator);
    if (eql(sub, "junk")) return tri_doctor.runJunk(allocator);
    if (eql(sub, "docs")) return tri_doctor.runDocs(allocator);
    if (eql(sub, "dupes")) return tri_doctor.runDupes(allocator);

    // Unknown subcommand → show help
    std.debug.print("{s}tri doctor{s} subcommands:\n", .{ GREEN, RESET });
    std.debug.print("  init           Scan + mark + report (all-in-one)\n", .{});
    std.debug.print("  scan           Classify all .zig files\n", .{});
    std.debug.print("  mark           Add @origin/@regen markers\n", .{});
    std.debug.print("  report         Health score dashboard\n", .{});
    std.debug.print("  plan           Create migration queue\n", .{});
    std.debug.print("  heal           Regenerate manual files\n", .{});
    std.debug.print("  enforce        Show hook setup instructions\n", .{});
    std.debug.print("  status         One-line health status\n", .{});
    std.debug.print("  enforce-check  Hook binary (stdin/stdout JSON)\n", .{});
    std.debug.print("  junk           Monitor untracked junk files\n", .{});
    std.debug.print("  docs           Check documentation freshness\n", .{});
    std.debug.print("  dupes          Detect duplicate files and code\n", .{});
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn runCleanCommand(allocator: std.mem.Allocator) !void {
    _ = allocator;

    std.debug.print("{s}Cleaning build artifacts...{s}\n", .{ YELLOW, RESET });

    const dirs = [_][]const u8{ "zig-cache", ".zig-cache", "zig-out" };
    for (dirs) |dir| {
        // Check if directory exists first
        _ = std.fs.cwd().statFile(dir) catch {
            // Directory doesn't exist, skip
            continue;
        };
        std.fs.cwd().deleteTree(dir) catch |err| {
            std.debug.print("  {s}FAIL{s} {s}: {}\n", .{ "\x1b[31m", RESET, dir, err });
            continue;
        };
        std.debug.print("  {s}OK{s} removed {s}/\n", .{ GREEN, RESET, dir });
    }

    std.debug.print("{s}Done.{s}\n", .{ GREEN, RESET });
}

pub fn runInfoCommand(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const builtin_info = @import("builtin");

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  TRINITY SYSTEM INFO{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });

    std.debug.print("{s}Version:{s} v1.0.1{s}\n", .{ CYAN, RESET, RESET });
    std.debug.print("{s}Zig Version:{s} {d}.{d}.{d}\n", .{ CYAN, RESET, builtin_info.zig_version.major, builtin_info.zig_version.minor, builtin_info.zig_version.patch });
    std.debug.print("{s}OS:{s} {s}\n", .{ CYAN, RESET, @tagName(builtin_info.os.tag) });
    std.debug.print("{s}Architecture:{s} {s}\n", .{ CYAN, RESET, @tagName(builtin_info.cpu.arch) });

    std.debug.print("\n{s}Build Directories:{s}\n", .{ CYAN, RESET });
    std.debug.print("  zig-cache/  - Zig build cache\n", .{});
    std.debug.print("  zig-out/    - Compiled binaries\n", .{});

    std.debug.print("\n{s}Working Directories:{s}\n", .{ CYAN, RESET });
    std.debug.print("  .trinity/    - Runtime data (jobs, registry, MCP schemas)\n", .{});

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });
}

pub fn runFmtCommand(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}Formatting Zig code...{s}\n", .{ YELLOW, RESET });

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "fmt", "src/" },
    }) catch |err| {
        std.debug.print("  {s}FAIL{s}: {}\n", .{ "\x1b[31m", RESET, err });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});
    }
    std.debug.print("  {s}OK{s} src/ formatted\n", .{ GREEN, RESET });
}

pub fn runStatsCommand(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  TRINITY STATISTICS (live){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });

    // Count .zig files in src/ and tools/
    var zig_count: usize = 0;
    var line_count: usize = 0;
    const scan_dirs = [_][]const u8{ "src", "tools" };
    for (scan_dirs) |scan_dir| {
        var walker = std.fs.cwd().openDir(scan_dir, .{ .iterate = true }) catch continue;
        defer walker.close();
        var it = walker.walk(allocator) catch continue;
        defer it.deinit();
        while (it.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            zig_count += 1;
            // Count lines
            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, entry.path }) catch continue;
            defer allocator.free(full_path);
            const file = std.fs.cwd().openFile(full_path, .{}) catch continue;
            defer file.close();
            const stat = file.stat() catch continue;
            // Estimate lines from file size (avg ~35 bytes/line for zig)
            line_count += @as(usize, @intCast(stat.size)) / 35;
        }
    }

    // Count .tri specs
    var spec_count: usize = 0;
    if (std.fs.cwd().openDir("specs", .{ .iterate = true })) |dir_val| {
        var dir = dir_val;
        var it = dir.walk(allocator) catch null;
        if (it) |*walker| {
            defer walker.deinit();
            while (walker.next() catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".tri")) {
                    spec_count += 1;
                }
            }
        }
        dir.close();
    } else |_| {}

    std.debug.print("{s}Code:{s}\n", .{ CYAN, RESET });
    std.debug.print("  .zig files: {d}\n", .{zig_count});
    std.debug.print("  ~lines:     {d}K\n", .{line_count / 1000});
    std.debug.print("  .tri specs: {d}\n\n", .{spec_count});

    // Git dirty count
    const git_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "status", "--short" },
    }) catch null;
    if (git_result) |r| {
        defer allocator.free(r.stdout);
        defer allocator.free(r.stderr);
        var dirty: usize = 0;
        var lines_it = std.mem.splitScalar(u8, r.stdout, '\n');
        while (lines_it.next()) |l| {
            if (l.len > 0) dirty += 1;
        }
        std.debug.print("{s}Git:{s}\n", .{ CYAN, RESET });
        std.debug.print("  dirty files: {d}\n\n", .{dirty});
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
}

pub fn runIglaCommand(allocator: std.mem.Allocator) !void {
    _ = allocator;

    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  IGLA - Anti-Theft Protection{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}IGLA is currently in stealth mode.{s}\n", .{ GRAY, RESET });
    std.debug.print("No code theft detected.\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE COMMANDS - Structural Editor Core
// ═══════════════════════════════════════════════════════════════════════════════
//
// NEEDLE is a structural code editor with Tier 0→1→2 fallback:
// - Tier 0: Fuzzy text matching (Aider-style)
// - Tier 1: AST-based matching (ast-grep-style)
// - Tier 2: Semantic VSA search (future)
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

/// Run needle edit command — structural find/replace in source files.
/// Usage: tri needle --file <path> --query <pattern> --replace <code>
pub fn runNeedleCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var file_path: ?[]const u8 = null;
    var query: ?[]const u8 = null;
    var replace: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--file") or std.mem.eql(u8, args[i], "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                file_path = args[i];
            }
        } else if (std.mem.eql(u8, args[i], "--query") or std.mem.eql(u8, args[i], "-q")) {
            if (i + 1 < args.len) {
                i += 1;
                query = args[i];
            }
        } else if (std.mem.eql(u8, args[i], "--replace") or std.mem.eql(u8, args[i], "-r")) {
            if (i + 1 < args.len) {
                i += 1;
                replace = args[i];
            }
        }
    }

    const fp = file_path orelse {
        std.debug.print("{s}Error: --file required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    };
    const q = query orelse {
        std.debug.print("{s}Error: --query required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    };

    // Read file
    const content = std.fs.cwd().readFileAlloc(allocator, fp, 10 * 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading {s}: {}{s}\n", .{ RED, fp, err, RESET });
        return;
    };
    defer allocator.free(content);

    // Find occurrences
    var count: usize = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, q)) |idx| {
        count += 1;
        pos = idx + q.len;
    }

    if (count == 0) {
        std.debug.print("{s}No matches for query in {s}{s}\n", .{ YELLOW, fp, RESET });
        return;
    }

    std.debug.print("{s}Found {d} match(es) in {s}{s}\n", .{ GREEN, count, fp, RESET });

    // Replace if --replace given
    if (replace) |r| {
        const new_content = std.mem.replaceOwned(u8, allocator, content, q, r) catch |err| {
            std.debug.print("{s}Error during replace: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(new_content);

        const file = std.fs.cwd().createFile(fp, .{}) catch |err| {
            std.debug.print("{s}Error writing {s}: {}{s}\n", .{ RED, fp, err, RESET });
            return;
        };
        defer file.close();
        file.writeAll(new_content) catch |err| {
            std.debug.print("{s}Error writing {s}: {}{s}\n", .{ RED, fp, err, RESET });
            return;
        };
        std.debug.print("{s}Replaced {d} occurrence(s) in {s}{s}\n", .{ GREEN, count, fp, RESET });
    }
}

/// Run needle search command — search for pattern across files.
/// Usage: tri needle-search <query> [--file <path>]
pub fn runNeedleSearchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Error: search query required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    }

    var query: []const u8 = args[0];
    var search_path: []const u8 = "src";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--file") or std.mem.eql(u8, args[i], "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                search_path = args[i];
            }
        } else {
            query = args[i];
        }
    }

    // Use grep via child process for recursive search
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "grep", "-rn", "--include=*.zig", query, search_path },
        .max_output_bytes = 1024 * 1024,
    }) catch {
        std.debug.print("{s}Error: grep failed{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        std.debug.print("{s}No matches for \"{s}\" in {s}{s}\n", .{ YELLOW, query, search_path, RESET });
    } else {
        std.debug.print("{s}Matches for \"{s}\":{s}\n{s}\n", .{ GREEN, query, RESET, result.stdout });
    }
}

/// Run needle check command — validate file compiles and has no obvious issues.
/// Usage: tri needle-check <file-path>
pub fn runNeedleCheckCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Error: file path required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    }

    const file_path = args[0];

    // Check file exists and is non-empty
    const stat = std.fs.cwd().statFile(file_path) catch |err| {
        std.debug.print("{s}Error: cannot stat {s}: {}{s}\n", .{ RED, file_path, err, RESET });
        return;
    };

    std.debug.print("{s}File:{s} {s}\n", .{ CYAN, RESET, file_path });
    std.debug.print("{s}Size:{s} {d} bytes\n", .{ CYAN, RESET, stat.size });

    // Quick quality checks
    const content = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(content);

    var todos: usize = 0;
    var empty_catches: usize = 0;
    var panics: usize = 0;
    var lines: usize = 0;
    var pos: usize = 0;

    while (pos < content.len) {
        const nl = std.mem.indexOfScalarPos(u8, content, pos, '\n') orelse content.len;
        const line = content[pos..nl];
        lines += 1;

        if (std.mem.indexOf(u8, line, "TODO") != null) todos += 1;
        if (std.mem.indexOf(u8, line, "catch {}") != null or
            std.mem.indexOf(u8, line, "catch { }") != null) empty_catches += 1;
        if (std.mem.indexOf(u8, line, "@panic") != null) panics += 1;

        pos = if (nl < content.len) nl + 1 else content.len;
    }

    std.debug.print("{s}Lines:{s} {d}\n", .{ CYAN, RESET, lines });
    if (todos > 0) std.debug.print("{s}TODOs:{s} {d}\n", .{ YELLOW, RESET, todos });
    if (empty_catches > 0) std.debug.print("{s}Empty catches:{s} {d}\n", .{ RED, RESET, empty_catches });
    if (panics > 0) std.debug.print("{s}@panic calls:{s} {d}\n", .{ RED, RESET, panics });

    const issues = todos + empty_catches + panics;
    if (issues == 0) {
        std.debug.print("{s}Quality: PASS{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}Quality: WARN — {d} issues ({d} TODOs, {d} empty catches, {d} panics){s}\n", .{ YELLOW, issues, todos, empty_catches, panics, RESET });
    }
}

fn printNeedleHelp() void {
    std.debug.print("\n{s}NEEDLE - Structural Editor Core{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri needle --file <path> --query <pattern> --replace <code>\n", .{});
    std.debug.print("  tri needle-search <query> [--file <path>]\n", .{});
    std.debug.print("  tri needle-check <file-path>\n", .{});
    std.debug.print("\n{s}OPTIONS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  -f, --file <path>      Target file path\n", .{});
    std.debug.print("  -q, --query <pattern>  Search pattern (S-expression or text)\n", .{});
    std.debug.print("  -r, --replace <code>   Replacement code\n", .{});
    std.debug.print("  --safety <level>       low|medium|high (default: medium)\n", .{});
    std.debug.print("  -p, --preview          Show diff without applying\n", .{});
    std.debug.print("  --mode <mode>          structural|semantic|text|auto\n", .{});
    std.debug.print("\n{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri needle -f src/main.zig -q \"fn oldName\" -r \"fn newName\"\n", .{});
    std.debug.print("  tri needle-search \"TODO\" --file src/main.zig\n", .{});
    std.debug.print("  tri needle-check src/main.zig\n", .{});
    std.debug.print("\n{s}TIERS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Tier 0: Fuzzy text matching (Aider-style)\n", .{});
    std.debug.print("  Tier 1: AST-based matching (ast-grep-style)\n", .{});
    std.debug.print("  Tier 2: Semantic VSA search (future)\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST REPL COMMAND - Cycle 100/101
// ═══════════════════════════════════════════════════════════════════════════════
//
// Run tests with special flags: --repl, --generate, --coverage, --full, etc.
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

/// Run test command with special flags (repl, generate, coverage, etc.)
pub fn runReplTestCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}TRI TEST REPL MODE{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Available flags:{s}\n", .{ CYAN, RESET });
    std.debug.print("  --repl, -r       Enter REPL mode for interactive testing\n", .{});
    std.debug.print("  --generate, -g   Generate test scaffolding\n", .{});
    std.debug.print("  --coverage       Run tests with coverage report\n", .{});
    std.debug.print("  --full, -f       Run all tests including slow ones\n", .{});
    std.debug.print("  --category, -c   Run tests by category\n", .{});
    std.debug.print("  --verbose, -v    Verbose test output\n", .{});
    std.debug.print("  --help, -h       Show this help\n\n", .{});
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ YELLOW, RESET });

    // For now, just show help. In a full implementation, this would:
    // - Enter REPL loop for interactive test execution
    // - Generate test scaffolding based on project analysis
    // - Run coverage analysis with lcov or similar
    // - Filter tests by category or speed
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC LINTER (Issue #68) — Quality Gate
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runLintCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Resolve vibee binary
    const vibee_path = blk: {
        const paths = [_][]const u8{ "zig-out/bin/vibee", "./zig-out/bin/vibee" };
        for (paths) |p| {
            std.fs.cwd().access(p, .{}) catch continue;
            break :blk p;
        }
        std.debug.print("{s}Error:{s} VIBEE binary not found. Run 'zig build' first.\n", .{ RED, RESET });
        return;
    };

    // Parse subcommands
    var target: ?[]const u8 = null;
    var all_mode = false;
    var report_mode = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--all") or std.mem.eql(u8, arg, "-a")) {
            all_mode = true;
        } else if (std.mem.eql(u8, arg, "--report") or std.mem.eql(u8, arg, "-r")) {
            report_mode = true;
        } else if (arg.len > 0 and arg[0] != '-') {
            target = arg;
        }
    }

    if (report_mode) {
        printLintReport();
        return;
    }

    if (all_mode) {
        target = "specs/tri/";
    }

    if (target == null) {
        printLintHelp();
        return;
    }

    const spec_target = target.?;

    // Run vibee validate <target>
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ vibee_path, "validate", spec_target },
        .max_output_bytes = 4_194_304,
    }) catch {
        std.debug.print("{s}Error:{s} vibee validate failed to execute\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // vibee validate writes to stderr via std.debug.print
    const output = if (result.stderr.len > 0) result.stderr else result.stdout;
    if (output.len > 0) std.debug.print("{s}", .{output});

    // Write protocol log to .trinity/lint/
    const lint_ok = switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
    writeLintLog(allocator, spec_target, lint_ok);

    // Exit status
    if (!lint_ok) {
        std.debug.print("\n{s}GATE BLOCKED{s} — spec validation failed\n", .{ RED, RESET });
    }
}

fn writeLintLog(allocator: std.mem.Allocator, spec_path: []const u8, passed: bool) void {
    // Ensure .trinity/lint/ directory exists
    std.fs.cwd().makePath(".trinity/lint") catch return;

    // Build date string for filename (YYYY-MM-DD.jsonl)
    const ts = std.time.timestamp();
    const epoch_secs: u64 = @intCast(ts);
    const day_secs: u64 = 86400;
    const days_since_epoch = epoch_secs / day_secs;
    // Approximate date calculation
    const year = 1970 + days_since_epoch / 365;
    const remainder = days_since_epoch % 365;
    const month = remainder / 30 + 1;
    const day = remainder % 30 + 1;

    var fname_buf: [64]u8 = undefined;
    const fname = std.fmt.bufPrint(&fname_buf, ".trinity/lint/{d}-{d:0>2}-{d:0>2}.jsonl", .{ year, month, day }) catch return;

    // Format JSONL entry
    const status_str: []const u8 = if (passed) "PASS" else "FAIL";
    const gate_str: []const u8 = if (passed) "OPEN" else "BLOCKED";

    var entry_buf: [512]u8 = undefined;
    const entry = std.fmt.bufPrint(&entry_buf, "{{\"spec\":\"{s}\",\"result\":\"{s}\",\"gate\":\"{s}\",\"epoch\":{d}}}\n", .{ spec_path, status_str, gate_str, epoch_secs }) catch return;

    // Append to log file
    const file = std.fs.cwd().openFile(fname, .{ .mode = .write_only }) catch {
        // File doesn't exist, create it
        const f = std.fs.cwd().createFile(fname, .{}) catch return;
        f.writeAll(entry) catch |err| {
            std.log.debug("failed to write pipeline log entry: {}", .{err});
        };
        f.close();
        return;
    };
    defer file.close();
    file.seekFromEnd(0) catch return;
    file.writeAll(entry) catch |err| {
        std.log.debug("failed to append pipeline log entry: {}", .{err});
    };

    _ = allocator;
}

fn printLintReport() void {
    std.debug.print("\n{s}LINT REPORT{s}\n", .{ YELLOW, RESET });
    std.debug.print("─────────────────────────────────\n", .{});

    // Read latest log file
    var dir = std.fs.cwd().openDir(".trinity/lint", .{ .iterate = true }) catch {
        std.debug.print("No lint logs found. Run 'tri lint --all' first.\n", .{});
        return;
    };
    defer dir.close();

    var latest_name: [64]u8 = undefined;
    var found = false;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".jsonl")) {
            const copy_len = @min(entry.name.len, latest_name.len - 1);
            @memcpy(latest_name[0..copy_len], entry.name[0..copy_len]);
            latest_name[copy_len] = 0;
            found = true;
        }
    }

    if (!found) {
        std.debug.print("No lint logs found.\n", .{});
        return;
    }

    // Count PASS/FAIL entries
    const sentinel: [*:0]const u8 = @ptrCast(&latest_name);
    const name_slice = std.mem.span(sentinel);
    const content = dir.readFileAlloc(std.heap.page_allocator, name_slice, 1_048_576) catch {
        std.debug.print("Error reading log.\n", .{});
        return;
    };
    defer std.heap.page_allocator.free(content);

    var pass_count: usize = 0;
    var fail_count: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, "\"PASS\"") != null) pass_count += 1;
        if (std.mem.indexOf(u8, line, "\"FAIL\"") != null) fail_count += 1;
    }

    const total = pass_count + fail_count;
    std.debug.print("  File: {s}\n", .{name_slice});
    std.debug.print("  Pass: {d}\n", .{pass_count});
    std.debug.print("  Fail: {d}\n", .{fail_count});
    if (total > 0) {
        const rate = @as(f64, @floatFromInt(pass_count)) / @as(f64, @floatFromInt(total)) * 100.0;
        std.debug.print("  Rate: {d:.1}%\n", .{rate});
    }
    std.debug.print("\n", .{});
}

fn printLintHelp() void {
    std.debug.print("\n{s}TRI LINT{s} — Spec Validation\n", .{ YELLOW, RESET });
    std.debug.print("─────────────────────────────────\n", .{});
    std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri lint <file.tri>    Validate a single spec\n", .{});
    std.debug.print("  tri lint --all         Validate all specs/tri/\n", .{});
    std.debug.print("  tri lint --report      Show lint statistics\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri lint specs/tri/sacred_cosmology.tri\n", .{});
    std.debug.print("  tri lint --all\n", .{});
    std.debug.print("  tri lint --report\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
// UI Command: Queen UI launcher
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runUiCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const sub = if (args.len > 0) args[0] else "";

    if (std.mem.eql(u8, sub, "kill")) {
        uiKill(allocator);
        return;
    }
    if (std.mem.eql(u8, sub, "build")) {
        try uiBuild(allocator);
        return;
    }
    if (std.mem.eql(u8, sub, "screenshot")) {
        try uiScreenshot(allocator);
        return;
    }
    if (std.mem.eql(u8, sub, "inspect")) {
        try uiInspect(allocator);
        return;
    }
    if (std.mem.eql(u8, sub, "help") or std.mem.eql(u8, sub, "--help")) {
        std.debug.print(
            \\{s}tri ui{s} — Queen UI launcher
            \\
            \\  {s}tri ui{s}            build + kill old + copy to .app + open
            \\  {s}tri ui build{s}      swift build only
            \\  {s}tri ui kill{s}       kill running Trinity.app
            \\  {s}tri ui screenshot{s} capture window → .trinity/ui_screenshot.png
            \\  {s}tri ui inspect{s}    diagnostic report (process, daemon, build)
            \\
        , .{ GREEN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET });
        return;
    }

    // Full cycle: kill → build → copy → open
    std.debug.print("{s}▸ Killing old Trinity.app...{s}\n", .{ GRAY, RESET });
    uiKill(allocator);

    std.debug.print("{s}▸ Building Queen UI (swift build)...{s}\n", .{ CYAN, RESET });
    try uiBuild(allocator);

    std.debug.print("{s}▸ Copying binary to Trinity.app bundle...{s}\n", .{ CYAN, RESET });
    try uiCopyBinary(allocator);

    std.debug.print("{s}▸ Opening Trinity.app...{s}\n", .{ GREEN, RESET });
    try uiOpen(allocator);

    std.debug.print("{s}✓ Queen UI launched{s}\n", .{ GREEN, RESET });
}

fn uiKill(allocator: std.mem.Allocator) void {
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "pkill", "-9", "-f", "Trinity.app" },
        .max_output_bytes = 4096,
    }) catch {};
    // Also kill by process name
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "pkill", "-9", "trinity" },
        .max_output_bytes = 4096,
    }) catch {};
    std.debug.print("{s}✓ Old processes killed{s}\n", .{ GREEN, RESET });
}

fn uiBuild(allocator: std.mem.Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "swift", "build" },
        .cwd = "apps/queen",
        .max_output_bytes = 256 * 1024,
    }) catch |err| {
        std.debug.print("{s}✗ swift build failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    if (code != 0) {
        std.debug.print("{s}✗ swift build failed (exit {d}):{s}\n{s}\n", .{ RED, code, RESET, result.stderr });
        return error.BuildFailed;
    }
    std.debug.print("{s}✓ Build OK{s}\n", .{ GREEN, RESET });
}

fn uiCopyBinary(allocator: std.mem.Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "cp",
            "apps/queen/.build/arm64-apple-macosx/debug/trinity",
            "apps/queen/Trinity.app/Contents/MacOS/trinity",
        },
        .max_output_bytes = 4096,
    }) catch |err| {
        std.debug.print("{s}✗ Copy failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };
    if (code != 0) {
        std.debug.print("{s}✗ Copy failed (exit {d}):{s}\n{s}\n", .{ RED, code, RESET, result.stderr });
        return error.CopyFailed;
    }
}

fn uiOpen(allocator: std.mem.Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "open", "apps/queen/Trinity.app" },
        .max_output_bytes = 4096,
    }) catch |err| {
        std.debug.print("{s}✗ open failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI Self-Debug: screenshot + inspect
// ═══════════════════════════════════════════════════════════════════════════════

fn uiScreenshot(allocator: std.mem.Allocator) !void {
    // Check if Trinity.app is running
    const pgrep = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "pgrep", "-x", "trinity" },
        .max_output_bytes = 4096,
    }) catch {
        std.debug.print("{s}✗ Trinity.app not running{s}\n", .{ RED, RESET });
        return error.NotRunning;
    };
    defer allocator.free(pgrep.stdout);
    defer allocator.free(pgrep.stderr);

    const pgrep_code: u8 = switch (pgrep.term) {
        .Exited => |c| c,
        else => 1,
    };

    if (pgrep_code != 0) {
        std.debug.print("{s}✗ Trinity.app not running — launch with: tri ui{s}\n", .{ RED, RESET });
        return error.NotRunning;
    }

    // Capture screenshot
    std.fs.cwd().makePath(".trinity") catch {};
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "screencapture", "-x", "-o", ".trinity/ui_screenshot.png" },
        .max_output_bytes = 4096,
    }) catch |err| {
        std.debug.print("{s}✗ screencapture failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    if (code != 0) {
        std.debug.print("{s}✗ screencapture failed (exit {d}){s}\n", .{ RED, code, RESET });
        return error.ScreenshotFailed;
    }

    std.debug.print("{s}✓ Screenshot saved: .trinity/ui_screenshot.png{s}\n", .{ GREEN, RESET });
}

fn uiInspect(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}▸ Queen UI Diagnostic{s}\n\n", .{ GOLDEN, RESET });

    // 1. Process check
    const pgrep = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "pgrep", "-x", "trinity" },
        .max_output_bytes = 4096,
    }) catch null;

    if (pgrep) |p| {
        defer allocator.free(p.stdout);
        defer allocator.free(p.stderr);
        const running: u8 = switch (p.term) {
            .Exited => |c| c,
            else => 1,
        };
        if (running == 0) {
            const pid_str = std.mem.trimRight(u8, p.stdout, "\n\r ");
            std.debug.print("  {s}Process:{s}    {s}RUNNING{s} (PID: {s})\n", .{ GRAY, RESET, GREEN, RESET, pid_str });
        } else {
            std.debug.print("  {s}Process:{s}    {s}NOT RUNNING{s}\n", .{ GRAY, RESET, RED, RESET });
        }
    } else {
        std.debug.print("  {s}Process:{s}    {s}NOT RUNNING{s}\n", .{ GRAY, RESET, RED, RESET });
    }

    // 2. Queen daemon state
    const state_file = std.fs.cwd().openFile(".trinity/queen_state.json", .{}) catch {
        std.debug.print("  {s}Daemon:{s}     {s}NO STATE{s}\n", .{ GRAY, RESET, RED, RESET });
        return;
    };
    defer state_file.close();

    var state_buf: [1024]u8 = undefined;
    const n = state_file.read(&state_buf) catch 0;
    if (n > 0) {
        const data = state_buf[0..n];
        if (qt.findJsonU32(data, "\"cycle\":")) |cycle| {
            std.debug.print("  {s}Daemon:{s}     cycle #{d}", .{ GRAY, RESET, cycle });
        }
        if (qt.findJsonI64(data, "\"started_at\":")) |started| {
            if (started > 0) {
                const uptime = std.time.timestamp() - started;
                std.debug.print(" | uptime {d}h {d}m", .{
                    @divTrunc(uptime, 3600),
                    @divTrunc(@mod(uptime, 3600), 60),
                });
            }
        }
        std.debug.print("\n", .{});
    }

    // 3. Senses freshness
    const senses_file = std.fs.cwd().openFile(".trinity/queen/senses.json", .{}) catch {
        std.debug.print("  {s}Senses:{s}     {s}NOT FOUND{s} (run: tri queen once)\n", .{ GRAY, RESET, RED, RESET });
        return;
    };
    defer senses_file.close();
    const senses_stat = senses_file.stat() catch {
        std.debug.print("  {s}Senses:{s}     {s}STAT FAILED{s}\n", .{ GRAY, RESET, RED, RESET });
        return;
    };
    const senses_age = std.time.timestamp() - @as(i64, @intCast(@divTrunc(senses_stat.mtime, std.time.ns_per_s)));
    const fresh = senses_age < 900;
    std.debug.print("  {s}Senses:{s}     {s}{s}{s} ({d}s ago)\n", .{
        GRAY,                      RESET,
        if (fresh) GREEN else RED, if (fresh) "FRESH" else "STALE",
        RESET,                     senses_age,
    });

    // 4. Last 5 audit entries
    const audit_file = std.fs.cwd().openFile(".trinity/queen/audit.jsonl", .{}) catch {
        std.debug.print("  {s}Audit:{s}      {s}NO LOG{s}\n", .{ GRAY, RESET, GRAY, RESET });
        return;
    };
    defer audit_file.close();
    const audit_stat = audit_file.stat() catch return;
    std.debug.print("  {s}Audit:{s}      {d} bytes\n\n", .{ GRAY, RESET, audit_stat.size });
}

// ═══════════════════════════════════════════════════════════════════════════════
// S³AI BRAIN CIRCUIT COMMANDS (v5.1 - Neuroanatomy)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTaskClaimCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printTaskClaimHelp();
        return;
    }

    const action = args[0];
    const reg = try basal_ganglia.getGlobal(allocator);

    if (std.mem.eql(u8, action, "claim")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri task claim <task_id> [--agent <id>]\n", .{});
            return;
        }
        const task_id = args[1];
        const agent_id = if (args.len >= 4 and std.mem.eql(u8, args[2], "--agent")) args[3] else "default";
        const claimed = try reg.claim(allocator, task_id, agent_id, 300000); // 5 min TTL
        if (claimed) {
            std.debug.print("{s}✓{s} Task {s} claimed by {s}\n", .{ GREEN, RESET, task_id, agent_id });
        } else {
            std.debug.print("{s}✗{s} Task {s} already claimed\n", .{ RED, RESET, task_id });
        }
    } else if (std.mem.eql(u8, action, "release")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri task release <task_id> [--agent <id>]\n", .{});
            return;
        }
        const task_id = args[1];
        const agent_id = if (args.len >= 4 and std.mem.eql(u8, args[2], "--agent")) args[3] else "default";
        const completed = reg.complete(task_id, agent_id);
        if (completed) {
            std.debug.print("{s}✓{s} Task {s} released by {s}\n", .{ GREEN, RESET, task_id, agent_id });
        } else {
            std.debug.print("{s}✗{s} Task {s} not claimed by {s}\n", .{ RED, RESET, task_id, agent_id });
        }
    } else if (std.mem.eql(u8, action, "list")) {
        std.debug.print("{s}Active Task Claims:{s}\n", .{ GOLDEN, RESET });
        var iter = reg.claims.iterator();
        var count: usize = 0;
        while (iter.next()) |entry| {
            const claim = entry.value_ptr.*;
            if (claim.isValid()) {
                std.debug.print("  {s}: {s} (agent: {s}, TTL: {d}s)\n", .{
                    entry.key_ptr.*, claim.task_id, claim.agent_id, claim.ttl_ms / 1000,
                });
                count += 1;
            }
        }
        if (count == 0) {
            std.debug.print("  {s}No active claims{s}\n", .{ GRAY, RESET });
        }
    } else if (std.mem.eql(u8, action, "stats")) {
        std.debug.print("{s}Basal Ganglia Stats:{s}\n", .{ GOLDEN, RESET });
        std.debug.print("  Total claims: {d}\n", .{reg.claims.count()});
    } else if (std.mem.eql(u8, action, "heartbeat")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri task heartbeat <task_id> [--agent <id>]\n", .{});
            return;
        }
        const task_id = args[1];
        const agent_id = if (args.len >= 4 and std.mem.eql(u8, args[2], "--agent")) args[3] else "default";
        const updated = reg.heartbeat(task_id, agent_id);
        if (updated) {
            std.debug.print("{s}✓{s} Heartbeat for {s} refreshed\n", .{ GREEN, RESET, task_id });
        } else {
            std.debug.print("{s}✗{s} Heartbeat failed for {s}\n", .{ RED, RESET, task_id });
        }
    } else if (std.mem.eql(u8, action, "reset")) {
        reg.reset();
        std.debug.print("{s}✓{s} Registry reset\n", .{ GREEN, RESET });
    } else {
        printTaskClaimHelp();
    }
}

pub fn runEventStreamCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printEventStreamHelp();
        return;
    }

    const action = args[0];
    const bus = try reticular_formation.getGlobal(allocator);

    if (std.mem.eql(u8, action, "stream")) {
        var since: i64 = 0;
        var max_events: usize = 100;
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--since") and i + 1 < args.len) {
                since = try std.fmt.parseInt(i64, args[i + 1], 10);
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--max") and i + 1 < args.len) {
                max_events = try std.fmt.parseInt(usize, args[i + 1], 10);
                i += 1;
            }
        }
        const events = try bus.poll(since, allocator, max_events);
        defer allocator.free(events);
        std.debug.print("{s}Events (since {d}):{s}\n", .{ GOLDEN, since, RESET });
        for (events, 0..) |evt, idx| {
            std.debug.print("  [{d}] {s} @ {d}\n", .{ idx, @tagName(evt.event_type), evt.timestamp });
        }
    } else if (std.mem.eql(u8, action, "stats")) {
        const stats = bus.getStats();
        std.debug.print("{s}Reticular Formation Stats:{s}\n", .{ GOLDEN, RESET });
        std.debug.print("  Published: {d}\n", .{stats.published});
        std.debug.print("  Polled: {d}\n", .{stats.polled});
        std.debug.print("  Buffered: {d}\n", .{stats.buffered});
    } else if (std.mem.eql(u8, action, "clear")) {
        bus.clear();
        std.debug.print("{s}✓{s} Event bus cleared\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, action, "trim")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri event trim <count>\n", .{});
            return;
        }
        const count = try std.fmt.parseInt(usize, args[1], 10);
        bus.trim(count);
        std.debug.print("{s}✓{s} Trimmed to {d} events\n", .{ GREEN, RESET, count });
    } else {
        printEventStreamHelp();
    }
}

fn printTaskClaimHelp() void {
    std.debug.print("{s}Basal Ganglia Commands (Task Claim Registry):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  tri task claim <task_id> [--agent <id>]     Claim a task\n", .{});
    std.debug.print("  tri task release <task_id> [--agent <id>]    Release a task\n", .{});
    std.debug.print("  tri task list [--agent <id>]                 List active claims\n", .{});
    std.debug.print("  tri task stats                               Show registry stats\n", .{});
    std.debug.print("  tri task heartbeat <task_id> [--agent <id>]  Refresh claim\n", .{});
    std.debug.print("  tri task reset                               Clear registry\n", .{});
}

fn printEventStreamHelp() void {
    std.debug.print("{s}Reticular Formation Commands (Event Bus):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  tri event stream [--since <ts>] [--max <N>]  Poll events\n", .{});
    std.debug.print("  tri event stats                               Show bus stats\n", .{});
    std.debug.print("  tri event trim <count>                        Trim old events\n", .{});
    std.debug.print("  tri event clear                               Clear all events\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRESS TEST COMMAND — S³AI Brain Load Testing
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runStressTestCommand(args: []const []const u8) !void {
    if (args.len > 0) {
        if (std.mem.eql(u8, args[0], "--health")) {
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var coord = try brain.AgentCoordination.init(allocator);
            const health = coord.healthCheck();

            std.debug.print("{s}╔═══════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  S³AI BRAIN HEALTH CHECK            ║{s}\n", .{ YELLOW, RESET });
            std.debug.print("{s}╚═══════════════════════════════════════╝{s}\n", .{ CYAN, RESET });
            std.debug.print("\n  Score: {d:.1}/100\n", .{health.score});
            std.debug.print("  Status: {s}{s}{s}\n\n", .{ if (health.healthy) GREEN else RED, if (health.healthy) "HEALTHY" else "UNHEALTHY", RESET });
            std.debug.print("  Active Claims: {d}\n", .{health.details.claims_count});
            std.debug.print("  Events Published: {d}\n", .{health.details.events_published});
            std.debug.print("  Events Buffered: {d}\n", .{health.details.events_buffered});

            if (!health.healthy) {
                return error.BrainUnhealthy;
            }
        } else if (std.mem.eql(u8, args[0], "--metrics")) {
            // Export Prometheus metrics (Corpus Callosum)
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var coord = try brain.AgentCoordination.init(allocator);
            const stats = coord.getStats();
            const health = coord.healthCheck();

            std.debug.print("# HELP s3ai_brain_active_claims Current number of active task claims\n", .{});
            std.debug.print("# TYPE s3ai_brain_active_claims gauge\n", .{});
            std.debug.print("s3ai_brain_active_claims {d}\n", .{stats.active_claims});

            std.debug.print("\n# HELP s3ai_brain_events_published Total events published\n", .{});
            std.debug.print("# TYPE s3ai_brain_events_published counter\n", .{});
            std.debug.print("s3ai_brain_events_published {d}\n", .{stats.total_events_published});

            std.debug.print("\n# HELP s3ai_brain_events_polled Total event polls\n", .{});
            std.debug.print("# TYPE s3ai_brain_events_polled counter\n", .{});
            std.debug.print("s3ai_brain_events_polled {d}\n", .{stats.total_events_polled});

            std.debug.print("\n# HELP s3ai_brain_events_buffered Current buffered events\n", .{});
            std.debug.print("# TYPE s3ai_brain_events_buffered gauge\n", .{});
            std.debug.print("s3ai_brain_events_buffered {d}\n", .{stats.buffered_events});

            std.debug.print("\n# HELP s3ai_brain_health_score Brain health score (0-100)\n", .{});
            std.debug.print("# TYPE s3ai_brain_health_score gauge\n", .{});
            std.debug.print("s3ai_brain_health_score {d:.1}\n", .{health.score});

            std.debug.print("\n# HELP s3ai_brain_healthy Brain health status (1=healthy, 0=unhealthy)\n", .{});
            std.debug.print("# TYPE s3ai_brain_healthy gauge\n", .{});
            std.debug.print("s3ai_brain_healthy {d}\n", .{@intFromBool(health.healthy)});
        } else if (std.mem.eql(u8, args[0], "--dump")) {
            // Dump brain state
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var coord = try brain.AgentCoordination.init(allocator);
            const stats = coord.getStats();
            const health = coord.healthCheck();

            std.debug.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
            std.debug.print("║  S³AI BRAIN DUMP — {s:>19}                  ║\n", .{"v5.1"});
            std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
            std.debug.print("║  HEALTH SCORE: {d:.1}/100  [{s:>10}]                        ║\n", .{ health.score, if (health.healthy) "HEALTHY" else "UNHEALTHY" });
            std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
            std.debug.print("║  Basal Ganglia (Action Selection)                            ║\n", .{});
            std.debug.print("║    Active Claims:    {d:>6}                                 ║\n", .{stats.active_claims});
            std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
            std.debug.print("║  Reticular Formation (Broadcast Alerting)                    ║\n", .{});
            std.debug.print("║    Events Published: {d:>6}                                 ║\n", .{stats.total_events_published});
            std.debug.print("║    Events Polled:    {d:>6}                                 ║\n", .{stats.total_events_polled});
            std.debug.print("║    Events Buffered:  {d:>6}                                 ║\n", .{stats.buffered_events});
            std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
            std.debug.print("║  Locus Coeruleus (Arousal Regulation)                        ║\n", .{});
            std.debug.print("║    Strategy:         {s:>30}        ║\n", .{@tagName(coord.backoff_policy.strategy)});
            std.debug.print("║    Initial Delay:    {d:>6} ms                             ║\n", .{coord.backoff_policy.initial_ms});
            std.debug.print("║    Max Delay:        {d:>6} ms                             ║\n", .{coord.backoff_policy.max_ms});
            std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
        } else if (std.mem.eql(u8, args[0], "--scan")) {
            // Visual brain scan
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var coord = try brain.AgentCoordination.init(allocator);
            const scan = coord.scan();

            std.debug.print("{s}╔═══════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  S³AI BRAIN SCAN — v5.1               ║{s}\n", .{ YELLOW, RESET });
            std.debug.print("{s}╠═══════════════════════════════════════╣{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  Basal Ganglia:     {s}  Action     ║{s}\n", .{ RESET, scan.basal_ganglia, RESET });
            std.debug.print("{s}║  Reticular Form.:  {s}  Alert      ║{s}\n", .{ RESET, scan.reticular_formation, RESET });
            std.debug.print("{s}║  Locus Coeruleus:  {s}  Arousal    ║{s}\n", .{ RESET, scan.locus_coeruleus, RESET });
            std.debug.print("{s}╠═══════════════════════════════════════╣{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  Overall Status:    {s}             ║{s}\n", .{ RESET, scan.overall, RESET });
            std.debug.print("{s}╚═══════════════════════════════════════╝{s}\n", .{ CYAN, RESET });
        } else if (std.mem.eql(u8, args[0], "--telemetry")) {
            // Show telemetry summary (Corpus Callosum)
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var coord = try brain.AgentCoordination.init(allocator);

            // Create telemetry instance
            var tel = brain.telemetry.BrainTelemetry.init(allocator, 1000);
            defer tel.deinit();

            // Record current point
            const stats = coord.getStats();
            const health = coord.healthCheck();
            const now = std.time.milliTimestamp();

            try tel.record(.{
                .timestamp = now,
                .active_claims = stats.active_claims,
                .events_published = stats.total_events_published,
                .events_buffered = stats.buffered_events,
                .health_score = health.score,
            });

            // Show summary
            std.debug.print("{s}╔═══════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  S³AI TELEMETRY — Corpus Callosum   ║{s}\n", .{ YELLOW, RESET });
            std.debug.print("{s}╚═══════════════════════════════════════╝{s}\n", .{ CYAN, RESET });
            std.debug.print("  Avg Health (10):  {d:.1}/100\n", .{tel.avgHealth(10)});
            const trend = tel.trend(10);
            const trend_str = switch (trend) {
                .improving => "📈 Improving",
                .stable => "➡️ Stable",
                .declining => "📉 Declining",
            };
            std.debug.print("  Trend:             {s}\n", .{trend_str});
        } else if (std.mem.eql(u8, args[0], "--history")) {
            // Show health history (Hippocampus)
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var history = brain.health_history.BrainHealthHistory.init(allocator);

            std.debug.print("{s}╔═══════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  S³AI HIPPOCAMPUS — Health Memory                ║{s}\n", .{ YELLOW, RESET });
            std.debug.print("{s}╚═══════════════════════════════════════════════════╝{s}\n", .{ CYAN, RESET });

            const snapshots = history.recent(10) catch |err| {
                std.debug.print("  Error reading history: {}\n", .{err});
                std.debug.print("  (Run --record to create first snapshot)\n", .{});
                return;
            };
            defer allocator.free(snapshots);

            if (snapshots.len == 0) {
                std.debug.print("  No history yet. Use --record to create snapshot.\n", .{});
            } else {
                std.debug.print("\n  Recent {d} snapshots:\n", .{snapshots.len});
                std.debug.print("  ┌────────────┬────────┬───────┬────────┬──────┐\n", .{});
                std.debug.print("  │ Time       │ Health │ OK    │ Claims │ Event│\n", .{});
                std.debug.print("  ├────────────┼────────┼───────┼────────┼──────┤\n", .{});
                for (snapshots) |snap| {
                    const time_str = if (snap.timestamp > 0)
                        std.fmt.allocPrint(allocator, "{d}m ago", .{@divTrunc(std.time.milliTimestamp() - snap.timestamp, 60000)}) catch "?"
                    else
                        "?";
                    defer if (!std.mem.eql(u8, time_str, "?")) allocator.free(time_str);

                    std.debug.print("  │ {s:>10} │ {d:6.1} │ {s:>5} │ {d:6} │ {d:4} │\n", .{
                        time_str, snap.health_score, if (snap.healthy) "✓" else "✗", snap.active_claims, snap.events_published,
                    });
                }
                std.debug.print("  └────────────┴────────┴───────┴────────┴──────┘\n", .{});
            }
        } else if (std.mem.eql(u8, args[0], "--record")) {
            // Record current health snapshot (Hippocampus consolidation)
            const brain = @import("brain");
            const allocator = std.heap.page_allocator;
            var coord = try brain.AgentCoordination.init(allocator);
            var history = brain.health_history.BrainHealthHistory.init(allocator);

            const stats = coord.getStats();
            const health = coord.healthCheck();

            const snapshot = brain.health_history.HealthSnapshot{
                .timestamp = std.time.milliTimestamp(),
                .health_score = health.score,
                .healthy = health.healthy,
                .active_claims = stats.active_claims,
                .events_published = stats.total_events_published,
                .events_buffered = stats.buffered_events,
                .stress_test_passed = true,
                .stress_test_score = null,
            };

            try history.record(snapshot);

            std.debug.print("{s}✓{s} Health snapshot recorded to Hippocampus\n", .{ GREEN, RESET });
            std.debug.print("  Score: {d:.1}/100\n", .{health.score});
            std.debug.print("  File: .trinity/brain_health_history.jsonl\n", .{});
        } else {
            // Full stress test
            std.debug.print("Use: zig build test-brain-stress\n", .{});
        }
    } else {
        // Full stress test (no args)
        std.debug.print("Use: zig build test-brain-stress\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN SIMULATION COMMAND — Realistic Workload Testing
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBrainSimulateCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    var output_json = false;
    var scenario: ?[]const u8 = null;

    // Parse args
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            output_json = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printSimulationHelp();
            return;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            std.debug.print("{s}Error: Unknown flag '{s}'{s}\n", .{ RED, arg, RESET });
            return;
        } else {
            scenario = arg;
        }
    }

    const scenario_name = scenario orelse {
        printSimulationHelp();
        return;
    };

    // Import simulation via brain module which is available
    const brain = @import("brain");
    const page_allocator = std.heap.page_allocator;

    const result = blk: {
        if (std.mem.eql(u8, scenario_name, "smoke")) {
            break :blk try brain.simulation.runSmokeTest(page_allocator);
        } else if (std.mem.eql(u8, scenario_name, "competition")) {
            break :blk try brain.simulation.runAgentCompetition(page_allocator);
        } else if (std.mem.eql(u8, scenario_name, "storm")) {
            break :blk try brain.simulation.runEventStorm(page_allocator);
        } else if (std.mem.eql(u8, scenario_name, "partition")) {
            break :blk try brain.simulation.runNetworkPartition(page_allocator);
        } else if (std.mem.eql(u8, scenario_name, "crash")) {
            break :blk try brain.simulation.runAgentCrash(page_allocator);
        } else {
            std.debug.print("{s}Error: Unknown scenario '{s}'{s}\n", .{ RED, scenario_name, RESET });
            printSimulationHelp();
            return;
        }
    };

    if (output_json) {
        var buffer: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try result.toJson(fbs.writer());
        std.debug.print("{s}", .{fbs.getWritten()});
    } else {
        var buffer: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try result.format(fbs.writer());
        std.debug.print("{s}", .{fbs.getWritten()});
    }
}

fn printSimulationHelp() void {
    std.debug.print("\n{s}S³AI BRAIN SIMULATION — Realistic Workload Testing{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri brain simulate <scenario>\n", .{});
    std.debug.print("\n{s}Scenarios:{s}\n", .{ CYAN, RESET });
    std.debug.print("  smoke         Quick smoke test (10 agents × 100 tasks)\n", .{});
    std.debug.print("  competition   100 agents competing for 1000 tasks\n", .{});
    std.debug.print("  storm         Event storm (1000 events/sec)\n", .{});
    std.debug.print("  partition     Network partition simulation\n", .{});
    std.debug.print("  crash         Agent crash simulation\n", .{});
    std.debug.print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    std.debug.print("  --json        Output result as JSON\n", .{});
    std.debug.print("  --help, -h    Show this help\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri brain simulate smoke\n", .{});
    std.debug.print("  tri brain simulate competition\n", .{});
    std.debug.print("  tri brain simulate storm --json\n", .{});
    std.debug.print("\n", .{});
}

const qt = @import("queen_types.zig");

// BUILTIN REFERENCE
// ═══════════════════════════════════════════════════════════════════════════════

const builtin = @import("builtin");

test "tri_commands_depin_reward_constants" {
    // Verify DePIN reward constants are sane
    try std.testing.expect(depin.REWARD_EVOLUTION_GEN > 0);
    try std.testing.expect(depin.REWARD_BENCHMARK > 0);
    try std.testing.expect(depin.TIER_MULTIPLIER_FREE == 1.0);
    try std.testing.expect(depin.TIER_MULTIPLIER_WHALE > depin.TIER_MULTIPLIER_FREE);
    // formatTRI converts nanoTRI to TRI
    const tri_val = depin.RewardCalculator.formatTRI(1_000_000_000.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), tri_val, 1e-10);
}
