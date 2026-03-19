const std = @import("std");
const Allocator = std.mem.Allocator;
const ips = @import("../../hslm/intraparietal_sulcus.zig");
const weber = @import("../../hslm/weber_tuning.zig");
const ofc = @import("../../hslm/orbitofrontal_value.zig");

const DEFAULT_ITERATIONS: u32 = 100_000;
const MIN_TIME_PER_OP_NS: u64 = 1_000_000;
const CPU_FREQ_HZ: f64 = 3_000_000_000.0;

pub const BenchmarkResult = struct {
    op: []const u8,
    ns_per_op: u64,
    calls: u64,
};

pub fn commandSensationBench(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;

    var iterations: u32 = DEFAULT_ITERATIONS;
    var run_all: bool = false;
    var csv_output: bool = false;
    var include_weber: bool = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--n")) {
            iterations = try std.fmt.parseInt(u32, args[arg + 2], 10);
        } else if (std.mem.eql(u8, arg, "--all")) {
            run_all = true;
            include_weber = true;
        } else if (std.mem.eql(u8, arg, "--csv")) {
            csv_output = true;
        } else if (std.mem.eql(u8, arg, "--warmup")) {
            const stdout = std.io.getStdOut();
            try stdout.writeAll(
                \\\\tri sensation bench [--n=N] [--all] [--csv] [--warmup]
                \\\Benchmark sensation operations (CPU profiling)
                \\\Options:
                \\\  --n=N          Iteration count (default: 100000)
                \\\  --all           Run all 8 operations
                \\\  --csv           Output CSV format
                \\\  --warmup       Warmup phase
            );
            return;
        }
    }

    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\\\op,ns_per_op,cycles_per_op
    );

    // Warmup
    if (std.mem.contains(u8, args, "--warmup")) {
        try stdout.writeAll("Warming up...", .{});
        const dummy: f32 = 1.0;
        _ = ips.gf16FromF32(dummy);
        _ = ips.gf16ToF32(ips.gf16FromF32(dummy));
        _ = ips.tf3FromF32(dummy);
        _ = ips.tf3ToF32(ips.tf3FromF32(dummy));
    }

    try benchmarkGF16(allocator, iterations);
    try benchmarkTF3(allocator, iterations);

    if (include_weber or run_all) {
        try benchmarkWeber(allocator, iterations);
    }

    try benchmarkOFC(allocator, iterations);

    const dummy: f32 = 1.0;
    try stdout.print("\\nBenchmark complete!\\n", .{});
}
ENDOFFILE
