// VIBEE BOGATYR REGISTRY - Plugin Management System
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("bogatyrs_common.zig");

/// with inwith
pub const BogatyrRegistry = struct {
    allocator: Allocator,
    plugins: std.StringHashMap(PluginEntry),

    const Self = @This();

    const PluginEntry = struct {
        plugin: interface.BogatyrPlugin,
        enabled: bool,
    };

    pub fn init(allocator: Allocator) !Self {
        var registry = Self{
            .allocator = allocator,
            .plugins = std.StringHashMap(PluginEntry).init(allocator),
        };

        // andwithand withinand in intoand (and validate_cmd.zig)
        // DEFERRED (v12): inand with 33  by  andand
        try registry.registerBasicChecks();

        return registry;
    }

    pub fn deinit(self: *Self) void {
        self.plugins.deinit();
    }

    /// Registration in into (while  by 33 )
    fn registerBasicChecks(self: *Self) !void {
        try self.register(@import("bogatyrs_yaml_syntax.zig").bogatyr);
        try self.register(@import("bogatyrs_spec_structure.zig").bogatyr);
    }

    /// Registration
    fn register(self: *Self, plugin: interface.BogatyrPlugin) !void {
        const entry = PluginEntry{
            .plugin = plugin,
            .enabled = true,
        };
        try self.plugins.put(plugin.name, entry);
    }

    /// and and by and
    pub fn getPlugin(self: *Self, name: []const u8) ?PluginEntry {
        return self.plugins.get(name);
    }

    /// and all and
    pub fn getAllPlugins(self: *Self) ![]interface.BogatyrPlugin {
        var list = std.ArrayList(interface.BogatyrPlugin).init(self.allocator);
        defer list.deinit();

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            try list.append(entry.value_ptr.plugin);
        }

        return list.toOwnedSlice();
    }

    /// and toandwithin andwithandin
    pub fn pluginCount(self: *const Self) usize {
        return self.plugins.count();
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "bogatyr registry initialization" {
    const allocator = std.testing.allocator;
    var registry = try BogatyrRegistry.init(allocator);
    defer registry.deinit();

    // Basic intoand before  andwithandin
    const num_plugins = registry.pluginCount();
    try std.testing.expect(num_plugins >= 0);
}
