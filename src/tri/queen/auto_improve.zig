const std = @import("std");

// Import existing queen modules
const jsonl_reader = @import("jsonl_reader.zig");
const episodes = @import("episodes.zig");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const TRINITY_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3
const DEFAULT_EPISODE_WINDOW: usize = 100;
const MIN_EPISODES_FOR_IMPROVE: usize = 10;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const ImproveConfig = struct {
    episode_window: usize = DEFAULT_EPISODE_WINDOW,
    min_episodes: usize = MIN_EPISODES_FOR_IMPROVE,
    quality_threshold: f64 = 0.8,
    max_deltas: u32 = 5,
};

pub const ImproveResult = struct {
    success: bool,
    applied_deltas: u32 = 0,
    quality_score: f64 = 0.0,
    cycles_analyzed: usize = 0,
    patterns_found: usize = 0,
    message: []const u8,
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
    allocator: std.mem.Allocator,
    config: ImproveConfig,

    /// Initialize with default config
    pub fn init(allocator: std.mem.Allocator) AutoImprove {
        return .{
            .allocator = allocator,
            .config = ImproveConfig{},
        };
    }

    /// Initialize with custom config
    pub fn initWithConfig(allocator: std.mem.Allocator, config: ImproveConfig) AutoImprove {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Run full self-improvement cycle with JSONL-based episode analysis
    pub fn runCycle(self: *const AutoImprove) !ImproveResult {
        std.debug.print("🔄 Starting self-improvement cycle...\n", .{});

        // Step 1: Load recent episodes from JSONL files
        const jsonl_config = jsonl_reader.JsonlEpisodesConfig{
            .logs_dir = ".trinity/logs",
            .agent_filter = null,
            .type_filter = null,
            .max_count = self.config.episode_window,
        };
        const recent_episodes = jsonl_reader.loadJsonlEpisodes(
            self.allocator,
            jsonl_config,
        ) catch |err| {
            std.debug.print("Failed to load episodes: {}\n", .{err});
            return ImproveResult{
                .success = false,
                .message = try std.fmt.allocPrint(self.allocator, "Failed to load episodes: {}", .{err}),
                .applied_deltas = 0,
                .quality_score = 0.0,
                .cycles_analyzed = 0,
                .patterns_found = 0,
            };
        };

        std.debug.print("📊 Loaded {d} episodes from JSONL\n", .{recent_episodes.len});

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

        // Step 3: Calculate quality score
        var success_count: usize = 0;
        var total_count: usize = 0;

        for (recent_episodes) |ep| {
            if (ep.result.success) {
                success_count += 1;
            }
            total_count += 1;

            // Clean up context memory
            if (ep.context.active_issues.len > 0)
                self.allocator.free(ep.context.active_issues);
        }

        const quality_score: f64 = if (total_count > 0)
            @as(f64, @floatFromInt(success_count)) / @as(f64, @floatFromInt(total_count))
        else
            0.0;

        std.debug.print("📈 Quality score: {d:.3} ({d}/{d})\n", .{
            quality_score, success_count, total_count,
        });

        // Step 4: Check if quality threshold met
        const meets_threshold = quality_score >= self.config.quality_threshold;
        std.debug.print("🔍 Threshold check: {d:.3} >= {d:.3} = {}\n", .{ quality_score, self.config.quality_threshold, meets_threshold });

        // Step 5: Analyze patterns
        const patterns = try self.analyzePatterns(recent_episodes);
        defer self.allocator.free(patterns);

        std.debug.print("🔍 Found {d} patterns\n", .{patterns.len});

        // Step 6: Return result
        const message = if (meets_threshold)
            "Quality threshold met - no improvements needed"
        else
            "Quality threshold not met - improvements needed";

        return ImproveResult{
            .success = true,
            .applied_deltas = 0,
            .quality_score = quality_score,
            .cycles_analyzed = recent_episodes.len,
            .patterns_found = patterns.len,
            .message = try self.allocator.dupe(u8, message),
        };
    }

    /// Analyze episodes for improvement patterns (public for backend access)
    pub fn analyzePatterns(self: *const AutoImprove, episode_list: []const episodes.Episode) ![]EpisodePattern {
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
                try patterns.append(self.allocator, EpisodePattern{
                    .pattern_type = .RepeatedFailure,
                    .frequency = entry.value_ptr.*,
                    .last_occurrence = std.time.timestamp(),
                    .suggestion = try self.allocator.dupe(u8, "Increase max_deltas or review parameters"),
                });
            }
        }

        return patterns.toOwnedSlice(self.allocator);
    }

    /// Generate .tri spec from episode analysis when quality < threshold
    /// Returns YAML spec with corrective deltas based on failure patterns
    pub fn generateTriSpec(self: *const AutoImprove, quality_score: f64, patterns: []const EpisodePattern) ![]const u8 {
        var spec_lines = try std.ArrayList([]const u8).initCapacity(self.allocator, 100);

        // Header with metadata
        try spec_lines.append(self.allocator, "# Auto-Improvement .tri Spec\n");
        try spec_lines.append(self.allocator, "# Quality Score: ");
        const quality_str = try std.fmt.allocPrint(self.allocator, "{d:.3}\n", .{quality_score});
        try spec_lines.append(self.allocator, quality_str);
        try spec_lines.append(self.allocator, "# Threshold: ");
        const threshold_str = try std.fmt.allocPrint(self.allocator, "{d:.3}\n", .{self.config.quality_threshold});
        try spec_lines.append(self.allocator, threshold_str);
        const status = if (quality_score >= 0.8) "MET" else "BELOW_THRESHOLD";
        try spec_lines.append(self.allocator, "# Status: ");
        try spec_lines.append(self.allocator, status);
        try spec_lines.append(self.allocator, "\n");
        try spec_lines.append(self.allocator, "@origin(auto_improve)\n");
        try spec_lines.append(self.allocator, "@regen(pattern_based)\n");
        try spec_lines.append(self.allocator, "\n");

        // If quality is good, minimal spec
        if (quality_score >= 0.8) {
            try spec_lines.append(self.allocator, "# Quality Threshold Met\n");
            try spec_lines.append(self.allocator, "# No deltas needed\n");
            try spec_lines.append(self.allocator, "\n");
            try spec_lines.append(self.allocator, "# Keep current configuration\n");
            try spec_lines.append(self.allocator, "# φ² + 1/φ² = 3 = TRINITY\n");
        } else {
            // Quality below threshold - apply corrective patterns
            try spec_lines.append(self.allocator, "# Quality Below Threshold\n");
            const pattern_count_str = try std.fmt.allocPrint(self.allocator, "# Applying {d} corrective patterns\n", .{patterns.len});
            try spec_lines.append(self.allocator, pattern_count_str);
            try spec_lines.append(self.allocator, "\n");
            try spec_lines.append(self.allocator, "# Trinumty Identity: φ² + 1/φ² = 3\n");
            try spec_lines.append(self.allocator, "\n");

            // Generate deltas based on pattern types
            var delta_count: u32 = 0;
            for (patterns) |pattern| {
                delta_count += 1;

                // Delta header
                const delta_header = try std.fmt.allocPrint(self.allocator, "## Delta {d}: {s}\n", .{ delta_count, @tagName(pattern.pattern_type) });
                try spec_lines.append(self.allocator, delta_header);
                try spec_lines.append(self.allocator, "@description(");
                try spec_lines.append(self.allocator, pattern.suggestion);
                try spec_lines.append(self.allocator, ")\n");
                try spec_lines.append(self.allocator, "\n");

                // Pattern-specific corrective actions
                switch (pattern.pattern_type) {
                    .RepeatedFailure => {
                        try spec_lines.append(self.allocator, "# Increase retry limit\n");
                        try spec_lines.append(self.allocator, "max_retries:\n");
                        try spec_lines.append(self.allocator, "  - value: ");
                        const retry_val_str = try std.fmt.allocPrint(self.allocator, "{d}\n", .{3 * pattern.frequency});
                        try spec_lines.append(self.allocator, retry_val_str);
                        try spec_lines.append(self.allocator, "\n");
                    },
                    .PerformanceDegradation => {
                        try spec_lines.append(self.allocator, "# Add performance monitoring\n");
                        try spec_lines.append(self.allocator, "monitoring:\n");
                        try spec_lines.append(self.allocator, "  - enable_histogram: true\n");
                        try spec_lines.append(self.allocator, "  - sample_interval_ms: 100\n");
                        try spec_lines.append(self.allocator, "  - alert_threshold_ms: 5000\n");
                        try spec_lines.append(self.allocator, "\n");
                    },
                    .MissingOptimization => {
                        try spec_lines.append(self.allocator, "# Enable auto-optimization\n");
                        try spec_lines.append(self.allocator, "optimization:\n");
                        try spec_lines.append(self.allocator, "  - strategy: cosine_schedule\n");
                        try spec_lines.append(self.allocator, "  - warmup_ratio: 0.1\n");
                        try spec_lines.append(self.allocator, "  - patience_epochs: 3\n");
                        try spec_lines.append(self.allocator, "\n");
                    },
                    .InefficentConfig => {
                        try spec_lines.append(self.allocator, "# Tune configuration parameters\n");
                        try spec_lines.append(self.allocator, "tuning:\n");
                        try spec_lines.append(self.allocator, "  - target_metric: throughput\n");
                        try spec_lines.append(self.allocator, "  - min_delta: 0.001\n");
                        try spec_lines.append(self.allocator, "  - max_delta: 0.1\n");
                        try spec_lines.append(self.allocator, "\n");
                    },
                }
            }
        }

        // Footer with validation
        try spec_lines.append(self.allocator, "\n");
        try spec_lines.append(self.allocator, "# Validation\n");
        try spec_lines.append(self.allocator, "# Expected outcome: quality_score >= {d:.3}\n");
        try spec_lines.append(self.allocator, "# Trinumty Identity: φ² + 1/φ² = 3\n");

        // Combine all lines
        var result = try std.ArrayList(u8).initCapacity(self.allocator, spec_lines.items.len * 2);
        for (spec_lines.items) |line| {
            try result.appendSlice(self.allocator, line);
        }

        return try result.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// MODULE-LEVEL HELPER FUNCTIONS
// ============================================================================

/// Convenience function to create AutoImprove with default config
pub fn init(allocator: std.mem.Allocator) AutoImprove {
    return AutoImprove.init(allocator);
}

/// Convenience function to create AutoImprove with custom config
pub fn initWithConfig(allocator: std.mem.Allocator, config: ImproveConfig) AutoImprove {
    return AutoImprove.initWithConfig(allocator, config);
}

// ============================================================================
// TESTS
// ============================================================================

test "auto_improve: init and initWithConfig" {
    const allocator = std.testing.allocator;

    const default_config = init(allocator);
    try std.testing.expectEqual(@as(usize, 100), default_config.config.episode_window);
    try std.testing.expectEqual(@as(usize, 10), default_config.config.min_episodes);

    const custom_config = initWithConfig(allocator, .{
        .episode_window = 50,
        .min_episodes = 5,
        .quality_threshold = 0.9,
    });
    try std.testing.expectEqual(@as(usize, 50), custom_config.config.episode_window);
    try std.testing.expectEqual(@as(usize, 5), custom_config.config.min_episodes);
    try std.testing.expectEqual(@as(f64, 0.9), custom_config.config.quality_threshold);
}

test "auto_improve: pattern types" {
    try std.testing.expectEqual(@as(usize, 5), @typeInfo(PatternType).Enum.fields.len);
}
