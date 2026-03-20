// Brain Benchmark Standalone Tool
// Run with: zig run tools/bench_brain.zig -- -iterations 10000

const std = @import("std");

const brain_benchmark = @import("../src/tri/brain_benchmark.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var iterations: u64 = 10000;
    var print_only_opportunities = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-iterations") and i + 1 < args.len) {
            iterations = try std.fmt.parseInt(u64, args[i + 1], 10);
            i += 1;
        } else if (std.mem.eql(u8, args[i], "-opportunities") or std.mem.eql(u8, args[i], "-o")) {
            print_only_opportunities = true;
        } else if (std.mem.eql(u8, args[i], "-h") or std.mem.eql(u8, args[i], "--help")) {
            try std.io.getStdOut().writeAll(
                \\Usage: bench_brain [options]
                \\
                \\Options:
                \\  -iterations N    Number of iterations per benchmark (default: 10000)
                \\  -opportunities   Print optimization opportunities only
                \\  -h, --help       Print this help
                \\
            );
            return;
        }
    }

    if (print_only_opportunities) {
        try brain_benchmark.printOptimizationReport();
        return;
    }

    // Run benchmarks
    const suite = try brain_benchmark.runAll(allocator, iterations);
    defer suite.deinit();

    // Print report
    try suite.printReport();

    // Print optimization opportunities
    try brain_benchmark.printOptimizationReport();
}
