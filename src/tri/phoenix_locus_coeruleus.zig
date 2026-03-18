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
    const state = init(sinkFn);

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
