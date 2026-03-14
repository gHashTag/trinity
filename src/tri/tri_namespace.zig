// @origin(spec:tri_namespace.tri) @regen(manual-impl)
//! P2.9: Namespace-First UX with Backward Compatibility
//!
//! Supports both namespace-based and flat command invocation:
//! - `tri dev bench` - namespace-based (NEW)
//! - `tri bench` - flat command with backward compatibility (EXISTING)
//!
//! Namespaces: core, dev, forge, agent, mcp, system

const std = @import("std");

/// Supported command namespaces
pub const Namespace = enum {
    core,
    dev,
    forge,
    agent,
    mcp,
    system,

    pub fn toString(self: Namespace) []const u8 {
        return switch (self) {
            .core => "core",
            .dev => "dev",
            .forge => "forge",
            .agent => "agent",
            .mcp => "mcp",
            .system => "system",
        };
    }

    pub fn fromString(str: []const u8) ?Namespace {
        if (std.mem.eql(u8, str, "core")) return .core;
        if (std.mem.eql(u8, str, "dev")) return .dev;
        if (std.mem.eql(u8, str, "forge")) return .forge;
        if (std.mem.eql(u8, str, "agent")) return .agent;
        if (std.mem.eql(u8, str, "mcp")) return .mcp;
        if (std.mem.eql(u8, str, "system")) return .system;
        return null;
    }
};

/// Parsed command result - either namespace+command or flat command
pub const ParsedCommand = union(enum) {
    /// Namespace-based invocation: `tri dev bench`
    namespaced: struct {
        namespace: Namespace,
        command: []const u8,
    },
    /// Flat invocation: `tri bench` (for backward compatibility)
    flat: struct {
        command: []const u8,
    },
    /// Help request
    help: void,
};

/// Parse command arguments into namespace-aware structure
/// Supports:
/// - `tri <namespace> <command>` → namespaced
/// - `tri <namespace>` → show namespace help
/// - `tri <command>` → flat (backward compatible)
/// - `tri help` → help
pub fn parseCommand(args: []const []const u8) ParsedCommand {
    if (args.len == 0) {
        return .help;
    }

    // Check for explicit help
    if (std.mem.eql(u8, args[0], "help") or
        std.mem.eql(u8, args[0], "--help") or
        std.mem.eql(u8, args[0], "-h"))
    {
        return .help;
    }

    // Check if first arg is a namespace
    if (Namespace.fromString(args[0])) |ns| {
        // `tri <namespace> <command>` or `tri <namespace>`
        if (args.len >= 2) {
            return .{ .namespaced = .{
                .namespace = ns,
                .command = args[1],
            } };
        } else {
            // `tri <namespace>` - show namespace help
            return .{
                .namespaced = .{
                    .namespace = ns,
                    .command = "", // empty = list namespace
                },
            };
        }
    }

    // Flat command (backward compatible): `tri <command>`
    return .{ .flat = .{
        .command = args[0],
    } };
}

/// Get list of all namespace names (ordered for display)
pub fn allNamespaces() []const []const u8 {
    return &[_][]const u8{
        "core",
        "dev",
        "forge",
        "agent",
        "mcp",
        "system",
    };
}

/// Get description for a namespace
pub fn namespaceDescription(ns: Namespace) []const u8 {
    return switch (ns) {
        .core => "AI, math, science commands (default)",
        .dev => "Development tools (test, bench, build, gen)",
        .forge => "FPGA toolchain (synth, route, flash)",
        .agent => "SWE agent, GitHub issues, protocol",
        .mcp => "MCP server management",
        .system => "System utilities (doctor, clean, info)",
    };
}

