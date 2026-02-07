// ============================================================================
// GOLDEN CHAIN - 16-Link Development Pipeline State Machine
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3 = TRINITY
// ============================================================================

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INVERSE: f64 = 0.618033988749895; // Needle threshold
pub const TRINITY: f64 = 3.0;

// ============================================================================
// CHAIN LINK ENUM (16 Links)
// ============================================================================

pub const ChainLink = enum(u8) {
    baseline = 1, // LINK 1: Analyze previous version v(n-1)
    metrics = 2, // LINK 2: Collect v(n-1) metrics
    pas_analyze = 3, // LINK 3: Research patterns (PAS)
    tech_tree = 4, // LINK 4: Build dependency graph
    spec_create = 5, // LINK 5: Create .vibee specs
    code_generate = 6, // LINK 6: vibee gen -> .zig
    test_run = 7, // LINK 7: zig build test
    benchmark_prev = 8, // LINK 8: CRITICAL - Compare to v(n-1)
    benchmark_external = 9, // LINK 9: Compare to llama.cpp/vLLM
    benchmark_theoretical = 10, // LINK 10: Gap to optimal
    delta_report = 11, // LINK 11: Improvement report
    optimize = 12, // LINK 12: Fix if needed (OPTIONAL)
    docs = 13, // LINK 13: Documentation with proofs
    toxic_verdict = 14, // LINK 14: Russian assessment
    git = 15, // LINK 15: Commit + push
    loop_decision = 16, // LINK 16: Decide next version

    pub fn getName(self: ChainLink) []const u8 {
        return switch (self) {
            .baseline => "BASELINE",
            .metrics => "METRICS",
            .pas_analyze => "PAS_ANALYZE",
            .tech_tree => "TECH_TREE",
            .spec_create => "SPEC_CREATE",
            .code_generate => "CODE_GENERATE",
            .test_run => "TEST_RUN",
            .benchmark_prev => "BENCHMARK_PREV",
            .benchmark_external => "BENCHMARK_EXTERNAL",
            .benchmark_theoretical => "BENCHMARK_THEORETICAL",
            .delta_report => "DELTA_REPORT",
            .optimize => "OPTIMIZE",
            .docs => "DOCS",
            .toxic_verdict => "TOXIC_VERDICT",
            .git => "GIT",
            .loop_decision => "LOOP",
        };
    }

    pub fn getDescription(self: ChainLink) []const u8 {
        return switch (self) {
            .baseline => "Analyze previous version v(n-1)",
            .metrics => "Collect performance metrics",
            .pas_analyze => "Research patterns and science",
            .tech_tree => "Build technology tree",
            .spec_create => "Create .vibee specifications",
            .code_generate => "Generate code from specs",
            .test_run => "Run test suite",
            .benchmark_prev => "CRITICAL: Compare to baseline",
            .benchmark_external => "Compare to external tools",
            .benchmark_theoretical => "Gap to theoretical maximum",
            .delta_report => "Generate improvement report",
            .optimize => "Optimize if needed",
            .docs => "Generate documentation",
            .toxic_verdict => "Critical self-assessment",
            .git => "Commit and push changes",
            .loop_decision => "Decide next iteration",
        };
    }

    pub fn isCritical(self: ChainLink) bool {
        return switch (self) {
            .benchmark_prev, .test_run, .loop_decision => true,
            else => false,
        };
    }

    pub fn isMandatory(self: ChainLink) bool {
        return self != .optimize; // Only optimize is optional
    }

    pub fn next(self: ChainLink) ?ChainLink {
        const val = @intFromEnum(self);
        if (val >= 16) return null;
        return @enumFromInt(val + 1);
    }

    pub fn prev(self: ChainLink) ?ChainLink {
        const val = @intFromEnum(self);
        if (val <= 1) return null;
        return @enumFromInt(val - 1);
    }
};

// ============================================================================
// PIPELINE STATUS
// ============================================================================

