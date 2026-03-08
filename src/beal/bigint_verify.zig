// ═══════════════════════════════════════════════════════════════════════════════
// BEAL BIGINT VERIFICATION - Exact Power Computation for Counterexample Verification
// ═══════════════════════════════════════════════════════════════════════════════
// Computes A^x, B^y, C^z exactly and verifies A^x + B^y = C^z
// Uses:
//   - u64 for results ≤ 64 bits
//   - u128 for results 65-128 bits
//   - Karatsuba multiplication for results > 128 bits
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// BIGINT REPRESENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Big integer for Beal power computation
/// Uses limb-based representation for arbitrary precision
pub const BigInt = struct {
    limbs: []u64,
    allocator: std.mem.Allocator,
    sign: bool = false, // true for negative (not used for Beal)

    const Self = @This();

    /// Create zero
    pub fn zero(allocator: std.mem.Allocator) !Self {
        const limbs = try allocator.alloc(u64, 1);
        limbs[0] = 0;
        return .{
            .limbs = limbs,
            .allocator = allocator,
        };
    }

    /// Create from u64
    pub fn fromU64(allocator: std.mem.Allocator, value: u64) !Self {
        const limbs = try allocator.alloc(u64, 1);
        limbs[0] = value;
        return .{
            .limbs = limbs,
            .allocator = allocator,
        };
    }

    /// Create from u128
    pub fn fromU128(allocator: std.mem.Allocator, value: u128) !Self {
        const lo: u64 = @truncate(value);
        const hi: u64 = @truncate(value >> 64);

        if (hi == 0) {
            return fromU64(allocator, lo);
        }

        const limbs = try allocator.alloc(u64, 2);
        limbs[0] = lo;
        limbs[1] = hi;
        return .{
            .limbs = limbs,
            .allocator = allocator,
        };
    }

    /// Get number of limbs
    pub fn limbCount(self: *const Self) usize {
        // Trim leading zeros
        var count = self.limbs.len;
        while (count > 1 and self.limbs[count - 1] == 0) {
            count -= 1;
        }
        return count;
    }

    /// Check if zero
    pub fn isZero(self: *const Self) bool {
        for (self.limbs) |limb| {
            if (limb != 0) return false;
        }
        return true;
    }

    /// Check if fits in u64
    pub fn fitsU64(self: *const Self) bool {
        return self.limbCount() <= 1;
    }

    /// Check if fits in u128
    pub fn fitsU128(self: *const Self) bool {
        const count = self.limbCount();
        if (count <= 1) return true;
        if (count > 2) return false;
        return self.limbs[1] == 0;
    }

    /// Convert to u64 (undefined if doesn't fit)
    pub fn toU64(self: *const Self) u64 {
        return self.limbs[0];
    }

    /// Convert to u128 (undefined if doesn't fit)
    pub fn toU128(self: *const Self) u128 {
        const lo: u128 = self.limbs[0];
        const hi: u128 = if (self.limbs.len > 1) self.limbs[1] else 0;
        return lo | (hi << 64);
    }

    /// Free memory
    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.limbs);
    }

    /// Copy
    pub fn clone(self: *const Self) !Self {
        const limbs = try self.allocator.alloc(u64, self.limbs.len);
        @memcpy(limbs, self.limbs);
        return .{
            .limbs = limbs,
            .allocator = self.allocator,
        };
    }

    /// Add two BigInts
    pub fn add(self: *const Self, other: *const Self) !Self {
        const max_limbs = @max(self.limbCount(), other.limbCount());
        const result_limbs = try self.allocator.alloc(u64, max_limbs + 1);
        @memset(result_limbs, 0);

        var carry: u64 = 0;
        for (0..max_limbs) |i| {
            const a = if (i < self.limbs.len) self.limbs[i] else 0;
            const b = if (i < other.limbs.len) other.limbs[i] else 0;
            const sum = a + b + carry;
            result_limbs[i] = sum;
            carry = if (sum < a or sum < b) 1 else 0;
        }
        result_limbs[max_limbs] = carry;

        return .{
            .limbs = result_limbs,
            .allocator = self.allocator,
        };
    }

    /// Subtract other from self (self must >= other)
    pub fn sub(self: *const Self, other: *const Self) !Self {
        const max_limbs = @max(self.limbCount(), other.limbCount());
        const result_limbs = try self.allocator.alloc(u64, max_limbs);
        @memset(result_limbs, 0);

        var borrow: u64 = 0;
        for (0..max_limbs) |i| {
            const a = if (i < self.limbs.len) self.limbs[i] else 0;
            const b = if (i < other.limbs.len) other.limbs[i] else 0;
            const diff = a -% b -% borrow;
            result_limbs[i] = diff;
            borrow = if (b > a) 1 else 0;
        }

        return .{
            .limbs = result_limbs,
            .allocator = self.allocator,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // MULTIPLICATION
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Schoolbook multiplication O(n²)
    fn schoolbookMul(self: *const Self, other: *const Self) !Self {
        const a_count = self.limbCount();
        const b_count = other.limbCount();
        const result_limbs = try self.allocator.alloc(u64, a_count + b_count);
        @memset(result_limbs, 0);

        for (0..a_count) |i| {
            var carry: u64 = 0;
            const a_limb = self.limbs[i];

            for (0..b_count) |j| {
                const b_limb = other.limbs[j];
                const product = @as(u128, a_limb) * @as(u128, b_limb);
                const lo: u64 = @truncate(product);
                const hi: u64 = @truncate(product >> 64);

                const new_sum = @as(u128, result_limbs[i + j]) + @as(u128, lo) + @as(u128, carry);
                result_limbs[i + j] = @truncate(new_sum);
                carry = hi + @as(u64, @truncate(new_sum >> 64));
            }

            var k = b_count;
            while (carry != 0) : (k += 1) {
                const new_sum = @as(u128, result_limbs[i + k]) + @as(u128, carry);
                result_limbs[i + k] = @truncate(new_sum);
                carry = @as(u64, @truncate(new_sum >> 64));
            }
        }

        return .{
            .limbs = result_limbs,
            .allocator = self.allocator,
        };
    }

    /// Karatsuba multiplication O(n^1.585)
    /// Only use for larger numbers (threshold >= 64 limbs)
    fn karatsubaMul(self: *const Self, other: *const Self) !Self {
        const n = @max(self.limbCount(), other.limbCount());

        // Base case: use schoolbook for small numbers
        if (n < 64) {
            return self.schoolbookMul(other);
        }

        // Split point
        const m = n / 2;

        // Split self into high and low parts
        const self_low = try self.slice(0, m);
        defer self_low.deinit();
        const self_high = try self.slice(m, n);
        defer self_high.deinit();

        // Split other into high and low parts
        const other_low = try other.slice(0, m);
        defer other_low.deinit();
        const other_high = try other.slice(m, n);
        defer other_high.deinit();

        // Karatsuba's algorithm:
        // z0 = x0 * y0
        // z2 = x1 * y1
        // z1 = (x0 + x1) * (y0 + y1) - z0 - z2

        const z0 = try self_low.schoolbookMul(&other_low);
        defer z0.deinit();

        const z2 = try self_high.schoolbookMul(&other_high);
        defer z2.deinit();

        const x_sum = try self_low.add(&self_high);
        defer x_sum.deinit();

        const y_sum = try other_low.add(&other_high);
        defer y_sum.deinit();

        const z1_temp = try x_sum.schoolbookMul(&y_sum);
        defer z1_temp.deinit();

        const z0_z2 = try z0.add(&z2);
        defer z0_z2.deinit();

        const z1 = try z1_temp.sub(&z0_z2);
        defer z1.deinit();

        // Combine results: result = z0 + z1 * B^m + z2 * B^(2m)
        const z1_shifted = try z1.shiftLeft(m * 64);
        defer z1_shifted.deinit();
        const result = try z0.add(&z1_shifted);
        const z2_shifted = try z2.shiftLeft(2 * m * 64);
        defer z2_shifted.deinit();
        const final = try result.add(&z2_shifted);

        return final;
    }

    /// Slice limbs [start, end)
    fn slice(self: *const Self, start: usize, end: usize) !Self {
        const len = if (end > self.limbs.len) self.limbs.len else end;
        const actual_len = if (len > start) len - start else 0;

        const limbs = try self.allocator.alloc(u64, actual_len);
        @memcpy(limbs, self.limbs[start..][0..actual_len]);

        // Zero-extend if necessary
        if (limbs.len < actual_len) {
            @memset(limbs[limbs.len..], 0);
        }

        return .{
            .limbs = limbs,
            .allocator = self.allocator,
        };
    }

    /// Shift left by bits
    fn shiftLeft(self: *const Self, bits: usize) !Self {
        if (bits == 0) return self.clone();

        const limb_shift = bits / 64;
        const bit_shift = @as(u6, @intCast(bits % 64));

        const old_count = self.limbCount();
        const new_count = old_count + limb_shift + 1;
        const result_limbs = try self.allocator.alloc(u64, new_count);
        @memset(result_limbs, 0);

        // Copy limbs with shift
        if (bit_shift == 0) {
            for (0..old_count) |i| {
                result_limbs[i + limb_shift] = self.limbs[i];
            }
        } else {
            var carry: u64 = 0;
            for (0..old_count) |i| {
                const limb = self.limbs[i];
                result_limbs[i + limb_shift] = (limb << bit_shift) | carry;
                // When bit_shift > 0, we need to shift by (64 - bit_shift)
                // Compute as u64 then truncate to u6 (safe since bit_shift > 0)
                const shift_amt_u64: u64 = 64 - @as(u64, bit_shift);
                carry = limb >> @as(u6, @truncate(shift_amt_u64));
            }
            result_limbs[old_count + limb_shift] = carry;
        }

        return .{
            .limbs = result_limbs,
            .allocator = self.allocator,
        };
    }

    /// Multiply two BigInts using optimal algorithm
    pub fn mul(self: *const Self, other: *const Self) !Self {
        // Choose algorithm based on size
        const n = @max(self.limbCount(), other.limbCount());

        if (n <= 4) {
            // For small numbers, simple u64/u128 is faster
            if (self.fitsU64() and other.fitsU64()) {
                const product = @as(u128, self.toU64()) * @as(u128, other.toU64());
                if (product <= std.math.maxInt(u64)) {
                    return fromU64(self.allocator, @truncate(product));
                }
                return fromU128(self.allocator, product);
            }
        }

        if (n < 64) {
            return self.schoolbookMul(other);
        }

        return self.karatsubaMul(other);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // POWER COMPUTATION
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Compute base^exp using binary exponentiation
    pub fn pow(allocator: std.mem.Allocator, base: u64, exp: u64) !Self {
        if (exp == 0) return fromU64(allocator, 1);
        if (exp == 1) return fromU64(allocator, base);

        var result = try Self.fromU64(allocator, 1);
        var current = try Self.fromU64(allocator, base);
        var remaining = exp;

        while (remaining > 0) {
            if (remaining & 1 == 1) {
                const old_result = result;
                result = try result.mul(&current);
                old_result.deinit();
            }
            remaining >>= 1;
            if (remaining > 0) {
                const old_current = current;
                current = try current.mul(&current);
                old_current.deinit();
            }
        }

        current.deinit();
        return result;
    }

    /// Compare two BigInts
    pub fn compare(self: *const Self, other: *const Self) std.math.Order {
        const a_count = self.limbCount();
        const b_count = other.limbCount();

        if (a_count != b_count) {
            return if (a_count > b_count) .gt else .lt;
        }

        for (0..a_count) |i| {
            const idx = a_count - 1 - i;
            if (self.limbs[idx] != other.limbs[idx]) {
                return if (self.limbs[idx] > other.limbs[idx]) .gt else .lt;
            }
        }

        return .eq;
    }

    /// Equality check
    pub fn eq(self: *const Self, other: *const Self) bool {
        return self.compare(other) == .eq;
    }

    /// Get bit length (position of highest set bit + 1)
    pub fn bitLength(self: *const Self) usize {
        const count = self.limbCount();
        if (count == 0) return 0;
        const top_limb = self.limbs[count - 1];
        if (top_limb == 0) return 0;
        return (count - 1) * 64 + (64 - @clz(top_limb));
    }

    /// Convert to f64 approximation (undefined if too large)
    pub fn toFloat64(self: *const Self) ?f64 {
        const count = self.limbCount();
        if (count == 0) return null;

        // For single limb, direct conversion
        if (count == 1) {
            return @as(f64, @floatFromInt(self.limbs[0]));
        }

        // For multi-limb, approximate using top 2-3 limbs
        // This gives about 50 significant bits of precision
        const top_limb = self.limbs[count - 1];
        const next_limb = if (count >= 2) self.limbs[count - 2] else 0;

        const bits_per_limb = 64.0;
        const shift = @as(f64, @floatFromInt(count - 1)) * bits_per_limb;

        // Combine top limbs into f64
        const top_value: f64 = @floatFromInt(top_limb);
        const next_value: f64 = @floatFromInt(next_limb);
        const combined = top_value + (next_value / @as(f64, 1 << 32));

        return combined * @as(f64, std.math.pow(f64, 2, shift));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// POWER VERIFICATION FOR BEAL
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify if A^x + B^y = C^z exactly
pub fn verifyBealEquation(
    allocator: std.mem.Allocator,
    a: u64,
    x: u64,
    b: u64,
    y: u64,
    c: u64,
    z: u64,
) !bool {
    // For small values, use native arithmetic
    if (a <= 1000 and x <= 10 and b <= 1000 and y <= 10) {
        const ax = std.math.pow(u128, a, x);
        const by = std.math.pow(u128, b, y);
        const cz = std.math.pow(u128, c, z);
        return ax + by == cz;
    }

    // For large values, use BigInt
    const a_pow = try BigInt.pow(allocator, a, x);
    defer a_pow.deinit();

    const b_pow = try BigInt.pow(allocator, b, y);
    defer b_pow.deinit();

    const sum = try a_pow.add(&b_pow);
    defer sum.deinit();

    const c_pow = try BigInt.pow(allocator, c, z);
    defer c_pow.deinit();

    return sum.eq(&c_pow);
}

/// Fast check: estimate bit length of base^exp
pub fn estimateBitLength(base: u64, exp: u64) usize {
    if (exp == 0) return 1;
    if (base <= 1) return if (base == 1) 1 else 0;

    // log2(base^exp) = exp * log2(base)
    // Approximate log2(base) as bit length - 1
    const base_clz = @clz(base);
    const base_bits = 64 - base_clz;
    return @as(usize, @intCast(exp * base_bits));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BigInt fromU64" {
    const allocator = std.testing.allocator;

    const zero = try BigInt.zero(allocator);
    defer zero.deinit();
    try std.testing.expect(zero.isZero());
    try std.testing.expectEqual(@as(u64, 0), zero.toU64());

    const val = try BigInt.fromU64(allocator, 12345);
    defer val.deinit();
    try std.testing.expect(!val.isZero());
    try std.testing.expectEqual(@as(u64, 12345), val.toU64());
}

test "BigInt fromU128" {
    const allocator = std.testing.allocator;

    const val = try BigInt.fromU128(allocator, 12345678901234567890);
    defer val.deinit();
    try std.testing.expectEqual(@as(u128, 12345678901234567890), val.toU128());
}

test "BigInt add" {
    const allocator = std.testing.allocator;

    const a = try BigInt.fromU64(allocator, 1000);
    defer a.deinit();
    const b = try BigInt.fromU64(allocator, 2000);
    defer b.deinit();

    const sum = try a.add(&b);
    defer sum.deinit();
    try std.testing.expectEqual(@as(u64, 3000), sum.toU64());
}

test "BigInt mul small" {
    const allocator = std.testing.allocator;

    const a = try BigInt.fromU64(allocator, 123);
    defer a.deinit();
    const b = try BigInt.fromU64(allocator, 456);
    defer b.deinit();

    const product = try a.mul(&b);
    defer product.deinit();
    try std.testing.expectEqual(@as(u64, 123 * 456), product.toU64());
}

test "BigInt pow" {
    const allocator = std.testing.allocator;

    // 2^10 = 1024
    const result = try BigInt.pow(allocator, 2, 10);
    defer result.deinit();
    try std.testing.expectEqual(@as(u64, 1024), result.toU64());

    // 3^5 = 243
    const result2 = try BigInt.pow(allocator, 3, 5);
    defer result2.deinit();
    try std.testing.expectEqual(@as(u64, 243), result2.toU64());

    // 10^6 = 1,000,000
    const result3 = try BigInt.pow(allocator, 10, 6);
    defer result3.deinit();
    try std.testing.expectEqual(@as(u64, 1_000_000), result3.toU64());
}

test "BigInt compare" {
    const allocator = std.testing.allocator;

    const a = try BigInt.fromU64(allocator, 100);
    defer a.deinit();
    const b = try BigInt.fromU64(allocator, 200);
    defer b.deinit();

    try std.testing.expectEqual(std.math.Order.lt, a.compare(&b));
    try std.testing.expectEqual(std.math.Order.gt, b.compare(&a));
    try std.testing.expectEqual(std.math.Order.eq, a.compare(&a));
}

test "verifyBealEquation - Pythagorean triple" {
    const allocator = std.testing.allocator;

    // 3^2 + 4^2 = 5^2 (9 + 16 = 25)
    const result = try verifyBealEquation(allocator, 3, 2, 4, 2, 5, 2);
    try std.testing.expect(result);
}

test "verifyBealEquation - non-solution" {
    const allocator = std.testing.allocator;

    // 7^3 + 8^3 ≠ 11^3 (343 + 512 = 855 ≠ 1331)
    const result = try verifyBealEquation(allocator, 7, 3, 8, 3, 11, 3);
    try std.testing.expect(!result);
}

test "BigInt large power" {
    const allocator = std.testing.allocator;

    // 2^64 needs multiple limbs
    const result = try BigInt.pow(allocator, 2, 64);
    defer result.deinit();
    try std.testing.expect(!result.fitsU64());
    try std.testing.expect(!result.fitsU128());
}

test "BigInt mul overflow" {
    const allocator = std.testing.allocator;

    // (2^64 - 1) * (2^64 - 1)
    const max_u64 = std.math.maxInt(u64);
    const a = try BigInt.fromU128(allocator, max_u64);
    defer a.deinit();
    const b = try a.clone();
    defer b.deinit();

    const product = try a.mul(&b);
    defer product.deinit();
    try std.testing.expect(product.limbCount() > 1);
}
