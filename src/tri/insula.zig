// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// INSULAR CORTEX — Interoception (Internal State Monitoring)
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Insula monitors internal body states (pulse, temperature, fatigue)
// Trinity: Monitor Queen's "health" metrics for LC to evaluate
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const hippocampus = @import("hippocampus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL STATE — Queen's interoceptive awareness
// ═══════════════════════════════════════════════════════════════════════════════

pub const InternalState = struct {
    // Timing (microseconds)
    cycle_latency_us: u64,
    thalamus_latency_us: u64,
    dlpfc_decision_us: u64,

    // Memory
    alloc_bytes: u64,
    alloc_count: u32,

    // Activity
    actions_taken: u32,
    actions_suppressed: u32,

    // Decision quality
    action_rate: f32, // % of cycles with action

    // Timestamp
    measured_at: i64,

    /// Create default state
    pub fn init() InternalState {
        return .{
            .cycle_latency_us = 0,
            .thalamus_latency_us = 0,
            .dlpfc_decision_us = 0,
            .alloc_bytes = 0,
            .alloc_count = 0,
            .actions_taken = 0,
            .actions_suppressed = 0,
            .action_rate = 0.0,
            .measured_at = 0,
        };
    }

    /// Check if cycle latency is healthy
    pub fn isHealthyLatency(self: *const InternalState) bool {
        return self.cycle_latency_us < 300_000; // <300ms
    }

    /// Check if memory usage is healthy
    pub fn isHealthyMemory(self: *const InternalState) bool {
        return self.alloc_bytes < 75_000_000; // <75MB
    }

    /// Check if activity rate is healthy
    pub fn isHealthyActivity(self: *const InternalState) bool {
        return self.action_rate >= 0.05; // >=5%
    }

    /// Overall health check
    pub fn isHealthy(self: *const InternalState) bool {
        return self.isHealthyLatency() and
            self.isHealthyMemory() and
            self.isHealthyActivity();
    }

    /// Format state as JSON for Hippocampus
    pub fn formatJson(self: *const InternalState, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"cycle_latency_us":{d},"thalamus_latency_us":{d},"dlpfc_decision_us":{d},
            \\"alloc_bytes":{d},"alloc_count":{d},
            \\"actions_taken":{d},"actions_suppressed":{d},"action_rate":{d:.3},
            \\"measured_at":{d}}}
        , .{
            self.cycle_latency_us,
            self.thalamus_latency_us,
            self.dlpfc_decision_us,
            self.alloc_bytes,
            self.alloc_count,
            self.actions_taken,
            self.actions_suppressed,
            self.action_rate,
            self.measured_at,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TIMING SNAPSHOT — Capture timing at a point in the cycle
// ═══════════════════════════════════════════════════════════════════════════════

pub const TimingSnapshot = struct {
    start: std.time.Instant,
    thalamus_end: ?std.time.Instant = null,
    dlpfc_end: ?std.time.Instant = null,
    test_mode: bool = false,

    pub fn init() TimingSnapshot {
        return .{
            .start = std.time.Instant.now() catch undefined,
        };
    }

    /// Test-friendly init with fixed timestamp
    pub fn initTest() TimingSnapshot {
        return .{
            .start = undefined,
            .test_mode = true,
        };
    }

    /// Mark thalamus phase complete
    pub fn markThalamus(self: *TimingSnapshot) void {
        self.thalamus_end = std.time.Instant.now() catch null;
    }

    /// Mark DLPFC decision complete
    pub fn markDlpfc(self: *TimingSnapshot) void {
        self.dlpfc_end = std.time.Instant.now() catch null;
    }

    /// Calculate cycle latency (total time from start to now)
    pub fn cycleLatencyUs(self: *const TimingSnapshot) u64 {
        // Handle test mode
        if (self.test_mode) return 0;

        const now = std.time.Instant.now() catch return 0;
        const elapsed_ns = now.since(self.start); // Returns nanoseconds
        return elapsed_ns / 1000; // Convert to microseconds
    }

    /// Calculate thalamus latency
    pub fn thalamusLatencyUs(self: *const TimingSnapshot) u64 {
        if (self.thalamus_end) |end| {
            // Handle test mode
            if (self.test_mode) return 0;

            const elapsed_ns = end.since(self.start); // Returns nanoseconds
            return elapsed_ns / 1000; // Convert to microseconds
        }
        return 0;
    }

    /// Calculate DLPFC decision latency
    pub fn dlpfcLatencyUs(self: *const TimingSnapshot) u64 {
        if (self.dlpfc_end) |end| {
            const thalamus_time = self.thalamus_end orelse self.start;

            // Handle test mode
            if (self.test_mode) return 0;

            const elapsed_ns = end.since(thalamus_time); // Returns nanoseconds
            return elapsed_ns / 1000; // Convert to microseconds
        }
        return 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEASURE STATE — Capture current internal state
// ═══════════════════════════════════════════════════════════════════════════════

/// Measure current internal state
pub fn measureState(
    allocator: Allocator,
    cycle_start: i64,
    timing: TimingSnapshot,
    actions_taken: u32,
    actions_suppressed: u32,
    total_cycles: u32,
) !InternalState {
    _ = cycle_start; // Reserved for future use (cycle start timestamp)
    // Get allocator stats (if available)
    // Note: std.heap.GeneralPurposeAllocator doesn't expose current usage
    // We'll use estimated values based on typical patterns
    const alloc_bytes = estimateAllocatedBytes(allocator);
    const alloc_count = estimateAllocCount(allocator);

    // Calculate action rate
    const action_rate: f32 = if (total_cycles > 0)
        @as(f32, @floatFromInt(actions_taken)) / @as(f32, @floatFromInt(total_cycles))
    else
        0.0;

    return InternalState{
        .cycle_latency_us = timing.cycleLatencyUs(),
        .thalamus_latency_us = timing.thalamusLatencyUs(),
        .dlpfc_decision_us = timing.dlpfcLatencyUs(),
        .alloc_bytes = alloc_bytes,
        .alloc_count = alloc_count,
        .actions_taken = actions_taken,
        .actions_suppressed = actions_suppressed,
        .action_rate = action_rate,
        .measured_at = std.time.timestamp(),
    };
}

/// Estimate allocated bytes (heuristic-based)
/// Since Zig allocators don't expose current usage, we use heuristics
fn estimateAllocatedBytes(allocator: Allocator) u64 {
    _ = allocator;
    // TODO: Use arena-based allocation for better tracking
    // For now, return a conservative estimate
    return 10_000_000; // 10MB baseline
}

/// Estimate allocation count (heuristic-based)
fn estimateAllocCount(allocator: Allocator) u32 {
    _ = allocator;
    // TODO: Track allocations with a counting allocator wrapper
    return 100; // Baseline estimate
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPORT STATE — Write to Hippocampus for persistent memory
// ═══════════════════════════════════════════════════════════════════════════════

const INSULA_MEMORY_PATH = ".trinity/memory/insula/current.jsonl";

/// Report state to Hippocampus (kind="insula_state")
pub fn reportState(allocator: Allocator, state: InternalState) !void {
    // Format as JSON
    const json = try state.formatJson(allocator);
    defer allocator.free(json);

    // Ensure directory exists
    std.fs.cwd().makePath(".trinity/memory/insula") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Append to JSONL file
    const file = try std.fs.cwd().openFile(INSULA_MEMORY_PATH, .{ .mode = .write_only });
    defer file.close();

    // Seek to end
    const stat = file.stat() catch return error.FileAccess;
    try file.seekTo(stat.size);

    // Write JSONL entry
    const line = try std.fmt.allocPrint(allocator, "{s}\n", .{json});
    defer allocator.free(line);

    try file.writeAll(line);

    // Also write to Hippocampus for cross-module access
    const summary = "Internal state metrics captured";
    _ = try hippocampus.writeObservation(allocator, "insula", summary, json);
}

/// Load recent states from file
pub fn loadStates(allocator: Allocator, limit: usize) ![]InternalState {
    const file = std.fs.cwd().openFile(INSULA_MEMORY_PATH, .{}) catch {
        return allocator.alloc(InternalState, 0);
    };
    defer file.close();

    const stat = file.stat() catch return allocator.alloc(InternalState, 0);
    if (stat.size == 0) return allocator.alloc(InternalState, 0);

    const contents = try allocator.alloc(u8, stat.size);
    defer allocator.free(contents);

    const n = file.readAll(contents) catch return allocator.alloc(InternalState, 0);
    if (n == 0) return allocator.alloc(InternalState, 0);

    // Parse JSONL (simplified parsing for robustness)
    var states = std.ArrayList(InternalState).init(allocator);
    errdefer states.deinit();

    var line_iter = std.mem.splitScalar(u8, contents[0..n], '\n');
    var count: usize = 0;

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        if (count >= limit) break;

        // Parse JSON manually (avoid full JSON parser for simplicity)
        if (parseInternalStateFromJson(line)) |state| {
            try states.append(state);
            count += 1;
        } else |_| {
            // Skip malformed lines
            continue;
        }
    }

    return states.toOwnedSlice();
}

/// Parse InternalState from JSON string (simplified parser)
fn parseInternalStateFromJson(json: []const u8) !InternalState {
    var state = InternalState.init();

    // Parse cycle_latency_us
    if (std.mem.indexOf(u8, json, "\"cycle_latency_us\":")) |idx| {
        const start = idx + "\"cycle_latency_us\":".len;
        state.cycle_latency_us = parseJsonU64(json[start..]) catch 0;
    }

    // Parse thalamus_latency_us
    if (std.mem.indexOf(u8, json, "\"thalamus_latency_us\":")) |idx| {
        const start = idx + "\"thalamus_latency_us\":".len;
        state.thalamus_latency_us = parseJsonU64(json[start..]) catch 0;
    }

    // Parse dlpfc_decision_us
    if (std.mem.indexOf(u8, json, "\"dlpfc_decision_us\":")) |idx| {
        const start = idx + "\"dlpfc_decision_us\":".len;
        state.dlpfc_decision_us = parseJsonU64(json[start..]) catch 0;
    }

    // Parse alloc_bytes
    if (std.mem.indexOf(u8, json, "\"alloc_bytes\":")) |idx| {
        const start = idx + "\"alloc_bytes\":".len;
        state.alloc_bytes = parseJsonU64(json[start..]) catch 0;
    }

    // Parse alloc_count
    if (std.mem.indexOf(u8, json, "\"alloc_count\":")) |idx| {
        const start = idx + "\"alloc_count\":".len;
        state.alloc_count = parseJsonU32(json[start..]) catch 0;
    }

    // Parse actions_taken
    if (std.mem.indexOf(u8, json, "\"actions_taken\":")) |idx| {
        const start = idx + "\"actions_taken\":".len;
        state.actions_taken = parseJsonU32(json[start..]) catch 0;
    }

    // Parse actions_suppressed
    if (std.mem.indexOf(u8, json, "\"actions_suppressed\":")) |idx| {
        const start = idx + "\"actions_suppressed\":".len;
        state.actions_suppressed = parseJsonU32(json[start..]) catch 0;
    }

    // Parse action_rate
    if (std.mem.indexOf(u8, json, "\"action_rate\":")) |idx| {
        const start = idx + "\"action_rate\":".len;
        state.action_rate = parseJsonF32(json[start..]) catch 0.0;
    }

    // Parse measured_at
    if (std.mem.indexOf(u8, json, "\"measured_at\":")) |idx| {
        const start = idx + "\"measured_at\":".len;
        state.measured_at = parseJsonI64(json[start..]) catch 0;
    }

    return state;
}

/// Parse u64 from JSON (simplified)
fn parseJsonU64(data: []const u8) !u64 {
    var start: usize = 0;
    while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}

    var end: usize = start;
    while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}

    if (end == start) return error.InvalidJson;

    return std.fmt.parseInt(u64, data[start..end], 10);
}

/// Parse u32 from JSON (simplified)
fn parseJsonU32(data: []const u8) !u32 {
    const value = try parseJsonU64(data);
    if (value > std.math.maxInt(u32)) return error.InvalidJson;
    return @as(u32, @intCast(value));
}

/// Parse f32 from JSON (simplified)
fn parseJsonF32(data: []const u8) !f32 {
    var start: usize = 0;
    while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}

    var end: usize = start;
    while (end < data.len and (data[end] >= '0' and data[end] <= '9' or data[end] == '.' or data[end] == '-')) : (end += 1) {}

    if (end == start) return error.InvalidJson;

    return std.fmt.parseFloat(f32, data[start..end]);
}

/// Parse i64 from JSON (simplified)
fn parseJsonI64(data: []const u8) !i64 {
    var start: usize = 0;
    while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}

    var end: usize = start;
    while (end < data.len and (data[end] == '-' or (data[end] >= '0' and data[end] <= '9'))) : (end += 1) {}

    if (end == start) return error.InvalidJson;

    return std.fmt.parseInt(i64, data[start..end], 10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "insula — InternalState init" {
    const state = InternalState.init();
    try std.testing.expectEqual(@as(u64, 0), state.cycle_latency_us);
    try std.testing.expectEqual(@as(u64, 0), state.alloc_bytes);
    try std.testing.expectEqual(@as(f32, 0.0), state.action_rate);
}

test "insula — InternalState isHealthyLatency" {
    var state = InternalState.init();
    try std.testing.expect(state.isHealthyLatency()); // 0 is healthy

    state.cycle_latency_us = 200_000; // 200ms
    try std.testing.expect(state.isHealthyLatency());

    state.cycle_latency_us = 400_000; // 400ms
    try std.testing.expect(!state.isHealthyLatency());
}

test "insula — InternalState isHealthyMemory" {
    var state = InternalState.init();
    try std.testing.expect(state.isHealthyMemory()); // 0 is healthy

    state.alloc_bytes = 50_000_000; // 50MB
    try std.testing.expect(state.isHealthyMemory());

    state.alloc_bytes = 100_000_000; // 100MB
    try std.testing.expect(!state.isHealthyMemory());
}

test "insula — InternalState isHealthyActivity" {
    var state = InternalState.init();
    try std.testing.expect(!state.isHealthyActivity()); // 0% is not healthy

    state.action_rate = 0.1; // 10%
    try std.testing.expect(state.isHealthyActivity());

    state.action_rate = 0.01; // 1%
    try std.testing.expect(!state.isHealthyActivity());
}

test "insula — InternalState isHealthy overall" {
    var state = InternalState{
        .cycle_latency_us = 100_000,
        .thalamus_latency_us = 30_000,
        .dlpfc_decision_us = 40_000,
        .alloc_bytes = 50_000_000,
        .alloc_count = 100,
        .actions_taken = 5,
        .actions_suppressed = 1,
        .action_rate = 0.1,
        .measured_at = 0,
    };
    try std.testing.expect(state.isHealthy());
}

test "insula — InternalState formatJson" {
    var state = InternalState{
        .cycle_latency_us = 123456,
        .thalamus_latency_us = 45000,
        .dlpfc_decision_us = 32000,
        .alloc_bytes = 50000000,
        .alloc_count = 1000,
        .actions_taken = 5,
        .actions_suppressed = 2,
        .action_rate = 0.125,
        .measured_at = 1710840000,
    };

    const json = try state.formatJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"cycle_latency_us\":123456") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"action_rate\":0.125") != null);
}

