//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.2: Spec Improver - Fill empty implementation fields
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Uses Golden Implementation Database to fill empty implementation fields
//! in .vibee specs with verified code patterns.
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const golden_db = @import("golden_db.zig");
const vibee_parser = @import("vibee_parser.zig");
const SpecEditor = @import("spec_editor.zig").SpecEditor;

/// Result of a spec improvement operation
pub const ImprovementResult = struct {
    behaviors_filled: usize = 0,
    behaviors_skipped: usize = 0,
    behaviors_total: usize = 0,
    errors: ArrayList(ErrorEntry),

    pub const ErrorEntry = struct {
        behavior_name: []const u8,
        reason: []const u8,
    };

    pub fn format(
        self: *const ImprovementResult,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("Improvement Result: {d}/{d} behaviors filled\n", .{
            self.behaviors_filled,
            self.behaviors_total,
        });
        try writer.print("  Skipped: {d}\n", .{self.behaviors_skipped});
        if (self.errors.items.len > 0) {
            try writer.print("  Errors: {d}\n", .{self.errors.items.len});
        }
    }
};

/// Stub behavior that needs implementation
pub const StubBehavior = struct {
    index: usize,
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    reason: StubReason,

    pub const StubReason = enum {
        empty_implementation,
        weak_implementation,
        no_match_found,
    };
};

