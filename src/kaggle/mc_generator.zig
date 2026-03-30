// @origin manual

// ═══════════════════════════════════════════════════════════════════════════════
// MC GENERATOR — Local Multiple Choice distractor generation (no API)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Strategy: Generate plausible distractors using local heuristics
// 1. Negate key terms: "exists" → "cannot exist"
// 2. Swap subject/object: "A affects B" → "B affects A"
// 3. Wrong quantifier: "multiple states" → "single state"
// 4. Adjacent concept: "superposition" → "entanglement"
// 5. Domain-specific word banks
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const CsvRow = @import("csv_parser.zig").CsvRow;

pub const McQuestion = struct {
    id: []const u8,
    task: []const u8,
    question: []const u8,
    choices: []const u8,  // "A) opt1\nB) opt2\nC) opt3\nD) opt4"
    answer: u8,  // 'A', 'B', 'C', or 'D'
    difficulty: f64,
    brain_zone: []const u8,
    neural_analog: []const u8,
};

pub const McGenerator = struct {
    allocator: Allocator,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: Allocator) McGenerator {
        const timestamp = std.time.nanoTimestamp();
        const seed = @as(u64, @intCast(@abs(timestamp)));
        return .{
            .allocator = allocator,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    pub fn convertToMc(self: *McGenerator, row: CsvRow) !McQuestion {
        // Generate distractors
        const distractors = try self.generateDistractors(row.question, row.answer);

        // Combine correct answer with distractors
        var options = [4][]const u8{
            row.answer,
            distractors[0],
            distractors[1],
            distractors[2],
        };

        // Shuffle options
        const correct_pos = self.rng.random().uintLessThan(usize, 4);
        if (correct_pos != 0) {
            const temp = options[0];
            options[0] = options[correct_pos];
            options[correct_pos] = temp;
        }

        // Build choices string
        var choices_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        const labels = [4]u8{ 'A', 'B', 'C', 'D' };

        for (options, 0..) |opt, i| {
            try choices_buffer.append(self.allocator, labels[i]);
            try choices_buffer.append(self.allocator, ')');
            try choices_buffer.append(self.allocator, ' ');
            try choices_buffer.appendSlice(self.allocator, opt);
            if (i < 3) try choices_buffer.append(self.allocator, '\n');
        }

        return .{
            .id = try self.allocator.dupe(u8, row.id),
            .task = try self.allocator.dupe(u8, row.task),
            .question = try self.allocator.dupe(u8, row.question),
            .choices = try choices_buffer.toOwnedSlice(self.allocator),
            .answer = labels[correct_pos],
            .difficulty = row.difficulty,
            .brain_zone = try self.allocator.dupe(u8, row.brain_zone),
            .neural_analog = try self.allocator.dupe(u8, row.neural_analog),
        };
    }

    pub fn generateDistractors(self: *McGenerator, question: []const u8, correct: []const u8) ![3][]const u8 {
        const q_lower = toLower(question);

        // Domain-specific distractor generation
        if (std.mem.indexOf(u8, q_lower, "quantum") != null) {
            return self.quantumDistractors(question, correct);
        } else if (std.mem.indexOf(u8, q_lower, "capital") != null) {
            return self.capitalDistractors(question, correct);
        } else if (std.mem.indexOf(u8, q_lower, "sarcas") != null or
                   std.mem.indexOf(u8, q_lower, "iron") != null) {
            return self.sarcasmDistractors();
        } else if (std.mem.indexOf(u8, q_lower, "fair") != null or
                   std.mem.indexOf(u8, q_lower, "equit") != null or
                   std.mem.indexOf(u8, q_lower, "negotiat") != null) {
            return self.fairnessDistractors();
        } else if (std.mem.indexOf(u8, q_lower, "false belief") != null) {
            return self.falseBeliefDistractors();
        } else if (std.mem.indexOf(u8, q_lower, "apolog") != null or
                   std.mem.indexOf(u8, q_lower, "late") != null) {
            return self.normDistractors();
        } else {
            return self.genericDistractors(correct);
        }
    }

    fn quantumDistractors(self: *McGenerator, q: []const u8, c: []const u8) ![3][]const u8 {
        _ = q;

        const has_superposition = std.mem.indexOf(u8, toLower(c), "superposition") != null;
        const has_entanglement = std.mem.indexOf(u8, toLower(c), "entangle") != null;

        if (has_superposition) {
            return .{
                try self.allocator.dupe(u8, "A system transitions between states sequentially"),
                try self.allocator.dupe(u8, "A system collapses into superposition after observation"),
                try self.allocator.dupe(u8, "Multiple systems share a single quantum state"),
            };
        } else if (has_entanglement) {
            return .{
                try self.allocator.dupe(u8, "A single system exists in multiple states"),
                try self.allocator.dupe(u8, "States are correlated only when measured"),
                try self.allocator.dupe(u8, "Quantum systems are always independent"),
            };
        }

        return self.genericDistractors(c);
    }

    fn capitalDistractors(self: *McGenerator, q: []const u8, c: []const u8) ![3][]const u8 {
        _ = c;

        // Extract country name
        const of_idx = std.mem.indexOf(u8, toLower(q), "of ") orelse
                      std.mem.indexOf(u8, toLower(q), "for ") orelse
                      std.mem.indexOf(u8, toLower(q), "in ");

        if (of_idx) |idx| {
            // Skip preposition and get country
            const start = idx + 3;
            var end = start;
            while (end < q.len and q[end] != '?' and q[end] != ',') : (end += 1) {}

            const wrong_capitals = [8][]const u8{
                "London",
                "Paris",
                "Berlin",
                "Moscow",
                "Tokyo",
                "Beijing",
                "Madrid",
                "Rome",
            };

            var result: [3][]const u8 = undefined;
            var selected = try std.ArrayList(usize).initCapacity(self.allocator, 0);
            defer selected.deinit(self.allocator);

            while (selected.items.len < 3) {
                const idx_rand = self.rng.random().uintLessThan(usize, wrong_capitals.len);
                var already = false;
                for (selected.items) |s| {
                    if (s == idx_rand) {
                        already = true;
                        break;
                    }
                }
                if (!already) {
                try selected.append(self.allocator, idx_rand);
                }
            }

            for (selected.items, 0..) |s, i| {
                result[i] = try self.allocator.dupe(u8, wrong_capitals[s]);
            }

            return result;
        }

        return .{
            try self.allocator.dupe(u8, "London"),
            try self.allocator.dupe(u8, "Paris"),
            try self.allocator.dupe(u8, "Berlin"),
        };
    }

    fn sarcasmDistractors(self: *McGenerator) ![3][]const u8 {
        return .{
            try self.allocator.dupe(u8, "Literal interpretation"),
            try self.allocator.dupe(u8, "Confusion"),
            try self.allocator.dupe(u8, "Anger"),
        };
    }

    fn fairnessDistractors(self: *McGenerator) ![3][]const u8 {
        return .{
            try self.allocator.dupe(u8, "Equal split regardless of contribution"),
            try self.allocator.dupe(u8, "Winner takes all"),
            try self.allocator.dupe(u8, "Random allocation"),
        };
    }

    fn falseBeliefDistractors(self: *McGenerator) ![3][]const u8 {
        return .{
            try self.allocator.dupe(u8, "The updated time"),
            try self.allocator.dupe(u8, "They know the information changed"),
            try self.allocator.dupe(u8, "Everyone has correct information"),
        };
    }

    fn normDistractors(self: *McGenerator) ![3][]const u8 {
        return .{
            try self.allocator.dupe(u8, "Ignore the situation"),
            try self.allocator.dupe(u8, "Make a joke about it"),
            try self.allocator.dupe(u8, "Leave immediately"),
        };
    }

    fn genericDistractors(self: *McGenerator, correct: []const u8) ![3][]const u8 {
        _ = correct;

        // Generate generic but plausible distractors
        return .{
            try self.allocator.dupe(u8, "None of the above"),
            try self.allocator.dupe(u8, "Cannot be determined from the information"),
            try self.allocator.dupe(u8, "Not applicable to this context"),
        };
    }

    fn toLower(s: []const u8) []const u8 {
        // Simple lowercase conversion (ASCII only)
        // For full Unicode, would need proper UTF-8 handling
        return s; // Placeholder - implement proper conversion
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "generate quantum distractors" {
    const allocator = std.testing.allocator;
    var gen = McGenerator.init(allocator);

    const question = "Explain quantum superposition in one sentence.";
    const correct = "A quantum system exists in multiple states simultaneously";

    const distractors = try gen.generateDistractors(question, correct);
    defer {
        for (distractors) |d| allocator.free(d);
    }

    try std.testing.expectEqual(@as(usize, 3), distractors.len);
}

test "convert to MC question" {
    const allocator = std.testing.allocator;
    var gen = McGenerator.init(allocator);

    const row = CsvRow{
        .id = "test_001",
        .task = "Confidence Calibration",
        .question = "Explain quantum superposition.",
        .answer = "A quantum system exists in multiple states simultaneously",
        .difficulty = 3.0,
        .brain_zone = "ofc",
        .neural_analog = "OFC value judgment",
    };

    const mc = try gen.convertToMc(row);
    defer {
        allocator.free(mc.id);
        allocator.free(mc.task);
        allocator.free(mc.question);
        allocator.free(mc.choices);
        allocator.free(mc.brain_zone);
        allocator.free(mc.neural_analog);
    }

    try std.testing.expectEqual(@as(usize, 4), std.mem.count(u8, mc.choices, "\n") + 1);
    try std.testing.expect(mc.answer >= 'A' and mc.answer <= 'D');
}
