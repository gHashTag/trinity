//! TRI CLI ONLY ORCHESTRATOR v8.27 — STRICT MODE
//!
//! Sacred Formula: φ² + 1/φ² = 3
//!
//! This orchestrator uses ONLY TRI CLI commands for all coding operations.
//! VIBEE remains ONLY as spec language (.tri files).
//!
//! Workflow: tri decompose → tri plan → tri spec create → tri gen → tri test →
//!           tri bench → tri verdict → tri git → tri loop decide
//!
//! Author: TRI COMMANDER (Abbey)
//! Version: 8.27.0

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI = 1.618033988749895; // Golden ratio
pub const MU = 0.0382; // Sacred learning rate
pub const CHI = 0.23607; // Chi constant
pub const SIGMA = 1.618; // Sigma
pub const EPSILON = 0.333; // Epsilon
pub const SACRED_THRESHOLD = 0.95; // Quality gate threshold
pub const TOTAL_LINKS = 999; // PHI LOOP total links
pub const MAX_SUB_AGENTS = 200; // Maximum sub-agents
pub const CIRCUIT_BREAK_THRESHOLD = 10; // Max failures before circuit break

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY REALMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Realm = enum {
    razum, // Mind - Gold #ffd700
    materiya, // Matter - Cyan #00ccff
    dukh, // Spirit - Purple #aa66ff

    pub fn color(self: Realm) []const u8 {
        return switch (self) {
            .razum => "#ffd700",
            .materiya => "#00ccff",
            .dukh => "#aa66ff",
        };
    }

    pub fn name(self: Realm) []const u8 {
        return switch (self) {
            .razum => "RAZUM",
            .materiya => "MATERIYA",
            .dukh => "DUKH",
        };
    }
};

