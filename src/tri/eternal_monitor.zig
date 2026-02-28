//! Eternal Monitoring System for TRI CLI
//! Continuously monitors system health using φ-based intervals
const std = @import("std");
const math = std.math;
const time = std.time;

/// Sacred mathematics constants
const PHI: f64 = 1.6180339887498948482;
const MU: f64 = 0.0382; // φ^(-4)
const CHI: f64 = 0.0618;
const EPSILON: f64 = 1.0 / 3.0;

/// Monitoring configuration
pub const Config = struct {
    interval_ms: u64 = @as(u64, @intFromFloat(PHI * 1000)), // φ seconds in ms
    health_timeout_ms: u64 = 5000,
    alert_threshold_ms: u64 = 10000,
    max_retries: u32 = 3,
    auto_heal: bool = true,
    verbose: bool = false,
};

/// Alert severity levels
pub const Severity = enum {
    info,
    warning,
    err,
    critical,

    pub fn color(self: Severity) []const u8 {
        return switch (self) {
            .info => "\x1b[36m", // Cyan
            .warning => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
            .critical => "\x1b[35m", // Magenta
        };
    }

    pub fn reset() []const u8 {
        return "\x1b[0m";
    }
};

/// Health check result
pub const HealthStatus = enum {
    healthy,
    degraded,
    failed,

    pub fn symbol(self: HealthStatus) []const u8 {
        return switch (self) {
            .healthy => "✓",
            .degraded => "⚠",
            .failed => "✗",
        };
    }
};

/// Alert entry
pub const Alert = struct {
    timestamp: i64,
    component: []const u8,
    message: []const u8,
    severity: Severity,
    metric_value: f64 = 0.0,

    pub fn format(self: Alert, allocator: std.mem.Allocator) ![]u8 {
        const timestamp_sec = @as(f64, @floatFromInt(self.timestamp)) / 1000.0;
        return try std.fmt.allocPrint(
            allocator,
            "{s}[{d:.3}][{s}] {s}: {s} ({d:.2}){s}",
            .{
                self.severity.color(),
                timestamp_sec,
                self.component,
                self.severity.color(),
                self.message,
                self.metric_value,
                Severity.reset(),
            },
        );
    }
};

/// System metrics
pub const Metrics = struct {
    cpu_usage: f64 = 0.0,
    memory_mb: f64 = 0.0,
    uptime_ms: i64 = 0,
    check_count: u64 = 0,
    failure_count: u64 = 0,
    avg_response_time_ms: f64 = 0.0,
    last_check_time_ms: i64 = 0,

    pub fn sacred_ratio(self: Metrics) f64 {
        if (self.check_count == 0) return 0.0;
        return @as(f64, @floatFromInt(self.failure_count)) / @as(f64, @floatFromInt(self.check_count));
    }
};

/// Component to monitor
pub const SystemComponent = struct {
    name: []const u8,
    health_check_fn: *const fn (allocator: std.mem.Allocator) anyerror!HealthStatus,
    last_status: HealthStatus = .healthy,
    failure_count: u32 = 0,
    last_check_ms: i64 = 0,

    pub fn init(
        name: []const u8,
        health_check_fn: *const fn (allocator: std.mem.Allocator) anyerror!HealthStatus,
    ) SystemComponent {
        return .{
            .name = name,
            .health_check_fn = health_check_fn,
        };
    }
};

