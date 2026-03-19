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

    /// Initialize command with zeroed memory
    pub fn init() MotorCommand {
        var cmd: MotorCommand = .{
            .subcommand = undefined,
            .subcommand_len = 0,
            .args = undefined,
            .arg_lens = [_]usize{0} ** MAX_CMD_ARGS,
            .arg_count = 0,
        };
        @memset(&cmd.subcommand, 0);
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
        var cmd: MotorCommand = undefined;
        @memset(&cmd.subcommand, 0);
        for (0..MAX_CMD_ARGS) |i| {
            @memset(&cmd.args[i], 0);
        }
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
        return MotorExecutor{ .allocator = allocator };
    }

    /// Execute a single motor command
    pub fn execute(self: *MotorExecutor, cmd: *const MotorCommand) !ExecutionResult {
        const argv = try cmd.toArgv(self.allocator);
        defer {
            self.allocator.free(argv);
        }

        const start = std.time.milliTimestamp();

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
            .max_output_bytes = 2 * 1024 * 1024,
        }) catch return ExecutionResult{
            .success = false,
            .duration_ms = 0,
            .error_msg = "error",
        };
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        const duration = std.time.milliTimestamp() - start;
        const success = result.term == .Exited and result.term.Exited == 0;

        // Check if command produced output
        const has_output = result.stdout.len > 0 or result.stderr.len > 0;

        return ExecutionResult{
            .success = success,
            .duration_ms = @intCast(duration),
            .error_msg = if (!success) "Command failed" else "",
            .has_output = has_output,
        };
    }

    /// Refresh context from current system state
    pub fn refreshContext(self: *MotorExecutor) !void {
        // Original fields - real system checks
        self.context.build_ok = try self.checkBuildOk();
        self.context.tests_pass = try self.checkTestsPass();
        self.context.farm_idle_count = try self.checkFarmIdleCount();
        self.context.arena_exists = try self.checkArenaExists();

        // v2: Extended context fields
        self.context.ouroboros_score = self.checkOuroborosScore() catch 0.0;
        self.context.dirty_files = self.checkDirtyFiles() catch 0;
        self.context.farm_best_ppl = self.checkFarmBestPpl() catch 999.0;
        self.context.stale_arena_hours = self.checkStaleArenaHours() catch 0;
        self.context.has_uncommitted = self.context.dirty_files > 0;
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
        }) catch return 0;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Parse output for "idle" status
        var idle_count: u8 = 0;
        var lines = std.mem.splitScalar(u8, result.stdout, '\n');

        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "idle")) |_| {
                if (std.mem.indexOf(u8, line, "(")) |_| {
                    const paren_idx = std.mem.lastIndexOf(u8, line, "(") orelse continue;
                    const after_paren = line[paren_idx + 1 ..];
                    if (std.mem.indexOf(u8, after_paren, "idle")) |_| {
                        const space_idx = std.mem.indexOfScalar(u8, after_paren, ' ') orelse after_paren.len;
                        idle_count = std.fmt.parseInt(u8, after_paren[0..space_idx], 10) catch idle_count;
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
        }) catch return false;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        const success = result.term == .Exited and result.term.Exited == 0;
        const has_output = result.stdout.len > 0;

        return success and has_output;
    }

    // v2: Additional check methods for new conditions

    /// Get ouroboros score from `tri ouroboros status`
    fn checkOuroborosScore(self: *MotorExecutor) !f32 {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "tri", "ouroboros", "status" },
            .max_output_bytes = 64 * 1024,
        }) catch return 0.0;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Parse score from output (format: "Score: XX.X")
        var score: f32 = 0.0;
        var lines = std.mem.splitScalar(u8, result.stdout, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "Score:")) |_| {
                const colon_idx = std.mem.lastIndexOf(u8, line, ":") orelse continue;
                const after_colon = line[colon_idx + 1 ..];
                score = std.fmt.parseFloat(f32, std.mem.trim(u8, after_colon, &std.ascii.whitespace)) catch 0.0;
                break;
            }
        }
        return score;
    }

    /// Get dirty files count from `tri git status`
    fn checkDirtyFiles(self: *MotorExecutor) !u16 {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "tri", "git", "status" },
            .max_output_bytes = 64 * 1024,
        }) catch return 0;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Count lines that indicate dirty state
        var count: u16 = 0;
        var lines = std.mem.splitScalar(u8, result.stdout, '\n');
        while (lines.next()) |line| {
            // Lines starting with " M", "M ", "??", etc. indicate changes
            if (line.len > 2 and (line[0] == 'M' or line[0] == '?' or line[1] == 'M')) {
                count += 1;
            }
        }
        return count;
    }

    /// Get best PPL from farm status
    fn checkFarmBestPpl(self: *MotorExecutor) !f32 {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "tri", "farm", "status" },
            .max_output_bytes = 64 * 1024,
        }) catch return 999.0;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Parse best PPL from output
        var best_ppl: f32 = 999.0;
        var lines = std.mem.splitScalar(u8, result.stdout, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "Best PPL:")) |_| {
                const colon_idx = std.mem.lastIndexOf(u8, line, ":") orelse continue;
                const after_colon = line[colon_idx + 1 ..];
                best_ppl = std.fmt.parseFloat(f32, std.mem.trim(u8, after_colon, &std.ascii.whitespace)) catch 999.0;
                break;
            }
        }
        return best_ppl;
    }

    /// Get stale arena hours by checking arena last battle timestamp
    fn checkStaleArenaHours(self: *MotorExecutor) !u16 {
        _ = self;
        // Check arena status file for last battle time
        const arena_file = std.fs.cwd().openFile(".trinity/arena_status.json", .{}) catch return 0;
        defer arena_file.close();

        var buf: [2048]u8 = undefined;
        const n = arena_file.read(&buf) catch return 0;
        const data = buf[0..n];

        // Parse last_battle_ts from JSON
        if (std.mem.indexOf(u8, data, "\"last_battle_ts\":")) |idx| {
            const after_colon = data[idx + 16 ..];
            const ts_end = std.mem.indexOfScalar(u8, after_colon, ',') orelse after_colon.len;
            const ts_end2 = std.mem.indexOfScalar(u8, after_colon[0..ts_end], '}') orelse ts_end;
            const ts_str = std.mem.trim(u8, after_colon[0..ts_end2], &std.ascii.whitespace);
            const last_ts = std.fmt.parseInt(i64, ts_str, 10) catch return 0;

            const now = std.time.timestamp();
            const hours_ago = @as(u16, @intCast(@divTrunc(now - last_ts, 3600)));
            return hours_ago;
        }

        return 0;
    }

    /// Check if a condition is currently true
    pub fn checkCondition(self: *MotorExecutor, cond: queen_premotor.SequenceStep.Condition) bool {
        return switch (cond) {
            .build_ok => self.context.build_ok,
            .tests_pass => self.context.tests_pass,
            .farm_idle_exists => self.context.farm_idle_count > 0,
            .arena_exists => self.context.arena_exists,
            .custom_check => false, // Would need fn pointer
            // v2: new conditions
            .health_critical => self.context.ouroboros_score < 50.0,
            .health_good => self.context.ouroboros_score >= 70.0,
            .dirty_exists => self.context.dirty_files > 0,
            .farm_has_leaders => self.context.farm_idle_count >= 3,
            .farm_best_ppl_good => self.context.farm_best_ppl < 10.0,
            .arena_stale => self.context.stale_arena_hours > 24,
            .has_uncommitted => self.context.has_uncommitted,
        };
    }

    /// Execute a motor plan (sequence of actions)
    pub fn executePlan(self: *MotorExecutor, plan: *const queen_premotor.MotorPlan) !PlanExecutionResult {
        var total_duration: u64 = 0;
        var steps_executed: u8 = 0;
        var failed_at: ?u8 = null;

        // Refresh context before executing plan
        try self.refreshContext();

        for (0..plan.sequence.step_count) |i| {
            const step = &plan.sequence.steps[i];

            // Check condition if present
            if (step.condition) |cond| {
                if (!self.checkCondition(cond)) {
                    failed_at = @intCast(i);
                    continue; // Skip this step
                }
            }

            // Apply delay if specified
            if (step.delay_ms > 0) {
                std.Thread.sleep(step.delay_ms * std.time.ns_per_ms);
            }

            // Execute the action
            const cmd = MotorCommand.fromAction(step.action);
            const result = try self.execute(&cmd);

            if (!result.success) {
                failed_at = @intCast(i);
                // Handle failure based on on_failure setting
                switch (step.on_failure) {
                    .stop => break,
                    .skip => continue,
                    .retry => {
                        // Simple retry once
                        _ = try self.execute(&cmd);
                    },
                    .fallback => |fallback_action| {
                        const fallback_cmd = MotorCommand.fromAction(fallback_action);
                        _ = try self.execute(&fallback_cmd);
                    },
                }
            }

            steps_executed += 1;
            total_duration += result.duration_ms;
        }

        return PlanExecutionResult{
            .success = failed_at == null,
            .steps_executed = steps_executed,
            .total_duration_ms = total_duration,
            .failed_at = failed_at,
            .error_msg = "",
        };
    }
};

