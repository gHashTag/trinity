// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN PRIMARY MOTOR CORTEX (M1) — Action Execution & Command Conversion
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// Phase 2: Receives motor plans from PMC, converts to concrete commands
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");
const queen_premotor = @import("queen_premotor.zig");

const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// MOTOR COMMANDS — Concrete executable commands
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_CMD_ARGS = 8;
pub const MAX_ARG_LEN = 64;

/// A concrete command ready for execution
pub const MotorCommand = struct {
    /// The tri subcommand to execute
    subcommand: [32]u8 = undefined,
    subcommand_len: usize = 0,
    /// Arguments for the subcommand
    args: [MAX_CMD_ARGS][MAX_ARG_LEN]u8 = undefined,
    arg_lens: [MAX_CMD_ARGS]usize = [_]usize{0} ** MAX_CMD_ARGS,
    arg_count: u8 = 0,

    /// Initialize args array
    pub fn init() MotorCommand {
        var cmd: MotorCommand = .{};
        for (0..MAX_CMD_ARGS) |i| {
            @memset(&cmd.args[i], 0);
        }
        return cmd;
    }

    pub fn subcommandStr(self: *const MotorCommand) []const u8 {
        return self.subcommand[0..self.subcommand_len];
    }

    /// Get argv slice for process execution
    pub fn toArgv(self: *const MotorCommand, allocator: Allocator) ![][]const u8 {
        var argv = try allocator.alloc([]const u8, self.arg_count + 2);
        argv[0] = "tri";
        argv[1] = self.subcommandStr();

        for (0..self.arg_count) |i| {
            argv[i + 2] = self.args[i][0..self.arg_lens[i]];
        }

        return argv;
    }

    /// Create from action kind
    pub fn fromAction(kind: qt.ActionKind) MotorCommand {
        var cmd = MotorCommand{};
        const label = kind.label();

        // Convert "farm status" → "farm" "status"
        if (std.mem.indexOf(u8, label, " ")) |space_idx| {
            // Split on first space
            @memcpy(cmd.subcommand[0..space_idx], label[0..space_idx]);
            cmd.subcommand_len = space_idx;

            // Add rest as first arg
            const arg_start = space_idx + 1;
            const arg = label[arg_start..];
            @memcpy(cmd.args[0][0..arg.len], arg);
            cmd.arg_lens[0] = arg.len;
            cmd.arg_count = 1;
        } else {
            // Single word command
            @memcpy(cmd.subcommand[0..label.len], label);
            cmd.subcommand_len = label.len;
            cmd.arg_count = 0;
        }

        return cmd;
    }

    /// Format command string for display
    pub fn format(self: *const MotorCommand, buf: []u8) []const u8 {
        var offset: usize = 0;
        const prefix = "tri ";
        @memcpy(buf[offset .. offset + prefix.len], prefix);
        offset += prefix.len;

        @memcpy(buf[offset .. offset + self.subcommand_len], self.subcommand[0..self.subcommand_len]);
        offset += self.subcommand_len;

        for (0..self.arg_count) |i| {
            buf[offset] = ' ';
            offset += 1;
            const arg = self.args[i][0..self.arg_lens[i]];
            @memcpy(buf[offset .. offset + arg.len], arg);
            offset += arg.len;
        }

        return buf[0..offset];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MOTOR EXECUTOR — Executes motor commands
// ═══════════════════════════════════════════════════════════════════════════════

pub const MotorExecutor = struct {
    allocator: Allocator,
    /// Cached context for condition checks - updated via refreshContext()
    context: queen_premotor.SequenceStep.ConditionContext = .{},

    pub fn init(allocator: Allocator) MotorExecutor {
        return .{ .allocator = allocator };
    }

    /// Refresh the condition context by running actual checks
    /// This updates cached values so checkCondition() can use them
    pub fn refreshContext(self: *MotorExecutor) !void {
        self.context.build_ok = try self.checkBuildOk();
        self.context.tests_pass = try self.checkTestsPass();
        self.context.farm_idle_count = try self.checkFarmIdleCount();
        self.context.arena_exists = try self.checkArenaExists();
    }

    /// Check if `zig build` succeeds
    fn checkBuildOk(self: *MotorExecutor) !bool {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "zig", "build" },
            .max_output_bytes = 64 * 1024,
        });
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        return result.term == .Exited and result.term.Exited == 0;
    }

    /// Check if `zig build test` succeeds
    fn checkTestsPass(self: *MotorExecutor) !bool {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "zig", "build", "test" },
            .max_output_bytes = 64 * 1024,
        });
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        return result.term == .Exited and result.term.Exited == 0;
    }

    /// Count idle farm services by running `tri farm list`
    fn checkFarmIdleCount(self: *MotorExecutor) !u8 {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "tri", "farm", "list" },
            .max_output_bytes = 128 * 1024,
        }) catch |err| {
            // If tri farm list fails, assume no idle services
            _ = err;
            return 0;
        };
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Parse output for "idle" status
        // Output format: "N total (M idle, K training, ...)"
        var idle_count: u8 = 0;
        var lines = std.mem.splitScalar(u8, result.stdout, '\n');

        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "idle")) |_| {
                // Try to extract number before "idle"
                const idle_start = std.mem.lastIndexOf(u8, line, " ") orelse continue;
                const after_space = line[idle_start + 1 ..];
                if (after_space.len > 4 and std.mem.eql(u8, after_space[0..4], "idle")) {
                    // Number is before "idle"
                    const num_str = line[0..idle_start];
                    // Find last space before the number
                    if (std.mem.lastIndexOf(u8, line[0..idle_start], " ")) |prev_space| {
                        const num = std.fmt.parseInt(u8, line[prev_space + 1 .. idle_start], 10) catch 0;
                        idle_count = num;
                    }
                }
                // Also check for "(X idle" pattern
                if (std.mem.indexOf(u8, line, "(")) |_| {
                    const paren_idx = std.mem.lastIndexOf(u8, line, "(").?;
                    const after_paren = line[paren_idx + 1 ..];
                    if (std.mem.indexOf(u8, after_paren, "idle")) |_| {
                        const space_idx = std.mem.indexOfScalar(u8, after_paren, ' ') orelse after_paren.len;
                        const num_str = after_paren[0..space_idx];
                        idle_count = std.fmt.parseInt(u8, num_str, 10) catch idle_count;
                    }
                }
            }
        }

        return idle_count;
    }

    /// Check if arena service is running via `tri arena status`
    fn checkArenaExists(self: *MotorExecutor) !bool {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "tri", "arena", "status" },
            .max_output_bytes = 64 * 1024,
        }) catch |err| {
            // If tri arena status fails, arena doesn't exist
            _ = err;
            return false;
        };
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Arena exists if command succeeded and output is non-empty
        const success = result.term == .Exited and result.term.Exited == 0;
        const has_output = result.stdout.len > 0;

        return success and has_output;
    }

    /// Execute a single motor command
    pub fn execute(self: *MotorExecutor, cmd: *const MotorCommand) !ExecutionResult {
        const argv = try cmd.toArgv(self.allocator);
        defer self.allocator.free(argv);

        const start = std.time.milliTimestamp();

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
            .max_output_bytes = 128 * 1024,
        }) catch |err| {
            return ExecutionResult{
                .success = false,
                .duration_ms = 0,
                .exit_code = -1,
                .error_msg = @errorName(err),
            };
        };
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        const elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - start));

        const success = switch (result.term) {
            .Exited => |code| code == 0,
            else => false,
        };

        const exit_code: i32 = switch (result.term) {
            .Exited => |code| code,
            .Signal => |_| -128, // Standard signal encoding
            .Stopped => |_| -127,
            .Unknown => -1,
        };

        return ExecutionResult{
            .success = success,
            .duration_ms = elapsed,
            .exit_code = exit_code,
            .stdout_len = result.stdout.len,
            .stderr_len = result.stderr.len,
        };
    }

    /// Execute action kind directly (converts to command first)
    pub fn executeAction(self: *MotorExecutor, kind: qt.ActionKind) !ExecutionResult {
        const cmd = MotorCommand.fromAction(kind);
        return self.execute(&cmd);
    }

    /// Execute a motor plan from PMC
    pub fn executePlan(self: *MotorExecutor, plan: *const queen_premotor.MotorPlan) !PlanExecutionResult {
        var result = PlanExecutionResult{
            .success = true,
            .steps_executed = 0,
            .total_duration_ms = 0,
        };

        const seq = &plan.sequence;
        const start = std.time.milliTimestamp();

        for (0..seq.step_count) |i| {
            const step = &seq.steps[i];

            // Check condition if present
            if (step.condition) |cond| {
                if (!self.checkCondition(cond, step.custom_check_fn)) {
                    continue;
                }
            }

            // Delay if specified
            if (step.delay_ms > 0) {
                std.Thread.sleep(step.delay_ms * std.time.ns_per_ms);
            }

            // Execute the action
            const exec_result = self.executeAction(step.action) catch |err| {
                result.success = false;
                result.failed_at = @intCast(i);
                result.error_msg = @errorName(err);
                break;
            };

            if (!exec_result.success) {
                // Handle failure based on on_failure action
                if (step.on_failure == .stop) {
                    result.success = false;
                    result.failed_at = @intCast(i);
                    break;
                } else if (step.on_failure == .skip) {
                    continue;
                }
                // TODO: handle retry and fallback
            }

            result.steps_executed += 1;
        }

        result.total_duration_ms = @intCast(@max(0, std.time.milliTimestamp() - start));
        return result;
    }

    /// Check a condition using cached context or custom check function
    fn checkCondition(
        self: *MotorExecutor,
        cond: queen_premotor.SequenceStep.Condition,
        custom_fn: ?queen_premotor.SequenceStep.CustomCheckFn,
    ) bool {
        return switch (cond) {
            .build_ok => self.context.build_ok,
            .tests_pass => self.context.tests_pass,
            .farm_idle_exists => self.context.farm_idle_count > 0,
            .arena_exists => self.context.arena_exists,
            .custom_check => if (custom_fn) |f| f(&self.context) else false,
            .health_critical => self.context.ouroboros_score < 50.0,
            .health_good => self.context.ouroboros_score >= 70.0,
            .dirty_exists => self.context.dirty_files > 0,
            .farm_has_leaders => self.context.farm_idle_count >= 3,
            .farm_best_ppl_good => self.context.farm_best_ppl < 10.0,
            .arena_stale => self.context.stale_arena_hours > 24,
            .has_uncommitted => self.context.has_uncommitted,
        };
    }
};

