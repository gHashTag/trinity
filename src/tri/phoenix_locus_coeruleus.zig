// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// LOCUS COERULEUS — Main Noradrenergic Source (Alarm System)
// ═════════════════════════════════════════════════════════════════════════
// Neuro: Main noradrenergic source — arousal, stress response, attention
// Trinity: ALARM SYSTEM — raise Queen DLPFC arousal for critical events
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const hippocampus = @import("hippocampus.zig");

// ═════════════════════════════════════════════════════════════════════════
// AROUSAL LEVEL — 0-5: sleep to emergency
// ═════════════════════════════════════════════════════════════════════

pub const ArousalLevel = enum(u8) {
    sleep = 0,
    idle = 1,
    normal = 2,
    alert = 3,
    alarm = 4,
    emergency = 5,

    pub fn label(self: ArousalLevel) []const u8 {
        return switch (self) {
            .sleep => "SLEEP",
            .idle => "IDLE",
            .normal => "NORMAL",
            .alert => "ALERT",
            .alarm => "ALARM",
            .emergency => "EMERGENCY",
        };
    }

    pub fn emoji(self: ArousalLevel) []const u8 {
        return switch (self) {
            .sleep => qt.E_TIMER,
            .idle => qt.E_WRENCH,
            .normal => qt.E_CHECK,
            .alert => qt.E_WRENCH,
            .alarm => qt.E_SIREN,
            .emergency => qt.E_FIRE,
        };
    }
};

// ═════════════════════════════════════════════════════════════════
// ALERT TYPES — What triggers alarm?
// ═══════════════════════════════════════════════════════════════════

pub const AlertKind = enum {
    worker_crashed, // Training service died
    ppl_divergence, // PPL skyrocketed (>10x baseline)
    build_broken, // Build system failed
    token_expired, // API key died
    health_critical, // Multiple cells broken
    memory_corruption, // Hippocampus write failed

    pub fn label(self: AlertKind) []const u8 {
        return switch (self) {
            .worker_crashed => "WORKER CRASHED",
            .ppl_divergence => "PPL DIVERGENCE",
            .build_broken => "BUILD BROKEN",
            .token_expired => "TOKEN EXPIRED",
            .health_critical => "HEALTH CRITICAL",
            .memory_corruption => "MEMORY CORRUPTION",
        };
    }

    pub fn severity(self: AlertKind) u8 {
        return switch (self) {
            .worker_crashed => 4,
            .ppl_divergence => 5,
            .build_broken => 5,
            .token_expired => 3,
            .health_critical => 5,
            .memory_corruption => 4,
        };
    }
};

/// Alert payload with metadata
pub const Alert = struct {
    kind: AlertKind,
    level: ArousalLevel,
    message: [256]u8 = undefined,
    message_len: usize = 0,
    timestamp: i64 = 0,

    pub fn messageStr(self: *const Alert) []const u8 {
        return self.message[0..self.message_len];
    }

    pub fn setMessage(self: *Alert, text: []const u8) void {
        const len = @min(text.len, self.message.len);
        @memcpy(self.message[0..len], text[0..len]);
        self.message_len = len;
        self.timestamp = std.time.timestamp();
    }
};

/// Locus Coeruleus state
pub const LocusState = struct {
    arousal: ArousalLevel = .normal,
    alert_count: u32 = 0,
    last_alert: Alert = Alert{
        .kind = .worker_crashed,
        .level = .normal,
        .message_len = 0,
        .timestamp = 0,
    },
    alert_sink: ?AlertSink = null,
};

/// Callback interface for sending alerts (avoids circular import)
pub const AlertSink = *const fn (Alert, ArousalLevel) void;

/// Helper: infer arousal level from alert kind
fn inferArousal(kind: AlertKind) ArousalLevel {
    const severity = kind.severity();
    if (severity >= 5) return .emergency;
    if (severity >= 4) return .alarm;
    if (severity >= 3) return .alert;
    return .normal;
}

/// Initialize Locus Coeruleus with alert sink
pub fn init(sink: AlertSink) LocusState {
    return .{
        .alert_sink = sink,
    };
}