pub const PlanExecutionResult = struct {
    success: bool,
    steps_executed: u8,
    total_duration_ms: u64,
    failed_at: ?u8 = null,
    error_msg: []const u8 = "",
};

pub const ExecutionResult = struct {
    success: bool,
    duration_ms: u64,
    error_msg: []const u8 = "",
    has_output: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Motor — MotorCommand init" {
    const cmd = MotorCommand.init();
    try std.testing.expectEqual(@as(usize, 0), cmd.subcommand_len);
    try std.testing.expectEqual(@as(u8, 0), cmd.arg_count);
}

test "Motor — MotorCommand fromAction" {
    const cmd = MotorCommand.fromAction(.farm_status);
    try std.testing.expectEqualStrings("farm", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
}

test "Motor — MotorExecutor init" {
    const allocator = std.testing.allocator;
    const exec = MotorExecutor.init(allocator);
    // Context has default values (build_ok=false until refreshed)
    try std.testing.expect(exec.context.build_ok == false);
    try std.testing.expect(exec.context.farm_idle_count == 0);
}

test "Motor — MotorCommand toArgv" {
    const allocator = std.testing.allocator;
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0.."farm".len], "farm");
    cmd.subcommand_len = "farm".len;
    @memcpy(cmd.args[0][0.."status".len], "status");
    cmd.arg_lens[0] = "status".len;
    cmd.arg_count = 1;

    const argv = try cmd.toArgv(allocator);
    defer allocator.free(argv);

    try std.testing.expectEqual(@as(usize, 3), argv.len);
    try std.testing.expectEqualStrings("tri", argv[0]);
    try std.testing.expectEqualStrings("farm", argv[1]);
    try std.testing.expectEqualStrings("status", argv[2]);
}

