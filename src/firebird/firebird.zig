// ═══════════════════════════════════════════════════════════════════════════════
// ЖАР ПТИЦА (FIREBIRD) - Ternary Virtual Anti-Detect Browser
// Integrated module with VSA operations for virtual space navigation
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const vsa = @import("vsa.zig");

// Re-export VSA types and operations
pub const TritVec = vsa.TritVec;
pub const SimilarityMetrics = vsa.SimilarityMetrics;
pub const Trit = vsa.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DIM: usize = vsa.DIM;
pub const PHI: f64 = vsa.PHI;
pub const PHI_INV: f64 = vsa.PHI_INV;
pub const TRINITY: f64 = vsa.TRINITY;

// Evolution parameters
pub const MU: f64 = 0.0382; // Mutation rate
pub const CHI: f64 = 0.0618; // Crossover rate (φ - 1)
pub const SIGMA: f64 = 1.618; // Selection pressure (φ)
pub const EPSILON: f64 = 0.333; // Elitism ratio (1/3 = ternary)

// φ-Spiral parameters
pub const SPIRAL_BASE_RADIUS: f64 = 30.0;
pub const SPIRAL_RADIUS_INCREMENT: f64 = 8.0;

// Similarity thresholds
pub const HUMAN_SIMILARITY_THRESHOLD: f64 = 0.7;
pub const EVASION_THRESHOLD: f64 = 0.5;

// Lucas number L(10) = 123
pub const LUCAS_10: u64 = 123;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// φ-spiral trajectory for evolution
pub const PhiSpiral = struct {
    angle: f64,
    radius: f64,
    iteration: u32,

    pub fn init(n: u32) PhiSpiral {
        const fi: f64 = @floatFromInt(n);
        return PhiSpiral{
            .angle = fi * PHI * math.pi,
            .radius = SPIRAL_BASE_RADIUS + fi * SPIRAL_RADIUS_INCREMENT,
            .iteration = n,
        };
    }

    pub fn next(self: *PhiSpiral) void {
        self.iteration += 1;
        const fi: f64 = @floatFromInt(self.iteration);
        self.angle = fi * PHI * math.pi;
        self.radius = SPIRAL_BASE_RADIUS + fi * SPIRAL_RADIUS_INCREMENT;
    }

    /// Get x, y coordinates on spiral
    pub fn getPosition(self: *const PhiSpiral) struct { x: f64, y: f64 } {
        return .{
            .x = self.radius * @cos(self.angle),
            .y = self.radius * @sin(self.angle),
        };
    }
};

/// State in virtual navigation space
pub const VirtualState = struct {
    allocator: std.mem.Allocator,
    position: TritVec,
    velocity: TritVec,
    fingerprint: TritVec,
    spiral: PhiSpiral,
    generation: u32,

    pub fn init(allocator: std.mem.Allocator, seed: u64) !VirtualState {
        return VirtualState{
            .allocator = allocator,
            .position = try TritVec.random(allocator, DIM, seed),
            .velocity = try TritVec.random(allocator, DIM, seed +% 1),
            .fingerprint = try TritVec.random(allocator, DIM, seed +% 2),
            .spiral = PhiSpiral.init(0),
            .generation = 0,
        };
    }

    pub fn deinit(self: *VirtualState) void {
        self.position.deinit();
        self.velocity.deinit();
        self.fingerprint.deinit();
    }
};

/// Navigation action in virtual space
pub const NavigationAction = struct {
    action_type: ActionType,
    target_vector: ?TritVec,
    confidence: f64,

    pub const ActionType = enum {
        move,
        click,
        scroll,
        wait,
        evolve,
    };
};

/// Evolution parameters for genetic algorithm
pub const EvolutionParams = struct {
    mutation_rate: f64 = MU,
    crossover_rate: f64 = CHI,
    selection_pressure: f64 = SIGMA,
    elitism_ratio: f64 = EPSILON,
};

// ═══════════════════════════════════════════════════════════════════════════════
// VIRTUAL SPACE INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize virtual space with random ternary vectors
pub fn initVirtualSpace(allocator: std.mem.Allocator, seed: u64) !VirtualState {
    return VirtualState.init(allocator, seed);
}

/// Initialize φ-spiral trajectory
pub fn initPhiSpiral(n: u32) PhiSpiral {
    return PhiSpiral.init(n);
}

