//! Ralph Agent - Main API for Autonomous Development
//! Integrates all components into a complete autonomous development system

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const core = @import("core.zig");
const quality = @import("quality.zig");
const git_mod = @import("git.zig");
const telegram_mod = @import("telegram.zig");
const memory_mod = @import("memory.zig");

pub const RalphAgent = struct {
    allocator: Allocator,
    config: RalphConfig,
    session: Session,
    memory: ?memory_mod.MemoryStore,
    telegram: telegram_mod.TelegramConfig,

    /// Initialize a new Ralph agent
    pub fn init(allocator: Allocator, config: RalphConfig) !RalphAgent {
        var session = try Session.init(allocator);
        errdefer session.deinit(allocator);

        const memory = if (config.enable_memory)
            try memory_mod.init(allocator, config.ralph_path)
        else
            null;

        const telegram_config = telegram_mod.TelegramConfig{
            .enabled = config.telegram_enabled,
            .chat_id = config.telegram_chat_id,
            .openclaw_bin = config.openclaw_bin,
        };

        return RalphAgent{
            .allocator = allocator,
            .config = config,
            .session = session,
            .memory = memory,
            .telegram = telegram_config,
        };
    }

    /// Cleanup agent resources
    pub fn deinit(self: *RalphAgent) void {
        self.session.deinit(self.allocator);
        if (self.memory) |*mem| {
            mem.deinit(self.allocator);
        }
    }

    /// Run one complete development cycle (Golden Chain)
    pub fn runOneCycle(self: *RalphAgent) !CycleResult {
        var cycle_result = CycleResult{
            .success = false,
            .link_completed = .none,
            .error_message = &.{},
            .files_modified = 0,
        };

        // Notify cycle start
        {
            const ctx = telegram_mod.EventContext{
                .branch = self.session.current_branch,
                .sha = self.session.last_commit_sha,
                .loop_number = @intCast(self.session.loop_count),
            };
            try telegram_mod.send(self.allocator, self.telegram, .loop_start, ctx);
        }

        // Link 1: TRI DECOMPOSE
        const tasks = core.triDecompose(self.allocator, self.config.fix_plan_path) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Decompose failed: {}", .{err});
            try self.handleCycleError(.decompose, cycle_result.error_message);
            return cycle_result;
        };

        // Select highest priority task
        if (tasks.len == 0) {
            cycle_result.error_message = "No tasks found in fix_plan.md";
            try self.handleCycleError(.decompose, cycle_result.error_message);
            return cycle_result;
        }

        const task = tasks[0];
        self.session.current_task_id = task.id;

        // Link 2: TRI PLAN
        _ = core.triPlan(self.allocator, self.config.tech_tree_path) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Plan failed: {}", .{err});
            try self.handleCycleError(.plan, cycle_result.error_message);
            return cycle_result;
        };

        // Link 3: TRI SPEC CREATE
        const spec_path = core.triSpecCreate(self.allocator, task) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Spec create failed: {}", .{err});
            try self.handleCycleError(.spec_create, cycle_result.error_message);
            return cycle_result;
        };

        // Consult memory if enabled
        if (self.memory) |*mem| {
            if (memory_mod.consult(mem.*, self.allocator, task.description)) |cr| {
                defer {
                    self.allocator.free(cr.keywords);
                    for (cr.success) |*s| {
                        self.allocator.free(s.pattern);
                        self.allocator.free(s.context);
                    }
                    self.allocator.free(cr.success);
                    for (cr.regression) |*r| {
                        self.allocator.free(r.pattern);
                        self.allocator.free(r.context);
                    }
                    self.allocator.free(cr.regression);
                }

                self.session.history_consulted = true;
                self.session.patterns_found = cr.success.len + cr.regression.len;
            } else |_| {
                self.session.history_consulted = false;
                self.session.patterns_found = 0;
            }
        }

        // Link 4: TRI GEN
        core.triGen(self.allocator, spec_path) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Gen failed: {}", .{err});
            try self.handleCycleError(.gen, cycle_result.error_message);
            return cycle_result;
        };

        // Link 5: TRI TEST
        const test_result = core.triTest(self.allocator) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Test failed: {}", .{err});
            try self.handleCycleError(.@"test", cycle_result.error_message);
            return cycle_result;
        };

        // Link 6: TRI BENCH
        const bench_result = core.triBench(self.allocator, self.config.benchmark_baseline) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Bench failed: {}", .{err});
            try self.handleCycleError(.bench, cycle_result.error_message);
            return cycle_result;
        };

        // Link 7: TRI VERDICT
        const verdict = core.triVerdict(self.allocator, test_result, bench_result) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Verdict failed: {}", .{err});
            try self.handleCycleError(.verdict, cycle_result.error_message);
            return cycle_result;
        };

        self.session.last_verdict_score = verdict.score;

        // Check if verdict is good enough
        if (verdict.score < 7) {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Verdict score too low: {d}/10", .{verdict.score});
            try self.handleCycleError(.verdict, cycle_result.error_message);
            return cycle_result;
        }

        // Link 8: TRI GIT
        const commit_msg = try self.formatCommitMessage(task, verdict);
        const git_result = core.triGit(self.allocator, commit_msg) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Git failed: {}", .{err});
            try self.handleCycleError(.git, cycle_result.error_message);
            return cycle_result;
        };

        if (!git_result.success) {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Git gates failed: {s}", .{
                git_result.failed_gate orelse "unknown",
            });
            try self.handleCycleError(.git, cycle_result.error_message);
            return cycle_result;
        }

        self.session.last_commit_sha = git_result.sha;

        // Notify commit
        {
            const ctx = telegram_mod.EventContext{
                .branch = self.session.current_branch,
                .sha = git_result.sha,
                .commit_message = commit_msg,
            };
            try telegram_mod.send(self.allocator, self.telegram, .commit, ctx);
        }

        // Link 9: TRI LOOP
        _ = core.triLoop(self.allocator, &self.session.session, true) catch |err| {
            cycle_result.error_message = try std.fmt.allocPrint(self.allocator, "Loop failed: {}", .{err});
            try self.handleCycleError(.loop, cycle_result.error_message);
            return cycle_result;
        };

        self.session.loop_count += 1;

        // Notify cycle end
        {
            const ctx = telegram_mod.EventContext{
                .branch = self.session.current_branch,
                .sha = git_result.sha,
            };
            try telegram_mod.send(self.allocator, self.telegram, .loop_end, ctx);
        }

        cycle_result.success = true;
        cycle_result.link_completed = .git;
        cycle_result.files_modified = 1;

        return cycle_result;
    }

    /// Run cycles until completion or halt
    pub fn runUntilComplete(self: *RalphAgent) !AgentSummary {
        var summary = AgentSummary{
            .total_cycles = 0,
            .successful_cycles = 0,
            .failed_cycles = 0,
            .total_files_modified = 0,
            .exit_reason = "Complete",
        };

        while (summary.total_cycles < self.config.max_loops_per_session) {
            const result = try self.runOneCycle();

            if (result.success) {
                summary.successful_cycles += 1;
                summary.total_files_modified += result.files_modified;

                if (try core.evaluateExit(self.allocator, self.session.session)) {
                    summary.exit_reason = "Exit criteria met";
                    break;
                }
            } else {
                summary.failed_cycles += 1;

                if (self.session.session.circuit_breaker == .open) {
                    summary.exit_reason = "Circuit breaker opened";
                    break;
                }

                if (result.link_completed == .loop) {
                    const decision = try core.triLoop(self.allocator, &self.session.session, false);
                    if (decision.action == .halt) {
                        summary.exit_reason = "Halted - no progress";
                        break;
                    }
                }
            }

            summary.total_cycles += 1;
        }

        return summary;
    }

    /// Get current status as RALPH_STATUS block
    pub fn getStatus(self: *const RalphAgent, allocator: Allocator) ![]const u8 {
        const status = if (self.session.session.no_progress_count == 0)
            "IN_PROGRESS"
        else if (self.session.session.circuit_breaker == .open)
            "BLOCKED"
        else
            "COMPLETE";

        return std.fmt.allocPrint(allocator,
            \\---RALPH_STATUS---
            \\STATUS: {s}
            \\BRANCH: {s}
            \\TASKS_COMPLETED_THIS_LOOP: {d}
            \\FILES_MODIFIED: {d}
            \\LOOP_COUNT: {d}
            \\HISTORY_CONSULTED: {s}
            \\PATTERNS_FOUND: {d}
            \\LAST_VERDICT: {d}/10
            \\CIRCUIT_BREAKER: {s}
            \\---END_RALPH_STATUS---
        , .{
            status,
            self.session.current_branch,
            self.session.completed_tasks,
            self.session.files_modified,
            self.session.loop_count,
            if (self.session.history_consulted) "true" else "false",
            self.session.patterns_found,
            self.session.last_verdict_score,
            @tagName(self.session.session.circuit_breaker),
        });
    }

    fn formatCommitMessage(self: *const RalphAgent, task: types.TaskEntry, verdict: core.ToxicVerdict) ![]const u8 {
        return std.fmt.allocPrint(self.allocator,
            \\feat({s}): {s} -- Score {d}/10
        , .{
            self.config.commit_scope,
            task.description,
            verdict.score,
        });
    }

    fn handleCycleError(self: *RalphAgent, link: types.GoldenChainLink, message: []const u8) !void {
        _ = link;

        const ctx = telegram_mod.EventContext{
            .branch = self.session.current_branch,
            .sha = self.session.last_commit_sha,
            .gate_name = message,
        };

        try telegram_mod.send(self.allocator, self.telegram, .gate_fail, ctx);
    }
};

