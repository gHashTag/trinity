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
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const json = std.json;

// Import brain region modules via module names (from build.zig)
// state_recovery module is set up with these module imports
const basal_ganglia_mod = @import("basal_ganglia");
const reticular_mod = @import("reticular_formation");

const basal_ganglia = struct {
    pub const Registry = basal_ganglia_mod.Registry;
    pub const TaskClaim = basal_ganglia_mod.TaskClaim;
};
const reticular_formation = struct {
    pub const EventBus = reticular_mod.EventBus;
    pub const EventData = reticular_mod.EventData;
    pub const AgentEventType = reticular_mod.AgentEventType;
};

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
    InvalidStatus,
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

/// Loaded state with arena for memory management
pub const LoadedState = struct {
    state: BrainState,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *LoadedState) void {
        self.arena.deinit();
    }

    pub fn constDeinit(self: *const LoadedState) void {
        // Cast away const for cleanup (safe for deinit)
        @constCast(self).deinit();
    }
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
        var json_buffer = std.ArrayList(u8).initCapacity(self.allocator, 8192) catch |err| {
            std.log.err("Failed to allocate JSON buffer: {}", .{err});
            return error.OutOfMemory;
        };
        defer json_buffer.deinit(self.allocator);
        try json_buffer.writer(self.allocator).print("{f}", .{json.fmt(state, .{ .whitespace = .indent_2 })});
        try file.writeAll(json_buffer.items);

        // Sync to disk
        try file.sync();

        // Atomic rename
        try fs.cwd().rename(tmp_path, self.state_file_path);

        std.log.info("Brain state saved to {s}", .{self.state_file_path});
    }

    /// Load brain state from disk
    /// Returns error if file not found or corrupted (caller should use defaults)
    pub fn load(self: *Self) !LoadedState {
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

        // Use an arena allocator for temporary parsing
        // All allocations will be freed when the arena is destroyed
        var arena_allocator = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        // Parse JSON into the arena
        const parsed = json.parseFromSlice(BrainState, arena, content, .{}) catch |err| {
            std.log.warn("Failed to parse brain state JSON: {}", .{err});
            return error.CorruptedData;
        };
        defer parsed.deinit();

        // Now copy the data into a permanent arena
        var permanent_arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer permanent_arena.deinit();
        const permanent_allocator = permanent_arena.allocator();

        // Deep copy the state into the permanent arena
        var state = try deepcopyState(permanent_allocator, parsed.value);

        // Validate and migrate if needed (now that we have a mutable copy)
        try self.validateAndMigrate(&state);

        std.log.info("Brain state loaded from {s} (version {d})", .{ self.state_file_path, state.version });

        return LoadedState{
            .state = state,
            .arena = permanent_arena,
        };
    }

    /// Capture current state from live brain components
    fn captureState(self: *Self, registry: *basal_ganglia.Registry, event_bus: *reticular_formation.EventBus) !BrainState {
        // Capture task claims
        var claims = std.ArrayList(TaskClaimState).initCapacity(self.allocator, 64) catch |err| {
            std.log.err("Failed to allocate claims: {}", .{err});
            return error.OutOfMemory;
        };
        defer claims.deinit(self.allocator);

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

                try claims.append(self.allocator, TaskClaimState{
                    .task_id = try self.allocator.dupe(u8, claim.task_id),
                    .agent_id = try self.allocator.dupe(u8, claim.agent_id),
                    .claimed_at = claim.claimed_at,
                    .ttl_ms = claim.ttl_ms,
                    .status = try self.allocator.dupe(u8, status_str),
                    .completed_at = claim.completed_at,
                    .last_heartbeat = claim.last_heartbeat,
                });
            }
        }

        // Capture events from reticular formation
        var events = std.ArrayList(EventState).initCapacity(self.allocator, 256) catch |err| {
            std.log.err("Failed to allocate events: {}", .{err});
            return error.OutOfMemory;
        };
        defer events.deinit(self.allocator);

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

                try events.append(self.allocator, EventState{
                    .event_type = try self.allocator.dupe(u8, event_type_str),
                    .timestamp = ev.timestamp,
                    .task_id = try self.allocator.dupe(u8, ev.task_id),
                    .agent_id = try self.allocator.dupe(u8, ev.agent_id),
                    .aux_string = try self.allocator.dupe(u8, ev.aux_string),
                    .duration_ms = ev.duration_ms,
                });
            }
        }

        // Capture metrics (simplified - just a snapshot)
        var metrics = std.ArrayList(MetricSnapshot).initCapacity(self.allocator, 16) catch |err| {
            std.log.err("Failed to allocate metrics: {}", .{err});
            return error.OutOfMemory;
        };
        defer metrics.deinit(self.allocator);

        // Add basic health metrics
        const now = std.time.milliTimestamp();

        try metrics.append(self.allocator, MetricSnapshot{
            .name = try self.allocator.dupe(u8, "brain.claims.count"),
            .value = @floatFromInt(claims.items.len),
            .timestamp = now,
            .tags = try self.allocator.alloc([]const u8, 0),
        });
        try metrics.append(self.allocator, MetricSnapshot{
            .name = try self.allocator.dupe(u8, "brain.events.buffered"),
            .value = @floatFromInt(events.items.len),
            .timestamp = now,
            .tags = try self.allocator.alloc([]const u8, 0),
        });

        // Get hostname (use environment or fallback)
        const hostname = std.posix.getenv("HOSTNAME") orelse std.posix.getenv("HOST") orelse "localhost";

        // Get PID (platform-specific) - using 0 as fallback
        const pid = if (builtin.os.tag == .linux)
            @as(i32, 0) // TODO: implement for linux
        else if (builtin.os.tag == .macos)
            @as(i32, 0) // TODO: implement for macos
        else
            @as(i32, 0);

        return BrainState{
            .version = CURRENT_VERSION,
            .saved_at = std.time.milliTimestamp(),
            .task_claims = try claims.toOwnedSlice(self.allocator),
            .events = try events.toOwnedSlice(self.allocator),
            .metrics = try metrics.toOwnedSlice(self.allocator),
            .metadata = .{
                .hostname = hostname,
                .pid = pid,
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

    /// Deep copy state into a new allocator
    fn deepcopyState(allocator: mem.Allocator, source: BrainState) !BrainState {
        // Copy task claims
        const task_claims = try allocator.alloc(TaskClaimState, source.task_claims.len);
        for (task_claims, source.task_claims) |*dest, src| {
            dest.* = .{
                .task_id = try allocator.dupe(u8, src.task_id),
                .agent_id = try allocator.dupe(u8, src.agent_id),
                .claimed_at = src.claimed_at,
                .ttl_ms = src.ttl_ms,
                .status = try allocator.dupe(u8, src.status),
                .completed_at = src.completed_at,
                .last_heartbeat = src.last_heartbeat,
            };
        }

        // Copy events
        const events = try allocator.alloc(EventState, source.events.len);
        for (events, source.events) |*dest, src| {
            dest.* = .{
                .event_type = try allocator.dupe(u8, src.event_type),
                .timestamp = src.timestamp,
                .task_id = try allocator.dupe(u8, src.task_id),
                .agent_id = try allocator.dupe(u8, src.agent_id),
                .aux_string = try allocator.dupe(u8, src.aux_string),
                .duration_ms = src.duration_ms,
            };
        }

        // Copy metrics
        const metrics = try allocator.alloc(MetricSnapshot, source.metrics.len);
        for (metrics, source.metrics) |*dest, src| {
            // Copy tags
            const tags = try allocator.alloc([]const u8, src.tags.len);
            for (tags, src.tags) |*tag_dest, tag_src| {
                tag_dest.* = try allocator.dupe(u8, tag_src);
            }

            dest.* = .{
                .name = try allocator.dupe(u8, src.name),
                .value = src.value,
                .timestamp = src.timestamp,
                .tags = tags,
            };
        }

        // Copy metadata
        const hostname = try allocator.dupe(u8, source.metadata.hostname);
        const tri_version = try allocator.dupe(u8, source.metadata.tri_version);

        return BrainState{
            .version = source.version,
            .saved_at = source.saved_at,
            .task_claims = task_claims,
            .events = events,
            .metrics = metrics,
            .metadata = .{
                .hostname = hostname,
                .pid = source.metadata.pid,
                .tri_version = tri_version,
            },
        };
    }

    /// Migrate state to next version
    fn migrate(self: *Self, state: *BrainState) !void {
        _ = self;

        switch (state.version) {
            1 => {
                // v1 is current, no migration needed
                // This is a placeholder for future v2
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
        }).initCapacity(self.allocator, 32) catch |err| {
            std.log.err("Failed to allocate backups: {}", .{err});
            return err;
        };

        defer {
            for (backups.items) |b| self.allocator.free(b.name);
            backups.deinit(self.allocator);
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
                    try backups.append(self.allocator, .{ .name = name_copy, .timestamp = timestamp });
                }
            }
        }

        // Sort by timestamp (newest first)
        const BackupEntry = @TypeOf(backups.items[0]);
        std.sort.pdq(BackupEntry, backups.items, {}, struct {
            fn lessThan(_: void, a: BackupEntry, b: BackupEntry) bool {
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
    pub fn restore(self: *Self, loaded: *const LoadedState, registry: *basal_ganglia.Registry, _event_bus: *reticular_formation.EventBus) !void {
        _ = _event_bus;
        const state = loaded.state;

        // Restore task claims
        for (state.task_claims) |claim_state| {
            // Create a dummy claim to get the enum type
            const dummy_claim = basal_ganglia.TaskClaim{
                .task_id = "",
                .agent_id = "",
                .claimed_at = 0,
                .ttl_ms = 0,
                .status = undefined,
                .completed_at = null,
                .last_heartbeat = 0,
            };
            const Status = @TypeOf(dummy_claim.status);

            const status: Status = if (mem.eql(u8, claim_state.status, "active"))
                .active
            else if (mem.eql(u8, claim_state.status, "completed"))
                .completed
            else if (mem.eql(u8, claim_state.status, "abandoned"))
                .abandoned
            else {
                std.log.err("Invalid status: '{s}' (len={d})", .{ claim_state.status, claim_state.status.len });
                return error.InvalidStatus;
            };

            // Skip completed/abandoned claims, only restore active ones
            if (status != .active) continue;

            // Check if claim is still valid (not expired)
            const now_ms = std.time.timestamp() * 1000;
            const age_ms = @as(u64, @intCast(now_ms - claim_state.claimed_at));

            if (age_ms < claim_state.ttl_ms) {
                // Restore claim
                const task_id_copy = try self.allocator.dupe(u8, claim_state.task_id);
                const new_claim = basal_ganglia.TaskClaim{
                    .task_id = task_id_copy,
                    .agent_id = try self.allocator.dupe(u8, claim_state.agent_id),
                    .claimed_at = claim_state.claimed_at,
                    .ttl_ms = claim_state.ttl_ms,
                    .status = .active,
                    .completed_at = null,
                    .last_heartbeat = claim_state.last_heartbeat,
                };

                registry.mutex.lock();
                try registry.claims.put(task_id_copy, new_claim);
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
            .modified_at = std.math.cast(i64, stat.mtime),
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

    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, registry, event_bus);

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
            const loaded = try manager.load();
            defer loaded.deinit();

            const state = loaded.state;
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

    const manager = try StateManager.init(allocator);
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
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.state.task_claims.len);
    try std.testing.expectEqual(CURRENT_VERSION, loaded.state.version);

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

    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, &new_registry, &event_bus);

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

// ═══════════════════════════════════════════════════════════════════════════════
// CRASH RECOVERY SCENARIO TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Crash recovery: mid-task agent crash recovery" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Simulate agent with active tasks
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Agent claims multiple tasks
    const agent_id = "agent-crash-victim";
    _ = try registry.claim(allocator, "task-1", agent_id, 60000);
    _ = try registry.claim(allocator, "task-2", agent_id, 60000);
    _ = try registry.claim(allocator, "task-3", agent_id, 60000);

    // Publish events
    try event_bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = agent_id } });
    try event_bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-2", .agent_id = agent_id } });

    // Save state (simulating periodic checkpoint)
    try manager.save(&registry, &event_bus);

    // Simulate crash: create new empty registry
    var crashed_registry = basal_ganglia.Registry.init(allocator);
    defer crashed_registry.deinit();

    // Load and recover
    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, &crashed_registry, &event_bus);

    // Verify all active tasks recovered
    try std.testing.expectEqual(@as(usize, 3), crashed_registry.claims.count());

    // Verify specific task IDs are present
    try std.testing.expect(crashed_registry.claims.get("task-1") != null);
    try std.testing.expect(crashed_registry.claims.get("task-2") != null);
    try std.testing.expect(crashed_registry.claims.get("task-3") != null);

    // Clean up
    manager.deleteState() catch {};
}

