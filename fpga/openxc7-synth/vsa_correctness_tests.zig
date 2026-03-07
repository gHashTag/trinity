//! ═══════════════════════════════════════════════════════════════════════════════
//! VSA CORRECTNESS TESTS — Vector Symbolic Architecture validation
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Comprehensive tests for VSA mathematical correctness:
//! - bundle2: Majority vote of 2 vectors
//! - bundle3: Majority vote of 3 vectors (3^3 = 27 truth table entries)
//! - bind: Ternary multiplication
//! - similarity: Cosine similarity bounds
//! - permutation: Cyclic shift properties
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("uart_protocol.zig");

const Trit = protocol.Trit;
const Vector16 = [16]Trit;

// ============================================================================
// TEST RESULTS
// ============================================================================

const TestResult = struct {
    name: []const u8,
    passed: bool,
    duration_ms: f64,
    details: []const u8,
};

/// Run all VSA correctness tests
pub fn runAll(allocator: std.mem.Allocator) ![]TestResult {
    std.debug.print("Running VSA Correctness Tests...\n", .{});

    var results = std.ArrayList(TestResult).init(allocator);

    // Bundle2: Majority vote of 2
    try testBundle2_Idempotent(&results);
    try testBundle2_ZeroPreserves(&results);
    try testBundle2_Consensus(&results);

    // Bundle3: Majority vote of 3 (27 truth table combinations)
    try testBundle3_AllZeros(&results);
    try testBundle3_AllPositives(&results);
    try testBundle3_AllNegatives(&results);
    try testBundle3_TwoPosOneZero(&results);
    try testBundle3_TwoNegOneZero(&results);
    try testBundle3_TwoPosOneNeg(&results);
    try testBundle3_ThreeWayTie(&results);
    try testBundle3_CompleteTruthTable(&results);

    // Bind: Ternary multiplication
    try testBind_Identity(&results);
    try testBind_ZeroAnnihilates(&results);
    try testBind_SelfInverse(&results);
    try testBind_Commutative(&results);

    // Similarity: Cosine similarity bounds
    try testSimilarity_IdenticalVectors(&results);
    try testSimilarity_OrthogonalVectors(&results);
    try testSimilarity_OppositeVectors(&results);
    try testSimilarity_ZeroVector(&results);

    // Permutation properties
    try testPermute_CyclicProperty(&results);
    try testPermute_Invertible(&results);

    return results.toOwnedSlice();
}

// ============================================================================
// VSA OPERATION HELPERS
// ============================================================================

/// Bundle 2 vectors (majority vote)
fn bundle2(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..16) |i| {
        const ta = a[i];
        const tb = b[i];

        result[i] = if (ta == .NEGATIVE and tb == .NEGATIVE)
            .NEGATIVE
        else if (ta == .POSITIVE and tb == .POSITIVE)
            .POSITIVE
        else if (ta == .ZERO)
            tb
        else if (tb == .ZERO)
            ta
        else
            .ZERO;
    }
    return result;
}

/// Bundle 3 vectors (majority vote) - CORRECT IMPLEMENTATION
fn bundle3(a: Vector16, b: Vector16, c: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..16) |i| {
        const ta = a[i];
        const tb = b[i];
        const tc = c[i];

        // Count votes for each trit value
        var pos_count: u2 = 0;
        var neg_count: u2 = 0;
        var zero_count: u2 = 0;

        if (ta == .POSITIVE) pos_count += 1 else if (ta == .NEGATIVE) neg_count += 1 else zero_count += 1;
        if (tb == .POSITIVE) pos_count += 1 else if (tb == .NEGATIVE) neg_count += 1 else zero_count += 1;
        if (tc == .POSITIVE) pos_count += 1 else if (tc == .NEGATIVE) neg_count += 1 else zero_count += 1;

        // Majority vote
        result[i] = if (pos_count >= 2)
            .POSITIVE
        else if (neg_count >= 2)
            .NEGATIVE
        else
            .ZERO;
    }
    return result;
}

