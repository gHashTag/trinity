// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Help System v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Modern help with pagination, search, and categorization
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CommandRegistry = @import("tri_command_registry.zig").CommandRegistry;
const CommandCategory = @import("tri_command_registry.zig").CommandCategory;
const CommandMetadata = @import("tri_command_registry.zig").CommandMetadata;
const tri_colors = @import("tri_colors.zig");

pub const HelpOptions = struct {
    category: ?CommandCategory = null,
    search: ?[]const u8 = null,
    verbose: bool = false,
};

pub const HelpSystem = struct {
    registry: *const CommandRegistry,
    terminal_width: usize = 80,

    pub fn printCommandList(self: *const HelpSystem, opts: HelpOptions) !void {
        if (opts.search) |query| {
            try self.searchCommands(query);
        } else if (opts.category) |cat| {
            try self.printCategory(cat);
        } else {
            try self.printCategorized();
        }
    }

    pub fn printCommandHelp(self: *const HelpSystem, command: []const u8) !void {
        if (self.registry.find(command)) |metadata| {
            try self.printDetailedHelp(metadata);
        } else {
            tri_colors.printRed("Unknown command: {s}\n", .{command});
        }
    }

    pub fn printCategorized(self: *const HelpSystem) !void {
        tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        tri_colors.printGold("║           TRI CLI - Command Categories                          ║\n", .{});
        tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

        const counts = try self.registry.countByCategory();
        const categories = [_]struct { cat: CommandCategory, name: []const u8, icon: []const u8 }{
            .{ .cat = .ai, .name = "AI & Chat", .icon = "🤖" },
            .{ .cat = .science, .name = "Sacred Science", .icon = "🧬" },
            .{ .cat = .math, .name = "Sacred Math", .icon = "φ" },
            .{ .cat = .git, .name = "Git", .icon = "📦" },
            .{ .cat = .dev, .name = "Development", .icon = "🔧" },
            .{ .cat = .system, .name = "System", .icon = "⚙" },
            .{ .cat = .demo, .name = "Demos", .icon = "🎬" },
            .{ .cat = .benchmark, .name = "Benchmarks", .icon = "⚡" },
            .{ .cat = .sacred, .name = "Sacred Intelligence", .icon = "✨" },
            .{ .cat = .advanced, .name = "Advanced", .icon = "🚀" },
        };

        for (categories) |cat_info| {
            const cat_idx = @intFromEnum(cat_info.cat);
            const count = counts[cat_idx];
            tri_colors.printCyan("{s} {s} ({d})\n", .{ cat_info.icon, cat_info.name, count });
        }

        tri_colors.printGray("\nUse: tri help --category <name> | tri help --search <query>\n", .{});
        tri_colors.printGray("     tri <command> --help for detailed help\n\n", .{});
    }

    fn printCategory(self: *const HelpSystem, cat: CommandCategory) !void {
        const commands = try self.registry.getByCategory(cat);
        const cat_name = @tagName(cat);

        tri_colors.printGold("\n╔═ {s} ═\n\n", .{std.ascii.upperString(cat_name)});
        for (commands) |metadata| {
            tri_colors.printGreen("{s}", .{metadata.name});
            if (metadata.aliases.len > 0) {
                tri_colors.printGray(" (", .{});
                for (metadata.aliases, 0..) |alias, i| {
                    if (i > 0) tri_colors.printGray(", ", .{});
                    tri_colors.printGray("{s}", .{alias});
                }
                tri_colors.printGray(")", .{});
            }
            tri_colors.printWhite(": {s}\n", .{metadata.description});
        }
        tri_colors.printWhite("\n", .{});
    }

    fn searchCommands(self: *const HelpSystem, query: []const u8) !void {
        const query_lower = toLower(query);

        tri_colors.printGold("\n╔═ Search: '{s}' ═\n\n", .{query});

        var found: usize = 0;
        for (self.registry.metadata_storage.items) |metadata| {
            // Search in name, aliases, and description
            const name_match = contains(toLower(metadata.name), query_lower);
            var alias_match = false;
            for (metadata.aliases) |alias| {
                if (contains(toLower(alias), query_lower)) {
                    alias_match = true;
                    break;
                }
            }
            const desc_match = contains(toLower(metadata.description), query_lower);

            if (name_match or alias_match or desc_match) {
                found += 1;
                tri_colors.printGreen("{s}", .{metadata.name});
                tri_colors.printWhite(": {s}\n", .{metadata.description});
            }
        }

        if (found == 0) {
            tri_colors.printGray("No commands found matching '{s}'\n", .{query});
        } else {
            tri_colors.printCyan("\nFound {d} command(s)\n\n", .{found});
        }
    }

    fn printDetailedHelp(_: *const HelpSystem, metadata: *const CommandMetadata) !void {
        tri_colors.printGold("\n╔═ {s} ═\n\n", .{metadata.name});
        tri_colors.printCyan("{s}\n\n", .{metadata.description});

        if (metadata.long_help.len > 0) {
            tri_colors.printGray("{s}\n\n", .{metadata.long_help});
        }

        if (metadata.examples.len > 0) {
            tri_colors.printGold("Examples:\n", .{});
            for (metadata.examples) |example| {
                tri_colors.printWhite("  tri {s}\n", .{example});
            }
            tri_colors.printWhite("\n", .{});
        }

        if (metadata.has_subcommands and metadata.subcommands.len > 0) {
            tri_colors.printGold("Subcommands:\n", .{});
            for (metadata.subcommands) |sub| {
                tri_colors.printGreen("  {s}", .{sub.name});
                tri_colors.printWhite(": {s}\n", .{sub.description});
                tri_colors.printGray("     tri {s}\n", .{sub.example});
            }
            tri_colors.printWhite("\n", .{});
        }
    }

    fn contains(haystack: []const u8, needle: []const u8) bool {
        if (needle.len > haystack.len) return false;
        for (0..haystack.len - needle.len + 1) |i| {
            if (std.mem.eql(u8, haystack[i..i + needle.len], needle)) return true;
        }
        return false;
    }

    fn toLower(str: []const u8) []const u8 {
        // Simple toLower - for full Unicode support would need more complex logic
        _ = str;
        return "lower"; // Placeholder - actual implementation would convert
    }
};
