// Trinity Unified Plugin Interface
// Generated from: specs/tri/plugin/plugin_interface.vibee
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const PLUGIN_API_VERSION: u32 = 1;
pub const MAX_PLUGIN_NAME_LEN: usize = 256;
pub const MAX_CAPABILITIES: usize = 64;
pub const DEFAULT_TIMEOUT_MS: u32 = 30000;

// ============================================================================
// TYPES
// ============================================================================

/// Category of plugin functionality
pub const PluginKind = enum(u8) {
    codegen, // Code generation (Zig, Verilog, Python, etc.)
    validator, // Bogatyr validators (33+1 pattern)
    vsa_op, // VSA operations (bind, bundle, permute)
    firebird_ext, // Firebird browser extensions
    optimizer, // Optimization passes
    backend, // Inference backends (CPU, CUDA, Metal)

    pub fn toString(self: PluginKind) []const u8 {
        return switch (self) {
            .codegen => "codegen",
            .validator => "validator",
            .vsa_op => "vsa_op",
            .firebird_ext => "firebird_ext",
            .optimizer => "optimizer",
            .backend => "backend",
        };
    }
};

/// Single capability provided by plugin
pub const PluginCapability = struct {
    name: []const u8,
    version: []const u8,
};

/// Plugin identification and metadata
pub const PluginMetadata = struct {
    id: []const u8, // "trinity.codegen.python"
    name: []const u8, // "Python Code Generator"
    version: []const u8, // "1.0.0"
    author: []const u8,
    kind: PluginKind,
    capabilities: []const PluginCapability,
    dependencies: []const []const u8,
    trinity_version: []const u8, // Minimum required
};

/// Runtime state of plugin
pub const PluginState = struct {
    loaded: bool = false,
    enabled: bool = true,
    error_count: u32 = 0,
    last_error: ?[]const u8 = null,
};

/// Result of plugin operation
pub const PluginResult = struct {
    success: bool,
    output: ?[]const u8,
    errors: []const []const u8,
    duration_ns: i64,
    memory_bytes: usize,

    pub fn ok(output: ?[]const u8, duration_ns: i64) PluginResult {
        return .{
            .success = true,
            .output = output,
            .errors = &[_][]const u8{},
            .duration_ns = duration_ns,
            .memory_bytes = 0,
        };
    }

    pub fn err(errors: []const []const u8, duration_ns: i64) PluginResult {
        return .{
            .success = false,
            .output = null,
            .errors = errors,
            .duration_ns = duration_ns,
            .memory_bytes = 0,
        };
    }
};

/// Execution context for plugin operations
pub const PluginContext = struct {
    allocator: Allocator,
    config: std.StringHashMap([]const u8),
    input_path: ?[]const u8,
    output_path: ?[]const u8,

    pub fn init(allocator: Allocator) PluginContext {
        return .{
            .allocator = allocator,
            .config = std.StringHashMap([]const u8).init(allocator),
            .input_path = null,
            .output_path = null,
        };
    }

    pub fn deinit(self: *PluginContext) void {
        self.config.deinit();
    }
};

/// Virtual function table for plugin operations
pub const PluginVTable = struct {
    init_fn: *const fn (*anyopaque, Allocator, []const u8) anyerror!void,
    deinit_fn: *const fn (*anyopaque) void,
    invoke_fn: *const fn (*anyopaque, []const u8, []const u8) anyerror!PluginResult,
    capabilities_fn: *const fn (*anyopaque) []const PluginCapability,
};

/// Core Plugin structure with vtable
pub const Plugin = struct {
    metadata: PluginMetadata,
    state: PluginState,
    vtable: *const PluginVTable,
    context: *anyopaque,

    const Self = @This();

    /// Initialize the plugin
    pub fn init(self: *Self, allocator: Allocator, config: []const u8) !void {
        try self.vtable.init_fn(self.context, allocator, config);
        self.state.loaded = true;
    }

    /// Deinitialize the plugin
    pub fn deinit(self: *Self) void {
        self.vtable.deinit_fn(self.context);
        self.state.loaded = false;
    }

    /// Invoke an operation on the plugin
    pub fn invoke(self: *Self, operation: []const u8, input: []const u8) !PluginResult {
        if (!self.state.enabled) {
            return PluginResult.err(&[_][]const u8{"Plugin is disabled"}, 0);
        }
        return self.vtable.invoke_fn(self.context, operation, input);
    }

    /// Get plugin capabilities
    pub fn capabilities(self: *Self) []const PluginCapability {
        return self.vtable.capabilities_fn(self.context);
    }

    /// Check if plugin provides a capability
    pub fn hasCapability(self: *Self, name: []const u8) bool {
        for (self.capabilities()) |cap| {
            if (std.mem.eql(u8, cap.name, name)) {
                return true;
            }
        }
        return false;
    }
};

