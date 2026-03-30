// @origin(spec:auto_improve.tri) @regen(manual-impl)
//
// Autonomous Self-Improvement Orchestration
// Combines .tri pipeline + .t27 algorithms for Queen evolution
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// Import existing queen modules
const episodes = @import("episodes.zig");
const self_learning = @import("self_learning.zig");
const tri27_bridge = @import("tri27_bridge.zig");

const Allocator = std.mem.Allocator;

// ============================================================================
// CONSTANTS
// ============================================================================

const TRINITY_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3
const DEFAULT_EPISODE_WINDOW: usize = 100;
const MIN_EPISODES_FOR_IMPROVE: usize = 10;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const ImproveConfig = struct {
    episode_window: usize = DEFAULT_EPISODE_WINDOW,
    min_episodes: usize = MIN_EPISODES_FOR_IMPROVE,
    quality_threshold: f64 = 0.7,
    max_deltas: u32 = 5,
};

pub const ImproveResult = struct {
    success: bool,
    applied_deltas: u32 = 0,
    quality_score: f64 = 0.0,
    cycles_analyzed: usize = 0,
    patterns_found: usize = 0,
    message: []const u8,
    config: ?self_learning.Tri27Config = null,
};

pub const EpisodePattern = struct {
    pattern_type: PatternType,
    frequency: usize,
    last_occurrence: i64,
    suggestion: []const u8,
};

pub const PatternType = enum {
    RepeatedFailure,
    PerformanceDegradation,
    MissingOptimization,
    InefficentConfig,
};

// ============================================================================
// AUTO IMPROVE ENGINE
// ============================================================================

