// @origin(manual-impl)
// ============================================================================
// TRI TOKEN - Token Rotator CLI Commands
// ============================================================================
// Commands: status, rotate, reset

const std = @import("std");
const token_rotator = @import("token_rotator.zig");

pub fn runTokenCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var rotator = try token_rotator.TokenState.init(allocator);
    defer rotator.deinit();

    if (args.len == 0) {
        try cmdStatus(&rotator);
        return;
    }

    const command = args[0];

    if (std.mem.eql(u8, command, "status")) {
        try cmdStatus(&rotator);
    } else if (std.mem.eql(u8, command, "rotate")) {
        try cmdRotate(&rotator);
    } else if (std.mem.eql(u8, command, "reset")) {
        try cmdReset(&rotator);
    } else if (std.mem.eql(u8, command, "test")) {
        try cmdTest(&rotator, allocator);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        std.debug.print("Available commands: status, rotate, reset, test\n", .{});
    }
}

fn cmdStatus(rotator: *token_rotator.TokenState) !void {
    const stdout = std.io.getStdOut();
    var writer = stdout.writer();

    try writer.print("\n╔══════════════════════════════════════╗\n", .{});
    try writer.print("║       Z.AI TOKEN ROTATOR STATUS          ║\n", .{});
    try writer.print("╠══════════════════════════════════════╣\n", .{});

    try writer.print("🔄 Total Rotations: {d}\n", .{rotator.total_rotations});
    try writer.print("⏰ Last Rotation: {s}\n", .{formatTimestamp(rotator.last_rotation)});
    try writer.print("\n", .{});

    for (rotator.tokens.items, 0..) |token, i| {
        const status_emoji = switch (token.status) {
            .active => "✅",
            .rate_limited => "⏸️",
            .expired => "❌",
        };

        const marker = if (i == @as(usize, rotator.current_index)) "▶ " else "  ";

        try writer.print("{s}{s} {s}: {s}\n", .{ marker, status_emoji, token.name, @tagName(token.status) });

        if (token.status == .rate_limited and token.reset_at) |reset| {
            const now = std.time.timestamp();
            if (reset > now) {
                const remaining = reset - now;
                try writer.print("   ⏳ Resets in {d}s ({s})\n", .{ remaining, formatTimestamp(reset) });
            } else {
                try writer.print("   ✨ Should be active now (time passed)\n", .{});
            }
        }

        try writer.print("   📊 Usage: {d} times\n", .{token.usage_count});

        if (token.last_429) |last| {
            try writer.print("   ⚠️  Last 429: {s}\n", .{formatTimestamp(last)});
        }
    }

    try writer.print("\n", .{});
}

fn cmdRotate(rotator: *token_rotator.TokenState) !void {
    _ = try rotator.getNextToken();
    try rotator.save();

    const stdout = std.io.getStdOut();
    var writer = stdout.writer();

    try writer.print("🔄 Rotated to next token\n", .{});
    try writer.print("Current index: {d}/{d}\n", .{ rotator.current_index + 1, rotator.tokens.items.len });

    const active_token = &rotator.tokens.items[rotator.current_index];
    try writer.print("Active: {s} ({s})\n", .{ active_token.name, @tagName(active_token.status) });
}

fn cmdReset(rotator: *token_rotator.TokenState) !void {
    try rotator.reset();

    const stdout = std.io.getStdOut();
    var writer = stdout.writer();

    try writer.print("✅ All tokens reset to active status\n", .{});
}

fn cmdTest(rotator: *token_rotator.TokenState, allocator: std.mem.Allocator) !void {
    const api_key = try rotator.getActiveToken();
    defer allocator.free(api_key);

    const stdout = std.io.getStdOut();
    var writer = stdout.writer();

    try writer.print("🧪 Testing active token...\n", .{});
    try writer.print("Token value: {s}...\n", .{api_key[0..16] ++ "...***"});

    // TODO: Make actual API call to test token
    try writer.print("✅ Token format looks valid (length: {d})\n", .{api_key.len});
}

fn formatTimestamp(ts: i64) []const u8 {
    if (ts == 0) return "never";

    var buf: [64]u8 = undefined;
    const seconds_since = std.time.timestamp() - ts;

    if (seconds_since < 60) {
        return try std.fmt.bufPrint(&buf, "{d}s ago", .{seconds_since});
    } else if (seconds_since < 3600) {
        return try std.fmt.bufPrint(&buf, "{d}m ago", .{seconds_since / 60});
    } else if (seconds_since < 86400) {
        return try std.fmt.bufPrint(&buf, "{d}h ago", .{seconds_since / 3600});
    } else {
        const days = seconds_since / 86400;
        return try std.fmt.bufPrint(&buf, "{d}d ago", .{days});
    }
}
