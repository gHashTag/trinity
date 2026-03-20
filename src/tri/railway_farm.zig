// @origin(spec:railway_farm.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// RAILWAY FARM — Multi-Account Scheduler & Capacity Tracker
// ═══════════════════════════════════════════════════════════════════════════════
//
// Manages multiple Railway accounts for parallel agent spawning.
// Auto-detects accounts from env vars: RAILWAY_API_TOKEN, _2, _3
// State persisted to .trinity/railway_farm.json
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const circuit_breaker = @import("railway_circuit_breaker.zig");

const FARM_STATE_FILE = ".trinity/railway_farm.json";
pub const MAX_ACCOUNTS: usize = 8;
const MAX_AGENTS: usize = 100;

pub const RailwayAccount = struct {
    id: u8, // 1, 2, 3...
    alias: [32]u8,
    alias_len: usize,
    env_suffix: [8]u8, // "", "_2", "_3"
    env_suffix_len: usize,
    daily_creates: u16,
    daily_reset_epoch: i64, // day boundary (epoch/86400 * 86400)
    active_services: u16,
    max_concurrent: u16, // 10 per account
    max_daily_creates: u16, // 25 per account

    // Circuit Breaker health tracking (optional, for smart routing)
    health: ?circuit_breaker.AccountHealth = null,

    pub fn canSpawn(self: *const RailwayAccount) bool {
        const now_day = @divTrunc(std.time.timestamp(), 86400) * 86400;
        var mutable = @constCast(self);
        if (now_day > self.daily_reset_epoch) {
            mutable.daily_creates = 0;
            mutable.daily_reset_epoch = now_day;
        }
        return self.active_services < self.max_concurrent and
            self.daily_creates < self.max_daily_creates;
    }

    pub fn availableSlots(self: *const RailwayAccount) u16 {
        const concurrent_left = self.max_concurrent -| self.active_services;
        const daily_left = self.max_daily_creates -| self.daily_creates;
        return @min(concurrent_left, daily_left);
    }

    pub fn getAlias(self: *const RailwayAccount) []const u8 {
        return self.alias[0..self.alias_len];
    }

    pub fn getSuffix(self: *const RailwayAccount) []const u8 {
        return self.env_suffix[0..self.env_suffix_len];
    }
};

pub const AgentMapping = struct {
    issue: u32,
    account_id: u8,
    service_id: [128]u8,
    service_id_len: usize,

    pub fn getServiceId(self: *const AgentMapping) []const u8 {
        return self.service_id[0..self.service_id_len];
    }
};

pub const FarmCapacity = struct {
    total_slots: u16,
    total_active: u16,
    total_daily_remaining: u16,
    account_count: u8,
};

pub const SpawnResult = struct {
    service_id_buf: [128]u8 = undefined,
    service_id_len: usize = 0,
    account_id: u8,
    status: enum { spawned, rate_limited, all_exhausted },

    pub fn getServiceId(self: *const SpawnResult) []const u8 {
        return self.service_id_buf[0..self.service_id_len];
    }
};

