# Automated Benchmarking Framework for Trinity S³AI

**Date:** 2026-03-26
**Issue:** #415
**Purpose:** Continuous performance tracking and regression detection

---

## Executive Summary

This document describes the automated benchmarking framework for Trinity S³AI, designed to:
1. Track performance metrics across commits
2. Detect regressions automatically
3. Generate reproducible benchmark reports
4. Integrate with CI/CD pipeline

---

## Part I: Benchmark Categories

### I.1 Performance Benchmarks

| Category | Metrics | Target | Threshold |
|----------|---------|--------|-----------|
| VSA Operations | ops/sec, latency | >100M ops/sec | -10% regression |
| HSLM Forward Pass | tokens/sec, latency | >8K tokens/sec | -5% regression |
| HSLM Training | steps/sec, loss | >100 steps/sec | -5% regression |
| FPGA Throughput | tokens/sec @ 50MHz | 8K tokens/sec | -5% regression |
| Memory Usage | MB | <500 MB | +10% regression |

### I.2 Correctness Benchmarks

| Category | Tests | Coverage | Requirement |
|-----------|-------|----------|-------------|
| VSA Operations | bind/unbind correctness | 100% | All passing |
| Ternary Quantization | STE gradient accuracy | 95% | <5% error |
| Consciousness Gate | System 1/2 distribution | 95% | <5% error |
| Model Training | PPL convergence | 100% | PPL < 130 |

---

## Part II: Benchmark Runner Implementation

### II.1 Core API (`src/bench/bench.zig`)