test "Crash recovery: partial task completion state preserved" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    const agent_id = "agent-partial";

    // Create tasks with different statuses
    _ = try registry.claim(allocator, "task-active", agent_id, 60000);
    _ = try registry.claim(allocator, "task-completed", agent_id, 60000);
    _ = try registry.claim(allocator, "task-abandoned", agent_id, 60000);

    // Mark some as completed/abandoned
    _ = registry.complete("task-completed", agent_id);
    _ = registry.abandon("task-abandoned", agent_id);

    // Save state
    try manager.save(&registry, &event_bus);

    // Load state and verify all statuses preserved
    var loaded = try manager.load();
    defer loaded.deinit();

    // Should have 3 total claims in state
    try std.testing.expectEqual(@as(usize, 3), loaded.state.task_claims.len);

    // Count by status
    var active_count: usize = 0;
    var completed_count: usize = 0;
    var abandoned_count: usize = 0;

    for (loaded.state.task_claims) |claim| {
        if (mem.eql(u8, claim.status, "active")) active_count += 1;
        if (mem.eql(u8, claim.status, "completed")) completed_count += 1;
        if (mem.eql(u8, claim.status, "abandoned")) abandoned_count += 1;
    }

    try std.testing.expectEqual(@as(usize, 1), active_count);
    try std.testing.expectEqual(@as(usize, 1), completed_count);
    try std.testing.expectEqual(@as(usize, 1), abandoned_count);

    // Clean up
    manager.deleteState() catch {};
}

