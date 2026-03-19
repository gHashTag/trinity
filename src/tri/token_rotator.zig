const std = @import("std");
const fs = std.fs;
const time = std.time;

pub const TokenStatus = enum(u8) { active = 0, rate_limited = 1, expired = 2 };

pub const TokenInfo = struct {
    name: []const u8,
    status: TokenStatus,
    last_429: ?i64 = null,
    reset_at: ?i64 = null,
    usage_count: u64 = 0,
};

pub const TokenRotator = struct {
    allocator: std.mem.Allocator,
    current_index: usize,
    tokens: std.ArrayListUnmanaged(TokenInfo),
    total_rotations: u64,
    last_rotation: i64,
    state_file: []const u8,

    pub fn init(allocator: std.mem.Allocator) !TokenRotator {
        const state_path = ".trinity/token_state.json";
        var rotator = TokenRotator{
            .allocator = allocator,
            .current_index = 0,
            .tokens = .{},
            .total_rotations = 0,
            .last_rotation = 0,
            .state_file = try allocator.dupe(u8, state_path),
        };

        if (rotator.load()) |_| {
            std.debug.print("[token_rotator] Loaded state from {s}\n", .{state_path});
        } else |_| {
            try rotator.initFromEnv(allocator);
        }

        return rotator;
    }

    pub fn deinit(self: *TokenRotator) void {
        for (self.tokens.items) |*token| {
            self.allocator.free(token.name);
        }
        self.tokens.deinit(self.allocator);
        self.allocator.free(self.state_file);
    }

    fn initFromEnv(self: *TokenRotator, allocator: std.mem.Allocator) !void {
        const TOKEN_ENV_VARS = [_][]const u8{
            "ZAI_KEY_1", "ZAI_KEY_2", "ZAI_KEY_3", "ZAI_KEY_5", "ZAI_KEY_6",
        };

        for (TOKEN_ENV_VARS) |env_var| {
            const key = std.posix.getenv(env_var) orelse continue;
            if (key.len == 0) continue;

            try self.tokens.append(allocator, TokenInfo{
                .name = try allocator.dupe(u8, env_var),
                .status = .active,
                .last_429 = null,
                .reset_at = null,
                .usage_count = 0,
            });
        }

        if (self.tokens.items.len == 0) {
            return error.NoTokensAvailable;
        }

        self.last_rotation = time.timestamp();
    }

    pub fn getActiveToken(self: *TokenRotator) ![]const u8 {
        if (self.tokens.items.len == 0) return error.NoTokensAvailable;

        const token = &self.tokens.items[self.current_index];

        const now = time.timestamp();
        if (token.status == .rate_limited) {
            if (token.reset_at) |reset_time| {
                if (reset_time <= now) {
                    token.status = .active;
                }
            }
        }

        if (token.status != .active) {
            return try self.getNextToken();
        }

        const key = std.posix.getenv(token.name) orelse return error.TokenNotFound;
        token.usage_count += 1;
        return self.allocator.dupe(u8, key);
    }

    pub fn getNextToken(self: *TokenRotator) ![]const u8 {
        if (self.tokens.items.len == 0) return error.NoTokensAvailable;

        const now = time.timestamp();

        for (0..self.tokens.items.len) |_| {
            self.current_index = (self.current_index + 1) % self.tokens.items.len;
            const token = &self.tokens.items[self.current_index];

            if (token.status == .rate_limited) {
                if (token.reset_at) |reset_time| {
                    if (reset_time > now) continue;
                    token.status = .active;
                }
            }

            if (token.status == .active) {
                const key = std.posix.getenv(token.name) orelse continue;
                if (key.len == 0) continue;

                token.usage_count += 1;
                self.total_rotations += 1;
                self.last_rotation = now;

                return self.allocator.dupe(u8, key);
            }
        }

        return error.AllTokensRateLimited;
    }

    pub fn on429Error(self: *TokenRotator, retry_after: ?[]const u8) !void {
        if (self.tokens.items.len == 0) return;

        const token = &self.tokens.items[self.current_index];
        const now = time.timestamp();
        token.status = .rate_limited;
        token.last_429 = now;

        if (retry_after) |ra_str| {
            token.reset_at = now + parseRetryAfter(ra_str);
        } else {
            token.reset_at = now + 3600;
        }

        try logEvent(now, token.name, "429", token.reset_at.? - now);
    }

    pub fn rotate(self: *TokenRotator) !void {
        if (self.tokens.items.len == 0) return error.NoTokensAvailable;

        self.current_index = (self.current_index + 1) % self.tokens.items.len;
        self.total_rotations += 1;
        self.last_rotation = time.timestamp();

        try self.save();
    }

    pub fn resetTokens(self: *TokenRotator) !void {
        for (self.tokens.items) |*token| {
            token.status = .active;
            token.last_429 = null;
            token.reset_at = null;
        }
        self.current_index = 0;
        try self.save();
    }

    pub fn save(self: *const TokenRotator) !void {
        const state_dir = std.fs.path.dirname(self.state_file) orelse ".";
        try fs.cwd().makePath(state_dir);

        var file = try fs.cwd().createFile(self.state_file, .{ .mode = 0o600 });
        defer file.close();

        const writer = file.writer();

        try writer.writeAll("{\n");
        try writer.print("  \"current_index\": {},\n", .{self.current_index});
        try writer.print("  \"total_rotations\": {},\n", .{self.total_rotations});
        try writer.print("  \"last_rotation\": {},\n", .{self.last_rotation});
        try writer.writeAll("  \"tokens\": [\n");

        for (self.tokens.items, 0..) |token, i| {
            try writer.print("    {{\"name\": \"{s}\", \"status\": {}, ", .{ token.name, @intFromEnum(token.status) });

            if (token.last_429) |ts| {
                try writer.print("\"last_429\": {}, ", .{ts});
            } else {
                try writer.writeAll("\"last_429\": null, ");
            }

            if (token.reset_at) |ts| {
                try writer.print("\"reset_at\": {}, ", .{ts});
            } else {
                try writer.writeAll("\"reset_at\": null, ");
            }

            try writer.print("\"usage_count\": {}}}", .{token.usage_count});

            if (i < self.tokens.items.len - 1) {
                try writer.writeAll(",\n");
            } else {
                try writer.writeAll("\n");
            }
        }

        try writer.writeAll("  ]\n");
        try writer.writeAll("}\n");

        try file.flush();
    }

    pub fn load(self: *TokenRotator) !void {
        const file_obj = fs.cwd().openFile(self.state_file, .{}) catch return error.FileNotFound;
        defer file_obj.close();

        const content = try std.fs.cwd().readFileAlloc(self.allocator, self.state_file, 10 * 1024);
        defer self.allocator.free(content);

        var pos: usize = 0;
        var current_idx: usize = 0;
        var total_rot: u64 = 0;
        var last_rot: i64 = 0;

        if (std.mem.indexOf(u8, content, "\"current_index\":")) |idx| {
            pos = idx + "\"current_index\": ".len;
            if (std.fmt.parseInt(usize, content[pos..], 10)) |val| {
                current_idx = val;
            } else |_| {}
        }

        if (std.mem.indexOf(u8, content, "\"total_rotations\":")) |idx| {
            pos = idx + "\"total_rotations\": ".len;
            if (std.fmt.parseInt(u64, content[pos..], 10)) |val| {
                total_rot = val;
            } else |_| {}
        }

        if (std.mem.indexOf(u8, content, "\"last_rotation\":")) |idx| {
            pos = idx + "\"last_rotation\": ".len;
            if (std.fmt.parseInt(i64, content[pos..], 10)) |val| {
                last_rot = val;
            } else |_| {}
        }

        self.current_index = current_idx;
        self.total_rotations = total_rot;
        self.last_rotation = last_rot;
    }

    pub fn getStats(self: *const TokenRotator) Stats {
        var result = Stats{ .total = self.tokens.items.len, .active = 0, .rate_limited = 0, .expired = 0 };

        for (self.tokens.items) |token| {
            switch (token.status) {
                .active => result.active += 1,
                .rate_limited => result.rate_limited += 1,
                .expired => result.expired += 1,
            }
        }

        return result;
    }
};

