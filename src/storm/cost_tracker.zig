//! STORM P5 — Cost Tracking
//! API tokens, CPU time, memory, network usage accounting
//! Supports per-agent and aggregate cost reporting

const std = @import("std");

pub const Cost = struct {
    api_tokens: u64 = 0,
    cpu_ms: u64 = 0,
    memory_mb: u64 = 0,
    network_bytes: u64 = 0,
    gpu_ms: u64 = 0,
    fpga_ops: u64 = 0,
};

pub const CostThresholds = struct {
    max_api_tokens: u64 = 1_000_000, // 1M tokens
    max_cpu_ms: u64 = 3_600_000, // 1 hour
    max_memory_mb: u64 = 8_192, // 8 GB
    max_network_bytes: u64 = 1_073_741_824, // 1 GB
    alert_at_percent: u8 = 80, // Alert at 80% of max
};

pub const CostReport = struct {
    total: Cost,
    per_agent: std.StringHashMap(Cost),
    exceeded_thresholds: [][]const u8,
    alert_triggered: bool = false,
};

pub const CostTracker = struct {
    allocator: std.mem.Allocator,
    costs: std.StringHashMap(Cost),
    thresholds: CostThresholds,
    start_time_ns: i64,

    pub fn init(allocator: std.mem.Allocator) !CostTracker {
        const now = std.time.nanoTimestamp();
        const costs = std.StringHashMap(Cost).init(allocator);
        return .{
            .allocator = allocator,
            .costs = costs,
            .thresholds = .{},
            .start_time_ns = @intCast(now),
        };
    }

    pub fn deinit(self: *CostTracker) void {
        var iter = self.costs.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.costs.deinit();
    }

    /// Track cost for an agent
    pub fn track(self: *CostTracker, agent_id: []const u8, cost: Cost) !void {
        // Clone agent_id for hashmap key
        const key = try self.allocator.dupe(u8, agent_id);
        errdefer self.allocator.free(key);

        // Get existing cost or create new
        const entry = try self.costs.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{};
        }

        // Accumulate costs
        entry.value_ptr.*.api_tokens += cost.api_tokens;
        entry.value_ptr.*.cpu_ms += cost.cpu_ms;
        entry.value_ptr.*.memory_mb += cost.memory_mb;
        entry.value_ptr.*.network_bytes += cost.network_bytes;
        entry.value_ptr.*.gpu_ms += cost.gpu_ms;
        entry.value_ptr.*.fpga_ops += cost.fpga_ops;
    }

    /// Get total cost across all agents
    pub fn getTotal(self: *const CostTracker) Cost {
        var total = Cost{};
        var iter = self.costs.iterator();
        while (iter.next()) |entry| {
            total.api_tokens += entry.value_ptr.*.api_tokens;
            total.cpu_ms += entry.value_ptr.*.cpu_ms;
            total.memory_mb = @max(total.memory_mb, entry.value_ptr.*.memory_mb); // Peak memory
            total.network_bytes += entry.value_ptr.*.network_bytes;
            total.gpu_ms += entry.value_ptr.*.gpu_ms;
            total.fpga_ops += entry.value_ptr.*.fpga_ops;
        }
        return total;
    }

    /// Get cost for specific agent
    pub fn getAgentCost(self: *const CostTracker, agent_id: []const u8) ?Cost {
        if (self.costs.get(agent_id)) |cost| {
            return cost;
        }
        return null;
    }

    /// Get agent count
    pub fn getAgentCount(self: *const CostTracker) usize {
        return self.costs.count();
    }

    /// Get elapsed time since tracker start
    pub fn getElapsedTimeMs(self: *const CostTracker) u64 {
        const now = std.time.nanoTimestamp();
        return @as(u64, @intFromFloat(@divTrunc(@as(f128, @floatFromInt(now - self.start_time_ns)), 1_000_000)));
    }

    /// Generate comprehensive cost report
    pub fn getReport(self: *CostTracker) !CostReport {
        var report = CostReport{
            .total = self.getTotal(),
            .per_agent = std.StringHashMap(Cost).init(self.allocator),
            .exceeded_thresholds = try self.allocator.alloc([]const u8, 0),
            .alert_triggered = false,
        };
        errdefer report.exceeded_thresholds.deinit(self.allocator);
        errdefer {
            var iter = report.per_agent.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            report.per_agent.deinit();
        }

        // Copy per-agent costs
        var iter = self.costs.iterator();
        while (iter.next()) |entry| {
            const key = try self.allocator.dupe(u8, entry.key_ptr.*);
            try report.per_agent.put(key, entry.value_ptr.*);
        }

        // Check thresholds
        if (report.total.api_tokens > self.thresholds.max_api_tokens) {
            try report.exceeded_thresholds.append(self.allocator, "API tokens exceeded");
            report.alert_triggered = true;
        }
        if (report.total.cpu_ms > self.thresholds.max_cpu_ms) {
            try report.exceeded_thresholds.append(self.allocator, "CPU time exceeded");
            report.alert_triggered = true;
        }
        if (report.total.memory_mb > self.thresholds.max_memory_mb) {
            try report.exceeded_thresholds.append(self.allocator, "Memory exceeded");
            report.alert_triggered = true;
        }
        if (report.total.network_bytes > self.thresholds.max_network_bytes) {
            try report.exceeded_thresholds.append(self.allocator, "Network exceeded");
            report.alert_triggered = true;
        }

        return report;
    }

    /// Print summary to stdout
    pub fn printSummary(self: *const CostTracker) !void {
        const total = self.getTotal();
        const elapsed = self.getElapsedTimeMs();

        std.debug.print("\n💰 COST TRACKING SUMMARY\n", .{});
        std.debug.print("═══════════════════════════════\n", .{});

        std.debug.print("Total API tokens: {d}\n", .{total.api_tokens});
        std.debug.print("Total CPU time: {d:.1}s\n", .{@as(f64, @floatFromInt(total.cpu_ms)) / 1000.0});
        std.debug.print("Peak memory: {d} MB\n", .{total.memory_mb});
        std.debug.print("Total network: {d:.2} MB\n", .{@as(f64, @floatFromInt(total.network_bytes)) / 1_048_576.0});
        if (total.gpu_ms > 0) {
            std.debug.print("GPU time: {d:.1}s\n", .{@as(f64, @floatFromInt(total.gpu_ms)) / 1000.0});
        }
        if (total.fpga_ops > 0) {
            std.debug.print("FPGA ops: {d}\n", .{total.fpga_ops});
        }
        std.debug.print("Elapsed time: {d:.1}s\n", .{@as(f64, @floatFromInt(elapsed)) / 1000.0});
        std.debug.print("Active agents: {d}\n", .{self.getAgentCount()});
    }

    /// Check if alert threshold exceeded
    pub fn checkAlert(self: *const CostTracker) bool {
        const total = self.getTotal();
        const alert_at_tokens = (self.thresholds.max_api_tokens * self.thresholds.alert_at_percent) / 100;
        const alert_at_cpu = (self.thresholds.max_cpu_ms * self.thresholds.alert_at_percent) / 100;
        const alert_at_memory = (self.thresholds.max_memory_mb * self.thresholds.alert_at_percent) / 100;
        const alert_at_network = (self.thresholds.max_network_bytes * self.thresholds.alert_at_percent) / 100;

        return total.api_tokens >= alert_at_tokens or
            total.cpu_ms >= alert_at_cpu or
            total.memory_mb >= alert_at_memory or
            total.network_bytes >= alert_at_network;
    }

    /// Reset all costs
    pub fn reset(self: *CostTracker) void {
        var iter = self.costs.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.* = .{};
        }
        self.start_time_ns = std.time.nanoTimestamp();
    }

    /// Export to JSON for persistence
    pub fn exportToJson(self: *CostTracker) ![]const u8 {
        const total = self.getTotal();

        var json_buf = std.ArrayListUnmanaged(u8){};
        defer json_buf.deinit(self.allocator);

        try json_buf.appendSlice(self.allocator, &[_]u8{'{'});
        try json_buf.writer(self.allocator).print("\"total_api_tokens\":{d},", .{total.api_tokens});
        try json_buf.writer(self.allocator).print("\"total_cpu_ms\":{d},", .{total.cpu_ms});
        try json_buf.writer(self.allocator).print("\"peak_memory_mb\":{d},", .{total.memory_mb});
        try json_buf.writer(self.allocator).print("\"total_network_bytes\":{d},", .{total.network_bytes});
        try json_buf.writer(self.allocator).print("\"total_gpu_ms\":{d},", .{total.gpu_ms});
        try json_buf.writer(self.allocator).print("\"total_fpga_ops\":{d},", .{total.fpga_ops});
        try json_buf.writer(self.allocator).print("\"agent_count\":{d}", .{self.getAgentCount()});
        try json_buf.appendSlice(self.allocator, &[_]u8{'}'});

        return self.allocator.dupe(u8, json_buf.items);
    }

    /// Import from JSON (for checkpoint recovery)
    pub fn importFromJson(self: *CostTracker, json: []const u8) !void {
        var parser = std.json.Parser.init(self.allocator, false);
        defer parser.deinit();
        var tree = try parser.parse(json);
        defer tree.deinit();

        if (tree != .object) return error.InvalidJson;

        const obj = tree.object;

        // Restore total metrics into a "system" agent
        var cost = Cost{};
        if (obj.get("total_api_tokens")) |v| {
            if (v == .integer) cost.api_tokens = @as(u64, @intCast(v.integer));
        }
        if (obj.get("total_cpu_ms")) |v| {
            if (v == .integer) cost.cpu_ms = @as(u64, @intCast(v.integer));
        }
        if (obj.get("peak_memory_mb")) |v| {
            if (v == .integer) cost.memory_mb = @as(u64, @intCast(v.integer));
        }
        if (obj.get("total_network_bytes")) |v| {
            if (v == .integer) cost.network_bytes = @as(u64, @intCast(v.integer));
        }
        if (obj.get("total_gpu_ms")) |v| {
            if (v == .integer) cost.gpu_ms = @as(u64, @intCast(v.integer));
        }
        if (obj.get("total_fpga_ops")) |v| {
            if (v == .integer) cost.fpga_ops = @as(u64, @intCast(v.integer));
        }

        try self.track("system_checkpoint_restore", cost);
    }
};