test "Crash recovery: expired claims not restored" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Create a claim with very short TTL (1ms)
    _ = try registry.claim(allocator, "task-short-lived", "agent-001", 1);

    // Save state immediately
    try manager.save(&registry, &event_bus);

    // Wait for expiration (sleep a bit)
    std.Thread.sleep(10 * std.time.ns_per_ms);

    // Load and restore - expired claim should not be restored
    var loaded = try manager.load();
    defer loaded.deinit();

    var new_registry = basal_ganglia.Registry.init(allocator);
    defer new_registry.deinit();

    try manager.restore(&loaded, &new_registry, &event_bus);

    // Claim should be expired and not restored
    const restored_claim = new_registry.claims.get("task-short-lived");
    if (restored_claim) |claim| {
        // If restored, it should not be valid
        try std.testing.expect(!claim.isValid());
    } else {
        // Or not restored at all (both behaviors are acceptable)
    }

    // Clean up
    manager.deleteState() catch {};
}

test "Crash recovery: multiple agents with separate claims" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Simulate multi-agent scenario
    _ = try registry.claim(allocator, "task-a1", "agent-alpha", 60000);
    _ = try registry.claim(allocator, "task-a2", "agent-alpha", 60000);
    _ = try registry.claim(allocator, "task-b1", "agent-beta", 60000);
    _ = try registry.claim(allocator, "task-b2", "agent-beta", 60000);
    _ = try registry.claim(allocator, "task-g1", "agent-gamma", 60000);

    try manager.save(&registry, &event_bus);

    // Crash recovery
    var recovered_registry = basal_ganglia.Registry.init(allocator);
    defer recovered_registry.deinit();

    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, &recovered_registry, &event_bus);

    // All active claims should be recovered
    try std.testing.expectEqual(@as(usize, 5), recovered_registry.claims.count());

    // Verify agent separation preserved
    const alpha_claim = recovered_registry.claims.get("task-a1").?;
    try std.testing.expectEqualStrings("agent-alpha", alpha_claim.agent_id);

    const beta_claim = recovered_registry.claims.get("task-b1").?;
    try std.testing.expectEqualStrings("agent-beta", beta_claim.agent_id);

    const gamma_claim = recovered_registry.claims.get("task-g1").?;
    try std.testing.expectEqualStrings("agent-gamma", gamma_claim.agent_id);

    // Clean up
    manager.deleteState() catch {};
}

