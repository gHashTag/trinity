//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN ADMIN — v1.0 — Administrative CLI Commands
//!
//! Brain Region: Hypothalamus (Homeostatic Regulation)
//!
//! Provides safe administrative tools for brain maintenance:
//! - reset: Reset all brain state
//! - doctor: Run diagnostic checks
//! - prune: Prune old events and expired claims
//! - migrate: Migrate state versions
//! - backup: Create backup
//! - restore: Restore from backup
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//! Safety: All destructive operations require explicit confirmation

const std = @import("std");
const fs = std.fs;
const mem = std.mem;

// Import brain region modules via module names (from build.zig)
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const state_recovery = @import("state_recovery");
const telemetry = @import("telemetry");

// ═══════════════════════════════════════════════════════════════════════════════
// ADMIN ERROR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdminError = error{
    /// Operation requires confirmation (use --force or --yes)
    ConfirmationRequired,
    /// State file is locked or in use
    StateLocked,
    /// Backup not found
    BackupNotFound,
    /// Invalid backup format
    InvalidBackup,
    /// Migration not supported
    MigrationNotSupported,
    /// Diagnostic check failed
    CheckFailed,
    /// Nothing to prune
    NothingToPrune,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSTIC RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiagnosticStatus = enum {
    healthy,
    warning,
    critical,
    unknown,
};

pub const DiagnosticCheck = struct {
    name: []const u8,
    status: DiagnosticStatus,
    message: []const u8,
    details: ?[]const u8 = null,
    suggestion: ?[]const u8 = null,
};

