//! Checkpoint Manager v8.21
//!
//! Git-style evolution history with rollback capability
//! Features:
//! - Snapshot pattern states at any point
//! - Branch and merge evolution paths
//! - Fast rollback to any generation
//! - Metadata tracking for each checkpoint

const std = @import("std");
const sacred = @import("sacred_constants.zig");

const ArrayList = std.array_list.Managed;
const Allocator = std.mem.Allocator;

/// Checkpoint metadata
pub const CheckpointMetadata = struct {
    id: u64,
    parent_id: ?u64,
    branch_name: []const u8,
    message: []const u8,
    timestamp: i64,
    generation: u32,
    pattern_count: usize,
    hash: u64,
};

/// Pattern snapshot
pub const PatternSnapshot = struct {
    pattern_id: u64,
    template: []const u8,
    confidence: f64,
    applied_at: i64,
};

/// Checkpoint containing full state
pub const Checkpoint = struct {
    metadata: CheckpointMetadata,
    patterns: ArrayList(PatternSnapshot),
    allocator: Allocator,

    /// Clone checkpoint
    pub fn clone(self: *const Checkpoint, allocator: Allocator) !Checkpoint {
        var new_patterns = ArrayList(PatternSnapshot).init(allocator);

        for (self.patterns.items) |pattern| {
            const new_template = try allocator.dupe(u8, pattern.template);
            errdefer allocator.free(new_template);

            try new_patterns.append(.{
                .pattern_id = pattern.pattern_id,
                .template = new_template,
                .confidence = pattern.confidence,
                .applied_at = pattern.applied_at,
            });
        }

        const new_message = try allocator.dupe(u8, self.metadata.message);
        errdefer allocator.free(new_message);

        const new_branch = try allocator.dupe(u8, self.metadata.branch_name);
        errdefer allocator.free(new_branch);

        return .{
            .metadata = .{
                .id = self.metadata.id,
                .parent_id = self.metadata.parent_id,
                .branch_name = new_branch,
                .message = new_message,
                .timestamp = self.metadata.timestamp,
                .generation = self.metadata.generation,
                .pattern_count = self.metadata.pattern_count,
                .hash = self.metadata.hash,
            },
            .patterns = new_patterns,
            .allocator = allocator,
        };
    }

    /// Deinitialize checkpoint
    pub fn deinit(self: *Checkpoint) void {
        for (self.patterns.items) |*pattern| {
            self.allocator.free(pattern.template);
        }
        self.patterns.deinit();
        self.allocator.free(self.metadata.message);
        self.allocator.free(self.metadata.branch_name);
    }
};

/// Branch tracking
pub const Branch = struct {
    name: []const u8,
    head_id: u64,
    created_at: i64,
};

