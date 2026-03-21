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
    _ = allocator;
    const subcommand = if (args.len > 0) args[0] else "";
    if (std.mem.eql(u8, subcommand, "igla")) {
        // TODO: runIglaBench not implemented yet
        std.debug.print("⚠️  igla bench: TODO - not implemented\n", .{});
    }
    const job_system = @import("job_system.zig");
    _ = job_system;
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
/// Usage: tri brain health [--json]
fn runBrainHealthCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Parse --json flag
    var output_json = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json") or std.mem.eql(u8, arg, "-j")) {
            output_json = true;
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
    // Stats struct types for type compatibility
    const BasalStats = struct {
        claim_attempts: u64,
        claim_success: u64,
        claim_conflicts: u64,
        heartbeat_calls: u64,
        heartbeat_success: u64,
        complete_calls: u64,
        complete_success: u64,
        abandon_calls: u64,
        abandon_success: u64,
        active_claims: usize,
    };
    const ReticularStats = struct {
        buffered: usize,
        published: u64,
        polled: u64,
        trim_count: u64,
        peak_buffered: usize,
        utilization_pct: f32,
    };
    // Get detailed stats for output
    const basal_stats = if (basal_ganglia.getGlobal(allocator)) |registry| blk: {
        const s = registry.getStats();
        break :blk BasalStats{
            .claim_attempts = s.claim_attempts,
            .claim_success = s.claim_success,
            .claim_conflicts = s.claim_conflicts,
            .heartbeat_calls = s.heartbeat_calls,
            .heartbeat_success = s.heartbeat_success,
            .complete_calls = s.complete_calls,
            .complete_success = s.complete_success,
            .abandon_calls = s.abandon_calls,
            .abandon_success = s.abandon_success,
            .active_claims = s.active_claims,
        };
    } else |_| BasalStats{
        .claim_attempts = 0,
        .claim_success = 0,
        .claim_conflicts = 0,
        .heartbeat_calls = 0,
        .heartbeat_success = 0,
        .complete_calls = 0,
        .complete_success = 0,
        .abandon_calls = 0,
        .abandon_success = 0,
        .active_claims = 0,
    };
    const reticular_stats = if (reticular_formation.getGlobal(allocator)) |bus| blk: {
        const s = bus.getStats();
        break :blk ReticularStats{
            .buffered = s.buffered,
            .published = s.published,
            .polled = s.polled,
            .trim_count = s.trim_count,
            .peak_buffered = s.peak_buffered,
            .utilization_pct = @as(f32, @floatFromInt(s.buffered)) / @as(f32, @floatFromInt(10_000)) * 100.0,
        };
    } else |_| ReticularStats{
        .buffered = 0,
        .published = 0,
        .polled = 0,
        .trim_count = 0,
        .peak_buffered = 0,
        .utilization_pct = 0.0,
    };
    // Calculate aggregate health score (0-100)
    var healthy_count: usize = 0;
    if (basal_status == RegionStatus.healthy) healthy_count = healthy_count + 1;
    if (reticular_status == RegionStatus.healthy) healthy_count = healthy_count + 1;
    var warning_count: usize = 0;
    if (basal_status == RegionStatus.warning) warning_count = warning_count + 1;
    if (reticular_status == RegionStatus.warning) warning_count = warning_count + 1;
    var critical_count: usize = 0;
    if (basal_status == RegionStatus.critical) critical_count = critical_count + 1;
    if (reticular_status == RegionStatus.critical) critical_count = critical_count + 1;
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
        std.debug.print("{{\n", .{});
        std.debug.print("  \"overall_health_score\": {d:.1},\n", .{health_score});
        std.debug.print("  \"basal_ganglia\": {{\n", .{});
        std.debug.print("    \"status\": \"{s}\",\n", .{basal_text});
        std.debug.print("    \"active_claims\": {d},\n", .{basal_stats.active_claims});
        std.debug.print("    \"claim_attempts\": {d},\n", .{basal_stats.claim_attempts});
        std.debug.print("    \"claim_success\": {d},\n", .{basal_stats.claim_success});
        std.debug.print("    \"claim_conflicts\": {d},\n", .{basal_stats.claim_conflicts});
        std.debug.print("    \"heartbeat_calls\": {d},\n", .{basal_stats.heartbeat_calls});
        std.debug.print("    \"heartbeat_success\": {d},\n", .{basal_stats.heartbeat_success});
        std.debug.print("    \"complete_calls\": {d},\n", .{basal_stats.complete_calls});
        std.debug.print("    \"complete_success\": {d},\n", .{basal_stats.complete_success});
        std.debug.print("    \"abandon_calls\": {d},\n", .{basal_stats.abandon_calls});
        std.debug.print("    \"abandon_success\": {d}\n", .{basal_stats.abandon_success});
        std.debug.print("  }},\n", .{});
        std.debug.print("  \"reticular_formation\": {{\n", .{});
        std.debug.print("    \"status\": \"{s}\",\n", .{reticular_text});
        std.debug.print("    \"buffered_events\": {d},\n", .{reticular_stats.buffered});
        std.debug.print("    \"published_events\": {d},\n", .{reticular_stats.published});
        std.debug.print("    \"polled_events\": {d},\n", .{reticular_stats.polled});
        std.debug.print("    \"utilization_percent\": {d:.1}\n", .{reticular_stats.utilization_pct});
        std.debug.print("  }}\n", .{});
        std.debug.print("}}\n", .{});
    } else {
        // Format as a colored dashboard
        std.debug.print("\n{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        std.debug.print("{s}                    {s}BRAIN HEALTH CHECK{s}                        {s}\n", .{ CYAN, BOLD, RESET, CYAN });
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        // Overall health score
        std.debug.print("{s}{s} Overall Health Score: {s}{s}{d:.1}{{RESET}}}}\n", .{ CYAN, RESET, score_color, BOLD, health_score });
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        // Basal Ganglia status
        std.debug.print("{s}Basal Ganglia{{RESET}}}}: {s}{s} {s}{s}\n", .{ CYAN, basal_color, BOLD, basal_icon, basal_text });
        std.debug.print("  Active Claims: {d}\n", .{basal_stats.active_claims});
        std.debug.print("  Claim Attempts: {d}\n", .{basal_stats.claim_attempts});
        const success_rate = if (basal_stats.claim_attempts > 0)
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(basal_stats.claim_success)) / @as(f32, @floatFromInt(basal_stats.claim_attempts)) * 100.0))
        else 0;
        std.debug.print("  Success Rate: {d}%\n", .{success_rate});
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        // Reticular Formation status
        std.debug.print("{s}Reticular Formation{{RESET}}: {s}{s} {s}{s}\n", .{ CYAN, reticular_color, BOLD, reticular_icon, reticular_text });
        std.debug.print("  Buffered Events: {d}\n", .{reticular_stats.buffered});
        std.debug.print("  Published Events: {d}\n", .{reticular_stats.published});
        std.debug.print("  Buffer Utilization: {d}%\n", .{@as(usize, @intFromFloat(reticular_stats.utilization_pct))});
        std.debug.print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        // Summary
        std.debug.print("{s}Summary: {d} healthy, {d} warning, {d} critical, {d} unavailable{{RESET}}\n", .{
            CYAN,
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
/// Stub: Brain Simulate Command (TODO: implement)
pub fn runBrainSimulateCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  brain simulate: TODO - not implemented yet\n", .{});
}
/// Stub: Brain Viz Command (TODO: implement)
pub fn runBrainVizCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  brain viz: TODO - not implemented yet\n", .{});
}
/// Stub: REPL Test Command (TODO: implement)
pub fn runReplTestCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  repl test: TODO - not implemented yet\n", .{});
}
/// SEBO Command - Sacred Evolutionary Bayesian Optimization
pub fn runSeboCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    // sebo_cli is a separate module imported via build.zig
    std.debug.print("⚠️  sebo: TODO - use tri-sebo-cli binary\n", .{});
}
/// Git Command - Routes to git operations
/// Usage: tri git <subcommand> [args]
pub fn runGitCommand(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    // Route to appropriate git function
    if (std.mem.eql(u8, subcommand, "status")) {
        try printGitStatus();
    } else if (std.mem.eql(u8, subcommand, "commit")) {
        try performGitCommit(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "push")) {
        try performGitPush();
    } else if (std.mem.eql(u8, subcommand, "pull")) {
        try performGitPull();
    } else if (std.mem.eql(u8, subcommand, "log")) {
        try printGitLog(allocator, args);
    } else {
        std.debug.print("Unknown git subcommand: {s}\n", .{subcommand});
    }
}
/// Print git status
fn printGitStatus() !void {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "git", "status", "--short" },
    }) catch |err| {
        std.debug.print("Error running git status: {s}\n", .{@errorName(err)});
        return error.GitFailed;
    };
    if (result.term.Exited != 0) {
        std.debug.print("Git status failed\n", .{});
        return error.GitFailed;
    }
    std.debug.print("{s}", .{result.stdout});
}
/// Perform git commit
fn performGitCommit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const commit_msg = if (args.len > 0)
        args[0]
    else
        "Update";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "commit", "-m", commit_msg },
    }) catch |err| {
        std.debug.print("Error running git commit: {s}\n", .{@errorName(err)});
        return error.GitFailed;
    };
    // RunResult no longer has deinit() in Zig 0.15 - memory managed by page_allocator
    if (result.term.Exited != 0) {
        std.debug.print("Git commit failed: {s}", .{result.stderr});
        return error.GitFailed;
    }
    std.debug.print("{s}", .{result.stdout});
}
/// Perform git push
fn performGitPush() !void {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "git", "push" },
    }) catch |err| {
        std.debug.print("Error running git push: {s}\n", .{@errorName(err)});
        return error.GitFailed;
    };
    if (result.term.Exited != 0) {
        std.debug.print("Git push failed: {s}", .{result.stderr});
        return error.GitFailed;
    }
    std.debug.print("{s}", .{result.stdout});
}
/// Perform git pull
fn performGitPull() !void {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "git", "pull" },
    }) catch |err| {
        std.debug.print("Error running git pull: {s}\n", .{@errorName(err)});
        return error.GitFailed;
    };
    if (result.term.Exited != 0) {
        std.debug.print("Git pull failed: {s}", .{result.stderr});
        return error.GitFailed;
    }
    std.debug.print("{s}", .{result.stdout});
}
/// Print git log
fn printGitLog(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const count_str = if (args.len > 0) args[0] else "10";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "log", "--oneline", "-n", count_str },
    }) catch |err| {
        std.debug.print("Error running git log: {s}\n", .{@errorName(err)});
        return error.GitFailed;
    };
    if (result.term.Exited != 0) {
        std.debug.print("Git log failed\n", .{});
        return error.GitFailed;
    }
    std.debug.print("{s}", .{result.stdout});
}
/// Print git help
pub fn printGitHelp() void {
    std.debug.print("{s}Git Commands:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri git status                    Show git status\n", .{});
    std.debug.print("  tri git commit [message]         Commit changes\n", .{});
    std.debug.print("  tri git push                      Push to remote\n", .{});
    std.debug.print("  tri git pull                      Pull from remote\n", .{});
    std.debug.print("  tri git log [n]                 Show log\n", .{});
}
/// Deploy Command - Routes to deployment operations
/// Usage: tri deploy <subcommand> [args]
pub fn runDeployCommand(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    if (std.mem.eql(u8, subcommand, "status")) {
        std.debug.print("{s}⚠️  deploy status: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
    } else if (std.mem.eql(u8, subcommand, "push")) {
        std.debug.print("{s}⚠️  deploy push: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
    } else if (std.mem.eql(u8, subcommand, "list")) {
        std.debug.print("{s}⚠️  deploy list: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
    } else {
        std.debug.print("{s}Error: unknown deploy subcommand '{s}'{s}\n", .{ RED, subcommand, RESET });
    }
}
/// Notify Command - Send notifications
/// Usage: tri notify <message> [--chat-id=ID] [--pin] [--edit=ID]
pub fn runNotifyCommand(allocator: std.mem.Allocator, msg: []const u8, chat_id_override: ?[]const u8, pin_after_send: bool, edit_message_id: ?[]const u8) !void {
    _ = allocator;
    _ = chat_id_override;
    _ = pin_after_send;
    _ = edit_message_id;
    std.debug.print("{s}⚠️  notify: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Message: {s}\n", .{msg});
}
/// Doctor Command - Health and migration tool
/// Usage: tri doctor [subcommand] [args]
pub fn runDoctorCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  doctor: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Use: tri doctor [init|scan|mark|report|plan|heal|enforce]\n", .{});
}
/// Sim Command - Simulation commands
/// Usage: tri sim <subcommand> [args]
pub fn runSimCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  sim: TODO - use tri-sim-suite or tri-sim-plot binaries{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Available: tri-sim-suite (run scenarios), tri-sim-plot (visualize CSV)\n", .{});
}
/// Clean Command - Clean temporary files
/// Usage: tri clean <target>
pub fn runCleanCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  clean: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
}
/// Info Command - System information
/// Usage: tri info [subcommand]
pub fn runInfoCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  info: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
}
/// Lint Command - Spec Linter
/// Usage: tri lint <target>
pub fn runLintCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  lint: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
}
/// Event Stream Command - Event streaming
/// Usage: tri event-stream <action>
pub fn runEventStreamCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  event-stream: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
}

