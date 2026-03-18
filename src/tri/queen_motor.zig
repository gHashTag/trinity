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

    /// Get stale arena hours (simplified - just returns 0 for now)
    fn checkStaleArenaHours(self: *MotorExecutor) !u16 {
        _ = self;
        // TODO: Parse actual timestamp from arena status
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
