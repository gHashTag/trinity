//! BRAIN STATE RECOVERY — v1.0 — Persistence and Crash Recovery
//!
//! Brain Region: Hippocampus (Long-term Memory Consolidation)
//!
//! Provides:
//! - Save brain state to JSON (task claims, event history, metrics)
//! - Load brain state on startup (crash recovery)
//! - State versioning with migration support
//! - Corrupted state file handling
//! - Automatic recovery on startup
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const json = std.json;

// Import brain region modules via module names (from build.zig)
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");

// ═══════════════════════════════════════════════════════════════════════════════
// STATE VERSIONING
// ═══════════════════════════════════════════════════════════════════════════════

/// Current state format version
pub const CURRENT_VERSION: u32 = 1;

/// Migration error
pub const MigrationError = error{
    UnsupportedVersion,
    CorruptedData,
    MigrationFailed,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN STATE STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Task claim state for serialization
pub const TaskClaimState = struct {
    task_id: []const u8,
    agent_id: []const u8,
    claimed_at: i64,
    ttl_ms: u64,
    status: []const u8, // "active", "completed", "abandoned"
    completed_at: ?i64,
    last_heartbeat: i64,
};

/// Event record state for serialization
pub const EventState = struct {
    event_type: []const u8, // stringified AgentEventType
    timestamp: i64,
    task_id: []const u8,
    agent_id: []const u8,
    aux_string: []const u8, // err_msg, reason, or unused
    duration_ms: u64,
};

/// Metric snapshot for serialization
pub const MetricSnapshot = struct {
    name: []const u8,
    value: f64,
    timestamp: i64,
    tags: []const []const u8, // key=value pairs
};

/// Complete brain state
pub const BrainState = struct {
    version: u32 = CURRENT_VERSION,
    saved_at: i64,
    task_claims: []TaskClaimState,
    events: []EventState,
    metrics: []MetricSnapshot,
    metadata: struct {
        hostname: []const u8,
        pid: u32,
        tri_version: []const u8,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATE MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const StateManager = struct {
    allocator: mem.Allocator,
    state_dir: []const u8,
    state_file_path: []const u8,
    backup_dir: []const u8,

    const Self = @This();

    /// Default state directory
    pub const DEFAULT_STATE_DIR = ".trinity/brain/state";

    /// Initialize state manager with default paths
    pub fn init(allocator: mem.Allocator) !Self {
        const state_dir = DEFAULT_STATE_DIR;
        try fs.cwd().makePath(state_dir);

        const state_file_path = try fs.path.join(allocator, &.{ state_dir, "brain_state.json" });
        errdefer allocator.free(state_file_path);

        const backup_dir = try fs.path.join(allocator, &.{ state_dir, "backups" });
        errdefer allocator.free(backup_dir);

        try fs.cwd().makePath(backup_dir);

        return Self{
            .allocator = allocator,
            .state_dir = state_dir,
            .state_file_path = state_file_path,
            .backup_dir = backup_dir,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.state_file_path);
        self.allocator.free(self.backup_dir);
    }

    /// Save current brain state to disk
    /// Returns error if save fails (caller should retry)
    pub fn save(self: *Self, registry: *basal_ganglia.Registry, event_bus: *reticular_formation.EventBus) !void {
        const state = try self.captureState(registry, event_bus);
        defer self.freeState(state);

        // Create backup before overwriting
        try self.createBackup();

        // Write to temporary file first (atomic write)
        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{self.state_file_path});
        defer self.allocator.free(tmp_path);

        const file = try fs.cwd().createFile(tmp_path, .{ .read = true });
        defer file.close();

        // Write JSON with pretty formatting
        try json.stringify(state, .{ .whitespace = .indent_2 }, file.writer());

        // Sync to disk
        try file.sync();

        // Atomic rename
        try fs.cwd().rename(tmp_path, self.state_file_path);

        std.log.info("Brain state saved to {s}", .{self.state_file_path});
    }

    /// Load brain state from disk
    /// Returns error if file not found or corrupted (caller should use defaults)
    pub fn load(self: *Self) !BrainState {
        const file = fs.cwd().openFile(self.state_file_path, .{}) catch |err| {
            std.log.warn("Failed to open brain state file: {}", .{err});
            return error.FileNotFound;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch |err| {
            std.log.warn("Failed to read brain state file: {}", .{err});
            return error.CorruptedData;
        };
        defer self.allocator.free(content);

        var parsed = json.parseFromSlice(BrainState, self.allocator, content, .{}) catch |err| {
            std.log.warn("Failed to parse brain state JSON: {}", .{err});
            return error.CorruptedData;
        };
        defer parsed.deinit();

        const state = parsed.value;

        // Validate and migrate if needed
        try self.validateAndMigrate(&state);

        std.log.info("Brain state loaded from {s} (version {d})", .{ self.state_file_path, state.version });
        return state;
    }

    /// Capture current state from live brain components
    fn captureState(self: *Self, registry: *basal_ganglia.Registry, event_bus: *reticular_formation.EventBus) !BrainState {
        // Capture task claims
        var claims = std.ArrayList(TaskClaimState).init(self.allocator);
        defer claims.deinit();

        {
            registry.mutex.lock();
            defer registry.mutex.unlock();

            var iter = registry.claims.iterator();
            while (iter.next()) |entry| {
                const claim = &entry.value_ptr.*;
                const status_str = switch (claim.status) {
                    .active => "active",
                    .completed => "completed",
                    .abandoned => "abandoned",
                };

                try claims.append(TaskClaimState{
                    .task_id = try self.allocator.dupe(u8, claim.task_id),
                    .agent_id = try self.allocator.dupe(u8, claim.agent_id),
                    .claimed_at = claim.claimed_at,
                    .ttl_ms = claim.ttl_ms,
                    .status = status_str,
                    .completed_at = claim.completed_at,
                    .last_heartbeat = claim.last_heartbeat,
                });
            }
        }

        // Capture events from reticular formation
        var events = std.ArrayList(EventState).init(self.allocator);
        defer events.deinit();

        {
            event_bus.mutex.lock();
            defer event_bus.mutex.unlock();

            for (event_bus.events.items) |ev| {
                const event_type_str = switch (ev.event_type) {
                    .task_claimed => "task_claimed",
                    .task_completed => "task_completed",
                    .task_failed => "task_failed",
                    .task_abandoned => "task_abandoned",
                    .agent_idle => "agent_idle",
                    .agent_spawned => "agent_spawned",
                };

                try events.append(EventState{
                    .event_type = event_type_str,
                    .timestamp = ev.timestamp,
                    .task_id = try self.allocator.dupe(u8, ev.task_id),
                    .agent_id = try self.allocator.dupe(u8, ev.agent_id),
                    .aux_string = try self.allocator.dupe(u8, ev.aux_string),
                    .duration_ms = ev.duration_ms,
                });
            }
        }

        // Capture metrics (simplified - just a snapshot)
        var metrics = std.ArrayList(MetricSnapshot).init(self.allocator);
        defer metrics.deinit();

        // Add basic health metrics
        const now = std.time.milliTimestamp();
        try metrics.append(MetricSnapshot{
            .name = "brain.claims.count",
            .value = @floatFromInt(claims.items.len),
            .timestamp = now,
            .tags = &[_][]const u8{},
        });
        try metrics.append(MetricSnapshot{
            .name = "brain.events.buffered",
            .value = @floatFromInt(events.items.len),
            .timestamp = now,
            .tags = &[_][]const u8{},
        });

        // Get hostname
        var hostname_buffer: [256]u8 = undefined;
        const hostname = std.os.gethostname(&hostname_buffer) catch &hostname_buffer;
        const hostname_len = mem.len(hostname);

        return BrainState{
            .version = CURRENT_VERSION,
            .saved_at = std.time.milliTimestamp(),
            .task_claims = try claims.toOwnedSlice(),
            .events = try events.toOwnedSlice(),
            .metrics = try metrics.toOwnedSlice(),
            .metadata = .{
                .hostname = hostname[0..hostname_len],
                .pid = std.os.linux.getpid() catch 0,
                .tri_version = "5.1.0-igla-ready",
            },
        };
    }

    /// Free state resources
    fn freeState(self: *Self, state: BrainState) void {
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

    /// Validate and migrate state if needed
    fn validateAndMigrate(self: *Self, state: *BrainState) !void {
        if (state.version > CURRENT_VERSION) {
            std.log.err("State version {d} is newer than supported version {d}", .{ state.version, CURRENT_VERSION });
            return MigrationError.UnsupportedVersion;
        }

        // Migrate from older versions (no-op for v1)
        while (state.version < CURRENT_VERSION) {
            try self.migrate(state);
        }
    }

    /// Migrate state to next version
    fn migrate(self: *Self, state: *BrainState) !void {
        _ = self;
        _ = state;

        switch (state.version) {
            1 => {
                // v1 -> v2 migration (placeholder for future)
                state.version = 2;
            },
            else => {
                std.log.err("Cannot migrate from version {d}", .{state.version});
                return MigrationError.MigrationFailed;
            },
        }
    }

    /// Create backup of current state file
    fn createBackup(self: *Self) !void {
        // Check if state file exists
        if (fs.cwd().openFile(self.state_file_path, .{})) |file| {
            file.close();

            // Create backup filename with timestamp
            const now = std.time.timestamp();
            const backup_name = try std.fmt.allocPrint(self.allocator, "brain_state_{d}.json", .{now});
            defer self.allocator.free(backup_name);

            const backup_path = try fs.path.join(self.allocator, &.{ self.backup_dir, backup_name });
            defer self.allocator.free(backup_path);

            // Copy file to backup
            {
                const src = try fs.cwd().openFile(self.state_file_path, .{});
                defer src.close();

                const dst = try fs.cwd().createFile(backup_path, .{});
                defer dst.close();

                const content = try src.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
                defer self.allocator.free(content);

                try dst.writeAll(content);
            }

            // Clean up old backups (keep last 10)
            try self.pruneBackups(10);

            std.log.info("Created backup: {s}", .{backup_path});
        } else |_| {
            // No existing state file, no backup needed
        }
    }

    /// Prune old backups, keeping only the most recent N
    fn pruneBackups(self: *Self, keep: usize) !void {
        var backups = std.ArrayList(struct {
            name: []const u8,
            timestamp: i64,
        }).init(self.allocator);

        defer {
            for (backups.items) |b| self.allocator.free(b.name);
            backups.deinit();
        }

        // List backup files
        var dir = try fs.cwd().openDir(self.backup_dir, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                // Parse timestamp from filename: brain_state_<timestamp>.json
                if (mem.startsWith(u8, entry.name, "brain_state_") and mem.endsWith(u8, entry.name, ".json")) {
                    const ts_str = entry.name["brain_state_".len .. entry.name.len - ".json".len];
                    const timestamp = std.fmt.parseInt(i64, ts_str, 10) catch continue;

                    const name_copy = try self.allocator.dupe(u8, entry.name);
                    try backups.append(.{ .name = name_copy, .timestamp = timestamp });
                }
            }
        }

        // Sort by timestamp (newest first)
        std.sort.insert(struct { name: []const u8, timestamp: i64 }, backups.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(backups.items[0]), b: @TypeOf(backups.items[0])) bool {
                return a.timestamp > b.timestamp;
            }
        }.lessThan);

        // Delete old backups
        if (backups.items.len > keep) {
            for (backups.items[keep..]) |old_backup| {
                const path = try fs.path.join(self.allocator, &.{ self.backup_dir, old_backup.name });
                defer self.allocator.free(path);

                fs.cwd().deleteFile(path) catch |err| {
                    std.log.warn("Failed to delete old backup {s}: {}", .{ path, err });
                };
            }
        }
    }

    /// Restore state to live brain components
    pub fn restore(self: *Self, state: BrainState, registry: *basal_ganglia.Registry, _event_bus: *reticular_formation.EventBus) !void {
        _ = _event_bus;

        // Restore task claims
        for (state.task_claims) |claim_state| {
            const status = if (mem.eql(u8, claim_state.status, "active"))
                basal_ganglia.TaskClaim.Status.active
            else if (mem.eql(u8, claim_state.status, "completed"))
                basal_ganglia.TaskClaim.Status.completed
            else if (mem.eql(u8, claim_state.status, "abandoned"))
                basal_ganglia.TaskClaim.Status.abandoned
            else
                return error.InvalidStatus;

            // Skip completed/abandoned claims, only restore active ones
            if (status != .active) continue;

            // Check if claim is still valid (not expired)
            const now_ms = std.time.timestamp() * 1000;
            const age_ms = @as(u64, @intCast(now_ms - claim_state.claimed_at));

            if (age_ms < claim_state.ttl_ms) {
                // Restore the claim
                const new_claim = basal_ganglia.TaskClaim{
                    .task_id = try self.allocator.dupe(u8, claim_state.task_id),
                    .agent_id = try self.allocator.dupe(u8, claim_state.agent_id),
                    .claimed_at = claim_state.claimed_at,
                    .ttl_ms = claim_state.ttl_ms,
                    .status = .active,
                    .completed_at = null,
                    .last_heartbeat = claim_state.last_heartbeat,
                };

                registry.mutex.lock();
                try registry.claims.put(
                    try self.allocator.dupe(u8, claim_state.task_id),
                    new_claim,
                );
                registry.mutex.unlock();
            }
        }

        // Note: We don't restore events to the event bus as it's a circular buffer
        // The events are preserved in the state file for debugging/analysis

        std.log.info("Restored {d} active task claims", .{state.task_claims.len});
    }

    /// Check if state file exists and is valid
    pub fn hasValidState(self: *Self) bool {
        if (fs.cwd().openFile(self.state_file_path, .{})) |file| {
            file.close();
            return true;
        } else |_| {
            return false;
        }
    }

    /// Get state file info
    pub const StateInfo = struct {
        exists: bool,
        path: []const u8,
        size_bytes: ?usize,
        modified_at: ?i64,
        backup_count: usize,
    };

    pub fn getStateInfo(self: *Self) !StateInfo {
        const stat = fs.cwd().statFile(self.state_file_path) catch |err| {
            if (err == error.FileNotFound) {
                return StateInfo{
                    .exists = false,
                    .path = self.state_file_path,
                    .size_bytes = null,
                    .modified_at = null,
                    .backup_count = 0,
                };
            }
            return err;
        };

        // Count backups
        var backup_count: usize = 0;
        var dir = try fs.cwd().openDir(self.backup_dir, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and mem.startsWith(u8, entry.name, "brain_state_")) {
                backup_count += 1;
            }
        }

        return StateInfo{
            .exists = true,
            .path = self.state_file_path,
            .size_bytes = @intCast(stat.size),
            .modified_at = stat.mtime,
            .backup_count = backup_count,
        };
    }

    /// Delete state file (for cleanup or reset)
    pub fn deleteState(self: *Self) !void {
        fs.cwd().deleteFile(self.state_file_path) catch |err| {
            if (err == error.FileNotFound) {
                return; // Already deleted
            }
            return err;
        };
        std.log.info("Deleted brain state file: {s}", .{self.state_file_path});
    }

    /// Wipe all state including backups (use with caution!)
    pub fn wipeAll(self: *Self) !void {
        // Delete state file
        self.deleteState() catch {};

        // Delete backup directory
        var dir = try fs.cwd().openDir(self.backup_dir, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const path = try fs.path.join(self.allocator, &.{ self.backup_dir, entry.name });
                defer self.allocator.free(path);
                fs.cwd().deleteFile(path) catch |err| {
                    std.log.warn("Failed to delete {s}: {}", .{ path, err });
                };
            }
        }

        std.log.warn("Wiped all brain state data", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-RECOVERY HELPER
// ═══════════════════════════════════════════════════════════════════════════════

/// Attempt automatic recovery on startup
/// Returns true if recovery was successful, false if no state to recover
pub fn autoRecover(allocator: mem.Allocator, registry: *basal_ganglia.Registry, event_bus: *reticular_formation.EventBus) !bool {
    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    if (!manager.hasValidState()) {
        std.log.info("No valid brain state found, starting fresh", .{});
        return false;
    }

    std.log.info("Found brain state, attempting recovery...", .{});

    const state = try manager.load();
    defer {
        // Free state resources
        for (state.task_claims) |claim| {
            allocator.free(claim.task_id);
            allocator.free(claim.agent_id);
            allocator.free(claim.status);
        }
        allocator.free(state.task_claims);

        for (state.events) |ev| {
            allocator.free(ev.event_type);
            allocator.free(ev.task_id);
            allocator.free(ev.agent_id);
            allocator.free(ev.aux_string);
        }
        allocator.free(state.events);

        for (state.metrics) |m| {
            allocator.free(m.name);
            for (m.tags) |tag| {
                allocator.free(tag);
            }
            allocator.free(m.tags);
        }
        allocator.free(state.metrics);
    }

    try manager.restore(state, registry, event_bus);

    std.debug.print("Brain recovery complete\n", .{});
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Run brain state recovery command
/// Usage: tri brain --save|--load|--status|--wipe
pub fn runBrainRecoveryCommand(allocator: mem.Allocator, args: []const []const u8) !void {
    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    if (args.len == 0) {
        try printBrainRecoveryHelp();
        return;
    }

    const cmd = args[0];

    if (mem.eql(u8, cmd, "--save") or mem.eql(u8, cmd, "-s")) {
        // Save current brain state
        const registry = try basal_ganglia.getGlobal(allocator);
        const event_bus = try reticular_formation.getGlobal(allocator);

        try manager.save(registry, event_bus);
        std.debug.print("Brain state saved successfully.\n", .{});

    } else if (mem.eql(u8, cmd, "--load") or mem.eql(u8, cmd, "-l")) {
        // Load and display brain state
        if (manager.hasValidState()) {
            const state = try manager.load();
            defer {
                for (state.task_claims) |claim| {
                    allocator.free(claim.task_id);
                    allocator.free(claim.agent_id);
                    allocator.free(claim.status);
                }
                allocator.free(state.task_claims);

                for (state.events) |ev| {
                    allocator.free(ev.event_type);
                    allocator.free(ev.task_id);
                    allocator.free(ev.agent_id);
                    allocator.free(ev.aux_string);
                }
                allocator.free(state.events);

                for (state.metrics) |m| {
                    allocator.free(m.name);
                    for (m.tags) |tag| {
                        allocator.free(tag);
                    }
                    allocator.free(m.tags);
                }
                allocator.free(state.metrics);
            }

            std.debug.print("Brain State (version {d}):\n", .{state.version});
            std.debug.print("  Saved at: {d}\n", .{state.saved_at});
            std.debug.print("  Task claims: {d}\n", .{state.task_claims.len});
            std.debug.print("  Events: {d}\n", .{state.events.len});
            std.debug.print("  Metrics: {d}\n", .{state.metrics.len});
            std.debug.print("  Hostname: {s}\n", .{state.metadata.hostname});
            std.debug.print("  PID: {d}\n", .{state.metadata.pid});
        } else {
            std.debug.print("No valid brain state found.\n", .{});
        }

    } else if (mem.eql(u8, cmd, "--status")) {
        // Show state file info
        const info = try manager.getStateInfo();

        std.debug.print("Brain State Status:\n", .{});
        std.debug.print("  Path: {s}\n", .{info.path});
        std.debug.print("  Exists: {s}\n", .{if (info.exists) "Yes" else "No"});

        if (info.exists) {
            std.debug.print("  Size: {d} bytes\n", .{info.size_bytes orelse 0});

            if (info.modified_at) |mtime| {
                const modified = std.time.timestamp();
                const age_sec = modified - mtime;
                std.debug.print("  Modified: {d} seconds ago\n", .{age_sec});
            }
        }

        std.debug.print("  Backups: {d}\n", .{info.backup_count});

    } else if (mem.eql(u8, cmd, "--wipe")) {
        // Wipe all state (requires confirmation)
        if (args.len > 1 and mem.eql(u8, args[1], "--force")) {
            try manager.wipeAll();
            std.debug.print("All brain state data wiped.\n", .{});
        } else {
            std.debug.print("This will delete all brain state data and backups!\n", .{});
            std.debug.print("Use --force to confirm: tri brain --wipe --force\n", .{});
        }

    } else if (mem.eql(u8, cmd, "--help") or mem.eql(u8, cmd, "-h")) {
        try printBrainRecoveryHelp();
    } else {
        std.debug.print("Unknown command: {s}\n", .{cmd});
        try printBrainRecoveryHelp();
    }
}

fn printBrainRecoveryHelp() !void {
    std.debug.print("\n{s}BRAIN STATE RECOVERY{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}Usage:{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("  tri brain --save        Save current brain state to disk\n", .{});
    std.debug.print("  tri brain --load        Load and display brain state\n", .{});
    std.debug.print("  tri brain --status      Show state file information\n", .{});
    std.debug.print("  tri brain --wipe        Delete all state data (requires --force)\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "StateManager init" {
    const allocator = std.testing.allocator;

    // Use temporary directory for testing
    const tmp_dir = "test_brain_state_tmp";
    try fs.cwd().makePath(tmp_dir);
    defer fs.cwd().deleteTree(tmp_dir) catch {};

    var manager = try StateManager.init(allocator);
    _ = manager;
}

test "StateManager save and load cycle" {
    const allocator = std.testing.allocator;

    // Create temporary state directory
    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Create test registry and event bus
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Add a test claim
    _ = try registry.claim(allocator, "test-task-1", "agent-001", 60000);

    // Save state
    try manager.save(&registry, &event_bus);

    // Load state
    const state = try manager.load();

    try std.testing.expectEqual(@as(usize, 1), state.task_claims.len);
    try std.testing.expectEqual(CURRENT_VERSION, state.version);

    // Cleanup
    {
        for (state.task_claims) |claim| {
            allocator.free(claim.task_id);
            allocator.free(claim.agent_id);
            allocator.free(claim.status);
        }
        allocator.free(state.task_claims);

        for (state.events) |ev| {
            allocator.free(ev.event_type);
            allocator.free(ev.task_id);
            allocator.free(ev.agent_id);
            allocator.free(ev.aux_string);
        }
        allocator.free(state.events);

        for (state.metrics) |m| {
            allocator.free(m.name);
            for (m.tags) |tag| {
                allocator.free(tag);
            }
            allocator.free(m.tags);
        }
        allocator.free(state.metrics);
    }

    // Clean up test state file
    manager.deleteState() catch {};
}

test "StateManager restore recovers task claims" {
    const allocator = std.testing.allocator;

    // Setup
    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Create original registry with claims
    var original_registry = basal_ganglia.Registry.init(allocator);
    defer original_registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Add test claims
    _ = try original_registry.claim(allocator, "task-1", "agent-001", 60000);
    _ = try original_registry.claim(allocator, "task-2", "agent-002", 60000);

    // Save state
    try manager.save(&original_registry, &event_bus);

    // Create new registry and restore
    var new_registry = basal_ganglia.Registry.init(allocator);
    defer new_registry.deinit();

    const state = try manager.load();
    defer {
        for (state.task_claims) |claim| {
            allocator.free(claim.task_id);
            allocator.free(claim.agent_id);
            allocator.free(claim.status);
        }
        allocator.free(state.task_claims);

        for (state.events) |ev| {
            allocator.free(ev.event_type);
            allocator.free(ev.task_id);
            allocator.free(ev.agent_id);
            allocator.free(ev.aux_string);
        }
        allocator.free(state.events);

        for (state.metrics) |m| {
            allocator.free(m.name);
            for (m.tags) |tag| {
                allocator.free(tag);
            }
            allocator.free(m.tags);
        }
        allocator.free(state.metrics);
    };

    try manager.restore(state, &new_registry, &event_bus);

    // Verify claims were restored
    try std.testing.expectEqual(@as(usize, 2), new_registry.claims.count());

    // Clean up
    manager.deleteState() catch {};
}

test "StateManager handles corrupted state file" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Write corrupted data to state file
    {
        const file = try fs.cwd().createFile(manager.state_file_path, .{ .read = true });
        defer file.close();
        try file.writeAll("corrupted json {{}}");
    }

    // Load should return error
    const result = manager.load();
    try std.testing.expectError(error.CorruptedData, result);

    // Clean up
    manager.deleteState() catch {};
}

test "StateManager getStateInfo" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Test with no state file
    const info_no_state = try manager.getStateInfo();
    try std.testing.expect(!info_no_state.exists);

    // Create state file
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    try manager.save(&registry, &event_bus);

    // Test with state file
    const info_with_state = try manager.getStateInfo();
    try std.testing.expect(info_with_state.exists);
    try std.testing.expect(info_with_state.size_bytes != null);
    try std.testing.expect(info_with_state.modified_at != null);

    // Clean up
    manager.deleteState() catch {};
}