pub const RailwayFarm = struct {
    accounts: [MAX_ACCOUNTS]RailwayAccount,
    account_count: u8,
    agent_map: [MAX_AGENTS]AgentMapping,
    agent_map_count: usize,
    state_loaded: bool,

    const Self = @This();

    /// Detect accounts from environment variables.
    /// Checks RAILWAY_API_TOKEN, RAILWAY_API_TOKEN_2, ..._3, etc.
    pub fn init() RailwayFarm {
        var farm = RailwayFarm{
            .accounts = undefined,
            .account_count = 0,
            .agent_map = undefined,
            .agent_map_count = 0,
            .state_loaded = false,
        };

        // Check primary account (no suffix)
        farm.tryAddAccount(1, "primary", "");

        // Check accounts 2-8
        const suffixes = [_][]const u8{ "_2", "_3", "_4", "_5", "_6", "_7", "_8" };
        const aliases = [_][]const u8{ "farm-2", "farm-3", "farm-4", "farm-5", "farm-6", "farm-7", "farm-8" };
        for (suffixes, aliases, 2..) |suffix, alias, idx| {
            farm.tryAddAccount(@intCast(idx), alias, suffix);
        }

        farm.loadState();
        // Initialize Circuit Breaker health tracking
        farm.initHealthTracking();
        return farm;
    }

    fn tryAddAccount(self: *Self, id: u8, alias: []const u8, suffix: []const u8) void {
        // Check if the token env var exists
        var key_buf: [64]u8 = undefined;
        const base = "RAILWAY_API_TOKEN";
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
        account.active_services = 0;
        account.max_concurrent = 25; // Railway PRO allows 100/project, 25 conservative
        account.max_daily_creates = 50; // PRO has no documented daily limit
        self.account_count += 1;
    }

    /// Select least-loaded account that can spawn.
    pub fn selectAccount(self: *Self) ?*RailwayAccount {
        var best: ?*RailwayAccount = null;
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

    /// Select best account using Circuit Breaker health scoring.
    /// Returns account with highest health score that can spawn.
    /// Falls back to selectAccount() if health tracking not initialized.
    pub fn selectHealthyAccount(self: *Self) ?*RailwayAccount {
        const now = std.time.timestamp();

        // Build AccountHealth array for selectBest()
        var health_accounts: [MAX_ACCOUNTS]circuit_breaker.AccountHealth = undefined;
        var health_count: usize = 0;

        for (self.accounts[0..self.account_count]) |*acct| {
            if (acct.health) |*h| {
                // Update circuit state based on current time
                _ = h.circuit.canUse(now);
                health_accounts[health_count] = h.*;
                health_count += 1;
            }
        }

        if (health_count == 0) {
            // No health tracking initialized, fallback to simple selection
            return self.selectAccount();
        }

        // Use circuit breaker to select best
        const best_health = circuit_breaker.selectBest(health_accounts[0..health_count], now) orelse {
            // All accounts exhausted, fallback to simple selection
            return self.selectAccount();
        };

        // Find corresponding RailwayAccount
        for (self.accounts[0..self.account_count]) |*acct| {
            if (acct.health) |*h| {
                if (std.mem.eql(u8, h.name, best_health.name)) {
                    return acct;
                }
            }
        }

        return self.selectAccount();
    }

    /// Initialize Circuit Breaker health tracking for all accounts.
    /// Call once during farm initialization.
    pub fn initHealthTracking(self: *Self) void {
        for (self.accounts[0..self.account_count]) |*acct| {
            acct.health = circuit_breaker.AccountHealth{
                .name = acct.getAlias(),
            };
        }
    }

    /// Record API call result in Circuit Breaker health tracking.
    /// Call after each Railway API request.
    pub fn recordApiResult(self: *Self, account_id: u8, latency_ms: u32, success: bool) void {
        const now = std.time.timestamp();
        for (self.accounts[0..self.account_count]) |*acct| {
            if (acct.id == account_id) {
                if (acct.health) |*h| {
                    h.record(latency_ms, success, now);
                }
                break;
            }
        }
    }

    /// Get a RailwayApi client for the given account ID.
    pub fn getApi(self: *Self, allocator: Allocator, account_id: u8) !railway_api.RailwayApi {
        for (self.accounts[0..self.account_count]) |*acct| {
            if (acct.id == account_id) {
                return railway_api.RailwayApi.initWithSuffix(allocator, acct.getSuffix());
            }
        }
        return error.MissingToken;
    }

    /// Get API client for the account owning a specific issue.
    pub fn getApiForIssue(self: *Self, allocator: Allocator, issue: u32) !railway_api.RailwayApi {
        for (self.agent_map[0..self.agent_map_count]) |*m| {
            if (m.issue == issue) {
                return self.getApi(allocator, m.account_id);
            }
        }
        // Fallback to primary
        return railway_api.RailwayApi.init(allocator);
    }

    /// Get account ID for an issue (or null).
    pub fn getAccountForIssue(self: *Self, issue: u32) ?u8 {
        for (self.agent_map[0..self.agent_map_count]) |*m| {
            if (m.issue == issue) return m.account_id;
        }
        return null;
    }

    /// Record an agent-to-account mapping.
    pub fn recordAgent(self: *Self, issue: u32, account_id: u8, service_id: []const u8) void {
        if (self.agent_map_count >= MAX_AGENTS) return;
        var entry = &self.agent_map[self.agent_map_count];
        entry.issue = issue;
        entry.account_id = account_id;
        entry.service_id_len = @min(service_id.len, 128);
        @memcpy(entry.service_id[0..entry.service_id_len], service_id[0..entry.service_id_len]);
        self.agent_map_count += 1;
        self.saveState();
    }

    /// Remove agent mapping for an issue.
    pub fn removeAgent(self: *Self, issue: u32) void {
        var write_idx: usize = 0;
        for (self.agent_map[0..self.agent_map_count]) |m| {
            if (m.issue != issue) {
                self.agent_map[write_idx] = m;
                write_idx += 1;
            }
        }
        self.agent_map_count = write_idx;
        self.saveState();
    }

    /// Spawn with auto-failover across accounts using Circuit Breaker health scoring.
    pub fn spawnWithFailover(self: *Self, allocator: Allocator, issue: u32, service_name: []const u8) !SpawnResult {
        var tried = [_]bool{false} ** (MAX_ACCOUNTS + 1);

        while (true) {
            // Use Circuit Breaker health scoring for account selection
            const account = self.selectHealthyAccount() orelse return SpawnResult{
                .account_id = 0,
                .status = .all_exhausted,
            };

            if (tried[account.id]) return SpawnResult{
                .account_id = 0,
                .status = .all_exhausted,
            };
            tried[account.id] = true;

            var api = self.getApi(allocator, account.id) catch continue;
            defer api.deinit();

            // Measure latency for Circuit Breaker
            const start = std.time.nanoTimestamp();

            const response = api.createService(service_name) catch {
                // Rate limited or daily cap — mark full, try next
                const end_fail = std.time.nanoTimestamp();
                const latency_fail = @as(u32, @intCast((end_fail - start) / 1_000_000));
                self.recordApiResult(account.id, latency_fail, false);

                account.daily_creates = account.max_daily_creates;
                self.saveState();
                continue;
            };
            defer allocator.free(response);

            // Extract service ID
            const service_id = extractId(response) orelse continue;

            account.daily_creates += 1;
            account.active_services += 1;
            self.recordAgent(issue, account.id, service_id);

            // Record success in Circuit Breaker
            const end = std.time.nanoTimestamp();
            const latency_ms = @as(u32, @intCast((end - start) / 1_000_000));
            self.recordApiResult(account.id, latency_ms, true);
            self.saveState();

            var result = SpawnResult{
                .account_id = account.id,
                .status = .spawned,
            };
            const copy_len = @min(service_id.len, result.service_id_buf.len);
            @memcpy(result.service_id_buf[0..copy_len], service_id[0..copy_len]);
            result.service_id_len = copy_len;
            return result;
        }
    }

    /// Sync active service counts from Railway APIs.
    pub fn syncAll(self: *Self, allocator: Allocator) void {
        for (self.accounts[0..self.account_count]) |*acct| {
            var api = self.getApi(allocator, acct.id) catch continue;
            defer api.deinit();

            const response = api.getServices() catch continue;
            defer allocator.free(response);

            // Count services by counting "name":" occurrences
            var count: u16 = 0;
            var offset: usize = 0;
            while (std.mem.indexOfPos(u8, response, offset, "\"name\":\"")) |idx| {
                count += 1;
                offset = idx + 8;
            }
            acct.active_services = count;
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
            cap.total_active += acct.active_services;
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

            // Find daily_creates for this account
            if (std.mem.indexOfPos(u8, content, id_end, "\"daily_creates\":")) |dc_idx| {
                const dc_start = dc_idx + 16;
                var dc_end = dc_start;
                while (dc_end < content.len and content[dc_end] >= '0' and content[dc_end] <= '9') : (dc_end += 1) {}
                const daily = std.fmt.parseInt(u16, content[dc_start..dc_end], 10) catch 0;

                // Find matching account and update
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

        // Parse agent_map
        offset = 0;
        self.agent_map_count = 0;
        const map_section = std.mem.indexOf(u8, content, "\"agent_map\":");
        if (map_section) |ms| {
            offset = ms;
            while (self.agent_map_count < MAX_AGENTS) {
                const issue_needle = "\"issue\":";
                const issue_idx = std.mem.indexOfPos(u8, content, offset, issue_needle) orelse break;
                const issue_start = issue_idx + issue_needle.len;
                var issue_end = issue_start;
                while (issue_end < content.len and content[issue_end] >= '0' and content[issue_end] <= '9') : (issue_end += 1) {}
                const issue_num = std.fmt.parseInt(u32, content[issue_start..issue_end], 10) catch break;

                const aid_needle = "\"account_id\":";
                const aid_idx = std.mem.indexOfPos(u8, content, issue_end, aid_needle) orelse break;
                const aid_start = aid_idx + aid_needle.len;
                var aid_end = aid_start;
                while (aid_end < content.len and content[aid_end] >= '0' and content[aid_end] <= '9') : (aid_end += 1) {}
                const aid = std.fmt.parseInt(u8, content[aid_start..aid_end], 10) catch break;

                const sid_needle = "\"service_id\":\"";
                const sid_idx = std.mem.indexOfPos(u8, content, aid_end, sid_needle) orelse break;
                const sid_start = sid_idx + sid_needle.len;
                const sid_end = std.mem.indexOfPos(u8, content, sid_start, "\"") orelse break;
                const sid = content[sid_start..sid_end];

                var entry = &self.agent_map[self.agent_map_count];
                entry.issue = issue_num;
                entry.account_id = aid;
                entry.service_id_len = @min(sid.len, 128);
                @memcpy(entry.service_id[0..entry.service_id_len], sid[0..entry.service_id_len]);
                self.agent_map_count += 1;
                offset = sid_end + 1;
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
            std.fmt.format(w, "\n  {{\"account_id\":{d},\"alias\":\"{s}\",\"daily_creates\":{d},\"active_services\":{d},\"daily_reset_epoch\":{d}}}", .{
                acct.id,
                acct.getAlias(),
                acct.daily_creates,
                acct.active_services,
                acct.daily_reset_epoch,
            }) catch return;
        }

        w.writeAll("\n],\"agent_map\":[") catch return;
        first = true;
        for (self.agent_map[0..self.agent_map_count]) |*m| {
            if (!first) w.writeAll(",") catch return;
            first = false;
            std.fmt.format(w, "\n  {{\"issue\":{d},\"account_id\":{d},\"service_id\":\"{s}\"}}", .{
                m.issue,
                m.account_id,
                m.getServiceId(),
            }) catch return;
        }
        w.writeAll("\n]}\n") catch return;

        const file = std.fs.cwd().createFile(FARM_STATE_FILE, .{}) catch return;
        defer file.close();
        file.writeAll(fbs.getWritten()) catch return;
    }
};

fn extractId(json: []const u8) ?[]const u8 {
    const needle = "\"id\":\"";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    const end = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RailwayAccount availableSlots" {
    var acct = RailwayAccount{
        .id = 1,
        .alias = undefined,
        .alias_len = 7,
        .env_suffix = undefined,
        .env_suffix_len = 0,
        .daily_creates = 10,
        .daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400,
        .active_services = 3,
        .max_concurrent = 10,
        .max_daily_creates = 25,
    };
    @memcpy(acct.alias[0..7], "primary");

    try std.testing.expectEqual(@as(u16, 7), acct.availableSlots());
}

test "RailwayAccount canSpawn at limit" {
    var acct = RailwayAccount{
        .id = 1,
        .alias = undefined,
        .alias_len = 7,
        .env_suffix = undefined,
        .env_suffix_len = 0,
        .daily_creates = 25,
        .daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400,
        .active_services = 0,
        .max_concurrent = 10,
        .max_daily_creates = 25,
    };
    @memcpy(acct.alias[0..7], "primary");

    try std.testing.expect(!acct.canSpawn());
}

test "FarmCapacity aggregate" {
    var farm = RailwayFarm{
        .accounts = undefined,
        .account_count = 0,
        .agent_map = undefined,
        .agent_map_count = 0,
        .state_loaded = true,
    };

    // Manually add 2 test accounts
    farm.accounts[0] = RailwayAccount{
        .id = 1,
        .alias = undefined,
        .alias_len = 7,
        .env_suffix = undefined,
        .env_suffix_len = 0,
        .daily_creates = 5,
        .daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400,
        .active_services = 3,
        .max_concurrent = 10,
        .max_daily_creates = 25,
    };
    @memcpy(farm.accounts[0].alias[0..7], "primary");

    farm.accounts[1] = RailwayAccount{
        .id = 2,
        .alias = undefined,
        .alias_len = 6,
        .env_suffix = undefined,
        .env_suffix_len = 2,
        .daily_creates = 0,
        .daily_reset_epoch = @divTrunc(std.time.timestamp(), 86400) * 86400,
        .active_services = 0,
        .max_concurrent = 10,
        .max_daily_creates = 25,
    };
    @memcpy(farm.accounts[1].alias[0..6], "farm-2");
    @memcpy(farm.accounts[1].env_suffix[0..2], "_2");

    farm.account_count = 2;

    const cap = farm.totalCapacity();
    try std.testing.expectEqual(@as(u8, 2), cap.account_count);
    try std.testing.expectEqual(@as(u16, 3), cap.total_active);
    try std.testing.expectEqual(@as(u16, 17), cap.total_slots); // 7 + 10
}
