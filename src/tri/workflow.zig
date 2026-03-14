// @origin(spec:workflow.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI WORKFLOW SCHEMA — Orchestrator Workflow Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred Formula: φ² + 1/φ² = 3
// Workflow Schema YAML Format and Execution Engine
//
// Author: TRI ORCHESTRATOR
// Version: 1.0.0
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringHashMap = std.StringHashMapUnmanaged;

// ═══════════════════════════════════════════════════════════════════════════════
// CORE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Workflow execution strategy
pub const WorkflowStrategy = enum {
    sequential, // Execute steps in order
    parallel, // Execute all steps concurrently
    conditional, // Execute based on conditions
    adaptive, // Dynamic strategy based on runtime context

    pub fn name(self: WorkflowStrategy) []const u8 {
        return switch (self) {
            .sequential => "SEQUENTIAL",
            .parallel => "PARALLEL",
            .conditional => "CONDITIONAL",
            .adaptive => "ADAPTIVE",
        };
    }
};

/// Sacred realm for workflow execution
pub const WorkflowRealm = enum {
    razum, // Mind - Gold #ffd700 - routing, intelligence, decisions
    materiya, // Matter - Cyan #00ccff - storage, data, infrastructure
    dukh, // Spirit - Purple #aa66ff - actions, tools, proofs
    universal, // All realms - can execute anywhere

    pub fn color(self: WorkflowRealm) []const u8 {
        return switch (self) {
            .razum => "#ffd700",
            .materiya => "#00ccff",
            .dukh => "#aa66ff",
            .universal => "#ffffff",
        };
    }

    pub fn name(self: WorkflowRealm) []const u8 {
        return switch (self) {
            .razum => "RAZUM",
            .materiya => "MATERIYA",
            .dukh => "DUKH",
            .universal => "UNIVERSAL",
        };
    }
};

/// Step execution state
pub const StepState = enum {
    pending, // Not yet started
    running, // Currently executing
    completed, // Successfully finished
    failed, // Failed with error
    skipped, // Skipped due to condition
    cancelled, // Cancelled by user or system
    timeout, // Timed out

    pub fn color(self: StepState) []const u8 {
        return switch (self) {
            .pending => "#808080", // Gray
            .running => "#ffa500", // Orange
            .completed => "#00ff00", // Green
            .failed => "#ff0000", // Red
            .skipped => "#ffff00", // Yellow
            .cancelled => "#ff69b4", // Pink
            .timeout => "#ff4500", // OrangeRed
        };
    }
};

/// Workflow execution state
pub const WorkflowExecutionState = enum {
    initialized, // Created but not started
    running, // Currently executing
    paused, // Paused by user or system
    completed, // Successfully finished
    failed, // Failed with error
    cancelled, // Cancelled by user
    timeout, // Timed out

    pub fn color(self: WorkflowExecutionState) []const u8 {
        return switch (self) {
            .initialized => "#87ceeb", // SkyBlue
            .running => "#00bfff", // DeepSkyBlue
            .paused => "#ffa500", // Orange
            .completed => "#32cd32", // LimeGreen
            .failed => "#dc143c", // Crimson
            .cancelled => "#ff69b4", // HotPink
            .timeout => "#ff6347", // Tomato
        };
    }
};