/// Eternal Monitor
pub const EternalMonitor = struct {
    allocator: std.mem.Allocator,
    config: Config,
    components: std.ArrayList(SystemComponent),
    component_capacity: usize = 16,
    alerts: std.ArrayList(Alert),
    metrics: Metrics,
    start_time_ms: i64,
    running: bool = true,

    pub fn init(allocator: std.mem.Allocator, config: Config) !*EternalMonitor {
        const monitor = try allocator.create(EternalMonitor);
        monitor.allocator = allocator;
        monitor.config = config;
        monitor.components = std.ArrayList(SystemComponent).initCapacity(allocator, 16) catch unreachable;
        monitor.alerts = std.ArrayList(Alert).initCapacity(allocator, 64) catch unreachable;
        monitor.metrics = .{};
        monitor.start_time_ms = timestamp_ms();
        monitor.running = true;
        return monitor;
    }

    pub fn deinit(self: *EternalMonitor) void {
        self.components.deinit(self.allocator);
        for (self.alerts.items) |*alert| {
            self.allocator.free(alert.component);
            self.allocator.free(alert.message);
        }
        self.alerts.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Register a component for monitoring
    pub fn registerComponent(self: *EternalMonitor, component: SystemComponent) !void {
        try self.components.append(self.allocator, component);
    }

    /// Add an alert
    pub fn addAlert(
        self: *EternalMonitor,
        component: []const u8,
        message: []const u8,
        severity: Severity,
        metric_value: f64,
    ) !void {
        const component_copy = try self.allocator.dupe(u8, component);
        errdefer self.allocator.free(component_copy);

        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);

        try self.alerts.append(self.allocator, Alert{
            .timestamp = timestamp_ms(),
            .component = component_copy,
            .message = message_copy,
            .severity = severity,
            .metric_value = metric_value,
        });

        if (self.config.verbose) {
            const alert = self.alerts.items[self.alerts.items.len - 1];
            const formatted = try alert.format(self.allocator);
            defer self.allocator.free(formatted);
            std.debug.print("{s}\n", .{formatted});
        }
    }

    /// Get recent alerts
    pub fn getRecentAlerts(self: *EternalMonitor, max_count: usize) ![]const Alert {
        const start = if (self.alerts.items.len > max_count)
            self.alerts.items.len - max_count
        else
            0;
        return self.alerts.items[start..];
    }

    /// Check component health
    pub fn checkComponent(self: *EternalMonitor, component: *SystemComponent) !HealthStatus {
        const start = timestamp_ms();
        const status = component.health_check_fn(self.allocator) catch |err| {
            const msg = try std.fmt.allocPrint(
                self.allocator,
                "Health check failed: {s}",
                .{@errorName(err)},
            );
            defer self.allocator.free(msg);

            try self.addAlert(component.name, msg, .err, 0.0);
            component.failure_count += 1;
            return .failed;
        };

        const elapsed = timestamp_ms() - start;
        component.last_check_ms = elapsed;

        // Alert on slow response
        if (elapsed > self.config.alert_threshold_ms) {
            const msg = try std.fmt.allocPrint(
                self.allocator,
                "Slow response: {d}ms",
                .{elapsed},
            );
            defer self.allocator.free(msg);

            try self.addAlert(component.name, msg, .warning, @floatFromInt(elapsed));
        }

        component.last_status = status;

        if (status == .failed) {
            component.failure_count += 1;
            const msg = try std.fmt.allocPrint(
                self.allocator,
                "Health check failed (attempt {d}/{d})",
                .{ component.failure_count, self.config.max_retries },
            );
            defer self.allocator.free(msg);

            const severity = if (component.failure_count >= self.config.max_retries)
                Severity.critical
            else
                Severity.err;

            try self.addAlert(component.name, msg, severity, 0.0);

            // Attempt auto-heal
            if (self.config.auto_heal and component.failure_count < self.config.max_retries) {
                try self.healComponent(component);
            }
        } else {
            component.failure_count = 0;
        }

        return status;
    }

    /// Attempt to heal a failed component
    pub fn healComponent(self: *EternalMonitor, component: *SystemComponent) !void {
        const msg = try std.fmt.allocPrint(
            self.allocator,
            "Attempting auto-heal for {s}",
            .{component.name},
        );
        defer self.allocator.free(msg);

        try self.addAlert(component.name, msg, .info, 0.0);

        // Simulate healing (in real implementation, would restart service)
        const sleep_ns = @as(u64, @intFromFloat(PHI * 500 * 1_000_000));
        std.posix.nanosleep(sleep_ns / 1_000_000_000, sleep_ns % 1_000_000_000); // φ/2 second wait

        // TODO: Implement actual healing logic per component
    }

    /// Run all health checks
    pub fn runHealthChecks(self: *EternalMonitor) !void {
        var healthy_count: usize = 0;
        var degraded_count: usize = 0;
        var failed_count: usize = 0;

        for (self.components.items) |*component| {
            const status = try self.checkComponent(component);

            switch (status) {
                .healthy => healthy_count += 1,
                .degraded => degraded_count += 1,
                .failed => failed_count += 1,
            }
        }

        self.metrics.check_count += 1;
        if (failed_count > 0) {
            self.metrics.failure_count += 1;
        }

        // Update average response time
        var total_time: i64 = 0;
        for (self.components.items) |*component| {
            total_time += component.last_check_ms;
        }
        if (self.components.items.len > 0) {
            self.metrics.avg_response_time_ms =
                @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(self.components.items.len));
        }

        self.metrics.last_check_time_ms = timestamp_ms();
        self.metrics.uptime_ms = self.metrics.last_check_time_ms - self.start_time_ms;
    }

    /// Display current status
    pub fn displayStatus(self: *EternalMonitor) !void {
        const now = timestamp_ms();
        const elapsed_sec = @as(f64, @floatFromInt(now - self.start_time_ms)) / 1000.0;
        const sacred_ratio = self.metrics.sacred_ratio();

        std.debug.print(
            \\╔════════════════════════════════════════════════════════════╗
            \\║            TRINITY ETERNAL MONITOR — φ² + 1/φ² = 3         ║
            \\╠════════════════════════════════════════════════════════════╣
            \\║ Uptime: {d:6.1}s  │  Checks: {d:5}  │  Sacred Ratio: {d:.4} ║
            \\╠════════════════════════════════════════════════════════════╣
        ,
            .{ elapsed_sec, self.metrics.check_count, sacred_ratio },
        );

        // Display components
        for (self.components.items) |*component| {
            const status_color = switch (component.last_status) {
                .healthy => "\x1b[32m", // Green
                .degraded => "\x1b[33m", // Yellow
                .failed => "\x1b[31m", // Red
            };

            std.debug.print(
                "║ {s}{s} {s:<20} {d:4}ms  [{d:2}/{d:2} failures]{s} ║\n",
                .{
                    status_color,
                    component.last_status.symbol(),
                    component.name,
                    component.last_check_ms,
                    component.failure_count,
                    self.config.max_retries,
                    "\x1b[0m",
                },
            );
        }

        std.debug.print("╠════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Recent Alerts ({d}/{d}):                                    ║\n", .{
            self.alerts.items.len,
            self.alerts.items.len,
        });

        const recent_alerts = try self.getRecentAlerts(5);

        if (recent_alerts.len == 0) {
            std.debug.print("║ No alerts — System in perfect harmony                      ║\n", .{});
        } else {
            for (recent_alerts) |alert| {
                const formatted = try alert.format(self.allocator);
                defer self.allocator.free(formatted);

                // Truncate if too long (simplified - just use formatted as-is for now)
                const truncated = formatted;

                std.debug.print("║ {s:<57} ║\n", .{truncated});
            }
        }

        std.debug.print("╚════════════════════════════════════════════════════════════╝\n", .{});
    }

    /// Display health report (one-time)
    pub fn displayHealthReport(self: *EternalMonitor) !void {
        std.debug.print("\n\x1b[1;36m╔══════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m║          TRINITY HEALTH REPORT — φ Balance         ║\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m╚══════════════════════════════════════════════════════╝\x1b[0m\n\n", .{});

        try self.runHealthChecks();

        var healthy: usize = 0;
        var degraded: usize = 0;
        var failed: usize = 0;

        for (self.components.items) |*component| {
            const status = component.last_status;

            const color = switch (status) {
                .healthy => "\x1b[32m",
                .degraded => "\x1b[33m",
                .failed => "\x1b[31m",
            };

            std.debug.print(
                "{s}{s} {s}\x1b[0m — {d:3}ms | Failures: {d}/{d}\n",
                .{
                    color,
                    status.symbol(),
                    component.name,
                    component.last_check_ms,
                    component.failure_count,
                    self.config.max_retries,
                },
            );

            switch (status) {
                .healthy => healthy += 1,
                .degraded => degraded += 1,
                .failed => failed += 1,
            }
        }

        std.debug.print("\n", .{});
        std.debug.print("Summary: {d} Healthy, {d} Degraded, {d} Failed\n", .{
            healthy,
            degraded,
            failed,
        });

        const total = healthy + degraded + failed;
        if (total > 0) {
            const health_percent = (@as(f64, @floatFromInt(healthy)) / @as(f64, @floatFromInt(total))) * 100.0;
            std.debug.print("Overall Health: {d:.1}%\n", .{health_percent});
        }

        std.debug.print("\nSacred Metrics:\n", .{});
        std.debug.print("  φ Interval:  {d:.3}s\n", .{@as(f64, @floatFromInt(self.config.interval_ms)) / 1000.0});
        std.debug.print("  Uptime:      {d:.1}s\n", .{@as(f64, @floatFromInt(self.metrics.uptime_ms)) / 1000.0});
        std.debug.print("  Checks:      {d}\n", .{self.metrics.check_count});
        std.debug.print("  Avg Response: {d:.2}ms\n", .{self.metrics.avg_response_time_ms});

        const sacred_ratio = self.metrics.sacred_ratio();
        std.debug.print("  Sacred Ratio: {d:.4} (closer to 0 = better)\n", .{sacred_ratio});

        if (sacred_ratio < CHI) {
            std.debug.print("\n\x1b[32m✓ System in perfect harmony (ratio < χ = {d:.4})\x1b[0m\n", .{CHI});
        } else if (sacred_ratio < EPSILON) {
            std.debug.print("\n\x1b[33m⚠ System stable but monitoring needed (ratio < ε = {d:.3})\x1b[0m\n", .{EPSILON});
        } else {
            std.debug.print("\n\x1b[31m✗ System needs attention (ratio = {d:.4})\x1b[0m\n", .{sacred_ratio});
        }
    }

    /// Display alerts
    pub fn displayAlerts(self: *EternalMonitor, max_count: usize) !void {
        std.debug.print("\n\x1b[1;36m╔══════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m║              TRINITY ALERT LOG                       ║\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m╚══════════════════════════════════════════════════════╝\x1b[0m\n\n", .{});

        if (self.alerts.items.len == 0) {
            std.debug.print("No alerts — System operating in perfect harmony.\n", .{});
            return;
        }

        const start = if (self.alerts.items.len > max_count)
            self.alerts.items.len - max_count
        else
            0;

        std.debug.print("Showing {d} most recent alerts:\n\n", .{self.alerts.items.len - start});

        for (self.alerts.items[start..], 0..) |alert, i| {
            const formatted = try alert.format(self.allocator);
            defer self.allocator.free(formatted);

            std.debug.print("{d:3}. {s}\n", .{i + 1, formatted});
        }

        // Alert summary
        var info_count: usize = 0;
        var warning_count: usize = 0;
        var error_count: usize = 0;
        var critical_count: usize = 0;

        for (self.alerts.items) |alert| {
            switch (alert.severity) {
                .info => info_count += 1,
                .warning => warning_count += 1,
                .err => error_count += 1,
                .critical => critical_count += 1,
            }
        }

        std.debug.print("\nAlert Summary:\n", .{});
        std.debug.print("  Info: {d}, Warning: {d}, Error: {d}, Critical: {d}\n", .{
            info_count,
            warning_count,
            error_count,
            critical_count,
        });
    }

    /// Run monitoring loop (eternal mode)
    pub fn runEternal(self: *EternalMonitor) !void {
        // Set up signal handling for graceful shutdown
        // Note: This is a simplified version. Full signal handling requires platform-specific code.

        std.debug.print("\n\x1b[1;36m╔══════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m║     TRINITY ETERNAL MONITOR — AWAKENING              ║\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m╠══════════════════════════════════════════════════════╣\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m║  Monitoring at φ-second intervals ({d:.3}s)            ║\x1b[0m\n", .{PHI});
        std.debug.print("\x1b[1;36m║  Press Ctrl+C to stop                                 ║\x1b[0m\n", .{});
        std.debug.print("\x1b[1;36m╚══════════════════════════════════════════════════════╝\x1b[0m\n\n", .{});

        var iteration: u64 = 0;
        while (self.running) {
            iteration += 1;

            // Run health checks
            try self.runHealthChecks();

            // Display status every iteration
            try self.displayStatus();

            // Display sacred geometry visualization
            if (self.config.verbose) {
                try self.displaySacredGeometry(iteration);
            }

            // φ-based sleep interval
            const sleep_ns = self.config.interval_ms * 1000000;
            std.posix.nanosleep(sleep_ns / 1_000_000_000, sleep_ns % 1_000_000_000); // Convert ms to ns
        }

        std.debug.print("\n\n\x1b[1;33mEternal monitor stopping gracefully...\x1b[0m\n", .{});
        std.debug.print("Total iterations: {d}\n", .{iteration});
        std.debug.print("Final uptime: {d:.1}s\n", .{@as(f64, @floatFromInt(self.metrics.uptime_ms)) / 1000.0});
    }

    /// Display sacred geometry visualization
    pub fn displaySacredGeometry(self: *EternalMonitor, iteration: u64) !void {
        _ = self;

        const phi_cycle = @as(f64, @floatFromInt(iteration % 10)) / 10.0;
        const phi_position = PHI * phi_cycle;

        // Simple φ-based visualization
        const bar_length = @as(usize, @intFromFloat(@mod(phi_position * 20, 40)));
        var i: usize = 0;
        std.debug.print("φ: [", .{});
        while (i < 40) : (i += 1) {
            if (i < bar_length) {
                std.debug.print("█", .{});
            } else {
                std.debug.print("░", .{});
            }
        }
        std.debug.print("] {d:.3}\n", .{phi_position});
    }

    /// Stop the eternal loop
    pub fn stop(self: *EternalMonitor) void {
        self.running = false;
    }
};