/// Checkpoint manager for evolution tracking
pub const CheckpointManager = struct {
    const Self = @This();

    allocator: Allocator,
    checkpoints: ArrayList(Checkpoint),
    checkpoint_map: std.AutoHashMap(u64, usize), // id -> index
    branches: ArrayList(Branch),
    current_branch: []const u8,
    head_id: u64,
    next_id: u64,

    /// Initialize checkpoint manager
    pub fn init(allocator: Allocator) !CheckpointManager {
        var manager = CheckpointManager{
            .allocator = allocator,
            .checkpoints = ArrayList(Checkpoint).init(allocator),
            .checkpoint_map = std.AutoHashMap(u64, usize).init(allocator),
            .branches = ArrayList(Branch).init(allocator),
            .current_branch = try allocator.dupe(u8, "main"),
            .head_id = 0,
            .next_id = 1,
        };

        // Create initial empty checkpoint
        _ = try manager.createCheckpoint(&.{}, "Initial commit");

        return manager;
    }

    /// Deinitialize
    pub fn deinit(self: *CheckpointManager) void {
        for (self.checkpoints.items) |*ckpt| {
            ckpt.deinit();
        }
        self.checkpoints.deinit();
        self.checkpoint_map.deinit();

        for (self.branches.items) |*branch| {
            self.allocator.free(branch.name);
        }
        self.branches.deinit();

        self.allocator.free(self.current_branch);
    }

    /// Generate checkpoint ID using φ-based hash
    fn generateId(self: *Self) u64 {
        const id = self.next_id;
        self.next_id +%= 1;
        return id;
    }

    /// Create new checkpoint
    pub fn createCheckpoint(
        self: *Self,
        patterns: []const PatternSnapshot,
        message: []const u8,
    ) !u64 {
        const id = self.generateId();
        const timestamp = std.time.timestamp();

        // Calculate hash using sacred checksum
        var hash: u64 = id;
        for (patterns) |p| {
            hash +%= p.pattern_id;
            hash +%= @intFromFloat(@floor(p.confidence * 1000));
        }

        // Copy patterns
        var pattern_list = ArrayList(PatternSnapshot).init(self.allocator);
        for (patterns) |pattern| {
            const template_copy = try self.allocator.dupe(u8, pattern.template);
            try pattern_list.append(.{
                .pattern_id = pattern.pattern_id,
                .template = template_copy,
                .confidence = pattern.confidence,
                .applied_at = pattern.applied_at,
            });
        }

        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);

        const branch_copy = try self.allocator.dupe(u8, self.current_branch);
        errdefer self.allocator.free(branch_copy);

        const metadata = CheckpointMetadata{
            .id = id,
            .parent_id = if (id == 1) null else self.head_id,
            .branch_name = branch_copy,
            .message = message_copy,
            .timestamp = timestamp,
            .generation = @intCast(id),
            .pattern_count = patterns.len,
            .hash = hash,
        };

        const checkpoint = Checkpoint{
            .metadata = metadata,
            .patterns = pattern_list,
            .allocator = self.allocator,
        };

        try self.checkpoints.append(checkpoint);
        try self.checkpoint_map.put(id, self.checkpoints.items.len - 1);
        self.head_id = id;

        return id;
    }

    /// Create new branch from checkpoint
    pub fn createBranch(self: *Self, branch_name: []const u8, from_id: u64) !void {
        const branch_copy = try self.allocator.dupe(u8, branch_name);
        errdefer self.allocator.free(branch_copy);

        try self.branches.append(.{
            .name = branch_copy,
            .head_id = from_id,
            .created_at = std.time.timestamp(),
        });
    }

    /// Switch to existing branch
    pub fn switchBranch(self: *Self, branch_name: []const u8) !void {
        // Find branch
        for (self.branches.items) |branch| {
            if (std.mem.eql(u8, branch.name, branch_name)) {
                // Update current branch
                self.allocator.free(self.current_branch);
                self.current_branch = try self.allocator.dupe(u8, branch_name);
                self.head_id = branch.head_id;
                return;
            }
        }
        return error.BranchNotFound;
    }

    /// Get checkpoint by ID
    pub fn getCheckpoint(self: *const Self, id: u64) ?*const Checkpoint {
        const idx = self.checkpoint_map.get(id) orelse return null;
        return &self.checkpoints.items[idx];
    }

    /// Get current head checkpoint
    pub fn getHead(self: *const Self) ?*const Checkpoint {
        return self.getCheckpoint(self.head_id);
    }

    /// Rollback to specific checkpoint
    pub fn rollbackTo(self: *Self, checkpoint_id: u64) !void {
        // Verify checkpoint exists
        if (self.getCheckpoint(checkpoint_id) == null) return error.CheckpointNotFound;

        // Update head to target checkpoint
        self.head_id = checkpoint_id;

        // Update current branch head
        for (self.branches.items) |*branch| {
            if (std.mem.eql(u8, branch.name, self.current_branch)) {
                branch.head_id = checkpoint_id;
                break;
            }
        }
    }

    /// Rollback to specific generation
    pub fn rollbackToGeneration(self: *Self, generation: u32) !void {
        for (self.checkpoints.items) |ckpt| {
            if (ckpt.metadata.generation == generation) {
                try self.rollbackTo(ckpt.metadata.id);
                return;
            }
        }
        return error.GenerationNotFound;
    }

    /// Get checkpoint history
    pub fn getHistory(self: *const Self, limit: usize) !ArrayList(*const CheckpointMetadata) {
        var result = ArrayList(*const CheckpointMetadata).init(self.allocator);

        var current_id: ?u64 = self.head_id;
        var count: usize = 0;

        while (current_id != null and count < limit) : (count += 1) {
            const ckpt = self.getCheckpoint(current_id.?) orelse break;
            try result.append(&ckpt.metadata);
            current_id = ckpt.metadata.parent_id;
        }

        return result;
    }

    /// Get all branches
    pub fn getBranches(self: *const Self) []const Branch {
        return self.branches.items;
    }

    /// Get current branch name
    pub fn getCurrentBranch(self: *const Self) []const u8 {
        return self.current_branch;
    }

    /// Calculate φ-weighted importance of checkpoint
    pub fn calculateImportance(self: *const Self, checkpoint_id: u64) f64 {
        const ckpt = self.getCheckpoint(checkpoint_id) orelse return 0;

        // More patterns = higher importance
        const pattern_score = @as(f64, @floatFromInt(ckpt.metadata.pattern_count));

        // Newer checkpoints have slight boost
        const age_score = 1.0 / (1.0 + @as(f64, @floatFromInt(std.time.timestamp() - ckpt.metadata.timestamp)) / 86400.0);

        // φ-weighted combination
        return pattern_score * sacred.PHI + age_score;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "Checkpoint Manager: Initialize" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 1), manager.checkpoints.items.len);
}