pub const ExecutionResult = struct {
    success: bool,
    duration_ms: u64,
    exit_code: i32,
    stdout_len: usize = 0,
    stderr_len: usize = 0,
    error_msg: []const u8 = "",
};

pub const PlanExecutionResult = struct {
    success: bool,
    steps_executed: u8,
    total_duration_ms: u64,
    failed_at: ?u8 = null,
    error_msg: []const u8 = "",
};

// ═══════════════════════════════════════════════════════════════════════════════
// MOTOR BATCH — Batch execution for parallel actions
// ═══════════════════════════════════════════════════════════════════════════════

pub const MotorBatch = struct {
    commands: [MAX_CMD_ARGS]MotorCommand = undefined,
    count: u8 = 0,
    parallel: bool = false,

    pub fn addCommand(self: *MotorBatch, cmd: MotorCommand) !void {
        if (self.count >= MAX_CMD_ARGS) return error.BatchFull;
        self.commands[self.count] = cmd;
        self.count += 1;
    }

    pub fn execute(self: *MotorBatch, allocator: Allocator) !BatchResult {
        var result = BatchResult{
            .count = self.count,
            .success_count = 0,
            .total_duration_ms = 0,
        };

        const start = std.time.milliTimestamp();

        if (self.parallel) {
            // Parallel execution using threads
            // For simplicity, execute sequentially for now
            // TODO: implement actual parallel execution
            for (0..self.count) |i| {
                var executor = MotorExecutor.init(allocator);
                const exec_result = executor.execute(&self.commands[i]) catch continue;
                if (exec_result.success) result.success_count += 1;
            }
        } else {
            // Sequential execution
            for (0..self.count) |i| {
                var executor = MotorExecutor.init(allocator);
                const exec_result = executor.execute(&self.commands[i]) catch continue;
                if (exec_result.success) result.success_count += 1;
            }
        }

        result.total_duration_ms = @intCast(@max(0, std.time.milliTimestamp() - start));
        return result;
    }
};

