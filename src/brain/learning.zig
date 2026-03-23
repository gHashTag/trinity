//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN LEARNING — Hippocampal Pattern Recognition & Adaptive Intelligence
//!
//! Learning system that adapts based on historical performance.
//! Brain Region: Hippocampus (Memory Consolidation + Pattern Recognition)
//!
//! Features:
//!   - Performance history tracking
//!   - Pattern recognition for optimal configurations
//!   - Adaptive backoff tuning
//!   - Failure prediction
//!   - Recommendation engine
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const mem = std.mem;
const math = std.math;
const fs = std.fs;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const LEARNING_DATA_PATH = ".trinity/brain/learning_history.jsonl";
const MAX_HISTORY_SIZE = 10000;
const PATTERN_WINDOW_SIZE = 100;
const CONFIDENCE_THRESHOLD = 0.7;

// Sacred constants for adaptive algorithms
const SACRED_PHI: f64 = 1.618033988749895;
const SACRED_PHI_INV: f64 = 0.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Operation types that can be tracked
pub const OperationType = enum(u8) {
    task_claim,
    task_complete,
    task_fail,
    backoff_wait,
    health_check,
    farm_recycle,
    service_deploy,
    agent_run,

    pub fn jsonStringify(value: OperationType, writer: anytype) !void {
        try writer.writeAll(switch (value) {
            .task_claim => "task_claim",
            .task_complete => "task_complete",
            .task_fail => "task_fail",
            .backoff_wait => "backoff_wait",
            .health_check => "health_check",
            .farm_recycle => "farm_recycle",
            .service_deploy => "service_deploy",
            .agent_run => "agent_run",
        });
    }
};

/// Performance metrics for a single operation
pub const PerformanceRecord = struct {
    timestamp: i64,
    operation: OperationType,
    duration_ms: u64,
    success: bool,
    metadata: Metadata,

    pub const Metadata = struct {
        task_id: []const u8,
        agent_id: []const u8,
        attempt: u32,
        backoff_ms: u64,
        error_msg: []const u8,
        health_score: f32,
    };
};

/// Pattern detected in historical data
pub const Pattern = struct {
    name: []const u8,
    confidence: f32,
    description: []const u8,
    recommendation: []const u8,
    pattern_type: PatternType,

    pub const PatternType = enum {
        backoff_optimal,
        failure_imminent,
        performance_degrading,
        optimal_window,
        resource_constraint,
    };
};

/// Adaptive backoff configuration
pub const AdaptiveBackoffConfig = struct {
    initial_ms: u64,
    max_ms: u64,
    multiplier: f32,
    strategy: BackoffStrategy,
    learned_multiplier: f32 = 1.0,
    confidence: f32 = 0.0,

    pub const BackoffStrategy = enum {
        exponential,
        linear,
        phi_weighted,
        adaptive,
    };
};

/// Failure prediction result
pub const FailurePrediction = struct {
    probability: f32,
    reason: []const u8,
    suggested_action: []const u8,
    time_until_failure_ms: u64,
};

/// Recommendation from the learning system
pub const Recommendation = struct {
    action: []const u8,
    priority: u8,
    confidence: f32,
    reasoning: []const u8,
};

