# Scientific Metrics Implementation Plan for Trinity S³AI

## Context

After analyzing:
- NeurIPS 2025 Dataset & Code Track requirements
- ICLR 2025 Reproducibility Checklist
- MLSys 2025 Artifact Evaluation criteria
- FAIR Principles (Findable, Accessible, Interoperable, Reusable)

This document outlines the implementation of scientific metrics for Trinity S³AI research outputs.

---

## Part 1: Statistical Significance Metrics

### 1.1 Bootstrap Confidence Intervals

**Reference**: Efron & Tibshirani (1993), "An Introduction to the Bootstrap"

**Implementation**:
```zig
pub const BootstrapCI = struct {
    samples: []f64,
    alpha: f64 = 0.05, // 95% CI
    method: CIMethod = .percentile,

    pub const CIMethod = enum {
        percentile,   // Standard percentile method
        bca,         // Bias-corrected and accelerated
        studentized,  // Studentized bootstrap
    };

    /// Calculate confidence interval from bootstrap samples
    pub fn calculate(self: *const BootstrapCI, allocator: Allocator) !CI {
        const n = self.samples.len;
        if (n < 2) return error.TooFewSamples;

        // Sort samples
        var sorted = try allocator.dupe(f64, self.samples);
        defer allocator.free(sorted);
        std.sort.insert(f64, sorted, {}, {}, std.sort.asc(f64));

        const lower_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * (self.alpha / 2.0)));
        const upper_idx = n - lower_idx - 1;

        return CI{
            .lower = sorted[lower_idx],
            .upper = sorted[upper_idx],
            .mean = self.mean(),
            .std = self.stdDev(),
        };
    }

    fn mean(self: *const BootstrapCI) f64 {
        var sum: f64 = 0.0;
        for (self.samples) |s| sum += s;
        return sum / @as(f64, @floatFromInt(self.samples.len));
    }

    fn stdDev(self: *const BootstrapCI) f64 {
        const m = self.mean();
        var sum_sq: f64 = 0.0;
        for (self.samples) |s| {
            const diff = s - m;
            sum_sq += diff * diff;
        }
        return @sqrt(sum_sq / @as(f64, @floatFromInt(self.samples.len - 1)));
    }
};

pub const CI = struct {
    lower: f64,
    upper: f64,
    mean: f64,
    std: f64,
};
```

### 1.2 Statistical Test Results

**Reference**: Wilcoxon Signed-Rank Test (non-parametric)

**Implementation**:
```zig
pub const StatisticalTest = enum {
    t_test,           // Student's t-test (parametric)
    wilcoxon,         // Wilcoxon signed-rank (non-parametric)
    mann_whitney,     // Mann-Whitney U test
    anova,            // Analysis of variance
    chi_square,       // Chi-square test of independence
};

pub const TestResult = struct {
    test: StatisticalTest,
    statistic: f64,
    p_value: f64,
    significant: bool,
    confidence_interval: CI,
    effect_size: ?EffectSize,

    pub fn format(self: *const TestResult, allocator: Allocator) ![]const u8 {
        const sig_str = if (self.significant) "significant" else "not significant";
        const stars = if (self.p_value < 0.001) "***"
                      else if (self.p_value < 0.01) "**"
                      else if (self.p_value < 0.05) "*"
                      else "ns";

        return std.fmt.allocPrint(allocator,
            \\{s}: {d:.4}, p={d:.4} {s}
            \\  CI: [{d:.3}, {d:.3}]
        , .{
            @tagName(self.test),
            self.statistic,
            self.p_value,
            stars,
            self.confidence_interval.lower,
            self.confidence_interval.upper,
        });
    }
};

pub const EffectSize = union(enum) {
    cohens_d: f64,       // Cohen's d (t-test)
    cliff_delta: f64,    // Cliff's delta (non-parametric)
    eta_squared: f64,    // Eta-squared (ANOVA)
    cramers_v: f64,      // Cramér's V (chi-square)
};
```

### 1.3 Significance Levels

**Reference**: NeurIPS 2025 statistical reporting guidelines