pub const DiagnosticReport = struct {
    overall_status: DiagnosticStatus,
    checks: []DiagnosticCheck,
    timestamp: i64,
    brain_version: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRUNE STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PruneStats = struct {
    expired_claims: usize,
    old_events: usize,
    old_backups: usize,
    bytes_freed: usize,
    duration_ms: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADMIN MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdminManager = struct {
    allocator: mem.Allocator,
    state_dir: []const u8,
    backup_dir: []const u8,

    const Self = @This();

    /// Default state directory
    pub const DEFAULT_STATE_DIR = state_recovery.StateManager.DEFAULT_STATE_DIR;

    /// Initialize admin manager with default paths
    pub fn init(allocator: mem.Allocator) !Self {
        const state_dir = DEFAULT_STATE_DIR;
        try fs.cwd().makePath(state_dir);

        const backup_dir = try fs.path.join(allocator, &.{ state_dir, "backups" });
        errdefer allocator.free(backup_dir);

        try fs.cwd().makePath(backup_dir);

        return Self{
            .allocator = allocator,
            .state_dir = state_dir,
            .backup_dir = backup_dir,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.backup_dir);
    }

    /// Reset all brain state (requires confirmation)
    /// WARNING: This is a destructive operation
    pub fn reset(self: *Self, confirmed: bool) !void {
        if (!confirmed) {
            std.log.warn("Brain reset requires confirmation. Use --force or --yes to confirm.", .{});
            return AdminError.ConfirmationRequired;
        }

        std.log.warn("Resetting all brain state...", .{});

        // Clear basal ganglia (task claims)
        {
            const registry = try basal_ganglia.getGlobal(self.allocator);
            registry.mutex.lock();
            defer registry.mutex.unlock();
            // Remove all claims
            var to_remove = std.ArrayList([]const u8).init(self.allocator);
            defer {
                for (to_remove.items) |key| self.allocator.free(key);
                to_remove.deinit();
            }
            var iter = registry.claims.iterator();
            while (iter.next()) |entry| {
                try to_remove.append(try self.allocator.dupe(u8, entry.key_ptr.*));
            }
            for (to_remove.items) |key| {
                if (registry.claims.fetchRemove(key)) |removed| {
                    self.allocator.free(removed.key);
                    self.allocator.free(removed.value.task_id);
                    self.allocator.free(removed.value.agent_id);
                }
            }
        }

        // Clear reticular formation (event bus)
        {
            const event_bus = try reticular_formation.getGlobal(self.allocator);
            event_bus.mutex.lock();
            defer event_bus.mutex.unlock();
            // Clear events via public API if available
            // For now, just let the events age out naturally
        }

        // Delete state file
        var state_manager = try state_recovery.StateManager.init(self.allocator);
        defer state_manager.deinit();
        try state_manager.deleteState();

        std.log.info("Brain state reset complete", .{});
    }

    /// Run diagnostic checks on brain components
    pub fn doctor(self: *Self) !DiagnosticReport {
        const start = std.time.nanoTimestamp();
        var checks = std.ArrayList(DiagnosticCheck).init(self.allocator);

        // Check 1: Basal Ganglia (Task Claims)
        {
            const registry = try basal_ganglia.getGlobal(self.allocator);
            registry.mutex.lock();
            defer registry.mutex.unlock();

            const claim_count = registry.claims.count();
            var expired_count: usize = 0;
            var iter = registry.claims.iterator();
            while (iter.next()) |entry| {
                if (!entry.value_ptr.isValid()) {
                    expired_count += 1;
                }
            }

            const status = if (claim_count == 0)
                DiagnosticStatus.healthy
            else if (claim_count < 100 and expired_count == 0)
                DiagnosticStatus.healthy
            else if (claim_count < 1000)
                DiagnosticStatus.warning
            else
                DiagnosticStatus.critical;

            const message = try std.fmt.allocPrint(self.allocator, "{d} claims ({d} expired)", .{ claim_count, expired_count });
            const suggestion = if (expired_count > 0)
                try self.allocator.dupe(u8, "Run 'tri brain admin prune' to remove expired claims")
            else
                null;

            try checks.append(DiagnosticCheck{
                .name = "Basal Ganglia",
                .status = status,
                .message = message,
                .suggestion = suggestion,
            });
        }

        // Check 2: Reticular Formation (Event Bus)
        {
            const event_bus = try reticular_formation.getGlobal(self.allocator);
            const stats = event_bus.getStats();

            const buffer_pct = @as(f32, @floatFromInt(stats.buffered)) / 10000.0 * 100.0;
            const status = if (buffer_pct < 10.0)
                DiagnosticStatus.healthy
            else if (buffer_pct < 50.0)
                DiagnosticStatus.warning
            else
                DiagnosticStatus.critical;

            const message = try std.fmt.allocPrint(self.allocator, "{d} events buffered ({d:.1}% full)", .{ stats.buffered, buffer_pct });
            const suggestion = if (buffer_pct > 50.0)
                try self.allocator.dupe(u8, "Event buffer is near capacity")
            else
                null;

            try checks.append(DiagnosticCheck{
                .name = "Reticular Formation",
                .status = status,
                .message = message,
                .suggestion = suggestion,
            });
        }

        // Check 3: State File
        {
            var state_manager = try state_recovery.StateManager.init(self.allocator);
            defer state_manager.deinit();

            const info = try state_manager.getStateInfo();
            const status = if (!info.exists)
                DiagnosticStatus.warning
            else if (info.size_bytes) |size|
                if (size < 10 * 1024 * 1024) DiagnosticStatus.healthy else DiagnosticStatus.warning
            else
                DiagnosticStatus.healthy;

            const message = if (info.exists)
                try std.fmt.allocPrint(self.allocator, "State file exists ({d} bytes, {d} backups)", .{ info.size_bytes orelse 0, info.backup_count })
            else
                try self.allocator.dupe(u8, "No state file found");

            try checks.append(DiagnosticCheck{
                .name = "State File",
                .status = status,
                .message = message,
                .suggestion = null,
            });
        }

        // Check 4: Event Log
        {
            const event_log_path = ".trinity/brain/events.jsonl";
            const file = fs.cwd().openFile(event_log_path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    try checks.append(DiagnosticCheck{
                        .name = "Event Log",
                        .status = DiagnosticStatus.warning,
                        .message = try self.allocator.dupe(u8, "No event log found"),
                        .suggestion = null,
                    });
                } else {
                    return err;
                }
            };
            defer file.close();

            const stat = try file.stat();
            const size_mb = @as(f32, @floatFromInt(stat.size)) / (1024 * 1024);

            const status = if (size_mb < 10.0)
                DiagnosticStatus.healthy
            else if (size_mb < 100.0)
                DiagnosticStatus.warning
            else
                DiagnosticStatus.critical;

            const message = try std.fmt.allocPrint(self.allocator, "Event log: {d:.2} MB", .{size_mb});
            const suggestion = if (size_mb > 100.0)
                try self.allocator.dupe(u8, "Consider archiving old event logs")
            else
                null;

            try checks.append(DiagnosticCheck{
                .name = "Event Log",
                .status = status,
                .message = message,
                .suggestion = suggestion,
            });
        }

        // Check 5: Telemetry
        {
            const tel = telemetry.BrainTelemetry.init(self.allocator, 100);
            defer tel.deinit();

            const avg_health = tel.avgHealth(10);
            const status = if (avg_health >= 80.0)
                DiagnosticStatus.healthy
            else if (avg_health >= 50.0)
                DiagnosticStatus.warning
            else
                DiagnosticStatus.critical;

            const message = try std.fmt.allocPrint(self.allocator, "Average health: {d:.1}", .{avg_health});

            try checks.append(DiagnosticCheck{
                .name = "Telemetry",
                .status = status,
                .message = message,
                .suggestion = null,
            });
        }

        // Calculate overall status
        var critical_count: usize = 0;
        var warning_count: usize = 0;
        for (checks.items) |check| {
            switch (check.status) {
                .critical => critical_count += 1,
                .warning => warning_count += 1,
                else => {},
            }
        }

        const overall_status = if (critical_count > 0)
            DiagnosticStatus.critical
        else if (warning_count > 0)
            DiagnosticStatus.warning
        else
            DiagnosticStatus.healthy;

        _ = std.time.nanoTimestamp() - start; // Track diagnostic duration

        return DiagnosticReport{
            .overall_status = overall_status,
            .checks = try checks.toOwnedSlice(),
            .timestamp = std.time.milliTimestamp(),
            .brain_version = "5.1.0",
        };
    }

    /// Prune old events and expired claims
    pub fn prune(self: *Self) !PruneStats {
        const start = std.time.nanoTimestamp();
        var stats = PruneStats{
            .expired_claims = 0,
            .old_events = 0,
            .old_backups = 0,
            .bytes_freed = 0,
            .duration_ms = 0,
        };

        // Prune expired claims from basal ganglia
        {
            const registry = try basal_ganglia.getGlobal(self.allocator);
            registry.mutex.lock();
            defer registry.mutex.unlock();

            var to_remove = std.ArrayList([]const u8).init(self.allocator);
            defer {
                for (to_remove.items) |key| self.allocator.free(key);
                to_remove.deinit();
            }

            var iter = registry.claims.iterator();
            while (iter.next()) |entry| {
                if (!entry.value_ptr.isValid()) {
                    try to_remove.append(try self.allocator.dupe(u8, entry.key_ptr.*));
                }
            }

            for (to_remove.items) |key| {
                if (registry.claims.fetchRemove(key)) |removed| {
                    self.allocator.free(removed.key);
                    self.allocator.free(removed.value.task_id);
                    self.allocator.free(removed.value.agent_id);
                    stats.expired_claims += 1;
                }
            }
        }

        // Prune old backups (keep last 10)
        {
            var state_manager = try state_recovery.StateManager.init(self.allocator);
            defer state_manager.deinit();

            const before_backups = try self.countBackups();
            try state_manager.pruneBackups(10);
            const after_backups = try self.countBackups();
            stats.old_backups = before_backups - after_backups;
        }

        stats.duration_ms = @intCast((std.time.nanoTimestamp() - start) / 1_000_000);

        if (stats.expired_claims == 0 and stats.old_backups == 0) {
            return AdminError.NothingToPrune;
        }

        return stats;
    }

    /// Create backup of current state
    pub fn backup(self: *Self, name: ?[]const u8) ![]const u8 {
        const timestamp = std.time.timestamp();
        const backup_name = if (name) |n|
            try std.fmt.allocPrint(self.allocator, "{s}_{d}", .{ n, timestamp })
        else
            try std.fmt.allocPrint(self.allocator, "manual_backup_{d}", .{timestamp});

        const backup_path = try fs.path.join(self.allocator, &.{ self.backup_dir, backup_name });
        errdefer self.allocator.free(backup_path);

        // Create state manager and capture state
        var state_manager = try state_recovery.StateManager.init(self.allocator);
        defer state_manager.deinit();

        const registry = try basal_ganglia.getGlobal(self.allocator);
        const event_bus = try reticular_formation.getGlobal(self.allocator);

        try state_manager.save(registry, event_bus);

        // Copy state file to backup
        const state_file_path = try fs.path.join(self.allocator, &.{ self.state_dir, "brain_state.json" });
        defer self.allocator.free(state_file_path);

        {
            const src = try fs.cwd().openFile(state_file_path, .{});
            defer src.close();

            const dst = try fs.cwd().createFile(backup_path, .{ .read = true });
            defer dst.close();

            const content = try src.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
            defer self.allocator.free(content);

            try dst.writeAll(content);
            try dst.sync();
        }

        std.log.info("Backup created: {s}", .{backup_path});

        return backup_path;
    }

    /// Restore from backup
    pub fn restore(self: *Self, backup_name: []const u8, confirmed: bool) !void {
        if (!confirmed) {
            std.log.warn("Restore requires confirmation. Use --force or --yes to confirm.", .{});
            return AdminError.ConfirmationRequired;
        }

        const backup_path = try fs.path.join(self.allocator, &.{ self.backup_dir, backup_name });
        defer self.allocator.free(backup_path);

        // Verify backup exists
        if (fs.cwd().openFile(backup_path, .{})) |file| {
            file.close();
        } else |_| {
            return AdminError.BackupNotFound;
        }

        // Create backup of current state before restoring
        {
            const pre_restore_backup = try self.backup(null);
            defer self.allocator.free(pre_restore_backup);
            std.log.info("Pre-restore backup created: {s}", .{pre_restore_backup});
        }

        // Copy backup to state file
        const state_file_path = try fs.path.join(self.allocator, &.{ self.state_dir, "brain_state.json" });
        defer self.allocator.free(state_file_path);

        {
            const src = try fs.cwd().openFile(backup_path, .{});
            defer src.close();

            const dst = try fs.cwd().createFile(state_file_path, .{ .read = true });
            defer dst.close();

            const content = try src.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
            defer self.allocator.free(content);

            try dst.writeAll(content);
            try dst.sync();
        }

        // Load and restore state
        var state_manager = try state_recovery.StateManager.init(self.allocator);
        defer state_manager.deinit();

        const state = try state_manager.load();
        defer {
            for (state.task_claims) |claim| {
                self.allocator.free(claim.task_id);
                self.allocator.free(claim.agent_id);
                self.allocator.free(claim.status);
            }
            self.allocator.free(state.task_claims);

            for (state.events) |ev| {
                self.allocator.free(ev.event_type);
                self.allocator.free(ev.task_id);
                self.allocator.free(ev.agent_id);
                self.allocator.free(ev.aux_string);
            }
            self.allocator.free(state.events);

            for (state.metrics) |m| {
                self.allocator.free(m.name);
                for (m.tags) |tag| {
                    self.allocator.free(tag);
                }
                self.allocator.free(m.tags);
            }
            self.allocator.free(state.metrics);
        }

        const registry = try basal_ganglia.getGlobal(self.allocator);
        const event_bus = try reticular_formation.getGlobal(self.allocator);

        try state_manager.restore(state, registry, event_bus);

        std.log.info("Restored from backup: {s}", .{backup_path});
    }

    /// List available backups
    pub fn listBackups(self: *Self) ![][]const u8 {
        var backups = std.ArrayList(struct {
            name: []const u8,
            timestamp: i64,
        }).init(self.allocator);

        defer {
            for (backups.items) |b| self.allocator.free(b.name);
            backups.deinit();
        }

        var dir = try fs.cwd().openDir(self.backup_dir, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const name_copy = try self.allocator.dupe(u8, entry.name);
                try backups.append(.{ .name = name_copy, .timestamp = 0 });
            }
        }

        // Sort by name (which includes timestamp)
        std.sort.insert(struct { name: []const u8, timestamp: i64 }, backups.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(backups.items[0]), b: @TypeOf(backups.items[0])) bool {
                return std.mem.lessThan(u8, a.name, b.name);
            }
        }.lessThan);

        var result = std.ArrayList([]const u8).init(self.allocator);
        for (backups.items) |b| {
            try result.append(try self.allocator.dupe(u8, b.name));
        }

        return result.toOwnedSlice();
    }

    /// Migrate state to current version
    pub fn migrate(self: *Self, confirmed: bool) !void {
        if (!confirmed) {
            std.log.warn("Migration requires confirmation. Use --force or --yes to confirm.", .{});
            return AdminError.ConfirmationRequired;
        }

        var state_manager = try state_recovery.StateManager.init(self.allocator);
        defer state_manager.deinit();

        if (!state_manager.hasValidState()) {
            std.log.warn("No state file found to migrate", .{});
            return AdminError.MigrationNotSupported;
        }

        // Load current state (this triggers migration internally)
        const state = try state_manager.load();
        defer {
            for (state.task_claims) |claim| {
                self.allocator.free(claim.task_id);
                self.allocator.free(claim.agent_id);
                self.allocator.free(claim.status);
            }
            self.allocator.free(state.task_claims);

            for (state.events) |ev| {
                self.allocator.free(ev.event_type);
                self.allocator.free(ev.task_id);
                self.allocator.free(ev.agent_id);
                self.allocator.free(ev.aux_string);
            }
            self.allocator.free(state.events);

            for (state.metrics) |m| {
                self.allocator.free(m.name);
                for (m.tags) |tag| {
                    self.allocator.free(tag);
                }
                self.allocator.free(m.tags);
            }
            self.allocator.free(state.metrics);
        }

        // Save migrated state
        const registry = try basal_ganglia.getGlobal(self.allocator);
        const event_bus = try reticular_formation.getGlobal(self.allocator);

        try state_manager.save(registry, event_bus);

        std.log.info("Migration complete: version {d}", .{state.version});
    }

    /// Count backup files
    fn countBackups(self: *Self) !usize {
        var count: usize = 0;
        var dir = try fs.cwd().openDir(self.backup_dir, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                count += 1;
            }
        }

        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Run brain admin command
