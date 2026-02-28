// TRI Orchestrator v2.0 - Full Command Registry
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;

pub const CommandCategory = enum(u8) {
    core, swe_agent, golden_chain, sacred_math, git, demo, bench,
    tvc, intelligence, dev_util, analysis, autonomous, info, orchestrator,
};

pub const RiskLevel = enum(u4) { safe, low, medium, high, critical };

pub const Realm = enum(u2) { razum, materiya, dukh, universal };

pub const CommandExecutor = *const fn(Allocator, [][]const u8) anyerror!OrchestratorResult;

pub const OrchestratorResult = struct {
    success: bool,
    steps_completed: u32,
    steps_total: u32,
    duration_ms: u64,
    sacred_score: f64,
    output: []const u8,
    @"error": ?[]const u8 = null,
};

pub const CommandMetadata = struct {
    name: []const u8,
    category: CommandCategory,
    realm: Realm,
    sacred_weight: f64,
    risk_level: RiskLevel,
    min_args: u32,
    max_args: u32,
    description: []const u8,
    executor: CommandExecutor,
};

pub const CommandRegistry = struct {
    const StringHashMap = std.StringHashMap;

    commands: StringHashMap(CommandMetadata),
    by_category: [14]ArrayList(*CommandMetadata),
    by_realm: [4]ArrayList(*CommandMetadata),
    alias_map: StringHashMap([]const u8),
    total_count: u32,
    sacred_score: f64,
    trinity_verified: bool,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !CommandRegistry {
        var registry = CommandRegistry{
            .commands = StringHashMap(CommandMetadata).init(allocator),
            .by_category = undefined,
            .by_realm = undefined,
            .alias_map = StringHashMap([]const u8).init(allocator),
            .total_count = 0,
            .sacred_score = 0.0,
            .trinity_verified = false,
            .allocator = allocator,
        };

        inline for (0..14) |i| {
            registry.by_category[i] = .{};
        }
        inline for (0..4) |i| {
            registry.by_realm[i] = .{};
        }

        return registry;
    }

    pub fn deinit(self: *CommandRegistry) void {
        var it = self.commands.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.name);
            self.allocator.free(entry.value_ptr.description);
        }
        self.commands.deinit();

        for (&self.by_category) |*list| {
            list.deinit(self.allocator);
        }
        for (&self.by_realm) |*list| {
            list.deinit(self.allocator);
        }

        var alias_it = self.alias_map.iterator();
        while (alias_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.alias_map.deinit();
    }

    pub fn registerCommand(self: *CommandRegistry, metadata: CommandMetadata) !void {
        const name_copy = try self.allocator.dupe(u8, metadata.name);
        errdefer self.allocator.free(name_copy);

        const desc_copy = try self.allocator.dupe(u8, metadata.description);
        errdefer self.allocator.free(desc_copy);

        var owned = metadata;
        owned.name = name_copy;
        owned.description = desc_copy;

        try self.commands.put(name_copy, owned);

        const cmd_ptr = self.commands.getPtr(name_copy).?;
        try self.by_category[@intFromEnum(metadata.category)].append(self.allocator, cmd_ptr);
        try self.by_realm[@intFromEnum(metadata.realm)].append(self.allocator, cmd_ptr);

        self.total_count += 1;
    }

    pub fn getCommand(self: *const CommandRegistry, name: []const u8) ?*const CommandMetadata {
        const canonical_name = self.alias_map.get(name) orelse name;
        return self.commands.getPtr(canonical_name);
    }

    pub fn calculateSacredScore(self: *const CommandRegistry) !f64 {
        if (self.total_count == 0) return 0.0;

        var total_weight: f64 = 0.0;
        var it = self.commands.iterator();
        while (it.next()) |entry| {
            total_weight += entry.value_ptr.sacred_weight;
        }

        return @min(1.0, total_weight / @as(f64, @floatFromInt(self.total_count)));
    }

    pub fn printStats(self: *const CommandRegistry) void {
        std.debug.print("\n\x1b[36m╔══════════════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║         TRINITY COMMAND REGISTRY v2.0 STATISTICS            ║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m╚══════════════════════════════════════════════════════════════╝\x1b[0m\n\n", .{});
        std.debug.print("Total Commands: {d}\n", .{self.total_count});
        std.debug.print("Trinity Verified: {s}\n", .{if (self.trinity_verified) "YES" else "NO"});
        std.debug.print("Sacred Score: {d:.4}\n\n", .{self.sacred_score});
    }
};

pub const WorkflowStep = struct {
    name: []const u8,
    command: []const u8,
    args: [][]const u8,
    depends_on: [][]const u8,
    condition: ?[]const u8,
    continue_on_failure: bool,
    timeout_ms: u64,
};

pub const Workflow = struct {
    name: []const u8,
    description: []const u8,
    steps: []WorkflowStep,
    strategy: u2,
    rollback_enabled: bool,
};

pub fn verifyTrinityIdentity() bool {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    return @abs(result - TRINITY) < 0.0001;
}

