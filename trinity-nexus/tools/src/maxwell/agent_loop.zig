// Maxwell Daemon - Agent Loop
// Основной цикл автономного агента
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const codebase = @import("codebase.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const DaemonStatus = enum {
    Idle,
    Working,
    Error,
    Stopped,
};

pub const TaskType = enum {
    Feature,
    Bugfix,
    Refactor,
    Test,
    Optimize,
    SelfImprove,
};

pub const TaskStatus = enum {
    Pending,
    InProgress,
    Completed,
    Failed,
};

pub const Task = struct {
    id: u64,
    description: []const u8,
    priority: u8, // 1-10
    task_type: TaskType,
    target_files: std.ArrayList([]const u8),
    constraints: std.ArrayList([]const u8),
    status: TaskStatus,
    result: ?TaskResult,
    created_at: i64,
    started_at: ?i64,
    completed_at: ?i64,

    pub fn init(allocator: std.mem.Allocator, id: u64, description: []const u8, task_type: TaskType) Task {
        return Task{
            .id = id,
            .description = description,
            .priority = 5,
            .task_type = task_type,
            .target_files = std.ArrayList([]const u8).init(allocator),
            .constraints = std.ArrayList([]const u8).init(allocator),
            .status = .Pending,
            .result = null,
            .created_at = std.time.timestamp(),
            .started_at = null,
            .completed_at = null,
        };
    }

    pub fn deinit(self: *Task) void {
        self.target_files.deinit();
        self.constraints.deinit();
    }
};

pub const TaskResult = struct {
    success: bool,
    files_created: std.ArrayList([]const u8),
    files_modified: std.ArrayList([]const u8),
    tests_passed: u32,
    tests_failed: u32,
    error_message: ?[]const u8,
    duration_ms: u64,

    pub fn init(allocator: std.mem.Allocator) TaskResult {
        return TaskResult{
            .success = false,
            .files_created = std.ArrayList([]const u8).init(allocator),
            .files_modified = std.ArrayList([]const u8).init(allocator),
            .tests_passed = 0,
            .tests_failed = 0,
            .error_message = null,
            .duration_ms = 0,
        };
    }

    pub fn deinit(self: *TaskResult) void {
        self.files_created.deinit();
        self.files_modified.deinit();
    }
};

pub const DaemonState = struct {
    status: DaemonStatus,
    current_task: ?*Task,
    tasks_completed: u64,
    tasks_failed: u64,
    start_time: i64,
    last_activity: i64,
};

