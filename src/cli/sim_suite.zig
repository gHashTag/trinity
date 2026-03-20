//! SIMULATION SUITE RUNNER — Parallel Evolution Scenarios
//!
//! Runs 5 parallel simulation scenarios to predict brain evolution:
//!   S1 Baseline — Ideal conditions (0% crash)
//!   S2 Current — 90% crash rate
//!   S3 Multi-obj — IGLA seeds injection
//!   S4 dePIN — Byzantine nodes + Microglia
//!   S5 dePIN No Immunity — Byzantine nodes only (shows effect of disabled immunity)
//!
//! Usage: tri-sim-suite [--steps N] [--output DIR]
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len > 1 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        printHelp();
        return;
    }

    var steps: u32 = 100;
    var output_dir: ?[]const u8 = null;

    // Parse args
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.startsWith(u8, args[i], "--steps=")) {
            const step_str = args[i]["--steps=".len..];
            steps = std.fmt.parseUnsigned(u32, step_str, 10) catch 100;
        } else if (std.mem.startsWith(u8, args[i], "--output=")) {
            output_dir = args[i]["--output=".len..];
        } else if (std.mem.eql(u8, args[i], "--version")) {
            print("tri-sim-suite v1.0 — Deterministic Brain Evolution Simulation\n", .{});
            return;
        }
    }

    // Create output directory if specified
    if (output_dir) |dir| {
        std.fs.cwd().makePath(dir) catch |err| {
            print("{s}Error creating output directory '{s}': {}{s}\n", .{ RED, dir, err, RESET });
            return error.OutputDirFailed;
        };
    }

    // Import evolution simulation
    const evo_sim = @import("brain").evolution_simulation;

    // Run all 5 scenarios
    print("\n{s}╔═══════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  DETERMINISTIC BRAIN EVOLUTION SIMULATION SUITE         ║{s}\n", .{ BOLD, RESET });
    print("{s}╚═══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });
    print("Running {d} scenarios in parallel...\n\n", .{6});

    // Run scenarios (note: Zig doesn't have true parallelism yet, so we run sequentially)
    var s1 = try evo_sim.runS1Baseline(allocator, steps);
    defer s1.deinit();
    print("  {s}✓{s} S1 Baseline complete: PPL={d:.2}, Diversity={d:.3}, Alive={d}\n", .{ GREEN, RESET, s1.final_ppl, s1.diversity_index, s1.workers_alive });

    var s2 = try evo_sim.runS2Current(allocator, steps);
    defer s2.deinit();
    const s2_status = if (s2.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s2.final_ppl});
    print("  {s}✓{s} S2 Current complete: PPL={s}, Alive={d}, Culled={d}\n", .{ GREEN, RESET, s2_status, s2.workers_alive, s2.workers_culled });

    var s3 = try evo_sim.runS3MultiObj(allocator, steps);
    defer s3.deinit();
    print("  {s}✓{s} S3 MultiObj complete: PPL={d:.2}, Diversity={d:.3}\n", .{ GREEN, RESET, s3.final_ppl, s3.diversity_index });

    var s4 = try evo_sim.runS4DePIN(allocator, steps);
    defer s4.deinit();
    const s4_status = if (s4.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s4.final_ppl});
    print("  {s}✓{s} S4 dePIN complete: PPL={s}, Alive={d}, Byzantine={d}\n", .{ GREEN, RESET, s4_status, s4.workers_alive, s4.byzantine_detected });

    var s5 = try evo_sim.runS5DePIN_NoImmunity(allocator, steps);
    defer s5.deinit();
    const s5_status = if (s5.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s5.final_ppl});
    print("  {s}✓{s} S5 dePIN NoImmunity complete: PPL={s}, Alive={d}, Byzantine={d}, NoMicroglia\n", .{ YELLOW, RESET, s5_status, s5.workers_alive, s5.byzantine_detected });

    var s6 = try evo_sim.runS6JEPA_Heavy(allocator, steps);
    defer s6.deinit();
    const s6_status = if (s6.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s6.final_ppl});
    print("  {s}✓{s} S6 JEPA-Heavy complete: PPL={s}, Alive={d}, Diversity={d:.3}, JEPA=35%\n", .{ MAGENTA, RESET, s6_status, s6.workers_alive, s6.diversity_index });

    print("\n{s}Simulation complete!{s}\n", .{ GREEN, RESET });

    // Write CSV if output directory specified
    if (output_dir) |dir| {
        const csv_path = try std.fmt.allocPrint(allocator, "{s}/simulation_results.csv", .{dir});
        const csv_file = try std.fs.cwd().createFile(csv_path, .{});
        defer csv_file.close();
        defer allocator.free(csv_path);

        // Enhanced CSV format for visualization and analysis
        try csv_file.writeAll("step,scenario_id,ppl,diversity,alive,culled,byzantine,converged,seed_rate,kill_rate\n");

        // Write data from all scenarios
        const s1_converged: u8 = if (s1.convergence_step != null) 1 else 0;
        for (s1.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d}\n", .{
                entry.step,          "S1",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s1.workers_culled, 0,             s1_converged,
                0.0,                 0.0,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }
        for (s2.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d}\n", .{
                entry.step,          "S2",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s2.workers_culled, 0,             0,
                0.90,                0.90,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }
        const s3_converged: u8 = if (s3.convergence_step != null) 1 else 0;
        for (s3.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d}\n", .{
                entry.step,          "S3",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s3.workers_culled, 0,             s3_converged,
                0.0,                 0.0,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }
        for (s4.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d}\n", .{
                entry.step,          "S4",              entry.avg_ppl,         entry.diversity,
                entry.alive_workers, s4.workers_culled, s4.byzantine_detected, 0,
                0.15,                0.15,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }
        for (s5.timeline) |entry| {
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d},{d}\n", .{
                entry.step,          "S5",              entry.avg_ppl,         entry.diversity,
                entry.alive_workers, s5.workers_culled, s5.byzantine_detected, 0,
                0.15,                0.15,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        print("{s}CSV written to {s}{s}\n", .{ CYAN, RESET, csv_path });
    }
}

fn printHelp() void {
    print("\n{s}SIMULATION SUITE RUNNER — Parallel Evolution Scenarios{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-suite [options]\n", .{});
    print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    print("  --steps=N     Number of evolution steps (default: 100)\n", .{});
    print("  --output=DIR  Write results to directory\n", .{});
    print("  --help, -h    Show this help\n", .{});
    print("  --version    Show version\n", .{});
    print("\n{s}Scenarios:{s}\n", .{ CYAN, RESET });
    print("  S1 Baseline   Ideal conditions (0% crash)\n", .{});
    print("  S2 Current    90% crash rate (current degradation)\n", .{});
    print("  S3 Multi-obj  IGLA seeds injection\n", .{});
    print("  S4 dePIN      Byzantine nodes + Microglia\n", .{});
    print("  S5 dePIN NoImmunity   Byzantine only (shows effect of disabled immunity)\n", .{});
    print("  S6 JEPA-Heavy  60% JEPA objective weight (objective selection impact)\n", .{});
    print("\n{s}Deterministic Seeds:{s}\n", .{ CYAN, RESET });
    print("  S1: 42    S2: 137    S3: 1618 (φ)    S4: 2718 (e)    S5: 3236 (φ²)\n", .{});
    print("  S6: 5242 (e³)\n", .{});
    print("\n", .{});
}
