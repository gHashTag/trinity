// @origin(spec:fly_farm.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// FLY.IO FARM — Multi-Account Scheduler & Capacity Tracker
// ═══════════════════════════════════════════════════════════════════════════════
//
// Manages multiple Fly.io accounts for parallel training deployment.
// Auto-detects accounts from env vars: FLY_API_TOKEN, FLY_API_TOKEN_2, ...
// State persisted to .trinity/fly_farm.json
//
// Uses flyctl CLI for all operations (no GraphQL, unlike Railway).
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const FARM_STATE_FILE = ".trinity/fly_farm.json";
pub const MAX_ACCOUNTS: usize = 8;
pub const MAX_APPS: usize = 100;

pub const FlyAccount = struct {
    id: u8, // 1, 2, 3...
    alias: [32]u8,
    alias_len: usize,
    env_suffix: [8]u8, // "", "_2", "_3"
    env_suffix_len: usize,
    daily_creates: u16,
    daily_reset_epoch: i64,
    active_apps: u16,
    max_concurrent: u16, // Fly.io free tier: 3 machines/app
    max_daily_creates: u16, // No documented daily limit

    pub fn canSpawn(self: *const FlyAccount) bool {
        const now_day = @divTrunc(std.time.timestamp(), 86400) * 86400;
        var mutable = @constCast(self);
        if (now_day > self.daily_reset_epoch) {
            mutable.daily_creates = 0;
            mutable.daily_reset_epoch = now_day;
        }
        return self.active_apps < self.max_concurrent and
            self.daily_creates < self.max_daily_creates;
    }

    pub fn availableSlots(self: *const FlyAccount) u16 {
        const concurrent_left = self.max_concurrent -| self.active_apps;
        const daily_left = self.max_daily_creates -| self.daily_creates;
        return @min(concurrent_left, daily_left);
    }

    pub fn getAlias(self: *const FlyAccount) []const u8 {
        return self.alias[0..self.alias_len];
    }

    pub fn getSuffix(self: *const FlyAccount) []const u8 {
        return self.env_suffix[0..self.env_suffix_len];
    }
};

pub const AppMapping = struct {
    app_name: [64]u8,
    app_name_len: usize,
    account_id: u8,

    pub fn getAppName(self: *const AppMapping) []const u8 {
        return self.app_name[0..self.app_name_len];
    }
};

pub const FarmCapacity = struct {
    total_slots: u16,
    total_active: u16,
    total_daily_remaining: u16,
    account_count: u8,
};

pub const SpawnResult = struct {
    app_name_buf: [64]u8 = undefined,
    app_name_len: usize = 0,
    account_id: u8,
    status: enum { spawned, rate_limited, all_exhausted, name_taken },

    pub fn getAppName(self: *const SpawnResult) []const u8 {
        return self.app_name_buf[0..self.app_name_len];
    }
};