test "insula — TimingSnapshot init" {
    const snap = TimingSnapshot.init();
    // Just verify it doesn't crash
    _ = snap;
}

test "insula — parseJsonU64" {
    const result = try parseJsonU64("12345");
    try std.testing.expectEqual(@as(u64, 12345), result);

    const result2 = parseJsonU64("  67890  ") catch 0;
    try std.testing.expectEqual(@as(u64, 67890), result2);
}

test "insula — parseJsonU32" {
    const result = try parseJsonU32("12345");
    try std.testing.expectEqual(@as(u32, 12345), result);
}

test "insula — parseJsonF32" {
    const result = try parseJsonF32("3.14");
    try std.testing.expectApproxEqAbs(@as(f32, 3.14), result, 0.01);
}

test "insula — parseJsonI64" {
    const result = try parseJsonI64("-12345");
    try std.testing.expectEqual(@as(i64, -12345), result);
}

test "insula — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "insula — CellHealth Status enum" {
    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(CellHealth.Status.healthy));
    try std.testing.expectEqual(@as(i32, 1), @intFromEnum(CellHealth.Status.weak));
    try std.testing.expectEqual(@as(i32, 2), @intFromEnum(CellHealth.Status.broken));
}

test "insula — CellHealth struct defaults" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "insula — TimingSnapshot initTest" {
    const snap = TimingSnapshot.initTest();
    try std.testing.expectEqual(@as(u64, 0), snap.cycleLatencyUs());
    try std.testing.expectEqual(@as(u64, 0), snap.thalamusLatencyUs());
    try std.testing.expectEqual(@as(u64, 0), snap.dlpfcLatencyUs());
}

