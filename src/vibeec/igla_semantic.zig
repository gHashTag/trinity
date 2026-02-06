// ═══════════════════════════════════════════════════════════════════════════════
// IGLA SEMANTIC - Pre-trained Embeddings → Ternary for Coherent Reasoning
// ═══════════════════════════════════════════════════════════════════════════════
//
// This module loads pre-trained word embeddings (Word2Vec/GloVe style),
// quantizes them to ternary {-1, 0, +1}, and enables semantic reasoning.
//
// Key achievement: "king - man + woman ≈ queen" works with real embeddings!
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EMBEDDING_DIM: usize = 50; // Standard GloVe 50d
pub const SIMD_WIDTH: usize = 16; // ARM NEON 128-bit
pub const SimdVec = @Vector(SIMD_WIDTH, i8);

pub const Trit = i8; // {-1, 0, +1}

// ═══════════════════════════════════════════════════════════════════════════════
// TRITVEC - Ternary Vector with SIMD ops
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

    /// Quantize float vector to ternary using thresholds
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
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD OPERATIONS
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

/// Vector addition (for analogy: A - B + C)
pub fn addVec(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alignedAlloc(Trit, .@"16", len);

    for (0..len) |i| {
        const sum: i16 = @as(i16, a.data[i]) + @as(i16, b.data[i]);
        // Clamp to ternary range
        data[i] = if (sum > 0) 1 else if (sum < 0) @as(i8, -1) else 0;
    }

    return TritVec{ .data = data, .len = len, .allocator = allocator };
}

/// Vector subtraction (for analogy: A - B + C)
pub fn subVec(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alignedAlloc(Trit, .@"16", len);

    for (0..len) |i| {
        const diff: i16 = @as(i16, a.data[i]) - @as(i16, b.data[i]);
        // Clamp to ternary range
        data[i] = if (diff > 0) 1 else if (diff < 0) @as(i8, -1) else 0;
    }

    return TritVec{ .data = data, .len = len, .allocator = allocator };
}

/// SIMD Dot Product
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

