// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN OFC (Orbitofrontal Cortex) — Unified Telegram Router
// ═══════════════════════════════════════════════════════════════════════════════
// S³AI Brain Module — Single entrypoint for ALL Telegram messages
// Neuro: Emotional integration, reward expectation, social communication
// Trinity: Telegram voice — ALL messages route through here
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");

// Import Locus Coeruleus for ArousalLevel
const locus_coeruleus = @import("phoenix_locus_coeruleus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT ROUTING — Where messages go
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChatRoute = enum {
    /// Personal DM (user: 144022504)
    personal,
    /// Main group chat (-5160767429) — DEFAULT for most messages
    group,
    /// Agent-specific channel (future)
    agent,
    /// Urgent alerts via Locus Coeruleus (group + pinned)
    alert,

    /// Get chat_id string for this route
    pub fn chatId(self: ChatRoute) []const u8 {
        return switch (self) {
            .personal => "144022504",
            .group => "-5160767429",
            .agent => "-5160767429", // Future: dedicated channels per agent
            .alert => "-5160767429", // Same as group, but pinned
        };
    }

    /// Emoji prefix for this route
    pub fn emoji(self: ChatRoute) []const u8 {
        return switch (self) {
            .personal => qt.E_HAND,
            .group => qt.E_CROWN,
            .agent => qt.E_ROBOT,
            .alert => qt.E_SIREN,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MOOD — System emotional state
// ═══════════════════════════════════════════════════════════════════════════════

pub const Mood = enum {
    calm, // Normal operation
    alert, // Stalled detected
    alarm, // Diverged/crashed
    euphoria, // PPL record!

    pub fn emoji(self: Mood) []const u8 {
        return switch (self) {
            .calm => qt.E_CHECK,
            .alert => qt.E_WRENCH,
            .alarm => qt.E_SIREN,
            .euphoria => qt.E_TROPHY,
        };
    }

    pub fn label(self: Mood) []const u8 {
        return switch (self) {
            .calm => "CALM",
            .alert => "ALERT",
            .alarm => "ALARM",
            .euphoria => "EUPHORIA",
        };
    }
};

/// Infer mood from system state (context-aware)
pub fn inferMood(build_ok: bool, ouroboros_score: f32, ppl_record: bool) Mood {
    if (!build_ok) return .alarm;
    if (ppl_record) return .euphoria;
    if (ouroboros_score < 40) return .alarm;
    if (ouroboros_score < 70) return .alert;
    return .calm;
}

/// Get mood label that explains actual state (human-readable)
pub fn moodLabelWithExplanation(mood: Mood, farm_active: u8, farm_total: u8) []const u8 {
    return switch (mood) {
        .calm => if (farm_active > 0)
            "Running smoothly"
        else if (farm_total > 0)
            "Farm idle"
        else
            "System normal",
        .alert => "Needs attention",
        .alarm => "Critical issue",
        .euphoria => "Great progress!",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPORT SECTIONS — Structured output for Telegram
// ═══════════════════════════════════════════════════════════════════════════════

pub const Section = struct {
    title: []const u8,
    content: []const u8,
    emoji: []const u8,
};

pub const Report = struct {
    mood: Mood = .calm,
    sections: []const Section = &.{},
    timestamp: i64 = 0,

    pub fn init(allocator: Allocator, m: Mood) Report {
        _ = allocator;
        return .{
            .mood = m,
            .timestamp = std.time.timestamp(),
        };
    }
};

/// Format status report for Telegram (human-readable)
pub fn formatStatusReport(
    allocator: Allocator,
    build_ok: bool,
    ouroboros_score: f32,
    farm_services: u8,
    best_ppl: f32,
) ![]const u8 {
    _ = ouroboros_score; // Not used in simplified version
    return formatStatusReportWithArousal(
        allocator,
        build_ok,
        0.0, // ouroboros_score placeholder
        farm_services,
        best_ppl,
        locus_coeruleus.ArousalLevel.normal,
    );
}

/// Format status report with arousal-aware tone
pub fn formatStatusReportWithArousal(
    allocator: Allocator,
    build_ok: bool,
    ouroboros_score: f32,
    farm_services: u8,
    best_ppl: f32,
    arousal: locus_coeruleus.ArousalLevel,
) ![]const u8 {
    _ = ouroboros_score; // Use mood inference for now

    // Build report inline (no allocator needed for static buffer)
    var buf: [2048]u8 = undefined;
    var offset: usize = 0;

    // Header with arousal-based tone
    const header = getArousalHeader(arousal);
    const header_len = @min(header.len, buf.len);
    @memcpy(buf[0..header_len], header);
    offset = header_len;

    // Build status
    const build_line = std.fmt.bufPrint(
        buf[offset..],
        "\n{s} Build: {s}",
        .{ if (build_ok) qt.E_CHECK else qt.E_CROSS, if (build_ok) "OK" else "FAIL" },
    ) catch return error.BufferTooSmall;
    offset += build_line.len;

    // Farm (human-readable)
    const farm_line = std.fmt.bufPrint(
        buf[offset..],
        "\n{s} {s}",
        .{ qt.E_DNA, formatFarmStatusHuman(farm_services, best_ppl) },
    ) catch return error.BufferTooSmall;
    offset += farm_line.len;

    // Add action guidance based on arousal
    const guidance = getArousalGuidance(arousal);
    if (guidance.len > 0) {
        const guidance_line = std.fmt.bufPrint(
            buf[offset..],
            "\n\n{s}",
            .{guidance},
        ) catch return error.BufferTooSmall;
        offset += guidance_line.len;
    }

    // Allocate and copy
    const result = try allocator.alloc(u8, offset);
    @memcpy(result, buf[0..offset]);
    return result;
}

/// Get header based on arousal level
fn getArousalHeader(arousal: locus_coeruleus.ArousalLevel) []const u8 {
    return switch (arousal) {
        .emergency => "\xf0\x9f\x94\xa5" ++ " CRITICAL - IMMEDIATE ACTION REQUIRED\n\n", // 🔥
        .alarm => "\xf0\x9f\x9a\xa8" ++ " ALERT - Needs attention\n\n", // 🚨
        .alert => "\xe2\x9a\xa0\xef\xb8\x8f" ++ " Warning - Check needed\n\n", // ⚠️
        .normal => "\xf0\x9f\xa7\xa0" ++ " Queen Status Briefing\n\n", // 🧠
        .idle => "\xe2\x8f\xb1" ++ " Queen Status Update\n\n", // ⏱
        .sleep => "\xf0\x9f\x8c\x99" ++ " Queen Dormant\n\n", // 🌙
    };
}

/// Get action guidance based on arousal
fn getArousalGuidance(arousal: locus_coeruleus.ArousalLevel) []const u8 {
    return switch (arousal) {
        .emergency => "\xe2\x9d\x8c" ++ " Critical failure detected. Manual intervention required.", // ❌
        .alarm => "\xf0\x9f\x94\xa7" ++ " Multiple issues detected. Auto-recovery in progress.", // 🔧
        .alert => "\xf0\x9f\x94\x8d" ++ " Some issues detected. Monitoring.", // 🔍
        else => "", // No guidance needed
    };
}

/// Format farm status in human-readable way
fn formatFarmStatusHuman(services: u8, ppl: f32) []const u8 {
    if (services == 0) {
        if (ppl < 999.0) {
            return "Farm idle. Last training complete.";
        }
        return "Farm offline. No workers running.";
    }
    if (ppl < 3.0) {
        return "Training running well! Excellent PPL.";
    }
    if (ppl < 10.0) {
        return "Training in progress.";
    }
    return "Training running.";
}

/// Format alert for Telegram (urgent notification)
pub fn formatAlert(
    allocator: Allocator,
    kind: AlertKind,
    detail: []const u8,
) ![]const u8 {
    const icon = switch (kind) {
        .build_broken => qt.E_SIREN,
        .ppl_record => qt.E_TROPHY,
        .worker_stalled => qt.E_TIMER,
        .worker_crashed => qt.E_COFFIN,
    };

    const label = switch (kind) {
        .build_broken => "BUILD BROKEN",
        .ppl_record => "NEW PPL RECORD",
        .worker_stalled => "WORKER STALLED",
        .worker_crashed => "WORKER CRASHED",
    };

    return std.fmt.allocPrint(
        allocator,
        "{s} {s}\n\n{s}\n",
        .{ icon, label, detail },
    );
}

pub const AlertKind = enum {
    build_broken,
    ppl_record,
    worker_stalled,
    worker_crashed,
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED SEND — Single entrypoint for ALL Telegram messages
// ═══════════════════════════════════════════════════════════════════════════════

/// Send message to specified chat route
pub fn send(allocator: Allocator, route: ChatRoute, message: []const u8) !void {
    const tg = qt.initTelegram();
    if (!tg.enabled) return error.TelegramDisabled;

    // Use route's chat_id instead of env var
    const chat_id = route.chatId();
    try sendRaw(allocator, tg.bot_token, chat_id, message);
}

/// Send formatted report with mood-based routing
pub fn sendReport(allocator: Allocator, mood: Mood, report: []const u8) !void {
    // Route based on mood urgency
    const route: ChatRoute = switch (mood) {
        .euphoria, .alarm, .alert => .alert, // Pin important stuff
        .calm => .group,
    };

    const formatted = try std.fmt.allocPrint(allocator, "{s} {s}\n\n{s}", .{
        mood.emoji(),
        mood.label(),
        report,
    });
    defer allocator.free(formatted);

    try send(allocator, route, formatted);
}

/// Send alert (always to alert route)
pub fn sendAlert(allocator: Allocator, kind: qt.AlertKind, detail: []const u8) !void {
    const formatted = try std.fmt.allocPrint(allocator, "{s} {s}: {s}", .{
        kind.emoji(),
        kind.labelRu(),
        detail,
    });
    defer allocator.free(formatted);

    try send(allocator, .alert, formatted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOW-LEVEL TELEGRAM CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

fn sendRaw(allocator: Allocator, bot_token: []const u8, chat_id: []const u8, text: []const u8) !void {
    var url_buf: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{bot_token});

    var body_buf: [8192]u8 = undefined;
    const body = try buildBody(&body_buf, chat_id, text);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    var req = try client.request(.POST, uri, .{
        .extra_headers = &.{.{
            .name = "Content-Type",
            .value = "application/json",
        }},
        .redirect_behavior = .unhandled,
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer_req = try req.sendBodyUnflushed(&.{});
    try body_writer_req.writer.writeAll(body);
    try body_writer_req.end();
    if (req.connection) |conn| try conn.flush();

    var redirect_buf: [0]u8 = .{};
    const response = try req.receiveHead(&redirect_buf);

    const status_code = @intFromEnum(response.head.status);
    if (status_code != 200) {
        std.debug.print("\x1b[38;2;255;85;85mOFC Telegram API error: {d}\x1b[0m\n", .{status_code});
        return error.TelegramError;
    }
}

fn buildBody(buf: []u8, chat_id: []const u8, text: []const u8) ![]const u8 {
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(buf[i..][0..prefix.len], prefix);
    i += prefix.len;

    @memcpy(buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    const mid = "\",\"parse_mode\":\"HTML\",\"text\":\"";
    @memcpy(buf[i..][0..mid.len], mid);
    i += mid.len;

    // JSON escape + HTML escape combined
    for (text) |c| {
        if (i + 6 > buf.len - 4) return error.BodyTooLarge;
        switch (c) {
            '"' => {
                @memcpy(buf[i..][0..2], "\\\"");
                i += 2;
            },
            '\\' => {
                @memcpy(buf[i..][0..2], "\\\\");
                i += 2;
            },
            '\n' => {
                @memcpy(buf[i..][0..2], "\\n");
                i += 2;
            },
            '<' => {
                @memcpy(buf[i..][0..4], "&lt;");
                i += 4;
            },
            '>' => {
                @memcpy(buf[i..][0..4], "&gt;");
                i += 4;
            },
            '&' => {
                @memcpy(buf[i..][0..5], "&amp;");
                i += 5;
            },
            else => {
                buf[i] = c;
                i += 1;
            },
        }
    }

    @memcpy(buf[i..][0..2], "\"}");
    i += 2;

    return buf[0..i];
}

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD PREDICTION — Orbitofrontal Cortex core function
// ═══════════════════════════════════════════════════════════════════════════════

/// Reward prediction model with adaptive learning rate
pub const RewardPrediction = struct {
    /// Expected reward value (0-100)
    expected: f32 = 50.0,
    /// Learning rate for prediction updates (0-1)
    learning_rate: f32 = 0.1,
    /// Confidence in prediction (0-1)
    confidence: f32 = 0.5,
    /// Total number of predictions made
    prediction_count: u32 = 0,
    /// Cumulative prediction error
    total_error: f32 = 0.0,

    /// Initialize a new reward prediction model
    pub fn init(initial_expected: f32) RewardPrediction {
        return .{
            .expected = std.math.clamp(initial_expected, 0.0, 100.0),
        };
    }

    /// Predict reward for a given action/state
    pub fn predictReward(self: *const RewardPrediction) f32 {
        return self.expected;
    }

    /// Compare expected vs actual reward, return prediction error
    pub fn compareExpectedVsActual(self: *const RewardPrediction, actual: f32) PredictionError {
        const error_val = actual - self.expected;
        const abs_error = if (error_val < 0) -error_val else error_val;

        return .{
            .expected = self.expected,
            .actual = actual,
            .error_value = error_val,
            .absolute_error = abs_error,
            .is_accurate = abs_error < 10.0, // Within 10% = accurate
        };
    }

    /// Update prediction model based on actual reward
    pub fn updatePredictionModel(self: *RewardPrediction, actual: f32) void {
        const error_val = actual - self.expected;

        // Update expected value using learning rate
        self.expected += self.learning_rate * error_val;
        self.expected = std.math.clamp(self.expected, 0.0, 100.0);

        // Update confidence based on accuracy
        const abs_error = if (error_val < 0) -error_val else error_val;
        if (abs_error < 10.0) {
            // Increase confidence on accurate predictions
            self.confidence += 0.05 * (1.0 - self.confidence);
        } else {
            // Decrease confidence on inaccurate predictions
            self.confidence *= 0.9;
        }
        self.confidence = std.math.clamp(self.confidence, 0.0, 1.0);

        // Track statistics
        self.prediction_count += 1;
        self.total_error += abs_error;
    }

    /// Get mean absolute error across all predictions
    pub fn meanAbsoluteError(self: *const RewardPrediction) f32 {
        if (self.prediction_count == 0) return 0.0;
        return self.total_error / @as(f32, @floatFromInt(self.prediction_count));
    }
};

/// Result of comparing expected vs actual reward
pub const PredictionError = struct {
    expected: f32,
    actual: f32,
    error_value: f32, // signed error (actual - expected)
    absolute_error: f32,
    is_accurate: bool,
};

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

test "ofc — inferMood calm" {
    const mood = inferMood(true, 75, false);
    try std.testing.expectEqual(Mood.calm, mood);
}

test "ofc — inferMood alarm" {
    const mood = inferMood(false, 50, false);
    try std.testing.expectEqual(Mood.alarm, mood);
}

test "ofc — inferMood euphoria" {
    const mood = inferMood(true, 70, true);
    try std.testing.expectEqual(Mood.euphoria, mood);
}

test "ofc — formatStatusReport" {
    const report = try formatStatusReport(std.testing.allocator, true, 72.5, 8, 4.6);
    defer std.testing.allocator.free(report);

    try std.testing.expect(report.len > 0);
    // New format uses human-readable messages like "Training in progress" instead of "CALM"
    try std.testing.expect(std.mem.indexOf(u8, report, "Training") != null or
        std.mem.indexOf(u8, report, "smoothly") != null);
}

test "ofc — formatAlert" {
    const alert = try formatAlert(std.testing.allocator, .build_broken, "src/vsa.zig:123");
    defer std.testing.allocator.free(alert);

    try std.testing.expect(std.mem.indexOf(u8, alert, "BUILD BROKEN") != null);
}

test "ofc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "ofc — ChatRoute chat_id" {
    try std.testing.expectEqualStrings("144022504", ChatRoute.personal.chatId());
    try std.testing.expectEqualStrings("-5160767429", ChatRoute.group.chatId());
    try std.testing.expectEqualStrings("-5160767429", ChatRoute.alert.chatId());
}

test "ofc — ChatRoute emoji" {
    try std.testing.expectEqual(qt.E_HAND, ChatRoute.personal.emoji());
    try std.testing.expectEqual(qt.E_CROWN, ChatRoute.group.emoji());
    try std.testing.expectEqual(qt.E_SIREN, ChatRoute.alert.emoji());
}

test "ofc — buildBody JSON escape" {
    var buf: [512]u8 = undefined;
    const body = try buildBody(&buf, "123", "hello\"world");
    try std.testing.expect(std.mem.indexOf(u8, body, "\\\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "chat_id") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD PREDICTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ofc — RewardPrediction init" {
    const rp = RewardPrediction.init(75.0);
    try std.testing.expectEqual(75.0, rp.expected);
    try std.testing.expectEqual(0.1, rp.learning_rate);
    try std.testing.expectEqual(0, rp.prediction_count);
}

test "ofc — RewardPrediction init clamps to 100" {
    const rp = RewardPrediction.init(150.0);
    try std.testing.expectEqual(100.0, rp.expected);
}

test "ofc — RewardPrediction init clamps to 0" {
    const rp = RewardPrediction.init(-50.0);
    try std.testing.expectEqual(0.0, rp.expected);
}

test "ofc — predictReward returns expected value" {
    var rp = RewardPrediction.init(42.0);
    const prediction = rp.predictReward();
    try std.testing.expectEqual(42.0, prediction);
}

test "ofc — compareExpectedVsActual positive error" {
    var rp = RewardPrediction.init(50.0);
    const result = rp.compareExpectedVsActual(70.0);

    try std.testing.expectEqual(50.0, result.expected);
    try std.testing.expectEqual(70.0, result.actual);
    try std.testing.expectEqual(20.0, result.error_value);
    try std.testing.expectEqual(20.0, result.absolute_error);
    try std.testing.expect(!result.is_accurate); // 20 > 10 threshold
}

test "ofc — compareExpectedVsActual negative error" {
    var rp = RewardPrediction.init(50.0);
    const result = rp.compareExpectedVsActual(30.0);

    try std.testing.expectEqual(50.0, result.expected);
    try std.testing.expectEqual(30.0, result.actual);
    try std.testing.expectEqual(-20.0, result.error_value);
    try std.testing.expectEqual(20.0, result.absolute_error);
    try std.testing.expect(!result.is_accurate);
}

test "ofc — compareExpectedVsActual accurate" {
    var rp = RewardPrediction.init(50.0);
    const result = rp.compareExpectedVsActual(55.0);

    try std.testing.expectEqual(50.0, result.expected);
    try std.testing.expectEqual(55.0, result.actual);
    try std.testing.expectEqual(5.0, result.error_value);
    try std.testing.expectEqual(5.0, result.absolute_error);
    try std.testing.expect(result.is_accurate); // 5 < 10 threshold
}

test "ofc — updatePredictionModel increases expected on positive error" {
    var rp = RewardPrediction.init(50.0);
    rp.updatePredictionModel(70.0);

    // expected = 50 + 0.1 * (70 - 50) = 50 + 2 = 52
    try std.testing.expectEqual(52.0, rp.expected);
    try std.testing.expectEqual(1, rp.prediction_count);
}

test "ofc — updatePredictionModel decreases expected on negative error" {
    var rp = RewardPrediction.init(50.0);
    rp.updatePredictionModel(30.0);

    // expected = 50 + 0.1 * (30 - 50) = 50 - 2 = 48
    try std.testing.expectEqual(48.0, rp.expected);
}

test "ofc — updatePredictionModel increases confidence on accuracy" {
    var rp = RewardPrediction{ .expected = 50.0, .confidence = 0.5 };
    rp.updatePredictionModel(55.0); // Small error = accurate

    try std.testing.expect(rp.confidence > 0.5);
}

test "ofc — updatePredictionModel decreases confidence on inaccuracy" {
    var rp = RewardPrediction{ .expected = 50.0, .confidence = 0.8 };
    rp.updatePredictionModel(80.0); // Large error = inaccurate

    try std.testing.expect(rp.confidence < 0.8);
}

test "ofc — updatePredictionModel clamps expected to 100" {
    var rp = RewardPrediction.init(95.0);
    rp.updatePredictionModel(200.0);

    try std.testing.expectEqual(100.0, rp.expected);
}

test "ofc — updatePredictionModel clamps expected to 0" {
    var rp = RewardPrediction.init(5.0);
    rp.updatePredictionModel(-100.0);

    try std.testing.expectEqual(0.0, rp.expected);
}

test "ofc — meanAbsoluteError calculates correctly" {
    var rp = RewardPrediction.init(50.0);
    rp.updatePredictionModel(60.0);
    rp.updatePredictionModel(40.0);
    rp.updatePredictionModel(45.0);

    const mae = rp.meanAbsoluteError();
    // MAE should be positive and reasonable (between 0 and 100)
    try std.testing.expect(mae > 0.0);
    try std.testing.expect(mae < 100.0);
    // With 3 updates, total_error > 0
    try std.testing.expect(rp.total_error > 0.0);
    try std.testing.expectEqual(3, rp.prediction_count);
}

test "ofc — meanAbsoluteError zero when no predictions" {
    const rp = RewardPrediction.init(50.0);
    try std.testing.expectEqual(0.0, rp.meanAbsoluteError());
}

test "ofc — Mood all values" {
    const moods = [_]Mood{ .calm, .alert, .alarm, .euphoria };
    for (moods) |m| {
        _ = m; // Verify all enum values exist
    }
}

test "ofc — Mood emoji all values" {
    try std.testing.expectEqual(qt.E_CHECK, Mood.calm.emoji());
    try std.testing.expectEqual(qt.E_WRENCH, Mood.alert.emoji());
    try std.testing.expectEqual(qt.E_SIREN, Mood.alarm.emoji());
    try std.testing.expectEqual(qt.E_TROPHY, Mood.euphoria.emoji());
}

test "ofc — Mood label all values" {
    try std.testing.expectEqualStrings("CALM", Mood.calm.label());
    try std.testing.expectEqualStrings("ALERT", Mood.alert.label());
    try std.testing.expectEqualStrings("ALARM", Mood.alarm.label());
    try std.testing.expectEqualStrings("EUPHORIA", Mood.euphoria.label());
}

test "ofc — inferMood alert threshold" {
    // Low ouroboros score but build OK
    const mood = inferMood(true, 60, false);
    try std.testing.expectEqual(Mood.alert, mood);
}

test "ofc — inferMood calm threshold" {
    // High ouroboros score, build OK, no PPL record
    const mood = inferMood(true, 85, false);
    try std.testing.expectEqual(Mood.calm, mood);
}

test "ofc — ChatRoute agent emoji" {
    try std.testing.expectEqual(qt.E_ROBOT, ChatRoute.agent.emoji());
}

test "ofc — ChatRoute agent chatId" {
    try std.testing.expectEqualStrings("-5160767429", ChatRoute.agent.chatId());
}

test "ofc — moodLabelWithExplanation calm" {
    const label = moodLabelWithExplanation(.calm, 10, 15);
    try std.testing.expect(label.len > 0);
}

test "ofc — moodLabelWithExplanation alarm" {
    const label = moodLabelWithExplanation(.alarm, 0, 15);
    try std.testing.expect(label.len > 0);
}

test "ofc — moodLabelWithExplanation euphoria" {
    const label = moodLabelWithExplanation(.euphoria, 15, 15);
    try std.testing.expect(label.len > 0);
}

test "ofc — RewardPrediction initialization" {
    const rp = RewardPrediction.init(42.0);
    try std.testing.expectEqual(@as(f32, 42.0), rp.predictReward());
}

test "ofc — RewardPrediction predictReward" {
    const rp = RewardPrediction.init(50.0);
    const prediction = rp.predictReward();
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), prediction, 0.01);
}

test "ofc — RewardPrediction compareExpectedVsActual" {
    const rp = RewardPrediction.init(50.0);
    const pred_err = rp.compareExpectedVsActual(60.0);
    try std.testing.expect(pred_err.actual == 60.0);
}

test "ofc — PredictionError fields" {
    const pred_err = PredictionError{
        .expected = 50.0,
        .actual = 60.0,
        .error_value = 10.0,
        .absolute_error = 10.0,
        .is_accurate = false,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), pred_err.expected, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), pred_err.actual, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pred_err.error_value, 0.01);
    try std.testing.expect(!pred_err.is_accurate);
}

test "ofc — CellHealth struct" {
    const cell_h = CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = 12345,
    };
    try std.testing.expectEqual(CellHealth.Status.healthy, cell_h.status);
    try std.testing.expectEqual(@as(u32, 0), cell_h.cycle);
    try std.testing.expectEqual(@as(i64, 12345), cell_h.last_check);
}