/// Get current timestamp in milliseconds
pub fn timestamp_ms() i64 {
    // Placeholder - in real implementation, use std.time.nanoTimestamp() / 1_000_000
    const ns = std.time.nanoTimestamp();
    return @intCast(@divFloor(ns, 1_000_000));
}

// ============================================================================
// Default Health Checks
// ============================================================================

/// Check memory availability
fn checkMemory(allocator: std.mem.Allocator) !HealthStatus {
    _ = allocator;
    // Placeholder - in real implementation, check actual memory usage
    return .healthy;
}

/// Check CPU load
fn checkCpu(allocator: std.mem.Allocator) !HealthStatus {
    _ = allocator;
    // Placeholder - in real implementation, check actual CPU usage
    return .healthy;
}

/// Check disk space
fn checkDisk(allocator: std.mem.Allocator) !HealthStatus {
    _ = allocator;
    // Placeholder - in real implementation, check actual disk space
    return .healthy;
}

/// Check VSA system
fn checkVSA(allocator: std.mem.Allocator) !HealthStatus {
    _ = allocator;
    // Placeholder - in real implementation, check VSA integrity
    return .healthy;
}

/// Check VM system
fn checkVM(allocator: std.mem.Allocator) !HealthStatus {
    _ = allocator;
    // Placeholder - in real implementation, check VM state
    return .healthy;
}

