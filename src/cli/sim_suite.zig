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

    // Run all 20 scenarios
    print("\n{s}╔═══════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  DETERMINISTIC BRAIN EVOLUTION SIMULATION SUITE         ║{s}\n", .{ BOLD, RESET });
    print("{s}╚═══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });
    print("Running {d} scenarios in parallel...\n\n", .{20});

    // Run scenarios (note: Zig doesn't have true parallelism yet, so we run sequentially)
    // Quantum metrics for non-quantum scenarios (S1-S15) — set to 0.0
    const q_superpos: f32 = 0.0;
    const q_coherence: f32 = 0.0;
    const q_interference: f32 = 0.0;
    const q_collapse: f32 = 0.0;

    var s1 = try evo_sim.runS1Baseline(allocator, steps);
    defer s1.deinit(allocator);
    print("  {s}✓{s} S1 Baseline complete: PPL={d:.2}, Diversity={d:.3}, Alive={d}\n", .{ GREEN, RESET, s1.final_ppl, s1.diversity_index, s1.workers_alive });

    var s2 = try evo_sim.runS2Current(allocator, steps);
    defer s2.deinit(allocator);
    const s2_status = if (s2.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s2.final_ppl});
    print("  {s}✓{s} S2 Current complete: PPL={s}, Alive={d}, Culled={d}\n", .{ GREEN, RESET, s2_status, s2.workers_alive, s2.workers_culled });

    var s3 = try evo_sim.runS3MultiObj(allocator, steps);
    defer s3.deinit(allocator);
    print("  {s}✓{s} S3 MultiObj complete: PPL={d:.2}, Diversity={d:.3}\n", .{ GREEN, RESET, s3.final_ppl, s3.diversity_index });

    var s4 = try evo_sim.runS4DePIN(allocator, steps);
    defer s4.deinit(allocator);
    const s4_status = if (s4.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s4.final_ppl});
    print("  {s}✓{s} S4 dePIN complete: PPL={s}, Alive={d}, Byzantine={d}\n", .{ GREEN, RESET, s4_status, s4.workers_alive, s4.byzantine_detected });

    var s5 = try evo_sim.runS5DePIN_NoImmunity(allocator, steps);
    defer s5.deinit(allocator);
    const s5_status = if (s5.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s5.final_ppl});
    print("  {s}✓{s} S5 dePIN NoImmunity complete: PPL={s}, Alive={d}, Byzantine={d}, NoMicroglia\n", .{ YELLOW, RESET, s5_status, s5.workers_alive, s5.byzantine_detected });

    var s6 = try evo_sim.runS6JEPA_Heavy(allocator, steps);
    defer s6.deinit(allocator);
    const s6_status = if (s6.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s6.final_ppl});
    print("  {s}✓{s} S6 JEPA-Heavy complete: PPL={s}, Alive={d}, Diversity={d:.3}, JEPA=35%\n", .{ MAGENTA, RESET, s6_status, s6.workers_alive, s6.diversity_index });

    // Sacred v2 search scenarios (S7-S15)
    var s7 = try evo_sim.runS7HighDiversity(allocator, steps);
    defer s7.deinit(allocator);
    const s7_status = if (s7.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s7.final_ppl});
    print("  {s}✓{s} S7 High-Diversity complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s7_status, s7.workers_alive, s7.diversity_index });

    var s8 = try evo_sim.runS8LowCrash(allocator, steps);
    defer s8.deinit(allocator);
    const s8_status = if (s8.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s8.final_ppl});
    print("  {s}✓{s} S8 Low-Crash complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s8_status, s8.workers_alive, s8.diversity_index });

    var s9 = try evo_sim.runS9ByzantineHeavy(allocator, steps);
    defer s9.deinit(allocator);
    const s9_status = if (s9.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s9.final_ppl});
    print("  {s}✓{s} S9 Byzantine-Heavy complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ YELLOW, RESET, s9_status, s9.workers_alive, s9.diversity_index });

    var s10 = try evo_sim.runS10EnergyOptimal(allocator, steps);
    defer s10.deinit(allocator);
    const s10_status = if (s10.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s10.final_ppl});
    print("  {s}✓{s} S10 Energy-Optimal complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s10_status, s10.workers_alive, s10.diversity_index });

    var s11 = try evo_sim.runS11SacredA(allocator, steps);
    defer s11.deinit(allocator);
    const s11_status = if (s11.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s11.final_ppl});
    print("  {s}✓{s} S11 Sacred-A complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s11_status, s11.workers_alive, s11.diversity_index });

    var s12 = try evo_sim.runS12SacredB(allocator, steps);
    defer s12.deinit(allocator);
    const s12_status = if (s12.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s12.final_ppl});
    print("  {s}✓{s} S12 Sacred-B complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s12_status, s12.workers_alive, s12.diversity_index });

    var s13 = try evo_sim.runS13SacredC(allocator, steps);
    defer s13.deinit(allocator);
    const s13_status = if (s13.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s13.final_ppl});
    print("  {s}✓{s} S13 Sacred-C complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s13_status, s13.workers_alive, s13.diversity_index });

    var s14 = try evo_sim.runS14Wide(allocator, steps);
    defer s14.deinit(allocator);
    const s14_status = if (s14.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s14.final_ppl});
    print("  {s}✓{s} S14 Wide complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s14_status, s14.workers_alive, s14.diversity_index });

    var s15 = try evo_sim.runS15BaselineExtended(allocator, steps);
    defer s15.deinit(allocator);
    const s15_status = if (s15.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s15.final_ppl});
    print("  {s}✓{s} S15 Baseline-Extended complete: PPL={s}, Alive={d}, Diversity={d:.3}\n", .{ GREEN, RESET, s15_status, s15.workers_alive, s15.diversity_index });

    // Quantum-inspired scenarios (S16-S20)
    var s16 = try evo_sim.runS16Superposition(allocator, steps);
    defer s16.deinit(allocator);
    const s16_status = if (s16.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s16.final_ppl});
    print("  {s}✓{s} S16 Superposition complete: PPL={s}, Alive={d}, Diversity={d:.3}, Superposition\n", .{ GREEN, RESET, s16_status, s16.workers_alive, s16.diversity_index });

    var s17 = try evo_sim.runS17Coherence(allocator, steps);
    defer s17.deinit(allocator);
    const s17_status = if (s17.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s17.final_ppl});
    print("  {s}✓{s} S17 Coherence complete: PPL={s}, Alive={d}, Diversity={d:.3}, Coherence\n", .{ GREEN, RESET, s17_status, s17.workers_alive, s17.diversity_index });

    var s18 = try evo_sim.runS18Interference(allocator, steps);
    defer s18.deinit(allocator);
    const s18_status = if (s18.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s18.final_ppl});
    print("  {s}✓{s} S18 Interference complete: PPL={s}, Alive={d}, Diversity={d:.3}, Interference\n", .{ GREEN, RESET, s18_status, s18.workers_alive, s18.diversity_index });

    var s19 = try evo_sim.runS19Collapse(allocator, steps);
    defer s19.deinit(allocator);
    const s19_status = if (s19.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s19.final_ppl});
    print("  {s}✓{s} S19 Collapse complete: PPL={s}, Alive={d}, Diversity={d:.3}, Collapse\n", .{ GREEN, RESET, s19_status, s19.workers_alive, s19.diversity_index });

    var s20 = try evo_sim.runS20QuantumZeno(allocator, steps);
    defer s20.deinit(allocator);
    const s20_status = if (s20.workers_alive == 0) "DEAD" else try std.fmt.allocPrint(allocator, "{d:.2}", .{s20.final_ppl});
    print("  {s}✓{s} S20 Quantum-Zeno complete: PPL={s}, Alive={d}, Diversity={d:.3}, Quantum-Zeno\n", .{ GREEN, RESET, s20_status, s20.workers_alive, s20.diversity_index });

    print("\n{s}Simulation complete!{s}\n", .{ GREEN, RESET });

    // Write CSV if output directory specified
    if (output_dir) |dir| {
        const csv_path = try std.fmt.allocPrint(allocator, "{s}/simulation_results.csv", .{dir});
        const csv_file = try std.fs.cwd().createFile(csv_path, .{});
        defer csv_file.close();
        defer allocator.free(csv_path);

        // Enhanced CSV format for visualization and analysis (22 columns)
        // energy_cost calculated as: cumulative alive workers × step
        // fpga_cost_norm = (lut_ratio * 0.7 + bram_ratio * 0.3)
        // quantum_*: quantum-inspired metrics (superposition, coherence, interference, collapse)
        try csv_file.writeAll("step,scenario_id,ppl,diversity,alive,culled,byzantine,converged,energy_cost,fpga_lut,fpga_bram,fpga_cost_norm,seed_rate,kill_rate,ntp_weight,jepa_weight,nca_weight,quantum_superposition,quantum_coherence,quantum_interference,quantum_collapse_prob\n");

        // Helper to write timeline with energy cost, policy params, and quantum metrics
        const writeTimeline = struct {
            fn write(timeline: []const evo_sim.EvolutionResult.TimelineEntry, scenario: []const u8, alloc: Allocator, csv_out: std.fs.File, converged: u8, energy_cost: f32, fpga_lut: u16, fpga_bram: u8, fpga_cost: f32, seed_rate: f32, kill_rate: f32, ntp_weight: f32, jepa_weight: f32, nca_weight: f32, quantum_superposition: f32, quantum_coherence: f32, quantum_interference: f32, quantum_collapse_prob: f32) !void {
                for (timeline) |entry| {
                    // Calculate cumulative energy cost up to this step
                    const cum_energy = energy_cost * @as(f32, @floatFromInt(entry.step + 1));
                    const line = try std.fmt.allocPrint(alloc, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d:.2},{d},{d},{d:.3},{d:.3},{d:.1},{d:.2},{d:.2},{d:.2},{d:.3},{d:.3},{d:.3},{d:.3}\n", .{
                        entry.step,       scenario,       entry.avg_ppl, entry.diversity,
                        entry.alive_workers, 0,               0,             converged,
                        cum_energy,       fpga_lut,        fpga_bram,       fpga_cost,
                        seed_rate,        kill_rate,      ntp_weight,
                        jepa_weight,      nca_weight,    quantum_superposition,
                        quantum_coherence, quantum_interference, quantum_collapse_prob,
                    });
                    try csv_out.writeAll(line);
                    alloc.free(line);
                }
            }
        }.write;

        // Write data from all scenarios (S1-S20)
        // FPGA costs from docs/fpga_cost.md
        const s1_converged: u8 = if (s1.convergence_step != null) 1 else 0;
        try writeTimeline(s1.timeline, "S1", allocator, csv_file, s1_converged, 25.0 * 100.0, 8000, 30, 0.22, 0.0, s1.kill_threshold, 1.0, 0.0, 0.0, q_superpos, q_coherence, q_interference, q_collapse);

        // S2 uses special manual CSV because it has very high crash rate and culled workers
        for (s2.timeline) |entry| {
            const cum_energy = 102.0 * @as(f32, @floatFromInt(entry.step + 1));
            const line = try std.fmt.allocPrint(allocator, "{d},{s},{d:.3},{d:.3},{d},{d},{d},{d},{d:.2},{d},{d},{d:.3},{d:.3},{d:.1},{d:.2},{d:.2},{d:.2},{d:.3},{d:.3},{d:.3},{d:.3}\n", .{
                entry.step,       "S2",              entry.avg_ppl, entry.diversity,
                entry.alive_workers, s2.workers_culled, 0,             0,
                cum_energy,       19000,            100,            0.40,
                s2.crash_rate,    s2.kill_threshold, 1.0,
                0.0,              0.0,
                q_superpos,       q_coherence,       q_interference, q_collapse,
            });
            try csv_file.writeAll(line);
            allocator.free(line);
        }

        const s3_converged: u8 = if (s3.convergence_step != null) 1 else 0;
        try writeTimeline(s3.timeline, "S3", allocator, csv_file, s3_converged, 50.0 * 200.0, 14000, 50, 0.42, 0.05, s3.kill_threshold, 0.60, 0.15, 0.15, q_superpos, q_coherence, q_interference, q_collapse);

        const s4_converged: u8 = if (s4.convergence_step != null) 1 else 0;
        try writeTimeline(s4.timeline, "S4", allocator, csv_file, s4_converged, 100.0 * 300.0, 25000, 110, 0.50, s4.crash_rate, s4.kill_threshold, 0.50, 0.25, 0.25, q_superpos, q_coherence, q_interference, q_collapse);

        const s5_converged: u8 = if (s5.convergence_step != null) 1 else 0;
        try writeTimeline(s5.timeline, "S5", allocator, csv_file, s5_converged, 100.0 * 300.0, 25000, 110, 0.50, s5.crash_rate, s5.kill_threshold, 0.50, 0.25, 0.25, q_superpos, q_coherence, q_interference, q_collapse);

        const s6_converged: u8 = if (s6.convergence_step != null) 1 else 0;
        try writeTimeline(s6.timeline, "S6", allocator, csv_file, s6_converged, 100.0 * 300.0, 16000, 85, 0.46, s6.crash_rate, s6.kill_threshold, 0.35, 0.35, 0.30, q_superpos, q_coherence, q_interference, q_collapse);

        const s7_converged: u8 = if (s7.convergence_step != null) 1 else 0;
        try writeTimeline(s7.timeline, "S7", allocator, csv_file, s7_converged, 150.0 * 200.0, 15000, 60, 0.27, 0.03, s7.kill_threshold, 0.25, 0.25, 0.25, q_superpos, q_coherence, q_interference, q_collapse);

        const s8_converged: u8 = if (s8.convergence_step != null) 1 else 0;
        try writeTimeline(s8.timeline, "S8", allocator, csv_file, s8_converged, 80.0 * 400.0, 13000, 75, 0.20, 0.01, s8.kill_threshold, 0.70, 0.20, 0.10, q_superpos, q_coherence, q_interference, q_collapse);

        const s9_converged: u8 = if (s9.convergence_step != null) 1 else 0;
        try writeTimeline(s9.timeline, "S9", allocator, csv_file, s9_converged, 120.0 * 200.0, 16000, 85, 0.46, s9.crash_rate, s9.kill_threshold, 0.50, 0.30, 0.20, q_superpos, q_coherence, q_interference, q_collapse);

        const s10_converged: u8 = if (s10.convergence_step != null) 1 else 0;
        try writeTimeline(s10.timeline, "S10", allocator, csv_file, s10_converged, 60.0 * 100.0, 12000, 50, 0.15, 0.02, s10.kill_threshold, 0.80, 0.0, 0.0, q_superpos, q_coherence, q_interference, q_collapse);

        const s11_converged: u8 = if (s11.convergence_step != null) 1 else 0;
        try writeTimeline(s11.timeline, "S11", allocator, csv_file, s11_converged, 120.0 * 200.0, 25000, 80, 0.40, 0.03, s11.kill_threshold, 0.40, 0.40, 0.20, q_superpos, q_coherence, q_interference, q_collapse);

        const s12_converged: u8 = if (s12.convergence_step != null) 1 else 0;
        try writeTimeline(s12.timeline, "S12", allocator, csv_file, s12_converged, 120.0 * 300.0, 35000, 120, 0.50, 0.02, s12.kill_threshold, 0.35, 0.50, 0.15, q_superpos, q_coherence, q_interference, q_collapse);

        const s13_converged: u8 = if (s13.convergence_step != null) 1 else 0;
        try writeTimeline(s13.timeline, "S13", allocator, csv_file, s13_converged, 80.0 * 300.0, 15000, 90, 0.25, 0.02, s13.kill_threshold, 0.50, 0.30, 0.20, q_superpos, q_coherence, q_interference, q_collapse);

        const s14_converged: u8 = if (s14.convergence_step != null) 1 else 0;
        try writeTimeline(s14.timeline, "S14", allocator, csv_file, s14_converged, 100.0 * 300.0, 18000, 100, 0.30, 0.02, s14.kill_threshold, 0.60, 0.25, 0.15, q_superpos, q_coherence, q_interference, q_collapse);

        const s15_converged: u8 = if (s15.convergence_step != null) 1 else 0;
        try writeTimeline(s15.timeline, "S15", allocator, csv_file, s15_converged, 100.0 * 400.0, 18000, 100, 0.30, 0.02, s15.kill_threshold, 0.70, 0.20, 0.10, s15.quantum_superposition, s15.quantum_coherence, s15.quantum_interference, s15.quantum_collapse_prob);

        // Quantum scenarios S16-S20
        const s16_converged: u8 = if (s16.convergence_step != null) 1 else 0;
        try writeTimeline(s16.timeline, "S16", allocator, csv_file, s16_converged, 200.0 * 400.0, 20000, 200, 0.40, 0.0, s16.kill_threshold, 0.20, 0.20, 0.20, s16.quantum_superposition, s16.quantum_coherence, s16.quantum_interference, s16.quantum_collapse_prob);

        const s17_converged: u8 = if (s17.convergence_step != null) 1 else 0;
        try writeTimeline(s17.timeline, "S17", allocator, csv_file, s17_converged, 80.0 * 300.0, 15000, 90, 0.25, 0.0, s17.kill_threshold, 0.50, 0.30, 0.20, s17.quantum_superposition, s17.quantum_coherence, s17.quantum_interference, s17.quantum_collapse_prob);

        const s18_converged: u8 = if (s18.convergence_step != null) 1 else 0;
        try writeTimeline(s18.timeline, "S18", allocator, csv_file, s18_converged, 120.0 * 400.0, 18000, 120, 0.30, 0.02, s18.kill_threshold, 0.60, 0.25, 0.15, s18.quantum_superposition, s18.quantum_coherence, s18.quantum_interference, s18.quantum_collapse_prob);

        const s19_converged: u8 = if (s19.convergence_step != null) 1 else 0;
        try writeTimeline(s19.timeline, "S19", allocator, csv_file, s19_converged, 50.0 * 200.0, 12000, 50, 0.15, 0.02, s19.kill_threshold, 0.80, 0.0, 0.0, s19.quantum_superposition, s19.quantum_coherence, s19.quantum_interference, s19.quantum_collapse_prob);

        const s20_converged: u8 = if (s20.convergence_step != null) 1 else 0;
        try writeTimeline(s20.timeline, "S20", allocator, csv_file, s20_converged, 60.0 * 200.0, 12000, 60, 0.15, 0.02, s20.kill_threshold, 0.60, 0.20, 0.20, s20.quantum_superposition, s20.quantum_coherence, s20.quantum_interference, s20.quantum_collapse_prob);

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
    print("  S6 JEPA-Heavy  35% JEPA objective weight (objective selection impact)\n", .{});
    print("  S7 High-Diversity  5 objective types, max exploration\n", .{});
    print("  S8 Low-Crash  1% crash, resilience demo\n", .{});
    print("  S9 Byzantine-Heavy  20% Byzantine, stress test\n", .{});
    print("  S10 Energy-Optimal  60 workers, minimal cumulative energy\n", .{});
    print("  S11 Sacred-A  Many heads (27), small context\n", .{});
    print("  S12 Sacred-B  Many heads (27), large context (81)\n", .{});
    print("  S13 Sacred-C  Compact (162 dims), 27 heads\n", .{});
    print("  S14 Wide  Wide context (81), standard heads (9)\n", .{});
    print("  S15 Baseline-Extended  Current Trinity, 4× training\n", .{});
    print("  S16 Superposition  φ⁷×1000 seed — maximum strategy diversity\n", .{});
    print("  S17 Coherence  φ⁸×1000 seed — maximum learning agreement\n", .{});
    print("  S18 Interference  φ⁹×1000 seed — constructive pattern interference\n", .{});
    print("  S19 Collapse  φ¹⁰×1000 seed — fast convergence to single state\n", .{});
    print("  S20 Quantum-Zeno  φ¹¹×1000 seed — frequent measurement blocks evolution\n", .{});
    print("\n{s}Deterministic Seeds:{s}\n", .{ CYAN, RESET });
    print("  S1: 42    S2: 137    S3: 1618 (φ)    S4: 2718 (e)    S5: 3236 (φ²)\n", .{});
    print("  S6: 5242 (e³)    S7: 8450 (φ³)    S8: 13692 (φ⁴)\n", .{});
    print("  S9: 22134 (φ⁵)   S10: 35780 (φ⁶)   S11-S15: sacred constants\n", .{});
    print("  S16-S20: φ⁷-φ¹¹ × 1000 (quantum-inspired seeds)\n", .{});
    print("\n", .{});
}