/// Workflow execution result
pub const WorkflowResult = enum {
    success,
    failure,
    cancelled,
    timeout,
    unknown,

    pub fn color(self: WorkflowResult) []const u8 {
        return switch (self) {
            .success => "#00ff00", // Green
            .failure => "#ff0000", // Red
            .cancelled => "#ff69b4", // Pink
            .timeout => "#ff4500", // OrangeRed
            .unknown => "#808080", // Gray
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKFLOW DEFINITION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Workflow variable definition
pub const WorkflowVariable = struct {
    name: []const u8,
    value: []const u8,
    type: VariableType = .string,
    description: ?[]const u8 = null,
    required: bool = true,

    pub const VariableType = enum {
        string,
        integer,
        float,
        boolean,
        json,

        pub fn parse(value: []const u8, var_type: VariableType) ![]const u8 {
            return switch (var_type) {
                .string => value,
                .integer => try std.fmt.allocPrint(std.testing.allocator, "{}", .{std.fmt.parseInt(i64, value, 10) catch return error.InvalidInteger}),
                .float => try std.fmt.allocPrint(std.testing.allocator, "{d}", .{std.fmt.parseFloat(f64, value) catch return error.InvalidFloat}),
                .boolean => if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) "true" else "false",
                .json => value, // DEFERRED (v12): Validate JSON syntax using std.json or similar
            };
        }
    };
};

/// Workflow step definition
pub const WorkflowStep = struct {
    id: []const u8,
    name: []const u8,
    command: []const u8,
    args: []const []const u8 = &[_][]const u8{},
    condition: ?[]const u8 = null, // Expression evaluated before execution
    depends_on: []const []const u8 = &[_][]const u8{}, // Step IDs that must complete first
    continue_on_failure: bool = false,
    realm: WorkflowRealm = .universal,
    timeout_ms: ?u64 = null,
    retry_policy: ?RetryPolicy = null,
    environment: ?StringHashMap([]const u8) = null,
    working_directory: ?[]const u8 = null,
    description: ?[]const u8 = null,

    pub const RetryPolicy = struct {
        max_attempts: u32 = 1,
        initial_delay_ms: u64 = 1000,
        max_delay_ms: u64 = 30000,
        backoff_multiplier: f64 = 2.0,
        jitter_enabled: bool = true,
    };
};

/// Complete workflow definition
pub const Workflow = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    strategy: WorkflowStrategy = .sequential,
    rollback_enabled: bool = false,
    sacred_validation: bool = true,
    timeout_ms: ?u64 = null,
    variables: StringHashMap(WorkflowVariable) = StringHashMap(WorkflowVariable).init(std.testing.allocator),
    steps: ArrayList(WorkflowStep) = ArrayList(WorkflowStep).init(std.testing.allocator),
    version: []const u8 = "1.0.0",
    created_at: i64 = std.time.timestamp(),
    updated_at: i64 = std.time.timestamp(),

    pub fn init(allocator: Allocator) Workflow {
        return Workflow{
            .allocator = allocator,
            .variables = StringHashMap(WorkflowVariable).init(allocator),
            .steps = ArrayList(WorkflowStep).init(allocator),
        };
    }

    pub fn deinit(self: *Workflow) void {
        var var_it = self.variables.iterator();
        while (var_it.next()) |entry| {
            self.allocator.free(entry.value.name);
            self.allocator.free(entry.value.value);
            if (entry.value.description) |desc| {
                self.allocator.free(desc);
            }
        }
        self.variables.deinit();

        for (self.steps.items) |*step| {
            self.allocator.free(step.id);
            self.allocator.free(step.name);
            self.allocator.free(step.command);
            for (step.args) |arg| {
                self.allocator.free(arg);
            }
            if (step.condition) |cond| {
                self.allocator.free(cond);
            }
            for (step.depends_on) |dep| {
                self.allocator.free(dep);
            }
            if (step.environment) |env| {
                var env_it = env.iterator();
                while (env_it.next()) |entry| {
                    self.allocator.free(entry.key_ptr.*);
                    self.allocator.free(entry.value_ptr.*);
                }
                env.deinit();
            }
            if (step.working_directory) |dir| {
                self.allocator.free(dir);
            }
            if (step.description) |desc| {
                self.allocator.free(desc);
            }
        }
        self.steps.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTION STATE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual step execution state
pub const StepExecutionState = struct {
    step_id: []const u8,
    state: StepState,
    start_time: ?i64 = null,
    end_time: ?i64 = null,
    duration_ms: u64 = 0,
    exit_code: ?u8 = null,
    output: ?[]const u8 = null,
    error_msg: ?[]const u8 = null,
    retry_count: u32 = 0,
    progress: f32 = 0.0, // 0.0 to 1.0

    pub fn init(step_id: []const u8) StepExecutionState {
        return .{
            .step_id = step_id,
            .state = .pending,
            .progress = 0.0,
        };
    }

    pub fn isCompleted(self: *const StepExecutionState) bool {
        return self.state == .completed or self.state == .failed or
            self.state == .skipped or self.state == .cancelled or
            self.state == .timeout;
    }

    pub fn duration(self: *const StepExecutionState) ?u64 {
        if (self.start_time) |start| {
            const end = self.end_time orelse std.time.timestamp();
            return @intCast(end - start);
        }
        return null;
    }
};

/// Complete workflow execution state
pub const ExecutionState = struct {
    workflow_id: []const u8,
    workflow_name: []const u8,
    state: WorkflowExecutionState,
    start_time: ?i64 = null,
    end_time: ?i64 = null,
    duration_ms: u64 = 0,
    current_step: ?[]const u8 = null,
    step_states: StringHashMap(StepExecutionState) = StringHashMap(StepExecutionState).init(std.testing.allocator),
    variables: StringHashMap([]const u8) = StringHashMap([]const u8).init(std.testing.allocator),
    logs: ArrayList(LogEntry) = ArrayList(LogEntry).init(std.testing.allocator),
    result: ?WorkflowResult = null,
    error_msg: ?[]const u8 = null,
    progress: f32 = 0.0,
    paused_at: ?i64 = null,
    created_at: i64 = std.time.timestamp(),

    pub const LogEntry = struct {
        timestamp: i64,
        level: LogLevel,
        message: []const u8,
        step_id: ?[]const u8 = null,

        pub const LogLevel = enum {
            debug,
            info,
            warn,
            err,

            pub fn color(self: LogLevel) []const u8 {
                return switch (self) {
                    .debug => "#87ceeb", // SkyBlue
                    .info => "#00ff00", // Green
                    .warn => "#ffa500", // Orange
                    .err => "#ff0000", // Red
                };
            }
        };
    };

    pub fn init(allocator: Allocator, workflow_id: []const u8, workflow_name: []const u8) ExecutionState {
        return ExecutionState{
            .allocator = allocator,
            .workflow_id = workflow_id,
            .workflow_name = workflow_name,
            .state = .initialized,
            .step_states = StringHashMap(StepExecutionState).init(allocator),
            .variables = StringHashMap([]const u8).init(allocator),
            .logs = ArrayList(LogEntry).init(allocator),
            .progress = 0.0,
        };
    }

    pub fn deinit(self: *ExecutionState) void {
        var state_it = self.step_states.iterator();
        while (state_it.next()) |entry| {
            self.allocator.free(entry.key);
        }
        self.step_states.deinit();

        var var_it = self.variables.iterator();
        while (var_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.variables.deinit();

        for (self.logs.items) |*log| {
            self.allocator.free(log.message);
            if (log.step_id) |step_id| {
                self.allocator.free(step_id);
            }
        }
        self.logs.deinit();
    }

    pub fn isCompleted(self: *const ExecutionState) bool {
        return self.state == .completed or self.state == .failed or
            self.state == .cancelled or self.state == .timeout;
    }

    pub fn duration(self: *const ExecutionState) ?u64 {
        if (self.start_time) |start| {
            const end = self.end_time orelse std.time.timestamp();
            return @intCast(end - start);
        }
        return null;
    }

    pub fn addLog(self: *ExecutionState, level: LogEntry.LogLevel, message: []const u8, step_id: ?[]const u8) !void {
        const log = LogEntry{
            .timestamp = std.time.timestamp(),
            .level = level,
            .message = try self.allocator.dupe(u8, message),
            .step_id = if (step_id) |sid| try self.allocator.dupe(u8, sid) else null,
        };
        try self.logs.append(log);
    }

    pub fn setVariable(self: *ExecutionState, name: []const u8, value: []const u8) !void {
        try self.variables.put(name, try self.allocator.dupe(u8, value));
    }

    pub fn getVariable(self: *ExecutionState, name: []const u8) ?[]const u8 {
        return self.variables.get(name);
    }

    pub fn getStepState(self: *ExecutionState, step_id: []const u8) ?*StepExecutionState {
        return self.step_states.getEntry(step_id);
    }

    pub fn addStepState(self: *ExecutionState, step_id: []const u8) !void {
        const state = StepExecutionState.init(try self.allocator.dupe(u8, step_id));
        try self.step_states.put(step_id, state);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Validation result for workflow definitions
pub const ValidationResult = struct {
    valid: bool,
    errors: ArrayList(ValidationError) = ArrayList(ValidationError).init(std.testing.allocator),
    warnings: ArrayList(ValidationWarning) = ArrayList(ValidationWarning).init(std.testing.allocator),
    sacred_score: ?f64 = null,

    pub const ValidationError = struct {
        path: []const u8,
        message: []const u8,
        severity: ErrorSeverity,

        pub const ErrorSeverity = enum {
            err,
            warning,
        };
    };

    pub const ValidationWarning = struct {
        path: []const u8,
        message: []const u8,
        suggestion: []const u8,
    };

    pub fn init(allocator: Allocator) ValidationResult {
        return ValidationResult{
            .errors = ArrayList(ValidationError).init(allocator),
            .warnings = ArrayList(ValidationWarning).init(allocator),
        };
    }

    pub fn deinit(self: *ValidationResult) void {
        for (self.errors.items) |*err| {
            self.allocator.free(err.path);
            self.allocator.free(err.message);
        }
        self.errors.deinit();

        for (self.warnings.items) |*warning| {
            self.allocator.free(warning.path);
            self.allocator.free(warning.message);
            self.allocator.free(warning.suggestion);
        }
        self.warnings.deinit();
    }

    pub fn addError(self: *ValidationResult, path: []const u8, message: []const u8, severity: ValidationError.ErrorSeverity) !void {
        const err = ValidationError{
            .path = try self.allocator.dupe(u8, path),
            .message = try self.allocator.dupe(u8, message),
            .severity = severity,
        };
        try self.errors.append(err);
    }

    pub fn addWarning(self: *ValidationResult, path: []const u8, message: []const u8, suggestion: []const u8) !void {
        const warning = ValidationWarning{
            .path = try self.allocator.dupe(u8, path),
            .message = try self.allocator.dupe(u8, message),
            .suggestion = try self.allocator.dupe(u8, suggestion),
        };
        try self.warnings.append(warning);
    }

    pub fn isValid(self: *const ValidationResult) bool {
        // Consider valid if no errors, or only warnings
        return for (self.errors.items) |e| {
            if (e.severity == .err) break false;
        } else true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKFLOW EXECUTOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Executor configuration
pub const ExecutorConfig = struct {
    max_concurrent_steps: u32 = 4,
    default_timeout_ms: u64 = 300_000, // 5 minutes
    max_retry_attempts: u32 = 3,
    retry_initial_delay_ms: u64 = 1000,
    retry_backoff_multiplier: f64 = 2.0,
    enable_sacred_validation: bool = true,
    sacred_threshold: f64 = 0.95,
    enable_rollback: bool = true,
    rollback_timeout_ms: u64 = 60_000,
    log_level: LogLevel = .info,

    pub const LogLevel = enum {
        debug,
        info,
        warn,
        err,
    };
};

/// Workflow execution options
pub const ExecutionOptions = struct {
    workflow_id: []const u8,
    variables: StringHashMap([]const u8) = StringHashMap([]const u8).init(std.testing.allocator),
    dry_run: bool = false,
    validate_only: bool = false,
    resume_from_step: ?[]const u8 = null,
    timeout_ms: ?u64 = null,
    config: ExecutorConfig = ExecutorConfig{},

    pub fn init(allocator: Allocator, workflow_id: []const u8) ExecutionOptions {
        return ExecutionOptions{
            .allocator = allocator,
            .workflow_id = workflow_id,
            .variables = StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ExecutionOptions) void {
        var var_it = self.variables.iterator();
        while (var_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.variables.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI = 1.618033988749895; // Golden ratio
pub const MU = 0.0382; // Sacred learning rate
pub const CHI = 0.23607; // Chi constant
pub const SIGMA = 1.618; // Sigma
pub const EPSILON = 0.333; // Epsilon
pub const SACRED_THRESHOLD = 0.95; // Quality gate threshold
pub const MAX_WORKFLOW_STEPS = 1000; // Maximum steps per workflow
pub const MAX_WORKFLOW_DURATION_MS = 31_536_000_000; // 365 days
pub const MAX_VARIABLE_NAME_LENGTH = 64;
pub const MAX_COMMAND_LENGTH = 4096;
pub const MAX_ARGS_PER_STEP = 32;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED VALIDATION FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify Trinity identity: φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() bool {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    return @abs(result - 3.0) < 0.0001;
}

/// Calculate sacred workflow score based on structure and properties
pub fn calculateSacredScore(workflow: *const Workflow) f64 {
    var score: f64 = 1.0;

    // Factor 1: Step count optimization (optimal around 5-10 steps)
    const step_count = @as(f64, @floatFromInt(workflow.steps.items.len));
    if (step_count > 0) {
        const step_score = if (step_count <= 10)
            1.0
        else if (step_count <= 50)
            0.8
        else if (step_count <= 100)
            0.6
        else
            0.3;
        score *= step_score;
    }

    // Factor 2: Strategy optimization
    const strategy_score = switch (workflow.strategy) {
        .sequential => 0.9,
        .parallel => 0.95,
        .conditional => 0.85,
        .adaptive => 1.0,
    };
    score *= strategy_score;

    // Factor 3: Realm distribution
    var realm_count: u32 = 0;
    for (workflow.steps.items) |step| {
        if (step.realm != .universal) {
            realm_count += 1;
        }
    }
    const realm_score = if (realm_count > 0)
        @min(1.0, @as(f64, @floatFromInt(realm_count)) / @as(f64, @floatFromInt(workflow.steps.items.len)))
    else
        0.5; // Universal steps get moderate score
    score *= realm_score;

    // Factor 4: Variable usage
    const var_score = if (workflow.variables.count() > 0)
        0.9
    else
        0.7;
    score *= var_score;

    // Apply Trinity identity modifier
    if (verifyTrinityIdentity()) {
        score *= PHI; // Golden ratio bonus
    } else {
        score *= 0.8; // Penalty for broken sacred formula
    }

    return @min(1.0, score);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Sacred constants" {
    try std.testing.expect(verifyTrinityIdentity());
    try std.testing.expectApproxEqAbs(PHI, 1.618, 0.001);
    try std.testing.expectApproxEqAbs(MU, 0.0382, 0.0001);
}

test "WorkflowStrategy names" {
    try std.testing.expectEqualStrings("SEQUENTIAL", WorkflowStrategy.sequential.name());
    try std.testing.expectEqualStrings("PARALLEL", WorkflowStrategy.parallel.name());
    try std.testing.expectEqualStrings("CONDITIONAL", WorkflowStrategy.conditional.name());
    try std.testing.expectEqualStrings("ADAPTIVE", WorkflowStrategy.adaptive.name());
}

test "WorkflowRealm colors and names" {
    try std.testing.expectEqualStrings("#ffd700", WorkflowRealm.razum.color());
    try std.testing.expectEqualStrings("#00ccff", WorkflowRealm.materiya.color());
    try std.testing.expectEqualStrings("#aa66ff", WorkflowRealm.dukh.color());
    try std.testing.expectEqualStrings("#ffffff", WorkflowRealm.universal.color());

    try std.testing.expectEqualStrings("RAZUM", WorkflowRealm.razum.name());
    try std.testing.expectEqualStrings("MATERIYA", WorkflowRealm.materiya.name());
    try std.testing.expectEqualStrings("DUKH", WorkflowRealm.dukh.name());
    try std.testing.expectEqualStrings("UNIVERSAL", WorkflowRealm.universal.name());
}

test "StepState colors" {
    try std.testing.expectEqualStrings("#808080", StepState.pending.color());
    try std.testing.expectEqualStrings("#ffa500", StepState.running.color());
    try std.testing.expectEqualStrings("#00ff00", StepState.completed.color());
    try std.testing.expectEqualStrings("#ff0000", StepState.failed.color());
}

test "WorkflowVariable type parsing" {
    const allocator = std.testing.allocator;

    // String type
    const str_result = WorkflowVariable.VariableType.parse("hello", .string) catch unreachable;
    try std.testing.expectEqualStrings("hello", str_result);

    // Integer type
    const int_result = WorkflowVariable.VariableType.parse("42", .integer) catch unreachable;
    try std.testing.expectEqualStrings("42", int_result);

    // Boolean type
    const bool_true = WorkflowVariable.VariableType.parse("true", .boolean) catch unreachable;
    try std.testing.expectEqualStrings("true", bool_true);
    const bool_false = WorkflowVariable.VariableType.parse("0", .boolean) catch unreachable;
    try std.testing.expectEqualStrings("false", bool_false);

    allocator.free(str_result);
    allocator.free(int_result);
    allocator.free(bool_true);
    allocator.free(bool_false);
}

test "Workflow initialization and cleanup" {
    const allocator = std.testing.allocator;
    var workflow = Workflow.init(allocator);
    defer workflow.deinit();

    try std.testing.expectEqual(@as(usize, 0), workflow.variables.count());
    try std.testing.expectEqual(@as(usize, 0), workflow.steps.items.len);
}

test "ExecutionState initialization and cleanup" {
    const allocator = std.testing.allocator;
    var state = ExecutionState.init(allocator, "test-workflow", "Test Workflow");
    defer state.deinit();

    try std.testing.expectEqualStrings("test-workflow", state.workflow_id);
    try std.testing.expectEqualStrings("Test Workflow", state.workflow_name);
    try std.testing.expectEqual(WorkflowExecutionState.initialized, state.state);
    try std.testing.expect(state.progress == 0.0);
}

test "ValidationResult management" {
    const allocator = std.testing.allocator;
    var result = ValidationResult.init(allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());

    try result.addError("steps[0].command", "Command is empty", .err);
    try std.testing.expect(!result.isValid());

    try result.addWarning("variables.temp", "Unused variable", "Remove or use variable");
    try std.testing.expectEqual(@as(usize, 1), result.errors.items.len);
    try std.testing.expectEqual(@as(usize, 1), result.warnings.items.len);
}

test "Sacred workflow score calculation" {
    const allocator = std.testing.allocator;
    var workflow = Workflow.init(allocator);
    defer workflow.deinit();

    // Test with empty workflow
    var score = calculateSacredScore(&workflow);
    try std.testing.expect(score > 0.0 and score <= 1.0);

    // Add some steps
    const step = WorkflowStep{
        .id = "step1",
        .name = "Test Step",
        .command = "echo hello",
        .realm = .razum,
    };
    try workflow.steps.append(step);

    score = calculateSacredScore(&workflow);
    try std.testing.expect(score > 0.0 and score <= 1.0);

    // Add more steps to test step count penalty
    for (0..20) |i| {
        const additional_step = WorkflowStep{
            .id = try std.fmt.allocPrint(allocator, "step{}", .{i + 2}),
            .name = try std.fmt.allocPrint(allocator, "Test Step {}", .{i + 2}),
            .command = "echo hello",
            .realm = .universal,
        };
        try workflow.steps.append(additional_step);
    }

    score = calculateSacredScore(&workflow);
    try std.testing.expect(score <= 0.8); // Should be lower due to many steps
}

test "StepExecutionState duration calculation" {
    const allocator = std.testing.allocator;
    var state = StepExecutionState.init("test-step");

    // Test duration when not started
    try std.testing.expect(state.duration() == null);

    // Test with start time but no end time
    state.start_time = std.time.timestamp() - 5000;
    try std.testing.expect(state.duration() != null);
    if (state.duration()) |duration| {
        try std.testing.expect(duration >= 4000); // Allow small margin
    }

    // Test with both start and end times
    state.end_time = std.time.timestamp();
    if (state.duration()) |duration| {
        try std.testing.expect(duration >= 4000);
    }
}