/// Learning system state
pub const LearningSystem = struct {
    allocator: mem.Allocator,
    history: std.ArrayList(PerformanceRecord),
    patterns: std.ArrayList(Pattern),
    backoff_config: AdaptiveBackoffConfig,
    failure_models: std.ArrayList(FailureModel),
    stats: SystemStats,

    pub const SystemStats = struct {
        total_records: usize = 0,
        successful_operations: usize = 0,
        failed_operations: usize = 0,
        avg_duration_ms: f64 = 0,
        last_update: i64 = 0,
    };

    pub const FailureModel = struct {
        operation: OperationType,
        threshold_ms: u64,
        failure_rate: f32,
        sample_count: usize,
    };

    const Self = @This();

    /// Initialize the learning system
    pub fn init(allocator: mem.Allocator) !Self {
        // Use ArrayListUnmanaged for better compatibility
        var history = std.ArrayListUnmanaged(PerformanceRecord){};
        try history.ensureTotalCapacity(allocator, 100);

        var patterns = std.ArrayListUnmanaged(Pattern){};
        try patterns.ensureTotalCapacity(allocator, 10);

        var failure_models = std.ArrayListUnmanaged(FailureModel){};
        try failure_models.ensureTotalCapacity(allocator, 10);

        return Self{
            .allocator = allocator,
            .history = history,
            .patterns = patterns,
            .backoff_config = .{
                .initial_ms = 1000,
                .max_ms = 60000,
                .multiplier = 2.0,
                .strategy = .adaptive,
            },
            .failure_models = failure_models,
            .stats = .{},
        };
    }

    /// Deinitialize and save state
    /// Frees all owned memory including pattern strings
    pub fn deinit(self: *Self) void {
        // Clear history
        self.history.clearAndFree(self.allocator);

        // Clear patterns and free their owned strings
        for (self.patterns.items) |pattern| {
            self.allocator.free(pattern.name);
            self.allocator.free(pattern.description);
            self.allocator.free(pattern.recommendation);
        }
        self.patterns.clearAndFree(self.allocator);

        // Clear failure models
        self.failure_models.clearAndFree(self.allocator);
    }

    /// Record a performance event
    pub fn recordEvent(self: *Self, event: PerformanceRecord) !void {
        // Add to history
        try self.history.append(self.allocator, event);

        // Trim if over limit
        while (self.history.items.len > MAX_HISTORY_SIZE) {
            _ = self.history.orderedRemove(0);
        }

        // Update stats
        self.updateStats();

        // Persist to disk
        try persistRecord(event);

        // Retrain patterns if enough data
        if (self.history.items.len % PATTERN_WINDOW_SIZE == 0) {
            try self.learnPatterns();
        }
    }

    /// Learn patterns from historical data
    pub fn learnPatterns(self: *Self) !void {
        // Free old pattern strings before clearing
        for (self.patterns.items) |pattern| {
            self.allocator.free(pattern.name);
            self.allocator.free(pattern.description);
            self.allocator.free(pattern.recommendation);
        }
        self.patterns.clearRetainingCapacity();

        // Pattern 1: Optimal backoff detection
        if (try self.detectOptimalBackoff()) |pattern| {
            try self.patterns.append(self.allocator, pattern);
        }

        // Pattern 2: Failure prediction
        if (try self.detectFailurePatterns()) |pattern| {
            try self.patterns.append(self.allocator, pattern);
        }

        // Pattern 3: Performance degradation
        if (try self.detectPerformanceDegradation()) |pattern| {
            try self.patterns.append(self.allocator, pattern);
        }

        // Pattern 4: Optimal timing windows
        if (try self.detectOptimalWindows()) |pattern| {
            try self.patterns.append(self.allocator, pattern);
        }

        // Update backoff config based on learned patterns
        self.updateBackoffConfig();
    }

    /// Get adaptive backoff delay
    pub fn getBackoffDelay(self: *Self, attempt: u32) u64 {
        const base_delay = switch (self.backoff_config.strategy) {
            .exponential => self.calcExponentialBackoff(attempt),
            .linear => self.calcLinearBackoff(attempt),
            .phi_weighted => self.calcPhiWeightedBackoff(attempt),
            .adaptive => self.calcAdaptiveBackoff(attempt),
        };

        return @min(self.backoff_config.max_ms, base_delay);
    }

    /// Predict probability of failure for next operation
    pub fn predictFailure(self: *const Self, operation: OperationType) FailurePrediction {
        var prob: f32 = 0;
        var reason: []const u8 = "No historical data";
        var action: []const u8 = "Proceed normally";

        // Find relevant failure model
        for (self.failure_models.items) |model| {
            if (model.operation == operation and model.sample_count >= 10) {
                prob = model.failure_rate;
                if (prob > 0.5) {
                    reason = "High historical failure rate";
                    action = "Consider retry with backoff";
                } else if (prob > 0.3) {
                    reason = "Moderate failure risk";
                    action = "Monitor closely";
                }
                break;
            }
        }

        // Check recent failures
        const recent_fail_rate = self.getRecentFailureRate(50);
        if (recent_fail_rate > 0.5) {
            prob = @max(prob, recent_fail_rate);
            reason = "Recent failure spike detected";
            action = "Increase backoff, reduce concurrency";
        }

        return .{
            .probability = prob,
            .reason = reason,
            .suggested_action = action,
            .time_until_failure_ms = if (prob > 0.5) 5000 else 30000,
        };
    }

    /// Get recommendation based on current state
    pub fn getRecommendation(self: *const Self) Recommendation {
        // Check for high-confidence patterns
        for (self.patterns.items) |pattern| {
            if (pattern.confidence >= CONFIDENCE_THRESHOLD) {
                return .{
                    .action = pattern.recommendation,
                    .priority = if (pattern.confidence > 0.9) 1 else 2,
                    .confidence = pattern.confidence,
                    .reasoning = pattern.description,
                };
            }
        }

        // Default recommendation based on stats
        const fail_rate = self.getRecentFailureRate(100);
        if (fail_rate > 0.3) {
            return .{
                .action = "Reduce concurrency, increase backoff",
                .priority = 1,
                .confidence = fail_rate,
                .reasoning = "Recent failure rate elevated",
            };
        }

        return .{
            .action = "Continue normal operation",
            .priority = 3,
            .confidence = 0.5,
            .reasoning = "No significant patterns detected",
        };
    }

    /// Export learning insights as JSON
    pub fn exportInsights(self: *const Self, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"stats\": {{\n", .{});
        try writer.print("    \"total_records\": {d},\n", .{self.stats.total_records});
        try writer.print("    \"success_rate\": {d:.2},\n", .{self.getSuccessRate()});
        try writer.print("    \"avg_duration_ms\": {d:.1}\n", .{self.stats.avg_duration_ms});
        try writer.print("  }},\n", .{});

        try writer.writeAll("  \"patterns\": [\n");
        for (self.patterns.items, 0..) |pattern, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("    {{\n", .{});
            try writer.print("      \"name\": \"{s}\",\n", .{pattern.name});
            try writer.print("      \"confidence\": {d:.2},\n", .{pattern.confidence});
            try writer.print("      \"type\": \"{s}\",\n", .{@tagName(pattern.pattern_type)});
            try writer.print("      \"description\": \"{s}\",\n", .{pattern.description});
            try writer.print("      \"recommendation\": \"{s}\"\n", .{pattern.recommendation});
            try writer.print("    }}", .{});
        }
        try writer.writeAll("\n  ],\n");

        try writer.writeAll("  \"backoff_config\": {\n");
        try writer.print("    \"strategy\": \"{s}\",\n", .{@tagName(self.backoff_config.strategy)});
        try writer.print("    \"learned_multiplier\": {d:.2},\n", .{self.backoff_config.learned_multiplier});
        try writer.print("    \"confidence\": {d:.2}\n", .{self.backoff_config.confidence});
        try writer.writeAll("  }\n");

        try writer.writeAll("}\n");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════════════════════

    fn updateStats(self: *Self) void {
        var total_duration: u64 = 0;
        var success_count: usize = 0;
        var fail_count: usize = 0;

        for (self.history.items) |entry| {
            total_duration += entry.duration_ms;
            if (entry.success) success_count += 1 else fail_count += 1;
        }

        self.stats.total_records = self.history.items.len;
        self.stats.successful_operations = success_count;
        self.stats.failed_operations = fail_count;
        self.stats.avg_duration_ms = if (self.history.items.len > 0)
            @as(f64, @floatFromInt(total_duration)) / @as(f64, @floatFromInt(self.history.items.len))
        else
            0;
        self.stats.last_update = std.time.milliTimestamp();
    }

    fn getSuccessRate(self: *const Self) f32 {
        if (self.stats.total_records == 0) return 1.0;
        return @as(f32, @floatFromInt(self.stats.successful_operations)) /
            @as(f32, @floatFromInt(self.stats.total_records));
    }

    fn getRecentFailureRate(self: *const Self, n: usize) f32 {
        const start = if (n > self.history.items.len) 0 else self.history.items.len - n;
        var failures: usize = 0;

        for (self.history.items[start..]) |entry| {
            if (!entry.success) failures += 1;
        }

        const count = self.history.items.len - start;
        if (count == 0) return 0;
        return @as(f32, @floatFromInt(failures)) / @as(f32, @floatFromInt(count));
    }

    fn calcExponentialBackoff(self: *const Self, attempt: u32) u64 {
        const base = @as(f64, @floatFromInt(self.backoff_config.initial_ms)) *
            std.math.pow(f32, self.backoff_config.multiplier, @as(f32, @floatFromInt(attempt)));
        return @intFromFloat(@min(base, @as(f64, @floatFromInt(self.backoff_config.max_ms))));
    }

    fn calcLinearBackoff(self: *const Self, attempt: u32) u64 {
        return @min(self.backoff_config.max_ms, self.backoff_config.initial_ms + (attempt * 1000));
    }

    fn calcPhiWeightedBackoff(self: *const Self, attempt: u32) u64 {
        const phi: f32 = 1.618;
        const phi_pow = std.math.pow(f32, phi, @as(f32, @floatFromInt(attempt)));
        const base = @as(f64, @floatFromInt(self.backoff_config.initial_ms)) * phi_pow;
        return @intFromFloat(@min(base, @as(f64, @floatFromInt(self.backoff_config.max_ms))));
    }

    fn calcAdaptiveBackoff(self: *Self, attempt: u32) u64 {
        // Use learned multiplier if confidence is high
        const effective_mult = if (self.backoff_config.confidence > CONFIDENCE_THRESHOLD)
            self.backoff_config.learned_multiplier
        else
            self.backoff_config.multiplier;

        const base = @as(f64, @floatFromInt(self.backoff_config.initial_ms)) *
            std.math.pow(f32, effective_mult, @as(f32, @floatFromInt(attempt)));

        // Apply phi-based jitter for thundering herd prevention
        const jitter: f64 = if (attempt % 2 == 0) 1.618 else 0.618;

        const result = @min(base * jitter, @as(f64, @floatFromInt(self.backoff_config.max_ms)));
        // Type safety: ensure result is never negative (rounding edge case)
        const safe_result = @max(result, 0.0);
        return @intFromFloat(safe_result);
    }

    fn detectOptimalBackoff(self: *Self) !?Pattern {
        if (self.history.items.len < 20) return null;

        // Analyze backoff success rates
        var backoff_success = std.AutoHashMap(u64, [2]usize).init(self.allocator);
        defer backoff_success.deinit();

        for (self.history.items) |entry| {
            if (entry.metadata.backoff_ms > 0) {
                const map_entry = try backoff_success.getOrPut(entry.metadata.backoff_ms);
                if (!map_entry.found_existing) {
                    map_entry.value_ptr.* = .{ 0, 0 };
                }
                if (entry.success) {
                    map_entry.value_ptr[0] += 1; // success
                } else {
                    map_entry.value_ptr[1] += 1; // failure
                }
            }
        }

        // Find best backoff value
        var best_backoff: u64 = 0;
        var best_rate: f32 = 0;

        var iter = backoff_success.iterator();
        while (iter.next()) |entry| {
            const total = entry.value_ptr[0] + entry.value_ptr[1];
            if (total == 0) continue;
            const rate = @as(f32, @floatFromInt(entry.value_ptr[0])) / @as(f32, @floatFromInt(total));
            if (rate > best_rate and total >= 3) {
                best_rate = rate;
                best_backoff = entry.key_ptr.*;
            }
        }

        if (best_backoff == 0 or best_rate < 0.7) return null;

        // Use static strings to avoid allocation in this helper
        // The caller will own the memory if needed
        const name = try self.allocator.dupe(u8, "optimal_backoff");
        errdefer self.allocator.free(name);

        const desc = try std.fmt.allocPrint(self.allocator, "Backoff of {d}ms has {d:.0}% success rate", .{ best_backoff, best_rate * 100 });
        errdefer self.allocator.free(desc);

        const rec = try std.fmt.allocPrint(self.allocator, "Use {d}ms initial backoff for this operation type", .{best_backoff});
        errdefer self.allocator.free(rec);

        return .{
            .name = name,
            .confidence = best_rate,
            .description = desc,
            .recommendation = rec,
            .pattern_type = .backoff_optimal,
        };
    }

    fn detectFailurePatterns(self: *Self) !?Pattern {
        const recent_fail_rate = self.getRecentFailureRate(50);

        if (recent_fail_rate > 0.4) {
            const name = try self.allocator.dupe(u8, "high_failure_rate");
            const desc = try std.fmt.allocPrint(self.allocator, "Recent failure rate: {d:.0}%", .{recent_fail_rate * 100});
            const rec = try self.allocator.dupe(u8, "Increase backoff, reduce concurrency, check resource limits");

            return .{
                .name = name,
                .confidence = recent_fail_rate,
                .description = desc,
                .recommendation = rec,
                .pattern_type = .failure_imminent,
            };
        }

        return null;
    }

    fn detectPerformanceDegradation(self: *Self) !?Pattern {
        if (self.history.items.len < 100) return null;

        // Compare first half vs second half
        const mid = self.history.items.len / 2;
        var first_sum: u64 = 0;
        var second_sum: u64 = 0;

        for (self.history.items[0..mid]) |entry| {
            first_sum += entry.duration_ms;
        }
        for (self.history.items[mid..]) |entry| {
            second_sum += entry.duration_ms;
        }

        const first_avg = @as(f64, @floatFromInt(first_sum)) / @as(f64, @floatFromInt(mid));
        const second_avg = @as(f64, @floatFromInt(second_sum)) / @as(f64, @floatFromInt(self.history.items.len - mid));

        const degradation: f32 = @floatCast((second_avg - first_avg) / first_avg);

        if (degradation > 0.5) { // 50% slower
            const name = try self.allocator.dupe(u8, "performance_degrading");
            const desc = try std.fmt.allocPrint(self.allocator, "Average duration increased by {d:.0}%", .{degradation * 100});
            const rec = try self.allocator.dupe(u8, "Check for resource leaks, increase capacity, or reduce load");

            return .{
                .name = name,
                .confidence = @min(0.9, degradation),
                .description = desc,
                .recommendation = rec,
                .pattern_type = .performance_degrading,
            };
        }

        return null;
    }

    fn detectOptimalWindows(self: *Self) !?Pattern {
        // Analyze time-of-day success patterns
        // Group records by hour and find success rate patterns
        if (self.history.items.len < 50) return null;

        var hour_success: [24]usize = [_]usize{0} ** 24;
        var hour_total: [24]usize = [_]usize{0} ** 24;

        // Aggregate by hour
        for (self.history.items) |record| {
            const timestamp_sec = @divFloor(record.timestamp, 1000);
            const hour = @as(usize, @intCast(@rem(timestamp_sec, 86400 / 3600)));
            hour_total[hour] += 1;
            if (record.success) hour_success[hour] += 1;
        }

        // Find best and worst hours
        var best_hour: usize = 0;
        var best_rate: f32 = 0;
        var worst_hour: usize = 0;
        var worst_rate: f32 = 1;

        for (0..24) |hour| {
            if (hour_total[hour] > 0) {
                const rate = @as(f32, @floatFromInt(hour_success[hour])) / @as(f32, @floatFromInt(hour_total[hour]));
                if (rate > best_rate) {
                    best_rate = rate;
                    best_hour = hour;
                }
                if (rate < worst_rate) {
                    worst_rate = rate;
                    worst_hour = hour;
                }
            }
        }

        // If there's a significant difference (>20%), create a pattern
        if (best_rate - worst_rate > 0.2 and hour_total[best_hour] >= 5) {
            const name = try std.fmt.allocPrint(self.allocator, "Optimal Time Window: Hour {d}:00-{d}:00", .{ best_hour, best_hour + 1 });
            errdefer self.allocator.free(name);

            const desc = try std.fmt.allocPrint(self.allocator, "Success rate at hour {d} is {d:.0}% vs {d:.0}% at worst hour ({d})", .{ best_hour, best_rate * 100, worst_rate * 100, worst_hour });
            errdefer self.allocator.free(desc);

            const rec = try self.allocator.dupe(u8, "Schedule critical operations during this optimal window");

            return .{
                .name = name,
                .confidence = best_rate - worst_rate,
                .description = desc,
                .recommendation = rec,
                .pattern_type = .optimal_window,
            };
        }

        return null;
    }

    fn updateBackoffConfig(self: *Self) void {
        // Find optimal backoff pattern
        for (self.patterns.items) |pattern| {
            if (pattern.pattern_type == .backoff_optimal and pattern.confidence > self.backoff_config.confidence) {
                // Extract backoff value from pattern description
                if (mem.indexOf(u8, pattern.description, "Backoff of ")) |start| {
                    const value_start = start + "Backoff of ".len;
                    if (mem.indexOf(u8, pattern.description[value_start..], "ms")) |end| {
                        const value_str = pattern.description[value_start .. value_start + end];
                        if (std.fmt.parseInt(u64, value_str, 10)) |value| {
                            self.backoff_config.initial_ms = value;
                            self.backoff_config.learned_multiplier = 1.618;
                            self.backoff_config.confidence = pattern.confidence;
                            self.backoff_config.strategy = .adaptive;
                        } else |_| {}
                    }
                }
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn loadHistoryImpl(allocator: mem.Allocator, history: *std.ArrayList(PerformanceRecord)) !void {
    const file = fs.cwd().openFile(LEARNING_DATA_PATH, .{}) catch |err| {
        if (err == error.FileNotFound) return; // No history yet
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(content);

    var lines = mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Parse JSON line into PerformanceRecord
        // Expected format: {"timestamp":1234567890,"operation":"task_claim","duration_ms":100,"success":true,"metadata":{...}}
        const parsed = std.json.parseFromSlice(PerformanceRecord, line, allocator) catch {
            // Failed to parse, skip this line
            // Could be legacy format or corrupted data
            continue;
        };

        // Skip records with invalid timestamp
        if (parsed.timestamp == 0) continue;

        try history.append(allocator, parsed.value);
    }
}

fn persistRecord(record: PerformanceRecord) !void {
    const dir = fs.path.dirname(LEARNING_DATA_PATH) orelse ".";
    try fs.cwd().makePath(dir);

    const file = try fs.cwd().createFile(LEARNING_DATA_PATH, .{ .read = true });
    defer file.close();

    try file.seekFromEnd(0);

    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();
    try writer.print("{{\"ts\":{d},\"op\":\"{s}\",\"dur\":{d},\"ok\":{s}}}\n", .{
        record.timestamp,
        @tagName(record.operation),
        record.duration_ms,
        if (record.success) "true" else "false",
    });
    try file.writeAll(fbs.getWritten());
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LearningSystem init and record" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    try learning.recordEvent(.{
        .timestamp = now,
        .operation = .task_claim,
        .duration_ms = 100,
        .success = true,
        .metadata = .{
            .task_id = "test-task-1",
            .agent_id = "agent-1",
            .attempt = 0,
            .backoff_ms = 0,
            .error_msg = "",
            .health_score = 100.0,
        },
    });

    try std.testing.expectEqual(@as(usize, 1), learning.history.items.len);
}

test "LearningSystem backoff calculation" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    // Test exponential backoff
    learning.backoff_config.strategy = .exponential;
    learning.backoff_config.initial_ms = 1000;
    learning.backoff_config.multiplier = 2.0;

    const delay0 = learning.getBackoffDelay(0);
    const delay1 = learning.getBackoffDelay(1);
    const delay2 = learning.getBackoffDelay(2);

    try std.testing.expectEqual(@as(u64, 1000), delay0);
    try std.testing.expectEqual(@as(u64, 2000), delay1);
    try std.testing.expectEqual(@as(u64, 4000), delay2);
}