pub const FlyFarm = struct {
    accounts: [MAX_ACCOUNTS]FlyAccount,
    account_count: u8,
    app_map: [MAX_APPS]AppMapping,
    app_map_count: usize,
    state_loaded: bool,

    const Self = @This();

    /// Detect accounts from environment variables.
    /// Checks FLY_API_TOKEN, FLY_API_TOKEN_2, ..._3, etc.
    pub fn init() FlyFarm {
        var farm = FlyFarm{
            .accounts = undefined,
            .account_count = 0,
            .app_map = undefined,
            .app_map_count = 0,
            .state_loaded = false,
        };

        // Check primary account (no suffix)
        farm.tryAddAccount(1, "fly-primary", "");

        // Check accounts 2-8
        for (2..9) |idx| {
            var suffix_buf: [8]u8 = undefined;
            const suffix = std.fmt.bufPrint(&suffix_buf, "_{d}", .{idx}) catch continue;

            var alias_buf: [32]u8 = undefined;
            const alias = std.fmt.bufPrint(&alias_buf, "fly-acct-{d}", .{idx}) catch continue;

            farm.tryAddAccount(@intCast(idx), alias, suffix);
        }

        farm.loadState();
        return farm;
    }

    fn tryAddAccount(self: *Self, id: u8, alias: []const u8, suffix: []const u8) void {
        // Check if the token env var exists
        var key_buf: [32]u8 = undefined;
        const base = "FLY_API_TOKEN";
        @memcpy(key_buf[0..base.len], base);
        @memcpy(key_buf[base.len .. base.len + suffix.len], suffix);
        const key = key_buf[0 .. base.len + suffix.len];

        // Just check existence — getEnvVarOwned needs allocator, so use a temp check
        const val = std.process.getEnvVarOwned(std.heap.page_allocator, key) catch return;
        std.heap.page_allocator.free(val);

        if (self.account_count >= MAX_ACCOUNTS) return;

        var account = &self.accounts[self.account_count];
        account.id = id;
        account.alias_len = @min(alias.len, 32);
        @memcpy(account.alias[0..account.alias_len], alias[0..account.alias_len]);
        account.env_suffix_len = @min(suffix.len, 8);
        @memcpy(account.env_suffix[0..account.env_suffix_len], suffix[0..account.env_suffix_len]);
        account.daily_creates = 0;
        account.daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400;
        account.active_apps = 0;
        account.max_concurrent = 3; // Fly.io free tier limit
        account.max_daily_creates = 50; // Conservative daily limit
        self.account_count += 1;
    }

    /// Select least-loaded account that can spawn.
    pub fn selectAccount(self: *Self) ?*FlyAccount {
        var best: ?*FlyAccount = null;
        var best_slots: u16 = 0;

        for (self.accounts[0..self.account_count]) |*acct| {
            if (!acct.canSpawn()) continue;
            const slots = acct.availableSlots();
            if (slots > best_slots or (slots == best_slots and best != null and acct.daily_creates < best.?.daily_creates)) {
                best = acct;
                best_slots = slots;
            }
        }
        return best;
    }

    /// Get environment variable for a specific account
    pub fn getAuthToken(self: *const Self, allocator: Allocator, account_id: u8) ![]const u8 {
        for (self.accounts[0..self.account_count]) |*acct| {
            if (acct.id == account_id) {
                var key_buf: [32]u8 = undefined;
                const base = "FLY_API_TOKEN";
                @memcpy(key_buf[0..base.len], base);
                @memcpy(key_buf[base.len .. base.len + acct.env_suffix_len], acct.env_suffix[0..acct.env_suffix_len]);
                const key = key_buf[0 .. base.len + acct.env_suffix_len];

                return std.process.getEnvVarOwned(allocator, key) orelse return error.TokenNotFound;
            }
        }
        return error.AccountNotFound;
    }

    /// Get account ID for an app (or null).
    pub fn getAccountForApp(self: *Self, app_name: []const u8) ?u8 {
        for (self.app_map[0..self.app_map_count]) |*m| {
            if (std.mem.eql(u8, m.getAppName(), app_name)) return m.account_id;
        }
        return null;
    }

    /// Record an app-to-account mapping.
    pub fn recordApp(self: *Self, app_name: []const u8, account_id: u8) void {
        if (self.app_map_count >= MAX_APPS) return;
        var entry = &self.app_map[self.app_map_count];
        entry.app_name_len = @min(app_name.len, 64);
        @memcpy(entry.app_name[0..entry.app_name_len], app_name[0..entry.app_name_len]);
        entry.account_id = account_id;
        self.app_map_count += 1;
        self.saveState();
    }

    /// Remove app mapping
    pub fn removeApp(self: *Self, app_name: []const u8) void {
        var write_idx: usize = 0;
        for (self.app_map[0..self.app_map_count]) |m| {
            if (!std.mem.eql(u8, m.getAppName(), app_name)) {
                self.app_map[write_idx] = m;
                write_idx += 1;
            }
        }
        self.app_map_count = write_idx;
        self.saveState();
    }

    /// Increment app count for an account
    pub fn incrementAppCount(self: *Self, account_id: u8) void {
        for (self.accounts[0..self.account_count]) |*acct| {
            if (acct.id == account_id) {
                acct.active_apps += 1;
                acct.daily_creates += 1;
                break;
            }
        }
        self.saveState();
    }

    /// Aggregate capacity across all accounts.
    pub fn totalCapacity(self: *Self) FarmCapacity {
        var cap = FarmCapacity{
            .total_slots = 0,
            .total_active = 0,
            .total_daily_remaining = 0,
            .account_count = self.account_count,
        };

        for (self.accounts[0..self.account_count]) |*acct| {
            cap.total_slots += acct.availableSlots();
            cap.total_active += acct.active_apps;
            cap.total_daily_remaining += acct.max_daily_creates -| acct.daily_creates;
        }
        return cap;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // State persistence
    // ═══════════════════════════════════════════════════════════════════════════

    fn loadState(self: *Self) void {
        if (self.state_loaded) return;
        self.state_loaded = true;

        const file = std.fs.cwd().openFile(FARM_STATE_FILE, .{}) catch return;
        defer file.close();

        var buf: [16384]u8 = undefined;
        const len = file.readAll(&buf) catch return;
        const content = buf[0..len];

        // Parse account daily_creates from saved state
        var offset: usize = 0;
        while (std.mem.indexOfPos(u8, content, offset, "\"account_id\":")) |idx| {
            const id_start = idx + 13;
            var id_end = id_start;
            while (id_end < content.len and content[id_end] >= '0' and content[id_end] <= '9') : (id_end += 1) {}
            const acct_id = std.fmt.parseInt(u8, content[id_start..id_end], 10) catch break;

            if (std.mem.indexOfPos(u8, content, id_end, "\"daily_creates\":")) |dc_idx| {
                const dc_start = dc_idx + 16;
                var dc_end = dc_start;
                while (dc_end < content.len and content[dc_end] >= '0' and content[dc_end] <= '9') : (dc_end += 1) {}
                const daily = std.fmt.parseInt(u16, content[dc_start..dc_end], 10) catch 0;

                for (self.accounts[0..self.account_count]) |*acct| {
                    if (acct.id == acct_id) {
                        acct.daily_creates = daily;
                        break;
                    }
                }
                offset = dc_end;
            } else {
                offset = id_end;
            }
        }

        // Parse app_map
        offset = 0;
        self.app_map_count = 0;
        const map_section = std.mem.indexOf(u8, content, "\"app_map\":");
        if (map_section) |ms| {
            offset = ms;
            while (self.app_map_count < MAX_APPS) {
                const name_needle = "\"app_name\":\"";
                const name_idx = std.mem.indexOfPos(u8, content, offset, name_needle) orelse break;
                const name_start = name_idx + name_needle.len;
                const name_end = std.mem.indexOfPos(u8, content, name_start, "\"") orelse break;
                const app_name = content[name_start..name_end];

                const aid_needle = "\"account_id\":";
                const aid_idx = std.mem.indexOfPos(u8, content, name_end, aid_needle) orelse break;
                const aid_start = aid_idx + aid_needle.len;
                var aid_end = aid_start;
                while (aid_end < content.len and content[aid_end] >= '0' and content[aid_end] <= '9') : (aid_end += 1) {}
                const aid = std.fmt.parseInt(u8, content[aid_start..aid_end], 10) catch break;

                var entry = &self.app_map[self.app_map_count];
                entry.app_name_len = @min(app_name.len, 64);
                @memcpy(entry.app_name[0..entry.app_name_len], app_name[0..entry.app_name_len]);
                entry.account_id = aid;
                self.app_map_count += 1;
                offset = aid_end + 1;
            }
        }
    }

    pub fn saveState(self: *Self) void {
        std.fs.cwd().makePath(".trinity") catch return;

        var buf: [16384]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const w = fbs.writer();

        w.writeAll("{\"accounts\":[") catch return;
        var first = true;
        for (self.accounts[0..self.account_count]) |*acct| {
            if (!first) w.writeAll(",") catch return;
            first = false;
            std.fmt.format(w, "\n  {{\"account_id\":{d},\"alias\":\"{s}\",\"daily_creates\":{d},\"active_apps\":{d},\"daily_reset_epoch\":{d}}}", .{
                acct.id,
                acct.getAlias(),
                acct.daily_creates,
                acct.active_apps,
                acct.daily_reset_epoch,
            }) catch return;
        }

        w.writeAll("\n],\"app_map\":[") catch return;
        first = true;
        for (self.app_map[0..self.app_map_count]) |*m| {
            if (!first) w.writeAll(",") catch return;
            first = false;
            std.fmt.format(w, "\n  {{\"app_name\":\"{s}\",\"account_id\":{d}}}", .{
                m.getAppName(),
                m.account_id,
            }) catch return;
        }
        w.writeAll("\n]}\n") catch return;

        const file = std.fs.cwd().createFile(FARM_STATE_FILE, .{}) catch return;
        defer file.close();
        file.writeAll(fbs.getWritten()) catch return;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FlyAccount availableSlots" {
    var acct = FlyAccount{
        .id = 1,
        .alias = undefined,
        .alias_len = 11,
        .env_suffix = undefined,
        .env_suffix_len = 0,
        .daily_creates = 10,
        .daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400,
        .active_apps = 1,
        .max_concurrent = 3,
        .max_daily_creates = 50,
    };
    @memcpy(acct.alias[0..11], "fly-primary");

    try std.testing.expectEqual(@as(u16, 2), acct.availableSlots()); // min(2, 40) = 2
}

test "FlyAccount canSpawn at limit" {
    var acct = FlyAccount{
        .id = 1,
        .alias = undefined,
        .alias_len = 11,
        .env_suffix = undefined,
        .env_suffix_len = 0,
        .daily_creates = 50,
        .daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400,
        .active_apps = 0,
        .max_concurrent = 3,
        .max_daily_creates = 50,
    };
    @memcpy(acct.alias[0..11], "fly-primary");

    try std.testing.expect(!acct.canSpawn());
}
