// rsbench — Reasoning Shortcuts Benchmark
// Tests whether models can find shortcuts instead of doing actual reasoning.
//
// The benchmark contains problems that can be solved either by:
// 1. Full reasoning (correct)
// 2. Statistical shortcuts (incorrect but tempting)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Problem types that test for reasoning shortcuts
pub const ProblemType = enum {
    /// A implies B, B implies C, does A imply C?
    transitivity,
    /// All A are B, all B are C, are all A C?
    syllogism,
    /// Counterfactual: If A were true, would B be true?
    counterfactual,
    /// Quantifier scope: Does "all A are not B" mean "no A are B"?
    quantifier_scope,
    /// Pragmatic inference: What is implied vs what is stated?
    pragmatic,
};

/// rsbench problem instance
pub const RsbenchProblem = struct {
    id: u32,
    problem_type: ProblemType,
    question: []const u8,
    options: []const []const u8,
    correct_answer: usize,
    /// The "shortcut" answer that models might pick
    shortcut_answer: usize,
    /// Explanation of why shortcut is wrong
    explanation: []const u8,
};

/// rsbench evaluation results
pub const RsbenchResults = struct {
    total: usize = 0,
    correct: usize = 0,
    shortcut_caught: usize = 0,
    by_type: [5]struct { correct: usize, total: usize } = [_]struct { correct: usize, total: usize }{
        .{ .correct = 0, .total = 0 },
        .{ .correct = 0, .total = 0 },
        .{ .correct = 0, .total = 0 },
        .{ .correct = 0, .total = 0 },
        .{ .correct = 0, .total = 0 },
    },

    pub fn accuracy(self: *const Self) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.correct)) / @as(f64, @floatFromInt(self.total));
    }

    pub fn shortcutRate(self: *const Self) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.shortcut_caught)) / @as(f64, @floatFromInt(self.total));
    }
};

/// rsbench runner
pub const Rsbench = struct {
    problems: std.ArrayList(RsbenchProblem),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .problems = std.ArrayList(RsbenchProblem).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.problems.items) |*p| p.deinit();
        self.problems.deinit();
    }

    pub fn addProblem(self: *Self, problem: RsbenchProblem) !void {
        try self.problems.append(problem);
    }

    /// Evaluate model predictions on rsbench
    pub fn evaluate(self: *Self, predictions: []const usize) RsbenchResults {
        var results = RsbenchResults{};
        results.total = @min(predictions.len, self.problems.items.len);

        for (0..results.total) |i| {
            const problem = self.problems.items[i];
            const prediction = predictions[i];

            // Check if correct
            if (prediction == problem.correct_answer) {
                results.correct += 1;
                const type_idx = @intFromEnum(problem.problem_type);
                results.by_type[type_idx].correct += 1;
            }

            // Check if shortcut was used
            if (prediction == problem.shortcut_answer and prediction != problem.correct_answer) {
                results.shortcut_caught += 1;
            }

            const type_idx = @intFromEnum(problem.problem_type);
            results.by_type[type_idx].total += 1;
        }

        return results;
    }

    /// Generate default rsbench problems
    pub fn generateDefaults(self: *Self) !void {
        // Transitivity problem
        try self.addProblem(RsbenchProblem{
            .id = 1,
            .problem_type = .transitivity,
            .question = "If A is taller than B, and B is taller than C, is A taller than C?",
            .options = &[_][]const u8{ "Yes", "No", "Cannot determine" },
            .correct_answer = 0, // Yes
            .shortcut_answer = 2, // Cannot determine (statistical uncertainty)
            .explanation = "Transitivity: A > B and B > C implies A > C",
        });

        // Syllogism problem
        try self.addProblem(RsbenchProblem{
            .id = 2,
            .problem_type = .syllogism,
            .question = "All A are B. All B are C. Are all A C?",
            .options = &[_][]const u8{ "Yes", "No", "Some A are C" },
            .correct_answer = 0, // Yes
            .shortcut_answer = 1, // No (negation bias)
            .explanation = "Syllogism: A ⊆ B and B ⊆ C implies A ⊆ C",
        });

        // Quantifier scope problem
        try self.addProblem(RsbenchProblem{
            .id = 3,
            .problem_type = .quantifier_scope,
            .question = "All A are not B. Does this mean no A are B?",
            .options = &[_][]const u8{ "Yes", "No", "Sometimes" },
            .correct_answer = 0, // Yes
            .shortcut_answer = 2, // Sometimes (uncertainty)
            .explanation = "Universal negative: ∀x (A(x) → ¬B(x)) means no A are B",
        });

        // Pragmatic inference problem
        try self.addProblem(RsbenchProblem{
            .id = 4,
            .problem_type = .pragmatic,
            .question = "Some of the cookies are chocolate. Does this mean all cookies are chocolate?",
            .options = &[_][]const u8{ "Yes", "No", "Maybe" },
            .correct_answer = 1, // No
            .shortcut_answer = 0, // Yes (overgeneralization)
            .explanation = "Existential 'some' does not imply universal 'all'",
        });

        // Counterfactual problem
        try self.addProblem(RsbenchProblem{
            .id = 5,
            .problem_type = .counterfactual,
            .question = "If it had rained, the ground would be wet. It didn't rain. Is the ground wet?",
            .options = &[_][]const u8{ "Yes", "No", "Cannot determine" },
            .correct_answer = 2, // Cannot determine
            .shortcut_answer = 1, // No (denying the antecedent fallacy)
            .explanation = "Denying the antecedent: P → Q does not mean ¬P → ¬Q",
        });
    }

    /// Report results
    pub fn report(results: *const RsbenchResults, writer: anytype) !void {
        try writer.print("rsbench Results:\n", .{});
        try writer.print("  Total Problems: {d}\n", .{results.total});
        try writer.print("  Correct: {d}\n", .{results.correct});
        try writer.print("  Accuracy: {d:.2}%\n", .{results.accuracy() * 100});
        try writer.print("  Shortcuts Caught: {d}\n", .{results.shortcut_caught});
        try writer.print("  Shortcut Rate: {d:.2}%\n", .{results.shortcutRate() * 100});

        try writer.print("\nBy Problem Type:\n", .{});
        const type_names = [_][]const u8{ "Transitivity", "Syllogism", "Counterfactual", "Quantifier Scope", "Pragmatic" };
        for (type_names, 0..) |name, i| {
            const stats = results.by_type[i];
            if (stats.total > 0) {
                const acc = @as(f64, @floatFromInt(stats.correct)) / @as(f64, @floatFromInt(stats.total));
                try writer.print("  {s}: {d:.2}% ({d}/{d})\n", .{ name, acc * 100, stats.correct, stats.total });
            }
        }
    }
};

