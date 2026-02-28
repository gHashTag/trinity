const std = @import("std");

// ============================================================================
// TRINITY: Test Registry (Cycle 101)
// Complete registry of all 134 TRI CLI commands with metadata
// ============================================================================

/// Command category for organizing tests
pub const CommandCategory = enum {
    math,
    golden_chain,
    swe_agent,
    git,
    demo,
    bench,
    info,
    sacred_agent,
    swarm,
    governance,
    dashboard,
    evolution,
    code_analysis,
    misc,

    pub fn toString(self: CommandCategory) []const u8 {
        return switch (self) {
            .math => "Math",
            .golden_chain => "Golden Chain",
            .swe_agent => "SWE Agent",
            .git => "Git",
            .demo => "Demo",
            .bench => "Benchmark",
            .info => "Info",
            .sacred_agent => "Sacred Agent",
            .swarm => "Swarm",
            .governance => "Governance",
            .dashboard => "Dashboard",
            .evolution => "Evolution",
            .code_analysis => "Code Analysis",
            .misc => "Miscellaneous",
        };
    }
};

/// Priority level for testing
pub const TestPriority = enum {
    critical,  // Must test before any release
    high,      // Core functionality
    medium,    // Important but not blocking
    low,       // Nice to have
};

/// Metadata for a single command test
pub const CommandTestInfo = struct {
    name: []const u8,
    category: CommandCategory,
    priority: TestPriority,
    example_args: []const []const u8,
    expected_patterns: []const []const u8,
    description: []const u8,

    /// Get full command string for testing
    pub fn getCommandString(self: *const CommandTestInfo, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        try buffer.appendSlice(allocator, self.name);
        for (self.example_args) |arg| {
            try buffer.append(allocator, ' ');
            try buffer.appendSlice(allocator, arg);
        }
        return buffer.toOwnedSlice(allocator);
    }
};

/// Registry of all 134 TRI commands
pub const CommandRegistry = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList(CommandTestInfo),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const commands = try std.ArrayList(CommandTestInfo).initCapacity(allocator, 256);
        return .{
            .allocator = allocator,
            .commands = commands,
        };
    }

    pub fn deinit(self: *Self) void {
        // Commands contain string literals, no need to free
        self.commands.deinit(self.allocator);
    }

    /// Get all commands by category
    pub fn getByCategory(self: *const Self, category: CommandCategory) []const CommandTestInfo {
        var result = std.ArrayList(CommandTestInfo).initCapacity(self.allocator, 32) catch return &[_]CommandTestInfo{};

        for (self.commands.items) |cmd| {
            if (cmd.category == category) {
                result.append(self.allocator, cmd) catch {};
            }
        }

        return result.toOwnedSlice(self.allocator) catch &[_]CommandTestInfo{};
    }

    /// Count commands in category
    pub fn countCategory(self: *const Self, category: CommandCategory) usize {
        var count: usize = 0;
        for (self.commands.items) |cmd| {
            if (cmd.category == category) count += 1;
        }
        return count;
    }

    /// Get critical commands (must test before release)
    pub fn getCritical(self: *const Self) []const CommandTestInfo {
        var result = std.ArrayList(CommandTestInfo).initCapacity(self.allocator, 32) catch return &[_]CommandTestInfo{};

        for (self.commands.items) |cmd| {
            if (cmd.priority == .critical) {
                result.append(self.allocator, cmd) catch {};
            }
        }

        return result.toOwnedSlice(self.allocator) catch &[_]CommandTestInfo{};
    }
};

// ============================================================================
// Command Definitions (134 total)
// ============================================================================