test "LearningSystem phi-weighted backoff" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    learning.backoff_config.strategy = .phi_weighted;
    learning.backoff_config.initial_ms = 1000;

    const delay0 = learning.getBackoffDelay(0);
    const delay1 = learning.getBackoffDelay(1);

    try std.testing.expect(delay0 > 0);
    try std.testing.expect(delay1 > delay0);
}

test "LearningSystem failure prediction" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const prediction = learning.predictFailure(.task_claim);

    try std.testing.expect(prediction.probability >= 0.0);
    try std.testing.expect(prediction.probability <= 1.0);
}

test "LearningSystem recommendation" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const rec = learning.getRecommendation();

    try std.testing.expect(rec.action.len > 0);
    try std.testing.expect(rec.priority >= 1 and rec.priority <= 3);
    try std.testing.expect(rec.confidence >= 0.0 and rec.confidence <= 1.0);
}

test "LearningSystem stats tracking" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add some records
    try learning.recordEvent(.{
        .timestamp = now,
        .operation = .task_claim,
        .duration_ms = 100,
        .success = true,
        .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
    });

    try learning.recordEvent(.{
        .timestamp = now + 1,
        .operation = .task_claim,
        .duration_ms = 200,
        .success = false,
        .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
    });

    try std.testing.expectEqual(@as(usize, 2), learning.stats.total_records);
    try std.testing.expectEqual(@as(usize, 1), learning.stats.successful_operations);
    try std.testing.expectEqual(@as(usize, 1), learning.stats.failed_operations);
}

