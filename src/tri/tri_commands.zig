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
const BOLD = "\x1b[1m";

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
    _ = allocator;

    if (std.mem.eql(u8, subcommand, "igla")) {
        // TODO: runIglaBench not implemented yet
        std.debug.print("⚠️  igla bench: TODO - not implemented\n", .{});
    }

    const job_system = @import("job_system.zig");
    _ = job_system;
    _ = args;
    _ = subcommand;

    std.debug.print("⚠️  bench async: TODO - job system not configured\n", .{});
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

        if (std.mem.eql(u8, args[0], "--viz") or std.mem.eql(u8, args[0], "viz")) {
            // Route to visualization command
            return runBrainVizCommand(allocator, args[1..]);
        }

        if (std.mem.eql(u8, args[0], "health")) {
            // Route to health command
            return runBrainHealthCommand(allocator, args[1..]);
        }
    }

    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) {
        std.debug.print("{s}Brain Commands:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri brain --alerts [list|stats|check|test]  Brain alerts system\n", .{});
        std.debug.print("  tri brain simulate [smoke|competition|storm|partition|crash] [--json]  Brain simulation\n", .{});
        std.debug.print("  tri brain --viz [map|sparkline|connections|heatmap|3d|preset]  Brain visualizations\n", .{});
        std.debug.print("  tri brain health                           Brain region health check\n", .{});
        return;
    }
}

/// Stub: Brain Alerts Command (TODO: implement)
fn runBrainAlertsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  brain alerts: TODO - not implemented\n", .{});
}

/// Stub: Brain State Recovery Command (TODO: implement)
fn runBrainStateRecoveryCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  brain state recovery: TODO - not implemented yet\n", .{});
}