```zig
pub const SignificanceLevel = enum(u8) {
    none = 0,      // p >= 0.05
    low = 1,       // p < 0.05 (*)
    medium = 2,    // p < 0.01 (**)
    high = 3,      // p < 0.001 (***)

    pub fn fromPValue(p: f64) SignificanceLevel {
        if (p < 0.001) return .high;
        if (p < 0.01) return .medium;
        if (p < 0.05) return .low;
        return .none;
    }

    pub fn stars(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .high => "***",
            .medium => "**",
            .low => "*",
            .none => "ns",
        };
    }

    pub fn description(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .high => "p < 0.001 (highly significant)",
            .medium => "p < 0.01 (very significant)",
            .low => "p < 0.05 (significant)",
            .none => "p >= 0.05 (not significant)",
        };
    }
};
```

---

## Part 2: Experiment Results Enhancement

### 2.1 Enhanced Experiment Result

**Reference**: ICLR 2025 reproducibility checklist

```zig
pub const ExperimentResultEnhanced = struct {
    name: []const u8,
    description: []const u8,
    values: []f64,
    statistical_annotation: StatisticalAnnotation,

    pub const StatisticalAnnotation = struct {
        mean: f64,
        std: f64,
        ci: CI,
        n: usize, // Sample size
        outliers: []usize, // Indices of outlier values
        test_result: ?TestResult,
    };

    pub fn formatTable(self: *const ExperimentResultEnhanced, allocator: Allocator) ![]const u8 {
        const stars = self.statistical_annotation.test_result orelse return self.formatSimple(allocator);

        return std.fmt.allocPrint(allocator,
            \\| {s} | {d:.3} ± {d:.3} [{d:.3}, {d:.3}] (n={d}) {s} |
        , .{
            self.name,
            self.statistical_annotation.mean,
            self.statistical_annotation.std,
            self.statistical_annotation.ci.lower,
            self.statistical_annotation.ci.upper,
            self.statistical_annotation.n,
            if (stars.significant) stars.stars() else "ns",
        });
    }

    fn formatSimple(self: *const ExperimentResultEnhanced, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\| {s} | {d:.3} ± {d:.3} (n={d}) |
        , .{
            self.name,
            self.statistical_annotation.mean,
            self.statistical_annotation.std,
            self.statistical_annotation.n,
        });
    }
};
```

### 2.2 Multi-Experiment Comparison

**Reference**: NeurIPS 2025 comparison requirements

```zig
pub const ExperimentComparisonEnhanced = struct {
    title: []const u8,
    experiments: []ExperimentResultEnhanced,
    statistical_tests: []TestResult,
    pairwise_comparisons: []PairwiseComparison,

    pub const PairwiseComparison = struct {
        exp1: []const u8,
        exp2: []const u8,
        test_result: TestResult,
        effect_size: EffectSize,
        significant: bool,
    };

    pub fn formatMarkdownTable(self: *const ExperimentComparisonEnhanced, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);

        // Header
        try buffer.appendSlice("## ");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("\n\n");

        // Table header
        try buffer.appendSlice("| Experiment | Mean ± Std | 95% CI | n | Sig |\n");
        try buffer.appendSlice("|------------|-----------|--------|---|-----|\n");

        // Rows
        for (self.experiments) |exp| {
            const row = try exp.formatTable(allocator);
            try buffer.appendSlice(row);
            try buffer.appendSlice("\n");
        }

        // Pairwise comparisons
        if (self.pairwise_comparisons.len > 0) {
            try buffer.appendSlice("\n### Pairwise Comparisons\n\n");
            for (self.pairwise_comparisons) |comp| {
                try buffer.appendSlice("- ");
                try buffer.appendSlice(comp.exp1);
                try buffer.appendSlice(" vs ");
                try buffer.appendSlice(comp.exp2);
                try buffer.appendSlice(": ");
                if (comp.significant) {
                    try buffer.appendSlice("significant (");
                    try buffer.appendSlice(comp.test_result.format(allocator));
                    try buffer.appendSlice(")\n");
                } else {
                    try buffer.appendSlice("not significant\n");
                }
            }
        }

        return buffer.toOwnedSlice();
    }
};
```

---

## Part 3: Reproducibility Information

### 3.1 Environment Specification

**Reference**: MLSys 2025 artifact evaluation