test "Motor — MotorCommand format" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0.."farm".len], "farm");
    cmd.subcommand_len = "farm".len;
    @memcpy(cmd.args[0][0.."status".len], "status");
    cmd.arg_lens[0] = "status".len;
    cmd.arg_count = 1;

    var buf: [128]u8 = undefined;
    const formatted = cmd.format(&buf);
    try std.testing.expectEqualStrings("tri farm status", formatted);
}

test "Motor — MotorCommand fromAction single word" {
    const cmd = MotorCommand.fromAction(.introspection);
    try std.testing.expectEqualStrings("introspection", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 0), cmd.arg_count);
}

test "Motor — MotorCommand fromAction multi word" {
    const cmd = MotorCommand.fromAction(.farm_status);
    try std.testing.expectEqualStrings("farm", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("status", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorExecutor checkCondition build_ok" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.build_ok = true;
    try std.testing.expect(exec.checkCondition(.build_ok));

    exec.context.build_ok = false;
    try std.testing.expect(!exec.checkCondition(.build_ok));
}

test "Motor — MotorExecutor checkCondition tests_pass" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.tests_pass = true;
    try std.testing.expect(exec.checkCondition(.tests_pass));

    exec.context.tests_pass = false;
    try std.testing.expect(!exec.checkCondition(.tests_pass));
}

test "Motor — MotorExecutor checkCondition farm_idle_exists" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.farm_idle_count = 0;
    try std.testing.expect(!exec.checkCondition(.farm_idle_exists));

    exec.context.farm_idle_count = 5;
    try std.testing.expect(exec.checkCondition(.farm_idle_exists));
}

test "Motor — MotorExecutor checkCondition health_critical" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.ouroboros_score = 30.0;
    try std.testing.expect(exec.checkCondition(.health_critical));

    exec.context.ouroboros_score = 70.0;
    try std.testing.expect(!exec.checkCondition(.health_critical));
}

