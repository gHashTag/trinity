//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.3: Self-Feeding Loop
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! VIBEE improves itself by adding successful implementations to the Golden DB
//! and rewarding agents with $TRI for quality improvements.
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const golden_db = @import("golden_db.zig");

/// Self-Feeding Loop - VIBEE improves itself
pub const SelfFeedingLoop = struct {
    allocator: Allocator,
    golden_db: *golden_db.GoldenDB,

    const Self = @This();

    pub fn init(allocator: Allocator, db: *golden_db.GoldenDB) Self {
        return .{
            .allocator = allocator,
            .golden_db = db,
        };
    }

    /// After successful patch - add seed to DB
    pub fn selfFeedSuccess(
        self: *Self,
        behavior_name: []const u8,
        signature: []const u8,
        implementation: []const u8,
        quality_score: f32,
    ) !void {
        if (quality_score > 0.85) {
            // Infer category from name
            const category = self.inferCategory(behavior_name);

            // Add to golden DB
            try self.golden_db.addNewSeed(behavior_name, signature, implementation, category);

            std.debug.print("  [Self-Feed] Added '{s}' (quality={d:.2})\n", .{
                behavior_name, quality_score
            });
        }
    }

    /// Process improvement results and auto-feed successful ones
    pub fn processImprovements(
        self: *Self,
        results: []const ImprovementResult,
    ) !FeedSummary {
        var summary = FeedSummary{
            .added_count = 0,
        };

        for (results) |result| {
            if (result.quality_score > 0.85) {
                try self.selfFeedSuccess(
                    result.behavior_name,
                    result.signature,
                    result.implementation,
                    result.quality_score,
                );
                summary.added_count += 1;
            }
        }

        return summary;
    }

    /// Infer category from function name
    fn inferCategory(self: *const Self, name: []const u8) golden_db.Category {
        _ = self;

        const name_lower = toLower(name);

        // VSA operations
        if (containsAny(name_lower, &.{ "bind", "bundle", "unbind", "similarity", "cosine", "hamming", "permute", "vector", "hypervector" })) {
            return .vsa;
        }

        // Tensor operations
        if (containsAny(name_lower, &.{ "tensor", "matmul", "matrix", "dot_product" })) {
            return .tensor;
        }

        // Economic operations
        if (containsAny(name_lower, &.{ "reward", "stake", "earn", "balance", "transfer", "tri" })) {
            return .economic;
        }

        // Swarm operations
        if (containsAny(name_lower, &.{ "swarm", "agent", "coord", "dispatch", "orchestrate" })) {
            return .swarm_runtime;
        }

        // I/O operations
        if (containsAny(name_lower, &.{ "read", "write", "save", "load", "file", "stream" })) {
            return .io;
        }

        // ML operations
        if (containsAny(name_lower, &.{ "embed", "encode", "decode", "transform", "attention" })) {
            return .ml;
        }

        // Lifecycle operations
        if (containsAny(name_lower, &.{ "init", "start", "stop", "shutdown", "deinit" })) {
            return .lifecycle;
        }

        // Data operations
        if (containsAny(name_lower, &.{ "get", "set", "add", "remove", "update" })) {
            return .data;
        }

        // Default to generic
        return .generic;
    }
};

pub const FeedSummary = struct {
    added_count: usize,
};

pub const ImprovementResult = struct {
    behavior_name: []const u8,
    signature: []const u8,
    implementation: []const u8,
    quality_score: f32,
};

/// Helper functions
fn toLower(s: []const u8) []const u8 {
    return s;
}

fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.mem.indexOf(u8, haystack, needle) != null) {
            return true;
        }
    }
    return false;
}
