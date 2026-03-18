//! TRINITY MCP Server v2.2 — Eternal Self-Healing + Auto-Scale
//!
//! Automatic health monitoring, self-healing, and scaling.
//! 99.99% uptime target with automatic failover.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Health check status
pub const HealthStatus = enum {
    healthy,
    degraded,
    unhealthy,
    unknown,
};

/// Instance state
pub const InstanceState = enum {
    starting,
    running,
    stopping,
    stopped,
    crashed,
    restarting,
};

/// Instance information
pub const Instance = struct {
    id: []const u8,
    region: []const u8,
    state: InstanceState,
    health: HealthStatus,
    uptime_ns: i64,
    last_health_check: i64,
    restart_count: u32,
    /// Current connections
    connections: u32,
    /// Memory usage in MB
    memory_mb: f64,
    /// CPU usage percentage
    cpu_percent: f64,

    /// Check if instance needs restart
    pub fn needsRestart(self: *const Instance) bool {
        // Auto-restart if crashed
        if (self.state == .crashed) return true;

        // Auto-restart if unhealthy for too long
        if (self.health == .unhealthy) {
            const now = std.time.nanoTimestamp();
            const unhealthy_ns = now - self.last_health_check;
            const five_minutes_ns: i64 = 300 * 1_000_000_000;
            if (unhealthy_ns > five_minutes_ns) return true;
        }

        // Auto-restart if restart count exceeds threshold
        if (self.restart_count > 5) return true;

        return false;
    }

    /// Check if instance is overloaded
    pub fn isOverloaded(self: *const Instance) bool {
        return self.cpu_percent > 80.0 or self.memory_mb > 400.0;
    }
};

/// Scaling policy
pub const ScalingPolicy = struct {
    min_instances: u32 = 1,
    max_instances: u32 = 50,
    target_cpu_percent: f64 = 60.0,
    target_memory_mb: f64 = 200.0,
    scale_up_cooldown_sec: u32 = 60,
    scale_down_cooldown_sec: u32 = 300,

    /// Calculate desired instance count
    pub fn calculateDesiredCount(self: *const ScalingPolicy, instances: []const Instance) u32 {
        if (instances.len == 0) return self.min_instances;

        var total_connections: u32 = 0;
        var avg_cpu: f64 = 0.0;
        var avg_memory: f64 = 0.0;
        var overloaded_count: u32 = 0;

        for (instances) |instance| {
            if (instance.state != .running) continue;

            total_connections += instance.connections;
            avg_cpu += instance.cpu_percent;
            avg_memory += instance.memory_mb;

            if (instance.isOverloaded()) overloaded_count += 1;
        }

        const running_count = @as(u32, @intCast(std.math.clamp(
            instances.len,
            self.min_instances,
            self.max_instances,
        )));

        if (running_count == 0) return self.min_instances;

        avg_cpu /= @as(f64, @floatFromInt(running_count));
        avg_memory /= @as(f64, @floatFromInt(running_count));

        // Scale up if overloaded
        const overloaded_ratio = @as(f64, @floatFromInt(overloaded_count)) / @as(f64, @floatFromInt(running_count));
        if (overloaded_ratio > 0.3 or avg_cpu > self.target_cpu_percent or avg_memory > self.target_memory_mb) {
            const new_count = @min(running_count + 1, self.max_instances);
            return new_count;
        }

        // Scale down if underutilized
        if (avg_cpu < 20.0 and avg_memory < 100.0 and running_count > self.min_instances) {
            const new_count = @max(running_count - 1, self.min_instances);
            return new_count;
        }

        return running_count;
    }
};

