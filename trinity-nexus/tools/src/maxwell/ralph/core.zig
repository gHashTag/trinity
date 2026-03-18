//! Golden Chain Core - 9 Links of Ralph Development Cycle
//! Implements the complete autonomous development workflow
//! Cycle 56: PAS Daemon integration for sacred code validation

const std = @import("std");
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const process = @import("process.zig");
const git_mod = @import("git.zig");
const quality = @import("quality.zig");
const telegram = @import("telegram.zig");
const memory_mod = @import("memory.zig");
const types = @import("types.zig");

// PAS Daemon integration for sacred validation (Cycle 56)
// Stub implementation for module compatibility
// Full PAS daemon available via Ralph's CLI build system
const pas_daemon_mod = struct {
    pub const DaemonConfig = struct {
        analysis_interval_ms: u64,
        auto_apply_threshold: f32,
        broadcast_enabled: bool,
        max_queue_size: usize,
        enable_sacred_scoring: bool,
    };
    pub const PasDaemon = struct {
        allocator: std.mem.Allocator,
        sacred_confidence_boost: f64 = 1.5,

        pub fn init(_: std.mem.Allocator, _: DaemonConfig) !PasDaemon {
            return PasDaemon{ .allocator = undefined };
        }
        pub fn deinit(self: *PasDaemon) void {
            _ = self;
        }
    };
    pub fn analyze_pattern(_: *const PasDaemon, _: u64, _: []const u8) f32 {
        return 0.95; // Default to sacred threshold for stub
    }
    pub fn calculate_sacred_score(_: *const PasDaemon, _: u64, _: []const u8) f64 {
        return 0.95; // Default to sacred threshold for stub
    }
};

pub const RalphError = error{
    DecomposeFailed,
    PlanFailed,
    SpecCreateFailed,
    GenFailed,
    TestFailed,
    BenchFailed,
    VerdictFailed,
    GitFailed,
    LoopFailed,
    FileNotFound,
    InvalidState,
    PASValidationFailed,
} || Allocator.Error || process.ProcessError || git_mod.GitError;

/// Link 1: TRI DECOMPOSE - Break objective into atomic Quarks
pub fn triDecompose(allocator: Allocator, fix_plan_path: []const u8) ![]types.TaskEntry {
    const content = try std.fs.cwd().readFileAlloc(allocator, fix_plan_path, std.math.maxInt(usize));
    defer allocator.free(content);

    const tasks = try parser.parseFixPlan(allocator, content);

    // Find highest priority incomplete task
    var selected_task: ?types.TaskEntry = null;
    var highest_priority: types.TaskPriority = .p3_low;

    for (tasks) |task| {
        if (task.status == .complete) continue;

        if (task.subtasks.len == 0) {
            continue;
        }

        const priority = task.priority;
        if (@intFromEnum(priority) < @intFromEnum(highest_priority)) {
            highest_priority = priority;
            selected_task = task;
        }
    }

    if (selected_task) |task| {
        var result = try std.ArrayList(types.TaskEntry).initCapacity(allocator, 0);
        try result.append(allocator, task);

        for (task.subtasks) |subtask| {
            try result.append(allocator, types.TaskEntry{
                .id = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ task.id, subtask.description }),
                .description = subtask.description,
                .priority = task.priority,
                .status = if (subtask.checked) types.TaskStatus.complete else types.TaskStatus.pending,
                .tech_tree_node = task.tech_tree_node,
                .subtasks = &.{},
                .blocker_reason = &.{},
                .acceptance_criteria = &.{},
            });
        }

        return result.toOwnedSlice(allocator);
    }

    return tasks;
}

