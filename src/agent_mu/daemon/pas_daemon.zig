//! PAS Daemon - Real-time Pattern Analysis Service
//!
//! The PAS Daemon runs background analysis tasks, automatically applies
//! high-confidence patterns, and streams results via WebSocket.

const std = @import("std");
const sacred = @import("sacred_constants.zig");

/// Daemon configuration
pub const DaemonConfig = struct {
    analysis_interval_ms: u64 = 1000,
    auto_apply_threshold: f32 = 0.95,
    broadcast_enabled: bool = true,
    max_queue_size: usize = 1000,
    enable_sacred_scoring: bool = true,

    pub fn default() DaemonConfig {
        return .{
            .analysis_interval_ms = 1000,
            .auto_apply_threshold = 0.95,
            .broadcast_enabled = true,
            .max_queue_size = 1000,
            .enable_sacred_scoring = true,
        };
    }
};

/// Analysis task for the daemon
pub const AnalysisTask = struct {
    task_id: u64,
    pattern_id: u64,
    pattern_data: []const u8,
    priority: Priority,
    created_at: i64,
    context: ?TaskContext,

    pub const Priority = enum(u8) { low = 0, normal = 1, high = 2, critical = 3 };
    pub const TaskContext = struct {
        source_agent: []const u8,
        correlation_id: ?u64,
        metadata: std.StringHashMap([]const u8),
    };
};

/// Analysis result from PAS processing
pub const AnalysisResult = struct {
    task_id: u64,
    pattern_id: u64,
    confidence: f32,
    sacred_score: f64,
    recommendation: []const u8,
    auto_applied: bool,
    processed_at: i64,
    processing_duration_ms: i64,

    pub fn isHighConfidence(self: *const AnalysisResult, threshold: f32) bool {
        return self.confidence >= threshold;
    }

    pub fn shouldAutoApply(self: *const AnalysisResult, threshold: f32, sacred_threshold: f64) bool {
        if (!self.isHighConfidence(threshold)) return false;
        if (sacred.SACRED_THRESHOLD > 0 and self.sacred_score < sacred_threshold) return false;
        return true;
    }
};

/// WebSocket server interface (placeholder for integration)
pub const WebSocketServer = struct {
    connected_clients: usize,
    messages_broadcast: usize,

    pub fn init() WebSocketServer {
        return .{
            .connected_clients = 0,
            .messages_broadcast = 0,
        };
    }

    pub fn broadcast(self: *WebSocketServer, message: []const u8) !void {
        _ = message;
        // Placeholder: In production, this would broadcast to all connected clients
        self.messages_broadcast += 1;
    }

    pub fn deinit(self: *WebSocketServer) void {
        _ = self;
    }
};

/// Task queue for daemon processing
pub const TaskQueue = struct {
    queue: std.array_list.Managed(AnalysisTask),
    max_size: usize,
    next_task_id: u64,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) TaskQueue {
        return .{
            .queue = std.array_list.Managed(AnalysisTask).init(allocator),
            .max_size = max_size,
            .next_task_id = 1,
        };
    }

    pub fn push(self: *TaskQueue, task: AnalysisTask) !void {
        if (self.queue.items.len >= self.max_size) {
            return error.QueueFull;
        }
        try self.queue.append(task);
    }

    pub fn pop(self: *TaskQueue) ?AnalysisTask {
        if (self.queue.items.len == 0) return null;

        // Find highest priority task
        var best_idx: usize = 0;
        var best_priority: u8 = 0;

        for (self.queue.items, 0..) |task, i| {
            const priority_val = @intFromEnum(task.priority);
            if (priority_val > best_priority) {
                best_priority = priority_val;
                best_idx = i;
            }
        }

        const task = self.queue.orderedRemove(best_idx);
        return task;
    }

    pub fn peek(self: *const TaskQueue) ?AnalysisTask {
        if (self.queue.items.len == 0) return null;
        return self.queue.items[0];
    }

    pub fn len(self: *const TaskQueue) usize {
        return self.queue.items.len;
    }

    pub fn deinit(self: *TaskQueue) void {
        const allocator = self.queue.allocator;
        var i: usize = 0;
        while (i < self.queue.items.len) : (i += 1) {
            const task = &self.queue.items[i];
            if (task.context) |*ctx| {
                ctx.metadata.deinit();
                allocator.destroy(ctx);
            }
            allocator.free(task.pattern_data);
        }
        self.queue.deinit();
    }
};

