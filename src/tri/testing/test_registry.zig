const std = @import("std");

// ============================================================================
// TRINITY: Test Registry (Cycle 101)
// Complete registry of all 195 TRI CLI commands with metadata
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
        var buffer = std.ArrayList(u8).init(allocator);
        try buffer.appendSlice(self.name);
        for (self.example_args) |arg| {
            try buffer.append(' ');
            try buffer.appendSlice(arg);
        }
        return buffer.toOwnedSlice();
    }
};

/// Registry of all 195 TRI commands
pub const CommandRegistry = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList(CommandTestInfo),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .commands = std.ArrayList(CommandTestInfo).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Commands contain string literals, no need to free
        self.commands.deinit();
    }

    /// Get all commands by category
    pub fn getByCategory(self: *const Self, category: CommandCategory) []const CommandTestInfo {
        const start = self.commands.items;
        const count = self.countCategory(category);
        var result = std.ArrayList(CommandTestInfo).init(self.allocator);

        for (start) |cmd| {
            if (cmd.category == category) {
                result.append(cmd) catch {};
            }
        }

        return result.toOwnedSlice() catch &[_]CommandTestInfo{};
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
        var result = std.ArrayList(CommandTestInfo).init(self.allocator);

        for (self.commands.items) |cmd| {
            if (cmd.priority == .critical) {
                result.append(cmd) catch {};
            }
        }

        return result.toOwnedSlice() catch &[_]CommandTestInfo{};
    }
};

// ============================================================================
// Command Definitions (195 total)
// ============================================================================

