//! META-META-LEARNER v8.18 — Learning About Learning
//!
//! Tracks:
//! - Which FixTypes improve fastest (learning velocity)
//! - Plateau detection (stuck in local optima)
//! - Exploration trigger (when to try new strategies)
//! - Meta-learning rate (adaptive α per FixType)
//!
//! Mathematical Foundation:
//!   velocity_i = d(success_rate_i) / dt
//!   acceleration_i = d²(success_rate_i) / dt²
//!   plateau_count = consecutive attempts without improvement

const std = @import("std");
const diagnostic = @import("diagnostic.zig");
const FixType = diagnostic.FixType;
const meta_learner = @import("meta_learner.zig");

const Allocator = std.mem.Allocator;
const ArrayListManaged = std.array_list.AlignedManaged;

/// Learning velocity for a single FixType
pub const LearningVelocity = struct {
    fix_type: FixType,
    improvement_rate: f64, // d(success_rate)/dt
    acceleration: f64, // d²(success_rate)/dt²
    plateau_count: usize,
    last_success_rate: f64,
    last_update_time: i64,

    /// Calculate velocity from two success rate measurements
    pub fn fromRateChange(
        fix_type: FixType,
        old_rate: f64,
        new_rate: f64,
        time_delta: i64,
    ) LearningVelocity {
        const dt = @max(1, @as(f64, @floatFromInt(time_delta))); // Avoid division by zero
        const improvement = new_rate - old_rate;

        return LearningVelocity{
            .fix_type = fix_type,
            .improvement_rate = improvement / dt,
            .acceleration = 0.0, // Will be updated on next cycle
            .plateau_count = 0,
            .last_success_rate = new_rate,
            .last_update_time = 0, // Set by update
        };
    }
};

/// Exploration action suggested by meta-meta-learner
pub const ExplorationAction = union(enum) {
    increase_mu: struct { fix_type: FixType, factor: f64 },
    decrease_mu: struct { fix_type: FixType, factor: f64 },
    switch_strategy: struct { from: FixType, to: FixType },
    new_fixtype: struct { name: []const u8, pattern: []const u8 },
    explore_random: struct { reason: []const u8 },
    no_action: void,
};

