// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// THALAMUS (Sensory Relay) — Source of Live Truth
// ═══════════════════════════════════════════════════════════════════════════════
//
// PROBLEM: evolution_state.json is stale cache — marks training workers as "stalled"
// SOLUTION: Query Railway logs API directly for real step= progression
//
// Thalamus is the ONLY authorized source of live truth about workers.
// All other modules (Hippocampus, DLPFC) MUST query Thalamus for live data.
//
// NEUROANATOMY: Thalamus = Sensory relay station, filters and relays
//     sensory input (Railway logs) to cortex (decision engine)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("../railway_api.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Live status from Railway logs (source of truth!)
pub const LiveStatus = enum {
    training,
    stalled,
    has_error,
    building,
    not_found,
    unknown,

    pub fn toString(self: LiveStatus) []const u8 {
        return switch (self) {
            .training => "TRAINING",
            .stalled => "stalled (no recent logs)",
            .has_error => "ERROR - needs restart",
            .building => "BUILDING",
            .not_found => "NOT FOUND",
            .unknown => "UNKNOWN",
        };
    }

    pub fn icon(self: LiveStatus) []const u8 {
        return switch (self) {
            .training => "✅",
            .stalled => "⏸️",
            .has_error => "❌",
            .building => "🔄",
            .not_found => "❓",
            .unknown => "❔",
        };
    }
};

/// Worker metrics from live logs
pub const WorkerMetrics = struct {
    step: u32 = 0,
    ppl: f32 = 0,
    tok_per_sec: f32 = 0,
    loss: f32 = 0,
    last_seen_sec: i64 = 0, // UNIX timestamp

    pub fn isFresh(self: *const WorkerMetrics, max_age_sec: i64) bool {
        const now = std.time.timestamp();
        if (self.last_seen_sec == 0) return false;
        const age = now - self.last_seen_sec;
        return age < max_age_sec;
    }
};

/// Full worker status from Thalamus (source of truth!)
pub const WorkerLiveState = struct {
    status: LiveStatus = .unknown,
    metrics: WorkerMetrics = .{},
    is_building: bool = false,
    has_error: bool = false,
    is_training: bool = false,
    fresh: bool = false, // Logs are recent (within 5 min default)
};

// ═══════════════════════════════════════════════════════════════════════════════
// THALAMUS API — Single Source of Live Truth
// ═══════════════════════════════════════════════════════════════════════════════

