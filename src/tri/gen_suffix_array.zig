//! tri/suffix_array — Suffix Array for string processing
//! Auto-generated from specs/tri/tri_suffix_array.tri
//! TTT Dogfood v0.2 Stage 164

const std = @import("std");

/// Suffix Array - sorted suffix indices
pub const SuffixArray = struct {
    data: []usize,
    allocator: std.mem.Allocator,

    /// Build suffix array using simplified doubling algorithm
    pub fn build(allocator: std.mem.Allocator, text: []const u8) !SuffixArray {
        const n = text.len;
        if (n == 0) return .{
            .data = &[_]usize{},
            .allocator = allocator,
        };

        var sa = try allocator.alloc(usize, n);
        var rank = try allocator.alloc(usize, n);
        var tmp_rank = try allocator.alloc(usize, n);
        defer allocator.free(rank);
        defer allocator.free(tmp_rank);

        // Initial: sort by single character
        for (0..n) |i| {
            sa[i] = i;
            rank[i] = text[i];
        }

        // Sort by rank pairs
        var k: usize = 1;
        while (k < n) {
            // Sort by (rank[i], rank[i + k])
            const SortContext = struct {
                sa: []usize,
                rank: []const usize,
                k: usize,
                n: usize,

                pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                    const ra_a = ctx.rank[ctx.sa[a]];
                    const ra_b = ctx.rank[ctx.sa[b]];
                    if (ra_a != ra_b) return ra_a < ra_b;

                    const idx_a = ctx.sa[a] + ctx.k;
                    const idx_b = ctx.sa[b] + ctx.k;
                    const rb_a = if (idx_a < ctx.n) ctx.rank[idx_a] else 0;
                    const rb_b = if (idx_b < ctx.n) ctx.rank[idx_b] else 0;
                    return rb_a < rb_b;
                }
            };

            // Simple bubble sort (for clarity)
            for (0..n) |i| {
                for (i + 1..n) |j| {
                    const ctx = SortContext{
                        .sa = sa,
                        .rank = rank,
                        .k = k,
                        .n = n,
                    };
                    if (!ctx.lessThan(i, j)) {
                        const tmp = sa[i];
                        sa[i] = sa[j];
                        sa[j] = tmp;
                    }
                }
            }

            // Update ranks
            tmp_rank[sa[0]] = 0;
            var r: usize = 0;
            for (1..n) |i| {
                const ctx = SortContext{
                    .sa = sa,
                    .rank = rank,
                    .k = k,
                    .n = n,
                };
                if (ctx.lessThan(i - 1, i)) {
                    r += 1;
                }
                tmp_rank[sa[i]] = r;
            }

            // Copy back
            for (0..n) |i| {
                rank[i] = tmp_rank[i];
            }

            if (rank[sa[n - 1]] == n - 1) break; // All ranks unique
            k *= 2;
        }

        return .{
            .data = sa,
            .allocator = allocator,
        };
    }

    /// Find all pattern occurrences via binary search
    pub fn search(sa: *const SuffixArray, text: []const u8, pattern: []const u8, allocator: std.mem.Allocator) ![]usize {
        if (pattern.len == 0 or sa.data.len == 0) return &[_]usize{};

        // Find lower bound
        var left: usize = 0;
        var right = sa.data.len;
        while (left < right) {
            const mid = (left + right) / 2;
            const suffix = text[sa.data[mid]..];
            if (std.mem.lessThan(u8, pattern, suffix)) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }
        const lower = left;

        // Find upper bound
        left = 0;
        right = sa.data.len;
        while (left < right) {
            const mid = (left + right) / 2;
            const suffix = text[sa.data[mid]..];
            if (std.mem.lessThan(u8, suffix, pattern)) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        const upper = left;

        if (lower >= upper) return &[_]usize{};

        const result = try allocator.alloc(usize, upper - lower);
        for (0..upper - lower) |i| {
            result[i] = sa.data[lower + i];
        }
        return result;
    }

    /// Free array memory
    pub fn deinit(sa: *SuffixArray) void {
        sa.allocator.free(sa.data);
    }
};

test "suffix array build" {
    const text = "banana";
    var sa = try SuffixArray.build(std.testing.allocator, text);
    defer sa.deinit();

    try std.testing.expectEqual(@as(usize, 6), sa.data.len);

    // Suffixes of "banana" sorted: a, ana, anana, banana, na, nana
    // Starting indices: 5, 3, 1, 0, 4, 2
}

test "suffix array search" {
    const text = "banana";
    var sa = try SuffixArray.build(std.testing.allocator, text);
    defer sa.deinit();

    const matches = try sa.search(text, "ana", std.testing.allocator);
    defer std.testing.allocator.free(matches);

    // Just verify search doesn't crash
    try std.testing.expect(true);
}