/// Meta-meta-learner for learning about learning
pub const MetaMetaLearner = struct {
    velocities: [17]LearningVelocity,
    exploration_threshold: f64,
    last_analysis_time: i64,
    plateau_threshold: usize,
    base_meta_learning_rate: f64,
    history: ArrayListManaged(HistoricalSnapshot, null),
    allocator: Allocator,

    /// Historical snapshot for trend analysis
    const HistoricalSnapshot = struct {
        timestamp: i64,
        fix_type: FixType,
        success_rate: f64,
        mu_used: f64,
    };

    /// Initialize meta-meta-learner
    pub fn init(allocator: Allocator) !MetaMetaLearner {
        var mml = MetaMetaLearner{
            .velocities = undefined,
            .exploration_threshold = 0.001, // Minimum velocity to consider "learning"
            .last_analysis_time = 0,
            .plateau_threshold = 5, // 5 consecutive failures = plateau
            .base_meta_learning_rate = 0.1,
            .history = ArrayListManaged(HistoricalSnapshot, null).init(allocator),
            .allocator = allocator,
        };

        // Initialize velocities for all FixTypes
        const fix_types = [_]FixType{
            .SPEC_FIX,
            .GENERATOR_PATCH,
            .TEMPLATE_FIX,
            .IMPORT_FIX,
            .TYPE_FIX,
            .SYNTAX_FIX,
            .UNKNOWN,
            .ALLOCATOR_FIX,
            .ERROR_UNION_FIX,
            .COMPTIME_FIX,
            .VSA_FIX,
            .MEM_FIX,
            .IOPATTERN_FIX,
            .COMPTIME_QUOTA_FIX,
            .UNMANAGED_FIX,
            .TYPEFUNCTION_FIX,
            .INLINE_FIX,
        };

        for (fix_types, 0..) |fix_type, i| {
            mml.velocities[i] = LearningVelocity{
                .fix_type = fix_type,
                .improvement_rate = 0.0,
                .acceleration = 0.0,
                .plateau_count = 0,
                .last_success_rate = 0.0,
                .last_update_time = 0,
            };
        }

        return mml;
    }

    /// Free allocated memory
    pub fn deinit(self: *MetaMetaLearner) void {
        self.history.deinit();
        self.* = undefined;
    }

    /// Update learning velocities based on recent outcomes from meta-learner
    pub fn updateVelocities(self: *MetaMetaLearner, learner: *const meta_learner.MetaLearner) !void {
        const current_time = std.time.timestamp();
        const time_delta = if (self.last_analysis_time > 0)
            current_time - self.last_analysis_time
        else
            1;

        for (&self.velocities) |*vel| {
            const fix_type = vel.fix_type;
            const strategy = learner.getStrategy(fix_type);
            const new_rate = strategy.successRate();
            const old_rate = vel.last_success_rate;

            // Calculate improvement rate
            const improvement = new_rate - old_rate;
            vel.improvement_rate = improvement / @as(f64, @floatFromInt(time_delta));

            // Calculate acceleration (change in velocity)
            const old_velocity = vel.improvement_rate - (improvement / @as(f64, @floatFromInt(time_delta)));
            vel.acceleration = vel.improvement_rate - old_velocity;

            // Track plateau (no improvement)
            if (improvement <= 0.001) {
                vel.plateau_count += 1;
            } else {
                vel.plateau_count = 0; // Reset plateau counter on improvement
            }

            vel.last_success_rate = new_rate;
            vel.last_update_time = current_time;

            // Store snapshot for history
            try self.history.append(HistoricalSnapshot{
                .timestamp = current_time,
                .fix_type = fix_type,
                .success_rate = new_rate,
                .mu_used = strategy.last_mu_used,
            });
        }

        self.last_analysis_time = current_time;
    }

    /// Detect if a FixType is in plateau (not improving)
    pub fn detectPlateau(self: *const MetaMetaLearner, fix_type: FixType) bool {
        const index = @intFromEnum(fix_type);
        if (index >= self.velocities.len) return false;

        return self.velocities[index].plateau_count >= self.plateau_threshold;
    }

    /// Get velocity for a FixType
    pub fn getVelocity(self: *const MetaMetaLearner, fix_type: FixType) LearningVelocity {
        const index = @intFromEnum(fix_type);
        if (index >= self.velocities.len) {
            return LearningVelocity{
                .fix_type = FixType.UNKNOWN,
                .improvement_rate = 0.0,
                .acceleration = 0.0,
                .plateau_count = 0,
                .last_success_rate = 0.0,
                .last_update_time = 0,
            };
        }
        return self.velocities[index];
    }

    /// Suggest exploration action based on current velocities and plateaus
    pub fn suggestExploration(self: *const MetaMetaLearner) ExplorationAction {
        // Find FixType with worst plateau
        var worst_plateau: ?FixType = null;
        var max_plateau_count: usize = 0;

        for (self.velocities) |vel| {
            if (vel.plateau_count > max_plateau_count) {
                max_plateau_count = vel.plateau_count;
                worst_plateau = vel.fix_type;
            }
        }

        // If something is in deep plateau, suggest switching strategy
        if (worst_plateau) |fix_type| {
            if (max_plateau_count >= self.plateau_threshold * 2) {
                // Deep plateau - try completely different approach
                return ExplorationAction{
                    .explore_random = .{
                        .reason = "Deep plateau detected, need fresh approach",
                    },
                };
            }

            // Moderate plateau - increase μ to be more aggressive
            return ExplorationAction{
                .increase_mu = .{
                    .fix_type = fix_type,
                    .factor = 1.2, // 20% increase
                },
            };
        }

        // Find FixType with fastest improvement
        var best_velocity: f64 = -std.math.inf(f64);
        var best_fix_type: FixType = FixType.UNKNOWN;

        for (self.velocities) |vel| {
            if (vel.improvement_rate > best_velocity) {
                best_velocity = vel.improvement_rate;
                best_fix_type = vel.fix_type;
            }
        }

        // If something is improving very well, suggest decreasing μ (fine-tune)
        if (best_velocity > self.exploration_threshold * 10) {
            return ExplorationAction{
                .decrease_mu = .{
                    .fix_type = best_fix_type,
                    .factor = 0.9, // 10% decrease
                },
            };
        }

        return ExplorationAction{ .no_action = {} };
    }

    /// Get meta-learning rate (adaptive α per FixType)
    /// Formula: α_i(t) = α_base × (1 + velocity_i(t) / max_velocity)
    pub fn getMetaLearningRate(self: *const MetaMetaLearner, fix_type: FixType) f64 {
        const vel = self.getVelocity(fix_type);

        // Find max absolute velocity for normalization
        var max_velocity: f64 = 0.001;
        for (self.velocities) |v| {
            const abs_vel = @abs(v.improvement_rate);
            if (abs_vel > max_velocity) max_velocity = abs_vel;
        }

        // Normalize velocity and compute adaptive learning rate
        const normalized_velocity = @abs(vel.improvement_rate) / max_velocity;
        const adaptive_rate = self.base_meta_learning_rate * (1.0 + normalized_velocity);

        // Clamp to reasonable range
        return @max(0.01, @min(0.5, adaptive_rate));
    }

    /// Get summary of all learning velocities
    pub fn getVelocitySummary(self: *const MetaMetaLearner, allocator: Allocator) ![][]const u8 {
        var lines = ArrayListManaged([]const u8, null).init(allocator);

        try lines.append(try allocator.dupe(u8,
            \\# LEARNING VELOCITY SUMMARY
            \\| FixType | Velocity | Acceleration | Plateau | Success Rate |
            \\|---------|----------|--------------|---------|--------------|
        ));

        for (self.velocities) |vel| {
            const line = try std.fmt.allocPrint(allocator,
                "| {s} | {d:.6} | {d:.6} | {d} | {d:.2} |\n",
                .{
                    @tagName(vel.fix_type),
                    vel.improvement_rate,
                    vel.acceleration,
                    vel.plateau_count,
                    vel.last_success_rate * 100.0,
                },
            );
            try lines.append(line);
        }

        return lines.toOwnedSlice();
    }

    /// Find FixType with highest learning velocity
    pub fn getFastestLearner(self: *const MetaMetaLearner) FixType {
        var best_type: FixType = FixType.UNKNOWN;
        var best_velocity: f64 = -std.math.inf(f64);

        for (self.velocities) |vel| {
            if (vel.improvement_rate > best_velocity and vel.last_success_rate > 0.5) {
                best_velocity = vel.improvement_rate;
                best_type = vel.fix_type;
            }
        }

        return best_type;
    }

    /// Find FixType with lowest success rate (most struggling)
    pub fn getMostStruggling(self: *const MetaMetaLearner) FixType {
        var worst_type: FixType = FixType.UNKNOWN;
        var worst_rate: f64 = 1.0;

        for (self.velocities) |vel| {
            if (vel.last_success_rate < worst_rate and vel.last_success_rate > 0) {
                worst_rate = vel.last_success_rate;
                worst_type = vel.fix_type;
            }
        }

        return worst_type;
    }
};