pub const RalphConfig = struct {
    ralph_path: []const u8 = ".ralph",
    fix_plan_path: []const u8 = ".ralph/fix_plan.md",
    tech_tree_path: []const u8 = ".ralph/TECH_TREE.md",
    benchmark_baseline: []const u8 = ".ralph/internal/.benchmark_baseline",
    max_loops_per_session: u64 = 100,
    circuit_breaker_threshold: u32 = 3,
    enable_memory: bool = true,
    telegram_enabled: bool = true,
    telegram_chat_id: []const u8 = "144022504",
    openclaw_bin: []const u8 = "node /Users/playra/openclaw/openclaw.mjs",
    commit_scope: []const u8 = "ralph",
};

pub const Session = struct {
    session: types.SessionState,
    current_task_id: []const u8,
    completed_tasks: u32,
    files_modified: u32,
    loop_count: u64,
    last_verdict_score: i64,
    history_consulted: bool,
    patterns_found: usize,
    current_branch: []const u8,
    last_commit_sha: []const u8,

    pub fn init(allocator: Allocator) !Session {
        const branch = git_mod.getCurrentBranch(allocator) catch "unknown";
        const sha = git_mod.getShortSha(allocator) catch "??????";

        return Session{
            .session = types.SessionState{
                .session_id = "ralph-session",
                .call_count = 0,
                .loop_count = 0,
                .loop_start_sha = sha,
                .current_branch = branch,
                .current_link = .decompose,
                .circuit_breaker = .closed,
                .no_progress_count = 0,
                .last_commit_sha = sha,
            },
            .current_task_id = "",
            .completed_tasks = 0,
            .files_modified = 0,
            .loop_count = 0,
            .last_verdict_score = 0,
            .history_consulted = false,
            .patterns_found = 0,
            .current_branch = branch,
            .last_commit_sha = sha,
        };
    }

    pub fn deinit(self: *Session, allocator: Allocator) void {
        // Free allocated strings from git functions
        // Note: Only free if not a static literal ("unknown" or "??????")
        if (self.current_branch.len > 0 and self.current_branch.ptr[0] != 0) {
            // Check if it's dynamically allocated (heuristic: longer than static literals)
            if (self.current_branch.len > 10) {
                allocator.free(self.current_branch);
            }
        }
        if (self.last_commit_sha.len > 0 and self.last_commit_sha.ptr[0] != 0) {
            if (self.last_commit_sha.len > 6) {
                allocator.free(self.last_commit_sha);
            }
        }
    }
};

pub const CycleResult = struct {
    success: bool,
    link_completed: types.GoldenChainLink,
    error_message: []const u8,
    files_modified: u32,
};

pub const AgentSummary = struct {
    total_cycles: u32,
    successful_cycles: u32,
    failed_cycles: u32,
    total_files_modified: u32,
    exit_reason: []const u8,
};

// ============================================================================
// Tests
// ============================================================================

test "agent: session init" {
    const allocator = std.testing.allocator;

    var session = try Session.init(allocator);
    defer session.deinit(allocator);

    try std.testing.expect(session.loop_count == 0);
    try std.testing.expect(session.session.circuit_breaker == .closed);
}
