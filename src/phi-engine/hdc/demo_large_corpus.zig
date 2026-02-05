//! HDC Large Corpus Benchmark: 1000+ samples
//!
//! Tests enhanced encoder (n-grams + TF-IDF) on larger dataset
//! to achieve +30% accuracy improvement over basic encoder.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const mtl = @import("multi_task_learner.zig");

// ═══════════════════════════════════════════════════════════════
// VOCABULARY BANKS FOR SYNTHETIC DATA GENERATION
// ═══════════════════════════════════════════════════════════════

const positive_words = [_][]const u8{
    "love",      "amazing",    "excellent",  "wonderful", "fantastic",
    "great",     "awesome",    "brilliant",  "superb",    "outstanding",
    "perfect",   "beautiful",  "delightful", "happy",     "pleased",
    "satisfied", "recommend",  "best",       "favorite",  "incredible",
    "impressive","magnificent","marvelous",  "terrific",  "fabulous",
    "splendid",  "glorious",   "exceptional","remarkable","phenomenal",
};

const negative_words = [_][]const u8{
    "hate",       "terrible",   "awful",      "horrible",  "worst",
    "bad",        "poor",       "disappointing","frustrating","annoying",
    "angry",      "upset",      "furious",    "disgusting","pathetic",
    "useless",    "waste",      "broken",     "failed",    "disaster",
    "nightmare",  "regret",     "avoid",      "never",     "ruined",
    "damaged",    "defective",  "inferior",   "subpar",    "unacceptable",
};

const neutral_words = [_][]const u8{
    "okay",      "fine",       "average",    "normal",    "standard",
    "acceptable","adequate",   "sufficient", "moderate",  "decent",
    "fair",      "ordinary",   "typical",    "regular",   "common",
    "usual",     "expected",   "reasonable", "passable",  "mediocre",
};

const tech_words = [_][]const u8{
    "computer",   "software",   "programming","code",      "algorithm",
    "machine",    "learning",   "artificial", "intelligence","neural",
    "network",    "database",   "server",     "cloud",     "API",
    "python",     "javascript", "framework",  "developer", "engineer",
    "cybersecurity","encryption","blockchain","cryptocurrency","DevOps",
    "kubernetes", "docker",     "container",  "microservices","frontend",
    "backend",    "fullstack",  "mobile",     "app",       "web",
};

const sports_words = [_][]const u8{
    "football",   "basketball", "soccer",     "tennis",    "championship",
    "team",       "player",     "coach",      "game",      "match",
    "score",      "victory",    "winner",     "athlete",   "training",
    "competition","medal",      "olympics",   "stadium",   "arena",
    "fans",       "cheering",   "referee",    "penalty",   "goal",
    "assist",     "defense",    "offense",    "league",    "tournament",
};

const finance_words = [_][]const u8{
    "stock",      "market",     "investment", "trading",   "portfolio",
    "bank",       "loan",       "interest",   "rate",      "mortgage",
    "credit",     "dividend",   "hedge",      "fund",      "mutual",
    "ETF",        "bonds",      "treasury",   "financial", "planning",
    "retirement", "savings",    "earnings",   "revenue",   "profit",
    "inflation",  "economy",    "venture",    "capital",   "startup",
};

const formal_words = [_][]const u8{
    "Dear",       "Sir",        "Madam",      "regarding", "respectfully",
    "Please",     "attached",   "requested",  "documents", "herewith",
    "hereby",     "acknowledge","receipt",    "formally",  "request",
    "Pursuant",   "discussion", "review",     "express",   "sincere",
    "gratitude",  "hesitate",   "contact",    "forward",   "favorable",
    "response",   "kindly",     "appreciate", "consideration","behalf",
};

