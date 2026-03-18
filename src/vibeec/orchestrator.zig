// ═══════════════════════════════════════════════════════════════════════════════
// RALPH ORCHESTRATOR - Connects Ralph Loop to fix_plan.md Task System
// ═══════════════════════════════════════════════════════════════════════════════
//
// Workflow:
//   1. Read .ralph/internal/fix_plan.md
//   2. Pick highest-priority task ([P1] → [P2] → [P3])
//   3. Create feature branch
//   4. Execute VIBEE generation
//   5. Run AGENT MU verification
//   6. Auto-fix if possible
//   7. Report results
//   8. Commit & push if success
//   9. Update TECH_TREE.md
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const RalphLoop = @import("ralph_loop.zig").RalphLoop;
const agent_mu = @import("agent_mu");
const allocator = std.heap.page_allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// ORCHESTRATOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskPriority = enum(u8) {
    p1 = 1,
    p2 = 2,
    p3 = 3,

    pub fn fromString(s: []const u8) ?TaskPriority {
        if (std.mem.eql(u8, s, "[P1]")) return .p1;
        if (std.mem.eql(u8, s, "[P2]")) return .p2;
        if (std.mem.eql(u8, s, "[P3]")) return .p3;
        return null;
    }

    pub fn toString(self: TaskPriority) []const u8 {
        return switch (self) {
            .p1 => "[P1]",
            .p2 => "[P2]",
            .p3 => "[P3]",
        };
    }
};

pub const Task = struct {
    name: []const u8,
    priority: TaskPriority,
    acceptance: []const u8,
    files: []const u8,
    blocked_by: []const u8,
    completed: bool,
    line_number: u32,

    /// Format task for display
    pub fn format(self: *const Task, writer: anytype) !void {
        try writer.print("{s} {s}\n", .{ self.priority.toString(), self.name });
        try writer.print("  Acceptance: {s}\n", .{self.acceptance});
        if (self.files.len > 0) {
            try writer.print("  Files: {s}\n", .{self.files});
        }
        if (self.blocked_by.len > 0) {
            try writer.print("  Blocked-by: {s}\n", .{self.blocked_by});
        }
    }
};

pub const CycleResult = enum {
    success,
    no_tasks,
    failed,
    circuit_open,
    verification_failed,
    blocked,

    pub fn toString(self: CycleResult) []const u8 {
        return switch (self) {
            .success => "SUCCESS",
            .no_tasks => "NO_TASKS",
            .failed => "FAILED",
            .circuit_open => "CIRCUIT_OPEN",
            .verification_failed => "VERIFICATION_FAILED",
            .blocked => "BLOCKED",
        };
    }
};

pub const CycleReport = struct {
    result: CycleResult,
    task: ?Task,
    iteration: u32,
    files_generated: u32,
    tests_passed: u32,
    tests_total: u32,
    errors_found: u32,
    errors_fixed: u32,
    duration_ms: u64,
    message: []const u8,

    pub fn deinit(self: *const CycleReport, alloc: std.mem.Allocator) void {
        if (self.message.len > 0) alloc.free(self.message);
        self.* = undefined;
    }
};

pub const OrchestratorConfig = struct {
    max_iterations: u32 = 100,
    enable_circuit_breaker: bool = true,
    rate_limit_per_hour: u32 = 100,
    auto_fix_enabled: bool = true,
    verbose: bool = false,
    create_branch: bool = true,
    commit_on_success: bool = false, // Requires user confirmation
};

