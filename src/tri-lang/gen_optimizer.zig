// ═══════════════════════════════════════════════════════════════════
// OPTIMIZER (GENERATED)
// ═══════════════════════════════════════════════════════════════════
// Core Optimizer Framework for Tri Language
// Generated from: specs/tri-lang/optimizer.tri
// TTT Dogfood v0.1 — DO NOT EDIT DIRECTLY
// Source of truth: .tri spec (edit spec, regenerate)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const TypedExpr = @import("typechecker.zig").TypedExpr;
const TypeEnv = @import("type_env.zig").TypeEnv;

// ═══════════════════════════════════════════════════════════════════════
// OPTIMIZER RESULT
// ═══════════════════════════════════════════════════════════════════════

/// Result of applying an optimizer pass
pub const OptimizerResult = enum {
    /// Pass made no changes, continue to next pass
    Continue,
    /// Pass replaced expression with optimized version
    Replace,
    /// Pass signaled to stop optimization (e.g., error detected)
    Stop,
};

// ═══════════════════════════════════════════════════════════════════════
// OPTIMIZER PASS
// ═══════════════════════════════════════════════════════════════════════

/// Single optimizer pass
/// Passes are applied sequentially to TypedExpr trees
pub const OptimizerPass = struct {
    /// Human-readable name for logging
    name: []const u8,
    /// Description of what this pass does
    description: []const u8,
    /// Run the pass on an expression
    /// Returns null if no changes, or a replacement expression if optimized
    run: *const fn (Allocator, *const TypedExpr, *const TypeEnv) ?TypedExpr,
};

// ═══════════════════════════════════════════════════════════════════════
// OPTIMIZER STATISTICS
// ═══════════════════════════════════════════════════════════════════════

/// Statistics for optimizer runs
pub const OptimizerStats = struct {
    /// Number of passes executed
    passes_run: usize = 0,
    /// Number of expressions modified
    expressions_modified: usize = 0,
    /// Number of fixed-point iterations
    iterations: usize = 0,

    pub fn init() OptimizerStats {
        return .{};
    }

    pub fn format(self: *const OptimizerStats, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "OptimizerStats{{ passes_run={d}, expressions_modified={d}, iterations={d} }}", .{ self.passes_run, self.expressions_modified, self.iterations });
    }
};

// ═══════════════════════════════════════════════════════════════════════
// OPTIMIZER CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════