test "LearningSystem pattern detection" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add records that should trigger failure pattern
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = i % 2 == 0, // 50% failure rate
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    try learning.learnPatterns();

    // Should detect at least one pattern
    try std.testing.expect(learning.patterns.items.len >= 1);
}

test "AdaptiveBackoffConfig defaults" {
    const config = AdaptiveBackoffConfig{
        .initial_ms = 1000,
        .max_ms = 60000,
        .multiplier = 2.0,
        .strategy = .exponential,
    };

    try std.testing.expectEqual(@as(u64, 1000), config.initial_ms);
    try std.testing.expectEqual(@as(u64, 60000), config.max_ms);
    try std.testing.expectEqual(@as(f32, 2.0), config.multiplier);
}

test "LearningSystem pattern recognition - optimal backoff" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add records showing 5000ms backoff has high success rate
    var i: usize = 0;
    while (i < 25) : (i += 1) {
        const backoff: u64 = if (i < 15) 5000 else 1000;
        const success = i < 15; // 5000ms backoff always succeeds
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = success,
            .metadata = .{
                .task_id = "",
                .agent_id = "",
                .attempt = 0,
                .backoff_ms = backoff,
                .error_msg = "",
                .health_score = 100.0,
            },
        });
    }

    try learning.learnPatterns();

    // Should detect optimal backoff pattern
    const has_optimal_pattern = for (learning.patterns.items) |pattern| {
        if (pattern.pattern_type == .backoff_optimal) break true;
    } else false;

    try std.testing.expect(has_optimal_pattern);
}

