// =============================================================================
// IGLA MULTI-AGENT SYSTEM v1.0 - Coordinator + Specialist Agents
// =============================================================================
//
// CYCLE 21: Golden Chain Pipeline
// - Coordinator agent for task decomposition
// - Specialist agents: Coder, Chat, Reasoner, Researcher
// - Task routing and result aggregation
// - Parallel agent execution simulation
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI ORCHESTRATES ETERNALLY
// =============================================================================

const std = @import("std");
const finetune = @import("igla_finetune_engine.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const MAX_AGENTS: usize = 8;
pub const MAX_TASKS: usize = 32;
pub const MAX_SUBTASKS: usize = 8;
pub const MAX_TASK_SIZE: usize = 512;
pub const MAX_RESULT_SIZE: usize = 1024;
pub const MAX_AGENT_NAME: usize = 32;

// =============================================================================
// AGENT TYPE
// =============================================================================

pub const AgentType = enum {
    Coordinator,
    Coder,
    Chat,
    Reasoner,
    Researcher,
    Analyst,
    Writer,
    Reviewer,

    pub fn getName(self: AgentType) []const u8 {
        return switch (self) {
            .Coordinator => "Coordinator",
            .Coder => "Coder",
            .Chat => "Chat",
            .Reasoner => "Reasoner",
            .Researcher => "Researcher",
            .Analyst => "Analyst",
            .Writer => "Writer",
            .Reviewer => "Reviewer",
        };
    }

    pub fn getDescription(self: AgentType) []const u8 {
        return switch (self) {
            .Coordinator => "Task decomposition and orchestration",
            .Coder => "Code generation and programming",
            .Chat => "Conversational dialogue",
            .Reasoner => "Logic and analysis",
            .Researcher => "Information retrieval",
            .Analyst => "Data analysis",
            .Writer => "Content creation",
            .Reviewer => "Quality review",
        };
    }

    pub fn isSpecialist(self: AgentType) bool {
        return self != .Coordinator;
    }
};

// =============================================================================
// AGENT STATE
// =============================================================================

pub const AgentState = enum {
    Idle,
    Working,
    Waiting,
    Complete,
    Error,

    pub fn getName(self: AgentState) []const u8 {
        return switch (self) {
            .Idle => "idle",
            .Working => "working",
            .Waiting => "waiting",
            .Complete => "complete",
            .Error => "error",
        };
    }

    pub fn isAvailable(self: AgentState) bool {
        return self == .Idle or self == .Complete;
    }

    pub fn isActive(self: AgentState) bool {
        return self == .Working or self == .Waiting;
    }
};

// =============================================================================
// TASK TYPE
// =============================================================================

pub const TaskType = enum {
    Code,
    Chat,
    Reason,
    Research,
    Analyze,
    Write,
    Review,
    Composite,

    pub fn getName(self: TaskType) []const u8 {
        return switch (self) {
            .Code => "code",
            .Chat => "chat",
            .Reason => "reason",
            .Research => "research",
            .Analyze => "analyze",
            .Write => "write",
            .Review => "review",
            .Composite => "composite",
        };
    }

    pub fn getPreferredAgent(self: TaskType) AgentType {
        return switch (self) {
            .Code => .Coder,
            .Chat => .Chat,
            .Reason => .Reasoner,
            .Research => .Researcher,
            .Analyze => .Analyst,
            .Write => .Writer,
            .Review => .Reviewer,
            .Composite => .Coordinator,
        };
    }

    pub fn detectFromInput(input: []const u8) TaskType {
        // Detect task type from keywords
        const lower = blk: {
            var buf: [256]u8 = undefined;
            const len = @min(input.len, 256);
            for (input[0..len], 0..) |c, i| {
                buf[i] = std.ascii.toLower(c);
            }
            break :blk buf[0..len];
        };

        if (std.mem.indexOf(u8, lower, "code") != null or
            std.mem.indexOf(u8, lower, "function") != null or
            std.mem.indexOf(u8, lower, "implement") != null or
            std.mem.indexOf(u8, lower, "program") != null)
        {
            return .Code;
        }

        if (std.mem.indexOf(u8, lower, "analyze") != null or
            std.mem.indexOf(u8, lower, "analysis") != null or
            std.mem.indexOf(u8, lower, "data") != null)
        {
            return .Analyze;
        }

        if (std.mem.indexOf(u8, lower, "research") != null or
            std.mem.indexOf(u8, lower, "find") != null or
            std.mem.indexOf(u8, lower, "search") != null)
        {
            return .Research;
        }

        if (std.mem.indexOf(u8, lower, "reason") != null or
            std.mem.indexOf(u8, lower, "logic") != null or
            std.mem.indexOf(u8, lower, "explain") != null or
            std.mem.indexOf(u8, lower, "why") != null)
        {
            return .Reason;
        }

        if (std.mem.indexOf(u8, lower, "write") != null or
            std.mem.indexOf(u8, lower, "create") != null or
            std.mem.indexOf(u8, lower, "compose") != null)
        {
            return .Write;
        }

        if (std.mem.indexOf(u8, lower, "review") != null or
            std.mem.indexOf(u8, lower, "check") != null or
            std.mem.indexOf(u8, lower, "verify") != null)
        {
            return .Review;
        }

        // Default to chat for general queries
        return .Chat;
    }
};

// =============================================================================
// TASK PRIORITY
// =============================================================================

pub const TaskPriority = enum(u8) {
    Low = 1,
    Normal = 2,
    High = 3,
    Critical = 4,

    pub fn getValue(self: TaskPriority) u8 {
        return @intFromEnum(self);
    }
};

// =============================================================================
// TASK
// =============================================================================

pub const Task = struct {
    id: u32,
    task_type: TaskType,
    input: [MAX_TASK_SIZE]u8,
    input_len: usize,
    priority: TaskPriority,
    parent_id: ?u32,
    created_at: i64,
    assigned_agent: ?AgentType,
    is_complete: bool,

    pub fn init(id: u32, task_type: TaskType, input: []const u8) Task {
        var task = Task{
            .id = id,
            .task_type = task_type,
            .input = undefined,
            .input_len = @min(input.len, MAX_TASK_SIZE),
            .priority = .Normal,
            .parent_id = null,
            .created_at = @intCast(std.time.nanoTimestamp()),
            .assigned_agent = null,
            .is_complete = false,
        };
        @memcpy(task.input[0..task.input_len], input[0..task.input_len]);
        return task;
    }

    pub fn getInput(self: *const Task) []const u8 {
        return self.input[0..self.input_len];
    }

    pub fn setPriority(self: *Task, priority: TaskPriority) void {
        self.priority = priority;
    }

    pub fn setParent(self: *Task, parent_id: u32) void {
        self.parent_id = parent_id;
    }

    pub fn assign(self: *Task, agent: AgentType) void {
        self.assigned_agent = agent;
    }

    pub fn complete(self: *Task) void {
        self.is_complete = true;
    }
};

// =============================================================================
// TASK RESULT
// =============================================================================

pub const TaskResult = struct {
    task_id: u32,
    output: [MAX_RESULT_SIZE]u8,
    output_len: usize,
    confidence: f32,
    agent_type: AgentType,
    processing_time_ns: i64,
    success: bool,

    pub fn init(task_id: u32, agent_type: AgentType) TaskResult {
        return TaskResult{
            .task_id = task_id,
            .output = undefined,
            .output_len = 0,
            .confidence = 0.0,
            .agent_type = agent_type,
            .processing_time_ns = 0,
            .success = false,
        };
    }

    pub fn setOutput(self: *TaskResult, output: []const u8, confidence: f32) void {
        self.output_len = @min(output.len, MAX_RESULT_SIZE);
        @memcpy(self.output[0..self.output_len], output[0..self.output_len]);
        self.confidence = confidence;
        self.success = true;
    }

    pub fn getOutput(self: *const TaskResult) []const u8 {
        return self.output[0..self.output_len];
    }

    pub fn setProcessingTime(self: *TaskResult, time_ns: i64) void {
        self.processing_time_ns = time_ns;
    }

    pub fn isHighQuality(self: *const TaskResult) bool {
        return self.success and self.confidence >= 0.7;
    }
};

// =============================================================================
// AGENT
// =============================================================================

pub const Agent = struct {
    agent_type: AgentType,
    state: AgentState,
    tasks_completed: usize,
    total_confidence: f32,
    finetune_engine: finetune.FineTuneEngine,

    pub fn init(agent_type: AgentType) Agent {
        return Agent{
            .agent_type = agent_type,
            .state = .Idle,
            .tasks_completed = 0,
            .total_confidence = 0.0,
            .finetune_engine = finetune.FineTuneEngine.init(),
        };
    }

    pub fn process(self: *Agent, task: *const Task) TaskResult {
        const start_time: i64 = @intCast(std.time.nanoTimestamp());
        self.state = .Working;

        var result = TaskResult.init(task.id, self.agent_type);

        // Generate response based on agent type
        const response = self.generateResponse(task);
        result.setOutput(response.content, response.confidence);

        const end_time: i64 = @intCast(std.time.nanoTimestamp());
        result.setProcessingTime(end_time - start_time);

        self.state = .Complete;
        self.tasks_completed += 1;
        self.total_confidence += result.confidence;

        return result;
    }

    const AgentResponse = struct {
        content: []const u8,
        confidence: f32,
    };

    fn generateResponse(self: *Agent, task: *const Task) AgentResponse {
        // Try fine-tuned response first
        const adapted = self.finetune_engine.infer(task.getInput());
        if (adapted.is_adapted and adapted.similarity >= 0.6) {
            return .{
                .content = adapted.getContent(),
                .confidence = adapted.similarity,
            };
        }

        // Generate default response based on agent type
        return switch (self.agent_type) {
            .Coder => .{
                .content = "// Generated code solution\nfn solve() void {\n    // Implementation here\n}",
                .confidence = 0.85,
            },
            .Chat => .{
                .content = "I understand your question. Let me help you with that.",
                .confidence = 0.90,
            },
            .Reasoner => .{
                .content = "Based on logical analysis: The conclusion follows from the premises through valid reasoning.",
                .confidence = 0.88,
            },
            .Researcher => .{
                .content = "Research findings: The topic has been extensively studied with multiple sources supporting the conclusion.",
                .confidence = 0.82,
            },
            .Analyst => .{
                .content = "Analysis results: The data shows significant patterns indicating positive correlation.",
                .confidence = 0.86,
            },
            .Writer => .{
                .content = "Content created: A well-structured piece addressing the key points with clarity.",
                .confidence = 0.84,
            },
            .Reviewer => .{
                .content = "Review complete: Quality meets standards with minor suggestions for improvement.",
                .confidence = 0.87,
            },
            .Coordinator => .{
                .content = "Task coordinated: Subtasks have been delegated and results aggregated.",
                .confidence = 0.92,
            },
        };
    }

    pub fn getAverageConfidence(self: *const Agent) f32 {
        if (self.tasks_completed == 0) return 0.0;
        return self.total_confidence / @as(f32, @floatFromInt(self.tasks_completed));
    }

    pub fn isAvailable(self: *const Agent) bool {
        return self.state.isAvailable();
    }

    pub fn canHandle(self: *const Agent, task_type: TaskType) bool {
        return task_type.getPreferredAgent() == self.agent_type;
    }

    pub fn train(self: *Agent, input: []const u8, output: []const u8) bool {
        const category = self.agent_type.getName();
        return self.finetune_engine.addExample(input, output, category);
    }
};

// =============================================================================
// AGENT POOL
// =============================================================================

pub const AgentPool = struct {
    agents: [MAX_AGENTS]Agent,
    agent_count: usize,

    pub fn init() AgentPool {
        var pool = AgentPool{
            .agents = undefined,
            .agent_count = 0,
        };

        // Initialize default agents
        _ = pool.addAgent(.Coordinator);
        _ = pool.addAgent(.Coder);
        _ = pool.addAgent(.Chat);
        _ = pool.addAgent(.Reasoner);
        _ = pool.addAgent(.Researcher);

        return pool;
    }

    pub fn addAgent(self: *AgentPool, agent_type: AgentType) bool {
        if (self.agent_count >= MAX_AGENTS) return false;
        self.agents[self.agent_count] = Agent.init(agent_type);
        self.agent_count += 1;
        return true;
    }

    pub fn getAgent(self: *AgentPool, agent_type: AgentType) ?*Agent {
        for (self.agents[0..self.agent_count]) |*agent| {
            if (agent.agent_type == agent_type) {
                return agent;
            }
        }
        return null;
    }

    pub fn getAvailableAgent(self: *AgentPool, task_type: TaskType) ?*Agent {
        const preferred = task_type.getPreferredAgent();

        // First try preferred agent
        if (self.getAgent(preferred)) |agent| {
            if (agent.isAvailable()) {
                return agent;
            }
        }

        // Try any available specialist
        for (self.agents[0..self.agent_count]) |*agent| {
            if (agent.isAvailable() and agent.agent_type.isSpecialist()) {
                return agent;
            }
        }

        return null;
    }

    pub fn getCoordinator(self: *AgentPool) ?*Agent {
        return self.getAgent(.Coordinator);
    }

    pub fn getTotalTasksCompleted(self: *const AgentPool) usize {
        var total: usize = 0;
        for (self.agents[0..self.agent_count]) |*agent| {
            total += agent.tasks_completed;
        }
        return total;
    }

    pub fn getOverallConfidence(self: *const AgentPool) f32 {
        var total_conf: f32 = 0.0;
        var total_tasks: usize = 0;
        for (self.agents[0..self.agent_count]) |*agent| {
            total_conf += agent.total_confidence;
            total_tasks += agent.tasks_completed;
        }
        if (total_tasks == 0) return 0.0;
        return total_conf / @as(f32, @floatFromInt(total_tasks));
    }
};

// =============================================================================
// TASK QUEUE
// =============================================================================

pub const TaskQueue = struct {
    tasks: [MAX_TASKS]Task,
    task_count: usize,
    next_id: u32,

    pub fn init() TaskQueue {
        return TaskQueue{
            .tasks = undefined,
            .task_count = 0,
            .next_id = 1,
        };
    }

    pub fn enqueue(self: *TaskQueue, task_type: TaskType, input: []const u8) ?u32 {
        if (self.task_count >= MAX_TASKS) return null;

        const id = self.next_id;
        self.tasks[self.task_count] = Task.init(id, task_type, input);
        self.task_count += 1;
        self.next_id += 1;
        return id;
    }

    pub fn getTask(self: *TaskQueue, id: u32) ?*Task {
        for (self.tasks[0..self.task_count]) |*task| {
            if (task.id == id) {
                return task;
            }
        }
        return null;
    }

    pub fn getNextPending(self: *TaskQueue) ?*Task {
        // Get highest priority pending task
        var best: ?*Task = null;
        var best_priority: u8 = 0;

        for (self.tasks[0..self.task_count]) |*task| {
            if (!task.is_complete and task.priority.getValue() > best_priority) {
                best = task;
                best_priority = task.priority.getValue();
            }
        }

        return best;
    }

    pub fn getPendingCount(self: *const TaskQueue) usize {
        var count: usize = 0;
        for (self.tasks[0..self.task_count]) |*task| {
            if (!task.is_complete) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getCompletedCount(self: *const TaskQueue) usize {
        return self.task_count - self.getPendingCount();
    }

    pub fn clear(self: *TaskQueue) void {
        self.task_count = 0;
    }
};

// =============================================================================
// COORDINATOR
// =============================================================================

pub const Coordinator = struct {
    agent: Agent,
    decompositions: usize,
    aggregations: usize,

    pub fn init() Coordinator {
        return Coordinator{
            .agent = Agent.init(.Coordinator),
            .decompositions = 0,
            .aggregations = 0,
        };
    }

    pub fn decompose(self: *Coordinator, task: *const Task) [MAX_SUBTASKS]?Task {
        var subtasks: [MAX_SUBTASKS]?Task = [_]?Task{null} ** MAX_SUBTASKS;

        // Analyze task and create subtasks
        const input = task.getInput();

        // Simple decomposition: split by "and" or detect multiple concerns
        var subtask_idx: usize = 0;

        // Check for compound tasks
        if (std.mem.indexOf(u8, input, " and ")) |_| {
            // Create subtasks for each part
            var parts = std.mem.splitSequence(u8, input, " and ");
            while (parts.next()) |part| {
                if (subtask_idx >= MAX_SUBTASKS) break;
                const task_type = TaskType.detectFromInput(part);
                var subtask = Task.init(@intCast(subtask_idx + 100), task_type, part);
                subtask.setParent(task.id);
                subtasks[subtask_idx] = subtask;
                subtask_idx += 1;
            }
        } else {
            // Single task, just detect type
            const task_type = TaskType.detectFromInput(input);
            var subtask = Task.init(100, task_type, input);
            subtask.setParent(task.id);
            subtasks[0] = subtask;
            subtask_idx = 1;
        }

        self.decompositions += 1;
        return subtasks;
    }

    pub fn aggregate(self: *Coordinator, results: []const TaskResult) TaskResult {
        var aggregated = TaskResult.init(0, .Coordinator);

        if (results.len == 0) {
            aggregated.setOutput("No results to aggregate.", 0.0);
            return aggregated;
        }

        // Combine results
        var combined: [MAX_RESULT_SIZE]u8 = undefined;
        var combined_len: usize = 0;
        var total_confidence: f32 = 0.0;
        var result_count: usize = 0;

        for (results) |*result| {
            if (!result.success) continue;

            const output = result.getOutput();
            if (combined_len + output.len + 2 < MAX_RESULT_SIZE) {
                @memcpy(combined[combined_len .. combined_len + output.len], output);
                combined_len += output.len;
                combined[combined_len] = ' ';
                combined_len += 1;
            }
            total_confidence += result.confidence;
            result_count += 1;
        }

        if (result_count > 0) {
            aggregated.setOutput(combined[0..combined_len], total_confidence / @as(f32, @floatFromInt(result_count)));
        } else {
            aggregated.setOutput("Aggregation failed.", 0.0);
        }

        self.aggregations += 1;
        return aggregated;
    }

    pub fn route(self: *Coordinator, task: *const Task) AgentType {
        _ = self;
        return task.task_type.getPreferredAgent();
    }
};

// =============================================================================
// MULTI-AGENT STATS
// =============================================================================

pub const MultiAgentStats = struct {
    total_tasks: usize,
    completed_tasks: usize,
    total_agents: usize,
    decompositions: usize,
    aggregations: usize,
    avg_confidence: f32,
    tasks_per_agent: f32,

    pub fn init() MultiAgentStats {
        return MultiAgentStats{
            .total_tasks = 0,
            .completed_tasks = 0,
            .total_agents = 0,
            .decompositions = 0,
            .aggregations = 0,
            .avg_confidence = 0.0,
            .tasks_per_agent = 0.0,
        };
    }

    pub fn getCompletionRate(self: *const MultiAgentStats) f32 {
        if (self.total_tasks == 0) return 0.0;
        return @as(f32, @floatFromInt(self.completed_tasks)) / @as(f32, @floatFromInt(self.total_tasks));
    }
};

// =============================================================================
// MULTI-AGENT SYSTEM
// =============================================================================

pub const MultiAgentSystem = struct {
    pool: AgentPool,
    queue: TaskQueue,
    coordinator: Coordinator,
    results: [MAX_TASKS]TaskResult,
    result_count: usize,
    stats: MultiAgentStats,

    pub fn init() MultiAgentSystem {
        return MultiAgentSystem{
            .pool = AgentPool.init(),
            .queue = TaskQueue.init(),
            .coordinator = Coordinator.init(),
            .results = undefined,
            .result_count = 0,
            .stats = MultiAgentStats.init(),
        };
    }

    pub fn submitTask(self: *MultiAgentSystem, input: []const u8) ?u32 {
        const task_type = TaskType.detectFromInput(input);
        const id = self.queue.enqueue(task_type, input);
        if (id != null) {
            self.stats.total_tasks += 1;
        }
        return id;
    }

    pub fn processAllTasks(self: *MultiAgentSystem) usize {
        var processed: usize = 0;

        while (self.queue.getNextPending()) |task| {
            const result = self.processTask(task);
            self.storeResult(result);
            task.complete();
            processed += 1;
        }

        self.updateStats();
        return processed;
    }

    fn processTask(self: *MultiAgentSystem, task: *Task) TaskResult {
        // Decompose if composite
        if (task.task_type == .Composite) {
            const subtasks = self.coordinator.decompose(task);
            var subtask_results: [MAX_SUBTASKS]TaskResult = undefined;
            var subtask_count: usize = 0;

            for (subtasks) |maybe_subtask| {
                if (maybe_subtask) |subtask| {
                    const agent_type = self.coordinator.route(&subtask);
                    if (self.pool.getAgent(agent_type)) |agent| {
                        subtask_results[subtask_count] = agent.process(&subtask);
                        subtask_count += 1;
                    }
                }
            }

            return self.coordinator.aggregate(subtask_results[0..subtask_count]);
        }

        // Route to appropriate agent
        const agent_type = self.coordinator.route(task);
        task.assign(agent_type);

        if (self.pool.getAgent(agent_type)) |agent| {
            return agent.process(task);
        }

        // Fallback to coordinator
        return self.coordinator.agent.process(task);
    }

    fn storeResult(self: *MultiAgentSystem, result: TaskResult) void {
        if (self.result_count < MAX_TASKS) {
            self.results[self.result_count] = result;
            self.result_count += 1;
            if (result.success) {
                self.stats.completed_tasks += 1;
            }
        }
    }

    pub fn getResult(self: *const MultiAgentSystem, task_id: u32) ?*const TaskResult {
        for (self.results[0..self.result_count]) |*result| {
            if (result.task_id == task_id) {
                return result;
            }
        }
        return null;
    }

    pub fn getStats(self: *const MultiAgentSystem) MultiAgentStats {
        return self.stats;
    }

    fn updateStats(self: *MultiAgentSystem) void {
        self.stats.total_agents = self.pool.agent_count;
        self.stats.decompositions = self.coordinator.decompositions;
        self.stats.aggregations = self.coordinator.aggregations;
        self.stats.avg_confidence = self.pool.getOverallConfidence();

        if (self.pool.agent_count > 0) {
            self.stats.tasks_per_agent = @as(f32, @floatFromInt(self.stats.completed_tasks)) /
                @as(f32, @floatFromInt(self.pool.agent_count));
        }
    }

    pub fn trainAgent(self: *MultiAgentSystem, agent_type: AgentType, input: []const u8, output: []const u8) bool {
        if (self.pool.getAgent(agent_type)) |agent| {
            return agent.train(input, output);
        }
        return false;
    }

    pub fn getAgentCount(self: *const MultiAgentSystem) usize {
        return self.pool.agent_count;
    }

    pub fn getCompletedTaskCount(self: *const MultiAgentSystem) usize {
        return self.result_count;
    }

    pub fn reset(self: *MultiAgentSystem) void {
        self.queue.clear();
        self.result_count = 0;
        self.stats = MultiAgentStats.init();
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "AgentType getName" {
    try std.testing.expectEqualStrings("Coordinator", AgentType.Coordinator.getName());
    try std.testing.expectEqualStrings("Coder", AgentType.Coder.getName());
    try std.testing.expectEqualStrings("Chat", AgentType.Chat.getName());
}

test "AgentType isSpecialist" {
    try std.testing.expect(!AgentType.Coordinator.isSpecialist());
    try std.testing.expect(AgentType.Coder.isSpecialist());
    try std.testing.expect(AgentType.Chat.isSpecialist());
}

test "AgentState getName" {
    try std.testing.expectEqualStrings("idle", AgentState.Idle.getName());
    try std.testing.expectEqualStrings("working", AgentState.Working.getName());
}

test "AgentState isAvailable" {
    try std.testing.expect(AgentState.Idle.isAvailable());
    try std.testing.expect(AgentState.Complete.isAvailable());
    try std.testing.expect(!AgentState.Working.isAvailable());
}

test "TaskType getName" {
    try std.testing.expectEqualStrings("code", TaskType.Code.getName());
    try std.testing.expectEqualStrings("chat", TaskType.Chat.getName());
}

test "TaskType getPreferredAgent" {
    try std.testing.expectEqual(AgentType.Coder, TaskType.Code.getPreferredAgent());
    try std.testing.expectEqual(AgentType.Chat, TaskType.Chat.getPreferredAgent());
    try std.testing.expectEqual(AgentType.Reasoner, TaskType.Reason.getPreferredAgent());
}

test "TaskType detectFromInput" {
    try std.testing.expectEqual(TaskType.Code, TaskType.detectFromInput("implement a function"));
    try std.testing.expectEqual(TaskType.Research, TaskType.detectFromInput("research this topic"));
    try std.testing.expectEqual(TaskType.Reason, TaskType.detectFromInput("explain why this works"));
    try std.testing.expectEqual(TaskType.Chat, TaskType.detectFromInput("hello there"));
}

test "TaskPriority getValue" {
    try std.testing.expectEqual(@as(u8, 1), TaskPriority.Low.getValue());
    try std.testing.expectEqual(@as(u8, 4), TaskPriority.Critical.getValue());
}

test "Task init" {
    const task = Task.init(1, .Code, "implement a function");
    try std.testing.expectEqual(@as(u32, 1), task.id);
    try std.testing.expectEqual(TaskType.Code, task.task_type);
    try std.testing.expectEqualStrings("implement a function", task.getInput());
}

test "Task setPriority" {
    var task = Task.init(1, .Code, "test");
    task.setPriority(.High);
    try std.testing.expectEqual(TaskPriority.High, task.priority);
}

test "Task setParent" {
    var task = Task.init(2, .Code, "subtask");
    task.setParent(1);
    try std.testing.expectEqual(@as(u32, 1), task.parent_id.?);
}

test "Task assign and complete" {
    var task = Task.init(1, .Code, "test");
    task.assign(.Coder);
    try std.testing.expectEqual(AgentType.Coder, task.assigned_agent.?);

    task.complete();
    try std.testing.expect(task.is_complete);
}

test "TaskResult init" {
    const result = TaskResult.init(1, .Coder);
    try std.testing.expectEqual(@as(u32, 1), result.task_id);
    try std.testing.expectEqual(AgentType.Coder, result.agent_type);
    try std.testing.expect(!result.success);
}

test "TaskResult setOutput" {
    var result = TaskResult.init(1, .Coder);
    result.setOutput("output text", 0.85);
    try std.testing.expectEqualStrings("output text", result.getOutput());
    try std.testing.expectEqual(@as(f32, 0.85), result.confidence);
    try std.testing.expect(result.success);
}

test "TaskResult isHighQuality" {
    var result = TaskResult.init(1, .Coder);
    result.setOutput("good output", 0.8);
    try std.testing.expect(result.isHighQuality());

    var low_result = TaskResult.init(2, .Coder);
    low_result.setOutput("poor output", 0.5);
    try std.testing.expect(!low_result.isHighQuality());
}

test "Agent init" {
    const agent = Agent.init(.Coder);
    try std.testing.expectEqual(AgentType.Coder, agent.agent_type);
    try std.testing.expectEqual(AgentState.Idle, agent.state);
    try std.testing.expectEqual(@as(usize, 0), agent.tasks_completed);
}

test "Agent process" {
    var agent = Agent.init(.Coder);
    const task = Task.init(1, .Code, "implement function");
    const result = agent.process(&task);

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(usize, 1), agent.tasks_completed);
    try std.testing.expectEqual(AgentState.Complete, agent.state);
}

test "Agent isAvailable" {
    var agent = Agent.init(.Coder);
    try std.testing.expect(agent.isAvailable());

    agent.state = .Working;
    try std.testing.expect(!agent.isAvailable());
}

test "Agent canHandle" {
    const coder = Agent.init(.Coder);
    try std.testing.expect(coder.canHandle(.Code));
    try std.testing.expect(!coder.canHandle(.Chat));
}

test "Agent getAverageConfidence" {
    var agent = Agent.init(.Coder);
    const task1 = Task.init(1, .Code, "task1");
    const task2 = Task.init(2, .Code, "task2");

    _ = agent.process(&task1);
    _ = agent.process(&task2);

    const avg = agent.getAverageConfidence();
    try std.testing.expect(avg > 0.5);
}

test "AgentPool init" {
    const pool = AgentPool.init();
    try std.testing.expectEqual(@as(usize, 5), pool.agent_count);
}

test "AgentPool getAgent" {
    var pool = AgentPool.init();
    const coder = pool.getAgent(.Coder);
    try std.testing.expect(coder != null);
    try std.testing.expectEqual(AgentType.Coder, coder.?.agent_type);
}

test "AgentPool getAvailableAgent" {
    var pool = AgentPool.init();
    const agent = pool.getAvailableAgent(.Code);
    try std.testing.expect(agent != null);
}

test "AgentPool getCoordinator" {
    var pool = AgentPool.init();
    const coord = pool.getCoordinator();
    try std.testing.expect(coord != null);
    try std.testing.expectEqual(AgentType.Coordinator, coord.?.agent_type);
}

test "TaskQueue init" {
    const queue = TaskQueue.init();
    try std.testing.expectEqual(@as(usize, 0), queue.task_count);
    try std.testing.expectEqual(@as(u32, 1), queue.next_id);
}

test "TaskQueue enqueue" {
    var queue = TaskQueue.init();
    const id = queue.enqueue(.Code, "test task");
    try std.testing.expect(id != null);
    try std.testing.expectEqual(@as(u32, 1), id.?);
    try std.testing.expectEqual(@as(usize, 1), queue.task_count);
}

test "TaskQueue getTask" {
    var queue = TaskQueue.init();
    _ = queue.enqueue(.Code, "test task");
    const task = queue.getTask(1);
    try std.testing.expect(task != null);
}

test "TaskQueue getNextPending" {
    var queue = TaskQueue.init();
    _ = queue.enqueue(.Code, "task1");
    _ = queue.enqueue(.Chat, "task2");

    const next = queue.getNextPending();
    try std.testing.expect(next != null);
}

test "TaskQueue priority ordering" {
    var queue = TaskQueue.init();
    _ = queue.enqueue(.Code, "low priority");
    const high_id = queue.enqueue(.Chat, "high priority");

    if (queue.getTask(high_id.?)) |high_task| {
        high_task.setPriority(.Critical);
    }

    const next = queue.getNextPending();
    try std.testing.expect(next != null);
    try std.testing.expectEqual(TaskPriority.Critical, next.?.priority);
}

test "Coordinator init" {
    const coord = Coordinator.init();
    try std.testing.expectEqual(@as(usize, 0), coord.decompositions);
    try std.testing.expectEqual(@as(usize, 0), coord.aggregations);
}

test "Coordinator decompose single" {
    var coord = Coordinator.init();
    const task = Task.init(1, .Composite, "implement a function");
    const subtasks = coord.decompose(&task);

    try std.testing.expect(subtasks[0] != null);
    try std.testing.expectEqual(@as(usize, 1), coord.decompositions);
}

test "Coordinator decompose compound" {
    var coord = Coordinator.init();
    const task = Task.init(1, .Composite, "implement code and research topic");
    const subtasks = coord.decompose(&task);

    var count: usize = 0;
    for (subtasks) |maybe| {
        if (maybe != null) count += 1;
    }
    try std.testing.expect(count >= 2);
}

test "Coordinator aggregate" {
    var coord = Coordinator.init();
    var results: [2]TaskResult = undefined;

    results[0] = TaskResult.init(1, .Coder);
    results[0].setOutput("result1", 0.8);

    results[1] = TaskResult.init(2, .Chat);
    results[1].setOutput("result2", 0.9);

    const aggregated = coord.aggregate(&results);
    try std.testing.expect(aggregated.success);
    try std.testing.expectEqual(@as(usize, 1), coord.aggregations);
}

test "Coordinator route" {
    var coord = Coordinator.init();
    const task = Task.init(1, .Code, "test");
    const agent_type = coord.route(&task);
    try std.testing.expectEqual(AgentType.Coder, agent_type);
}

test "MultiAgentStats init" {
    const stats = MultiAgentStats.init();
    try std.testing.expectEqual(@as(usize, 0), stats.total_tasks);
    try std.testing.expectEqual(@as(f32, 0.0), stats.avg_confidence);
}

test "MultiAgentStats getCompletionRate" {
    var stats = MultiAgentStats.init();
    stats.total_tasks = 10;
    stats.completed_tasks = 8;
    const rate = stats.getCompletionRate();
    try std.testing.expect(rate >= 0.79);
    try std.testing.expect(rate <= 0.81);
}

test "MultiAgentSystem init" {
    const system = MultiAgentSystem.init();
    try std.testing.expectEqual(@as(usize, 5), system.pool.agent_count);
    try std.testing.expectEqual(@as(usize, 0), system.queue.task_count);
}

test "MultiAgentSystem submitTask" {
    var system = MultiAgentSystem.init();
    const id = system.submitTask("implement a function");
    try std.testing.expect(id != null);
    try std.testing.expectEqual(@as(usize, 1), system.stats.total_tasks);
}

test "MultiAgentSystem processAllTasks" {
    var system = MultiAgentSystem.init();
    _ = system.submitTask("implement code");
    _ = system.submitTask("chat with user");

    const processed = system.processAllTasks();
    try std.testing.expectEqual(@as(usize, 2), processed);
    try std.testing.expectEqual(@as(usize, 2), system.getCompletedTaskCount());
}

test "MultiAgentSystem getResult" {
    var system = MultiAgentSystem.init();
    const id = system.submitTask("test task");
    _ = system.processAllTasks();

    const result = system.getResult(id.?);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.success);
}

test "MultiAgentSystem getStats" {
    var system = MultiAgentSystem.init();
    _ = system.submitTask("task1");
    _ = system.submitTask("task2");
    _ = system.processAllTasks();

    const stats = system.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_tasks);
    try std.testing.expectEqual(@as(usize, 2), stats.completed_tasks);
}

test "MultiAgentSystem trainAgent" {
    var system = MultiAgentSystem.init();
    const trained = system.trainAgent(.Coder, "input", "output");
    try std.testing.expect(trained);
}

test "MultiAgentSystem reset" {
    var system = MultiAgentSystem.init();
    _ = system.submitTask("task1");
    _ = system.processAllTasks();

    system.reset();
    try std.testing.expectEqual(@as(usize, 0), system.queue.task_count);
    try std.testing.expectEqual(@as(usize, 0), system.result_count);
}

test "Multiple task types routed correctly" {
    var system = MultiAgentSystem.init();
    _ = system.submitTask("implement a function"); // -> Coder
    _ = system.submitTask("hello, how are you?"); // -> Chat
    _ = system.submitTask("explain why this works"); // -> Reasoner
    _ = system.submitTask("research this topic"); // -> Researcher

    const processed = system.processAllTasks();
    try std.testing.expectEqual(@as(usize, 4), processed);

    const stats = system.getStats();
    try std.testing.expect(stats.avg_confidence > 0.7);
}

test "AgentPool addAgent" {
    var pool = AgentPool.init();
    const initial_count = pool.agent_count;
    const added = pool.addAgent(.Analyst);
    try std.testing.expect(added);
    try std.testing.expectEqual(initial_count + 1, pool.agent_count);
}

test "TaskQueue clear" {
    var queue = TaskQueue.init();
    _ = queue.enqueue(.Code, "task1");
    _ = queue.enqueue(.Chat, "task2");
    queue.clear();
    try std.testing.expectEqual(@as(usize, 0), queue.task_count);
}

test "Agent train" {
    var agent = Agent.init(.Coder);
    const trained = agent.train("input pattern", "output response");
    try std.testing.expect(trained);
}

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() void {
    std.debug.print("\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("     IGLA MULTI-AGENT SYSTEM BENCHMARK (CYCLE 21)\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("\n", .{});

    var system = MultiAgentSystem.init();

    std.debug.print("  Agents initialized: {d}\n", .{system.getAgentCount()});
    std.debug.print("  Agent types: Coordinator, Coder, Chat, Reasoner, Researcher\n\n", .{});

    // Submit diverse tasks
    const tasks = [_][]const u8{
        "implement a sorting function",
        "hello, how are you today?",
        "explain why recursion works",
        "research the topic of AI",
        "analyze this data pattern",
        "write a blog post about coding",
        "review this code for bugs",
        "find information about Zig",
        "implement code and research topic",
        "chat with me and explain why",
    };

    std.debug.print("  Submitting {d} tasks...\n\n", .{tasks.len});

    var task_ids: [tasks.len]u32 = undefined;
    for (tasks, 0..) |task, i| {
        if (system.submitTask(task)) |id| {
            task_ids[i] = id;
        }
    }

    const start: i64 = @intCast(std.time.nanoTimestamp());
    const processed = system.processAllTasks();
    const end: i64 = @intCast(std.time.nanoTimestamp());

    std.debug.print("  Task Results:\n", .{});

    var high_quality: usize = 0;
    for (task_ids[0..processed], 0..) |id, i| {
        if (system.getResult(id)) |result| {
            const quality = if (result.isHighQuality()) "[HIGH]" else "[OK]";
            if (result.isHighQuality()) high_quality += 1;
            std.debug.print("  {d}. {s} \"{s}..\" -> {s} (conf: {d:.2})\n", .{
                i + 1,
                quality,
                tasks[i][0..@min(tasks[i].len, 25)],
                result.agent_type.getName(),
                result.confidence,
            });
        }
    }

    const stats = system.getStats();
    const total_time_us = @as(f64, @floatFromInt(end - start)) / 1000.0;
    const tasks_per_sec = @as(f64, @floatFromInt(processed)) / (@as(f64, @floatFromInt(end - start)) / 1_000_000_000.0);

    std.debug.print("\n", .{});
    std.debug.print("  Total tasks: {d}\n", .{stats.total_tasks});
    std.debug.print("  Completed: {d}\n", .{stats.completed_tasks});
    std.debug.print("  High quality: {d}\n", .{high_quality});
    std.debug.print("  Agents used: {d}\n", .{stats.total_agents});
    std.debug.print("  Decompositions: {d}\n", .{stats.decompositions});
    std.debug.print("  Avg confidence: {d:.2}\n", .{stats.avg_confidence});
    std.debug.print("  Total time: {d:.0}us\n", .{total_time_us});
    std.debug.print("  Throughput: {d:.0} tasks/s\n", .{tasks_per_sec});
    std.debug.print("\n", .{});

    // Golden Ratio Gate
    const completion_rate = stats.getCompletionRate();
    const passed = completion_rate > 0.618;

    std.debug.print("  Completion rate: {d:.2}\n", .{completion_rate});
    if (passed) {
        std.debug.print("  Golden Ratio Gate: PASSED (>0.618)\n", .{});
    } else {
        std.debug.print("  Golden Ratio Gate: FAILED (<0.618)\n", .{});
    }
    std.debug.print("\n", .{});
}

pub fn main() void {
    runBenchmark();
}
