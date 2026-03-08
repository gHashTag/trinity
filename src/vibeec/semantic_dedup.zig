//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.6: Semantic Deduplication using Text Similarity
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Finds and merges duplicate seed implementations using:
//! - Jaccard word similarity
//! - Category-aware matching
//! - Quality-based canonical selection
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const golden_db = @import("golden_db.zig");

/// Duplicate group - seeds that are similar to each other
pub const DuplicateGroup = struct {
    canonical: *golden_db.GoldenImpl,
    duplicates: std.ArrayList(*golden_db.GoldenImpl),
    max_similarity: f32 = 0.0,
    allocator: Allocator,

    pub fn init(allocator: Allocator, canonical: *golden_db.GoldenImpl) DuplicateGroup {
        return .{
            .canonical = canonical,
            .duplicates = std.ArrayList(*golden_db.GoldenImpl).initCapacity(allocator, 4) catch .{},
            .max_similarity = 0.0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DuplicateGroup) void {
        self.duplicates.deinit(self.allocator);
    }

    /// Clone the group (allocates new list)
    pub fn clone(self: *const DuplicateGroup, allocator: Allocator) !DuplicateGroup {
        var new_group = DuplicateGroup.init(allocator, self.canonical);
        for (self.duplicates.items) |dup| {
            try new_group.duplicates.append(allocator, dup);
        }
        new_group.max_similarity = self.max_similarity;
        return new_group;
    }
};

/// Merge statistics
pub const MergeStats = struct {
    removed: usize = 0,
    kept: usize = 0,
    groups_processed: usize = 0,
    total_saved_bytes: usize = 0,
};

/// Semantic Deduplicator - finds and removes duplicate implementations
pub const SemanticDeduplicator = struct {
    allocator: Allocator,
    golden_db: *golden_db.GoldenDB,
    similarity_threshold: f32 = 0.95,

    const Self = @This();

    pub fn init(allocator: Allocator, db: *golden_db.GoldenDB) Self {
        return .{
            .allocator = allocator,
            .golden_db = db,
            .similarity_threshold = 0.95,
        };
    }

    /// Find all duplicate groups in Golden DB
    pub fn findDuplicates(self: *const Self) ![]DuplicateGroup {
        var groups = std.ArrayList(DuplicateGroup).initCapacity(self.allocator, 10) catch |err| {
            std.debug.print("    [Error] Cannot allocate groups list: {}\n", .{err});
            return err;
        };

        const impls = self.golden_db.implementations.items;
        var processed = try std.ArrayList(bool).initCapacity(self.allocator, impls.len);
        defer processed.deinit(self.allocator);

        // Initialize processed tracker
        try processed.appendNTimes(self.allocator, false, impls.len);

        // Compare each pair
        for (impls, 0..) |*seed1, i| {
            if (processed.items[i]) continue;
            processed.items[i] = true;

            var group = DuplicateGroup.init(self.allocator, seed1.*);
            errdefer group.deinit();

            for (impls[i + 1 ..], 0..) |*seed2, j| {
                const idx2 = i + 1 + j;
                if (processed.items[idx2]) continue;

                // Skip different categories (can't be duplicates)
                if (seed1.*.category != seed2.*.category) continue;

                const sim = self.computeTextSimilarity(
                    seed1.*.body,
                    seed2.*.body,
                );

                if (sim >= self.similarity_threshold) {
                    try group.duplicates.append(self.allocator, seed2.*);
                    processed.items[idx2] = true;
                    if (sim > group.max_similarity) {
                        group.max_similarity = sim;
                    }
                }
            }

            if (group.duplicates.items.len > 0) {
                try groups.append(self.allocator, try group.clone(self.allocator));
            }
            group.deinit();
        }

        return groups.toOwnedSlice(self.allocator);
    }

    /// Merge duplicate seeds - keep highest quality as canonical
    pub fn mergeDuplicates(
        self: *Self,
        groups: []const DuplicateGroup,
    ) !MergeStats {
        var stats = MergeStats{};
        stats.groups_processed = groups.len;

        var to_remove = std.ArrayList(usize).initCapacity(self.allocator, 10) catch |err| {
            std.debug.print("    [Error] Cannot allocate remove list: {}\n", .{err});
            return err;
        };
        defer to_remove.deinit(self.allocator);

        for (groups) |group| {
            // Find highest quality seed
            var best = group.canonical;
            var best_quality = self.computeQuality(best);

            for (group.duplicates.items) |dup| {
                const quality = self.computeQuality(dup);
                if (quality > best_quality) {
                    best = dup;
                    best_quality = quality;
                }
            }

            // Mark all except best for removal
            if (best == group.canonical) {
                for (group.duplicates.items) |dup| {
                    try to_remove.append(self.allocator, self.indexOf(dup));
                    stats.removed += 1;
                    stats.total_saved_bytes += dup.name.len + dup.signature.len + dup.body.len;
                }
            } else {
                try to_remove.append(self.allocator, self.indexOf(group.canonical));
                stats.removed += 1;
                stats.total_saved_bytes += group.canonical.name.len + group.canonical.signature.len + group.canonical.body.len;

                for (group.duplicates.items) |dup| {
                    if (dup != best) {
                        try to_remove.append(self.allocator, self.indexOf(dup));
                        stats.removed += 1;
                        stats.total_saved_bytes += dup.name.len + dup.signature.len + dup.body.len;
                    }
                }
            }

            stats.kept += 1;
        }

        // Remove marked (in reverse order to preserve indices)
        std.sort.insertion(usize, to_remove.items, {}, comptime std.sort.desc(usize));

        for (to_remove.items) |idx| {
            _ = self.golden_db.implementations.orderedRemove(idx);
        }

        return stats;
    }

    /// Get deduplication statistics without merging
    pub fn getDedupStats(self: *const Self) !DedupStats {
        const groups = try self.findDuplicates();
        defer {
            for (groups) |*g| g.deinit();
            self.allocator.free(groups);
        }

        var total_duplicates: usize = 0;
        var max_similarity: f32 = 0.0;

        for (groups) |group| {
            total_duplicates += group.duplicates.items.len;
            if (group.max_similarity > max_similarity) {
                max_similarity = group.max_similarity;
            }
        }

        return DedupStats{
            .total_seeds = self.golden_db.implementations.items.len,
            .duplicate_groups = groups.len,
            .total_duplicates = total_duplicates,
            .max_similarity = max_similarity,
            .potential_savings = total_duplicates * 100, // Estimate
        };
    }

    /// Compute text similarity using Jaccard word similarity
    fn computeTextSimilarity(
        self: *const Self,
        text1: []const u8,
        text2: []const u8,
    ) f32 {
        var words1 = std.StringHashMap(void).init(self.allocator);
        defer words1.deinit();

        var words2 = std.StringHashMap(void).init(self.allocator);
        defer words2.deinit();

        // Tokenize and clean
        var iter1 = std.mem.tokenizeScalar(u8, text1, ' ');
        while (iter1.next()) |word| {
            const cleaned = self.cleanWord(word);
            if (cleaned.len > 2) {
                words1.put(cleaned, {}) catch {};
            }
        }

        var iter2 = std.mem.tokenizeScalar(u8, text2, ' ');
        while (iter2.next()) |word| {
            const cleaned = self.cleanWord(word);
            if (cleaned.len > 2) {
                words2.put(cleaned, {}) catch {};
            }
        }

        // Jaccard similarity
        var intersection: usize = 0;
        var iter = words1.iterator();
        while (iter.next()) |entry| {
            if (words2.contains(entry.key_ptr.*)) {
                intersection += 1;
            }
        }

        const union_count = words1.count() + words2.count() - intersection;
        if (union_count == 0) return 0.0;

        return @as(f32, @floatFromInt(intersection)) / @as(f32, @floatFromInt(union_count));
    }

    /// Clean word for comparison (remove punctuation, lowercase)
    fn cleanWord(self: *const Self, word: []const u8) []const u8 {
        _ = self;
        // Simple cleaning - strip common punctuation
        var start: usize = 0;
        var end: usize = word.len;

        if (word.len > 0) {
            const first = word[0];
            if (first == '(' or first == ')' or first == '{' or first == '}' or
                first == '[' or first == ']' or first == ';' or first == ':')
            {
                start = 1;
            }
        }

        if (word.len > start + 3) {
            const last = word[word.len - 1];
            if (last == '(' or last == ')' or last == '{' or last == '}' or
                last == '[' or last == ']' or last == ';' or last == ',' or
                last == ':')
            {
                end = word.len - 1;
            }
        }

        return word[start..end];
    }

    /// Compute quality score for an implementation
    fn computeQuality(self: *const Self, impl: *const golden_db.GoldenImpl) f32 {
        _ = self;
        var score = impl.confidence; // Base confidence

        // Bonus for longer implementations
        if (impl.body.len > 100) score += 0.05;
        if (impl.body.len > 200) score += 0.05;

        // Penalty for TODO/FIXME
        if (std.mem.indexOf(u8, impl.body, "TODO") != null) score -= 0.1;
        if (std.mem.indexOf(u8, impl.body, "FIXME") != null) score -= 0.1;

        return @max(0.0, @min(1.0, score));
    }

    /// Get index of implementation in the list
    fn indexOf(self: *const Self, impl: *const golden_db.GoldenImpl) usize {
        const items = self.golden_db.implementations.items;
        for (items, 0..) |item, i| {
            if (item == impl) return i;
        }
        return 0;
    }
};

/// Deduplication statistics (without modifying DB)
pub const DedupStats = struct {
    total_seeds: usize = 0,
    duplicate_groups: usize = 0,
    total_duplicates: usize = 0,
    max_similarity: f32 = 0.0,
    potential_savings: usize = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "SemanticDeduplicator: init" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const deduper = SemanticDeduplicator.init(std.testing.allocator, &db);
    _ = deduper;
}

test "SemanticDeduplicator: computeTextSimilarity - identical" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const deduper = SemanticDeduplicator.init(std.testing.allocator, &db);

    const text = "const x = 42; return x;";
    const sim = deduper.computeTextSimilarity(text, text);

    try std.testing.expect(sim == 1.0);
}

test "SemanticDeduplicator: computeTextSimilarity - different" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const deduper = SemanticDeduplicator.init(std.testing.allocator, &db);

    const text1 = "const x = 42; return x;";
    const text2 = "completely different function here";
    const text3 = "const y = 42; return y;";

    const sim12 = deduper.computeTextSimilarity(text1, text2);
    const sim13 = deduper.computeTextSimilarity(text1, text3);

    try std.testing.expect(sim13 > sim12); // More similar should have higher score
}

test "SemanticDeduplicator: computeQuality" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const deduper = SemanticDeduplicator.init(std.testing.allocator, &db);

    // Create test implementations
    var impl1 = golden_db.GoldenImpl{
        .name = "test1",
        .signature = "pub fn test1() !void",
        .body = "const x = 42; return x;",
        .category = .generic,
        .confidence = 0.8,
    };

    var impl2 = golden_db.GoldenImpl{
        .name = "test2",
        .signature = "pub fn test2() !void",
        .body = "// TODO: implement this",
        .category = .generic,
        .confidence = 0.8,
    };

    const q1 = deduper.computeQuality(&impl1);
    const q2 = deduper.computeQuality(&impl2);

    try std.testing.expect(q1 > q2); // No TODO should score higher
}