/// Bind two vectors (ternary multiplication)
fn bind(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..16) |i| {
        const ta = a[i];
        const tb = b[i];

        result[i] = if (ta == .ZERO or tb == .ZERO)
            .ZERO
        else if (ta == tb)
            .POSITIVE
        else
            .NEGATIVE;
    }
    return result;
}

// ============================================================================
// BUNDLE2 TESTS
// ============================================================================

fn testBundle2_Idempotent(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = allOnes();
    const result = bundle2(vec, vec);

    // bundle2(all+, all+) = all+
    var passed = true;
    for (result) |t| {
        if (t != .POSITIVE) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle2_idempotent",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle2(all+, all+) should be all+",
    });
}

fn testBundle2_ZeroPreserves(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = randomVector();
    const zeros = allZeros();
    const result = bundle2(vec, zeros);

    // bundle2(x, 000...) = x
    const passed = std.mem.eql(Trit, &vec, &result);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle2_zero_preserves",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle2(x, 000...) should preserve x",
    });
}

fn testBundle2_Consensus(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const zeros = allZeros();
    const result = bundle2(ones, zeros);

    // bundle2(+++, 000) = 000 (disagreement -> zero)
    const passed = result[0] == .ZERO;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle2_consensus",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle2(+++, 000) should give zero",
    });
}

// ============================================================================
// BUNDLE3 TESTS
// ============================================================================

fn testBundle3_AllZeros(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const zeros = allZeros();
    const result = bundle3(zeros, zeros, zeros);

    var passed = true;
    for (result) |t| {
        if (t != .ZERO) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_all_zeros",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(000..., 000..., 000...) = 000...",
    });
}

fn testBundle3_AllPositives(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const result = bundle3(ones, ones, ones);

    var passed = true;
    for (result) |t| {
        if (t != .POSITIVE) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_all_positives",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(+++, +++, +++) = +++",
    });
}

fn testBundle3_AllNegatives(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const negs = allNegatives();
    const result = bundle3(negs, negs, negs);

    var passed = true;
    for (result) |t| {
        if (t != .NEGATIVE) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_all_negatives",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(---, ---, ---) = ---",
    });
}

fn testBundle3_TwoPosOneZero(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const zeros = allZeros();
    const result = bundle3(ones, ones, zeros);

    // ++, +, 0 -> ++ (2 positives win)
    var passed = true;
    for (result) |t| {
        if (t != .POSITIVE) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_two_pos_one_zero",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(+++, +++, 000) = +++ (majority)",
    });
}

fn testBundle3_TwoNegOneZero(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const negs = allNegatives();
    const zeros = allZeros();
    const result = bundle3(negs, negs, zeros);

    // --, -, 0 -> -- (2 negatives win)
    var passed = true;
    for (result) |t| {
        if (t != .NEGATIVE) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_two_neg_one_zero",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(---, ---, 000) = --- (majority)",
    });
}

fn testBundle3_TwoPosOneNeg(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const negs = allNegatives();
    const result = bundle3(ones, ones, negs);

    // ++, +, - -> 0 (1 pos, 1 neg, 1 zero implied)
    const passed = result[0] == .ZERO;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_two_pos_one_neg",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(+++, +++, ---) = 000 (no majority)",
    });
}

fn testBundle3_ThreeWayTie(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const negs = allNegatives();
    const zeros = allZeros();
    const result = bundle3(ones, negs, zeros);

    // +, -, 0 -> 0 (complete tie)
    const passed = result[0] == .ZERO;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_three_way_tie",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bundle3(+++, ---, 000) = 000 (tie)",
    });
}

