// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Registry-Based Help Implementation
// ═══════════════════════════════════════════════════════════════════════════════
//
// Shows all 168+ commands from CommandRegistry with:
// - Category grouping
// - Search functionality
// - Detailed command help
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CommandRegistry = @import("tri_command_registry.zig").CommandRegistry;
const CommandCategory = @import("tri_command_registry.zig").CommandCategory;
const HelpSystem = @import("tri_help.zig").HelpSystem;
const tri_colors = @import("tri_colors.zig");

/// Run help command with registry
/// Supports:
///   - tri help              Show all categories
///   - tri help --search X   Search commands
///   - tri help --category Y Show category
///   - tri help <command>    Show detailed help
pub fn runHelp(allocator: std.mem.Allocator, registry: *const CommandRegistry, args: []const []const u8) !void {
    var help_system = HelpSystem{
        .registry = registry,
        .allocator = allocator,
        .terminal_width = 80,
    };

    // Parse arguments
    if (args.len == 0) {
        // Show all categories
        try help_system.printCategorized();
        return;
    }

    // Check for flags
    if (args.len >= 2) {
        if (std.mem.eql(u8, args[0], "--search") or std.mem.eql(u8, args[0], "-s")) {
            // Search mode
            var hs = HelpSystem{
                .registry = registry,
                .allocator = allocator,
                .terminal_width = 80,
            };
            try hs.searchCommands(args[1]);
            return;
        }

        if (std.mem.eql(u8, args[0], "--category") or std.mem.eql(u8, args[0], "-c") or
            std.mem.eql(u8, args[0], "--cat"))
        {
            // Category mode - parse category name
            const cat_name = args[1];
            const cat = parseCategory(cat_name);
            if (cat) |c| {
                try help_system.printCategory(c);
            } else {
                tri_colors.printRed("Unknown category: {s}\n", .{cat_name});
                try printCategories(allocator);
            }
            return;
        }
    }

    // Check if first arg is a known category
    if (parseCategory(args[0])) |cat| {
        try help_system.printCategory(cat);
        return;
    }

    // Otherwise, treat as command name for detailed help
    const command_name = args[0];
    if (registry.find(command_name)) |metadata| {
        try help_system.printDetailedHelp(metadata);
    } else {
        tri_colors.printRed("Unknown command: {s}\n", .{command_name});
        tri_colors.printGray("Use 'tri help' to see all commands\n", .{});
        tri_colors.printGray("Use 'tri help --search <query>' to search\n", .{});
    }
}

/// Parse category name string to CommandCategory
fn parseCategory(name: []const u8) ?CommandCategory {
    const lower_arr = toLowerStatic(name);
    const lower_name = lower_arr[0..name.len]; // Convert array to slice

    // Map category names to enum values
    if (std.mem.eql(u8, lower_name, "ai")) return .ai;
    if (std.mem.eql(u8, lower_name, "dev")) return .dev;
    if (std.mem.eql(u8, lower_name, "git")) return .git;
    if (std.mem.eql(u8, lower_name, "math") or std.mem.eql(u8, lower_name, "mathematics")) return .math;
    if (std.mem.eql(u8, lower_name, "science") or std.mem.eql(u8, lower_name, "sacred")) return .science;
    if (std.mem.eql(u8, lower_name, "system") or std.mem.eql(u8, lower_name, "sys")) return .system;
    if (std.mem.eql(u8, lower_name, "demo") or std.mem.eql(u8, lower_name, "demos")) return .demo;
    if (std.mem.eql(u8, lower_name, "benchmark") or std.mem.eql(u8, lower_name, "bench")) return .benchmark;
    if (std.mem.eql(u8, lower_name, "advanced")) return .advanced;
    if (std.mem.eql(u8, lower_name, "depn") or std.mem.eql(u8, lower_name, "dep")) return .depn;

    return null;
}

/// Convert string to lowercase (static, no allocation)
fn toLowerStatic(str: []const u8) [256]u8 {
    var result: [256]u8 = undefined;
    const len = @min(str.len, 255);
    for (0..len) |i| {
        const c = str[i];
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    result[len] = 0;
    return result;
}

/// Print all available categories
fn printCategories(allocator: std.mem.Allocator) !void {
    _ = allocator;
    tri_colors.printCyan("\nAvailable categories:\n", .{});
    tri_colors.printWhite("  ai          - AI/ML commands\n", .{});
    tri_colors.printWhite("  dev         - Development tools\n", .{});
    tri_colors.printWhite("  git         - Git operations\n", .{});
    tri_colors.printWhite("  math        - Sacred mathematics\n", .{});
    tri_colors.printWhite("  science     - Sacred science (biology, chemistry, cosmology)\n", .{});
    tri_colors.printWhite("  system      - System utilities\n", .{});
    tri_colors.printWhite("  demo        - Demo commands\n", .{});
    tri_colors.printWhite("  benchmark   - Benchmark commands\n", .{});
    tri_colors.printWhite("  advanced    - Advanced features\n", .{});
    tri_colors.printWhite("  depn        - Depin/Infrastructure\n", .{});
    tri_colors.printWhite("\n", .{});
}