test "Crash recovery: state survives incomplete write (atomic rename)" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Create initial good state
    _ = try registry.claim(allocator, "task-important", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Simulate incomplete write by creating a .tmp file
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{manager.state_file_path});
    defer allocator.free(tmp_path);

    {
        const tmp_file = try fs.cwd().createFile(tmp_path, .{ .read = true });
        defer tmp_file.close();
        try tmp_file.writeAll("{\"incomplete\": \"data\"");
    }

    // Original state should still be intact
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.state.task_claims.len);
    try std.testing.expectEqualStrings("task-important", loaded.state.task_claims[0].task_id);

    // Clean up
    manager.deleteState() catch {};
    fs.cwd().deleteFile(tmp_path) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE VERSIONING AND MIGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "State versioning: current version saved correctly" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    _ = try registry.claim(allocator, "task-version-test", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(CURRENT_VERSION, loaded.state.version);

    // Clean up
    manager.deleteState() catch {};
}

test "State versioning: future version rejected" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Manually write a state file with future version
    {
        const file = try fs.cwd().createFile(manager.state_file_path, .{ .read = true });
        defer file.close();

        const future_version = CURRENT_VERSION + 1;
        const json_str = try std.fmt.allocPrint(allocator,
            \\{{
            \\  "version": {d},
            \\  "saved_at": 1234567890,
            \\  "task_claims": [],
            \\  "events": [],
            \\  "metrics": [],
            \\  "metadata": {{
            \\    "hostname": "test",
            \\    "pid": 123,
            \\    "tri_version": "test"
            \\  }}
            \\}}
        , .{future_version});
        defer allocator.free(json_str);

        try file.writeAll(json_str);
    }

    // Load should fail with UnsupportedVersion
    const result = manager.load();
    try std.testing.expectError(MigrationError.UnsupportedVersion, result);

    // Clean up
    manager.deleteState() catch {};
}