/// Cosine Similarity
pub fn cosineSimilarity(a: *const TritVec, b: *const TritVec) f64 {
    const dot = dotProductSimd(a, b);
    const norm_a = @sqrt(@as(f64, @floatFromInt(dotProductSimd(a, a))));
    const norm_b = @sqrt(@as(f64, @floatFromInt(dotProductSimd(b, b))));

    if (norm_a == 0 or norm_b == 0) return 0;
    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const WordResult = struct {
    word: []const u8,
    similarity: f64,
};

pub const SemanticEngine = struct {
    allocator: std.mem.Allocator,
    words: std.StringHashMap(TritVec),
    dim: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dim: usize) Self {
        return Self{
            .allocator = allocator,
            .words = std.StringHashMap(TritVec).init(allocator),
            .dim = dim,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.words.valueIterator();
        while (iter.next()) |vec| {
            var v = vec.*;
            v.deinit();
        }
        self.words.deinit();
    }

    /// Load embeddings from file
    pub fn loadFromFile(self: *Self, path: []const u8, threshold: f32) !usize {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Error opening file {s}: {}\n", .{ path, err });
            return err;
        };
        defer file.close();

        // Read entire file into memory
        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch |err| {
            std.debug.print("Error reading file: {}\n", .{err});
            return err;
        };
        defer self.allocator.free(content);

        var count: usize = 0;
        var floats: [EMBEDDING_DIM]f32 = undefined;

        // Split by lines
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            // Skip comments and empty lines
            if (line.len == 0 or line[0] == '#') continue;

            // Parse: word f0 f1 f2 ... f49
            var iter = std.mem.splitScalar(u8, line, ' ');

            const word = iter.next() orelse continue;

            // Parse floats
            var dim_idx: usize = 0;
            while (iter.next()) |token| {
                if (dim_idx >= EMBEDDING_DIM) break;
                floats[dim_idx] = std.fmt.parseFloat(f32, token) catch continue;
                dim_idx += 1;
            }

            if (dim_idx < EMBEDDING_DIM) continue;

            // Quantize to ternary
            var vec = try TritVec.fromFloats(self.allocator, &floats, threshold);
            errdefer vec.deinit();

            // Store word (need to dupe the key)
            const word_key = try self.allocator.dupe(u8, word);
            try self.words.put(word_key, vec);
            count += 1;
        }

        return count;
    }

    /// Get vector for word
    pub fn getVec(self: *Self, word: []const u8) ?*TritVec {
        return self.words.getPtr(word);
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

    /// Word analogy: A is to B as C is to ?
    /// Formula: result = C + (B - A)
    /// Example: king - man + woman = queen
    pub fn analogy(self: *Self, a: []const u8, b: []const u8, c: []const u8) !WordResult {
        const va = self.getVec(a) orelse return error.WordNotFound;
        const vb = self.getVec(b) orelse return error.WordNotFound;
        const vc = self.getVec(c) orelse return error.WordNotFound;

        // Compute: result = B - A + C (standard analogy formula)
        var diff = try subVec(self.allocator, vb, va);
        defer diff.deinit();

        var result = try addVec(self.allocator, &diff, vc);
        defer result.deinit();

        // Find most similar, excluding input words
        const exclude = [_][]const u8{ a, b, c };
        return self.findMostSimilar(&result, &exclude);
    }

    /// Simple similarity between two words
    pub fn similarity(self: *Self, word1: []const u8, word2: []const u8) !f64 {
        const v1 = self.getVec(word1) orelse return error.WordNotFound;
        const v2 = self.getVec(word2) orelse return error.WordNotFound;
        return cosineSimilarity(v1, v2);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

fn benchmarkAnalogy(engine: *SemanticEngine, a: []const u8, b: []const u8, c: []const u8, expected: []const u8) !void {
    var timer = try std.time.Timer.start();

    const result = engine.analogy(a, b, c) catch |err| {
        std.debug.print("  {s} - {s} + {s} = ERROR: {}\n", .{ a, b, c, err });
        return;
    };

    const elapsed = timer.read();
    const elapsed_us = @as(f64, @floatFromInt(elapsed)) / 1000.0;

    const correct = std.mem.eql(u8, result.word, expected);
    const status = if (correct) "✓" else "✗";

    std.debug.print("  {s} - {s} + {s} = {s} (expected: {s}) {s} [sim={d:.3}, {d:.1}µs]\n", .{
        a,
        b,
        c,
        result.word,
        expected,
        status,
        result.similarity,
        elapsed_us,
    });
}

fn benchmarkSimilarity(engine: *SemanticEngine, word1: []const u8, word2: []const u8) !void {
    const sim = engine.similarity(word1, word2) catch |err| {
        std.debug.print("  sim({s}, {s}) = ERROR: {}\n", .{ word1, word2, err });
        return;
    };
    std.debug.print("  sim({s}, {s}) = {d:.3}\n", .{ word1, word2, sim });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use debug.print for Zig 0.15 compatibility
    const print = std.debug.print;

    print(
        \\╔══════════════════════════════════════════════════════════════╗
        \\║     IGLA SEMANTIC — PRE-TRAINED EMBEDDINGS → TERNARY        ║
        \\║     Word2Vec/GloVe → Ternary Quantization                   ║
        \\║     φ² + 1/φ² = 3 = TRINITY                                  ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
        \\
    , .{});

    // Initialize engine
    var engine = SemanticEngine.init(allocator, EMBEDDING_DIM);
    defer engine.deinit();

    // Load embeddings
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("     LOADING EMBEDDINGS                                        \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const embedding_path = "models/embeddings/semantic_core.txt";
    const threshold: f32 = 0.15; // Quantization threshold

    var timer = try std.time.Timer.start();
    const word_count = engine.loadFromFile(embedding_path, threshold) catch |err| {
        print("  ERROR loading embeddings: {}\n", .{err});
        print("  Make sure {s} exists\n", .{embedding_path});
        return;
    };
    const load_time = timer.read();

    print("  Loaded {d} words in {d:.2}ms\n", .{
        word_count,
        @as(f64, @floatFromInt(load_time)) / 1_000_000.0,
    });
    print("  Quantization threshold: {d:.2}\n", .{threshold});
    print("  Dimension: {d}\n\n", .{EMBEDDING_DIM});

    // Word similarities
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("     WORD SIMILARITIES                                         \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    try benchmarkSimilarity(&engine, "king", "queen");
    try benchmarkSimilarity(&engine, "king", "man");
    try benchmarkSimilarity(&engine, "man", "woman");
    try benchmarkSimilarity(&engine, "dog", "cat");
    try benchmarkSimilarity(&engine, "paris", "france");
    try benchmarkSimilarity(&engine, "berlin", "germany");
    try benchmarkSimilarity(&engine, "happy", "sad");
    try benchmarkSimilarity(&engine, "good", "bad");
    try benchmarkSimilarity(&engine, "king", "dog");
    try benchmarkSimilarity(&engine, "apple", "orange");

    // Word analogies
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("     WORD ANALOGIES (A - B + C = ?)                            \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    print("  Gender analogies:\n", .{});
    try benchmarkAnalogy(&engine, "man", "king", "woman", "queen");
    try benchmarkAnalogy(&engine, "man", "boy", "woman", "girl");
    try benchmarkAnalogy(&engine, "man", "prince", "woman", "princess");

    print("\n  Geography analogies:\n", .{});
    try benchmarkAnalogy(&engine, "france", "paris", "germany", "berlin");
    try benchmarkAnalogy(&engine, "france", "paris", "england", "london");

    print("\n  Animal analogies:\n", .{});
    try benchmarkAnalogy(&engine, "dog", "puppy", "cat", "kitten");

    print("\n  Opposite analogies:\n", .{});
    try benchmarkAnalogy(&engine, "good", "happy", "bad", "sad");

    // Performance benchmark
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("     PERFORMANCE BENCHMARK                                      \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const iterations: usize = 1000;
    timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        _ = engine.analogy("man", "king", "woman") catch continue;
    }

    const bench_time = timer.read();
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(bench_time)) / 1_000_000_000.0);

    print("  Iterations: {d}\n", .{iterations});
    print("  Total time: {d:.2}ms\n", .{@as(f64, @floatFromInt(bench_time)) / 1_000_000.0});
    print("  Speed: {d:.0} analogies/sec\n", .{ops_per_sec});

    // Summary
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("     SUMMARY                                                    \n", .{});
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    print("  Words loaded: {d}\n", .{word_count});
    print("  Embedding dimension: {d}\n", .{EMBEDDING_DIM});
    print("  Quantization: float → ternary {{-1, 0, +1}}\n", .{});
    print("  Performance: {d:.0} ops/s\n", .{ops_per_sec});

    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}
