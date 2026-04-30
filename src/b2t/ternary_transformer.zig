const std = @import("std");

pub const Trit = enum(i8) { P = 1, Z = 0, N = -1 };

pub const TernaryEmbedding = struct {
    weights: []Trit,
    vocab_size: usize,
    embed_dim: usize,

    pub fn init(allocator: std.mem.Allocator, vocab_size: usize, embed_dim: usize) !TernaryEmbedding {
        const weights = try allocator.alloc(Trit, vocab_size * embed_dim);
        @memset(weights, .Z);
        return .{
            .weights = weights,
            .vocab_size = vocab_size,
            .embed_dim = embed_dim,
        };
    }

    pub fn deinit(self: *TernaryEmbedding, allocator: std.mem.Allocator) void {
        allocator.free(self.weights);
    }

    pub fn lookup(self: *const TernaryEmbedding, token_id: usize) []const Trit {
        std.debug.assert(token_id < self.vocab_size);
        return self.weights[token_id * self.embed_dim ..][0..self.embed_dim];
    }

    pub fn encode(self: *const TernaryEmbedding, token_ids: []const usize, output: []f32) void {
        for (token_ids, 0..) |tid, seq_pos| {
            const emb = self.lookup(tid);
            for (emb, 0..) |trit, d| {
                const val: f32 = switch (trit) {
                    .P => 1.0,
                    .N => -1.0,
                    .Z => 0.0,
                };
                output[seq_pos * self.embed_dim + d] = val;
            }
        }
    }
};

pub const TernaryLinear = struct {
    weights: []Trit,
    in_dim: usize,
    out_dim: usize,

    pub fn init(allocator: std.mem.Allocator, in_dim: usize, out_dim: usize) !TernaryLinear {
        const weights = try allocator.alloc(Trit, in_dim * out_dim);
        @memset(weights, .Z);
        return .{
            .weights = weights,
            .in_dim = in_dim,
            .out_dim = out_dim,
        };
    }

    pub fn deinit(self: *TernaryLinear, allocator: std.mem.Allocator) void {
        allocator.free(self.weights);
    }

    pub fn forward(self: *const TernaryLinear, input: []const f32, output: []f32) void {
        std.debug.assert(input.len >= self.in_dim);
        std.debug.assert(output.len >= self.out_dim);

        for (0..self.out_dim) |o| {
            var sum: f32 = 0.0;
            for (0..self.in_dim) |i| {
                const w = self.weights[o * self.in_dim + i];
                switch (w) {
                    .P => sum += input[i],
                    .N => sum -= input[i],
                    .Z => {},
                }
            }
            output[o] = sum;
        }
    }

    pub fn forwardTernaryInput(self: *const TernaryLinear, input: []const Trit, output: []Trit) void {
        std.debug.assert(input.len >= self.in_dim);
        std.debug.assert(output.len >= self.out_dim);

        for (0..self.out_dim) |o| {
            var sum: i32 = 0;
            for (0..self.in_dim) |i| {
                const w: i32 = @intFromEnum(self.weights[o * self.in_dim + i]);
                const x: i32 = @intFromEnum(input[i]);
                sum += w * x;
            }
            output[o] = if (sum > 0) .P else if (sum < 0) .N else .Z;
        }
    }
};

pub const TernaryAttention = struct {
    q_proj: TernaryLinear,
    k_proj: TernaryLinear,
    v_proj: TernaryLinear,
    out_proj: TernaryLinear,
    num_heads: usize,
    head_dim: usize,

    pub fn init(allocator: std.mem.Allocator, embed_dim: usize, num_heads: usize) !TernaryAttention {
        const head_dim = embed_dim / num_heads;
        return .{
            .q_proj = try TernaryLinear.init(allocator, embed_dim, embed_dim),
            .k_proj = try TernaryLinear.init(allocator, embed_dim, embed_dim),
            .v_proj = try TernaryLinear.init(allocator, embed_dim, embed_dim),
            .out_proj = try TernaryLinear.init(allocator, embed_dim, embed_dim),
            .num_heads = num_heads,
            .head_dim = head_dim,
        };
    }

    pub fn deinit(self: *TernaryAttention, allocator: std.mem.Allocator) void {
        self.q_proj.deinit(allocator);
        self.k_proj.deinit(allocator);
        self.v_proj.deinit(allocator);
        self.out_proj.deinit(allocator);
    }

    pub fn forward(self: *TernaryAttention, input: []const f32, output: []f32, seq_len: usize, embed_dim: usize) void {
        const total = seq_len * embed_dim;

        var q_buf = std.mem.zeroes([256]f32);

        self.q_proj.forward(input, output);
        self.k_proj.forward(input, output);
        self.v_proj.forward(input, output);

        _ = q_buf;
        _ = total;
    }
};

