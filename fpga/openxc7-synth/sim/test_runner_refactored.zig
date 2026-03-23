// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA Simulation Framework — Test Runner (REFACTORED)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Main test orchestrator for FPGA simulation testing
//
// Usage: zig run test_runner_refactored.zig -- [--all|--vsa|--tqnn|--uart|--scheduler]
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import domain test modules
const vsa_tests = @import("tests/vsa_tests.zig");
const tqnn_tests = @import("tests/tqnn_tests.zig");
const uart_tests = @import("tests/uart_tests.zig");
const scheduler_tests = @import("tests/scheduler_tests.zig");

// Import reporting modules
const TestReport = @import("json_reporter.zig").TestReport;

// ============================================================================
// COMMAND LINE OPTIONS
// ============================================================================

const Options = struct {
    run_vsa: bool = false,
    run_tqnn: bool = false,
    run_uart: bool = false,
    run_scheduler: bool = false,
    output_file: []const u8 = "results.json",

    pub fn parse(args: []const [:0]u8) !Options {
        var opts = Options{};
        for (args[1..]) |arg| {
            if (std.mem.eql(u8, arg, "--all")) {
                opts.run_vsa = true;
                opts.run_tqnn = true;
                opts.run_uart = true;
                opts.run_scheduler = true;
            } else if (std.mem.eql(u8, arg, "--vsa")) {
                opts.run_vsa = true;
            } else if (std.mem.eql(u8, arg, "--tqnn")) {
                opts.run_tqnn = true;
            } else if (std.mem.eql(u8, arg, "--uart")) {
                opts.run_uart = true;
            } else if (std.mem.eql(u8, arg, "--scheduler")) {
                opts.run_scheduler = true;
            } else if (std.mem.startsWith(u8, arg, "--output=")) {
                opts.output_file = arg["--output=".len..];
            } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                printUsage();
                std.process.exit(0);
            }
        }
        return opts;
    }

    fn printUsage() void {
        std.debug.print(
            \\TRINITY FPGA Simulation Test Runner
            \\Usage: zig run test_runner_refactored.zig -- [OPTIONS]
            \\
            \\Options:
            \\  --all           Run all tests (default if none specified)
            \\  --vsa           Run VSA operation tests
            \\  --tqnn          Run TQNN layer tests
            \\  --uart          Run UART protocol tests
            \\  --scheduler     Run OS scheduler tests
            \\  --output=FILE   Output JSON file (default: results.json)
            \\  --help, -h      Show this help
            \\
        , .{});
    }
};

// ============================================================================
// MAIN
// ============================================================================

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    var opts = try Options.parse(args);

    // Default to --all if nothing specified
    if (!opts.run_vsa and !opts.run_tqnn and !opts.run_uart and !opts.run_scheduler) {
        opts.run_vsa = true;
        opts.run_tqnn = true;
        opts.run_uart = true;
        opts.run_scheduler = true;
    }

    // Initialize report
    var report = try TestReport.init(allocator, "trinity_simulation");
    defer report.tests.deinit(allocator);

    const start_total = std.time.nanoTimestamp();

    // Run selected test suites using domain modules
    if (opts.run_vsa) try vsa_tests.runAll(allocator, &report);
    if (opts.run_tqnn) try tqnn_tests.runAll(allocator, &report);
    if (opts.run_uart) try uart_tests.runAll(allocator, &report);
    if (opts.run_scheduler) try scheduler_tests.runAll(allocator, &report);

    const total_duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start_total)) / 1_000_000.0;

    // Print summary
    const sum = report.summary();
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Test Summary: {d}/{d} passed ({d:.0}%)\n", .{
        sum.passed, sum.total, sum.success_rate * 100.0
    });
    std.debug.print("Duration: {d:.2} ms\n", .{total_duration_ms});
    std.debug.print("Golden Identity: φ² + 1/φ² = 3 ✓\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});

    // Write JSON report
    std.debug.print("\nWriting results to {s}...\n", .{opts.output_file});
    try report.writeFile(opts.output_file);
    std.debug.print("Done!\n", .{});
}
