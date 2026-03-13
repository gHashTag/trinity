// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY UNIFIED COMMAND INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Purpose: Single source of truth for all TRI commands
//
// Architecture:
//   Command Registry (this file) → CLI Dispatch → API Routes → MCP Tools
//
// φ² + 1/φ² = 3 = TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified command handler signature
/// All TRI commands must implement this signature
pub const CommandFn = *const fn (allocator: Allocator, args: []const []const u8) Error!void;

/// Command execution error
pub const Error = error{
    InvalidArguments,
    NotImplemented,
    MissingDependency,
    NetworkError,
    FilesystemError,
    // Re-export common errors
    OutOfMemory,
};

/// Command metadata for registry, API, and MCP
pub const CommandMetadata = struct {
    /// Primary command name (e.g., "mesh", "wallet", "dashboard")
    name: []const u8,

    /// Short description (1 line)
    description: []const u8,

    /// Category for grouping (e.g., "Core", "Omega", "Mesh", "Wallet")
    category: []const u8,

    /// Alternative names (e.g., {"dash", "ui"} for "dashboard")
    aliases: []const []const u8,

    /// Handler function
    handler: CommandFn,

    /// Expose via MCP?
    mcp_enabled: bool = true,

    /// Expose via API route? (null = no direct route)
    api_route: ?[]const u8 = null,

    /// Long help text (null = use description)
    help_long: ?[]const u8 = null,
};

/// Command category for grouping
pub const CommandCategory = enum {
    Core,
    SWE_Agent,
    Git,
    Golden_Chain,
    TVC,
    Multi_Agent,
    Long_Context,
    RAG,
    Voice_IO,
    Code_Sandbox,
    Streaming,
    Vision,
    Fine_Tuning,
    Batched,
    Priority_Queue,
    Deadline,
    Multi_Modal,
    Unified_Agent,
    Autonomous,
    Orchestration,
    MM_Orchestration,
    Memory,
    Persistent,
    Spawn,
    Cluster,
    Work_Stealing,
    Plugin,
    Comms,
    Observe,
    Consensus,
    Spec_Exec,
    Governor,
    Fed_Learn,
    Event_Src,
    Cap_Sec,
    DTXN,
    Cache,
    Contract,
    Workflow,
    Chemistry,
    Sacred_Math,
    Sacred_Science,
    Temporal,
    Quantum,
    Omega,
    Trinity_OS,
    Dev_Util,
    Needle,
    Dashboard,
    Wallet,
    Mesh,
    Reputation,
    Hardware,
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

/// Global command registry
var registry: std.ArrayList(CommandMetadata) = undefined;
var registry_initialized = false;

/// Initialize the command registry
pub fn init(allocator: Allocator) !void {
    if (registry_initialized) return;

    registry = std.ArrayList(CommandMetadata).init(allocator);
    registry_initialized = true;

    // NOTE: Auto-population from Command enum deferred - manual registration required
    // Integration with existing code planned for v12
}

/// Register a command
pub fn register(meta: CommandMetadata) !void {
    if (!registry_initialized) return error.NotInitialized;

    // Check for duplicates
    for (registry.items) |cmd| {
        if (std.mem.eql(u8, cmd.name, meta.name)) {
            std.debug.print("Warning: Duplicate command name: {s}\n", .{meta.name});
            return error.DuplicateCommand;
        }
    }

    try registry.append(meta);
}

/// Get command by name (checks aliases too)
pub fn get(name: []const u8) ?CommandMetadata {
    if (!registry_initialized) return null;

    for (registry.items) |cmd| {
        if (std.mem.eql(u8, cmd.name, name)) return cmd;

        // Check aliases
        for (cmd.aliases) |alias| {
            if (std.mem.eql(u8, alias, name)) return cmd;
        }
    }

    return null;
}

/// List all commands in a category
pub fn listCategory(category: CommandCategory) []const CommandMetadata {
    if (!registry_initialized) return &[_]CommandMetadata{};

    const cat_str = @tagName(category);
    var result = std.ArrayList(CommandMetadata).init(registry.allocator);

    for (registry.items) |cmd| {
        if (std.mem.eql(u8, cmd.category, cat_str)) {
            result.append(cmd) catch |err| {
                std.log.warn("command append failed: {s}", .{@errorName(err)});
            };
        }
    }

    return result.toOwnedSlice() catch &[_]CommandMetadata{};
}

/// List all commands
pub fn listAll() []const CommandMetadata {
    if (!registry_initialized) return &[_]CommandMetadata{};
    return registry.items;
}

/// Get command count
pub fn count() usize {
    if (!registry_initialized) return 0;
    return registry.items.len;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP AUTO-DISCOVERY
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate MCP tool schema for a command
pub fn toMcpTool(cmd: CommandMetadata) McpToolSchema {
    return McpToolSchema{
        .name = cmd.name,
        .description = cmd.description,
        .input_schema = .{
            .type = "object",
            .properties = &[_]Property{
                .{
                    .name = "args",
                    .type = "array",
                    .description = "Command arguments",
                    .required = false,
                },
            },
        },
    };
}

pub const McpToolSchema = struct {
    name: []const u8,
    description: []const u8,
    input_schema: InputSchema,
};

pub const InputSchema = struct {
    type: []const u8,
    properties: []const Property,
};

pub const Property = struct {
    name: []const u8,
    type: []const u8,
    description: []const u8,
    required: bool,
};

/// Get all MCP-enabled tools
pub fn listMcpTools() []const McpToolSchema {
    if (!registry_initialized) return &[_]McpToolSchema{};

    var result = std.ArrayList(McpToolSchema).init(registry.allocator);

    for (registry.items) |cmd| {
        if (cmd.mcp_enabled) {
            result.append(toMcpTool(cmd)) catch |err| {
                std.log.warn("MCP tool append failed: {s}", .{@errorName(err)});
            };
        }
    }

    return result.toOwnedSlice() catch &[_]McpToolSchema{};
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLEANUP
// ═══════════════════════════════════════════════════════════════════════════════

/// Deinitialize the registry
pub fn deinit() void {
    if (registry_initialized) {
        registry.deinit();
        registry_initialized = false;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION HOOK
// ═══════════════════════════════════════════════════════════════════════════════

// This will be called from main.zig during startup
comptime {
    // Ensure this module is linked
    _ = Error;
    _ = CommandFn;
}
