//! Ralph Type Definitions
//! Centralized types for autonomous development system

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Enums
// ============================================================================

pub const CircuitBreakerState = enum {
    closed,
    half_open,
    open,
};

pub const TaskPriority = enum {
    p0_critical,
    p1_high,
    p2_medium,
    p3_low,
};

pub const WorkType = enum {
    implementation,
    testing,
    documentation,
    refactoring,
    benchmarking,
};

pub const VerdictStatus = enum {
    prod,
    fail,
};

/// Task status enum - replaces string status fields
pub const TaskStatus = enum {
    pending,
    in_progress,
    complete,
    blocked,

    /// Convert from string representation
    pub fn fromString(s: []const u8) !TaskStatus {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "in_progress")) return .in_progress;
        if (std.mem.eql(u8, s, "complete")) return .complete;
        if (std.mem.eql(u8, s, "blocked")) return .blocked;
        return error.InvalidStatus;
    }

    /// Convert to string representation
    pub fn toString(self: TaskStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .in_progress => "in_progress",
            .complete => "complete",
            .blocked => "blocked",
        };
    }
};

/// Tech tree node status enum
pub const NodeStatus = enum {
    available,
    in_progress,
    completed,
    locked,

    /// Convert from string representation
    pub fn fromString(s: []const u8) !NodeStatus {
        if (std.mem.eql(u8, s, "available")) return .available;
        if (std.mem.eql(u8, s, "in_progress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "locked")) return .locked;
        return error.InvalidStatus;
    }

    /// Convert to string representation
    pub fn toString(self: NodeStatus) []const u8 {
        return switch (self) {
            .available => "available",
            .in_progress => "in_progress",
            .completed => "completed",
            .locked => "locked",
        };
    }
};

/// Tech tree branch category
pub const BranchType = enum {
    core,           // Core infrastructure
    compiler,       // VIBEE compiler
    runtime,        // Runtime execution
    memory,         // Memory management
    quality,        // Quality gates
    observability,  // Metrics/monitoring

    /// Convert from string representation
    pub fn fromString(s: []const u8) !BranchType {
        if (std.mem.eql(u8, s, "core")) return .core;
        if (std.mem.eql(u8, s, "compiler")) return .compiler;
        if (std.mem.eql(u8, s, "runtime")) return .runtime;
        if (std.mem.eql(u8, s, "memory")) return .memory;
        if (std.mem.eql(u8, s, "quality")) return .quality;
        if (std.mem.eql(u8, s, "observability")) return .observability;
        return error.InvalidBranch;
    }

    /// Convert to string representation
    pub fn toString(self: BranchType) []const u8 {
        return switch (self) {
            .core => "core",
            .compiler => "compiler",
            .runtime => "runtime",
            .memory => "memory",
            .quality => "quality",
            .observability => "observability",
        };
    }
};

pub const LoopAction = enum {
    @"continue",
    complete,
    halt,
    escalate,
};

pub const GoldenChainLink = enum {
    none,
    decompose,
    plan,
    spec_create,
    gen,
    @"test",
    bench,
    verdict,
    git,
    loop,
};

// ============================================================================
// Structs
// ============================================================================

/// Subtask entry within a task
pub const Subtask = struct {
    description: []const u8,
    checked: bool,

    pub fn deinit(self: *Subtask, allocator: Allocator) void {
        allocator.free(self.description);
    }
};

/// Acceptance criterion for a task
pub const AcceptanceCriterion = struct {
    description: []const u8,

    pub fn deinit(self: *AcceptanceCriterion, allocator: Allocator) void {
        allocator.free(self.description);
    }
};

/// Task entry from fix_plan.md
pub const TaskEntry = struct {
    id: []const u8,
    description: []const u8,
    priority: TaskPriority,
    status: TaskStatus,
    tech_tree_node: []const u8,
    subtasks: []Subtask,
    blocker_reason: []const u8,
    acceptance_criteria: []AcceptanceCriterion,

    /// Free all allocated memory
    pub fn deinit(self: *TaskEntry, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.description);
        allocator.free(self.tech_tree_node);
        allocator.free(self.blocker_reason);

        for (self.subtasks) |*s| s.deinit(allocator);
        allocator.free(self.subtasks);

        for (self.acceptance_criteria) |*c| c.deinit(allocator);
        allocator.free(self.acceptance_criteria);
    }
};

/// Tech tree node from TECH_TREE.md
pub const TechTreeNode = struct {
    id: []const u8,
    name: []const u8,
    branch: BranchType,
    impact: f64,
    complexity: f64,
    unlock_count: i64,
    status: NodeStatus,
    dependencies: [][]const u8,

    /// Free all allocated memory
    pub fn deinit(self: *TechTreeNode, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);

        for (self.dependencies) |dep| {
            allocator.free(dep);
        }
        allocator.free(self.dependencies);
    }
};

/// Session state for tracking Ralph progress
pub const SessionState = struct {
    session_id: []const u8,
    call_count: i64,
    loop_count: i64,
    loop_start_sha: []const u8,
    current_branch: []const u8,
    current_link: GoldenChainLink,
    circuit_breaker: CircuitBreakerState,
    no_progress_count: i64,
    last_commit_sha: []const u8,

    /// Free all allocated memory
    pub fn deinit(self: *SessionState, allocator: Allocator) void {
        allocator.free(self.session_id);
        allocator.free(self.loop_start_sha);
        allocator.free(self.current_branch);
        allocator.free(self.last_commit_sha);
    }
};

/// Quality gate result
pub const GateResult = enum {
    pass,
    fail,
};

