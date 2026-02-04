// Trinity Unified Plugin Registry
// Generated from: specs/tri/plugin/plugin_registry.vibee
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("plugin_interface.zig");

const Plugin = interface.Plugin;
const PluginKind = interface.PluginKind;
const PluginCapability = interface.PluginCapability;
const PluginMetadata = interface.PluginMetadata;

// ============================================================================
// CONSTANTS
// ============================================================================

/// Priority ranges
pub const PRIORITY_CORE: u32 = 0; // Core Trinity plugins
pub const PRIORITY_OFFICIAL: u32 = 50; // Official extensions
pub const PRIORITY_COMMUNITY: u32 = 100; // Community plugins
pub const PRIORITY_USER: u32 = 200; // User-installed plugins

/// Limits
pub const MAX_PLUGINS: usize = 1024;
pub const MAX_CAPABILITIES_PER_PLUGIN: usize = 64;

// ============================================================================
// TYPES
// ============================================================================

/// Origin of loaded plugin
pub const PluginSource = enum(u8) {
    builtin, // Compile-time @import
    local_zig, // Local .zig file
    local_wasm, // Local .wasm file
    remote, // Downloaded from registry
};

/// Single entry in plugin registry
pub const RegistryEntry = struct {
    plugin: *Plugin,
    source: PluginSource,
    priority: u32,
    enabled: bool,
    load_time_ns: i64,
};

/// Query for finding plugins
pub const PluginQuery = struct {
    kind: ?PluginKind = null,
    capability: ?[]const u8 = null,
    name_pattern: ?[]const u8 = null,
    enabled_only: bool = true,
};

/// Statistics about registered plugins
pub const RegistryStats = struct {
    total_count: usize,
    enabled_count: usize,
    builtin_count: usize,
    wasm_count: usize,
    by_kind: std.EnumArray(PluginKind, usize),
};

// ============================================================================
// PLUGIN REGISTRY
// ============================================================================

