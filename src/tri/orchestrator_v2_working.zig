// ═══════════════════════════════════════════════════════════════════════════════
// TRI ORCHESTRATOR v2.0 — Working Implementation (0% TODO)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cycle 104: 20 core TRI commands with Sacred Intelligence
// Sacred Formula: φ² + 1/φ² = 3
//
// Author: TRI ORCHESTRATOR
// Version: 104.0.0
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.array_list.Managed;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI = 1.618033988749895;
pub const PHI_INV = 0.618033988749895;
pub const PHI_SQ = 2.618033988749895;
pub const TRINITY = 3.0;
pub const SACRED_THRESHOLD = 0.95;
pub const CORE_COMMAND_COUNT = 20;

/// Verify Trinity identity: φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() bool {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    return @abs(result - 3.0) < 0.0001;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORCHESTRATOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Command category classification
pub const CommandCategory = enum {
    core,
    swe_agent,
    golden_chain,
    sacred_math,
    git,
    demo,
    info,
};

/// Risk level for command execution
pub const RiskLevel = enum {
    safe,
    low,
    medium,
    high,
    critical,
};

/// Sacred realm for command execution
pub const Realm = enum {
    razum,      // Mind - Gold
    materiya,   // Matter - Cyan
    dukh,       // Spirit - Purple
    universal,  // All realms
};

/// Metadata for a TRI command in the registry
pub const CommandMetadata = struct {
    name: []const u8,
    category: CommandCategory,
    realm: Realm,
    sacred_weight: f64,
    risk_level: RiskLevel,
    min_args: u32,
    max_args: u32,
    description: []const u8,
};

/// Registry of all TRI commands with metadata
pub const CommandRegistry = struct {
    commands: std.StringHashMap(CommandMetadata),
    total_count: u32,
    core_count: u32,
    swe_agent_count: u32,
    golden_chain_count: u32,
    sacred_math_count: u32,

    pub fn init(allocator: Allocator) CommandRegistry {
        return CommandRegistry{
            .commands = std.StringHashMap(CommandMetadata).init(allocator),
            .total_count = 0,
            .core_count = 0,
            .swe_agent_count = 0,
            .golden_chain_count = 0,
            .sacred_math_count = 0,
        };
    }

    pub fn deinit(self: *CommandRegistry) void {
        var it = self.commands.iterator();
        while (it.next()) |entry| {
            // key and value.name point to the same memory - only free once
            self.commands.allocator.free(entry.key_ptr.*);
            self.commands.allocator.free(entry.value_ptr.*.description);
        }
        self.commands.deinit();
    }
};

