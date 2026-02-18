// Maxwell Daemon - Main Module
// Автономный агент-программист
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

pub const codebase = @import("codebase.zig");
pub const agent_loop = @import("agent_loop.zig");
pub const code_analyzer = @import("code_analyzer.zig");
pub const spec_generator = @import("spec_generator.zig");
pub const llm_client = @import("llm_client.zig");
pub const memory_store = @import("memory_store.zig");

// Re-export main types
pub const Codebase = codebase.Codebase;
pub const AgentLoop = agent_loop.AgentLoop;
pub const DaemonConfig = agent_loop.DaemonConfig;
pub const Task = agent_loop.Task;
pub const TaskType = agent_loop.TaskType;
pub const CodeAnalyzer = code_analyzer.CodeAnalyzer;
pub const SpecGenerator = spec_generator.SpecGenerator;
pub const Specification = spec_generator.Specification;
pub const LLMClient = llm_client.LLMClient;
pub const LLMConfig = llm_client.LLMConfig;
pub const MemoryStore = memory_store.MemoryStore;

// ═══════════════════════════════════════════════════════════════════════════════
// MAXWELL DAEMON
// ═══════════════════════════════════════════════════════════════════════════════

/// Полный демон Maxwell с всеми компонентами
pub const MaxwellDaemon = struct {
    allocator: std.mem.Allocator,
    config: DaemonConfig,
    
    // Core components
    agent: AgentLoop,
    analyzer: CodeAnalyzer,
    spec_gen: SpecGenerator,
    llm: LLMClient,
    memory: MemoryStore,

    pub fn init(allocator: std.mem.Allocator, config: DaemonConfig, llm_config: LLMConfig) MaxwellDaemon {
        var agent = AgentLoop.init(allocator, config);
        
        return MaxwellDaemon{
            .allocator = allocator,
            .config = config,
            .agent = agent,
            .analyzer = CodeAnalyzer.init(allocator, &agent.codebase_interface),
            .spec_gen = SpecGenerator.init(allocator),
            .llm = LLMClient.init(allocator, llm_config),
            .memory = MemoryStore.init(allocator),
        };
    }

    pub fn deinit(self: *MaxwellDaemon) void {
        self.agent.deinit();
        self.analyzer.deinit();
        self.spec_gen.deinit();
        self.llm.deinit();
        self.memory.deinit();
    }

    /// Запустить демона
    pub fn start(self: *MaxwellDaemon) !void {
        std.debug.print(
            \\
            \\╔══════════════════════════════════════════════════════════════╗
            \\║                    🧠 MAXWELL DAEMON                         ║
            \\║              "Демон, который сортирует код"                  ║
            \\║                                                              ║
            \\║  φ² + 1/φ² = 3 = TRINITY                                    ║
            \\╚══════════════════════════════════════════════════════════════╝
            \\
        , .{});

        // Load memory from disk
        self.memory.load(".maxwell_memory") catch {};

        // Set up event handlers
        self.agent.on_task_complete = onTaskComplete;

        // Start agent loop
        try self.agent.start();

        std.debug.print("[MAXWELL] Daemon started. Waiting for tasks...\n", .{});
    }

    /// Остановить демона
    pub fn stop(self: *MaxwellDaemon) void {
        std.debug.print("[MAXWELL] Stopping daemon...\n", .{});

        self.agent.stop();

        // Save memory to disk
        self.memory.save(".maxwell_memory") catch {};

        std.debug.print("[MAXWELL] Daemon stopped.\n", .{});
    }

    /// Отправить задачу
    pub fn submitTask(self: *MaxwellDaemon, description: []const u8, task_type: TaskType) !u64 {
        return self.agent.submitTask(description, task_type);
    }

    /// Получить статус
    pub fn getStatus(self: *MaxwellDaemon) Status {
        const agent_state = self.agent.getState();
        const memory_stats = self.memory.getStats();

        return Status{
            .daemon_status = agent_state.status,
            .tasks_completed = agent_state.tasks_completed,
            .tasks_failed = agent_state.tasks_failed,
            .queue_length = self.agent.getQueueLength(),
            .uptime_seconds = @intCast(self.agent.getUptime()),
            .patterns_learned = memory_stats.total_patterns,
            .success_rate = memory_stats.success_rate,
        };
    }

    pub const Status = struct {
        daemon_status: agent_loop.DaemonStatus,
        tasks_completed: u64,
        tasks_failed: u64,
        queue_length: usize,
        uptime_seconds: u64,
        patterns_learned: u32,
        success_rate: f32,
    };

    fn onTaskComplete(task: *Task, result: *agent_loop.TaskResult) void {
        _ = task;
        _ = result;
        // Record experience in memory
        // This would need access to self, which requires a different approach
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "start")) {
        try startDaemon(allocator);
    } else if (std.mem.eql(u8, command, "status")) {
        try showStatus(allocator);
    } else if (std.mem.eql(u8, command, "task")) {
        if (args.len < 3) {
            std.debug.print("Usage: maxwell task <description>\n", .{});
            return;
        }
        try submitTask(allocator, args[2]);
    } else if (std.mem.eql(u8, command, "analyze")) {
        try analyzeCodebase(allocator);
    } else if (std.mem.eql(u8, command, "help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\Maxwell Daemon - Autonomous Coding Agent
        \\
        \\Usage: maxwell <command> [options]
        \\
        \\Commands:
        \\  start     Start the Maxwell daemon
        \\  stop      Stop the Maxwell daemon
        \\  status    Show daemon status
        \\  task      Submit a task to the daemon
        \\  analyze   Analyze the codebase
        \\  help      Show this help message
        \\
        \\Examples:
        \\  maxwell start
        \\  maxwell task "Add user authentication"
        \\  maxwell analyze
        \\
        \\φ² + 1/φ² = 3 = TRINITY
        \\
    , .{});
}