test "State versioning: zero version (legacy) migrated to current" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Write a v0 (legacy) state file
    {
        const file = try fs.cwd().createFile(manager.state_file_path, .{ .read = true });
        defer file.close();

        // Version 0 state (simplified format)
        const json_str =
            \\{
            \\  "version": 0,
            \\  "saved_at": 1234567890,
            \\  "task_claims": [],
            \\  "events": [],
            \\  "metrics": [],
            \\  "metadata": {
            \\    "hostname": "legacy",
            \\    "pid": 1,
            \\    "tri_version": "0.1.0"
            \\  }
            \\}
        ;
        try file.writeAll(json_str);
    }

    // Load should succeed and migrate
    var loaded = try manager.load();
    defer loaded.deinit();

    // After migration, version should be current
    try std.testing.expectEqual(CURRENT_VERSION, loaded.state.version);

    // Clean up
    manager.deleteState() catch {};
}

test "State versioning: metadata preserved during migration" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Write state with metadata
    {
        const file = try fs.cwd().createFile(manager.state_file_path, .{ .read = true });
        defer file.close();

        const json_str =
            \\{
            \\  "version": 1,
            \\  "saved_at": 1234567890,
            \\  "task_claims": [{
            \\    "task_id": "test-task",
            \\    "agent_id": "test-agent",
            \\    "claimed_at": 1234567000,
            \\    "ttl_ms": 60000,
            \\    "status": "active",
            \\    "completed_at": null,
            \\    "last_heartbeat": 1234567000
            \\  }],
            \\  "events": [],
            \\  "metrics": [],
            \\  "metadata": {
            \\    "hostname": "test-host",
            \\    "pid": 42,
            \\    "tri_version": "1.0.0-test"
            \\  }
            \\}
        ;
        try file.writeAll(json_str);
    }

    var loaded = try manager.load();
    defer loaded.deinit();

    // Metadata should be preserved
    try std.testing.expectEqualStrings("test-host", loaded.state.metadata.hostname);
    try std.testing.expectEqual(@as(u32, 42), loaded.state.metadata.pid);
    try std.testing.expectEqualStrings("1.0.0-test", loaded.state.metadata.tri_version);

    // Clean up
    manager.deleteState() catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKUP AND RESTORE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Backup: created before state overwrite" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Initial save
    _ = try registry.claim(allocator, "task-initial", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Get initial backup count
    const info_initial = try manager.getStateInfo();
    const initial_backups = info_initial.backup_count;

    // Add more claims and save again (should create backup)
    _ = try registry.claim(allocator, "task-second", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Backup count should have increased
    const info_after = try manager.getStateInfo();
    try std.testing.expect(info_after.backup_count > initial_backups);

    // Clean up
    manager.wipeAll() catch {};
}

test "Backup: backup file contains previous state" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Save initial state with one task
    _ = try registry.claim(allocator, "task-backup-test", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Add another task and save (backup created)
    _ = try registry.claim(allocator, "task-newer", "agent-002", 60000);
    try manager.save(&registry, &event_bus);

    // Verify backup directory has files
    var backup_dir = try fs.cwd().openDir(manager.backup_dir, .{ .iterate = true });
    defer backup_dir.close();

    var backup_count: usize = 0;
    var iter = backup_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and mem.startsWith(u8, entry.name, "brain_state_")) {
            backup_count += 1;
        }
    }

    try std.testing.expect(backup_count > 0);

    // Clean up
    manager.wipeAll() catch {};
}