pub const PipelineStatus = enum {
    not_started,
    in_progress,
    completed,
    failed,
    skipped,

    pub fn getSymbol(self: PipelineStatus) []const u8 {
        return switch (self) {
            .not_started => "○",
            .in_progress => "◐",
            .completed => "●",
            .failed => "✗",
            .skipped => "◌",
        };
    }
};

// ============================================================================
// LINK METRICS
// ============================================================================

pub const LinkMetrics = struct {
    duration_ms: u64 = 0,
    tests_passed: u32 = 0,
    tests_failed: u32 = 0,
    tests_total: u32 = 0,
    memory_bytes: u64 = 0,
    tokens_per_sec: f64 = 0.0,
    coverage_percent: f64 = 0.0,
    improvement_rate: f64 = 0.0,
};

// ============================================================================
// LINK RESULT
// ============================================================================

pub const LinkResult = struct {
    link: ChainLink,
    status: PipelineStatus,
    started_at: i64,
    completed_at: i64,
    output: []const u8,
    error_message: []const u8,
    metrics: LinkMetrics,

    pub fn init(link: ChainLink) LinkResult {
        return .{
            .link = link,
            .status = .not_started,
            .started_at = 0,
            .completed_at = 0,
            .output = "",
            .error_message = "",
            .metrics = .{},
        };
    }

    pub fn duration(self: *const LinkResult) i64 {
        if (self.completed_at > self.started_at) {
            return self.completed_at - self.started_at;
        }
        return 0;
    }
};

// ============================================================================
// NEEDLE STATUS (Immortality Check)
// ============================================================================

pub const NeedleStatus = enum {
    immortal, // > phi^-1 (0.618) - Koschei lives
    mortal_improving, // 0 < rate < phi^-1 - improving but not enough
    regression, // rate <= 0 - getting worse

    pub fn getMessage(self: NeedleStatus) []const u8 {
        return switch (self) {
            .immortal => "KOSCHEI IMMORTAL! Needle is sharp. (rate > phi^-1)",
            .mortal_improving => "Improving, but needle dulls. Need more!",
            .regression => "REGRESSION! Needle broken. Rollback required.",
        };
    }

    pub fn getRussianMessage(self: NeedleStatus) []const u8 {
        return switch (self) {
            .immortal => "KOSHCHEY BESSSMERTEN! Igla ostra.",
            .mortal_improving => "Uluchshenie est', no Igla tupitsya.",
            .regression => "REGRESSIYA! Igla slomana.",
        };
    }
};

pub fn checkNeedleThreshold(improvement_rate: f64) NeedleStatus {
    if (improvement_rate > PHI_INVERSE) {
        return .immortal;
    } else if (improvement_rate > 0) {
        return .mortal_improving;
    } else {
        return .regression;
    }
}

// ============================================================================
// PIPELINE STATE
// ============================================================================

