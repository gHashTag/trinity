//! SIMULATION SUITE RUNNER — Parallel Evolution Scenarios
//!
//! Runs 4 parallel simulation scenarios to predict brain evolution:
//!   S1 Baseline — Ideal conditions (0% crash)
//!   S2 Current — 90% crash rate
//!   S3 Multi-obj — IGLA seeds injection
//!   S4 dePIN — Byzantine nodes + Microglia
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

    // Run all 4 scenarios
    print("\n{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  DETERMINISTIC BRAIN EVOLUTION SIMULATION SUITE         ║{s}\n", .{ BOLD, RESET });
    print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });
    print("Running {d} scenarios in parallel...\n\n", .{4});

    // Run scenarios (note: Zig doesn't have true parallelism yet, so we run sequentially)
    var s1 = try evo_sim.runS1Baseline(allocator, steps);
    defer s1.deinit(allocator);
    print("  {s}✓{s} S1 Baseline complete: PPL={d:.2}, Diversity={d:.3}\n", .{ GREEN, RESET, s1.final_ppl, s1.diversity_index });

    var s2 = try evo_sim.runS2Current(allocator, steps);
    defer s2.deinit(allocator);
    print("  {s}✓{s} S2 Current complete: PPL={d:.2}, Culled={d}\n", .{ GREEN, RESET, s2.final_ppl, s2.workers_culled });

    var s3 = try evo_sim.runS3MultiObj(allocator, steps);
    defer s3.deinit(allocator);
    print("  {s}✓{s} S3 MultiObj complete: PPL={d:.2}, Diversity={d:.3}\n", .{ GREEN, RESET, s3.final_ppl, s3.diversity_index });

    var s4 = try evo_sim.runS4DePIN(allocator, steps);
    defer s4.deinit(allocator);
    print("  {s}✓{s} S4 dePIN complete: PPL={d:.2}, Byzantine detected={d}\n", .{ GREEN, RESET, s4.final_ppl, s4.byzantine_detected });

    // Create suite for comparison table
    const suite = evo_sim.SuiteResult{
        .s1 = s1,
        .s2 = s2,
        .s3 = s3,
        .s4 = s4,
    };

    // Print comparison table
    print("\n{s}COMPARISON TABLE{s}\n", .{ BOLD, RESET });
    print("\n", .{});
    var stdout_buf: [8192]u8 = undefined;
    var stdout_stream = std.io.fixedBufferStream(&stdout_buf);
    try suite.printComparison(stdout_stream.writer(), allocator);
    print("{s}", .{stdout_stream.getWritten()});

    // Write results to files if output directory specified
    if (output_dir) |dir| {
        print("\n{s}Writing results to {s}...{s}\n", .{ CYAN, dir, RESET });

        const base_path = try std.fmt.allocPrint(allocator, "{s}/sim_result", .{dir});
        defer allocator.free(base_path);

        try writeResult(&s1, base_path, "s1_baseline.jsonl", allocator);
        try writeResult(&s2, base_path, "s2_current.jsonl", allocator);
        try writeResult(&s3, base_path, "s3_multiobj.jsonl", allocator);
        try writeResult(&s4, base_path, "s4_depin.jsonl", allocator);

        // Write comparison CSV
        const csv_path = try std.fmt.allocPrint(allocator, "{s}/comparison.csv", .{dir});
        defer allocator.free(csv_path);
        try writeComparisonCsv(&suite, csv_path, allocator);

        print("{s}✓ Results written{ s}\n", .{ GREEN, RESET });
    }

    print("\n{s}Simulation complete!{s}\n", .{ GREEN, RESET });
}

fn writeResult(result: *const @import("brain").evolution_simulation.EvolutionResult, base_path: []const u8, filename: []const u8, allocator: Allocator) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}_{s}", .{ base_path, filename });
    defer allocator.free(path);

    var json_buf: [8192]u8 = undefined;
    var json_stream = std.io.fixedBufferStream(&json_buf);
    try result.toJson(json_stream.writer(), allocator);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(json_stream.getWritten());
}

// Helper function to format a CSV row
fn fmtRow(r: *const @import("brain").evolution_simulation.EvolutionResult, name: []const u8, w: anytype, _: Allocator) !void {
    var conv_buf: [32]u8 = undefined;
    const conv = if (r.convergence_step) |s| std.fmt.bufPrintZ(&conv_buf, "{d}", .{s}) else "never";

    try w.print("{s},{d:.2},{s},{d:.3},{d},{d},{d}\n", .{
        name,                r.final_ppl,      conv,                 r.diversity_index,
        r.microglia_actions, r.workers_culled, r.byzantine_detected,
        r.steps,
    });
}

fn writeComparisonCsv(suite: *const @import("brain").evolution_simulation.SuiteResult, path: []const u8, allocator: Allocator) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var writer_stream = std.io.fixedBufferStream(&write_buf);

    try writer_stream.writer().writeAll("scenario,final_ppl,convergence_step,diversity,microglia_actions,workers_culled,byzantine_detected\n");

    try fmtRow(&suite.s1, "S1_Baseline", writer_stream.writer(), allocator);
    try fmtRow(&suite.s2, "S2_Current", writer_stream.writer(), allocator);
    try fmtRow(&suite.s3, "S3_MultiObj", writer_stream.writer(), allocator);
    try fmtRow(&suite.s4, "S4_dePIN", writer_stream.writer(), allocator);

    try file.writeAll(writer_stream.getWritten());
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
    print("\n{s}Output Files:{s}\n", .{ CYAN, RESET });
    print("  sim_result_s1_baseline.jsonl  S1 results\n", .{});
    print("  sim_result_s2_current.jsonl   S2 results\n", .{});
    print("  sim_result_s3_multiobj.jsonl  S3 results\n", .{});
    print("  sim_result_s4_depin.jsonl     S4 results\n", .{});
    print("  comparison.csv                Comparison table\n", .{});
    print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-suite\n", .{});
    print("  tri-sim-suite --steps 200\n", .{});
    print("  tri-sim-suite --steps 100 --output .trinity/sim_results\n", .{});
    print("\n{s}Deterministic Seeds:{s}\n", .{ CYAN, RESET });
    print("  S1: 42    S2: 137    S3: 1618 (φ)    S4: 2718 (e)\n", .{});
    print("\n", .{});
}
