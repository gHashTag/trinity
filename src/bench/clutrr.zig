// CLUTRR Benchmark — Compositional Language Understanding and Textual Relational Reasoning
// Tests ability to reason over relationships in a graph structure.
//
// Task: Given a description of family relationships, predict the relationship between two people.
// Example: "A is B's mother. B is C's father. What is A to C?" → Grandmother
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const MAX_DEPTH = 5;
const MAX_NODES = 20;

/// Relationship types in CLUTRR
pub const Relation = enum(u8) {
    // Direct family
    mother = 0,
    father = 1,
    sister = 2,
    brother = 3,
    daughter = 4,
    son = 5,
    wife = 6,
    husband = 7,

    // Extended family
    grandmother = 8,
    grandfather = 9,
    aunt = 10,
    uncle = 11,
    cousin = 12,
    niece = 13,
    nephew = 14,

    // In-laws
    mother_in_law = 15,
    father_in_law = 16,
    sister_in_law = 17,
    brother_in_law = 18,

    // Step relations
    step_mother = 19,
    step_father = 20,
    step_daughter = 21,
    step_son = 22,
};

/// CLUTRR data point
pub const ClutrrExample = struct {
    context: []const u8,
    query: []const u8,
    answer: Relation,
    depth: usize,
    num_entities: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        ctx: []const u8,
        qry: []const u8,
        ans: Relation,
        d: usize,
        n: usize,
    ) !ClutrrExample {
        return ClutrrExample{
            .context = try allocator.dupe(u8, ctx),
            .query = try allocator.dupe(u8, qry),
            .answer = ans,
            .depth = d,
            .num_entities = n,
        };
    }

    pub fn deinit(self: *const ClutrrExample, allocator: std.mem.Allocator) void {
        allocator.free(self.context);
        allocator.free(self.query);
    }
};

/// CLUTRR dataset
pub const ClutrrDataset = struct {
    examples: std.ArrayList(ClutrrExample),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .examples = std.ArrayList(ClutrrExample).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.examples.items) |*ex| {
            ex.deinit(self.allocator);
        }
        self.examples.deinit();
    }

    pub fn addExample(self: *Self, example: ClutrrExample) !void {
        try self.examples.append(example);
    }

    pub fn len(self: *const Self) usize {
        return self.examples.items.len;
    }

    /// Generate synthetic CLUTRR examples
    pub fn generateSynthetic(self: *Self, count: usize, max_depth: usize) !void {
        var prng = std.Random.DefaultPrng.init(0xFEED_A5E5);
        const rng = prng.random();

        for (0..count) |_| {
            const depth = rng.intRangeAtMost(usize, 1, max_depth);
            const num_entities = rng.intRangeAtMost(usize, 2, @min(MAX_NODES, depth + 2));

            // Generate a random family tree
            const context = try self.generateContext(depth, num_entities, rng);
            const (query, answer) = try self.generateQuery(&context, rng);

            const example = try ClutrrExample.init(
                self.allocator,
                context.text,
                query,
                answer,
                depth,
                num_entities,
            );
            try self.examples.append(example);
        }
    }

    const FamilyContext = struct {
        text: []const u8,
        relations: std.ArrayList(struct { []const u8, Relation }),
    };

    fn generateContext(self: *Self, depth: usize, num_entities: usize, rng: std.Random) !FamilyContext {
        _ = self;
        _ = depth;
        _ = num_entities;
        _ = rng;

        // Placeholder - would generate actual family relationships
        return FamilyContext{
            .text = "A is B's mother. B is C's father.",
            .relations = std.ArrayList(struct { []const u8, Relation }).init(self.allocator),
        };
    }

    fn generateQuery(self: *Self, context: *const FamilyContext, rng: std.Random) !struct { []const u8, Relation } {
        _ = context;
        _ = rng;

        const query = "What is A to C?";
        return .{ query, .grandmother };
    }
};