// ═════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════

test "Cost init and defaults" {
    const cost = Cost{};
    try std.testing.expectEqual(@as(u64, 0), cost.api_tokens);
    try std.testing.expectEqual(@as(u64, 0), cost.cpu_ms);
}

test "Cost accumulation" {
    var cost1 = Cost{ .api_tokens = 1000, .cpu_ms = 500 };
    const cost2 = Cost{ .api_tokens = 2000, .cpu_ms = 1000 };

    cost1.api_tokens += cost2.api_tokens;
    cost1.cpu_ms += cost2.cpu_ms;

    try std.testing.expectEqual(@as(u64, 3000), cost1.api_tokens);
    try std.testing.expectEqual(@as(u64, 1500), cost1.cpu_ms);
}

test "CostTracker init" {
    const allocator = std.testing.allocator;
    var tracker = try CostTracker.init(allocator);
    defer tracker.deinit();

    try std.testing.expectEqual(@as(usize, 0), tracker.getAgentCount());
    try std.testing.expectEqual(Cost{}, tracker.getTotal());
}

test "CostTracker track" {
    const allocator = std.testing.allocator;
    var tracker = try CostTracker.init(allocator);
    defer tracker.deinit();

    const cost = Cost{ .api_tokens = 1000, .cpu_ms = 500 };
    try tracker.track("agent-1", cost);

    try std.testing.expectEqual(@as(usize, 1), tracker.getAgentCount());
    try std.testing.expectEqual(@as(u64, 1000), tracker.getTotal().api_tokens);
}

test "CostThresholds defaults" {
    const thresholds = CostThresholds{};
    try std.testing.expectEqual(@as(u64, 1_000_000), thresholds.max_api_tokens);
    try std.testing.expectEqual(@as(u8, 80), thresholds.alert_at_percent);
}

test "getElapsedTimeMs" {
    const allocator = std.testing.allocator;
    var tracker = try CostTracker.init(allocator);
    defer tracker.deinit();

    std.Thread.sleep(10_000_000); // 10ms
    const elapsed = tracker.getElapsedTimeMs();

    try std.testing.expect(elapsed >= 10);
    try std.testing.expect(elapsed < 100); // Should be close to 10ms
}

test "checkAlert at 80%" {
    const allocator = std.testing.allocator;
    var tracker = try CostTracker.init(allocator);
    defer tracker.deinit();

    tracker.thresholds.max_api_tokens = 1000;
    tracker.thresholds.alert_at_percent = 80; // Alert at 800

    // Below threshold
    try tracker.track("agent-1", Cost{ .api_tokens = 500 });
    try std.testing.expect(!tracker.checkAlert());

    // At threshold
    try tracker.track("agent-2", Cost{ .api_tokens = 300 });
    try std.testing.expect(tracker.checkAlert());
}