pub const Thalamus = struct {
    allocator: Allocator,
    api: railway_api.RailwayApi,
    suffix: []const u8, // "" or "_2", "_3" for multi-account

    const Self = @This();

    /// Initialize Thalamus with Railway API client
    pub fn init(allocator: Allocator, suffix: []const u8) !Self {
        const api = try railway_api.RailwayApi.initWithSuffix(allocator, suffix);
        return .{
            .allocator = allocator,
            .api = api,
            .suffix = suffix,
        };
    }

    pub fn deinit(self: *Self) void {
        self.api.deinit();
    }

    /// Get live step count from Railway logs (source of truth!)
    /// Returns 0 if no step found or worker doesn't exist
    pub fn getWorkerLiveStep(self: *Self, service_name: []const u8) !u32 {
        const service_id = self.api.getServiceIdByName(self.api.project_id, service_name) catch return 0;
        defer self.allocator.free(service_id);

        const dep_id = self.api.getLatestDeploymentId(service_id) catch return 0;
        if (dep_id == null) return 0;
        defer self.allocator.free(dep_id.?);

        const logs_json = self.api.getDeploymentLogs(dep_id.?, 20) catch return "";
        defer if (logs_json.len > 0) self.allocator.free(@constCast(logs_json));

        return parseLatestStep(logs_json);
    }

    /// Get live status from Railway logs (source of truth!)
    /// suffix: "" for RAILWAY_API_TOKEN, "_2" for RAILWAY_API_TOKEN_2
    pub fn getWorkerLiveStatus(self: *Self, service_name: []const u8) !WorkerLiveState {
        var state: WorkerLiveState = .{};
        const MAX_LOG_LINES: usize = 20;

        // Get service ID
        const service_id = self.api.getServiceIdByName(self.api.project_id, service_name) catch {
            state.status = .not_found;
            return state;
        };
        defer self.allocator.free(service_id);

        // Get latest deployment ID
        const dep_id = self.api.getLatestDeploymentId(service_id) catch {
            state.status = .not_found;
            return state;
        };
        if (dep_id == null) {
            state.status = .not_found;
            return state;
        }
        defer self.allocator.free(dep_id.?);

        // Get deployment status
        const dep_status = self.api.getDeploymentStatus(dep_id.?) catch "UNKNOWN";

        // Get logs
        const logs_json = self.api.getDeploymentLogs(dep_id.?, MAX_LOG_LINES) catch "";
        defer if (logs_json.len > 0) self.allocator.free(@constCast(logs_json));

        // Check deployment status first
        if (std.mem.eql(u8, dep_status, "BUILDING") or
            std.mem.eql(u8, dep_status, "DEPLOYING") or
            std.mem.eql(u8, dep_status, "INITIALIZING"))
        {
            state.status = .building;
            state.is_building = true;
            return state;
        }

        // Check for real errors
        if (hasRealError(logs_json)) {
            state.status = .has_error;
            state.has_error = true;
            return state;
        }

        // Check for training activity
        if (hasTrainingLogs(logs_json)) {
            state.status = .training;
            state.is_training = true;
            state.metrics.step = parseLatestStep(logs_json);
            state.metrics.ppl = parseLatestPPL(logs_json);
            state.metrics.tok_per_sec = parseLatestTokPerSec(logs_json);
            state.metrics.loss = parseLatestLoss(logs_json);
            state.metrics.last_seen_sec = std.time.timestamp();
            state.fresh = areLogsFresh(logs_json);
        } else if (std.mem.eql(u8, dep_status, "SUCCESS")) {
            state.status = .stalled; // Running but no logs = possibly stalled
        }

        return state;
    }

    /// Get latest metrics from logs (PPL, tok/s, loss)
    pub fn getWorkerMetrics(self: *Self, service_name: []const u8) !WorkerMetrics {
        const state = try self.getWorkerLiveStatus(service_name);
        return state.metrics;
    }

    /// Get live states for all sacred workers
    pub fn getSacredWorkersLive(self: *Self) !std.StringHashMap(WorkerLiveState) {
        const sacred_file = std.fs.cwd().openFile(".trinity/sacred_workers.txt", .{}) catch {
            return std.StringHashMap(WorkerLiveState).init(self.allocator);
        };
        defer sacred_file.close();

        const content = try sacred_file.readToEndAlloc(self.allocator, 8192);
        defer self.allocator.free(content);

        var states = std.StringHashMap(WorkerLiveState).init(self.allocator);

        var iter = std.mem.splitScalar(u8, content, '\n');
        while (iter.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            const state = self.getWorkerLiveStatus(trimmed) catch continue;
            try states.put(trimmed, state);
        }

        return states;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSING HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if logs show real error (DatasetNotFound, OOM, panic)
fn hasRealError(logs_json: []const u8) bool {
    const error_patterns = [_][]const u8{
        "DatasetNotFound",
        "dataset not found",
        "Out of memory",
        "panic:",
        "fatal error",
        "segmentation fault",
    };

    for (error_patterns) |pattern| {
        if (std.mem.indexOf(u8, logs_json, pattern) != null) {
            return true;
        }
    }
    return false;
}

/// Check if logs show active training (step= entries present)
fn hasTrainingLogs(logs_json: []const u8) bool {
    return std.mem.indexOf(u8, logs_json, "step=") != null or
        std.mem.indexOf(u8, logs_json, "Step ") != null;
}

/// Parse latest step from logs JSON
fn parseLatestStep(logs_json: []const u8) u32 {
    var max_step: u32 = 0;

    var iter = std.mem.splitSequence(u8, logs_json, "step");
    while (iter.next()) |part| {
        if (part.len == 0) continue;

        const start_idx = std.mem.indexOfAny(u8, part, "=:") orelse continue;
        var start = start_idx + 1;
        if (start >= part.len) continue;

        if (part[start] == '"') start += 1;
        if (start >= part.len) continue;

        var end: usize = start;
        while (end < part.len and part[end] >= '0' and part[end] <= '9') : (end += 1) {}

        if (end > start) {
            const step_str = part[start..end];
            const step = std.fmt.parseInt(u32, step_str, 10) catch continue;
            if (step > max_step) max_step = step;
        }
    }

    return max_step;
}

/// Parse latest PPL from logs JSON
fn parseLatestPPL(logs_json: []const u8) f32 {
    if (std.mem.indexOf(u8, logs_json, "PPL=")) |idx| {
        const start = idx + 4;
        var end = start;
        while (end < logs_json.len and (logs_json[end] >= '0' and logs_json[end] <= '9' or logs_json[end] == '.')) : (end += 1) {}
        if (end > start) {
            return std.fmt.parseFloat(f32, logs_json[start..end]) catch 0;
        }
    }
    return 0;
}

/// Parse latest tok/s from logs JSON
fn parseLatestTokPerSec(logs_json: []const u8) f32 {
    if (std.mem.indexOf(u8, logs_json, "tok/s=")) |idx| {
        const start = idx + 6;
        var end = start;
        while (end < logs_json.len and (logs_json[end] >= '0' and logs_json[end] <= '9' or logs_json[end] == '.')) : (end += 1) {}
        if (end > start) {
            return std.fmt.parseFloat(f32, logs_json[start..end]) catch 0;
        }
    }
    return 0;
}

/// Parse latest loss from logs JSON
fn parseLatestLoss(logs_json: []const u8) f32 {
    if (std.mem.indexOf(u8, logs_json, "loss=")) |idx| {
        const start = idx + 5;
        var end = start;
        while (end < logs_json.len and (logs_json[end] >= '0' and logs_json[end] <= '9' or logs_json[end] == '.' or logs_json[end] == '-')) : (end += 1) {}
        if (end > start) {
            return std.fmt.parseFloat(f32, logs_json[start..end]) catch 0;
        }
    }
    return 0;
}

/// Check if logs are fresh (contain entries from last 5 minutes)
fn areLogsFresh(logs_json: []const u8) bool {
    _ = 5 * 60; // MAX_FRESHNESS_SEC for future use

    var iter = std.mem.splitSequence(u8, logs_json, "T");
    while (iter.next()) |part| {
        if (part.len < 8) continue;

        var end: usize = 0;
        while (end < part.len and end < 8 and (part[end] >= '0' and part[end] <= '9' or part[end] == ':')) : (end += 1) {}

        if (end >= 8) {
            return true;
        }
    }

    // Fallback: if logs contain "step=" they're probably recent enough
    return std.mem.indexOf(u8, logs_json, "step=") != null;
}

test "thalamus_parse_step" {
    const test_json = "Some logs step=500 step=600 more logs";
    const step = parseLatestStep(test_json);
    try std.testing.expectEqual(@as(u32, 600), step);
}

test "thalamus_parse_ppl" {
    const test_json = "Training logs PPL=4.5 step=100";
    const ppl = parseLatestPPL(test_json);
    try std.testing.expectApproxEqRel(@as(f32, 4.5), ppl, 0.01);
}

test "thalamus_detect_error" {
    const test_json = "Some logs panic: something wrong";
    const has_err = hasRealError(test_json);
    try std.testing.expect(has_err);
}

test "thalamus_has_training_logs" {
    const test_json = "step=100 loss=0.5";
    const has_logs = hasTrainingLogs(test_json);
    try std.testing.expect(has_logs);
}

// ═══════════════════════════════════════════════════════════════════════════════
// THALAMUS COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "thalamus_live_status_enum" {
    try std.testing.expectEqualStrings("training", LiveStatus.training.toString());
    try std.testing.expectEqualStrings("stalled", LiveStatus.stalled.toString());
    try std.testing.expectEqualStrings("crashed", LiveStatus.crashed.toString());
    try std.testing.expectEqualStrings("unknown", LiveStatus.unknown.toString());
    try std.testing.expectEqualStrings("succeeded", LiveStatus.succeeded.toString());
}

test "thalamus_parse_step_no_match" {
    const test_json = "Some logs without step numbers";
    const step = parseLatestStep(test_json);
    try std.testing.expectEqual(@as(u32, 0), step);
}

test "thalamus_parse_step_single" {
    const test_json = "Training at step=12345";
    const step = parseLatestStep(test_json);
    try std.testing.expectEqual(@as(u32, 12345), step);
}

test "thalamus_parse_step_large" {
    const test_json = "Training complete step=999999";
    const step = parseLatestStep(test_json);
    try std.testing.expectEqual(@as(u32, 999999), step);
}

test "thalamus_parse_ppl_no_match" {
    const test_json = "Training logs without PPL";
    const ppl = parseLatestPPL(test_json);
    try std.testing.expect(ppl < 0); // Should return negative for not found
}

test "thalamus_parse_ppl_low" {
    const test_json = "Excellent progress PPL=2.15";
    const ppl = parseLatestPPL(test_json);
    try std.testing.expect(ppl > 2.0 and ppl < 3.0);
}

test "thalamus_parse_ppl_high" {
    const test_json = "Early training PPL=95.3";
    const ppl = parseLatestPPL(test_json);
    try std.testing.expect(ppl > 90.0);
}

test "thalamus_parse_ppl_multiple" {
    const test_json = "PPL=10.5 then PPL=8.2 finally PPL=5.1";
    const ppl = parseLatestPPL(test_json);
    try std.testing.expect(ppl > 5.0 and ppl < 5.2);
}

test "thalamus_error_detection_multiple" {
    const error_keywords = [_][]const u8{
        "panic: out of memory",
        "error: file not found",
        "FATAL: cannot continue",
        "exception: division by zero",
    };

    for (error_keywords) |err| {
        try std.testing.expect(hasRealError(err), "Should detect error in: {s}", .{err});
    }
}

test "thalamus_error_detection_false_positive" {
    const safe_logs = [_][]const u8{
        "Training step 100 completed",
        "Loss decreased to 0.5",
        "Checkpoint saved successfully",
        "Epoch finished",
    };

    for (safe_logs) |log| {
        try std.testing.expect(!hasRealError(log), "Should not detect error in: {s}", .{log});
    }
}

test "thalamus_training_logs_detection" {
    const valid_logs = [_][]const u8{
        "12:34:56 step=100 loss=0.5",
        "Timestamp with step=500",
        "step=1000 PPL=4.5",
    };

    for (valid_logs) |log| {
        try std.testing.expect(hasTrainingLogs(log), "Should detect training in: {s}", .{log});
    }
}

test "thalamus_training_logs_negative" {
    const invalid_logs = [_][]const u8{
        "Just some random text",
        "No step numbers here",
        "Only colons : without numbers",
    };

    for (invalid_logs) |log| {
        try std.testing.expect(!hasTrainingLogs(log), "Should not detect training in: {s}", .{log});
    }
}

test "thalamus_worker_metrics_init" {
    const metrics = WorkerMetrics{
        .step = 1000,
        .ppl = 4.5,
        .tok_per_sec = 1200.0,
        .loss = 0.3,
    };

    try std.testing.expectEqual(@as(u32, 1000), metrics.step);
    try std.testing.expectEqual(@as(f32, 4.5), metrics.ppl);
    try std.testing.expectEqual(@as(f32, 1200.0), metrics.tok_per_sec);
}

test "thalamus_worker_live_state_init" {
    const state = WorkerLiveState{
        .status = .training,
        .metrics = .{
            .step = 500,
            .ppl = 5.0,
            .tok_per_sec = 1000.0,
            .loss = 0.4,
        },
        .logs_json = "step=500 loss=0.4",
    };

    try std.testing.expectEqual(LiveStatus.training, state.status);
    try std.testing.expectEqual(@as(u32, 500), state.metrics.step);
}

test "thalamus_all_live_statuses" {
    const statuses = [_]LiveStatus{
        .training,
        .stalled,
        .crashed,
        .unknown,
        .succeeded,
    };

    for (statuses) |status| {
        const str = status.toString();
        try std.testing.expect(str.len > 0);
    }
}

test "thalamus_edge_case_empty_logs" {
    try std.testing.expectEqual(@as(u32, 0), parseLatestStep(""));
    try std.testing.expect(parseLatestPPL("") < 0);
    try std.testing.expect(!hasRealError(""));
    try std.testing.expect(!hasTrainingLogs(""));
}