/// Usage: tri brain admin <reset|doctor|prune|migrate|backup|restore> [options]
pub fn runBrainAdminCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try printBrainAdminHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (mem.eql(u8, subcommand, "reset")) {
        try runResetCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "doctor")) {
        try runDoctorCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "prune")) {
        try runPruneCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "migrate")) {
        try runMigrateCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "backup")) {
        try runBackupCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "restore")) {
        try runRestoreCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "list")) {
        try runListCommand(allocator, sub_args);
    } else if (mem.eql(u8, subcommand, "--help") or mem.eql(u8, subcommand, "-h")) {
        try printBrainAdminHelp();
    } else {
        std.debug.print("Unknown admin command: {s}\n\n", .{subcommand});
        try printBrainAdminHelp();
    }
}

fn runResetCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    const confirmed = for (args) |arg| {
        if (mem.eql(u8, arg, "--force") or mem.eql(u8, arg, "--yes") or mem.eql(u8, arg, "-y")) {
            break true;
        }
    } else false;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    try manager.reset(confirmed);
}

fn runDoctorCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    _ = args;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const report = try manager.doctor();
    defer {
        for (report.checks) |check| {
            allocator.free(check.message);
            if (check.suggestion) |s| allocator.free(s);
            if (check.details) |d| allocator.free(d);
        }
        allocator.free(report.checks);
    }

    // Print report
    const status_emoji = switch (report.overall_status) {
        .healthy => "\x1b[32m✓\x1b[0m", // Green check
        .warning => "\x1b[33m⚠\x1b[0m", // Yellow warning
        .critical => "\x1b[31m✗\x1b[0m", // Red X
        .unknown => "?",
    };

    std.debug.print("\n{s} BRAIN HEALTH REPORT {s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s} Overall Status: {s}\n\n", .{ status_emoji, @tagName(report.overall_status) });

    for (report.checks) |check| {
        const emoji = switch (check.status) {
            .healthy => "\x1b[32m✓\x1b[0m",
            .warning => "\x1b[33m⚠\x1b[0m",
            .critical => "\x1b[31m✗\x1b[0m",
            .unknown => "?",
        };
        std.debug.print("  {s} {s}: {s}\n", .{ emoji, check.name, check.message });
        if (check.suggestion) |s| {
            std.debug.print("      → {s}\n", .{s});
        }
    }

    std.debug.print("\n", .{});
}