/// Get example commands for a namespace
pub fn namespaceExamples(allocator: std.mem.Allocator, ns: Namespace) ![][]const u8 {
    const examples = switch (ns) {
        .core => &[_][]const u8{
            "tri core phi 10",
            "tri core constants",
            "tri core bio DNA:ATGC",
            "tri core cosmos hubble",
        },
        .dev => &[_][]const u8{
            "tri dev test src/vsa.zig",
            "tri dev bench --filter vsa",
            "tri dev build",
            "tri dev gen specs/my.tri",
        },
        .forge => &[_][]const u8{
            "tri forge fpga design.v",
            "tri forge flash output.bit",
            "tri forge sacred-const",
        },
        .agent => &[_][]const u8{
            "tri agent issue create 'Add feature'",
            "tri agent issue comment 42 --agent ralph --step '1/3'",
            "tri agent issue decompose 42 --template standard",
            "tri agent board sync --issue 42 --column in-progress",
        },
        .mcp => &[_][]const u8{
            "tri mcp export schemas.json",
            "tri mcp doctor",
            "tri mcp tools",
        },
        .system => &[_][]const u8{
            "tri system doctor",
            "tri system info",
            "tri system clean",
        },
    };

    // Duplicate for caller ownership
    const result = try allocator.alloc([]const u8, examples.len);
    for (examples, 0..) |ex, i| {
        result[i] = try allocator.dupe(u8, ex);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

test "Namespace enum has all namespaces" {
    const ns_count = @typeInfo(Namespace).Enum.fields.len;
    try std.testing.expectEqual(@as(usize, 6), ns_count);
}

test "Namespace toString works for all values" {
    const tests = [_]struct { ns: Namespace, expected: []const u8 }{
        .{ .ns = .core, .expected = "core" },
        .{ .ns = .dev, .expected = "dev" },
        .{ .ns = .forge, .expected = "forge" },
        .{ .ns = .agent, .expected = "agent" },
        .{ .ns = .mcp, .expected = "mcp" },
        .{ .ns = .system, .expected = "system" },
    };
    inline for (tests) |t| {
        try std.testing.expectEqualStrings(t.expected, t.ns.toString());
    }
}

test "Namespace fromString works for all values" {
    try std.testing.expectEqual(Namespace.core, Namespace.fromString("core"));
    try std.testing.expectEqual(Namespace.dev, Namespace.fromString("dev"));
    try std.testing.expectEqual(Namespace.forge, Namespace.fromString("forge"));
    try std.testing.expectEqual(Namespace.agent, Namespace.fromString("agent"));
    try std.testing.expectEqual(Namespace.mcp, Namespace.fromString("mcp"));
    try std.testing.expectEqual(Namespace.system, Namespace.fromString("system"));
    try std.testing.expect(null, Namespace.fromString("invalid"));
}

test "parseCommand returns help for empty args" {
    const parsed = parseCommand(&.{});
    try std.testing.expect(ParsedCommand.help == parsed);
}

test "parseCommand returns help for --help" {
    const parsed = parseCommand(&.{"--help"});
    try std.testing.expect(ParsedCommand.help == parsed);
}

test "parseCommand returns help for -h" {
    const parsed = parseCommand(&.{"-h"});
    try std.testing.expect(ParsedCommand.help == parsed);
}

test "parseCommand handles namespaced command" {
    const parsed = parseCommand(&.{ "dev", "test" });
    try std.testing.expectEqual(ParsedCommand.namespaced, parsed);
    const ns_val = parsed.namespaced;
    try std.testing.expectEqual(Namespace.dev, ns_val.namespace);
    try std.testing.expectEqualStrings("test", ns_val.command);
}

test "parseCommand handles namespace only" {
    const parsed = parseCommand(&.{"dev"});
    try std.testing.expectEqual(ParsedCommand.namespaced, parsed);
    const ns_val = parsed.namespaced;
    try std.testing.expectEqual(Namespace.dev, ns_val.namespace);
    try std.testing.expectEqualStrings("", ns_val.command);
}

test "parseCommand handles flat command" {
    const parsed = parseCommand(&.{"test"});
    try std.testing.expectEqual(ParsedCommand.flat, parsed);
    const flat_val = parsed.flat;
    try std.testing.expectEqualStrings("test", flat_val.command);
}

test "allNamespaces returns correct count" {
    const namespaces = allNamespaces();
    try std.testing.expectEqual(@as(usize, 6), namespaces.len);
}

test "namespaceDescription returns non-empty strings" {
    for (@typeInfo(Namespace).Enum.fields) |field| {
        const ns = @field(Namespace, field.name);
        const desc = namespaceDescription(ns);
        try std.testing.expect(desc.len > 0);
    }
}

test "namespaceExamples returns non-empty for each namespace" {
    const allocator = std.testing.allocator;
    for (@typeInfo(Namespace).Enum.fields) |field| {
        const ns = @field(Namespace, field.name);
        const examples = try namespaceExamples(allocator, ns);
        try std.testing.expect(examples.len > 0);
    }
}
