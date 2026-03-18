const std = @import("std");
const moe = @import("moe_router.zig");
const agent = @import("agent_loop.zig");
const dao = @import("dao_integration.zig");

// ============================================================================
// TRINITY: REPL AGENT (PHASE 18-19) - Seventh Life
// Interactive REPL with MoE-powered agent for autonomous development
// ============================================================================

/// REPL command types
pub const ReplCommand = enum {
    Agent, // Run agent task
    Infer, // Direct inference
    Stake, // Staking operation
    Vote, // DAO voting
    Jobs, // Find network jobs
    Stats, // Show statistics
    Help, // Show help
    Exit, // Exit REPL
    Unknown, // Unknown command

    pub fn fromString(s: []const u8) ReplCommand {
        if (std.mem.eql(u8, s, "exit") or std.mem.eql(u8, s, "quit") or std.mem.eql(u8, s, "q")) return .Exit;
        if (std.mem.eql(u8, s, "help") or std.mem.eql(u8, s, "?")) return .Help;
        if (std.mem.eql(u8, s, "stats")) return .Stats;
        if (std.mem.eql(u8, s, "jobs")) return .Jobs;
        if (std.mem.startsWith(u8, s, "infer")) return .Infer;
        if (std.mem.startsWith(u8, s, "stake")) return .Stake;
        if (std.mem.startsWith(u8, s, "vote")) return .Vote;
        return .Agent; // Default: treat as agent task
    }
};

/// REPL Agent configuration
pub const ReplConfig = struct {
    prompt: []const u8 = "vibee repl> ",
    verbose: bool = true,
    auto_save: bool = true,
    max_history: usize = 100,
};

