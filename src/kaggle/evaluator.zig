// @origin manual

// ═══════════════════════════════════════════════════════════════════════════════
// EVALUATOR — Local evaluation engine for cognitive benchmarks
// ═══════════════════════════════════════════════════════════════════════════════
//
// Runs HSLM locally on benchmark items without external API calls.
// Outputs accuracy per track, confusion matrix, and detailed results.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const CsvRow = @import("csv_parser.zig").CsvRow;
const McQuestion = @import("mc_generator.zig").McQuestion;
const Matcher = @import("matcher.zig").Matcher;
const MatchStrategy = @import("matcher.zig").MatchStrategy;

pub const EvalResult = struct {
    total: usize = 0,
    correct: usize = 0,
    incorrect: usize = 0,
    accuracy: f64 = 0.0,
    strategy_counts: [6]usize = [_]usize{0} ** 6,
    confusion: std.AutoHashMap(ConfusionKey, usize),
    per_task: std.StringHashMap(TaskStats),

    pub const ConfusionKey = struct {
        expected: []const u8,
        predicted: []const u8,

        pub fn hash(self: ConfusionKey) u64 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(self.expected);
            hasher.update(self.predicted);
            return hasher.final();
        }

        pub fn eql(a: ConfusionKey, b: ConfusionKey) bool {
            return std.mem.eql(u8, a.expected, b.expected) and
                   std.mem.eql(u8, a.predicted, b.predicted);
        }
    };

    pub const TaskStats = struct {
        total: usize = 0,
        correct: usize = 0,
        accuracy: f64 = 0.0,
    };
};