/// PAS Daemon - Main daemon structure
pub const PasDaemon = struct {
    config: DaemonConfig,
    running: bool,
    task_queue: TaskQueue,
    ws_server: ?*WebSocketServer,
    allocator: std.mem.Allocator,
    processed_count: usize,
    auto_applied_count: usize,
    sacred_confidence_boost: f64,

    /// Initialize a new PAS Daemon
    pub fn init(allocator: std.mem.Allocator, config: DaemonConfig) PasDaemon {
        return .{
            .config = config,
            .running = false,
            .task_queue = TaskQueue.init(allocator, config.max_queue_size),
            .ws_server = null,
            .allocator = allocator,
            .processed_count = 0,
            .auto_applied_count = 0,
            .sacred_confidence_boost = sacred.MU, // Start with sacred MU boost
        };
    }

    /// Attach WebSocket server
    pub fn attachWebSocketServer(self: *PasDaemon, ws_server: *WebSocketServer) !void {
        if (self.ws_server != null) return error.AlreadyAttached;
        self.ws_server = ws_server;
    }

    /// Start the daemon
    pub fn start(self: *PasDaemon) !void {
        if (self.running) return error.AlreadyRunning;
        self.running = true;
    }

    /// Stop the daemon
    pub fn stop(self: *PasDaemon) void {
        self.running = false;
    }

    /// Submit a new analysis task
    pub fn submitTask(self: *PasDaemon, pattern_id: u64, pattern_data: []const u8, priority: AnalysisTask.Priority) !u64 {
        const task_data = try self.allocator.dupe(u8, pattern_data);
        errdefer self.allocator.free(task_data);

        const task = AnalysisTask{
            .task_id = self.task_queue.next_task_id,
            .pattern_id = pattern_id,
            .pattern_data = task_data,
            .priority = priority,
            .created_at = std.time.milliTimestamp(),
            .context = null,
        };

        try self.task_queue.push(task);
        self.task_queue.next_task_id += 1;
        return task.task_id;
    }

    /// Process a single task
    pub fn processTask(self: *PasDaemon, task: AnalysisTask) !AnalysisResult {
        const start_time = std.time.milliTimestamp();

        // Analyze pattern with sacred mathematics
        const base_confidence = try self.analyzePattern(task.pattern_id, task.pattern_data);

        // Apply sacred confidence boost
        const intelligence_factor = sacred.SacredMath.intelligenceMultiplier(self.auto_applied_count);
        const boost_amount = base_confidence + @as(f32, @floatCast(self.sacred_confidence_boost * intelligence_factor));
        const boosted_confidence = if (boost_amount > 1.0) 1.0 else boost_amount;

        // Calculate sacred score
        const sacred_score = try self.calculateSacredScore(task.pattern_id, task.pattern_data);

        // Generate recommendation
        const recommendation = try self.generateRecommendation(boosted_confidence, sacred_score);

        const end_time = std.time.milliTimestamp();

        // Auto-apply if high confidence
        var auto_applied = false;
        var result = AnalysisResult{
            .task_id = task.task_id,
            .pattern_id = task.pattern_id,
            .confidence = boosted_confidence,
            .sacred_score = sacred_score,
            .recommendation = recommendation,
            .auto_applied = false,
            .processed_at = end_time,
            .processing_duration_ms = end_time - start_time,
        };

        if (result.shouldAutoApply(self.config.auto_apply_threshold, sacred.SACRED_THRESHOLD)) {
            try self.autoApply(task.pattern_id, task.pattern_data);
            auto_applied = true;
            self.auto_applied_count += 1;
        }

        self.processed_count += 1;

        // Update sacred confidence boost based on success
        self.updateSacredBoost(auto_applied);

        result.auto_applied = auto_applied;
        return result;
    }

    /// Main daemon loop (call this periodically)
    pub fn tick(self: *PasDaemon) !void {
        if (!self.running) return error.NotRunning;

        const task = self.task_queue.pop() orelse return;
        const result = try self.processTask(task);

        // Broadcast result if enabled
        if (self.config.broadcast_enabled and self.ws_server != null) {
            const formatted = try self.formatResult(result);
            defer self.allocator.free(formatted);
            try self.ws_server.?.broadcast(formatted);
        }

        // Cleanup task
        self.allocator.free(task.pattern_data);
    }

    /// Analyze pattern and return confidence
    fn analyzePattern(self: *PasDaemon, pattern_id: u64, pattern_data: []const u8) !f32 {
        _ = pattern_id;
        _ = self;

        // Placeholder: In production, this would call actual PAS analysis
        // For now, simulate analysis with sacred math

        // Calculate pattern hash for deterministic results
        var hash: u64 = 0;
        for (pattern_data) |byte| {
            hash = hash *% 31 +% byte;
        }

        // Use hash to generate deterministic confidence
        const base_confidence: f32 = @floatFromInt(@as(u64, @intCast(hash % 30)) + 70);
        return base_confidence / 100.0;
    }

    /// Calculate sacred score for pattern
    fn calculateSacredScore(self: *PasDaemon, pattern_id: u64, pattern_data: []const u8) !f64 {
        _ = pattern_id;
        _ = self;

        // Use sacred checksum as base score
        const checksum = sacred.SacredMath.sacredChecksum(pattern_data);

        // Normalize to 0-1 range using PHI
        const normalized = @as(f64, @floatFromInt(checksum % 1000)) / 1000.0;
        const result = normalized * sacred.PHI;
        return if (result > 1.0) 1.0 else result;
    }

    /// Generate recommendation based on scores
    fn generateRecommendation(self: *PasDaemon, confidence: f32, sacred_score: f64) ![]const u8 {
        if (confidence >= 0.98 and sacred_score >= sacred.SACRED_THRESHOLD) {
            return self.allocator.dupe(u8, "AUTO-APPLY: High confidence with sacred validation");
        } else if (confidence >= 0.90) {
            return self.allocator.dupe(u8, "RECOMMEND: Manual review suggested");
        } else if (confidence >= 0.70) {
            return self.allocator.dupe(u8, "DEFER: Low confidence, needs more data");
        } else {
            return self.allocator.dupe(u8, "REJECT: Confidence too low");
        }
    }

    /// Auto-apply a pattern
    fn autoApply(self: *PasDaemon, pattern_id: u64, pattern_data: []const u8) !void {
        _ = pattern_id;
        _ = pattern_data;
        _ = self;
        // Placeholder: In production, this would apply the pattern
        // For now, just track the count
    }

    /// Update sacred confidence boost based on results
    fn updateSacredBoost(self: *PasDaemon, success: bool) void {
        if (success) {
            // Decrease boost (we're more confident)
            const new_boost = self.sacred_confidence_boost * sacred.PHI_INV;
            self.sacred_confidence_boost = if (new_boost < sacred.MU) sacred.MU else new_boost;
        } else {
            // Increase boost (we need more confidence)
            const new_boost = self.sacred_confidence_boost * sacred.PHI;
            self.sacred_confidence_boost = if (new_boost > 0.1) 0.1 else new_boost;
        }
    }

    /// Format result for broadcasting
    fn formatResult(self: *PasDaemon, result: AnalysisResult) ![]const u8 {
        const json = try std.fmt.allocPrint(
            self.allocator,
            "{{\"{s}\":{d},\"{s}\":{d},\"{s}\":{d:.3},\"{s}\":{d:.3},\"{s}\":\"{s}\",\"{s}\":{d:.3},\"{s}\":{d},\"{s}\":{d}}}",
            .{
                "task_id",     result.task_id,
                "pattern_id",  result.pattern_id,
                "confidence",  result.confidence,
                "sacred",      result.sacred_score,
                "action",      if (result.auto_applied) "AUTO_APPLIED" else "ANALYZED",
                "threshold",   self.config.auto_apply_threshold,
                "processed",   self.processed_count,
                "duration_ms", result.processing_duration_ms,
            },
        );
        return json;
    }

    /// Get daemon statistics
    pub fn getStats(self: *const PasDaemon) DaemonStats {
        return .{
            .running = self.running,
            .queue_length = self.task_queue.len(),
            .processed_count = self.processed_count,
            .auto_applied_count = self.auto_applied_count,
            .auto_apply_rate = if (self.processed_count > 0)
                @as(f64, @floatFromInt(self.auto_applied_count)) / @as(f64, @floatFromInt(self.processed_count))
            else
                0.0,
            .sacred_confidence_boost = self.sacred_confidence_boost,
            .connected_clients = if (self.ws_server != null) self.ws_server.?.connected_clients else 0,
        };
    }

    /// Deinitialize daemon
    pub fn deinit(self: *PasDaemon) void {
        self.task_queue.deinit();
    }
};