pub const TernaryLayerNorm = struct {
    dim: usize,

    pub fn init(dim: usize) TernaryLayerNorm {
        return .{ .dim = dim };
    }

    pub fn forward(self: *const TernaryLayerNorm, input: []const f32, output: []f32) void {
        std.debug.assert(input.len >= self.dim);
        std.debug.assert(output.len >= self.dim);

        var mean: f32 = 0;
        for (input[0..self.dim]) |x| mean += x;
        mean /= @as(f32, @floatFromInt(self.dim));

        var var_sum: f32 = 0;
        for (input[0..self.dim]) |x| {
            const d = x - mean;
            var_sum += d * d;
        }
        const inv_std = 1.0 / @max(std.math.sqrt(var_sum / @as(f32, @floatFromInt(self.dim))), 1e-8);

        for (input[0..self.dim], output[0..self.dim]) |x, *o| {
            o.* = (x - mean) * inv_std;
        }
    }
};

pub const TernaryResidualNorm = struct {
    norm: TernaryLayerNorm,

    pub fn init(dim: usize) TernaryResidualNorm {
        return .{ .norm = TernaryLayerNorm.init(dim) };
    }

    pub fn forward(self: *TernaryResidualNorm, residual: []const f32, input: []const f32, output: []f32) void {
        self.norm.forward(input, output);
        for (residual[0..self.norm.dim], output[0..self.norm.dim]) |r, *o| {
            o.* += r;
        }
    }
};

pub const TernaryTransformerBlock = struct {
    pre_norm: TernaryResidualNorm,
    attn: TernaryAttention,
    post_norm: TernaryResidualNorm,
    ffn_up: TernaryLinear,
    ffn_down: TernaryLinear,
    dim: usize,

    pub fn init(allocator: std.mem.Allocator, dim: usize, num_heads: usize, ffn_dim: usize) !TernaryTransformerBlock {
        return .{
            .pre_norm = TernaryResidualNorm.init(dim),
            .attn = try TernaryAttention.init(allocator, dim, num_heads),
            .post_norm = TernaryResidualNorm.init(dim),
            .ffn_up = try TernaryLinear.init(allocator, dim, ffn_dim),
            .ffn_down = try TernaryLinear.init(allocator, ffn_dim, dim),
            .dim = dim,
        };
    }

    pub fn deinit(self: *TernaryTransformerBlock, allocator: std.mem.Allocator) void {
        self.attn.deinit(allocator);
        self.ffn_up.deinit(allocator);
        self.ffn_down.deinit(allocator);
    }
};

pub const TernaryTransformer = struct {
    allocator: std.mem.Allocator,
    embedding: TernaryEmbedding,
    blocks: std.ArrayList(TernaryTransformerBlock),
    final_norm: TernaryLayerNorm,
    lm_head: TernaryLinear,
    vocab_size: usize,
    embed_dim: usize,
    num_blocks: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        vocab_size: usize,
        embed_dim: usize,
        num_blocks: usize,
        num_heads: usize,
        ffn_dim: usize,
    ) !TernaryTransformer {
        return .{
            .allocator = allocator,
            .embedding = try TernaryEmbedding.init(allocator, vocab_size, embed_dim),
            .blocks = std.ArrayList(TernaryTransformerBlock).init(allocator),
            .final_norm = TernaryLayerNorm.init(embed_dim),
            .lm_head = try TernaryLinear.init(allocator, embed_dim, vocab_size),
            .vocab_size = vocab_size,
            .embed_dim = embed_dim,
            .num_blocks = num_blocks,
        };
    }

    pub fn deinit(self: *TernaryTransformer) void {
        self.embedding.deinit(self.allocator);
        for (self.blocks.items) |*b| b.deinit(self.allocator);
        self.blocks.deinit();
        self.lm_head.deinit(self.allocator);
    }

    pub fn addBlock(self: *TernaryTransformer, num_heads: usize, ffn_dim: usize) !void {
        const block = try TernaryTransformerBlock.init(self.allocator, self.embed_dim, num_heads, ffn_dim);
        try self.blocks.append(block);
    }

    pub fn totalParams(self: *const TernaryTransformer) usize {
        var count: usize = self.vocab_size * self.embed_dim;
        count += self.lm_head.in_dim * self.lm_head.out_dim;
        for (self.blocks.items) |b| {
            count += b.attn.q_proj.in_dim * b.attn.q_proj.out_dim * 4;
            count += b.ffn_up.in_dim * b.ffn_up.out_dim;
            count += b.ffn_down.in_dim * b.ffn_down.out_dim;
        }
        return count;
    }

    pub fn totalBits(self: *const TernaryTransformer) usize {
        return self.totalParams() * 2;
    }

    pub fn modelSizeBytes(self: *const TernaryTransformer) usize {
        return self.totalBits() / 8;
    }
};

