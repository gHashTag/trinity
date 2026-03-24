// ═════════════════════════════════════════════════════════════════════════════════════
// DEGRADED MODE — Fallback when worker modules unavailable
// ═════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const DEGRADED_WARNING =
    \\x1b[33;1m
    \\╔══════════════════════════════════════════════════════╗
    \\║  DEGRADED MODE                                             ║
    \\╠══════════════════════════════════════════════════════════╣
    \\║  The following command is unavailable:                      ║
    \\╠══════════════════════════════════════════════════════════╣
    \\║  Reason: {s}                                           ║
    \\╠════════════════════════════════════════════════════════════╣
    \\║  Actions:                                                ║
    \\║  1. Run: zig build queens  — compile supervisors      ║
    \\║  2. Run: tri doctor status — check system status       ║
    \\║  3. Run: tri issue list     — Check open issues              ║
    \\╠═════════════════════════════════════════════════════════════╣
    \\║  Run 'tri doctor diagnose' for detailed diagnosis             ║
    \\╚═══════════════════════════════════════════════════════════════╝
    \\x1b[0m;

/// Show degraded notice for unavailable command
pub fn showDegradedNotice(module_name: []const u8, reason: []const u8) void {
    const msg = std.fmt.allocPrintZ(std.heap.page_allocator, DEGRADED_WARNING, .{
        module_name, reason,
    }) catch return;
    defer std.heap.page_allocator.free(msg);
    std.debug.print("{s}\n", .{msg});
}

/// Run command in degraded mode (shows notice + helpful alternatives)
pub fn runDegradedCommand(cmd: []const u8, args: []const []const u8) !void {
    showDegradedNotice(cmd, "worker module not available in this build");

    // Try to provide helpful alternatives
    std.debug.print("\nAlternatives:\n", .{});
    std.debug.print("  zig build temple    — Build L0 (sacred core)\n", .{});
    std.debug.print("  zig build queens    — Build L1 (supervisors)\n", .{});
    std.debug.print("  zig build tri        — Build L2 (full tri with workers)\n", .{});
    std.debug.print("  tri doctor status — Check system status\n", .{});
    std.debug.print("  tri issue list     — Check open issues\n", .{});
    std.debug.print("\nRun 'zig build queens' then retry your command.\n", .{});

    return error.ModuleDegraded;
}

/// Check if we have full build config (all workers available)
/// Returns true if all optional modules are enabled
pub fn hasFullBuild() bool {
    // This is a runtime check since build_config.zig is generated
    // at compile time by build.zig
    return true; // Assume full build unless build options specify otherwise
}

/// Get list of missing modules (for diagnostics)
pub fn getMissingModules() []const []const u8 {
    // In a real implementation, this would check @import build_config
    // For now, return empty since we can't access compile-time values at runtime
    return &[_][]const u8{};
}