pub const PipelineState = struct {
    allocator: std.mem.Allocator,
    version: u32,
    phase: ChainLink,
    status: PipelineStatus,
    started_at: i64,
    results: [16]LinkResult,
    improvement_rate: f64,
    task_description: []const u8,
    verbose: bool,

    pub fn init(allocator: std.mem.Allocator, version: u32, task: []const u8) PipelineState {
        var results: [16]LinkResult = undefined;
        inline for (0..16) |i| {
            results[i] = LinkResult.init(@enumFromInt(i + 1));
        }

        return .{
            .allocator = allocator,
            .version = version,
            .phase = .baseline,
            .status = .not_started,
            .started_at = std.time.timestamp(),
            .results = results,
            .improvement_rate = 0.0,
            .task_description = task,
            .verbose = false,
        };
    }

    pub fn getResult(self: *const PipelineState, link: ChainLink) *const LinkResult {
        const idx = @intFromEnum(link) - 1;
        return &self.results[idx];
    }

    pub fn setResult(self: *PipelineState, link: ChainLink, result: LinkResult) void {
        const idx = @intFromEnum(link) - 1;
        self.results[idx] = result;
    }

    pub fn isImmortal(self: *const PipelineState) bool {
        return self.improvement_rate > PHI_INVERSE;
    }

    pub fn getNeedleStatus(self: *const PipelineState) NeedleStatus {
        return checkNeedleThreshold(self.improvement_rate);
    }

    pub fn canContinue(self: *const PipelineState) bool {
        // Check if all mandatory links up to current passed
        for (self.results, 0..) |result, i| {
            const link: ChainLink = @enumFromInt(i + 1);
            if (link.isMandatory() and result.status == .failed) {
                return false;
            }
            if (@intFromEnum(link) >= @intFromEnum(self.phase)) {
                break;
            }
        }
        return true;
    }

    pub fn getCompletedCount(self: *const PipelineState) u32 {
        var count: u32 = 0;
        for (self.results) |result| {
            if (result.status == .completed) count += 1;
        }
        return count;
    }

    pub fn getProgressPercent(self: *const PipelineState) f64 {
        return @as(f64, @floatFromInt(self.getCompletedCount())) / 16.0 * 100.0;
    }

    pub fn getMetricsFilePath(self: *const PipelineState, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "metrics/v{d}.json", .{self.version});
    }

    pub fn getPrevMetricsFilePath(self: *const PipelineState, buf: []u8) ![]const u8 {
        if (self.version == 1) return "metrics/v0.json";
        return std.fmt.bufPrint(buf, "metrics/v{d}.json", .{self.version - 1});
    }
};

// ============================================================================
// CHAIN ERROR
// ============================================================================

pub const ChainError = error{
    // Critical errors - abort pipeline
    CriticalLinkFailed,
    TestsFailedGate,
    BenchmarkRegression,

    // Recoverable errors
    MetricsFileNotFound,
    SpecParseWarning,
    BenchmarkTimeout,
    GitConflict,

    // Informational
    ExternalBenchmarkUnavailable,
    TheoreticalBenchmarkSkipped,

    // System
    OutOfMemory,
    FileNotFound,
    ProcessFailed,
};

pub const RecoveryStrategy = enum {
    abort, // Stop pipeline immediately
    retry, // Retry current link (with backoff)
    skip, // Skip this link, continue
    loop_back, // Go back to earlier link
    manual_intervention, // Pause and wait for user
};

pub fn getRecoveryStrategy(err: ChainError, link: ChainLink) RecoveryStrategy {
    return switch (err) {
        ChainError.CriticalLinkFailed, ChainError.TestsFailedGate, ChainError.BenchmarkRegression => .abort,
        ChainError.MetricsFileNotFound => if (link == .baseline) .skip else .abort,
        ChainError.BenchmarkTimeout => .retry,
        ChainError.GitConflict => .manual_intervention,
        ChainError.ExternalBenchmarkUnavailable, ChainError.TheoreticalBenchmarkSkipped => .skip,
        ChainError.SpecParseWarning => .skip,
        ChainError.OutOfMemory, ChainError.FileNotFound, ChainError.ProcessFailed => .abort,
    };
}

// ============================================================================
// IMPROVEMENT RATE CALCULATION
// ============================================================================

pub const VersionMetrics = struct {
    tokens_per_second: f64 = 0.0,
    peak_rss_bytes: u64 = 0,
    tests_total: u32 = 0,
    tests_passed: u32 = 0,
    accuracy: f64 = 0.0,
};