fn noopExecutor(_: Allocator, args: [][]const u8) anyerror!OrchestratorResult {
    _ = args;
    return OrchestratorResult{
        .success = true,
        .steps_completed = 1,
        .steps_total = 1,
        .duration_ms = 0,
        .sacred_score = 1.0,
        .output = "Command executed (noop)",
        .@"error" = null,
    };
}

pub fn registerAllCommands(allocator: Allocator) !CommandRegistry {
    var registry = try CommandRegistry.init(allocator);
    errdefer registry.deinit();

    // Core commands (15)
    const core_names = [_][]const u8{
        "chat", "code", "gen", "convert", "serve", "bench", "evolve",
        "multi_cluster", "test", "verify", "verdict", "distributed",
        "orchestrate_v2", "spec_create", "loop_decide",
    };
    for (core_names, 0..) |name, i| {
        const realm: Realm = if (i == 6 or i == 10 or i == 14) .dukh else if (i == 0 or i == 1 or i == 2 or i == 12 or i == 13) .razum else .materiya;
        try registry.registerCommand(.{
            .name = name,
            .category = .core,
            .realm = realm,
            .sacred_weight = if (realm == .razum) PHI else if (realm == .dukh) PHI_INV else 1.0,
            .risk_level = .safe,
            .min_args = 0,
            .max_args = 100,
            .description = "Core command",
            .executor = noopExecutor,
        });
    }

    // SWE Agent (6)
    const swe_names = [_][]const u8{ "fix", "explain", "test_cmd", "doc", "refactor", "reason" };
    for (swe_names) |name| {
        try registry.registerCommand(.{
            .name = name,
            .category = .swe_agent,
            .realm = .razum,
            .sacred_weight = PHI,
            .risk_level = .low,
            .min_args = 0,
            .max_args = 10,
            .description = "SWE Agent command",
            .executor = noopExecutor,
        });
    }

    // Golden Chain (3)
    const gc_names = [_][]const u8{ "pipeline", "decompose", "plan" };
    const gc_realms = [_]Realm{ .dukh, .razum, .razum };
    for (gc_names, 0..) |name, i| {
        try registry.registerCommand(.{
            .name = name,
            .category = .golden_chain,
            .realm = gc_realms[i],
            .sacred_weight = if (gc_realms[i] == .razum) PHI else PHI_INV,
            .risk_level = .safe,
            .min_args = 0,
            .max_args = 10,
            .description = "Golden Chain command",
            .executor = noopExecutor,
        });
    }

    // Sacred Math (9)
    const math_names = [_][]const u8{ "math", "constants_cmd", "phi", "fib", "lucas", "spiral", "gematria", "formula_cmd", "sacred" };
    for (math_names) |name| {
        try registry.registerCommand(.{
            .name = name,
            .category = .sacred_math,
            .realm = .razum,
            .sacred_weight = PHI_SQ,
            .risk_level = .safe,
            .min_args = 0,
            .max_args = 10,
            .description = "Sacred Math command",
            .executor = noopExecutor,
        });
    }

    // Sacred Agents (8)
    const agent_names = [_][]const u8{ "identity", "swarm", "govern", "dashboard", "omega", "math_agent", "intelligence", "chem" };
    for (agent_names) |name| {
        try registry.registerCommand(.{
            .name = name,
            .category = .intelligence,
            .realm = .dukh,
            .sacred_weight = PHI_INV,
            .risk_level = .medium,
            .min_args = 0,
            .max_args = 10,
            .description = "Sacred Agent command",
            .executor = noopExecutor,
        });
    }

    // Git (4)
    const git_names = [_][]const u8{ "commit", "diff", "status", "log" };
    for (git_names) |name| {
        try registry.registerCommand(.{
            .name = name,
            .category = .git,
            .realm = .materiya,
            .sacred_weight = 1.0,
            .risk_level = .medium,
            .min_args = 0,
            .max_args = 10,
            .description = "Git command",
            .executor = noopExecutor,
        });
    }

    // Demo/Bench (70)
    const demo_names = [_][]const u8{
        "agents_demo", "agents_bench", "context_demo", "context_bench",
        "rag_demo", "rag_bench", "voice_demo", "voice_bench",
        "sandbox_demo", "sandbox_bench", "stream_demo", "stream_bench",
        "vision_demo", "vision_bench", "finetune_demo", "finetune_bench",
        "batched_demo", "batched_bench", "priority_demo", "priority_bench",
        "deadline_demo", "deadline_bench", "multimodal_demo", "multimodal_bench",
        "tooluse_demo", "tooluse_bench", "unified_demo", "unified_bench",
        "autonomous_demo", "autonomous_bench", "orchestration_demo", "orchestration_bench",
        "mm_orch_demo", "mm_orch_bench", "memory_demo", "memory_bench",
        "persist_demo", "persist_bench", "spawn_demo", "spawn_bench",
        "cluster_demo", "cluster_bench", "worksteal_demo", "worksteal_bench",
        "plugin_demo", "plugin_bench", "comms_demo", "comms_bench",
        "observe_demo", "observe_bench", "consensus_demo", "consensus_bench",
        "specexec_demo", "specexec_bench", "governor_demo", "governor_bench",
        "fedlearn_demo", "fedlearn_bench", "eventsrc_demo", "eventsrc_bench",
        "capsec_demo", "capsec_bench", "dtxn_demo", "dtxn_bench",
        "cache_demo", "cache_bench", "contract_demo", "contract_bench",
        "workflow_demo", "workflow_bench",
    };
    for (demo_names) |name| {
        const is_demo = std.mem.endsWith(u8, name, "_demo");
        const is_orch = std.mem.indexOf(u8, name, "orch") != null;
        try registry.registerCommand(.{
            .name = name,
            .category = if (is_demo) .demo else .bench,
            .realm = if (is_demo and is_orch) .dukh else .materiya,
            .sacred_weight = 1.0,
            .risk_level = .safe,
            .min_args = 0,
            .max_args = 1,
            .description = "Demo/Benchmark",
            .executor = noopExecutor,
        });
    }

    // TVC (2)
    try registry.registerCommand(.{ .name = "tvc_demo", .category = .tvc, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .safe, .min_args = 0, .max_args = 1, .description = "TVC Demo", .executor = noopExecutor });
    try registry.registerCommand(.{ .name = "tvc_stats", .category = .tvc, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .safe, .min_args = 0, .max_args = 1, .description = "TVC Stats", .executor = noopExecutor });

    // Dev Util (7)
    const util_names = [_][]const u8{ "doctor", "clean", "fmt_cmd", "stats_cmd", "igla", "test_repl", "monitor" };
    for (util_names) |name| {
        try registry.registerCommand(.{ .name = name, .category = .dev_util, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .safe, .min_args = 0, .max_args = 5, .description = "Dev Util", .executor = noopExecutor });
    }

    // Info (4)
    const info_names = [_][]const u8{ "deps", "info", "version", "help" };
    for (info_names) |name| {
        try registry.registerCommand(.{ .name = name, .category = .info, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .safe, .min_args = 0, .max_args = 1, .description = "Info", .executor = noopExecutor });
    }

    // Analysis (3)
    const analysis_names = [_][]const u8{ "analyze", "search_cmd", "context_info" };
    for (analysis_names) |name| {
        try registry.registerCommand(.{ .name = name, .category = .analysis, .realm = .razum, .sacred_weight = PHI, .risk_level = .safe, .min_args = 0, .max_args = 10, .description = "Analysis", .executor = noopExecutor });
    }

    // Autonomous (6)
    const auto_names = [_][]const u8{ "auto_commit", "ml_optimize", "deploy_dashboard", "self_host", "safeguards_show", "safeguards_disable" };
    for (auto_names) |name| {
        const is_critical = std.mem.eql(u8, name, "safeguards_disable");
        try registry.registerCommand(.{
            .name = name,
            .category = .autonomous,
            .realm = .dukh,
            .sacred_weight = PHI_INV,
            .risk_level = if (is_critical) .critical else .high,
            .min_args = 0,
            .max_args = 10,
            .description = "Autonomous",
            .executor = noopExecutor,
        });
    }

    registry.trinity_verified = verifyTrinityIdentity();
    registry.sacred_score = try registry.calculateSacredScore();

    return registry;
}