test "insula — TimingSnapshot markThalamus" {
    var snap = TimingSnapshot.initTest();
    snap.markThalamus();
    // Verify method doesn't crash in test mode
    // (thalamus_end may be null or set depending on platform)
}

test "insula — TimingSnapshot markDlpfc" {
    var snap = TimingSnapshot.initTest();
    snap.markDlpfc();
    // Verify method doesn't crash in test mode
    // (dlpfc_end may be null or set depending on platform)
}

test "insula — measureState basic" {
    const timing = TimingSnapshot.initTest();
    const state = try measureState(
        std.testing.allocator,
        0,
        timing,
        5, // actions_taken
        2, // actions_suppressed
        10, // total_cycles
    );
    try std.testing.expectEqual(@as(u32, 5), state.actions_taken);
    try std.testing.expectEqual(@as(u32, 2), state.actions_suppressed);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.action_rate, 0.01);
}

test "insula — measureState zero cycles" {
    const timing = TimingSnapshot.initTest();
    const state = try measureState(
        std.testing.allocator,
        0,
        timing,
        0,
        0,
        0, // total_cycles = 0
    );
    try std.testing.expectEqual(@as(f32, 0.0), state.action_rate);
}

test "insula — parseJsonU64 handles invalid input" {
    const result = parseJsonU64("abc");
    try std.testing.expectError(error.InvalidJson, result);
}

