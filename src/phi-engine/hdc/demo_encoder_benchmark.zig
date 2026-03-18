//! HDC Encoder Benchmark: Basic vs Enhanced (N-grams + TF-IDF)
//!
//! Compares accuracy between:
//! - TextEncoder (basic unigram + position)
//! - EnhancedTextEncoder (n-grams + TF-IDF weighting)
//!
//! Target: +30% accuracy improvement
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const mtl = @import("multi_task_learner.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║        HDC ENCODER BENCHMARK: Basic vs Enhanced                  ║\n", .{});
    try stdout.print("║           N-grams + TF-IDF for +30% Accuracy                     ║\n", .{});
    try stdout.print("║                  φ² + 1/φ² = 3                                   ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    const dim: usize = 10000;

    // ═══════════════════════════════════════════════════════════════
    // EXPANDED TRAINING DATA (20+ samples per class)
    // ═══════════════════════════════════════════════════════════════

    // Sentiment training data (expanded)
    const sentiment_train = [_]struct { text: []const u8, label: []const u8 }{
        // Positive (10 samples)
        .{ .text = "I love this amazing product great experience wonderful", .label = "positive" },
        .{ .text = "fantastic excellent best ever highly recommend", .label = "positive" },
        .{ .text = "happy satisfied pleased delighted joy wonderful", .label = "positive" },
        .{ .text = "brilliant superb outstanding magnificent perfect", .label = "positive" },
        .{ .text = "awesome incredible amazing love it so much", .label = "positive" },
        .{ .text = "great quality excellent service very happy", .label = "positive" },
        .{ .text = "wonderful experience highly satisfied recommend", .label = "positive" },
        .{ .text = "love love love this product amazing quality", .label = "positive" },
        .{ .text = "best purchase ever extremely happy satisfied", .label = "positive" },
        .{ .text = "perfect exactly what I wanted love it", .label = "positive" },
        // Negative (10 samples)
        .{ .text = "terrible awful horrible worst disappointed angry", .label = "negative" },
        .{ .text = "bad poor hate dislike frustrating annoying", .label = "negative" },
        .{ .text = "angry upset annoyed irritated furious mad", .label = "negative" },
        .{ .text = "waste of money terrible quality avoid", .label = "negative" },
        .{ .text = "horrible experience never again disappointed", .label = "negative" },
        .{ .text = "worst product ever hate it so much", .label = "negative" },
        .{ .text = "terrible service bad quality very unhappy", .label = "negative" },
        .{ .text = "disappointed frustrated angry waste of time", .label = "negative" },
        .{ .text = "awful terrible horrible do not buy", .label = "negative" },
        .{ .text = "hate this product worst purchase ever", .label = "negative" },
        // Neutral (6 samples)
        .{ .text = "okay fine average normal standard acceptable", .label = "neutral" },
        .{ .text = "acceptable adequate sufficient moderate decent", .label = "neutral" },
        .{ .text = "nothing special just okay average product", .label = "neutral" },
        .{ .text = "mediocre neither good nor bad average", .label = "neutral" },
        .{ .text = "standard quality nothing remarkable ordinary", .label = "neutral" },
        .{ .text = "fair enough acceptable not great not bad", .label = "neutral" },
    };

    // Topic training data (expanded)
    const topic_train = [_]struct { text: []const u8, label: []const u8 }{
        // Technology (8 samples)
        .{ .text = "computer software programming code algorithm developer", .label = "technology" },
        .{ .text = "machine learning artificial intelligence neural network", .label = "technology" },
        .{ .text = "database server cloud computing API microservices", .label = "technology" },
        .{ .text = "python javascript programming language framework", .label = "technology" },
        .{ .text = "cybersecurity encryption data protection firewall", .label = "technology" },
        .{ .text = "mobile app development iOS Android flutter", .label = "technology" },
        .{ .text = "blockchain cryptocurrency smart contract ethereum", .label = "technology" },
        .{ .text = "DevOps kubernetes docker container deployment", .label = "technology" },
        // Sports (8 samples)
        .{ .text = "football basketball soccer tennis championship game", .label = "sports" },
        .{ .text = "team player coach game match score victory", .label = "sports" },
        .{ .text = "athlete training competition medal victory winner", .label = "sports" },
        .{ .text = "baseball hockey golf swimming running marathon", .label = "sports" },
        .{ .text = "world cup championship league tournament finals", .label = "sports" },
        .{ .text = "stadium arena fans cheering crowd excitement", .label = "sports" },
        .{ .text = "referee penalty goal assist defense offense", .label = "sports" },
        .{ .text = "olympics gold medal record breaking athlete", .label = "sports" },
        // Finance (8 samples)
        .{ .text = "stock market investment trading portfolio dividend", .label = "finance" },
        .{ .text = "bank loan interest rate mortgage credit score", .label = "finance" },
        .{ .text = "cryptocurrency bitcoin ethereum trading exchange", .label = "finance" },
        .{ .text = "hedge fund mutual fund ETF bonds treasury", .label = "finance" },
        .{ .text = "financial planning retirement savings investment", .label = "finance" },
        .{ .text = "quarterly earnings revenue profit margin growth", .label = "finance" },
        .{ .text = "inflation interest rates federal reserve economy", .label = "finance" },
        .{ .text = "venture capital startup funding IPO valuation", .label = "finance" },
    };

    // Formality training data (expanded)
    const formality_train = [_]struct { text: []const u8, label: []const u8 }{
        // Formal (8 samples)
        .{ .text = "Dear Sir Madam regarding your inquiry respectfully", .label = "formal" },
        .{ .text = "Please find attached the requested documents herewith", .label = "formal" },
        .{ .text = "We hereby acknowledge receipt of your letter", .label = "formal" },
        .{ .text = "I am writing to formally request information", .label = "formal" },
        .{ .text = "Pursuant to our discussion please review attached", .label = "formal" },
        .{ .text = "We would like to express our sincere gratitude", .label = "formal" },
        .{ .text = "Please do not hesitate to contact us", .label = "formal" },
        .{ .text = "We look forward to your favorable response", .label = "formal" },
        // Informal (8 samples)
        .{ .text = "hey whats up gonna check this out later", .label = "informal" },
        .{ .text = "lol thats cool yeah sure thing no problem", .label = "informal" },
        .{ .text = "yo dude awesome stuff wanna hang out", .label = "informal" },
        .{ .text = "btw did you see that crazy thing omg", .label = "informal" },
        .{ .text = "haha thats hilarious cant stop laughing lmao", .label = "informal" },
        .{ .text = "gonna grab some food wanna come with", .label = "informal" },
        .{ .text = "sup bro how you doing these days", .label = "informal" },
        .{ .text = "nah dont worry about it its all good", .label = "informal" },
    };

    // Test data
    const test_data = [_]struct { text: []const u8, sentiment: []const u8, topic: []const u8, formality: []const u8 }{
        .{ .text = "I love this amazing software programming experience", .sentiment = "positive", .topic = "technology", .formality = "informal" },
        .{ .text = "terrible football game worst match ever played", .sentiment = "negative", .topic = "sports", .formality = "informal" },
        .{ .text = "Dear Sir regarding your investment portfolio inquiry", .sentiment = "neutral", .topic = "finance", .formality = "formal" },
        .{ .text = "hey whats up with the new computer code", .sentiment = "neutral", .topic = "technology", .formality = "informal" },
        .{ .text = "excellent basketball championship victory celebration", .sentiment = "positive", .topic = "sports", .formality = "informal" },
        .{ .text = "We acknowledge receipt of your bank statement", .sentiment = "neutral", .topic = "finance", .formality = "formal" },
        .{ .text = "lol that stock market crash was really bad", .sentiment = "negative", .topic = "finance", .formality = "informal" },
        .{ .text = "wonderful neural network training results achieved", .sentiment = "positive", .topic = "technology", .formality = "informal" },
        .{ .text = "yo dude check out this sports game tonight", .sentiment = "neutral", .topic = "sports", .formality = "informal" },
        .{ .text = "Please find attached the algorithm documentation", .sentiment = "neutral", .topic = "technology", .formality = "formal" },
        .{ .text = "hate this terrible service worst experience ever", .sentiment = "negative", .topic = "technology", .formality = "informal" },
        .{ .text = "fantastic game winning goal amazing victory", .sentiment = "positive", .topic = "sports", .formality = "informal" },
    };

    // ═══════════════════════════════════════════════════════════════
    // BENCHMARK: BASIC ENCODER
    // ═══════════════════════════════════════════════════════════════

    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    BASIC ENCODER (Unigram + Position)             \n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    var basic_encoder = mtl.TextEncoder.init(allocator, dim);
    defer basic_encoder.deinit();

    var basic_learner = mtl.MultiTaskLearner.init(allocator, .{
        .dim = dim,
        .learning_rate = 0.5,
        .similarity_threshold = 0.1,
    });
    defer basic_learner.deinit();

    try basic_learner.addTask("sentiment");
    try basic_learner.addTask("topic");
    try basic_learner.addTask("formality");

    // Train basic
    for (sentiment_train) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();
        try basic_learner.trainTask("sentiment", vec.data, sample.label);
    }
    for (topic_train) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();
        try basic_learner.trainTask("topic", vec.data, sample.label);
    }
    for (formality_train) |sample| {
        var vec = try basic_encoder.encode(sample.text);
        defer vec.deinit();
        try basic_learner.trainTask("formality", vec.data, sample.label);
    }

    // Test basic
    var basic_correct: [3]u32 = .{ 0, 0, 0 };
    var basic_total: u32 = 0;

    for (test_data) |sample| {
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
        basic_total += 1;
    }

    const basic_acc_sentiment = @as(f64, @floatFromInt(basic_correct[0])) / @as(f64, @floatFromInt(basic_total)) * 100.0;
    const basic_acc_topic = @as(f64, @floatFromInt(basic_correct[1])) / @as(f64, @floatFromInt(basic_total)) * 100.0;
    const basic_acc_formality = @as(f64, @floatFromInt(basic_correct[2])) / @as(f64, @floatFromInt(basic_total)) * 100.0;
    const basic_avg = (basic_acc_sentiment + basic_acc_topic + basic_acc_formality) / 3.0;

    try stdout.print("\nBasic Encoder Results:\n", .{});
    try stdout.print("  Sentiment:  {d}/{d} = {d:.1}%\n", .{ basic_correct[0], basic_total, basic_acc_sentiment });
    try stdout.print("  Topic:      {d}/{d} = {d:.1}%\n", .{ basic_correct[1], basic_total, basic_acc_topic });
    try stdout.print("  Formality:  {d}/{d} = {d:.1}%\n", .{ basic_correct[2], basic_total, basic_acc_formality });
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
        .ngram_weight = 0.5, // Lower weight for n-grams
    });
    defer enhanced_encoder.deinit();

    var enhanced_learner = mtl.MultiTaskLearner.init(allocator, .{
        .dim = dim,
        .learning_rate = 0.5,
        .similarity_threshold = 0.1,
    });
    defer enhanced_learner.deinit();

    try enhanced_learner.addTask("sentiment");
    try enhanced_learner.addTask("topic");
    try enhanced_learner.addTask("formality");

    // Build IDF from all training data
    for (sentiment_train) |sample| {
        try enhanced_encoder.updateDocFreq(sample.text);
    }
    for (topic_train) |sample| {
        try enhanced_encoder.updateDocFreq(sample.text);
    }
    for (formality_train) |sample| {
        try enhanced_encoder.updateDocFreq(sample.text);
    }

    try stdout.print("  TF-IDF corpus: {d} documents\n", .{enhanced_encoder.total_docs});

    // Train enhanced (single pass, rely on better encoding)
    for (sentiment_train) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();
        try enhanced_learner.trainTask("sentiment", vec.data, sample.label);
    }
    for (topic_train) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();
        try enhanced_learner.trainTask("topic", vec.data, sample.label);
    }
    for (formality_train) |sample| {
        var vec = try enhanced_encoder.encode(sample.text);
        defer vec.deinit();
        try enhanced_learner.trainTask("formality", vec.data, sample.label);
    }

    // Test enhanced
    var enhanced_correct: [3]u32 = .{ 0, 0, 0 };
    var enhanced_total: u32 = 0;

    for (test_data) |sample| {
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
        enhanced_total += 1;
    }

    const enhanced_acc_sentiment = @as(f64, @floatFromInt(enhanced_correct[0])) / @as(f64, @floatFromInt(enhanced_total)) * 100.0;
    const enhanced_acc_topic = @as(f64, @floatFromInt(enhanced_correct[1])) / @as(f64, @floatFromInt(enhanced_total)) * 100.0;
    const enhanced_acc_formality = @as(f64, @floatFromInt(enhanced_correct[2])) / @as(f64, @floatFromInt(enhanced_total)) * 100.0;
    const enhanced_avg = (enhanced_acc_sentiment + enhanced_acc_topic + enhanced_acc_formality) / 3.0;

    try stdout.print("\nEnhanced Encoder Results:\n", .{});
    try stdout.print("  Sentiment:  {d}/{d} = {d:.1}%\n", .{ enhanced_correct[0], enhanced_total, enhanced_acc_sentiment });
    try stdout.print("  Topic:      {d}/{d} = {d:.1}%\n", .{ enhanced_correct[1], enhanced_total, enhanced_acc_topic });
    try stdout.print("  Formality:  {d}/{d} = {d:.1}%\n", .{ enhanced_correct[2], enhanced_total, enhanced_acc_formality });
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

    try stdout.print("\n╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    COMPARISON SUMMARY                            ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("║  Metric          │ Basic    │ Enhanced │ Improvement            ║\n", .{});
    try stdout.print("║  ────────────────┼──────────┼──────────┼────────────            ║\n", .{});

    const sent_imp = enhanced_acc_sentiment - basic_acc_sentiment;
    const topic_imp = enhanced_acc_topic - basic_acc_topic;
    const form_imp = enhanced_acc_formality - basic_acc_formality;
    const avg_imp = enhanced_avg - basic_avg;

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
    } else if (avg_imp > 0) {
        try stdout.print("║  ⚠ Improvement: +{d:.1}% (target: +30%)                           ║\n", .{avg_imp});
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
    try stdout.print("φ² + 1/φ² = 3 | ENCODER BENCHMARK COMPLETE\n", .{});
    try stdout.print("\n", .{});
}

test "benchmark compiles" {
    const allocator = std.testing.allocator;
    var encoder = mtl.EnhancedTextEncoder.init(allocator, 100, .{});
    defer encoder.deinit();
    try std.testing.expectEqual(@as(u32, 0), encoder.total_docs);
}
