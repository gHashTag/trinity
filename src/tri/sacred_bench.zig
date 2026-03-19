// @origin(spec:tri_sacred_bench.tri) @regen(manual-impl)

// ═════════════════════════════════════════════════════════════════════
// SACRED BENCHMARK — GF16/TF3-9 Performance Measurement
// ═════════════════════════════════════════════════════════════════════
//
// Phase 6.3 — Run iverilog benchmarks and parse results
//
// Usage: tri sacred bench [--n=N] [--mode=ALL|gf16_add|gf16_mul|tf3_add|tf3_dot] [--output=csv|human]
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const GOLD = colors.GOLDEN;
const CYAN = colors.CYAN;
const GREEN = colors.GREEN;
const RED = colors.RED;
const RESET = colors.RESET;

// =============================================================================
// BENCHMARK RESULTS STRUCTURE
// =============================================================================

pub const BenchmarkResult = struct {
    mode: []const u8,
    cycles_per_op: f64,
    ops_per_sec: f64,
    gops_per_sec: f64,
};

pub const BenchmarkResults = struct {
    gf16_add: ?BenchmarkResult,
    gf16_mul: ?BenchmarkResult,
    tf3_add: ?BenchmarkResult,
    tf3_dot: ?BenchmarkResult,

    pub fn deinit(self: *BenchmarkResults, allocator: std.mem.Allocator) void {
        if (self.gf16_add) |*r| {
            allocator.free(r.mode);
            r.mode = "";
        }
        if (self.gf16_mul) |*r| {
            allocator.free(r.mode);
            r.mode = "";
        }
        if (self.tf3_add) |*r| {
            allocator.free(r.mode);
            r.mode = "";
        }
        if (self.tf3_dot) |*r| {
            allocator.free(r.mode);
            r.mode = "";
        }
    }
};

// =============================================================================
// CSV PARSING
// =============================================================================

fn parseCsvOutput(allocator: std.mem.Allocator, output: []const u8) !BenchmarkResults {
    var results = BenchmarkResults{
        .gf16_add = null,
        .gf16_mul = null,
        .tf3_add = null,
        .tf3_dot = null,
    };

    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        // Skip empty lines and comments
        if (line.len == 0 or line[0] == '#') continue;

        // Parse CSV line: mode,cycles_per_op,ops_per_sec,gops_per_sec
        var fields = std.mem.splitScalar(u8, line, ',');
        const mode_str = fields.first();
        if (mode_str.len == 0) continue;

        const cycles_str = fields.next() orelse continue;
        const ops_str = fields.next() orelse continue;
        const gops_str = fields.next() orelse continue;

        const cycles = try std.fmt.parseFloat(f64, cycles_str);
        const ops = try std.fmt.parseFloat(f64, ops_str);
        const gops = try std.fmt.parseFloat(f64, gops_str);

        const mode_name = try allocator.dupe(u8, mode_str);
        const result = BenchmarkResult{
            .mode = mode_name,
            .cycles_per_op = cycles,
            .ops_per_sec = ops,
            .gops_per_sec = gops,
        };

        if (std.mem.eql(u8, mode_name, "gf16_add")) {
            results.gf16_add = result;
        } else if (std.mem.eql(u8, mode_name, "gf16_mul")) {
            results.gf16_mul = result;
        } else if (std.mem.eql(u8, mode_name, "tf3_add")) {
            results.tf3_add = result;
        } else if (std.mem.eql(u8, mode_name, "tf3_dot")) {
            results.tf3_dot = result;
        }
    }

    return results;
}

// =============================================================================
// IVERILOG EXECUTION
// =============================================================================

fn runIverilogBenchmark(allocator: std.mem.Allocator, ops: u32) ![]const u8 {
    const fpga_dir = "fpga/openxc7-synth";
    const sacred_alu_v = try std.fs.path.join(allocator, &.{ fpga_dir, "sacred_alu.v" });
    defer allocator.free(sacred_alu_v);

    const gf16_alu_v = try std.fs.path.join(allocator, &.{ fpga_dir, "gf16_alu.v" });
    defer allocator.free(gf16_alu_v);

    const tf3_add_v = try std.fs.path.join(allocator, &.{ fpga_dir, "tf3_add.v" });
    defer allocator.free(tf3_add_v);

    const tf3_dot_v = try std.fs.path.join(allocator, &.{ fpga_dir, "tf3_dot.v" });
    defer allocator.free(tf3_dot_v);

    const tb_dir = try std.fs.path.join(allocator, &.{ fpga_dir, "tb" });
    defer allocator.free(tb_dir);

    const tb_bench_v = try std.fs.path.join(allocator, &.{ tb_dir, "tb_bench_sacred.v" });
    defer allocator.free(tb_bench_v);

    // Check if iverilog is available
    const result_iverilog = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &.{ "iverilog", "--version" },
    });
    if (result_iverilog.term != .Exited or result_iverilog.exit_code != 0) {
        return error.IverilogNotFound;
    }

    // Compile testbench with +define+ for BENCH_OPS
    const sim_output = try std.fs.path.join(allocator, &.{ fpga_dir, "tb_bench_sim" });
    defer allocator.free(sim_output);

    const compile_args = &[_][]const u8{
        "iverilog",
        "-o",
        sim_output,
        "-g2012", // Use SystemVerilog 2012
        try std.fmt.allocPrint(allocator, "+define+BENCH_OPS={d}", .{ops}),
        sacred_alu_v,
        gf16_alu_v,
        tf3_add_v,
        tf3_dot_v,
        tb_bench_v,
    };

    const result_compile = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = compile_args,
    });
    if (result_compile.term != .Exited or result_compile.exit_code != 0) {
        std.debug.print("{s}iverilog failed:{s}\n{s}\n", .{ RED, RESET, result_compile.stderr });
        return error.IverilogCompileFailed;
    }

    // Run simulation
    const result_sim = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &.{ "vvp", sim_output },
    });
    if (result_sim.term != .Exited or result_sim.exit_code != 0) {
        std.debug.print("{s}vvp failed:{s}\n{s}\n", .{ RED, RESET, result_sim.stderr });
        return error.VvpRunFailed;
    }

    return result_sim.stdout;
}

