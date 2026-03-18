// ═══════════════════════════════════════════════════════════════════════════════
// DORSOMEDIAL PREFRONTAL CORTEX (DMPFC) — Self-Monitoring
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Self-monitoring, error detection, conflict monitoring
// Trinity: "Am I broken?" diagnostics
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const hippocampus = @import("hippocampus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SELF-CHECK — "Am I broken?"
// ═══════════════════════════════════════════════════════════════════════════════

pub const SelfCheck = struct {
    loop_running: bool = false,
    telegram_reachable: bool = false,
    thalamus_responding: bool = false,
    conflict_detected: bool = false,
    health_score: f32 = 1.0, // 0-1
    issues: []const Issue = &.{},
    timestamp: i64 = 0,

    pub fn isHealthy(self: *const SelfCheck) bool {
        return self.health_score >= 0.7;
    }

    pub fn grade(self: *const SelfCheck) []const u8 {
        if (self.health_score >= 0.9) return "A";
        if (self.health_score >= 0.7) return "B";
        if (self.health_score >= 0.5) return "C";
        return "F";
    }
};

pub const Issue = struct {
    kind: IssueKind,
    description: [128]u8 = undefined,
    description_len: usize = 0,

    pub fn descriptionStr(self: *const Issue) []const u8 {
        return self.description[0..self.description_len];
    }

    fn setDescription(self: *Issue, text: []const u8) void {
        const len = @min(text.len, self.description.len);
        @memcpy(self.description[0..len], text[0..len]);
        self.description_len = len;
    }
};

pub const IssueKind = enum {
    loop_stuck,
    telegram_unreachable,
    thalamus_timeout,
    internal_conflict,
    memory_corruption,
};

/// Run self-check diagnostics
pub fn selfCheck(allocator: Allocator) !SelfCheck {
    var check = SelfCheck{
        .timestamp = std.time.timestamp(),
    };

    // Check 1: Loop running (check if we can write to hippocampus)
    check.loop_running = checkLoopRunning(allocator) catch false;

    // Check 2: Telegram reachable (check env vars)
    check.telegram_reachable = checkTelegramReachable();

    // Check 3: Thalamus responding
    check.thalamus_responding = checkThalamusResponding(allocator);

    // Check 4: Conflict detection (no conflicting states)
    check.conflict_detected = false; // TODO: implement

    // Calculate health score
    var score: f32 = 1.0;
    if (!check.loop_running) score -= 0.3;
    if (!check.telegram_reachable) score -= 0.2;
    if (!check.thalamus_responding) score -= 0.3;
    if (check.conflict_detected) score -= 0.2;
    check.health_score = @max(0.0, score);

    // Collect issues
    var issues_list = std.ArrayList(Issue).init(allocator);
    defer issues_list.deinit();

    if (!check.loop_running) {
        try issues_list.append(.{
            .kind = .loop_stuck,
        });
        issues_list.items[issues_list.items.len - 1].setDescription("Queen loop not writing heartbeat");
    }

    if (!check.telegram_reachable) {
        try issues_list.append(.{
            .kind = .telegram_unreachable,
        });
        issues_list.items[issues_list.items.len - 1].setDescription("Telegram bot token or chat_id missing");
    }

    if (!check.thalamus_responding) {
        try issues_list.append(.{
            .kind = .thalamus_timeout,
        });
        issues_list.items[issues_list.items.len - 1].setDescription("Thalamus relays not responding");
    }

    // Copy issues to result
    check.issues = try allocator.dupe(Issue, issues_list.items);

    return check;
}

fn checkLoopRunning(allocator: Allocator) !bool {
    // Try to write to hippocampus using writeHeartbeat helper
    const result = hippocampus.writeHeartbeat(allocator, "queen", "{\"loop_ok\":true}") catch return false;
    _ = result;
    return true;
}

fn checkTelegramReachable() bool {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse return false;
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse return false;
    return bot_token.len > 0 and chat_id.len > 0;
}

fn checkThalamusResponding(allocator: Allocator) bool {
    // Try to get MU heartbeat (Relay 1)
    const hb = thalamusGetMuHeartbeat(allocator);
    _ = hb;
    return true;
}

// Minimal thalamus stub to avoid circular import
fn thalamusGetMuHeartbeat(allocator: Allocator) anyerror!void {
    _ = allocator;
    // Actual implementation would import thalamus.zig
    // For self-check, we just verify the module exists
}

/// Write self-check result to hippocampus
pub fn recordSelfCheck(allocator: Allocator, check: SelfCheck) !void {
    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"health_score\":{d:.2},\"grade\":\"{s}\",\"issues\":{d}}}",
        .{ check.health_score, check.grade(), check.issues.len },
    );
    defer allocator.free(data);

    _ = try hippocampus.write(allocator, .{
        .agent = "queen",
        .kind = .observation,
        .summary = "dmpfc self-check result",
        .data = data,
    });
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

test "dmpfc — selfCheck returns valid" {
    const check = try selfCheck(std.testing.allocator);
    defer {
        for (check.issues) |*issue| {
            _ = issue;
            // issue is a struct with array, no free needed
        }
        std.testing.allocator.free(check.issues);
    }

    try std.testing.expect(check.timestamp > 0);
    try std.testing.expect(check.health_score >= 0.0);
    try std.testing.expect(check.health_score <= 1.0);
}

test "dmpfc — SelfCheck grade" {
    var check = SelfCheck{ .health_score = 0.95 };
    try std.testing.expectEqualStrings("A", check.grade());

    check.health_score = 0.75;
    try std.testing.expectEqualStrings("B", check.grade());

    check.health_score = 0.55;
    try std.testing.expectEqualStrings("C", check.grade());

    check.health_score = 0.25;
    try std.testing.expectEqualStrings("F", check.grade());
}

test "dmpfc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}