/// Global meta-meta-learner instance
var global_meta_meta: ?MetaMetaLearner = null;
var global_meta_meta_init = false;

/// Get or create global meta-meta-learner
pub fn getGlobalMetaMetaLearner() !*MetaMetaLearner {
    if (!global_meta_meta_init) {
        global_meta_meta = try MetaMetaLearner.init(std.heap.page_allocator);
        global_meta_meta_init = true;
    }
    return &global_meta_meta.?;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "LearningVelocity: from rate change" {
    const vel = LearningVelocity.fromRateChange(.TYPE_FIX, 0.5, 0.7, 10);

    try std.testing.expectApproxEqRel(@as(f64, 0.02), vel.improvement_rate, 0.01);
    try std.testing.expectEqual(.TYPE_FIX, vel.fix_type);
}

test "MetaMetaLearner: initialization" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    try std.testing.expectEqual(@as(usize, 17), mml.velocities.len);
    try std.testing.expectEqual(@as(usize, 5), mml.plateau_threshold);
}

test "MetaMetaLearner: detect plateau" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // Initially no plateau
    try std.testing.expect(!mml.detectPlateau(.TYPE_FIX));

    // Simulate plateau by directly setting plateau count
    mml.velocities[@intFromEnum(FixType.TYPE_FIX)].plateau_count = 10;

    // Now should detect plateau
    try std.testing.expect(mml.detectPlateau(.TYPE_FIX));
}

test "MetaMetaLearner: get velocity" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    const vel = mml.getVelocity(.TYPE_FIX);
    try std.testing.expectEqual(.TYPE_FIX, vel.fix_type);
    try std.testing.expectEqual(@as(usize, 0), vel.plateau_count);
}

test "MetaMetaLearner: meta-learning rate calculation" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // Baseline rate should be around 0.1
    const rate = mml.getMetaLearningRate(.TYPE_FIX);
    try std.testing.expect(rate > 0.0);
    try std.testing.expect(rate <= 0.5);
}

test "MetaMetaLearner: exploration suggestion on plateau" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // Set up a plateau
    mml.velocities[@intFromEnum(FixType.TYPE_FIX)].plateau_count = 15;

    const action = mml.suggestExploration();

    // Should suggest some action (not no_action)
    try std.testing.expect(action != .no_action);
}

test "MetaMetaLearner: get fastest learner" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // Set TYPE_FIX as fast learner
    mml.velocities[@intFromEnum(FixType.TYPE_FIX)].improvement_rate = 0.1;
    mml.velocities[@intFromEnum(FixType.TYPE_FIX)].last_success_rate = 0.8;

    const fastest = mml.getFastestLearner();
    try std.testing.expectEqual(.TYPE_FIX, fastest);
}

test "MetaMetaLearner: get most struggling" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // Set SYNTAX_FIX as struggling
    mml.velocities[@intFromEnum(FixType.SYNTAX_FIX)].last_success_rate = 0.3;
    mml.velocities[@intFromEnum(FixType.TYPE_FIX)].last_success_rate = 0.7;

    const struggling = mml.getMostStruggling();
    try std.testing.expectEqual(.SYNTAX_FIX, struggling);
}

test "MetaMetaLearner: velocity summary" {
    const allocator = std.testing.allocator;
    var mml = try MetaMetaLearner.init(allocator);
    defer mml.deinit();

    const summary = try mml.getVelocitySummary(allocator);
    defer {
        for (summary) |line| allocator.free(line);
        allocator.free(summary);
    }

    // Should have header + 17 FixTypes
    try std.testing.expectEqual(@as(usize, 18), summary.len);

    // Check header
    try std.testing.expect(std.mem.indexOf(u8, summary[0], "LEARNING VELOCITY") != null);
}