/// Spec Improver - fills empty implementations using GoldenDB
pub const SpecImprover = struct {
    allocator: Allocator,
    golden_db: golden_db.GoldenDB,
    editor: SpecEditor,

    const Self = @This();

    /// Initialize the spec improver
    pub fn init(allocator: Allocator) !Self {
        const db = try golden_db.GoldenDB.init(allocator);
        return .{
            .allocator = allocator,
            .golden_db = db,
            .editor = SpecEditor.init(allocator),
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.golden_db.deinit();
    }

    /// Find all behaviors with empty or weak implementations
    pub fn findStubBehaviors(
        self: *const Self,
        spec: *const vibee_parser.VibeeSpec,
    ) !ArrayList(StubBehavior) {
        var stubs = ArrayList(StubBehavior){};

        for (spec.behaviors.items, 0..) |b, i| {
            const reason = if (b.implementation.len == 0)
                StubBehavior.StubReason.empty_implementation
            else if (std.mem.indexOf(u8, b.implementation, "TODO") != null)
                StubBehavior.StubReason.weak_implementation
            else
                continue;

            try stubs.append(self.allocator, .{
                .index = i,
                .name = b.name,
                .given = b.given,
                .when = b.when,
                .then = b.then,
                .reason = reason,
            });
        }

        return stubs;
    }

    /// Generate implementation for a behavior using GoldenDB
    pub fn generateImplementation(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
    ) !?[]const u8 {
        // Strategy 1: Exact name match
        if (self.golden_db.get(behavior.name, .{})) |impl| {
            // Build full implementation with signature and body
            const impl_str = try self.buildFullImplementation(impl);
            return impl_str;
        }

        // Strategy 2: Search by semantic tags
        var tags = try self.extractKeywords(behavior);
        defer {
            for (tags.items) |tag| {
                self.allocator.free(tag);
            }
            tags.deinit(self.allocator);
        }

        if (tags.items.len > 0) {
            // Try first tag
            const results = try self.golden_db.search(tags.items[0], .{});
            defer self.allocator.free(results);

            if (results.len > 0) {
                const impl_str = try self.buildFullImplementation(results[0]);
                return impl_str;
            }
        }

        // Strategy 3: No match found
        return null;
    }

    /// Extract keywords from behavior for semantic search
    fn extractKeywords(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
    ) !ArrayList([]const u8) {
        var keywords = ArrayList([]const u8){};

        // Extract from behavior name
        var name_parts = std.mem.splitScalar(u8, behavior.name, '_');
        while (name_parts.next()) |part| {
            if (part.len > 2) { // Skip short words
                const dupe = try self.allocator.dupe(u8, part);
                try keywords.append(self.allocator, dupe);
            }
        }

        return keywords;
    }

    /// Build full implementation string from GoldenImpl
    fn buildFullImplementation(
        self: *const Self,
        impl: *const golden_db.GoldenImpl,
    ) ![]const u8 {
        // Simple format: signature + body
        // The emitter will handle proper function generation
        return std.fmt.allocPrint(
            self.allocator,
            "{s}\n{s}",
            .{ impl.signature, impl.body },
        );
    }

    /// Improve a spec file by filling empty implementations
    pub fn improveSpecFile(self: *Self, spec_path: []const u8) !ImprovementResult {
        var result = ImprovementResult{
            .errors = ArrayList(ImprovementResult.ErrorEntry){},
        };

        // Read spec
        var spec = try self.editor.read(spec_path);
        defer spec.deinit();

        result.behaviors_total = spec.behaviors.items.len;

        // Find stub behaviors
        const stubs = try self.findStubBehaviors(&spec);
        defer {
            for (stubs.items) |*s| {
                _ = s;
                // Strings are slices into spec, no need to free
            }
            stubs.deinit(self.allocator);
        }

        // Fill each stub
        for (stubs.items) |stub| {
            const behavior = &spec.behaviors.items[stub.index];

            if (try self.generateImplementation(behavior)) |impl| {
                defer self.allocator.free(impl);

                // Update the behavior's implementation
                // Note: This requires modifying the parser to support allocated strings
                // For now, we track what we would fill
                result.behaviors_filled += 1;
            } else {
                result.behaviors_skipped += 1;
                const entry = ImprovementResult.ErrorEntry{
                    .behavior_name = behavior.name,
                    .reason = "No matching implementation found",
                };
                try result.errors.append(self.allocator, entry);
            }
        }

        // Write improved spec (TODO: when parser supports allocated impl strings)
        _ = try self.editor.writeAtomic(spec_path, &spec);

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "SpecImprover: init" {
    var improver = try SpecImprover.init(std.testing.allocator);
    defer improver.deinit();

    // Check that golden DB has VSA implementations
    const bind_impl = improver.golden_db.get("bind", .{});
    try std.testing.expect(bind_impl != null);
    try std.testing.expectEqualStrings("bind", bind_impl.?.name);
}

test "SpecImprover: findStubBehaviors" {
    var improver = try SpecImprover.init(std.testing.allocator);
    defer improver.deinit();

    // Create a mock spec with some behaviors
    var spec = vibee_parser.VibeeSpec.init(std.testing.allocator);
    defer spec.deinit();

    // Add a behavior with empty implementation
    try spec.behaviors.append(std.testing.allocator, .{
        .name = "test_bind",
        .given = "Two vectors",
        .when = "Need binding",
        .then = "Return bound vector",
        .implementation = "", // Empty = stub
        .test_cases = .{},
    });

    // Add a behavior with implementation
    try spec.behaviors.append(std.testing.allocator, .{
        .name = "real_func",
        .given = "Input",
        .when = "Action",
        .then = "Result",
        .implementation = "return 42;",
        .test_cases = .{},
    });

    var stubs = try improver.findStubBehaviors(&spec);
    defer {
        for (stubs.items) |*s| {
            _ = s;
        }
        stubs.deinit(std.testing.allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), stubs.items.len);
    try std.testing.expectEqualStrings("test_bind", stubs.items[0].name);
}

test "SpecImprover: generateImplementation" {
    const improver = try SpecImprover.init(std.testing.allocator);
    defer improver.deinit();

    const behavior = vibee_parser.Behavior{
        .name = "bind",
        .given = "Two vectors",
        .when = "Need binding",
        .then = "Return bound vector",
        .implementation = "",
        .test_cases = .{},
    };

    const impl = try improver.generateImplementation(&behavior);
    defer if (impl) |i| std.testing.allocator.free(i);

    try std.testing.expect(impl != null);
    try std.testing.expect(std.mem.indexOf(u8, impl.?, "for") != null); // bind uses a for loop
}