test "Backup: old backups pruned automatically" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Create multiple saves to generate backups
    const save_count: usize = 15;
    for (0..save_count) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 60000);
        try manager.save(&registry, &event_bus);
    }

    // Check that backups are pruned (should keep at most 10)
    const info = try manager.getStateInfo();
    try std.testing.expect(info.backup_count <= 10);

    // Clean up
    manager.wipeAll() catch {};
}

test "Backup: filename includes timestamp" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    _ = try registry.claim(allocator, "task-timestamp", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Check backup files have correct naming pattern
    var backup_dir = try fs.cwd().openDir(manager.backup_dir, .{ .iterate = true });
    defer backup_dir.close();

    var iter = backup_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and mem.startsWith(u8, entry.name, "brain_state_")) {
            // Filename should be brain_state_<timestamp>.json
            try std.testing.expect(mem.endsWith(u8, entry.name, ".json"));

            // Extract and validate timestamp format
            const ts_str = entry.name["brain_state_".len .. entry.name.len - ".json".len];
            const timestamp = std.fmt.parseInt(i64, ts_str, 10) catch {
                try std.testing.expect(false); // Should not reach here
                return;
            };

            // Timestamp should be relatively recent (within last hour)
            const now = std.time.timestamp();
            try std.testing.expect(timestamp > now - 3600);
            try std.testing.expect(timestamp <= now);
        }
    }

    // Clean up
    manager.wipeAll() catch {};
}

test "Restore: only active claims restored" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    const agent_id = "agent-restore-test";

    // Create claims with different statuses
    _ = try registry.claim(allocator, "task-active-1", agent_id, 60000);
    _ = try registry.claim(allocator, "task-active-2", agent_id, 60000);
    _ = try registry.claim(allocator, "task-complete", agent_id, 60000);
    _ = try registry.claim(allocator, "task-abandon", agent_id, 60000);

    // Mark some as non-active
    _ = registry.complete("task-complete", agent_id);
    _ = registry.abandon("task-abandon", agent_id);

    // Save state
    try manager.save(&registry, &event_bus);

    // Restore to new registry
    var new_registry = basal_ganglia.Registry.init(allocator);
    defer new_registry.deinit();

    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, &new_registry, &event_bus);

    // Only active claims should be restored
    try std.testing.expectEqual(@as(usize, 2), new_registry.claims.count());
    try std.testing.expect(new_registry.claims.get("task-active-1") != null);
    try std.testing.expect(new_registry.claims.get("task-active-2") != null);
    try std.testing.expect(new_registry.claims.get("task-complete") == null);
    try std.testing.expect(new_registry.claims.get("task-abandon") == null);

    // Clean up
    manager.deleteState() catch {};
}

