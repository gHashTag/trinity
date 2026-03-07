//! ═══════════════════════════════════════════════════════════════════════════════
//! VSA TESTS — Vector Symbolic Architecture test suite
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Tests for VSA operations: bind, bundle, similarity, hamming distance
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const MockFpga = @import("../mock_fpga.zig").MockFpga;
const TestVectors = @import("../mock_fpga.zig").TestVectors;
const Trit = @import("../mock_fpga.zig").Trit;
const TestResult = @import("../json_reporter.zig").TestResult;
const TestStatus = @import("../json_reporter.zig").TestStatus;

/// Run all VSA tests
pub fn runAll(allocator: std.mem.Allocator, report: anytype) !void {
    std.debug.print("Running VSA Tests...\n", .{});

    var fpga = MockFpga.init(allocator);

    try testBind16(allocator, &fpga, report);
    try testBind256(allocator, &fpga, report);
    try testBundle16(allocator, &fpga, report);
    try testSimilarityIdentical(allocator, &fpga, report);
    try testHammingOnesZeros(allocator, &fpga, report);
    try testBindBenchmark(allocator, &fpga, report);

    const stats = fpga.getStats();
    std.debug.print("  VSA Stats: bind={d}, bundle={d}, similarity={d}\n", .{
        stats.bind_count, stats.bundle_count, stats.similarity_count
    });
}

/// Test 1: Bind 16-trit vectors
fn testBind16(allocator: std.mem.Allocator, fpga: *MockFpga, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    const vec_a = TestVectors.allOnes(16);
    const vec_b = TestVectors.alternating(16);
    const result = try fpga.vsaBind(&vec_a, &vec_b);
    defer allocator.free(result);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    // Verify: bind(all+, alt) should be alt (per trit multiplication)
    var match = true;
    for (0..16) |i| {
        const expected = if (i % 2 == 0) Trit.positive else Trit.negative;
        if (result[i] != expected) match = false;
    }

    try report.addTest(TestResult{
        .name = "vsa_bind_16",
        .status = if (match) TestStatus.pass else TestStatus.fail,
        .duration_ms = duration_ms,
        .details = .{
            .vector_a = "[++++++++++++++++]",
            .vector_b = "[+-+-+-+-+-+-+-+-]",
            .result_match = match,
        },
    });
}

/// Test 2: Bind 256-trit vectors
fn testBind256(allocator: std.mem.Allocator, fpga: *MockFpga, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    const vec_a = try TestVectors.random(256);
    const vec_b = try TestVectors.random(256);
    const result = try fpga.vsaBind(&vec_a, &vec_b);
    defer allocator.free(result);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(TestResult{
        .name = "vsa_bind_256",
        .status = TestStatus.pass, // Just check it runs
        .duration_ms = duration_ms,
        .details = .{},
    });
}

/// Test 3: Bundle 2 vectors
fn testBundle16(allocator: std.mem.Allocator, fpga: *MockFpga, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    const vec_a = TestVectors.allOnes(16);
    const vec_b = TestVectors.allOnes(16);
    const result = try fpga.vsaBundle2(&vec_a, &vec_b);
    defer allocator.free(result);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    // Bundle(all+, all+) should be all+
    var match = true;
    for (result) |t| {
        if (t != .positive) match = false;
    }

    try report.addTest(TestResult{
        .name = "vsa_bundle_16",
        .status = if (match) TestStatus.pass else TestStatus.fail,
        .duration_ms = duration_ms,
        .details = .{
            .vector_a = "[++++++++++++++++]",
            .vector_b = "[++++++++++++++++]",
            .expected = "[++++++++++++++++]",
            .result_match = match,
        },
    });
}

/// Test 4: Similarity
fn testSimilarityIdentical(allocator: std.mem.Allocator, fpga: *MockFpga, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    const vec_a = TestVectors.allOnes(16);
    const vec_b = TestVectors.allOnes(16);
    const score = try fpga.vsaSimilarity(&vec_a, &vec_b);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    // Same vectors should have max similarity
    try report.addTest(TestResult{
        .name = "vsa_similarity_identical",
        .status = if (score == 255) TestStatus.pass else TestStatus.fail,
        .duration_ms = duration_ms,
        .details = .{
            .expected = "255",
            .actual = try std.fmt.allocPrint(allocator, "{d}", .{score}),
            .result_match = score == 255,
        },
    });
}

/// Test 5: Hamming Distance
fn testHammingOnesZeros(allocator: std.mem.Allocator, fpga_: *MockFpga, report: anytype) !void {
    _ = fpga_;
    const start = std.time.nanoTimestamp();
    const vec_a = TestVectors.allOnes(16);
    const vec_b = TestVectors.allZeros(16);
    const distance = MockFpga.hammingDistance(&vec_a, &vec_b);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(TestResult{
        .name = "vsa_hamming_all_ones_zeros",
        .status = if (distance == 16) TestStatus.pass else TestStatus.fail,
        .duration_ms = duration_ms,
        .details = .{
            .expected = "16",
            .actual = try std.fmt.allocPrint(allocator, "{d}", .{distance}),
            .result_match = distance == 16,
        },
    });
}

/// Benchmark: 10K bind operations
fn testBindBenchmark(allocator: std.mem.Allocator, fpga: *MockFpga, report: anytype) !void {
    const iterations = 10_000;
    const vec_a = TestVectors.allOnes(16);
    const vec_b = TestVectors.alternating(16);

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try fpga.vsaBind(&vec_a, &vec_b);
        allocator.free(result);
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const duration_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const ops_per_sec = @as(u64, @intFromFloat(@as(f64, @floatFromInt(iterations)) /
        (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0)));

    try report.addTest(TestResult{
        .name = "vsa_bind_benchmark_10k",
        .status = TestStatus.pass,
        .duration_ms = duration_ms,
        .details = .{
            .ops_per_sec = ops_per_sec,
        },
    });
}