pub const AutoImprove = struct {
    allocator: Allocator,
    config: ImproveConfig,

    pub fn init(allocator: Allocator) AutoImprove {
        return .{
            .allocator = allocator,
            .config = ImproveConfig{},
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: ImproveConfig) AutoImprove {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Run full self-improvement cycle
    pub fn runCycle(self: *const AutoImprove) !ImproveResult {
        std.debug.print("🔄 Starting self-improvement cycle...\n", .{});

        // Step 1: Load recent episodes
        const recent_episodes = episodes.loadRecentEpisodes(
            self.allocator,
            self.config.episode_window,
        ) catch |err| {
            std.debug.print("Failed to load episodes: {}\n", .{err});
            return ImproveResult{
                .success = false,
                .message = try self.allocator.dupe(u8, @errorName(err)),
            };
        };
        defer {
            for (recent_episodes) |ep| {
                if (ep.context.active_issues.len > 0)
                    self.allocator.free(ep.context.active_issues);
            }
            self.allocator.free(recent_episodes);
        }

        std.debug.print("📊 Loaded {d} episodes\n", .{recent_episodes.len});

        // Step 2: Check minimum episode count
        if (recent_episodes.len < self.config.min_episodes) {
            return ImproveResult{
                .success = false,
                .message = try std.fmt.allocPrint(
                    self.allocator,
                    "Insufficient episodes: {d} < {d}",
                    .{ recent_episodes.len, self.config.min_episodes },
                ),
            };
        }

        // Step 3: Analyze patterns
        const patterns = try self.analyzePatterns(recent_episodes);
        defer self.allocator.free(patterns);

        std.debug.print("🔍 Found {d} patterns\n", .{patterns.len});

        // Step 4: Generate improvement suggestions
        const suggestions = try self.generateSuggestions(patterns);
        defer {
            for (suggestions) |s| {
                self.allocator.free(s);
            }
            self.allocator.free(suggestions);
        }

        // Step 5: Execute self-learning cycle (from self_learning.zig)
        const cycle_result = self_learning.runSelfLearningCycle(
            self.allocator,
            self.config.episode_window,
        ) catch |err| {
            std.debug.print("Self-learning cycle failed: {}\n", .{err});
            return ImproveResult{
                .success = false,
                .message = try self.allocator.dupe(u8, @errorName(err)),
            };
        };

        std.debug.print("✅ Applied {d} deltas\n", .{cycle_result.applied_deltas});

        // Step 6: Return result
        return ImproveResult{
            .success = true,
            .applied_deltas = cycle_result.applied_deltas,
            .quality_score = cycle_result.evaluation.success_rate,
            .cycles_analyzed = recent_episodes.len,
            .patterns_found = patterns.len,
            .message = try self.allocator.dupe(u8, "Self-improvement cycle completed"),
            .config = cycle_result.config,
        };
    }

    /// Analyze episodes for improvement patterns
    fn analyzePatterns(self: *const AutoImprove, episode_list: []const episodes.Episode) ![]EpisodePattern {
        var patterns = try std.ArrayList(EpisodePattern).initCapacity(self.allocator, 0);

        // Count failures by action type
        var failure_counts = std.StringHashMap(usize).init(self.allocator);
        defer {
            var iter = failure_counts.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            failure_counts.deinit();
        }

        for (episode_list) |ep| {
            if (!ep.result.success) {
                const action = @tagName(ep.action);
                const count = failure_counts.get(action) orelse 0;
                try failure_counts.put(try self.allocator.dupe(u8, action), count + 1);
            }
        }

        // Generate patterns from failure analysis
        var iter = failure_counts.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* >= 3) {
                // Repeated failure pattern
                try patterns.append(self.allocator, EpisodePattern{
                    .pattern_type = .RepeatedFailure,
                    .frequency = entry.value_ptr.*,
                    .last_occurrence = std.time.timestamp(),
                    .suggestion = try self.allocator.dupe(u8, "Adjust parameters or skip this operation"),
                });
            }
        }

        return patterns.toOwnedSlice(self.allocator);
    }

    /// Generate improvement suggestions from patterns
    fn generateSuggestions(self: *const AutoImprove, patterns: []const EpisodePattern) ![][]const u8 {
        var suggestions = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);

        for (patterns) |pattern| {
            const suggestion = try std.fmt.allocPrint(
                self.allocator,
                "Pattern: {s} (freq: {d})",
                .{ @tagName(pattern.pattern_type), pattern.frequency },
            );
            try suggestions.append(self.allocator, suggestion);
        }

        return suggestions.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// EPISODE TO TRI CONVERTER
// ============================================================================

pub const EpisodeToTri = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) EpisodeToTri {
        return .{ .allocator = allocator };
    }

    /// Convert episodes to .tri specification for self-improvement
    pub fn generateSpec(
        self: *const EpisodeToTri,
        episode_list: []const episodes.Episode,
        writer: anytype,
    ) !void {
        _ = self;
        _ = episode_list;
        try writer.writeAll(
            \\# Generated by Queen Episode-to-Tri Converter
            \\# φ² + 1/φ² = 3 = TRINITY
            \\
            \\name: queen_self_improvement
            \\version: "1.0.0"
            \\language: zig
            \\module: queen_auto_improve
            \\
            \\types:
            \\  ImprovementCandidate:
            \\    fields:
            \\      - name: episode_pattern
            \\        type: "[]Episode"
            \\      - name: tri_spec
            \\        type: "[]const u8"
            \\      - name: t27_algorithms
            \\        type: "[][]const u8"
            \\
            \\  ImprovementResult:
            \\    fields:
            \\      - name: success
            \\        type: "bool"
            \\      - name: applied_deltas
            \\        type: "u32"
            \\      - name: quality_score
            \\        type: "f64"
            \\
            \\behaviors:
            \\  - name: analyzeAndImprove
            \\    description: "Analyze episodes and generate improvements"
            \\    returns: "ImprovementResult"
            \\
        );
    }

    /// Extract failure modes from episodes
    pub fn extractFailureModes(
        self: *const EpisodeToTri,
        episode_list: []const episodes.Episode,
    ) ![][]const u8 {
        var modes = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);

        for (episode_list) |ep| {
            if (!ep.result.success) {
                const mode = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}: {s}",
                    .{ @tagName(ep.action), ep.outcome },
                );
                try modes.append(mode);
            }
        }

        return modes.toOwnedSlice();
    }

    /// Map episodes to .t27 algorithms
    pub fn mapToT27Algorithms(
        self: *const EpisodeToTri,
        episode_list: []const episodes.Episode,
    ) ![][]const u8 {
        var algorithms = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);

        for (episode_list) |ep| {
            // Map episode action to corresponding .t27 algorithm
            const algo = switch (ep.action) {
                .scale_up => "t27/optimization/sgd.t27",
                .scale_down => "t27/optimization/sgd.t27",
                .trigger => "t27/control/pid.t27",
                .set => "t27/common/utility.t27",
                .wait => "t27/common/wait.t27",
                .tri27_op => "t27/tri27/executor.t27",
            };

            try algorithms.append(try self.allocator.dupe(u8, algo));
        }

        return algorithms.toOwnedSlice();
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "auto_improve: AutoImprove init" {
    const allocator = std.testing.allocator;
    const auto_improve = AutoImprove.init(allocator);

    try std.testing.expectEqual(DEFAULT_EPISODE_WINDOW, auto_improve.config.episode_window);
    try std.testing.expectEqual(MIN_EPISODES_FOR_IMPROVE, auto_improve.config.min_episodes);
}

test "auto_improve: EpisodeToTri init" {
    const allocator = std.testing.allocator;
    const converter = EpisodeToTri.init(allocator);

    _ = converter;
}