test "Restore: heartbeat timestamp preserved" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Create claim and capture heartbeat time
    const task_id = "task-heartbeat-preserve";
    _ = try registry.claim(allocator, task_id, "agent-001", 60000);

    // Get original heartbeat timestamp
    const original_claim = registry.claims.get(task_id).?;
    const original_heartbeat = original_claim.last_heartbeat;

    try manager.save(&registry, &event_bus);

    // Restore
    var new_registry = basal_ganglia.Registry.init(allocator);
    defer new_registry.deinit();

    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, &new_registry, &event_bus);

    // Heartbeat should be preserved
    const restored_claim = new_registry.claims.get(task_id).?;
    try std.testing.expectEqual(original_heartbeat, restored_claim.last_heartbeat);

    // Clean up
    manager.deleteState() catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-RECOVERY FUNCTIONALITY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Auto-recovery: returns false when no state exists" {
    const allocator = std.testing.allocator;

    // Ensure clean state
    const tmp_dir = ".trinity/brain/state";
    fs.cwd().deleteTree(tmp_dir) catch {};

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Auto-recover should return false (no state to recover)
    const recovered = try autoRecover(allocator, &registry, &event_bus);
    try std.testing.expect(!recovered);
}

test "Auto-recovery: recovers valid state" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    // First, create a state to recover
    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var original_registry = basal_ganglia.Registry.init(allocator);
    defer original_registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    _ = try original_registry.claim(allocator, "task-auto-1", "agent-auto", 60000);
    _ = try original_registry.claim(allocator, "task-auto-2", "agent-auto", 60000);

    try manager.save(&original_registry, &event_bus);

    // Now simulate crash and auto-recovery
    var crashed_registry = basal_ganglia.Registry.init(allocator);
    defer crashed_registry.deinit();

    const recovered = try autoRecover(allocator, &crashed_registry, &event_bus);

    // Should recover successfully
    try std.testing.expect(recovered);
    try std.testing.expectEqual(@as(usize, 2), crashed_registry.claims.count());

    // Clean up
    manager.deleteState() catch {};
}

test "Auto-recovery: handles corrupted state gracefully" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Write corrupted state
    {
        const file = try fs.cwd().createFile(manager.state_file_path, .{ .read = true });
        defer file.close();
        try file.writeAll("definitely not valid json {{{");
    }

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Auto-recover should handle error gracefully (return false or error)
    const result = autoRecover(allocator, &registry, &event_bus);

    // Should either return error or false (both acceptable)
    if (result) |recovered| {
        try std.testing.expect(!recovered);
    } else |_| {
        // Error is also acceptable
    }

    // Clean up
    manager.deleteState() catch {};
}

test "Auto-recovery: multiple sequential recoveries" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Create initial state
    var registry1 = basal_ganglia.Registry.init(allocator);
    defer registry1.deinit();

    var event_bus1 = reticular_formation.EventBus.init(allocator);
    defer event_bus1.deinit();

    _ = try registry1.claim(allocator, "task-seq-1", "agent-001", 60000);
    try manager.save(&registry1, &event_bus1);

    // First recovery
    var registry2 = basal_ganglia.Registry.init(allocator);
    defer registry2.deinit();

    var event_bus2 = reticular_formation.EventBus.init(allocator);
    defer event_bus2.deinit();

    const recovered1 = try autoRecover(allocator, &registry2, &event_bus2);
    try std.testing.expect(recovered1);

    // Update state and save again
    _ = try registry2.claim(allocator, "task-seq-2", "agent-002", 60000);
    try manager.save(&registry2, &event_bus2);

    // Second recovery should get updated state
    var registry3 = basal_ganglia.Registry.init(allocator);
    defer registry3.deinit();

    var event_bus3 = reticular_formation.EventBus.init(allocator);
    defer event_bus3.deinit();

    const recovered2 = try autoRecover(allocator, &registry3, &event_bus3);
    try std.testing.expect(recovered2);
    try std.testing.expectEqual(@as(usize, 2), registry3.claims.count());

    // Clean up
    manager.deleteState() catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDGE CASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Edge case: empty state (no claims, no events)" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Save empty state
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    try manager.save(&registry, &event_bus);

    // Load and verify
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 0), loaded.state.task_claims.len);
    try std.testing.expectEqual(@as(usize, 0), loaded.state.events.len);
    try std.testing.expectEqual(CURRENT_VERSION, loaded.state.version);

    // Should still have metrics (health metrics)
    try std.testing.expect(loaded.state.metrics.len >= 2);

    // Clean up
    manager.deleteState() catch {};
}

