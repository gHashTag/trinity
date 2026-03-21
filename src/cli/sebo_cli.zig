//! SEBO CLI — Sacred Evolutionary Bayesian Optimization
//!
//! Hyperparameter search for brain evolution using Sacred constants as priors.
//!
//! Usage: tri-sebo run [--generations N] [--population N] [--steps N]
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
// brain module is provided by build.zig as a module import
const brain = @import("brain");

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

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2 or std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        printHelp();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "run")) {
        try runSebo(allocator, args);
    } else if (std.mem.eql(u8, command, "--version")) {
        print("tri-sebo v1.0 — Sacred Evolutionary Bayesian Optimization\n", .{});
    } else {
        print("{s}Error: unknown command '{s}'{s}\n", .{ RED, command, RESET });
        print("Run '{s}--help{s}' for usage.\n", .{ CYAN, RESET });
        return error.UnknownCommand;
    }
}

fn runSebo(allocator: Allocator, args: []const []const u8) !void {
    // Import SEBO
    const sebo = brain.sebo;

    // Parse args
    var generations: u32 = 10;
    var population: u32 = 10;
    var steps: u32 = 100;
    var use_simulation: bool = false;

    for (args[2..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--generations=")) {
            const val = arg["--generations=".len..];
            generations = std.fmt.parseUnsigned(u32, val, 10) catch generations;
        } else if (std.mem.startsWith(u8, arg, "--population=")) {
            const val = arg["--population=".len..];
            population = std.fmt.parseUnsigned(u32, val, 10) catch population;
        } else if (std.mem.startsWith(u8, arg, "--steps=")) {
            const val = arg["--steps=".len..];
            steps = std.fmt.parseUnsigned(u32, val, 10) catch steps;
        } else if (std.mem.eql(u8, arg, "--use-simulation")) {
            use_simulation = true;
        }
    }

    print("\n{s}╔═══════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  SACRED EVOLUTIONARY BAYESIAN OPTIMIZATION           ║{s}\n", .{ BOLD, RESET });
    print("{s}╚═══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    print("{s}Configuration:{s}\n", .{ YELLOW, RESET });
    print("  Generations: {d}\n", .{generations});
    print("  Population:  {d}\n", .{population});
    print("  Steps:       {d}\n", .{steps});
    print("  Mode:        {s}{s}\n", .{ if (use_simulation) GREEN else YELLOW, if (use_simulation) "Real Simulation" else "Synthetic (Fast)" });
    print("\n", .{});

    // SEBO configuration
    const config = sebo.SeboConfig{
        .population_size = population,
        .generations = generations,
        .steps = steps,
        .use_simulation = use_simulation,
        .mutation_rate = 0.1,
        .crossover_rate = 0.7,
        .elitism = 2,
    };

    // Initialize optimizer
    var optimizer = try sebo.SeboOptimizer.init(allocator, config);
    defer optimizer.deinit();

    print("{s}Starting optimization...{s}\n\n", .{ GREEN, RESET });

    // Run optimization
    try optimizer.run();

    // Get best result
    const best = optimizer.getBest();

    print("\n{s}═════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    print("{s}OPTIMIZATION COMPLETE{s}\n\n", .{ BOLD, RESET });

    print("{s}Best Hyperparameters:{s}\n", .{ YELLOW, RESET });
    print("  NTP Weight:      {d:.3}\n", .{@as(f64, best.config.ntp_weight)});
    print("  JEPA Weight:     {d:.3}\n", .{@as(f64, best.config.jepa_weight)});
    print("  NCA Weight:      {d:.3}\n", .{@as(f64, best.config.nca_weight)});
    print("  Workers:         {d}\n", .{best.config.workers});
    print("  Kill Threshold: {d:.3}\n\n", .{@as(f64, best.config.kill_threshold)});

    print("{s}Best Objectives:{s}\n", .{ YELLOW, RESET });
    print("  PPL:         {d:.2}\n", .{@as(f64, best.objectives.ppl)});
    print("  Diversity:   {d:.3}\n", .{@as(f64, best.objectives.diversity)});
    print("  FPGA Cost:   {d:.3}\n", .{@as(f64, best.objectives.fpga_cost)});
    print("  Fitness:     {d:.4}\n\n", .{@as(f64, best.fitness)});

    print("{s}Sacred Priors Used:{s}\n", .{ YELLOW, RESET });
    print("  PHI (φ):         {d:.6}\n", .{@as(f64, sebo.SACRED_PRIORS.PHI)});
    print("  E:               {d:.6}\n", .{@as(f64, sebo.SACRED_PRIORS.E)});
    print("  PI (π):          {d:.6}\n", .{@as(f64, sebo.SACRED_PRIORS.PI)});
    print("  PHI_INVERSE:     {d:.6}\n", .{@as(f64, sebo.SACRED_PRIORS.PHI_INVERSE)});
    print("\n", .{});

    // Show Sacred identity
    const phi_squared = sebo.SACRED_PRIORS.PHI * sebo.SACRED_PRIORS.PHI;
    const phi_inv_sq = sebo.SACRED_PRIORS.PHI_INVERSE * sebo.SACRED_PRIORS.PHI_INVERSE;
    print("{s}Trinity Identity:{s} φ² + 1/φ² = {d:.6} + {d:.6} = {d:.1} = TRINITY\n\n", .{
        MAGENTA, RESET, phi_squared, phi_inv_sq, phi_squared + phi_inv_sq,
    });
}

fn printHelp() void {
    print("\n{s}SEBO CLI — Sacred Evolutionary Bayesian Optimization{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    print("  tri-sebo run [options]\n", .{});
    print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    print("  --generations=N  Number of generations (default: 10)\n", .{});
    print("  --population=N   Population size (default: 10)\n", .{});
    print("  --steps=N        Simulation steps per evaluation (default: 100)\n", .{});
    print("  --use-simulation Use real evolution simulation (slower, accurate)\n", .{});
    print("  --help, -h       Show this help\n", .{});
    print("  --version        Show version\n", .{});
    print("\n{s}Description:{s}\n", .{ CYAN, RESET });
    print("  SEBO optimizes brain evolution hyperparameters using Sacred\n", .{});
    print("  constants (φ, e, π) as Bayesian priors. Multi-objective optimization\n", .{});
    print("  minimizes PPL and FPGA cost while maximizing diversity.\n", .{});
    print("\n  {s}Modes:{s}\n", .{ YELLOW, RESET });
    print("  Synthetic (default): Fast evaluation using formulas\n", .{});
    print("  Real (--use-simulation): Slow, uses full evolution simulation\n", .{});
    print("\n{s}Sacred Identity:{s}\n", .{ CYAN, RESET });
    print("  φ² + 1/φ² = 3 = TRINITY\n", .{});
    print("  where φ = (1 + √5) / 2 ≈ 1.618034\n", .{});
    print("\n", .{});
}