const informal_words = [_][]const u8{
    "hey",        "whats",      "up",         "gonna",     "check",
    "lol",        "thats",      "cool",       "yeah",      "sure",
    "yo",         "dude",       "awesome",    "wanna",     "hang",
    "btw",        "omg",        "haha",       "hilarious", "cant",
    "laughing",   "lmao",       "grab",       "food",      "come",
    "sup",        "bro",        "doing",      "nah",       "dont",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║        HDC LARGE CORPUS BENCHMARK (1000+ samples)                ║\n", .{});
    try stdout.print("║           N-grams + TF-IDF for +30% Accuracy                     ║\n", .{});
    try stdout.print("║                  φ² + 1/φ² = 3                                   ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    const dim: usize = 10000;
    const samples_per_class: usize = 150; // 150 * 8 classes = 1200 samples
    const test_samples: usize = 50;

    // ═══════════════════════════════════════════════════════════════
    // GENERATE SYNTHETIC CORPUS
    // ═══════════════════════════════════════════════════════════════

    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    GENERATING SYNTHETIC CORPUS                    \n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    var train_sentiment = std.ArrayList(struct { text: []u8, label: []const u8 }).init(allocator);
    defer {
        for (train_sentiment.items) |item| allocator.free(item.text);
        train_sentiment.deinit();
    }

    var train_topic = std.ArrayList(struct { text: []u8, label: []const u8 }).init(allocator);
    defer {
        for (train_topic.items) |item| allocator.free(item.text);
        train_topic.deinit();
    }

    var train_formality = std.ArrayList(struct { text: []u8, label: []const u8 }).init(allocator);
    defer {
        for (train_formality.items) |item| allocator.free(item.text);
        train_formality.deinit();
    }

    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    // Generate sentiment samples
    for (0..samples_per_class) |i| {
        // Positive
        const pos_text = try generateSentence(allocator, random, &positive_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_sentiment.append(.{ .text = pos_text, .label = "positive" });

        // Negative
        const neg_text = try generateSentence(allocator, random, &negative_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_sentiment.append(.{ .text = neg_text, .label = "negative" });

        // Neutral (every 3rd iteration)
        if (i % 3 == 0) {
            const neu_text = try generateSentence(allocator, random, &neutral_words, 5 + random.intRangeAtMost(usize, 0, 5));
            try train_sentiment.append(.{ .text = neu_text, .label = "neutral" });
        }
    }

    // Generate topic samples
    for (0..samples_per_class) |_| {
        const tech_text = try generateSentence(allocator, random, &tech_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_topic.append(.{ .text = tech_text, .label = "technology" });

        const sports_text = try generateSentence(allocator, random, &sports_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_topic.append(.{ .text = sports_text, .label = "sports" });

        const finance_text = try generateSentence(allocator, random, &finance_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_topic.append(.{ .text = finance_text, .label = "finance" });
    }

    // Generate formality samples
    for (0..samples_per_class) |_| {
        const formal_text = try generateSentence(allocator, random, &formal_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_formality.append(.{ .text = formal_text, .label = "formal" });

        const informal_text = try generateSentence(allocator, random, &informal_words, 5 + random.intRangeAtMost(usize, 0, 5));
        try train_formality.append(.{ .text = informal_text, .label = "informal" });
    }

    const total_samples = train_sentiment.items.len + train_topic.items.len + train_formality.items.len;
    try stdout.print("  Sentiment samples: {d}\n", .{train_sentiment.items.len});
    try stdout.print("  Topic samples:     {d}\n", .{train_topic.items.len});
    try stdout.print("  Formality samples: {d}\n", .{train_formality.items.len});
    try stdout.print("  TOTAL:             {d}\n", .{total_samples});

    // Generate test samples
    var test_data = std.ArrayList(struct { text: []u8, sentiment: []const u8, topic: []const u8, formality: []const u8 }).init(allocator);
    defer {
        for (test_data.items) |item| allocator.free(item.text);
        test_data.deinit();
    }

    for (0..test_samples) |_| {
        // Mix sentiment + topic + formality
        const sent_label = switch (random.intRangeAtMost(u8, 0, 2)) {
            0 => "positive",
            1 => "negative",
            else => "neutral",
        };
        const sent_words: []const []const u8 = switch (random.intRangeAtMost(u8, 0, 2)) {
            0 => &positive_words,
            1 => &negative_words,
            else => &neutral_words,
        };

        const topic_label = switch (random.intRangeAtMost(u8, 0, 2)) {
            0 => "technology",
            1 => "sports",
            else => "finance",
        };
        const topic_words_arr: []const []const u8 = switch (random.intRangeAtMost(u8, 0, 2)) {
            0 => &tech_words,
            1 => &sports_words,
            else => &finance_words,
        };

        const form_label = if (random.boolean()) "formal" else "informal";
        const form_words: []const []const u8 = if (random.boolean()) &formal_words else &informal_words;

        // Generate mixed text
        var text_buf = std.ArrayList(u8).init(allocator);
        defer text_buf.deinit();

        // Add 2-3 words from each category
        for (0..2) |_| {
            const w1 = sent_words[random.intRangeAtMost(usize, 0, sent_words.len - 1)];
            try text_buf.appendSlice(w1);
            try text_buf.append(' ');
        }
        for (0..2) |_| {
            const w2 = topic_words_arr[random.intRangeAtMost(usize, 0, topic_words_arr.len - 1)];
            try text_buf.appendSlice(w2);
            try text_buf.append(' ');
        }
        for (0..2) |_| {
            const w3 = form_words[random.intRangeAtMost(usize, 0, form_words.len - 1)];
            try text_buf.appendSlice(w3);
            try text_buf.append(' ');
        }

        const text = try allocator.dupe(u8, text_buf.items);
        try test_data.append(.{
            .text = text,
            .sentiment = sent_label,
            .topic = topic_label,
            .formality = form_label,
        });
    }

    try stdout.print("  Test samples:      {d}\n", .{test_data.items.len});

    // ═══════════════════════════════════════════════════════════════
    // BENCHMARK: BASIC ENCODER
    // ═══════════════════════════════════════════════════════════════

    try stdout.print("\n═══════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    BASIC ENCODER (Unigram + Position)             \n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    var basic_encoder = mtl.TextEncoder.init(allocator, dim);
    defer basic_encoder.deinit();

    var basic_learner = mtl.MultiTaskLearner.init(allocator, .{
        .dim = dim,
        .learning_rate = 0.3,
        .similarity_threshold = 0.1,
    });
    defer basic_learner.deinit();

    try basic_learner.addTask("sentiment");
    try basic_learner.addTask("topic");
    try basic_learner.addTask("formality");

    // Train basic
    for (train_sentiment.items) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();
        try basic_learner.trainTask("sentiment", vec.data, sample.label);
    }
    for (train_topic.items) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();
        try basic_learner.trainTask("topic", vec.data, sample.label);
    }
    for (train_formality.items) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();
        try basic_learner.trainTask("formality", vec.data, sample.label);
    }

    // Test basic
    var basic_correct: [3]u32 = .{ 0, 0, 0 };

    for (test_data.items) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();

        var result = try basic_learner.predictAll(vec.data);
        defer result.deinit();

        for (result.predictions) |pred| {
            if (std.mem.eql(u8, pred.task, "sentiment")) {
                if (std.mem.eql(u8, pred.label, sample.sentiment)) basic_correct[0] += 1;
            } else if (std.mem.eql(u8, pred.task, "topic")) {
                if (std.mem.eql(u8, pred.label, sample.topic)) basic_correct[1] += 1;
            } else if (std.mem.eql(u8, pred.task, "formality")) {
                if (std.mem.eql(u8, pred.label, sample.formality)) basic_correct[2] += 1;
            }
        }
    }

    const basic_total: f64 = @floatFromInt(test_data.items.len);
    const basic_acc_sentiment = @as(f64, @floatFromInt(basic_correct[0])) / basic_total * 100.0;
    const basic_acc_topic = @as(f64, @floatFromInt(basic_correct[1])) / basic_total * 100.0;
    const basic_acc_formality = @as(f64, @floatFromInt(basic_correct[2])) / basic_total * 100.0;
    const basic_avg = (basic_acc_sentiment + basic_acc_topic + basic_acc_formality) / 3.0;

    try stdout.print("\nBasic Encoder Results:\n", .{});
    try stdout.print("  Sentiment:  {d}/{d} = {d:.1}%\n", .{ basic_correct[0], test_data.items.len, basic_acc_sentiment });
    try stdout.print("  Topic:      {d}/{d} = {d:.1}%\n", .{ basic_correct[1], test_data.items.len, basic_acc_topic });
    try stdout.print("  Formality:  {d}/{d} = {d:.1}%\n", .{ basic_correct[2], test_data.items.len, basic_acc_formality });
    try stdout.print("  AVERAGE:    {d:.1}%\n", .{basic_avg});

    // ═══════════════════════════════════════════════════════════════
    // BENCHMARK: ENHANCED ENCODER
    // ═══════════════════════════════════════════════════════════════

    try stdout.print("\n═══════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                 ENHANCED ENCODER (N-grams + TF-IDF)               \n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    var enhanced_encoder = mtl.EnhancedTextEncoder.init(allocator, dim, .{
        .use_bigrams = true,
        .use_trigrams = true,
        .use_tfidf = true,
        .ngram_weight = 1.5,
    });
    defer enhanced_encoder.deinit();

    var enhanced_learner = mtl.MultiTaskLearner.init(allocator, .{
        .dim = dim,
        .learning_rate = 0.3,
        .similarity_threshold = 0.1,
    });
    defer enhanced_learner.deinit();

    try enhanced_learner.addTask("sentiment");
    try enhanced_learner.addTask("topic");
    try enhanced_learner.addTask("formality");

    // Build IDF from all training data
    for (train_sentiment.items) |sample| {
        try enhanced_encoder.updateDocFreq(sample.text);
    }
    for (train_topic.items) |sample| {
        try enhanced_encoder.updateDocFreq(sample.text);
    }
    for (train_formality.items) |sample| {
        try enhanced_encoder.updateDocFreq(sample.text);
    }

    try stdout.print("  TF-IDF corpus: {d} documents\n", .{enhanced_encoder.total_docs});

    // Train enhanced
    for (train_sentiment.items) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();
        try enhanced_learner.trainTask("sentiment", vec.data, sample.label);
    }
    for (train_topic.items) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();
        try enhanced_learner.trainTask("topic", vec.data, sample.label);
    }
    for (train_formality.items) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();
        try enhanced_learner.trainTask("formality", vec.data, sample.label);
    }

    // Test enhanced
    var enhanced_correct: [3]u32 = .{ 0, 0, 0 };

    for (test_data.items) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();

        var result = try enhanced_learner.predictAll(vec.data);
        defer result.deinit();

        for (result.predictions) |pred| {
            if (std.mem.eql(u8, pred.task, "sentiment")) {
                if (std.mem.eql(u8, pred.label, sample.sentiment)) enhanced_correct[0] += 1;
            } else if (std.mem.eql(u8, pred.task, "topic")) {
                if (std.mem.eql(u8, pred.label, sample.topic)) enhanced_correct[1] += 1;
            } else if (std.mem.eql(u8, pred.task, "formality")) {
                if (std.mem.eql(u8, pred.label, sample.formality)) enhanced_correct[2] += 1;
            }
        }
    }

    const enhanced_total: f64 = @floatFromInt(test_data.items.len);
    const enhanced_acc_sentiment = @as(f64, @floatFromInt(enhanced_correct[0])) / enhanced_total * 100.0;
    const enhanced_acc_topic = @as(f64, @floatFromInt(enhanced_correct[1])) / enhanced_total * 100.0;
    const enhanced_acc_formality = @as(f64, @floatFromInt(enhanced_correct[2])) / enhanced_total * 100.0;
    const enhanced_avg = (enhanced_acc_sentiment + enhanced_acc_topic + enhanced_acc_formality) / 3.0;

    try stdout.print("\nEnhanced Encoder Results:\n", .{});
    try stdout.print("  Sentiment:  {d}/{d} = {d:.1}%\n", .{ enhanced_correct[0], test_data.items.len, enhanced_acc_sentiment });
    try stdout.print("  Topic:      {d}/{d} = {d:.1}%\n", .{ enhanced_correct[1], test_data.items.len, enhanced_acc_topic });
    try stdout.print("  Formality:  {d}/{d} = {d:.1}%\n", .{ enhanced_correct[2], test_data.items.len, enhanced_acc_formality });
    try stdout.print("  AVERAGE:    {d:.1}%\n", .{enhanced_avg});

    // ═══════════════════════════════════════════════════════════════
    // INTERFERENCE CHECK
    // ═══════════════════════════════════════════════════════════════

    try stdout.print("\n═══════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    INTERFERENCE CHECK                             \n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    const metrics = try enhanced_learner.measureAllInterference();
    defer allocator.free(metrics);

    var all_pass = true;
    for (metrics) |m| {
        const status = if (m.max_similarity < 0.05) "PASS" else "HIGH";
        if (m.max_similarity >= 0.05) all_pass = false;
        try stdout.print("  {s} vs {s}: max={d:.4} avg={d:.4} [{s}]\n", .{
            m.task1,
            m.task2,
            m.max_similarity,
            m.avg_similarity,
            status,
        });
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPARISON SUMMARY
    // ═══════════════════════════════════════════════════════════════

    const sent_imp = enhanced_acc_sentiment - basic_acc_sentiment;
    const topic_imp = enhanced_acc_topic - basic_acc_topic;
    const form_imp = enhanced_acc_formality - basic_acc_formality;
    const avg_imp = enhanced_avg - basic_avg;

    try stdout.print("\n╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    COMPARISON SUMMARY                            ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  Corpus size: {d} training samples                             ║\n", .{total_samples});
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("║  Metric          │ Basic    │ Enhanced │ Improvement            ║\n", .{});
    try stdout.print("║  ────────────────┼──────────┼──────────┼────────────            ║\n", .{});

    const sent_sign: []const u8 = if (sent_imp >= 0) "+" else "";
    const topic_sign: []const u8 = if (topic_imp >= 0) "+" else "";
    const form_sign: []const u8 = if (form_imp >= 0) "+" else "";
    const avg_sign: []const u8 = if (avg_imp >= 0) "+" else "";

    try stdout.print("║  Sentiment       │ {d:5.1}%   │ {d:5.1}%   │ {s}{d:.1}%               ║\n", .{ basic_acc_sentiment, enhanced_acc_sentiment, sent_sign, sent_imp });
    try stdout.print("║  Topic           │ {d:5.1}%   │ {d:5.1}%   │ {s}{d:.1}%               ║\n", .{ basic_acc_topic, enhanced_acc_topic, topic_sign, topic_imp });
    try stdout.print("║  Formality       │ {d:5.1}%   │ {d:5.1}%   │ {s}{d:.1}%               ║\n", .{ basic_acc_formality, enhanced_acc_formality, form_sign, form_imp });
    try stdout.print("║  ────────────────┼──────────┼──────────┼────────────            ║\n", .{});
    try stdout.print("║  AVERAGE         │ {d:5.1}%   │ {d:5.1}%   │ {s}{d:.1}%               ║\n", .{ basic_avg, enhanced_avg, avg_sign, avg_imp });
    try stdout.print("║                                                                  ║\n", .{});

    if (avg_imp >= 30.0) {
        try stdout.print("║  ✓ TARGET ACHIEVED: +30% accuracy improvement                   ║\n", .{});
    } else if (avg_imp >= 10.0) {
        try stdout.print("║  ⚠ Good improvement: {s}{d:.1}% (target: +30%)                    ║\n", .{ avg_sign, avg_imp });
    } else if (avg_imp > 0) {
        try stdout.print("║  ⚠ Modest improvement: {s}{d:.1}% (target: +30%)                  ║\n", .{ avg_sign, avg_imp });
    } else {
        try stdout.print("║  ❌ No improvement detected                                      ║\n", .{});
    }

    if (all_pass) {
        try stdout.print("║  ✓ Interference: ALL < 0.05 (VERIFIED)                           ║\n", .{});
    } else {
        try stdout.print("║  ⚠ Interference: some pairs > 0.05                               ║\n", .{});
    }

    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("φ² + 1/φ² = 3 | LARGE CORPUS BENCHMARK COMPLETE\n", .{});
    try stdout.print("\n", .{});
}

fn generateSentence(allocator: std.mem.Allocator, random: std.Random, words: []const []const u8, count: usize) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();

    for (0..count) |i| {
        const word = words[random.intRangeAtMost(usize, 0, words.len - 1)];
        try buf.appendSlice(word);
        if (i < count - 1) try buf.append(' ');
    }

    return buf.toOwnedSlice();
}

test "large corpus compiles" {
    // Just verify compilation
    const allocator = std.testing.allocator;
    var encoder = mtl.EnhancedTextEncoder.init(allocator, 100, .{});
    defer encoder.deinit();
    try std.testing.expectEqual(@as(u32, 0), encoder.total_docs);
}