/// Self-healing manager
pub const HealingManager = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    instances: std.ArrayList(Instance),
    policy: ScalingPolicy,
    last_scale_time: i64,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, app_name: []const u8, policy: ScalingPolicy) HealingManager {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .instances = std.ArrayList(Instance).init(allocator),
            .policy = policy,
            .last_scale_time = 0,
            .running = false,
        };
    }

    pub fn deinit(self: *HealingManager) void {
        self.instances.deinit();
    }

    /// Start the healing daemon
    pub fn start(self: *HealingManager) !void {
        self.running = true;
        std.debug.print("Self-healing daemon started for {s}\n", .{self.app_name});
    }

    /// Stop the healing daemon
    pub fn stop(self: *HealingManager) void {
        self.running = false;
        std.debug.print("Self-healing daemon stopped\n", .{});
    }

    /// Run healing cycle (should be called periodically)
    pub fn runCycle(self: *HealingManager) !HealingReport {
        const start_time = std.time.nanoTimestamp();

        // Refresh instance status from Fly.io
        try self.refreshInstances();

        // Check instance health
        var unhealthy_count: u32 = 0;
        var crashed_count: u32 = 0;
        var restarted_count: u32 = 0;

        for (self.instances.items) |*instance| {
            if (instance.health == .unhealthy) unhealthy_count += 1;
            if (instance.state == .crashed) crashed_count += 1;

            if (instance.needsRestart()) {
                try self.restartInstance(instance);
                restarted_count += 1;
            }
        }

        // Auto-scale based on load
        const scaled = try self.autoScale();

        const end_time = std.time.nanoTimestamp();

        return .{
            .timestamp = end_time,
            .total_instances = @intCast(self.instances.items.len),
            .healthy_instances = @intCast(self.instances.items.len - unhealthy_count),
            .unhealthy_instances = unhealthy_count,
            .crashed_instances = crashed_count,
            .restarted_instances = restarted_count,
            .scaled = scaled,
            .cycle_duration_ms = @intCast((end_time - start_time) / 1_000_000),
        };
    }

    /// Refresh instance status from Fly.io
    fn refreshInstances(self: *HealingManager) !void {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "flyctl", "status", "--all", "--json", "--app", self.app_name },
        }) catch return;

        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        if (result.term.Exited != 0) return;

        // Parse JSON to extract instance states
        // flyctl status --json returns {"Machines":[{"id":"...","state":"started",...}]}
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, result.stdout, .{}) catch return;
        defer parsed.deinit();

        const machines = switch (parsed.value) {
            .object => |obj| obj.get("Machines") orelse return,
            else => return,
        };
        const machines_arr = switch (machines) {
            .array => |arr| arr.items,
            else => return,
        };

        // Update existing instances from API response
        for (self.instances.items) |*inst| {
            for (machines_arr) |machine| {
                const obj = switch (machine) {
                    .object => |o| o,
                    else => continue,
                };
                const machine_id = switch (obj.get("id") orelse continue) {
                    .string => |s| s,
                    else => continue,
                };
                if (!std.mem.eql(u8, inst.id, machine_id)) continue;

                // Update state from "state" field
                const state_str = switch (obj.get("state") orelse continue) {
                    .string => |s| s,
                    else => continue,
                };
                inst.state = if (std.mem.eql(u8, state_str, "started"))
                    .running
                else if (std.mem.eql(u8, state_str, "starting"))
                    .starting
                else if (std.mem.eql(u8, state_str, "stopping"))
                    .stopping
                else if (std.mem.eql(u8, state_str, "stopped"))
                    .stopped
                else
                    .crashed;

                inst.last_health_check = std.time.nanoTimestamp();
                inst.health = if (inst.state == .running) .healthy else .degraded;
            }
        }
    }

    /// Restart a specific instance by its ID
    fn restartInstance(self: *HealingManager, instance: *Instance) !void {
        instance.state = .restarting;
        instance.restart_count += 1;

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "flyctl", "machine", "restart", instance.id, "--app", self.app_name },
        }) catch return;

        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        if (result.term.Exited == 0) {
            instance.state = .starting;
            instance.health = .unknown;
        } else {
            instance.state = .crashed;
            instance.health = .unhealthy;
        }
    }

    /// Auto-scale based on policy
    fn autoScale(self: *HealingManager) !bool {
        const now = std.time.nanoTimestamp();
        const time_since_last_scale = (now - self.last_scale_time) / 1_000_000_000;

        const desired_count = self.policy.calculateDesiredCount(self.instances.items);
        const current_count: u32 = @intCast(self.instances.items.len);

        if (desired_count == current_count) return false;

        // Check cooldown
        const cooldown_sec = if (desired_count > current_count)
            self.policy.scale_up_cooldown_sec
        else
            self.policy.scale_down_cooldown_sec;

        if (time_since_last_scale < cooldown_sec) {
            std.debug.print("Scale cooldown active ({d}s remaining)\n", .{cooldown_sec - @as(u32, @intCast(time_since_last_scale))});
            return false;
        }

        // Scale
        std.debug.print("Scaling from {d} to {d} instances\n", .{ current_count, desired_count });

        const scale_result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{
                "flyctl",
                "scale",
                "count",
                try std.fmt.allocPrint(self.allocator, "{d}", .{desired_count}),
                "--app",
                self.app_name,
            },
        }) catch {
            return false;
        };

        defer {
            self.allocator.free(scale_result.stdout);
            self.allocator.free(scale_result.stderr);
        }

        self.last_scale_time = now;
        return true;
    }
};