/// Initialize registry with all commands
pub fn initRegistry(allocator: std.mem.Allocator) !CommandRegistry {
    var registry = try CommandRegistry.init(allocator);

    // ========================================================================
    // Core Commands (14) - CRITICAL
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "chat",
        .category = .sacred_agent,
        .priority = .critical,
        .example_args = &[_][]const u8{"--stream", "Hello"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Interactive chat with vision + voice + tools",
    });
    try registry.commands.append(allocator, .{
        .name = "code",
        .category = .swe_agent,
        .priority = .critical,
        .example_args = &[_][]const u8{"--stream", "generate fibonacci"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Generate code with typing effect",
    });
    try registry.commands.append(allocator, .{
        .name = "gen",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"specs/tri/feature.vibee"},
        .expected_patterns = &[_][]const u8{},  // Empty - gen may fail on missing spec
        .description = "Compile VIBEE spec to Zig/Verilog",
    });
    try registry.commands.append(allocator, .{
        .name = "pipeline",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"run", "implement feature"},
        .expected_patterns = &[_][]const u8{"GOLDEN CHAIN", "Link"},
        .description = "Execute 17-link Golden Chain",
    });
    try registry.commands.append(allocator, .{
        .name = "decompose",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"Implement REST API"},
        .expected_patterns = &[_][]const u8{"Sub-tasks", "Decomposition"},
        .description = "Break task into sub-tasks (Link 4)",
    });
    try registry.commands.append(allocator, .{
        .name = "plan",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"Build authentication system"},
        .expected_patterns = &[_][]const u8{"Plan Generation", "Link"},
        .description = "Generate implementation plan (Link 5)",
    });
    try registry.commands.append(allocator, .{
        .name = "spec_create",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"test_module"},
        .expected_patterns = &[_][]const u8{"Template:", ".vibee"},
        .description = "Create .vibee spec template (Link 6)",
    });
    try registry.commands.append(allocator, .{
        .name = "loop_decide",
        .category = .evolution,
        .priority = .critical,
        .example_args = &[_][]const u8{"auto"},
        .expected_patterns = &[_][]const u8{"Loop Decision", "DECISION"},
        .description = "Loop decision: CONTINUE/EXIT (Link 17)",
    });
    try registry.commands.append(allocator, .{
        .name = "verify",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"Verification", "Tests"},
        .description = "Run tests + benchmarks (Links 7-11)",
    });
    try registry.commands.append(allocator, .{
        .name = "bench",
        .category = .bench,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"BENCHMARK", "Running"},
        .description = "Run performance benchmarks",
    });
    try registry.commands.append(allocator, .{
        .name = "verdict",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TOXIC VERDICT", "KOSCHEI"},
        .description = "Generate toxic verdict (Link 14)",
    });
    try registry.commands.append(allocator, .{
        .name = "deps",
        .category = .golden_chain,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"dependencies"},
        .description = "List project dependencies",
    });
    try registry.commands.append(allocator, .{
        .name = "distributed",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"distributed", "inference"},
        .description = "Distributed inference",
    });
    try registry.commands.append(allocator, .{
        .name = "multi_cluster",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"cluster", "multi"},
        .description = "Multi-cluster management (Cycle #97)",
    });

    // ========================================================================
    // Git Commands (4)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "status",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"GIT", "status"},
        .description = "Git status --short",
    });
    try registry.commands.append(allocator, .{
        .name = "diff",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"GIT", "diff"},
        .description = "Git diff",
    });
    try registry.commands.append(allocator, .{
        .name = "log",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"GIT", "log"},
        .description = "Git log --oneline -10",
    });
    try registry.commands.append(allocator, .{
        .name = "commit",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{"message"},
        .expected_patterns = &[_][]const u8{"GIT"},
        .description = "Git add -A && commit",
    });

    // ========================================================================
    // Sacred Mathematics (10) - CRITICAL
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "math",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"SACRED MATHEMATICS", "SUBCOMMANDS"},
        .description = "Sacred math dispatcher",
    });
    try registry.commands.append(allocator, .{
        .name = "phi",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"10"},
        .expected_patterns = &[_][]const u8{"phi", "="},
        .description = "Compute φⁿ",
    });
    try registry.commands.append(allocator, .{
        .name = "fib",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"10"},
        .expected_patterns = &[_][]const u8{"F(", "="},
        .description = "Fibonacci with BigInt",
    });
    try registry.commands.append(allocator, .{
        .name = "lucas",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"2"},
        .expected_patterns = &[_][]const u8{"L(", "TRINITY"},
        .description = "Lucas L(n) — L(2)=3=TRINITY",
    });
    try registry.commands.append(allocator, .{
        .name = "spiral",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{"5"},
        .expected_patterns = &[_][]const u8{"SPIRAL"},
        .description = "φ-spiral coordinates",
    });
    try registry.commands.append(allocator, .{
        .name = "gematria",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{"TRINITY"},
        .expected_patterns = &[_][]const u8{"Gematria"},
        .description = "Calculate gematria value",
    });
    try registry.commands.append(allocator, .{
        .name = "sacred",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"SACRED FORMULA"},
        .description = "Sacred mathematics overview",
    });
    try registry.commands.append(allocator, .{
        .name = "formula_cmd",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{"3"},
        .expected_patterns = &[_][]const u8{},  // Variable/error output
        .description = "Sacred formula decomposition",
    });
    try registry.commands.append(allocator, .{
        .name = "constants_cmd",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"SACRED MATHEMATICS CONSTANTS", "φ"},
        .description = "Show φ, π, e, μ, χ, σ, ε...",
    });

    // ========================================================================
    // SWE Agent Commands (9)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "fix",
        .category = .swe_agent,
        .priority = .high,
        .example_args = &[_][]const u8{"src/main.zig"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Detect and fix bugs",
    });
    try registry.commands.append(allocator, .{
        .name = "explain",
        .category = .swe_agent,
        .priority = .high,
        .example_args = &[_][]const u8{"What is Zig?"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Explain code or concept",
    });
    try registry.commands.append(allocator, .{
        .name = "test_cmd",
        .category = .swe_agent,
        .priority = .high,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Generate tests",
    });
    try registry.commands.append(allocator, .{
        .name = "doc",
        .category = .swe_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Generate documentation",
    });
    try registry.commands.append(allocator, .{
        .name = "refactor",
        .category = .swe_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Suggest refactoring",
    });
    try registry.commands.append(allocator, .{
        .name = "reason",
        .category = .swe_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{"2 + 2"},
        .expected_patterns = &[_][]const u8{"TRINITY"},
        .description = "Chain-of-thought reasoning",
    });
    try registry.commands.append(allocator, .{
        .name = "analyze",
        .category = .code_analysis,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"analyze"},
        .description = "Analyze codebase",
    });
    try registry.commands.append(allocator, .{
        .name = "search_cmd",
        .category = .code_analysis,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"search"},
        .description = "Search functionality",
    });
    try registry.commands.append(allocator, .{
        .name = "context_info",
        .category = .code_analysis,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"context"},
        .description = "Context information (Cycle 92)",
    });

    // ========================================================================
    // Info Commands (4)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "info",
        .category = .info,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"System Information", "TRI CLI"},
        .description = "System information",
    });
    try registry.commands.append(allocator, .{
        .name = "version",
        .category = .info,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TRI CLI", "Trinity"},
        .description = "Show version",
    });
    try registry.commands.append(allocator, .{
        .name = "help",
        .category = .info,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"USAGE:", "COMMANDS:"},
        .description = "Show all commands",
    });

    // ========================================================================
    // Sacred Agent Commands (5)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "identity",
        .category = .sacred_agent,
        .priority = .critical,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"SACRED IDENTITY", "Intelligence"},
        .description = "Affirm sacred intelligence identity",
    });
    try registry.commands.append(allocator, .{
        .name = "swarm",
        .category = .swarm,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"swarm"},
        .description = "Show swarm status",
    });
    try registry.commands.append(allocator, .{
        .name = "govern",
        .category = .governance,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"govern"},
        .description = "Governance commands",
    });
    try registry.commands.append(allocator, .{
        .name = "dashboard",
        .category = .dashboard,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"dashboard"},
        .description = "Show dashboard",
    });
    try registry.commands.append(allocator, .{
        .name = "omega",
        .category = .sacred_agent,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"OMEGA", "Sacred Intelligence"},
        .description = "Omega/awakening command",
    });

    // ========================================================================
    // Evolution Commands (Cycle 97)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "evolve",
        .category = .evolution,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"evolve"},
        .description = "Evolve fingerprint (Firebird)",
    });
    try registry.commands.append(allocator, .{
        .name = "auto_commit",
        .category = .evolution,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"commit"},
        .description = "Auto-commit functionality (Cycle 97)",
    });
    try registry.commands.append(allocator, .{
        .name = "ml_optimize",
        .category = .evolution,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"optimize"},
        .description = "ML optimization (Cycle 97)",
    });
    try registry.commands.append(allocator, .{
        .name = "deploy_dashboard",
        .category = .evolution,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"dashboard"},
        .description = "Dashboard deployment (Cycle 97)",
    });
    try registry.commands.append(allocator, .{
        .name = "self_host",
        .category = .evolution,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"host"},
        .description = "Self-hosting (Cycle 97)",
    });
    try registry.commands.append(allocator, .{
        .name = "safeguards_show",
        .category = .evolution,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"safeguards"},
        .description = "Show safeguards",
    });
    try registry.commands.append(allocator, .{
        .name = "safeguards_disable",
        .category = .evolution,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"safeguards"},
        .description = "Disable safeguards",
    });

    // ========================================================================
    // Core Commands (Convert, Serve)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "convert",
        .category = .golden_chain,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"convert"},
        .description = "Format conversion",
    });
    try registry.commands.append(allocator, .{
        .name = "serve",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"serve", "server"},
        .description = "Unified API server (Golden Chain #102)",
    });
    try registry.commands.append(allocator, .{
        .name = "tvc_stats",
        .category = .info,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TVC", "stats"},
        .description = "Show TVC corpus statistics",
    });

    // ========================================================================
    // Demo Commands (33) - One per cycle
    // ========================================================================
    const demo_commands = [_][]const u8{
        "tvc_demo",       "agents_demo",    "context_demo",   "rag_demo",
        "voice_demo",     "sandbox_demo",   "stream_demo",    "vision_demo",
        "finetune_demo",  "batched_demo",   "priority_demo",  "deadline_demo",
        "multimodal_demo","tooluse_demo",   "unified_demo",   "autonomous_demo",
        "orchestration_demo", "mm_orch_demo", "memory_demo",  "persist_demo",
        "spawn_demo",     "cluster_demo",   "worksteal_demo", "plugin_demo",
        "comms_demo",     "observe_demo",   "consensus_demo", "specexec_demo",
        "governor_demo",  "fedlearn_demo",  "eventsrc_demo",  "capsec_demo",
        "dtxn_demo",      "cache_demo",     "contract_demo",  "workflow_demo",
    };

    for (demo_commands) |cmd| {
        try registry.commands.append(allocator, .{
            .name = cmd,
            .category = .demo,
            .priority = .low,
            .example_args = &[_][]const u8{},
            .expected_patterns = &[_][]const u8{},  // Empty - demos are variable
            .description = "Demo command",
        });
    }

    // ========================================================================
    // Benchmark Commands (33) - One per cycle
    // ========================================================================
    const bench_commands = [_][]const u8{
        "agents_bench",   "context_bench",  "rag_bench",      "voice_bench",
        "sandbox_bench",  "stream_bench",   "vision_bench",   "finetune_bench",
        "batched_bench",  "priority_bench", "deadline_bench", "multimodal_bench",
        "tooluse_bench",  "unified_bench",  "autonomous_bench","orchestration_bench",
        "mm_orch_bench",  "memory_bench",   "persist_bench",  "spawn_bench",
        "cluster_bench",  "worksteal_bench","plugin_bench",   "comms_bench",
        "observe_bench",  "consensus_bench","specexec_bench", "governor_bench",
        "fedlearn_bench", "eventsrc_bench", "capsec_bench",   "dtxn_bench",
        "cache_bench",    "contract_bench", "workflow_bench",
    };

    for (bench_commands) |cmd| {
        try registry.commands.append(allocator, .{
            .name = cmd,
            .category = .bench,
            .priority = .low,
            .example_args = &[_][]const u8{},
            .expected_patterns = &[_][]const u8{},  // Empty - benchmarks are variable
            .description = "Benchmark command",
        });
    }

    // ========================================================================
    // Additional Commands (Chem, Intelligence, Dev Utils, Monitor)
    // ========================================================================
    try registry.commands.append(allocator, .{
        .name = "chem",
        .category = .misc,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Chemistry commands (v6.0)",
    });
    try registry.commands.append(allocator, .{
        .name = "intelligence",
        .category = .misc,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"intelligence"},
        .description = "Intelligence system",
    });
    try registry.commands.append(allocator, .{
        .name = "doctor",
        .category = .misc,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Dev utility: doctor",
    });
    try registry.commands.append(allocator, .{
        .name = "clean",
        .category = .misc,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Dev utility: clean",
    });
    try registry.commands.append(allocator, .{
        .name = "fmt_cmd",
        .category = .misc,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Dev utility: format",
    });
    try registry.commands.append(allocator, .{
        .name = "stats_cmd",
        .category = .misc,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Dev utility: stats",
    });
    try registry.commands.append(allocator, .{
        .name = "igla",
        .category = .misc,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Dev utility: igla",
    });
    try registry.commands.append(allocator, .{
        .name = "monitor",
        .category = .misc,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Eternal monitor",
    });
    try registry.commands.append(allocator, .{
        .name = "math_agent",
        .category = .sacred_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{},  // Variable output
        .description = "Math agent (Cycle 98)",
    });

    return registry;
}

