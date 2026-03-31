// @origin(spec:data.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Data Loading with Curriculum Learning
// Text → token sequences → batches for training
// Supports raw text files, pre-tokenized data, and curriculum learning

const std = @import("std");
const constants = @import("constants.zig");
const tokenizer_mod = @import("tokenizer.zig");

const CONTEXT_LEN = constants.CONTEXT_LEN;
const VOCAB_SIZE = constants.VOCAB_SIZE;

// ═══════════════════════════════════════════════════════════════════════════════
// CURRICULUM LEARNING
// ═══════════════════════════════════════════════════════════════════════════════

/// Curriculum learning schedule
pub const CurriculumSchedule = enum {
    /// Linear progression: difficulty = current_step / total_steps
    linear,
    /// Exponential progression: difficulty = 1 - exp(-k * step)
    exponential,
    /// Step progression: difficulty increases at milestones
    step,
    /// Cosine annealing: smooth start and end
    cosine,
    /// No curriculum (standard training)
    none,
};

/// Curriculum learning configuration
pub const CurriculumConfig = struct {
    /// Schedule type
    schedule: CurriculumSchedule = .none,
    /// Total steps for full difficulty
    total_steps: u64 = 100_000,
    /// Minimum sequence length (start of curriculum)
    min_seq_len: usize = 8,
    /// Maximum sequence length (end of curriculum)
    max_seq_len: usize = CONTEXT_LEN,
    /// Number of difficulty milestones (for step schedule)
    num_milestones: usize = 10,
    /// Exponential growth rate (for exponential schedule)
    growth_rate: f32 = 5.0,

    pub fn init() CurriculumConfig {
        return CurriculumConfig{};
    }
};