test "Motor — MotorExecutor checkCondition health_good" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.ouroboros_score = 80.0;
    try std.testing.expect(exec.checkCondition(.health_good));

    exec.context.ouroboros_score = 50.0;
    try std.testing.expect(!exec.checkCondition(.health_good));
}

test "Motor — MotorExecutor checkCondition dirty_exists" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.dirty_files = 0;
    try std.testing.expect(!exec.checkCondition(.dirty_exists));

    exec.context.dirty_files = 5;
    try std.testing.expect(exec.checkCondition(.dirty_exists));
}

test "Motor — MotorExecutor checkCondition farm_has_leaders" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.farm_idle_count = 2;
    try std.testing.expect(!exec.checkCondition(.farm_has_leaders));

    exec.context.farm_idle_count = 5;
    try std.testing.expect(exec.checkCondition(.farm_has_leaders));
}

test "Motor — MotorExecutor checkCondition farm_best_ppl_good" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.farm_best_ppl = 15.0;
    try std.testing.expect(!exec.checkCondition(.farm_best_ppl_good));

    exec.context.farm_best_ppl = 8.0;
    try std.testing.expect(exec.checkCondition(.farm_best_ppl_good));
}

test "Motor — MotorExecutor checkCondition arena_stale" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.stale_arena_hours = 10;
    try std.testing.expect(!exec.checkCondition(.arena_stale));

    exec.context.stale_arena_hours = 30;
    try std.testing.expect(exec.checkCondition(.arena_stale));
}

test "Motor — MotorExecutor checkCondition has_uncommitted" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.has_uncommitted = false;
    try std.testing.expect(!exec.checkCondition(.has_uncommitted));

    exec.context.has_uncommitted = true;
    try std.testing.expect(exec.checkCondition(.has_uncommitted));
}

test "Motor — ExecutionResult fields" {
    const result = ExecutionResult{
        .success = true,
        .duration_ms = 1234,
        .error_msg = "",
        .has_output = true,
    };
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u64, 1234), result.duration_ms);
    try std.testing.expect(result.has_output);
}

test "Motor — PlanExecutionResult success" {
    const result = PlanExecutionResult{
        .success = true,
        .steps_executed = 5,
        .total_duration_ms = 1000,
        .failed_at = null,
        .error_msg = "",
    };
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 5), result.steps_executed);
    try std.testing.expect(result.failed_at == null);
}

test "Motor — PlanExecutionResult failure" {
    const result = PlanExecutionResult{
        .success = false,
        .steps_executed = 2,
        .total_duration_ms = 500,
        .failed_at = 2,
        .error_msg = "Command failed",
    };
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u8, 2), result.steps_executed);
    try std.testing.expectEqual(@as(u8, 2), result.failed_at.?);
}

test "Motor — MotorCommand subcommandStr empty" {
    const cmd = MotorCommand.init();
    try std.testing.expectEqual(@as(usize, 0), cmd.subcommand_len);
    try std.testing.expectEqual(@as(usize, 0), cmd.subcommandStr().len);
}

test "Motor — MotorCommand fromAction with single word" {
    const cmd = MotorCommand.fromAction(.introspection);
    try std.testing.expectEqualStrings("introspection", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 0), cmd.arg_count);
}

test "Motor — MotorCommand toArgv with no args" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0..6], "status");
    cmd.subcommand_len = 6;

    const argv = try cmd.toArgv(std.testing.allocator);
    defer std.testing.allocator.free(argv);

    try std.testing.expectEqual(@as(usize, 2), argv.len);
    try std.testing.expectEqualStrings("tri", argv[0]);
    try std.testing.expectEqualStrings("status", argv[1]);
}

test "Motor — MotorCommand toArgv with args" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0..4], "farm");
    cmd.subcommand_len = 4;
    @memcpy(cmd.args[0][0..6], "status");
    cmd.arg_lens[0] = 6;
    cmd.arg_count = 1;

    const argv = try cmd.toArgv(std.testing.allocator);
    defer std.testing.allocator.free(argv);

    try std.testing.expectEqual(@as(usize, 3), argv.len);
    try std.testing.expectEqualStrings("tri", argv[0]);
    try std.testing.expectEqualStrings("farm", argv[1]);
    try std.testing.expectEqualStrings("status", argv[2]);
}

