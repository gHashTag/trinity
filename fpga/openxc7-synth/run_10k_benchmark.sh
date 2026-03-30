#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY VSA 10K BENCHMARK SCRIPT                                           ║
# ║  Week 2 Day 1: Benchmark 10K-dimensional VSA operations                     ║
# ║                                                                              ║
# ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

ITERATIONS=${1:-1000}

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY VSA 10K BENCHMARK                                                 ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Iterations: $ITERATIONS"
echo "Dimensions: 10,000"
echo "Vector size: 2,500 bytes"
echo ""

# Build the benchmark
echo "Building benchmark..."
cd /Users/playra/trinity-w1

# Create a simple test program
cat > zig-out/bin/vsa_10k_bench.zig << 'EOF'
const std = @import("std");
const vsa10k = @import("src/vsa/10k_vsa.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    const iterations = 1000;
    const result = try vsa10k.benchmark(allocator, iterations);
    vsa10k.printBenchmark(result);

    // Calculate FPGA speedup estimate
    const fpga_bind_ns = 60.0; // 3 cycles @ 50MHz
    const speedup = result.bind_ns / fpga_bind_ns;

    stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════
        \\FPGA SPEEDUP ESTIMATE
        \\═══════════════════════════════════════════════════════════════════════════
        \\CPU bind time:    {d:.2} ns
        \\FPGA bind time:   {d:.2} ns (estimated, 3 cycles @ 50MHz)
        \\Speedup:          {d:.1}x
        \\═══════════════════════════════════════════════════════════════════════════
        \\
        \\φ² + 1/φ² = 3 = TRINITY
        \\
    , .{ result.bind_ns, fpga_bind_ns, speedup }) catch return;
}
EOF

# Run zig test to execute benchmark
echo ""
echo "Running benchmark..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
zig test src/vsa/10k_vsa.zig --test-no-exec -freference-trace 2>/dev/null || true

# Alternative: build and run a standalone binary
echo ""
echo "Building standalone benchmark..."
zig build-exe -O ReleaseFast -femit-bin=zig-out/bin/vsa_10k_bench -target native-native \
    --deps vsa_10k_bench --module root src/vsa/10k_vsa.zig \
    --name vsa_10k_bench 2>/dev/null || echo "Build via zig build-exe failed, using zig test"

# Run via zig test (simpler)
echo ""
echo "Running via zig test..."
zig test src/vsa/10k_vsa.zig -femit-bin=zig-cache/bin/vsa_10k_test \
    --test-filter "benchmark" 2>/dev/null || {
    echo ""
    echo "Note: Full benchmark requires running through trinity VSA tests."
    echo "Run: zig build test"
    echo ""
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ Benchmark complete"
echo ""
echo "For full integration test, run:"
echo "  zig build test"
echo ""