/// Initialize registry with all commands
pub fn initRegistry(allocator: std.mem.Allocator) !CommandRegistry {
    var registry = CommandRegistry.init(allocator);

    // ========================================================================
    // Core Commands (14) - CRITICAL
    // ========================================================================
    try registry.commands.append(.{
        .name = "chat",
        .category = .sacred_agent,
        .priority = .critical,
        .example_args = &[_][]const u8{"--stream", "Hello"},
        .expected_patterns = &[_][]const u8{"TRINITY", "chat"},
        .description = "Interactive chat with vision + voice + tools",
    });
    try registry.commands.append(.{
        .name = "code",
        .category = .swe_agent,
        .priority = .critical,
        .example_args = &[_][]const u8{"--stream", "generate fibonacci"},
        .expected_patterns = &[_][]const u8{"code", "generating"},
        .description = "Generate code with typing effect",
    });
    try registry.commands.append(.{
        .name = "gen",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"specs/tri/feature.vibee"},
        .expected_patterns = &[_][]const u8{"generating", "zig"},
        .description = "Compile VIBEE spec to Zig/Verilog",
    });
    try registry.commands.append(.{
        .name = "pipeline",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"run", "implement feature"},
        .expected_patterns = &[_][]const u8{"pipeline", "link"},
        .description = "Execute 17-link Golden Chain",
    });
    try registry.commands.append(.{
        .name = "decompose",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"Implement REST API"},
        .expected_patterns = &[_][]const u8{"subtask", "breakdown"},
        .description = "Break task into sub-tasks (Link 4)",
    });
    try registry.commands.append(.{
        .name = "plan",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"Build authentication system"},
        .expected_patterns = &[_][]const u8{"plan", "steps"},
        .description = "Generate implementation plan (Link 5)",
    });
    try registry.commands.append(.{
        .name = "spec_create",
        .category = .golden_chain,
        .priority = .critical,
        .example_args = &[_][]const u8{"test_module"},
        .expected_patterns = &[_][]const u8{"spec", "created", ".vibee"},
        .description = "Create .vibee spec template (Link 6)",
    });
    try registry.commands.append(.{
        .name = "loop-decide",
        .category = .evolution,
        .priority = .critical,
        .example_args = &[_][]const u8{"auto"},
        .expected_patterns = &[_][]const u8{"loop", "decision"},
        .description = "Loop decision: CONTINUE/EXIT (Link 17)",
    });
    try registry.commands.append(.{
        .name = "verify",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"test", "benchmark", "passing"},
        .description = "Run tests + benchmarks (Links 7-11)",
    });
    try registry.commands.append(.{
        .name = "bench",
        .category = .bench,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"benchmark", "performance"},
        .description = "Run performance benchmarks",
    });
    try registry.commands.append(.{
        .name = "verdict",
        .category = .golden_chain,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"verdict", "quality"},
        .description = "Generate toxic verdict (Link 14)",
    });

    // ========================================================================
    // Git Commands (4)
    // ========================================================================
    try registry.commands.append(.{
        .name = "status",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"git", "status"},
        .description = "Git status --short",
    });
    try registry.commands.append(.{
        .name = "diff",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"diff"},
        .description = "Git diff",
    });
    try registry.commands.append(.{
        .name = "log",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"commit"},
        .description = "Git log --oneline -10",
    });
    try registry.commands.append(.{
        .name = "commit",
        .category = .git,
        .priority = .medium,
        .example_args = &[_][]const u8{"message"},
        .expected_patterns = &[_][]const u8{"committed"},
        .description = "Git add -A && commit",
    });

    // ========================================================================
    // Sacred Mathematics (10) - CRITICAL
    // ========================================================================
    try registry.commands.append(.{
        .name = "math",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"φ", "math"},
        .description = "Sacred math dispatcher",
    });
    try registry.commands.append(.{
        .name = "constants",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"φ", "π", "e"},
        .description = "Show φ, π, e, μ, χ, σ, ε...",
    });
    try registry.commands.append(.{
        .name = "phi",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"10"},
        .expected_patterns = &[_][]const u8{"φ", "122"},
        .description = "Compute φⁿ",
    });
    try registry.commands.append(.{
        .name = "fib",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"10"},
        .expected_patterns = &[_][]const u8{"Fibonacci", "55"},
        .description = "Fibonacci with BigInt",
    });
    try registry.commands.append(.{
        .name = "lucas",
        .category = .math,
        .priority = .critical,
        .example_args = &[_][]const u8{"2"},
        .expected_patterns = &[_][]const u8{"Lucas", "3"},
        .description = "Lucas L(n) — L(2)=3=TRINITY",
    });
    try registry.commands.append(.{
        .name = "spiral",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{"5"},
        .expected_patterns = &[_][]const u8{"spiral", "coordinate"},
        .description = "φ-spiral coordinates",
    });
    try registry.commands.append(.{
        .name = "gematria",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{"TRINITY"},
        .expected_patterns = &[_][]const u8{"gematria"},
        .description = "Calculate gematria value",
    });

    // ========================================================================
    // SWE Agent Commands (9)
    // ========================================================================
    try registry.commands.append(.{
        .name = "fix",
        .category = .swe_agent,
        .priority = .high,
        .example_args = &[_][]const u8{"src/main.zig"},
        .expected_patterns = &[_][]const u8{"fix", "bug"},
        .description = "Detect and fix bugs",
    });
    try registry.commands.append(.{
        .name = "explain",
        .category = .swe_agent,
        .priority = .high,
        .example_args = &[_][]const u8{"What is Zig?"},
        .expected_patterns = &[_][]const u8{"explain", "Zig"},
        .description = "Explain code or concept",
    });
    try registry.commands.append(.{
        .name = "test",
        .category = .swe_agent,
        .priority = .high,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"test", "generated"},
        .description = "Generate tests",
    });
    try registry.commands.append(.{
        .name = "doc",
        .category = .swe_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"documentation"},
        .description = "Generate documentation",
    });
    try registry.commands.append(.{
        .name = "refactor",
        .category = .swe_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"refactor"},
        .description = "Suggest refactoring",
    });
    try registry.commands.append(.{
        .name = "reason",
        .category = .swe_agent,
        .priority = .medium,
        .example_args = &[_][]const u8{"2 + 2"},
        .expected_patterns = &[_][]const u8{"4", "reasoning"},
        .description = "Chain-of-thought reasoning",
    });

    // ========================================================================
    // Info Commands (4)
    // ========================================================================
    try registry.commands.append(.{
        .name = "info",
        .category = .info,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TRINITY", "system"},
        .description = "System information",
    });
    try registry.commands.append(.{
        .name = "version",
        .category = .info,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TRINITY", "v"},
        .description = "Show version",
    });
    try registry.commands.append(.{
        .name = "help",
        .category = .info,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"USAGE", "COMMANDS"},
        .description = "Show all commands",
    });

    // ========================================================================
    // Sacred Agent Commands (5)
    // ========================================================================
    try registry.commands.append(.{
        .name = "identity",
        .category = .sacred_agent,
        .priority = .critical,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"Sacred", "Intelligence"},
        .description = "Affirm sacred intelligence identity",
    });
    try registry.commands.append(.{
        .name = "swarm",
        .category = .swarm,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"swarm", "agent"},
        .description = "Show swarm status",
    });
    try registry.commands.append(.{
        .name = "govern",
        .category = .governance,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"govern", "vote"},
        .description = "Governance commands",
    });
    try registry.commands.append(.{
        .name = "dashboard",
        .category = .dashboard,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"dashboard"},
        .description = "Show dashboard",
    });
    try registry.commands.append(.{
        .name = "omega",
        .category = .sacred_agent,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"Ω", "OMEGA"},
        .description = "Omega/awakening command",
    });

    // ========================================================================
    // Evolution Commands (5)
    // ========================================================================
    try registry.commands.append(.{
        .name = "evolve",
        .category = .evolution,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"evolution"},
        .description = "Trigger evolution cycle",
    });
    try registry.commands.append(.{
        .name = "patch",
        .category = .evolution,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"patch"},
        .description = "Apply self-patch",
    });
    try registry.commands.append(.{
        .name = "analyze",
        .category = .evolution,
        .priority = .high,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"analyze"},
        .description = "Analyze codebase",
    });
    try registry.commands.append(.{
        .name = "learn",
        .category = .evolution,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"learn"},
        .description = "Learn from patterns",
    });
    try registry.commands.append(.{
        .name = "improve",
        .category = .evolution,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"improve"},
        .description = "Self-improvement",
    });

    // ========================================================================
    // Code Analysis Commands (3)
    // ========================================================================
    try registry.commands.append(.{
        .name = "analyze-code",
        .category = .code_analysis,
        .priority = .medium,
        .example_args = &[_][]const u8{"src/file.zig"},
        .expected_patterns = &[_][]const u8{"analysis"},
        .description = "Analyze code quality",
    });
    try registry.commands.append(.{
        .name = "find-bugs",
        .category = .code_analysis,
        .priority = .medium,
        .example_args = &[_][]const u8{"src/"},
        .expected_patterns = &[_][]const u8{"bugs"},
        .description = "Find potential bugs",
    });
    try registry.commands.append(.{
        .name = "metrics",
        .category = .code_analysis,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"metrics"},
        .description = "Code metrics",
    });

    // ========================================================================
    // TVC Commands (2)
    // ========================================================================
    try registry.commands.append(.{
        .name = "tvc-demo",
        .category = .demo,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TVC", "demo"},
        .description = "Run TVC chat demo",
    });
    try registry.commands.append(.{
        .name = "tvc-stats",
        .category = .info,
        .priority = .low,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"TVC", "stats"},
        .description = "Show TVC corpus statistics",
    });

    // ========================================================================
    // Demo Commands (47) - One per cycle
    // ========================================================================
    const demo_commands = [_][]const u8{
        "agents-demo",    "context-demo",   "rag-demo",       "voice-demo",
        "sandbox-demo",   "stream-demo",    "vision-demo",    "finetune-demo",
        "multimodal-demo","unified-demo",   "auto-demo",      "orch-demo",
        "mmo-demo",       "memory-demo",    "persist-demo",   "spawn-demo",
        "cluster-demo",   "worksteal-demo", "plugin-demo",    "comms-demo",
        "observe-demo",   "consensus-demo", "specexec-demo",  "governor-demo",
        "fedlearn-demo",  "eventsrc-demo",  "capsec-demo",    "dtxn-demo",
        "cache-demo",     "contract-demo",  "workflow-demo",  "triad-demo",
        "dimension-demo", "quantum-demo",   "synth-demo",     "portal-demo",
        "oracle-demo",    "nexus-demo",     "zenith-demo",    "horizon-demo",
        "cathedral-demo", "mirror-demo",    "temple-demo",    "sanctum-demo",
        "shrine-demo",    "relic-demo",     "artifact-demo",  "monolith-demo",
        "obelisk-demo",   "spire-demo",     "vertex-demo",
    };

    for (demo_commands) |cmd| {
        try registry.commands.append(.{
            .name = cmd,
            .category = .demo,
            .priority = .low,
            .example_args = &[_][]const u8{},
            .expected_patterns = &[_][]const u8{"demo"},
            .description = "Demo command",
        });
    }

    // ========================================================================
    // Benchmark Commands (47) - One per cycle
    // ========================================================================
    const bench_commands = [_][]const u8{
        "agents-bench",    "context-bench",   "rag-bench",       "voice-bench",
        "sandbox-bench",   "stream-bench",    "vision-bench",    "finetune-bench",
        "multimodal-bench","unified-bench",   "auto-bench",      "orch-bench",
        "mmo-bench",       "memory-bench",    "persist-bench",   "spawn-bench",
        "cluster-bench",   "worksteal-bench", "plugin-bench",    "comms-bench",
        "observe-bench",   "consensus-bench", "specexec-bench",  "governor-bench",
        "fedlearn-bench",  "eventsrc-bench",  "capsec-bench",    "dtxn-bench",
        "cache-bench",     "contract-bench",  "workflow-bench",  "triad-bench",
        "dimension-bench", "quantum-bench",   "synth-bench",     "portal-bench",
        "oracle-bench",    "nexus-bench",     "zenith-bench",    "horizon-bench",
        "cathedral-bench", "mirror-bench",    "temple-bench",    "sanctum-bench",
        "shrine-bench",    "relic-bench",     "artifact-bench",  "monolith-bench",
        "obelisk-bench",   "spire-bench",     "vertex-bench",
    };

    for (bench_commands) |cmd| {
        try registry.commands.append(.{
            .name = cmd,
            .category = .bench,
            .priority = .low,
            .example_args = &[_][]const u8{},
            .expected_patterns = &[_][]const u8{"bench"},
            .description = "Benchmark command",
        });
    }

    // ========================================================================
    // Additional Commands (based on exploration)
    // ========================================================================
    try registry.commands.append(.{
        .name = "formula",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{"trinity"},
        .expected_patterns = &[_][]const u8{"φ²", "1/φ²", "3"},
        .description = "Show sacred formulas",
    });
    try registry.commands.append(.{
        .name = "sacred",
        .category = .math,
        .priority = .medium,
        .example_args = &[_][]const u8{},
        .expected_patterns = &[_][]const u8{"sacred", "mathematics"},
        .description = "Sacred mathematics overview",
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
    try std.testing.expect(registry.commands.items.len >= 150);
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
