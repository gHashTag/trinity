// Trinity Validator Adapter
// Generated from: specs/tri/plugin/adapters/validator_adapter.vibee
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3
//
// Purpose: Wrap legacy BogatyrPlugin validators as unified Plugin interface.
// Maintains backward compatibility with existing 33+1 validators.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import via build.zig module or relative path fallback
const plugin_interface = @import("plugin_interface");
const Plugin = plugin_interface.Plugin;
const PluginMetadata = plugin_interface.PluginMetadata;
const PluginKind = plugin_interface.PluginKind;
const PluginCapability = plugin_interface.PluginCapability;
const PluginResult = plugin_interface.PluginResult;
const PluginVTable = plugin_interface.PluginVTable;

const bogatyrs_common = @import("bogatyrs_common");
const BogatyrPlugin = bogatyrs_common.BogatyrPlugin;
const BogatyrResult = bogatyrs_common.BogatyrResult;
const BogatyrVerdict = bogatyrs_common.BogatyrVerdict;
const ValidationContext = bogatyrs_common.ValidationContext;
const ValidatorConfig = bogatyrs_common.ValidatorConfig;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const VALIDATOR_CAPABILITY = "validate";
pub const VALIDATOR_NAMESPACE = "trinity.validator";

// ============================================================================
// ADAPTER CONTEXT
// ============================================================================

/// Context holding BogatyrPlugin reference and state
pub const ValidatorPluginContext = struct {
    bogatyr: *const BogatyrPlugin,
    allocator: Allocator,
    last_result: ?BogatyrResult,
    validation_ctx: ?ValidationContext,

    const Self = @This();

    pub fn init(allocator: Allocator, bogatyr: *const BogatyrPlugin) Self {
        return .{
            .bogatyr = bogatyr,
            .allocator = allocator,
            .last_result = null,
            .validation_ctx = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.last_result = null;
        self.validation_ctx = null;
    }
};

/// Adapted validator: BogatyrPlugin wrapped as Plugin
pub const AdaptedValidator = struct {
    plugin: Plugin,
    context: ValidatorPluginContext,

    const Self = @This();

    pub fn getPlugin(self: *Self) *Plugin {
        return &self.plugin;
    }
};

// ============================================================================
// VTABLE IMPLEMENTATION
// ============================================================================

const validator_vtable = PluginVTable{
    .init_fn = validatorInit,
    .deinit_fn = validatorDeinit,
    .invoke_fn = validatorInvoke,
    .capabilities_fn = validatorCapabilities,
};

fn validatorInit(ctx: *anyopaque, _: Allocator, _: []const u8) anyerror!void {
    _ = ctx;
    // BogatyrPlugins are stateless, no initialization needed
}

fn validatorDeinit(ctx: *anyopaque) void {
    const context: *ValidatorPluginContext = @ptrCast(@alignCast(ctx));
    context.deinit();
}

fn validatorInvoke(ctx: *anyopaque, operation: []const u8, input: []const u8) anyerror!PluginResult {
    const context: *ValidatorPluginContext = @ptrCast(@alignCast(ctx));

    // Only "validate" operation is supported
    if (!std.mem.eql(u8, operation, VALIDATOR_CAPABILITY)) {
        return PluginResult.err(&[_][]const u8{"Unknown operation. Use 'validate'."}, 0);
    }

    // Create validation context from input
    const validation_ctx = ValidationContext{
        .allocator = context.allocator,
        .spec_path = input,
        .source = input,
        .config = ValidatorConfig{},
        .ast = null,
        .symbol_table = null,
    };

    // Call the underlying BogatyrPlugin
    const timer_start = std.time.nanoTimestamp();
    const result = try context.bogatyr.validate(&validation_ctx);
    const duration: i64 = @intCast(std.time.nanoTimestamp() - timer_start);

    // Store result for later access
    context.last_result = result;

    // Convert BogatyrResult to PluginResult
    return convertResult(result, duration);
}

fn validatorCapabilities(_: *anyopaque) []const PluginCapability {
    return &[_]PluginCapability{
        .{ .name = VALIDATOR_CAPABILITY, .version = "1.0.0" },
    };
}

// ============================================================================
// RESULT CONVERSION
// ============================================================================

/// Convert BogatyrResult to PluginResult
fn convertResult(bogatyr_result: BogatyrResult, duration_ns: i64) PluginResult {
    const success = switch (bogatyr_result.verdict) {
        .Pass => true,
        .Warning => true,
        .Fail => false,
        .Skip => true,
    };

    if (success) {
        return PluginResult.ok(verdictToString(bogatyr_result.verdict), duration_ns);
    } else {
        // Convert errors to string array
        return PluginResult{
            .success = false,
            .output = null,
            .errors = &[_][]const u8{},
            .duration_ns = duration_ns,
            .memory_bytes = 0,
        };
    }
}

fn verdictToString(verdict: BogatyrVerdict) []const u8 {
    return switch (verdict) {
        .Pass => "PASS",
        .Fail => "FAIL",
        .Warning => "WARNING",
        .Skip => "SKIP",
    };
}

// ============================================================================
// PUBLIC API
// ============================================================================

/// Wrap a BogatyrPlugin as a unified Plugin
pub fn wrapBogatyr(allocator: Allocator, bogatyr: *const BogatyrPlugin) !*AdaptedValidator {
    const adapted = try allocator.create(AdaptedValidator);

    // Initialize context
    adapted.context = ValidatorPluginContext.init(allocator, bogatyr);

    // Build plugin ID: trinity.validator.<name>
    const id = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ VALIDATOR_NAMESPACE, bogatyr.name });

    // Create Plugin with metadata from BogatyrPlugin
    adapted.plugin = Plugin{
        .metadata = PluginMetadata{
            .id = id,
            .name = bogatyr.name,
            .version = bogatyr.version,
            .author = "Trinity Team",
            .kind = .validator,
            .capabilities = &[_]PluginCapability{
                .{ .name = VALIDATOR_CAPABILITY, .version = bogatyr.version },
            },
            .dependencies = &[_][]const u8{},
            .trinity_version = ">=22.0.0",
        },
        .state = .{ .loaded = true, .enabled = true },
        .vtable = &validator_vtable,
        .context = &adapted.context,
    };

    return adapted;
}

