// ═══════════════════════════════════════════════════════════════════════════════
// BEAL CONJECTURE SCANNER - CLI Entry Point
// ═══════════════════════════════════════════════════════════════════════════════
// Search for counterexamples: A^x + B^y = C^z with coprime bases, exponents > 2
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod_filter = @import("mod_filter.zig");
const search_mod = @import("search.zig");
const simd = @import("simd_neon.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config = search_mod.SearchConfig{};
    var run_benchmarks = false;
    var verbose = false;

    // Simple argument parsing
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            try printHelp();
            return;
        }
        if (std.mem.eql(u8, args[i], "--max-base") and i + 1 < args.len) {
            config.max_base = try std.fmt.parseInt(u32, args[i + 1], 10);
            i += 1;
        }
        if (std.mem.eql(u8, args[i], "--max-exp") and i + 1 < args.len) {
            config.max_exponent = @as(u8, @intCast(try std.fmt.parseInt(u32, args[i + 1], 10)));
            i += 1;
        }
        if (std.mem.eql(u8, args[i], "--threads") and i + 1 < args.len) {
            config.num_threads = try std.fmt.parseInt(usize, args[i + 1], 10);
            i += 1;
        }
        if (std.mem.eql(u8, args[i], "--benchmark") or std.mem.eql(u8, args[i], "-b")) {
            run_benchmarks = true;
        }
        if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
            verbose = true;
        }
    }

    // Print banner
    try printBanner();

    // Detect and print SIMD capability
    const simd_target = simd.detectSimdTarget();
    const simd_width = simd.getSimdWidth();
    std.debug.print("SIMD: {} (width: {})\n", .{ simd_target, simd_width });

    if (run_benchmarks) {
        try runBenchmarks(allocator);
        return;
    }

    // Initialize power table
    std.debug.print("\nInitializing modular filter...\n", .{});
    var timer = try std.time.Timer.start();

    var power_table = try mod_filter.PowerTable.init(
        allocator,
        &mod_filter.RECOMMENDED_PRIMES,
        config.max_base,
        config.max_exponent,
    );
    defer power_table.deinit();

    const init_time = timer.read();
    std.debug.print(
        "  Power table: {} bases × {} exponents × {} primes\n",
        .{ config.max_base, config.max_exponent, mod_filter.NUM_PRIMES },
    );
    std.debug.print("  Memory: {d:.1} MB\n", .{
        @as(f64, @floatFromInt(power_table.memoryUsage())) / 1024 / 1024,
    });
    std.debug.print("  Initialized in {d:.2} ms\n\n", .{
        @as(f64, @floatFromInt(init_time)) / 1_000_000,
    });

    // Run search
    std.debug.print("Starting search for counterexamples...\n", .{});
    std.debug.print("  Range: A,B,C < {d}\n", .{config.max_base});
    std.debug.print("  Exponents: {d} <= x,y,z <= {d}\n", .{ config.min_exponent, config.max_exponent });
    std.debug.print("  Threads: {}\n\n", .{config.num_threads});

    var search_timer = try std.time.Timer.start();

    const results = try search_mod.searchParallel(
        allocator,
        &power_table,
        &config,
    );

    const search_time = search_timer.read();

    // Print results
    std.debug.print("\nSearch completed in {d:.2} seconds\n", .{
        @as(f64, @floatFromInt(search_time)) / 1_000_000_000,
    });

    if (results.len > 0) {
        std.debug.print("\n🎯 FOUND {} COUNTEREXAMPLE(S):\n\n", .{results.len});
        for (results) |r| {
            const formatted = try r.format(allocator);
            defer allocator.free(formatted);
            std.debug.print("  {s}\n", .{formatted});
        }

        std.debug.print("\n⚠️  VERIFY WITH EXACT BIGINT COMPUTATION!\n", .{});
    } else {
        std.debug.print("\n✓ No counterexamples found in range.\n", .{});
    }
}

