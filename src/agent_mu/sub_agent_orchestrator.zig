//! AGENT MU v8.26 - Sub-Agent Orchestrator
//!
//! Manages up to 200 parallel sub-agents for complex tasks
//! Uses consensus mechanism to merge results

const std = @import("std");
const mcp_nexus = @import("mcp_nexus.zig");

/// Sub-Agent Task
pub const SubAgentTask = struct {
    id: []const u8,
    description: []const u8,
    agent_type: AgentType,
    model: mcp_nexus.ModelType,
    timeout_ms: u64,
    status: TaskStatus,

    pub fn deinit(self: *const SubAgentTask, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.description);
    }
};

pub const AgentType = enum {
    general_purpose, // General-purpose agent
    explorer,        // Fast codebase exploration
    planner,         // Implementation planning
    coder,           // Code writing and editing
    reviewer,        // Code review
    tester,          // Test generation
    debugger,        // Debugging
    analyzer,        // Code analysis
    optimizer,       // Performance optimization
    documenter,      // Documentation
};

pub const TaskStatus = enum {
    pending,
    running,
    completed,
    failed,
    timeout,
};

/// Sub-Agent Result
pub const SubAgentResult = struct {
    task_id: []const u8,
    success: bool,
    output: []const u8,
    confidence: f64,
    execution_time_ms: u64,

    pub fn deinit(self: *const SubAgentResult, allocator: std.mem.Allocator) void {
        allocator.free(self.task_id);
        allocator.free(self.output);
    }
};

/// Orchestrator for managing sub-agents
pub const SubAgentOrchestrator = struct {
    allocator: std.mem.Allocator,
    max_agents: u32,
    active_tasks: std.StringHashMap(*SubAgentTask),
    completed_results: std.ArrayList(SubAgentResult),
    nexus: *mcp_nexus.McpNexus,

    pub fn init(allocator: std.mem.Allocator, max_agents: u32, nexus: *mcp_nexus.McpNexus) SubAgentOrchestrator {
        return SubAgentOrchestrator{
            .allocator = allocator,
            .max_agents = max_agents,
            .active_tasks = std.StringHashMap(*SubAgentTask).init(allocator),
            .completed_results = std.ArrayListUnmanaged(SubAgentResult){},
            .nexus = nexus,
        };
    }

    pub fn deinit(self: *SubAgentOrchestrator) void {
        var it = self.active_tasks.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.active_tasks.deinit();

        for (self.completed_results.items) |*result| {
            result.deinit(self.allocator);
        }
        self.completed_results.deinit(self.allocator);
    }

    /// Spawn multiple sub-agents for parallel processing
    pub fn spawnParallel(self: *SubAgentOrchestrator, tasks: []const SubAgentTask) !void {
        if (tasks.len > self.max_agents) {
            return error.TooManyTasks;
        }

        for (tasks) |task| {
            const task_copy = try self.allocator.create(SubAgentTask);
            task_copy.* = SubAgentTask{
                .id = try self.allocator.dupe(u8, task.id),
                .description = try self.allocator.dupe(u8, task.description),
                .agent_type = task.agent_type,
                .model = task.model,
                .timeout_ms = task.timeout_ms,
                .status = .pending,
            };

            try self.active_tasks.put(task_copy.id, task_copy);
        }
    }

    /// Execute all pending tasks
    pub fn executeAll(self: *SubAgentOrchestrator) !void {
        var it = self.active_tasks.iterator();
        while (it.next()) |entry| {
            const task = entry.value_ptr.*;

            task.status = .running;

            // In production, this would call the actual MCP agent_spawn
            // For now, we simulate execution
            const result = SubAgentResult{
                .task_id = try self.allocator.dupe(u8, task.id),
                .success = true,
                .output = try std.fmt.allocPrint(self.allocator,
                    "Simulated result for task: {s}",
                    .{task.description}),
                .confidence = 0.8,
                .execution_time_ms = 100,
            };

            try self.completed_results.append(self.allocator, result);
            task.status = .completed;
        }
    }

    /// Get all results
    pub fn getResults(self: *const SubAgentOrchestrator) []const SubAgentResult {
        return self.completed_results.items;
    }

    /// Apply φ-consensus to get best result
    pub fn getConsensusResult(self: *SubAgentOrchestrator) !SubAgentResult {
        if (self.completed_results.items.len == 0) {
            return error.NoResults;
        }

        var best_idx: usize = 0;
        var best_score: f64 = 0.0;

        for (self.completed_results.items, 0..) |result, i| {
            if (!result.success) continue;

            const score = result.confidence * mcp_nexus.PHI;
            if (score > best_score) {
                best_score = score;
                best_idx = i;
            }
        }

        // Clone the best result
        const best = self.completed_results.items[best_idx];
        return SubAgentResult{
            .task_id = try self.allocator.dupe(u8, best.task_id),
            .success = best.success,
            .output = try self.allocator.dupe(u8, best.output),
            .confidence = best.confidence,
            .execution_time_ms = best.execution_time_ms,
        };
    }

    /// Get statistics
    pub fn getStats(self: *const SubAgentOrchestrator) struct {
        total: u32,
        completed: u32,
        failed: u32,
        pending: u32,
        running: u32,
    } {
        var completed: u32 = 0;
        var failed: u32 = 0;
        var pending: u32 = 0;
        var running: u32 = 0;

        var it = self.active_tasks.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*.status) {
                .pending => pending += 1,
                .running => running += 1,
                .completed => completed += 1,
                .failed, .timeout => failed += 1,
            }
        }

        return .{
            .total = @intCast(self.active_tasks.count()),
            .completed = completed,
            .failed = failed,
            .pending = pending,
            .running = running,
        };
    }
};

