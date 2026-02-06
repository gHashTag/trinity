// ═══════════════════════════════════════════════════════════════════════════════
// IGLA BATCH OPTIMIZED v4.0 - Target 1000+ ops/s
// ═══════════════════════════════════════════════════════════════════════════════
//
// Key Optimization: Contiguous vocabulary matrix + batch SIMD
//
// Before: 553 ops/s (scattered memory, per-query iteration)
// Target: 1000+ ops/s (contiguous memory, batch processing)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const EMBEDDING_DIM: usize = 300;
pub const TOP_K: usize = 10;
pub const MAX_VOCAB: usize = 50_000;
pub const SIMD_WIDTH: usize = 16;

pub const Trit = i8;
pub const SimdVec = @Vector(SIMD_WIDTH, i8);
pub const SimdVecI32 = @Vector(SIMD_WIDTH, i32);

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH VOCABULARY STORE - Contiguous memory layout
// ═══════════════════════════════════════════════════════════════════════════════

pub const BatchVocabStore = struct {
    // Contiguous matrix: [vocab_size × EMBEDDING_DIM] stored row-major
    matrix: []align(64) Trit,  // 64-byte aligned for cache line
    norms: []f32,              // Precomputed norms
    words: [][]const u8,
    word_to_idx: std.StringHashMap(usize),
    count: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .matrix = try allocator.alignedAlloc(Trit, .@"64", MAX_VOCAB * EMBEDDING_DIM),
            .norms = try allocator.alloc(f32, MAX_VOCAB),
            .words = try allocator.alloc([]const u8, MAX_VOCAB),
            .word_to_idx = std.StringHashMap(usize).init(allocator),
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (0..self.count) |i| {
            self.allocator.free(self.words[i]);
        }
        self.allocator.free(self.matrix);
        self.allocator.free(self.norms);
        self.allocator.free(self.words);
        self.word_to_idx.deinit();
    }

    /// Get pointer to vector at index (zero-copy)
    pub fn getVectorPtr(self: *const Self, idx: usize) [*]const Trit {
        return self.matrix.ptr + idx * EMBEDDING_DIM;
    }

    /// Get word index
    pub fn getIdx(self: *const Self, word: []const u8) ?usize {
        return self.word_to_idx.get(word);
    }

    /// Add word with vector
    pub fn addWord(self: *Self, word: []const u8, data: []const Trit, norm: f32) !void {
        if (self.count >= MAX_VOCAB) return error.VocabFull;

        const idx = self.count;
        const offset = idx * EMBEDDING_DIM;

        // Copy vector data to contiguous matrix
        @memcpy(self.matrix[offset..][0..EMBEDDING_DIM], data);
        self.norms[idx] = norm;

        // Store word
        const word_copy = try self.allocator.dupe(u8, word);
        self.words[idx] = word_copy;
        try self.word_to_idx.put(word_copy, idx);

        self.count += 1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH SIMD DOT PRODUCT - Optimized for contiguous memory
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD dot product with prefetch hints
inline fn dotProductBatch(query: [*]const Trit, vocab_row: [*]const Trit) i32 {
    const chunks = EMBEDDING_DIM / SIMD_WIDTH;
    var total: i32 = 0;

    // Process 16 elements at a time
    comptime var i: usize = 0;
    inline while (i < chunks) : (i += 1) {
        const offset = i * SIMD_WIDTH;
        const va: SimdVec = query[offset..][0..SIMD_WIDTH].*;
        const vb: SimdVec = vocab_row[offset..][0..SIMD_WIDTH].*;
        const prod = va * vb;
        total += @reduce(.Add, @as(SimdVecI32, prod));
    }

    // Remainder (300 % 16 = 12)
    const remainder_start = chunks * SIMD_WIDTH;
    inline for (remainder_start..EMBEDDING_DIM) |j| {
        total += @as(i32, query[j]) * @as(i32, vocab_row[j]);
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-K HEAP
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimilarityResult = struct {
    word_idx: usize,
    similarity: f32,
};

pub const TopKHeap = struct {
    items: [TOP_K]SimilarityResult,
    count: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{ .items = undefined, .count = 0 };
    }

    pub fn getMin(self: *const Self) f32 {
        if (self.count < TOP_K) return -std.math.inf(f32);
        return self.items[0].similarity;
    }

    pub fn push(self: *Self, result: SimilarityResult) void {
        if (self.count < TOP_K) {
            self.items[self.count] = result;
            self.count += 1;
            self.heapifyUp(self.count - 1);
        } else if (result.similarity > self.items[0].similarity) {
            self.items[0] = result;
            self.heapifyDown(0);
        }
    }

    fn heapifyUp(self: *Self, idx: usize) void {
        var i = idx;
        while (i > 0) {
            const parent = (i - 1) / 2;
            if (self.items[i].similarity < self.items[parent].similarity) {
                const tmp = self.items[i];
                self.items[i] = self.items[parent];
                self.items[parent] = tmp;
                i = parent;
            } else break;
        }
    }

    fn heapifyDown(self: *Self, idx: usize) void {
        var i = idx;
        while (true) {
            var smallest = i;
            const left = 2 * i + 1;
            const right = 2 * i + 2;

            if (left < self.count and self.items[left].similarity < self.items[smallest].similarity) {
                smallest = left;
            }
            if (right < self.count and self.items[right].similarity < self.items[smallest].similarity) {
                smallest = right;
            }

            if (smallest != i) {
                const tmp = self.items[i];
                self.items[i] = self.items[smallest];
                self.items[smallest] = tmp;
                i = smallest;
            } else break;
        }
    }

    pub fn getSorted(self: *Self) []SimilarityResult {
        std.mem.sort(SimilarityResult, self.items[0..self.count], {}, struct {
            fn cmp(_: void, a: SimilarityResult, b: SimilarityResult) bool {
                return a.similarity > b.similarity;
            }
        }.cmp);
        return self.items[0..self.count];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH TOP-K SEARCH - Core optimization
// ═══════════════════════════════════════════════════════════════════════════════

/// Batch search with contiguous memory access
pub fn batchTopKSearch(
    vocab: *const BatchVocabStore,
    query: [*]const Trit,
    query_norm: f32,
    exclude_hashes: []const u64,
) TopKHeap {
    var heap = TopKHeap.init();

    const vocab_count = vocab.count;
    const matrix_ptr = vocab.matrix.ptr;
    const norms_ptr = vocab.norms.ptr;
    const words_ptr = vocab.words.ptr;

    // Process vocabulary in cache-friendly order
    var idx: usize = 0;
    while (idx < vocab_count) : (idx += 1) {
        // Fast exclusion check
        const word_hash = std.hash.Wyhash.hash(0, words_ptr[idx]);
        var excluded = false;
        for (exclude_hashes) |ex_hash| {
            if (word_hash == ex_hash) {
                excluded = true;
                break;
            }
        }
        if (excluded) continue;

        // Early termination with norm bound
        const vec_norm = norms_ptr[idx];
        if (heap.count >= TOP_K) {
            const max_possible = query_norm * vec_norm;
            if (max_possible <= heap.getMin()) continue;
        }

        // Batch SIMD dot product
        const vocab_row = matrix_ptr + idx * EMBEDDING_DIM;
        const dot = dotProductBatch(query, vocab_row);

        const denom = query_norm * vec_norm;
        const sim = if (denom < 0.0001) 0 else @as(f32, @floatFromInt(dot)) / denom;

        heap.push(.{ .word_idx = idx, .similarity = sim });
    }

    return heap;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALOGY ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const AnalogyResult = struct {
    answer: []const u8,
    similarity: f32,
};

/// Compute analogy with batch optimization
pub fn computeAnalogyBatch(
    vocab: *const BatchVocabStore,
    a: []const u8,
    b: []const u8,
    c: []const u8,
) ?AnalogyResult {
    const idx_a = vocab.getIdx(a) orelse return null;
    const idx_b = vocab.getIdx(b) orelse return null;
    const idx_c = vocab.getIdx(c) orelse return null;

    const vec_a = vocab.getVectorPtr(idx_a);
    const vec_b = vocab.getVectorPtr(idx_b);
    const vec_c = vocab.getVectorPtr(idx_c);

    // Compute query = b - a + c (stack allocated)
    var query: [EMBEDDING_DIM]Trit align(64) = undefined;
    var sum_sq: i32 = 0;

    for (0..EMBEDDING_DIM) |i| {
        const sum = @as(i32, vec_b[i]) - @as(i32, vec_a[i]) + @as(i32, vec_c[i]);
        if (sum > 0) {
            query[i] = 1;
            sum_sq += 1;
        } else if (sum < 0) {
            query[i] = -1;
            sum_sq += 1;
        } else {
            query[i] = 0;
        }
    }
    const query_norm = @sqrt(@as(f32, @floatFromInt(sum_sq)));

    // Exclude input words
    const exclude_hashes = [_]u64{
        std.hash.Wyhash.hash(0, a),
        std.hash.Wyhash.hash(0, b),
        std.hash.Wyhash.hash(0, c),
    };

    // Batch search
    var heap = batchTopKSearch(vocab, &query, query_norm, &exclude_hashes);
    const results = heap.getSorted();

    if (results.len == 0) return null;

    return AnalogyResult{
        .answer = vocab.words[results[0].word_idx],
        .similarity = results[0].similarity,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOVE LOADER - Batch optimized
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadGloVeBatch(allocator: std.mem.Allocator, path: []const u8, max_words: usize) !BatchVocabStore {
    var vocab = try BatchVocabStore.init(allocator);
    errdefer vocab.deinit();

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    defer allocator.free(content);
    _ = try file.readAll(content);

    var temp_data: [EMBEDDING_DIM]Trit = undefined;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var count: usize = 0;

    while (lines.next()) |line| {
        if (count >= max_words) break;
        if (line.len == 0) continue;

        var parts = std.mem.splitScalar(u8, line, ' ');
        const word = parts.next() orelse continue;

        var floats: [EMBEDDING_DIM]f32 = undefined;
        var dim: usize = 0;

        while (parts.next()) |val_str| {
            if (dim >= EMBEDDING_DIM) break;
            floats[dim] = std.fmt.parseFloat(f32, val_str) catch continue;
            dim += 1;
        }

        if (dim < EMBEDDING_DIM) continue;

        // Adaptive quantization
        var sum: f32 = 0;
        for (floats) |f| sum += @abs(f);
        const threshold = (sum / EMBEDDING_DIM) * 0.5;

        var sum_sq: i32 = 0;
        for (floats, 0..) |f, i| {
            if (f > threshold) {
                temp_data[i] = 1;
                sum_sq += 1;
            } else if (f < -threshold) {
                temp_data[i] = -1;
                sum_sq += 1;
            } else {
                temp_data[i] = 0;
            }
        }
        const norm = @sqrt(@as(f32, @floatFromInt(sum_sq)));

        try vocab.addWord(word, &temp_data, norm);
        count += 1;

        if (count % 10000 == 0) {
            std.debug.print("  Loaded {d} words...\n", .{count});
        }
    }

    return vocab;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

const AnalogyTest = struct {
    a: []const u8,
    b: []const u8,
    c: []const u8,
    expected: []const u8,
};

const TESTS = [_]AnalogyTest{
    .{ .a = "man", .b = "king", .c = "woman", .expected = "queen" },
    .{ .a = "man", .b = "boy", .c = "woman", .expected = "girl" },
    .{ .a = "brother", .b = "sister", .c = "father", .expected = "mother" },
    .{ .a = "he", .b = "she", .c = "his", .expected = "her" },
    .{ .a = "man", .b = "actor", .c = "woman", .expected = "actress" },
    .{ .a = "king", .b = "queen", .c = "prince", .expected = "princess" },
    .{ .a = "husband", .b = "wife", .c = "uncle", .expected = "aunt" },
    .{ .a = "france", .b = "paris", .c = "germany", .expected = "berlin" },
    .{ .a = "france", .b = "paris", .c = "italy", .expected = "rome" },
    .{ .a = "france", .b = "paris", .c = "japan", .expected = "tokyo" },
    .{ .a = "france", .b = "paris", .c = "england", .expected = "london" },
    .{ .a = "france", .b = "paris", .c = "russia", .expected = "moscow" },
    .{ .a = "france", .b = "paris", .c = "spain", .expected = "madrid" },
    .{ .a = "good", .b = "better", .c = "bad", .expected = "worse" },
    .{ .a = "good", .b = "best", .c = "bad", .expected = "worst" },
    .{ .a = "big", .b = "bigger", .c = "small", .expected = "smaller" },
    .{ .a = "slow", .b = "slower", .c = "fast", .expected = "faster" },
    .{ .a = "walk", .b = "walking", .c = "run", .expected = "running" },
    .{ .a = "go", .b = "went", .c = "come", .expected = "came" },
    .{ .a = "eat", .b = "ate", .c = "drink", .expected = "drank" },
    .{ .a = "cat", .b = "cats", .c = "dog", .expected = "dogs" },
    .{ .a = "child", .b = "children", .c = "man", .expected = "men" },
    .{ .a = "good", .b = "bad", .c = "happy", .expected = "sad" },
    .{ .a = "hot", .b = "cold", .c = "high", .expected = "low" },
    .{ .a = "quick", .b = "quicker", .c = "slow", .expected = "slower" },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("================================================================\n", .{});
    std.debug.print("   IGLA BATCH OPTIMIZED v4.0\n", .{});
    std.debug.print("   Target: 1000+ ops/s (Contiguous Memory + SIMD)\n", .{});
    std.debug.print("================================================================\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("  Loading GloVe (batch optimized)...\n", .{});

    var vocab = loadGloVeBatch(allocator, "models/embeddings/glove.6B.300d.txt", MAX_VOCAB) catch |err| {
        std.debug.print("  ERROR: {s}\n", .{@errorName(err)});
        return err;
    };
    defer vocab.deinit();

    std.debug.print("  Loaded {d} words (contiguous matrix: {d} MB)\n", .{
        vocab.count,
        vocab.count * EMBEDDING_DIM / 1024 / 1024,
    });
    std.debug.print("\n", .{});

    // Warmup
    _ = computeAnalogyBatch(&vocab, "man", "king", "woman");

    // Benchmark
    std.debug.print("================================================================\n", .{});
    std.debug.print("   BENCHMARK ({d} analogies)\n", .{TESTS.len});
    std.debug.print("================================================================\n", .{});

    var correct: usize = 0;
    const start_time = std.time.nanoTimestamp();

    for (TESTS) |t| {
        const result = computeAnalogyBatch(&vocab, t.a, t.b, t.c);
        if (result) |r| {
            const ok = std.mem.eql(u8, r.answer, t.expected);
            if (ok) {
                std.debug.print("  [OK] {s} - {s} + {s} = {s}\n", .{ t.a, t.b, t.c, r.answer });
                correct += 1;
            } else {
                std.debug.print("  [X ] {s} - {s} + {s} = {s} (exp: {s})\n", .{ t.a, t.b, t.c, r.answer, t.expected });
            }
        }
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = @as(u64, @intCast(end_time - start_time));
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(TESTS.len)) / (elapsed_ms / 1000.0);

    const accuracy = @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(TESTS.len)) * 100.0;

    std.debug.print("\n", .{});
    std.debug.print("================================================================\n", .{});
    std.debug.print("   RESULTS\n", .{});
    std.debug.print("================================================================\n", .{});
    std.debug.print("  Accuracy: {d}/{d} ({d:.1}%)\n", .{ correct, TESTS.len, accuracy });
    std.debug.print("  Time: {d:.2}ms\n", .{elapsed_ms});
    std.debug.print("  Speed: {d:.1} ops/s\n", .{ops_per_sec});
    std.debug.print("  Vocab: {d} words\n", .{vocab.count});
    std.debug.print("\n", .{});

    std.debug.print("================================================================\n", .{});
    std.debug.print("   VERDICT\n", .{});
    std.debug.print("================================================================\n", .{});

    if (ops_per_sec >= 1000.0 and accuracy >= 80.0) {
        std.debug.print("  STATUS: TARGET MET!\n", .{});
    } else {
        std.debug.print("  STATUS: BELOW TARGET\n", .{});
    }
    std.debug.print("  Speed: {d:.1} ops/s {s} 1000\n", .{ ops_per_sec, if (ops_per_sec >= 1000.0) ">=" else "<" });
    std.debug.print("  Accuracy: {d:.1}% {s} 80%\n", .{ accuracy, if (accuracy >= 80.0) ">=" else "<" });

    std.debug.print("\n", .{});
    std.debug.print("================================================================\n", .{});
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
    std.debug.print("================================================================\n", .{});
}