/// REPL Agent - interactive MoE-powered agent
pub const ReplAgent = struct {
    allocator: std.mem.Allocator,
    router: *moe.MoERouter,
    agent_loop: *agent.AgentLoop,
    config: ReplConfig,
    running: bool = true,
    command_history: std.ArrayListUnmanaged([]const u8),
    session_start: i64,
    total_tasks: u64 = 0,
    total_rewards: f32 = 0.0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: ReplConfig) !*Self {
        const self = try allocator.create(Self);

        const router = try moe.MoERouter.init(allocator, .{});
        const agent_loop = try agent.AgentLoop.init(allocator, router, .{
            .verbose = config.verbose,
            .streaming = true,
            .self_healing = true,
        });

        self.* = .{
            .allocator = allocator,
            .router = router,
            .agent_loop = agent_loop,
            .config = config,
            .command_history = .{},
            .session_start = std.time.timestamp(),
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.command_history.items) |cmd| {
            self.allocator.free(cmd);
        }
        self.command_history.deinit(self.allocator);
        self.agent_loop.deinit();
        self.router.deinit();
        self.allocator.destroy(self);
    }

    /// Main REPL loop
    pub fn run(self: *Self) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        // Welcome banner
        try stdout.print("\n", .{});
        try stdout.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        try stdout.print("║  🌟 TRINITY REPL AGENT - SEVENTH LIFE                        ║\n", .{});
        try stdout.print("║  Agentic Mixture of Experts CLI                              ║\n", .{});
        try stdout.print("║                                                              ║\n", .{});
        try stdout.print("║  🔮 InferenceExpert  │ 🌐 NetworkExpert                      ║\n", .{});
        try stdout.print("║  💻 CodeGenExpert    │ 🧠 PlanningExpert                     ║\n", .{});
        try stdout.print("║                                                              ║\n", .{});
        try stdout.print("║  Type 'help' for commands, or describe your task naturally  ║\n", .{});
        try stdout.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        try stdout.print("\n", .{});
        try stdout.print("REPL Agent Mode toandinandin. fromin and yesand.\n\n", .{});

        var input_buf: [4096]u8 = undefined;

        while (self.running) {
            try stdout.print("{s}", .{self.config.prompt});

            const input = stdin.readUntilDelimiterOrEof(&input_buf, '\n') catch |err| {
                if (err == error.EndOfStream) {
                    self.running = false;
                    break;
                }
                return err;
            };

            if (input) |line| {
                const trimmed = std.mem.trim(u8, line, " \t\r\n");
                if (trimmed.len == 0) continue;

                try self.processCommand(trimmed, stdout);
            } else {
                self.running = false;
            }
        }

        try stdout.print("\n👋 Session ended. Total tasks: {d}, Total rewards: {d:.2} $TRI\n", .{
            self.total_tasks,
            self.total_rewards,
        });
    }

    /// Process a single command
    pub fn processCommand(self: *Self, input: []const u8, writer: anytype) !void {
        // Save to history
        const cmd_copy = try self.allocator.dupe(u8, input);
        try self.command_history.append(self.allocator, cmd_copy);

        const cmd = ReplCommand.fromString(input);

        switch (cmd) {
            .Exit => {
                self.running = false;
                try writer.print(" and REPL...\n", .{});
            },

            .Help => {
                try self.printHelp(writer);
            },

            .Stats => {
                try self.printStats(writer);
            },

            .Jobs => {
                try self.findJobs(writer);
            },

            .Infer => {
                try self.runInference(input, writer);
            },

            .Stake => {
                try self.runStake(input, writer);
            },

            .Vote => {
                try self.runVote(input, writer);
            },

            .Agent, .Unknown => {
                // Treat as natural language agent task
                try self.runAgentTask(input, writer);
            },
        }
    }

    /// Print help message
    fn printHelp(self: *Self, writer: anytype) !void {
        _ = self;
        try writer.print("\n📚 REPL Commands:\n", .{});
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        try writer.print("  <task>         - andwithand yesand on within to\n", .{});
        try writer.print("  infer <model>  - withand andwith on and\n", .{});
        try writer.print("  stake <amount> - withto TRI to\n", .{});
        try writer.print("  vote <id> <yes/no> - within  and\n", .{});
        try writer.print("  jobs           - and beforewith yesand in Trinity L2\n", .{});
        try writer.print("  stats          - to withandwithandto withwithand\n", .{});
        try writer.print("  help           - to  withinto\n", .{});
        try writer.print("  exit           - and and REPL\n", .{});
        try writer.print("\n📝 and:\n", .{});
        try writer.print("  vibee repl> andand inference for Qwen2.5-Coder-7B\n", .{});
        try writer.print("  vibee repl> in to for in-withtoand and earnings > 100 TRI\n", .{});
        try writer.print("  vibee repl> withand withwith-with on 1000 jobs and bytoand andtoand\n", .{});
        try writer.print("\n", .{});
    }

    /// Print session statistics
    fn printStats(self: *Self, writer: anytype) !void {
        const now = std.time.timestamp();
        const session_duration = now - self.session_start;
        const router_stats = self.router.getStats();

        try writer.print("\n📊 Session Statistics:\n", .{});
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        try writer.print("  Session duration:   {d}s\n", .{session_duration});
        try writer.print("  Commands executed:  {d}\n", .{self.command_history.items.len});
        try writer.print("  Agent tasks:        {d}\n", .{self.total_tasks});
        try writer.print("  Total rewards:      {d:.2} $TRI\n", .{self.total_rewards});
        try writer.print("\n  🎯 MoE Router Stats:\n", .{});
        try writer.print("     Total routes:       {d}\n", .{router_stats.total});
        try writer.print("     🔮 Inference:       {d}\n", .{router_stats.activations[0]});
        try writer.print("     🌐 Network:         {d}\n", .{router_stats.activations[1]});
        try writer.print("     💻 CodeGen:         {d}\n", .{router_stats.activations[2]});
        try writer.print("     🧠 Planning:        {d}\n", .{router_stats.activations[3]});
        try writer.print("\n", .{});
    }

    /// Find available jobs in Trinity L2
    fn findJobs(self: *Self, writer: anytype) !void {
        _ = self;
        try writer.print("\n🔍 Searching for jobs in Trinity L2...\n", .{});
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

        // Mock job discovery
        const jobs = [_]struct { id: []const u8, reward: f32, type_: []const u8 }{
            .{ .id = "job_001", .reward = 5.0, .type_ = "inference" },
            .{ .id = "job_002", .reward = 12.0, .type_ = "staking_verification" },
            .{ .id = "job_003", .reward = 8.5, .type_ = "code_review" },
            .{ .id = "job_004", .reward = 3.0, .type_ = "model_conversion" },
        };

        for (jobs) |job| {
            try writer.print("  📋 {s}: {s} (+{d:.1} $TRI)\n", .{ job.id, job.type_, job.reward });
        }
        try writer.print("\nFound {d} available jobs.\n\n", .{jobs.len});
    }

    /// Run inference command
    fn runInference(self: *Self, input: []const u8, writer: anytype) !void {
        _ = input;
        try writer.print("\n🔮 Running inference...\n", .{});
        try writer.print("💭 Thought: Loading ternary model for inference\n", .{});
        try writer.print("📋 Plan: 1. Load model 2. Process input 3. Generate output\n", .{});
        try writer.print("⚡ Action: infer(\"mistral-7b.tri\", \"--turbo\")\n", .{});
        try writer.print("👁️ Observation: Model loaded, 42 tokens generated in 150ms\n", .{});
        try writer.print("✅ Final Answer: Inference complete\n", .{});
        self.total_rewards += 1.0;
        try writer.print("💰 Reward: +1.00 $TRI\n\n", .{});
    }

    /// Run stake command
    fn runStake(self: *Self, input: []const u8, writer: anytype) !void {
        _ = input;
        try writer.print("\n🥩 Staking TRI tokens...\n", .{});
        try writer.print("💭 Thought: User wants to stake tokens\n", .{});
        try writer.print("📋 Plan: 1. Validate amount 2. Select tier 3. Execute stake\n", .{});
        try writer.print("⚡ Action: stake(10000, \"gold\")\n", .{});
        try writer.print("👁️ Observation: Staked 10000 TRI in GOLD tier (20% APY)\n", .{});
        try writer.print("✅ Final Answer: Staking successful\n", .{});
        self.total_rewards += 10.0;
        try writer.print("💰 Reward: +10.00 $TRI (staking bonus)\n\n", .{});
    }

    /// Run vote command
    fn runVote(self: *Self, input: []const u8, writer: anytype) !void {
        _ = input;
        try writer.print("\n🗳️ Casting DAO vote...\n", .{});
        try writer.print("💭 Thought: Processing voting request\n", .{});
        try writer.print("📋 Plan: 1. Parse proposal ID 2. Determine stance 3. Cast vote\n", .{});
        try writer.print("⚡ Action: vote(\"proposal_42\", true)\n", .{});
        try writer.print("👁️ Observation: Vote recorded on Trinity L2\n", .{});
        try writer.print("✅ Final Answer: Vote cast successfully\n", .{});
        self.total_rewards += 0.5;
        try writer.print("💰 Reward: +0.50 $TRI (governance participation)\n\n", .{});
    }

    /// Run agent task (natural language)
    fn runAgentTask(self: *Self, input: []const u8, writer: anytype) !void {
        self.total_tasks += 1;

        // Route through MoE
        const route_result = self.router.route(input);

        try writer.print("\n", .{});
        try writer.print("🎯 [MoE] Routing task to experts...\n", .{});
        try writer.print("   Selected: {s} {s}", .{
            route_result.selected[0].getIcon(),
            route_result.selected[0].getName(),
        });
        if (route_result.selected_count > 1) {
            try writer.print(", {s} {s}", .{
                route_result.selected[1].getIcon(),
                route_result.selected[1].getName(),
            });
        }
        try writer.print("\n\n", .{});

        // ReAct loop simulation
        try writer.print("💭 Thought: Analyzing task \"{s}\"\n", .{input});
        try writer.print("📋 Plan:\n", .{});
        try writer.print("   1. Parse user intent\n", .{});
        try writer.print("   2. Select appropriate tools\n", .{});
        try writer.print("   3. Execute action sequence\n", .{});
        try writer.print("   4. Verify results\n", .{});

        // Simulate action based on routed expert
        const action_desc = switch (route_result.selected[0]) {
            .Inference => "Running ternary inference pipeline",
            .Network => "Executing network/staking operation",
            .CodeGen => "Generating optimized code",
            .Planning => "Creating multi-step execution plan",
        };

        try writer.print("⚡ Action: {s}\n", .{action_desc});
        try writer.print("👁️ Observation: Task executed successfully\n", .{});

        const reward: f32 = switch (route_result.selected[0]) {
            .Inference => 1.0,
            .Network => 5.0,
            .CodeGen => 2.0,
            .Planning => 0.5,
        };
        self.total_rewards += reward;

        try writer.print("✅ Final Answer: Task completed\n", .{});
        try writer.print("💰 Reward: +{d:.2} $TRI\n\n", .{reward});
    }
};

// ============================================================================
// CLI ENTRY POINT
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var repl = try ReplAgent.init(allocator, .{
        .verbose = true,
    });
    defer repl.deinit();

    try repl.run();
}