/// Check Firebird LLM
fn checkFirebird(allocator: std.mem.Allocator) !HealthStatus {
    _ = allocator;
    // Placeholder - in real implementation, check Firebird availability
    return .healthy;
}

/// Create default monitor with standard components
pub fn createDefaultMonitor(allocator: std.mem.Allocator, config: Config) !*EternalMonitor {
    const monitor = try EternalMonitor.init(allocator, config);

    // Register default components
    try monitor.registerComponent(SystemComponent.init("Memory", checkMemory));
    try monitor.registerComponent(SystemComponent.init("CPU", checkCpu));
    try monitor.registerComponent(SystemComponent.init("Disk", checkDisk));
    try monitor.registerComponent(SystemComponent.init("VSA System", checkVSA));
    try monitor.registerComponent(SystemComponent.init("VM System", checkVM));
    try monitor.registerComponent(SystemComponent.init("Firebird LLM", checkFirebird));

    return monitor;
}

// ============================================================================
// CLI Entry Point
// ============================================================================

pub const Command = enum {
    eternal,
    health,
    alerts,

    pub fn fromString(str: []const u8) ?Command {
        if (std.mem.eql(u8, str, "--eternal")) return .eternal;
        if (std.mem.eql(u8, str, "--health")) return .health;
        if (std.mem.eql(u8, str, "--alerts")) return .alerts;
        return null;
    }
};