```zig
const std = @import("std");
const hslm = @import("hslm/model.zig");
const vsa = @import("vsa.zig");

pub const BenchmarkConfig = struct {
    name: []const u8,
    warmup_iterations: usize = 10,
    benchmark_iterations: usize = 100,
    output_format: OutputFormat = .JSON,

    pub const OutputFormat = enum {
        JSON,
        Markdown,
        CSV,
    };
};

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    mean_time_ns: u64,
    median_time_ns: u64,
    std_dev_ns: u64,
    ops_per_second: f64,
    regression_threshold: f64 = 0.9,  // 10% regression = fail
    baseline_mean_ns: u64 = 0,

    pub fn format(self: *const BenchmarkResult, format: BenchmarkConfig.OutputFormat) ![]const u8;
    pub fn isRegression(self: *const BenchmarkResult) bool {
        if (self.baseline_mean_ns == 0) return false;
        return @as(f64, @floatFromInt(self.mean_time_ns)) >
               @as(f64, @floatFromInt(self.baseline_mean_ns)) / self.regression_threshold;
    }
};

pub const BenchmarkSuite = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),

    pub fn init(allocator: std.mem.Allocator) BenchmarkSuite {
        return BenchmarkSuite{
            .allocator = allocator,
            .results = std.ArrayList(BenchmarkResult).init(allocator),
        };
    }

    pub fn runAll(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        // VSA Bind Benchmark
        try self.benchmarkVSABind(config);

        // VSA Bundle Benchmark
        try self.benchmarkVSABundle(config);

        // HSLM Forward Pass Benchmark
        try self.benchmarkHSLMForward(config);

        // HSLM Training Step Benchmark
        try self.benchmarkHSLMTraining(config);

        // Generate Report
        try self.generateReport(config.output_format);
    }

    fn benchmarkVSABind(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        const dim: usize = 1024;

        // Allocate vectors
        var a = try allocator.alloc(i8, dim);
        defer allocator.free(a);
        var b = try allocator.alloc(i8, dim);
        defer allocator.free(b);
        var result = try allocator.alloc(i8, dim);
        defer allocator.free(result);

        // Initialize with random data
        var prng = std.Random.DefaultPrng.init(0xTRINIT1);
        const rng = prng.random();
        for (0..dim) |i| {
            a[i] = rng.intRange(i8, -1, 2);  // {-1, 0, +1}
            b[i] = rng.intRange(i8, -1, 2);
        }

        // Warmup
        var i: usize = 0;
        while (i < config.warmup_iterations) : (i += 1) {
            _ = vsa.bind(a, b, result);
        }

        // Benchmark
        const iterations = config.benchmark_iterations;
        var times = try allocator.alloc(u64, iterations);
        defer allocator.free(times);

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = vsa.bind(a, b, result);
            const end = std.time.nanoTimestamp();
            times[i] = end - start;
        }

        // Compute statistics
        const total_time = std.mem.sum(u64, times);
        const mean_time = total_time / iterations;
        const min_time = std.mem.min(u64, times);
        const max_time = std.mem.max(u64, times);

        // Sort for median
        std.sort.insertion(u64, times);
        const median_time = times[iterations / 2];

        // Standard deviation
        var variance: u64 = 0;
        for (times) |t| {
            const diff = @as(i64, @intCast(t)) - @as(i64, @intCast(mean_time));
            variance += @intCast(u64, diff * diff);
        }
        variance /= iterations;
        const std_dev = @sqrt(@as(f64, @floatFromInt(variance)));

        // Ops per second (ns to sec)
        const ops_per_sec = @as(f64, @floatFromInt(dim * iterations)) /
                           @as(f64, @floatFromInt(total_time)) * 1_000_000_000;

        try self.results.append(BenchmarkResult{
            .name = "VSA Bind",
            .iterations = iterations,
            .total_time_ns = total_time,
            .min_time_ns = min_time,
            .max_time_ns = max_time,
            .mean_time_ns = mean_time,
            .median_time_ns = median_time,
            .std_dev_ns = @intFromFloat(std_dev),
            .ops_per_second = ops_per_sec,
        });
    }

    fn benchmarkVSABundle(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        // Similar structure to benchmarkVSABind
        // Use vsa.bundle2 or vsa.bundle3
        _ = self;
        _ = config;
        return error.NotImplemented;
    }

    fn benchmarkHSLMForward(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var model = try hslm.HSLM.init(allocator);
        defer model.deinit();

        const seq_len = 81;
        var tokens = try allocator.alloc(u32, seq_len);
        defer allocator.free(tokens);

        // Warmup
        var i: usize = 0;
        while (i < config.warmup_iterations) : (i += 1) {
            _ = try model.forward(tokens);
        }

        // Benchmark
        const iterations = config.benchmark_iterations;
        var times = try allocator.alloc(u64, iterations);
        defer allocator.free(times);

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = try model.forward(tokens);
            const end = std.time.nanoTimestamp();
            times[i] = end - start;
        }

        // Compute statistics...
        _ = times;

        try self.results.append(BenchmarkResult{
            .name = "HSLM Forward Pass",
            .iterations = iterations,
            .total_time_ns = 0,  // TODO: compute
            .min_time_ns = 0,
            .max_time_ns = 0,
            .mean_time_ns = 0,
            .median_time_ns = 0,
            .std_dev_ns = 0,
            .ops_per_second = 0,  // tokens/sec
        });
    }

    fn benchmarkHSLMTraining(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        _ = self;
        _ = config;
        return error.NotImplemented;
    }

    fn generateReport(self: *BenchmarkSuite, format: BenchmarkConfig.OutputFormat) !void {
        switch (format) {
            .JSON => try self.generateJSONReport(),
            .Markdown => try self.generateMarkdownReport(),
            .CSV => try self.generateCSVReport(),
        }
    }

    fn generateJSONReport(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut();
        const writer = stdout.writer();

        try writer.writeAll("{\"benchmarks\":[\n");
        for (self.results.items, 0..) |result, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("  {{\"name\":\"{s}\",\"ops_per_second\":{d:.2},\"mean_ns\":{d}}}",
                .{result.name, result.ops_per_second, result.mean_time_ns});
        }
        try writer.writeAll("\n]}\n");
    }

    fn generateMarkdownReport(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut();
        const writer = stdout.writer();

        try writer.writeAll("# Benchmark Results\n\n");
        try writer.writeAll("| Benchmark | Ops/sec | Mean (ns) | Min (ns) | Max (ns) | Std Dev |\n");
        try writer.writeAll("|-----------|---------|----------|----------|----------|----------|\n");

        for (self.results.items) |result| {
            try writer.print("| {s} | {d:.2} | {d} | {d} | {d} | {d:.2} |\n",
                .{result.name, result.ops_per_second, result.mean_time_ns,
                  result.min_time_ns, result.max_time_ns, result.std_dev_ns});
        }
    }

    fn generateCSVReport(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut();
        const writer = stdout.writer();

        try writer.writeAll("name,ops_per_second,mean_ns,min_ns,max_ns,std_dev_ns\n");
        for (self.results.items) |result| {
            try writer.print("{s},{d:.2},{d},{d},{d},{d:.2}\n",
                .{result.name, result.ops_per_second, result.mean_time_ns,
                  result.min_time_ns, result.max_time_ns, result.std_dev_ns});
        }
    }
};
```

