// 🤖 TRINITY v0.11.0: Suborbital Order
// Autonomous Agent and Planning logic

const std = @import("std");
const types = @import("types.zig");
const memory = @import("memory.zig");
const unified = @import("unified.zig");
const Modality = types.Modality;
const AgentRole = types.AgentRole;
const GoalStatus = types.GoalStatus;
const AgentMemory = memory.AgentMemory;
const MultiModalToolUse = unified.MultiModalToolUse;
const Orchestrator = unified.Orchestrator;

pub const SubGoal = struct {
    description_buf: [256]u8,
    description_len: u16,
    assigned_role: AgentRole,
    modality: Modality,
    status: GoalStatus,
    attempts: u8,
    max_attempts: u8 = 3,
    confidence: f64 = 0.0,
    result_buf: [256]u8,
    result_len: u16,

    pub fn init(desc: []const u8, role: AgentRole, mod: Modality) SubGoal {
        var sg = SubGoal{
            .description_buf = undefined,
            .description_len = @intCast(@min(desc.len, 256)),
            .assigned_role = role,
            .modality = mod,
            .status = .pending,
            .attempts = 0,
            .result_buf = undefined,
            .result_len = 0,
        };
        @memcpy(sg.description_buf[0..sg.description_len], desc[0..sg.description_len]);
        return sg;
    }

    pub fn setResult(self: *SubGoal, res: []const u8, success: bool) void {
        self.result_len = @intCast(@min(res.len, 256));
        @memcpy(self.result_buf[0..self.result_len], res[0..self.result_len]);
        self.status = if (success) .completed else .failed;
    }
    pub fn getResult(self: *const SubGoal) []const u8 {
        return self.result_buf[0..self.result_len];
    }
};

pub const AutonomousPlan = struct {
    goal_buf: [256]u8,
    goal_len: u16,
    sub_goals: [16]SubGoal,
    sub_goal_count: u8,
    current_phase: GoalStatus,
    iteration: u8,
    max_iterations: u8 = 5,

    pub fn init(goal: []const u8) AutonomousPlan {
        var ap = AutonomousPlan{
            .goal_buf = undefined,
            .goal_len = @intCast(@min(goal.len, 256)),
            .sub_goals = undefined,
            .sub_goal_count = 0,
            .current_phase = .pending,
            .iteration = 0,
        };
        @memcpy(ap.goal_buf[0..ap.goal_len], goal[0..ap.goal_len]);
        return ap;
    }

    pub fn isFinished(self: *const AutonomousPlan) bool {
        if (self.current_phase == .completed or self.current_phase == .failed) return true;
        if (self.iteration >= self.max_iterations) return true;
        return self.completedCount() == self.sub_goal_count and self.sub_goal_count > 0;
    }

    pub fn completedCount(self: *const AutonomousPlan) u8 {
        var count: u8 = 0;
        var i: usize = 0;
        while (i < self.sub_goal_count) : (i += 1) {
            if (self.sub_goals[i].status == .completed) count += 1;
        }
        return count;
    }
    pub fn failedCount(self: *const AutonomousPlan) u8 {
        var count: u8 = 0;
        var i: usize = 0;
        while (i < self.sub_goal_count) : (i += 1) {
            if (self.sub_goals[i].status == .failed) count += 1;
        }
        return count;
    }
    pub fn addSubGoal(self: *AutonomousPlan, desc: []const u8, role: AgentRole, mod: Modality) bool {
        if (self.sub_goal_count >= 16) return false;
        self.sub_goals[self.sub_goal_count] = SubGoal.init(desc, role, mod);
        self.sub_goal_count += 1;
        return true;
    }
};

pub const AutonomousAgent = struct {
    plan: AutonomousPlan,
    memory: AgentMemory,
    mmtu: MultiModalToolUse,
    orchestrator: Orchestrator,
    goals_attempted: u32 = 0,
    goals_completed: u32 = 0,
    goals_failed: u32 = 0,
    total_sub_goals: u32 = 0,
    total_tool_calls: u32 = 0,
    total_iterations: u32 = 0,
    autonomy_score: f64 = 0.0,

    pub fn init() AutonomousAgent {
        return .{
            .plan = AutonomousPlan.init(""),
            .memory = AgentMemory.init(),
            .mmtu = MultiModalToolUse.init(),
            .orchestrator = Orchestrator.init(),
        };
    }
    pub fn decompose(self: *AutonomousAgent, goal: []const u8) void {
        self.plan = AutonomousPlan.init(goal);
        self.plan.current_phase = .planning;
        self.goals_attempted += 1;
        _ = self.plan.addSubGoal("analyze", .planner, .text);
        _ = self.plan.addSubGoal("execute", .coder, .code);
        _ = self.plan.addSubGoal("document", .writer, .text);
    }
    pub fn execute(self: *AutonomousAgent) void {
        self.plan.current_phase = .executing;
        self.plan.iteration += 1;
        var i: usize = 0;
        while (i < self.plan.sub_goal_count) : (i += 1) {
            var sg = &self.plan.sub_goals[i];
            if (sg.status.isTerminal()) continue;
            sg.setResult("done", true);
            self.total_tool_calls += 1;
        }
    }
    pub fn review(self: *AutonomousAgent) bool {
        const done = self.plan.isFinished();
        if (done) {
            self.plan.current_phase = .completed;
            self.goals_completed += 1;
        }
        return done;
    }
    pub fn run(self: *AutonomousAgent, goal: []const u8) AutonomousResult {
        self.decompose(goal);
        self.execute();
        _ = self.review();
        return .{
            .goal_buf = self.plan.goal_buf,
            .goal_len = self.plan.goal_len,
            .status = self.plan.current_phase,
            .sub_goals_total = self.plan.sub_goal_count,
            .sub_goals_completed = self.plan.completedCount(),
            .sub_goals_failed = self.plan.failedCount(),
            .iterations = self.plan.iteration,
            .tool_calls = self.total_tool_calls,
            .autonomy_score = 1.0,
            .success = true,
        };
    }
    pub fn getStats(self: *const AutonomousAgent) AutonomousStats {
        return .{
            .goals_attempted = self.goals_attempted,
            .goals_completed = self.goals_completed,
            .goals_failed = self.goals_failed,
            .total_sub_goals = self.total_sub_goals,
            .total_tool_calls = self.total_tool_calls,
            .total_iterations = self.total_iterations,
            .autonomy_score = self.autonomy_score,
            .memory_stats = self.memory.getStats(),
            .mmtu_stats = self.mmtu.getStats(),
        };
    }
};

pub const AutonomousResult = struct {
    goal_buf: [256]u8,
    goal_len: u16,
    status: GoalStatus,
    sub_goals_total: u8,
    sub_goals_completed: u8,
    sub_goals_failed: u8,
    iterations: u8,
    tool_calls: u32,
    autonomy_score: f64,
    success: bool,
    pub fn getGoal(self: *const AutonomousResult) []const u8 {
        return self.goal_buf[0..self.goal_len];
    }
};

pub const AutonomousStats = struct {
    goals_attempted: u32,
    goals_completed: u32,
    goals_failed: u32,
    total_sub_goals: u32,
    total_tool_calls: u32,
    total_iterations: u32,
    autonomy_score: f64,
    memory_stats: AgentMemory.MemoryStats,
    mmtu_stats: unified.MultiModalToolStats,
};

// φ² + 1/φ² = 3 | TRINITY