/// Collection of quality gate results
pub const QualityGates = struct {
    build: GateResult,
    @"test": GateResult,
    format: GateResult,
    branch_valid: GateResult,

    pub fn allPassed(self: QualityGates) bool {
        return self.build == .pass and
            self.@"test" == .pass and
            self.format == .pass and
            self.branch_valid == .pass;
    }

    pub fn getFailedGate(self: QualityGates) ?[]const u8 {
        if (self.build == .fail) return "build";
        if (self.@"test" == .fail) return "test";
        if (self.format == .fail) return "format";
        if (self.branch_valid == .fail) return "branch";
        return null;
    }
};

/// Toxic verdict result
pub const ToxicVerdict = struct {
    score: i64,
    status: VerdictStatus,
    flaws: [][]const u8,
    assessment: []const u8,
    recommendation: []const u8,

    /// Free all allocated memory
    pub fn deinit(self: *ToxicVerdict, allocator: Allocator) void {
        for (self.flaws) |flaw| {
            allocator.free(flaw);
        }
        allocator.free(self.flaws);
        allocator.free(self.assessment);
        allocator.free(self.recommendation);
    }
};

/// Ralph agent configuration
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

// ============================================================================
// Legacy Types (for backward compatibility)
// ============================================================================

/// Memory store placeholder (actual implementation in memory.zig)
pub const MemoryStore = struct {
    success_patterns: []const u8,
    regression_patterns: []const u8,
    benchmark_baseline: []const u8,
};

/// Ralph status summary
pub const RalphStatus = struct {
    status: []const u8,
    branch: []const u8,
    tasks_completed: i64,
    files_modified: i64,
    gates: QualityGates,
    history_consulted: bool,
    patterns_found: i64,
    tech_tree_node: []const u8,
    tech_tree_updated: bool,
    work_type: WorkType,
    exit_signal: bool,
    recommendation: []const u8,
};

/// Ralph agent (legacy)
pub const RalphAgent = struct {
    config: RalphConfig,
    session: SessionState,
    memory: MemoryStore,
    current_task: TaskEntry,
    gates: QualityGates,
    last_verdict: ToxicVerdict,
    tech_tree: []const u8,
};

// ============================================================================
// Tests
// ============================================================================

test "types: TaskStatus fromString" {
    const testing = std.testing;

    try testing.expectEqual(TaskStatus.pending, try TaskStatus.fromString("pending"));
    try testing.expectEqual(TaskStatus.in_progress, try TaskStatus.fromString("in_progress"));
    try testing.expectEqual(TaskStatus.complete, try TaskStatus.fromString("complete"));
    try testing.expectEqual(TaskStatus.blocked, try TaskStatus.fromString("blocked"));

    try testing.expectError(error.InvalidStatus, TaskStatus.fromString("invalid"));
}

test "types: TaskStatus toString" {
    const testing = std.testing;

    try testing.expectEqualStrings("pending", TaskStatus.pending.toString());
    try testing.expectEqualStrings("in_progress", TaskStatus.in_progress.toString());
    try testing.expectEqualStrings("complete", TaskStatus.complete.toString());
    try testing.expectEqualStrings("blocked", TaskStatus.blocked.toString());
}

test "types: NodeStatus fromString" {
    const testing = std.testing;

    try testing.expectEqual(NodeStatus.available, try NodeStatus.fromString("available"));
    try testing.expectEqual(NodeStatus.in_progress, try NodeStatus.fromString("in_progress"));
    try testing.expectEqual(NodeStatus.completed, try NodeStatus.fromString("completed"));
    try testing.expectEqual(NodeStatus.locked, try NodeStatus.fromString("locked"));

    try testing.expectError(error.InvalidStatus, NodeStatus.fromString("invalid"));
}

test "types: NodeStatus toString" {
    const testing = std.testing;

    try testing.expectEqualStrings("available", NodeStatus.available.toString());
    try testing.expectEqualStrings("in_progress", NodeStatus.in_progress.toString());
    try testing.expectEqualStrings("completed", NodeStatus.completed.toString());
    try testing.expectEqualStrings("locked", NodeStatus.locked.toString());
}

test "types: BranchType fromString" {
    const testing = std.testing;

    try testing.expectEqual(BranchType.core, try BranchType.fromString("core"));
    try testing.expectEqual(BranchType.compiler, try BranchType.fromString("compiler"));
    try testing.expectEqual(BranchType.runtime, try BranchType.fromString("runtime"));
    try testing.expectEqual(BranchType.memory, try BranchType.fromString("memory"));
    try testing.expectEqual(BranchType.quality, try BranchType.fromString("quality"));
    try testing.expectEqual(BranchType.observability, try BranchType.fromString("observability"));

    try testing.expectError(error.InvalidBranch, BranchType.fromString("invalid"));
}

test "types: QualityGates allPassed" {
    const gates = QualityGates{
        .build = .pass,
        .@"test" = .pass,
        .format = .pass,
        .branch_valid = .pass,
    };

    try std.testing.expect(gates.allPassed());
}

test "types: QualityGates getFailedGate" {
    var gates = QualityGates{
        .build = .fail,
        .@"test" = .pass,
        .format = .pass,
        .branch_valid = .pass,
    };

    try std.testing.expectEqualStrings("build", gates.getFailedGate().?);

    gates = QualityGates{
        .build = .pass,
        .@"test" = .fail,
        .format = .pass,
        .branch_valid = .pass,
    };

    try std.testing.expectEqualStrings("test", gates.getFailedGate().?);
}
