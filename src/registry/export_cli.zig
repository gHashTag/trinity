//! Registry Export CLI — Export command registry to JSON
//! Usage: zig build export-registry
//! Output: .trinity/registry.json

const std = @import("std");
const mcp_gen = @import("mcp_gen.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get output path from command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const output_path = if (args.len > 1)
        args[1]
    else
        ".trinity/registry.json";

    // Export registry
    try mcp_gen.exportRegistry(allocator, output_path);

    // Also export MCP schemas
    const mcp_schemas_path = if (args.len > 2)
        args[2]
    else
        ".trinity/mcp_schemas.json";

    try mcp_gen.exportMcpSchemas(allocator, mcp_schemas_path);

    // Print stats
    const stats = mcp_gen.calculateStats();
    std.debug.print(
        \\═══════════════════════════════════════════════════════════════
        \\Registry Export Complete
        \\═══════════════════════════════════════════════════════════════
        \\Total commands: {d}
        \\MCP-enabled: {d}
        \\
        \\By mode:
        \\  sync: {d}
        \\  job: {d}
        \\  stream: {d}
        \\
        \\By stability:
        \\  stable: {d}
        \\  experimental: {d}
        \\  dangerous: {d}
        \\
        \\By namespace:
        \\  core: {d}
        \\  dev: {d}
        \\  forge: {d}
        \\  agent: {d}
        \\  mcp: {d}
        \\  system: {d}
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{
        stats.total_commands,
        stats.mcp_enabled,
        stats.by_mode.sync,
        stats.by_mode.job,
        stats.by_mode.stream,
        stats.by_stability.stable,
        stats.by_stability.experimental,
        stats.by_stability.dangerous,
        stats.by_namespace.core,
        stats.by_namespace.dev,
        stats.by_namespace.forge,
        stats.by_namespace.agent,
        stats.by_namespace.mcp,
        stats.by_namespace.system,
    });
}
