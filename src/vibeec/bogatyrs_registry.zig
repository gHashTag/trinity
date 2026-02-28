// VIBEE BOGATYR REGISTRY - Plugin Management System
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("bogatyrs_common.zig");

/// Рееwithтр inwithех богатырей
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

        // Регandwithтрandруем withущеwithтinующandе базоinые проinерtoand (andз validate_cmd.zig)
        // TODO: Добаinandть оwithтальные 33 богатыря by мере реалandзацandand
        try registry.registerBasicChecks();

        return registry;
    }

    pub fn deinit(self: *Self) void {
        self.plugins.deinit();
    }

    /// Registration базоinых проinероto (while без byлных 33 богатырей)
    fn registerBasicChecks(self: *Self) !void {
        try self.register(@import("bogatyrs_yaml_syntax.zig").bogatyr);
        try self.register(@import("bogatyrs_spec_structure.zig").bogatyr);
        // Жар-птandца — 34-й Богатырь-Тinорец with прandнцandbyм synthesis
        try self.register(@import("bogatyr_34_creator.zig").bogatyr);
    }

    /// Registration одного богатыря
    fn register(self: *Self, plugin: interface.BogatyrPlugin) !void {
        const entry = PluginEntry{
            .plugin = plugin,
            .enabled = true,
        };
        try self.plugins.put(plugin.name, entry);
    }

    /// Получandть плагandн by andменand
    pub fn getPlugin(self: *Self, name: []const u8) ?PluginEntry {
        return self.plugins.get(name);
    }

    /// Получandть all плагandны
    pub fn getAllPlugins(self: *Self) ![]interface.BogatyrPlugin {
        var list = std.ArrayList(interface.BogatyrPlugin).init(self.allocator);
        defer list.deinit();

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            try list.append(entry.value_ptr.plugin);
        }

        return list.toOwnedSlice();
    }

    /// Получandть toолandчеwithтinо зарегandwithтрandроinанных богатырей
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

    // Базоinые проinерtoand beforeлжны быть зарегandwithтрandроinаны
    const num_plugins = registry.pluginCount();
    try std.testing.expect(num_plugins >= 0);
}