test "insula — parseJsonF32 handles invalid input" {
    const result = parseJsonF32("xyz");
    try std.testing.expectError(error.InvalidJson, result);
}

test "insula — parseJsonI64 handles invalid input" {
    const result = parseJsonI64("not-a-number");
    try std.testing.expectError(error.InvalidJson, result);
}

test "insula — parseJsonU32 overflow" {
    const result = parseJsonU32("999999999999999999999");
    try std.testing.expectError(error.Overflow, result);
}

test "insula — parseInternalStateFromJson basic" {
    const json = "{\"cycle_latency_us\":123456,\"thalamus_latency_us\":30000,\"dlpfc_decision_us\":20000,\"alloc_bytes\":50000000,\"alloc_count\":100,\"actions_taken\":5,\"actions_suppressed\":1,\"action_rate\":0.5,\"measured_at\":1710840000}";
    const state = try parseInternalStateFromJson(json);
    try std.testing.expectEqual(@as(u64, 123456), state.cycle_latency_us);
    try std.testing.expectEqual(@as(u64, 30000), state.thalamus_latency_us);
    try std.testing.expectEqual(@as(u64, 20000), state.dlpfc_decision_us);
    try std.testing.expectEqual(@as(u64, 50000000), state.alloc_bytes);
    try std.testing.expectEqual(@as(u32, 100), state.alloc_count);
    try std.testing.expectEqual(@as(u32, 5), state.actions_taken);
    try std.testing.expectEqual(@as(u32, 1), state.actions_suppressed);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.action_rate, 0.01);
    try std.testing.expectEqual(@as(i64, 1710840000), state.measured_at);
}

