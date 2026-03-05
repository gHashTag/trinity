// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA Simulation Framework — Mock FPGA Layer
// ═══════════════════════════════════════════════════════════════════════════════
//
// Software implementations matching FPGA behavior for testing
// without physical hardware.
//
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ============================================================================
// TRIT TYPE
// ============================================================================

pub const Trit = enum(i2) {
    negative = -1,
    zero = 0,
    positive = 1,

    pub fn format(self: Trit) []const u8 {
        return switch (self) {
            .negative => "-",
            .zero => "0",
            .positive => "+",
        };
    }
};

// ============================================================================
// VECTOR TYPES (matching FPGA dimensions)
// ============================================================================

pub const Vector16 = [16]Trit;
pub const Vector256 = [256]Trit;
pub const Vector10K = [10000]Trit;

// ============================================================================
// MOCK FPGA — VSA OPERATIONS
// ============================================================================

pub const MockFpga = struct {
    allocator: std.mem.Allocator,
    bind_count: u64 = 0,
    bundle_count: u64 = 0,
    similarity_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) MockFpga {
        return .{
            .allocator = allocator,
        };
    }

    // ========================================================================
    // VSA BIND — Association operation (hardware permutation)
    // ========================================================================

    pub fn vsaBind(self: *MockFpga, a: []const Trit, b: []const Trit) ![]Trit {
        std.debug.assert(a.len == b.len);
        self.bind_count += 1;

        const result = try self.allocator.alloc(Trit, a.len);
        for (0..a.len) |i| {
            // Hardware bind: trit multiplication with permutation
            result[i] = tritMul(a[i], b[i]);
        }
        return result;
    }

    // ========================================================================
    // VSA BUNDLE — Majority vote (fusion)
    // ========================================================================

    pub fn vsaBundle(self: *MockFpga, vectors: []const []const Trit) ![]Trit {
        if (vectors.len == 0) return error.EmptyBundle;
        const dim = vectors[0].len;
        self.bundle_count += 1;

        const result = try self.allocator.alloc(Trit, dim);
        for (0..dim) |i| {
            var pos_count: u32 = 0;
            var neg_count: u32 = 0;
            var zero_count: u32 = 0;

            for (vectors) |v| {
                switch (v[i]) {
                    .positive => pos_count += 1,
                    .negative => neg_count += 1,
                    .zero => zero_count += 1,
                }
            }

            // Majority vote
            result[i] = if (pos_count > neg_count and pos_count > zero_count)
                Trit.positive
            else if (neg_count > pos_count and neg_count > zero_count)
                Trit.negative
            else
                Trit.zero;
        }
        return result;
    }

    // ========================================================================
    // VSA BUNDLE2 — Two-vector bundle (optimized)
    // ========================================================================

    pub fn vsaBundle2(self: *MockFpga, a: []const Trit, b: []const Trit) ![]Trit {
        return self.vsaBundle(&[_][]const Trit{ a, b });
    }

    // ========================================================================
    // VSA SIMILARITY — Cosine similarity [-1, 1] scaled to [0, 255]
    // ========================================================================

    pub fn vsaSimilarity(self: *MockFpga, a: []const Trit, b: []const Trit) !u8 {
        std.debug.assert(a.len == b.len);
        self.similarity_count += 1;

        var dot: i32 = 0;
        var mag_a: i32 = 0;
        var mag_b: i32 = 0;

        for (0..a.len) |i| {
            const ai = @intFromEnum(a[i]);
            const bi = @intFromEnum(b[i]);
            dot += ai * bi;
            mag_a += ai * ai;
            mag_b += bi * bi;
        }

        if (mag_a == 0 or mag_b == 0) return 0;

        // Cosine similarity scaled to 0-255
        const cos_sim: f32 = @as(f32, @floatFromInt(dot)) /
            @sqrt(@as(f32, @floatFromInt(mag_a)) * @as(f32, @floatFromInt(mag_b)));

        // Map [-1, 1] to [0, 255]
        const scaled = ((cos_sim + 1.0) / 2.0) * 255.0;
        return @intFromFloat(scaled);
    }

    // ========================================================================
    // HAMMING DISTANCE — Count differing trits
    // ========================================================================

    pub fn hammingDistance(a: []const Trit, b: []const Trit) u32 {
        std.debug.assert(a.len == b.len);
        var count: u32 = 0;
        for (0..a.len) |i| {
            if (a[i] != b[i]) count += 1;
        }
        return count;
    }

    // ========================================================================
    // CYCLIC PERMUTE — Rotate vector (hardware permutation)
    // ========================================================================

    pub fn permute(vec: []const Trit, count: u32) []const Trit {
        const n = @as(usize, @intCast(count)) % vec.len;
        return vec[n..] ++ vec[0..n];
    }

    // ========================================================================
    // STATISTICS
    // ========================================================================

    pub fn getStats(self: *const MockFpga) Stats {
        return .{
            .bind_count = self.bind_count,
            .bundle_count = self.bundle_count,
            .similarity_count = self.similarity_count,
        };
    }

    pub const Stats = struct {
        bind_count: u64,
        bundle_count: u64,
        similarity_count: u64,
    };
};

// ============================================================================
// TRIT ARITHMETIC
// ============================================================================

fn tritMul(a: Trit, b: Trit) Trit {
    // Trit multiplication table
    //     × | -  0  +
    //    ---|---------
    //     - | +  0  -
    //     0 | 0  0  0
    //     + | -  0  +
    return switch (a) {
        .zero => .zero,
        .positive => b,
        .negative => switch (b) {
            .positive => .negative,
            .negative => .positive,
            .zero => .zero,
        },
    };
}

// ============================================================================
// TEST VECTOR GENERATORS
// ============================================================================

pub const TestVectors = struct {
    pub fn allOnes(comptime N: usize) [N]Trit {
        var result: [N]Trit = undefined;
        for (&result) |*t| t.* = .positive;
        return result;
    }

    pub fn allZeros(comptime N: usize) [N]Trit {
        var result: [N]Trit = undefined;
        for (&result) |*t| t.* = .zero;
        return result;
    }

    pub fn allNegatives(comptime N: usize) [N]Trit {
        var result: [N]Trit = undefined;
        for (&result) |*t| t.* = .negative;
        return result;
    }

    pub fn alternating(comptime N: usize) [N]Trit {
        var result: [N]Trit = undefined;
        for (0..N) |i| {
            result[i] = if (i % 2 == 0) .positive else .negative;
        }
        return result;
    }

    pub fn random(comptime N: usize) ![N]Trit {
        var result: [N]Trit = undefined;
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        for (&result) |*t| {
            const r = rng.random().uintAtMost(u8, 2);
            t.* = switch (r) {
                0 => .negative,
                1 => .zero,
                else => .positive,
            };
        }
        return result;
    }
};

// ============================================================================
// VECTOR FORMATTING
// ============================================================================

pub fn formatVector(vec: []const Trit, writer: anytype) !void {
    try writer.writeAll("[");
    for (vec, 0..) |t, i| {
        if (i > 0) try writer.writeAll(" ");
        try writer.writeAll(t.format());
        if (i >= 16) { // Show first 16 only
            try writer.writeAll("...");
            break;
        }
    }
    try writer.writeAll("]");
}

// ============================================================================
// SACRED CONSTANTS
// ============================================================================

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = PHI * PHI + 1.0 / (PHI * PHI); // = 3.0

comptime {
    if (GOLDEN_IDENTITY < 2.99 or GOLDEN_IDENTITY > 3.01) {
        @compileError("Golden Identity violated: φ² + 1/φ² != 3");
    }
}