/// Main entry point for tri monitor command
pub fn execute(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    var config = Config{};
    var command: Command = .health;
    var verbose = false;

    // Parse arguments
    var i: usize = 1; // Skip program name
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--eternal")) {
            command = .eternal;
        } else if (std.mem.eql(u8, arg, "--health")) {
            command = .health;
        } else if (std.mem.eql(u8, arg, "--alerts")) {
            command = .alerts;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--no-heal")) {
            config.auto_heal = false;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return 0;
        } else {
            std.debug.print("Unknown option: {s}\n\n", .{arg});
            printUsage();
            return 1;
        }
    }

    config.verbose = verbose;

    // Create monitor
    const monitor = try createDefaultMonitor(allocator, config);
    defer monitor.deinit();

    // Execute command
    switch (command) {
        .eternal => {
            try monitor.runEternal();
            return 0;
        },
        .health => {
            try monitor.displayHealthReport();
            return 0;
        },
        .alerts => {
            try monitor.displayAlerts(20);
            return 0;
        },
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage: tri monitor [OPTIONS]
        \\
        \\Eternal Monitoring System for TRI CLI
        \\
        \\Commands:
        \\  --eternal    Run monitoring forever (until Ctrl+C)
        \\  --health     One-time health check (default)
        \\  --alerts     Display recent alerts
        \\
        \\Options:
        \\  -v, --verbose    Enable verbose output
        \\  --no-heal        Disable auto-healing
        \\  -h, --help       Show this help message
        \\
        \\Sacred Intervals:
        \\  Monitor runs at φ-second intervals (1.618s)
        \\  Sacred ratio = failures / checks
        \\  χ = 0.0618 (warning threshold)
        \\  ε = 0.333 (critical threshold)
        \\
        \\Examples:
        \\  tri monitor --eternal           # Run forever
        \\  tri monitor --health            # One-time check
        \\  tri monitor --alerts            # Show alerts
        \\  tri monitor --eternal -v        # Verbose eternal mode
        \\
    , .{});
}

