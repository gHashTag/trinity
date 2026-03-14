//! ═══════════════════════════════════════════════════════════════════════════════
//! AGENT LOAD BALANCER v1.0
//!
//! Dynamic scaling and load balancing for Trinity agent swarms
//!
//! Features:
//! - Queue-based auto-scaling (spin up/spin down agents)
//! - Per-agent task tracking
//! - Consensus timeout and deadlock prevention
//! - Circuit breaker for stuck agents
//! - Real-time metrics and monitoring
//!
//! Success Criteria:
//! - Handle 100 concurrent tasks
//! - No deadlocks in 32-agent consensus
//! - Auto-scale based on queue depth
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const swarm_collab = @import("swarm_collaboration.zig");

const Allocator = std.mem.Allocator;
const AgentType = swarm_collab.AgentType;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScalingConfig = struct {
    /// Minimum number of agents (never scale below this)
    min_agents: u32 = 2,

    /// Maximum number of agents (never scale above this)
    max_agents: u32 = 32,

    /// Queue depth threshold to trigger scale-up (0.0-1.0 of max_agents)
    scale_up_threshold: f64 = 0.7,

    /// Queue depth threshold to trigger scale-down (0.0-1.0 of max_agents)
    scale_down_threshold: f64 = 0.3,

    /// Consensus timeout in milliseconds
    consensus_timeout_ms: u64 = 10000,

    /// Circuit breaker: consecutive failures before agent is marked unhealthy
    circuit_breaker_threshold: u32 = 3,

    /// Circuit breaker cooldown: milliseconds before retrying unhealthy agent
    circuit_breaker_cooldown_ms: u64 = 30000,

    /// Scaling cooldown: minimum milliseconds between scaling events
    scaling_cooldown_ms: u64 = 5000,

    /// Task timeout per agent (milliseconds)
    task_timeout_ms: u64 = 30000,

    /// Enable/disable auto-scaling
    auto_scaling_enabled: bool = true,
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const AgentHealth = enum {
    healthy,
    unhealthy,
    circuit_open,
    recovering,
};

pub const AgentState = struct {
    id: []const u8,
    agent_type: AgentType,
    health: AgentHealth,
    active_tasks: u32,
    completed_tasks: u32,
    failed_tasks: u32,
    consecutive_failures: u32,
    last_activity: i64,
    circuit_open_until: i64,
    created_at: i64,

    pub fn init(allocator: Allocator, id: []const u8, agent_type: AgentType) AgentState {
        const now = std.time.timestamp();
        return AgentState{
            .id = allocator.dupe(u8, id) catch id,
            .agent_type = agent_type,
            .health = .healthy,
            .active_tasks = 0,
            .completed_tasks = 0,
            .failed_tasks = 0,
            .consecutive_failures = 0,
            .last_activity = now,
            .circuit_open_until = 0,
            .created_at = now,
        };
    }

    pub fn deinit(self: *AgentState, allocator: Allocator) void {
        allocator.free(self.id);
    }

    /// Check if agent is available for new tasks
    pub fn isAvailable(self: *const AgentState) bool {
        const now = std.time.timestamp();

        // Check circuit breaker
        if (self.health == .circuit_open) {
            if (now >= self.circuit_open_until) {
                // Circuit breaker cooldown expired
                return false; // Still needs explicit recovery
            }
            return false;
        }

        // Only healthy agents can take tasks
        return self.health == .healthy;
    }

    /// Record task completion
    pub fn recordSuccess(self: *AgentState) void {
        self.completed_tasks += 1;
        self.consecutive_failures = 0;
        self.last_activity = std.time.timestamp();

        // Auto-recover from unhealthy state on success
        if (self.health == .recovering) {
            self.health = .healthy;
        }
    }

    /// Record task failure
    pub fn recordFailure(self: *AgentState, config: ScalingConfig) bool {
        self.failed_tasks += 1;
        self.consecutive_failures += 1;
        self.last_activity = std.time.timestamp();

        // Check circuit breaker threshold
        if (self.consecutive_failures >= config.circuit_breaker_threshold) {
            self.health = .circuit_open;
            const now = std.time.timestamp();
            self.circuit_open_until = now + @as(i64, @intCast(config.circuit_breaker_cooldown_ms / 1000));
            return true; // Circuit opened
        }

        // Mark unhealthy after first failure
        if (self.health == .healthy) {
            self.health = .unhealthy;
        }

        return false;
    }

    /// Attempt to recover agent from circuit breaker
    pub fn recover(self: *AgentState) bool {
        if (self.health != .circuit_open) return false;

        const now = std.time.timestamp();
        if (now < self.circuit_open_until) return false; // Still in cooldown

        self.health = .recovering;
        self.consecutive_failures = 0;
        return true;
    }

    /// Get success rate (0.0-1.0)
    pub fn getSuccessRate(self: *const AgentState) f64 {
        const total = self.completed_tasks + self.failed_tasks;
        if (total == 0) return 1.0;
        return @as(f64, @floatFromInt(self.completed_tasks)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TASK QUEUE
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskPriority = enum(u8) {
    low = 1,
    normal = 5,
    high = 7,
    critical = 10,
};

pub const QueuedTask = struct {
    id: []const u8,
    payload: []const u8,
    priority: TaskPriority,
    created_at: i64,
    timeout_at: i64,
    retries_left: u32,
    assigned_agent: ?[]const u8,

    pub fn init(allocator: Allocator, id: []const u8, payload: []const u8, priority: TaskPriority, timeout_ms: u64) QueuedTask {
        const now = std.time.timestamp();
        return QueuedTask{
            .id = allocator.dupe(u8, id) catch id,
            .payload = allocator.dupe(u8, payload) catch payload,
            .priority = priority,
            .created_at = now,
            .timeout_at = now + @as(i64, @intCast(timeout_ms / 1000)),
            .retries_left = 3,
            .assigned_agent = null,
        };
    }

    pub fn deinit(self: *QueuedTask, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.payload);
        if (self.assigned_agent) |agent| {
            allocator.free(agent);
        }
    }

    /// Check if task has timed out
    pub fn isTimedOut(self: *const QueuedTask) bool {
        return std.time.timestamp() >= self.timeout_at;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSENSUS MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConsensusState = enum {
    pending,
    in_progress,
    reached,
    timeout,
    failed,
};

pub const ConsensusVote = struct {
    agent_id: []const u8,
    decision: bool,
    timestamp: i64,
    reasoning: ?[]const u8,
};

pub const ConsensusSession = struct {
    id: []const u8,
    proposal: []const u8,
    state: ConsensusState,
    votes: std.array_list.Managed(ConsensusVote),
    required_votes: u32,
    timeout_at: i64,
    created_at: i64,
    result: ?bool,

    pub fn init(allocator: Allocator, id: []const u8, proposal: []const u8, required_votes: u32, timeout_ms: u64) ConsensusSession {
        const now = std.time.timestamp();
        return ConsensusSession{
            .id = allocator.dupe(u8, id) catch id,
            .proposal = allocator.dupe(u8, proposal) catch proposal,
            .state = .pending,
            .votes = std.array_list.Managed(ConsensusVote).init(allocator),
            .required_votes = required_votes,
            .timeout_at = now + @as(i64, @intCast(timeout_ms / 1000)),
            .created_at = now,
            .result = null,
        };
    }

    pub fn deinit(self: *ConsensusSession, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.proposal);
        for (self.votes.items) |*vote| {
            if (vote.reasoning) |r| {
                allocator.free(r);
            }
        }
        self.votes.deinit();
    }

    /// Add vote and check if consensus is reached
    pub fn addVote(self: *ConsensusSession, agent_id: []const u8, decision: bool, reasoning: ?[]const u8) !bool {
        const vote = ConsensusVote{
            .agent_id = agent_id,
            .decision = decision,
            .timestamp = std.time.timestamp(),
            .reasoning = reasoning,
        };

        try self.votes.append(vote);
        self.state = .in_progress;

        // Check if we have enough votes
        if (self.votes.items.len >= self.required_votes) {
            return self.checkConsensus();
        }

        return false;
    }

    /// Check if consensus is reached based on votes
    pub fn checkConsensus(self: *ConsensusSession) bool {
        if (self.votes.items.len == 0) return false;
        if (self.votes.items.len < self.required_votes) return false;

        var yes_votes: u32 = 0;
        for (self.votes.items) |vote| {
            if (vote.decision) yes_votes += 1;
        }

        // Supermajority: >70%
        const ratio = @as(f64, @floatFromInt(yes_votes)) / @as(f64, @floatFromInt(self.votes.items.len));
        const consensus_reached = ratio > 0.7;

        if (consensus_reached) {
            self.state = .reached;
            self.result = true;
        } else {
            self.state = .failed;
            self.result = false;
        }

        return consensus_reached;
    }

    /// Check if consensus has timed out
    pub fn isTimedOut(self: *const ConsensusSession) bool {
        return std.time.timestamp() >= self.timeout_at;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOAD BALANCER METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LoadBalancerMetrics = struct {
    total_agents: u32,
    active_agents: u32,
    healthy_agents: u32,
    unhealthy_agents: u32,
    circuit_open_agents: u32,
    queued_tasks: u32,
    active_tasks: u32,
    completed_tasks: u32,
    failed_tasks: u32,
    average_queue_depth: f64,
    scaling_events: u32,
    last_scaling_time: i64,
    consensus_timeout_count: u32,
    deadlock_prevention_count: u32,

    pub fn toJson(self: *const LoadBalancerMetrics, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"total_agents":{d},"active_agents":{d},"healthy_agents":{d},"unhealthy_agents":{d},"circuit_open_agents":{d},"queued_tasks":{d},"active_tasks":{d},"completed_tasks":{d},"failed_tasks":{d},"average_queue_depth":{d:.2},"scaling_events":{d},"last_scaling_time":{d},"consensus_timeout_count":{d},"deadlock_prevention_count":{d}}}
        , .{
            self.total_agents,
            self.active_agents,
            self.healthy_agents,
            self.unhealthy_agents,
            self.circuit_open_agents,
            self.queued_tasks,
            self.active_tasks,
            self.completed_tasks,
            self.failed_tasks,
            self.average_queue_depth,
            self.scaling_events,
            self.last_scaling_time,
            self.consensus_timeout_count,
            self.deadlock_prevention_count,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOAD BALANCER
// ═══════════════════════════════════════════════════════════════════════════════

pub const AgentLoadBalancer = struct {
    allocator: Allocator,
    config: ScalingConfig,
    agents: std.StringHashMap(AgentState),
    task_queue: std.array_list.Managed(QueuedTask),
    consensus_sessions: std.StringHashMap(ConsensusSession),
    metrics: LoadBalancerMetrics,
    last_scaling_time: i64,
    agent_counter: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ScalingConfig) !Self {
        var lb = Self{
            .allocator = allocator,
            .config = config,
            .agents = std.StringHashMap(AgentState).init(allocator),
            .task_queue = std.array_list.Managed(QueuedTask).init(allocator),
            .consensus_sessions = std.StringHashMap(ConsensusSession).init(allocator),
            .metrics = LoadBalancerMetrics{
                .total_agents = 0,
                .active_agents = 0,
                .healthy_agents = 0,
                .unhealthy_agents = 0,
                .circuit_open_agents = 0,
                .queued_tasks = 0,
                .active_tasks = 0,
                .completed_tasks = 0,
                .failed_tasks = 0,
                .average_queue_depth = 0.0,
                .scaling_events = 0,
                .last_scaling_time = 0,
                .consensus_timeout_count = 0,
                .deadlock_prevention_count = 0,
            },
            .last_scaling_time = 0,
            .agent_counter = 0,
        };

        // Initialize with minimum number of agents
        try lb.scaleTo(config.min_agents);

        return lb;
    }

    pub fn deinit(self: *Self) void {
        var agent_iter = self.agents.iterator();
        while (agent_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.agents.deinit();

        for (self.task_queue.items) |*task| {
            task.deinit(self.allocator);
        }
        self.task_queue.deinit();

        var consensus_iter = self.consensus_sessions.iterator();
        while (consensus_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.consensus_sessions.deinit();
    }

    /// ═══════════════════════════════════════════════════════════════════════════
    /// SCALING OPERATIONS
    /// ═══════════════════════════════════════════════════════════════════════════
    /// Scale to specific number of agents
    fn scaleTo(self: *Self, target_count: u32) !void {
        const current_count = @as(u32, @intCast(self.agents.count()));

        if (target_count > current_count) {
            // Scale up
            const to_add = target_count - current_count;
            var i: u32 = 0;
            while (i < to_add) : (i += 1) {
                try self.spawnAgent();
            }
        } else if (target_count < current_count) {
            // Scale down (remove idle agents first)
            const to_remove = current_count - target_count;
            try self.removeIdleAgents(to_remove);
        }
    }

    /// Spawn a new agent
    fn spawnAgent(self: *Self) !void {
        self.agent_counter += 1;
        const agent_id = try std.fmt.allocPrint(self.allocator, "agent_{d}", .{self.agent_counter});

        const agent = AgentState.init(self.allocator, agent_id, .AGENT_MU);
        try self.agents.put(agent_id, agent);

        self.metrics.total_agents = @intCast(self.agents.count());
        self.metrics.scaling_events += 1;
        self.last_scaling_time = std.time.timestamp();
    }

    /// Remove idle agents (with no active tasks)
    fn removeIdleAgents(self: *Self, count: u32) !void {
        var removed: u32 = 0;
        var agent_ids_to_remove = std.array_list.Managed([]const u8).init(self.allocator);
        defer {
            for (agent_ids_to_remove.items) |id| {
                self.allocator.free(id);
            }
            agent_ids_to_remove.deinit();
        }

        // First pass: find agents to remove
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            if (removed >= count) break;
            if (self.agents.count() <= self.config.min_agents) break;

            const agent = entry.value_ptr.*;
            if (agent.active_tasks == 0 and agent.health == .healthy) {
                try agent_ids_to_remove.append(try self.allocator.dupe(u8, entry.key_ptr.*));
                removed += 1;
            }
        }

        // Second pass: actually remove them
        for (agent_ids_to_remove.items) |id| {
            if (self.agents.getPtr(id)) |agent| {
                agent.deinit(self.allocator);
            }
            _ = self.agents.remove(id);
            self.metrics.scaling_events += 1;
        }

        self.metrics.total_agents = @intCast(self.agents.count());
        self.last_scaling_time = std.time.timestamp();
    }

    /// Check if scaling is needed based on queue depth
    pub fn checkScaling(self: *Self) !bool {
        if (!self.config.auto_scaling_enabled) return false;

        const now = std.time.timestamp();
        const cooldown_passed = (now - self.last_scaling_time) >= (self.config.scaling_cooldown_ms / 1000);

        if (!cooldown_passed) return false;

        const queue_depth = @as(f64, @floatFromInt(self.task_queue.items.len));
        const max_capacity = @as(f64, @floatFromInt(self.config.max_agents));
        const queue_ratio = queue_depth / max_capacity;

        if (queue_ratio > self.config.scale_up_threshold) {
            // Scale up
            const current = @as(u32, @intCast(self.agents.count()));
            if (current < self.config.max_agents) {
                const target = @min(current + 2, self.config.max_agents);
                try self.scaleTo(target);
                return true;
            }
        } else if (queue_ratio < self.config.scale_down_threshold) {
            // Scale down
            const current = @as(u32, @intCast(self.agents.count()));
            if (current > self.config.min_agents) {
                const target = @max(current - 1, self.config.min_agents);
                try self.scaleTo(target);
                return true;
            }
        }

        return false;
    }

    /// ═══════════════════════════════════════════════════════════════════════════
    /// TASK OPERATIONS
    /// ═══════════════════════════════════════════════════════════════════════════
    /// Queue a task for execution
    pub fn queueTask(self: *Self, id: []const u8, payload: []const u8, priority: TaskPriority) !void {
        const task = QueuedTask.init(self.allocator, id, payload, priority, self.config.task_timeout_ms);
        try self.task_queue.append(task);
        self.metrics.queued_tasks = @intCast(self.task_queue.items.len);

        // Trigger scaling check
        _ = try self.checkScaling();
    }

    /// Assign task to best available agent
    pub fn assignTask(self: *Self) !?[]const u8 {
        if (self.task_queue.items.len == 0) return null;

        // Find best available agent (least loaded)
        var best_agent: ?*AgentState = null;
        var min_tasks: u32 = std.math.maxInt(u32);

        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const agent = entry.value_ptr;
            if (agent.isAvailable() and agent.active_tasks < min_tasks) {
                min_tasks = agent.active_tasks;
                best_agent = agent;
            }
        }

        if (best_agent == null) return null; // No available agents

        // Get highest priority task
        const task_index = try self.findHighestPriorityTask();
        const task = &self.task_queue.items[task_index];

        // Assign task
        best_agent.?.active_tasks += 1;
        best_agent.?.last_activity = std.time.timestamp();
        task.assigned_agent = try self.allocator.dupe(u8, best_agent.?.id);

        // Move task to active (remove from queue)
        _ = self.task_queue.orderedRemove(task_index);
        self.metrics.queued_tasks = @intCast(self.task_queue.items.len);
        self.metrics.active_tasks += 1;

        return try self.allocator.dupe(u8, task.id);
    }

    /// Find highest priority task in queue
    fn findHighestPriorityTask(self: *Self) !usize {
        if (self.task_queue.items.len == 0) return error.NoTasks;

        var best_index: usize = 0;
        var best_priority: u8 = 0;

        for (self.task_queue.items, 0..) |task, i| {
            const priority_val = @intFromEnum(task.priority);
            if (priority_val > best_priority) {
                best_priority = priority_val;
                best_index = i;
            }
        }

        return best_index;
    }

    /// Mark task as completed
    pub fn completeTask(self: *Self, task_id: []const u8, agent_id: []const u8, success: bool) !void {
        if (self.agents.getPtr(agent_id)) |agent| {
            agent.active_tasks -= 1;

            if (success) {
                agent.recordSuccess();
                self.metrics.completed_tasks += 1;
            } else {
                const circuit_opened = agent.recordFailure(self.config);
                self.metrics.failed_tasks += 1;

                if (circuit_opened) {
                    // Task failed and circuit opened, reschedule if retries left
                    // DEFERRED (v12): Find and reschedule task to different agent
                    // Requires: retry queue, agent selection, task requeuing
                    _ = task_id;
                }
            }
        }

        self.metrics.active_tasks -= 1;

        // Check for timed-out tasks
        try self.cleanupTimedOutTasks();

        // Check for scaling
        _ = try self.checkScaling();
    }

    /// Remove timed-out tasks from queue
    fn cleanupTimedOutTasks(self: *Self) !void {
        var i: usize = 0;
        while (i < self.task_queue.items.len) {
            const task = &self.task_queue.items[i];
            if (task.isTimedOut()) {
                task.deinit(self.allocator);
                _ = self.task_queue.orderedRemove(i);
            } else {
                i += 1;
            }
        }
        self.metrics.queued_tasks = @intCast(self.task_queue.items.len);
    }

    /// ═══════════════════════════════════════════════════════════════════════════
    /// CONSENSUS OPERATIONS
    /// ═══════════════════════════════════════════════════════════════════════════
    /// Start a new consensus session
    pub fn startConsensus(self: *Self, proposal: []const u8) ![]const u8 {
        const session_id = try std.fmt.allocPrint(self.allocator, "consensus_{d}", .{std.time.timestamp()});

        const required_votes = @min(@as(u32, @intCast(self.agents.count())), 10); // Max 10 votes needed
        const session = ConsensusSession.init(self.allocator, session_id, proposal, required_votes, self.config.consensus_timeout_ms);

        try self.consensus_sessions.put(session_id, session);

        return session_id;
    }

    /// Add vote to consensus session
    pub fn addConsensusVote(self: *Self, session_id: []const u8, agent_id: []const u8, decision: bool, reasoning: ?[]const u8) !bool {
        const session = self.consensus_sessions.getPtr(session_id) orelse return error.SessionNotFound;

        if (session.state == .timeout or session.state == .reached or session.state == .failed) {
            return error.SessionClosed;
        }

        const consensus_reached = try session.addVote(agent_id, decision, reasoning);

        if (consensus_reached) {
            return true;
        }

        // Check for timeout
        if (session.isTimedOut()) {
            session.state = .timeout;
            self.metrics.consensus_timeout_count += 1;

            // Activate deadlock prevention
            try self.preventDeadlock(session_id);
        }

        return false;
    }

    /// Prevent deadlock in stuck consensus
    fn preventDeadlock(self: *Self, session_id: []const u8) !void {
        const session = self.consensus_sessions.getPtr(session_id) orelse return;

        // If we have at least 50% votes, use majority decision
        if (session.votes.items.len > 0 and session.votes.items.len >= session.required_votes / 2) {
            var yes_votes: u32 = 0;
            for (session.votes.items) |vote| {
                if (vote.decision) yes_votes += 1;
            }

            const ratio = @as(f64, @floatFromInt(yes_votes)) / @as(f64, @floatFromInt(session.votes.items.len));
            session.result = ratio >= 0.5;
            session.state = .reached; // Override timeout
            self.metrics.deadlock_prevention_count += 1;
        }
    }

    /// Get consensus session result
    pub fn getConsensusResult(self: *Self, session_id: []const u8) ?bool {
        const session = self.consensus_sessions.get(session_id) orelse return null;
        return session.result;
    }

    /// ═══════════════════════════════════════════════════════════════════════════
    /// METRICS AND MONITORING
    /// ═══════════════════════════════════════════════════════════════════════════
    /// Update metrics
    pub fn updateMetrics(self: *Self) void {
        var healthy: u32 = 0;
        var unhealthy: u32 = 0;
        var circuit_open: u32 = 0;
        var active: u32 = 0;

        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const agent = entry.value_ptr.*;
            if (agent.active_tasks > 0) active += 1;

            switch (agent.health) {
                .healthy => healthy += 1,
                .unhealthy, .recovering => unhealthy += 1,
                .circuit_open => circuit_open += 1,
            }
        }

        self.metrics.total_agents = @intCast(self.agents.count());
        self.metrics.active_agents = active;
        self.metrics.healthy_agents = healthy;
        self.metrics.unhealthy_agents = unhealthy;
        self.metrics.circuit_open_agents = circuit_open;
        self.metrics.queued_tasks = @intCast(self.task_queue.items.len);
        self.metrics.last_scaling_time = self.last_scaling_time;

        // Calculate average queue depth (moving average would be better)
        self.metrics.average_queue_depth = @as(f64, @floatFromInt(self.task_queue.items.len)) /
            @as(f64, @floatFromInt(self.metrics.total_agents));
    }

    /// Get current metrics
    pub fn getMetrics(self: *Self) LoadBalancerMetrics {
        self.updateMetrics();
        return self.metrics;
    }

    /// Get metrics as JSON
    pub fn getMetricsJson(self: *Self) ![]const u8 {
        self.updateMetrics();
        return self.metrics.toJson(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LoadBalancer: initialization" {
    const allocator = std.testing.allocator;
    const config = ScalingConfig{
        .min_agents = 2,
        .max_agents = 8,
        .auto_scaling_enabled = false, // Disable for testing
    };

    var lb = try AgentLoadBalancer.init(allocator, config);
    defer lb.deinit();

    try std.testing.expectEqual(@as(usize, 2), lb.agents.count());
}

test "LoadBalancer: queue task" {
    const allocator = std.testing.allocator;
    const config = ScalingConfig{
        .min_agents = 2,
        .max_agents = 8,
        .auto_scaling_enabled = false,
    };

    var lb = try AgentLoadBalancer.init(allocator, config);
    defer lb.deinit();

    try lb.queueTask("task1", "payload", .normal);

    try std.testing.expectEqual(@as(usize, 1), lb.task_queue.items.len);
}

test "LoadBalancer: scale up" {
    const allocator = std.testing.allocator;
    const config = ScalingConfig{
        .min_agents = 2,
        .max_agents = 8,
        .scale_up_threshold = 0.5,
        .auto_scaling_enabled = true,
        .scaling_cooldown_ms = 0, // Disable cooldown for testing
    };

    var lb = try AgentLoadBalancer.init(allocator, config);
    defer lb.deinit();

    // Queue enough tasks to trigger scale-up
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        try lb.queueTask("task", "payload", .normal);
    }

    _ = try lb.checkScaling();

    // Should scale up (6 tasks > 0.5 * 8 = 4 threshold)
    try std.testing.expect(lb.agents.count() > 2);
}

test "LoadBalancer: agent health tracking" {
    const allocator = std.testing.allocator;

    const config = ScalingConfig{
        .min_agents = 1,
        .max_agents = 4,
        .circuit_breaker_threshold = 2,
        .auto_scaling_enabled = false,
    };

    var lb = try AgentLoadBalancer.init(allocator, config);
    defer lb.deinit();

    var iter = lb.agents.iterator();
    const first_entry = iter.next().?;
    var agent = first_entry.value_ptr;

    // Record failures
    try std.testing.expect(!agent.recordFailure(config)); // First failure
    try std.testing.expectEqual(.unhealthy, agent.health);

    try std.testing.expect(agent.recordFailure(config)); // Second failure triggers circuit
    try std.testing.expectEqual(.circuit_open, agent.health);

    // Check agent is unavailable
    try std.testing.expect(!agent.isAvailable());
}

test "LoadBalancer: consensus timeout" {
    const allocator = std.testing.allocator;
    const config = ScalingConfig{
        .min_agents = 2,
        .max_agents = 8,
        .consensus_timeout_ms = 100, // Very short timeout
        .auto_scaling_enabled = false,
    };

    var lb = try AgentLoadBalancer.init(allocator, config);
    defer lb.deinit();

    const session_id = try lb.startConsensus("Test proposal");

    // Wait for timeout (200ms > 100ms timeout)
    std.posix.nanosleep(0, 200 * 1000000); // 200ms in nanoseconds

    // Try to add vote (should not return error, but check state)
    _ = try lb.addConsensusVote(session_id, "agent_1", true, null);

    // Check timeout was recorded
    const session = lb.consensus_sessions.get(session_id).?;
    // The vote should have been added but session is now timed out
    try std.testing.expect(session.isTimedOut());
}

test "LoadBalancer: metrics" {
    const allocator = std.testing.allocator;
    const config = ScalingConfig{
        .min_agents = 4,
        .max_agents = 8,
        .auto_scaling_enabled = false,
    };

    var lb = try AgentLoadBalancer.init(allocator, config);
    defer lb.deinit();

    const metrics = lb.getMetrics();

    try std.testing.expectEqual(@as(u32, 4), metrics.total_agents);
    try std.testing.expectEqual(@as(u32, 4), metrics.healthy_agents);
}