// =============================================================================
// FORMATTING
// =============================================================================

fn printHumanReport(results: BenchmarkResults) void {
    std.debug.print("\n{s}╔═════════════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║         SACRED ALU BENCHMARK RESULTS                              ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╠═════════════════════════════════════════════════════════════╣{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║ Mode        │ Cycles/op │ Throughput │ GOP/s      ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╠═══════════════════════════════════════════════════════════════╣{s}\n", .{ GOLD, RESET });

    const print_row = struct {
        fn print(mode: []const u8, result: ?BenchmarkResult) void {
            if (result != null) {
                std.debug.print("{s}║ %-11s │ %8.2f  │ %8.2f M │ %8.2f   ║{s}\n", .{ GREEN, mode, result.cycles_per_op, result.ops_per_sec / 1e6, result.gops_per_sec, RESET });
            } else {
                std.debug.print("{s}║ %-11s │ %-8s  │ %-8s │ %-8s ║{s}\n", .{ RED, mode, "N/A", "N/A", "N/A", RESET });
            }
        }
    }.print;

    print_row("GF16_ADD", results.gf16_add);
    print_row("GF16_MUL", results.gf16_mul);
    print_row("TF3_ADD", results.tf3_add);
    print_row("TF3_DOT", results.tf3_dot);

    std.debug.print("{s}╚═════════════════════════════════════════════════════════════════╝{s}\n", .{ GOLD, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

fn printCsvReport(results: BenchmarkResults) void {
    std.debug.print("mode,cycles_per_op,ops_per_sec,gops_per_sec\n", .{});
    const print_row = struct {
        fn print(result: ?BenchmarkResult) void {
            if (result != null) {
                std.debug.print("{s},{d:.2},{d:.0},{d:.4}\n", .{ result.mode, result.cycles_per_op, result.ops_per_sec, result.gops_per_sec });
            }
        }
    }.print;

    print_row(results.gf16_add);
    print_row(results.gf16_mul);
    print_row(results.tf3_add);
    print_row(results.tf3_dot);
}

// =============================================================================
// MAIN COMMAND
// =============================================================================

pub fn runSacredBenchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var num_ops: u32 = 100000;
    var output_format: []const u8 = "human";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--n") and i + 1 < args.len) {
            num_ops = try std.fmt.parseInt(u32, args[i + 1], 10);
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--output") and i + 1 < args.len) {
            output_format = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            try printBenchHelp();
            return;
        }
    }

    std.debug.print("\n{s}══════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}SACRED ALU BENCHMARK{ s}\n", .{ GOLD, RESET });
    std.debug.print("{s}════════════════════════════════════════{s}\n\n", .{ GOLD, RESET });

    std.debug.print("{s}Configuration:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Operations per mode: {d}\n", .{num_ops});
    std.debug.print("  Output format: {s}\n\n", .{output_format});

    std.debug.print("{s}Running iverilog benchmark...{s}\n", .{ GREEN, RESET });

    const output = try runIverilogBenchmark(allocator, num_ops);
    defer allocator.free(output);

    const results = try parseCsvOutput(allocator, output);
    defer results.deinit(allocator);

    if (std.mem.eql(u8, output_format, "csv")) {
        printCsvReport(results);
    } else {
        printHumanReport(results);
    }
}

fn printBenchHelp() !void {
    std.debug.print("\n{s}════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}SACRED ALU BENCHMARK COMMAND{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}══════════════════════════════════════════{s}\n\n", .{ GOLD, RESET });

    std.debug.print("{s}Usage:{s} tri sacred bench [options]\n\n", .{ CYAN, RESET });

    std.debug.print("{s}Options:{s}\n", .{ GOLD, RESET });
    std.debug.print("  {s}--n N{s}          Number of operations per mode (default: 100000)\n", .{ GREEN, RESET });
    std.debug.print("  {s}--output FORMAT{s} Output format: human (default) | csv\n", .{ GREEN, RESET });
    std.debug.print("  {s}-h, --help{s}     Show this help\n\n", .{ GREEN, RESET });

    std.debug.print("{s}Example:{s} tri sacred bench --n 50000 --output csv\n", .{ CYAN, RESET });

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// =============================================================================
// TESTS
// =============================================================================

test "sacred bench: parse CSV output" {
    const csv_output =
        \\# CSV OUTPUT
        \\mode,cycles_per_op,ops_per_sec,gops_per_sec
        \\gf16_add,1.50,2000000000.0,2.00
        \\gf16_mul,1.25,2500000000.0,2.50
        \\tf3_add,2.00,1500000000.0,1.50
        \\tf3_dot,3.00,1000000000.0,1.00
    ;

    const allocator = std.testing.allocator;
    const results = try parseCsvOutput(allocator, csv_output);
    defer results.deinit(allocator);

    try std.testing.expect(results.gf16_add != null);
    try std.testing.expect(results.gf16_mul != null);
    try std.testing.expect(results.tf3_add != null);
    try std.testing.expect(results.tf3_dot != null);

    try std.testing.expectEqual(@as(f64, 1.50), results.gf16_add.?.cycles_per_op);
    try std.testing.expectEqual(@as(f64, 2.50), results.gf16_mul.?.gops_per_sec);
}

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        try runSacredBenchCommand(allocator, args[1..]);
        return 0;
    }

    try printBenchHelp();
    return 0;
}
