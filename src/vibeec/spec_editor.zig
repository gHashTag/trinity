//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.2: Spec Editor - Safe .tri file editing
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Provides atomic, transaction-safe editing of .tri spec files.
//! All writes create backups first to prevent data loss.
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const vibee_parser = @import("vibee_parser.zig");

/// Spec editor for safe .tri file manipulation
pub const SpecEditor = struct {
    allocator: Allocator,
    backup_dir: []const u8,

    const Self = @This();

    /// Initialize with default backup directory (.tri_backups)
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .backup_dir = ".tri_backups",
        };
    }

    /// Initialize with custom backup directory
    pub fn initWithBackup(allocator: Allocator, backup_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .backup_dir = backup_dir,
        };
    }

    /// Read a .tri spec file
    /// NOTE: Caller owns the returned spec and must call deinit()
    pub fn read(self: *const Self, path: []const u8) !vibee_parser.VibeeSpec {
        const content = try std.fs.cwd().readFileAlloc(self.allocator, path, 1_000_000);
        var parser = vibee_parser.VibeeParser.init(self.allocator, content);
        var spec = try parser.parse();
        spec.owns_source = true; // content was readFileAlloc'd
        // Note: spec now owns the content via source_content field
        // Don't free content here - spec.deinit() will handle it
        return spec;
    }

    /// Create backup of spec file
    pub fn backup(self: *const Self, path: []const u8) ![]const u8 {
        // Ensure backup directory exists
        std.fs.cwd().makePath(self.backup_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Generate backup filename with timestamp
        const basename = std.fs.path.basename(path);
        const now = std.time.timestamp();
        const backup_name = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.{d}.bak",
            .{ self.backup_dir, basename, now },
        );

        // Copy file to backup location
        const content = try std.fs.cwd().readFileAlloc(self.allocator, path, 10_000_000);
        defer self.allocator.free(content);

        try std.fs.cwd().writeFile(.{ .sub_path = backup_name, .data = content });

        return backup_name;
    }

    /// Write spec to file with atomic operation (write to temp, then rename)
    pub fn writeAtomic(self: *const Self, path: []const u8, spec: *const vibee_parser.VibeeSpec) !void {
        // Create backup first
        _ = try self.backup(path);

        // Generate YAML content
        const yaml = try self.specToYaml(spec);
        defer self.allocator.free(yaml);

        // Write to temporary file
        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path});
        defer self.allocator.free(tmp_path);

        try std.fs.cwd().writeFile(.{ .sub_path = tmp_path, .data = yaml });

        // Atomic rename (overwrites target)
        try std.fs.cwd().rename(tmp_path, path);
    }

    /// Update implementation field for a behavior by index
    pub fn updateImplementation(
        self: *const Self,
        spec: *vibee_parser.VibeeSpec,
        behavior_idx: usize,
        new_impl: []const u8,
    ) !void {
        if (behavior_idx >= spec.behaviors.items.len) {
            return error.InvalidBehaviorIndex;
        }

        const behavior = &spec.behaviors.items[behavior_idx];

        // Free old implementation if it was allocated
        if (behavior.implementation.len > 0) {
            // Note: In the current parser, strings are slices into the original input
            // So we don't free them here. This will need adjustment if the parser
            // switches to allocated strings.
        }

        // Store new implementation (needs allocator in current parser design)
        _ = new_impl;
        _ = self;
        return error.NotImplemented;
    }

    /// Convert spec back to YAML format (for writing)
    fn specToYaml(self: *const Self, spec: *const vibee_parser.VibeeSpec) ![]const u8 {
        const ArrayList = @import("std").ArrayList;
        var buffer = ArrayList(u8).empty;
        defer buffer.deinit(self.allocator);

        const writer = buffer.writer(self.allocator);

        // Header
        try writer.print("name: {s}\n", .{spec.name});
        try writer.print("version: \"{s}\"\n", .{spec.version});
        try writer.print("language: {s}\n", .{spec.language});
        try writer.writeAll("\n");

        // Types
        if (spec.types.items.len > 0) {
            try writer.writeAll("types:\n");
            for (spec.types.items) |t| {
                try writer.print("  {s}:\n", .{t.name});
                if (t.fields.items.len > 0) {
                    try writer.writeAll("    fields:\n");
                    for (t.fields.items) |f| {
                        try writer.print("      {s}: {s}\n", .{ f.name, f.type_name });
                    }
                }
            }
            try writer.writeAll("\n");
        }

        // Behaviors
        if (spec.behaviors.items.len > 0) {
            try writer.writeAll("behaviors:\n");
            for (spec.behaviors.items) |b| {
                try writer.writeAll("  - name: ");
                try writer.writeAll(b.name);
                try writer.writeAll("\n");

                if (b.given.len > 0) {
                    try writer.writeAll("    given: ");
                    try writer.writeAll(b.given);
                    try writer.writeAll("\n");
                }

                if (b.when.len > 0) {
                    try writer.writeAll("    when: ");
                    try writer.writeAll(b.when);
                    try writer.writeAll("\n");
                }

                if (b.then.len > 0) {
                    try writer.writeAll("    then: ");
                    try writer.writeAll(b.then);
                    try writer.writeAll("\n");
                }

                if (b.implementation.len > 0) {
                    try writer.writeAll("    implementation: |\n");
                    var impl_lines = std.mem.splitScalar(u8, b.implementation, '\n');
                    while (impl_lines.next()) |line| {
                        try writer.writeAll("      ");
                        try writer.writeAll(line);
                        try writer.writeAll("\n");
                    }
                }

                try writer.writeAll("\n");
            }
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    /// Clean old backups (keep last N)
    pub fn cleanOldBackups(self: *const Self, keep_count: usize) !void {
        _ = self;
        _ = keep_count;
        return error.NotImplemented;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "SpecEditor: init" {
    const editor = SpecEditor.init(std.testing.allocator);
    try std.testing.expectEqualStrings(".tri_backups", editor.backup_dir);
}

test "SpecEditor: initWithBackup" {
    const editor = SpecEditor.initWithBackup(std.testing.allocator, ".my_backups");
    try std.testing.expectEqualStrings(".my_backups", editor.backup_dir);
}