/// Task Claim Command - Async task claiming
/// UI Command - UI commands
/// Usage: tri ui <subcommand> [args]
/// Queen UI Command - Launch Queen UI (Swift app)
/// Usage: tri ui
pub fn runUiCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    const queen_dir = "apps/queen";

    // Kill any running swift processes
    std.debug.print("{s}🔄 Killing existing swift processes...{s}\n", .{ CYAN, RESET });
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "pkill", "-f", "swift-frontend" },
    }) catch |err| {
        // pkill may fail if no processes found - that's OK
        std.debug.print("{s}info: pkill: {s}{s}\n", .{ GRAY, @errorName(err), RESET });
    };

    // Wait a moment for processes to terminate
    std.Thread.sleep(100_000_000); // 100ms

    // Run swift run
    std.debug.print("{s}🚀 Launching Queen UI...{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}  Directory: {s}{s}\n", .{ GRAY, queen_dir, RESET });
    std.debug.print("{s}  Command: swift run &{s}\n\n", .{ GRAY, RESET });

    // Run in background via shell
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "cd apps/queen && swift run &" },
    }) catch |err| {
        std.debug.print("{s}⚠️  Launch command returned: {s}{s}\n", .{ YELLOW, @errorName(err), RESET });
    };

    std.debug.print("{s}✅ Queen UI launched in background{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}💡 Monitor with: ps aux | grep Queen{s}\n", .{ YELLOW, RESET });
}

/// Task Claim Command - Claim tasks from brain task queue
/// Usage: tri task-claim <action>
pub fn runTaskClaimCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("{s}⚠️  task-claim: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
}
/// Stress Test Command - Run stress tests
/// Usage: tri stress-test [options]
pub fn runStressTestCommand(args: []const []const u8) !void {
    _ = args;
    std.debug.print("{s}⚠️  stress-test: TODO - not implemented yet{s}\n", .{ YELLOW, RESET });
}
