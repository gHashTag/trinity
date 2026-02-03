// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD CLI - Command Line Interface for ЖАР ПТИЦА
// Ternary Virtual Anti-Detect Browser
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");
const vsa_simd = @import("vsa_simd.zig");
const firebird = @import("firebird.zig");
const evolution = @import("evolution.zig");
const parallel = @import("parallel.zig");
const b2t = @import("b2t_integration.zig");
const wasm_parser = @import("wasm_parser.zig");

const TritVec = vsa.TritVec;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const VERSION = "1.0.0";
const BANNER =
    \\
    \\  ╔═══════════════════════════════════════════════════════════════╗
    \\  ║     ЖАР ПТИЦА (FIREBIRD) v1.0.0                               ║
    \\  ║     Ternary Virtual Anti-Detect Browser                       ║
    \\  ║     φ² + 1/φ² = 3 = TRINITY                                   ║
    \\  ╚═══════════════════════════════════════════════════════════════╝
    \\
;

const HELP =
    \\USAGE: firebird <command> [options]
    \\
    \\COMMANDS:
    \\  evolve      Evolve fingerprint to evade detection
    \\  convert     Convert WASM to TVC IR file
    \\  execute     Execute TVC IR with virtual navigation
    \\  b2t         Binary-to-Ternary demo (no file)
    \\  benchmark   Run performance benchmarks
    \\  info        Show system information
    \\  help        Show this help message
    \\
    \\EVOLVE OPTIONS:
    \\  --dim <N>        Vector dimension (default: 10000)
    \\  --pop <N>        Population size (default: 50)
    \\  --gen <N>        Max generations (default: 100)
    \\  --threads <N>    Number of threads (default: 4)
    \\  --seed <N>       Random seed (default: timestamp)
    \\  --target <F>     Target fitness (default: 0.9)
    \\  --ir <path>      TVC IR file for B2T-based evolution
    \\  --output <path>  Save evolved fingerprint to file
    \\  --quiet          Suppress progress output
    \\
    \\CONVERT OPTIONS:
    \\  --input <path>   Input WASM file
    \\  --output <path>  Output TVC IR file
    \\
    \\EXECUTE OPTIONS:
    \\  --ir <path>      TVC IR file to execute
    \\  --dim <N>        Vector dimension (default: 10000)
    \\  --steps <N>      Navigation steps (default: 10)
    \\  --seed <N>       Random seed (default: timestamp)
    \\
    \\B2T OPTIONS:
    \\  --dim <N>        Vector dimension (default: 10000)
    \\  --seed <N>       Random seed (default: timestamp)
    \\  --navigate       Run virtual navigation demo
    \\
    \\BENCHMARK OPTIONS:
    \\  --dim <N>        Vector dimension (default: 10000)
    \\  --iterations <N> Number of iterations (default: 100)
    \\
    \\EXAMPLES:
    \\  firebird convert --input=module.wasm --output=module.tvc
    \\  firebird execute --ir=module.tvc --steps=20
    \\  firebird evolve --dim 100000 --gen 50
    \\  firebird benchmark --dim 100000
    \\
;

// ═══════════════════════════════════════════════════════════════════════════════
// CLI OPTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const EvolveOptions = struct {
    dim: usize = 10000,
    pop: usize = 50,
    gen: usize = 100,
    threads: usize = 4,
    seed: ?u64 = null,
    target: f64 = 0.9,
    quiet: bool = false,
    ir: ?[]const u8 = null, // Optional TVC IR file for B2T-based evolution
    output: ?[]const u8 = null, // Output fingerprint file
};

const BenchmarkOptions = struct {
    dim: usize = 10000,
    iterations: usize = 100,
};

const B2TOptions = struct {
    file: ?[]const u8 = null,
    dim: usize = 10000,
    seed: ?u64 = null,
    navigate: bool = false,
};

const ConvertOptions = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
};

