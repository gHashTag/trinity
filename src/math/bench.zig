//! Math Benchmark Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_bench.zig)
//! DO NOT EDIT: Modify math_bench.tri spec and regenerate

// Types
pub const BenchmarkCategory = @import("gen_bench.zig").BenchmarkCategory;
pub const BenchmarkResult = @import("gen_bench.zig").BenchmarkResult;
pub const BenchmarkSuite = @import("gen_bench.zig").BenchmarkSuite;
pub const BenchmarkConfig = @import("gen_bench.zig").BenchmarkConfig;
pub const OutputFormat = @import("gen_bench.zig").OutputFormat;

// Benchmark functions
pub const runGoldenWrapBench = @import("gen_bench.zig").runGoldenWrapBench;
pub const runPhiHashBench = @import("gen_bench.zig").runPhiHashBench;
pub const runSIMDBench = @import("gen_bench.zig").runSIMDBench;
pub const runFibonacciBench = @import("gen_bench.zig").runFibonacciBench;
pub const runLucasBench = @import("gen_bench.zig").runLucasBench;
pub const runPhiPowerBench = @import("gen_bench.zig").runPhiPowerBench;
pub const runSpiralBench = @import("gen_bench.zig").runSpiralBench;
pub const runVerifyBench = @import("gen_bench.zig").runVerifyBench;
pub const runAllBenchmarks = @import("gen_bench.zig").runAllBenchmarks;
pub const printBenchmarkResults = @import("gen_bench.zig").printBenchmarkResults;
pub const compareWithBaseline = @import("gen_bench.zig").compareWithBaseline;

// Utility functions
pub const phiHashMod = @import("gen_bench.zig").phiHashMod;
pub const fibonacci = @import("gen_bench.zig").fibonacci;
pub const lucas = @import("gen_bench.zig").lucas;
pub const verifyTrinityIdentity = @import("gen_bench.zig").verifyTrinityIdentity;
pub const verifyPhiIdentity = @import("gen_bench.zig").verifyPhiIdentity;
