// VIBEE BOGATYR REGISTRY - Plugin Management System
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("bogatyrs_common.zig");

/// [CYR:[EN]]with[EN] inwith[EN] [CYR:[EN]]
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

        // [CYR:[EN]]andwith[EN]and[CYR:[EN]] with[CYR:[EN]]with[EN]in[CYR:[EN]]and[EN] [CYR:[EN]]in[EN] [CYR:[EN]]in[EN]toand (and[EN] validate_cmd.zig)
        // TODO: [CYR:[EN]]inand[EN] [EN]with[CYR:[EN]] 33 [CYR:[EN]] by [CYR:[EN]] [CYR:[EN]]and[CYR:[EN]]andand
        try registry.registerBasicChecks();

        return registry;
    }

    pub fn deinit(self: *Self) void {
        self.plugins.deinit();
    }

    /// Registration [CYR:[EN]]in[EN] [CYR:[EN]]in[CYR:[EN]]to (while [CYR:[EN]] by[CYR:[EN]] 33 [CYR:[EN]])
    fn registerBasicChecks(self: *Self) !void {
        try self.register(@import("bogatyrs_yaml_syntax.zig").bogatyr);
        try self.register(@import("bogatyrs_spec_structure.zig").bogatyr);
    }

    /// Registration [CYR:[EN]] [CYR:[EN]]
    fn register(self: *Self, plugin: interface.BogatyrPlugin) !void {
        const entry = PluginEntry{
            .plugin = plugin,
            .enabled = true,
        };
        try self.plugins.put(plugin.name, entry);
    }

    /// [CYR:[EN]]and[EN] [CYR:[EN]]and[EN] by and[CYR:[EN]]and
    pub fn getPlugin(self: *Self, name: []const u8) ?PluginEntry {
        return self.plugins.get(name);
    }

    /// [CYR:[EN]]and[EN] all [CYR:[EN]]and[EN]
    pub fn getAllPlugins(self: *Self) ![]interface.BogatyrPlugin {
        var list = std.ArrayList(interface.BogatyrPlugin).init(self.allocator);
        defer list.deinit();

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            try list.append(entry.value_ptr.plugin);
        }

        return list.toOwnedSlice();
    }

    /// [CYR:[EN]]and[EN] to[EN]and[EN]with[EN]in[EN] [CYR:[EN]]andwith[EN]and[EN]in[CYR:[EN]] [CYR:[EN]]
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

    // Basic [CYR:[EN]]in[EN]toand before[CYR:[EN]] [CYR:[EN]] [CYR:[EN]]andwith[EN]and[EN]in[CYR:[EN]]
    const num_plugins = registry.pluginCount();
    try std.testing.expect(num_plugins >= 0);
}
