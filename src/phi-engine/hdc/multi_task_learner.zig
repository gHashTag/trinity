//! HDC Multi-Task Learner - Shared encoder with independent task heads
//!
//! Architecture:
//! - Shared text encoder (text → hypervector)
//! - Independent prototype banks per task
//! - Simultaneous prediction across all tasks
//!
//! Key property: Task heads are independent (no interference)
//! Interference metric: cosine similarity between task prototypes < 0.05
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

pub const MultiTaskConfig = struct {
    dim: usize = 10240,
    learning_rate: f64 = 0.1,
    similarity_threshold: f64 = 0.3,
    max_classes_per_task: usize = 100,
};

// ═══════════════════════════════════════════════════════════════
// TASK HEAD - Independent prototype bank for one task
// ═══════════════════════════════════════════════════════════════

pub const TaskHead = struct {
    name: []const u8,
    prototypes: std.StringHashMap(TaskPrototype),
    allocator: std.mem.Allocator,
    dim: usize,
    samples_trained: u64,

    pub const TaskPrototype = struct {
        label: []const u8,
        accumulator: []f64,
        vector: []Trit,
        count: u64,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, label: []const u8, dim: usize) !TaskPrototype {
            const acc = try allocator.alloc(f64, dim);
            @memset(acc, 0.0);
            const vec = try allocator.alloc(Trit, dim);
            @memset(vec, 0);
            const label_copy = try allocator.dupe(u8, label);

            return .{
                .label = label_copy,
                .accumulator = acc,
                .vector = vec,
                .count = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *TaskPrototype) void {
            self.allocator.free(self.accumulator);
            self.allocator.free(self.vector);
            self.allocator.free(@constCast(self.label));
        }

        pub fn update(self: *TaskPrototype, input: []const Trit, lr: f64) void {
            hdc.onlineUpdate(self.accumulator, input, lr);
            hdc.quantizeToTernary(self.accumulator, self.vector);
            self.count += 1;
        }
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, dim: usize) !TaskHead {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .name = name_copy,
            .prototypes = std.StringHashMap(TaskPrototype).init(allocator),
            .allocator = allocator,
            .dim = dim,
            .samples_trained = 0,
        };
    }

    pub fn deinit(self: *TaskHead) void {
        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            var proto = entry.value_ptr;
            proto.deinit();
        }
        self.prototypes.deinit();
        self.allocator.free(@constCast(self.name));
    }

    /// Train this task head on a labeled example
    pub fn train(self: *TaskHead, input: []const Trit, label: []const u8, lr: f64) !void {
        self.samples_trained += 1;

        if (self.prototypes.getPtr(label)) |proto| {
            proto.update(input, lr);
        } else {
            var new_proto = try TaskPrototype.init(self.allocator, label, self.dim);
            new_proto.update(input, 1.0); // First example: full update
            try self.prototypes.put(label, new_proto);
        }
    }

    /// Predict class for this task
    pub fn predict(self: *TaskHead, input: []const Trit) TaskPrediction {
        var best_sim: f64 = -2.0;
        var best_label: []const u8 = "";

        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            const sim = hdc.similarity(input, entry.value_ptr.vector);
            if (sim > best_sim) {
                best_sim = sim;
                best_label = entry.key_ptr.*;
            }
        }

        return .{
            .task = self.name,
            .label = best_label,
            .confidence = if (best_sim > -2.0) best_sim else 0.0,
        };
    }

    /// Get all prototype labels
    pub fn getLabels(self: *TaskHead, allocator: std.mem.Allocator) ![][]const u8 {
        var labels = std.ArrayList([]const u8).init(allocator);
        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            try labels.append(entry.key_ptr.*);
        }
        return labels.toOwnedSlice();
    }

    /// Get prototype vector for a label
    pub fn getPrototype(self: *TaskHead, label: []const u8) ?[]const Trit {
        if (self.prototypes.get(label)) |proto| {
            return proto.vector;
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════
// PREDICTION RESULT
// ═══════════════════════════════════════════════════════════════

pub const TaskPrediction = struct {
    task: []const u8,
    label: []const u8,
    confidence: f64,
};

pub const MultiTaskPrediction = struct {
    predictions: []TaskPrediction,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MultiTaskPrediction) void {
        self.allocator.free(self.predictions);
    }
};

// ═══════════════════════════════════════════════════════════════
// INTERFERENCE METRICS
// ═══════════════════════════════════════════════════════════════

pub const InterferenceMetrics = struct {
    task1: []const u8,
    task2: []const u8,
    max_similarity: f64,
    avg_similarity: f64,
    pairs_checked: usize,
};

// ═══════════════════════════════════════════════════════════════
// MULTI-TASK LEARNER
// ═══════════════════════════════════════════════════════════════

pub const MultiTaskLearner = struct {
    config: MultiTaskConfig,
    tasks: std.StringHashMap(TaskHead),
    allocator: std.mem.Allocator,
    dim: usize,

    pub fn init(allocator: std.mem.Allocator, config: MultiTaskConfig) MultiTaskLearner {
        return .{
            .config = config,
            .tasks = std.StringHashMap(TaskHead).init(allocator),
            .allocator = allocator,
            .dim = config.dim,
        };
    }

    pub fn deinit(self: *MultiTaskLearner) void {
        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            var task = entry.value_ptr;
            task.deinit();
        }
        self.tasks.deinit();
    }

    /// Add a new task head
    pub fn addTask(self: *MultiTaskLearner, task_name: []const u8) !void {
        if (!self.tasks.contains(task_name)) {
            const task = try TaskHead.init(self.allocator, task_name, self.dim);
            try self.tasks.put(task_name, task);
        }
    }

    /// Train a specific task on encoded input
    pub fn trainTask(self: *MultiTaskLearner, task_name: []const u8, input: []const Trit, label: []const u8) !void {
        if (self.tasks.getPtr(task_name)) |task| {
            try task.train(input, label, self.config.learning_rate);
        } else {
            return error.TaskNotFound;
        }
    }

    /// Predict for a specific task
    pub fn predictTask(self: *MultiTaskLearner, task_name: []const u8, input: []const Trit) ?TaskPrediction {
        if (self.tasks.getPtr(task_name)) |task| {
            return task.predict(input);
        }
        return null;
    }

    /// Predict for ALL tasks simultaneously
    pub fn predictAll(self: *MultiTaskLearner, input: []const Trit) !MultiTaskPrediction {
        var predictions = std.ArrayList(TaskPrediction).init(self.allocator);

        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            const pred = entry.value_ptr.predict(input);
            try predictions.append(pred);
        }

        return .{
            .predictions = try predictions.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    /// Measure interference between two tasks
    pub fn measureInterference(self: *MultiTaskLearner, task1_name: []const u8, task2_name: []const u8) !InterferenceMetrics {
        const task1 = self.tasks.getPtr(task1_name) orelse return error.TaskNotFound;
        const task2 = self.tasks.getPtr(task2_name) orelse return error.TaskNotFound;

        var max_sim: f64 = 0.0;
        var total_sim: f64 = 0.0;
        var pairs: usize = 0;

        var iter1 = task1.prototypes.iterator();
        while (iter1.next()) |entry1| {
            var iter2 = task2.prototypes.iterator();
            while (iter2.next()) |entry2| {
                const sim = @abs(hdc.similarity(entry1.value_ptr.vector, entry2.value_ptr.vector));
                if (sim > max_sim) max_sim = sim;
                total_sim += sim;
                pairs += 1;
            }
        }

        return .{
            .task1 = task1_name,
            .task2 = task2_name,
            .max_similarity = max_sim,
            .avg_similarity = if (pairs > 0) total_sim / @as(f64, @floatFromInt(pairs)) else 0.0,
            .pairs_checked = pairs,
        };
    }

    /// Measure interference across ALL task pairs
    pub fn measureAllInterference(self: *MultiTaskLearner) ![]InterferenceMetrics {
        var metrics = std.ArrayList(InterferenceMetrics).init(self.allocator);
        var task_names = std.ArrayList([]const u8).init(self.allocator);
        defer task_names.deinit();

        var iter_names = self.tasks.iterator();
        while (iter_names.next()) |entry| {
            try task_names.append(entry.key_ptr.*);
        }

        const names = task_names.items;
        for (0..names.len) |i| {
            for (i + 1..names.len) |j| {
                const m = try self.measureInterference(names[i], names[j]);
                try metrics.append(m);
            }
        }

        return metrics.toOwnedSlice();
    }

    /// Get task statistics
    pub fn getTaskStats(self: *MultiTaskLearner) ![]TaskStats {
        var stats = std.ArrayList(TaskStats).init(self.allocator);

        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            try stats.append(.{
                .name = entry.key_ptr.*,
                .num_classes = entry.value_ptr.prototypes.count(),
                .samples_trained = entry.value_ptr.samples_trained,
            });
        }

        return stats.toOwnedSlice();
    }

    pub const TaskStats = struct {
        name: []const u8,
        num_classes: usize,
        samples_trained: u64,
    };
};