pub const NodeType = enum {
    alpha, // Razum
    beta, // Materiya
    gamma, // Dukh

    pub fn realm(self: NodeType) Realm {
        return switch (self) {
            .alpha => .razum,
            .beta => .materiya,
            .gamma => .dukh,
        };
    }

    pub fn name(self: NodeType) []const u8 {
        return switch (self) {
            .alpha => "Alpha",
            .beta => "Beta",
            .gamma => "Gamma",
        };
    }

    pub fn phiWeight(self: NodeType) f64 {
        return switch (self) {
            .alpha => PHI, // φ for intelligence
            .beta => 1.0, // 1 for neutral
            .gamma => 1.0 / PHI, // 1/φ for action
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ORCHESTRATOR STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const OrchestratorPhase = enum {
    idle,
    decompose,
    plan,
    spec_create,
    gen,
    testing,
    bench,
    verdict,
    git,
    loop_decide,
    complete,
    failed,

    pub fn name(self: OrchestratorPhase) []const u8 {
        return switch (self) {
            .idle => "IDLE",
            .decompose => "DECOMPOSE",
            .plan => "PLAN",
            .spec_create => "SPEC_CREATE",
            .gen => "GEN",
            .testing => "TEST",
            .bench => "BENCH",
            .verdict => "VERDICT",
            .git => "GIT",
            .loop_decide => "LOOP_DECIDE",
            .complete => "COMPLETE",
            .failed => "FAILED",
        };
    }
};

pub const LoopDecision = enum {
    cont,
    stop,
    retry,
    skip,
    circuit_break,
};

pub const OrchestratorConfig = struct {
    auto_fix: bool = true,
    max_retries: u32 = 3,
    learn_from_failures: bool = true,
    phi_weighted_voting: bool = true,
    verbose: bool = false,
    max_links: u32 = 999,
    phi_threshold: f64 = SACRED_THRESHOLD,
    enable_rollback: bool = true,

    pub fn init() OrchestratorConfig {
        return OrchestratorConfig{};
    }
};

pub const OrchestratorState = struct {
    current_phase: OrchestratorPhase,
    current_link: u32,
    passed_links: u32,
    failed_links: u32,
    skipped_links: u32,
    active_agents: u32,
    circuit_breaker_open: bool,
    start_time: i64,
    last_commit: ?[]const u8,

    pub fn init() OrchestratorState {
        return OrchestratorState{
            .current_phase = .idle,
            .current_link = 1,
            .passed_links = 0,
            .failed_links = 0,
            .skipped_links = 0,
            .active_agents = 0,
            .circuit_breaker_open = false,
            .start_time = std.time.timestamp(),
            .last_commit = null,
        };
    }

    pub fn completionPercentage(self: *const OrchestratorState) f32 {
        if (TOTAL_LINKS == 0) return 0;
        return @as(f32, @floatFromInt(self.current_link)) * 100.0 / @as(f32, @floatFromInt(TOTAL_LINKS));
    }

    pub fn successRate(self: *const OrchestratorState) f32 {
        const total = self.passed_links + self.failed_links;
        if (total == 0) return 0;
        return @as(f32, @floatFromInt(self.passed_links)) * 100.0 / @as(f32, @floatFromInt(total));
    }
};

pub const CircuitBreakerState = struct {
    is_open: bool = false,
    failure_count: u32 = 0,
    last_failure_time: i64 = 0,
    last_failure_reason: ?[]const u8 = null,
    half_open_attempts: u32 = 0,

    pub fn trip(self: *CircuitBreakerState, reason: []const u8) void {
        self.is_open = true;
        self.failure_count += 1;
        self.last_failure_time = std.time.timestamp();
        self.last_failure_reason = reason;
        self.half_open_attempts = 0;
    }

    pub fn reset(self: *CircuitBreakerState) void {
        self.is_open = false;
        self.failure_count = 0;
        self.last_failure_time = 0;
        self.last_failure_reason = null;
        self.half_open_attempts = 0;
    }

    pub fn shouldTrip(self: *const CircuitBreakerState) bool {
        return self.failure_count >= CIRCUIT_BREAK_THRESHOLD;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKFLOW RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const WorkflowResult = struct {
    phase: OrchestratorPhase,
    success: bool,
    output: []const u8,
    err_msg: ?[]const u8,
    duration_ms: u64,
    timestamp: i64,

    pub fn init(phase: OrchestratorPhase) WorkflowResult {
        return WorkflowResult{
            .phase = phase,
            .success = false,
            .output = "",
            .err_msg = null,
            .duration_ms = 0,
            .timestamp = std.time.timestamp(),
        };
    }
};

pub const VerdictResult = struct {
    pas_score: f64,
    trinity_identity: bool,
    confidence: f32,
    sona_q_value: f64,
    passes_threshold: bool,
    reasoning: ?[]const u8,

    pub fn passes(self: *const VerdictResult) bool {
        return self.passes_threshold and
            self.trinity_identity and
            self.confidence >= 0.95;
    }
};

pub const ConsensusResult = struct {
    final_decision: LoopDecision,
    consensus_score: f64,
    phi_weighted_score: f64,
    participant_count: u32,
    agreement_level: f64,
    trinity_verified: bool,
    timestamp: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLUSTER NODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeStatus = enum {
    initializing,
    active,
    busy,
    degraded,
    offline,
    pending,
};

pub const ClusterNode = struct {
    node_id: []const u8,
    node_type: NodeType,
    realm: Realm,
    status: NodeStatus,
    health: f64,
    last_heartbeat: i64,
    capabilities: []const []const u8,

    pub fn isHealthy(self: *const ClusterNode) bool {
        return self.health >= 0.5 and
            (self.status == .active or self.status == .busy);
    }

    pub fn canAcceptTask(self: *const ClusterNode) bool {
        return self.isHealthy() and self.status != .offline;
    }
};

pub const AgentVote = struct {
    agent_id: []const u8,
    node_type: NodeType,
    decision: LoopDecision,
    confidence: f32,
    pas_score: f64,
    reasoning: ?[]const u8,
    timestamp: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE ORCHESTRATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const TriOrchestrator = struct {
    allocator: std.mem.Allocator,
    config: OrchestratorConfig,
    state: OrchestratorState,
    circuit_breaker: CircuitBreakerState,
    cluster_nodes: []ClusterNode,
    sacred_log_path: []const u8,

    /// Initialize the TRI CLI Orchestrator
    pub fn init(allocator: std.mem.Allocator, config: OrchestratorConfig) TriOrchestrator {
        // Initialize 3-node cluster
        const nodes = allocator.alloc(ClusterNode, 3) catch &[_]ClusterNode{};

        nodes[0] = ClusterNode{
            .node_id = "alpha-001",
            .node_type = .alpha,
            .realm = .razum,
            .status = .initializing,
            .health = 1.0,
            .last_heartbeat = std.time.timestamp(),
            .capabilities = &[_][]const u8{ "routing", "planning", "analysis" },
        };

        nodes[1] = ClusterNode{
            .node_id = "beta-001",
            .node_type = .beta,
            .realm = .materiya,
            .status = .initializing,
            .health = 1.0,
            .last_heartbeat = std.time.timestamp(),
            .capabilities = &[_][]const u8{ "storage", "memory", "data" },
        };

        nodes[2] = ClusterNode{
            .node_id = "gamma-001",
            .node_type = .gamma,
            .realm = .dukh,
            .status = .initializing,
            .health = 1.0,
            .last_heartbeat = std.time.timestamp(),
            .capabilities = &[_][]const u8{ "execution", "tools", "actions" },
        };

        return TriOrchestrator{
            .allocator = allocator,
            .config = config,
            .state = OrchestratorState.init(),
            .circuit_breaker = CircuitBreakerState{},
            .cluster_nodes = nodes,
            .sacred_log_path = "deploy/trinity-nexus/.ralph/sacred_tool_calls.log",
        };
    }

    pub fn deinit(self: *TriOrchestrator) void {
        self.allocator.free(self.cluster_nodes);
    }

    /// Verify Trinity identity: φ² + 1/φ² = 3
    pub fn verifyTrinityIdentity() bool {
        const phi_sq = PHI * PHI;
        const inv_phi_sq = 1.0 / phi_sq;
        const result = phi_sq + inv_phi_sq;
        return @abs(result - 3.0) < 0.0001;
    }

    /// Calculate φ-weighted consensus
    pub fn phiWeightedConsensus(
        alpha_vote: f64,
        beta_vote: f64,
        gamma_vote: f64,
    ) f64 {
        // Alpha gets φ weight, Beta is neutral, Gamma gets 1/φ
        return (alpha_vote * PHI) + beta_vote + (gamma_vote / PHI);
    }

    /// Execute strict workflow using ONLY TRI CLI commands
    pub fn executeStrictWorkflow(self: *TriOrchestrator, task: []const u8) !WorkflowResult {
        if (self.config.verbose) {
            std.debug.print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
            std.debug.print("║  TRI CLI ONLY ORCHESTRATOR v8.27 — STRICT MODE                 ║\n", .{});
            std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
            std.debug.print("║  Task: {s:55} ║\n", .{task});
            std.debug.print("║  φ² + 1/φ² = {d:.3} {s:40} ║\n", .{ PHI * PHI + 1.0 / (PHI * PHI), if (verifyTrinityIdentity()) "✓" else "✗" });
            std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});
        }

        // Check circuit breaker
        if (self.circuit_breaker.is_open) {
            if (self.config.verbose) {
                std.debug.print("✗ Circuit breaker is OPEN, cannot start workflow\n", .{});
            }
            var result = WorkflowResult.init(.idle);
            result.success = false;
            result.err_msg = try self.allocator.dupe(u8, "Circuit breaker is open");
            return result;
        }

        // Phase 1: tri decompose <task>
        self.state.current_phase = .decompose;
        const decompose_result = try self.executeTriCommand(&.{ "tri", "decompose", task });
        if (!decompose_result.success) {
            return self.handleFailure(.decompose, decompose_result);
        }

        // Phase 2: tri plan <subtasks>
        self.state.current_phase = .plan;
        const plan_result = try self.executeTriCommand(&.{ "tri", "plan" });
        if (!plan_result.success) {
            return self.handleFailure(.plan, plan_result);
        }

        // Phase 3: tri spec create <plan>
        self.state.current_phase = .spec_create;
        const spec_result = try self.executeTriCommand(&.{ "tri", "spec-create", "auto" });
        if (!spec_result.success) {
            return self.handleFailure(.spec_create, spec_result);
        }

        // Phase 4: tri gen <spec.tri>
        self.state.current_phase = .gen;
        const gen_result = try self.executeTriCommand(&.{ "tri", "gen", "auto.tri" });
        if (!gen_result.success) {
            return self.handleFailure(.gen, gen_result);
        }

        // Phase 5: tri test
        self.state.current_phase = .testing;
        const test_result = try self.executeTriCommand(&.{ "tri", "test" });
        if (!test_result.success) {
            return self.handleFailure(.testing, test_result);
        }

        // Phase 6: tri bench
        self.state.current_phase = .bench;
        const bench_result = try self.executeTriCommand(&.{ "tri", "bench" });
        if (!bench_result.success) {
            return self.handleFailure(.bench, bench_result);
        }

        // Phase 7: tri verdict
        self.state.current_phase = .verdict;
        const verdict_result = try self.executeTriCommand(&.{ "tri", "verdict" });
        if (!verdict_result.success) {
            return self.handleFailure(.verdict, verdict_result);
        }

        // Phase 8: tri git commit (if verdict passes)
        self.state.current_phase = .git;
        const git_result = try self.executeTriCommand(&.{ "tri", "git", "commit", "-m", "auto-commit from orchestrator" });
        if (!git_result.success) {
            return self.handleFailure(.git, git_result);
        }

        // Phase 9: tri loop decide
        self.state.current_phase = .loop_decide;
        const decide_result = try self.executeTriCommand(&.{ "tri", "loop-decide" });
        if (!decide_result.success) {
            return self.handleFailure(.loop_decide, decide_result);
        }

        // Workflow complete
        self.state.current_phase = .complete;
        self.state.passed_links += 1;

        var final_result = WorkflowResult.init(.complete);
        final_result.success = true;
        final_result.output = try self.allocator.dupe(u8, "Workflow completed successfully");

        return final_result;
    }

    /// Execute a TRI CLI command and log it
    fn executeTriCommand(self: *TriOrchestrator, argv: []const []const u8) !WorkflowResult {
        const cmd_name = argv[1]; // "decompose", "plan", etc.
        var result = WorkflowResult.init(.idle);

        // Log sacred tool call
        try self.logSacredCall(cmd_name, if (argv.len > 2) argv[2] else "");

        // Execute command
        const start_time = std.time.nanoTimestamp();
        const cmd_result = try self.runCommand(argv);
        result.duration_ms = @as(u64, @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000)));

        if (cmd_result.success) {
            result.success = true;
            result.output = try self.allocator.dupe(u8, cmd_result.output);
        } else {
            result.success = false;
            result.err_msg = try self.allocator.dupe(u8, cmd_result.error_message orelse "Unknown error");
            result.output = try self.allocator.dupe(u8, cmd_result.output);
        }

        return result;
    }

    /// Run a command and capture output
    fn runCommand(self: *TriOrchestrator, argv: []const []const u8) !CommandResult {
        _ = self;

        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| {
            return CommandResult{
                .success = false,
                .output = "",
                .error_message = try self.allocator.dupe(u8, @tagName(err)),
                .exit_code = 1,
            };
        };

        const stdout = if (child.stdout) |stdout_file|
            try stdout_file.readToEndAlloc(self.allocator, 10_000_000)
        else
            "";

        const stderr = if (child.stderr) |stderr_file|
            try stderr_file.readToEndAlloc(self.allocator, 10_000_000)
        else
            "";

        const term = child.wait() catch |err| {
            return CommandResult{
                .success = false,
                .output = stdout,
                .error_message = try self.allocator.dupe(u8, @tagName(err)),
                .exit_code = 1,
            };
        };

        const exit_code = switch (term) {
            .Exited => |code| code,
            else => 1,
        };

        return CommandResult{
            .success = exit_code == 0,
            .output = stdout,
            .error_message = if (exit_code != 0 and stderr.len > 0) try self.allocator.dupe(u8, stderr) else null,
            .exit_code = @intCast(exit_code),
        };
    }

    /// Handle workflow failure with rollback
    fn handleFailure(self: *TriOrchestrator, phase: OrchestratorPhase, result: WorkflowResult) !WorkflowResult {
        self.state.failed_links += 1;
        self.circuit_breaker.trip(result.err_msg orelse "Unknown error");

        if (self.config.enable_rollback) {
            _ = try self.executeTriCommand(&.{ "tri", "git", "reset", "--hard", "HEAD" });
        }

        if (self.circuit_breaker.shouldTrip()) {
            self.circuit_breaker.is_open = true;
            self.state.current_phase = .failed;

            if (self.config.verbose) {
                std.debug.print("\n✗ CIRCUIT BREAKER ACTIVATED — Too many failures\n", .{});
            }
        }

        var failed_result = WorkflowResult.init(phase);
        failed_result.success = false;
        failed_result.err_msg = try self.allocator.dupe(u8, result.err_msg orelse "Unknown error");
        failed_result.output = result.output;

        return failed_result;
    }

    /// Log to sacred_tool_calls.log with φ marker
    fn logSacredCall(self: *TriOrchestrator, command: []const u8, arg: []const u8) !void {
        const timestamp = std.time.timestamp();
        const epoch_abs = @abs(@as(i64, @intCast(@divFloor(timestamp, 1_000_000_000))));

        var buf: [512]u8 = undefined;
        const log_line = try std.fmt.bufPrint(&buf, "[φ] {} | tri {s} {s}\n", .{
            epoch_abs,
            command,
            arg,
        });

        // Append to sacred log
        const file = try std.fs.cwd().openFile(self.sacred_log_path, .{ .mode = .read_write }) catch |err| {
            if (err == error.FileNotFound) {
                // Create directory and file
                try std.fs.cwd().makePath("deploy/trinity-nexus/.ralph");
                const new_file = try std.fs.cwd().createFile(self.sacred_log_path, .{});
                defer new_file.close();
                try new_file.writeAll(log_line);
                return;
            }
            return err;
        };
        defer file.close();

        try file.seekFromEnd(0);
        try file.writeAll(log_line);
    }

    /// Calculate φ-weighted consensus from agent votes
    pub fn calculateConsensus(self: *TriOrchestrator, votes: []const AgentVote) ConsensusResult {
        _ = self;

        var total_weight: f64 = 0;
        var proceed_weight: f64 = 0;

        for (votes) |vote| {
            const weight = vote.node_type.phiWeight() * vote.confidence;
            total_weight += weight;

            if (vote.decision == .cont) {
                proceed_weight += weight;
            }
        }

        const agreement = if (total_weight > 0) proceed_weight / total_weight else 0;
        const phi_weighted = phiWeightedConsensus(
            if (total_weight > 0) proceed_weight else 0,
            0,
            if (total_weight > 0) total_weight - proceed_weight else 0,
        );

        const final_decision: LoopDecision = if (agreement >= 0.5)
            .cont
        else if (agreement >= 0.3)
            .retry
        else
            .circuit_break;

        return ConsensusResult{
            .final_decision = final_decision,
            .consensus_score = agreement,
            .phi_weighted_score = phi_weighted,
            .participant_count = @intCast(votes.len),
            .agreement_level = agreement,
            .trinity_verified = verifyTrinityIdentity(),
            .timestamp = std.time.timestamp(),
        };
    }

    /// Get status report
    pub fn getStatus(self: *const TriOrchestrator) []const u8 {
        return "TRI CLI Orchestrator v8.27 — STRICT MODE";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const CommandResult = struct {
    success: bool,
    output: []const u8,
    error_message: ?[]const u8,
    exit_code: u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Sacred constants" {
    try std.testing.expect(TriOrchestrator.verifyTrinityIdentity());
    try std.testing.expectApproxEqAbs(PHI, 1.618, 0.001);
    try std.testing.expectApproxEqAbs(MU, 0.0382, 0.0001);
}

test "Trinity Identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(result, 3.0, 0.0001);
}

test "OrchestratorState initialization" {
    const state = OrchestratorState.init();
    try std.testing.expectEqual(OrchestratorPhase.idle, state.current_phase);
    try std.testing.expectEqual(@as(u32, 1), state.current_link);
    try std.testing.expectEqual(@as(u32, 0), state.passed_links);
    try std.testing.expectEqual(@as(u32, 0), state.failed_links);
}

test "OrchestratorState metrics" {
    var state = OrchestratorState.init();
    state.passed_links = 50;
    state.failed_links = 10;
    state.current_link = 60;

    const completion = state.completionPercentage();
    const success_rate = state.successRate();

    try std.testing.expect(completion > 0 and completion < 100);
    try std.testing.expect(success_rate > 80 and success_rate < 100);
}

test "NodeType phi weights" {
    try std.testing.expectApproxEqAbs(NodeType.alpha.phiWeight(), PHI, 0.001);
    try std.testing.expectApproxEqAbs(NodeType.beta.phiWeight(), 1.0, 0.001);
    try std.testing.expectApproxEqAbs(NodeType.gamma.phiWeight(), 1.0 / PHI, 0.001);
}

test "CircuitBreakerState" {
    var breaker = CircuitBreakerState{};

    try std.testing.expect(!breaker.is_open);
    try std.testing.expect(!breaker.shouldTrip());

    // Trip after threshold
    var i: u32 = 0;
    while (i < CIRCUIT_BREAK_THRESHOLD) : (i += 1) {
        breaker.trip("test failure");
    }

    try std.testing.expect(breaker.shouldTrip());

    breaker.reset();
    try std.testing.expect(!breaker.is_open);
    try std.testing.expect(!breaker.shouldTrip());
}

test "TriOrchestrator initialization" {
    const allocator = std.testing.allocator;
    const config = OrchestratorConfig.init();
    var orch = TriOrchestrator.init(allocator, config);
    defer orch.deinit();

    try std.testing.expectEqual(@as(usize, 3), orch.cluster_nodes.len);
    try std.testing.expectEqual(NodeType.alpha, orch.cluster_nodes[0].node_type);
    try std.testing.expectEqual(NodeType.beta, orch.cluster_nodes[1].node_type);
    try std.testing.expectEqual(NodeType.gamma, orch.cluster_nodes[2].node_type);
}

test "Phi weighted consensus" {
    const score = TriOrchestrator.phiWeightedConsensus(1.0, 0.5, 0.3);
    // Alpha (φ * 1.0) + Beta (1.0 * 0.5) + Gamma (1/φ * 0.3)
    const expected = (PHI * 1.0) + (1.0 * 0.5) + ((1.0 / PHI) * 0.3);
    try std.testing.expectApproxEqAbs(score, expected, 0.001);
}

test "Realm colors and names" {
    try std.testing.expectEqualStrings("#ffd700", Realm.razum.color());
    try std.testing.expectEqualStrings("#00ccff", Realm.materiya.color());
    try std.testing.expectEqualStrings("#aa66ff", Realm.dukh.color());

    try std.testing.expectEqualStrings("RAZUM", Realm.razum.name());
    try std.testing.expectEqualStrings("MATERIYA", Realm.materiya.name());
    try std.testing.expectEqualStrings("DUKH", Realm.dukh.name());
}

test "ClusterNode health check" {
    var node = ClusterNode{
        .node_id = "test",
        .node_type = .alpha,
        .realm = .razum,
        .status = .active,
        .health = 0.8,
        .last_heartbeat = std.time.timestamp(),
        .capabilities = &[_][]const u8{},
    };

    try std.testing.expect(node.isHealthy());
    try std.testing.expect(node.canAcceptTask());

    node.health = 0.3;
    try std.testing.expect(!node.isHealthy());

    node.status = .offline;
    try std.testing.expect(!node.canAcceptTask());
}
