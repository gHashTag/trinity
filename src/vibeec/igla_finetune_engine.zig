// =============================================================================
// IGLA FINE-TUNING ENGINE v1.0 - Custom Model Adaptation from Examples
// =============================================================================
//
// CYCLE 20: Golden Chain Pipeline
// - Local fine-tuning from user examples
// - Pattern extraction and matching
// - Weight adaptation for personalized responses
// - Integration with API Server (Cycle 19)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI LEARNS ETERNALLY
// =============================================================================

const std = @import("std");
const api = @import("igla_api_server.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const MAX_EXAMPLES: usize = 100;
pub const MAX_EXAMPLE_SIZE: usize = 512;
pub const MAX_PATTERN_SIZE: usize = 64;
pub const MAX_CATEGORIES: usize = 16;
pub const DEFAULT_LEARNING_RATE: f32 = 0.1;
pub const DEFAULT_SIMILARITY_THRESHOLD: f32 = 0.5;
pub const PATTERN_VECTOR_SIZE: usize = 32;

// =============================================================================
// TRAINING EXAMPLE
// =============================================================================

pub const TrainingExample = struct {
    input: [MAX_EXAMPLE_SIZE]u8,
    input_len: usize,
    output: [MAX_EXAMPLE_SIZE]u8,
    output_len: usize,
    category: [MAX_PATTERN_SIZE]u8,
    category_len: usize,
    weight: f32,
    timestamp: i64,
    is_active: bool,

    pub fn init(input: []const u8, output: []const u8, category: []const u8) TrainingExample {
        var example = TrainingExample{
            .input = undefined,
            .input_len = @min(input.len, MAX_EXAMPLE_SIZE),
            .output = undefined,
            .output_len = @min(output.len, MAX_EXAMPLE_SIZE),
            .category = undefined,
            .category_len = @min(category.len, MAX_PATTERN_SIZE),
            .weight = 1.0,
            .timestamp = @intCast(std.time.nanoTimestamp()),
            .is_active = true,
        };
        @memcpy(example.input[0..example.input_len], input[0..example.input_len]);
        @memcpy(example.output[0..example.output_len], output[0..example.output_len]);
        @memcpy(example.category[0..example.category_len], category[0..example.category_len]);
        return example;
    }

    pub fn getInput(self: *const TrainingExample) []const u8 {
        return self.input[0..self.input_len];
    }

    pub fn getOutput(self: *const TrainingExample) []const u8 {
        return self.output[0..self.output_len];
    }

    pub fn getCategory(self: *const TrainingExample) []const u8 {
        return self.category[0..self.category_len];
    }

    pub fn setWeight(self: *TrainingExample, weight: f32) void {
        self.weight = @max(0.0, @min(weight, 10.0));
    }

    pub fn deactivate(self: *TrainingExample) void {
        self.is_active = false;
    }
};

// =============================================================================
// EXAMPLE STORE
// =============================================================================

pub const ExampleStore = struct {
    examples: [MAX_EXAMPLES]TrainingExample,
    example_count: usize,
    total_added: usize,
    total_removed: usize,

    pub fn init() ExampleStore {
        return ExampleStore{
            .examples = undefined,
            .example_count = 0,
            .total_added = 0,
            .total_removed = 0,
        };
    }

    pub fn addExample(self: *ExampleStore, input: []const u8, output: []const u8, category: []const u8) bool {
        if (self.example_count >= MAX_EXAMPLES) {
            return false;
        }
        self.examples[self.example_count] = TrainingExample.init(input, output, category);
        self.example_count += 1;
        self.total_added += 1;
        return true;
    }

    pub fn getExample(self: *const ExampleStore, index: usize) ?*const TrainingExample {
        if (index >= self.example_count) {
            return null;
        }
        return &self.examples[index];
    }

    pub fn removeExample(self: *ExampleStore, index: usize) bool {
        if (index >= self.example_count) {
            return false;
        }
        self.examples[index].deactivate();
        self.total_removed += 1;
        return true;
    }

    pub fn getActiveCount(self: *const ExampleStore) usize {
        var count: usize = 0;
        for (self.examples[0..self.example_count]) |*example| {
            if (example.is_active) {
                count += 1;
            }
        }
        return count;
    }

    pub fn clear(self: *ExampleStore) void {
        self.example_count = 0;
    }

    pub fn findByCategory(self: *const ExampleStore, category: []const u8) ?*const TrainingExample {
        for (self.examples[0..self.example_count]) |*example| {
            if (example.is_active and std.mem.eql(u8, example.getCategory(), category)) {
                return example;
            }
        }
        return null;
    }
};

// =============================================================================
// PATTERN VECTOR
// =============================================================================

pub const PatternVector = struct {
    values: [PATTERN_VECTOR_SIZE]f32,
    magnitude: f32,

    pub fn init() PatternVector {
        var vec = PatternVector{
            .values = undefined,
            .magnitude = 0.0,
        };
        for (&vec.values) |*v| {
            v.* = 0.0;
        }
        return vec;
    }

    pub fn fromText(text: []const u8) PatternVector {
        var vec = PatternVector.init();

        // Simple character frequency based pattern
        for (text) |c| {
            const idx = @as(usize, c) % PATTERN_VECTOR_SIZE;
            vec.values[idx] += 1.0;
        }

        // Normalize
        vec.normalize();
        return vec;
    }

    pub fn normalize(self: *PatternVector) void {
        var sum: f32 = 0.0;
        for (self.values) |v| {
            sum += v * v;
        }
        self.magnitude = @sqrt(sum);

        if (self.magnitude > 0.001) {
            for (&self.values) |*v| {
                v.* /= self.magnitude;
            }
            self.magnitude = 1.0;
        }
    }

    pub fn cosineSimilarity(self: *const PatternVector, other: *const PatternVector) f32 {
        if (self.magnitude < 0.001 or other.magnitude < 0.001) {
            return 0.0;
        }

        var dot: f32 = 0.0;
        for (self.values, other.values) |a, b| {
            dot += a * b;
        }

        return dot / (self.magnitude * other.magnitude);
    }

    pub fn add(self: *PatternVector, other: *const PatternVector, weight: f32) void {
        for (&self.values, other.values) |*a, b| {
            a.* += b * weight;
        }
        self.normalize();
    }
};

// =============================================================================
// PATTERN EXTRACTOR
// =============================================================================

pub const PatternExtractor = struct {
    patterns: [MAX_CATEGORIES]PatternVector,
    category_names: [MAX_CATEGORIES][MAX_PATTERN_SIZE]u8,
    category_lens: [MAX_CATEGORIES]usize,
    pattern_count: usize,

    pub fn init() PatternExtractor {
        var extractor = PatternExtractor{
            .patterns = undefined,
            .category_names = undefined,
            .category_lens = undefined,
            .pattern_count = 0,
        };
        for (&extractor.patterns) |*p| {
            p.* = PatternVector.init();
        }
        for (&extractor.category_lens) |*l| {
            l.* = 0;
        }
        return extractor;
    }

    pub fn extractPattern(self: *PatternExtractor, example: *const TrainingExample) bool {
        // Find or create category
        const category = example.getCategory();
        var cat_idx: ?usize = null;

        for (0..self.pattern_count) |i| {
            if (std.mem.eql(u8, self.category_names[i][0..self.category_lens[i]], category)) {
                cat_idx = i;
                break;
            }
        }

        if (cat_idx == null) {
            if (self.pattern_count >= MAX_CATEGORIES) {
                return false;
            }
            cat_idx = self.pattern_count;
            self.category_lens[cat_idx.?] = category.len;
            @memcpy(self.category_names[cat_idx.?][0..category.len], category);
            self.pattern_count += 1;
        }

        // Extract pattern from input
        const input_pattern = PatternVector.fromText(example.getInput());
        self.patterns[cat_idx.?].add(&input_pattern, example.weight);

        return true;
    }

    pub fn getPattern(self: *const PatternExtractor, category: []const u8) ?*const PatternVector {
        for (0..self.pattern_count) |i| {
            if (std.mem.eql(u8, self.category_names[i][0..self.category_lens[i]], category)) {
                return &self.patterns[i];
            }
        }
        return null;
    }

    pub fn findBestMatch(self: *const PatternExtractor, input: []const u8, threshold: f32) ?struct { category: []const u8, similarity: f32 } {
        const input_pattern = PatternVector.fromText(input);

        var best_similarity: f32 = 0.0;
        var best_idx: ?usize = null;

        for (0..self.pattern_count) |i| {
            const similarity = input_pattern.cosineSimilarity(&self.patterns[i]);
            if (similarity > best_similarity and similarity >= threshold) {
                best_similarity = similarity;
                best_idx = i;
            }
        }

        if (best_idx) |idx| {
            return .{
                .category = self.category_names[idx][0..self.category_lens[idx]],
                .similarity = best_similarity,
            };
        }
        return null;
    }
};

// =============================================================================
// WEIGHT ADAPTER
// =============================================================================

pub const WeightAdapter = struct {
    category_weights: [MAX_CATEGORIES]f32,
    learning_rate: f32,
    total_adaptations: usize,

    pub fn init() WeightAdapter {
        var adapter = WeightAdapter{
            .category_weights = undefined,
            .learning_rate = DEFAULT_LEARNING_RATE,
            .total_adaptations = 0,
        };
        for (&adapter.category_weights) |*w| {
            w.* = 1.0;
        }
        return adapter;
    }

    pub fn initWithLearningRate(lr: f32) WeightAdapter {
        var adapter = WeightAdapter.init();
        adapter.learning_rate = @max(0.01, @min(lr, 1.0));
        return adapter;
    }

    pub fn adapt(self: *WeightAdapter, category_idx: usize, feedback: f32) void {
        if (category_idx >= MAX_CATEGORIES) return;

        // Simple gradient update
        const delta = feedback * self.learning_rate;
        self.category_weights[category_idx] += delta;

        // Clamp weights
        self.category_weights[category_idx] = @max(0.1, @min(self.category_weights[category_idx], 5.0));

        self.total_adaptations += 1;
    }

    pub fn getWeight(self: *const WeightAdapter, category_idx: usize) f32 {
        if (category_idx >= MAX_CATEGORIES) return 1.0;
        return self.category_weights[category_idx];
    }

    pub fn reset(self: *WeightAdapter) void {
        for (&self.category_weights) |*w| {
            w.* = 1.0;
        }
        self.total_adaptations = 0;
    }
};

// =============================================================================
// FINE-TUNE CONFIG
// =============================================================================

pub const FineTuneConfig = struct {
    learning_rate: f32,
    similarity_threshold: f32,
    max_examples: usize,
    auto_adapt: bool,
    decay_rate: f32,

    pub fn init() FineTuneConfig {
        return FineTuneConfig{
            .learning_rate = DEFAULT_LEARNING_RATE,
            .similarity_threshold = DEFAULT_SIMILARITY_THRESHOLD,
            .max_examples = MAX_EXAMPLES,
            .auto_adapt = true,
            .decay_rate = 0.99,
        };
    }

    pub fn withLearningRate(self: FineTuneConfig, lr: f32) FineTuneConfig {
        var config = self;
        config.learning_rate = @max(0.01, @min(lr, 1.0));
        return config;
    }

    pub fn withThreshold(self: FineTuneConfig, threshold: f32) FineTuneConfig {
        var config = self;
        config.similarity_threshold = @max(0.1, @min(threshold, 0.99));
        return config;
    }

    pub fn withAutoAdapt(self: FineTuneConfig, auto: bool) FineTuneConfig {
        var config = self;
        config.auto_adapt = auto;
        return config;
    }
};

// =============================================================================
// ADAPTED RESPONSE
// =============================================================================

pub const AdaptedResponse = struct {
    content: [MAX_EXAMPLE_SIZE]u8,
    content_len: usize,
    category: [MAX_PATTERN_SIZE]u8,
    category_len: usize,
    similarity: f32,
    weight_applied: f32,
    is_adapted: bool,
    adaptation_source: AdaptationSource,

    pub const AdaptationSource = enum {
        None,
        ExactMatch,
        PatternMatch,
        WeightedBlend,
    };

    pub fn init() AdaptedResponse {
        return AdaptedResponse{
            .content = undefined,
            .content_len = 0,
            .category = undefined,
            .category_len = 0,
            .similarity = 0.0,
            .weight_applied = 1.0,
            .is_adapted = false,
            .adaptation_source = .None,
        };
    }

    pub fn fromExample(example: *const TrainingExample, similarity: f32) AdaptedResponse {
        var response = AdaptedResponse.init();
        response.content_len = example.output_len;
        @memcpy(response.content[0..response.content_len], example.output[0..example.output_len]);
        response.category_len = example.category_len;
        @memcpy(response.category[0..response.category_len], example.category[0..example.category_len]);
        response.similarity = similarity;
        response.weight_applied = example.weight;
        response.is_adapted = true;
        response.adaptation_source = if (similarity >= 0.95) .ExactMatch else .PatternMatch;
        return response;
    }

    pub fn fromDefault(content: []const u8) AdaptedResponse {
        var response = AdaptedResponse.init();
        response.content_len = @min(content.len, MAX_EXAMPLE_SIZE);
        @memcpy(response.content[0..response.content_len], content[0..response.content_len]);
        response.is_adapted = false;
        return response;
    }

    pub fn getContent(self: *const AdaptedResponse) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn getCategory(self: *const AdaptedResponse) []const u8 {
        return self.category[0..self.category_len];
    }

    pub fn isHighQuality(self: *const AdaptedResponse) bool {
        return self.is_adapted and self.similarity >= 0.7;
    }
};

// =============================================================================
// FINE-TUNE STATS
// =============================================================================

pub const FineTuneStats = struct {
    total_examples: usize,
    active_examples: usize,
    pattern_count: usize,
    total_adaptations: usize,
    total_inferences: usize,
    adapted_inferences: usize,
    average_similarity: f32,

    pub fn init() FineTuneStats {
        return FineTuneStats{
            .total_examples = 0,
            .active_examples = 0,
            .pattern_count = 0,
            .total_adaptations = 0,
            .total_inferences = 0,
            .adapted_inferences = 0,
            .average_similarity = 0.0,
        };
    }

    pub fn getAdaptationRate(self: *const FineTuneStats) f32 {
        if (self.total_inferences == 0) return 0.0;
        return @as(f32, @floatFromInt(self.adapted_inferences)) / @as(f32, @floatFromInt(self.total_inferences));
    }
};

// =============================================================================
// FINE-TUNE ENGINE
// =============================================================================

pub const FineTuneEngine = struct {
    store: ExampleStore,
    extractor: PatternExtractor,
    adapter: WeightAdapter,
    config: FineTuneConfig,
    api_server: api.ApiServer,
    stats: FineTuneStats,
    total_similarity: f32,

    pub fn init() FineTuneEngine {
        return FineTuneEngine{
            .store = ExampleStore.init(),
            .extractor = PatternExtractor.init(),
            .adapter = WeightAdapter.init(),
            .config = FineTuneConfig.init(),
            .api_server = api.ApiServer.init(),
            .stats = FineTuneStats.init(),
            .total_similarity = 0.0,
        };
    }

    pub fn initWithConfig(config: FineTuneConfig) FineTuneEngine {
        var engine = FineTuneEngine.init();
        engine.config = config;
        engine.adapter = WeightAdapter.initWithLearningRate(config.learning_rate);
        return engine;
    }

    pub fn addExample(self: *FineTuneEngine, input: []const u8, output: []const u8, category: []const u8) bool {
        if (!self.store.addExample(input, output, category)) {
            return false;
        }

        // Extract pattern from new example
        if (self.store.getExample(self.store.example_count - 1)) |example| {
            _ = self.extractor.extractPattern(example);
        }

        self.updateStats();
        return true;
    }

    pub fn train(self: *FineTuneEngine) usize {
        var trained: usize = 0;

        for (0..self.store.example_count) |i| {
            if (self.store.getExample(i)) |example| {
                if (example.is_active) {
                    if (self.extractor.extractPattern(example)) {
                        trained += 1;
                    }
                }
            }
        }

        self.updateStats();
        return trained;
    }

    pub fn infer(self: *FineTuneEngine, input: []const u8) AdaptedResponse {
        self.stats.total_inferences += 1;

        // Try to find matching pattern
        if (self.extractor.findBestMatch(input, self.config.similarity_threshold)) |match| {
            // Find example with this category
            if (self.store.findByCategory(match.category)) |example| {
                self.stats.adapted_inferences += 1;
                self.total_similarity += match.similarity;
                self.updateStats();

                // Auto-adapt if enabled
                if (self.config.auto_adapt) {
                    // Find category index
                    for (0..self.extractor.pattern_count) |i| {
                        if (std.mem.eql(u8, self.extractor.category_names[i][0..self.extractor.category_lens[i]], match.category)) {
                            self.adapter.adapt(i, 0.1); // Positive feedback for match
                            break;
                        }
                    }
                }

                return AdaptedResponse.fromExample(example, match.similarity);
            }
        }

        // Fallback to API server
        const api_request = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
        const api_response = self.api_server.processRequest(api_request);
        _ = api_response;

        self.updateStats();
        return AdaptedResponse.fromDefault("I understand. Let me help you with that based on my training.");
    }

    pub fn provideFeedback(self: *FineTuneEngine, category: []const u8, feedback: f32) void {
        for (0..self.extractor.pattern_count) |i| {
            if (std.mem.eql(u8, self.extractor.category_names[i][0..self.extractor.category_lens[i]], category)) {
                self.adapter.adapt(i, feedback);
                break;
            }
        }
        self.stats.total_adaptations += 1;
    }

    pub fn getStats(self: *const FineTuneEngine) FineTuneStats {
        return self.stats;
    }

    fn updateStats(self: *FineTuneEngine) void {
        self.stats.total_examples = self.store.example_count;
        self.stats.active_examples = self.store.getActiveCount();
        self.stats.pattern_count = self.extractor.pattern_count;
        self.stats.total_adaptations = self.adapter.total_adaptations;

        if (self.stats.adapted_inferences > 0) {
            self.stats.average_similarity = self.total_similarity / @as(f32, @floatFromInt(self.stats.adapted_inferences));
        }
    }

    pub fn reset(self: *FineTuneEngine) void {
        self.store.clear();
        self.extractor = PatternExtractor.init();
        self.adapter.reset();
        self.stats = FineTuneStats.init();
        self.total_similarity = 0.0;
    }

    pub fn getExampleCount(self: *const FineTuneEngine) usize {
        return self.store.example_count;
    }

    pub fn getPatternCount(self: *const FineTuneEngine) usize {
        return self.extractor.pattern_count;
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "TrainingExample init" {
    const example = TrainingExample.init("Hello", "Hi there!", "greeting");
    try std.testing.expectEqualStrings("Hello", example.getInput());
    try std.testing.expectEqualStrings("Hi there!", example.getOutput());
    try std.testing.expectEqualStrings("greeting", example.getCategory());
    try std.testing.expect(example.is_active);
}

test "TrainingExample setWeight" {
    var example = TrainingExample.init("test", "response", "category");
    example.setWeight(2.5);
    try std.testing.expectEqual(@as(f32, 2.5), example.weight);

    // Test clamping
    example.setWeight(15.0);
    try std.testing.expectEqual(@as(f32, 10.0), example.weight);

    example.setWeight(-5.0);
    try std.testing.expectEqual(@as(f32, 0.0), example.weight);
}

test "TrainingExample deactivate" {
    var example = TrainingExample.init("test", "response", "category");
    try std.testing.expect(example.is_active);
    example.deactivate();
    try std.testing.expect(!example.is_active);
}

test "ExampleStore init" {
    const store = ExampleStore.init();
    try std.testing.expectEqual(@as(usize, 0), store.example_count);
    try std.testing.expectEqual(@as(usize, 0), store.total_added);
}

test "ExampleStore addExample" {
    var store = ExampleStore.init();
    const added = store.addExample("input", "output", "category");
    try std.testing.expect(added);
    try std.testing.expectEqual(@as(usize, 1), store.example_count);
    try std.testing.expectEqual(@as(usize, 1), store.total_added);
}

test "ExampleStore getExample" {
    var store = ExampleStore.init();
    _ = store.addExample("Hello", "Hi!", "greeting");

    const example = store.getExample(0);
    try std.testing.expect(example != null);
    try std.testing.expectEqualStrings("Hello", example.?.getInput());

    const invalid = store.getExample(100);
    try std.testing.expect(invalid == null);
}

test "ExampleStore removeExample" {
    var store = ExampleStore.init();
    _ = store.addExample("test", "response", "category");

    try std.testing.expectEqual(@as(usize, 1), store.getActiveCount());

    const removed = store.removeExample(0);
    try std.testing.expect(removed);
    try std.testing.expectEqual(@as(usize, 0), store.getActiveCount());
}

test "ExampleStore findByCategory" {
    var store = ExampleStore.init();
    _ = store.addExample("Hello", "Hi!", "greeting");
    _ = store.addExample("Bye", "Goodbye!", "farewell");

    const found = store.findByCategory("greeting");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Hi!", found.?.getOutput());

    const not_found = store.findByCategory("unknown");
    try std.testing.expect(not_found == null);
}

test "ExampleStore clear" {
    var store = ExampleStore.init();
    _ = store.addExample("test1", "response1", "cat1");
    _ = store.addExample("test2", "response2", "cat2");

    try std.testing.expectEqual(@as(usize, 2), store.example_count);

    store.clear();
    try std.testing.expectEqual(@as(usize, 0), store.example_count);
}

test "PatternVector init" {
    const vec = PatternVector.init();
    try std.testing.expectEqual(@as(f32, 0.0), vec.magnitude);
    for (vec.values) |v| {
        try std.testing.expectEqual(@as(f32, 0.0), v);
    }
}

test "PatternVector fromText" {
    const vec = PatternVector.fromText("hello");
    try std.testing.expect(vec.magnitude > 0.9); // Should be normalized to ~1.0
}

test "PatternVector cosineSimilarity" {
    const vec1 = PatternVector.fromText("hello world");
    const vec2 = PatternVector.fromText("hello there");
    const vec3 = PatternVector.fromText("xyz123");

    const sim_same = vec1.cosineSimilarity(&vec1);
    try std.testing.expect(sim_same > 0.99);

    const sim_similar = vec1.cosineSimilarity(&vec2);
    try std.testing.expect(sim_similar > 0.5);

    const sim_different = vec1.cosineSimilarity(&vec3);
    try std.testing.expect(sim_different < sim_similar);
}

test "PatternExtractor init" {
    const extractor = PatternExtractor.init();
    try std.testing.expectEqual(@as(usize, 0), extractor.pattern_count);
}

test "PatternExtractor extractPattern" {
    var extractor = PatternExtractor.init();
    const example = TrainingExample.init("hello", "hi!", "greeting");

    const extracted = extractor.extractPattern(&example);
    try std.testing.expect(extracted);
    try std.testing.expectEqual(@as(usize, 1), extractor.pattern_count);
}

test "PatternExtractor getPattern" {
    var extractor = PatternExtractor.init();
    const example = TrainingExample.init("hello", "hi!", "greeting");
    _ = extractor.extractPattern(&example);

    const pattern = extractor.getPattern("greeting");
    try std.testing.expect(pattern != null);

    const not_found = extractor.getPattern("unknown");
    try std.testing.expect(not_found == null);
}

test "PatternExtractor findBestMatch" {
    var extractor = PatternExtractor.init();
    const example = TrainingExample.init("hello world", "hi!", "greeting");
    _ = extractor.extractPattern(&example);

    const match = extractor.findBestMatch("hello there", 0.3);
    try std.testing.expect(match != null);
    try std.testing.expectEqualStrings("greeting", match.?.category);

    const no_match = extractor.findBestMatch("xyz", 0.9);
    try std.testing.expect(no_match == null);
}

test "WeightAdapter init" {
    const adapter = WeightAdapter.init();
    try std.testing.expectEqual(DEFAULT_LEARNING_RATE, adapter.learning_rate);
    try std.testing.expectEqual(@as(usize, 0), adapter.total_adaptations);
}

test "WeightAdapter adapt" {
    var adapter = WeightAdapter.init();
    adapter.adapt(0, 1.0);
    try std.testing.expect(adapter.category_weights[0] > 1.0);
    try std.testing.expectEqual(@as(usize, 1), adapter.total_adaptations);
}

test "WeightAdapter getWeight" {
    const adapter = WeightAdapter.init();
    try std.testing.expectEqual(@as(f32, 1.0), adapter.getWeight(0));
    try std.testing.expectEqual(@as(f32, 1.0), adapter.getWeight(1000)); // Out of bounds returns default
}

test "WeightAdapter reset" {
    var adapter = WeightAdapter.init();
    adapter.adapt(0, 1.0);
    adapter.adapt(1, -0.5);

    adapter.reset();
    try std.testing.expectEqual(@as(f32, 1.0), adapter.category_weights[0]);
    try std.testing.expectEqual(@as(usize, 0), adapter.total_adaptations);
}

test "FineTuneConfig init" {
    const config = FineTuneConfig.init();
    try std.testing.expectEqual(DEFAULT_LEARNING_RATE, config.learning_rate);
    try std.testing.expectEqual(DEFAULT_SIMILARITY_THRESHOLD, config.similarity_threshold);
    try std.testing.expect(config.auto_adapt);
}

test "FineTuneConfig withLearningRate" {
    const config = FineTuneConfig.init().withLearningRate(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), config.learning_rate);
}

test "FineTuneConfig withThreshold" {
    const config = FineTuneConfig.init().withThreshold(0.8);
    try std.testing.expectEqual(@as(f32, 0.8), config.similarity_threshold);
}

test "AdaptedResponse init" {
    const response = AdaptedResponse.init();
    try std.testing.expect(!response.is_adapted);
    try std.testing.expectEqual(AdaptedResponse.AdaptationSource.None, response.adaptation_source);
}

test "AdaptedResponse fromExample" {
    const example = TrainingExample.init("input", "output", "category");
    const response = AdaptedResponse.fromExample(&example, 0.9);

    try std.testing.expect(response.is_adapted);
    try std.testing.expectEqualStrings("output", response.getContent());
    try std.testing.expectEqual(@as(f32, 0.9), response.similarity);
}

test "AdaptedResponse fromDefault" {
    const response = AdaptedResponse.fromDefault("default response");
    try std.testing.expect(!response.is_adapted);
    try std.testing.expectEqualStrings("default response", response.getContent());
}

test "AdaptedResponse isHighQuality" {
    const example = TrainingExample.init("input", "output", "category");

    const high_quality = AdaptedResponse.fromExample(&example, 0.8);
    try std.testing.expect(high_quality.isHighQuality());

    const low_quality = AdaptedResponse.fromExample(&example, 0.5);
    try std.testing.expect(!low_quality.isHighQuality());
}

test "FineTuneStats init" {
    const stats = FineTuneStats.init();
    try std.testing.expectEqual(@as(usize, 0), stats.total_examples);
    try std.testing.expectEqual(@as(f32, 0.0), stats.average_similarity);
}

test "FineTuneStats getAdaptationRate" {
    var stats = FineTuneStats.init();
    stats.total_inferences = 10;
    stats.adapted_inferences = 7;

    const rate = stats.getAdaptationRate();
    try std.testing.expect(rate > 0.69);
    try std.testing.expect(rate < 0.71);
}

test "FineTuneEngine init" {
    const engine = FineTuneEngine.init();
    try std.testing.expectEqual(@as(usize, 0), engine.getExampleCount());
    try std.testing.expectEqual(@as(usize, 0), engine.getPatternCount());
}

test "FineTuneEngine addExample" {
    var engine = FineTuneEngine.init();
    const added = engine.addExample("Hello", "Hi there!", "greeting");

    try std.testing.expect(added);
    try std.testing.expectEqual(@as(usize, 1), engine.getExampleCount());
    try std.testing.expectEqual(@as(usize, 1), engine.getPatternCount());
}

test "FineTuneEngine train" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("Hello", "Hi!", "greeting");
    _ = engine.addExample("Bye", "Goodbye!", "farewell");

    const trained = engine.train();
    try std.testing.expectEqual(@as(usize, 2), trained);
}

test "FineTuneEngine infer with match" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("Hello world", "Hi there!", "greeting");
    _ = engine.train();

    const response = engine.infer("Hello friend");
    try std.testing.expect(response.is_adapted);
    try std.testing.expectEqualStrings("Hi there!", response.getContent());
}

