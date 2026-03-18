//! Telegram Reporter - Send notifications via OpenClaw
//! Reports gate results, commits, circuit breaker state changes

const std = @import("std");
const Allocator = std.mem.Allocator;
const process = @import("process.zig");

pub const TelegramConfig = struct {
    enabled: bool,
    chat_id: []const u8,
    openclaw_bin: []const u8,
};

pub const Event = enum {
    loop_start,
    loop_end,
    gate_pass,
    gate_fail,
    commit,
    circuit_open,
    circuit_close,
    verdict,
    status,
};

pub const EventContext = struct {
    branch: []const u8 = "",
    sha: []const u8 = "",
    commit_message: []const u8 = "",
    gate_name: []const u8 = "",
    loop_number: u32 = 0,
    verdict_score: i32 = 0,
};

/// Send Telegram notification via OpenClaw
/// Gracefully degrades if OpenClaw is unavailable
pub fn send(allocator: Allocator, config: TelegramConfig, event: Event, ctx: EventContext) !void {
    if (!config.enabled) return;

    const message = try formatMessage(allocator, event, ctx);
    defer allocator.free(message);

    const emoji = getEmoji(event);
    const full_message = try std.fmt.allocPrint(allocator, "{s} {s}", .{ emoji, message });
    defer allocator.free(full_message);

    // Build OpenClaw command
    const args = &[_][]const u8{
        config.openclaw_bin,
        "--chat",
        config.chat_id,
        "--message",
        full_message,
    };

    // Try to send, but don't fail if OpenClaw is unavailable
    _ = process.run(allocator, args) catch |err| {
        std.log.warn("Failed to send Telegram notification: {}", .{err});
        return;
    };
}

fn formatMessage(allocator: Allocator, event: Event, ctx: EventContext) ![]const u8 {
    return switch (event) {
        .loop_start => std.fmt.allocPrint(allocator,
            \\🔄 Ralph Loop Start
            \\Branch: {s}
            \\Loop: {d}
        , .{ ctx.branch, ctx.loop_number }),

        .loop_end => std.fmt.allocPrint(allocator,
            \\✅ Ralph Loop Complete
            \\Branch: {s}
            \\SHA: {s}
        , .{ ctx.branch, ctx.sha }),

        .gate_pass => std.fmt.allocPrint(allocator,
            \\✅ Gate Passed: {s}
            \\Branch: {s}
        , .{ ctx.gate_name, ctx.branch }),

        .gate_fail => std.fmt.allocPrint(allocator,
            \\❌ Gate Failed: {s}
            \\Branch: {s}
            \\SHA: {s}
        , .{ ctx.gate_name, ctx.branch, ctx.sha }),

        .commit => std.fmt.allocPrint(allocator,
            \\💾 Commit Created
            \\Branch: {s}
            \\SHA: {s}
            \\Message: {s}
        , .{ ctx.branch, ctx.sha, ctx.commit_message }),

        .circuit_open => std.fmt.allocPrint(allocator,
            \\🚨 Circuit Breaker OPEN
            \\Branch: {s}
            \\Too many failures - halting
        , .{ctx.branch}),

        .circuit_close => std.fmt.allocPrint(allocator,
            \\✅ Circuit Breaker CLOSED
            \\Branch: {s}
            \\Resuming operations
        , .{ctx.branch}),

        .verdict => std.fmt.allocPrint(allocator,
            \\⚖️ Toxic Verdict
            \\Branch: {s}
            \\Score: {d}/10
        , .{ ctx.branch, ctx.verdict_score }),

        .status => std.fmt.allocPrint(allocator,
            \\📊 Ralph Status
            \\Branch: {s}
            \\SHA: {s}
        , .{ ctx.branch, ctx.sha }),
    };
}

fn getEmoji(event: Event) []const u8 {
    return switch (event) {
        .loop_start => "🔄",
        .loop_end => "✅",
        .gate_pass => "✅",
        .gate_fail => "❌",
        .commit => "💾",
        .circuit_open => "🚨",
        .circuit_close => "✅",
        .verdict => "⚖️",
        .status => "📊",
    };
}

// ============================================================================
// Tests
// ============================================================================

test "telegram: format message" {
    const allocator = std.testing.allocator;

    const ctx = EventContext{
        .branch = "test-branch",
        .loop_number = 5,
    };

    const msg = try formatMessage(allocator, .loop_start, ctx);
    defer allocator.free(msg);

    try std.testing.expect(std.mem.indexOf(u8, msg, "test-branch") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "5") != null);
}

test "telegram: get emoji" {
    try std.testing.expectEqualStrings("✅", getEmoji(.gate_pass));
    try std.testing.expectEqualStrings("❌", getEmoji(.gate_fail));
    try std.testing.expectEqualStrings("🚨", getEmoji(.circuit_open));
}