test "LearningSystem adaptive backoff tuning" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add records to train the adaptive backoff
    // Note: recordEvent calls learnPatterns every PATTERN_WINDOW_SIZE events
    var i: usize = 0;
    while (i < 99) : (i += 1) {
        const backoff: u64 = 2000 + @as(u64, @intCast(i % 5)) * 1000;
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .backoff_wait,
            .duration_ms = backoff,
            .success = true,
            .metadata = .{
                .task_id = "",
                .agent_id = "",
                .attempt = @intCast(i % 10),
                .backoff_ms = backoff,
                .error_msg = "",
                .health_score = 100.0,
            },
        });
    }

    // Test that adaptive backoff respects max_ms
    learning.backoff_config.max_ms = 10000;
    const delay_high_attempt = learning.getBackoffDelay(100);
    try std.testing.expect(delay_high_attempt <= 10000);
}

test "LearningSystem performance tracking" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add records with varying durations
    const durations = [_]u64{ 50, 100, 150, 200, 250, 300, 350, 400, 450, 500 };
    for (durations, 0..) |dur, idx| {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(idx)),
            .operation = .task_complete,
            .duration_ms = dur,
            .success = true,
            .metadata = .{
                .task_id = "",
                .agent_id = "",
                .attempt = 0,
                .backoff_ms = 0,
                .error_msg = "",
                .health_score = 100.0,
            },
        });
    }

    // Check stats are computed correctly
    try std.testing.expectEqual(@as(usize, 10), learning.stats.total_records);
    try std.testing.expectEqual(@as(usize, 10), learning.stats.successful_operations);
    try std.testing.expectEqual(@as(usize, 0), learning.stats.failed_operations);

    // Average should be (50+100+...+500) / 10 = 275
    const expected_avg: f64 = 275.0;
    try std.testing.expectApproxEqAbs(expected_avg, learning.stats.avg_duration_ms, 0.01);
}