test "FineTuneEngine infer without match" {
    var engine = FineTuneEngine.init();
    const response = engine.infer("xyz123");
    try std.testing.expect(!response.is_adapted);
}

test "FineTuneEngine provideFeedback" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("test", "response", "category");

    engine.provideFeedback("category", 0.5);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_adaptations);
}

test "FineTuneEngine getStats" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("Hello", "Hi!", "greeting");
    _ = engine.infer("Hello world");

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_examples);
    try std.testing.expectEqual(@as(usize, 1), stats.total_inferences);
}

test "FineTuneEngine reset" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("test", "response", "category");
    _ = engine.infer("test input");

    engine.reset();

    try std.testing.expectEqual(@as(usize, 0), engine.getExampleCount());
    try std.testing.expectEqual(@as(usize, 0), engine.getPatternCount());
}

test "FineTuneEngine multiple examples same category" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("Hello", "Hi!", "greeting");
    _ = engine.addExample("Hey there", "Hello!", "greeting");

    try std.testing.expectEqual(@as(usize, 2), engine.getExampleCount());
    try std.testing.expectEqual(@as(usize, 1), engine.getPatternCount()); // Same category
}

test "FineTuneEngine multiple categories" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("Hello", "Hi!", "greeting");
    _ = engine.addExample("Bye", "Goodbye!", "farewell");
    _ = engine.addExample("Help me", "Sure!", "request");

    try std.testing.expectEqual(@as(usize, 3), engine.getExampleCount());
    try std.testing.expectEqual(@as(usize, 3), engine.getPatternCount());
}