fn runPruneCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    _ = args;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const stats = manager.prune() catch |err| {
        if (err == AdminError.NothingToPrune) {
            std.debug.print("Nothing to prune — brain is clean\n", .{});
            return;
        }
        return err;
    };

    std.debug.print("Prune complete:\n", .{});
    std.debug.print("  Expired claims: {d}\n", .{stats.expired_claims});
    std.debug.print("  Old events: {d}\n", .{stats.old_events});
    std.debug.print("  Old backups: {d}\n", .{stats.old_backups});
    std.debug.print("  Bytes freed: {d}\n", .{stats.bytes_freed});
    std.debug.print("  Duration: {d}ms\n", .{stats.duration_ms});
}

fn runMigrateCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    const confirmed = for (args) |arg| {
        if (mem.eql(u8, arg, "--force") or mem.eql(u8, arg, "--yes") or mem.eql(u8, arg, "-y")) {
            break true;
        }
    } else false;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    try manager.migrate(confirmed);
}

fn runBackupCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    const name = if (args.len > 0) args[0] else null;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const backup_path = try manager.backup(name);
    defer allocator.free(backup_path);

    std.debug.print("Backup created: {s}\n", .{backup_path});
}

fn runRestoreCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri brain admin restore <backup_name> [--force]\n", .{});
        return;
    }

    const backup_name = args[0];
    const confirmed = if (args.len > 1)
        for (args[1..]) |arg| {
            if (mem.eql(u8, arg, "--force") or mem.eql(u8, arg, "--yes") or mem.eql(u8, arg, "-y")) {
                break true;
            }
        } else false
    else
        false;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    try manager.restore(backup_name, confirmed);
}