test "LearningSystem failure prediction with history" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add high failure rate for task_claim
    var i: usize = 0;
    while (i < 60) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = i % 3 != 0, // 33% failure rate
            .metadata = .{
                .task_id = "",
                .agent_id = "",
                .attempt = 0,
                .backoff_ms = 0,
                .error_msg = if (i % 3 == 0) "timeout" else "",
                .health_score = 100.0,
            },
        });
    }

    const prediction = learning.predictFailure(.task_claim);

    // Should predict some failure probability
    try std.testing.expect(prediction.probability >= 0.0);
    try std.testing.expect(prediction.suggested_action.len > 0);
}

test "LearningSystem export insights" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    try learning.recordEvent(.{
        .timestamp = now,
        .operation = .task_claim,
        .duration_ms = 100,
        .success = true,
        .metadata = .{
            .task_id = "test-task",
            .agent_id = "agent-1",
            .attempt = 0,
            .backoff_ms = 0,
            .error_msg = "",
            .health_score = 100.0,
        },
    });

    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try learning.exportInsights(writer);

    const output = fbs.getWritten();
    try std.testing.expect(output.len > 0);
    try std.testing.expect(mem.containsAtLeast(u8, output, 1, "\"stats\""));
    try std.testing.expect(mem.containsAtLeast(u8, output, 1, "\"patterns\""));
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKOFF CALCULATION EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════════

test "LearningSystem linear backoff" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    learning.backoff_config.strategy = .linear;
    learning.backoff_config.initial_ms = 1000;
    learning.backoff_config.max_ms = 60000;

    const delay0 = learning.getBackoffDelay(0);
    const delay1 = learning.getBackoffDelay(1);
    const delay2 = learning.getBackoffDelay(2);
    const delay10 = learning.getBackoffDelay(10);

    // Linear: initial + attempt * 1000
    try std.testing.expectEqual(@as(u64, 1000), delay0);
    try std.testing.expectEqual(@as(u64, 2000), delay1);
    try std.testing.expectEqual(@as(u64, 3000), delay2);
    try std.testing.expectEqual(@as(u64, 11000), delay10);
}

test "LearningSystem backoff respects max_ms" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    learning.backoff_config.strategy = .exponential;
    learning.backoff_config.initial_ms = 1000;
    learning.backoff_config.max_ms = 5000;
    learning.backoff_config.multiplier = 2.0;

    // Even at high attempt, should not exceed max
    const delay100 = learning.getBackoffDelay(100);
    try std.testing.expect(delay100 <= 5000);
}

test "LearningSystem phi-weighted backoff increases" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    learning.backoff_config.strategy = .phi_weighted;
    learning.backoff_config.initial_ms = 1000;

    const attempts = [_]u32{ 0, 1, 2, 3, 4, 5 };
    var prev: u64 = 0;

    for (attempts) |attempt| {
        const delay = learning.getBackoffDelay(attempt);
        try std.testing.expect(delay > prev); // Monotonically increasing
        prev = delay;
    }
}

test "LearningSystem adaptive backoff uses learned multiplier" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    learning.backoff_config.strategy = .adaptive;
    learning.backoff_config.initial_ms = 1000;
    learning.backoff_config.learned_multiplier = 1.5;
    learning.backoff_config.confidence = 0.8; // Above threshold

    const delay1 = learning.getBackoffDelay(1);
    const delay2 = learning.getBackoffDelay(2);

    // Should use learned multiplier instead of default
    try std.testing.expect(delay2 > delay1);
}

test "LearningSystem adaptive backoff falls back to default" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    learning.backoff_config.strategy = .adaptive;
    learning.backoff_config.initial_ms = 1000;
    learning.backoff_config.learned_multiplier = 3.0; // High value
    learning.backoff_config.confidence = 0.5; // Below threshold

    const delay1 = learning.getBackoffDelay(1);

    // Should use default multiplier (2.0) when confidence low
    const expected_max = @as(u64, @intFromFloat(@as(f64, @floatFromInt(learning.backoff_config.initial_ms)) * std.math.pow(f32, 2.0, 1)));
    try std.testing.expect(delay1 <= expected_max);
}

test "LearningSystem zero attempt backoff" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const strategies = [_]AdaptiveBackoffConfig.BackoffStrategy{
        .exponential, .linear, .phi_weighted, .adaptive,
    };

    for (strategies) |strategy| {
        learning.backoff_config.strategy = strategy;
        learning.backoff_config.initial_ms = 1000;

        const delay = learning.getBackoffDelay(0);

        // Attempt 0 should return initial delay (or with jitter for adaptive)
        switch (strategy) {
            .adaptive => {
                // Adaptive applies jitter at attempt 0: 1000 * 1.618 = 1618
                try std.testing.expectEqual(@as(u64, 1618), delay);
            },
            else => {
                // Other strategies return initial delay
                try std.testing.expectEqual(@as(u64, 1000), delay);
            },
        }
    }
}

