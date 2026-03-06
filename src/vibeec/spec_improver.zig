//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.3: Spec Improver - Fill empty implementation fields + Self-Feeding
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Uses Golden Implementation Database to fill empty implementation fields
//! in .vibee specs with verified code patterns.
//!
//! V10.3: Self-feeding loop - successful improvements are added back to Golden DB
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
const self_feeding = @import("self_feeding.zig");
const vibe_rewards = @import("vibe_rewards.zig");

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

/// V10.3: Extended result with quality scores for self-feeding
pub const DetailedImprovementResult = struct {
    base: ImprovementResult,
    filled_behaviors: ArrayList(FilledBehavior),
    total_tri_earned: f64,

    pub const FilledBehavior = struct {
        name: []const u8,
        signature: []const u8,
        implementation: []const u8,
        quality_score: f32,
    };

    pub fn init(allocator: Allocator) @This() {
        _ = allocator;
        return .{
            .base = .{
                .errors = ArrayList(ImprovementResult.ErrorEntry){},
            },
            .filled_behaviors = ArrayList(FilledBehavior){},
            .total_tri_earned = 0,
        };
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        // Free error entries
        for (self.base.errors.items) |*err| {
            allocator.free(err.behavior_name);
            allocator.free(err.reason);
        }
        self.base.errors.deinit(allocator);

        // Free filled behavior entries
        for (self.filled_behaviors.items) |*fb| {
            allocator.free(fb.name);
            allocator.free(fb.signature);
            allocator.free(fb.implementation);
        }
        self.filled_behaviors.deinit(allocator);
    }

    /// Add a filled behavior with quality score
    pub fn addFilled(
        self: *@This(),
        allocator: Allocator,
        name: []const u8,
        signature: []const u8,
        implementation: []const u8,
        quality_score: f32,
    ) !void {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sig_copy = try allocator.dupe(u8, signature);
        errdefer allocator.free(sig_copy);

        const impl_copy = try allocator.dupe(u8, implementation);
        errdefer allocator.free(impl_copy);

        try self.filled_behaviors.append(allocator, .{
            .name = name_copy,
            .signature = sig_copy,
            .implementation = impl_copy,
            .quality_score = quality_score,
        });

        self.base.behaviors_filled += 1;

        // Calculate $TRI reward
        const reward = vibe_rewards.VibeRewardSystem.rewardForImprovement(
            quality_score,
            5, // Default complexity
        );
        self.total_tri_earned += reward;
    }

    /// Export to self_feeding.ImprovementResult array
    pub fn toSelfFeedingResults(
        self: *const @This(),
    ) []const self_feeding.ImprovementResult {
        // This creates a view - caller must not free the returned array
        // The actual data is owned by filled_behaviors
        @setRuntimeSafety(false);
        const ptr: [*]const self_feeding.ImprovementResult = @ptrCast(self.filled_behaviors.items.ptr);
        return ptr[0..self.filled_behaviors.items.len];
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
/// V10.3: Self-feeding loop integration
/// V10.4: Live $TRI earnings tracking
pub const SpecImprover = struct {
    allocator: Allocator,
    golden_db: golden_db.GoldenDB,
    editor: SpecEditor,
    self_feeding_loop: ?*self_feeding.SelfFeedingLoop,
    agent_id: []const u8,
    total_tri_earned: f64,

    const Self = @This();

    /// Initialize the spec improver
    pub fn init(allocator: Allocator) !Self {
        const db = try golden_db.GoldenDB.init(allocator);
        return .{
            .allocator = allocator,
            .golden_db = db,
            .editor = SpecEditor.init(allocator),
            .self_feeding_loop = null,
            .agent_id = "vibee-v10.4",
            .total_tri_earned = 0,
        };
    }

    /// Set self-feeding loop (V10.3)
    pub fn setSelfFeedingLoop(self: *Self, loop: *self_feeding.SelfFeedingLoop) void {
        self.self_feeding_loop = loop;
    }

    /// Set agent ID for rewards (V10.3)
    pub fn setAgentId(self: *Self, agent_id: []const u8) void {
        self.agent_id = agent_id;
    }

    /// V10.4: Get total $TRI earned by this improver
    pub fn getTotalEarned(self: *const Self) f64 {
        return self.total_tri_earned;
    }

    /// V10.4: Reset earnings tracker
    pub fn resetEarnings(self: *Self) void {
        self.total_tri_earned = 0;
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

    /// V10.3: Estimate quality of an implementation (0.0 - 1.0)
    fn estimateQuality(self: *const Self, impl: *const golden_db.GoldenImpl) f32 {
        _ = self;
        var score: f32 = 0.5; // Base score

        // Body length factor (prefer substantial implementations)
        if (impl.body.len > 200) score += 0.1;
        if (impl.body.len > 500) score += 0.1;

        // Has error handling
        if (std.mem.indexOf(u8, impl.body, "err") != null or
            std.mem.indexOf(u8, impl.body, "error") != null)
        {
            score += 0.1;
        }

        // Has documentation
        if (std.mem.indexOf(u8, impl.body, "///") != null) {
            score += 0.1;
        }

        // Not just TODO/panic
        if (std.mem.indexOf(u8, impl.body, "TODO") != null or
            std.mem.indexOf(u8, impl.body, "@panic") != null)
        {
            score -= 0.2;
        }

        return @max(0.0, @min(1.0, score));
    }

    /// V10.3: Generate implementation with quality score
    pub fn generateImplementationWithQuality(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
    ) !struct {
        implementation: []const u8,
        signature: []const u8,
        quality: f32,
    } {
        // Strategy 1: Exact name match
        if (self.golden_db.get(behavior.name, .{})) |impl| {
            const quality = self.estimateQuality(impl);
            const impl_str = try self.buildFullImplementation(impl);
            return .{
                .implementation = impl_str,
                .signature = impl.signature,
                .quality = quality,
            };
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
            const results = try self.golden_db.search(tags.items[0], .{});
            defer self.allocator.free(results);

            if (results.len > 0) {
                const impl = results[0];
                const quality = self.estimateQuality(impl);
                const impl_str = try self.buildFullImplementation(impl);
                return .{
                    .implementation = impl_str,
                    .signature = impl.signature,
                    .quality = quality,
                };
            }
        }

        // Strategy 3: No match found
        return error.NoMatchFound;
    }

    /// V10.3: Improve spec with self-feeding (high-quality implementations fed back to DB)
    pub fn improveSpecWithSelfFeeding(
        self: *Self,
        spec_path: []const u8,
    ) !DetailedImprovementResult {
        var detailed_result = DetailedImprovementResult.init(self.allocator);
        errdefer detailed_result.deinit(self.allocator);

        // Read spec
        var spec = try self.editor.read(spec_path);
        defer spec.deinit();

        detailed_result.base.behaviors_total = spec.behaviors.items.len;

        // Find stub behaviors
        var stubs = try self.findStubBehaviors(&spec);
        defer {
            for (stubs.items) |*s| {
                _ = s;
            }
            stubs.deinit(self.allocator);
        }

        // Fill each stub
        for (stubs.items) |stub| {
            const behavior = &spec.behaviors.items[stub.index];

            const result = self.generateImplementationWithQuality(behavior) catch |err| {
                // Track error
                const name_dup = self.allocator.dupe(u8, behavior.name) catch continue;
                const reason_dup = self.allocator.dupe(u8, "No matching implementation") catch {
                    self.allocator.free(name_dup);
                    continue;
                };
                _ = err;

                try detailed_result.base.errors.append(self.allocator, .{
                    .behavior_name = name_dup,
                    .reason = reason_dup,
                });
                detailed_result.base.behaviors_skipped += 1;
                continue;
            };

            // Free the implementation string after we're done
            defer self.allocator.free(result.implementation);

            // Track what we filled
            try detailed_result.addFilled(
                self.allocator,
                behavior.name,
                result.signature,
                result.implementation,
                result.quality,
            );

            // V10.4: Track $TRI earned for this improvement
            const reward = vibe_rewards.VibeRewardSystem.rewardForImprovement(
                result.quality,
                5, // Default complexity
            );
            self.total_tri_earned += reward;

            std.debug.print("  [Reward] {s}: quality={d:.2} → {d:.1} TRI\n", .{
                behavior.name, result.quality, reward
            });

            // Self-feed high-quality implementations back to Golden DB
            if (self.self_feeding_loop != null and result.quality > 0.85) {
                self_feeding.SelfFeedingLoop.selfFeedSuccess(
                    self.self_feeding_loop.?,
                    behavior.name,
                    result.signature,
                    result.implementation,
                    result.quality,
                ) catch |err| {
                    std.debug.print("  [Warning] Self-feeding failed for '{s}': {}\n", .{
                        behavior.name, err
                    });
                };
            }
        }

        std.debug.print("  [Total] TRI earned this session: {d:.1}\n", .{self.total_tri_earned});

        return detailed_result;
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
        var stubs = try self.findStubBehaviors(&spec);
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
                // Duplicate strings since they point into spec which will be deinited
                const name_dup = try self.allocator.dupe(u8, behavior.name);
                const reason_dup = try self.allocator.dupe(u8, "No matching implementation found");
                const entry = ImprovementResult.ErrorEntry{
                    .behavior_name = name_dup,
                    .reason = reason_dup,
                };
                try result.errors.append(self.allocator, entry);
            }
        }

        // DEFERRED (v12): Write improved spec (when parser supports allocated impl strings)
        // Current limitation: parser doesn't handle dynamically allocated implementation strings
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
    var improver = try SpecImprover.init(std.testing.allocator);
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