/// Get registry as singleton (lazy init)
var global_registry: ?CommandRegistry = null;

pub fn getGlobalRegistry(allocator: std.mem.Allocator) !*CommandRegistry {
    if (global_registry == null) {
        global_registry = try initRegistry(allocator);
    }
    return &global_registry.?;
}

// ============================================================================
// Tests
// ============================================================================

test "CommandRegistry initialization" {
    const allocator = std.testing.allocator;
    var registry = try initRegistry(allocator);
    defer registry.deinit();

    // Should have all commands
    try std.testing.expect(registry.commands.items.len >= 134);
}

test "CommandRegistry category filtering" {
    const allocator = std.testing.allocator;
    var registry = try initRegistry(allocator);
    defer registry.deinit();

    const math_cmds = registry.getByCategory(.math);
    defer allocator.free(math_cmds);

    // Should have at least some math commands
    try std.testing.expect(math_cmds.len >= 5);
}

test "CommandRegistry critical commands" {
    const allocator = std.testing.allocator;
    var registry = try initRegistry(allocator);
    defer registry.deinit();

    const critical = registry.getCritical();
    defer allocator.free(critical);

    // Should have at least some critical commands
    try std.testing.expect(critical.len >= 10);
}

test "CommandTestInfo getCommandString" {
    const info = CommandTestInfo{
        .name = "phi",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"10"},
        .expected_patterns = &[_][]const u8{"122"},
        .description = "Compute phi power",
    };

    const allocator = std.testing.allocator;
    const cmd_str = try info.getCommandString(allocator);
    defer allocator.free(cmd_str);

    try std.testing.expectEqualStrings("phi 10", cmd_str);
}