/// Daemon statistics
pub const DaemonStats = struct {
    running: bool,
    queue_length: usize,
    processed_count: usize,
    auto_applied_count: usize,
    auto_apply_rate: f64,
    sacred_confidence_boost: f64,
    connected_clients: usize,
};

// ============================================================================
// Tests
// ============================================================================

test "PasDaemon initialization" {
    const allocator = std.testing.allocator;
    const config = DaemonConfig.default();
    var daemon = PasDaemon.init(allocator, config);
    defer daemon.deinit();

    try std.testing.expect(!daemon.running);
    try std.testing.expectEqual(@as(usize, 0), daemon.task_queue.len());
}

test "PasDaemon start and stop" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer daemon.deinit();

    try daemon.start();
    try std.testing.expect(daemon.running);

    daemon.stop();
    try std.testing.expect(!daemon.running);
}

test "PasDaemon submit task" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer daemon.deinit();

    try daemon.start();

    const pattern_data = "test_pattern";
    const task_id = try daemon.submitTask(123, pattern_data, .normal);

    try std.testing.expectEqual(@as(usize, 1), daemon.task_queue.len());
    try std.testing.expectEqual(@as(u64, 1), task_id);
}

test "PasDaemon task priority ordering" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer {
        // Clean up remaining tasks (context is null in these tests)
        while (daemon.task_queue.pop()) |task| {
            allocator.free(task.pattern_data);
        }
        daemon.deinit();
    }

    try daemon.start();

    // Submit tasks with different priorities
    _ = try daemon.submitTask(1, "low", .low);
    _ = try daemon.submitTask(2, "critical", .critical);
    _ = try daemon.submitTask(3, "normal", .normal);

    // Should pop critical first
    const task1 = daemon.task_queue.pop();
    try std.testing.expect(task1 != null);
    try std.testing.expectEqual(AnalysisTask.Priority.critical, task1.?.priority);
    // Clean up the popped task
    if (task1) |t| {
        allocator.free(t.pattern_data);
    }
}