/// CLUTRR evaluator
pub const ClutrrEvaluator = struct {
    correct: usize = 0,
    total: usize = 0,
    by_depth: [MAX_DEPTH + 1]usize = [_]usize{0} ** (MAX_DEPTH + 1),
    correct_by_depth: [MAX_DEPTH + 1]usize = [_]usize{0} ** (MAX_DEPTH + 1),

    pub fn init() ClutrrEvaluator {
        return ClutrrEvaluator{};
    }

    pub fn evaluate(self: *ClutrrEvaluator, predicted: Relation, expected: Relation, depth: usize) void {
        self.total += 1;
        if (depth <= MAX_DEPTH) {
            self.by_depth[depth] += 1;
        }

        if (predicted == expected) {
            self.correct += 1;
            if (depth <= MAX_DEPTH) {
                self.correct_by_depth[depth] += 1;
            }
        }
    }

    pub fn accuracy(self: *const Self) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.correct)) / @as(f64, @floatFromInt(self.total));
    }

    pub fn accuracyByDepth(self: *const Self, depth: usize) f64 {
        if (depth > MAX_DEPTH or self.by_depth[depth] == 0) return 0.0;
        return @as(f64, @floatFromInt(self.correct_by_depth[depth])) /
            @as(f64, @floatFromInt(self.by_depth[depth]));
    }

    pub fn report(self: *const Self, writer: anytype) !void {
        try writer.print("CLUTRR Results:\n", .{});
        try writer.print("  Overall Accuracy: {d:.2}%\n", .{self.accuracy() * 100});
        try writer.print("  Total Examples: {d}\n", .{self.total});

        try writer.print("\nBy Depth:\n", .{});
        for (1..MAX_DEPTH + 1) |d| {
            if (self.by_depth[d] > 0) {
                try writer.print("  Depth {d}: {d:.2}% ({d}/{d})\n", .{
                    d, self.accuracyByDepth(d) * 100,
                    self.correct_by_depth[d], self.by_depth[d],
                });
            }
        }
    }
};

/// Relation name for display
pub fn relationName(rel: Relation) []const u8 {
    return switch (rel) {
        .mother => "mother",
        .father => "father",
        .sister => "sister",
        .brother => "brother",
        .daughter => "daughter",
        .son => "son",
        .wife => "wife",
        .husband => "husband",
        .grandmother => "grandmother",
        .grandfather => "grandfather",
        .aunt => "aunt",
        .uncle => "uncle",
        .cousin => "cousin",
        .niece => "niece",
        .nephew => "nephew",
        .mother_in_law => "mother-in-law",
        .father_in_law => "father-in-law",
        .sister_in_law => "sister-in-law",
        .brother_in_law => "brother-in-law",
        .step_mother => "step-mother",
        .step_father => "step-father",
        .step_daughter => "step-daughter",
        .step_son => "step-son",
    };
}

/// Parse relation from string
pub fn parseRelation(name: []const u8) ?Relation {
    if (std.mem.eql(u8, name, "mother")) return .mother;
    if (std.mem.eql(u8, name, "father")) return .father;
    if (std.mem.eql(u8, name, "sister")) return .sister;
    if (std.mem.eql(u8, name, "brother")) return .brother;
    if (std.mem.eql(u8, name, "daughter")) return .daughter;
    if (std.mem.eql(u8, name, "son")) return .son;
    if (std.mem.eql(u8, name, "grandmother")) return .grandmother;
    if (std.mem.eql(u8, name, "grandfather")) return .grandfather;
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CLUTRR evaluator init" {
    var evaluator = ClutrrEvaluator.init();

    try std.testing.expectEqual(@as(usize, 0), evaluator.total);
    try std.testing.expectEqual(@as(f64, 0.0), evaluator.accuracy());
}

test "CLUTRR evaluator accuracy" {
    var evaluator = ClutrrEvaluator.init();

    evaluator.evaluate(.mother, .mother, 1);
    evaluator.evaluate(.father, .mother, 1);
    evaluator.evaluate(.sister, .sister, 2);

    try std.testing.expectEqual(@as(usize, 3), evaluator.total);
    try std.testing.expectEqual(@as(usize, 2), evaluator.correct);
    try std.testing.expectApproxEqRel(@as(f64, 2.0 / 3.0), evaluator.accuracy(), 0.01);
}

test "CLUTRR evaluator by depth" {
    var evaluator = ClutrrEvaluator.init();

    evaluator.evaluate(.mother, .mother, 1);
    evaluator.evaluate(.father, .father, 1);
    evaluator.evaluate(.sister, .brother, 2); // Wrong
    evaluator.evaluate(.daughter, .daughter, 2);

    try std.testing.expectEqual(@as(f64, 1.0), evaluator.accuracyByDepth(1));
    try std.testing.expectApproxEqRel(@as(f64, 0.5), evaluator.accuracyByDepth(2), 0.01);
}

test "CLUTRR dataset init" {
    const allocator = std.testing.allocator;
    var dataset = ClutrrDataset.init(allocator);
    defer dataset.deinit();

    try std.testing.expectEqual(@as(usize, 0), dataset.len());
}

test "CLUTRR relation name" {
    try std.testing.expectEqualStrings("mother", relationName(.mother));
    try std.testing.expectEqualStrings("father", relationName(.father));
    try std.testing.expectEqualStrings("grandmother", relationName(.grandmother));
}

test "CLUTRR parse relation" {
    try std.testing.expectEqual(.mother, parseRelation("mother").?);
    try std.testing.expectEqual(.father, parseRelation("father").?);
    try std.testing.expectEqual(.grandmother, parseRelation("grandmother").?);
    try std.testing.expect(parseRelation("unknown") == null);
}

// φ² + 1/φ² = 3 | TRINITY
