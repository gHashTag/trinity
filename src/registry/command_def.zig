// =============================================================================
// UNIFIED COMMAND REGISTRY — Single Source of Truth
// =============================================================================
//
// All TRI commands are defined here ONCE. CLI, MCP, API, and docs
// all derive their metadata from this unified definition.
//
// To add a new command:
//   1. Add entry to command_table.zig
//   2. All interfaces (CLI, MCP, API, docs) pick it up automatically
//
// =============================================================================

const std = @import("std");

/// Command execution function signature (CLI-only, set at runtime)
pub const CommandFn = *const fn (allocator: std.mem.Allocator, args: []const []const u8) anyerror!void;

/// Parameter types for MCP/API schema generation
pub const ParamType = enum {
    string,
    integer,
    number,
    boolean,

    pub fn toJsonSchema(self: ParamType) []const u8 {
        return switch (self) {
            .string => "string",
            .integer => "integer",
            .number => "number",
            .boolean => "boolean",
        };
    }
};

/// Input parameter definition (used for MCP tool schemas + API request bodies)
pub const InputParam = struct {
    name: []const u8,
    param_type: ParamType,
    description: []const u8 = "",
    required: bool = false,
    default_value: ?[]const u8 = null,
};

/// Subcommand metadata
pub const Subcommand = struct {
    name: []const u8,
    description: []const u8,
    example: []const u8,
    execute: ?CommandFn = null,
};

/// Command category for grouping in help, API, and MCP
pub const CommandCategory = enum {
    ai,
    dev,
    git,
    math,
    science,
    sacred,
    system,
    demo,
    benchmark,
    advanced,
    depin,

    pub fn displayName(self: CommandCategory) []const u8 {
        return switch (self) {
            .ai => "AI & Chat",
            .dev => "Development",
            .git => "Git",
            .math => "Sacred Math",
            .science => "Sacred Science",
            .sacred => "Sacred Intelligence",
            .system => "System",
            .demo => "Demos",
            .benchmark => "Benchmarks",
            .advanced => "Advanced",
            .depin => "DePIN",
        };
    }

    pub fn icon(self: CommandCategory) []const u8 {
        return switch (self) {
            .ai => "\xf0\x9f\xa4\x96",
            .dev => "\xf0\x9f\x94\xa7",
            .git => "\xf0\x9f\x93\xa6",
            .math => "\xcf\x86",
            .science => "\xf0\x9f\xa7\xac",
            .sacred => "\xe2\x9c\xa8",
            .system => "\xe2\x9a\x99",
            .demo => "\xf0\x9f\x8e\xac",
            .benchmark => "\xe2\x9a\xa1",
            .advanced => "\xf0\x9f\x9a\x80",
            .depin => "\xf0\x9f\x8c\x90",
        };
    }
};

/// API protocol flags
pub const ApiProtocol = enum {
    REST,
    GRAPHQL,
    GRPC,
    WEBSOCKET,

    pub fn toString(self: ApiProtocol) []const u8 {
        return switch (self) {
            .REST => "REST",
            .GRAPHQL => "GraphQL",
            .GRPC => "gRPC",
            .WEBSOCKET => "WebSocket",
        };
    }
};

// =============================================================================
// NEW: Execution Mode — How command executes
// =============================================================================

pub const ExecutionMode = enum {
    /// Executes synchronously, returns result immediately
    sync,
    /// Spawns a job, returns job_id for status polling
    job,
    /// Streaming output (Server-Sent Events or WebSocket)
    stream,

    pub fn toString(self: ExecutionMode) []const u8 {
        return switch (self) {
            .sync => "sync",
            .job => "job",
            .stream => "stream",
        };
    }
};

// =============================================================================
// NEW: Side Effects — What external state command can modify
// =============================================================================

pub const SideEffect = enum {
    /// No external state changes (read-only)
    none,
    /// Modifies git repository (status, commits, branches)
    repo,
    /// Creates/modifies/deletes files on filesystem
    filesystem,
    /// Makes network requests (HTTP, RPC, etc.)
    network,
    /// Interacts with physical hardware (FPGA flashing, JTAG)
    hardware,

    pub fn toString(self: SideEffect) []const u8 {
        return switch (self) {
            .none => "none",
            .repo => "repo",
            .filesystem => "filesystem",
            .network => "network",
            .hardware => "hardware",
        };
    }
};