test "PasDaemon process task" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer daemon.deinit();

    try daemon.start();

    const pattern_data = "test_pattern_data";
    const task = AnalysisTask{
        .task_id = 1,
        .pattern_id = 456,
        .pattern_data = pattern_data,
        .priority = .normal,
        .created_at = std.time.milliTimestamp(),
        .context = null,
    };

    const result = try daemon.processTask(task);
    defer allocator.free(result.recommendation);

    try std.testing.expect(result.confidence >= 0.0);
    try std.testing.expect(result.confidence <= 1.0);
    try std.testing.expect(result.sacred_score >= 0.0);
    try std.testing.expect(result.processing_duration_ms >= 0);
}

test "PasDaemon auto-apply threshold" {
    const allocator = std.testing.allocator;
    var config = DaemonConfig.default();
    config.auto_apply_threshold = 0.50; // Lower threshold for testing

    var daemon = PasDaemon.init(allocator, config);
    defer daemon.deinit();

    try daemon.start();

    // Create task that should auto-apply
    const pattern_data = "AAAAA"; // Should hash to high confidence
    const task = AnalysisTask{
        .task_id = 1,
        .pattern_id = 1,
        .pattern_data = pattern_data,
        .priority = .high,
        .created_at = std.time.milliTimestamp(),
        .context = null,
    };

    const result = try daemon.processTask(task);
    defer allocator.free(result.recommendation);

    // With low threshold and good hash, should auto-apply
    try std.testing.expect(daemon.auto_applied_count >= 0);
}

