// @origin(spec:storm/config.tri) @regen(vibee)
// ═══════════════════════════════════════════════════════════════════════════════
// STORM CONFIG — Configuration parser and defaults for STORM operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LogLevel = enum(u2) {
    debug,
    info,
    warn,
    err,

    pub fn fromStr(s: []const u8) ?LogLevel {
        if (std.mem.eql(u8, s, "debug")) return .debug;
        if (std.mem.eql(u8, s, "info")) return .info;
        if (std.mem.eql(u8, s, "warn")) return .warn;
        if (std.mem.eql(u8, s, "err")) return .err;
        return null;
    }

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "debug",
            .info => "info",
            .warn => "warn",
            .err => "err",
        };
    }
};

pub const WaveConfig = struct {
    wave_id: u4,
    agent_count: u8,
    parallel: bool = true,
    timeout_ms: u64 = 300_000,

    pub fn fromJson(allocator: std.mem.Allocator, obj: std.json.Value) !WaveConfig {
        _ = allocator;
        const wave_id = if (obj.object.get("wave_id")) |v| blk: {
            if (v != .integer) return error.InvalidWaveId;
            break :blk @as(u4, @intCast(v.integer));
        } else return error.MissingWaveId;

        const agent_count = if (obj.object.get("agent_count")) |v| blk: {
            if (v != .integer) return error.InvalidAgentCount;
            break :blk @as(u8, @intCast(v.integer));
        } else 3;

        const parallel = if (obj.object.get("parallel")) |v| blk: {
            if (v != .bool) return error.InvalidParallel;
            break :blk v.bool;
        } else true;

        const timeout_ms = if (obj.object.get("timeout_ms")) |v| blk: {
            if (v != .integer) return error.InvalidTimeout;
            break :blk @as(u64, @intCast(v.integer));
        } else 300_000;

        return .{
            .wave_id = wave_id,
            .agent_count = agent_count,
            .parallel = parallel,
            .timeout_ms = timeout_ms,
        };
    }
};

pub const AgentConfig = struct {
    max_concurrent: u8 = 10,
    heartbeat_interval_ms: u64 = 30_000,
    retry_count: u3 = 3,
};

