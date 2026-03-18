// ═══════════════════════════════════════════════════════════════════════════════
// ORBITOFRONTAL CORTEX (OFC) — Telegram Voice + Mood
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Emotional integration, reward expectation, social communication
// Trinity: Telegram voice — formatting reports, "mood" of system
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");

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