test "Motor — MotorCommand format with args" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0..3], "git");
    cmd.subcommand_len = 3;
    @memcpy(cmd.args[0][0..6], "commit");
    cmd.arg_lens[0] = 6;
    @memcpy(cmd.args[1][0..2], "-m");
    cmd.arg_lens[1] = 2;
    @memcpy(cmd.args[2][0..4], "test");
    cmd.arg_lens[2] = 4;
    cmd.arg_count = 3;

    var buf: [128]u8 = undefined;
    const formatted = cmd.format(&buf);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "git") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "commit") != null);
}

test "Motor — MotorCommand format single word" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0..6], "status");
    cmd.subcommand_len = 6;

    var buf: [64]u8 = undefined;
    const formatted = cmd.format(&buf);

    try std.testing.expectEqualStrings("tri status", formatted);
}

test "Motor — ExecutionResult all fields populated" {
    const result = ExecutionResult{
        .success = true,
        .duration_ms = 100,
        .error_msg = "",
        .has_output = true,
    };

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u64, 100), result.duration_ms);
    try std.testing.expect(result.has_output);
}

test "Motor — ExecutionResult with failure" {
    const result = ExecutionResult{
        .success = false,
        .duration_ms = 50,
        .error_msg = "Command failed",
        .has_output = false,
    };

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u64, 50), result.duration_ms);
}

test "Motor — PlanExecutionResult with no failures" {
    const result = PlanExecutionResult{
        .success = true,
        .steps_executed = 5,
        .total_duration_ms = 1000,
    };

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 5), result.steps_executed);
    try std.testing.expect(result.failed_at == null);
}

test "Motor — PlanExecutionResult zero steps" {
    const result = PlanExecutionResult{
        .success = true,
        .steps_executed = 0,
        .total_duration_ms = 0,
    };

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 0), result.steps_executed);
}

test "Motor — MotorCommand max args" {
    var cmd = MotorCommand.init();
    cmd.arg_count = MAX_CMD_ARGS;

    try std.testing.expectEqual(@as(u8, MAX_CMD_ARGS), cmd.arg_count);
}

test "Motor — MAX_CMD_ARGS and MAX_ARG_LEN constants" {
    try std.testing.expect(MAX_CMD_ARGS > 0);
    try std.testing.expect(MAX_ARG_LEN > 0);
    try std.testing.expect(MAX_ARG_LEN >= 32); // Should fit reasonable args
}

test "Motor — MotorCommand fromAction all action kinds compile" {
    // Just verify that fromAction doesn't crash for various action kinds
    _ = MotorCommand.fromAction(.farm_status);
    _ = MotorCommand.fromAction(.doctor_scan);
    _ = MotorCommand.fromAction(.git_commit_state);
    _ = MotorCommand.fromAction(.introspection);
}

test "Motor — MotorExecutor init creates valid executor" {
    _ = MotorExecutor.init(std.testing.allocator);

    // Just verify it initializes without crashing
}

// ═══════════════════════════════════════════════════════════════════
// MotorCommand EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Motor — MotorCommand getArg returns empty for invalid index" {
    var cmd = MotorCommand.init();
    cmd.arg_count = 0;

    const arg = cmd.args[0][0..0]; // Empty slice
    try std.testing.expectEqual(@as(usize, 0), arg.len);
}

test "Motor — MotorCommand getArg with valid index" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.args[0][0.."test".len], "test");
    cmd.arg_lens[0] = "test".len;
    cmd.arg_count = 1;

    try std.testing.expectEqualStrings("test", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand fromAction cloud_spawn" {
    const cmd = MotorCommand.fromAction(.cloud_spawn);
    try std.testing.expectEqualStrings("cloud", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("spawn", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand fromAction farm_recycle" {
    const cmd = MotorCommand.fromAction(.farm_recycle);
    try std.testing.expectEqualStrings("farm", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("recycle", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand fromAction doctor_quick" {
    const cmd = MotorCommand.fromAction(.doctor_quick);
    try std.testing.expectEqualStrings("doctor", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("quick", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand format with multiple args" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0..4], "farm");
    cmd.subcommand_len = 4;
    @memcpy(cmd.args[0][0..6], "status");
    cmd.arg_lens[0] = 6;
    @memcpy(cmd.args[1][0..6], "--json");
    cmd.arg_lens[1] = 6;
    cmd.arg_count = 2;

    var buf: [128]u8 = undefined;
    const formatted = cmd.format(&buf);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "farm") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "status") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "--json") != null);
}

test "Motor — MotorCommand toArgv max args" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0..3], "cmd");
    cmd.subcommand_len = 3;

    // Fill all args
    var i: u8 = 0;
    while (i < MAX_CMD_ARGS) : (i += 1) {
        @memcpy(cmd.args[i][0..3], "arg");
        cmd.arg_lens[i] = 3;
    }
    cmd.arg_count = MAX_CMD_ARGS;

    const argv = try cmd.toArgv(std.testing.allocator);
    defer std.testing.allocator.free(argv);

    try std.testing.expectEqual(@as(usize, MAX_CMD_ARGS + 2), argv.len);
}

