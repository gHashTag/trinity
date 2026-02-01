const std = @import("std");
const moe = @import("moe_router.zig");
const dao = @import("dao_integration.zig");

// ============================================================================
// TRINITY: AGENT LOOP (PHASE 17) - ReAct Pattern with MoE Routing
// Thought → Action → Observation → Repeat
// ============================================================================

/// Agent execution state
pub const AgentState = enum {
    Idle,
    Thinking,
    Planning,
    Acting,
    Observing,
    Done,
    Error,

    pub fn getIcon(self: AgentState) []const u8 {
        return switch (self) {
            .Idle => "💤",
            .Thinking => "🤔",
            .Planning => "📋",
            .Acting => "⚡",
            .Observing => "👁️",
            .Done => "✅",
            .Error => "❌",
        };
    }
};

/// Tool types available to the agent
pub const Tool = enum {
    Infer, // Run inference on a model
    Convert, // Convert model formats
    Stake, // Stake TRI tokens
    Vote, // Vote on DAO proposals
    WebSearch, // External: web search (mock)
    CodeExec, // External: code execution (mock)
    FindJobs, // Find jobs in Trinity L2

    pub fn getName(self: Tool) []const u8 {
        return switch (self) {
            .Infer => "infer",
            .Convert => "convert",
            .Stake => "stake",
            .Vote => "vote",
            .WebSearch => "web_search",
            .CodeExec => "code_exec",
            .FindJobs => "find_jobs",
        };
    }

    pub fn getDescription(self: Tool) []const u8 {
        return switch (self) {
            .Infer => "Run inference on ternary models (Mistral-7B.tri, Qwen2.5-Coder-7B.tri)",
            .Convert => "Convert models to ternary format",
            .Stake => "Stake $TRI tokens with tier (bronze/silver/gold)",
            .Vote => "Vote on DAO proposals (yes/no)",
            .WebSearch => "Search the web for information",
            .CodeExec => "Execute generated code",
            .FindJobs => "Find available jobs in Trinity L2 network",
        };
    }
};

/// Action to be executed
pub const Action = struct {
    tool: Tool,
    args: []const []const u8,
    confidence: f32 = 1.0,
};

/// Single step in agent history
pub const Step = struct {
    thought: []const u8,
    action: ?Action,
    observation: []const u8,
    state: AgentState,
    expert_used: moe.Expert,
};

/// Thought result from reasoning
pub const ThoughtResult = struct {
    thought: []const u8,
    suggested_tool: ?Tool,
    suggested_args: []const []const u8,
    confidence: f32,
    should_finish: bool,
};

/// Observation result from action
pub const ObservationResult = struct {
    success: bool,
    output: []const u8,
    error_msg: ?[]const u8 = null,
    reward: f32 = 0.0, // Mock TRI reward
};

/// Agent configuration
pub const AgentConfig = struct {
    max_steps: usize = 10,
    verbose: bool = true,
    self_healing: bool = true,
    streaming: bool = true,
};