pub const BatchResult = struct {
    count: u8,
    success_count: u8,
    total_duration_ms: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND BUILDER — Build complex commands
// ═══════════════════════════════════════════════════════════════════════════════

pub const CommandBuilder = struct {
    cmd: MotorCommand = .{},

    pub fn init() CommandBuilder {
        return .{};
    }

    pub fn subcommand(self: *CommandBuilder, name: []const u8) !void {
        if (name.len > 32) return error.NameTooLong;
        @memcpy(self.cmd.subcommand[0..name.len], name);
        self.cmd.subcommand_len = name.len;
    }

    pub fn arg(self: *CommandBuilder, value: []const u8) !void {
        if (self.cmd.arg_count >= MAX_CMD_ARGS) return error.TooManyArgs;
        if (value.len > MAX_ARG_LEN) return error.ArgTooLong;

        @memcpy(self.cmd.args[self.cmd.arg_count][0..value.len], value);
        self.cmd.arg_lens[self.cmd.arg_count] = value.len;
        self.cmd.arg_count += 1;
    }

    pub fn build(self: *const CommandBuilder) MotorCommand {
        return self.cmd;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Motor — MotorCommand fromAction" {
    const cmd = MotorCommand.fromAction(.farm_status);
    try std.testing.expectEqualStrings("farm", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("status", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand format" {
    var cmd = MotorCommand.fromAction(.doctor_quick);
    var buf: [128]u8 = undefined;
    const formatted = cmd.format(&buf);
    try std.testing.expect(formatted.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "tri") != null);
}

test "Motor — CommandBuilder" {
    var builder = CommandBuilder{};
    try builder.subcommand("farm");
    try builder.arg("status");
    const cmd = builder.build();

    try std.testing.expectEqualStrings("farm", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
}

test "Motor — MotorBatch add" {
    var batch = MotorBatch{};
    try batch.addCommand(MotorCommand.fromAction(.farm_status));
    try batch.addCommand(MotorCommand.fromAction(.arena_status));
    try std.testing.expectEqual(@as(u8, 2), batch.count);
}

test "Motor — MotorExecutor executeAction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var executor = MotorExecutor.init(allocator);
    const result = try executor.executeAction(.farm_status);

    // Should succeed (farm_status is read-only)
    _ = result;
}

test "Motor — MotorExecutor executePlan" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const plan = queen_premotor.MotorPlan.init(.assess_health);
    var executor = MotorExecutor.init(allocator);
    const result = try executor.executePlan(&plan);

    _ = result;
}