pub const Evaluator = struct {
    allocator: Allocator,
    matcher: Matcher,

    pub fn init(allocator: Allocator) Evaluator {
        return .{
            .allocator = allocator,
            .matcher = Matcher.init(allocator),
        };
    }

    /// Evaluate rows with given model responses
    pub fn evaluate(
        self: *const Evaluator,
        rows: []const CsvRow,
        responses: []const []const u8,
    ) !EvalResult {
        std.debug.assert(rows.len == responses.len);

        var result = EvalResult{
            .confusion = std.AutoHashMap(EvalResult.ConfusionKey, usize).init(self.allocator),
            .per_task = std.StringHashMap(EvalResult.TaskStats).init(self.allocator),
        };
        defer {
            var conf_iter = result.confusion.iterator();
            while (conf_iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.expected);
                self.allocator.free(entry.key_ptr.predicted);
            }
            result.confusion.deinit();

            var task_iter = result.per_task.iterator();
            while (task_iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            result.per_task.deinit();
        }

        result.total = rows.len;

        for (rows, responses, 0..) |row, response, i| {
            const match_result = self.matcher.match(response, row.answer);

            if (match_result.matched) {
                result.correct += 1;
            } else {
                result.incorrect += 1;
            }

            // Track strategy usage
            const strategy_idx = @intFromEnum(match_result.strategy);
            if (strategy_idx < result.strategy_counts.len) {
                result.strategy_counts[strategy_idx] += 1;
            }

            // Track confusion matrix
            const key = EvalResult.ConfusionKey{
                .expected = try self.allocator.dupe(u8, row.answer),
                .predicted = try self.allocator.dupe(u8, response),
            };
            try result.confusion.put(key, (result.confusion.get(key) orelse 0) + 1);

            // Track per-task statistics
            const task_stats = try result.per_task.getOrPut(row.task);
            if (!task_stats.exists) {
                task_stats.key_ptr.* = try self.allocator.dupe(u8, row.task);
                task_stats.value_ptr.* = .{};
            }
            task_stats.value_ptr.total += 1;
            if (match_result.matched) {
                task_stats.value_ptr.correct += 1;
            }

            if ((i + 1) % 100 == 0) {
                std.debug.print("  Evaluated {d}/{d} (acc: {d:.2}%)\n", .{
                    i + 1, rows.len,
                    @as(f64, @floatFromInt(result.correct * 100)) / @as(f64, @floatFromInt(result.total)),
                });
            }
        }

        // Calculate final accuracy
        if (result.total > 0) {
            result.accuracy = @as(f64, @floatFromInt(result.correct)) /
                            @as(f64, @floatFromInt(result.total));
        }

        // Calculate per-task accuracies
        var task_iter = result.per_task.iterator();
        while (task_iter.next()) |entry| {
            if (entry.value_ptr.total > 0) {
                entry.value_ptr.accuracy = @as(f64, @floatFromInt(entry.value_ptr.correct)) /
                                        @as(f64, @floatFromInt(entry.value_ptr.total));
            }
        }

        return result;
    }

    /// Generate mock responses for testing (use actual model in production)
    pub fn mockResponse(self: *Evaluator, row: CsvRow) ![]const u8 {
        // For testing: return correct answer 70% of time
        const timestamp = std.time.nanoTimestamp();
        const seed = @as(u64, @intCast(@abs(timestamp)));
        const rng = std.Random.DefaultPrng.init(seed);
        if (rng.random().float(f64) < 0.7) {
            return self.allocator.dupe(u8, row.answer);
        } else {
            return self.allocator.dupe(u8, "incorrect mock response");
        }
    }

    pub fn printReport(self: *const Evaluator, result: EvalResult) void {
        _ = self;

        std.debug.print("\n{s}═══ EVALUATION REPORT ═══{s}\n", .{"\x1b[1m", "\x1b[0m"});
        std.debug.print("Total Items: {d}\n", .{result.total});
        std.debug.print("Correct: {d}\n", .{result.correct});
        std.debug.print("Incorrect: {d}\n", .{result.incorrect});
        std.debug.print("{s}Accuracy: {d:.2}%{s}\n\n", .{"\x1b[32m", result.accuracy * 100, "\x1b[0m"});

        std.debug.print("{s}Strategy Breakdown:{s}\n", .{"\x1b[1m", "\x1b[0m"});
        const strategy_names = [6][]const u8{
            "StripParenthetical",
            "ExactMatch",
            "McLetter",
            "Substring",
            "WordBoundary",
            "SequentialWord",
        };

        for (strategy_names, result.strategy_counts) |name, count| {
            if (count > 0) {
                std.debug.print("  {s}: {d}\n", .{name, count});
            }
        }

        std.debug.print("\n{s}Per-Task Breakdown:{s}\n", .{"\x1b[1m", "\x1b[0m"});
        var task_iter = result.per_task.iterator();
        while (task_iter.next()) |entry| {
            std.debug.print("  {s}: {d}/{d} ({d:.2}%)\n", .{
                entry.key_ptr.*,
                entry.value_ptr.correct,
                entry.value_ptr.total,
                entry.value_ptr.accuracy * 100,
            });
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH EVALUATOR — Evaluate all tracks
// ═══════════════════════════════════════════════════════════════════════════════

pub const BatchEvaluator = struct {
    allocator: Allocator,
    base_path: []const u8 = "kaggle/data",

    pub fn init(allocator: Allocator) BatchEvaluator {
        return .{
            .allocator = allocator,
        };
    }

    const TrackConfig = struct {
        id: []const u8,
        name: []const u8,
        file: []const u8,
    };

    const TRACKS = [5]TrackConfig{
        .{ .id = "tmp", .name = "Metacognition", .file = "tmp_metacognition.csv" },
        .{ .id = "thlp", .name = "Learning", .file = "thlp_learning.csv" },
        .{ .id = "tagp", .name = "Attention", .file = "tagp_attention.csv" },
        .{ .id = "tefb", .name = "Executive", .file = "tefb_executive.csv" },
        .{ .id = "tscp", .name = "Social", .file = "tscp_social.csv" },
    };

    pub fn evaluateAll(self: *BatchEvaluator) !void {
        const evaluator = Evaluator.init(self.allocator);

        std.debug.print("\n{s}═══ BATCH EVALUATION ═══{s}\n", .{"\x1b[1m", "\x1b[0m"});

        for (TRACKS) |track| {
            const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.base_path, track.file });
            defer self.allocator.free(path);

            std.debug.print("\n{s}Track: {s} — {s}{s}\n", .{"\x1b[36m", track.id, track.name, "\x1b[0m"});

            // Check if file exists
            const file = std.fs.cwd().openFile(path, .{}) catch |err| {
                std.debug.print("  {s}✗ File not found: {}{s}\n", .{"\x1b[31m", err, "\x1b[0m"});
                continue;
            };
            file.close();

            // Parse CSV
            const CsvParser = @import("csv_parser.zig").CsvParser;
            const parser = CsvParser.init(self.allocator, path);
            const parse_result = try parser.parse();

            // Generate mock responses and evaluate
            var responses = std.ArrayList([]const u8).initCapacity(self.allocator, 0);
            defer {
                for (responses.items) |r| self.allocator.free(r);
                responses.deinit();
            }

            for (parse_result.rows) |row| {
                try responses.append(try evaluator.mockResponse(row));
            }

            // Evaluate
            const eval_result = try evaluator.evaluate(parse_result.rows, responses.items);
            evaluator.printReport(eval_result);

            // Cleanup rows
            for (parse_result.rows) |r| {
                self.allocator.free(r.id);
                self.allocator.free(r.task);
                self.allocator.free(r.question);
                self.allocator.free(r.answer);
                if (r.brain_zone.len > 0) self.allocator.free(r.brain_zone);
                if (r.neural_analog.len > 0) self.allocator.free(r.neural_analog);
            }
            self.allocator.free(parse_result.rows);
            parse_result.stats.deinit();
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "evaluate with perfect responses" {
    const allocator = std.testing.allocator;
    const evaluator = Evaluator.init(allocator);

    const rows = [_]CsvRow{
        .{ .id = "1", .task = "test", .question = "Q1", .answer = "A1", .difficulty = 1 },
        .{ .id = "2", .task = "test", .question = "Q2", .answer = "A2", .difficulty = 1 },
        .{ .id = "3", .task = "test", .question = "Q3", .answer = "A3", .difficulty = 1 },
    };

    const responses = [_][]const u8{ "A1", "A2", "A3" };

    const result = try evaluator.evaluate(&rows, &responses);

    try std.testing.expectEqual(@as(usize, 3), result.total);
    try std.testing.expectEqual(@as(usize, 3), result.correct);
    try std.testing.expectEqual(@as(f64, 1.0), result.accuracy);
}

test "evaluate with mixed responses" {
    const allocator = std.testing.allocator;
    const evaluator = Evaluator.init(allocator);

    const rows = [_]CsvRow{
        .{ .id = "1", .task = "test", .question = "Q1", .answer = "A1", .difficulty = 1 },
        .{ .id = "2", .task = "test", .question = "Q2", .answer = "A2", .difficulty = 1 },
    };

    const responses = [_][]const u8{ "A1", "wrong" };

    const result = try evaluator.evaluate(&rows, &responses);

    try std.testing.expectEqual(@as(usize, 2), result.total);
    try std.testing.expectEqual(@as(usize, 1), result.correct);
    try std.testing.expectEqual(@as(f64, 0.5), result.accuracy);
}