pub const StormConfig = struct {
    waves: u4 = 5,
    agents: u8 = 32,
    config_path: []const u8 = ".trinity/storm/config.json",
    checkpoint_dir: []const u8 = ".trinity/storm/checkpoints/",
    log_level: LogLevel = .info,
    max_concurrent_agents: u8 = 10,
    heartbeat_interval_ms: u64 = 30_000,
    retry_count: u3 = 3,
    wave_configs: [5]WaveConfig = default_waves,

    const default_waves = [5]WaveConfig{
        .{ .wave_id = 1, .agent_count = 3, .parallel = true, .timeout_ms = 300_000 },
        .{ .wave_id = 2, .agent_count = 4, .parallel = true, .timeout_ms = 300_000 },
        .{ .wave_id = 3, .agent_count = 16, .parallel = true, .timeout_ms = 600_000 },
        .{ .wave_id = 4, .agent_count = 5, .parallel = true, .timeout_ms = 300_000 },
        .{ .wave_id = 5, .agent_count = 4, .parallel = false, .timeout_ms = 300_000 },
    };

    /// Load config from JSON file. Use defaults if file missing.
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !StormConfig {
        var config = defaults();
        config.config_path = path;

        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return config;
            }
            return err;
        };
        defer file.close();

        const contents = file.readToEndAlloc(allocator, 64 * 1024) catch |err| {
            if (err == error.FileTooBig) return error.ConfigTooLarge;
            return err;
        };
        defer allocator.free(contents);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch {
            return error.InvalidJson;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidRoot;

        // Parse simple fields
        if (root.object.get("waves")) |v| {
            if (v == .integer) config.waves = @as(u4, @intCast(@min(v.integer, 10)));
        }
        if (root.object.get("agents")) |v| {
            if (v == .integer) config.agents = @as(u8, @intCast(@min(v.integer, 100)));
        }
        if (root.object.get("checkpoint_dir")) |v| {
            if (v == .string) config.checkpoint_dir = try allocator.dupe(u8, v.string);
        }
        if (root.object.get("log_level")) |v| {
            if (v == .string) {
                if (LogLevel.fromStr(v.string)) |lvl| {
                    config.log_level = lvl;
                }
            }
        }
        if (root.object.get("max_concurrent_agents")) |v| {
            if (v == .integer) config.max_concurrent_agents = @as(u8, @intCast(v.integer));
        }
        if (root.object.get("heartbeat_interval_ms")) |v| {
            if (v == .integer) config.heartbeat_interval_ms = @intCast(v.integer);
        }
        if (root.object.get("retry_count")) |v| {
            if (v == .integer) config.retry_count = @as(u3, @intCast(@min(v.integer, 7)));
        }

        // Parse wave_configs array
        if (root.object.get("wave_configs")) |v| {
            if (v == .array) {
                var i: usize = 0;
                for (v.array.items) |item| {
                    if (item == .object and i < config.wave_configs.len) {
                        config.wave_configs[i] = try WaveConfig.fromJson(allocator, item);
                        i += 1;
                    }
                }
            }
        }

        try config.validate();
        return config;
    }

    /// Save config to config_path.
    pub fn save(self: *const StormConfig) !void {
        // Ensure directory exists
        std.fs.cwd().makePath(".trinity/storm") catch {};

        var json_buf: [4096]u8 = undefined;
        const json = try std.fmt.bufPrint(&json_buf,
            \\{{
            \\  "waves": {d},
            \\  "agents": {d},
            \\  "checkpoint_dir": "{s}",
            \\  "log_level": "{s}",
            \\  "max_concurrent_agents": {d},
            \\  "heartbeat_interval_ms": {d},
            \\  "retry_count": {d},
            \\  "wave_configs": [
            \\    {{"wave_id":1,"agent_count":3,"parallel":true,"timeout_ms":300000}},
            \\    {{"wave_id":2,"agent_count":4,"parallel":true,"timeout_ms":300000}},
            \\    {{"wave_id":3,"agent_count":16,"parallel":true,"timeout_ms":600000}},
            \\    {{"wave_id":4,"agent_count":5,"parallel":true,"timeout_ms":300000}},
            \\    {{"wave_id":5,"agent_count":4,"parallel":false,"timeout_ms":300000}}
            \\  ]
            \\}}
        , .{
            self.waves,
            self.agents,
            self.checkpoint_dir,
            self.log_level.toString(),
            self.max_concurrent_agents,
            self.heartbeat_interval_ms,
            self.retry_count,
        });

        const file = try std.fs.cwd().createFile(self.config_path, .{});
        defer file.close();
        try file.writeAll(json);
    }

    /// Return default StormConfig.
    pub fn defaults() StormConfig {
        return .{};
    }

    /// Validate config values.
    pub fn validate(self: *const StormConfig) !void {
        if (self.waves == 0 or self.waves > 10) return error.InvalidWaveCount;
        if (self.agents == 0 or self.agents > 100) return error.InvalidAgentCount;
        if (self.max_concurrent_agents == 0 or self.max_concurrent_agents > 50) return error.InvalidMaxConcurrent;
        if (self.heartbeat_interval_ms < 1000) return error.InvalidHeartbeat;
        if (self.retry_count > 7) return error.InvalidRetryCount;

        // Validate wave configs
        var total_agents: u8 = 0;
        for (self.wave_configs[0..self.waves]) |wc| {
            if (wc.agent_count == 0) return error.InvalidWaveAgentCount;
            if (wc.timeout_ms < 10_000) return error.InvalidWaveTimeout;
            total_agents += wc.agent_count;
        }
        if (total_agents > self.agents) return error.TotalAgentsExceedsConfig;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LogLevel fromStr roundtrip" {
    const levels = [_]LogLevel{ .debug, .info, .warn, .err };
    for (levels) |lvl| {
        const str = lvl.toString();
        const parsed = LogLevel.fromStr(str).?;
        try std.testing.expectEqual(lvl, parsed);
    }
}

test "StormConfig defaults" {
    const config = StormConfig.defaults();
    try std.testing.expectEqual(@as(u4, 5), config.waves);
    try std.testing.expectEqual(@as(u8, 32), config.agents);
    try std.testing.expectEqual(@as(u8, 10), config.max_concurrent_agents);
    try std.testing.expectEqual(@as(u64, 30_000), config.heartbeat_interval_ms);
    try std.testing.expectEqual(@as(u3, 3), config.retry_count);
    try std.testing.expectEqual(LogLevel.info, config.log_level);
}

test "StormConfig validate valid" {
    const config = StormConfig.defaults();
    try config.validate();
}

test "StormConfig validate invalid waves" {
    var config = StormConfig.defaults();
    config.waves = 11;
    try std.testing.expectError(error.InvalidWaveCount, config.validate());
}

test "StormConfig validate invalid agents" {
    var config = StormConfig.defaults();
    config.agents = 0;
    try std.testing.expectError(error.InvalidAgentCount, config.validate());
}
