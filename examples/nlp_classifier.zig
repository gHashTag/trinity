// Trinity SDK - NLP Classification Example
// Demonstrates text classification using hyperdimensional computing
//
// This example shows how to:
// 1. Encode text as hypervectors using n-gram encoding
// 2. Train a simple classifier
// 3. Classify new text samples

const std = @import("std");
const trinity = @import("trinity");

const Hypervector = trinity.Hypervector;
const Classifier = trinity.sdk.Classifier;
const Codebook = trinity.sdk.Codebook;
const SequenceEncoder = trinity.sdk.SequenceEncoder;

/// Text encoder using character n-grams
const TextEncoder = struct {
    codebook: Codebook,
    seq_encoder: SequenceEncoder,
    dimension: usize,
    ngram_size: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dimension: usize, ngram_size: usize) Self {
        return Self{
            .codebook = Codebook.init(allocator, dimension),
            .seq_encoder = SequenceEncoder.init(dimension),
            .dimension = dimension,
            .ngram_size = ngram_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.codebook.deinit();
    }

    /// Encode text to hypervector using n-gram encoding
    pub fn encode(self: *Self, text: []const u8) !Hypervector {
        if (text.len < self.ngram_size) {
            // Text too short, encode as single symbol
            const hv = try self.codebook.encode(text);
            return hv.clone();
        }

        // Extract n-grams and bundle them
        var result = Hypervector.init(self.dimension);
        var count: usize = 0;

        var i: usize = 0;
        while (i + self.ngram_size <= text.len) : (i += 1) {
            const ngram = text[i .. i + self.ngram_size];
            var ngram_hv = try self.codebook.encode(ngram);

            // Position-encode the n-gram
            var positioned = ngram_hv.permute(i);

            // Bundle into result
            result = result.bundle(&positioned);
            count += 1;
        }

        return result;
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("              TRINITY NLP CLASSIFIER EXAMPLE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    // Initialize encoder and classifier
    const dimension = 10000;
    var encoder = TextEncoder.init(allocator, dimension, 3);
    defer encoder.deinit();

    var classifier = Classifier.init(allocator, dimension);
    defer classifier.deinit();

    // ─────────────────────────────────────────────────────────────────────────
    // Training Data
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("1. TRAINING\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // Positive sentiment samples
    const positive_samples = [_][]const u8{
        "great product love it",
        "amazing quality excellent",
        "wonderful experience happy",
        "fantastic service great",
        "love this product amazing",
    };

    // Negative sentiment samples
    const negative_samples = [_][]const u8{
        "terrible product hate it",
        "awful quality horrible",
        "bad experience unhappy",
        "poor service terrible",
        "hate this product awful",
    };

    // Train on positive samples
    for (positive_samples) |sample| {
        var encoded = try encoder.encode(sample);
        try classifier.train("positive", &encoded);
    }
    try stdout.print("Trained on {d} positive samples\n", .{positive_samples.len});

    // Train on negative samples
    for (negative_samples) |sample| {
        var encoded = try encoder.encode(sample);
        try classifier.train("negative", &encoded);
    }
    try stdout.print("Trained on {d} negative samples\n", .{negative_samples.len});
    try stdout.print("Total classes: {d}\n\n", .{classifier.classCount()});

    // ─────────────────────────────────────────────────────────────────────────
    // Testing
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("2. TESTING\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    const test_samples = [_][]const u8{
        "great quality love it",
        "terrible service hate",
        "amazing product excellent",
        "awful experience bad",
        "happy with purchase",
        "unhappy with quality",
    };

    const expected = [_][]const u8{
        "positive",
        "negative",
        "positive",
        "negative",
        "positive",
        "negative",
    };

    var correct: usize = 0;

    for (test_samples, 0..) |sample, i| {
        var encoded = try encoder.encode(sample);
        const result = classifier.predictWithConfidence(&encoded);

        const predicted = result.class orelse "unknown";
        const is_correct = std.mem.eql(u8, predicted, expected[i]);
        if (is_correct) correct += 1;

        const mark = if (is_correct) "✓" else "✗";
        try stdout.print("{s} \"{s}\"\n", .{ mark, sample });
        try stdout.print("   Predicted: {s} (confidence: {d:.3})\n", .{ predicted, result.confidence });
    }

    const accuracy = @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(test_samples.len)) * 100;
    try stdout.print("\nAccuracy: {d}/{d} ({d:.1}%)\n\n", .{ correct, test_samples.len, accuracy });

    // ─────────────────────────────────────────────────────────────────────────
    // Summary
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("✓ Text encoding using character n-grams\n", .{});
    try stdout.print("✓ Position encoding with permutation\n", .{});
    try stdout.print("✓ Simple HDC classifier with bundling\n", .{});
    try stdout.print("✓ One-shot learning (no backpropagation)\n", .{});
    try stdout.print("\nAdvantages of HDC for NLP:\n", .{});
    try stdout.print("  - Fast training (single pass)\n", .{});
    try stdout.print("  - Interpretable representations\n", .{});
    try stdout.print("  - Robust to noise and typos\n", .{});
    try stdout.print("  - Low memory footprint\n", .{});
    try stdout.print("\nφ² + 1/φ² = 3\n\n", .{});
}