/// Complete truth table test for bundle3 (3^3 = 27 combinations)
fn testBundle3_CompleteTruthTable(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const all_trits = [_]Trit{ .ZERO, .POSITIVE, .NEGATIVE };
    var passed: usize = 0;
    var total: usize = 0;

    // Test all 27 combinations
    for (all_trits) |ta| {
        for (all_trits) |tb| {
            for (all_trits) |tc| {
                total += 1;

                // Build single-trit vectors
                const vec_a = [_]Trit{ta} ** 16;
                const vec_b = [_]Trit{tb} ** 16;
                const vec_c = [_]Trit{tc} ** 16;

                const result = bundle3(vec_a, vec_b, vec_c);
                const expected = majorityVote3(ta, tb, tc);

                if (result[0] == expected) passed += 1;
            }
        }
    }

    _ = @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total));
    const all_passed = passed == total;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bundle3_complete_truth_table",
        .passed = all_passed,
        .duration_ms = duration_ms,
        .details = if (all_passed)
            "All 27 combinations passed"
        else
            "Some combinations failed",
    });
}

/// Majority vote of 3 trits
fn majorityVote3(a: Trit, b: Trit, c: Trit) Trit {
    // Count votes
    var pos: u2 = 0;
    var neg: u2 = 0;
    var zero: u2 = 0;

    if (a == .POSITIVE) pos += 1 else if (a == .NEGATIVE) neg += 1 else zero += 1;
    if (b == .POSITIVE) pos += 1 else if (b == .NEGATIVE) neg += 1 else zero += 1;
    if (c == .POSITIVE) pos += 1 else if (c == .NEGATIVE) neg += 1 else zero += 1;

    return if (pos >= 2) .POSITIVE else if (neg >= 2) .NEGATIVE else .ZERO;
}

// ============================================================================
// BIND TESTS
// ============================================================================

fn testBind_Identity(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = randomVector();
    const ones = allOnes();
    const result = bind(vec, ones);

    // bind(x, +++) = x (ones are multiplicative identity)
    const passed = std.mem.eql(Trit, &vec, &result);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bind_identity",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bind(x, +++) should preserve x",
    });
}

fn testBind_ZeroAnnihilates(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = randomVector();
    const zeros = allZeros();
    const result = bind(vec, zeros);

    // bind(x, 000...) = 000... (zero annihilates)
    var passed = true;
    for (result) |t| {
        if (t != .ZERO) passed = false;
    }

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bind_zero_annihilates",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bind(x, 000...) should be all zeros",
    });
}

fn testBind_SelfInverse(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = randomVector();
    const bound = bind(vec, vec);
    const unbound = bind(bound, vec);

    // bind(bind(x, x), x) = x (self-inverse property)
    const passed = std.mem.eql(Trit, &vec, &unbound);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bind_self_inverse",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bind(bind(x, x), x) should equal x",
    });
}

fn testBind_Commutative(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec_a = randomVector();
    const vec_b = randomVector();

    const ab = bind(vec_a, vec_b);
    const ba = bind(vec_b, vec_a);

    // bind(a, b) = bind(b, a)
    const passed = std.mem.eql(Trit, &ab, &ba);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_bind_commutative",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "bind(a, b) should equal bind(b, a)",
    });
}

// ============================================================================
// SIMILARITY TESTS
// ============================================================================

fn testSimilarity_IdenticalVectors(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = allOnes();
    // Simpler similarity: just count matching trits
    const score = tritMatchScore(vec, vec);

    const passed = score == 255; // Perfect match

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_similarity_identical",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "Identical vectors should have max similarity",
    });
}

fn testSimilarity_OrthogonalVectors(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const alt = alternatingVector();
    const score = tritMatchScore(ones, alt);

    // Should be less than perfect
    const passed = score < 255 and score > 0;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_similarity_orthogonal",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "Orthogonal vectors should have partial similarity",
    });
}

fn testSimilarity_OppositeVectors(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const ones = allOnes();
    const negs = allNegatives();
    const score = tritMatchScore(ones, negs);

    // Opposite vectors should have 0 similarity
    const passed = score == 0;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_similarity_opposite",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "Opposite vectors should have 0 similarity",
    });
}

