// ═══════════════════════════════════════════════════════════════════════════════
// IGLA GLOVE - Full GloVe 300d → Ternary for Production Semantic Reasoning
// ═══════════════════════════════════════════════════════════════════════════════
//
// Production semantic engine using GloVe 6B 300d embeddings (400K vocabulary)
// Quantizes float32 → ternary {-1, 0, +1} for 20x memory savings
// Target: 80%+ analogy accuracy (vs 43% with toy 29-word vocab)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EMBEDDING_DIM: usize = 300; // GloVe 6B 300d
pub const SIMD_WIDTH: usize = 16; // ARM NEON 128-bit
pub const SimdVec = @Vector(SIMD_WIDTH, i8);
pub const MAX_WORD_LEN: usize = 64;
pub const MAX_VOCAB_SIZE: usize = 500_000; // 400K words + buffer

pub const Trit = i8; // {-1, 0, +1}

// ═══════════════════════════════════════════════════════════════════════════════
// TRITVEC - Ternary Vector with SIMD ops (300d aligned)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritVec = struct {
    data: []align(16) Trit,
    len: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dim: usize) !Self {
        const data = try allocator.alignedAlloc(Trit, .@"16", dim);
        @memset(data, 0);
        return Self{ .data = data, .len = dim, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    pub fn clone(self: *const Self) !Self {
        const data = try self.allocator.alignedAlloc(Trit, .@"16", self.len);
        @memcpy(data, self.data);
        return Self{ .data = data, .len = self.len, .allocator = self.allocator };
    }

    /// Quantize float vector to ternary using adaptive threshold
    pub fn fromFloats(allocator: std.mem.Allocator, floats: []const f32, threshold: f32) !Self {
        const data = try allocator.alignedAlloc(Trit, .@"16", floats.len);
        for (floats, 0..) |f, i| {
            if (f > threshold) {
                data[i] = 1;
            } else if (f < -threshold) {
                data[i] = -1;
            } else {
                data[i] = 0;
            }
        }
        return Self{ .data = data, .len = floats.len, .allocator = allocator };
    }

    /// Quantize with adaptive threshold (based on vector magnitude)
    pub fn fromFloatsAdaptive(allocator: std.mem.Allocator, floats: []const f32) !Self {
        // Compute mean absolute value for adaptive threshold
        var sum: f64 = 0;
        for (floats) |f| {
            sum += @abs(f);
        }
        const mean = @as(f32, @floatCast(sum / @as(f64, @floatFromInt(floats.len))));
        const threshold = mean * 0.5; // 50% of mean as threshold

        return fromFloats(allocator, floats, threshold);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD OPERATIONS (optimized for 300d)
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD Bind (element-wise multiplication)
pub fn bindSimd(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alignedAlloc(Trit, .@"16", len);

    const chunks = len / SIMD_WIDTH;
    const remainder = len % SIMD_WIDTH;

    for (0..chunks) |chunk| {
        const offset = chunk * SIMD_WIDTH;
        const va: SimdVec = a.data[offset..][0..SIMD_WIDTH].*;
        const vb: SimdVec = b.data[offset..][0..SIMD_WIDTH].*;
        data[offset..][0..SIMD_WIDTH].* = va * vb;
    }

    const base = chunks * SIMD_WIDTH;
    for (0..remainder) |i| {
        data[base + i] = a.data[base + i] * b.data[base + i];
    }

    return TritVec{ .data = data, .len = len, .allocator = allocator };
}

/// Vector addition for analogy (A - B + C)
pub fn addVec(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alignedAlloc(Trit, .@"16", len);

    for (0..len) |i| {
        const sum: i16 = @as(i16, a.data[i]) + @as(i16, b.data[i]);
        data[i] = if (sum > 0) 1 else if (sum < 0) @as(i8, -1) else 0;
    }

    return TritVec{ .data = data, .len = len, .allocator = allocator };
}

/// Vector subtraction for analogy
pub fn subVec(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alignedAlloc(Trit, .@"16", len);

    for (0..len) |i| {
        const diff: i16 = @as(i16, a.data[i]) - @as(i16, b.data[i]);
        data[i] = if (diff > 0) 1 else if (diff < 0) @as(i8, -1) else 0;
    }

    return TritVec{ .data = data, .len = len, .allocator = allocator };
}

/// SIMD Dot Product (optimized for 300d - exactly 18.75 chunks of 16)
pub fn dotProductSimd(a: *const TritVec, b: *const TritVec) i64 {
    const len = @min(a.len, b.len);
    const chunks = len / SIMD_WIDTH;
    const remainder = len % SIMD_WIDTH;

    var sum: i64 = 0;

    for (0..chunks) |chunk| {
        const offset = chunk * SIMD_WIDTH;
        const va: SimdVec = a.data[offset..][0..SIMD_WIDTH].*;
        const vb: SimdVec = b.data[offset..][0..SIMD_WIDTH].*;
        const prod = va * vb;
        inline for (0..SIMD_WIDTH) |i| {
            sum += prod[i];
        }
    }

    const base = chunks * SIMD_WIDTH;
    for (0..remainder) |i| {
        sum += @as(i64, a.data[base + i]) * @as(i64, b.data[base + i]);
    }

    return sum;
}

/// Cosine Similarity [-1, 1]
pub fn cosineSimilarity(a: *const TritVec, b: *const TritVec) f64 {
    const dot = dotProductSimd(a, b);
    const norm_a = @sqrt(@as(f64, @floatFromInt(dotProductSimd(a, a))));
    const norm_b = @sqrt(@as(f64, @floatFromInt(dotProductSimd(b, b))));

    if (norm_a == 0 or norm_b == 0) return 0;
    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOVE ENGINE - Production Semantic Engine
// ═══════════════════════════════════════════════════════════════════════════════

pub const WordResult = struct {
    word: []const u8,
    similarity: f64,
};

pub const TopKResult = struct {
    words: [10]WordResult,
    count: usize,
};

pub const GloveEngine = struct {
    allocator: std.mem.Allocator,
    words: std.StringHashMap(TritVec),
    dim: usize,
    threshold: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .words = std.StringHashMap(TritVec).init(allocator),
            .dim = EMBEDDING_DIM,
            .threshold = 0.0, // Will be set during loading
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.words.valueIterator();
        while (iter.next()) |vec| {
            var v = vec.*;
            v.deinit();
        }
        // Free word keys
        var key_iter = self.words.keyIterator();
        while (key_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.words.deinit();
    }

    /// Load GloVe embeddings from file (streaming for large files)
    pub fn loadFromFile(self: *Self, path: []const u8, max_words: usize) !usize {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Error opening file {s}: {}\n", .{ path, err });
            return err;
        };
        defer file.close();

        // Read entire file into memory (simpler for Zig 0.15)
        const content = file.readToEndAlloc(self.allocator, 2 * 1024 * 1024 * 1024) catch |err| {
            std.debug.print("Error reading file: {}\n", .{err});
            return err;
        };
        defer self.allocator.free(content);

        var count: usize = 0;
        var floats: [EMBEDDING_DIM]f32 = undefined;

        // First pass: compute global statistics for adaptive threshold
        var sum_abs: f64 = 0;
        var total_values: usize = 0;

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            if (count >= max_words) break;

            var iter = std.mem.splitScalar(u8, line, ' ');
            const word = iter.next() orelse continue;

            // Parse floats
            var dim_idx: usize = 0;
            while (iter.next()) |token| {
                if (dim_idx >= EMBEDDING_DIM) break;
                const val = std.fmt.parseFloat(f32, token) catch continue;
                floats[dim_idx] = val;
                sum_abs += @abs(val);
                total_values += 1;
                dim_idx += 1;
            }

            if (dim_idx < EMBEDDING_DIM) continue;

            // Set threshold based on running average
            if (count == 0) {
                self.threshold = @as(f32, @floatCast(sum_abs / @as(f64, @floatFromInt(total_values)))) * 0.3;
            }

            // Quantize to ternary
            var vec = try TritVec.fromFloats(self.allocator, &floats, self.threshold);
            errdefer vec.deinit();

            // Store word
            const word_key = try self.allocator.dupe(u8, word);
            try self.words.put(word_key, vec);
            count += 1;

            // Progress indicator
            if (count % 50000 == 0) {
                std.debug.print("  Loaded {d} words...\n", .{count});
            }
        }

        return count;
    }

    /// Get vector for word
    pub fn getVec(self: *Self, word: []const u8) ?*TritVec {
        return self.words.getPtr(word);
    }

    /// Check if word exists
    pub fn hasWord(self: *Self, word: []const u8) bool {
        return self.words.contains(word);
    }

    /// Find most similar word to query vector
    pub fn findMostSimilar(self: *Self, query: *const TritVec, exclude: []const []const u8) WordResult {
        var best_word: []const u8 = "";
        var best_sim: f64 = -2.0;

        var iter = self.words.iterator();
        while (iter.next()) |entry| {
            // Check if word should be excluded
            var excluded = false;
            for (exclude) |ex| {
                if (std.mem.eql(u8, entry.key_ptr.*, ex)) {
                    excluded = true;
                    break;
                }
            }
            if (excluded) continue;

            const sim = cosineSimilarity(query, &entry.value_ptr.*);
            if (sim > best_sim) {
                best_sim = sim;
                best_word = entry.key_ptr.*;
            }
        }

        return .{ .word = best_word, .similarity = best_sim };
    }

    /// Find top K most similar words
    pub fn findTopK(self: *Self, query: *const TritVec, exclude: []const []const u8, k: usize) TopKResult {
        var result = TopKResult{
            .words = undefined,
            .count = 0,
        };

        const actual_k = @min(k, 10);

        // Simple O(n*k) selection
        var used: [10][]const u8 = undefined;
        var used_count: usize = 0;

        for (0..actual_k) |round| {
            var best_word: []const u8 = "";
            var best_sim: f64 = -2.0;

            var iter = self.words.iterator();
            while (iter.next()) |entry| {
                // Check exclusions
                var excluded = false;
                for (exclude) |ex| {
                    if (std.mem.eql(u8, entry.key_ptr.*, ex)) {
                        excluded = true;
                        break;
                    }
                }
                if (excluded) continue;

                // Check already used
                for (used[0..used_count]) |u| {
                    if (std.mem.eql(u8, entry.key_ptr.*, u)) {
                        excluded = true;
                        break;
                    }
                }
                if (excluded) continue;

                const sim = cosineSimilarity(query, &entry.value_ptr.*);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_word = entry.key_ptr.*;
                }
            }

            if (best_word.len > 0) {
                result.words[round] = .{ .word = best_word, .similarity = best_sim };
                used[used_count] = best_word;
                used_count += 1;
                result.count += 1;
            }
        }

        return result;
    }

    /// Word analogy: A is to B as C is to ?
    /// Formula: result = B - A + C
    pub fn analogy(self: *Self, a: []const u8, b: []const u8, c: []const u8) !WordResult {
        const va = self.getVec(a) orelse return error.WordNotFound;
        const vb = self.getVec(b) orelse return error.WordNotFound;
        const vc = self.getVec(c) orelse return error.WordNotFound;

        // Compute: result = B - A + C
        var diff = try subVec(self.allocator, vb, va);
        defer diff.deinit();

        var result = try addVec(self.allocator, &diff, vc);
        defer result.deinit();

        // Find most similar, excluding input words
        const exclude = [_][]const u8{ a, b, c };
        return self.findMostSimilar(&result, &exclude);
    }

    /// Word analogy returning top K candidates
    pub fn analogyTopK(self: *Self, a: []const u8, b: []const u8, c: []const u8, k: usize) !TopKResult {
        const va = self.getVec(a) orelse return error.WordNotFound;
        const vb = self.getVec(b) orelse return error.WordNotFound;
        const vc = self.getVec(c) orelse return error.WordNotFound;

        var diff = try subVec(self.allocator, vb, va);
        defer diff.deinit();

        var result = try addVec(self.allocator, &diff, vc);
        defer result.deinit();

        const exclude = [_][]const u8{ a, b, c };
        return self.findTopK(&result, &exclude, k);
    }

    /// Simple similarity between two words
    pub fn similarity(self: *Self, word1: []const u8, word2: []const u8) !f64 {
        const v1 = self.getVec(word1) orelse return error.WordNotFound;
        const v2 = self.getVec(word2) orelse return error.WordNotFound;
        return cosineSimilarity(v1, v2);
    }

    /// Get vocabulary size
    pub fn vocabSize(self: *Self) usize {
        return self.words.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANALOGY TEST SUITE (20+ analogies for 80%+ target)
// ═══════════════════════════════════════════════════════════════════════════════

pub const AnalogyTest = struct {
    a: []const u8,
    b: []const u8,
    c: []const u8,
    expected: []const u8,
    category: []const u8,
};

pub const ANALOGY_TESTS = [_]AnalogyTest{
    // Gender (classic)
    .{ .a = "man", .b = "king", .c = "woman", .expected = "queen", .category = "gender" },
    .{ .a = "man", .b = "boy", .c = "woman", .expected = "girl", .category = "gender" },
    .{ .a = "brother", .b = "sister", .c = "father", .expected = "mother", .category = "gender" },
    .{ .a = "he", .b = "she", .c = "his", .expected = "her", .category = "gender" },
    .{ .a = "man", .b = "actor", .c = "woman", .expected = "actress", .category = "gender" },

    // Geography (capitals)
    .{ .a = "france", .b = "paris", .c = "germany", .expected = "berlin", .category = "capital" },
    .{ .a = "france", .b = "paris", .c = "italy", .expected = "rome", .category = "capital" },
    .{ .a = "france", .b = "paris", .c = "japan", .expected = "tokyo", .category = "capital" },
    .{ .a = "france", .b = "paris", .c = "england", .expected = "london", .category = "capital" },
    .{ .a = "france", .b = "paris", .c = "russia", .expected = "moscow", .category = "capital" },
    .{ .a = "france", .b = "paris", .c = "spain", .expected = "madrid", .category = "capital" },

    // Comparative/Superlative
    .{ .a = "good", .b = "better", .c = "bad", .expected = "worse", .category = "comparative" },
    .{ .a = "good", .b = "best", .c = "bad", .expected = "worst", .category = "superlative" },
    .{ .a = "big", .b = "bigger", .c = "small", .expected = "smaller", .category = "comparative" },

    // Verb tenses
    .{ .a = "walk", .b = "walking", .c = "run", .expected = "running", .category = "tense" },
    .{ .a = "go", .b = "went", .c = "come", .expected = "came", .category = "tense" },
    .{ .a = "eat", .b = "ate", .c = "drink", .expected = "drank", .category = "tense" },

    // Plurals
    .{ .a = "cat", .b = "cats", .c = "dog", .expected = "dogs", .category = "plural" },
    .{ .a = "child", .b = "children", .c = "man", .expected = "men", .category = "plural" },

    // Opposites
    .{ .a = "good", .b = "bad", .c = "happy", .expected = "sad", .category = "opposite" },
    .{ .a = "hot", .b = "cold", .c = "high", .expected = "low", .category = "opposite" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Full GloVe Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const print = std.debug.print;

    print(
        \\╔══════════════════════════════════════════════════════════════╗
        \\║   IGLA GLOVE — PRODUCTION SEMANTIC REASONING ENGINE          ║
        \\║   GloVe 6B 300d → Ternary Quantization (400K words)          ║
        \\║   Target: 80%+ Analogy Accuracy                              ║
        \\║   φ² + 1/φ² = 3 = TRINITY                                    ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
        \\
    , .{});

    // Initialize engine
    var engine = GloveEngine.init(allocator);
    defer engine.deinit();

    // Load GloVe embeddings
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("     LOADING GLOVE 300d EMBEDDINGS                             \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const embedding_path = "models/embeddings/glove.6B.300d.txt";
    const max_words: usize = 400_000;

    var timer = try std.time.Timer.start();
    const word_count = engine.loadFromFile(embedding_path, max_words) catch |err| {
        print("  ERROR loading embeddings: {}\n", .{err});
        print("  Make sure {s} exists\n", .{embedding_path});
        print("  Run: python3 scripts/download_glove.py\n", .{});
        return;
    };
    const load_time = timer.read();

    print("\n  Loaded {d} words in {d:.2}s\n", .{
        word_count,
        @as(f64, @floatFromInt(load_time)) / 1_000_000_000.0,
    });
    print("  Quantization threshold: {d:.4}\n", .{engine.threshold});
    print("  Dimension: {d}\n", .{EMBEDDING_DIM});
    print("  Memory: ~{d}MB (ternary)\n\n", .{(word_count * EMBEDDING_DIM) / (1024 * 1024)});

    // Run analogy test suite
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("     ANALOGY TEST SUITE ({d} tests)                            \n", .{ANALOGY_TESTS.len});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    var correct: usize = 0;
    var total: usize = 0;
    var category_correct = std.StringHashMap(usize).init(allocator);
    var category_total = std.StringHashMap(usize).init(allocator);
    defer category_correct.deinit();
    defer category_total.deinit();

    for (ANALOGY_TESTS) |test_case| {
        // Skip if words not in vocabulary
        if (!engine.hasWord(test_case.a) or !engine.hasWord(test_case.b) or
            !engine.hasWord(test_case.c) or !engine.hasWord(test_case.expected))
        {
            print("  SKIP: {s} - {s} + {s} = ? (word not in vocab)\n", .{
                test_case.a,
                test_case.b,
                test_case.c,
            });
            continue;
        }

        const result = engine.analogy(test_case.a, test_case.b, test_case.c) catch |err| {
            print("  ERROR: {s} - {s} + {s}: {}\n", .{ test_case.a, test_case.b, test_case.c, err });
            continue;
        };

        total += 1;
        const is_correct = std.mem.eql(u8, result.word, test_case.expected);
        if (is_correct) correct += 1;

        // Track by category
        const cat_total = category_total.get(test_case.category) orelse 0;
        try category_total.put(test_case.category, cat_total + 1);
        if (is_correct) {
            const cat_correct = category_correct.get(test_case.category) orelse 0;
            try category_correct.put(test_case.category, cat_correct + 1);
        }

        const status = if (is_correct) "OK" else "MISS";
        print("  [{s:4}] {s} - {s} + {s} = {s}", .{
            status,
            test_case.a,
            test_case.b,
            test_case.c,
            result.word,
        });
        if (!is_correct) {
            print(" (expected: {s})", .{test_case.expected});
        }
        print(" [sim={d:.3}]\n", .{result.similarity});
    }

    // Results
    const accuracy = if (total > 0)
        @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(total)) * 100.0
    else
        0.0;

    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("     RESULTS                                                    \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    print("  Overall: {d}/{d} correct ({d:.1}%)\n", .{ correct, total, accuracy });

    print("\n  By Category:\n", .{});
    var cat_iter = category_total.iterator();
    while (cat_iter.next()) |entry| {
        const cat_c = category_correct.get(entry.key_ptr.*) orelse 0;
        const cat_t = entry.value_ptr.*;
        const cat_acc = @as(f64, @floatFromInt(cat_c)) / @as(f64, @floatFromInt(cat_t)) * 100.0;
        print("    {s}: {d}/{d} ({d:.0}%)\n", .{ entry.key_ptr.*, cat_c, cat_t, cat_acc });
    }

    // Performance benchmark
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("     PERFORMANCE BENCHMARK                                      \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const iterations: usize = 100;
    timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        _ = engine.analogy("man", "king", "woman") catch continue;
    }

    const bench_time = timer.read();
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(bench_time)) / 1_000_000_000.0);

    print("  Iterations: {d}\n", .{iterations});
    print("  Total time: {d:.2}ms\n", .{@as(f64, @floatFromInt(bench_time)) / 1_000_000.0});
    print("  Speed: {d:.1} analogies/sec\n", .{ops_per_sec});
    print("  Vocabulary search: {d} words\n", .{word_count});

    // Summary
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("     SUMMARY                                                    \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const target_met = accuracy >= 80.0;
    const status_str = if (target_met) "TARGET MET" else "BELOW TARGET";

    print("  Vocabulary: {d} words\n", .{word_count});
    print("  Dimension: {d}d → ternary\n", .{EMBEDDING_DIM});
    print("  Accuracy: {d:.1}% ({s})\n", .{ accuracy, status_str });
    print("  Speed: {d:.1} ops/s\n", .{ops_per_sec});

    if (target_met) {
        print("\n  *** 80%+ ACCURACY TARGET ACHIEVED! ***\n", .{});
    } else {
        print("\n  Accuracy below 80% target.\n", .{});
        print("  Consider: top-k matching, L2 norm, or more tests.\n", .{});
    }

    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}