pub fn runOrchestrateCommand(args: [][]const u8) !void {
    _ = args;
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Orchestrate command (simplified)\n", .{});
}

pub fn runPipelineCommand(args: [][]const u8) !void {
    const allocator = std.heap.page_allocator;

    if (args.len < 1) {
        std.debug.print("Usage: tri pipeline <task>\n", .{});
        return error.Usage;
    }

    const task = args[0];

    std.debug.print("\n{s} GOLDEN CHAIN PIPELINE {s}\n", .{"═" ** 30, "═" ** 30});
    std.debug.print("Task: {s}\n", .{task});
    std.debug.print("Links: 17\n", .{});
    std.debug.print("{s}\n", .{"═" ** 70});

    var registry = try registerAllCommands(allocator);
    defer registry.deinit();
    registry.printStats();

    std.debug.print("\n\x1b[33m{s} Golden Chain initiated for: {s} \x1b[0m\n", .{"✓", task});
    std.debug.print("Trinity Verified: {s}\n", .{if (registry.trinity_verified) "YES ✓" else "NO ✗"});
    std.debug.print("Sacred Score: {d:.4}\n", .{registry.sacred_score});
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTION STRATEGIES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutionResult = struct {
    step_name: []const u8,
    success: bool,
    duration_ms: u64,
    sacred_score: f64,
    output: []const u8,
    error_msg: ?[]const u8 = null,
};

pub const WorkflowExecutor = struct {
    allocator: Allocator,
    registry: *CommandRegistry,
    workflow: *const Workflow,

    pub fn init(allocator: Allocator, registry: *CommandRegistry, workflow: *const Workflow) WorkflowExecutor {
        return .{
            .allocator = allocator,
            .registry = registry,
            .workflow = workflow,
        };
    }

    /// Execute workflow based on strategy
    pub fn execute(self: *const WorkflowExecutor) ![]ExecutionResult {
        return switch (self.workflow.strategy) {
            0 => self.executeSequential(),
            1 => self.executeParallel(),
            2 => self.executeConditional(),
            3 => self.executeAdaptive(),
            else => self.executeSequential(),
        };
    }

    /// Execute steps in dependency order (topological sort)
    pub fn executeSequential(self: *const WorkflowExecutor) ![]ExecutionResult {
        const ordered_steps = try self.resolveDependencies();
        defer self.allocator.free(ordered_steps);

        var results = std.ArrayList(ExecutionResult).init(self.allocator);
        defer results.deinit(self.allocator);

        for (ordered_steps) |step_idx| {
            const step = &self.workflow.steps[step_idx];
            const start_time = std.time.milliTimestamp();

            const cmd = self.registry.getCommand(step.command) orelse {
                std.debug.print("Command not found: {s}\n", .{step.command});
                if (!step.continue_on_failure) return error.CommandNotFound;
                try results.append(self.allocator, .{
                    .step_name = step.name,
                    .success = false,
                    .duration_ms = 0,
                    .sacred_score = 0.0,
                    .output = "",
                    .error_msg = null,
                });
                continue;
            };

            const result = try cmd.executor(self.allocator, step.args);
            const end_time = std.time.milliTimestamp();

            try results.append(self.allocator, .{
                .step_name = step.name,
                .success = result.success,
                .duration_ms = @intCast(end_time - start_time),
                .sacred_score = result.sacred_score,
                .output = result.output,
                .error_msg = result.@"error",
            });

            if (!result.success and !step.continue_on_failure) {
                std.debug.print("Step failed: {s}\n", .{step.name});
                return error.StepFailed;
            }
        }

        return results.toOwnedSlice(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PARALLEL EXECUTION - Level-based with std.Thread
    // ═══════════════════════════════════════════════════════════════════════════════

    const ParallelContext = struct {
        mutex: std.Thread.Mutex,
        results: []ExecutionResult,
        result_count: std.atomic.Value(usize),
        has_failure: std.atomic.Value(bool),
        total_sacred_score: std.atomic.Value(f64),
        allocator: Allocator,
        executor: *const WorkflowExecutor,
        step_indices: []const usize,

        fn init(allocator: Allocator, executor: *const WorkflowExecutor, step_indices: []const usize) !ParallelContext {
            const results = try allocator.alloc(ExecutionResult, step_indices.len);
            @memset(results, undefined);
            return .{
                .mutex = .{},
                .results = results,
                .result_count = std.atomic.Value(usize).init(0),
                .has_failure = std.atomic.Value(bool).init(false),
                .total_sacred_score = std.atomic.Value(f64).init(0.0),
                .allocator = allocator,
                .executor = executor,
                .step_indices = step_indices,
            };
        }

        fn deinit(self: *ParallelContext) void {
            for (self.results) |*result| {
                if (result.output.len > 0) self.allocator.free(result.output);
                if (result.error_msg) |msg| self.allocator.free(msg);
            }
            self.allocator.free(self.results);
        }
    };

    const ThreadTask = struct {
        context: *ParallelContext,
        step_idx: usize,
        position: usize,

        fn run(task: *ThreadTask) !void {
            const step_index = task.step_idx;
            const pos = task.position;
            const context = task.context;
            const executor = context.executor;
            const step = &executor.workflow.steps[step_index];

            const start_time = std.time.milliTimestamp();

            const cmd = if (context.executor.registry.getCommand(step.command)) |cmd| cmd else {
                context.mutex.lock();
                defer context.mutex.unlock();
                context.results[pos] = .{
                    .step_name = step.name,
                    .success = false,
                    .duration_ms = 0,
                    .sacred_score = 0.0,
                    .output = "",
                    .error_msg = try std.fmt.allocPrint(context.allocator, "Command not found: {s}", .{step.command}),
                };
                context.has_failure.store(true, .seq_cst);
                context.result_count.fetchAdd(1, .seq_cst);
                return;
            };

            const result = try cmd.executor(context.allocator, step.args);
            const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

            context.mutex.lock();
            defer context.mutex.unlock();

            context.results[pos] = .{
                .step_name = step.name,
                .success = result.success,
                .duration_ms = duration,
                .sacred_score = result.sacred_score,
                .output = try context.allocator.dupe(u8, result.output),
                .error_msg = if (result.@"error") |err| try context.allocator.dupe(u8, err) else null,
            };

            const current_score = context.total_sacred_score.load(.seq_cst);
            _ = context.total_sacred_score.compareAndSwap(
                current_score,
                current_score + result.sacred_score,
                .seq_cst,
                .seq_cst,
            );

            if (!result.success and !step.continue_on_failure) {
                context.has_failure.store(true, .seq_cst);
            }

            _ = context.result_count.fetchAdd(1, .seq_cst);
        }
    };

    /// Execute independent steps concurrently using level-based parallelization
    pub fn executeParallel(self: *const WorkflowExecutor) ![]ExecutionResult {
        const n = self.workflow.steps.len;
        const cpu_count = try std.Thread.getCpuCount();
        const max_threads = @min(cpu_count, @as(usize, @intFromFloat(@as(f64, @floatFromInt(cpu_count)) * PHI)));

        // Build dependency graph and compute levels (Kahn's algorithm variant)
        var in_degree = try self.allocator.alloc(usize, n);
        defer self.allocator.free(in_degree);
        @memset(in_degree, 0);

        var adj_list = try self.allocator.alloc(std.ArrayList(usize), n);
        defer {
            for (adj_list) |*list| list.deinit(self.allocator);
            self.allocator.free(adj_list);
        }
        for (0..n) |i| {
            adj_list[i] = std.ArrayList(usize).init(self.allocator);
        }

        for (0..n) |i| {
            for (self.workflow.steps[i].depends_on) |dep_name| {
                if (self.findStepIndex(dep_name)) |dep_idx| {
                    in_degree[i] += 1;
                    try adj_list[dep_idx].append(i);
                }
            }
        }

        // Group steps by execution level
        var levels = std.ArrayList(std.ArrayList(usize)).init(self.allocator);
        defer {
            for (levels.items) |*level| level.deinit(self.allocator);
            levels.deinit(self.allocator);
        }

        {
            const first_level = std.ArrayList(usize).init(self.allocator);
            try levels.append(first_level);
        }

        var queue = std.ArrayList(usize).init(self.allocator);
        defer queue.deinit(self.allocator);

        for (0..n) |i| {
            if (in_degree[i] == 0) {
                try queue.append(i);
            }
        }

        while (queue.items.len > 0) {
            var new_level = std.ArrayList(usize).init(self.allocator);
            defer {
                if (new_level.items.len > 0) {
                    new_level.deinit(self.allocator);
                }
            }

            const level_size = queue.items.len;
            for (0..level_size) |_| {
                const idx = queue.orderedRemove(0);
                try levels.items[levels.items.len - 1].append(idx);

                for (adj_list[idx].items) |neighbor| {
                    in_degree[neighbor] -= 1;
                    if (in_degree[neighbor] == 0) {
                        try queue.append(neighbor);
                    }
                }
            }

            if (queue.items.len > 0) {
                try levels.append(new_level);
            }
        }

        // Execute each level in parallel
        var all_results = std.ArrayList(ExecutionResult).init(self.allocator);
        defer {
            for (all_results.items) |*r| {
                self.allocator.free(r.output);
                if (r.error_msg) |msg| self.allocator.free(msg);
            }
            all_results.deinit(self.allocator);
        }

        for (levels.items) |level| {
            if (level.items.len == 0) continue;
            if (level.items.len == 1) {
                // Single step - execute directly
                const idx = level.items[0];
                const step = &self.workflow.steps[idx];
                const start_time = std.time.milliTimestamp();

                const cmd = self.registry.getCommand(step.command) orelse {
                    return error.CommandNotFound;
                };
                const result = try cmd.executor(self.allocator, step.args);
                const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

                try all_results.append(.{
                    .step_name = step.name,
                    .success = result.success,
                    .duration_ms = duration,
                    .sacred_score = result.sacred_score,
                    .output = try self.allocator.dupe(u8, result.output),
                    .error_msg = if (result.@"error") |err| try self.allocator.dupe(u8, err) else null,
                });

                if (!result.success and !step.continue_on_failure) {
                    return error.StepFailed;
                }
                continue;
            }

            // Multiple steps - execute in parallel
            const threads_to_spawn = @min(level.items.len, max_threads);
            var context = try ParallelContext.init(self.allocator, self, level.items);
            defer context.deinit();

            var threads = try self.allocator.alloc(std.Thread, threads_to_spawn);
            defer self.allocator.free(threads);

            var thread_idx: usize = 0;
            for (level.items, 0..) |step_idx, i| {
                if (thread_idx >= threads_to_spawn) break;

                threads[thread_idx] = try std.Thread.spawn(.{}, ThreadTask.run, .{
                    &.{ .context = &context, .step_idx = step_idx, .position = i },
                });
                thread_idx += 1;
            }

            // Execute remaining steps in current thread
            for (thread_idx..level.items.len) |i| {
                const step_idx = level.items[i];
                const pos = i;
                const step = &self.workflow.steps[step_idx];
                const start_time = std.time.milliTimestamp();

                const cmd = self.registry.getCommand(step.command) orelse {
                    return error.CommandNotFound;
                };
                const result = try cmd.executor(self.allocator, step.args);
                const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

                context.mutex.lock();
                defer context.mutex.unlock();

                context.results[pos] = .{
                    .step_name = step.name,
                    .success = result.success,
                    .duration_ms = duration,
                    .sacred_score = result.sacred_score,
                    .output = try self.allocator.dupe(u8, result.output),
                    .error_msg = if (result.@"error") |err| try self.allocator.dupe(u8, err) else null,
                };

                if (!result.success and !step.continue_on_failure) {
                    context.has_failure.store(true, .seq_cst);
                }
                _ = context.result_count.fetchAdd(1, .seq_cst);
            }

            // Wait for all threads
            for (threads[0..thread_idx]) |thread| {
                thread.join();
            }

            // Append results
            try all_results.appendSlice(context.results);

            if (context.has_failure.load(.seq_cst)) {
                return error.StepFailed;
            }
        }

        return all_results.toOwnedSlice(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // CONDITIONAL EXECUTION - AST-based condition evaluation
    // ═══════════════════════════════════════════════════════════════════════════════

    const ConditionAST = union(enum) {
        boolean: bool,
        comparison: struct {
            left: []const u8,
            op: []const u8,
            right: []const u8,
        },
        logical: struct {
            op: []const u8,
            left: *ConditionAST,
            right: *ConditionAST,
        },
        reference: []const u8, // step('id').field or direct field like 'success'
        contains: struct {
            left: []const u8,
            pattern: []const u8,
        },
        phi_call: struct {
            n: []const u8,
            comparison: []const u8,
            threshold: []const u8,
        },
    };

    fn parseCondition(allocator: Allocator, expr: []const u8) !ConditionAST {
        var trimmed = std.mem.trim(u8, expr, &std.ascii.whitespace);

        // Handle logical operators (&&, ||)
        if (std.mem.indexOf(u8, trimmed, " && ")) |idx| {
            const left_expr = trimmed[0..idx];
            const right_expr = trimmed[idx + 4 ..];
            const left = try allocator.create(ConditionAST);
            const right = try allocator.create(ConditionAST);
            left.* = try parseCondition(allocator, left_expr);
            right.* = try parseCondition(allocator, right_expr);
            return .{ .logical = .{ .op = "&&", .left = left, .right = right } };
        }
        if (std.mem.indexOf(u8, trimmed, " || ")) |idx| {
            const left_expr = trimmed[0..idx];
            const right_expr = trimmed[idx + 4 ..];
            const left = try allocator.create(ConditionAST);
            const right = try allocator.create(ConditionAST);
            left.* = try parseCondition(allocator, left_expr);
            right.* = try parseCondition(allocator, right_expr);
            return .{ .logical = .{ .op = "||", .left = left, .right = right } };
        }

        // Handle negation (!)
        if (std.mem.startsWith(u8, trimmed, "!")) {
            const inner = trimmed[1..];
            if (std.mem.eql(u8, inner, "success")) {
                return .{ .boolean = false };
            }
            if (std.mem.eql(u8, inner, "failed")) {
                return .{ .boolean = true };
            }
        }

        // Handle simple boolean keywords
        if (std.mem.eql(u8, trimmed, "success")) return .{ .boolean = true };
        if (std.mem.eql(u8, trimmed, "failed")) return .{ .boolean = false };

        // Handle step('id').field references
        if (std.mem.startsWith(u8, trimmed, "step(")) {
            const end_idx = std.mem.indexOf(u8, trimmed, ")") orelse return error.InvalidCondition;
            const step_name = trimmed["step(".len..end_idx];
            const rest = trimmed[end_idx + 1 ..];
            if (std.mem.startsWith(u8, rest, ".")) {
                const field = rest[1..];
                return .{ .reference = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ step_name, field }) };
            }
        }

        // Handle 'contains' operator
        if (std.mem.indexOf(u8, trimmed, " contains ")) |idx| {
            const left = trimmed[0..idx];
            var pattern = trimmed[idx + 10 ..];
            // Strip quotes from pattern
            if (pattern.len > 1 and (pattern[0] == '\'' or pattern[0] == '"')) {
                pattern = pattern[1 .. pattern.len - 1];
            }
            return .{ .contains = .{ .left = left, .pattern = pattern } };
        }

        // Handle phi(n) comparisons
        if (std.mem.startsWith(u8, trimmed, "phi(")) {
            const end_idx = std.mem.indexOf(u8, trimmed, ")") orelse return error.InvalidCondition;
            const n_str = trimmed["phi(".len..end_idx];
            var rest = trimmed[end_idx + 1 ..];
            rest = std.mem.trim(u8, rest, &std.ascii.whitespace);

            const op_end = std.mem.indexOfScalar(u8, rest, ' ') orelse return error.InvalidCondition;
            const op = rest[0..op_end];
            const threshold = std.mem.trimLeft(u8, rest[op_end + 1 ..], &std.ascii.whitespace);

            return .{ .phi_call = .{ .n = n_str, .comparison = op, .threshold = threshold } };
        }

        // Handle comparisons (>, >=, <, <=, ==, !=)
        const ops = [_][]const u8{ ">=", "<=", "==", "!=", ">", "<" };
        for (ops) |op| {
            if (std.mem.indexOf(u8, trimmed, op)) |idx| {
                if (idx == 0) continue;
                const left = std.mem.trimRight(u8, trimmed[0..idx], &std.ascii.whitespace);
                const right = std.mem.trimLeft(u8, trimmed[idx + op.len ..], &std.ascii.whitespace);
                return .{ .comparison = .{ .left = left, .op = op, .right = right } };
            }
        }

        // Direct field reference
        return .{ .reference = trimmed };
    }

    fn evaluateCondition(ast: *const ConditionAST, results: []const ExecutionResult, last_success: bool) bool {
        return switch (ast.*) {
            .boolean => |b| b,
            .comparison => |c| blk: {
                const left_val = getValue(c.left, results, last_success);
                const right_val = getValue(c.right, results, last_success);
                break :blk switch (c.op[0]) {
                    '>' => if (c.op.len == 2) left_val >= right_val else left_val > right_val,
                    '<' => if (c.op.len == 2) left_val <= right_val else left_val < right_val,
                    '=' => left_val == right_val,
                    '!' => left_val != right_val,
                    else => false,
                };
            },
            .logical => |l| switch (l.op[0]) {
                '&' => evaluateCondition(l.left, results, last_success) and evaluateCondition(l.right, results, last_success),
                '|' => evaluateCondition(l.left, results, last_success) or evaluateCondition(l.right, results, last_success),
                else => false,
            },
            .reference => |r| evaluateReference(r, results, last_success),
            .contains => |c| blk: {
                const value = getStringValue(c.left, results);
                break :blk std.mem.indexOf(u8, value, c.pattern) != null;
            },
            .phi_call => |c| blk: {
                const n_f = std.fmt.parseFloat(f64, c.n) catch 0;
                const phi_n = std.math.pow(f64, PHI, n_f);
                const threshold = std.fmt.parseFloat(f64, c.threshold) catch 0;
                break :blk switch (c.comparison[0]) {
                    '>' => if (c.comparison.len == 2) phi_n >= threshold else phi_n > threshold,
                    '<' => if (c.comparison.len == 2) phi_n <= threshold else phi_n < threshold,
                    '=' => @abs(phi_n - threshold) < 0.0001,
                    else => false,
                };
            },
        };
    }

    fn getValue(ref: []const u8, results: []const ExecutionResult, last_success: bool) f64 {
        if (std.mem.eql(u8, ref, "success")) return if (last_success) 1.0 else 0.0;
        if (std.mem.eql(u8, ref, "failed")) return if (last_success) 0.0 else 1.0;
        if (std.mem.startsWith(u8, ref, "sacred_score")) return if (last_success) 1.0 else 0.0;

        // Parse step('id').field
        if (std.mem.indexOf(u8, ref, ".")) |dot_idx| {
            const step_name = ref[0..dot_idx];
            const field = ref[dot_idx + 1 ..];
            for (results) |r| {
                if (std.mem.eql(u8, r.step_name, step_name)) {
                    if (std.mem.eql(u8, field, "success")) return if (r.success) 1.0 else 0.0;
                    if (std.mem.eql(u8, field, "sacred_score")) return r.sacred_score;
                    if (std.mem.eql(u8, field, "duration_ms")) return @floatFromInt(r.duration_ms);
                }
            }
        }
        return 0.0;
    }

    fn getStringValue(ref: []const u8, results: []const ExecutionResult) []const u8 {
        if (std.mem.eql(u8, ref, "output")) {
            if (results.len > 0) return results[results.len - 1].output else return "";
        }
        if (std.mem.startsWith(u8, ref, "step(")) {
            const end_idx = std.mem.indexOf(u8, ref, ")") orelse return "";
            const step_name = ref["step(".len..end_idx];
            const rest = ref[end_idx + 1 ..];
            if (std.mem.startsWith(u8, rest, ".output")) {
                for (results) |r| {
                    if (std.mem.eql(u8, r.step_name, step_name)) return r.output;
                }
            }
        }
        return "";
    }

    fn evaluateReference(ref: []const u8, results: []const ExecutionResult, last_success: bool) bool {
        if (std.mem.eql(u8, ref, "success")) return last_success;
        if (std.mem.eql(u8, ref, "failed")) return !last_success;

        // Parse step('id').field
        if (std.mem.indexOf(u8, ref, ".")) |dot_idx| {
            const step_name = ref[0..dot_idx];
            const field = ref[dot_idx + 1 ..];
            for (results) |r| {
                if (std.mem.eql(u8, r.step_name, step_name)) {
                    if (std.mem.eql(u8, field, "success")) return r.success;
                    if (std.mem.eql(u8, field, "failed")) return !r.success;
                }
            }
        }
        return last_success;
    }

    /// Execute with conditional branching based on step conditions
    pub fn executeConditional(self: *const WorkflowExecutor) ![]ExecutionResult {
        const ordered_steps = try self.resolveDependencies();
        defer self.allocator.free(ordered_steps);

        var results = std.ArrayList(ExecutionResult).init(self.allocator);
        defer {
            for (results.items) |*r| {
                self.allocator.free(r.output);
                if (r.error_msg) |msg| self.allocator.free(msg);
            }
            results.deinit(self.allocator);
        }

        var last_success = true;

        for (ordered_steps) |step_idx| {
            const step = &self.workflow.steps[step_idx];

            // Check condition
            if (step.condition) |cond| {
                const ast = try parseCondition(self.allocator, cond);
                defer {
                    // Simple cleanup - in production would use proper arena/deinit
                    if (ast == .logical) {
                        self.allocator.destroy(ast.logical.left);
                        self.allocator.destroy(ast.logical.right);
                    }
                }

                if (!evaluateCondition(&ast, results.items, last_success)) {
                    // Skip this step - condition not met
                    continue;
                }
            }

            const start_time = std.time.milliTimestamp();

            const cmd = self.registry.getCommand(step.command) orelse {
                return error.CommandNotFound;
            };
            const result = try cmd.executor(self.allocator, step.args);
            const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

            const exec_result = ExecutionResult{
                .step_name = step.name,
                .success = result.success,
                .duration_ms = duration,
                .sacred_score = result.sacred_score,
                .output = try self.allocator.dupe(u8, result.output),
                .error_msg = if (result.@"error") |err| try self.allocator.dupe(u8, err) else null,
            };

            try results.append(exec_result);
            last_success = exec_result.success;

            if (!exec_result.success and !step.continue_on_failure) {
                std.debug.print("Conditional step failed: {s}\n", .{step.name});
                return error.StepFailed;
            }
        }

        return results.toOwnedSlice(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ADAPTIVE EXECUTION - Auto-select optimal strategy
    // ═══════════════════════════════════════════════════════════════════════════════

    fn analyzeWorkflow(self: *const WorkflowExecutor) struct {
        has_conditions: bool,
        parallelizable_ratio: f64,
        avg_complexity: f64,
        sacred_alignment: f64,
    } {
        var has_conditions = false;
        var parallelizable_count: usize = 0;
        var total_complexity: f64 = 0;
        var total_sacred: f64 = 0;

        const n = self.workflow.steps.len;

        for (self.workflow.steps) |step| {
            if (step.condition != null) has_conditions = true;

            // Check if step has no dependencies (parallelizable)
            if (step.depends_on.len == 0) parallelizable_count += 1;

            // Estimate complexity from args count
            const complexity = @as(f64, @floatFromInt(step.args.len));
            total_complexity += complexity;

            // Get sacred weight from command
            if (self.registry.getCommand(step.command)) |cmd| {
                total_sacred += cmd.sacred_weight;
            }
        }

        return .{
            .has_conditions = has_conditions,
            .parallelizable_ratio = if (n > 0) @as(f64, @floatFromInt(parallelizable_count)) / @as(f64, @floatFromInt(n)) else 0,
            .avg_complexity = if (n > 0) total_complexity / @as(f64, @floatFromInt(n)) else 0,
            .sacred_alignment = if (n > 0) total_sacred / @as(f64, @floatFromInt(n)) else 0,
        };
    }

    /// Auto-select execution strategy based on workflow analysis
    pub fn executeAdaptive(self: *const WorkflowExecutor) ![]ExecutionResult {
        const analysis = self.analyzeWorkflow();

        // Decision matrix based on φ-sacred principles
        // High parallelizability (> 1/φ) + no conditions → parallel
        // Has conditions → conditional
        // Low sacred alignment → sequential (safe)
        // Otherwise → sequential

        if (analysis.has_conditions) {
            std.debug.print("[Adaptive] Selected conditional execution\n", .{});
            return self.executeConditional();
        }

        if (analysis.parallelizable_ratio > PHI_INV and analysis.sacred_alignment > 0.7) {
            std.debug.print("[Adaptive] Selected parallel execution (ratio: {d:.2}, sacred: {d:.2})\n", .{
                analysis.parallelizable_ratio, analysis.sacred_alignment
            });
            return self.executeParallel();
        }

        if (analysis.avg_complexity > PHI) {
            // High complexity tasks benefit from parallel execution
            std.debug.print("[Adaptive] Selected parallel execution (high complexity: {d:.2})\n", .{analysis.avg_complexity});
            return self.executeParallel();
        }

        std.debug.print("[Adaptive] Selected sequential execution\n", .{});
        return self.executeSequential();
    }

    /// Resolve step dependencies using topological sort
    pub fn resolveDependencies(self: *const WorkflowExecutor) ![]usize {
        const n = self.workflow.steps.len;
        const visited = try self.allocator.alloc(bool, n);
        defer self.allocator.free(visited);
        @memset(visited, false);

        var order = std.ArrayList(usize).init(self.allocator);
        defer order.deinit(self.allocator);

        for (0..n) |i| {
            if (!visited[i]) {
                try self.visit(i, visited, &order);
            }
        }

        return order.toOwnedSlice(self.allocator);
    }

    fn visit(self: *const WorkflowExecutor, idx: usize, visited: []bool, order: *std.ArrayList(usize)) !void {
        if (visited[idx]) return;
        visited[idx] = true;

        const step = &self.workflow.steps[idx];
        for (step.depends_on) |dep_name| {
            const dep_idx = self.findStepIndex(dep_name) orelse continue;
            try self.visit(dep_idx, visited, order);
        }

        try order.append(self.allocator, idx);
    }

    fn findStepIndex(self: *const WorkflowExecutor, name: []const u8) ?usize {
        for (self.workflow.steps, 0..) |step, i| {
            if (std.mem.eql(u8, step.name, name)) return i;
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Trinity Identity" {
    try std.testing.expect(verifyTrinityIdentity());
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
}

test "Command Registry" {
    const allocator = std.testing.allocator;
    var registry = try CommandRegistry.init(allocator);
    defer registry.deinit();

    try std.testing.expectEqual(registry.total_count, 0);
}

test "Register All Commands" {
    const allocator = std.testing.allocator;
    var registry = try registerAllCommands(allocator);
    defer registry.deinit();

    try std.testing.expect(registry.total_count >= 130);
    try std.testing.expect(registry.trinity_verified);
}
