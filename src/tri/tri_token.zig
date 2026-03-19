// ============================================================================
// TRI TOKEN - Token Rotator CLI Commands
// ============================================================================
// Commands: status, rotate, reset

const std = @import("std");
const token_rotator = @import("../tri/token_rotator.zig");

pub fn runTokenCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showUsage();
        return;
    }

    var rotator = try token_rotator.TokenRotator.init(allocator);
    defer rotator.deinit();

    const command = args[0];

    if (std.mem.eql(u8, command, "status")) {
        try showStatus(allocator, &rotator);
    } else if (std.mem.eql(u8, command, "rotate")) {
        try rotateToken(&rotator);
    } else if (std.mem.eql(u8, command, "reset")) {
        try resetTokens(&rotator);
    } else if (std.mem.eql(u8, command, "test")) {
        try testToken(allocator, &rotator);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try showUsage();
    }
}

fn showUsage() !void {
    const stdout = std.io.getStdErr().writer();
    try stdout.print(
        \\Usage: tri token <command>
        \\
        \\Commands:
        \\  status    Show all tokens status with emoji
        \\  rotate    Force rotation to next token
        \\  reset     Reset all tokens to active state
        \\  test      Test current token availability
        \\
    , .{});
}

fn showStatus(allocator: std.mem.Allocator, rotator: *const token_rotator.TokenRotator) !void {
    const stdout = std.io.getStdErr().writer();

    const stats = rotator.getStats();
    const now = std.time.timestamp();

    try stdout.writeAll("\n  🔄 Token Rotator Status\n");
    try stdout.writeAll("  " ++ "=" ** 35 ++ "\n");

    // Время последней ротации
    const time_diff = now - rotator.last_rotation;
    const time_str = if (time_diff < 60) try std.fmt.allocPrint(allocator, "{}s ago", .{time_diff})
                    else if (time_diff < 3600) try std.fmt.allocPrint(allocator, "{d:.1}m ago", .{@as(f64, time_diff) / 60.0})
                    else try std.fmt.allocPrint(allocator, "{d:.1}h ago", .{@as(f64, time_diff) / 3600.0});
    defer allocator.free(time_str);

    try stdout.print("\n  📊 Stats:\n", .{});
    try stdout.print("    Total tokens: {d}\n", .{stats.total});
    try stdout.print("    ✅ Active: {d}\n", .{stats.active});
    try stdout.print("    ⏳ Rate limited: {d}\n", .{stats.rate_limited});
    try stdout.print("    ⚠️  Expired: {d}\n", .{stats.expired});
    try stdout.print("    Total rotations: {d}\n", .{rotator.total_rotations});
    try stdout.print("    Last rotation: {s}\n", .{time_str});

    try stdout.print("\n  🔑 Tokens:\n", .{});

    for (rotator.tokens.items, 0..) |token, i| {
        const is_current = i == rotator.current_index;

        // Статус emoji
        const emoji = switch (token.status) {
            .active => if (is_current) "🟢" else "🟢",
            .rate_limited => "🔴",
            .expired => "⚫",
        };

        try stdout.print("    {s} ", .{emoji});

        // Индикатор текущего токена
        if (is_current) try stdout.writeAll("[CURRENT] ");

        // Имя env var
        try stdout.print("{s} ", .{token.name});

        // Статус текст
        try stdout.print("({s}) ", .{@tagName(token.status)});

        // Детали для rate_limited
        if (token.status == .rate_limited) {
            if (token.reset_at) |reset| {
                const remaining = reset - now;
                const remaining_str = if (remaining < 60) try std.fmt.allocPrint(allocator, "{}s", .{remaining})
                                      else if (remaining < 3600) try std.fmt.allocPrint(allocator, "{d:.1}m", .{@as(f64, remaining) / 60.0})
                                      else try std.fmt.allocPrint(allocator, "{d:.1}h", .{@as(f64, remaining) / 3600.0});
                defer allocator.free(remaining_str);

                try stdout.print("→ resets in {s}", .{remaining_str});
            }
        }

        // Usage count
        try stdout.print(" | {d} uses\n", .{token.usage_count});
    }

    try stdout.writeAll("\n");
}

fn rotateToken(rotator: *token_rotator.TokenRotator) !void {
    const stdout = std.io.getStdErr().writer();

    const old_index = rotator.current_index;
    try rotator.rotate();

    try stdout.print("🔄 Rotated from token {d} to {d}\n", .{ old_index + 1, rotator.current_index + 1 });
    try stdout.print("🔑 Current token: {s}\n", .{rotator.tokens.items[rotator.current_index].name});
    try stdout.print("💾 State saved to .trinity/token_state.json\n", .{});
}

fn resetTokens(rotator: *token_rotator.TokenRotator) !void {
    const stdout = std.io.getStdErr().writer();

    const rate_limited_before = rotator.getStats().rate_limited;

    if (rate_limited_before == 0) {
        try stdout.writeAll("✅ All tokens already active\n");
        return;
    }

    try rotator.resetTokens();

    try stdout.print("🔄 Reset {d} rate-limited tokens to active\n", .{rate_limited_before});
    try stdout.writeAll("💾 State saved to .trinity/token_state.json\n");
}

fn testToken(allocator: std.mem.Allocator, rotator: *token_rotator.TokenRotator) !void {
    const stdout = std.io.getStdErr().writer();

    try stdout.writeAll("🧪 Testing active token...\n");

    // Получаем текущий токен
    const token = try rotator.getActiveToken();
    defer allocator.free(token);

    // Проверяем что токен не пустой
    if (token.len == 0) {
        try stdout.writeAll("❌ Token is empty or not set\n");
        return;
    }

    // Показываем токен (маскируем середину для безопасности)
    const masked = try maskToken(allocator, token);
    defer allocator.free(masked);

    try stdout.print("✅ Active token: {s}\n", .{masked});
    try stdout.print("📝 Token name: {s}\n", .{rotator.tokens.items[rotator.current_index].name});
}

fn maskToken(allocator: std.mem.Allocator, token: []const u8) ![]const u8 {
    if (token.len <= 10) {
        return try std.fmt.allocPrint(allocator, "{s}***", .{token[0..3]});
    }

    return try std.fmt.allocPrint(allocator, "{s}...{s}", .{ token[0..5], token[token.len - 5..] });
}