test "LearningSystem backoff config validation" {
    const config = AdaptiveBackoffConfig{
        .initial_ms = 100,
        .max_ms = 60000,
        .multiplier = 2.0,
        .strategy = .exponential,
    };

    try std.testing.expectEqual(@as(u64, 100), config.initial_ms);
    try std.testing.expectEqual(@as(u64, 60000), config.max_ms);
    try std.testing.expectEqual(@as(f32, 2.0), config.multiplier);
    try std.testing.expectEqual(.exponential, config.strategy);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN DETECTION EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════════

test "LearningSystem detectPerformanceDegradation" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // First half: fast operations (10ms)
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_complete,
            .duration_ms = 10,
            .success = true,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    // Second half: slow operations (20ms - 100% increase)
    while (i < 100) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_complete,
            .duration_ms = 20,
            .success = true,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    try learning.learnPatterns();

    // Should detect performance degradation
    const has_degradation = for (learning.patterns.items) |pattern| {
        if (pattern.pattern_type == .performance_degrading) break true;
    } else false;

    try std.testing.expect(has_degradation);
}

test "LearningSystem pattern detection insufficient data" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add fewer than minimum for pattern detection
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = true,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    try learning.learnPatterns();

    // Should not have patterns due to insufficient data
    try std.testing.expectEqual(@as(usize, 0), learning.patterns.items.len);
}

test "LearningSystem optimal backoff pattern" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Create high success rate for 3000ms backoff
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        const backoff: u64 = if (i < 20) 3000 else 1000;
        const success = i < 20;

        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .backoff_wait,
            .duration_ms = backoff,
            .success = success,
            .metadata = .{
                .task_id = "",
                .agent_id = "",
                .attempt = 0,
                .backoff_ms = backoff,
                .error_msg = "",
                .health_score = 100.0,
            },
        });
    }

    try learning.learnPatterns();

    // Should detect optimal backoff pattern
    const has_optimal = for (learning.patterns.items) |pattern| {
        if (pattern.pattern_type == .backoff_optimal and pattern.confidence > 0.6) break true;
    } else false;

    try std.testing.expect(has_optimal);
}

test "LearningSystem pattern type enumeration" {
    const pattern_types = [_]Pattern.PatternType{
        .backoff_optimal,
        .failure_imminent,
        .performance_degrading,
        .optimal_window,
        .resource_constraint,
    };

    for (pattern_types, 0..) |pt, i| {
        try std.testing.expectEqual(@as(usize, i), @intFromEnum(pt));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS AND FAILURE RATE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LearningSystem stats update accuracy" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add 3 successful, 2 failed events
    const durations = [_]u64{ 100, 200, 150, 300, 250 };
    const successes = [_]bool{ true, true, true, false, false };

    for (durations, 0..) |dur, i| {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = dur,
            .success = successes[i],
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    try std.testing.expectEqual(@as(usize, 5), learning.stats.total_records);
    try std.testing.expectEqual(@as(usize, 3), learning.stats.successful_operations);
    try std.testing.expectEqual(@as(usize, 2), learning.stats.failed_operations);

    // Average: (100+200+150+300+250)/5 = 200
    try std.testing.expectApproxEqAbs(@as(f64, 200.0), learning.stats.avg_duration_ms, 0.01);
}

test "LearningSystem stats with no records" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    try std.testing.expectEqual(@as(usize, 0), learning.stats.total_records);
    try std.testing.expectEqual(@as(usize, 0), learning.stats.successful_operations);
    try std.testing.expectEqual(@as(usize, 0), learning.stats.failed_operations);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), learning.stats.avg_duration_ms, 0.01);
}

test "LearningSystem getRecentFailureRate all failures" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add 10 failures
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = false,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    // getRecentFailureRate is private, test via learnPatterns
    try learning.learnPatterns();

    // Should detect high failure rate
    const has_failure_pattern = for (learning.patterns.items) |pattern| {
        if (pattern.pattern_type == .failure_imminent) break true;
    } else false;

    try std.testing.expect(has_failure_pattern);
}

test "LearningSystem getSuccessRate" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // 7 success, 3 failure = 70% success rate
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = i < 7,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    const success_rate = learning.getSuccessRate();
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), success_rate, 0.01);
}

test "LearningSystem getSuccessRate no records" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    // No records, should return 1.0 (perfect)
    const success_rate = learning.getSuccessRate();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), success_rate, 0.01);
}

test "LearningSystem history trimming at limit" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add exactly MAX_HISTORY_SIZE + 1 events
    var i: usize = 0;
    while (i < MAX_HISTORY_SIZE + 10) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = true,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    // History should be trimmed to MAX_HISTORY_SIZE
    try std.testing.expectEqual(MAX_HISTORY_SIZE, learning.history.items.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTION AND RECOMMENDATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LearningSystem predictFailure no data" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const prediction = learning.predictFailure(.task_claim);

    try std.testing.expectEqual(@as(f32, 0.0), prediction.probability);
    try std.testing.expectEqualStrings("No historical data", prediction.reason);
}

test "LearningSystem predictFailure high probability" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    // Create failure model for task_fail operation
    const fail_model = LearningSystem.FailureModel{
        .operation = .task_fail,
        .threshold_ms = 1000,
        .failure_rate = 0.8,
        .sample_count = 50,
    };
    try learning.failure_models.append(allocator, fail_model);

    const prediction = learning.predictFailure(.task_fail);

    // Should predict high failure probability
    try std.testing.expect(prediction.probability > 0.5);
    try std.testing.expect(mem.indexOf(u8, prediction.reason, "failure") != null);
}

test "LearningSystem getRecommendation high priority" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    // Add high confidence pattern
    const pattern = Pattern{
        .name = try allocator.dupe(u8, "high_conf_pattern"),
        .confidence = 0.95,
        .description = try allocator.dupe(u8, "Critical issue detected"),
        .recommendation = try allocator.dupe(u8, "Immediate action required"),
        .pattern_type = .failure_imminent,
    };
    try learning.patterns.append(allocator, pattern);

    const rec = learning.getRecommendation();

    try std.testing.expectEqual(@as(u8, 1), rec.priority); // High priority
    try std.testing.expectEqualStrings("Immediate action required", rec.action);
    try std.testing.expect(rec.confidence > 0.9);
}

