// ═══════════════════════════════════════════════════════════════════════════════
// Railway Token Recovery Utility
// ═══════════════════════════════════════════════════════════════════════════════
// Validates Railway tokens and generates .env update commands
//
// Usage: zig build token_recovery && ./zig-out/bin/token-recovery
//
// Get new tokens from: https://railway.com/account/tokens
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const Account = struct {
    name: []const u8,
    env_key: []const u8,
};

const accounts = [_]Account{
    .{ .name = "PRIMARY", .env_key = "RAILWAY_API_TOKEN" },
    .{ .name = "FARM-2", .env_key = "RAILWAY_API_TOKEN_2" },
    .{ .name = "FARM-3", .env_key = "RAILWAY_API_TOKEN_3" },
    .{ .name = "FARM-4", .env_key = "RAILWAY_API_TOKEN_4" },
    .{ .name = "FARM-5", .env_key = "RAILWAY_API_TOKEN_5" },
    .{ .name = "FARM-6", .env_key = "RAILWAY_API_TOKEN_6" },
    .{ .name = "FARM-7", .env_key = "RAILWAY_API_TOKEN_7" },
    .{ .name = "FARM-8", .env_key = "RAILWAY_API_TOKEN_8" },
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.fs.File.stderr().deprecatedWriter();
    const stdin = std.fs.File.stdin().deprecatedReader();

    try stdout.print("🔧 Railway Token Recovery\n", .{});
    try stdout.print("═════════════════════════════\n\n", .{});
    try stdout.print("Get new tokens from: https://railway.com/account/tokens\n\n", .{});

    try stdout.print("Enter each new token (press Enter to skip):\n", .{});
    try stdout.print("(Paste token and press Enter, or Ctrl+D when done)\n\n", .{});

    var valid_tokens = std.StringHashMap([]const u8).init(allocator);
    defer {
        var iter = valid_tokens.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        valid_tokens.deinit();
    }

    for (accounts) |acct| {
        try stdout.print("{s} ({s}): ", .{ acct.name, acct.env_key });

        var token_buf: [100]u8 = undefined;
        const token = stdin.readUntilDelimiterOrEof(token_buf[0..], '\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        if (token == null or token.?.len == 0) {
            try stdout.print("  ⚠️  Skipping {s}\n", .{acct.name});
            continue;
        }

        const trimmed = std.mem.trim(u8, token.?, &std.ascii.whitespace);
        if (trimmed.len == 0) {
            try stdout.print("  ⚠️  Skipping {s}\n", .{acct.name});
            continue;
        }

        try stdout.print("  Testing token... ", .{});

        const email = testToken(allocator, trimmed) catch |err| {
            try stdout.print("❌ Error: {}\n", .{err});
            continue;
        };

        if (email) |e| {
            try stdout.print("✅ Valid! Account: {s}\n", .{e});
            const key_copy = try allocator.dupe(u8, acct.env_key);
            const val_copy = try allocator.dupe(u8, trimmed);
            try valid_tokens.put(key_copy, val_copy);
        } else {
            try stdout.print("❌ Invalid token!\n", .{});
        }
    }

    try stdout.print("\n", .{});

    if (valid_tokens.count() == 0) {
        try stdout.print("⚠️  No valid tokens entered.\n", .{});
        return;
    }

    try stdout.print("═════════════════════════════\n", .{});
    try stdout.print("📝 Update .env with:\n\n", .{});

    var iter = valid_tokens.iterator();
    while (iter.next()) |entry| {
        try stdout.print("{s}={s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    try stdout.print("\n", .{});
    try stdout.print("Next steps:\n", .{});
    try stdout.print("  1. Update .env with the values above\n", .{});
    try stdout.print("  2. source .env\n", .{});
    try stdout.print("  3. zig build tri\n", .{});
    try stdout.print("  4. tri farm status\n", .{});
    try stdout.print("  5. tri farm recycle --account PRIMARY --batch 5 --skip-ci\n", .{});
}

fn testToken(allocator: std.mem.Allocator, token: []const u8) !?[]const u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("https://railway.com/graphql");

    const query = "{\"query\":\"query { me { email } }\"}";

    var auth_buf: [256]u8 = undefined;
    const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

    var headers = [_]std.http.Header{
        .{ .name = "Authorization", .value = auth_val },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var req = client.request(.POST, uri, .{
        .extra_headers = &headers,
    }) catch return null;
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = query.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch return null;
    body_writer.writer.writeAll(query) catch return null;
    body_writer.end() catch return null;
    if (req.connection) |conn| conn.flush() catch return null;

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch return null;

    if (response.head.status != .ok) return null;

    var transfer_buffer: [4096]u8 = undefined;
    var reader = response.reader(&transfer_buffer);
    const body = reader.allocRemaining(allocator, std.Io.Limit.limited(4096)) catch return null;
    defer allocator.free(body);

    // Parse JSON to extract email
    const Json = std.json;
    const parsed = Json.parseFromSlice(Json.Value, allocator, body, .{}) catch return null;
    defer parsed.deinit();

    if (parsed.value.object.get("data")) |data| {
        if (data.object.get("me")) |me| {
            if (me.object.get("email")) |email_val| {
                if (email_val == .string) {
                    return try allocator.dupe(u8, email_val.string);
                }
            }
        }
    }

    return null;
}
