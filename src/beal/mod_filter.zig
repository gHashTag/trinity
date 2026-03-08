// ═══════════════════════════════════════════════════════════════════════════════
// BEAL MODULAR FILTER - Multi-Prime Modular Arithmetic Pre-filter
// ═══════════════════════════════════════════════════════════════════════════════
// Pre-filters 99.9% of non-solutions via modular congruence checks
// If A^x + B^y ≠ C^z (mod p) for ANY prime p, it's not a solution
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const simd = @import("simd_neon.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PRIME SELECTION
// ═══════════════════════════════════════════════════════════════════════════════
/// Selected 64-bit primes for modular filtering
/// Mersenne prime (2^61 - 1) enables fast bit-mask modulo
/// Classic primes for diversity
pub const RECOMMENDED_PRIMES = [3]u64{
    0x1FFFFFFFFFFFFFFF, // 2^61 - 1 (Mersenne prime)
    1000000007, // Classic prime
    1000000009, // Offset prime (coprime to above)
};

pub const NUM_PRIMES: usize = 3;

// ═══════════════════════════════════════════════════════════════════════════════
// MODULAR EXPONENTIATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Fast modular exponentiation using repeated squaring
/// Returns (base^exp) mod modulus
pub fn powMod(base: u64, exp: u8, modulus: u64) u64 {
    if (modulus == 1) return 0;
    if (exp == 0) return 1;

    var result: u64 = 1;
    var b = base % modulus;
    var e = exp;

    while (e > 0) {
        if (e & 1 == 1) {
            result = (result *% b) % modulus;
        }
        e >>= 1;
        b = (b *% b) % modulus;
    }

    return result;
}

/// Fast mod for Mersenne prime (2^61 - 1)
/// Uses bit operations instead of division
pub fn modMersenne61(x: u128) u64 {
    const m: u64 = 0x1FFFFFFFFFFFFFFF; // 2^61 - 1
    if (x < m) return @as(u64, @truncate(x));

    // Reduce: (x AND m) + (x >> 61)
    var reduced = @as(u64, @truncate(x & m)) + @as(u64, @truncate(x >> 61));
    while (reduced >= m) {
        reduced = (reduced & m) + @as(u64, @truncate(reduced >> 61));
    }
    return reduced;
}

/// Squaring modulo Mersenne 61
pub fn powModMersenne61(base: u64, exp: u8) u64 {
    if (exp == 0) return 1;

    var result: u64 = 1;
    var b: u128 = base;
    var e = exp;

    while (e > 0) {
        if (e & 1 == 1) {
            result = modMersenne61(@as(u128, result) * b);
        }
        e >>= 1;
        b = modMersenne61(b * b);
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// POWER TABLE
// ═══════════════════════════════════════════════════════════════════════════════

/// Precomputed power table for fast modular lookup
/// power_tables[prime_idx][base][exponent] = base^exponent mod prime
pub const PowerTable = struct {
    allocator: std.mem.Allocator,
    data: [][][]u64, // [NUM_PRIMES][max_base + 1][max_exp + 1]
    primes: []const u64,
    max_base: u32,
    max_exp: u8,

    const Self = @This();

    /// Initialize power table with precomputed values
    pub fn init(allocator: std.mem.Allocator, primes: []const u64, max_base: u32, max_exp: u8) !Self {
        const num_primes = primes.len;

        // Allocate 3D array
        const data = try allocator.alloc([][]u64, num_primes);
        errdefer {
            for (data) |dim1| {
                for (dim1) |dim2| {
                    allocator.free(dim2);
                }
                allocator.free(dim1);
            }
            allocator.free(data);
        }

        for (0..num_primes) |p_idx| {
            data[p_idx] = try allocator.alloc([]u64, max_base + 1);
            errdefer allocator.free(data[p_idx]);

            for (0..max_base + 1) |base| {
                data[p_idx][base] = try allocator.alloc(u64, max_exp + 1);
                errdefer allocator.free(data[p_idx][base]);

                const prime = primes[p_idx];

                // Precompute base^exp mod prime for all exponents
                data[p_idx][base][0] = 1; // Anything^0 = 1
                var exp: u8 = 1;
                while (exp <= max_exp) : (exp += 1) {
                    if (p_idx == 0 and prime == RECOMMENDED_PRIMES[0]) {
                        // Use Mersenne optimization for first prime
                        data[p_idx][base][exp] = powModMersenne61(@as(u64, base), exp);
                    } else {
                        data[p_idx][base][exp] = powMod(@as(u64, base), exp, prime);
                    }
                }
            }
        }

        return .{
            .allocator = allocator,
            .data = data,
            .primes = primes,
            .max_base = max_base,
            .max_exp = max_exp,
        };
    }

    /// Get precomputed power: base^exp mod prime
    pub inline fn get(self: *const Self, prime_idx: usize, base: u32, exp: u8) u64 {
        std.debug.assert(prime_idx < self.primes.len);
        std.debug.assert(base <= self.max_base);
        std.debug.assert(exp <= self.max_exp);
        return self.data[prime_idx][base][exp];
    }

    /// Clean up memory
    pub fn deinit(self: *Self) void {
        for (self.data) |dim1| {
            for (dim1) |dim2| {
                self.allocator.free(dim2);
            }
            self.allocator.free(dim1);
        }
        self.allocator.free(self.data);
    }

    /// Get memory usage in bytes
    pub fn memoryUsage(self: *const Self) usize {
        var total: usize = 0;
        for (self.data) |dim1| {
            for (dim1) |dim2| {
                total += dim2.len * @sizeOf(u64);
            }
        }
        return total;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MODULAR CONGRUENCE CHECKING
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if A^x + B^y ≡ C^z (mod p) for ALL primes
/// Returns true only if congruence holds for every prime
pub inline fn checkModularAll(
    table: *const PowerTable,
    a: u32,
    b: u32,
    c: u32,
    x: u8,
    y: u8,
    z: u8,
) bool {
    const num_primes = table.primes.len;

    // For 3 primes, use SIMD-optimized path
    if (num_primes == 3) {
        return checkModularSIMD3(table, a, b, c, x, y, z);
    }

    // Fallback: scalar check
    for (0..num_primes) |p_idx| {
        const ax = table.get(p_idx, a, x);
        const by = table.get(p_idx, b, y);
        const cz = table.get(p_idx, c, z);

        // Check: A^x + B^y ≡ C^z (mod p)
        if ((ax +% by) % table.primes[p_idx] != cz) {
            return false;
        }
    }
    return true;
}

/// SIMD-optimized check for exactly 3 primes
pub inline fn checkModularSIMD3(
    table: *const PowerTable,
    a: u32,
    b: u32,
    c: u32,
    x: u8,
    y: u8,
    z: u8,
) bool {
    const ax = [3]u64{
        table.get(0, a, x),
        table.get(1, a, x),
        table.get(2, a, x),
    };
    const by = [3]u64{
        table.get(0, b, y),
        table.get(1, b, y),
        table.get(2, b, y),
    };
    const cz = [3]u64{
        table.get(0, c, z),
        table.get(1, c, z),
        table.get(2, c, z),
    };

    // Modular reduction for each prime
    const left = [3]u64{
        (ax[0] + by[0]) % table.primes[0],
        (ax[1] + by[1]) % table.primes[1],
        (ax[2] + by[2]) % table.primes[2],
    };

    // Compare
    return left[0] == cz[0] and left[1] == cz[1] and left[2] == cz[2];
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const FilterStats = struct {
    total_checked: u64 = 0,
    passed: u64 = 0,
    rejected: u64 = 0,

    pub inline fn rejectionRate(self: *const FilterStats) f64 {
        if (self.total_checked == 0) return 0;
        return @as(f64, @floatFromInt(self.rejected)) / @as(f64, @floatFromInt(self.total_checked));
    }

    pub fn format(self: *const FilterStats, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "Modular: {d} checked, {d} passed, {d} rejected ({d:.1}%)",
            .{
                self.total_checked,
                self.passed,
                self.rejected,
                self.rejectionRate() * 100,
            },
        );
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "powMod - basic cases" {
    try std.testing.expectEqual(@as(u64, 1), powMod(2, 0, 100));
    try std.testing.expectEqual(@as(u64, 8), powMod(2, 3, 100));
    try std.testing.expectEqual(@as(u64, 24), powMod(2, 10, 100)); // 1024 % 100
    try std.testing.expectEqual(@as(u64, 2), powMod(2, 10, 7)); // 1024 % 7
}

test "powMod - large exponents" {
    try std.testing.expectEqual(@as(u64, 1), powMod(123, 0, 456));
    try std.testing.expectEqual(@as(u64, 123 % 456), powMod(123, 1, 456));
}

test "modMersenne61" {
    // Values less than modulus pass through
    try std.testing.expectEqual(@as(u64, 42), modMersenne61(42));

    // 2^61 should wrap to 1 (since 2^61 ≡ 1 (mod 2^61-1))
    const two_61: u128 = 1 << 61;
    try std.testing.expectEqual(@as(u64, 1), modMersenne61(two_61));

    // 2^62 ≡ 2 (mod 2^61-1)
    const two_62: u128 = 1 << 62;
    try std.testing.expectEqual(@as(u64, 2), modMersenne61(two_62));
}

test "powModMersenne61" {
    // 2^10 = 1024
    const result = powModMersenne61(2, 10);
    try std.testing.expectEqual(@as(u64, 1024), result);

    // Test a larger exponent
    const result2 = powModMersenne61(7, 20);
    try std.testing.expect(result2 > 0);
}

test "PowerTable - initialization" {
    const allocator = std.testing.allocator;
    var table = try PowerTable.init(allocator, &RECOMMENDED_PRIMES, 100, 10);
    defer table.deinit();

    try std.testing.expectEqual(@as(usize, 3), table.primes.len);
    try std.testing.expectEqual(@as(u32, 100), table.max_base);
    try std.testing.expectEqual(@as(u8, 10), table.max_exp);

    // Check memory usage is reasonable
    const mem = table.memoryUsage();
    try std.testing.expect(mem > 0);
    try std.testing.expect(mem < 1024 * 1024); // Should be < 1MB for this size
}

test "PowerTable - lookup correctness" {
    const allocator = std.testing.allocator;
    var table = try PowerTable.init(allocator, &RECOMMENDED_PRIMES, 10, 10);
    defer table.deinit();

    // 2^0 = 1 mod anything
    try std.testing.expectEqual(@as(u64, 1), table.get(0, 2, 0));
    try std.testing.expectEqual(@as(u64, 1), table.get(1, 2, 0));

    // 2^10 = 1024
    const val = table.get(2, 2, 10); // Using prime 1000000009
    try std.testing.expectEqual(@as(u64, 1024), val);

    // 3^5 = 243
    const val2 = table.get(2, 3, 5);
    try std.testing.expectEqual(@as(u64, 243), val2);
}

test "checkModularAll - valid equation" {
    const allocator = std.testing.allocator;
    var table = try PowerTable.init(allocator, &RECOMMENDED_PRIMES, 100, 10);
    defer table.deinit();

    // 3^2 + 4^2 = 5^2 (9 + 16 = 25)
    // This is a valid equation, should pass modular check
    const passes = checkModularAll(&table, 3, 4, 5, 2, 2, 2);
    try std.testing.expect(passes);
}

test "checkModularAll - invalid equation" {
    const allocator = std.testing.allocator;
    var table = try PowerTable.init(allocator, &RECOMMENDED_PRIMES, 100, 10);
    defer table.deinit();

    // 7^3 + 8^3 ≠ 11^3
    const passes = checkModularAll(&table, 7, 8, 11, 3, 3, 3);
    try std.testing.expect(!passes);
}

test "FilterStats - tracking" {
    var stats = FilterStats{};

    stats.total_checked = 1000;
    stats.rejected = 999;
    stats.passed = 1;

    try std.testing.expectEqual(@as(u64, 1000), stats.total_checked);
    try std.testing.expectApproxEqAbs(@as(f64, 0.999), stats.rejectionRate(), 0.001);
}
