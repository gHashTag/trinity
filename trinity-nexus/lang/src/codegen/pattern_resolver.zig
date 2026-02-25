// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN RESOLVER - Pattern Reference Resolution for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// Resolves pattern references to actual Pattern implementations
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

const pattern_engine = @import("pattern_engine.zig");
pub const Pattern = pattern_engine.Pattern;

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN REFERENCE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Reference to a pattern (can be by name, category, or semantic query)
pub const PatternRef = union(enum) {
    by_name: NameRef,
    by_category: CategoryRef,
    by_query: QueryRef,
    direct: DirectRef,

    pub const NameRef = struct {
        name: []const u8,
    };

    pub const CategoryRef = struct {
        category: []const u8,
        index: usize, // Which pattern in category (0 = first match)
    };

    pub const QueryRef = struct {
        query: []const u8, // Semantic query text
        threshold: f64 = 0.3, // Minimum similarity score
    };

    pub const DirectRef = struct {
        pattern: *const Pattern,
    };
};

/// Resolved pattern with metadata
pub const ResolvedPattern = struct {
    pattern: Pattern,
    confidence: f64,
    resolution_path: []const u8, // How it was resolved (for debugging)

    pub fn deinit(self: *ResolvedPattern, allocator: Allocator) void {
        self.pattern.deinit(allocator);
        allocator.free(self.resolution_path);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN REGISTRY (Simplified - HNSW will be in separate module)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternRegistry = struct {
    allocator: Allocator,
    patterns: std.StringHashMap(Pattern),
    by_category: std.StringHashMap(ArrayList([]const u8)),

    const Self = @This();

    pub fn init(allocator: Allocator) PatternRegistry {
        return PatternRegistry{
            .allocator = allocator,
            .patterns = std.StringHashMap(Pattern).init(allocator),
            .by_category = std.StringHashMap(ArrayList([]const u8)).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all patterns
        var pattern_iter = self.patterns.iterator();
        while (pattern_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.patterns.deinit();

        // Free category lists
        var cat_iter = self.by_category.iterator();
        while (cat_iter.next()) |entry| {
            for (entry.value_ptr.items) |pattern_name| {
                self.allocator.free(pattern_name);
            }
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.by_category.deinit();
    }

    /// Register a pattern in the registry
    pub fn registerPattern(self: *Self, pattern: Pattern) !void {
        const name_copy = try self.allocator.dupe(u8, pattern.name);
        errdefer self.allocator.free(name_copy);

        // Remove old pattern if exists
        if (self.patterns.fetchRemove(pattern.name)) |old_entry| {
            old_entry.value.deinit(self.allocator);
            self.allocator.free(old_entry.key);

            // Remove from category index
            if (self.by_category.getPtr(pattern.category)) |cat_list| {
                for (cat_list.items, 0..) |p_name, i| {
                    if (std.mem.eql(u8, p_name, pattern.name)) {
                        _ = cat_list.orderedRemove(i);
                        self.allocator.free(p_name);
                        break;
                    }
                }
            }
        }

        try self.patterns.put(name_copy, pattern);

        // Add to category index
        const cat_key = try self.allocator.dupe(u8, pattern.category);
        const cat_entry = try self.by_category.getOrPut(cat_key);
        if (!cat_entry.found_existing) {
            cat_entry.value_ptr.* = .{};
        } else {
            self.allocator.free(cat_key);
        }

        const name_for_list = try self.allocator.dupe(u8, pattern.name);
        try cat_entry.value_ptr.append(self.allocator, name_for_list);
    }

    /// Get pattern by exact name
    pub fn getPattern(self: *const Self, name: []const u8) ?Pattern {
        if (self.patterns.get(name)) |p| {
            // Return a copy (shallow copy is OK for Pattern)
            return p;
        }
        return null;
    }

    /// Find patterns by category
    pub fn getByCategory(self: *const Self, category: []const u8) ![]const Pattern {
        const pattern_names = self.by_category.get(category) orelse return &.{};

        const patterns = try self.allocator.alloc(Pattern, pattern_names.items.len);
        for (pattern_names.items, 0..) |name, i| {
            if (self.patterns.get(name)) |p| {
                patterns[i] = p;
            } else {
                return error.PatternNotFound;
            }
        }

        return patterns;
    }

    /// Find pattern using semantic query
    pub fn findByQuery(self: *const Self, query: []const u8, threshold: f64) !?Pattern {
        var best_pattern: ?Pattern = null;
        var best_score: f64 = threshold;

        var iter = self.patterns.iterator();
        while (iter.next()) |entry| {
            const pattern = entry.value_ptr.*;
            const score = computeQuerySimilarity(query, &pattern);

            if (score > best_score) {
                best_score = score;
                best_pattern = pattern;
            }
        }

        return best_pattern;
    }

    /// Get all registered pattern names
    pub fn listPatterns(self: *const Self) ![][]const u8 {
        const names = try self.allocator.alloc([]const u8, self.patterns.count());
        var i: usize = 0;
        var iter = self.patterns.iterator();
        while (iter.next()) |entry| : (i += 1) {
            names[i] = entry.key_ptr.*;
        }
        return names;
    }

    /// Get all categories
    pub fn listCategories(self: *const Self) ![][]const u8 {
        const categories = try self.allocator.alloc([]const u8, self.by_category.count());
        var i: usize = 0;
        var iter = self.by_category.iterator();
        while (iter.next()) |entry| : (i += 1) {
            categories[i] = entry.key_ptr.*;
        }
        return categories;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN RESOLVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternResolver = struct {
    registry: *PatternRegistry,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, registry: *PatternRegistry) PatternResolver {
        return PatternResolver{
            .registry = registry,
            .allocator = allocator,
        };
    }

    /// Resolve a pattern reference to an actual pattern
    pub fn resolvePattern(self: *const Self, ref: PatternRef) !ResolvedPattern {
        return switch (ref) {
            .by_name => |r| try self.resolveByName(r.name),
            .by_category => |r| try self.resolveByCategory(r.category, r.index),
            .by_query => |r| try self.resolveByQuery(r.query, r.threshold),
            .direct => |r| try self.resolveDirect(r.pattern),
        };
    }

    fn resolveByName(self: *const Self, name: []const u8) !ResolvedPattern {
        const pattern = self.registry.getPattern(name) orelse {
            return error.PatternNotFound;
        };

        const path = try std.fmt.allocPrint(self.allocator, "by_name:{s}", .{name});

        return ResolvedPattern{
            .pattern = pattern,
            .confidence = 1.0, // Exact match
            .resolution_path = path,
        };
    }

    fn resolveByCategory(self: *const Self, category: []const u8, index: usize) !ResolvedPattern {
        const patterns = try self.registry.getByCategory(category);
        defer self.allocator.free(patterns);

        if (index >= patterns.len) {
            return error.PatternIndexOutOfBounds;
        }

        const pattern = patterns[index];
        const path = try std.fmt.allocPrint(self.allocator, "by_category:{s}[{d}]", .{ category, index });

        return ResolvedPattern{
            .pattern = pattern,
            .confidence = 0.8, // Category-based match
            .resolution_path = path,
        };
    }

    fn resolveByQuery(self: *const Self, query: []const u8, threshold: f64) !ResolvedPattern {
        const pattern = (try self.registry.findByQuery(query, threshold)) orelse {
            return error.NoMatchingPattern;
        };

        const score = computeQuerySimilarity(query, &pattern);
        const path = try std.fmt.allocPrint(self.allocator, "by_query:{s}({d:.2})", .{ query, score });

        return ResolvedPattern{
            .pattern = pattern,
            .confidence = score,
            .resolution_path = path,
        };
    }

    fn resolveDirect(self: *const Self, pattern_ptr: *const Pattern) !ResolvedPattern {
        const path = try std.fmt.allocPrint(self.allocator, "direct:{s}", .{pattern_ptr.name});

        return ResolvedPattern{
            .pattern = pattern_ptr.*,
            .confidence = 1.0,
            .resolution_path = path,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute similarity between query and pattern
fn computeQuerySimilarity(query: []const u8, pattern: *const Pattern) f64 {
    // Check pattern name
    if (std.mem.indexOf(u8, query, pattern.name) != null) {
        return 1.0;
    }

    // Check category
    if (std.mem.indexOf(u8, query, pattern.category) != null) {
        return 0.9;
    }

    // Check description (word overlap)
    return wordOverlap(query, pattern.description);
}

/// Compute word overlap between two strings (0.0 to 1.0)
fn wordOverlap(a: []const u8, b: []const u8) f64 {
    var words_a = std.StringHashMap(void).init(std.heap.page_allocator);
    defer words_a.deinit();

    var words_b = std.StringHashMap(void).init(std.heap.page_allocator);
    defer words_b.deinit();

    // Tokenize a
    {
        var iter = std.mem.tokenizeScalar(u8, a, ' ');
        while (iter.next()) |word| {
            words_a.put(word, {}) catch {};
        }
    }

    // Tokenize b
    {
        var iter = std.mem.tokenizeScalar(u8, b, ' ');
        while (iter.next()) |word| {
            words_b.put(word, {}) catch {};
        }
    }

    // Compute intersection
    var intersection: usize = 0;
    var iter = words_a.iterator();
    while (iter.next()) |entry| {
        if (words_b.contains(entry.key_ptr.*)) {
            intersection += 1;
        }
    }

    // Jaccard
    const union_count = words_a.count() + words_b.count() - intersection;
    if (union_count == 0) return 0.0;

    return @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(union_count));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PatternRegistry - register and retrieve" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    var pattern = Pattern.init(std.testing.allocator, "test_pattern", "test");
    pattern.description = "A test pattern";
    pattern.template = "test template";

    try registry.registerPattern(pattern);

    const retrieved = registry.getPattern("test_pattern");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("test_pattern", retrieved.?.name);
}

test "PatternRegistry - category indexing" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    // Register multiple patterns in same category
    {
        var p1 = Pattern.init(std.testing.allocator, "pattern1", "vsa");
        p1.description = "VSA pattern 1";
        try registry.registerPattern(p1);
    }

    {
        var p2 = Pattern.init(std.testing.allocator, "pattern2", "vsa");
        p2.description = "VSA pattern 2";
        try registry.registerPattern(p2);
    }

    // Get by category
    const patterns = try registry.getByCategory("vsa");
    defer std.testing.allocator.free(patterns);

    try std.testing.expectEqual(@as(usize, 2), patterns.len);
}

test "PatternResolver - resolve by name" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    var pattern = Pattern.init(std.testing.allocator, "my_pattern", "test");
    pattern.description = "Test pattern";
    try registry.registerPattern(pattern);

    var resolver = PatternResolver.init(std.testing.allocator, &registry);

    const ref = PatternRef{ .by_name = .{ .name = "my_pattern" } };
    var resolved = try resolver.resolvePattern(ref);
    defer resolved.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("my_pattern", resolved.pattern.name);
    try std.testing.expectApproxEqAbs(1.0, resolved.confidence, 0.01);
}

test "PatternResolver - resolve by category" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    {
        const p1 = Pattern.init(std.testing.allocator, "first", "vsa");
        try registry.registerPattern(p1);
    }
    {
        const p2 = Pattern.init(std.testing.allocator, "second", "vsa");
        try registry.registerPattern(p2);
    }

    var resolver = PatternResolver.init(std.testing.allocator, &registry);

    const ref = PatternRef{ .by_category = .{ .category = "vsa", .index = 0 } };
    var resolved = try resolver.resolvePattern(ref);
    defer resolved.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("first", resolved.pattern.name);
}

test "PatternResolver - resolve by query" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    var pattern = Pattern.init(std.testing.allocator, "vector_bind", "vsa");
    pattern.description = "bind two hypervectors together";
    try registry.registerPattern(pattern);

    var resolver = PatternResolver.init(std.testing.allocator, &registry);

    const ref = PatternRef{
        .by_query = .{
            .query = "I need to bind vectors",
            .threshold = 0.1,
        },
    };

    var resolved = try resolver.resolvePattern(ref);
    defer resolved.deinit(std.testing.allocator);

    try std.testing.expect(resolved.confidence > 0.1);
    try std.testing.expectEqualStrings("vector_bind", resolved.pattern.name);
}

test "wordOverlap - identical text" {
    const score = wordOverlap("hello world", "hello world");
    try std.testing.expectApproxEqAbs(1.0, score, 0.01);
}

test "wordOverlap - partial overlap" {
    const score = wordOverlap("hello world test", "hello universe");
    try std.testing.expect(score > 0.1 and score < 0.6);
}