// =============================================================================
// NEW: Stability Level — Maturity level for API/MCP exposure
// =============================================================================

pub const StabilityLevel = enum {
    /// Production-ready, stable API, backward compatibility guaranteed
    stable,
    /// Under active development, API may change
    experimental,
    /// Dangerous operations (data loss risk, irreversible changes)
    dangerous,

    pub fn toString(self: StabilityLevel) []const u8 {
        return switch (self) {
            .stable => "stable",
            .experimental => "experimental",
            .dangerous => "dangerous",
        };
    }
};

// =============================================================================
// NEW: CLI Namespace — Hierarchical command organization
// =============================================================================

pub const CliNamespace = enum {
    /// Default namespace - core AI, math, science commands
    core,
    /// Development tools - test, bench, build, gen
    dev,
    /// FPGA toolchain - synth, route, bitstream, flash
    forge,
    /// SWE agent, distributed computing
    agent,
    /// MCP server management
    mcp,
    /// System utilities - doctor, clean, info
    system,

    pub fn toString(self: CliNamespace) []const u8 {
        return switch (self) {
            .core => "core",
            .dev => "dev",
            .forge => "forge",
            .agent => "agent",
            .mcp => "mcp",
            .system => "system",
        };
    }
};

/// Unified command definition — the SINGLE SOURCE OF TRUTH
///
/// Every TRI command is described by one CommandDef entry.
/// CLI, MCP server, API server, and documentation all read from this.
pub const CommandDef = struct {
    // ===== Core identity (all interfaces) =====
    /// Primary command name (e.g., "bio", "phi", "commit")
    name: []const u8,
    /// Alternative names (e.g., &.{ "biology" })
    aliases: []const []const u8 = &.{},
    /// Short 1-line description
    description: []const u8,
    /// Extended help text (multi-line)
    long_help: []const u8 = "",
    /// Category for grouping
    category: CommandCategory,
    /// Usage examples
    examples: []const []const u8 = &.{},

    // ===== CLI-specific =====
    /// Whether command has subcommands
    has_subcommands: bool = false,
    /// Subcommand definitions (if any)
    subcommands: []const Subcommand = &.{},

    // ===== MCP-specific =====
    /// Expose as MCP tool? (default: false)
    mcp_enabled: bool = false,
    /// Override MCP tool name (default: "tri_{name}" with hyphens replaced by underscores)
    mcp_name: ?[]const u8 = null,
    /// Human-readable display name for MCP
    mcp_display_name: ?[]const u8 = null,
    /// Typed parameter definitions (generates JSON Schema for MCP, OpenAPI for API)
    input_params: []const InputParam = &.{},

    // ===== API-specific =====
    /// Expose as API endpoint? (default: false)
    api_enabled: bool = false,
    /// Which protocols this command is available on
    api_protocols: []const ApiProtocol = &.{},
    /// Rate limit (requests per minute), null = unlimited
    api_rate_limit: ?u32 = null,
    /// Whether authentication is required
    api_auth_required: bool = false,

    // ===== NEW: CLI hierarchy =====
    /// CLI namespace (core/dev/forge/agent/mcp/system)
    cli_namespace: CliNamespace = .core,

    // ===== NEW: Execution mode =====
    /// How command executes (sync/job/stream)
    mode: ExecutionMode = .sync,

    // ===== NEW: Side effects =====
    /// What external state this command can modify
    side_effects: []const SideEffect = &.{},

    // ===== NEW: Stability =====
    /// Maturity level for API/MCP exposure
    stability: StabilityLevel = .stable,

    // ===== NEW: Evidence requirements =====
    /// Artifacts that must be present before job completion
    required_artifacts: []const []const u8 = &.{},

    // ===== NEW: Job configuration =====
    /// For job-mode commands, default timeout in seconds
    job_timeout: u32 = 300,

    /// Get the effective MCP tool name
    pub fn getMcpToolName(self: *const CommandDef) []const u8 {
        if (self.mcp_name) |name| return name;
        // Default: "tri_{name}" — caller should handle hyphen replacement at runtime
        return self.name;
    }

    /// Get effective MCP display name
    pub fn getMcpDisplayName(self: *const CommandDef) []const u8 {
        if (self.mcp_display_name) |name| return name;
        return self.description;
    }
};