pub const Stats = struct {
    total: usize,
    active: usize,
    rate_limited: usize,
    expired: usize,
};

pub fn parseRetryAfter(str: []const u8) i64 {
    if (std.fmt.parseInt(i64, str, 10)) |seconds| {
        return seconds;
    } else |_| {}

    return 3600;
}

pub fn is429Error(response_body: []const u8) bool {
    return std.mem.indexOf(u8, response_body, "\"code\":\"1308\"") != null or
        (std.mem.indexOf(u8, response_body, "\"error\"") != null and
            (std.mem.indexOf(u8, response_body, "\"429\"") != null or
                std.mem.indexOf(u8, response_body, "\"1308\"") != null));
}

pub fn extractRetryAfter(response_body: []const u8) ?[]const u8 {
    const fields = [_][]const u8{
        "\"retry_after\"",
        "\"retry-after\"",
        "\"Retry-After\"",
    };

    for (fields) |field| {
        if (std.mem.indexOf(u8, response_body, field)) |pos| {
            const value_start = pos + field.len + 2;
            if (value_start < response_body.len) {
                const value_end = std.mem.indexOfScalar(u8, response_body[value_start..], ',') orelse
                    std.mem.indexOfScalar(u8, response_body[value_start..], '}') orelse
                    std.mem.indexOfScalar(u8, response_body[value_start..], ']') orelse response_body.len;
                return response_body[value_start .. value_start + value_end];
            }
        }
    }

    return null;
}

fn logEvent(timestamp: i64, token_name: []const u8, event_type: []const u8, duration: i64) !void {
    const log_path = ".trinity/event_log.jsonl";
    std.fs.cwd().makePath(".trinity") catch {};

    var file_obj = std.fs.cwd().openFile(log_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            const new_file = try std.fs.cwd().createFile(log_path, .{});
            new_file.close();
            return;
        } else {
            return err;
        }
    };
    defer file_obj.close();

    try file_obj.seekFromEnd(0);

    const log_entry = try std.fmt.allocPrint(std.heap.page_allocator, "{{\"timestamp\":{},\"event\":\"token_{s}\",\"token_name\":\"{s}\",\"duration\":{}}}\n", .{ timestamp, event_type, token_name, duration });
    defer std.heap.page_allocator.free(log_entry);

    try file_obj.writeAll(log_entry);
}

const testing = std.testing;

test "is429Error - z.ai format" {
    const body1 = "{\"error\":{\"code\":\"1308\",\"message\":\"Usage limit reached\"}}";
    try testing.expect(is429Error(body1));

    const body2 = "{\"error\":{\"code\":\"1308\"}}";
    try testing.expect(is429Error(body2));

    const body3 = "{\"error\":{\"429\":\"rate limit\"}}";
    try testing.expect(is429Error(body3));

    const body4 = "{\"result\":\"ok\"}}";
    try testing.expect(!is429Error(body4));
}

test "parseRetryAfter" {
    try testing.expectEqual(@as(i64, 3600), parseRetryAfter("3600"));
    try testing.expectEqual(@as(i64, 60), parseRetryAfter("60"));
    try testing.expectEqual(@as(i64, 3600), parseRetryAfter("Tue, 15 Nov 1994 08:12:31 GMT"));
}