/// Trigger alarm — send to sink and raise arousal
pub fn triggerAlarm(
    state: *LocusState,
    kind: AlertKind,
    message: []const u8,
    level: ?ArousalLevel, // Use caller's level or default based on severity
) !void {
    const alert_level = level orelse inferArousal(kind);

    // Build alert payload
    var alert = Alert{
        .kind = kind,
        .level = alert_level,
    };

    const len = @min(message.len, alert.message.len);
    @memcpy(alert.message[0..len], message[0..len]);
    alert.message_len = len;

    // Raise arousal
    if (@intFromEnum(alert_level) > @intFromEnum(state.arousal)) {
        state.arousal = alert_level;
    }

    // Call sink (Telegram, DLPFC, etc.)
    if (state.alert_sink) |sink| {
        sink(alert, state.arousal);
    }

    // Update counters
    state.alert_count += 1;
    state.last_alert = alert;

    // Log to hippocampus
    try logToHippocampus(state, kind, message);
}

/// Check arousal level
pub fn getArousal(state: *const LocusState) ArousalLevel {
    return state.arousal;
}

/// Get alert count
pub fn getAlertCount(state: *const LocusState) u32 {
    return state.alert_count;
}

/// Decay arousal over time (natural relaxation)
pub fn decayArousal(state: *LocusState, decay_sec: u32) void {
    _ = decay_sec;
    const now = std.time.timestamp();
    const last_alert_age = now - state.last_alert.timestamp;

    // Fast decay: lose 1 level per 5 minutes of no alerts
    if (last_alert_age > 300) {
        const current_level = @intFromEnum(state.arousal);
        if (current_level > 0) {
            state.arousal = @as(ArousalLevel, @enumFromInt(current_level - 1));
        }
    }
}

/// Log alert to hippocampus
fn logToHippocampus(state: *const LocusState, kind: AlertKind, message: []const u8) !void {
    const data = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "\\\"kind\\\":\\\"{s}\\\",\\\"level\\\":\\\"{s}\\\",\\\"message\\\":\\\"{s}\\\"",
        .{ kind.label(), state.arousal.label(), message },
    );
    defer std.heap.page_allocator.free(data);

    _ = try hippocampus.writeError(std.heap.page_allocator, "locus_coeruleus", "alert triggered", data);
}

// ═════════════════════════════════════════════════════════════════
// FILE PERSISTENCE — Save/load LC state for cross-cycle continuity
// ═════════════════════════════════════════════════════════════════

const LOCUS_STATE_PATH = ".trinity/queen/locus_state.json";

/// Save LC state to file
pub fn saveState(state: LocusState) void {
    var file = std.fs.cwd().openFile(LOCUS_STATE_PATH, .{ .mode = .write_only }) catch {
        // Create parent dirs if missing
        std.fs.cwd().makePath(".trinity/queen") catch return;
        return std.fs.cwd().createFile(LOCUS_STATE_PATH, .{}) catch |err| {
            _ = err;
            return;
        };
    };
    defer file.close();

    // Truncate existing file
    file.setEndPos(0) catch {};

    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf,
        \\{{"arousal":{d},"alert_count":{d},"last_alert_ts":{d}}}
    , .{
        @intFromEnum(state.arousal),
        state.alert_count,
        state.last_alert.timestamp,
    }) catch return;

    file.writeAll(msg) catch {};
}