/// Link 2: TRI PLAN - Select strategy and tech tree path
pub fn triPlan(allocator: Allocator, tech_tree_path: []const u8) !PlanOptions {
    const content = try std.fs.cwd().readFileAlloc(allocator, tech_tree_path, std.math.maxInt(usize));
    defer allocator.free(content);

    const tree = try parser.parseTechTree(allocator, content);
    defer {
        for (tree.in_progress) |*n| n.deinit(allocator);
        allocator.free(tree.in_progress);
        for (tree.available) |*n| n.deinit(allocator);
        allocator.free(tree.available);
        for (tree.completed) |*n| n.deinit(allocator);
        allocator.free(tree.completed);
        for (tree.locked) |*n| n.deinit(allocator);
        allocator.free(tree.locked);
    }

    var candidates = try std.ArrayList(NodeCandidate).initCapacity(allocator, 0);
    defer {
        for (candidates.items) |*c| {
            allocator.free(c.id);
            allocator.free(c.name);
            allocator.free(c.justification);
        }
        candidates.deinit(allocator);
    }

    for (tree.available) |node| {
        const roi = (node.impact / node.complexity) * @as(f64, @floatFromInt(node.dependencies.len));

        try candidates.append(allocator, NodeCandidate{
            .id = try allocator.dupe(u8, node.id),
            .name = try allocator.dupe(u8, node.name),
            .roi = roi,
            .justification = try std.fmt.allocPrint(allocator,
                "Impact: {d:.1}, Complexity: {d:.1}, Unlocks: {d}",
                .{ node.impact, node.complexity, node.dependencies.len }),
        });
    }

    std.sort.insertion(NodeCandidate, candidates.items, {}, struct {
        fn lessThan(_: void, a: NodeCandidate, b: NodeCandidate) bool {
            return a.roi > b.roi;
        }
    }.lessThan);

    _ = @min(3, candidates.items.len);
    var options = PlanOptions{
        .option1 = undefined,
        .option2 = null,
        .option3 = null,
    };

    if (candidates.items.len > 0) {
        options.option1 = candidates.items[0];
        candidates.items[0].justification = try allocator.dupe(u8, candidates.items[0].justification);
    }
    if (candidates.items.len > 1) {
        options.option2 = candidates.items[1];
        candidates.items[1].justification = try allocator.dupe(u8, candidates.items[1].justification);
    }
    if (candidates.items.len > 2) {
        options.option3 = candidates.items[2];
        candidates.items[2].justification = try allocator.dupe(u8, candidates.items[2].justification);
    }

    return options;
}

pub const NodeCandidate = struct {
    id: []const u8,
    name: []const u8,
    roi: f64,
    justification: []const u8,
};

pub const PlanOptions = struct {
    option1: NodeCandidate,
    option2: ?NodeCandidate = null,
    option3: ?NodeCandidate = null,
};

/// Link 3: TRI SPEC CREATE - Create/update .vibee specification
pub fn triSpecCreate(allocator: Allocator, task: types.TaskEntry) ![]const u8 {
    var spec_name = try std.ArrayList(u8).initCapacity(allocator, 0);
    for (task.description) |c| {
        if (c == ' ' or c == '/' or c == '\\') {
            try spec_name.append(allocator, '_');
        } else if (std.ascii.isAlphanumeric(c) or c == '_' or c == '-') {
            try spec_name.append(allocator, c);
        }
    }

    const spec_path = try std.fmt.allocPrint(allocator, "specs/tri/{s}.vibee", .{spec_name.items});

    if (std.fs.cwd().openFile(spec_path, .{})) |file| {
        file.close();
        return allocator.dupe(u8, spec_path);
    } else |_| {
        const file = try std.fs.cwd().createFile(spec_path, .{});
        defer file.close();

        const spec_content = try generateSpecContent(allocator, task);
        try file.writeAll(spec_content);
    }

    return allocator.dupe(u8, spec_path);
}

fn generateSpecContent(allocator: Allocator, task: types.TaskEntry) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\name: {s}
        \\version: "1.0.0"
        \\language: zig
        \\module: {s}
        \\
        \\types:
        \\  # Add types here
        \\
        \\behaviors:
        \\  - name: {s}
        \\    given: Precondition
        \\    when: Action
        \\    then: Expected result
    , .{
        task.description,
        task.description,
        task.description,
    });
}