pub fn calculateImprovementRate(prev: *const VersionMetrics, curr: *const VersionMetrics) f64 {
    var total_weight: f64 = 0.0;
    var weighted_improvement: f64 = 0.0;

    // Performance (weight: 0.4)
    if (prev.tokens_per_second > 0) {
        const perf_ratio = curr.tokens_per_second / prev.tokens_per_second;
        weighted_improvement += 0.4 * (perf_ratio - 1.0);
        total_weight += 0.4;
    }

    // Memory efficiency (weight: 0.3)
    if (prev.peak_rss_bytes > 0 and curr.peak_rss_bytes > 0) {
        const prev_mem = @as(f64, @floatFromInt(prev.peak_rss_bytes));
        const curr_mem = @as(f64, @floatFromInt(curr.peak_rss_bytes));
        const mem_ratio = prev_mem / curr_mem; // Lower is better
        weighted_improvement += 0.3 * (mem_ratio - 1.0);
        total_weight += 0.3;
    }

    // Test coverage (weight: 0.2)
    if (prev.tests_total > 0) {
        const prev_tests = @as(f64, @floatFromInt(prev.tests_total));
        const curr_tests = @as(f64, @floatFromInt(curr.tests_total));
        const test_ratio = curr_tests / prev_tests;
        weighted_improvement += 0.2 * (test_ratio - 1.0);
        total_weight += 0.2;
    }

    // Accuracy (weight: 0.1)
    if (prev.accuracy > 0) {
        const acc_improvement = curr.accuracy - prev.accuracy;
        weighted_improvement += 0.1 * acc_improvement;
        total_weight += 0.1;
    }

    if (total_weight > 0) {
        return weighted_improvement / total_weight;
    }
    return 0.0;
}

// ============================================================================
// TESTS
// ============================================================================

test "ChainLink enumeration" {
    const baseline = ChainLink.baseline;
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(baseline));
    try std.testing.expectEqualStrings("BASELINE", baseline.getName());
    try std.testing.expect(!baseline.isCritical());
    try std.testing.expect(baseline.isMandatory());

    const benchmark = ChainLink.benchmark_prev;
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(benchmark));
    try std.testing.expect(benchmark.isCritical());

    const optimize = ChainLink.optimize;
    try std.testing.expect(!optimize.isMandatory());
}

test "ChainLink navigation" {
    const baseline = ChainLink.baseline;
    try std.testing.expectEqual(ChainLink.metrics, baseline.next().?);
    try std.testing.expectEqual(@as(?ChainLink, null), baseline.prev());

    const loop = ChainLink.loop_decision;
    try std.testing.expectEqual(@as(?ChainLink, null), loop.next());
    try std.testing.expectEqual(ChainLink.git, loop.prev().?);
}

test "Needle threshold" {
    try std.testing.expectEqual(NeedleStatus.immortal, checkNeedleThreshold(0.7));
    try std.testing.expectEqual(NeedleStatus.mortal_improving, checkNeedleThreshold(0.3));
    try std.testing.expectEqual(NeedleStatus.regression, checkNeedleThreshold(-0.1));
    try std.testing.expectEqual(NeedleStatus.regression, checkNeedleThreshold(0.0));
}

test "Improvement rate calculation" {
    const prev = VersionMetrics{
        .tokens_per_second = 1000.0,
        .peak_rss_bytes = 100_000_000,
        .tests_total = 100,
        .accuracy = 0.8,
    };

    const curr = VersionMetrics{
        .tokens_per_second = 1200.0, // 20% better
        .peak_rss_bytes = 90_000_000, // 10% less memory
        .tests_total = 110, // 10% more tests
        .accuracy = 0.85, // 5% better accuracy
    };

    const rate = calculateImprovementRate(&prev, &curr);
    try std.testing.expect(rate > 0);
    try std.testing.expect(rate < 1.0);
}

test "PipelineState initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const state = PipelineState.init(allocator, 1, "test task");
    try std.testing.expectEqual(@as(u32, 1), state.version);
    try std.testing.expectEqual(ChainLink.baseline, state.phase);
    try std.testing.expectEqual(PipelineStatus.not_started, state.status);
    try std.testing.expectEqual(@as(u32, 0), state.getCompletedCount());
}