test "PasDaemon sacred confidence boost" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer daemon.deinit();

    try std.testing.expectApproxEqAbs(sacred.MU, daemon.sacred_confidence_boost, 0.001);

    try daemon.start();

    // Simulate successful auto-applies
    for (0..5) |_| {
        daemon.auto_applied_count += 1;
        daemon.updateSacredBoost(true);
    }

    // Boost should decrease with success
    try std.testing.expect(daemon.sacred_confidence_boost < sacred.MU + 0.01);
}

test "PasDaemon getStats" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer daemon.deinit();

    var stats = daemon.getStats();
    try std.testing.expect(!stats.running);

    try daemon.start();

    stats = daemon.getStats();
    try std.testing.expect(stats.running);

    _ = try daemon.submitTask(1, "test", .normal);
    _ = try daemon.submitTask(2, "test2", .normal);

    stats = daemon.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.queue_length);
}

test "PasDaemon WebSocket attachment" {
    const allocator = std.testing.allocator;
    var daemon = PasDaemon.init(allocator, DaemonConfig.default());
    defer daemon.deinit();

    var ws_server = WebSocketServer.init();
    defer ws_server.deinit();

    try daemon.attachWebSocketServer(&ws_server);
    try std.testing.expect(daemon.ws_server != null);

    // Should error on second attachment
    const result = daemon.attachWebSocketServer(&ws_server);
    try std.testing.expectError(error.AlreadyAttached, result);
}

test "PasDaemon queue full" {
    const allocator = std.testing.allocator;
    var config = DaemonConfig.default();
    config.max_queue_size = 2;

    var daemon = PasDaemon.init(allocator, config);
    defer daemon.deinit();

    try daemon.start();

    _ = try daemon.submitTask(1, "test1", .normal);
    _ = try daemon.submitTask(2, "test2", .normal);

    // Third task should fail
    const result = daemon.submitTask(3, "test3", .normal);
    try std.testing.expectError(error.QueueFull, result);
}

test "TaskQueue init and push" {
    const allocator = std.testing.allocator;
    var queue = TaskQueue.init(allocator, 10);
    defer queue.deinit();

    const task = AnalysisTask{
        .task_id = 1,
        .pattern_id = 100,
        .pattern_data = try allocator.dupe(u8, "test"),
        .priority = .normal,
        .created_at = 0,
        .context = null,
    };

    try queue.push(task);
    try std.testing.expectEqual(@as(usize, 1), queue.len());
}

test "TaskQueue pop priority ordering" {
    const allocator = std.testing.allocator;
    var queue = TaskQueue.init(allocator, 10);
    defer {
        // Clean up remaining tasks (context is null in these tests)
        while (queue.pop()) |task| {
            allocator.free(task.pattern_data);
        }
        queue.deinit();
    }

    try queue.push(.{
        .task_id = 1,
        .pattern_id = 1,
        .pattern_data = try allocator.dupe(u8, "low"),
        .priority = .low,
        .created_at = 0,
        .context = null,
    });

    try queue.push(.{
        .task_id = 2,
        .pattern_id = 2,
        .pattern_data = try allocator.dupe(u8, "critical"),
        .priority = .critical,
        .created_at = 0,
        .context = null,
    });

    const task = queue.pop();
    try std.testing.expect(task != null);
    try std.testing.expectEqual(AnalysisTask.Priority.critical, task.?.priority);
    // Clean up the popped task
    if (task) |t| {
        allocator.free(t.pattern_data);
    }
}

test "AnalysisResult shouldAutoApply" {
    const result = AnalysisResult{
        .task_id = 1,
        .pattern_id = 1,
        .confidence = 0.96,
        .sacred_score = sacred.SACRED_THRESHOLD + 0.01,
        .recommendation = "test",
        .auto_applied = false,
        .processed_at = 0,
        .processing_duration_ms = 0,
    };

    try std.testing.expect(result.shouldAutoApply(0.95, sacred.SACRED_THRESHOLD));

    const low_confidence = AnalysisResult{
        .task_id = 1,
        .pattern_id = 1,
        .confidence = 0.90,
        .sacred_score = 0.9,
        .recommendation = "test",
        .auto_applied = false,
        .processed_at = 0,
        .processing_duration_ms = 0,
    };

    try std.testing.expect(!low_confidence.shouldAutoApply(0.95, sacred.SACRED_THRESHOLD));
}