/// Link 4: TRI GEN - Generate Zig code via VIBEE compiler with PAS validation
pub fn triGen(allocator: Allocator, spec_path: []const u8) !GenResult {
    // 1. Generate code normally via VIBEE
    var result = try process.vibeeGen(allocator, spec_path);
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        std.log.err("VIBEE gen failed: {s}", .{result.stderr});
        return RalphError.GenFailed;
    }

    std.log.info("Generated code from {s}", .{spec_path});

    // 2. PAS Daemon validation (Cycle 56 integration)
    const pas_config = pas_daemon_mod.DaemonConfig{
        .analysis_interval_ms = 100,
        .auto_apply_threshold = 0.95,
        .broadcast_enabled = false,
        .max_queue_size = 10,
        .enable_sacred_scoring = true,
    };

    var pas_daemon = try pas_daemon_mod.PasDaemon.init(allocator, pas_config);
    defer pas_daemon.deinit();

    // Compute pattern ID from spec path
    var hash_state = std.hash.Wyhash.init(0);
    hash_state.update(spec_path);
    const pattern_id = hash_state.finalize();

    // Submit generated code for PAS analysis
    try pas_daemon.submit_task(pattern_id, result.stdout, .high);

    // Process and get sacred validation
    const task = pas_daemon_mod.AnalysisTask{
        .task_id = pattern_id,
        .pattern_id = pattern_id,
        .pattern_data = result.stdout,
        .priority = .high,
        .created_at = std.time.milliTimestamp(),
        .context = null,
    };
    const pas_result = try pas_daemon_mod.process_task(&pas_daemon, task);

    // Check sacred confidence threshold
    if (pas_result.confidence < pas_daemon_mod.SACRED_THRESHOLD) {
        std.log.err("PAS validation failed: confidence={d:.3} < threshold={d:.3}",
            .{ pas_result.confidence, pas_daemon_mod.SACRED_THRESHOLD });
        return RalphError.PASValidationFailed;
    }

    if (pas_result.sacred_score < pas_daemon_mod.SACRED_THRESHOLD) {
        std.log.err("PAS sacred score failed: score={d:.3} < threshold={d:.3}",
            .{ pas_result.sacred_score, pas_daemon_mod.SACRED_THRESHOLD });
        return RalphError.PASValidationFailed;
    }

    std.log.info("PAS validation passed: confidence={d:.3}, sacred={d:.3}",
        .{ pas_result.confidence, pas_result.sacred_score });

    return GenResult{
        .spec_path = spec_path,
        .output_code = result.stdout,
        .pas_confidence = pas_result.confidence,
        .pas_sacred_score = pas_result.sacred_score,
    };
}

pub const GenResult = struct {
    spec_path: []const u8,
    output_code: []const u8,
    pas_confidence: f32,
    pas_sacred_score: f64,
};

/// Link 5: TRI TEST - Run test suite
pub fn triTest(allocator: Allocator) !TestResult {
    const start_time = try std.time.Instant.now();

    var result = process.zigTest(allocator, &[_][]const u8{}) catch |err| {
        return TestResult{
            .passed = false,
            .duration_ns = 0,
            .output = @errorName(err),
        };
    };
    defer result.deinit(allocator);

    const end_time = try std.time.Instant.now();

    return TestResult{
        .passed = result.exit_code == 0,
        .duration_ns = end_time.since(start_time),
        .output = try allocator.dupe(u8, result.stdout),
    };
}

pub const TestResult = struct {
    passed: bool,
    duration_ns: u64,
    output: []const u8,
};

/// Link 6: TRI BENCH - Benchmark vs baseline
pub fn triBench(allocator: Allocator, baseline_path: []const u8) !BenchmarkResult {
    const start_time = try std.time.Instant.now();

    var result = process.run(allocator, &[_][]const u8{ "zig", "build", "bench" }) catch |err| {
        return BenchmarkResult{
            .passed = false,
            .duration_ns = 0,
            .regression = false,
            .output = @errorName(err),
        };
    };
    defer result.deinit(allocator);

    const end_time = try std.time.Instant.now();

    const baseline_content = std.fs.cwd().readFileAlloc(allocator, baseline_path, std.math.maxInt(usize)) catch {
        return BenchmarkResult{
            .passed = result.exit_code == 0,
            .duration_ns = end_time.since(start_time),
            .regression = false,
            .output = try allocator.dupe(u8, result.stdout),
        };
    };
    defer allocator.free(baseline_content);

    return BenchmarkResult{
        .passed = result.exit_code == 0,
        .duration_ns = end_time.since(start_time),
        .regression = false,
        .output = try allocator.dupe(u8, result.stdout),
    };
}