// =============================================================================
// UTILITY: JSON Schema generation from InputParam
// =============================================================================

/// Generate a JSON Schema string from InputParam slice (runtime, allocator-based)
pub fn generateJsonSchema(allocator: std.mem.Allocator, params: []const InputParam) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator,
        \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{
    );

    var first = true;
    for (params) |p| {
        if (!first) try buf.append(allocator, ',');
        first = false;

        try buf.append(allocator, '"');
        try buf.appendSlice(allocator, p.name);
        try buf.appendSlice(allocator, "\":{\"type\":\"");
        try buf.appendSlice(allocator, p.param_type.toJsonSchema());
        try buf.append(allocator, '"');
        if (p.description.len > 0) {
            try buf.appendSlice(allocator, ",\"description\":\"");
            // Simple escape for JSON string
            for (p.description) |c| {
                switch (c) {
                    '"' => try buf.appendSlice(allocator, "\\\""),
                    '\\' => try buf.appendSlice(allocator, "\\\\"),
                    '\n' => try buf.appendSlice(allocator, "\\n"),
                    else => try buf.append(allocator, c),
                }
            }
            try buf.append(allocator, '"');
        }
        try buf.append(allocator, '}');
    }

    try buf.append(allocator, '}');

    // Add required array if any params are required
    var has_required = false;
    for (params) |p| {
        if (p.required) {
            has_required = true;
            break;
        }
    }

    if (has_required) {
        try buf.appendSlice(allocator, ",\"required\":[");
        var first_req = true;
        for (params) |p| {
            if (p.required) {
                if (!first_req) try buf.append(allocator, ',');
                first_req = false;
                try buf.append(allocator, '"');
                try buf.appendSlice(allocator, p.name);
                try buf.append(allocator, '"');
            }
        }
        try buf.append(allocator, ']');
    }

    try buf.append(allocator, '}');

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// TESTS
// =============================================================================

test "ParamType.toJsonSchema" {
    try std.testing.expectEqualStrings("string", ParamType.string.toJsonSchema());
    try std.testing.expectEqualStrings("integer", ParamType.integer.toJsonSchema());
    try std.testing.expectEqualStrings("number", ParamType.number.toJsonSchema());
    try std.testing.expectEqualStrings("boolean", ParamType.boolean.toJsonSchema());
}

test "CommandCategory.displayName" {
    try std.testing.expectEqualStrings("AI & Chat", CommandCategory.ai.displayName());
    try std.testing.expectEqualStrings("Development", CommandCategory.dev.displayName());
    try std.testing.expectEqualStrings("DePIN", CommandCategory.depin.displayName());
}

test "CommandDef defaults" {
    const def = CommandDef{
        .name = "test-cmd",
        .description = "A test command",
        .category = .dev,
    };
    try std.testing.expect(!def.mcp_enabled);
    try std.testing.expect(!def.api_enabled);
    try std.testing.expect(!def.has_subcommands);
    try std.testing.expect(def.aliases.len == 0);
    try std.testing.expect(def.input_params.len == 0);
}

test "generateJsonSchema empty params" {
    const allocator = std.testing.allocator;
    const schema = try generateJsonSchema(allocator, &.{});
    defer allocator.free(schema);
    try std.testing.expectEqualStrings(
        \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    , schema);
}

test "generateJsonSchema with params" {
    const allocator = std.testing.allocator;
    const params = [_]InputParam{
        .{ .name = "n", .param_type = .integer, .required = true },
        .{ .name = "verbose", .param_type = .boolean },
    };
    const schema = try generateJsonSchema(allocator, &params);
    defer allocator.free(schema);
    // Verify it contains expected fragments
    try std.testing.expect(std.mem.indexOf(u8, schema, "\"n\":{\"type\":\"integer\"}") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "\"required\":[\"n\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "\"verbose\":{\"type\":\"boolean\"}") != null);
}