pub const DaemonConfig = struct {
    llm_api_key: []const u8,
    llm_model: []const u8,
    max_concurrent_tasks: u32,
    auto_commit: bool,
    safety_mode: SafetyMode,
    working_directory: []const u8,
    log_level: LogLevel,
    poll_interval_ms: u64,

    pub const SafetyMode = enum {
        Strict, // Требует подтверждения для каждого действия
        Normal, // Автоматически, но с ограничениями
        Permissive, // Минимальные ограничения
    };

    pub const LogLevel = enum {
        Debug,
        Info,
        Warn,
        Error,
    };

    pub fn default() DaemonConfig {
        return DaemonConfig{
            .llm_api_key = "",
            .llm_model = "claude-3-opus",
            .max_concurrent_tasks = 1,
            .auto_commit = false,
            .safety_mode = .Normal,
            .working_directory = ".",
            .log_level = .Info,
            .poll_interval_ms = 1000,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT LOOP
// ═══════════════════════════════════════════════════════════════════════════════

pub const AgentLoop = struct {
    allocator: std.mem.Allocator,
    config: DaemonConfig,
    state: DaemonState,
    codebase_interface: codebase.Codebase,
    
    // Task queue (priority queue)
    task_queue: std.PriorityQueue(*Task, void, taskCompare),
    
    // Event handlers
    on_task_start: ?*const fn (*Task) void,
    on_task_complete: ?*const fn (*Task, *TaskResult) void,
    on_error: ?*const fn ([]const u8) void,
    
    // Thread for async operation
    running: std.atomic.Value(bool),
    thread: ?std.Thread,

    fn taskCompare(_: void, a: *Task, b: *Task) std.math.Order {
        // Higher priority first
        if (a.priority > b.priority) return .lt;
        if (a.priority < b.priority) return .gt;
        // Earlier created first
        if (a.created_at < b.created_at) return .lt;
        if (a.created_at > b.created_at) return .gt;
        return .eq;
    }

    pub fn init(allocator: std.mem.Allocator, config: DaemonConfig) AgentLoop {
        return AgentLoop{
            .allocator = allocator,
            .config = config,
            .state = DaemonState{
                .status = .Idle,
                .current_task = null,
                .tasks_completed = 0,
                .tasks_failed = 0,
                .start_time = std.time.timestamp(),
                .last_activity = std.time.timestamp(),
            },
            .codebase_interface = codebase.Codebase.init(allocator, config.working_directory),
            .task_queue = std.PriorityQueue(*Task, void, taskCompare).init(allocator, {}),
            .on_task_start = null,
            .on_task_complete = null,
            .on_error = null,
            .running = std.atomic.Value(bool).init(false),
            .thread = null,
        };
    }

    pub fn deinit(self: *AgentLoop) void {
        self.stop();
        self.codebase_interface.deinit();
        
        while (self.task_queue.removeOrNull()) |task| {
            task.deinit();
            self.allocator.destroy(task);
        }
        self.task_queue.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Запустить демона в фоновом режиме
    pub fn start(self: *AgentLoop) !void {
        if (self.running.load(.seq_cst)) return;
        
        self.running.store(true, .seq_cst);
        self.state.status = .Idle;
        self.state.start_time = std.time.timestamp();
        
        self.log(.Info, "Maxwell Daemon starting...");
        
        self.thread = try std.Thread.spawn(.{}, runLoop, .{self});
    }

    /// Остановить демона
    pub fn stop(self: *AgentLoop) void {
        if (!self.running.load(.seq_cst)) return;
        
        self.log(.Info, "Maxwell Daemon stopping...");
        self.running.store(false, .seq_cst);
        
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
        
        self.state.status = .Stopped;
    }

    /// Запустить один цикл (для тестирования)
    pub fn step(self: *AgentLoop) !void {
        try self.processNextTask();
    }

    /// Основной цикл демона
    fn runLoop(self: *AgentLoop) void {
        while (self.running.load(.seq_cst)) {
            self.processNextTask() catch |err| {
                self.state.status = .Error;
                self.log(.Error, @errorName(err));
                if (self.on_error) |handler| {
                    handler(@errorName(err));
                }
            };
            
            std.time.sleep(self.config.poll_interval_ms * std.time.ns_per_ms);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TASK MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Добавить задачу в очередь
    pub fn submitTask(self: *AgentLoop, description: []const u8, task_type: TaskType) !u64 {
        const task = try self.allocator.create(Task);
        const id = @as(u64, @intCast(std.time.timestamp())) ^ @as(u64, @intFromPtr(task));
        
        task.* = Task.init(self.allocator, id, description, task_type);
        try self.task_queue.add(task);
        
        self.log(.Info, "Task submitted");
        return id;
    }

    /// Добавить задачу с приоритетом
    pub fn submitTaskWithPriority(self: *AgentLoop, description: []const u8, task_type: TaskType, priority: u8) !u64 {
        const task = try self.allocator.create(Task);
        const id = @as(u64, @intCast(std.time.timestamp())) ^ @as(u64, @intFromPtr(task));
        
        task.* = Task.init(self.allocator, id, description, task_type);
        task.priority = @min(priority, 10);
        try self.task_queue.add(task);
        
        return id;
    }

    /// Обработать следующую задачу
    fn processNextTask(self: *AgentLoop) !void {
        if (self.state.current_task != null) return; // Already working
        
        const task = self.task_queue.removeOrNull() orelse {
            self.state.status = .Idle;
            return;
        };
        
        self.state.status = .Working;
        self.state.current_task = task;
        self.state.last_activity = std.time.timestamp();
        
        task.status = .InProgress;
        task.started_at = std.time.timestamp();
        
        if (self.on_task_start) |handler| {
            handler(task);
        }
        
        // Execute task
        var result = TaskResult.init(self.allocator);
        const start_time = std.time.milliTimestamp();
        
        self.executeTask(task, &result) catch |err| {
            result.success = false;
            result.error_message = @errorName(err);
            self.state.tasks_failed += 1;
        };
        
        result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);
        
        if (result.success) {
            self.state.tasks_completed += 1;
            task.status = .Completed;
        } else {
            self.state.tasks_failed += 1;
            task.status = .Failed;
        }
        
        task.completed_at = std.time.timestamp();
        task.result = result;
        
        if (self.on_task_complete) |handler| {
            handler(task, &result);
        }
        
        self.state.current_task = null;
        self.state.status = .Idle;
    }

    /// Выполнить задачу
    fn executeTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        self.log(.Info, "Executing task");
        
        switch (task.task_type) {
            .Feature => try self.executeFeatureTask(task, result),
            .Bugfix => try self.executeBugfixTask(task, result),
            .Refactor => try self.executeRefactorTask(task, result),
            .Test => try self.executeTestTask(task, result),
            .Optimize => try self.executeOptimizeTask(task, result),
            .SelfImprove => try self.executeSelfImproveTask(task, result),
        }
    }

    fn executeFeatureTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        // 1. Analyze codebase
        self.log(.Debug, "Analyzing codebase...");
        
        // 2. Generate .vibee spec
        const spec_path = try self.generateSpec(task);
        try result.files_created.append(spec_path);
        
        // 3. Run vibee gen
        const gen_result = self.codebase_interface.runVibeeGen(spec_path);
        if (gen_result.exit_code != 0) {
            result.error_message = gen_result.stderr;
            return;
        }
        
        // 4. Run tests
        const test_result = try self.runTests(task);
        result.tests_passed = test_result.passed;
        result.tests_failed = test_result.failed;
        
        result.success = test_result.failed == 0;
    }

    fn executeBugfixTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        _ = self;
        _ = task;
        result.success = true;
        // TODO: Implement bugfix logic
    }

    fn executeRefactorTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        _ = self;
        _ = task;
        result.success = true;
        // TODO: Implement refactor logic
    }

    fn executeTestTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        const test_result = try self.runTests(task);
        result.tests_passed = test_result.passed;
        result.tests_failed = test_result.failed;
        result.success = true;
    }

    fn executeOptimizeTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        _ = self;
        _ = task;
        result.success = true;
        // TODO: Implement optimize logic
    }

    fn executeSelfImproveTask(self: *AgentLoop, task: *Task, result: *TaskResult) !void {
        _ = self;
        _ = task;
        result.success = true;
        // TODO: Implement self-improvement logic
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn generateSpec(self: *AgentLoop, task: *Task) ![]const u8 {
        _ = task;
        // TODO: Use LLM to generate spec
        const spec_content =
            \\name: generated_feature
            \\version: "1.0.0"
            \\language: zig
            \\module: generated_feature
            \\
            \\types:
            \\  Result:
            \\    fields:
            \\      value: Int
            \\
            \\behaviors:
            \\  - name: process
            \\    given: Input
            \\    when: Called
            \\    then: Returns Result
        ;
        
        const spec_path = "specs/tri/generated_feature.vibee";
        _ = self.codebase_interface.writeFile(spec_path, spec_content);
        
        return spec_path;
    }

    const TestResult = struct {
        passed: u32,
        failed: u32,
    };

    fn runTests(self: *AgentLoop, task: *Task) !TestResult {
        var passed: u32 = 0;
        var failed: u32 = 0;
        
        for (task.target_files.items) |file| {
            if (std.mem.endsWith(u8, file, ".zig")) {
                const result = self.codebase_interface.runTests(file);
                if (result.exit_code == 0) {
                    passed += 1;
                } else {
                    failed += 1;
                }
            }
        }
        
        // If no specific files, run all tests
        if (task.target_files.items.len == 0) {
            const result = self.codebase_interface.exec("zig", &[_][]const u8{ "build", "test" });
            if (result.exit_code == 0) {
                passed = 1;
            } else {
                failed = 1;
            }
        }
        
        return TestResult{ .passed = passed, .failed = failed };
    }

    fn log(self: *AgentLoop, level: DaemonConfig.LogLevel, message: []const u8) void {
        if (@intFromEnum(level) < @intFromEnum(self.config.log_level)) return;
        
        const level_str = switch (level) {
            .Debug => "DEBUG",
            .Info => "INFO",
            .Warn => "WARN",
            .Error => "ERROR",
        };
        
        std.debug.print("[MAXWELL] [{s}] {s}\n", .{ level_str, message });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATUS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getState(self: *AgentLoop) DaemonState {
        return self.state;
    }

    pub fn getQueueLength(self: *AgentLoop) usize {
        return self.task_queue.count();
    }

    pub fn getUptime(self: *AgentLoop) i64 {
        return std.time.timestamp() - self.state.start_time;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AgentLoop init and deinit" {
    var config = DaemonConfig.default();
    config.working_directory = "/tmp";
    
    var agent = AgentLoop.init(std.testing.allocator, config);
    defer agent.deinit();
    
    try std.testing.expectEqual(DaemonStatus.Idle, agent.state.status);
}

test "AgentLoop submit task" {
    var config = DaemonConfig.default();
    config.working_directory = "/tmp";
    
    var agent = AgentLoop.init(std.testing.allocator, config);
    defer agent.deinit();
    
    const id = try agent.submitTask("Test task", .Feature);
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(@as(usize, 1), agent.getQueueLength());
}

test "AgentLoop priority queue" {
    var config = DaemonConfig.default();
    config.working_directory = "/tmp";
    
    var agent = AgentLoop.init(std.testing.allocator, config);
    defer agent.deinit();
    
    _ = try agent.submitTaskWithPriority("Low priority", .Feature, 1);
    _ = try agent.submitTaskWithPriority("High priority", .Feature, 10);
    _ = try agent.submitTaskWithPriority("Medium priority", .Feature, 5);
    
    try std.testing.expectEqual(@as(usize, 3), agent.getQueueLength());
    
    // High priority should be first
    const first = agent.task_queue.peek().?;
    try std.testing.expectEqual(@as(u8, 10), first.priority);
}
