// @origin(spec:farm_telegram.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// FARM TELEGRAM — Stream Farm Progress to Group Chat
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sends Telegram notifications for farm task execution.
// Reuses runNotifyCommand() from tri_commands.zig.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const issue_planner = @import("issue_planner.zig");
const FarmTask = issue_planner.FarmTask;

/// Notify Telegram when a farm task starts
pub fn notifyTaskStart(allocator: Allocator, task: FarmTask) !void {
    const emoji = getEmoji(task.objective);

    const priority_icon = if (task.priority == 1) "🔴" else if (task.priority == 2) "🟡" else if (task.priority == 3) "🟢" else "⚪";

    const message = try std.fmt.allocPrint(allocator,
        \\{s} {s}FARM #{d}: {s}
        \\{s}📊 Objective: {s} ×{d}
        \\📐 Context: {d} | Schedule: {s}
        \\{s}⏳ Status: starting...
        \\
    , .{
        emoji,
        priority_icon,
        task.issue_number,
        task.issue_title,
        if (task.sacred) "✨ SACRED" else "",
        task.objective,
        task.count,
        task.context,
        task.lr_schedule,
        if (task.sacred) "✨" else "🔄",
    });
    defer allocator.free(message);

    try sendNotification(allocator, message);
}

/// Notify Telegram with injection progress
pub fn notifyTaskProgress(allocator: Allocator, task: FarmTask, injected: u32, total: u32) !void {
    if (injected == 0) return; // Don't notify on failure

    const emoji = getEmoji(task.objective);

    const message = try std.fmt.allocPrint(allocator,
        \\{s} ✅ FARM #{d}: {d}/{d} {s} workers injected
        \\   Context: {d} | Schedule: {s}
        \\
    , .{
        emoji,
        task.issue_number,
        injected,
        total,
        task.objective,
        task.context,
        task.lr_schedule,
    });
    defer allocator.free(message);

    try sendNotification(allocator, message);
}

/// Notify Telegram when a task completes
pub fn notifyTaskComplete(allocator: Allocator, task: FarmTask, success: bool, error_msg: ?[]const u8) !void {
    const status_icon = if (success) "✅" else "❌";
    const status_text = if (success) "complete" else "failed";

    var message_buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&message_buf);
    const writer = fbs.writer();

    writer.print(
        \\{s} FARM #{d}: {s}
        \\   Status: {s}
        \\
    , .{ status_icon, task.issue_number, task.issue_title, status_text }) catch return;

    if (error_msg) |err| {
        writer.print("   Error: {s}\n", .{err}) catch return;
    }

    const message = try allocator.dupe(u8, fbs.getWritten());
    defer allocator.free(message);

    try sendNotification(allocator, message);
}

/// Send notification via Telegram Bot API
fn sendNotification(allocator: Allocator, message: []const u8) !void {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse return error.NoBotToken;
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse return error.NoChatId;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{bot_token}) catch return error.InvalidUrl;

    // Build JSON body
    var body_buf: [8192]u8 = undefined;
    var body_fbs = std.io.fixedBufferStream(&body_buf);
    const body_writer = body_fbs.writer();

    // Start JSON
    body_writer.writeAll("{\"chat_id\":\"") catch return error.BodyTooLarge;
    body_writer.writeAll(chat_id) catch return error.BodyTooLarge;
    body_writer.writeAll("\",\"parse_mode\":\"HTML\",\"text\":\"") catch return error.BodyTooLarge;

    // Escape message
    for (message) |c| {
        switch (c) {
            '"' => body_writer.writeAll("\\\"") catch return error.BodyTooLarge,
            '\\' => body_writer.writeAll("\\\\") catch return error.BodyTooLarge,
            '\n' => body_writer.writeAll("\\n") catch return error.BodyTooLarge,
            '<' => body_writer.writeAll("&lt;") catch return error.BodyTooLarge,
            '>' => body_writer.writeAll("&gt;") catch return error.BodyTooLarge,
            '&' => body_writer.writeAll("&amp;") catch return error.BodyTooLarge,
            else => body_writer.writeByte(c) catch return error.BodyTooLarge,
        }
    }

    body_writer.writeAll("\"}") catch return error.BodyTooLarge;

    const body_written = body_fbs.getWritten();
    const body = body_buf[0..body_written.len];

    const uri = std.Uri.parse(url) catch return error.InvalidUrl;
    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .redirect_behavior = .unhandled,
    }) catch return error.RequestFailed;

    try req.sendBodyComplete(body);
}

/// Get emoji for objective type
fn getEmoji(objective: []const u8) []const u8 {
    if (std.mem.eql(u8, objective, "ntp")) return "🧠";
    if (std.mem.eql(u8, objective, "nca")) return "🔗";
    if (std.mem.eql(u8, objective, "jepa")) return "🎬";
    if (std.mem.eql(u8, objective, "hybrid")) return "🔮";
    return "🚜";
}