/// Curriculum learning state
pub const Curriculum = struct {
    config: CurriculumConfig,
    current_step: u64 = 0,
    current_seq_len: usize = 8,
    difficulty: f32 = 0.0,

    const Self = @This();

    pub fn init(config: CurriculumConfig) Self {
        var self = Self{
            .config = config,
            .current_seq_len = config.min_seq_len,
        };
        self.updateDifficulty(0);
        return self;
    }

    /// Update difficulty based on current step
    pub fn updateDifficulty(self: *Self, step: u64) void {
        self.current_step = step;
        const progress = if (self.config.total_steps > 0)
            @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(self.config.total_steps))
        else
            1.0;

        self.difficulty = switch (self.config.schedule) {
            .none => 1.0,
            .linear => @min(1.0, progress),
            .exponential => 1.0 - @exp(-self.config.growth_rate * progress),
            .step => @floor(progress * @as(f32, @floatFromInt(self.config.num_milestones))) /
                @as(f32, @floatFromInt(self.config.num_milestones)),
            .cosine => (1.0 - @cos(progress * std.math.pi)) / 2.0,
        };

        // Clamp difficulty to [0, 1]
        self.difficulty = @max(0.0, @min(1.0, self.difficulty));

        // Update sequence length based on difficulty
        const seq_range = @as(f32, @floatFromInt(self.config.max_seq_len - self.config.min_seq_len));
        self.current_seq_len = self.config.min_seq_len +
            @as(usize, @intFromFloat(self.difficulty * seq_range));
    }

    /// Get current sequence length
    pub fn getSeqLen(self: *const Self) usize {
        return self.current_seq_len;
    }

    /// Check if curriculum is complete
    pub fn isComplete(self: *const Self) bool {
        return self.difficulty >= 0.99 or self.current_step >= self.config.total_steps;
    }
};

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
        const inputs = try allocator.alloc(u16, total);
        errdefer allocator.free(inputs);
        const targets = try allocator.alloc(u16, total);
        return Self{
            .inputs = inputs,
            .targets = targets,
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
// DATASET WITH CURRICULUM LEARNING
// ═══════════════════════════════════════════════════════════════════════════════

/// Data item with metadata for curriculum sorting
const DataItem = struct {
    tokens: []u16,
    complexity: f32 = 0.0,
    seq_len: usize = 0,
};

pub const Dataset = struct {
    /// All tokens stored as a growable buffer
    tokens: std.ArrayList(u16),
    tokenizer: tokenizer_mod.Tokenizer,
    seq_len: usize,
    cursor: usize,
    allocator: std.mem.Allocator,
    /// Curriculum learning state
    curriculum: Curriculum = Curriculum.init(CurriculumConfig.init()),
    /// Data items for curriculum sorting
    items: std.ArrayList(DataItem),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, seq_len: usize) !Self {
        return Self{
            .tokens = .{},
            .tokenizer = try tokenizer_mod.Tokenizer.init(allocator),
            .seq_len = seq_len,
            .cursor = 0,
            .allocator = allocator,
            .items = std.ArrayList(DataItem).empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit(self.allocator);
        self.tokenizer.deinit();
        // Free item tokens
        for (self.items.items) |*item| {
            self.allocator.free(item.tokens);
        }
        self.items.deinit(self.allocator);
    }

    /// Enable curriculum learning with config
    pub fn enableCurriculum(self: *Self, config: CurriculumConfig) void {
        self.curriculum = Curriculum.init(config);
    }

    /// Get current sequence length from curriculum
    pub fn getCurrentSeqLen(self: *const Self) usize {
        if (self.curriculum.config.schedule == .none) {
            return self.seq_len;
        }
        return self.curriculum.getSeqLen();
    }

    /// Update curriculum for current step
    pub fn updateCurriculum(self: *Self, step: u64) void {
        self.curriculum.updateDifficulty(step);
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
        const current_len = self.getCurrentSeqLen();
        if (self.tokens.items.len < current_len + 1) return 0;
        return self.tokens.items.len - current_len;
    }

    /// Get next batch (cycling through data)
    pub fn nextBatch(self: *Self, batch: *Batch) void {
        const data = self.tokens.items;
        const current_len = self.getCurrentSeqLen();
        if (data.len < current_len + 1) return;

        for (0..batch.batch_size) |b| {
            // Wrap cursor
            if (self.cursor + current_len + 1 > data.len) {
                self.cursor = 0;
            }

            const b_offset = b * batch.seq_len;
            // Input: tokens[cursor..cursor+seq_len]
            // Target: tokens[cursor+1..cursor+seq_len+1] (shifted by 1)
            for (0..current_len) |s| {
                batch.inputs[b_offset + s] = data[self.cursor + s];
                batch.targets[b_offset + s] = data[self.cursor + s + 1];
            }

            // Pad if current_seq_len < batch.seq_len
            for (current_len..batch.seq_len) |s| {
                batch.inputs[b_offset + s] = 0; // PAD token
                batch.targets[b_offset + s] = 0;
            }

            self.cursor += current_len;
        }
    }

    /// Reset cursor to beginning
    pub fn reset(self: *Self) void {
        self.cursor = 0;
    }

    /// Load text file with shard offset: skip first skip_lines, then load max_lines.
    /// Used for data sharding across multiple training services.
    pub fn loadTextFileShard(self: *Self, path: []const u8, skip_lines: usize, max_lines: usize) !usize {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const reader = file.deprecatedReader();
        var line_buf: [8192]u8 = undefined;

        // Skip to shard start
        var skipped: usize = 0;
        while (skipped < skip_lines) {
            _ = reader.readUntilDelimiterOrEof(&line_buf, '\n') catch break orelse break;
            skipped += 1;
        }

        // Load shard data
        var lines_loaded: usize = 0;
        while (lines_loaded < max_lines) {
            const maybe_line = reader.readUntilDelimiterOrEof(&line_buf, '\n') catch break;
            const line = maybe_line orelse break;
            if (line.len > 10) {
                try self.addText(line);
                lines_loaded += 1;
            }
        }
        return lines_loaded;
    }

    /// Split dataset into train and validation sets.
    /// Keeps first train_ratio of tokens in self, returns rest as new Dataset.
    pub fn splitTrainVal(self: *Self, train_ratio: f32) !Self {
        const total = self.tokens.items.len;
        const train_end = @as(usize, @intFromFloat(@as(f32, @floatFromInt(total)) * train_ratio));

        var val = try Self.init(self.allocator, self.seq_len);
        try val.tokens.appendSlice(val.allocator, self.tokens.items[train_end..]);

        self.tokens.shrinkRetainingCapacity(train_end);
        self.cursor = 0;

        return val;
    }

    /// Load text from a file on disk (one story per line)
    pub fn loadTextFile(self: *Self, path: []const u8, max_lines: usize) !usize {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const reader = file.deprecatedReader();

        var line_buf: [8192]u8 = undefined;
        var lines_loaded: usize = 0;

        while (lines_loaded < max_lines) {
            const maybe_line = reader.readUntilDelimiterOrEof(&line_buf, '\n') catch break;
            const line = maybe_line orelse break;
            if (line.len > 10) { // Skip very short lines
                try self.addText(line);
                lines_loaded += 1;
            }
        }

        return lines_loaded;
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

    /// Sort data by complexity for curriculum learning
    /// Complexity = sequence length + token diversity
    pub fn sortByComplexity(self: *Self) !void {
        if (self.items.items.len == 0) {
            // Build items from tokens
            const seq_len = self.getCurrentSeqLen();
            var i: usize = 0;
            while (i + seq_len < self.tokens.items.len) : (i += 1) {
                const tokens = try self.allocator.dupe(u16, self.tokens.items[i .. i + seq_len]);
                const complexity = self.computeComplexity(tokens);
                try self.items.append(self.allocator, .{
                    .tokens = tokens,
                    .complexity = complexity,
                    .seq_len = seq_len,
                });
            }
        }

        // Sort by complexity (simplest first)
        const context = struct {
            fn lessThan(_: void, a: DataItem, b: DataItem) bool {
                return a.complexity < b.complexity;
            }
        };
        std.sort.insertion(DataItem, self.items.items, {}, context.lessThan);

        // Rebuild tokens from sorted items
        self.tokens.clearRetainingCapacity();
        for (self.items.items) |item| {
            try self.tokens.appendSlice(self.allocator, item.tokens);
        }
    }

    /// Compute complexity score for a sequence
    fn computeComplexity(self: *const Self, tokens: []const u16) f32 {
        if (tokens.len == 0) return 0.0;

        // Complexity factors:
        // 1. Length (longer = more complex)
        // 2. Token diversity (unique tokens / total tokens)
        // 3. Rare token count

        var unique_count: usize = 0;
        var seen = std.AutoHashMap(u16, void).init(self.allocator);
        defer seen.deinit();

        for (tokens) |tok| {
            if (!seen.contains(tok)) {
                try seen.put(tok, {});
                unique_count += 1;
            }
        }

        const diversity = @as(f32, @floatFromInt(unique_count)) / @as(f32, @floatFromInt(tokens.len));
        const length_factor = @as(f32, @floatFromInt(tokens.len)) / CONTEXT_LEN;

        return length_factor * 0.5 + diversity * 0.5;
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

test "curriculum linear schedule" {
    const config = CurriculumConfig{
        .schedule = .linear,
        .total_steps = 1000,
        .min_seq_len = 8,
        .max_seq_len = 32,
    };
    var curriculum = Curriculum.init(config);

    // At step 0, should be at min
    try std.testing.expectEqual(@as(usize, 8), curriculum.getSeqLen());

    // At step 500, should be halfway
    curriculum.updateDifficulty(500);
    try std.testing.expectEqual(@as(usize, 20), curriculum.getSeqLen());

    // At step 1000, should be at max
    curriculum.updateDifficulty(1000);
    try std.testing.expectEqual(@as(usize, 32), curriculum.getSeqLen());
}

test "curriculum exponential schedule" {
    const config = CurriculumConfig{
        .schedule = .exponential,
        .total_steps = 1000,
        .min_seq_len = 8,
        .max_seq_len = 32,
        .growth_rate = 5.0,
    };
    var curriculum = Curriculum.init(config);

    curriculum.updateDifficulty(0);
    try std.testing.expectEqual(@as(usize, 8), curriculum.getSeqLen());

    // Exponential should grow faster initially
    curriculum.updateDifficulty(200);
    const seq_len_200 = curriculum.getSeqLen();
    try std.testing.expect(seq_len_200 > 8);
}

test "curriculum step schedule" {
    const config = CurriculumConfig{
        .schedule = .step,
        .total_steps = 1000,
        .min_seq_len = 8,
        .max_seq_len = 32,
        .num_milestones = 4,
    };
    var curriculum = Curriculum.init(config);

    // At step 0, should be at min
    curriculum.updateDifficulty(0);
    try std.testing.expectEqual(@as(usize, 8), curriculum.getSeqLen());

    // At step 250 (1/4 through first milestone), still at min
    curriculum.updateDifficulty(249);
    try std.testing.expectEqual(@as(usize, 8), curriculum.getSeqLen());

    // At step 250 (first milestone), should jump to 14 (8 + 6)
    curriculum.updateDifficulty(250);
    try std.testing.expectEqual(@as(usize, 14), curriculum.getSeqLen());
}

test "dataset with curriculum" {
    const allocator = std.testing.allocator;
    var ds = try Dataset.init(allocator, 32);
    defer ds.deinit();

    const config = CurriculumConfig{
        .schedule = .linear,
        .total_steps = 100,
        .min_seq_len = 8,
        .max_seq_len = 32,
    };
    ds.enableCurriculum(config);

    // At step 0, seq len should be 8
    ds.updateCurriculum(0);
    try std.testing.expectEqual(@as(usize, 8), ds.getCurrentSeqLen());

    // At step 50, seq len should be 20
    ds.updateCurriculum(50);
    try std.testing.expectEqual(@as(usize, 20), ds.getCurrentSeqLen());
}

test "curriculum cosine schedule" {
    const config = CurriculumConfig{
        .schedule = .cosine,
        .total_steps = 1000,
        .min_seq_len = 8,
        .max_seq_len = 32,
    };
    var curriculum = Curriculum.init(config);

    // Cosine starts slow, speeds up in middle, slows at end
    curriculum.updateDifficulty(0);
    try std.testing.expectEqual(@as(usize, 8), curriculum.getSeqLen());

    curriculum.updateDifficulty(500);
    const mid_seq_len = curriculum.getSeqLen();
    try std.testing.expect(mid_seq_len > 8 and mid_seq_len < 32);
}

// φ² + 1/φ² = 3 | TRINITY
