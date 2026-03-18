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
            .agent => "-5160767429", // TODO: agent-specific channels
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

/// Infer mood from system state
pub fn inferMood(build_ok: bool, ouroboros_score: f32, ppl_record: bool) Mood {
    if (!build_ok) return .alarm;
    if (ppl_record) return .euphoria;
    if (ouroboros_score < 40) return .alarm;
    if (ouroboros_score < 70) return .alert;
    return .calm;
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

/// Format status report for Telegram
pub fn formatStatusReport(
    allocator: Allocator,
    build_ok: bool,
    ouroboros_score: f32,
    farm_services: u8,
    best_ppl: f32,
) ![]const u8 {
    const mood = inferMood(build_ok, ouroboros_score, false);

    // Build report inline (no allocator needed for static buffer)
    var buf: [1024]u8 = undefined;
    var offset: usize = 0;

    // Header
    const header = std.fmt.bufPrint(
        buf[offset..],
        "{s} Queen {s} — {s}\n\n",
        .{ mood.emoji(), mood.label(), qt.E_CROWN },
    ) catch return error.BufferTooSmall;
    offset += header.len;

    // Build status
    const build_line = std.fmt.bufPrint(
        buf[offset..],
        "{s} Build: {s}\n",
        .{ if (build_ok) qt.E_CHECK else qt.E_CROSS, if (build_ok) "OK" else "FAIL" },
    ) catch return error.BufferTooSmall;
    offset += build_line.len;

    // Ouroboros
    const ouro_line = std.fmt.bufPrint(
        buf[offset..],
        "{s} Ouroboros: {d:.1}\n",
        .{ qt.E_CYCLE, ouroboros_score },
    ) catch return error.BufferTooSmall;
    offset += ouro_line.len;

    // Farm
    const farm_line = std.fmt.bufPrint(
        buf[offset..],
        "{s} Farm: {d} srv, PPL {d:.1}\n",
        .{ qt.E_DNA, farm_services, best_ppl },
    ) catch return error.BufferTooSmall;
    offset += farm_line.len;

    // Allocate and copy
    const result = try allocator.alloc(u8, offset);
    @memcpy(result, buf[0..offset]);
    return result;
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
    try std.testing.expect(std.mem.indexOf(u8, report, "CALM") != null);
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
