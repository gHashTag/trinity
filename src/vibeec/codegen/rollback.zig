//! v10.1: Rollback Mechanism for Self-Improver Framework
//!
//! This module provides transaction-safe patching with automatic rollback
//! on failure, ensuring code quality is maintained.
//!
//! Features:
//! - Create backups before patching
//! - Restore from backup on failure
//! - Transaction-style patching (backup → patch → validate → commit/rollback)
//! - Human-approval gates for critical patches

const std = @import("std");
const PatchValidator = @import("validator.zig").PatchValidator;

/// Rollback manager for transaction-safe patching
pub const RollbackManager = struct {
    allocator: std.mem.Allocator,
    backup_dir: []const u8,

    /// Create a new rollback manager
    pub fn init(allocator: std.mem.Allocator, backup_dir: []const u8) RollbackManager {
        return .{
            .allocator = allocator,
            .backup_dir = backup_dir,
        };
    }

    /// Create backup of a file before patching
    pub fn createBackup(self: *RollbackManager, file_path: []const u8) ![]const u8 {
        // Read original file
        const source = try std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000);
        defer self.allocator.free(source);

        // Create backup filename with timestamp
        const timestamp = std.time.timestamp();
        const backup_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.{d}.bak",
            .{ self.backup_dir, std.fs.path.basename(file_path), timestamp }
        );
        errdefer self.allocator.free(backup_path);

        // Ensure backup directory exists
        try std.fs.cwd().makePath(self.backup_dir);

        // Write backup
        try std.fs.cwd().writeFile(.{
            .sub_path = backup_path,
            .data = source,
        });

        return backup_path;
    }

    /// Restore from backup
    pub fn rollback(self: *RollbackManager, file_path: []const u8, backup_path: []const u8) !void {
        // Read backup
        const backup_content = try std.fs.cwd().readFileAlloc(self.allocator, backup_path, 10_000_000);
        defer self.allocator.free(backup_content);

        // Restore original file
        try std.fs.cwd().writeFile(.{
            .sub_path = file_path,
            .data = backup_content,
        });
    }

    /// Transaction for safe patching
    pub const PatchTransaction = struct {
        manager: *RollbackManager,
        file_path: []const u8,
        backup_path: ?[]const u8 = null,
        committed: bool = false,

        /// Apply a patch with automatic rollback on failure
        pub fn apply(
            self: *PatchTransaction,
            patch_fn: *const fn (file_path: []const u8) anyerror![]const u8,
            validator: *const PatchValidator,
        ) ![]const u8 {
            // Step 1: Create backup
            self.backup_path = try self.manager.createBackup(self.file_path);

            // Step 2: Apply patch
            const patched_source = patch_fn(self.file_path) catch |err| {
                // Patch failed - rollback
                if (self.backup_path) |bp| {
                    self.manager.rollback(self.file_path, bp) catch {};
                }
                return err;
            };

            // Step 3: Write patched source atomically
            try std.fs.cwd().writeFile(.{
                .sub_path = self.file_path,
                .data = patched_source,
            });

            // Step 4: Validate
            const validation = try validator.validateFile(self.file_path);
            if (!validation.passed) {
                // Validation failed - rollback
                if (self.backup_path) |bp| {
                    try self.manager.rollback(self.file_path, bp);
                }
                return error.ValidationFailed;
            }

            // Step 5: Success - mark as committed
            self.committed = true;
            return patched_source;
        }

        /// Commit the transaction (keeps the patch, removes backup)
        pub fn commit(self: *PatchTransaction) !void {
            if (self.committed) {
                if (self.backup_path) |bp| {
                    // Remove backup file
                    std.fs.cwd().deleteFile(bp) catch {};
                    self.backup_path = null;
                }
            }
        }

        /// Rollback the transaction (restores original, keeps backup)
        pub fn abort(self: *PatchTransaction) !void {
            if (self.backup_path) |bp| {
                try self.manager.rollback(self.file_path, bp);
            }
        }

        /// Cleanup - call this in defer
        pub fn cleanup(self: *PatchTransaction) void {
            if (!self.committed) {
                if (self.backup_path) |bp| {
                    // Transaction was not committed - keep backup for manual inspection
                    _ = bp;
                }
            }
        }
    };

    /// Begin a new transaction
    pub fn beginTransaction(self: *RollbackManager, file_path: []const u8) PatchTransaction {
        return .{
            .manager = self,
            .file_path = file_path,
        };
    }

    /// Human approval check for critical patches
    pub const ApprovalLevel = enum {
        /// No approval needed - safe to apply automatically
        auto,
        /// Ask user before applying
        prompt,
        /// Require explicit confirmation for critical changes
        critical,
    };

    pub fn shouldRequireApproval(file_path: []const u8, patch_type: PatchType) ApprovalLevel {
        _ = file_path;

        return switch (patch_type) {
            .refactor => .auto,
            .behavior_add => .prompt,
            .economic => .critical,
            .signature_fix => .auto,
            .stub_to_real => .prompt,
        };
    }

    pub const PatchType = enum {
        refactor,
        behavior_add,
        economic,
        signature_fix,
        stub_to_real,
    };
};

// Tests
test "RollbackManager: create and restore backup" {
    // Create a temp subdirectory in the test's working directory
    const temp_subdir = "rollback_test_dir";

    // Create test file directly
    const test_file = try std.fmt.allocPrint(std.testing.allocator, "{s}/test.zig", .{temp_subdir});
    defer std.testing.allocator.free(test_file);

    // Create temp directory and test file
    try std.fs.cwd().makePath(temp_subdir);
    defer {
        std.fs.cwd().deleteTree(temp_subdir) catch {};
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = test_file,
        .data = "pub fn test() void {}",
    });

    var manager = RollbackManager.init(std.testing.allocator, temp_subdir);

    // Create backup
    const backup_path = try manager.createBackup(test_file);
    defer std.testing.allocator.free(backup_path);

    try std.testing.expect(backup_path.len > 0);

    // Modify file
    try std.fs.cwd().writeFile(.{
        .sub_path = test_file,
        .data = "pub fn test() void { // modified }",
    });

    // Restore from backup
    try manager.rollback(test_file, backup_path);

    // Verify restoration
    const content = try std.fs.cwd().readFileAlloc(std.testing.allocator, test_file, 1000);
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings("pub fn test() void {}", content);
}