// ============================================================================
// LEGACY ADAPTER (BogatyrPlugin compatibility)
// ============================================================================

/// Legacy BogatyrPlugin interface (from bogatyr_interface.zig)
pub const LegacyBogatyrPlugin = struct {
    name: []const u8,
    version: []const u8,
    category: []const u8,
    priority: u32,
    validate: *const fn (*const anyopaque) anyerror!LegacyBogatyrResult,
};

pub const LegacyBogatyrResult = struct {
    verdict: enum { Pass, Fail, Warning, Skip },
    errors: []const anyopaque,
    metrics: struct {
        duration_ns: i64,
        checks_performed: usize,
    },
};

/// Wrap legacy BogatyrPlugin as unified Plugin
pub fn wrapBogatyr(allocator: Allocator, bogatyr: LegacyBogatyrPlugin) !*Plugin {
    const plugin = try allocator.create(Plugin);
    plugin.* = .{
        .metadata = .{
            .id = bogatyr.name,
            .name = bogatyr.name,
            .version = bogatyr.version,
            .author = "Trinity Team",
            .kind = .validator,
            .capabilities = &[_]PluginCapability{.{
                .name = "validate",
                .version = bogatyr.version,
            }},
            .dependencies = &[_][]const u8{},
            .trinity_version = ">=22.0.0",
        },
        .state = .{},
        .vtable = &bogatyr_vtable,
        .context = @ptrCast(@constCast(&bogatyr)),
    };
    return plugin;
}

const bogatyr_vtable = PluginVTable{
    .init_fn = bogatyrInit,
    .deinit_fn = bogatyrDeinit,
    .invoke_fn = bogatyrInvoke,
    .capabilities_fn = bogatyrCapabilities,
};

fn bogatyrInit(_: *anyopaque, _: Allocator, _: []const u8) anyerror!void {}
fn bogatyrDeinit(_: *anyopaque) void {}
fn bogatyrInvoke(_: *anyopaque, _: []const u8, _: []const u8) anyerror!PluginResult {
    return PluginResult.ok(null, 0);
}
fn bogatyrCapabilities(_: *anyopaque) []const PluginCapability {
    return &[_]PluginCapability{};
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Create a new Plugin with given metadata and vtable
pub fn createPlugin(
    metadata: PluginMetadata,
    vtable: *const PluginVTable,
    context: *anyopaque,
) Plugin {
    return .{
        .metadata = metadata,
        .state = .{},
        .vtable = vtable,
        .context = context,
    };
}

/// Parse plugin ID into namespace, kind, name
pub fn parsePluginId(id: []const u8) struct { namespace: []const u8, kind: []const u8, name: []const u8 } {
    var parts: [3][]const u8 = undefined;
    var iter = std.mem.splitScalar(u8, id, '.');
    var i: usize = 0;
    while (iter.next()) |part| {
        if (i < 3) {
            parts[i] = part;
            i += 1;
        }
    }
    return .{
        .namespace = if (i > 0) parts[0] else "",
        .kind = if (i > 1) parts[1] else "",
        .name = if (i > 2) parts[2] else "",
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "plugin kind to string" {
    try std.testing.expectEqualStrings("codegen", PluginKind.codegen.toString());
    try std.testing.expectEqualStrings("validator", PluginKind.validator.toString());
}

test "plugin result ok" {
    const result = PluginResult.ok("output", 1000);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("output", result.output.?);
}

test "parse plugin id" {
    const parsed = parsePluginId("trinity.codegen.python");
    try std.testing.expectEqualStrings("trinity", parsed.namespace);
    try std.testing.expectEqualStrings("codegen", parsed.kind);
    try std.testing.expectEqualStrings("python", parsed.name);
}