fn printBanner() !void {
    std.debug.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║           BEAL CONJECTURE SIMD SCANNER v1.0                  ║
        \\║     Search for A^x + B^y = C^z with coprime bases             ║
        \\║                  φ² + 1/φ² = 3                               ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
    , .{});
}

fn printHelp() !void {
    std.debug.print(
        \\Usage: beal [OPTIONS]
        \\
        \\Options:
        \\  --max-base N     Maximum base value (default: 1000)
        \\  --max-exp N      Maximum exponent (default: 10)
        \\  --threads N      Number of threads (default: 4)
        \\  --benchmark, -b  Run benchmarks
        \\  --verbose, -v    Verbose output
        \\  --help, -h       Show this help
        \\
        \\Beal Conjecture:
        \\  If A^x + B^y = C^z where A,B,C are positive integers
        \\  and x,y,z > 2, then gcd(A,B,C) > 1.
        \\
        \\  Counterexample = coprime bases (gcd = 1) = $1,000,000 prize!
        \\
    , .{});
}

fn runBenchmarks(allocator: std.mem.Allocator) !void {
    std.debug.print("\nRunning benchmarks...\n\n", .{});

    // Benchmark 1: GCD filter
    std.debug.print("GCD Filter Benchmark:\n", .{});
    var gcd_timer = try std.time.Timer.start();
    var gcd_count: u32 = 0;
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        var j: u32 = i + 1;
        while (j < 10000) : (j += 1) {
            _ = @import("gcd.zig").isPairCoprime(i, j);
            gcd_count += 1;
        }
    }
    const gcd_time = gcd_timer.read();
    const gcd_rate = @as(f64, @floatFromInt(gcd_count)) / @as(f64, @floatFromInt(gcd_time));
    std.debug.print("  Checked {d} pairs in {d:.2} ms\n", .{ gcd_count, @as(f64, @floatFromInt(gcd_time)) / 1_000_000 });
    std.debug.print("  Rate: {d:.0} pairs/sec\n\n", .{gcd_rate * 1_000_000_000});

    // Benchmark 2: Modular filter
    std.debug.print("Modular Filter Benchmark:\n", .{});
    const max_base: u32 = 1000;
    const max_exp: u8 = 10;

    var mod_init_time = try std.time.Timer.start();
    var mod_table = try mod_filter.PowerTable.init(
        allocator,
        &mod_filter.RECOMMENDED_PRIMES,
        max_base,
        max_exp,
    );
    const mod_init = mod_init_time.read();
    _ = mod_init;
    defer mod_table.deinit();
    std.debug.print("  Memory: {d:.1} MB\n\n", .{
        @as(f64, @floatFromInt(mod_table.memoryUsage())) / 1024 / 1024,
    });

    // Benchmark 3: SIMD operations
    std.debug.print("SIMD Benchmark:\n", .{});
    const simd_target = simd.detectSimdTarget();
    std.debug.print("  Target: {}\n", .{simd_target});
    std.debug.print("  Width: {}\n", .{simd.getSimdWidth()});

    // Benchmark check4PrimesSIMD
    var simd_timer = try std.time.Timer.start();
    var simd_count: usize = 0;
    var iter: usize = 0;
    while (iter < 1_000_000) : (iter += 1) {
        const ax = [4]u64{ 9, 8, 27, 64 };
        const by = [4]u64{ 16, 18, 64, 125 };
        const cz = [4]u64{ 25, 26, 91, 189 };
        _ = simd.check4PrimesSIMD(ax, by, cz);
        simd_count += 1;
    }
    const simd_time = simd_timer.read();
    const simd_rate = @as(f64, @floatFromInt(simd_count)) / @as(f64, @floatFromInt(simd_time));
    std.debug.print("  check4PrimesSIMD: {d:.0} checks/sec\n\n", .{simd_rate * 1_000_000_000});

    std.debug.print("Benchmarks complete.\n", .{});
}

test "beal main - help output" {
    try printHelp();
}

test "beal main - banner" {
    try printBanner();
}
