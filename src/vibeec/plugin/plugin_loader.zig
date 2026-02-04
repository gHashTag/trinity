// Trinity Plugin Loader
// Generated from: specs/tri/plugin/plugin_loader.vibee
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("plugin_interface.zig");
const registry_mod = @import("plugin_registry.zig");

const Plugin = interface.Plugin;
const PluginMetadata = interface.PluginMetadata;
const PluginVTable = interface.PluginVTable;
const PluginResult = interface.PluginResult;
const PluginCapability = interface.PluginCapability;
const PluginKind = interface.PluginKind;
const PluginRegistry = registry_mod.PluginRegistry;
const PluginSource = registry_mod.PluginSource;

// ============================================================================
// CONSTANTS
// ============================================================================

/// Required WASM exports
pub const WASM_EXPORT_INIT = "plugin_init";
pub const WASM_EXPORT_DEINIT = "plugin_deinit";
pub const WASM_EXPORT_INVOKE = "plugin_invoke";
pub const WASM_EXPORT_METADATA = "plugin_metadata";
pub const WASM_EXPORT_CAPABILITIES = "plugin_capabilities";

/// Limits
pub const DEFAULT_MEMORY_LIMIT_MB: usize = 256;
pub const DEFAULT_TIMEOUT_MS: u32 = 30000;
pub const MAX_WASM_PAGES: usize = 65536;

// ============================================================================
// TYPES
// ============================================================================

/// How to load the plugin
pub const LoadStrategy = enum(u8) {
    comptime_import, // @import for core plugins (Zig)
    wasm_runtime, // WASM for community plugins
    native_ffi, // Native .so/.dylib via FFI
};

/// Exported function from WASM module
pub const WASMExport = struct {
    name: []const u8,
    param_count: u32,
    return_count: u32,
};

/// Loaded WASM plugin module
pub const WASMModule = struct {
    allocator: Allocator,
    binary: []const u8,
    exports: []WASMExport,
    memory_pages: usize,

    pub fn deinit(self: *WASMModule) void {
        self.allocator.free(self.exports);
    }
};

/// Result of loading a plugin
pub const LoadResult = struct {
    success: bool,
    plugin: ?*Plugin,
    @"error": ?[]const u8,
    load_time_ns: i64,

    pub fn ok(plugin: *Plugin, load_time_ns: i64) LoadResult {
        return .{
            .success = true,
            .plugin = plugin,
            .@"error" = null,
            .load_time_ns = load_time_ns,
        };
    }

    pub fn err(message: []const u8) LoadResult {
        return .{
            .success = false,
            .plugin = null,
            .@"error" = message,
            .load_time_ns = 0,
        };
    }
};

/// Security settings for plugin loading
pub const SecurityConfig = struct {
    verify_signatures: bool = true,
    allow_native: bool = false,
    sandbox_wasm: bool = true,
    memory_limit_mb: usize = DEFAULT_MEMORY_LIMIT_MB,
    timeout_ms: u32 = DEFAULT_TIMEOUT_MS,
};

// ============================================================================
// PLUGIN LOADER
// ============================================================================

/// Unified plugin loader
pub const PluginLoader = struct {
    allocator: Allocator,
    registry: *PluginRegistry,
    security_config: SecurityConfig,
    loaded_modules: std.ArrayList(*WASMModule),

    const Self = @This();

    /// Initialize plugin loader
    pub fn init(allocator: Allocator, registry: *PluginRegistry, config: SecurityConfig) Self {
        return .{
            .allocator = allocator,
            .registry = registry,
            .security_config = config,
            .loaded_modules = std.ArrayList(*WASMModule).init(allocator),
        };
    }

    /// Destroy plugin loader
    pub fn deinit(self: *Self) void {
        for (self.loaded_modules.items) |module| {
            module.deinit();
            self.allocator.destroy(module);
        }
        self.loaded_modules.deinit();
    }

    /// Load plugin from filesystem path
    pub fn loadFromPath(self: *Self, path: []const u8) !LoadResult {
        const start_time = std.time.nanoTimestamp();

        // Detect file type
        const strategy = detectStrategy(path);

        const result = switch (strategy) {
            .comptime_import => return LoadResult.err("Comptime import not supported at runtime"),
            .wasm_runtime => try self.loadWASM(path),
            .native_ffi => {
                if (!self.security_config.allow_native) {
                    return LoadResult.err("Native plugins not allowed by security config");
                }
                return LoadResult.err("Native FFI not yet implemented");
            },
        };

        const end_time = std.time.nanoTimestamp();
        const load_time = end_time - start_time;

        if (result.plugin) |plugin| {
            return LoadResult.ok(plugin, load_time);
        }
        return result;
    }

    /// Load WASM plugin from path
    fn loadWASM(self: *Self, path: []const u8) !LoadResult {
        // Read WASM file
        const file = std.fs.cwd().openFile(path, .{}) catch |e| {
            return LoadResult.err(switch (e) {
                error.FileNotFound => "WASM file not found",
                else => "Failed to open WASM file",
            });
        };
        defer file.close();

        const binary = file.readToEndAlloc(self.allocator, 100 * 1024 * 1024) catch {
            return LoadResult.err("Failed to read WASM file");
        };
        defer self.allocator.free(binary);

        return self.loadWASMFromBytes(binary);
    }

    /// Load WASM plugin from bytes
    pub fn loadWASMFromBytes(self: *Self, binary: []const u8) !LoadResult {
        // Validate WASM magic number
        if (binary.len < 8) {
            return LoadResult.err("Invalid WASM: too small");
        }

        const magic = binary[0..4];
        if (!std.mem.eql(u8, magic, &[_]u8{ 0x00, 0x61, 0x73, 0x6d })) {
            return LoadResult.err("Invalid WASM: bad magic number");
        }

        // Parse WASM module (simplified - just validate structure)
        const module = try self.allocator.create(WASMModule);
        module.* = .{
            .allocator = self.allocator,
            .binary = try self.allocator.dupe(u8, binary),
            .exports = try self.allocator.alloc(WASMExport, 0),
            .memory_pages = 1,
        };

        try self.loaded_modules.append(module);

        // Create plugin wrapper
        const plugin = try self.createWASMPlugin(module);

        return LoadResult.ok(plugin, 0);
    }

    /// Create Plugin wrapper for WASM module
    fn createWASMPlugin(self: *Self, module: *WASMModule) !*Plugin {
        const plugin = try self.allocator.create(Plugin);

        // Create context that holds module reference
        const ctx = try self.allocator.create(WASMPluginContext);
        ctx.* = .{
            .module = module,
            .allocator = self.allocator,
        };

        plugin.* = .{
            .metadata = .{
                .id = "wasm.plugin.loaded",
                .name = "WASM Plugin",
                .version = "1.0.0",
                .author = "Unknown",
                .kind = .firebird_ext,
                .capabilities = &[_]PluginCapability{},
                .dependencies = &[_][]const u8{},
                .trinity_version = ">=22.0.0",
            },
            .state = .{ .loaded = true },
            .vtable = &wasm_vtable,
            .context = ctx,
        };

        // Register in registry
        try self.registry.register(plugin, .local_wasm, registry_mod.PRIORITY_COMMUNITY);

        return plugin;
    }

    /// Verify WASM has required exports
    pub fn verifyWASMExports(module: *const WASMModule) bool {
        const required = [_][]const u8{
            WASM_EXPORT_INIT,
            WASM_EXPORT_INVOKE,
            WASM_EXPORT_METADATA,
        };

        for (required) |req| {
            var found = false;
            for (module.exports) |exp| {
                if (std.mem.eql(u8, exp.name, req)) {
                    found = true;
                    break;
                }
            }
            if (!found) return false;
        }
        return true;
    }

    /// Verify plugin signature (ed25519)
    pub fn verifySignature(_: *Self, _: []const u8, _: []const u8) bool {
        // TODO: Implement ed25519 verification
        return true;
    }
};