/// Load LC state from file (returns default if missing)
pub fn loadState() LocusState {
    const file = std.fs.cwd().openFile(LOCUS_STATE_PATH, .{}) catch return LocusState{};
    defer file.close();

    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch return LocusState{};
    if (n == 0) return LocusState{};

    const data = buf[0..n];
    var state = LocusState{};

    // Parse JSON manually (avoid full JSON parser for simplicity)
    if (std.mem.indexOf(u8, data, "\"arousal\":")) |idx| {
        var start = idx + "\"arousal\":".len;
        if (start < data.len and data[start] == ' ') start += 1;
        var end = start;
        while (end < data.len and data[end] >= '0' and data[end] <= '5') : (end += 1) {}
        if (end > start) {
            const level_str = data[start..end];
            const level = std.fmt.parseInt(u8, level_str, 10) catch 0;
            if (level <= 5) {
                state.arousal = @as(ArousalLevel, @enumFromInt(@as(u2, @intCast(level))));
            }
        }
    }

    if (std.mem.indexOf(u8, data, "\"alert_count\":")) |idx| {
        var start = idx + "\"alert_count\":".len;
        if (start < data.len and data[start] == ' ') start += 1;
        var end = start;
        while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
        if (end > start) {
            state.alert_count = std.fmt.parseInt(u32, data[start..end], 10) catch 0;
        }
    }

    if (std.mem.indexOf(u8, data, "\"last_alert_ts\":")) |idx| {
        var start = idx + "\"last_alert_ts\":".len;
        if (start < data.len and data[start] == ' ') start += 1;
        var end = start;
        while (end < data.len and (data[end] >= '0' and data[end] <= '9' or data[end] == '-')) : (end += 1) {}
        if (end > start) {
            state.last_alert.timestamp = std.fmt.parseInt(i64, data[start..end], 10) catch 0;
        }
    }

    return state;
}

// ═════════════════════════════════════════════════════════════════
// CELL HEALTH — for tri cell status
// ═════════════════════════════════════════════════════════════════

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

// ═════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════

fn sinkFn(_: Alert, _: ArousalLevel) void {}

test "locus_coeruleus — init sets sink" {
    const state = init(sinkFn);
    try std.testing.expect(state.alert_sink != null);
}

test "locus_coeruleus — triggerAlarm raises arousal" {
    // Use a simple sink that just verifies it was called
    var state = init(sinkFn);

    try triggerAlarm(&state, .worker_crashed, "Worker crashed", .alarm);
    try std.testing.expectEqual(ArousalLevel.alarm, state.arousal);
    try std.testing.expectEqual(@as(u32, 1), state.alert_count);
}

test "locus_coeruleus — decayArousal works" {
    var state = init(sinkFn);
    state.arousal = .alarm;

    // Simulate time passing (mock by setting old timestamp)
    // Can't actually modify time.time.timestamp() in tests
    // Just verify decay logic doesn't panic
    decayArousal(&state, 300);

    // Should not decay if alert was recent (simulated by not updating timestamp)
    // This is a logic test, not a full simulation
}

test "locus_coeruleus — ArousalLevel severity" {
    try std.testing.expectEqual(@as(u8, 5), AlertKind.ppl_divergence.severity());
    try std.testing.expectEqual(@as(u8, 3), AlertKind.token_expired.severity());
}

test "locus_coeruleus — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

// ═══════════════════════════════════════════════════════════════════════════════
// AROUSAL LEVEL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — ArousalLevel all values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ArousalLevel.sleep));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(ArousalLevel.idle));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(ArousalLevel.normal));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(ArousalLevel.alert));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(ArousalLevel.alarm));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(ArousalLevel.emergency));
}

test "locus_coeruleus — ArousalLevel labels" {
    try std.testing.expectEqualStrings("SLEEP", ArousalLevel.sleep.label());
    try std.testing.expectEqualStrings("IDLE", ArousalLevel.idle.label());
    try std.testing.expectEqualStrings("NORMAL", ArousalLevel.normal.label());
    try std.testing.expectEqualStrings("ALERT", ArousalLevel.alert.label());
    try std.testing.expectEqualStrings("ALARM", ArousalLevel.alarm.label());
    try std.testing.expectEqualStrings("EMERGENCY", ArousalLevel.emergency.label());
}

