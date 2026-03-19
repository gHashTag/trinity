//! ORCHESTRATOR COORDINATOR v8.27 — TRI CLI Integration
//!
//! Integrates TRI CLI Orchestrator with Agent MU for:
//! - Multi-agent spawning (up to 200 sub-agents)
//! - Load balancing across Alpha/Beta/Gamma nodes
//! - φ-weighted consensus for decisions
//! - Failure detection and recovery
//!
//! Sacred Formula: φ² + 1/φ² = 3

const std = @import("std");

// S³AI Brain Regions (Neuroanatomy v5.1)
const brain = @import("../brain/brain.zig");
const basal_ganglia = brain.basal_ganglia;
const reticular_formation = brain.reticular_formation;
const locus_coeruleus = brain.locus_coeruleus;
const amygdala = brain.amygdala;
const prefrontal_cortex = brain.prefrontal_cortex;

// Shared orchestrator types — local copy to avoid circular dep on trinity.vibeec
// Source of truth: src/vibeec/tri_orchestrator.zig
pub const PHI = 1.618033988749895;
pub const MU = 0.0382;
pub const SACRED_THRESHOLD = 0.95;
pub const MAX_SUB_AGENTS = 200;
pub const CIRCUIT_BREAK_THRESHOLD = 10;

pub const Realm = enum {
    razum,
    materiya,
    dukh,

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
    alpha,
    beta,
    gamma,

    pub fn realm(self: NodeType) Realm {
        return switch (self) {
            .alpha => .razum,
            .beta => .materiya,
            .gamma => .dukh,
        };
    }
    pub fn phiWeight(self: NodeType) f64 {
        return switch (self) {
            .alpha => PHI,
            .beta => 1.0,
            .gamma => 1.0 / PHI,
        };
    }
};

pub const OrchestratorPhase = enum {
    idle,
    decompose,
    plan,
    spec_create,
    gen,
    @"test",
    bench,
    verdict,
    git,
    loop_decide,
    complete,
    failed,
};

pub const LoopDecision = enum { @"continue", stop, retry, skip, circuit_break };

