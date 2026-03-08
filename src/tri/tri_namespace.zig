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
        std.mem.eql(u8, args[0], "-h")) {
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
            return .{ .namespaced = .{
                .namespace = ns,
                .command = "",  // empty = list namespace
            } };
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
        .agent => "SWE agent, distributed computing",
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
            "tri dev gen specs/my.vibee",
        },
        .forge => &[_][]const u8{
            "tri forge fpga design.v",
            "tri forge flash output.bit",
            "tri forge sacred-const",
        },
        .agent => &[_][]const u8{
            "tri agent fix file.zig",
            "tri agent explain code.zig",
            "tri agent decompose 'add feature'",
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