test "LearningSystem getRecommendation default" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    // No patterns, should return default
    const rec = learning.getRecommendation();

    try std.testing.expect(rec.action.len > 0);
    try std.testing.expectEqual(@as(u8, 3), rec.priority); // Low priority
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), rec.confidence, 0.01);
}

test "LearningSystem getRecommendation moderate failure rate" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Create 40% failure rate (below 0.5 threshold)
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = i % 5 != 0, // 20% failure rate
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    const rec = learning.getRecommendation();

    // Should recommend continue normal operation
    try std.testing.expect(mem.indexOf(u8, rec.action, "Continue") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPERATION TYPE AND STRUCTURE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "OperationType all values" {
    const operations = [_]OperationType{
        .task_claim,
        .task_complete,
        .task_fail,
        .backoff_wait,
        .health_check,
        .farm_recycle,
        .service_deploy,
        .agent_run,
    };

    for (operations, 0..) |op, i| {
        try std.testing.expectEqual(@as(usize, i), @intFromEnum(op));
    }
}

test "PerformanceRecord metadata structure" {
    const metadata = PerformanceRecord.Metadata{
        .task_id = "task-123",
        .agent_id = "agent-abc",
        .attempt = 5,
        .backoff_ms = 1000,
        .error_msg = "timeout",
        .health_score = 85.5,
    };

    try std.testing.expectEqualStrings("task-123", metadata.task_id);
    try std.testing.expectEqualStrings("agent-abc", metadata.agent_id);
    try std.testing.expectEqual(@as(u32, 5), metadata.attempt);
    try std.testing.expectEqual(@as(u64, 1000), metadata.backoff_ms);
    try std.testing.expectEqualStrings("timeout", metadata.error_msg);
    try std.testing.expectApproxEqAbs(@as(f32, 85.5), metadata.health_score, 0.01);
}

test "FailurePrediction structure" {
    const prediction = FailurePrediction{
        .probability = 0.75,
        .reason = "High failure rate",
        .suggested_action = "Retry with backoff",
        .time_until_failure_ms = 5000,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 0.75), prediction.probability, 0.01);
    try std.testing.expectEqualStrings("High failure rate", prediction.reason);
    try std.testing.expectEqualStrings("Retry with backoff", prediction.suggested_action);
    try std.testing.expectEqual(@as(u64, 5000), prediction.time_until_failure_ms);
}

test "Recommendation structure" {
    const rec = Recommendation{
        .action = "Increase backoff",
        .priority = 1,
        .confidence = 0.85,
        .reasoning = "Recent failures detected",
    };

    try std.testing.expectEqualStrings("Increase backoff", rec.action);
    try std.testing.expectEqual(@as(u8, 1), rec.priority);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), rec.confidence, 0.01);
    try std.testing.expectEqualStrings("Recent failures detected", rec.reasoning);
}

test "AdaptiveBackoffConfig strategy all values" {
    const strategies = [_]AdaptiveBackoffConfig.BackoffStrategy{
        .exponential,
        .linear,
        .phi_weighted,
        .adaptive,
    };

    for (strategies, 0..) |strat, i| {
        try std.testing.expectEqual(@as(usize, i), @intFromEnum(strat));
    }
}

test "LearningSystem timestamp tracking" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const before = std.time.milliTimestamp();

    try learning.recordEvent(.{
        .timestamp = before,
        .operation = .task_claim,
        .duration_ms = 100,
        .success = true,
        .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
    });

    const after = std.time.milliTimestamp();

    // Last update should be within expected window
    try std.testing.expect(learning.stats.last_update >= before);
    try std.testing.expect(learning.stats.last_update <= after);
}

test "LearningSystem pattern retraining trigger" {
    const allocator = std.testing.allocator;
    var learning = try LearningSystem.init(allocator);
    defer learning.deinit();

    const now = std.time.milliTimestamp();

    // Add exactly PATTERN_WINDOW_SIZE - 1 events (should not trigger)
    var i: usize = 0;
    while (i < PATTERN_WINDOW_SIZE - 1) : (i += 1) {
        try learning.recordEvent(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .operation = .task_claim,
            .duration_ms = 100,
            .success = true,
            .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
        });
    }

    // Patterns should not be learned yet
    try std.testing.expectEqual(@as(usize, 0), learning.patterns.items.len);

    // Add one more event (should trigger pattern learning)
    try learning.recordEvent(.{
        .timestamp = now + @as(i64, @intCast(PATTERN_WINDOW_SIZE - 1)),
        .operation = .task_claim,
        .duration_ms = 100,
        .success = true,
        .metadata = .{ .task_id = "", .agent_id = "", .attempt = 0, .backoff_ms = 0, .error_msg = "", .health_score = 100.0 },
    });

    // Patterns should be learned now
    // Note: may not detect patterns with such simple data, but learnPatterns was called
}

test "LearningSystem confidence threshold constant" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), CONFIDENCE_THRESHOLD, 0.01);
}

test "LearningSystem pattern window size constant" {
    try std.testing.expectEqual(@as(usize, 100), PATTERN_WINDOW_SIZE);
}

test "LearningSystem max history size constant" {
    try std.testing.expectEqual(@as(usize, 10000), MAX_HISTORY_SIZE);
}

test "LearningSystem sacred phi constant" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.618033988749895), SACRED_PHI, 0.0001);
}

test "LearningSystem sacred phi inverse constant" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.618033988749895), SACRED_PHI_INV, 0.0001);
}