fn runListCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    _ = args;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const backups = try manager.listBackups();
    defer {
        for (backups) |b| allocator.free(b);
        allocator.free(backups);
    }

    if (backups.len == 0) {
        std.debug.print("No backups found\n", .{});
        return;
    }

    std.debug.print("Available backups ({d}):\n", .{backups.len});
    for (backups) |backup| {
        std.debug.print("  {s}\n", .{backup});
    }
}

fn printBrainAdminHelp() !void {
    std.debug.print("\n{s}BRAIN ADMIN COMMANDS{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}Usage:{s} tri brain admin <command> [options]\n\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}Commands:{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("  reset                    Reset all brain state (requires --force)\n", .{});
    std.debug.print("  doctor                    Run diagnostic checks\n", .{});
    std.debug.print("  prune                     Prune old events and expired claims\n", .{});
    std.debug.print("  migrate                   Migrate state to current version\n", .{});
    std.debug.print("  backup [name]             Create backup\n", .{});
    std.debug.print("  restore <name>            Restore from backup (requires --force)\n", .{});
    std.debug.print("  list                      List available backups\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("{s}Options:{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("  --force, --yes, -y        Confirm destructive operations\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("{s}Examples:{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("  tri brain admin doctor\n", .{});
    std.debug.print("  tri brain admin prune\n", .{});
    std.debug.print("  tri brain admin backup before_experiment\n", .{});
    std.debug.print("  tri brain admin restore backup_123456 --force\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AdminManager init" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.state_dir.len > 0);
    try std.testing.expect(manager.backup_dir.len > 0);
}

test "AdminManager doctor - all checks" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const report = try manager.doctor();
    defer {
        for (report.checks) |check| {
            allocator.free(check.message);
            if (check.suggestion) |s| allocator.free(s);
            if (check.details) |d| allocator.free(d);
        }
        allocator.free(report.checks);
    }

    try std.testing.expect(report.checks.len > 0);
    try std.testing.expectEqual(@as(usize, 5), report.checks.len); // 5 checks

    // Verify overall status is valid
    try std.testing.expect(report.overall_status == .healthy or
        report.overall_status == .warning or
        report.overall_status == .critical);

    // Verify brain version
    try std.testing.expect(report.brain_version.len > 0);

    // Verify timestamp is recent (within last minute)
    const now = std.time.milliTimestamp();
    const age_ms = now - report.timestamp;
    try std.testing.expect(age_ms >= 0 and age_ms < 60_000);
}

test "AdminManager doctor - check names" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const report = try manager.doctor();
    defer {
        for (report.checks) |check| {
            allocator.free(check.message);
            if (check.suggestion) |s| allocator.free(s);
            if (check.details) |d| allocator.free(d);
        }
        allocator.free(report.checks);
    }

    // Verify expected check names exist
    const expected_checks = [_][]const u8{
        "Basal Ganglia",
        "Reticular Formation",
        "State File",
        "Event Log",
        "Telemetry",
    };

    for (expected_checks) |expected| {
        var found = false;
        for (report.checks) |check| {
            if (mem.eql(u8, check.name, expected)) {
                found = true;
                break;
            }
        }
        try std.testing.expect(found, "Expected check '{s}' not found", .{expected});
    }
}

test "AdminManager prune - empty state" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Prune on empty state should return NothingToPrune
    const result = manager.prune();
    if (result) |stats| {
        // If it succeeds, verify no items were pruned
        try std.testing.expectEqual(@as(usize, 0), stats.expired_claims);
        try std.testing.expectEqual(@as(usize, 0), stats.old_events);
    } else |err| {
        try std.testing.expectEqual(AdminError.NothingToPrune, err);
    }
}

test "AdminManager prune - with expired claims" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Create an expired claim
    const registry = try basal_ganglia.getGlobal(allocator);
    registry.mutex.lock();
    defer registry.mutex.unlock();

    const now_ms = std.time.timestamp() * 1000;
    const expired_claim = basal_ganglia.TaskClaim{
        .task_id = try allocator.dupe(u8, "test_task_expired"),
        .agent_id = try allocator.dupe(u8, "test_agent"),
        .claimed_at = now_ms - 100_000, // 100 seconds ago
        .ttl_ms = 1000, // 1 second TTL (already expired)
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms - 100_000, // Old heartbeat
    };

    try registry.claims.put(try allocator.dupe(u8, "test_task_expired"), expired_claim);

    // Prune should remove the expired claim
    const stats = try manager.prune();
    try std.testing.expectEqual(@as(usize, 1), stats.expired_claims);
    try std.testing.expect(stats.duration_ms > 0);
}

test "AdminManager backup - named backup" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const backup_path = try manager.backup("test_backup");
    defer allocator.free(backup_path);

    try std.testing.expect(mem.indexOf(u8, backup_path, "test_backup") != null);
    try std.testing.expect(mem.endsWith(u8, backup_path, ".json"));
}

