//! tri/distance — String distance metrics
//! Auto-generated from specs/tri/tri_distance.tri
//! TTT Dogfood v0.2 Stage 130

const std = @import("std");

/// Distance metric type
pub const DistanceMetric = enum {
    Levenshtein,
    Hamming,
    Jaro,
    JaroWinkler,
};

/// Levenshtein edit distance
pub fn levenshtein(a: []const u8, b: []const u8) usize {
    const m = a.len;
    const n = b.len;

    if (m == 0) return n;
    if (n == 0) return m;

    var matrix: [101][101]usize = undefined;

    for (0..m + 1) |i| {
        matrix[i][0] = i;
    }
    for (0..n + 1) |j| {
        matrix[0][j] = j;
    }

    for (1..m + 1) |i| {
        for (1..n + 1) |j| {
            const cost: usize = if (a[i - 1] == b[j - 1]) 0 else 1;
            matrix[i][j] = @min(
                @min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
                matrix[i - 1][j - 1] + cost,
            );
        }
    }

    return matrix[m][n];
}

/// Hamming distance (requires equal length)
pub fn hamming(a: []const u8, b: []const u8) usize {
    if (a.len != b.len) return std.math.maxInt(usize);

    var count: usize = 0;
    for (a, b) |ca, cb| {
        if (ca != cb) count += 1;
    }
    return count;
}

/// Jaro similarity
pub fn jaro(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1;
    if (a.len == 0 or b.len == 0) return 0;

    const match_distance = @max(a.len, b.len) / 2 - 1;
    if (match_distance < 0) return 0;

    var a_matches = [1]bool{false} ** 100;
    var b_matches = [1]bool{false} ** 100;

    var matches: usize = 0;
    var transpositions: usize = 0;

    for (0..a.len) |i| {
        const start = if (i > match_distance) i - match_distance else 0;
        const end = @min(i + match_distance + 1, b.len);

        for (start..end) |j| {
            if (b_matches[j] or a[i] != b[j]) continue;
            a_matches[i] = true;
            b_matches[j] = true;
            matches += 1;
            break;
        }
    }

    if (matches == 0) return 0;

    var k: usize = 0;
    for (0..a.len) |i| {
        if (!a_matches[i]) continue;
        while (!b_matches[k]) k += 1;
        if (a[i] != b[k]) transpositions += 1;
        k += 1;
    }

    return (@as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(a.len)) +
        @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(b.len)) +
        @as(f64, @floatFromInt(matches - transpositions / 2)) / @as(f64, @floatFromInt(matches))) / 3;
}

/// Jaro-Winkler similarity
pub fn jaroWinkler(a: []const u8, b: []const u8) f64 {
    const j = jaro(a, b);

    var prefix: usize = 0;
    const max_prefix = @min(4, @min(a.len, b.len));

    for (0..max_prefix) |i| {
        if (a[i] == b[i]) prefix += 1 else break;
    }

    return j + @as(f64, @floatFromInt(prefix)) * 0.1 * (1 - j);
}

test "levenshtein" {
    try std.testing.expectEqual(@as(usize, 3), levenshtein("kitten", "sitting"));
    try std.testing.expectEqual(@as(usize, 0), levenshtein("same", "same"));
}

test "hamming" {
    try std.testing.expectEqual(@as(usize, 3), hamming("karolin", "kathrin"));
    try std.testing.expectEqual(@as(usize, 0), hamming("1010", "1010"));
}

test "jaro" {
    const sim = jaro("MARTHA", "MARHTA");
    try std.testing.expectApproxEqRel(@as(f64, 0.944), sim, 0.01);
}

test "jaro winkler" {
    const sim = jaroWinkler("MARTHA", "MARHTA");
    try std.testing.expectApproxEqRel(@as(f64, 0.961), sim, 0.01);
}