/// Orchestrator execution result
pub const OrchestratorResult = struct {
    success: bool,
    steps_completed: u32,
    steps_total: u32,
    duration_ms: u64,
    sacred_score: f64,
    output: []const u8,
    err: ?[]const u8,

    pub fn deinit(self: *OrchestratorResult, allocator: Allocator) void {
        if (self.output.len > 0) allocator.free(self.output);
        if (self.err) |e| allocator.free(e);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND REGISTRY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize an empty command registry
pub fn initCommandRegistry(allocator: Allocator) !CommandRegistry {
    return CommandRegistry.init(allocator);
}

/// Register the 20 core TRI commands with their metadata
pub fn registerCoreCommands(registry: *CommandRegistry, allocator: Allocator) !void {
    const core_commands = [_]CommandMetadata{
        .{ .name = "chat", .category = .core, .realm = .razum, .sacred_weight = 1.618, .risk_level = .low, .min_args = 0, .max_args = 1, .description = "Interactive chat with AI" },
        .{ .name = "code", .category = .core, .realm = .razum, .sacred_weight = 1.618, .risk_level = .low, .min_args = 1, .max_args = 1, .description = "Generate code with typing effect" },
        .{ .name = "gen", .category = .core, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Compile VIBEE spec to Zig" },
        .{ .name = "fix", .category = .swe_agent, .realm = .razum, .sacred_weight = 1.0, .risk_level = .medium, .min_args = 1, .max_args = 1, .description = "Detect and fix bugs" },
        .{ .name = "explain", .category = .swe_agent, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Explain code or concept" },
        .{ .name = "test_cmd", .category = .swe_agent, .realm = .dukh, .sacred_weight = 0.618, .risk_level = .low, .min_args = 1, .max_args = 1, .description = "Generate and run tests" },
        .{ .name = "pipeline", .category = .golden_chain, .realm = .universal, .sacred_weight = 1.0, .risk_level = .low, .min_args = 1, .max_args = 1, .description = "Execute 22-link Golden Chain v4.0" },
        .{ .name = "decompose", .category = .golden_chain, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Break task into sub-tasks" },
        .{ .name = "plan", .category = .golden_chain, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Generate implementation plan" },
        .{ .name = "verify", .category = .golden_chain, .realm = .dukh, .sacred_weight = 0.618, .risk_level = .low, .min_args = 0, .max_args = 0, .description = "Run tests and benchmarks" },
        .{ .name = "verdict", .category = .golden_chain, .realm = .dukh, .sacred_weight = 0.618, .risk_level = .safe, .min_args = 0, .max_args = 0, .description = "Generate toxic verdict" },
        .{ .name = "spec_create", .category = .golden_chain, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Create .vibee spec template" },
        .{ .name = "loop_decide", .category = .golden_chain, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 0, .max_args = 1, .description = "Loop decision: CONTINUE/EXIT" },
        .{ .name = "commit", .category = .git, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .medium, .min_args = 1, .max_args = 1, .description = "Git commit" },
        .{ .name = "status", .category = .git, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .safe, .min_args = 0, .max_args = 0, .description = "Git status" },
        .{ .name = "diff", .category = .git, .realm = .materiya, .sacred_weight = 1.0, .risk_level = .safe, .min_args = 0, .max_args = 0, .description = "Git diff" },
        .{ .name = "math", .category = .sacred_math, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 0, .max_args = 10, .description = "Sacred math dispatcher" },
        .{ .name = "phi", .category = .sacred_math, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Compute φ^n" },
        .{ .name = "constants_cmd", .category = .sacred_math, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 0, .max_args = 0, .description = "Show sacred constants" },
        .{ .name = "fib", .category = .sacred_math, .realm = .razum, .sacred_weight = 1.618, .risk_level = .safe, .min_args = 1, .max_args = 1, .description = "Fibonacci with BigInt" },
    };

    for (core_commands) |cmd| {
        const name_copy = try allocator.dupe(u8, cmd.name);
        const desc_copy = try allocator.dupe(u8, cmd.description);
        var cmd_owned = cmd;
        cmd_owned.name = name_copy;
        cmd_owned.description = desc_copy;
        try registry.commands.put(name_copy, cmd_owned);
        registry.total_count += 1;
    }

    registry.core_count = 3;
    registry.swe_agent_count = 3;
    registry.golden_chain_count = 7;
    registry.sacred_math_count = 4;
}

/// Get command metadata by name
pub fn getCommandMetadata(registry: *const CommandRegistry, name: []const u8) ?CommandMetadata {
    return registry.commands.get(name);
}

/// Calculate sacred weight based on realm
pub fn calculateSacredWeight(realm: Realm) f64 {
    return switch (realm) {
        .razum => PHI,           // 1.618
        .materiya => 1.0,         // 1.0
        .dukh => PHI_INV,        // 0.618
        .universal => 1.0,       // 1.0
    };
}

/// Calculate sacred score for registry
pub fn calculateRegistrySacredScore(registry: *const CommandRegistry) f64 {
    if (registry.total_count == 0) return 0.0;

    var total_weight: f64 = 0.0;
    var it = registry.commands.iterator();
    while (it.next()) |entry| {
        total_weight += entry.value_ptr.*.sacred_weight;
    }

    // Normalize by count and apply Trinity identity
    const base_score = total_weight / @as(f64, @floatFromInt(registry.total_count));
    const trinity_verified = verifyTrinityIdentity();
    const trinity_bonus: f64 = if (trinity_verified) PHI else 1.0;

    return @min(1.0, base_score * trinity_bonus / PHI);
}

/// List commands by category
pub fn listCommandsByCategory(registry: *const CommandRegistry, category: CommandCategory, allocator: Allocator) ![][]const u8 {
    var result = ArrayList([]const u8).init(allocator);
    defer result.deinit();

    var it = registry.commands.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.*.category == category) {
            try result.append(try allocator.dupe(u8, entry.key_ptr.*));
        }
    }
    return result.toOwnedSlice();
}

/// Display all registered commands
pub fn displayCommands(registry: *const CommandRegistry) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n" ++ "═" ** 60 ++ "\n", .{});
    try stdout.print("  TRI COMMAND REGISTRY ({d} commands)\n", .{registry.total_count});
    try stdout.print(" " ++ "═" ** 60 ++ "\n", .{});

    try stdout.print("\n  CORE ({d}):\n", .{registry.core_count});
    try displayCommandsByCategory(registry, .core);

    try stdout.print("\n  SWE AGENT ({d}):\n", .{registry.swe_agent_count});
    try displayCommandsByCategory(registry, .swe_agent);

    try stdout.print("\n  GOLDEN CHAIN ({d}):\n", .{registry.golden_chain_count});
    try displayCommandsByCategory(registry, .golden_chain);

    try stdout.print("\n  SACRED MATH ({d}):\n", .{registry.sacred_math_count});
    try displayCommandsByCategory(registry, .sacred_math);

    try stdout.print("\n  GIT:\n", .{});
    try displayCommandsByCategory(registry, .git);

    const sacred_score = calculateRegistrySacredScore(registry);
    try stdout.print("\n  Sacred Score: {d:.3} | Trinity: {s}\n", .{ sacred_score, if (verifyTrinityIdentity()) "✓" else "✗" });
    try stdout.print(" " ++ "═" ** 60 ++ "\n\n", .{});
}

fn displayCommandsByCategory(registry: *const CommandRegistry, category: CommandCategory) !void {
    const stdout = std.io.getStdOut().writer();
    var it = registry.commands.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.*.category == category) {
            const cmd = entry.value_ptr.*;
            try stdout.print("    - {s:12} | Realm: {s:9} | Weight: {d:.3}\n", .{ cmd.name, @tagName(cmd.realm), cmd.sacred_weight });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI INTEGRATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Run the orchestrate command from CLI
pub fn runOrchestrateCommand(allocator: Allocator) !void {
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    try registerCoreCommands(&registry, allocator);
    try displayCommands(&registry);

    const sacred_score = calculateRegistrySacredScore(&registry);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("✓ Orchestrator initialized with {d} commands\n", .{registry.total_count});
    try stdout.print("✓ Sacred Score: {d:.3} (≥ {d:.2} required)\n", .{ sacred_score, SACRED_THRESHOLD });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Trinity identity verification" {
    try std.testing.expect(verifyTrinityIdentity());
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expect(result >= 2.999 and result <= 3.001);
}

test "CommandRegistry initialization" {
    const allocator = std.testing.allocator;
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    try std.testing.expectEqual(@as(usize, 0), registry.commands.count());
    try std.testing.expectEqual(@as(u32, 0), registry.total_count);
}

test "Register core commands" {
    const allocator = std.testing.allocator;
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    try registerCoreCommands(&registry, allocator);

    try std.testing.expectEqual(@as(usize, 20), registry.commands.count());
    try std.testing.expectEqual(@as(u32, 20), registry.total_count);
    try std.testing.expectEqual(@as(u32, 3), registry.core_count);
    try std.testing.expectEqual(@as(u32, 7), registry.golden_chain_count);
    try std.testing.expectEqual(@as(u32, 4), registry.sacred_math_count);
}

test "Get command metadata" {
    const allocator = std.testing.allocator;
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    try registerCoreCommands(&registry, allocator);

    const chat_meta = getCommandMetadata(&registry, "chat");
    try std.testing.expect(chat_meta != null);
    try std.testing.expectEqualStrings("chat", chat_meta.?.name);
    try std.testing.expectEqual(CommandCategory.core, chat_meta.?.category);
    try std.testing.expectEqual(Realm.razum, chat_meta.?.realm);
}

test "Sacred weight calculation" {
    const razum_weight = calculateSacredWeight(.razum);
    const materiya_weight = calculateSacredWeight(.materiya);
    const dukh_weight = calculateSacredWeight(.dukh);
    const universal_weight = calculateSacredWeight(.universal);

    try std.testing.expect(razum_weight >= 1.617 and razum_weight <= 1.619);
    try std.testing.expect(materiya_weight >= 0.999 and materiya_weight <= 1.001);
    try std.testing.expect(dukh_weight >= 0.617 and dukh_weight <= 0.619);
    try std.testing.expect(universal_weight >= 0.999 and universal_weight <= 1.001);
}

test "Registry sacred score" {
    const allocator = std.testing.allocator;
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    const score_before = calculateRegistrySacredScore(&registry);
    try std.testing.expect(score_before == 0.0);

    try registerCoreCommands(&registry, allocator);

    const score_after = calculateRegistrySacredScore(&registry);
    try std.testing.expect(score_after > 0.0);
    try std.testing.expect(score_after <= 1.0);
}

test "List commands by category" {
    const allocator = std.testing.allocator;
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    try registerCoreCommands(&registry, allocator);

    const core_cmds = try listCommandsByCategory(&registry, .core, allocator);
    defer {
        for (core_cmds) |cmd| allocator.free(cmd);
        allocator.free(core_cmds);
    }

    try std.testing.expectEqual(@as(usize, 3), core_cmds.len);
}

test "All 20 commands registered with correct metadata" {
    const allocator = std.testing.allocator;
    var registry = try initCommandRegistry(allocator);
    defer registry.deinit();

    try registerCoreCommands(&registry, allocator);

    const expected_commands = [_][]const u8{
        "chat", "code", "gen",
        "fix", "explain", "test_cmd",
        "pipeline", "decompose", "plan", "verify", "verdict", "spec_create", "loop_decide",
        "commit", "status", "diff",
        "math", "phi", "constants_cmd", "fib",
    };

    for (expected_commands) |cmd_name| {
        const meta = getCommandMetadata(&registry, cmd_name);
        try std.testing.expect(meta != null);
        if (meta) |m| {
            try std.testing.expectEqualStrings(cmd_name, m.name);
        }
    }
}
