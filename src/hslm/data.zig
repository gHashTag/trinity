// HSLM — Data Loading
// Text → token sequences → batches for training
// Supports raw text files and pre-tokenized data

const std = @import("std");
const constants = @import("constants.zig");
const tokenizer_mod = @import("tokenizer.zig");

const CONTEXT_LEN = constants.CONTEXT_LEN;
const VOCAB_SIZE = constants.VOCAB_SIZE;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA BATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub const Batch = struct {
    /// Input token sequences: batch_size × seq_len
    inputs: []u16,
    /// Target tokens (shifted by 1): batch_size × seq_len
    targets: []u16,
    batch_size: usize,
    seq_len: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, batch_size: usize, seq_len: usize) !Self {
        const total = batch_size * seq_len;
        return Self{
            .inputs = try allocator.alloc(u16, total),
            .targets = try allocator.alloc(u16, total),
            .batch_size = batch_size,
            .seq_len = seq_len,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.inputs);
        self.allocator.free(self.targets);
    }

    /// Get input sequence for batch index i
    pub fn getInput(self: *const Self, i: usize) []const u16 {
        const offset = i * self.seq_len;
        return self.inputs[offset .. offset + self.seq_len];
    }

    /// Get target sequence for batch index i
    pub fn getTarget(self: *const Self, i: usize) []const u16 {
        const offset = i * self.seq_len;
        return self.targets[offset .. offset + self.seq_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DATASET
// ═══════════════════════════════════════════════════════════════════════════════

pub const Dataset = struct {
    /// All tokens stored as a growable buffer
    tokens: std.ArrayList(u16),
    tokenizer: tokenizer_mod.Tokenizer,
    seq_len: usize,
    cursor: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, seq_len: usize) !Self {
        return Self{
            .tokens = .{},
            .tokenizer = try tokenizer_mod.Tokenizer.init(allocator),
            .seq_len = seq_len,
            .cursor = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
        self.tokenizer.deinit();
    }

    /// Add raw text to the dataset
    pub fn addText(self: *Self, text: []const u8) !void {
        var buf: [4096]u16 = undefined;
        var offset: usize = 0;

        while (offset < text.len) {
            const chunk_end = @min(offset + 2000, text.len);
            const chunk = text[offset..chunk_end];
            const n = self.tokenizer.encode(chunk, &buf);
            try self.tokens.appendSlice(self.allocator, buf[0..n]);
            offset = chunk_end;
        }
    }

    /// Add pre-tokenized data
    pub fn addTokens(self: *Self, tokens: []const u16) !void {
        try self.tokens.appendSlice(self.allocator, tokens);
    }

    /// Total number of tokens
    pub fn totalTokens(self: *const Self) usize {
        return self.tokens.items.len;
    }

    /// Number of complete sequences available
    pub fn numSequences(self: *const Self) usize {
        if (self.tokens.items.len < self.seq_len + 1) return 0;
        return self.tokens.items.len - self.seq_len;
    }

    /// Get next batch (cycling through data)
    pub fn nextBatch(self: *Self, batch: *Batch) void {
        const data = self.tokens.items;
        if (data.len < self.seq_len + 1) return;

        for (0..batch.batch_size) |b| {
            // Wrap cursor
            if (self.cursor + self.seq_len + 1 > data.len) {
                self.cursor = 0;
            }

            const b_offset = b * batch.seq_len;
            // Input: tokens[cursor..cursor+seq_len]
            // Target: tokens[cursor+1..cursor+seq_len+1] (shifted by 1)
            for (0..self.seq_len) |s| {
                batch.inputs[b_offset + s] = data[self.cursor + s];
                batch.targets[b_offset + s] = data[self.cursor + s + 1];
            }

            self.cursor += self.seq_len;
        }
    }

    /// Reset cursor to beginning
    pub fn reset(self: *Self) void {
        self.cursor = 0;
    }

    /// Shuffle data (Fisher-Yates on individual token level)
    pub fn shuffle(self: *Self, seed: u64) void {
        const data = self.tokens.items;
        const n = data.len;
        if (n < 2) return;

        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();

        var i = n - 1;
        while (i > 0) : (i -= 1) {
            const j = rng.intRangeAtMost(usize, 0, i);
            if (i != j) {
                const tmp = data[i];
                data[i] = data[j];
                data[j] = tmp;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "batch init/deinit" {
    const allocator = std.testing.allocator;
    var batch = try Batch.init(allocator, 4, 16);
    defer batch.deinit();

    try std.testing.expect(batch.inputs.len == 64);
    try std.testing.expect(batch.targets.len == 64);
}

test "dataset add text" {
    const allocator = std.testing.allocator;
    var ds = try Dataset.init(allocator, 16);
    defer ds.deinit();

    try ds.addText("Hello world. This is a test of the HSLM tokenizer.");
    try std.testing.expect(ds.totalTokens() > 0);
}

test "dataset next batch" {
    const allocator = std.testing.allocator;
    var ds = try Dataset.init(allocator, 8);
    defer ds.deinit();

    // Add enough text for at least one batch
    try ds.addText("The quick brown fox jumps over the lazy dog. ");
    try ds.addText("A second sentence for more data to fill the batch.");

    try std.testing.expect(ds.totalTokens() > 16);

    var batch = try Batch.init(allocator, 2, 8);
    defer batch.deinit();

    ds.nextBatch(&batch);

    // Targets should be inputs shifted by 1
    const input = batch.getInput(0);
    const target = batch.getTarget(0);
    try std.testing.expect(input.len == 8);
    try std.testing.expect(target.len == 8);

    // All tokens should be valid
    for (input) |t| {
        try std.testing.expect(t < VOCAB_SIZE);
    }
    for (target) |t| {
        try std.testing.expect(t < VOCAB_SIZE);
    }
}

test "dataset num sequences" {
    const allocator = std.testing.allocator;
    var ds = try Dataset.init(allocator, 4);
    defer ds.deinit();

    try ds.addTokens(&[_]u16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    // seq_len=4, need seq_len+1=5 tokens per sequence
    // 10 tokens → 10-4 = 6 sequences
    try std.testing.expect(ds.numSequences() == 6);
}