test "Motor — MotorCommand zeros memory on init" {
    const cmd = MotorCommand.init();

    // Subcommand should be zeros
    for (cmd.subcommand) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }

    try std.testing.expectEqual(@as(usize, 0), cmd.subcommand_len);
    try std.testing.expectEqual(@as(u8, 0), cmd.arg_count);
}

test "Motor — MotorCommand subcommandStr with populated command" {
    var cmd = MotorCommand.init();
    @memcpy(cmd.subcommand[0.."doctor".len], "doctor");
    cmd.subcommand_len = "doctor".len;

    try std.testing.expectEqualStrings("doctor", cmd.subcommandStr());
}

// ═══════════════════════════════════════════════════════════════════
// MotorExecutor EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Motor — MotorExecutor context default values" {
    const allocator = std.testing.allocator;
    const exec = MotorExecutor.init(allocator);

    try std.testing.expectEqual(@as(f32, 0.0), exec.context.ouroboros_score);
    try std.testing.expectEqual(@as(u16, 0), exec.context.dirty_files);
    try std.testing.expectEqual(@as(f32, 999.0), exec.context.farm_best_ppl);
    try std.testing.expectEqual(@as(u16, 0), exec.context.stale_arena_hours);
    try std.testing.expect(!exec.context.has_uncommitted);
}

test "Motor — MotorExecutor checkCondition arena_exists" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    exec.context.arena_exists = true;
    try std.testing.expect(exec.checkCondition(.arena_exists));

    exec.context.arena_exists = false;
    try std.testing.expect(!exec.checkCondition(.arena_exists));
}

test "Motor — MotorExecutor checkCondition custom_check returns false" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);
    try std.testing.expect(!exec.checkCondition(.custom_check));
}

test "Motor — MotorExecutor checkCondition boundary values" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);

    // health_critical: exactly 50 should not trigger
    exec.context.ouroboros_score = 50.0;
    try std.testing.expect(!exec.checkCondition(.health_critical));

    // health_good: exactly 70 should trigger
    exec.context.ouroboros_score = 70.0;
    try std.testing.expect(exec.checkCondition(.health_good));

    // arena_stale: exactly 24 should not trigger
    exec.context.stale_arena_hours = 24;
    try std.testing.expect(!exec.checkCondition(.arena_stale));

    // arena_stale: exactly 25 should trigger
    exec.context.stale_arena_hours = 25;
    try std.testing.expect(exec.checkCondition(.arena_stale));
}

test "Motor — MotorExecutor checkCondition farm_idle_exists boundary" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);

    // Exactly 0 should not trigger
    exec.context.farm_idle_count = 0;
    try std.testing.expect(!exec.checkCondition(.farm_idle_exists));

    // Exactly 1 should trigger
    exec.context.farm_idle_count = 1;
    try std.testing.expect(exec.checkCondition(.farm_idle_exists));
}

test "Motor — MotorExecutor checkCondition dirty_exists boundary" {
    const allocator = std.testing.allocator;
    var exec = MotorExecutor.init(allocator);

    // Exactly 0 should not trigger
    exec.context.dirty_files = 0;
    try std.testing.expect(!exec.checkCondition(.dirty_exists));

    // Exactly 1 should trigger
    exec.context.dirty_files = 1;
    try std.testing.expect(exec.checkCondition(.dirty_exists));
}