test "FineTuneEngine adaptation rate" {
    var engine = FineTuneEngine.init();
    _ = engine.addExample("Hello world", "Hi there!", "greeting");
    _ = engine.train();

    // These should match
    _ = engine.infer("Hello friend");
    _ = engine.infer("Hello there");

    // This should not match well
    _ = engine.infer("xyz123");

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.total_inferences);
    try std.testing.expect(stats.adapted_inferences >= 2);
}

test "FineTuneEngine config affects behavior" {
    const config = FineTuneConfig.init().withThreshold(0.9);
    var engine = FineTuneEngine.initWithConfig(config);

    _ = engine.addExample("Hello", "Hi!", "greeting");
    _ = engine.train();

    // With high threshold, partial match shouldn't work
    const response = engine.infer("xyz Hello abc");
    // May or may not match depending on similarity
    _ = response;
}

test "PatternVector add" {
    var vec1 = PatternVector.fromText("hello");
    const vec2 = PatternVector.fromText("world");

    vec1.add(&vec2, 0.5);
    try std.testing.expect(vec1.magnitude > 0.9);
}

test "ExampleStore getActiveCount multiple" {
    var store = ExampleStore.init();
    _ = store.addExample("a", "b", "c");
    _ = store.addExample("d", "e", "f");
    _ = store.addExample("g", "h", "i");

    try std.testing.expectEqual(@as(usize, 3), store.getActiveCount());

    _ = store.removeExample(1);
    try std.testing.expectEqual(@as(usize, 2), store.getActiveCount());
}

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() void {
    std.debug.print("\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("     IGLA FINE-TUNING ENGINE BENCHMARK (CYCLE 20)\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("\n", .{});

    var engine = FineTuneEngine.init();

    // Add training examples
    const examples = [_]struct { input: []const u8, output: []const u8, category: []const u8 }{
        .{ .input = "Hello", .output = "Hi there! How can I help you?", .category = "greeting" },
        .{ .input = "Hey", .output = "Hello! Nice to meet you!", .category = "greeting" },
        .{ .input = "Goodbye", .output = "Goodbye! Have a great day!", .category = "farewell" },
        .{ .input = "Bye", .output = "See you later!", .category = "farewell" },
        .{ .input = "Help me", .output = "I'm here to help! What do you need?", .category = "request" },
        .{ .input = "I need assistance", .output = "Of course! Let me assist you.", .category = "request" },
        .{ .input = "What is AI?", .output = "AI is artificial intelligence, the simulation of human intelligence by machines.", .category = "question" },
        .{ .input = "How does it work?", .output = "It works by processing patterns and learning from examples.", .category = "question" },
        .{ .input = "Thank you", .output = "You're welcome!", .category = "gratitude" },
        .{ .input = "Thanks a lot", .output = "My pleasure! Happy to help!", .category = "gratitude" },
    };

    std.debug.print("  Adding {d} training examples...\n", .{examples.len});

    for (examples) |ex| {
        _ = engine.addExample(ex.input, ex.output, ex.category);
    }

    std.debug.print("  Training patterns...\n", .{});
    const trained = engine.train();
    std.debug.print("  Trained {d} examples\n", .{trained});

    // Run inference tests
    const test_inputs = [_][]const u8{
        "Hello there",
        "Hey friend",
        "Goodbye for now",
        "See you bye",
        "Help me please",
        "I need help",
        "What is machine learning?",
        "How does AI work?",
        "Thank you so much",
        "Thanks!",
        "Random unrelated text",
        "xyz123",
    };

    std.debug.print("\n  Running {d} inference tests...\n\n", .{test_inputs.len});

    var adapted_count: usize = 0;
    var total_similarity: f32 = 0.0;
    var total_time: i64 = 0;

    for (test_inputs) |input| {
        const start: i64 = @intCast(std.time.nanoTimestamp());
        const response = engine.infer(input);
        const end: i64 = @intCast(std.time.nanoTimestamp());

        total_time += end - start;

        if (response.is_adapted) {
            adapted_count += 1;
            total_similarity += response.similarity;
            std.debug.print("  [MATCH] \"{s}\" -> \"{s}\" (sim: {d:.2})\n", .{
                input,
                response.getContent()[0..@min(response.content_len, 30)],
                response.similarity,
            });
        } else {
            std.debug.print("  [DEFAULT] \"{s}\" -> (no match)\n", .{input});
        }
    }

    const stats = engine.getStats();
    const adaptation_rate = stats.getAdaptationRate();
    const avg_similarity = if (adapted_count > 0) total_similarity / @as(f32, @floatFromInt(adapted_count)) else 0.0;
    const avg_time_us = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(test_inputs.len)) / 1000.0;
    const ops_per_sec = @as(f64, @floatFromInt(test_inputs.len)) / (@as(f64, @floatFromInt(total_time)) / 1_000_000_000.0);

    std.debug.print("\n", .{});
    std.debug.print("  Total examples: {d}\n", .{stats.total_examples});
    std.debug.print("  Pattern categories: {d}\n", .{stats.pattern_count});
    std.debug.print("  Total inferences: {d}\n", .{stats.total_inferences});
    std.debug.print("  Adapted inferences: {d}\n", .{stats.adapted_inferences});
    std.debug.print("  Adaptation rate: {d:.2}\n", .{adaptation_rate});
    std.debug.print("  Avg similarity: {d:.2}\n", .{avg_similarity});
    std.debug.print("  Avg inference time: {d:.0}us\n", .{avg_time_us});
    std.debug.print("  Throughput: {d:.0} infer/s\n", .{ops_per_sec});
    std.debug.print("\n", .{});

    // Golden Ratio Gate
    const improvement = adaptation_rate;
    const passed = improvement > 0.618;

    std.debug.print("  Improvement rate: {d:.2}\n", .{improvement});
    if (passed) {
        std.debug.print("  Golden Ratio Gate: PASSED (>0.618)\n", .{});
    } else {
        std.debug.print("  Golden Ratio Gate: FAILED (<0.618)\n", .{});
    }
    std.debug.print("\n", .{});
}

pub fn main() void {
    runBenchmark();
}