// ============================================================================
// Tests
// ============================================================================

test "EternalMonitor init and deinit" {
    const allocator = std.testing.allocator;
    const config = Config{};
    const monitor = try EternalMonitor.init(allocator, config);
    defer monitor.deinit();

    try std.testing.expectEqual(@as(i64, 0), @as(i64, @intCast(monitor.components.items.len)));
}

test "EternalMonitor register components" {
    const allocator = std.testing.allocator;
    const config = Config{};
    const monitor = try EternalMonitor.init(allocator, config);
    defer monitor.deinit();

    try monitor.registerComponent(SystemComponent.init("Test", checkMemory));
    try std.testing.expectEqual(@as(usize, 1), monitor.components.items.len);
}

test "EternalMonitor add alert" {
    const allocator = std.testing.allocator;
    const config = Config{};
    const monitor = try EternalMonitor.init(allocator, config);
    defer monitor.deinit();

    try monitor.addAlert("Test", "Test alert", Severity.info, 1.0);
    try std.testing.expectEqual(@as(usize, 1), monitor.alerts.items.len);
}

test "EternalMonitor sacred ratio" {
    const allocator = std.testing.allocator;
    const config = Config{};
    const monitor = try EternalMonitor.init(allocator, config);
    defer monitor.deinit();

    monitor.metrics.check_count = 100;
    monitor.metrics.failure_count = 5;

    const ratio = monitor.metrics.sacred_ratio();
    try std.testing.expectApproxEqAbs(@as(f64, 0.05), ratio, 0.001);
}

test "createDefaultMonitor" {
    const allocator = std.testing.allocator;
    const config = Config{};
    const monitor = try createDefaultMonitor(allocator, config);
    defer monitor.deinit();

    try std.testing.expectEqual(@as(usize, 6), monitor.components.items.len);
}

test "Alert format" {
    const allocator = std.testing.allocator;
    const alert = Alert{
        .timestamp = 12345000,
        .component = "Test",
        .message = "Test message",
        .severity = Severity.info,
        .metric_value = 1.5,
    };

    const formatted = try alert.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(formatted.len > 0);
}
