// @origin(spec:golden_chain.tri) @regen(manual-impl)

// ============================================================================
// GOLDEN CHAIN - 26-Link Development Pipeline State Machine
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3 = TRINITY
// v4.3: Added Link 24 (Perplexity Scholar) for research-assisted error fixing
// ============================================================================

const std = @import("std");

// Import sacred constants from sacred module
const sacred = @import("sacred");

// ============================================================================
// CONSTANTS (from canonical source)
// ============================================================================

pub const PHI = sacred.math.PHI;
pub const PHI_INVERSE = 1.0 / sacred.math.PHI; // Needle threshold
pub const TRINITY = 3.0; // phi^2 + 1/phi^2 = 3

// ============================================================================
// CHAIN LINK ENUM (26 Links) — GOLDEN CHAIN v4.4
// ============================================================================

pub const chain_link_count = 26;

pub const ChainLink = enum(u8) {
    tvc_gate = 0, // LINK 0: TVC Gate - Mandatory first check (distributed learning)
    baseline = 1, // LINK 1: Analyze previous version v(n-1)
    metrics = 2, // LINK 2: Collect v(n-1) metrics
    pas_analyze = 3, // LINK 3: Research patterns (PAS)
    tech_tree = 4, // LINK 4: Build dependency graph
    strict_check = 5, // LINK 5: VIBEE-first compliance check
    spec_create = 6, // LINK 6: Create .tri specs
    code_generate = 7, // LINK 7: vibee gen -> .zig
    sacred_analyze = 8, // LINK 8: Sacred Intelligence analysis
    test_run = 9, // LINK 9: zig build test
    benchmark_prev = 10, // LINK 10: CRITICAL - Compare to v(n-1)
    swe_fix = 11, // LINK 11: SWE Agent error fixing
    benchmark_external = 12, // LINK 12: Compare to llama.cpp/vLLM
    benchmark_theoretical = 13, // LINK 13: Gap to optimal
    delta_report = 14, // LINK 14: Improvement report
    optimize = 15, // LINK 15: Fix if needed (OPTIONAL)
    docs = 16, // LINK 16: Documentation with proofs
    toxic_verdict = 17, // LINK 17: Russian assessment
    git = 18, // LINK 18: Commit + push (with auto-commit)
    loop_decision = 19, // LINK 19: Decide next version
    fly_deploy = 20, // LINK 20: Auto-deploy to Fly.io
    eternal_self_evolution = 21, // LINK 21: [v4.0] Pipeline analyzes itself
    self_referential_evolution = 22, // LINK 22: [v4.1] Pipeline improves itself (circular bootstrapping)
    vision_led_test = 23, // LINK 23: [v4.2] Camera-based LED verification for FPGA
    perplexity_scholar = 24, // LINK 24: [v4.3] Research-assisted error fixing via Perplexity Sonar Pro
    spec_lint = 25, // LINK 25: [v4.4] Spec validation — blocks code_generate on bad specs

    pub fn getName(self: ChainLink) []const u8 {
        return switch (self) {
            .tvc_gate => "TVC_GATE",
            .baseline => "BASELINE",
            .metrics => "METRICS",
            .pas_analyze => "PAS_ANALYZE",
            .tech_tree => "TECH_TREE",
            .strict_check => "STRICT_CHECK",
            .spec_create => "SPEC_CREATE",
            .code_generate => "CODE_GENERATE",
            .sacred_analyze => "SACRED_ANALYZE",
            .test_run => "TEST_RUN",
            .benchmark_prev => "BENCHMARK_PREV",
            .swe_fix => "SWE_FIX",
            .benchmark_external => "BENCHMARK_EXTERNAL",
            .benchmark_theoretical => "BENCHMARK_THEORETICAL",
            .delta_report => "DELTA_REPORT",
            .optimize => "OPTIMIZE",
            .docs => "DOCS",
            .toxic_verdict => "TOXIC_VERDICT",
            .git => "GIT",
            .loop_decision => "LOOP",
            .fly_deploy => "FLY_DEPLOY",
            .eternal_self_evolution => "ETERNAL_SELF_EVOLUTION",
            .self_referential_evolution => "SELF_REFERENTIAL_EVOLUTION",
            .vision_led_test => "VISION_LED_TEST",
            .perplexity_scholar => "PERPLEXITY_SCHOLAR",
            .spec_lint => "SPEC_LINT",
        };
    }

    pub fn getDescription(self: ChainLink) []const u8 {
        return switch (self) {
            .tvc_gate => "TVC Gate: Search corpus, return cached or continue",
            .baseline => "Analyze previous version v(n-1)",
            .metrics => "Collect performance metrics",
            .pas_analyze => "Research patterns and science",
            .tech_tree => "Build technology tree",
            .strict_check => "VIBEE-first compliance check",
            .spec_create => "Create .tri specifications",
            .code_generate => "Generate code from specs",
            .sacred_analyze => "Sacred Intelligence code analysis",
            .test_run => "Run test suite",
            .benchmark_prev => "CRITICAL: Compare to baseline",
            .swe_fix => "SWE Agent error fixing",
            .benchmark_external => "Compare to external tools",
            .benchmark_theoretical => "Gap to theoretical maximum",
            .delta_report => "Generate improvement report",
            .optimize => "Optimize if needed",
            .docs => "Generate documentation",
            .toxic_verdict => "Critical self-assessment",
            .git => "Commit and push changes",
            .loop_decision => "Decide next iteration",
            .fly_deploy => "Auto-deploy to Fly.io cloud",
            .eternal_self_evolution => "ETERNAL: Pipeline analyzes itself",
            .self_referential_evolution => "SELF-REFERENTIAL: Pipeline improves itself (circular bootstrapping)",
            .vision_led_test => "VISION: Camera-based LED verification for FPGA hardware",
            .perplexity_scholar => "SCHOLAR: Research-assisted error fixing via Perplexity Sonar Pro",
            .spec_lint => "SPEC_LINT: Validate .tri spec syntax and types before code generation",
        };
    }

    /// CLI command name for `tri chain <cmd>`.
    pub fn getCliName(self: ChainLink) []const u8 {
        return switch (self) {
            .tvc_gate => "cache",
            .baseline => "baseline",
            .metrics => "metrics",
            .pas_analyze => "patterns",
            .tech_tree => "tree",
            .strict_check => "check-spec",
            .spec_create => "spec",
            .code_generate => "codegen",
            .sacred_analyze => "analyze",
            .test_run => "test",
            .benchmark_prev => "bench",
            .swe_fix => "fix",
            .benchmark_external => "bench-ext",
            .benchmark_theoretical => "bench-theory",
            .delta_report => "delta",
            .optimize => "optimize",
            .docs => "docs",
            .toxic_verdict => "verdict",
            .git => "git",
            .loop_decision => "loop",
            .fly_deploy => "deploy",
            .eternal_self_evolution => "evolve",
            .self_referential_evolution => "self-ref",
            .vision_led_test => "fpga-test",
            .perplexity_scholar => "research",
            .spec_lint => "lint-spec",
        };
    }

    /// MCP tool name: chain_<name>.
    pub fn getMcpToolName(self: ChainLink) []const u8 {
        return switch (self) {
            .tvc_gate => "chain_cache",
            .baseline => "chain_baseline",
            .metrics => "chain_metrics",
            .pas_analyze => "chain_patterns",
            .tech_tree => "chain_tree",
            .strict_check => "chain_check_spec",
            .spec_create => "chain_spec",
            .code_generate => "chain_codegen",
            .sacred_analyze => "chain_analyze",
            .test_run => "chain_test",
            .benchmark_prev => "chain_bench",
            .swe_fix => "chain_fix",
            .benchmark_external => "chain_bench_ext",
            .benchmark_theoretical => "chain_bench_theory",
            .delta_report => "chain_delta",
            .optimize => "chain_optimize",
            .docs => "chain_docs",
            .toxic_verdict => "chain_verdict",
            .git => "chain_git",
            .loop_decision => "chain_loop",
            .fly_deploy => "chain_deploy",
            .eternal_self_evolution => "chain_evolve",
            .self_referential_evolution => "chain_self_ref",
            .vision_led_test => "chain_fpga_test",
            .perplexity_scholar => "chain_research",
            .spec_lint => "chain_lint_spec",
        };
    }

    /// Resolve CLI name to ChainLink.
    pub fn fromCliName(name: []const u8) ?ChainLink {
        inline for (0..chain_link_count) |i| {
            const link: ChainLink = @enumFromInt(i);
            if (std.mem.eql(u8, name, link.getCliName())) return link;
        }
        return null;
    }

    /// Resolve MCP tool name to ChainLink.
    pub fn fromMcpToolName(name: []const u8) ?ChainLink {
        inline for (0..chain_link_count) |i| {
            const link: ChainLink = @enumFromInt(i);
            if (std.mem.eql(u8, name, link.getMcpToolName())) return link;
        }
        return null;
    }

    /// Get the AgentRole that owns this link.
    pub fn getOwnerRole(self: ChainLink) ?AgentRole {
        for (ALL_ROLES) |role| {
            if (role.ownsLink(self)) return role;
        }
        return null;
    }

    pub fn isCritical(self: ChainLink) bool {
        return switch (self) {
            .tvc_gate, .benchmark_prev, .test_run, .loop_decision, .code_generate, .eternal_self_evolution, .self_referential_evolution, .spec_lint => true,
            else => false,
        };
    }

    pub fn isMandatory(self: ChainLink) bool {
        return self != .optimize and self != .swe_fix and self != .fly_deploy and self != .perplexity_scholar;
    }

    pub fn next(self: ChainLink) ?ChainLink {
        const val = @intFromEnum(self);
        if (val >= chain_link_count - 1) return null;
        return @enumFromInt(val + 1);
    }

    pub fn prev(self: ChainLink) ?ChainLink {
        const val = @intFromEnum(self);
        if (val == 0) return null;
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
    results: [chain_link_count]LinkResult, // Links 0-25 — v4.4
    improvement_rate: f64,
    task_description: []const u8,
    verbose: bool,
    /// Cached response from TVC Gate (if hit)
    cached_response: ?[]const u8,
    /// TVC Gate skipped pipeline (cache hit)
    tvc_hit: bool,
    /// Self-evolution: pipeline can add new links
    self_evolution_enabled: bool,

    pub fn init(allocator: std.mem.Allocator, version: u32, task: []const u8) PipelineState {
        var results: [chain_link_count]LinkResult = undefined;
        inline for (0..chain_link_count) |i| {
            results[i] = LinkResult.init(@enumFromInt(i));
        }

        return .{
            .allocator = allocator,
            .version = version,
            .phase = .tvc_gate, // Start at TVC Gate (Link 0)
            .status = .not_started,
            .started_at = std.time.timestamp(),
            .results = results,
            .improvement_rate = 0.0,
            .task_description = task,
            .verbose = false,
            .cached_response = null,
            .tvc_hit = false,
            .self_evolution_enabled = true,
        };
    }

    pub fn getResult(self: *const PipelineState, link: ChainLink) *const LinkResult {
        const idx = @intFromEnum(link);
        return &self.results[idx];
    }

    pub fn setResult(self: *PipelineState, link: ChainLink, result: LinkResult) void {
        const idx = @intFromEnum(link);
        self.results[idx] = result;
    }

    pub fn isImmortal(self: *const PipelineState) bool {
        return self.improvement_rate > PHI_INVERSE;
    }

    pub fn getNeedleStatus(self: *const PipelineState) NeedleStatus {
        return checkNeedleThreshold(self.improvement_rate);
    }

    pub fn canContinue(self: *const PipelineState) bool {
        // TVC hit means we can skip the rest
        if (self.tvc_hit) return true;

        // Check if all mandatory links up to current passed
        for (self.results, 0..) |result, i| {
            const link: ChainLink = @enumFromInt(i);
            if (link.isMandatory() and result.status == .failed) {
                return false;
            }
            if (@intFromEnum(link) > @intFromEnum(self.phase)) {
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
        return @as(f64, @floatFromInt(self.getCompletedCount())) / @as(f64, @floatFromInt(chain_link_count)) * 100.0;
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
// AGENT ROLE (v5.0 — Role Split)
// ============================================================================

pub const AgentRole = enum {
    planner, // Links 0-6: TVC → spec creation
    coder, // Links 7-8: codegen → sacred analysis
    reviewer, // Links 8-10: analysis → benchmark comparison
    tester, // Links 9-13: test → theoretical benchmark (no LLM needed)
    integrator, // Links 14-19: report → loop decision

    pub fn getName(self: AgentRole) []const u8 {
        return switch (self) {
            .planner => "PLANNER",
            .coder => "CODER",
            .reviewer => "REVIEWER",
            .tester => "TESTER",
            .integrator => "INTEGRATOR",
        };
    }

    pub fn getEmoji(self: AgentRole) []const u8 {
        return switch (self) {
            .planner => "\xf0\x9f\xa7\xa0",
            .coder => "\xf0\x9f\x92\xbb",
            .reviewer => "\xf0\x9f\x94\x8d",
            .tester => "\xf0\x9f\xa7\xaa",
            .integrator => "\xf0\x9f\x93\xa6",
        };
    }

    pub fn getLabel(self: AgentRole) []const u8 {
        return switch (self) {
            .planner => "role:planner",
            .coder => "role:coder",
            .reviewer => "role:reviewer",
            .tester => "role:tester",
            .integrator => "role:integrator",
        };
    }

    /// Returns the range of chain links this role is responsible for.
    /// start_link is inclusive, end_link is exclusive.
    pub fn getLinkRange(self: AgentRole) struct { start: u8, end: u8 } {
        return switch (self) {
            .planner => .{ .start = 0, .end = 7 }, // Links 0-6
            .coder => .{ .start = 7, .end = 9 }, // Links 7-8
            .reviewer => .{ .start = 9, .end = 11 }, // Links 9-10
            .tester => .{ .start = 11, .end = 14 }, // Links 11-13
            .integrator => .{ .start = 14, .end = 26 }, // Links 14-25
        };
    }

    /// Check if a given chain link belongs to this role.
    pub fn ownsLink(self: AgentRole, link: ChainLink) bool {
        const range = self.getLinkRange();
        const link_idx = @intFromEnum(link);
        return link_idx >= range.start and link_idx < range.end;
    }

    /// Whether this role requires an LLM (Claude/GLM).
    pub fn requiresLLM(self: AgentRole) bool {
        return self != .tester; // Tester is pure Zig: build test + benchmark
    }

    /// Detect role from issue label string (e.g. "role:planner").
    pub fn fromLabel(label: []const u8) ?AgentRole {
        if (std.mem.eql(u8, label, "role:planner")) return .planner;
        if (std.mem.eql(u8, label, "role:coder")) return .coder;
        if (std.mem.eql(u8, label, "role:reviewer")) return .reviewer;
        if (std.mem.eql(u8, label, "role:tester")) return .tester;
        if (std.mem.eql(u8, label, "role:integrator")) return .integrator;
        return null;
    }

    /// The next role in the pipeline chain.
    pub fn nextRole(self: AgentRole) ?AgentRole {
        return switch (self) {
            .planner => .coder,
            .coder => .reviewer,
            .reviewer => .tester,
            .tester => .integrator,
            .integrator => null,
        };
    }

    /// The previous role (supervisor of this role, per RTADev pattern).
    pub fn supervisor(self: AgentRole) ?AgentRole {
        return switch (self) {
            .planner => null,
            .coder => .planner,
            .reviewer => .coder,
            .tester => .reviewer,
            .integrator => .tester,
        };
    }
};

/// Ordered list of all 5 roles for iteration.
pub const ALL_ROLES = [_]AgentRole{
    .planner, .coder, .reviewer, .tester, .integrator,
};

// ============================================================================
// SPEC NAME UTILITY (deduplicated from pipeline_executor)
// ============================================================================

/// Derive a sanitized spec name from a task description.
/// "add worktree command" → "add_worktree_command"
pub fn deriveSpecName(task: []const u8, buf: *[256]u8) []const u8 {
    var len: usize = 0;
    for (task) |c| {
        if (len >= buf.len - 1) break;
        if (c == ' ' or c == '-') {
            buf[len] = '_';
            len += 1;
        } else if ((c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_') {
            buf[len] = c;
            len += 1;
        } else if (c >= 'A' and c <= 'Z') {
            buf[len] = c + 32; // lowercase
            len += 1;
        }
    }
    return buf[0..len];
}

/// Build spec path from task: "specs/tri/<name>.tri"
pub fn deriveSpecPath(task: []const u8, name_buf: *[256]u8, path_buf: *[512]u8) ?[]const u8 {
    const spec_name = deriveSpecName(task, name_buf);
    return std.fmt.bufPrint(path_buf, "specs/tri/{s}.tri", .{spec_name}) catch null;
}

/// Build generated output path from task: "generated/<name>.zig"
pub fn deriveOutputPath(task: []const u8, name_buf: *[256]u8, path_buf: *[512]u8) ?[]const u8 {
    const spec_name = deriveSpecName(task, name_buf);
    return std.fmt.bufPrint(path_buf, "generated/{s}.zig", .{spec_name}) catch null;
}

// ============================================================================
// LINK GROUP — v5.1 Parallel Execution Groups
// ============================================================================

pub const LinkGroup = struct {
    links: []const ChainLink,
    parallel: bool,
    name: []const u8,
};

/// Returns the execution plan: ordered groups of links.
/// Parallel groups run concurrently; sequential groups run one-by-one.
pub fn getExecutionPlan() []const LinkGroup {
    return &EXECUTION_PLAN;
}

const EXECUTION_PLAN = [_]LinkGroup{
    // Group 0: TVC Gate (must run first, alone)
    .{ .links = &.{.tvc_gate}, .parallel = false, .name = "TVC Gate" },
    // Group A: Read-only analysis (parallel)
    .{ .links = &.{ .baseline, .metrics, .pas_analyze }, .parallel = true, .name = "Analysis (parallel)" },
    // Group B: Sequential dependency chain
    .{ .links = &.{.tech_tree}, .parallel = false, .name = "Tech Tree" },
    .{ .links = &.{.strict_check}, .parallel = false, .name = "Strict Check" },
    .{ .links = &.{.spec_create}, .parallel = false, .name = "Spec Create" },
    .{ .links = &.{.spec_lint}, .parallel = false, .name = "Spec Lint" },
    .{ .links = &.{.code_generate}, .parallel = false, .name = "Code Generate" },
    .{ .links = &.{.sacred_analyze}, .parallel = false, .name = "Sacred Analyze" },
    .{ .links = &.{.test_run}, .parallel = false, .name = "Test Run" },
    .{ .links = &.{.benchmark_prev}, .parallel = false, .name = "Benchmark Prev" },
    .{ .links = &.{.swe_fix}, .parallel = false, .name = "SWE Fix" },
    // Group C: Independent benchmarks (parallel)
    .{ .links = &.{ .benchmark_external, .benchmark_theoretical }, .parallel = true, .name = "Benchmarks (parallel)" },
    // Group D: Sequential finalization
    .{ .links = &.{.delta_report}, .parallel = false, .name = "Delta Report" },
    .{ .links = &.{.optimize}, .parallel = false, .name = "Optimize" },
    .{ .links = &.{.docs}, .parallel = false, .name = "Docs" },
    .{ .links = &.{.toxic_verdict}, .parallel = false, .name = "Toxic Verdict" },
    .{ .links = &.{.git}, .parallel = false, .name = "Git" },
    .{ .links = &.{.loop_decision}, .parallel = false, .name = "Loop Decision" },
    .{ .links = &.{.fly_deploy}, .parallel = false, .name = "Fly Deploy" },
    .{ .links = &.{.eternal_self_evolution}, .parallel = false, .name = "Self Evolution" },
    .{ .links = &.{.self_referential_evolution}, .parallel = false, .name = "Self Referential" },
    .{ .links = &.{.vision_led_test}, .parallel = false, .name = "Vision LED Test" },
    .{ .links = &.{.perplexity_scholar}, .parallel = false, .name = "Perplexity Scholar" },
};

// ============================================================================
// MODEL ROULETTE — v5.1 Per-Role LLM Routing
// ============================================================================

/// Get the model to use for a given role.
/// Checks role-specific env var, then CLAUDE_MODEL, then falls back to "glm-5".
pub fn getModelForRole(role: AgentRole) [64]u8 {
    var result: [64]u8 = undefined;
    @memset(&result, 0);

    // 1. Check role-specific env var
    const env_name = switch (role) {
        .planner => "TRINITY_MODEL_PLANNER",
        .coder => "TRINITY_MODEL_CODER",
        .reviewer => "TRINITY_MODEL_REVIEWER",
        .tester => "TRINITY_MODEL_TESTER",
        .integrator => "TRINITY_MODEL_INTEGRATOR",
    };

    if (std.posix.getenv(env_name)) |val| {
        const len = @min(val.len, result.len);
        @memcpy(result[0..len], val[0..len]);
        return result;
    }

    // 2. Fallback to CLAUDE_MODEL
    if (std.posix.getenv("CLAUDE_MODEL")) |val| {
        const len = @min(val.len, result.len);
        @memcpy(result[0..len], val[0..len]);
        return result;
    }

    // 3. Default — claude-sonnet-4-6 (falls back to glm-5 if z.ai proxy)
    const default = "claude-sonnet-4-6";
    @memcpy(result[0..default.len], default);
    return result;
}

/// Get model string as a slice (trims trailing zeros).
pub fn getModelSlice(buf: *const [64]u8) []const u8 {
    var len: usize = 0;
    while (len < buf.len and buf[len] != 0) : (len += 1) {}
    return buf[0..len];
}

// ============================================================================
// TESTS
// ============================================================================

test "ChainLink enumeration" {
    const tvc_gate = ChainLink.tvc_gate;
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(tvc_gate));
    try std.testing.expectEqualStrings("TVC_GATE", tvc_gate.getName());
    try std.testing.expect(tvc_gate.isCritical()); // TVC Gate is critical
    try std.testing.expect(tvc_gate.isMandatory());

    const baseline = ChainLink.baseline;
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(baseline));
    try std.testing.expectEqualStrings("BASELINE", baseline.getName());
    try std.testing.expect(!baseline.isCritical());
    try std.testing.expect(baseline.isMandatory());

    const benchmark = ChainLink.benchmark_prev;
    try std.testing.expectEqual(@as(u8, 10), @intFromEnum(benchmark)); // v4.0: link 10
    try std.testing.expect(benchmark.isCritical());

    const optimize = ChainLink.optimize;
    try std.testing.expect(!optimize.isMandatory());
}

test "ChainLink navigation" {
    const tvc_gate = ChainLink.tvc_gate;
    try std.testing.expectEqual(ChainLink.baseline, tvc_gate.next().?);
    try std.testing.expectEqual(@as(?ChainLink, null), tvc_gate.prev());

    const baseline = ChainLink.baseline;
    try std.testing.expectEqual(ChainLink.metrics, baseline.next().?);
    try std.testing.expectEqual(ChainLink.tvc_gate, baseline.prev().?);

    const git = ChainLink.git;
    try std.testing.expectEqual(ChainLink.loop_decision, git.next().?);
    try std.testing.expectEqual(ChainLink.toxic_verdict, git.prev().?);

    const loop = ChainLink.loop_decision;
    try std.testing.expectEqual(ChainLink.fly_deploy, loop.next().?); // v4.0: next is fly_deploy
    try std.testing.expectEqual(ChainLink.git, loop.prev().?); // v4.0: prev is git

    const fly_deploy = ChainLink.fly_deploy;
    try std.testing.expectEqual(ChainLink.eternal_self_evolution, fly_deploy.next().?);

    const eternal = ChainLink.eternal_self_evolution;
    try std.testing.expectEqual(ChainLink.self_referential_evolution, eternal.next().?); // v4.1

    const self_referential = ChainLink.self_referential_evolution;
    try std.testing.expectEqual(ChainLink.vision_led_test, self_referential.next().?); // v4.2

    const vision_led = ChainLink.vision_led_test;
    try std.testing.expectEqual(ChainLink.perplexity_scholar, vision_led.next().?); // v4.3

    const scholar = ChainLink.perplexity_scholar;
    try std.testing.expectEqual(ChainLink.spec_lint, scholar.next().?); // v4.3

    const spec_lint = ChainLink.spec_lint;
    try std.testing.expectEqual(@as(?ChainLink, null), spec_lint.next()); // v4.4: last link
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
    try std.testing.expectEqual(ChainLink.tvc_gate, state.phase); // Starts at TVC Gate
    try std.testing.expectEqual(PipelineStatus.not_started, state.status);
    try std.testing.expectEqual(@as(u32, 0), state.getCompletedCount());
    try std.testing.expect(state.cached_response == null);
    try std.testing.expect(!state.tvc_hit);
}

test "AgentRole link ownership" {
    // Planner owns links 0-6
    try std.testing.expect(AgentRole.planner.ownsLink(.tvc_gate));
    try std.testing.expect(AgentRole.planner.ownsLink(.spec_create));
    try std.testing.expect(!AgentRole.planner.ownsLink(.code_generate)); // link 7

    // Coder owns links 7-8
    try std.testing.expect(AgentRole.coder.ownsLink(.code_generate));
    try std.testing.expect(AgentRole.coder.ownsLink(.sacred_analyze));
    try std.testing.expect(!AgentRole.coder.ownsLink(.test_run)); // link 9

    // Tester doesn't need LLM
    try std.testing.expect(!AgentRole.tester.requiresLLM());
    try std.testing.expect(AgentRole.coder.requiresLLM());
}

test "AgentRole chain" {
    try std.testing.expectEqual(AgentRole.coder, AgentRole.planner.nextRole().?);
    try std.testing.expectEqual(AgentRole.reviewer, AgentRole.coder.nextRole().?);
    try std.testing.expectEqual(@as(?AgentRole, null), AgentRole.integrator.nextRole());
    try std.testing.expectEqual(AgentRole.planner, AgentRole.coder.supervisor().?);
}

test "AgentRole fromLabel" {
    try std.testing.expectEqual(AgentRole.planner, AgentRole.fromLabel("role:planner").?);
    try std.testing.expectEqual(AgentRole.tester, AgentRole.fromLabel("role:tester").?);
    try std.testing.expect(AgentRole.fromLabel("agent:ralph") == null);
}

test "deriveSpecName" {
    var buf: [256]u8 = undefined;
    try std.testing.expectEqualStrings("add_dark_mode", deriveSpecName("add dark mode", &buf));
    try std.testing.expectEqualStrings("fix_bug_123", deriveSpecName("Fix Bug-123", &buf));
}

test "getExecutionPlan has all 26 links" {
    const plan = getExecutionPlan();
    var total_links: usize = 0;
    for (plan) |group| {
        total_links += group.links.len;
    }
    try std.testing.expectEqual(@as(usize, 26), total_links);
}

test "getExecutionPlan parallel groups" {
    const plan = getExecutionPlan();
    // Group 1 (index 1) should be parallel with 3 links
    try std.testing.expect(plan[1].parallel);
    try std.testing.expectEqual(@as(usize, 3), plan[1].links.len);
    // Group with benchmarks should also be parallel
    var found_bench_parallel = false;
    for (plan) |group| {
        if (group.parallel and group.links.len == 2) {
            for (group.links) |link| {
                if (link == .benchmark_external) found_bench_parallel = true;
            }
        }
    }
    try std.testing.expect(found_bench_parallel);
}

test "getModelForRole returns default" {
    const buf = getModelForRole(.planner);
    const model = getModelSlice(&buf);
    // Should return env var or default "glm-5"
    try std.testing.expect(model.len > 0);
}