/// Get the original BogatyrPlugin from an AdaptedValidator
pub fn unwrapBogatyr(adapted: *AdaptedValidator) *const BogatyrPlugin {
    return adapted.context.bogatyr;
}

/// Get the last validation result
pub fn getLastResult(adapted: *AdaptedValidator) ?BogatyrResult {
    return adapted.context.last_result;
}

/// Check if a Plugin is an adapted validator
pub fn isAdaptedValidator(plugin: *const Plugin) bool {
    return plugin.metadata.kind == .validator and
        plugin.vtable == &validator_vtable;
}

// ============================================================================
// REGISTRY MIGRATION
// ============================================================================

/// Migrate BogatyrRegistry entries to PluginRegistry
/// Takes a list of BogatyrPlugins and returns adapted Plugins
pub fn migrateValidators(
    allocator: Allocator,
    bogatyrs: []const *const BogatyrPlugin,
) ![]const *AdaptedValidator {
    var adapted_list = std.ArrayList(*AdaptedValidator).init(allocator);
    errdefer adapted_list.deinit();

    for (bogatyrs) |bogatyr| {
        const adapted = try wrapBogatyr(allocator, bogatyr);
        try adapted_list.append(adapted);
    }

    return adapted_list.toOwnedSlice();
}

/// Free migrated validators
pub fn freeMigratedValidators(allocator: Allocator, validators: []const *AdaptedValidator) void {
    for (validators) |validator| {
        allocator.free(validator.plugin.metadata.id);
        allocator.destroy(validator);
    }
    allocator.free(validators);
}

// ============================================================================
// TESTS
// ============================================================================

test "wrap bogatyr plugin" {
    const allocator = std.testing.allocator;

    // Create a mock BogatyrPlugin
    const mock_bogatyr = BogatyrPlugin{
        .name = "test_validator",
        .version = "1.0.0",
        .category = "syntax",
        .priority = 10,
        .validate = mockValidate,
    };

    const adapted = try wrapBogatyr(allocator, &mock_bogatyr);
    defer {
        allocator.free(adapted.plugin.metadata.id);
        allocator.destroy(adapted);
    }

    // Verify metadata
    try std.testing.expectEqualStrings("test_validator", adapted.plugin.metadata.name);
    try std.testing.expectEqualStrings("1.0.0", adapted.plugin.metadata.version);
    try std.testing.expect(adapted.plugin.metadata.kind == .validator);

    // Verify ID format
    try std.testing.expect(std.mem.startsWith(u8, adapted.plugin.metadata.id, VALIDATOR_NAMESPACE));
}

test "adapted validator has validate capability" {
    const allocator = std.testing.allocator;

    const mock_bogatyr = BogatyrPlugin{
        .name = "cap_test",
        .version = "2.0.0",
        .category = "semantic",
        .priority = 5,
        .validate = mockValidate,
    };

    const adapted = try wrapBogatyr(allocator, &mock_bogatyr);
    defer {
        allocator.free(adapted.plugin.metadata.id);
        allocator.destroy(adapted);
    }

    // Check capability
    try std.testing.expect(adapted.plugin.hasCapability(VALIDATOR_CAPABILITY));
}

test "is adapted validator check" {
    const allocator = std.testing.allocator;

    const mock_bogatyr = BogatyrPlugin{
        .name = "check_test",
        .version = "1.0.0",
        .category = "test",
        .priority = 1,
        .validate = mockValidate,
    };

    const adapted = try wrapBogatyr(allocator, &mock_bogatyr);
    defer {
        allocator.free(adapted.plugin.metadata.id);
        allocator.destroy(adapted);
    }

    try std.testing.expect(isAdaptedValidator(&adapted.plugin));
}

test "convert bogatyr result pass" {
    const bogatyr_result = BogatyrResult{
        .verdict = .Pass,
        .errors = &[_]bogatyrs_common.ValidationError{},
        .metrics = .{ .duration_ns = 1000, .checks_performed = 5 },
    };

    const plugin_result = convertResult(bogatyr_result, 1000);
    try std.testing.expect(plugin_result.success);
    try std.testing.expectEqualStrings("PASS", plugin_result.output.?);
}

test "convert bogatyr result fail" {
    const bogatyr_result = BogatyrResult{
        .verdict = .Fail,
        .errors = &[_]bogatyrs_common.ValidationError{},
        .metrics = .{ .duration_ns = 500, .checks_performed = 3 },
    };

    const plugin_result = convertResult(bogatyr_result, 500);
    try std.testing.expect(!plugin_result.success);
}

// Mock validate function for tests
fn mockValidate(_: *const ValidationContext) anyerror!BogatyrResult {
    return BogatyrResult{
        .verdict = .Pass,
        .errors = &[_]bogatyrs_common.ValidationError{},
        .metrics = .{ .duration_ns = 0, .checks_performed = 1 },
    };
}