// ═══════════════════════════════════════════════════════════════════
// ExecutionResult EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Motor — ExecutionResult default values" {
    const result = ExecutionResult{
        .success = false,
        .duration_ms = 0,
        .error_msg = &.{},
        .has_output = false,
    };

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u64, 0), result.duration_ms);
    try std.testing.expectEqual(@as(usize, 0), result.error_msg.len);
    try std.testing.expect(!result.has_output);
}

test "Motor — ExecutionResult with error message" {
    const result = ExecutionResult{
        .success = false,
        .duration_ms = 100,
        .error_msg = "Build failed",
        .has_output = false,
    };

    try std.testing.expectEqualStrings("Build failed", result.error_msg);
}

test "Motor — ExecutionResult duration_ms max value" {
    const result = ExecutionResult{
        .success = true,
        .duration_ms = 999999,
        .error_msg = "",
        .has_output = false,
    };

    try std.testing.expectEqual(@as(u64, 999999), result.duration_ms);
}

// ═══════════════════════════════════════════════════════════════════
// PlanExecutionResult EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Motor — PlanExecutionResult with error message" {
    const result = PlanExecutionResult{
        .success = false,
        .steps_executed = 3,
        .total_duration_ms = 500,
        .failed_at = 2,
        .error_msg = "Step 2 failed",
    };

    try std.testing.expectEqualStrings("Step 2 failed", result.error_msg);
}

test "Motor — PlanExecutionResult partial success" {
    const result = PlanExecutionResult{
        .success = false,
        .steps_executed = 3,
        .total_duration_ms = 300,
        .failed_at = 3,
        .error_msg = "",
    };

    try std.testing.expectEqual(@as(u8, 3), result.steps_executed);
    try std.testing.expectEqual(@as(u8, 3), result.failed_at.?);
}

test "Motor — PlanExecutionResult total_duration_ms accumulation" {
    var result = PlanExecutionResult{
        .success = true,
        .steps_executed = 5,
        .total_duration_ms = 0,
    };

    try std.testing.expectEqual(@as(u64, 0), result.total_duration_ms);

    result.total_duration_ms = 5000;
    try std.testing.expectEqual(@as(u64, 5000), result.total_duration_ms);
}

test "Motor — PlanExecutionResult failed_at optional handling" {
    const success_result = PlanExecutionResult{
        .success = true,
        .steps_executed = 5,
        .total_duration_ms = 1000,
        .failed_at = null,
    };

    try std.testing.expect(success_result.failed_at == null);

    const fail_result = PlanExecutionResult{
        .success = false,
        .steps_executed = 2,
        .total_duration_ms = 200,
        .failed_at = 1,
    };

    try std.testing.expectEqual(@as(u8, 1), fail_result.failed_at.?);
}

test "Motor — PlanExecutionResult steps_executed max value" {
    const result = PlanExecutionResult{
        .success = true,
        .steps_executed = 255,
        .total_duration_ms = 10000,
    };

    try std.testing.expectEqual(@as(u8, 255), result.steps_executed);
}

test "Motor — MotorCommand subcommand buffer size" {
    try std.testing.expect(@as(usize, 32) >= @as(usize, "introspection".len));
    try std.testing.expect(@as(usize, 32) >= @as(usize, "git_commit_state".len));
}

test "Motor — MotorCommand arg buffer size" {
    try std.testing.expect(MAX_ARG_LEN >= 32); // Should fit reasonable args
    try std.testing.expect(MAX_ARG_LEN >= 64); // Should fit longer args too
}

test "Motor — MotorCommand fromAction notify" {
    const cmd = MotorCommand.fromAction(.notify);
    try std.testing.expectEqualStrings("notify", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 0), cmd.arg_count);
}

test "Motor — MotorCommand fromAction issue_comment" {
    const cmd = MotorCommand.fromAction(.issue_comment);
    try std.testing.expectEqualStrings("issue", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("comment", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand fromAction ouroboros_cycle" {
    const cmd = MotorCommand.fromAction(.ouroboros_cycle);
    try std.testing.expectEqualStrings("ouroboros", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("cycle", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Motor — MotorCommand fromAction all single word actions" {
    const single_actions = [_]qt.ActionKind{
        .introspection,
        .notify,
        .farm_status,
    };

    for (single_actions) |action| {
        const cmd = MotorCommand.fromAction(action);
        try std.testing.expect(cmd.arg_count == 0);
        try std.testing.expect(cmd.subcommand_len > 0);
    }
}