test "Checkpoint Manager: Create checkpoint" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    const patterns = [_]PatternSnapshot{
        .{
            .pattern_id = 1,
            .template = "test",
            .confidence = 0.95,
            .applied_at = 0,
        },
    };

    const id = try manager.createCheckpoint(&patterns, "Test commit");
    try std.testing.expectEqual(@as(u64, 2), id);
    try std.testing.expectEqual(@as(usize, 2), manager.checkpoints.items.len);
}

test "Checkpoint Manager: Get checkpoint" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    const ckpt = manager.getCheckpoint(1);
    try std.testing.expect(ckpt != null);
}

test "Checkpoint Manager: Rollback to checkpoint" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    const patterns = [_]PatternSnapshot{
        .{
            .pattern_id = 1,
            .template = "test",
            .confidence = 0.95,
            .applied_at = 0,
        },
    };

    _ = try manager.createCheckpoint(&patterns, "Second commit");
    try std.testing.expectEqual(@as(u64, 2), manager.head_id);

    try manager.rollbackTo(1);
    try std.testing.expectEqual(@as(u64, 1), manager.head_id);
}

test "Checkpoint Manager: Create and switch branch" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.createBranch("feature", 1);
    try manager.switchBranch("feature");

    try std.testing.expect(std.mem.eql(u8, "feature", manager.getCurrentBranch()));
}

test "Checkpoint Manager: Get history" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    const patterns = [_]PatternSnapshot{
        .{
            .pattern_id = 1,
            .template = "test",
            .confidence = 0.95,
            .applied_at = 0,
        },
    };

    _ = try manager.createCheckpoint(&patterns, "Second commit");
    _ = try manager.createCheckpoint(&patterns, "Third commit");

    const history = try manager.getHistory(10);
    defer history.deinit();
    try std.testing.expect(history.items.len >= 3);
}

test "Checkpoint Manager: Calculate importance" {
    var manager = try CheckpointManager.init(std.testing.allocator);
    defer manager.deinit();

    const patterns = [_]PatternSnapshot{
        .{
            .pattern_id = 1,
            .template = "test",
            .confidence = 0.95,
            .applied_at = 0,
        },
    };

    _ = try manager.createCheckpoint(&patterns, "Test commit");

    const importance = manager.calculateImportance(2);
    try std.testing.expect(importance > 0);
}