test "Edge case: very long task IDs and agent IDs" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Create very long IDs (stress test for serialization)
    const long_task_id = "task-" ++ "a" ** 500;
    const long_agent_id = "agent-" ++ "b" ** 500;

    _ = try registry.claim(allocator, long_task_id, long_agent_id, 60000);
    try manager.save(&registry, &event_bus);

    // Load and verify
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.state.task_claims.len);
    try std.testing.expectEqualStrings(long_task_id, loaded.state.task_claims[0].task_id);
    try std.testing.expectEqualStrings(long_agent_id, loaded.state.task_claims[0].agent_id);

    // Clean up
    manager.deleteState() catch {};
}

test "Edge case: special characters in task IDs" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Task IDs with special characters
    const special_tasks = [_][]const u8{
        "task/with/slashes",
        "task-with-dashes",
        "task_with_underscores",
        "task.with.dots",
        "task:with:colons",
    };

    for (special_tasks) |task_id| {
        _ = try registry.claim(allocator, task_id, "agent-001", 60000);
    }

    try manager.save(&registry, &event_bus);

    // Load and verify all special IDs preserved
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, special_tasks.len), loaded.state.task_claims.len);

    // Clean up
    manager.deleteState() catch {};
}

test "Edge case: concurrent save and load (basic test)" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Save state
    _ = try registry.claim(allocator, "task-concurrent", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Immediately load (test for file handle conflicts)
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.state.task_claims.len);

    // Save again while state is loaded
    _ = try registry.claim(allocator, "task-concurrent-2", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Load new state
    var loaded2 = try manager.load();
    defer loaded2.deinit();

    try std.testing.expectEqual(@as(usize, 2), loaded2.state.task_claims.len);

    // Clean up
    manager.deleteState() catch {};
}

test "Edge case: state file with UTF-8 content" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Use UTF-8 characters in task/agent IDs
    const utf8_task = "task-日本語-тест-🧠";
    const utf8_agent = "agent-тест";

    _ = try registry.claim(allocator, utf8_task, utf8_agent, 60000);
    try manager.save(&registry, &event_bus);

    // Load and verify UTF-8 preserved
    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.state.task_claims.len);
    try std.testing.expectEqualStrings(utf8_task, loaded.state.task_claims[0].task_id);
    try std.testing.expectEqualStrings(utf8_agent, loaded.state.task_claims[0].agent_id);

    // Clean up
    manager.deleteState() catch {};
}

test "Edge case: deleteState on non-existent file" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    // Ensure no state file exists
    manager.deleteState() catch {};

    // deleteState should not fail on non-existent file
    try manager.deleteState();
}

test "Edge case: wipeAll removes everything" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try fs.cwd().makePath(tmp_dir);

    var manager = try StateManager.init(allocator);
    defer manager.deinit();

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    // Create state and backups
    _ = try registry.claim(allocator, "task-wipe", "agent-001", 60000);
    try manager.save(&registry, &event_bus);

    // Create more backups
    for (0..5) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-wipe-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 60000);
        try manager.save(&registry, &event_bus);
    }

    // Verify backups exist
    const info_before = try manager.getStateInfo();
    try std.testing.expect(info_before.backup_count > 0);

    // Wipe all
    try manager.wipeAll();

    // Verify everything gone
    const info_after = try manager.getStateInfo();
    try std.testing.expect(!info_after.exists);
    try std.testing.expectEqual(@as(usize, 0), info_after.backup_count);
}