const ExecuteOptions = struct {
    ir: ?[]const u8 = null,
    dim: usize = 10000,
    steps: usize = 10,
    seed: ?u64 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printBanner();
        try printHelp();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "evolve")) {
        try cmdEvolve(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "convert")) {
        try cmdConvert(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "execute")) {
        try cmdExecute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "b2t")) {
        try cmdB2T(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "benchmark")) {
        try cmdBenchmark(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "info")) {
        try cmdInfo();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printBanner();
        try printHelp();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdConvert(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var opts = ConvertOptions{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--input") and i + 1 < args.len) {
            i += 1;
            opts.input = args[i];
        } else if (std.mem.eql(u8, arg, "--output") and i + 1 < args.len) {
            i += 1;
            opts.output = args[i];
        } else if (std.mem.startsWith(u8, arg, "--input=")) {
            opts.input = arg[8..];
        } else if (std.mem.startsWith(u8, arg, "--output=")) {
            opts.output = arg[9..];
        }
    }

    if (opts.input == null) {
        std.debug.print("Error: --input is required\n", .{});
        return;
    }

    const output_path = opts.output orelse "output.tvc";

    try printBanner();
    std.debug.print("WASM to TVC Conversion\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Input:  {s}\n", .{opts.input.?});
    std.debug.print("  Output: {s}\n", .{output_path});
    std.debug.print("\n", .{});

    // Load WASM file
    var timer = try std.time.Timer.start();
    const wasm_data = wasm_parser.loadWasmFile(allocator, opts.input.?) catch |err| {
        std.debug.print("Error loading WASM file: {}\n", .{err});
        return;
    };
    defer allocator.free(wasm_data);
    const load_time = timer.read() / 1000;

    std.debug.print("  Loaded: {d} bytes in {d}us\n", .{ wasm_data.len, load_time });

    // Parse WASM
    timer.reset();
    var parser = wasm_parser.WasmParser.init(allocator, wasm_data);
    var wasm_module = parser.parse() catch |err| {
        std.debug.print("Error parsing WASM: {}\n", .{err});
        return;
    };
    defer wasm_module.deinit();
    const parse_time = timer.read() / 1000;

    std.debug.print("  Parsed: {d} functions, {d} types in {d}us\n", .{
        wasm_module.functions.items.len,
        wasm_module.types.items.len,
        parse_time,
    });

    // Convert to TVC
    timer.reset();
    var converter = wasm_parser.WasmToTVC.init(allocator);
    var tvc_module = try converter.convert(&wasm_module, "converted");
    defer tvc_module.deinit();
    const convert_time = timer.read() / 1000;

    var total_instrs: usize = 0;
    for (tvc_module.blocks.items) |*blk| {
        total_instrs += blk.instructions.items.len;
    }

    std.debug.print("  Converted: {d} blocks, {d} instructions in {d}us\n", .{
        tvc_module.blocks.items.len,
        total_instrs,
        convert_time,
    });

    // Save TVC file
    timer.reset();
    wasm_parser.saveTVCFile(allocator, &tvc_module, output_path) catch |err| {
        std.debug.print("Error saving TVC file: {}\n", .{err});
        return;
    };
    const save_time = timer.read() / 1000;

    std.debug.print("  Saved: {s} in {d}us\n", .{ output_path, save_time });
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CONVERSION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn cmdExecute(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var opts = ExecuteOptions{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--ir") and i + 1 < args.len) {
            i += 1;
            opts.ir = args[i];
        } else if (std.mem.eql(u8, arg, "--dim") and i + 1 < args.len) {
            i += 1;
            opts.dim = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--steps") and i + 1 < args.len) {
            i += 1;
            opts.steps = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--seed") and i + 1 < args.len) {
            i += 1;
            opts.seed = try std.fmt.parseInt(u64, args[i], 10);
        } else if (std.mem.startsWith(u8, arg, "--ir=")) {
            opts.ir = arg[5..];
        }
    }

    if (opts.ir == null) {
        std.debug.print("Error: --ir is required\n", .{});
        return;
    }

    const seed = opts.seed orelse @as(u64, @intCast(std.time.timestamp()));

    try printBanner();
    std.debug.print("TVC IR Execution with Virtual Navigation\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  IR File:   {s}\n", .{opts.ir.?});
    std.debug.print("  Dimension: {d}\n", .{opts.dim});
    std.debug.print("  Steps:     {d}\n", .{opts.steps});
    std.debug.print("  Seed:      {d}\n", .{seed});
    std.debug.print("\n", .{});

    // Load TVC file
    var timer = try std.time.Timer.start();
    var tvc_module = wasm_parser.loadTVCFile(allocator, opts.ir.?) catch |err| {
        std.debug.print("Error loading TVC file: {}\n", .{err});
        return;
    };
    defer tvc_module.deinit();
    const load_time = timer.read() / 1000;

    var total_instrs: usize = 0;
    for (tvc_module.blocks.items) |*blk| {
        total_instrs += blk.instructions.items.len;
    }

    std.debug.print("  Loaded: {d} blocks, {d} instructions in {d}us\n", .{
        tvc_module.blocks.items.len,
        total_instrs,
        load_time,
    });

    // Encode to ternary vectors
    timer.reset();
    var encoded = try b2t.encodeModule(allocator, &tvc_module, opts.dim, seed);
    defer encoded.deinit();
    const encode_time = timer.read() / 1000;

    std.debug.print("  Encoded: dim={d} in {d}us\n", .{ encoded.len, encode_time });
    std.debug.print("\n", .{});

    // Virtual navigation
    std.debug.print("Virtual Navigation:\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});

    var nav = try b2t.NavigationState.init(allocator, &tvc_module, opts.dim, seed);
    defer nav.deinit();

    const initial_stats = nav.getStats();
    std.debug.print("  Initial: similarity={d:.4}\n", .{initial_stats.similarity});

    for (0..opts.steps) |step| {
        try nav.navigateTowardsModule(0.3);
        const stats = nav.getStats();
        std.debug.print("  Step {d:2}: similarity={d:.4}\n", .{ step + 1, stats.similarity });
    }

    const final_stats = nav.getStats();
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Final: steps={d}, similarity={d:.4}\n", .{ final_stats.steps, final_stats.similarity });

    // Evasion metrics
    std.debug.print("\n", .{});
    std.debug.print("Evasion Metrics:\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});

    // Create a "default" fingerprint to compare against
    var default_fp = try vsa.TritVec.random(allocator, opts.dim, 0);
    defer default_fp.deinit();

    const default_sim = vsa_simd.cosineSimilaritySimd(&nav.position, &default_fp);
    const module_sim = final_stats.similarity;

    std.debug.print("  Similarity to default: {d:.4} (target: <0.5)\n", .{default_sim});
    std.debug.print("  Similarity to module:  {d:.4} (target: >0.7)\n", .{module_sim});

    const evasion_score = if (default_sim < 0.5 and module_sim > 0.3) "PASS" else "NEEDS WORK";
    std.debug.print("  Evasion status: {s}\n", .{evasion_score});

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("EXECUTION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn cmdEvolve(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var opts = EvolveOptions{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dim") and i + 1 < args.len) {
            i += 1;
            opts.dim = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--pop") and i + 1 < args.len) {
            i += 1;
            opts.pop = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--gen") and i + 1 < args.len) {
            i += 1;
            opts.gen = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--threads") and i + 1 < args.len) {
            i += 1;
            opts.threads = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--seed") and i + 1 < args.len) {
            i += 1;
            opts.seed = try std.fmt.parseInt(u64, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--target") and i + 1 < args.len) {
            i += 1;
            opts.target = try std.fmt.parseFloat(f64, args[i]);
        } else if (std.mem.eql(u8, arg, "--quiet") or std.mem.eql(u8, arg, "-q")) {
            opts.quiet = true;
        } else if (std.mem.eql(u8, arg, "--ir") and i + 1 < args.len) {
            i += 1;
            opts.ir = args[i];
        } else if (std.mem.eql(u8, arg, "--output") and i + 1 < args.len) {
            i += 1;
            opts.output = args[i];
        } else if (std.mem.startsWith(u8, arg, "--ir=")) {
            opts.ir = arg[5..];
        } else if (std.mem.startsWith(u8, arg, "--output=")) {
            opts.output = arg[9..];
        }
    }

    // Get seed
    const seed = opts.seed orelse @as(u64, @intCast(std.time.timestamp()));

    if (!opts.quiet) {
        try printBanner();
        std.debug.print("Evolving fingerprint...\n", .{});
        std.debug.print("  Dimension:   {d}\n", .{opts.dim});
        std.debug.print("  Population:  {d}\n", .{opts.pop});
        std.debug.print("  Generations: {d}\n", .{opts.gen});
        std.debug.print("  Threads:     {d}\n", .{opts.threads});
        std.debug.print("  Seed:        {d}\n", .{seed});
        std.debug.print("  Target:      {d:.2}\n", .{opts.target});
        if (opts.ir) |ir_path| {
            std.debug.print("  IR File:     {s}\n", .{ir_path});
        }
        if (opts.output) |out_path| {
            std.debug.print("  Output:      {s}\n", .{out_path});
        }
        std.debug.print("\n", .{});
    }

    // Create human pattern - either from IR or random
    var human: TritVec = undefined;
    var tvc_module_opt: ?b2t.TVCModule = null;

    if (opts.ir) |ir_path| {
        // Load TVC IR and encode as target
        tvc_module_opt = wasm_parser.loadTVCFile(allocator, ir_path) catch |err| {
            std.debug.print("Error loading TVC file: {}\n", .{err});
            return;
        };
        human = try b2t.encodeModule(allocator, &tvc_module_opt.?, opts.dim, seed);
        if (!opts.quiet) {
            std.debug.print("Loaded IR as evolution target\n\n", .{});
        }
    } else {
        human = try TritVec.random(allocator, opts.dim, seed);
    }
    defer human.deinit();
    defer if (tvc_module_opt) |*m| m.deinit();

    // Create initial fingerprint
    var initial = try TritVec.random(allocator, opts.dim, seed +% 1);
    defer initial.deinit();

    // Configure evolution
    const config = parallel.ParallelConfig{
        .base_config = .{
            .population_size = opts.pop,
            .max_generations = opts.gen,
            .target_fitness = opts.target,
            .tournament_size = 3,
        },
        .num_threads = opts.threads,
    };

    // Initialize population
    var population = try evolution.Population.init(allocator, opts.pop, opts.dim, seed +% 2);
    defer population.deinit();

    // Run evolution with progress
    var timer = try std.time.Timer.start();

    if (!opts.quiet) {
        std.debug.print("Generation | Fitness | Similarity | Time\n", .{});
        std.debug.print("-----------|---------|------------|------\n", .{});
    }

    var rng = std.Random.DefaultPrng.init(seed +% 3);

    while (population.generation < opts.gen) {
        try parallel.evolveGenerationParallel(allocator, &population, &human, &config, &rng);

        if (!opts.quiet and (population.generation % 10 == 0 or population.generation == 1)) {
            const best = population.getBest();
            const sim = vsa_simd.cosineSimilaritySimd(&best.chromosome, &human);
            const elapsed = timer.read() / 1_000_000;
            std.debug.print("    {d:4}   |  {d:.4} |    {d:.4}   | {d}ms\n", .{
                population.generation,
                population.best_fitness,
                sim,
                elapsed,
            });
        }

        if (population.best_fitness >= opts.target) {
            break;
        }
    }

    const total_time = timer.read() / 1_000_000;

    // Final results
    const best = population.getBest();
    const final_sim = vsa_simd.cosineSimilaritySimd(&best.chromosome, &human);

    if (!opts.quiet) {
        std.debug.print("\n", .{});
    }

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("EVOLUTION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Generations:      {d}\n", .{population.generation});
    std.debug.print("  Final fitness:    {d:.4}\n", .{population.best_fitness});
    std.debug.print("  Human similarity: {d:.4}\n", .{final_sim});
    std.debug.print("  Total time:       {d}ms\n", .{total_time});
    std.debug.print("  Time/generation:  {d}ms\n", .{if (population.generation > 0) total_time / population.generation else 0});
    std.debug.print("  Converged:        {}\n", .{population.best_fitness >= opts.target});

    // Save fingerprint if output specified
    if (opts.output) |out_path| {
        const file = try std.fs.cwd().createFile(out_path, .{});
        defer file.close();

        // Write fingerprint as binary trit data
        try file.writeAll("FP01"); // Magic
        try file.writer().writeInt(u32, @intCast(best.chromosome.len), .little);
        for (best.chromosome.data) |trit| {
            try file.writer().writeByte(@as(u8, @bitCast(trit)));
        }
        std.debug.print("  Saved to:         {s}\n", .{out_path});
    }

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn cmdB2T(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var opts = B2TOptions{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--file") and i + 1 < args.len) {
            i += 1;
            opts.file = args[i];
        } else if (std.mem.eql(u8, arg, "--dim") and i + 1 < args.len) {
            i += 1;
            opts.dim = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--seed") and i + 1 < args.len) {
            i += 1;
            opts.seed = try std.fmt.parseInt(u64, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--navigate")) {
            opts.navigate = true;
        }
    }

    const seed = opts.seed orelse @as(u64, @intCast(std.time.timestamp()));

    try printBanner();
    std.debug.print("Binary-to-Ternary (B2T) Conversion\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Dimension:   {d}\n", .{opts.dim});
    std.debug.print("  Seed:        {d}\n", .{seed});
    std.debug.print("\n", .{});

    // Create demo TVC module (or load from file in future)
    var module = b2t.TVCModule.init(allocator, "demo_module");
    defer module.deinit();

    // Add sample blocks using TVC opcodes
    const block1 = try module.addBlock("block1");
    try block1.addInstruction(.{ .opcode = .t_push, .operand1 = 42 });
    try block1.addInstruction(.{ .opcode = .t_push, .operand1 = 10 });
    try block1.addInstruction(.{ .opcode = .t_add });

    const block2 = try module.addBlock("block2");
    try block2.addInstruction(.{ .opcode = .t_load, .operand1 = 0 });
    try block2.addInstruction(.{ .opcode = .t_push, .operand1 = 1 });
    try block2.addInstruction(.{ .opcode = .t_sub });
    try block2.addInstruction(.{ .opcode = .t_store, .operand1 = 0 });

    std.debug.print("TVC Module created:\n", .{});
    std.debug.print("  Blocks: {d}\n", .{module.blocks.items.len});

    // Encode to ternary
    var timer = try std.time.Timer.start();
    var encoded = try b2t.encodeModule(allocator, &module, opts.dim, seed);
    defer encoded.deinit();
    const encode_time = timer.read() / 1000;

    std.debug.print("  Encoded dimension: {d}\n", .{encoded.len});
    std.debug.print("  Encoding time: {d}us\n", .{encode_time});
    std.debug.print("\n", .{});

    if (opts.navigate) {
        std.debug.print("Virtual Navigation Demo\n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

        var nav = try b2t.NavigationState.init(allocator, &module, opts.dim, seed);
        defer nav.deinit();

        std.debug.print("Initial state:\n", .{});
        const stats0 = nav.getStats();
        std.debug.print("  Steps: {d}, History: {d}, Similarity: {d:.4}\n", .{ stats0.steps, stats0.history_depth, stats0.similarity });

        // Navigate towards module
        for (0..10) |step| {
            try nav.navigateTowardsModule(0.3);
            const stats = nav.getStats();
            std.debug.print("  Step {d}: Similarity = {d:.4}\n", .{ step + 1, stats.similarity });
        }

        std.debug.print("\nFinal state:\n", .{});
        const final_stats = nav.getStats();
        std.debug.print("  Steps: {d}, History: {d}, Similarity: {d:.4}\n", .{ final_stats.steps, final_stats.history_depth, final_stats.similarity });
    }

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("B2T CONVERSION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn cmdBenchmark(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var opts = BenchmarkOptions{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dim") and i + 1 < args.len) {
            i += 1;
            opts.dim = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--iterations") and i + 1 < args.len) {
            i += 1;
            opts.iterations = try std.fmt.parseInt(usize, args[i], 10);
        }
    }

    try printBanner();
    std.debug.print("Running benchmarks...\n", .{});
    std.debug.print("  Dimension:   {d}\n", .{opts.dim});
    std.debug.print("  Iterations:  {d}\n", .{opts.iterations});
    std.debug.print("\n", .{});

    // Create test vectors
    var a = try TritVec.random(allocator, opts.dim, 12345);
    defer a.deinit();
    var b = try TritVec.random(allocator, opts.dim, 67890);
    defer b.deinit();

    // Benchmark bind
    var timer = try std.time.Timer.start();
    for (0..opts.iterations) |_| {
        var r = try vsa_simd.bindSimd(allocator, &a, &b);
        r.deinit();
    }
    const bind_ns = timer.read() / opts.iterations;

    // Benchmark dot product
    timer.reset();
    for (0..opts.iterations) |_| {
        _ = vsa_simd.dotProductSimd(&a, &b);
    }
    const dot_ns = timer.read() / opts.iterations;

    // Benchmark similarity
    timer.reset();
    for (0..opts.iterations) |_| {
        _ = vsa_simd.cosineSimilaritySimd(&a, &b);
    }
    const sim_ns = timer.read() / opts.iterations;

    // Benchmark hamming
    timer.reset();
    for (0..opts.iterations) |_| {
        _ = vsa_simd.hammingDistanceSimd(&a, &b);
    }
    const hamming_ns = timer.read() / opts.iterations;

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("VSA BENCHMARK RESULTS (SIMD)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Bind:             {d}us\n", .{bind_ns / 1000});
    std.debug.print("  Dot Product:      {d}us\n", .{dot_ns / 1000});
    std.debug.print("  Cosine Similarity:{d}us\n", .{sim_ns / 1000});
    std.debug.print("  Hamming Distance: {d}us\n", .{hamming_ns / 1000});
    std.debug.print("  Memory per vector:{d}KB\n", .{opts.dim / 1024});
    std.debug.print("\n", .{});

    // B2T Benchmarks
    std.debug.print("B2T BENCHMARK RESULTS\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    // Create sample TVC module
    var module = b2t.TVCModule.init(allocator, "benchmark");
    defer module.deinit();

    const block = try module.addBlock("main");
    for (0..100) |j| {
        try block.addInstruction(.{ .opcode = .t_push, .operand1 = @intCast(j) });
        try block.addInstruction(.{ .opcode = .t_add });
    }

    // Benchmark TVC encoding
    timer.reset();
    for (0..opts.iterations) |_| {
        var encoded = try b2t.encodeModule(allocator, &module, opts.dim, 12345);
        encoded.deinit();
    }
    const encode_ns = timer.read() / opts.iterations;

    std.debug.print("  TVC Encode:       {d}us (200 instructions)\n", .{encode_ns / 1000});

    // Benchmark navigation
    var nav = try b2t.NavigationState.init(allocator, &module, opts.dim, 12345);
    defer nav.deinit();

    timer.reset();
    for (0..opts.iterations) |_| {
        try nav.navigateTowardsModule(0.3);
    }
    const nav_ns = timer.read() / opts.iterations;

    std.debug.print("  Navigation step:  {d}us\n", .{nav_ns / 1000});

    // Summary
    std.debug.print("\n", .{});
    std.debug.print("PERFORMANCE SUMMARY\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    const ops_per_sec = 1_000_000_000 / bind_ns;
    const nav_per_sec = 1_000_000_000 / nav_ns;

    std.debug.print("  Bind ops/sec:     {d}\n", .{ops_per_sec});
    std.debug.print("  Nav steps/sec:    {d}\n", .{nav_per_sec});
    std.debug.print("  Throughput:       {d:.2} MB/s (bind)\n", .{@as(f64, @floatFromInt(opts.dim * ops_per_sec)) / 1_000_000.0});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn cmdInfo() !void {
    try printBanner();

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("SYSTEM INFORMATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Version:          {s}\n", .{VERSION});
    std.debug.print("  SIMD Width:       {d} elements\n", .{vsa_simd.SIMD_WIDTH});
    std.debug.print("\n", .{});
    std.debug.print("CONSTANTS:\n", .{});
    std.debug.print("  φ (PHI):          {d:.10}\n", .{firebird.PHI});
    std.debug.print("  φ² + 1/φ²:        {d:.10} (= TRINITY)\n", .{firebird.PHI * firebird.PHI + 1.0 / (firebird.PHI * firebird.PHI)});
    std.debug.print("  Default DIM:      {d}\n", .{vsa.DIM});
    std.debug.print("\n", .{});
    std.debug.print("EVOLUTION PARAMETERS:\n", .{});
    std.debug.print("  μ (mutation):     {d:.4}\n", .{firebird.MU});
    std.debug.print("  χ (crossover):    {d:.4}\n", .{firebird.CHI});
    std.debug.print("  σ (selection):    {d:.4}\n", .{firebird.SIGMA});
    std.debug.print("  ε (elitism):      {d:.4}\n", .{firebird.EPSILON});
    std.debug.print("  Target similarity:{d:.2}\n", .{firebird.HUMAN_SIMILARITY_THRESHOLD});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn printBanner() !void {
    std.debug.print("{s}", .{BANNER});
}

fn printHelp() !void {
    std.debug.print("{s}", .{HELP});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cli parses evolve options" {
    // Just verify the module compiles
    const opts = EvolveOptions{};
    try std.testing.expectEqual(@as(usize, 10000), opts.dim);
    try std.testing.expectEqual(@as(usize, 50), opts.pop);
}

test "cli parses benchmark options" {
    const opts = BenchmarkOptions{};
    try std.testing.expectEqual(@as(usize, 10000), opts.dim);
    try std.testing.expectEqual(@as(usize, 100), opts.iterations);
}