test "ternary embedding lookup" {
    const allocator = std.testing.allocator;
    var emb = try TernaryEmbedding.init(allocator, 10, 4);
    defer emb.deinit(allocator);

    emb.weights[5 * 4 + 0] = .P;
    emb.weights[5 * 4 + 1] = .N;
    emb.weights[5 * 4 + 2] = .Z;
    emb.weights[5 * 4 + 3] = .P;

    const e = emb.lookup(5);
    try std.testing.expectEqual(Trit.P, e[0]);
    try std.testing.expectEqual(Trit.N, e[1]);
    try std.testing.expectEqual(Trit.Z, e[2]);
    try std.testing.expectEqual(Trit.P, e[3]);
}

test "ternary linear forward" {
    const allocator = std.testing.allocator;
    var linear = try TernaryLinear.init(allocator, 3, 2);
    defer linear.deinit(allocator);

    linear.weights[0] = .P;
    linear.weights[1] = .Z;
    linear.weights[2] = .N;
    linear.weights[3] = .N;
    linear.weights[4] = .P;
    linear.weights[5] = .Z;

    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;
    linear.forward(&input, &output);

    try std.testing.expectApproxEqAbs(@as(f32, -2.0), output[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), output[1], 1e-6);
}

test "ternary layer norm" {
    const norm = TernaryLayerNorm.init(4);
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;
    norm.forward(&input, &output);

    var sum: f32 = 0;
    for (output) |o| sum += o;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sum, 1e-5);
}

test "ternary transformer param count" {
    const allocator = std.testing.allocator;
    var model = try TernaryTransformer.init(allocator, 27, 9, 2, 3, 27);
    defer model.deinit();

    try model.addBlock(3, 27);

    const params = model.totalParams();
    try std.testing.expect(params > 0);

    const bytes = model.modelSizeBytes();
    try std.testing.expect(bytes > 0);
}

test "ternary embedding encode sequence" {
    const allocator = std.testing.allocator;
    var emb = try TernaryEmbedding.init(allocator, 10, 3);
    defer emb.deinit(allocator);

    emb.weights[1 * 3 + 0] = .P;
    emb.weights[1 * 3 + 1] = .P;
    emb.weights[1 * 3 + 2] = .P;
    emb.weights[2 * 3 + 0] = .N;
    emb.weights[2 * 3 + 1] = .N;
    emb.weights[2 * 3 + 2] = .N;

    const tokens = [_]usize{ 1, 2 };
    var output: [6]f32 = undefined;
    emb.encode(&tokens, &output);

    try std.testing.expectEqual(@as(f32, 1.0), output[0]);
    try std.testing.expectEqual(@as(f32, -1.0), output[3]);
}

test "ternary linear with ternary input" {
    const allocator = std.testing.allocator;
    var linear = try TernaryLinear.init(allocator, 3, 2);
    defer linear.deinit(allocator);

    linear.weights[0] = .P;
    linear.weights[1] = .P;
    linear.weights[2] = .P;
    linear.weights[3] = .N;
    linear.weights[4] = .Z;
    linear.weights[5] = .N;

    const input = [_]Trit{ .P, .N, .Z };
    var output: [2]Trit = undefined;
    linear.forwardTernaryInput(&input, &output);

    try std.testing.expectEqual(Trit.Z, output[0]);
    try std.testing.expectEqual(Trit.N, output[1]);
}