fn testSimilarity_ZeroVector(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = allOnes();
    const zeros = allZeros();
    const score = tritMatchScore(vec, zeros);

    // Similarity with zero vector should be 0
    const passed = score == 0;

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_similarity_zero_vector",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "Similarity with zero vector should be 0",
    });
}

/// Simple trit match score (0-255)
fn tritMatchScore(a: Vector16, b: Vector16) u8 {
    var matches: usize = 0;
    for (0..16) |i| {
        if (a[i] == b[i]) matches += 1;
    }
    return @intCast((matches * 255) / 16);
}

// ============================================================================
// PERMUTATION TESTS
// ============================================================================

fn testPermute_CyclicProperty(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = randomVector();
    const perm1 = permute(vec, 1);
    const perm2 = permute(perm1, 1);
    const perm4 = permute(perm2, 2);

    // permute(permute(x, 1), 1) = permute(x, 2)
    const direct = permute(vec, 2);

    const passed = std.mem.eql(Trit, &perm2, &direct) and
        std.mem.eql(Trit, &perm4, &direct);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_permute_cyclic",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "Cyclic permutation property",
    });
}

fn testPermute_Invertible(results: *std.ArrayList(TestResult)) !void {
    const start = std.time.nanoTimestamp();

    const vec = randomVector();
    const perm = permute(vec, 5);
    const unperm = permute(perm, 11); // 16 - 5 = 11 (inverse)

    // permute(permute(x, k), 16-k) = x
    const passed = std.mem.eql(Trit, &vec, &unperm);

    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try results.append(.{
        .name = "vsa_permute_invertible",
        .passed = passed,
        .duration_ms = duration_ms,
        .details = "Permutation should be invertible",
    });
}

/// Cyclic permutation
fn permute(vec: Vector16, count: u4) Vector16 {
    var result: Vector16 = undefined;
    for (0..16) |i| {
        result[i] = vec[(i + 16 - @as(usize, @intCast(count))) % 16];
    }
    return result;
}

// ============================================================================
// VECTOR HELPERS
// ============================================================================

var prng = std.Random.DefaultPrng.init(12345);

fn randomVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..16) |i| {
        const r = prng.random().intRangeAtMost(u2, 0, 2);
        vec[i] = @enumFromInt(r);
    }
    return vec;
}

fn allOnes() Vector16 {
    var vec: Vector16 = undefined;
    for (0..16) |i| {
        vec[i] = .POSITIVE;
    }
    return vec;
}

fn allNegatives() Vector16 {
    var vec: Vector16 = undefined;
    for (0..16) |i| {
        vec[i] = .NEGATIVE;
    }
    return vec;
}

fn allZeros() Vector16 {
    var vec: Vector16 = undefined;
    for (0..16) |i| {
        vec[i] = .ZERO;
    }
    return vec;
}

fn alternatingVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..16) |i| {
        vec[i] = if (i % 2 == 0) .POSITIVE else .NEGATIVE;
    }
    return vec;
}

// ============================================================================
// SUMMARY
// ============================================================================

pub fn printSummary(results: []TestResult) void {
    std.debug.print("\n═══════════════════════════════════════\n", .{});
    std.debug.print("VSA Correctness Test Summary\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});

    var passed: usize = 0;
    var failed: usize = 0;
    var total_ms: f64 = 0.0;

    for (results) |tc| {
        const status = if (tc.passed) "✅" else "❌";
        std.debug.print("{s} {s}: {s}\n", .{ status, tc.name, tc.details });

        if (tc.passed) passed += 1 else failed += 1;
        total_ms += tc.duration_ms;
    }

    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Results: {d}/{d} passed ({d:.0}%)\n", .{
        passed, results.len, @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(results.len)) * 100.0
    });
    std.debug.print("Duration: {d:.2} ms\n", .{total_ms});

    if (failed == 0) {
        std.debug.print("✅ ALL VSA CORRECTNESS TESTS PASSED\n", .{});
    } else {
        std.debug.print("❌ {d} TESTS FAILED\n", .{failed});
    }
}