/// Healing cycle report
pub const HealingReport = struct {
    timestamp: i64,
    total_instances: u32,
    healthy_instances: u32,
    unhealthy_instances: u32,
    crashed_instances: u32,
    restarted_instances: u32,
    scaled: bool,
    cycle_duration_ms: u64,

    /// Format as human-readable
    pub fn format(self: *const HealingReport, allocator: std.mem.Allocator) ![]const u8 {
        var output = std.ArrayList(u8).init(allocator);

        try output.appendSlice(
            \\═══════════════════════════════════════════════════════════════
            \\  Self-Healing Cycle Report
            \\═══════════════════════════════════════════════════════════════
            \\
        );

        try output.print("Instances: {d}/{d} healthy\n", .{ self.healthy_instances, self.total_instances });
        try output.print("Unhealthy: {d}\n", .{self.unhealthy_instances});
        try output.print("Crashed: {d}\n", .{self.crashed_instances});
        try output.print("Restarted: {d}\n", .{self.restarted_instances});
        try output.print("Scaled: {s}\n", .{if (self.scaled) "YES" else "NO"});
        try output.print("Cycle time: {d}ms\n", .{self.cycle_duration_ms});

        try output.appendSlice(
            \\═══════════════════════════════════════════════════════════════
            \\
        );

        return output.toOwnedSlice();
    }
};

/// Uptime calculator
pub const UptimeCalculator = struct {
    start_time: i64,
    downtime_ns: i64 = 0,

    pub fn init() UptimeCalculator {
        return .{
            .start_time = std.time.nanoTimestamp(),
        };
    }

    /// Record downtime
    pub fn recordDowntime(self: *UptimeCalculator, duration_ns: i64) void {
        self.downtime_ns += duration_ns;
    }

    /// Calculate uptime percentage
    pub fn uptimePercentage(self: *const UptimeCalculator) f64 {
        const now = std.time.nanoTimestamp();
        const total_ns = now - self.start_time;
        const uptime_ns = total_ns - self.downtime_ns;

        if (total_ns <= 0) return 100.0;
        return (@as(f64, @floatFromInt(uptime_ns)) / @as(f64, @floatFromInt(total_ns))) * 100.0;
    }

    /// Check if 99.99% uptime target is met
    pub fn meetsTarget(self: *const UptimeCalculator) bool {
        return self.uptimePercentage() >= 99.99;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "instance — crashed needs restart" {
    const instance = Instance{
        .id = "test-1",
        .region = "us-east",
        .state = .crashed,
        .health = .unhealthy,
        .connections = 0,
        .last_health_check = 0,
        .restart_count = 0,
        .memory_mb = 100.0,
        .cpu_percent = 10.0,
    };
    try std.testing.expect(instance.needsRestart());
}

test "instance — healthy running no restart" {
    const instance = Instance{
        .id = "test-2",
        .region = "eu-west",
        .state = .running,
        .health = .healthy,
        .connections = 10,
        .last_health_check = std.time.nanoTimestamp(),
        .restart_count = 0,
        .memory_mb = 100.0,
        .cpu_percent = 30.0,
    };
    try std.testing.expect(!instance.needsRestart());
    try std.testing.expect(!instance.isOverloaded());
}

test "instance — overloaded" {
    const instance = Instance{
        .id = "test-3",
        .region = "ap-south",
        .state = .running,
        .health = .degraded,
        .connections = 100,
        .last_health_check = std.time.nanoTimestamp(),
        .restart_count = 0,
        .memory_mb = 500.0,
        .cpu_percent = 95.0,
    };
    try std.testing.expect(instance.isOverloaded());
}

test "scaling policy — min instances when empty" {
    const policy = ScalingPolicy{ .min_instances = 2 };
    const empty = [_]Instance{};
    try std.testing.expectEqual(@as(u32, 2), policy.calculateDesiredCount(&empty));
}