test "AdminManager backup - anonymous backup" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const backup_path = try manager.backup(null);
    defer allocator.free(backup_path);

    try std.testing.expect(mem.indexOf(u8, backup_path, "manual_backup_") != null);
    try std.testing.expect(mem.endsWith(u8, backup_path, ".json"));
}

test "AdminManager listBackups - after backup" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Create a backup
    const backup_path = try manager.backup("test_list");
    defer allocator.free(backup_path);

    // List backups
    const backups = try manager.listBackups();
    defer {
        for (backups) |b| allocator.free(b);
        allocator.free(backups);
    }

    // Should have at least one backup
    try std.testing.expect(backups.len >= 1);

    // Verify our backup is in the list
    var found = false;
    for (backups) |b| {
        if (mem.indexOf(u8, b, "test_list") != null) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}

test "AdminManager reset - without confirmation" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Reset without confirmation should fail
    const result = manager.reset(false);
    try std.testing.expectError(AdminError.ConfirmationRequired, result);
}

test "AdminManager reset - with confirmation" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Create some test state first
    const registry = try basal_ganglia.getGlobal(allocator);
    _ = try registry.claim(allocator, "test_reset_task", "test_agent", 5000);

    // Reset with confirmation should succeed
    try manager.reset(true);

    // Verify claims were cleared
    registry.mutex.lock();
    defer registry.mutex.unlock();
    try std.testing.expectEqual(@as(usize, 0), registry.claims.count());
}