### II.2 CLI Integration (`src/tri/bench.zig`)

```zig
pub const BenchCommand = struct {
    pub fn execute(allocator: std.mem.Allocator, args: [][]const u8) !void {
        var config = BenchmarkConfig{
            .name = "Trinity Benchmark Suite",
            .warmup_iterations = 10,
            .benchmark_iterations = 100,
            .output_format = .JSON,
        };

        // Parse arguments
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--format")) {
                i += 1;
                if (i >= args.len) return error.MissingArgument;
                if (std.mem.eql(u8, args[i], "json")) {
                    config.output_format = .JSON;
                } else if (std.mem.eql(u8, args[i], "markdown")) {
                    config.output_format = .Markdown;
                } else if (std.mem.eql(u8, args[i], "csv")) {
                    config.output_format = .CSV;
                } else {
                    return error.InvalidFormat;
                }
            } else if (std.mem.eql(u8, args[i], "--iterations")) {
                i += 1;
                if (i >= args.len) return error.MissingArgument;
                config.benchmark_iterations = try std.fmt.parseInt(usize, args[i]);
            }
        }

        var suite = BenchmarkSuite.init(allocator);
        try suite.runAll(config);
    }
};
```

---

## Part III: CI/CD Integration

### III.1 GitHub Actions Workflow

```yaml
# .github/workflows/bench.yml
name: Benchmark

on: [push, pull_request]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Zig
        run: |
          curl -O https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
          tar xf zig-linux-x86_64-0.15.0.tar.xz
          export PATH=$PATH:$PWD/zig-linux-x86_64-0.15.0

      - name: Build Benchmarks
        run: zig build bench

      - name: Run Benchmarks
        run: zig-out/bin/bench --format json > benchmark-results.json

      - name: Check Regressions
        run: |
          python scripts/check_regression.py \
            --current benchmark-results.json \
            --baseline .github/baselines/benchmark.json \
            --threshold 0.9

      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: benchmark-results.json

      - name: Update Baseline (main branch only)
        if: github.ref == 'refs/heads/main'
        run: |
          mkdir -p .github/baselines
          cp benchmark-results.json .github/baselines/benchmark.json
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .github/baselines/benchmark.json
          git commit -m "chore: update benchmark baseline"
          git push
```

### III.2 Regression Check Script (`scripts/check_regression.py`)

```python
#!/usr/bin/env python3
"""Check for performance regressions in benchmark results."""

import json
import sys
from typing import Dict, List

def load_results(path: str) -> Dict:
    """Load benchmark results from JSON file."""
    with open(path) as f:
        return json.load(f)

def check_regression(current: Dict, baseline: Dict, threshold: float = 0.9) -> List[str]:
    """Check for performance regressions."""
    regressions = []

    for current_result in current.get("benchmarks", []):
        name = current_result["name"]
        current_mean = current_result.get("mean_ns", 0)

        # Find baseline result
        baseline_result = None
        for b in baseline.get("benchmarks", []):
            if b["name"] == name:
                baseline_result = b
                break

        if baseline_result is None:
            continue

        baseline_mean = baseline_result.get("mean_ns", 0)
        if baseline_mean == 0:
            continue

        # Check regression (time increased beyond threshold)
        ratio = baseline_mean / current_mean
        if ratio < threshold:
            percent_change = (current_mean / baseline_mean - 1) * 100
            regressions.append(
                f"{name}: {percent_change:+.1f}% "
                f"(current: {current_mean}ns, baseline: {baseline_mean}ns)"
            )

    return regressions

def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--current", required=True)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--threshold", type=float, default=0.9)
    args = parser.parse_args()

    current = load_results(args.current)
    baseline = load_results(args.baseline)

    regressions = check_regression(current, baseline, args.threshold)

    if regressions:
        print("❌ Performance Regressions Detected:")
        for regression in regressions:
            print(f"  - {regression}")
        sys.exit(1)
    else:
        print("✅ No performance regressions detected")
        sys.exit(0)

if __name__ == "__main__":
    main()
```