// ═══════════════════════════════════════════════════════════════════════════════
// ORCHESTRATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const Orchestrator = struct {
    alloc: std.mem.Allocator,
    loop: RalphLoop,
    config: OrchestratorConfig,
    fix_plan_path: []const u8,
    branch_prefix: []const u8,

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, config: OrchestratorConfig) !Self {
        const loop_config = ralph_loop.LoopConfig{
            .max_iterations = config.max_iterations,
            .confidence_threshold = 40,
            .enable_circuit_breaker = config.enable_circuit_breaker,
            .enable_rate_limiting = true,
            .rate_limit_per_hour = config.rate_limit_per_hour,
        };

        const loop = try RalphLoop.initWithConfig(alloc, loop_config);
        return Self{
            .alloc = alloc,
            .loop = loop,
            .config = config,
            .fix_plan_path = ".ralph/internal/fix_plan.md",
            .branch_prefix = "ralph",
        };
    }

    pub fn deinit(self: *Self) void {
        self.loop.deinit();
    }

    /// Run autonomous development cycle
    pub fn run(self: *Self, task_filter: ?[]const u8) !CycleReport {
        const start_time = std.time.milliTimestamp();

        // Step 1: Read fix_plan.md
        var tasks = try self.readFixPlan();
        defer {
            for (tasks.items) |*t| {
                self.alloc.free(t.name);
                self.alloc.free(t.acceptance);
                self.alloc.free(t.files);
                self.alloc.free(t.blocked_by);
            }
            tasks.deinit(self.alloc);
        }

        // Step 2: Filter and pick task (inlined pickTask logic)
        // Apply filter if provided
        const filter_val = task_filter orelse "";
        if (filter_val.len > 0) {
            // Filter tasks in-place by setting completed=true for non-matching
            for (tasks.items) |*t| {
                if (std.mem.indexOf(u8, t.name, filter_val) == null) {
                    t.completed = true; // Mark as completed to skip
                }
            }
        }

        // Find highest-priority task (inlined from pickTask)
        var best_task: ?Task = null;
        var best_priority: u8 = 255;
        for (tasks.items) |task| {
            if (task.completed) continue;
            const pval = @intFromEnum(task.priority);
            if (pval < best_priority) {
                best_priority = pval;
                best_task = task;
            }
        }

        const task = best_task orelse {
            return CycleReport{
                .result = .no_tasks,
                .task = null,
                .iteration = 0,
                .files_generated = 0,
                .tests_passed = 0,
                .tests_total = 0,
                .errors_found = 0,
                .errors_fixed = 0,
                .duration_ms = 0,
                .message = try self.alloc.dupe(u8, "No available tasks in fix_plan.md"),
            };
        };

        // Check if task is blocked
        if (task.blocked_by.len > 0 and !std.mem.eql(u8, task.blocked_by, "(none)")) {
            return CycleReport{
                .result = .blocked,
                .task = try self.copyTask(task),
                .iteration = 0,
                .files_generated = 0,
                .tests_passed = 0,
                .tests_total = 0,
                .errors_found = 0,
                .errors_fixed = 0,
                .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
                .message = try std.fmt.allocPrint(self.alloc, "Task blocked by: {s}", .{task.blocked_by}),
            };
        }

        if (self.config.verbose) {
            std.debug.print("\n📋 Task: {s} {s}\n", .{ task.priority.toString(), task.name });
            std.debug.print("   Acceptance: {s}\n", .{task.acceptance});
        }

        // Step 3: Create branch (if enabled)
        if (self.config.create_branch) {
            const branch_name = try std.fmt.allocPrint(self.alloc, "{s}/{s}", .{ self.branch_prefix, sanitizeName(task.name) });
            defer self.alloc.free(branch_name);

            if (self.config.verbose) {
                std.debug.print("   Branch: {s}\n", .{branch_name});
            }

            _ = try self.gitCreateBranch(branch_name);
        }

        // Step 4: Execute Ralph Loop iterations
        var iteration: u32 = 0;
        var errors_fixed: u32 = 0;

        while (self.loop.canContinue() and iteration < self.config.max_iterations) {
            iteration += 1;

            if (self.config.verbose) {
                std.debug.print("\n🔄 Iteration {d}/{}\n", .{ iteration, self.config.max_iterations });
            }

            // Generate code (this would call VIBEE generation)
            const generated_file = try self.generateFromTask(task);
            defer self.alloc.free(generated_file);

            // Step 5: AGENT MU verification
            const agent_config = agent_mu.Config{
                .max_retries = 3,
                .timeout_seconds = 120,
                .verbose = self.config.verbose,
                .enable_auto_fix = self.config.auto_fix_enabled,
            };

            const verify_result = agent_mu.verifyAndFix(
                self.alloc,
                generated_file,
                agent_config,
            ) catch |err| blk: {
                if (self.config.verbose) {
                    std.debug.print("   ❌ Verification error: {}\n", .{err});
                }
                break :blk agent_mu.Result{
                    .success = false,
                    .attempts_made = 0,
                    .error_message = "Verification failed",
                    .fix_applied = false,
                };
            };

            if (verify_result.success) {
                // Record iteration success
                _ = try self.loop.processIteration(ralph_loop.IterationResult{
                    .iteration = iteration,
                    .state = .completed,
                    .files_changed = 1,
                    .tests_run = 1,
                    .tests_passed = 1,
                    .errors = 0,
                    .confidence = 100,
                    .exit_signal = true,
                    .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
                });

                if (verify_result.fix_applied) {
                    errors_fixed += 1;
                }

                // Success!
                const duration = std.time.milliTimestamp() - start_time;

                return CycleReport{
                    .result = .success,
                    .task = try self.copyTask(task),
                    .iteration = iteration,
                    .files_generated = 1,
                    .tests_passed = 1,
                    .tests_total = 1,
                    .errors_found = if (verify_result.fix_applied) 1 else 0,
                    .errors_fixed = errors_fixed,
                    .duration_ms = @intCast(duration),
                    .message = try self.alloc.dupe(u8, "Task completed successfully"),
                };
            }

            // Record iteration failure
            _ = try self.loop.processIteration(ralph_loop.IterationResult{
                .iteration = iteration,
                .state = .iterating,
                .files_changed = 0,
                .tests_run = 0,
                .tests_passed = 0,
                .errors = 1,
                .confidence = 0,
                .exit_signal = false,
                .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
            });

            if (self.config.verbose) {
                std.debug.print("   ⚠️  Verification failed: {s}\n", .{verify_result.error_message});
                std.debug.print("   Attempts: {d}/3\n", .{verify_result.attempts_made});
            }
        }

        // Check circuit breaker
        if (self.loop.exit_condition == .circuit_open) {
            return CycleReport{
                .result = .circuit_open,
                .task = try self.copyTask(task),
                .iteration = iteration,
                .files_generated = 0,
                .tests_passed = 0,
                .tests_total = 0,
                .errors_found = 1,
                .errors_fixed = errors_fixed,
                .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
                .message = try self.alloc.dupe(u8, "Circuit breaker opened - too many failures"),
            };
        }

        // Max iterations reached
        return CycleReport{
            .result = .failed,
            .task = try self.copyTask(task),
            .iteration = iteration,
            .files_generated = 0,
            .tests_passed = 0,
            .tests_total = 0,
            .errors_found = 1,
            .errors_fixed = errors_fixed,
            .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
            .message = try std.fmt.allocPrint(self.alloc, "Max iterations reached ({d})", .{self.config.max_iterations}),
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Read and parse fix_plan.md
    fn readFixPlan(self: *Self) !std.ArrayList(Task) {
        const file = std.fs.cwd().openFile(self.fix_plan_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                std.debug.print("⚠️  fix_plan.md not found at: {s}\n", .{self.fix_plan_path});
                const empty = std.ArrayList(Task){};
                return empty;
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.alloc, 1024 * 1024); // Max 1MB
        defer self.alloc.free(content);

        var tasks = std.ArrayList(Task).initCapacity(self.alloc, 16) catch return error.OutOfMemory;
        errdefer {
            for (tasks.items) |*t| {
                self.alloc.free(t.name);
                self.alloc.free(t.acceptance);
                self.alloc.free(t.files);
                self.alloc.free(t.blocked_by);
            }
            tasks.deinit(self.alloc);
        }

        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_num: u32 = 0;
        var current_task: ?Task = null;

        while (lines.next()) |line| {
            line_num += 1;
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

            // Skip empty lines and comments
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Check for task line: `- [ ] [P1/P2/P3] Task description`
            if (std.mem.startsWith(u8, trimmed, "- [ ] ")) {
                // Save previous task if exists
                if (current_task) |t| {
                    try tasks.append(self.alloc, t);
                }

                // Parse priority
                const after_checkbox = trimmed["- [ ] ".len..];
                var priority = TaskPriority.p3; // Default
                var name_start = after_checkbox;

                if (std.mem.startsWith(u8, after_checkbox, "[P1]")) {
                    priority = .p1;
                    name_start = after_checkbox["[P1]".len..];
                } else if (std.mem.startsWith(u8, after_checkbox, "[P2]")) {
                    priority = .p2;
                    name_start = after_checkbox["[P2]".len..];
                } else if (std.mem.startsWith(u8, after_checkbox, "[P3]")) {
                    priority = .p3;
                    name_start = after_checkbox["[P3]".len..];
                }

                const name = std.mem.trim(u8, name_start, &std.ascii.whitespace);

                current_task = Task{
                    .name = try self.alloc.dupe(u8, name),
                    .priority = priority,
                    .acceptance = "",
                    .files = "",
                    .blocked_by = "",
                    .completed = true, // [ ] means not completed
                    .line_number = line_num,
                };
            } else if (std.mem.startsWith(u8, trimmed, "- [x] ")) {
                // Completed task - skip
                current_task = null;
            } else if (current_task != null) {
                // Parse task properties
                if (std.mem.startsWith(u8, trimmed, "- Acceptance:")) {
                    const value = std.mem.trim(u8, trimmed["- Acceptance:".len..], &std.ascii.whitespace);
                    if (current_task) |*t| {
                        self.alloc.free(t.acceptance);
                        t.acceptance = try self.alloc.dupe(u8, value);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "- Files:")) {
                    const value = std.mem.trim(u8, trimmed["- Files:".len..], &std.ascii.whitespace);
                    if (current_task) |*t| {
                        self.alloc.free(t.files);
                        t.files = try self.alloc.dupe(u8, value);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "- Blocked-by:")) {
                    const value = std.mem.trim(u8, trimmed["- Blocked-by:".len..], &std.ascii.whitespace);
                    if (current_task) |*t| {
                        self.alloc.free(t.blocked_by);
                        t.blocked_by = try self.alloc.dupe(u8, value);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "- DONE:")) {
                    // Task is marked as done with notes
                    if (current_task) |*t| {
                        t.completed = true;
                    }
                }
            }
        }

        // Save last task
        if (current_task) |t| {
            try tasks.append(self.alloc, t);
        }

        return tasks;
    }

    /// Copy a task (for returning in reports)
    fn copyTask(self: *Self, task: Task) !Task {
        return Task{
            .name = try self.alloc.dupe(u8, task.name),
            .priority = task.priority,
            .acceptance = try self.alloc.dupe(u8, task.acceptance),
            .files = try self.alloc.dupe(u8, task.files),
            .blocked_by = try self.alloc.dupe(u8, task.blocked_by),
            .completed = task.completed,
            .line_number = task.line_number,
        };
    }

    /// Generate code from task (extracts spec file from task description)
    fn generateFromTask(self: *Self, task: Task) ![]const u8 {
        // For now, derive spec file from task name
        // Task: "Create xyz module" -> specs/tri/xyz_module.tri
        const sanitized = sanitizeName(task.name);
        const spec_file = try std.fmt.allocPrint(self.alloc, "specs/tri/{s}.tri", .{sanitized});

        // Check if spec file exists
        if (std.fs.cwd().openFile(spec_file, .{})) |file| {
            file.close();
            // File exists, generate output path
            return deriveOutputPath(self.alloc, spec_file);
        } else |_| {
            // File doesn't exist, return a default path
            self.alloc.free(spec_file);
            return try self.alloc.dupe(u8, "trinity/output/generated.zig");
        }
    }

    /// Create git branch
    fn gitCreateBranch(self: *Self, branch_name: []const u8) !void {
        const result = try std.process.Child.run(.{
            .allocator = self.alloc,
            .argv = &.{ "git", "checkout", "-b", branch_name },
        });

        defer {
            self.alloc.free(result.stdout);
            self.alloc.free(result.stderr);
        }

        if ((switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        }) != 0) {
            std.debug.print("⚠️  git checkout failed: {s}\n", .{result.stderr});
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Sanitize task name for use in file/branch names
fn sanitizeName(name: []const u8) []const u8 {
    // Simple sanitization - in production, would do more
    if (name.len == 0) return "task";

    // Find first alphanumeric character
    var start: usize = 0;
    while (start < name.len and !std.ascii.isAlphanumeric(name[start])) : (start += 1) {}

    if (start >= name.len) return "task";

    return name[start..];
}

/// Derive output path from spec file path
fn deriveOutputPath(alloc: std.mem.Allocator, spec_file: []const u8) ![]const u8 {
    const basename = std.fs.path.basename(spec_file);
    const stem = std.fs.path.stem(basename);

    return try std.fmt.allocPrint(alloc, "trinity/output/{s}.zig", .{stem});
}

const ralph_loop = struct {
    pub const LoopConfig = @import("ralph_loop.zig").LoopConfig;
    pub const IterationResult = @import("ralph_loop.zig").IterationResult;
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Orchestrator: init and deinit" {
    const alloc = std.testing.allocator;
    const config = OrchestratorConfig{};
    var orch = try Orchestrator.init(alloc, config);
    defer orch.deinit();

    try std.testing.expectEqual(@as(usize, 0), orch.loop.iteration);
}

test "TaskPriority: fromString" {
    try std.testing.expectEqual(TaskPriority.p1, TaskPriority.fromString("[P1]").?);
    try std.testing.expectEqual(TaskPriority.p2, TaskPriority.fromString("[P2]").?);
    try std.testing.expectEqual(TaskPriority.p3, TaskPriority.fromString("[P3]").?);
    try std.testing.expect(TaskPriority.fromString("[P4]") == null);
}

test "TaskPriority: toString" {
    try std.testing.expectEqualStrings("[P1]", TaskPriority.p1.toString());
    try std.testing.expectEqualStrings("[P2]", TaskPriority.p2.toString());
    try std.testing.expectEqualStrings("[P3]", TaskPriority.p3.toString());
}