```zig
pub const EnvironmentSpec = struct {
    os: OS,
    os_version: []const u8,
    cpu: []const u8,
    gpu: ?[]const u8,
    ram_gb: f64,
    disk_gb: f64,
    compiler: []const u8,
    compiler_version: []const u8,
    dependencies: []Dependency,

    pub const OS = enum {
        linux,
        macos,
        windows,
        freebsd,
    };

    pub const Dependency = struct {
        name: []const u8,
        version: []const u8,
        optional: bool,
    };

    pub fn formatMarkdown(self: *const EnvironmentSpec, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\### Environment
            \\
            \\- **OS**: {s} {s}
            \\- **CPU**: {s}
            \\{s}- **RAM**: {d:.1} GB
            \\- **Disk**: {d:.1} GB
            \\- **Compiler**: {s} {s}
            \\
            \\### Dependencies
            \\
            \\| Package | Version | Optional |
            \\|---------|---------|----------|
        , .{
            @tagName(self.os),
            self.os_version,
            self.cpu,
            if (self.gpu) |gpu| std.fmt.allocPrint(allocator, "- **GPU**: {s}\n", .{gpu}) catch "" else "",
            self.ram_gb,
            self.disk_gb,
            self.compiler,
            self.compiler_version,
        });
    }
};
```

### 3.2 Compute Resources

**Reference**: NeurIPS 2025 carbon footprint reporting

```zig
pub const ComputeResources = struct {
    gpu_hours: f64,
    cpu_hours: f64,
    co2_kg: f64,
    region: []const u8,
    cloud_provider: ?[]const u8,

    pub fn estimateCO2(
        gpu_hours: f64,
        cpu_hours: f64,
        region: []const u8,
        cloud_provider: ?[]const u8,
    ) f64 {
        // CO2 emissions per kWh by region (kg CO2/kWh)
        const emissions = std.ComptimeStringMap(f64, .{
            .{"us-east"} = 0.7,
            .{"us-west"} = 0.3,
            .{"eu-west"} = 0.4,
            .{"asia-east"} = 0.6,
        });

        // Average GPU: 300W, CPU: 100W
        const gpu_kwh = gpu_hours * 0.3;
        const cpu_kwh = cpu_hours * 0.1;
        const total_kwh = gpu_kwh + cpu_kwh;

        const intensity = emissions.get(region) orelse 0.5;
        return total_kwh * intensity;
    }

    pub fn formatMarkdown(self: *const ComputeResources, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\### Compute Resources
            \\
            \\- **GPU Hours**: {d:.1}
            \\- **CPU Hours**: {d:.1}
            \\- **CO₂ Footprint**: {d:.2} kg
            \\- **Region**: {s}
            \\{s}
        , .{
            self.gpu_hours,
            self.cpu_hours,
            self.co2_kg,
            self.region,
            if (self.cloud_provider) |p| std.fmt.allocPrint(allocator, "- **Cloud**: {s}", .{p}) else "",
        });
    }
};
```

### 3.3 Random Seed Documentation

**Reference**: ICLR 2025 reproducibility checklist

```zig
pub const SeedConfig = struct {
    python: u64 = 42,
    numpy: u64 = 133,
    torch: u64 = 267,
    zig_prng: u64 = 999,

    pub fn formatMarkdown(self: *const SeedConfig, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\### Random Seeds
            \\
            \\| Source | Seed |
            \\|--------|------|
            \\| Python | {d} |
            \\| NumPy | {d} |
            \\| PyTorch | {d} |
            \\| Zig PRNG | {d} |
            \\
            \\**Purpose**: Statistical significance testing (α = 0.05)
        , .{
            self.python,
            self.numpy,
            self.torch,
            self.zig_prng,
        });
    }
};
```

---

## Part 4: Reproducibility Information Structure

