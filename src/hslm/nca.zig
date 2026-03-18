// @origin(manual) @regen(pending)
// NCA — Neural Cellular Automata data generator for pre-pre-training
// Based on MIT paper arXiv 2603.10055: NCA pre-pre-training beats
// 1.6B language tokens with just 164M synthetic tokens.
//
// 9×9 toroidal grid = 81 cells = CONTEXT_LEN. Each CA timestep
// is one context window. Attention learns transferable long-range
// dependency tracking from spatiotemporal CA dynamics.
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const NcaConfig = struct {
    grid_size: u8 = 9, // 9×9 = 81 = CONTEXT_LEN
    num_states: u8 = 9, // K=9 states per cell
    rollout_steps: u16 = 128, // T timesteps per trajectory
    token_offset: u16 = 4, // skip PAD/BOS/EOS/UNK
    min_entropy: f32 = 1.5, // reject too-simple trajectories
    max_entropy: f32 = 2.8, // reject too-random (log2(9)=3.17)
    seed: u64 = 42,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NCA RULE — Totalistic 2D cellular automaton
// ═══════════════════════════════════════════════════════════════════════════════

pub const NcaRule = struct {
    /// Lookup: table[current_state][neighbor_sum_mod_K] → next_state
    table: [9][9]u8,

    pub fn generate(rng: std.Random) NcaRule {
        var rule: NcaRule = undefined;
        for (0..9) |s| {
            for (0..9) |n| {
                rule.table[s][n] = @intCast(rng.uintLessThan(u8, 9));
            }
        }
        return rule;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GRID — 9×9 toroidal cell array
// ═══════════════════════════════════════════════════════════════════════════════

pub const GRID_CELLS = 81; // 9×9

pub const Grid = struct {
    cells: [GRID_CELLS]u8,

    pub fn random(rng: std.Random, num_states: u8) Grid {
        var g: Grid = undefined;
        for (&g.cells) |*c| {
            c.* = @intCast(rng.uintLessThan(u8, num_states));
        }
        return g;
    }

    /// Flatten grid to tokens with offset (cell_state + token_offset)
    pub fn toTokens(self: *const Grid, offset: u16) [GRID_CELLS]u16 {
        var tokens: [GRID_CELLS]u16 = undefined;
        for (self.cells, 0..) |c, i| {
            tokens[i] = @as(u16, c) + offset;
        }
        return tokens;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STEP — One CA timestep with toroidal Moore neighborhood
// ═══════════════════════════════════════════════════════════════════════════════

/// Advance grid by one step using totalistic rule with toroidal boundary
pub fn stepGrid(grid: *const Grid, rule: *const NcaRule, size: u8) Grid {
    var next: Grid = undefined;
    const s: usize = size;

    for (0..s) |y| {
        for (0..s) |x| {
            const idx = y * s + x;
            const current = grid.cells[idx];

            // Moore neighborhood sum (8 neighbors, toroidal wrap)
            var sum: usize = 0;
            const deltas = [_]i8{ -1, 0, 1 };
            for (deltas) |dy| {
                for (deltas) |dx| {
                    if (dy == 0 and dx == 0) continue;
                    // Toroidal wrap: @mod handles negative correctly
                    const nx: usize = @intCast(@mod(@as(i16, @intCast(x)) + dx, @as(i16, @intCast(s))));
                    const ny: usize = @intCast(@mod(@as(i16, @intCast(y)) + dy, @as(i16, @intCast(s))));
                    sum += grid.cells[ny * s + nx];
                }
            }

            const neighbor_mod: u8 = @intCast(sum % s);
            next.cells[idx] = rule.table[current][neighbor_mod];
        }
    }
    return next;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLLOUT — Generate token sequence from one trajectory
// ═══════════════════════════════════════════════════════════════════════════════

/// Run NCA for T steps, return T*81 tokens
pub fn rollout(
    allocator: Allocator,
    rule: *const NcaRule,
    initial: *const Grid,
    config: NcaConfig,
) ![]u16 {
    const total = @as(usize, config.rollout_steps) * GRID_CELLS;
    var tokens = try allocator.alloc(u16, total);

    var grid = initial.*;
    for (0..config.rollout_steps) |t| {
        const frame = grid.toTokens(config.token_offset);
        const offset = t * GRID_CELLS;
        @memcpy(tokens[offset .. offset + GRID_CELLS], &frame);
        grid = stepGrid(&grid, rule, config.grid_size);
    }

    return tokens;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENTROPY FILTER
// ═══════════════════════════════════════════════════════════════════════════════

/// Shannon entropy of token sequence (in bits)
pub fn shannonEntropy(tokens: []const u16, num_states: u8) f32 {
    var counts = [_]u32{0} ** 16; // max 16 states
    for (tokens) |t| {
        if (t < 16) counts[t] += 1;
    }
    const n: f32 = @floatFromInt(tokens.len);
    var h: f32 = 0;
    for (0..num_states) |i| {
        if (counts[i] == 0) continue;
        const p: f32 = @as(f32, @floatFromInt(counts[i])) / n;
        h -= p * @log2(p);
    }
    return h;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATASET GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate NCA token dataset for pre-pre-training.
/// Produces at least `target_tokens` tokens, filtered by entropy.
pub fn generateNcaDataset(
    allocator: Allocator,
    config: NcaConfig,
    target_tokens: usize,
) !std.ArrayList(u16) {
    var result: std.ArrayList(u16) = .{};
    var prng = std.Random.DefaultPrng.init(config.seed);
    const rng = prng.random();

    var attempts: u32 = 0;
    const max_attempts: u32 = 100_000;

    while (result.items.len < target_tokens and attempts < max_attempts) {
        attempts += 1;

        // Generate random rule and initial grid
        const rule = NcaRule.generate(rng);
        const initial = Grid.random(rng, config.num_states);

        // Rollout
        const tokens = try rollout(allocator, &rule, &initial, config);
        defer allocator.free(tokens);

        // Entropy filter (on raw cell states, subtract offset)
        var raw = try allocator.alloc(u16, tokens.len);
        defer allocator.free(raw);
        for (tokens, 0..) |t, i| {
            raw[i] = t - config.token_offset;
        }
        const h = shannonEntropy(raw, config.num_states);

        if (h >= config.min_entropy and h <= config.max_entropy) {
            try result.appendSlice(allocator, tokens);
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "nca rule valid" {
    var prng = std.Random.DefaultPrng.init(42);
    const rule = NcaRule.generate(prng.random());
    for (0..9) |s| {
        for (0..9) |n| {
            try std.testing.expect(rule.table[s][n] < 9);
        }
    }
}

test "nca step deterministic" {
    var prng = std.Random.DefaultPrng.init(42);
    const rule = NcaRule.generate(prng.random());

    var prng2 = std.Random.DefaultPrng.init(99);
    const grid = Grid.random(prng2.random(), 9);

    const g1 = stepGrid(&grid, &rule, 9);
    const g2 = stepGrid(&grid, &rule, 9);

    for (g1.cells, g2.cells) |a, b| {
        try std.testing.expectEqual(a, b);
    }
}

test "nca rollout token count" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const rule = NcaRule.generate(prng.random());
    const grid = Grid.random(prng.random(), 9);

    const config = NcaConfig{ .rollout_steps = 128 };
    const tokens = try rollout(allocator, &rule, &grid, config);
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 128 * 81), tokens.len);
}

test "nca tokens in range" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const rule = NcaRule.generate(prng.random());
    const grid = Grid.random(prng.random(), 9);

    const config = NcaConfig{ .rollout_steps = 16 };
    const tokens = try rollout(allocator, &rule, &grid, config);
    defer allocator.free(tokens);

    for (tokens) |t| {
        try std.testing.expect(t >= 4 and t <= 12);
    }
}

test "nca entropy filter" {
    // All-same grid should have entropy = 0 → rejected
    var uniform = Grid{ .cells = [_]u8{3} ** GRID_CELLS };
    const uniform_tokens = uniform.toTokens(4);
    const h_uniform = shannonEntropy(&uniform_tokens, 9);
    try std.testing.expect(h_uniform < 1.5); // too simple

    // Well-distributed should pass
    var diverse = Grid{ .cells = undefined };
    for (0..GRID_CELLS) |i| {
        diverse.cells[i] = @intCast(i % 9);
    }
    const diverse_tokens = diverse.toTokens(4);
    const h_diverse = shannonEntropy(&diverse_tokens, 9);
    try std.testing.expect(h_diverse >= 1.5 and h_diverse <= 2.8);
}

test "nca dataset generates tokens" {
    const allocator = std.testing.allocator;
    const config = NcaConfig{ .rollout_steps = 32, .seed = 123 };
    var dataset = try generateNcaDataset(allocator, config, 5000);
    defer dataset.deinit(allocator);

    try std.testing.expect(dataset.items.len >= 5000);

    // All tokens in valid range
    for (dataset.items) |t| {
        try std.testing.expect(t >= 4 and t <= 12);
    }
}

test "nca toroidal boundary" {
    // Corner cell (0,0) should see 8 neighbors via wrap
    var grid = Grid{ .cells = [_]u8{0} ** GRID_CELLS };
    grid.cells[0] = 1; // (0,0) = 1
    grid.cells[80] = 2; // (8,8) = 2 — toroidal neighbor of (0,0)

    // Rule: state 0, any neighbor sum → 0; but the point is all 8 neighbors are accessed
    var rule: NcaRule = undefined;
    for (0..9) |s| {
        for (0..9) |n| {
            rule.table[s][n] = @intCast((s + n) % 9);
        }
    }

    const next = stepGrid(&grid, &rule, 9);
    // Cell (0,0) has state=1, neighbor sum includes cell(8,8)=2
    // If toroidal works, (0,0) sees (8,8) as neighbor
    // neighbor_sum for (0,0) = cell(8,0)+cell(8,1)+cell(1,0)+cell(1,1)+cell(0,1)+cell(0,8)+cell(8,8)+cell(1,8)
    //                        = 0+0+0+0+0+0+2+0 = 2
    // next[0] = table[1][2%9] = table[1][2] = (1+2)%9 = 3
    try std.testing.expectEqual(@as(u8, 3), next.cells[0]);
}