pub const AgentVote = struct {
    agent_id: []const u8,
    node_type: NodeType,
    decision: LoopDecision,
    confidence: f32,
    pas_score: f64,
    reasoning: ?[]const u8,
    timestamp: i64,
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
// COORDINATED TASK
// ═══════════════════════════════════════════════════════════════════════════════

pub const CoordinatedTask = struct {
    id: []const u8,
    description: []const u8,
    realm: Realm,
    priority: TaskPriority,
    status: TaskStatus,
    assigned_node: ?[]const u8,
    created_at: i64,
    started_at: ?i64,
    completed_at: ?i64,
    result: ?TaskResult,

    pub const TaskPriority = enum(u8) {
        low = 1,
        normal = 5,
        high = 7,
        critical = 10,
    };

    pub const TaskStatus = enum {
        pending,
        assigned,
        running,
        completed,
        failed,
        timeout,
    };

    pub const TaskResult = struct {
        success: bool,
        output: []const u8,
        err_msg: ?[]const u8,
        duration_ms: u64,
        pas_score: f64,
    };

    pub fn init(allocator: std.mem.Allocator, id: []const u8, description: []const u8, realm: Realm, priority: TaskPriority) CoordinatedTask {
        return CoordinatedTask{
            .id = allocator.dupe(u8, id) catch id,
            .description = allocator.dupe(u8, description) catch description,
            .realm = realm,
            .priority = priority,
            .status = .pending,
            .assigned_node = null,
            .created_at = std.time.timestamp(),
            .started_at = null,
            .completed_at = null,
            .result = null,
        };
    }

    pub fn deinit(self: *CoordinatedTask, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.description);
        if (self.assigned_node) |node| allocator.free(node);
        if (self.result) |*r| {
            allocator.free(r.output);
            if (r.err_msg) |err| allocator.free(err);
        }
    }

    pub fn isComplete(self: *const CoordinatedTask) bool {
        return self.status == .completed or self.status == .failed or self.status == .timeout;
    }

    pub fn getDurationMs(self: *const CoordinatedTask) ?u64 {
        if (self.started_at == null or self.completed_at == null) return null;
        const started_ms = self.started_at.? * 1000;
        const completed_ms = self.completed_at.? * 1000;
        return @intCast(completed_ms - started_ms);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COORDINATOR CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const CoordinatorConfig = struct {
    max_sub_agents: u32 = MAX_SUB_AGENTS,
    enable_load_balancing: bool = true,
    enable_phi_consensus: bool = true,
    auto_scaling: bool = true,
    scale_up_threshold: f64 = 0.7,
    scale_down_threshold: f64 = 0.3,
    consensus_timeout_ms: u64 = 10000,
    task_timeout_ms: u64 = 30000,
    verbose: bool = false,

    pub fn init() CoordinatorConfig {
        return CoordinatorConfig{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NODE STATUS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeStatus = enum {
    initializing,
    active,
    busy,
    degraded,
    offline,
    pending,
};

pub const CoordinatedNode = struct {
    id: []const u8,
    node_type: NodeType,
    realm: Realm,
    status: NodeStatus,
    health: f64,
    active_tasks: u32,
    completed_tasks: u32,
    failed_tasks: u32,
    last_heartbeat: i64,
    capabilities: []const []const u8,

    pub fn isAvailable(self: *const CoordinatedNode) bool {
        return self.health >= 0.5 and
            (self.status == .active or self.status == .busy);
    }

    pub fn canAcceptTask(self: *const CoordinatedNode, task_realm: Realm) bool {
        return self.isAvailable() and self.realm == task_realm;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COORDINATOR METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const CoordinatorMetrics = struct {
    total_tasks: u32 = 0,
    pending_tasks: u32 = 0,
    running_tasks: u32 = 0,
    completed_tasks: u32 = 0,
    failed_tasks: u32 = 0,
    active_nodes: u32 = 0,
    total_sub_agents: u32 = 0,
    average_task_duration_ms: u64 = 0,
    consensus_count: u32 = 0,
    circuit_break_count: u32 = 0,

    pub fn getSuccessRate(self: *const CoordinatorMetrics) f64 {
        const total = self.completed_tasks + self.failed_tasks;
        if (total == 0) return 1.0;
        return @as(f64, @floatFromInt(self.completed_tasks)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COORDINATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const OrchestratorCoordinator = struct {
    allocator: std.mem.Allocator,
    config: CoordinatorConfig,
    nodes: []CoordinatedNode,
    task_queue: std.ArrayList(CoordinatedTask),
    active_tasks: std.StringHashMap(CoordinatedTask),
    completed_tasks: std.ArrayList(CoordinatedTask),
    metrics: CoordinatorMetrics,
    agent_counter: u32,

    // S³AI Brain Integration (v5.1)
    coordination: brain.AgentCoordination,
    backoff_attempts: std.StringHashMap(u32), // Track retries per task

    /// Initialize the coordinator with 3-node cluster
    pub fn init(allocator: std.mem.Allocator, config: CoordinatorConfig) !OrchestratorCoordinator {
        // Create 3-node cluster
        const nodes = try allocator.alloc(CoordinatedNode, 3);
        var initialized_nodes: usize = 0;
        errdefer {
            for (nodes[0..initialized_nodes]) |n| allocator.free(n.id);
            allocator.free(nodes);
        }

        nodes[0] = CoordinatedNode{
            .id = try allocator.dupe(u8, "alpha-001"),
            .node_type = .alpha,
            .realm = .razum,
            .status = .initializing,
            .health = 1.0,
            .active_tasks = 0,
            .completed_tasks = 0,
            .failed_tasks = 0,
            .last_heartbeat = std.time.timestamp(),
            .capabilities = &[_][]const u8{ "routing", "planning", "analysis", "decompose" },
        };
        initialized_nodes = 1;

        nodes[1] = CoordinatedNode{
            .id = try allocator.dupe(u8, "beta-001"),
            .node_type = .beta,
            .realm = .materiya,
            .status = .initializing,
            .health = 1.0,
            .active_tasks = 0,
            .completed_tasks = 0,
            .failed_tasks = 0,
            .last_heartbeat = std.time.timestamp(),
            .capabilities = &[_][]const u8{ "storage", "memory", "data", "spec-create", "gen" },
        };
        initialized_nodes = 2;

        nodes[2] = CoordinatedNode{
            .id = try allocator.dupe(u8, "gamma-001"),
            .node_type = .gamma,
            .realm = .dukh,
            .status = .initializing,
            .health = 1.0,
            .active_tasks = 0,
            .completed_tasks = 0,
            .failed_tasks = 0,
            .last_heartbeat = std.time.timestamp(),
            .capabilities = &[_][]const u8{ "execution", "tools", "actions", "test", "bench" },
        };

        return OrchestratorCoordinator{
            .allocator = allocator,
            .config = config,
            .nodes = nodes,
            .task_queue = std.ArrayList(CoordinatedTask).init(allocator),
            .active_tasks = std.StringHashMap(CoordinatedTask).init(allocator),
            .completed_tasks = std.ArrayList(CoordinatedTask).init(allocator),
            .metrics = CoordinatorMetrics{},
            .agent_counter = 0,
            // S³AI Brain Integration
            .coordination = try brain.AgentCoordination.init(allocator),
            .backoff_attempts = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn deinit(self: *OrchestratorCoordinator) void {
        for (self.nodes) |*node| {
            self.allocator.free(node.id);
        }
        self.allocator.free(self.nodes);

        for (self.task_queue.items) |*task| {
            task.deinit(self.allocator);
        }
        self.task_queue.deinit();

        var task_iter = self.active_tasks.iterator();
        while (task_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.active_tasks.deinit();

        for (self.completed_tasks.items) |*task| {
            task.deinit(self.allocator);
        }
        self.completed_tasks.deinit();

        // Cleanup S³AI Brain Integration
        var backoff_iter = self.backoff_attempts.iterator();
        while (backoff_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.backoff_attempts.deinit();
    }

    /// Start all nodes
    pub fn startNodes(self: *OrchestratorCoordinator) !void {
        for (self.nodes) |*node| {
            node.status = .active;
        }
        self.metrics.active_nodes = @intCast(self.nodes.len);
    }

    /// Queue a task for execution
    pub fn queueTask(self: *OrchestratorCoordinator, description: []const u8, realm: Realm, priority: CoordinatedTask.TaskPriority) ![]const u8 {
        self.agent_counter += 1;
        const task_id = try std.fmt.allocPrint(self.allocator, "task_{d}", .{self.agent_counter});

        const task = CoordinatedTask.init(self.allocator, task_id, description, realm, priority);

        // Amygdala: analyze task salience for prioritization
        const realm_str = @tagName(realm);
        const priority_str = @tagName(priority);
        const salience = amygdala.Amygdala.analyzeTask(task_id, realm_str, priority_str);

        if (self.config.verbose and amygdala.Amygdala.requiresAttention(salience)) {
            std.debug.print("[Amygdala] {s} task {s}: {s} {s}\n", .{
                salience.level.emoji(), task_id, @tagName(salience.level), realm_str,
            });
        }

        // High-salience tasks go to front of queue
        if (salience.level == .critical or salience.level == .high) {
            try self.task_queue.insert(0, task);
        } else {
            try self.task_queue.append(task);
        }

        self.metrics.total_tasks += 1;
        self.metrics.pending_tasks += 1;

        // Try to assign immediately
        _ = try self.assignTasks();

        return task_id;
    }

    /// Assign pending tasks to available nodes
    pub fn assignTasks(self: *OrchestratorCoordinator) !usize {
        // Prefrontal Cortex: executive decision before assigning tasks
        const decision = try self.makeExecutiveDecision();
        if (self.config.verbose) {
            std.debug.print("[PrefrontalCortex] Executive decision: {s} (confidence: {d:.1})\n", .{
                @tagName(decision.action), decision.confidence,
            });
        }

        // Act on executive decision
        switch (decision.action) {
            .pause => {
                // Pause task acceptance - don't assign anything
                if (self.config.verbose) {
                    std.debug.print("[PrefrontalCortex] Pausing task acceptance due to: {s}\n", .{decision.reasoning});
                }
                return 0;
            },
            .throttle => {
                // Throttle - only assign half the tasks
                const max_assign = @max(1, self.task_queue.items.len / 2);
                var assigned: usize = 0;
                var i: usize = 0;
                while (i < self.task_queue.items.len and assigned < max_assign) {
                    const task = &self.task_queue.items[i];
                    if (try self.assignToNode(task)) {
                        const task_copy = self.task_queue.orderedRemove(i);
                        try self.active_tasks.put(task_copy.id, task_copy);
                        self.metrics.pending_tasks -= 1;
                        self.metrics.running_tasks += 1;
                        assigned += 1;
                    } else {
                        i += 1;
                    }
                }
                return assigned;
            },
            .scale_up => {
                // Scale up - spawn more agents if possible
                if (self.nodes.len < self.config.max_nodes) {
                    if (self.config.verbose) {
                        std.debug.print("[PrefrontalCortex] Scaling up: adding new agent\n", .{});
                    }
                    // Note: actual agent spawning would happen here
                }
                // Fall through to normal assignment
            },
            .scale_down => {
                // Scale down - remove idle agents
                if (self.config.verbose) {
                    std.debug.print("[PrefrontalCortex] Scaling down: removing idle agents\n", .{});
                }
                // Note: actual agent removal would happen here
            },
            .proceed => {
                // Normal operation
            },
            .alert => {
                // Alert - critical condition requiring intervention
                std.debug.print("[PrefrontalCortex] ALERT: {s}\n", .{decision.reasoning});
                // Continue with reduced assignment
                const max_assign = @max(1, self.task_queue.items.len / 4);
                var assigned: usize = 0;
                var i: usize = 0;
                while (i < self.task_queue.items.len and assigned < max_assign) {
                    const task = &self.task_queue.items[i];
                    if (try self.assignToNode(task)) {
                        const task_copy = self.task_queue.orderedRemove(i);
                        try self.active_tasks.put(task_copy.id, task_copy);
                        self.metrics.pending_tasks -= 1;
                        self.metrics.running_tasks += 1;
                        assigned += 1;
                    } else {
                        i += 1;
                    }
                }
                return assigned;
            },
        }

        // Normal assignment for proceed/scale_up/scale_down
        var assigned: usize = 0;
        var i: usize = 0;
        while (i < self.task_queue.items.len) {
            const task = &self.task_queue.items[i];

            // Find best node for this task
            if (try self.assignToNode(task)) {
                // Move from queue to active
                const task_copy = self.task_queue.orderedRemove(i);
                try self.active_tasks.put(task_copy.id, task_copy);
                self.metrics.pending_tasks -= 1;
                self.metrics.running_tasks += 1;
                assigned += 1;
            } else {
                i += 1;
            }
        }

        return assigned;
    }

    /// Assign task to best available node with Basal Ganglia claim
    fn assignToNode(self: *OrchestratorCoordinator, task: *CoordinatedTask) !bool {
        // First, try to claim task via Basal Ganglia
        const agent_id = if (task.assigned_node) |node| node else "orchestrator";
        const claimed = try self.coordination.claimTask(task.id, agent_id);

        if (!claimed) {
            // Task already claimed — record backoff attempt
            const attempt = self.backoff_attempts.get(task.id) orelse 0;
            try self.backoff_attempts.put(
                try self.allocator.dupe(u8, task.id),
                attempt + 1,
            );

            if (self.config.verbose) {
                const delay_ms = self.coordination.getBackoffDelay(attempt);
                std.debug.print("[Brain] Task {s} already claimed, backoff {d}ms (attempt {d})\n", .{
                    task.id, delay_ms, attempt + 1,
                });
            }
            return false;
        }

        // Claim successful — find best node
        var best_node: ?*CoordinatedNode = null;
        var min_load: u32 = std.math.maxInt(u32);

        for (self.nodes) |*node| {
            if (!node.canAcceptTask(task.realm)) continue;

            if (node.active_tasks < min_load) {
                min_load = node.active_tasks;
                best_node = node;
            }
        }

        if (best_node == null) {
            // No node available — release claim
            _ = self.coordination.completeTask(task.id, agent_id, 0);
            return false;
        }

        // Assign task to node
        task.assigned_node = try self.allocator.dupe(u8, best_node.?.id);
        task.status = .assigned;
        best_node.?.active_tasks += 1;
        best_node.?.last_heartbeat = std.time.timestamp();
        if (best_node.?.active_tasks > 0) {
            best_node.?.status = .busy;
        }

        // Clear backoff attempts on success
        if (self.backoff_attempts.fetchRemove(task.id)) |entry| {
            self.allocator.free(entry.key);
        }

        return true;
    }

    /// Execute a task using TRI CLI command
    pub fn executeTask(self: *OrchestratorCoordinator, task_id: []const u8) !void {
        const task = self.active_tasks.getPtr(task_id) orelse return error.TaskNotFound;

        task.status = .running;
        const now = std.time.timestamp();
        task.started_at = now;

        // Execute via TRI CLI based on realm
        const result = try self.executeViaTriCli(task);

        task.completed_at = std.time.timestamp();
        task.status = if (result.success) .completed else .failed;
        task.result = result;

        // Publish completion/failure event to Reticular Formation
        const agent_id = if (task.assigned_node) |node| node else "orchestrator";
        if (result.success) {
            const duration_ms = if (task.getDurationMs()) |d| d else 0;
            try self.coordination.completeTask(task_id, agent_id, duration_ms);
        } else {
            const err_msg = if (result.err_msg) |err| err else "unknown error";

            // Amygdala: analyze error salience for alerting
            const err_salience = amygdala.Amygdala.analyzeError(err_msg);
            if (self.config.verbose and amygdala.Amygdala.requiresAttention(err_salience)) {
                std.debug.print("[Amygdala] {s} error in {s}: {s} ({d:.1}/100)\n", .{
                    err_salience.level.emoji(), task_id, @tagName(err_salience.level), err_salience.score,
                });
            }

            try self.coordination.failTask(task_id, agent_id, err_msg);
        }

        // Update metrics
        if (result.success) {
            self.metrics.completed_tasks += 1;
        } else {
            self.metrics.failed_tasks += 1;
        }
        self.metrics.running_tasks -= 1;

        // Update node
        if (task.assigned_node) |node_id| {
            for (self.nodes) |*node| {
                if (std.mem.eql(u8, node.id, node_id)) {
                    node.active_tasks -= 1;
                    if (result.success) {
                        node.completed_tasks += 1;
                    } else {
                        node.failed_tasks += 1;
                    }
                    if (node.active_tasks == 0) {
                        node.status = .active;
                    }
                    break;
                }
            }
        }

        // Move to completed
        const task_copy = self.active_tasks.fetchRemove(task_id).?.value;
        try self.completed_tasks.append(task_copy);
    }

    /// Execute task via TRI CLI
    fn executeViaTriCli(self: *OrchestratorCoordinator, task: *CoordinatedTask) !CoordinatedTask.TaskResult {
        _ = self;

        // Determine TRI CLI command based on task realm and description
        const argv = try self.buildTriCliCommand(task);
        defer {
            for (argv) |arg| {
                if (arg != task.description) {
                    self.allocator.free(arg);
                }
            }
            self.allocator.free(argv);
        }

        const start_time = std.time.nanoTimestamp();

        // Run command
        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| {
            return CoordinatedTask.TaskResult{
                .success = false,
                .output = "",
                .err_msg = try self.allocator.dupe(u8, @tagName(err)),
                .duration_ms = 0,
                .pas_score = 0,
            };
        };

        const stdout = if (child.stdout) |stdout_file|
            try stdout_file.readToEndAlloc(self.allocator, 10_000_000)
        else
            "";

        const stderr = if (child.stderr) |stderr_file|
            try stderr_file.readToEndAlloc(self.allocator, 1_000_000)
        else
            "";

        const term = child.wait() catch |err| {
            return CoordinatedTask.TaskResult{
                .success = false,
                .output = stdout,
                .err_msg = try self.allocator.dupe(u8, @tagName(err)),
                .duration_ms = @as(u64, @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000))),
                .pas_score = 0,
            };
        };

        const duration_ms = @as(u64, @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000)));
        const exit_code = switch (term) {
            .Exited => |code| code,
            else => 1,
        };

        return CoordinatedTask.TaskResult{
            .success = exit_code == 0,
            .output = stdout,
            .err_msg = if (exit_code != 0 and stderr.len > 0) try self.allocator.dupe(u8, stderr) else null,
            .duration_ms = duration_ms,
            .pas_score = if (exit_code == 0) 0.97 else 0.3, // Simplified PAS score
        };
    }

    /// Build TRI CLI command arguments for task
    fn buildTriCliCommand(self: *OrchestratorCoordinator, task: *CoordinatedTask) ![]const []const u8 {
        const argv = try self.allocator.alloc([]const u8, 4);

        argv[0] = try self.allocator.dupe(u8, "tri");
        argv[1] = try self.allocator.dupe(u8, "pipeline");
        argv[2] = try self.allocator.dupe(u8, "run");
        argv[3] = task.description; // Already owned by task

        return argv;
    }

    /// Calculate φ-weighted consensus from agent votes
    pub fn calculateConsensus(self: *OrchestratorCoordinator, votes: []const AgentVote) ConsensusResult {
        _ = self;

        var total_weight: f64 = 0;
        var proceed_weight: f64 = 0;

        for (votes) |vote| {
            const weight = vote.node_type.phiWeight() * vote.confidence;
            total_weight += weight;

            if (vote.decision == .@"continue") {
                proceed_weight += weight;
            }
        }

        const agreement = if (total_weight > 0) proceed_weight / total_weight else 0;

        const final_decision: LoopDecision = if (agreement >= 0.5)
            .@"continue"
        else if (agreement >= 0.3)
            .retry
        else
            .circuit_break;

        self.metrics.consensus_count += 1;

        return ConsensusResult{
            .final_decision = final_decision,
            .consensus_score = agreement,
            .phi_weighted_score = tri_orchestrator.TriOrchestrator.phiWeightedConsensus(
                if (total_weight > 0) proceed_weight else 0,
                0,
                if (total_weight > 0) total_weight - proceed_weight else 0,
            ),
            .participant_count = @intCast(votes.len),
            .agreement_level = agreement,
            .trinity_verified = tri_orchestrator.TriOrchestrator.verifyTrinityIdentity(),
            .timestamp = std.time.timestamp(),
        };
    }

    /// Get current metrics
    pub fn getMetrics(self: *OrchestratorCoordinator) CoordinatorMetrics {
        return self.metrics;
    }

    /// Get node status report
    pub fn getNodeStatusReport(self: *OrchestratorCoordinator) ![]const u8 {
        var report = std.ArrayList(u8).init(self.allocator);

        try report.appendSlice("╔═══════════════════════════════════════════════════════════════╗\n");
        try report.appendSlice("║  ORCHESTRATOR COORDINATOR — Node Status Report                  ║\n");
        try report.appendSlice("╠═══════════════════════════════════════════════════════════════╣\n");

        for (self.nodes) |node| {
            try report.print("║  Node: {s:10} | Realm: {s:10} | Status: {s:12} │ Health: {d:.2} ║\n", .{
                node.id,
                node.realm.name(),
                @tagName(node.status),
                node.health,
            });
            try report.print("║    Tasks: {d:4} active | {d:4} completed | {d:4} failed                   ║\n", .{
                node.active_tasks,
                node.completed_tasks,
                node.failed_tasks,
            });
        }

        try report.appendSlice("╠═══════════════════════════════════════════════════════════════╣\n");
        try report.print("║  Metrics: {d:4} total | {d:4} pending | {d:4} running | {d:4} completed │\n", .{
            self.metrics.total_tasks,
            self.metrics.pending_tasks,
            self.metrics.running_tasks,
            self.metrics.completed_tasks,
        });
        try report.print("║  Success Rate: {d:.1}%                                                ║\n", .{self.metrics.getSuccessRate() * 100});
        try report.appendSlice("╠═════════════════════════════════════════════════════════════╣\n");
        const brain_stats = self.coordination.getStats();
        try report.print("║  Brain: {d:4} active claims │ {d:5} events │{s}\n", .{
            brain_stats.active_claims,
            brain_stats.total_events_published,
            RESET,
        });
        try report.appendSlice("╚═══════════════════════════════════════════════════════════════╝\n");

        return report.toOwnedSlice();
    }

    /// Update health status of all nodes
    pub fn updateNodeHealth(self: *OrchestratorCoordinator) void {
        const now = std.time.timestamp();

        for (self.nodes) |*node| {
            // Decay health if no recent heartbeat
            const time_since_heartbeat = now - node.last_heartbeat;
            if (time_since_heartbeat > 60) {
                node.health = @max(0, node.health - 0.1);
                if (node.health < 0.5) {
                    node.status = .degraded;
                }
            }

            // Update status based on load
            if (node.active_tasks == 0 and node.health >= 0.8) {
                node.status = .active;
            } else if (node.active_tasks > 0) {
                node.status = .busy;
            }
        }
    }

    /// Scale sub-agents based on load
    pub fn checkScaling(self: *OrchestratorCoordinator) !bool {
        if (!self.config.auto_scaling) return false;

        const total_capacity = @as(f64, @floatFromInt(self.nodes.len * 10)); // Assume 10 tasks per node
        const current_load = @as(f64, @floatFromInt(self.metrics.running_tasks));
        const load_ratio = current_load / total_capacity;

        if (load_ratio > self.config.scale_up_threshold) {
            // Would trigger sub-agent spawning in production
            if (self.config.verbose) {
                std.debug.print("[Coordinator] Scale up triggered: load={d:.2}\n", .{load_ratio});
            }
            return true;
        } else if (load_ratio < self.config.scale_down_threshold) {
            // Would trigger sub-agent termination in production
            if (self.config.verbose) {
                std.debug.print("[Coordinator] Scale down triggered: load={d:.2}\n", .{load_ratio});
            }
            return true;
        }

        return false;
    }

    /// Make executive decision using Prefrontal Cortex
    fn makeExecutiveDecision(self: *OrchestratorCoordinator) !prefrontal_cortex.Decision {
        const health = self.coordination.healthCheck();
        const stats = self.coordination.getStats();

        // Build decision context
        const ctx = prefrontal_cortex.DecisionContext{
            .task_count = self.metrics.pending_tasks,
            .active_agents = self.nodes.len,
            .error_rate = if (self.metrics.total_tasks > 0)
                @as(f32, @floatFromInt(self.metrics.failed_tasks)) / @as(f32, @floatFromInt(self.metrics.total_tasks))
            else
                0.0,
            .avg_latency_ms = 0, // Would need to track actual latency
            .memory_usage_pct = 50.0, // Placeholder - would need actual memory tracking
        };

        return prefrontal_cortex.PrefrontalCortex.decide(ctx);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "OrchestratorCoordinator initialization" {
    const allocator = std.testing.allocator;
    const config = CoordinatorConfig.init();
    var coord = try OrchestratorCoordinator.init(allocator, config);
    defer coord.deinit();

    try std.testing.expectEqual(@as(usize, 3), coord.nodes.len);
    try std.testing.expectEqual(.alpha, coord.nodes[0].node_type);
    try std.testing.expectEqual(.beta, coord.nodes[1].node_type);
    try std.testing.expectEqual(.gamma, coord.nodes[2].node_type);
}

test "OrchestratorCoordinator queue task" {
    const allocator = std.testing.allocator;
    const config = CoordinatorConfig.init();
    var coord = try OrchestratorCoordinator.init(allocator, config);
    defer coord.deinit();

    try coord.startNodes();

    const task_id = try coord.queueTask("Test task", .razum, .normal);
    _ = task_id;

    try std.testing.expectEqual(@as(usize, 1), coord.task_queue.items.len);
    try std.testing.expectEqual(@as(u32, 1), coord.metrics.total_tasks);
}

test "OrchestratorCoordinator assign tasks" {
    const allocator = std.testing.allocator;
    const config = CoordinatorConfig.init();
    var coord = try OrchestratorCoordinator.init(allocator, config);
    defer coord.deinit();

    try coord.startNodes();

    _ = try coord.queueTask("Analyze code", .razum, .normal);
    _ = try coord.queueTask("Store data", .materiya, .normal);
    _ = try coord.queueTask("Execute action", .dukh, .normal);

    const assigned = try coord.assignTasks();

    try std.testing.expectEqual(@as(usize, 3), assigned);
    try std.testing.expectEqual(@as(usize, 0), coord.task_queue.items.len);
    try std.testing.expectEqual(@as(u32, 3), coord.metrics.running_tasks);
}

test "OrchestratorCoordinator φ consensus" {
    const allocator = std.testing.allocator;
    const config = CoordinatorConfig.init();
    var coord = try OrchestratorCoordinator.init(allocator, config);
    defer coord.deinit();

    const votes = [_]AgentVote{
        .{
            .agent_id = "alpha-001",
            .node_type = .alpha,
            .decision = .@"continue",
            .confidence = 0.95,
            .pas_score = 0.97,
            .reasoning = null,
            .timestamp = std.time.timestamp(),
        },
        .{
            .agent_id = "beta-001",
            .node_type = .beta,
            .decision = .@"continue",
            .confidence = 0.90,
            .pas_score = 0.92,
            .reasoning = null,
            .timestamp = std.time.timestamp(),
        },
        .{
            .agent_id = "gamma-001",
            .node_type = .gamma,
            .decision = .retry,
            .confidence = 0.70,
            .pas_score = 0.75,
            .reasoning = null,
            .timestamp = std.time.timestamp(),
        },
    };

    const result = coord.calculateConsensus(&votes);

    try std.testing.expectEqual(.@"continue", result.final_decision);
    try std.testing.expect(result.consensus_score > 0.5); // Alpha + Beta should outweigh Gamma
}

test "OrchestratorCoordinator metrics" {
    const allocator = std.testing.allocator;
    const config = CoordinatorConfig.init();
    var coord = try OrchestratorCoordinator.init(allocator, config);
    defer coord.deinit();

    coord.metrics.completed_tasks = 80;
    coord.metrics.failed_tasks = 20;

    const success_rate = coord.metrics.getSuccessRate();

    try std.testing.expectApproxEqAbs(success_rate, 0.8, 0.01);
}

test "OrchestratorCoordinator node availability" {
    const allocator = std.testing.allocator;

    var node = CoordinatedNode{
        .id = "test-node",
        .node_type = .alpha,
        .realm = .razum,
        .status = .active,
        .health = 0.8,
        .active_tasks = 0,
        .completed_tasks = 10,
        .failed_tasks = 1,
        .last_heartbeat = std.time.timestamp(),
        .capabilities = &[_][]const u8{},
    };

    try std.testing.expect(node.isAvailable());
    try std.testing.expect(node.canAcceptTask(.razum));
    try std.testing.expect(!node.canAcceptTask(.materiya));

    node.health = 0.3;
    try std.testing.expect(!node.isAvailable());
}

test "CoordinatedTask lifecycle" {
    const allocator = std.testing.allocator;

    var task = CoordinatedTask.init(allocator, "task-1", "Test task", .razum, .normal);
    defer task.deinit(allocator);

    try std.testing.expectEqual(.pending, task.status);
    try std.testing.expect(!task.isComplete());

    task.status = .running;
    const now = std.time.timestamp();
    task.started_at = now;
    task.completed_at = now + 1000;

    try std.testing.expect(task.isComplete());
    try std.testing.expect(task.getDurationMs() != null);
}