/// Main Agent Loop implementation
pub const AgentLoop = struct {
    allocator: std.mem.Allocator,
    router: *moe.MoERouter,
    dao_manager: dao.DAOManager,
    config: AgentConfig,
    state: AgentState = .Idle,
    history: std.ArrayListUnmanaged(Step),
    current_task: []const u8 = "",
    total_reward: f32 = 0.0,
    error_count: u32 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, router: *moe.MoERouter, config: AgentConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .router = router,
            .dao_manager = dao.DAOManager.init(allocator),
            .config = config,
            .history = .{},
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit(self.allocator);
        self.dao_manager.deinit();
        self.allocator.destroy(self);
    }

    /// Main agent execution loop
    pub fn run(self: *Self, task: []const u8) !void {
        self.current_task = task;
        self.state = .Thinking;
        self.error_count = 0;

        if (self.config.verbose) {
            std.debug.print("\n🚀 [Agent] Starting task: \"{s}\"\n", .{task});
            std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        }

        // Route to experts
        const route_result = self.router.route(task);
        if (self.config.verbose) {
            moe.MoERouter.printRoute(route_result);
        }

        // ReAct loop
        var step_count: usize = 0;
        while (step_count < self.config.max_steps and self.state != .Done and self.state != .Error) : (step_count += 1) {
            if (self.config.verbose) {
                std.debug.print("\n── Step {d} ──\n", .{step_count + 1});
            }

            // THINK
            self.state = .Thinking;
            const thought = self.think(route_result.selected[0]);

            if (self.config.streaming) {
                std.debug.print("💭 Thought: {s}\n", .{thought.thought});
            }

            if (thought.should_finish) {
                self.state = .Done;
                break;
            }

            // PLAN (if needed)
            if (thought.suggested_tool == null) {
                self.state = .Planning;
                if (self.config.streaming) {
                    std.debug.print("📋 Plan: Analyzing task requirements...\n", .{});
                }
                continue;
            }

            // ACT
            self.state = .Acting;
            const action = Action{
                .tool = thought.suggested_tool.?,
                .args = thought.suggested_args,
                .confidence = thought.confidence,
            };

            if (self.config.streaming) {
                std.debug.print("⚡ Action: {s}(", .{action.tool.getName()});
                for (action.args, 0..) |arg, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    std.debug.print("\"{s}\"", .{arg});
                }
                std.debug.print(")\n", .{});
            }

            const observation = self.act(action) catch |err| {
                if (self.config.self_healing) {
                    self.selfHeal(err, route_result);
                    continue;
                }
                self.state = .Error;
                break;
            };

            // OBSERVE
            self.state = .Observing;
            if (self.config.streaming) {
                std.debug.print("👁️ Observation: {s}\n", .{observation.output});
                if (observation.reward > 0) {
                    std.debug.print("💰 Reward: +{d:.2} $TRI\n", .{observation.reward});
                }
            }

            self.total_reward += observation.reward;

            // Record step in history
            try self.history.append(self.allocator, .{
                .thought = thought.thought,
                .action = action,
                .observation = observation.output,
                .state = self.state,
                .expert_used = route_result.selected[0],
            });

            // Check if task is complete
            if (self.isTaskComplete(observation)) {
                self.state = .Done;
            }
        }

        // Final summary
        if (self.config.verbose) {
            std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
            std.debug.print("{s} [Agent] Task completed in {d} steps\n", .{ self.state.getIcon(), step_count });
            std.debug.print("💰 Total rewards: {d:.2} $TRI\n", .{self.total_reward});
        }
    }

    /// Thinking phase - analyze task and decide next action
    fn think(self: *Self, expert: moe.Expert) ThoughtResult {
        _ = self;
        // Mock reasoning based on expert type
        return switch (expert) {
            .Inference => .{
                .thought = "Need to run inference on ternary model",
                .suggested_tool = .Infer,
                .suggested_args = &[_][]const u8{ "mistral-7b.tri", "--turbo" },
                .confidence = 0.9,
                .should_finish = false,
            },
            .Network => .{
                .thought = "Network operation required - checking staking/voting",
                .suggested_tool = .Stake,
                .suggested_args = &[_][]const u8{ "10000", "--tier", "gold" },
                .confidence = 0.85,
                .should_finish = false,
            },
            .CodeGen => .{
                .thought = "Code generation task detected",
                .suggested_tool = .CodeExec,
                .suggested_args = &[_][]const u8{"generate_optimization"},
                .confidence = 0.8,
                .should_finish = false,
            },
            .Planning => .{
                .thought = "Multi-step task - need to create execution plan",
                .suggested_tool = null,
                .suggested_args = &[_][]const u8{},
                .confidence = 0.7,
                .should_finish = false,
            },
        };
    }

    /// Action execution phase
    fn act(self: *Self, action: Action) !ObservationResult {
        return switch (action.tool) {
            .Infer => .{
                .success = true,
                .output = "Inference complete: Mistral-7B.tri loaded, 42 tokens generated",
                .reward = 1.0,
            },
            .Stake => blk: {
                const amount = std.fmt.parseFloat(f64, action.args[0]) catch 1000.0;
                try self.dao_manager.stake(amount, .GOLD);
                break :blk .{
                    .success = true,
                    .output = "Staked successfully in GOLD tier",
                    .reward = @floatCast(amount * 0.001),
                };
            },
            .Vote => blk: {
                try self.dao_manager.vote("proposal_42", true);
                break :blk .{
                    .success = true,
                    .output = "Vote cast: YES on proposal_42",
                    .reward = 0.5,
                };
            },
            .FindJobs => .{
                .success = true,
                .output = "Found 3 jobs in Trinity L2: [inference_task_1, staking_reward_2, code_review_3]",
                .reward = 0.1,
            },
            .WebSearch => .{
                .success = true,
                .output = "[Mock] Web search results: Found relevant documentation",
                .reward = 0.0,
            },
            .CodeExec => .{
                .success = true,
                .output = "[Mock] Code executed successfully: optimization applied",
                .reward = 2.0,
            },
            .Convert => .{
                .success = true,
                .output = "Model converted to ternary format",
                .reward = 0.5,
            },
        };
    }

    /// Self-healing: switch experts or mutate strategy on error
    fn selfHeal(self: *Self, err: anyerror, route_result: moe.RouteResult) void {
        self.error_count += 1;
        if (self.config.verbose) {
            std.debug.print("🩹 [Self-Healing] Error: {s}, switching to backup expert\n", .{@errorName(err)});
        }

        // Switch to second expert if available
        if (route_result.selected_count > 1) {
            std.debug.print("🔄 Switching from {s} to {s}\n", .{
                route_result.selected[0].getName(),
                route_result.selected[1].getName(),
            });
        }

        // Reset state to thinking
        self.state = .Thinking;
    }

    /// Check if task is complete
    fn isTaskComplete(self: *Self, observation: ObservationResult) bool {
        _ = self;
        return observation.success and observation.reward > 0;
    }

    /// Get agent history
    pub fn getHistory(self: *Self) []const Step {
        return self.history.items;
    }
};

// ============================================================================
// CLI INTERFACE
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🌟 TRINITY AGENT LOOP - PHASE 17\n", .{});
    std.debug.print("   ReAct Pattern with MoE Routing\n\n", .{});

    // Initialize MoE router
    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    // Initialize agent
    var agent = try AgentLoop.init(allocator, router, .{
        .verbose = true,
        .streaming = true,
        .self_healing = true,
        .max_steps = 5,
    });
    defer agent.deinit();

    // Demo tasks
    const demo_tasks = [_][]const u8{
        "Запусти инференс на Mistral-7B и застейкай 10000 TRI",
        "Максимизируй earnings на моём node в Ko Samui",
    };

    for (demo_tasks) |task| {
        try agent.run(task);
        std.debug.print("\n", .{});
    }

    std.debug.print("✅ Agent Loop Phase 17 Complete!\n", .{});
}