/// Agent Type Router - selects best agent type for task
pub fn routeAgentType(task_description: []const u8) AgentType {
    const desc = task_description;

    // Case-insensitive search for keywords
    if (indexOfIgnoreCase(desc, "test")) return .tester;
    if (indexOfIgnoreCase(desc, "debug")) return .debugger;
    if (indexOfIgnoreCase(desc, "review")) return .reviewer;
    if (indexOfIgnoreCase(desc, "document")) return .documenter;
    if (indexOfIgnoreCase(desc, "optimize")) return .optimizer;
    if (indexOfIgnoreCase(desc, "analyze")) return .analyzer;
    if (indexOfIgnoreCase(desc, "explore")) return .explorer;
    if (indexOfIgnoreCase(desc, "plan")) return .planner;
    if (indexOfIgnoreCase(desc, "write") or
        indexOfIgnoreCase(desc, "implement")) return .coder;

    return .general_purpose;
}

/// Helper for case-insensitive substring search
fn indexOfIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    const max_start = haystack.len - needle.len;
    var i: usize = 0;

    while (i <= max_start) : (i += 1) {
        const slice = haystack[i..];
        if (slice.len < needle.len) break;

        var match = true;
        for (needle, 0..) |c_n, j| {
            const c_h = slice[j];
            if (std.ascii.toLower(c_h) != std.ascii.toLower(c_n)) {
                match = false;
                break;
            }
        }

        if (match) return true;
    }

    return false;
}

test "Sub-Agent Orchestrator - spawn and execute" {
    const allocator = std.testing.allocator;
    var nexus = mcp_nexus.McpNexus.init(allocator);
    var orchestrator = SubAgentOrchestrator.init(allocator, 10, &nexus);
    defer orchestrator.deinit();

    const tasks = [_]SubAgentTask{
        .{
            .id = "task1",
            .description = "Analyze code",
            .agent_type = .analyzer,
            .model = .haiku,
            .timeout_ms = 1000,
            .status = .pending,
        },
        .{
            .id = "task2",
            .description = "Write test",
            .agent_type = .tester,
            .model = .haiku,
            .timeout_ms = 1000,
            .status = .pending,
        },
    };

    try orchestrator.spawnParallel(&tasks);
    try orchestrator.executeAll();

    const results = orchestrator.getResults();
    try std.testing.expectEqual(@as(usize, 2), results.len);
}

test "Agent Type Router" {
    try std.testing.expectEqual(AgentType.tester, routeAgentType("Write tests for module"));
    try std.testing.expectEqual(AgentType.debugger, routeAgentType("Debug this error"));
    try std.testing.expectEqual(AgentType.reviewer, routeAgentType("Review this code"));
    try std.testing.expectEqual(AgentType.general_purpose, routeAgentType("Do something"));
}