test "insula — parseInternalStateFromJson partial" {
    const json = "{\"cycle_latency_us\":100000,\"action_rate\":0.25}";
    const state = try parseInternalStateFromJson(json);
    try std.testing.expectEqual(@as(u64, 100000), state.cycle_latency_us);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), state.action_rate, 0.01);
    // Unparsed fields should be 0
    try std.testing.expectEqual(@as(u64, 0), state.alloc_bytes);
}

test "insula — InternalState unhealthy overall" {
    var state = InternalState.init();
    state.cycle_latency_us = 500_000; // Too slow
    try std.testing.expect(!state.isHealthy());
}

test "insula — InternalState unhealthy memory" {
    var state = InternalState.init();
    state.alloc_bytes = 100_000_000; // Too much memory
    try std.testing.expect(!state.isHealthy());
}

test "insula — InternalState unhealthy activity" {
    var state = InternalState.init();
    state.action_rate = 0.01; // Too low
    try std.testing.expect(!state.isHealthy());
}

test "insula — InternalState threshold boundary" {
    var state = InternalState.init();
    state.cycle_latency_us = 299_999; // Just under threshold
    try std.testing.expect(state.isHealthyLatency());

    state.cycle_latency_us = 300_000; // Exactly at threshold
    try std.testing.expect(!state.isHealthyLatency());
}

test "insula — InternalState memory threshold" {
    var state = InternalState.init();
    state.alloc_bytes = 74_999_999; // Just under threshold
    try std.testing.expect(state.isHealthyMemory());

    state.alloc_bytes = 75_000_000; // Exactly at threshold
    try std.testing.expect(!state.isHealthyMemory());
}

test "insula — InternalState activity threshold" {
    var state = InternalState.init();
    state.action_rate = 0.049; // Just under threshold
    try std.testing.expect(!state.isHealthyActivity());

    state.action_rate = 0.05; // Exactly at threshold
    try std.testing.expect(state.isHealthyActivity());
}