// ═════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════

test "Rsbench init" {
    const allocator = std.testing.allocator;
    var rs = Rsbench.init(allocator);
    defer rs.deinit();

    try std.testing.expectEqual(@as(usize, 0), rs.problems.items.len);
}

test "Rsbench generate defaults" {
    const allocator = std.testing.allocator;
    var rs = Rsbench.init(allocator);
    defer rs.deinit();

    try rs.generateDefaults();

    try std.testing.expectEqual(@as(usize, 5), rs.problems.items.len);
}

test "Rsbench evaluate correct predictions" {
    const allocator = std.testing.allocator;
    var rs = Rsbench.init(allocator);
    defer rs.deinit();

    try rs.generateDefaults();

    // Correct predictions
    const predictions = [_]usize{ 0, 0, 0, 1, 2 };
    const results = rs.evaluate(&predictions);

    try std.testing.expectEqual(@as(usize, 5), results.total);
    try std.testing.expectEqual(@as(usize, 5), results.correct);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), results.accuracy(), 0.01);
}

test "Rsbench evaluate shortcut predictions" {
    const allocator = std.testing.allocator;
    var rs = Rsbench.init(allocator);
    defer rs.deinit();

    try rs.generateDefaults();

    // Shortcut predictions (all wrong)
    const predictions = [_]usize{ 2, 1, 2, 0, 1 };
    const results = rs.evaluate(&predictions);

    try std.testing.expectEqual(@as(usize, 5), results.total);
    try std.testing.expectEqual(@as(usize, 0), results.correct);
    try std.testing.expectEqual(@as(usize, 5), results.shortcut_caught);
}

test "Rsbench results accuracy" {
    const allocator = std.testing.allocator;
    var rs = Rsbench.init(allocator);
    defer rs.deinit();

    try rs.generateDefaults();

    // Mixed predictions
    const predictions = [_]usize{ 0, 0, 2, 1, 1 }; // 3 correct, 2 shortcuts
    const results = rs.evaluate(&predictions);

    try std.testing.expectApproxEqAbs(@as(f64, 0.6), results.accuracy(), 0.01);
}

// φ² + 1/φ² = 3 | TRINITY