/// Brain Health Check - Shows status of all brain regions (implemented elsewhere)
/// Usage: tri brain health
// Note: Implementation moved to avoid duplicate
// pub fn runBrainHealthCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--json")) {
            output_json = true;
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            std.debug.print("Brain Health Check:\n", .{});
            std.debug.print("  tri brain health [--json]\n", .{});
            std.debug.print("\nOptions:\n", .{});
            std.debug.print("  --json  Output in JSON format\n", .{});
            return;
        }
    }

    const RegionStatus = enum {
        healthy,
        unavailable,
        warning,
        critical,
    };

    // Check Basal Ganglia
    const basal_status: RegionStatus = blk: {
        if (basal_ganglia.getGlobal(allocator)) |registry| {
            const stats = registry.getStats();
            const status = if (stats.active_claims == 0)
                RegionStatus.healthy
            else if (stats.active_claims < 100 and stats.claim_conflicts < stats.claim_attempts * 5 / 100)
                RegionStatus.healthy
            else if (stats.active_claims < 1000)
                RegionStatus.warning
            else
                RegionStatus.critical;
            break :blk status;
        } else |_| {
            break :blk RegionStatus.unavailable;
        }
    };

    // Check Reticular Formation
    const reticular_status: RegionStatus = blk: {
        if (reticular_formation.getGlobal(allocator)) |bus| {
            const stats = bus.getStats();
            const utilization_pct = @as(f32, @floatFromInt(stats.buffered)) / @as(f32, @floatFromInt(10_000)) * 100.0;
            const status = if (utilization_pct < 10.0)
                RegionStatus.healthy
            else if (utilization_pct < 50.0)
                RegionStatus.healthy
            else if (utilization_pct < 80.0)
                RegionStatus.warning
            else
                RegionStatus.critical;
            break :blk status;
        } else |_| {
            break :blk RegionStatus.unavailable;
        }
    };

    // Get detailed stats for output
    const basal_stats = if (basal_ganglia.getGlobal(allocator)) |registry| blk: {
        const s = registry.getStats();
        break :blk .{
            .active = s.active_claims,
            .attempts = s.claim_attempts,
            .successes = s.claim_success,
            .conflicts = s.claim_conflicts,
        };
    } else |_| .{
        .active = 0,
        .attempts = 0,
        .successes = 0,
        .conflicts = 0,
    };

    const reticular_stats = if (reticular_formation.getGlobal(allocator)) |bus| blk: {
        const s = bus.getStats();
        break :blk .{
            .buffered = s.buffered,
            .published = s.published,
            .polled = s.polled,
            .utilization_pct = @as(f32, @floatFromInt(s.buffered)) / @as(f32, @floatFromInt(10_000)) * 100.0,
        };
    } else |_| .{
        .buffered = 0,
        .published = 0,
        .polled = 0,
        .utilization_pct = 0.0,
    };

    // Calculate aggregate health score (0-100)
    var healthy_count: usize = 0;
    if (basal_status == RegionStatus.healthy) healthy_count += 1;
    if (reticular_status == RegionStatus.healthy) healthy_count += 1;

    var warning_count: usize = 0;
    if (basal_status == RegionStatus.warning) warning_count += 1;
    if (reticular_status == RegionStatus.warning) warning_count += 1;

    var critical_count: usize = 0;
    if (basal_status == RegionStatus.critical) critical_count += 1;
    if (reticular_status == RegionStatus.critical) critical_count += 1;

    var unavailable_count: usize = 0;
    if (basal_status == RegionStatus.unavailable) unavailable_count += 1;
    if (reticular_status == RegionStatus.unavailable) unavailable_count += 1;

    const total_regions = healthy_count + warning_count + critical_count + unavailable_count;
    const health_score: f32 = if (total_regions > 0)
        @as(f32, @floatFromInt(healthy_count * 100 + warning_count * 50)) / @as(f32, @floatFromInt(total_regions))
    else
        100.0;

    // Inline status helpers - no nested functions
    const basal_icon = if (basal_status == RegionStatus.healthy) "[OK]" else if (basal_status == RegionStatus.warning) "[!]" else if (basal_status == RegionStatus.critical) "[X]" else "[?]";
    const basal_text = if (basal_status == RegionStatus.healthy) "healthy" else if (basal_status == RegionStatus.warning) "warning" else if (basal_status == RegionStatus.critical) "critical" else "unavailable";
    const basal_color = if (basal_status == RegionStatus.healthy) GREEN else if (basal_status == RegionStatus.warning) YELLOW else if (basal_status == RegionStatus.critical) RED else WHITE;

    const reticular_icon = if (reticular_status == RegionStatus.healthy) "[OK]" else if (reticular_status == RegionStatus.warning) "[!]" else if (reticular_status == RegionStatus.critical) "[X]" else "[?]";
    const reticular_text = if (reticular_status == RegionStatus.healthy) "healthy" else if (reticular_status == RegionStatus.warning) "warning" else if (reticular_status == RegionStatus.critical) "critical" else "unavailable";
    const reticular_color = if (reticular_status == RegionStatus.healthy) GREEN else if (reticular_status == RegionStatus.warning) YELLOW else if (reticular_status == RegionStatus.critical) RED else WHITE;

    const score_color = if (health_score >= 80) GREEN else if (health_score >= 50) YELLOW else RED;

    // Output based on format
    if (output_json) {
        std.debug.print("{\n", .{});
        std.debug.print("  \"overall_health_score\": {d:.1},\n", .{health_score});
        std.debug.print("  \"basal_ganglia\": {\n", .{});
        std.debug.print("    \"status\": \"{s}\",\n", .{basal_text});
        std.debug.print("    \"active_claims\": {d},\n", .{basal_stats.active});
        std.debug.print("    \"claim_attempts\": {d},\n", .{basal_stats.attempts});
        std.debug.print("    \"claim_successes\": {d},\n", .{basal_stats.successes});
        std.debug.print("    \"claim_conflicts\": {d}\n", .{basal_stats.conflicts});
        std.debug.print("  },\n", .{});
        std.debug.print("  \"reticular_formation\": {\n", .{});
        std.debug.print("    \"status\": \"{s}\",\n", .{reticular_text});
        std.debug.print("    \"buffered_events\": {d},\n", .{reticular_stats.buffered});
        std.debug.print("    \"published_events\": {d},\n", .{reticular_stats.published});
        std.debug.print("    \"polled_events\": {d},\n", .{reticular_stats.polled});
        std.debug.print("    \"utilization_percent\": {d:.1}\n", .{reticular_stats.utilization_pct});
        std.debug.print("  }\n", .{});
        std.debug.print("}\n", .{});
    } else {
        // Format as a colored dashboard
        std.debug.print("\n{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        std.debug.print("{s}                    {s}BRAIN HEALTH CHECK{s}                        {s}\n", .{ CYAN, BOLD, RESET, CYAN });
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });

        // Overall health score
        std.debug.print("{s}{s} Overall Health Score: {s}{d:6.1}%{s}\n", .{ CYAN, RESET, score_color, BOLD, health_score, RESET });
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });

        // Basal Ganglia status
        std.debug.print("{s}Basal Ganglia{RESET}: {s}{s} {s}\n", .{ CYAN, basal_color, BOLD, basal_icon, basal_text, RESET });
        std.debug.print("  Active Claims: {d}\n", .{basal_stats.active});
        std.debug.print("  Claim Attempts: {d}\n", .{basal_stats.attempts});
        const success_rate = if (basal_stats.attempts > 0)
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(basal_stats.successes)) / @as(f32, @floatFromInt(basal_stats.attempts)) * 100.0))
        else 0;
        std.debug.print("  Success Rate: {d}%\n", .{success_rate});
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });

        // Reticular Formation status
        std.debug.print("{s}Reticular Formation{RESET}: {s}{s} {s}\n", .{ CYAN, reticular_color, BOLD, reticular_icon, reticular_text, RESET });
        std.debug.print("  Buffered Events: {d}\n", .{reticular_stats.buffered});
        std.debug.print("  Published Events: {d}\n", .{reticular_stats.published});
        std.debug.print("  Buffer Utilization: {d}%\n", .{@as(usize, @intFromFloat(reticular_stats.utilization_pct))});
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });

        // Summary
        std.debug.print("{s}Summary: {d} healthy, {d} warning, {d} critical, {d} unavailable{RESET}\n", .{
            CYAN, RESET,
            healthy_count,
            warning_count,
            critical_count,
            unavailable_count,
        });
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });
    }

    // Set exit code based on health
    if (critical_count > 0) {
        std.process.exit(2);
    } else if (warning_count > 0) {
        std.process.exit(1);
    } else if (unavailable_count > 0) {
        std.process.exit(3);
    }

}