/// Create random ternary vector
pub fn randomTritVector(allocator: std.mem.Allocator, seed: u64) !TritVec {
    return TritVec.random(allocator, DIM, seed);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPERATIONS (delegated to vsa.zig)
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind two vectors (element-wise multiplication)
pub fn bindVectors(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    return vsa.bind(allocator, a, b);
}

/// Bundle vectors (majority voting)
pub fn bundleVectors(allocator: std.mem.Allocator, vectors: []const *const TritVec) !TritVec {
    return vsa.bundleN(allocator, vectors);
}

/// Permute vector (cyclic shift)
pub fn permuteVector(allocator: std.mem.Allocator, v: *const TritVec, k: usize) !TritVec {
    return vsa.permute(allocator, v, k);
}

/// Compute cosine similarity
pub fn cosineSimilarity(a: *const TritVec, b: *const TritVec) f64 {
    return vsa.cosineSimilarity(a, b);
}

/// Compute Hamming distance
pub fn hammingDistance(a: *const TritVec, b: *const TritVec) usize {
    return vsa.hammingDistance(a, b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MUTATION OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Mutate vector with probability μ per trit
pub fn mutateVector(allocator: std.mem.Allocator, v: *const TritVec, mutation_rate: f64, seed: u64) !TritVec {
    const data = try allocator.alloc(Trit, v.len);
    @memcpy(data, v.data);

    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();

    for (data) |*trit| {
        if (rand.float(f64) < mutation_rate) {
            // Flip to random different value
            const current = trit.*;
            const r = rand.float(f32);
            if (current == 0) {
                trit.* = if (r < 0.5) -1 else 1;
            } else if (current == 1) {
                trit.* = if (r < 0.5) -1 else 0;
            } else {
                trit.* = if (r < 0.5) 0 else 1;
            }
        }
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = v.len,
    };
}

/// Crossover two vectors with rate χ
pub fn crossoverVectors(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec, crossover_rate: f64, seed: u64) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alloc(Trit, len);

    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();

    // Single-point crossover
    const crossover_point = rand.intRangeAtMost(usize, 0, len);
    var use_a = rand.float(f64) < 0.5;

    for (0..len) |i| {
        if (i == crossover_point and rand.float(f64) < crossover_rate) {
            use_a = !use_a;
        }
        data[i] = if (use_a) a.data[i] else b.data[i];
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = len,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTION OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Fitness function based on similarity to human pattern
pub fn computeFitness(v: *const TritVec, human_pattern: *const TritVec) f64 {
    const sim = vsa.cosineSimilarity(v, human_pattern);
    // Fitness is higher when similarity is close to HUMAN_SIMILARITY_THRESHOLD
    const diff = @abs(sim - HUMAN_SIMILARITY_THRESHOLD);
    return 1.0 - diff;
}

/// Select fittest vectors from population
pub fn selectFittest(
    allocator: std.mem.Allocator,
    population: []const *const TritVec,
    human_pattern: *const TritVec,
    selection_pressure: f64,
    count: usize,
) ![]TritVec {
    if (population.len == 0) return &[_]TritVec{};

    // Compute fitness for each
    const fitness = try allocator.alloc(f64, population.len);
    defer allocator.free(fitness);

    for (population, 0..) |v, i| {
        fitness[i] = computeFitness(v, human_pattern) * selection_pressure;
    }

    // Sort by fitness (descending)
    const indices = try allocator.alloc(usize, population.len);
    defer allocator.free(indices);
    for (0..population.len) |i| indices[i] = i;

    std.mem.sort(usize, indices, fitness, struct {
        fn lessThan(ctx: []f64, a: usize, b: usize) bool {
            return ctx[a] > ctx[b]; // Descending
        }
    }.lessThan);

    // Select top count
    const result_count = @min(count, population.len);
    const result = try allocator.alloc(TritVec, result_count);

    for (0..result_count) |i| {
        result[i] = try population[indices[i]].clone();
    }

    return result;
}

/// Apply elitism - preserve top ε fraction unchanged
pub fn applyElitism(
    allocator: std.mem.Allocator,
    population: []const *const TritVec,
    human_pattern: *const TritVec,
    elitism_ratio: f64,
) ![]TritVec {
    const elite_count = @max(1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(population.len)) * elitism_ratio)));
    return selectFittest(allocator, population, human_pattern, 1.0, elite_count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-SPIRAL EVOLUTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Evolve vector along φ-spiral trajectory
pub fn evolvePhiSpiral(
    allocator: std.mem.Allocator,
    v: *const TritVec,
    spiral: *PhiSpiral,
    seed: u64,
) !TritVec {
    // Get spiral position
    const pos = spiral.getPosition();

    // Use spiral position to influence mutation
    const mutation_rate = MU * (1.0 + @abs(@sin(pos.x / 100.0)));

    // Mutate vector
    const mutated = try mutateVector(allocator, v, mutation_rate, seed);

    // Advance spiral
    spiral.next();

    return mutated;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAVIGATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Navigate in virtual space by binding position with action
pub fn navigateVirtual(
    allocator: std.mem.Allocator,
    state: *VirtualState,
    action: *const TritVec,
) !void {
    // New position = bind(current_position, action)
    const new_position = try vsa.bind(allocator, &state.position, action);

    // Swap positions
    state.position.deinit();
    state.position = new_position;
}

/// Compute action vector for navigation
pub fn computeAction(
    allocator: std.mem.Allocator,
    current: *const TritVec,
    target: *const TritVec,
) !NavigationAction {
    // Action = bind(current, target) to get transformation
    const action_vec = try vsa.bind(allocator, current, target);

    const confidence = vsa.cosineSimilarity(current, target);

    return NavigationAction{
        .action_type = .move,
        .target_vector = action_vec,
        .confidence = confidence,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVASION
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if fingerprint is human-like
pub fn checkHumanSimilarity(fingerprint: *const TritVec, human_pattern: *const TritVec) bool {
    const sim = vsa.cosineSimilarity(fingerprint, human_pattern);
    return sim > HUMAN_SIMILARITY_THRESHOLD;
}

/// Evade detection by mutating fingerprint to maintain human-like similarity
pub fn evadeDetection(
    allocator: std.mem.Allocator,
    fingerprint: *const TritVec,
    human_pattern: *const TritVec,
    seed: u64,
) !TritVec {
    var current = try fingerprint.clone();
    var rng = std.Random.DefaultPrng.init(seed);

    // Iteratively mutate until human-like
    var iterations: u32 = 0;
    while (iterations < 100) : (iterations += 1) {
        const sim = vsa.cosineSimilarity(&current, human_pattern);

        if (sim > HUMAN_SIMILARITY_THRESHOLD) {
            return current;
        }

        // Mutate towards human pattern
        const mutated = try mutateVector(allocator, &current, MU * 2.0, rng.random().int(u64));
        current.deinit();
        current = mutated;
    }

    return current;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify Trinity identity: φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() bool {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const trinity = phi_sq + phi_inv_sq;
    return @abs(trinity - TRINITY) < 1e-10;
}

/// Compute V formula: V = n × 3^k × π^m × φ^p × e^q
pub fn computeVFormula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {
    return n * math.pow(f64, 3.0, k) * math.pow(f64, math.pi, m) * math.pow(f64, PHI, p) * math.pow(f64, math.e, q);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "init virtual space" {
    const allocator = std.testing.allocator;

    var state = try initVirtualSpace(allocator, 12345);
    defer state.deinit();

    try std.testing.expectEqual(DIM, state.position.len);
    try std.testing.expectEqual(DIM, state.fingerprint.len);
}

test "phi spiral trajectory" {
    var spiral = initPhiSpiral(0);

    const pos0 = spiral.getPosition();
    try std.testing.expectApproxEqAbs(SPIRAL_BASE_RADIUS, pos0.x, 0.01);

    spiral.next();
    _ = spiral.getPosition(); // Position changes after next()
    // After advancing, the spiral should have moved
    try std.testing.expect(spiral.radius > SPIRAL_BASE_RADIUS);
}

test "mutation changes vector" {
    const allocator = std.testing.allocator;

    var v = try randomTritVector(allocator, 11111);
    defer v.deinit();

    const mutated = try mutateVector(allocator, &v, 0.5, 22222);
    defer @constCast(&mutated).deinit();

    // Should be different
    const distance = hammingDistance(&v, &mutated);
    try std.testing.expect(distance > 0);
}

test "crossover combines parents" {
    const allocator = std.testing.allocator;

    var a = try randomTritVector(allocator, 33333);
    defer a.deinit();
    var b = try randomTritVector(allocator, 44444);
    defer b.deinit();

    const child = try crossoverVectors(allocator, &a, &b, 0.5, 55555);
    defer @constCast(&child).deinit();

    // Child should be somewhat similar to both parents
    const sim_a = cosineSimilarity(&child, &a);
    const sim_b = cosineSimilarity(&child, &b);

    try std.testing.expect(sim_a > 0.2 or sim_b > 0.2);
}

test "phi spiral evolution" {
    const allocator = std.testing.allocator;

    var v = try randomTritVector(allocator, 66666);
    defer v.deinit();

    var spiral = initPhiSpiral(0);

    const evolved = try evolvePhiSpiral(allocator, &v, &spiral, 77777);
    defer @constCast(&evolved).deinit();

    // Should be different after evolution
    const distance = hammingDistance(&v, &evolved);
    try std.testing.expect(distance > 0);

    // Spiral should have advanced
    try std.testing.expectEqual(@as(u32, 1), spiral.iteration);
}

test "navigate virtual space" {
    const allocator = std.testing.allocator;

    var state = try initVirtualSpace(allocator, 88888);
    defer state.deinit();

    const action = try randomTritVector(allocator, 99999);
    defer @constCast(&action).deinit();

    const old_pos = try state.position.clone();
    defer @constCast(&old_pos).deinit();

    try navigateVirtual(allocator, &state, &action);

    // Position should have changed
    const distance = hammingDistance(&old_pos, &state.position);
    try std.testing.expect(distance > 0);
}

test "verify trinity identity" {
    try std.testing.expect(verifyTrinityIdentity());
}

test "compute V formula" {
    // V = 30 × 3^1 × π^0 × φ^0 × e^0 = 90
    const v = computeVFormula(30, 1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(90.0, v, 0.01);
}