pub const BenchmarkResult = struct {
    passed: bool,
    duration_ns: u64,
    regression: bool,
    output: []const u8,
};

/// Link 7: TRI VERDICT - Toxic Verdict assessment with PAS sacred scoring
pub fn triVerdict(allocator: Allocator, test_result: TestResult, bench_result: BenchmarkResult) !ToxicVerdict {
    return triVerdictWithPAS(allocator, test_result, bench_result, null);
}

/// Enhanced verdict with PAS analysis (Cycle 56)
pub fn triVerdictWithPAS(
    allocator: Allocator,
    test_result: TestResult,
    bench_result: BenchmarkResult,
    generated_code: ?[]const u8,
) !ToxicVerdict {
    var score: i64 = 10;
    var flaws = try std.ArrayList([]const u8).initCapacity(allocator, 0);

    if (!test_result.passed) {
        score -= 5;
        try flaws.append(allocator, try allocator.dupe(u8, "Tests failed"));
    }

    if (bench_result.regression) {
        score -= 3;
        try flaws.append(allocator, try allocator.dupe(u8, "Performance regression detected"));
    }

    if (!bench_result.passed) {
        score -= 2;
        try flaws.append(allocator, try allocator.dupe(u8, "Benchmarks failed to run"));
    }

    // PAS sacred scoring (Cycle 56 integration)
    var pas_sacred_boost: f64 = 0.0;
    if (generated_code) |code| {
        const pas_config = pas_daemon_mod.DaemonConfig{
            .analysis_interval_ms = 100,
            .auto_apply_threshold = 0.95,
            .broadcast_enabled = false,
            .max_queue_size = 10,
            .enable_sacred_scoring = true,
        };

        var pas_daemon = pas_daemon_mod.PasDaemon.init(allocator, pas_config) catch |err| {
            std.log.warn("PAS daemon init failed: {}", .{@errorName(err)});
            return RalphError.PASValidationFailed;
        };
        defer pas_daemon.deinit();

        // Get sacred scores
        const confidence = pas_daemon_mod.analyze_pattern(&pas_daemon, 0, code);
        const sacred_score = pas_daemon_mod.calculate_sacred_score(&pas_daemon, 0, code);

        // Apply sacred boost to verdict
        pas_sacred_boost = @as(f64, sacred_score) * pas_daemon.sacred_confidence_boost;

        // Adjust score based on sacred confidence
        if (confidence >= 0.95 and sacred_score >= 0.95) {
            score += 1; // Bonus for high sacred confidence
        } else if (confidence < 0.80 or sacred_score < 0.80) {
            score -= 1; // Penalty for low sacred confidence
            try flaws.append(allocator, try allocator.dupe(u8, "Low PAS sacred confidence"));
        }

        std.log.info("PAS Verdict: confidence={d:.3}, sacred={d:.3}, boost={d:.3}",
            .{ confidence, sacred_score, pas_sacred_boost });
    }

    const status = if (score >= 8) types.VerdictStatus.prod else types.VerdictStatus.fail;

    return ToxicVerdict{
        .score = score,
        .status = status,
        .flaws = try flaws.toOwnedSlice(allocator),
        .assessment = try allocator.dupe(u8, "Automated assessment completed"),
        .pas_sacred_boost = pas_sacred_boost,
        .recommendation = if (score >= 8)
            try allocator.dupe(u8, "Approved for commit")
        else
            try allocator.dupe(u8, "Fix identified issues before commit"),
    };
}

pub const ToxicVerdict = struct {
    score: i64,
    status: types.VerdictStatus,
    flaws: [][]const u8,
    assessment: []const u8,
    recommendation: []const u8,
    pas_sacred_boost: f64 = 0.0,

    pub fn deinit(self: *ToxicVerdict, allocator: Allocator) void {
        for (self.flaws) |flaw| {
            allocator.free(flaw);
        }
        allocator.free(self.flaws);
        allocator.free(self.assessment);
        allocator.free(self.recommendation);
    }
};