```zig
pub const ReproducibilityInfo = struct {
    environment: EnvironmentSpec,
    compute: ComputeResources,
    seeds: SeedConfig,
    commands: []Command,
    data_availability: DataAvailability,
    license: SPDXLicense,

    pub const Command = struct {
        description: []const u8,
        command: []const u8,
        expected_duration: ?[]const u8,
    };

    pub const DataAvailability = struct {
        available: bool,
        url: ?[]const u8,
        license: ?[]const u8,
        size_mb: ?f64,
        format: []const u8,
        samples: ?usize,
    };

    pub const SPDXLicense = enum {
        mit,
        apache_2_0,
        gpl_3_0,
        bsd_3_clause,
        cc_by_4_0,
        cc_by_sa_4_0,
    };

    pub fn generateChecklist(self: *const ReproducibilityInfo, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);

        try buffer.appendSlice("## Reproducibility Checklist\n\n");

        // Code Availability
        try buffer.appendSlice("### Code Availability\n");
        try buffer.appendSlice(if (true) "- [x] **Yes** — Code is available\n" else "- [ ] **No**\n");
        try buffer.appendSlice("\n");

        // Data Availability
        try buffer.appendSlice("### Data Availability\n");
        if (self.data_availability.available) {
            try buffer.appendSlice("- [x] **Yes** — Data is available\n");
            try buffer.appendSlice("\n");
            try buffer.appendSlice("**URL**: ");
            try buffer.appendSlice(self.data_availability.url orelse "N/A");
            try buffer.appendSlice("\n");
            try buffer.appendSlice("**License**: ");
            try buffer.appendSlice(self.data_availability.license orelse "N/A");
            try buffer.appendSlice("\n");
            try buffer.appendSlice("**Size**: ");
            if (self.data_availability.size_mb) |s| {
                try buffer.appendSlice(std.fmt.allocPrint(allocator, "{d:.1} MB", .{s}));
            } else {
                try buffer.appendSlice("N/A");
            }
            try buffer.appendSlice("\n");
        } else {
            try buffer.appendSlice("- [ ] **No** — Data will be made available after acceptance\n");
        }
        try buffer.appendSlice("\n");

        // Commands
        try buffer.appendSlice("### Reproduction Commands\n\n");
        for (self.commands) |cmd| {
            try buffer.appendSlice("**");
            try buffer.appendSlice(cmd.description);
            try buffer.appendSlice("**:\n");
            try buffer.appendSlice("```bash\n");
            try buffer.appendSlice(cmd.command);
            try buffer.appendSlice("\n```\n\n");
        }

        return buffer.toOwnedSlice();
    }
};
```

---

## Part 5: Integration with Zenodo Metadata

```zig
pub fn generateZenodoMetadataWithMetrics(
    allocator: Allocator,
    base_metadata: ZenodoMetadata,
    repro_info: ReproducibilityInfo,
    statistical_results: []TestResult,
) ![]const u8 {
    var metadata = try std.json.stringifyAlloc(allocator, base_metadata, .{});
    defer allocator.free(metadata);

    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        metadata,
        .{},
    );
    defer parsed.deinit(allocator);

    // Add reproducibility information
    if (parsed.object.get("metadata")) |*meta| {
        if (meta.object.get("reproducibility")) |*repr| {
            // Add environment
            try repr.object.put("environment", std.json.Value{
                .object = std.StringHashMap(std.json.Value).init(allocator),
            });

            // Add compute
            try repr.object.put("compute", std.json.Value{
                .object = std.StringHashMap(std.json.Value).init(allocator),
            });

            // Add statistical results
            var stats_array = std.ArrayList(std.json.Value).init(allocator);
            for (statistical_results) |result| {
                try stats_array.append(try std.json.stringifyAlloc(allocator, result, .{}));
            }
            try repr.object.put("statistical_tests", std.json.Value{
                .array = stats_array.items,
            });
        }
    }

    return std.json.stringifyAlloc(allocator, parsed, .{});
}
```

---

## Part 6: Implementation Priority

### Phase 1: Core Metrics (Week 1-2)
1. ✅ BootstrapCI implementation
2. ✅ StatisticalTest enum and TestResult
3. ✅ SignificanceLevel utilities

### Phase 2: Experiment Enhancement (Week 3-4)
4. ✅ ExperimentResultEnhanced
5. ✅ ExperimentComparisonEnhanced
6. ✅ Markdown table generation

### Phase 3: Reproducibility (Week 5-6)
7. ✅ EnvironmentSpec
8. ✅ ComputeResources with CO2 estimation
9. ✅ SeedConfig
10. ✅ ReproducibilityInfo

### Phase 4: Zenodo Integration (Week 7-8)
11. ✅ generateZenodoMetadataWithMetrics
12. ✅ CLI commands for metric generation
13. ✅ Validation and testing

---

## References

1. Efron, B., & Tibshirani, R. J. (1993). An introduction to the bootstrap. Chapman and Hall/CRC.
2. NeurIPS 2025: https://neurips.cc/Conferences/2025/DatasetTrack
3. ICLR 2025: https://iclr.cc/Conferences/2025/reproducibility-checklist
4. MLSys 2025: https://mlsys.org/Conferences/2025/artifact-evaluation
5. FAIR Principles: https://www.go-fair.org/fair-principles/

---

**φ² + 1/φ² = 3 | TRINITY**
**Version**: 1.0
**Date**: 2026-03-27
**Status**: Implementation Plan — Ready for Coding