/// Central registry for all plugins
pub const PluginRegistry = struct {
    allocator: Allocator,
    plugins: std.StringHashMap(RegistryEntry),
    by_kind: std.EnumArray(PluginKind, std.ArrayList([]const u8)),
    by_capability: std.StringHashMap(std.ArrayList([]const u8)),

    const Self = @This();

    /// Initialize new registry
    pub fn init(allocator: Allocator) !Self {
        var registry = Self{
            .allocator = allocator,
            .plugins = std.StringHashMap(RegistryEntry).init(allocator),
            .by_kind = std.EnumArray(PluginKind, std.ArrayList([]const u8)).initFill(std.ArrayList([]const u8).init(allocator)),
            .by_capability = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
        };

        // Register builtin plugins
        try registry.registerBuiltinPlugins();

        return registry;
    }

    /// Destroy registry and all plugins
    pub fn deinit(self: *Self) void {
        // Deinit all plugins
        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.plugin.deinit();
        }

        // Free maps
        self.plugins.deinit();

        var kind_iter = self.by_kind.iterator();
        while (kind_iter.next()) |list| {
            list.value.deinit();
        }

        var cap_iter = self.by_capability.iterator();
        while (cap_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.by_capability.deinit();
    }

    /// Register a plugin
    pub fn register(self: *Self, plugin: *Plugin, source: PluginSource, priority: u32) !void {
        const id = plugin.metadata.id;

        // Check for conflicts
        if (self.plugins.contains(id)) {
            return error.PluginAlreadyRegistered;
        }

        // Check limits
        if (self.plugins.count() >= MAX_PLUGINS) {
            return error.TooManyPlugins;
        }

        const entry = RegistryEntry{
            .plugin = plugin,
            .source = source,
            .priority = priority,
            .enabled = true,
            .load_time_ns = std.time.nanoTimestamp(),
        };

        try self.plugins.put(id, entry);

        // Update kind index
        try self.by_kind.getPtr(plugin.metadata.kind).append(id);

        // Update capability index
        for (plugin.metadata.capabilities) |cap| {
            const cap_list = try self.by_capability.getOrPut(cap.name);
            if (!cap_list.found_existing) {
                cap_list.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
            }
            try cap_list.value_ptr.append(id);
        }
    }

    /// Unregister a plugin
    pub fn unregister(self: *Self, id: []const u8) !void {
        const entry = self.plugins.get(id) orelse return error.PluginNotFound;

        // Call deinit
        entry.plugin.deinit();

        // Remove from kind index
        const kind_list = self.by_kind.getPtr(entry.plugin.metadata.kind);
        for (kind_list.items, 0..) |item, i| {
            if (std.mem.eql(u8, item, id)) {
                _ = kind_list.swapRemove(i);
                break;
            }
        }

        // Remove from capability index
        for (entry.plugin.metadata.capabilities) |cap| {
            if (self.by_capability.getPtr(cap.name)) |cap_list| {
                for (cap_list.items, 0..) |item, i| {
                    if (std.mem.eql(u8, item, id)) {
                        _ = cap_list.swapRemove(i);
                        break;
                    }
                }
            }
        }

        _ = self.plugins.remove(id);
    }

    /// Get plugin by ID
    pub fn get(self: *Self, id: []const u8) ?*RegistryEntry {
        return self.plugins.getPtr(id);
    }

    /// Get plugin by ID (const)
    pub fn getConst(self: *const Self, id: []const u8) ?RegistryEntry {
        return self.plugins.get(id);
    }

    /// Query plugins
    pub fn query(self: *Self, q: PluginQuery) ![]RegistryEntry {
        var results = std.ArrayList(RegistryEntry).init(self.allocator);
        defer results.deinit();

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            const e = entry.value_ptr.*;

            // Filter by enabled
            if (q.enabled_only and !e.enabled) continue;

            // Filter by kind
            if (q.kind) |kind| {
                if (e.plugin.metadata.kind != kind) continue;
            }

            // Filter by capability
            if (q.capability) |cap| {
                if (!e.plugin.hasCapability(cap)) continue;
            }

            // Filter by name pattern
            if (q.name_pattern) |pattern| {
                if (std.mem.indexOf(u8, e.plugin.metadata.name, pattern) == null) continue;
            }

            try results.append(e);
        }

        // Sort by priority (lower = higher priority)
        std.mem.sort(RegistryEntry, results.items, {}, struct {
            fn lessThan(_: void, a: RegistryEntry, b: RegistryEntry) bool {
                return a.priority < b.priority;
            }
        }.lessThan);

        return try results.toOwnedSlice();
    }

    /// List plugins by kind
    pub fn listByKind(self: *Self, kind: PluginKind) ![]RegistryEntry {
        return self.query(.{ .kind = kind });
    }

    /// List plugins by capability
    pub fn listByCapability(self: *Self, capability: []const u8) ![]RegistryEntry {
        return self.query(.{ .capability = capability });
    }

    /// Enable plugin
    pub fn enable(self: *Self, id: []const u8) !void {
        const entry = self.plugins.getPtr(id) orelse return error.PluginNotFound;
        entry.enabled = true;
        entry.plugin.state.enabled = true;
    }

    /// Disable plugin
    pub fn disable(self: *Self, id: []const u8) !void {
        const entry = self.plugins.getPtr(id) orelse return error.PluginNotFound;
        entry.enabled = false;
        entry.plugin.state.enabled = false;
    }

    /// Get registry statistics
    pub fn getStats(self: *const Self) RegistryStats {
        var stats = RegistryStats{
            .total_count = self.plugins.count(),
            .enabled_count = 0,
            .builtin_count = 0,
            .wasm_count = 0,
            .by_kind = std.EnumArray(PluginKind, usize).initFill(0),
        };

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            const e = entry.value_ptr.*;
            if (e.enabled) stats.enabled_count += 1;
            if (e.source == .builtin) stats.builtin_count += 1;
            if (e.source == .local_wasm) stats.wasm_count += 1;
            stats.by_kind.getPtr(e.plugin.metadata.kind).* += 1;
        }

        return stats;
    }

    /// Get plugin count
    pub fn pluginCount(self: *const Self) usize {
        return self.plugins.count();
    }

    /// Register builtin plugins (compile-time)
    fn registerBuiltinPlugins(self: *Self) !void {
        // TODO: Register core plugins via @import
        // This will be expanded as we create adapter plugins
        _ = self;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "registry init and deinit" {
    const allocator = std.testing.allocator;
    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    const stats = registry.getStats();
    try std.testing.expect(stats.total_count >= 0);
}

test "registry stats" {
    const allocator = std.testing.allocator;
    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    const stats = registry.getStats();
    try std.testing.expect(stats.enabled_count <= stats.total_count);
}