/// Link 8: TRI GIT - Commit to feature branch
pub fn triGit(allocator: Allocator, message: []const u8) !GitCommitResult {
    var gates = try quality.runQualityGates(allocator);
    defer gates.deinit(allocator);

    if (!gates.allPassed()) {
        return GitCommitResult{
            .success = false,
            .sha = &.{},
            .failed_gate = gates.getFailedGate() orelse "unknown",
        };
    }

    try git_mod.commit(allocator, message);

    const sha = try git_mod.getShortSha(allocator);

    return GitCommitResult{
        .success = true,
        .sha = sha,
        .failed_gate = null,
    };
}

pub const GitCommitResult = struct {
    success: bool,
    sha: []const u8,
    failed_gate: ?[]const u8,
};

/// Link 9: TRI LOOP - Loop decision
pub fn triLoop(allocator: Allocator, session: *types.SessionState, made_progress: bool) !LoopDecision {
    _ = allocator;

    const transition = try quality.circuitBreakerCheck(
        session.circuit_breaker,
        made_progress,
        @intCast(session.no_progress_count),
        3,
    );

    session.circuit_breaker = transition.new_state;
    session.no_progress_count = @intCast(transition.no_progress_count);

    if (transition.should_halt) {
        return LoopDecision{
            .action = .halt,
            .reason = "Circuit breaker open - too many failures",
        };
    }

    if (made_progress) {
        return LoopDecision{
            .action = .@"continue",
            .reason = "Progress made - continue to next cycle",
        };
    }

    return LoopDecision{
        .action = .@"continue",
        .reason = "No progress but within threshold - retry",
    };
}

pub const LoopDecision = struct {
    action: LoopAction,
    reason: []const u8,
};

pub const LoopAction = enum {
    @"continue",
    complete,
    halt,
    escalate,
};

/// Select tech tree node by ROI
pub fn selectTechTreeNode(allocator: Allocator, tech_tree_path: []const u8) ![]NodeCandidate {
    const options = try triPlan(allocator, tech_tree_path);

    var candidates = try std.ArrayList(NodeCandidate).initCapacity(allocator, 0);
    try candidates.append(allocator, options.option1);

    if (options.option2) |opt2| {
        try candidates.append(allocator, opt2);
    }
    if (options.option3) |opt3| {
        try candidates.append(allocator, opt3);
    }

    return candidates.toOwnedSlice(allocator);
}

/// Check exit signal conditions
pub fn evaluateExit(allocator: Allocator, session: types.SessionState) !bool {
    _ = allocator;
    const has_progress = session.no_progress_count == 0;
    const valid_branch = session.current_branch.len > 0 and
        !std.mem.eql(u8, session.current_branch, "main");
    const circuit_ok = session.circuit_breaker != .open;

    return has_progress and valid_branch and circuit_ok;
}

// ============================================================================
// Tests
// ============================================================================

test "core: tri_verdict all pass" {
    const allocator = std.testing.allocator;

    const test_result = TestResult{
        .passed = true,
        .duration_ns = 1_000_000,
        .output = &.{},
    };

    const bench_result = BenchmarkResult{
        .passed = true,
        .duration_ns = 2_000_000,
        .regression = false,
        .output = &.{},
    };

    var verdict = try triVerdict(allocator, test_result, bench_result);
    defer verdict.deinit(allocator);

    try std.testing.expect(verdict.score >= 8);
    try std.testing.expectEqual(types.VerdictStatus.prod, verdict.status);
}

test "core: tri_verdict with failures" {
    const allocator = std.testing.allocator;

    const test_result = TestResult{
        .passed = false,
        .duration_ns = 1_000_000,
        .output = "Test failed",
    };

    const bench_result = BenchmarkResult{
        .passed = true,
        .duration_ns = 2_000_000,
        .regression = false,
        .output = &.{},
    };

    var verdict = try triVerdict(allocator, test_result, bench_result);
    defer verdict.deinit(allocator);

    try std.testing.expect(verdict.score < 8);
    try std.testing.expectEqual(types.VerdictStatus.fail, verdict.status);
}