/// Optimizer configuration options
pub const OptimizerConfig = struct {
    /// Maximum number of fixed-point iterations
    max_iterations: usize = 10,
    /// Enable verbose logging
    verbose: bool = false,
    /// Stop on first error
    stop_on_error: bool = true,

    pub fn init() OptimizerConfig {
        return .{
            .max_iterations = 10,
            .verbose = false,
            .stop_on_error = true,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════
// OPTIMIZER
// ═══════════════════════════════════════════════════════════════════════

/// Core optimizer with pass registry
pub const Optimizer = struct {
    allocator: Allocator,
    passes: std.ArrayList(OptimizerPass),
    config: OptimizerConfig,
    stats: OptimizerStats,

    const Self = @This();

    /// Create new optimizer with default config
    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .passes = .{}, // Empty ArrayList in Zig 0.15
            .config = OptimizerConfig.init(),
            .stats = OptimizerStats.init(),
        };
    }

    /// Create new optimizer with custom config
    pub fn initWithConfig(allocator: Allocator, config: OptimizerConfig) !Self {
        return Self{
            .allocator = allocator,
            .passes = .{}, // Empty ArrayList in Zig 0.15
            .config = config,
            .stats = OptimizerStats.init(),
        };
    }

    /// Free optimizer resources
    pub fn deinit(self: *Self) void {
        self.passes.deinit(self.allocator);
    }

    /// Add a pass to the optimizer
    /// Passes are executed in the order they are added
    pub fn addPass(self: *Self, pass: OptimizerPass) !void {
        try self.passes.append(self.allocator, pass);
    }

    /// Add multiple passes at once
    pub fn addPasses(self: *Self, passes: []const OptimizerPass) !void {
        for (passes) |pass| {
            try self.passes.append(self.allocator, pass);
        }
    }

    /// Clear all registered passes
    pub fn clearPasses(self: *Self) void {
        self.passes.clearRetainingCapacity();
    }

    /// Get number of registered passes
    pub fn passCount(self: *const Self) usize {
        return self.passes.items.len;
    }

    /// Get the passes list (for iteration)
    pub fn getPasses(self: *const Self) []const OptimizerPass {
        return self.passes.items;
    }

    /// Run optimizer on expression
    /// Applies all passes sequentially with fixed-point iteration
    pub fn run(self: *Self, expr: *const TypedExpr, env: *const TypeEnv) !*const TypedExpr {
        var current = expr;
        self.stats = OptimizerStats.init();

        // Fixed-point iteration: repeat until no changes
        var iteration: usize = 0;
        while (iteration < self.config.max_iterations) : (iteration += 1) {
            var modified = false;

            // Apply each pass
            for (self.passes.items) |pass| {
                self.stats.passes_run += 1;

                if (self.config.verbose) {
                    std.debug.print("Running pass: {s}\n", .{pass.name});
                }

                // Run the pass
                if (pass.run(self.allocator, current, env)) |replacement| {
                    // Pass returned a replacement
                    const new_expr = try self.allocator.create(TypedExpr);
                    new_expr.* = replacement;
                    current = new_expr;

                    self.stats.expressions_modified += 1;
                    modified = true;

                    if (self.config.verbose) {
                        std.debug.print("  -> Expression modified\n", .{});
                    }
                } else {
                    if (self.config.verbose) {
                        std.debug.print("  -> No change\n", .{});
                    }
                }
            }

            // If no changes made, we've reached fixed point
            if (!modified) break;
        }

        self.stats.iterations = iteration + 1;

        return current;
    }

    /// Run optimizer with statistics callback
    /// Calls the callback after each pass with current stats
    pub const StatsCallback = fn (stats: *const OptimizerStats) void;

    pub fn runWithCallback(
        self: *Self,
        expr: *const TypedExpr,
        env: *const TypeEnv,
        callback: StatsCallback,
    ) !*const TypedExpr {
        _ = callback;
        // For now, just call regular run
        // Full implementation would call callback after each pass
        return self.run(expr, env);
    }

    /// Get current statistics
    pub fn getStats(self: *const Self) OptimizerStats {
        return self.stats;
    }

    /// Reset statistics
    pub fn resetStats(self: *Self) void {
        self.stats = OptimizerStats.init();
    }

    /// Check if optimizer has any passes registered
    pub fn hasPasses(self: *const Self) bool {
        return self.passes.items.len > 0;
    }

    /// Get list of registered pass names (for debugging)
    pub fn getPassNames(self: *Self, allocator: Allocator) ![][]const u8 {
        var names = try std.ArrayList([]const u8).initCapacity(allocator, self.passes.items.len);

        for (self.passes.items) |pass| {
            const name_copy = try allocator.dupe(u8, pass.name);
            try names.append(allocator, name_copy);
        }

        return names.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════
// OPTIMIZER BUILDER
// ═══════════════════════════════════════════════════════════════════════

/// Builder pattern for constructing optimizers
pub const OptimizerBuilder = struct {
    allocator: Allocator,
    passes: std.ArrayList(OptimizerPass),
    config: OptimizerConfig,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .passes = .{}, // Empty ArrayList in Zig 0.15
            .config = OptimizerConfig.init(),
        };
    }

    /// Add a pass
    pub fn addPass(self: *Self, pass: OptimizerPass) !*Self {
        try self.passes.append(self.allocator, pass);
        return self;
    }

    /// Set max iterations
    pub fn maxIterations(self: *Self, n: usize) *Self {
        self.config.max_iterations = n;
        return self;
    }

    /// Enable verbose mode
    pub fn verbose(self: *Self, enable: bool) *Self {
        self.config.verbose = enable;
        return self;
    }

    /// Stop on error
    pub fn stopOnError(self: *Self, enable: bool) *Self {
        self.config.stop_on_error = enable;
        return self;
    }

    /// Build the optimizer
    pub fn build(self: *Self) !Optimizer {
        var opt = try Optimizer.initWithConfig(self.allocator, self.config);
        for (self.passes.items) |pass| {
            try opt.addPass(pass);
        }
        return opt;
    }

    /// Free builder resources
    pub fn deinit(self: *Self) void {
        self.passes.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════
// PREDEFINED PASS SETS
// ═══════════════════════════════════════════════════════════════════════

/// Standard optimization passes (recommended for most code)
/// Includes: constant folding, dead code elimination
pub fn standardPasses(allocator: Allocator) ![]const OptimizerPass {
    _ = allocator;
    // Passes will be added from optimizer_passes.zig
    return &[_]OptimizerPass{};
}

/// Aggressive optimization passes (for release builds)
/// Includes: standard passes + array fusion + inline expansion
pub fn aggressivePasses(allocator: Allocator) ![]const OptimizerPass {
    _ = allocator;
    // Passes will be added from optimizer_passes.zig
    return &[_]OptimizerPass{};
}

/// Minimal optimization passes (for fast iteration)
/// Includes: only constant folding
pub fn minimalPasses(allocator: Allocator) ![]const OptimizerPass {
    _ = allocator;
    // Passes will be added from optimizer_passes.zig
    return &[_]OptimizerPass{};
}

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════

test "Optimizer init" {
    const allocator = std.testing.allocator;
    var opt = try Optimizer.init(allocator);
    defer opt.deinit();

    try std.testing.expectEqual(@as(usize, 0), opt.passCount());
    try std.testing.expect(!opt.hasPasses());
}

test "Optimizer addPass" {
    const allocator = std.testing.allocator;
    var opt = try Optimizer.init(allocator);
    defer opt.deinit();

    const noop_pass = OptimizerPass{
        .name = "noop",
        .description = "Does nothing",
        .run = struct {
            fn run(alloc: std.mem.Allocator, expr: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = alloc;
                _ = expr;
                _ = env;
                return null;
            }
        }.run,
    };

    try opt.addPass(noop_pass);
    try std.testing.expectEqual(@as(usize, 1), opt.passCount());
    try std.testing.expect(opt.hasPasses());
}

test "Optimizer clearPasses" {
    const allocator = std.testing.allocator;
    var opt = try Optimizer.init(allocator);
    defer opt.deinit();

    const noop_pass = OptimizerPass{
        .name = "noop",
        .description = "Does nothing",
        .run = struct {
            fn run(alloc: std.mem.Allocator, expr: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = alloc;
                _ = expr;
                _ = env;
                return null;
            }
        }.run,
    };

    try opt.addPass(noop_pass);
    opt.clearPasses();

    try std.testing.expectEqual(@as(usize, 0), opt.passCount());
}

test "Optimizer getPassNames" {
    const allocator = std.testing.allocator;
    var opt = try Optimizer.init(allocator);
    defer opt.deinit();

    const pass1 = OptimizerPass{
        .name = "pass1",
        .description = "First pass",
        .run = struct {
            fn run(a: std.mem.Allocator, e: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = a;
                _ = e;
                _ = env;
                return null;
            }
        }.run,
    };

    const pass2 = OptimizerPass{
        .name = "pass2",
        .description = "Second pass",
        .run = struct {
            fn run(a: std.mem.Allocator, e: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = a;
                _ = e;
                _ = env;
                return null;
            }
        }.run,
    };

    try opt.addPass(pass1);
    try opt.addPass(pass2);

    const names = try opt.getPassNames(allocator);
    defer {
        for (names) |n| allocator.free(n);
        allocator.free(names);
    }

    try std.testing.expectEqual(@as(usize, 2), names.len);
    try std.testing.expectEqualStrings("pass1", names[0]);
    try std.testing.expectEqualStrings("pass2", names[1]);
}

test "OptimizerStats init" {
    const stats = OptimizerStats.init();
    try std.testing.expectEqual(@as(usize, 0), stats.passes_run);
    try std.testing.expectEqual(@as(usize, 0), stats.expressions_modified);
    try std.testing.expectEqual(@as(usize, 0), stats.iterations);
}

test "OptimizerConfig init" {
    const config = OptimizerConfig.init();
    try std.testing.expectEqual(@as(usize, 10), config.max_iterations);
    try std.testing.expect(!config.verbose);
    try std.testing.expect(config.stop_on_error);
}

test "OptimizerBuilder basic" {
    const allocator = std.testing.allocator;
    var builder = try OptimizerBuilder.init(allocator);
    defer builder.deinit();

    const pass = OptimizerPass{
        .name = "test",
        .description = "Test pass",
        .run = struct {
            fn run(a: std.mem.Allocator, e: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = a;
                _ = e;
                _ = env;
                return null;
            }
        }.run,
    };

    _ = try builder.addPass(pass);
    _ = builder.maxIterations(5).verbose(true);

    try std.testing.expectEqual(@as(usize, 5), builder.config.max_iterations);
    try std.testing.expect(builder.config.verbose);
}

test "Optimizer run no changes" {
    const allocator = std.testing.allocator;
    var opt = try Optimizer.init(allocator);
    defer opt.deinit();

    const noop_pass = OptimizerPass{
        .name = "noop",
        .description = "Does nothing",
        .run = struct {
            fn run(a: std.mem.Allocator, e: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = a;
                _ = e;
                _ = env;
                return null;
            }
        }.run,
    };

    try opt.addPass(noop_pass);

    const expr = try allocator.create(TypedExpr);
    defer allocator.destroy(expr);
    expr.* = TypedExpr{ .Int = .{ .value = 42 } };

    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const result = try opt.run(expr, &env);
    try std.testing.expectEqual(@as(usize, 0), opt.stats.expressions_modified);
    _ = result;
}

test "Optimizer run with replacement" {
    const allocator = std.testing.allocator;
    var opt = try Optimizer.init(allocator);
    defer opt.deinit();

    const replace_pass = OptimizerPass{
        .name = "replace_int",
        .description = "Replace 42 with 100",
        .run = struct {
            fn run(a: std.mem.Allocator, e: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
                _ = a;
                _ = env;
                if (e.* == .Int and e.Int.value == 42) {
                    return TypedExpr{ .Int = .{ .value = 100 } };
                }
                return null;
            }
        }.run,
    };

    try opt.addPass(replace_pass);

    const expr = try allocator.create(TypedExpr);
    defer allocator.destroy(expr);
    expr.* = TypedExpr{ .Int = .{ .value = 42 } };

    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const result = try opt.run(expr, &env);
    try std.testing.expectEqual(@as(usize, 1), opt.stats.expressions_modified);
    try std.testing.expectEqual(@as(i64, 100), result.*.Int.value);
}