fn startDaemon(allocator: std.mem.Allocator) !void {
    var config = DaemonConfig.default();
    config.working_directory = ".";

    const llm_config = LLMConfig.claude();

    var daemon = MaxwellDaemon.init(allocator, config, llm_config);
    defer daemon.deinit();

    try daemon.start();

    // Wait for interrupt
    std.debug.print("[MAXWELL] Press Ctrl+C to stop...\n", .{});

    // Simple blocking wait (in real implementation, use signal handling)
    while (daemon.agent.running.load(.seq_cst)) {
        std.time.sleep(1 * std.time.ns_per_s);
    }

    daemon.stop();
}

fn showStatus(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print(
        \\
        \\Maxwell Daemon Status
        \\═════════════════════
        \\Status: Not running (use 'maxwell start' to start)
        \\
    , .{});
}

fn submitTask(allocator: std.mem.Allocator, description: []const u8) !void {
    _ = allocator;
    std.debug.print("[MAXWELL] Task submitted: {s}\n", .{description});
    std.debug.print("[MAXWELL] Note: Daemon must be running to process tasks\n", .{});
}

fn analyzeCodebase(allocator: std.mem.Allocator) !void {
    var cb = Codebase.init(allocator, ".");
    defer cb.deinit();

    var analyzer = CodeAnalyzer.init(allocator, &cb);
    defer analyzer.deinit();

    const metrics = try analyzer.analyzeCodebase(&[_][]const u8{ "singleton", "factory", "builder" });

    std.debug.print(
        \\
        \\Codebase Analysis
        \\═════════════════
        \\Total files:     {d}
        \\Total lines:     {d}
        \\Total functions: {d}
        \\Total types:     {d}
        \\Total tests:     {d}
        \\Avg complexity:  {d:.2}
        \\Max complexity:  {d}
        \\Test coverage:   {d:.1}%
        \\
    , .{
        metrics.total_files,
        metrics.total_lines,
        metrics.total_functions,
        metrics.total_types,
        metrics.total_tests,
        metrics.avg_complexity,
        metrics.max_complexity,
        metrics.test_coverage_estimate,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MaxwellDaemon init and deinit" {
    var config = DaemonConfig.default();
    config.working_directory = "/tmp";

    const llm_config = LLMConfig.claude();

    var daemon = MaxwellDaemon.init(std.testing.allocator, config, llm_config);
    defer daemon.deinit();
}

test "all maxwell modules compile" {
    // This test ensures all modules compile correctly
    _ = codebase;
    _ = agent_loop;
    _ = code_analyzer;
    _ = spec_generator;
    _ = llm_client;
    _ = memory_store;
}