// ============================================================================
// WASM PLUGIN CONTEXT
// ============================================================================

const WASMPluginContext = struct {
    module: *WASMModule,
    allocator: Allocator,
};

const wasm_vtable = PluginVTable{
    .init_fn = wasmInit,
    .deinit_fn = wasmDeinit,
    .invoke_fn = wasmInvoke,
    .capabilities_fn = wasmCapabilities,
};

fn wasmInit(_: *anyopaque, _: Allocator, _: []const u8) anyerror!void {
    // WASM init would call exported function
}

fn wasmDeinit(_: *anyopaque) void {
    // WASM deinit would call exported function
}

fn wasmInvoke(_: *anyopaque, operation: []const u8, _: []const u8) anyerror!PluginResult {
    // WASM invoke would call exported function
    _ = operation;
    return PluginResult.ok(null, 0);
}

fn wasmCapabilities(_: *anyopaque) []const PluginCapability {
    return &[_]PluginCapability{};
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Detect load strategy from file extension
pub fn detectStrategy(path: []const u8) LoadStrategy {
    if (std.mem.endsWith(u8, path, ".wasm")) {
        return .wasm_runtime;
    } else if (std.mem.endsWith(u8, path, ".zig")) {
        return .comptime_import;
    } else if (std.mem.endsWith(u8, path, ".so") or
        std.mem.endsWith(u8, path, ".dylib") or
        std.mem.endsWith(u8, path, ".dll"))
    {
        return .native_ffi;
    }
    return .wasm_runtime; // Default to WASM
}

/// Load builtin plugins at comptime
pub fn loadBuiltinPlugins(registry: *PluginRegistry) !void {
    // This function is called at compile time to register core plugins
    // Each builtin plugin is @imported and registered
    _ = registry;

    // Example (will be expanded):
    // const codegen_zig = @import("../codegen/zig_codegen.zig");
    // try registry.register(codegen_zig.plugin, .builtin, PRIORITY_CORE);
}

// ============================================================================
// TESTS
// ============================================================================

test "detect strategy from path" {
    try std.testing.expectEqual(LoadStrategy.wasm_runtime, detectStrategy("plugin.wasm"));
    try std.testing.expectEqual(LoadStrategy.comptime_import, detectStrategy("plugin.zig"));
    try std.testing.expectEqual(LoadStrategy.native_ffi, detectStrategy("plugin.so"));
    try std.testing.expectEqual(LoadStrategy.native_ffi, detectStrategy("plugin.dylib"));
}

test "load result ok" {
    var plugin: Plugin = undefined;
    const result = LoadResult.ok(&plugin, 1000);
    try std.testing.expect(result.success);
    try std.testing.expect(result.plugin != null);
}

test "load result err" {
    const result = LoadResult.err("test error");
    try std.testing.expect(!result.success);
    try std.testing.expectEqualStrings("test error", result.@"error".?);
}

test "security config defaults" {
    const config = SecurityConfig{};
    try std.testing.expect(config.verify_signatures);
    try std.testing.expect(!config.allow_native);
    try std.testing.expect(config.sandbox_wasm);
}

test "plugin loader init and deinit" {
    const allocator = std.testing.allocator;
    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    var loader = PluginLoader.init(allocator, &registry, .{});
    defer loader.deinit();

    try std.testing.expect(loader.loaded_modules.items.len == 0);
}