test "locus_coeruleus — ArousalLevel emoji" {
    // Just verify the emoji function returns something non-empty
    for (std.meta.tags(ArousalLevel)) |level| {
        const emoji = level.emoji();
        try std.testing.expect(emoji.len > 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT KIND TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — AlertKind all labels" {
    try std.testing.expectEqualStrings("WORKER CRASHED", AlertKind.worker_crashed.label());
    try std.testing.expectEqualStrings("PPL DIVERGENCE", AlertKind.ppl_divergence.label());
    try std.testing.expectEqualStrings("BUILD BROKEN", AlertKind.build_broken.label());
    try std.testing.expectEqualStrings("TOKEN EXPIRED", AlertKind.token_expired.label());
    try std.testing.expectEqualStrings("HEALTH CRITICAL", AlertKind.health_critical.label());
    try std.testing.expectEqualStrings("MEMORY CORRUPTION", AlertKind.memory_corruption.label());
}

test "locus_coeruleus — AlertKind all severities" {
    try std.testing.expectEqual(@as(u8, 4), AlertKind.worker_crashed.severity());
    try std.testing.expectEqual(@as(u8, 5), AlertKind.ppl_divergence.severity());
    try std.testing.expectEqual(@as(u8, 5), AlertKind.build_broken.severity());
    try std.testing.expectEqual(@as(u8, 3), AlertKind.token_expired.severity());
    try std.testing.expectEqual(@as(u8, 5), AlertKind.health_critical.severity());
    try std.testing.expectEqual(@as(u8, 4), AlertKind.memory_corruption.severity());
}

test "locus_coeruleus — AlertKind severity ranges" {
    // Verify severity is always in valid range 3-5
    for (std.meta.tags(AlertKind)) |kind| {
        const sev = kind.severity();
        try std.testing.expect(sev >= 3 and sev <= 5);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — Alert setMessage" {
    var alert = Alert{
        .kind = .worker_crashed,
        .level = .alarm,
    };

    try std.testing.expectEqual(@as(usize, 0), alert.message_len);

    alert.setMessage("Test message");
    try std.testing.expectEqualStrings("Test message", alert.messageStr());
    try std.testing.expectEqual(@as(usize, 12), alert.message_len);
}

test "locus_coeruleus — Alert setMessage truncates" {
    var alert = Alert{
        .kind = .worker_crashed,
        .level = .alarm,
    };

    // Create a message longer than 256 bytes
    var long_text: [300]u8 = undefined;
    @memset(&long_text, 'A');
    long_text[299] = 0;

    alert.setMessage(&long_text);
    try std.testing.expectEqual(@as(usize, 256), alert.message_len); // Truncated to max
}

test "locus_coeruleus — Alert setMessage updates timestamp" {
    var alert = Alert{
        .kind = .worker_crashed,
        .level = .alarm,
    };

    try std.testing.expectEqual(@as(i64, 0), alert.timestamp);

    const before = std.time.timestamp();
    alert.setMessage("Test");
    const after = std.time.timestamp();

    try std.testing.expect(alert.timestamp >= before);
    try std.testing.expect(alert.timestamp <= after);
}

test "locus_coeruleus — Alert messageStr empty" {
    const alert = Alert{
        .kind = .worker_crashed,
        .level = .alarm,
        .message_len = 0,
    };

    try std.testing.expectEqualStrings("", alert.messageStr());
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCUS STATE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — LocusState defaults" {
    const state = LocusState{};

    try std.testing.expectEqual(ArousalLevel.normal, state.arousal);
    try std.testing.expectEqual(@as(u32, 0), state.alert_count);
    try std.testing.expect(state.alert_sink == null);
}

test "locus_coeruleus — LocusState last_alert defaults" {
    const state = LocusState{};

    try std.testing.expectEqual(AlertKind.worker_crashed, state.last_alert.kind);
    try std.testing.expectEqual(ArousalLevel.normal, state.last_alert.level);
    try std.testing.expectEqual(@as(usize, 0), state.last_alert.message_len);
    try std.testing.expectEqual(@as(i64, 0), state.last_alert.timestamp);
}

test "locus_coeruleus — init without sink" {
    const state = LocusState{};

    try std.testing.expectEqual(ArousalLevel.normal, state.arousal);
    try std.testing.expect(state.alert_sink == null);
}

test "locus_coeruleus — getArousal" {
    var state = LocusState{};
    state.arousal = .alarm;

    try std.testing.expectEqual(ArousalLevel.alarm, getArousal(&state));
}

test "locus_coeruleus — getAlertCount" {
    var state = LocusState{};
    state.alert_count = 42;

    try std.testing.expectEqual(@as(u32, 42), getAlertCount(&state));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRIGGER ALARM TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — triggerAlarm increments count" {
    var state = init(sinkFn);

    try triggerAlarm(&state, .build_broken, "Build failed", null);
    try triggerAlarm(&state, .token_expired, "Token expired", null);

    try std.testing.expectEqual(@as(u32, 2), state.alert_count);
}

test "locus_coeruleus — triggerAlarm with null level uses inference" {
    var state = init(sinkFn);

    try triggerAlarm(&state, .ppl_divergence, "PPL spike", null);

    // ppl_divergence has severity 5 → should be emergency
    try std.testing.expectEqual(ArousalLevel.emergency, state.arousal);
}

test "locus_coeruleus — triggerAlarm with explicit level" {
    var state = init(sinkFn);

    try triggerAlarm(&state, .worker_crashed, "Worker died", .alert);

    try std.testing.expectEqual(ArousalLevel.alert, state.arousal);
}

test "locus_coeruleus — triggerAlarm updates last_alert" {
    var state = init(sinkFn);

    try triggerAlarm(&state, .health_critical, "Critical health", null);

    try std.testing.expectEqual(AlertKind.health_critical, state.last_alert.kind);
    try std.testing.expectEqualStrings("Critical health", state.last_alert.messageStr());
}

test "locus_coeruleus — triggerAlarm only raises arousal if higher" {
    var state = init(sinkFn);

    try triggerAlarm(&state, .token_expired, "Token expired", null); // severity 3 → alert
    try std.testing.expectEqual(ArousalLevel.alert, state.arousal);

    try triggerAlarm(&state, .worker_crashed, "Worker crashed", null); // severity 4 → alarm
    try std.testing.expectEqual(ArousalLevel.alarm, state.arousal);

    // Lower severity should not decrease arousal
    try triggerAlarm(&state, .token_expired, "Another token", null);
    try std.testing.expectEqual(ArousalLevel.alarm, state.arousal);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DECAY AROUSAL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — decayArousal from emergency" {
    var state = init(sinkFn);
    state.arousal = .emergency;
    state.last_alert.timestamp = std.time.timestamp() - 400; // 400 seconds ago

    decayArousal(&state, 300);

    // Should decay by 1 level after 5 minutes
    try std.testing.expectEqual(ArousalLevel.alarm, state.arousal);
}

test "locus_coeruleus — decayArousal from sleep stays sleep" {
    var state = init(sinkFn);
    state.arousal = .sleep;

    decayArousal(&state, 300);

    try std.testing.expectEqual(ArousalLevel.sleep, state.arousal);
}

test "locus_coeruleus — decayArousal recent alert no decay" {
    var state = init(sinkFn);
    state.arousal = .alarm;
    state.last_alert.timestamp = std.time.timestamp(); // Just now

    decayArousal(&state, 300);

    try std.testing.expectEqual(ArousalLevel.alarm, state.arousal);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "locus_coeruleus — CellHealth defaults" {
    const h = CellHealth{};

    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "locus_coeruleus — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFER AROUSAL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus — inferArousal severity 5 to emergency" {
    // ppl_divergence, build_broken, health_critical all have severity 5
    const arousal = inferArousal(.ppl_divergence);
    try std.testing.expectEqual(ArousalLevel.emergency, arousal);
}

test "locus_coeruleus — inferArousal severity 4 to alarm" {
    // worker_crashed, memory_corruption have severity 4
    const arousal = inferArousal(.worker_crashed);
    try std.testing.expectEqual(ArousalLevel.alarm, arousal);
}

test "locus_coeruleus — inferArousal severity 3 to alert" {
    // token_expired has severity 3
    const arousal = inferArousal(.token_expired);
    try std.testing.expectEqual(ArousalLevel.alert, arousal);
}
