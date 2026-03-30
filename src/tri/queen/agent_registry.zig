//! Agent Registry — Track all 27 agents, their health, and capabilities
//!
//! Queen (Omega) maintains a registry of all agents in the 27-agent grid.
//! Agents register on startup, send heartbeats, and can be queried for status.
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const AgentStatus = enum {
    online,
    offline,
    degraded,
    busy,
};

pub const AgentInfo = struct {
    domain: []const u8,
    port: u16,
    status: AgentStatus,
    last_heartbeat: i64,
    capabilities: [][]const u8,
    started_at: i64,
    task_count: u32 = 0,

    /// Check if agent is healthy (heartbeat within 60 seconds)
    pub fn isHealthy(self: *const AgentInfo) bool {
        const now = std.time.timestamp();
        const elapsed = now - self.last_heartbeat;
        return elapsed < 60;
    }

    /// Get time since last heartbeat in seconds
    pub fn secondsSinceHeartbeat(self: *const AgentInfo) i64 {
        const now = std.time.timestamp();
        return now - self.last_heartbeat;
    }
};

pub const AgentRegistry = struct {
    allocator: std.mem.Allocator,
    agents: std.StringHashMap(*AgentInfo),
    mutex: std.Thread.Mutex,

    /// Initialize empty registry
    pub fn init(allocator: std.mem.Allocator) AgentRegistry {
        return AgentRegistry{
            .allocator = allocator,
            .agents = std.StringHashMap(*AgentInfo).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    /// Deinitialize registry
    pub fn deinit(self: *AgentRegistry) void {
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr.*;
            self.allocator.free(info.domain);
            for (info.capabilities) |cap| {
                self.allocator.free(cap);
            }
            self.allocator.free(info.capabilities);
            self.allocator.destroy(info);
        }
        self.agents.deinit();
    }

    /// Register a new agent or update existing
    pub fn register(self: *AgentRegistry, domain: []const u8, port: u16, capabilities: [][]const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();

        // Check if agent already exists
        if (self.agents.get(domain)) |existing| {
            // Update existing agent
            existing.*.port = port;
            existing.*.status = .online;
            existing.*.last_heartbeat = now;

            // Update capabilities
            for (existing.*.capabilities) |cap| {
                self.allocator.free(cap);
            }
            self.allocator.free(existing.*.capabilities);
            existing.*.capabilities = capabilities;
            return;
        }

        // Create new agent info
        const info = try self.allocator.create(AgentInfo);
        info.* = AgentInfo{
            .domain = try self.allocator.dupe(u8, domain),
            .port = port,
            .status = .online,
            .last_heartbeat = now,
            .started_at = now,
            .capabilities = capabilities,
        };

        try self.agents.put(info.domain, info);
    }

    /// Process heartbeat from agent
    pub fn heartbeat(self: *AgentRegistry, domain: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.agents.get(domain)) |info| {
            info.*.last_heartbeat = std.time.timestamp();
            info.*.status = .online;
            return true;
        }
        return false;
    }

    /// Update agent status
    pub fn setStatus(self: *AgentRegistry, domain: []const u8, status: AgentStatus) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.agents.get(domain)) |info| {
            info.*.status = status;
        }
    }

    /// Increment agent task counter
    pub fn incrementTaskCount(self: *AgentRegistry, domain: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.agents.get(domain)) |info| {
            info.*.task_count += 1;
        }
    }

    /// Get agent info by domain
    pub fn getAgent(self: *AgentRegistry, domain: []const u8) ?*AgentInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.agents.get(domain);
    }

    /// Get list of all agent domains
    pub fn getAllDomains(self: *AgentRegistry) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var domains = try std.ArrayList([]const u8).initCapacity(self.allocator, self.agents.count());
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            try domains.append(entry.key_ptr.*);
        }
        return domains.toOwnedSlice();
    }

    /// Get list of online agents
    pub fn getOnlineAgents(self: *AgentRegistry) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.status == .online and entry.value_ptr.*.isHealthy()) {
                try list.append(self.allocator, entry.key_ptr.*);
            }
        }
        return list.toOwnedSlice(self.allocator);
    }

    /// Get list of offline/failed agents
    pub fn getOfflineAgents(self: *AgentRegistry) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.*.isHealthy()) {
                try list.append(self.allocator, entry.key_ptr.*);
            }
        }
        return list.toOwnedSlice(self.allocator);
    }

    /// Get agents with specific capability
    pub fn getAgentsWithCapability(self: *AgentRegistry, capability: []const u8) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.*.capabilities) |cap| {
                if (std.mem.eql(u8, cap, capability)) {
                    try list.append(self.allocator, entry.key_ptr.*);
                    break;
                }
            }
        }
        return list.toOwnedSlice(self.allocator);
    }

    /// Get least busy agent (by task count)
    pub fn getLeastBusyAgent(self: *AgentRegistry) !?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.agents.count() == 0) return null;

        var min_tasks: u32 = std.math.maxInt(u32);
        var best_agent: ?[]const u8 = null;

        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr.*;
            if (info.status == .online and info.isHealthy() and info.task_count < min_tasks) {
                min_tasks = info.task_count;
                best_agent = info.domain;
            }
        }

        return best_agent;
    }

    /// Get registry statistics
    pub const RegistryStats = struct {
        total_agents: usize,
        online_agents: usize,
        offline_agents: usize,
        busy_agents: usize,
        total_tasks: u64,
    };

    pub fn getStats(self: *AgentRegistry) RegistryStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var stats = RegistryStats{
            .total_agents = self.agents.count(),
            .online_agents = 0,
            .offline_agents = 0,
            .busy_agents = 0,
            .total_tasks = 0,
        };

        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr.*;
            stats.total_tasks += info.task_count;

            if (info.isHealthy()) {
                if (info.status == .busy) {
                    stats.busy_agents += 1;
                } else {
                    stats.online_agents += 1;
                }
            } else {
                stats.offline_agents += 1;
            }
        }

        return stats;
    }

    /// Export registry as JSON
    pub fn toJson(self: *AgentRegistry) ![]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var json_buffer = std.ArrayList(u8).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        const writer = json_buffer.writer();

        try writer.writeAll("{\"agents\":[");

        var first = true;
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr.*;

            if (!first) try writer.writeAll(",");
            first = false;

            try writer.print(
                "{{\"domain\":\"{s}\",\"port\":{d},\"status\":\"{s}\",\"last_heartbeat\":{d},\"task_count\":{d}}}",
                .{
                    info.domain,
                    info.port,
                    @tagName(info.status),
                    info.last_heartbeat,
                    info.task_count,
                });
        }

        try writer.writeAll("]}");
        return json_buffer.toOwnedSlice();
    }

    /// Prune agents that haven't sent heartbeat in 5 minutes
    pub fn pruneStaleAgents(self: *AgentRegistry) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var stale_domains = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch return error.OutOfMemory;

        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr.*;
            if (now - info.last_heartbeat > 300) {
                try stale_domains.append(info.domain);
            }
        }

        for (stale_domains.items) |domain| {
            if (self.agents.fetchRemove(domain)) |removed| {
                const info = removed.value;
                self.allocator.free(info.domain);
                for (info.capabilities) |cap| {
                    self.allocator.free(cap);
                }
                self.allocator.free(info.capabilities);
                self.allocator.destroy(info);
            }
        }

        return stale_domains.items.len;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Agent Registry — register and heartbeat" {
    const allocator = std.testing.allocator;
    var registry = AgentRegistry.init(allocator);
    defer registry.deinit();

    // Register agent
    var capabilities = try allocator.alloc([]const u8, 2);
    capabilities[0] = try allocator.dupe(u8, "generic");
    capabilities[1] = try allocator.dupe(u8, "heartbeat");

    try registry.register("alpha", 9001, capabilities);

    // Check agent is registered
    const agent = registry.getAgent("alpha").?;
    try std.testing.expectEqual(@as(u16, 9001), agent.port);
    try std.testing.expectEqual(AgentStatus.online, agent.status);

    // Send heartbeat
    const result = try registry.heartbeat("alpha");
    try std.testing.expect(result);
}

test "Agent Registry — get online agents" {
    const allocator = std.testing.allocator;
    var registry = AgentRegistry.init(allocator);
    defer registry.deinit();

    // Register multiple agents
    var caps1 = try allocator.alloc([]const u8, 1);
    caps1[0] = try allocator.dupe(u8, "generic");
    try registry.register("alpha", 9001, caps1);

    var caps2 = try allocator.alloc([]const u8, 1);
    caps2[0] = try allocator.dupe(u8, "generic");
    try registry.register("beta", 9002, caps2);

    // Get online agents
    const online = try registry.getOnlineAgents();
    defer allocator.free(online);
    try std.testing.expectEqual(@as(usize, 2), online.len);
}

test "Agent Registry — statistics" {
    const allocator = std.testing.allocator;
    var registry = AgentRegistry.init(allocator);
    defer registry.deinit();

    var caps = try allocator.alloc([]const u8, 1);
    caps[0] = try allocator.dupe(u8, "generic");
    try registry.register("alpha", 9001, caps);

    try registry.incrementTaskCount("alpha");

    const stats = registry.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_agents);
    try std.testing.expectEqual(@as(usize, 1), stats.online_agents);
    try std.testing.expectEqual(@as(u64, 1), stats.total_tasks);
}