---

## Part IV: Baseline Management

### IV.1 Baseline Storage

```
.github/baselines/
├── benchmark.json         # Current baseline (main branch)
├── history/               # Historical baselines
│   ├── 2026-03-01.json
│   ├── 2026-03-08.json
│   └── 2026-03-15.json
└── README.md              # Baseline documentation
```

### IV.2 Baseline Format

```json
{
  "version": "1.0",
  "commit": "b4c02a1ce70",
  "date": "2026-03-26T12:00:00Z",
  "zig_version": "0.15.0",
  "benchmarks": [
    {
      "name": "VSA Bind",
      "iterations": 100,
      "ops_per_second": 120000000,
      "mean_ns": 8.5,
      "min_ns": 7.2,
      "max_ns": 12.1,
      "std_dev_ns": 0.8
    },
    {
      "name": "VSA Bundle",
      "iterations": 100,
      "ops_per_second": 95000000,
      "mean_ns": 10.8,
      "min_ns": 9.5,
      "max_ns": 15.3,
      "std_dev_ns": 1.1
    },
    {
      "name": "HSLM Forward Pass",
      "iterations": 100,
      "ops_per_second": 8000,
      "mean_ns": 125000,
      "min_ns": 118000,
      "max_ns": 145000,
      "std_dev_ns": 5000
    }
  ]
}
```

---

## Part V: Reporting

### V.1 Automated Reports

Benchmark reports are automatically generated in three formats:

1. **JSON**: Machine-readable for CI/CD integration
2. **Markdown**: Human-readable for documentation
3. **CSV**: Spreadsheet-compatible for analysis

### V.2 Report Generation

```bash
# Generate all formats
zig-out/bin/bench --format json > results.json
zig-out/bin/bench --format markdown > results.md
zig-out/bin/bench --format csv > results.csv
```

### V.3 Report Distribution

- **GitHub Actions**: Upload as artifacts
- **Slack/Telegram**: Post summary notifications
- **Documentation**: Include in research papers

---

## Part VI: Usage Examples

### VI.1 Running All Benchmarks

```bash
# Run full benchmark suite
zig build bench
./zig-out/bin/bench --format markdown

# With custom iterations
./zig-out/bin/bench --iterations 1000 --format json

# Check against baseline
python scripts/check_regression.py \
  --current results.json \
  --baseline .github/baselines/benchmark.json
```

### VI.2 Individual Benchmark Categories

```bash
# VSA benchmarks only
zig-out/bin/bench --category vsa

# HSLM benchmarks only
zig-out/bin/bench --category hslm

# FPGA benchmarks only
zig-out/bin/bench --category fpga
```

---

## Conclusion

The automated benchmarking framework provides:
1. **Continuous performance tracking** across all commits
2. **Regression detection** with configurable thresholds
3. **Multiple output formats** for different use cases
4. **CI/CD integration** for automated testing
5. **Baseline management** for historical comparison

Implementation status:
- Core benchmark runner: Proposed (needs implementation)
- Regression checker: Proposed (needs implementation)
- CI/CD workflow: Proposed (needs implementation)
- Baseline storage: Ready

**Next Steps:**
1. Implement benchmark runner in `src/bench/bench.zig`
2. Create CLI entry point in `src/tri/bench.zig`
3. Set up GitHub Actions workflow
4. Create initial baseline from current commit

---

**Document Control:** BENCHMARK-001
**Status:** Complete — Framework Design
**φ² + 1/φ² = 3 | TRINITY**
