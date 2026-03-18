// telegram_card.zig — Per-agent Telegram card with edit-in-place UX
// Creates ONE message on init, then edits it on every step change.
// Timeline accumulates inside the card. Zero spam.
const std = @import("std");
const telegram = @import("telegram.zig");

pub const TelegramCard = struct {
    config: telegram.TelegramConfig,
    msg_id: ?i64 = null,
    issue: u32,
    title: []const u8,
    timeline: std.ArrayList(u8),
    start_time: i64,
    step: u8 = 0,
    total_steps: u8 = 8,
    final_status: ?[]const u8 = null,
    pr_url: ?[]const u8 = null,

    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        config: telegram.TelegramConfig,
        issue: u32,
        title: []const u8,
    ) TelegramCard {
        return .{
            .config = config,
            .issue = issue,
            .title = title,
            .timeline = .empty,
            .allocator = allocator,
            .start_time = @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_s)),
        };
    }

    pub fn deinit(self: *TelegramCard) void {
        self.timeline.deinit(self.allocator);
    }

    /// Send the initial card message and capture msg_id for future edits.
    pub fn sendInitial(self: *TelegramCard) void {
        self.appendTimelineEntry("\xf0\x9f\x8c\x85 Awake") catch return;
        var buf: [2048]u8 = undefined;
        const card = self.buildCard(&buf) orelse return;
        self.msg_id = telegram.sendAndCapture(self.config, card);
    }

    /// Append a step to the timeline and edit the card.
    pub fn appendStep(self: *TelegramCard, text: []const u8) void {
        self.step += 1;
        self.appendTimelineEntry(text) catch return;
        self.editCard();
    }

    /// Refresh the card without advancing step (for periodic 30s updates).
    pub fn refresh(self: *TelegramCard) void {
        self.editCard();
    }

    /// Final edit: mark card as done with result.
    pub fn finalize(self: *TelegramCard, status: []const u8, pr_url: ?[]const u8) void {
        self.final_status = status;
        self.pr_url = pr_url;
        self.step = self.total_steps;
        self.appendTimelineEntry(status) catch return;
        self.editCard();
    }

    /// Send a NEW message with issue summary (Level 3 — only at completion).
    pub fn sendIssueSummary(
        self: *TelegramCard,
        diff_stats: []const u8,
        test_result: []const u8,
        pr_url: ?[]const u8,
    ) void {
        var buf: [2048]u8 = undefined;
        const elapsed = self.elapsedSecs();
        const mins = @divTrunc(elapsed, 60);
        const secs = @mod(elapsed, 60);

        const msg = std.fmt.bufPrint(&buf,
            \\{s} #{d} \xe2\x80\x94 {s}
            \\\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81
            \\{s}
            \\{s}
            \\{s}
            \\\xe2\x8f\xb1 {d}m{d:0>2}s
        , .{
            if (self.final_status != null) "\xe2\x9c\x85" else "\xe2\x9d\x8c",
            self.issue,
            self.title,
            diff_stats,
            test_result,
            if (pr_url) |u| u else "no PR",
            mins,
            secs,
        }) catch return;

        telegram.send(self.config, msg);
    }

    // ── internal ──

    fn editCard(self: *TelegramCard) void {
        if (self.msg_id) |mid| {
            var buf: [2048]u8 = undefined;
            const card = self.buildCard(&buf) orelse return;
            telegram.editMessage(self.config, mid, card);
        }
    }

    fn appendTimelineEntry(self: *TelegramCard, text: []const u8) !void {
        const elapsed = self.elapsedSecs();
        const mins: u64 = @intCast(@divTrunc(elapsed, 60));
        const secs: u64 = @intCast(@mod(elapsed, 60));

        const writer = self.timeline.writer(self.allocator);
        try writer.print("{d:0>2}:{d:0>2} {s}\n", .{ mins, secs, text });
    }

    fn buildCard(self: *TelegramCard, buf: []u8) ?[]const u8 {
        const elapsed = self.elapsedSecs();
        const mins: u64 = @intCast(@divTrunc(elapsed, 60));
        const secs: u64 = @intCast(@mod(elapsed, 60));

        // Simple ASCII progress bar
        var pbar: [8]u8 = undefined;
        for (&pbar, 0..) |*p, j| {
            p.* = if (j < self.step) '#' else '.';
        }

        const timeline_slice = self.timeline.items;

        return std.fmt.bufPrint(buf,
            \\\xf0\x9f\x94\xa7 #{d} \xe2\x80\x94 {s}
            \\\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81
            \\{s}
            \\\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81
            \\[{s}] {d}/{d}
            \\\xe2\x8f\xb1 {d}m{d:0>2}s
        , .{
            self.issue,
            self.title,
            timeline_slice,
            &pbar,
            self.step,
            self.total_steps,
            mins,
            secs,
        }) catch null;
    }

    fn elapsedSecs(self: *const TelegramCard) i64 {
        const now: i64 = @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_s));
        return now - self.start_time;
    }
};

test "TelegramCard init and timeline" {
    const allocator = std.testing.allocator;
    const config = telegram.TelegramConfig{ .bot_token = "", .chat_id = "", .enabled = false };
    var card = TelegramCard.init(allocator, config, 315, "test issue");
    defer card.deinit();

    // Disabled config — sendInitial is a no-op but timeline still works
    card.sendInitial();
    try std.testing.expect(card.timeline.items.len > 0);

    card.appendStep("Auth OK");
    try std.testing.expectEqual(@as(u8, 1), card.step);
}