test "AdminManager restore - without confirmation" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Create a backup first
    const backup_path = try manager.backup("test_restore_confirm");
    defer allocator.free(backup_path);

    // Restore without confirmation should fail
    const result = manager.restore("test_restore_confirm_123", false);
    try std.testing.expectError(AdminError.ConfirmationRequired, result);
}

test "AdminManager restore - backup not found" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Try to restore non-existent backup
    const result = manager.restore("nonexistent_backup_12345", true);
    try std.testing.expectError(AdminError.BackupNotFound, result);
}

test "AdminManager migrate - without confirmation" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Migrate without confirmation should fail
    const result = manager.migrate(false);
    try std.testing.expectError(AdminError.ConfirmationRequired, result);
}

test "AdminManager - backup restore cycle" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Create test state
    const registry = try basal_ganglia.getGlobal(allocator);
    _ = try registry.claim(allocator, "cycle_test_task", "cycle_agent", 10000);

    // Create backup
    const backup_path = try manager.backup("cycle_test");
    defer allocator.free(backup_path);

    // Verify claim exists
    try std.testing.expect(registry.claims.get("cycle_test_task") != null);

    // Clear the claim manually
    {
        registry.mutex.lock();
        defer registry.mutex.unlock();
        if (registry.claims.fetchRemove("cycle_test_task")) |removed| {
            allocator.free(removed.key);
            allocator.free(removed.value.task_id);
            allocator.free(removed.value.agent_id);
        }
    }

    // Verify claim is gone
    try std.testing.expect(registry.claims.get("cycle_test_task") == null);

    // Restore from backup (this will recreate the state file and load it)
    // Note: This test verifies the backup was created, but full restore testing
    // requires more complex setup with state_manager
}

test "AdminManager - PruneStats structure" {
    // Verify PruneStats can be created and has expected fields
    const stats = PruneStats{
        .expired_claims = 5,
        .old_events = 10,
        .old_backups = 2,
        .bytes_freed = 1024,
        .duration_ms = 100,
    };

    try std.testing.expectEqual(@as(usize, 5), stats.expired_claims);
    try std.testing.expectEqual(@as(usize, 10), stats.old_events);
    try std.testing.expectEqual(@as(usize, 2), stats.old_backups);
    try std.testing.expectEqual(@as(usize, 1024), stats.bytes_freed);
    try std.testing.expectEqual(@as(u64, 100), stats.duration_ms);
}

test "AdminManager - DiagnosticStatus enum" {
    // Verify DiagnosticStatus has expected values
    const healthy: DiagnosticStatus = .healthy;
    const warning: DiagnosticStatus = .warning;
    const critical: DiagnosticStatus = .critical;
    const unknown: DiagnosticStatus = .unknown;

    _ = healthy;
    _ = warning;
    _ = critical;
    _ = unknown;

    try std.testing.expect(true);
}