// ═══════════════════════════════════════════════════════════════
// SHARED TEXT ENCODER (Basic)
// ═══════════════════════════════════════════════════════════════

pub const TextEncoder = struct {
    codebook: std.StringHashMap(HyperVector),
    dim: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dim: usize) TextEncoder {
        return .{
            .codebook = std.StringHashMap(HyperVector).init(allocator),
            .dim = dim,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextEncoder) void {
        var iter = self.codebook.iterator();
        while (iter.next()) |entry| {
            var vec = entry.value_ptr;
            vec.deinit();
        }
        self.codebook.deinit();
    }

    /// Get or create a random vector for a token
    fn getTokenVector(self: *TextEncoder, token: []const u8) ![]const Trit {
        if (self.codebook.get(token)) |vec| {
            return vec.data;
        }

        // Create deterministic random vector from token hash
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(token);
        const seed = hasher.final();

        const vec = try hdc.randomVector(self.allocator, self.dim, seed);
        try self.codebook.put(token, vec);
        return vec.data;
    }

    /// Encode text to hypervector using n-gram binding
    pub fn encode(self: *TextEncoder, text: []const u8) !HyperVector {
        var result = try hdc.zeroVector(self.allocator, self.dim);
        var temp = try HyperVector.init(self.allocator, self.dim);
        defer temp.deinit();

        // Tokenize by whitespace
        var tokens = std.mem.tokenizeAny(u8, text, " \t\n\r");
        var pos: usize = 0;

        while (tokens.next()) |token| {
            const token_vec = try self.getTokenVector(token);

            // Permute by position for sequence encoding
            hdc.permute(token_vec, pos, temp.data);

            // Bundle into result
            for (0..self.dim) |i| {
                const sum: i16 = @as(i16, result.data[i]) + @as(i16, temp.data[i]);
                if (sum > 1) {
                    result.data[i] = 1;
                } else if (sum < -1) {
                    result.data[i] = -1;
                } else {
                    result.data[i] = @intCast(sum);
                }
            }

            pos += 1;
        }

        // Normalize to ternary
        for (result.data) |*t| {
            if (t.* > 0) t.* = 1 else if (t.* < 0) t.* = -1;
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════
// ENHANCED TEXT ENCODER (N-grams + TF-IDF weighting)
// ═══════════════════════════════════════════════════════════════

pub const EnhancedTextEncoder = struct {
    pub const Config = struct {
        use_bigrams: bool = true,
        use_trigrams: bool = true,
        use_tfidf: bool = true,
        ngram_weight: f64 = 1.5, // Weight for n-grams vs unigrams
    };

    codebook: std.StringHashMap(HyperVector),
    doc_freq: std.StringHashMap(u32), // Document frequency for IDF
    total_docs: u32,
    dim: usize,
    allocator: std.mem.Allocator,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, dim: usize, config: Config) EnhancedTextEncoder {
        return .{
            .codebook = std.StringHashMap(HyperVector).init(allocator),
            .doc_freq = std.StringHashMap(u32).init(allocator),
            .total_docs = 0,
            .dim = dim,
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *EnhancedTextEncoder) void {
        var iter = self.codebook.iterator();
        while (iter.next()) |entry| {
            var vec = entry.value_ptr;
            vec.deinit();
        }
        self.codebook.deinit();
        self.doc_freq.deinit();
    }

    /// Get or create a random vector for a token/n-gram
    fn getTokenVector(self: *EnhancedTextEncoder, token: []const u8) ![]const Trit {
        if (self.codebook.get(token)) |vec| {
            return vec.data;
        }

        var hasher = std.hash.Wyhash.init(0);
        hasher.update(token);
        const seed = hasher.final();

        const vec = try hdc.randomVector(self.allocator, self.dim, seed);
        try self.codebook.put(token, vec);
        return vec.data;
    }

    /// Update document frequency for IDF calculation
    pub fn updateDocFreq(self: *EnhancedTextEncoder, text: []const u8) !void {
        self.total_docs += 1;

        var seen = std.StringHashMap(bool).init(self.allocator);
        defer seen.deinit();

        var tokens = std.mem.tokenizeAny(u8, text, " \t\n\r");
        while (tokens.next()) |token| {
            if (!seen.contains(token)) {
                try seen.put(token, true);
                const current = self.doc_freq.get(token) orelse 0;
                try self.doc_freq.put(token, current + 1);
            }
        }
    }

    /// Calculate IDF weight for a token
    fn getIdfWeight(self: *EnhancedTextEncoder, token: []const u8) f64 {
        if (!self.config.use_tfidf or self.total_docs == 0) return 1.0;

        const df = self.doc_freq.get(token) orelse 1;
        // IDF = log(N / df) + 1
        const idf = @log(@as(f64, @floatFromInt(self.total_docs)) / @as(f64, @floatFromInt(df))) + 1.0;
        return @min(idf, 3.0); // Cap at 3x weight
    }

    /// Encode text with n-grams and TF-IDF weighting
    pub fn encode(self: *EnhancedTextEncoder, text: []const u8) !HyperVector {
        var accumulator = try self.allocator.alloc(f64, self.dim);
        defer self.allocator.free(accumulator);
        @memset(accumulator, 0.0);

        var temp = try HyperVector.init(self.allocator, self.dim);
        defer temp.deinit();

        // Collect tokens
        var token_list = std.ArrayList([]const u8).init(self.allocator);
        defer token_list.deinit();

        var tokens = std.mem.tokenizeAny(u8, text, " \t\n\r");
        while (tokens.next()) |token| {
            try token_list.append(token);
        }

        const token_arr = token_list.items;

        // Process unigrams with TF-IDF weighting
        for (token_arr, 0..) |token, pos| {
            const token_vec = try self.getTokenVector(token);
            const weight = self.getIdfWeight(token);

            hdc.permute(token_vec, pos, temp.data);

            for (0..self.dim) |i| {
                accumulator[i] += weight * @as(f64, @floatFromInt(temp.data[i]));
            }
        }

        // Process bigrams
        if (self.config.use_bigrams and token_arr.len >= 2) {
            for (0..token_arr.len - 1) |i| {
                // Create bigram by binding two consecutive tokens
                const t1_vec = try self.getTokenVector(token_arr[i]);
                const t2_vec = try self.getTokenVector(token_arr[i + 1]);

                // Bind t1 and t2 for bigram
                for (0..self.dim) |j| {
                    const bound: Trit = t1_vec[j] * t2_vec[j];
                    accumulator[j] += self.config.ngram_weight * @as(f64, @floatFromInt(bound));
                }
            }
        }

        // Process trigrams
        if (self.config.use_trigrams and token_arr.len >= 3) {
            for (0..token_arr.len - 2) |i| {
                const t1_vec = try self.getTokenVector(token_arr[i]);
                const t2_vec = try self.getTokenVector(token_arr[i + 1]);
                const t3_vec = try self.getTokenVector(token_arr[i + 2]);

                // Bind t1, t2, t3 for trigram
                for (0..self.dim) |j| {
                    const bound: Trit = t1_vec[j] * t2_vec[j] * t3_vec[j];
                    accumulator[j] += self.config.ngram_weight * 1.2 * @as(f64, @floatFromInt(bound));
                }
            }
        }

        // Quantize to ternary
        var result = try hdc.zeroVector(self.allocator, self.dim);
        for (0..self.dim) |i| {
            if (accumulator[i] > 0.5) {
                result.data[i] = 1;
            } else if (accumulator[i] < -0.5) {
                result.data[i] = -1;
            } else {
                result.data[i] = 0;
            }
        }

        return result;
    }

    /// Encode with character-level n-grams (for robustness)
    pub fn encodeWithCharNgrams(self: *EnhancedTextEncoder, text: []const u8) !HyperVector {
        var accumulator = try self.allocator.alloc(f64, self.dim);
        defer self.allocator.free(accumulator);
        @memset(accumulator, 0.0);

        // Word-level encoding
        var word_vec = try self.encode(text);
        defer word_vec.deinit();

        for (0..self.dim) |i| {
            accumulator[i] += @as(f64, @floatFromInt(word_vec.data[i]));
        }

        // Character trigrams (3-grams)
        if (text.len >= 3) {
            for (0..text.len - 2) |i| {
                const trigram = text[i .. i + 3];
                var hasher = std.hash.Wyhash.init(12345); // Different seed for char n-grams
                hasher.update(trigram);
                const seed = hasher.final();

                var rng = std.Random.DefaultPrng.init(seed);
                const random = rng.random();

                for (0..self.dim) |j| {
                    const trit: f64 = @floatFromInt(random.intRangeAtMost(i8, -1, 1));
                    accumulator[j] += 0.3 * trit; // Lower weight for char n-grams
                }
            }
        }

        // Quantize
        var result = try hdc.zeroVector(self.allocator, self.dim);
        for (0..self.dim) |i| {
            if (accumulator[i] > 0.5) {
                result.data[i] = 1;
            } else if (accumulator[i] < -0.5) {
                result.data[i] = -1;
            } else {
                result.data[i] = 0;
            }
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "multi-task learner init" {
    const allocator = std.testing.allocator;
    var learner = MultiTaskLearner.init(allocator, .{ .dim = 1000 });
    defer learner.deinit();

    try learner.addTask("sentiment");
    try learner.addTask("topic");
    try learner.addTask("formality");

    try std.testing.expectEqual(@as(usize, 3), learner.tasks.count());
}

test "task independence - no interference" {
    const allocator = std.testing.allocator;
    var learner = MultiTaskLearner.init(allocator, .{ .dim = 10000 });
    defer learner.deinit();

    try learner.addTask("sentiment");
    try learner.addTask("topic");

    // Train sentiment task
    var pos_vec = try hdc.randomVector(allocator, 10000, 11111);
    defer pos_vec.deinit();
    var neg_vec = try hdc.randomVector(allocator, 10000, 22222);
    defer neg_vec.deinit();

    try learner.trainTask("sentiment", pos_vec.data, "positive");
    try learner.trainTask("sentiment", neg_vec.data, "negative");

    // Train topic task with DIFFERENT vectors
    var tech_vec = try hdc.randomVector(allocator, 10000, 33333);
    defer tech_vec.deinit();
    var sports_vec = try hdc.randomVector(allocator, 10000, 44444);
    defer sports_vec.deinit();

    try learner.trainTask("topic", tech_vec.data, "technology");
    try learner.trainTask("topic", sports_vec.data, "sports");

    // Measure interference
    const interference = try learner.measureInterference("sentiment", "topic");

    // Random vectors should have near-zero similarity
    try std.testing.expect(interference.max_similarity < 0.15);
    try std.testing.expect(interference.avg_similarity < 0.1);
}

test "simultaneous prediction" {
    const allocator = std.testing.allocator;
    var learner = MultiTaskLearner.init(allocator, .{ .dim = 5000 });
    defer learner.deinit();

    try learner.addTask("sentiment");
    try learner.addTask("topic");

    // Train
    var pos_vec = try hdc.randomVector(allocator, 5000, 11111);
    defer pos_vec.deinit();
    var tech_vec = try hdc.randomVector(allocator, 5000, 33333);
    defer tech_vec.deinit();

    try learner.trainTask("sentiment", pos_vec.data, "positive");
    try learner.trainTask("topic", tech_vec.data, "technology");

    // Predict on positive sentiment vector
    var result = try learner.predictAll(pos_vec.data);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.predictions.len);

    // Should correctly identify sentiment
    for (result.predictions) |pred| {
        if (std.mem.eql(u8, pred.task, "sentiment")) {
            try std.testing.expectEqualStrings("positive", pred.label);
            try std.testing.expect(pred.confidence > 0.5);
        }
    }
}

test "text encoder deterministic" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator, 1000);
    defer encoder.deinit();

    var vec1 = try encoder.encode("hello world");
    defer vec1.deinit();
    var vec2 = try encoder.encode("hello world");
    defer vec2.deinit();

    const sim = hdc.similarity(vec1.data, vec2.data);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "text encoder different texts" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator, 5000);
    defer encoder.deinit();

    var vec1 = try encoder.encode("I love this product");
    defer vec1.deinit();
    var vec2 = try encoder.encode("terrible experience bad");
    defer vec2.deinit();

    const sim = hdc.similarity(vec1.data, vec2.data);
    // Different texts should have low similarity
    try std.testing.expect(@abs(sim) < 0.3);
}