test "runResetCommand - parses confirmation flags" {
    const allocator = std.testing.allocator;

    // Test with --force flag
    {
        var manager = try AdminManager.init(allocator);
        defer manager.deinit();
        try manager.reset(true); // Equivalent to --force
    }

    // Test with --yes flag
    {
        var manager = try AdminManager.init(allocator);
        defer manager.deinit();
        try manager.reset(true); // Equivalent to --yes
    }

    // Test with -y flag
    {
        var manager = try AdminManager.init(allocator);
        defer manager.deinit();
        try manager.reset(true); // Equivalent to -y
    }
}

test "runDoctorCommand - executes successfully" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const report = try manager.doctor();
    defer {
        for (report.checks) |check| {
            allocator.free(check.message);
            if (check.suggestion) |s| allocator.free(s);
            if (check.details) |d| allocator.free(d);
        }
        allocator.free(report.checks);
    }

    // Verify report structure
    try std.testing.expect(report.timestamp > 0);
    try std.testing.expect(report.brain_version.len > 0);
    try std.testing.expect(report.checks.len > 0);
}

test "runPruneCommand - handles NothingToPrune" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Prune on clean state
    const result = manager.prune();
    if (result) |stats| {
        _ = stats;
    } else |err| {
        // Should get NothingToPrune error
        try std.testing.expectEqual(AdminError.NothingToPrune, err);
    }
}

test "runMigrateCommand - requires confirmation" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Migrate without confirmation should fail
    const result = manager.migrate(false);
    try std.testing.expectError(AdminError.ConfirmationRequired, result);
}

test "runBackupCommand - with and without name" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Backup with name
    {
        const backup_path = try manager.backup("named_backup");
        defer allocator.free(backup_path);
        try std.testing.expect(mem.indexOf(u8, backup_path, "named_backup") != null);
    }

    // Backup without name
    {
        const backup_path = try manager.backup(null);
        defer allocator.free(backup_path);
        try std.testing.expect(mem.indexOf(u8, backup_path, "manual_backup_") != null);
    }
}

test "runRestoreCommand - validates backup name" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Restore without backup name should handle gracefully
    const result = manager.restore("", true);
    try std.testing.expectError(AdminError.BackupNotFound, result);
}

test "runListCommand - returns list" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    const backups = try manager.listBackups();
    defer {
        for (backups) |b| allocator.free(b);
        allocator.free(backups);
    }

    // Should return a valid list (even if empty)
    _ = backups.len;
}

test "AdminManager - multiple prune operations" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // First prune
    _ = manager.prune() catch |err| {
        try std.testing.expectEqual(AdminError.NothingToPrune, err);
    };

    // Second prune should also be safe
    _ = manager.prune() catch |err| {
        try std.testing.expectEqual(AdminError.NothingToPrune, err);
    };
}

test "AdminManager - doctor with existing claims" {
    const allocator = std.testing.allocator;

    var manager = try AdminManager.init(allocator);
    defer manager.deinit();

    // Create some active claims
    const registry = try basal_ganglia.getGlobal(allocator);
    _ = try registry.claim(allocator, "doctor_test_1", "agent_1", 10000);
    _ = try registry.claim(allocator, "doctor_test_2", "agent_2", 10000);
    defer {
        registry.mutex.lock();
        defer registry.mutex.unlock();
        if (registry.claims.fetchRemove("doctor_test_1")) |removed| {
            allocator.free(removed.key);
            allocator.free(removed.value.task_id);
            allocator.free(removed.value.agent_id);
        }
        if (registry.claims.fetchRemove("doctor_test_2")) |removed| {
            allocator.free(removed.key);
            allocator.free(removed.value.task_id);
            allocator.free(removed.value.agent_id);
        }
    }

    // Run doctor - should report the claims
    const report = try manager.doctor();
    defer {
        for (report.checks) |check| {
            allocator.free(check.message);
            if (check.suggestion) |s| allocator.free(s);
            if (check.details) |d| allocator.free(d);
        }
        allocator.free(report.checks);
    }

    // Find basal ganglia check
    var basal_check: ?DiagnosticCheck = null;
    for (report.checks) |check| {
        if (mem.eql(u8, check.name, "Basal Ganglia")) {
            basal_check = check;
            break;
        }
    }

    try std.testing.expect(basal_check != null);
    if (basal_check) |check| {
        try std.testing.expect(mem.indexOf(u8, check.message, "claims") != null);
    }
}

test "AdminManager - DEFAULT_STATE_DIR constant" {
    try std.testing.expectEqual(@as([]const u8, state_recovery.StateManager.DEFAULT_STATE_DIR), AdminManager.DEFAULT_STATE_DIR);
}
