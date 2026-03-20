//! Compile-time проверки Sacred математики.
//! Если проверки не проходят — ошибка компиляции.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const phi = 1.6180339887498948482;
pub const phi_sq = phi * phi;
pub const inv_phi = 1.0 / phi;
pub const trinity = phi_sq + 1.0 / phi_sq; // = 3.0

// Compile-time верификация Sacred констант
comptime {
    if (@abs(trinity - 3.0) > 1e-15)
        @compileError("φ² + 1/φ² ≠ 3 — Trinity math broken!");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY RESONANCE CHECKS
// ═══════════════════════════════════════════════════════════════════════════════

/// Проверить что размерность соответствует тернарному резонансу (3^k)
pub fn assertTritResonance(comptime dims: usize) void {
    comptime {
        if (dims == 0) @compileError("dims cannot be zero");
        var n = dims;
        while (n % 3 == 0 and n > 1) n /= 3;
        if (n != 1)
            @compileError("dims must be 3^k for ternary resonance!");
    }
}

/// Проверить что значение является степенью 3 (comptime)
pub fn isPowerOf3(comptime n: usize) bool {
    comptime {
        if (n == 0) return false;
        var m = n;
        while (m % 3 == 0 and m > 1) m /= 3;
        return m == 1;
    }
}

/// Получить k для 3^k = n (comptime)
pub fn tritPower(comptime n: usize) comptime_int {
    comptime {
        if (!isPowerOf3(n))
            @compileError("n must be power of 3");
        var k: comptime_int = 0;
        var m = n;
        while (m > 1) : (k += 1) m /= 3;
        return k;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHI-DISTANCE CHECKS
// ═══════════════════════════════════════════════════════════════════════════════

/// Проверить phi-distance формата
pub fn assertPhiDistance(comptime distance: comptime_float, max: comptime_float) void {
    comptime {
        if (distance > max)
            @compileError("phi-distance too large! Format suboptimal.");
    }
}

/// Вычислить phi-distance для формата с n_total бит, n_exp бит
pub fn computePhiDistance(comptime n_total: comptime_int, comptime n_exp: comptime_int) comptime_float {
    const n_mant = n_total - n_exp - 1; // -1 for sign
    return @abs(@as(comptime_float, @floatFromInt(n_exp)) / @as(comptime_float, @floatFromInt(n_mant)) - 1.0 / phi);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED DIMENSIONS CHECKS
// ═══════════════════════════════════════════════════════════════════════════════

/// Рекомендуемые размерности для Sacred слоёв
pub const SacredDimensions = struct {
    /// Контекстная длина для HSLM (3^4 = 81)
    pub const context_len: usize = 81;
    /// Размер embedding (3^5 = 243)
    pub const embed_dim: usize = 243;
    /// Размер VSA вектора (3^6 = 729)
    pub const vsa_dim: usize = 729;
    /// Максимальная длина последовательности (3^7 = 2187)
    pub const seq_max: usize = 2187;
};

/// Проверить что размерность — Sacred Dimensions
pub fn assertSacredDim(comptime dim: usize, comptime ctx: []const u8) void {
    comptime {
        const valid_dims = [_]usize{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049 };
        var is_valid = false;
        for (valid_dims) |d| {
            if (d == dim) {
                is_valid = true;
                break;
            }
        }
        if (!is_valid)
            @compileError(ctx ++ ": dimension must be 3^k (Sacred dimension)");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPILE-TIME SACRED CONSTANTS TABLE
// ═══════════════════════════════════════════════════════════════════════════════

/// Powers of 3 up to 3^10
pub const PowersOf3 = [11]usize{
    1,      // 3^0
    3,      // 3^1
    9,      // 3^2
    27,     // 3^3
    81,     // 3^4
    243,    // 3^5
    729,    // 3^6
    2187,   // 3^7
    6561,   // 3^8
    19683,  // 3^9
    59049,  // 3^10
};

/// Powers of φ up to φ^10
pub const PowersOfPhi = [11]f64{
    1.0,
    1.6180339887498948482,                     // φ^1
    2.6180339887498948482,                     // φ^2
    4.2360679774997896964,                     // φ^3
    6.8541019662496845446,                     // φ^4
    11.090169943749474241,                     // φ^5
    17.944271909999158785,                     // φ^6
    29.034441853748633026,                     // φ^7
    46.978713763747791811,                     // φ^8
    76.013155617496424837,                     // φ^9
    122.99186938124421665,                     // φ^10
};

// ═══════════════════════════════════════════════════════════════════════════════
// RUNTIME VERIFICATION (для тестов)
// ═══════════════════════════════════════════════════════════════════════════════

/// Структура для runtime проверки Sacred инвариантов
pub const SacredVerifier = struct {
    passed: usize = 0,
    failed: usize = 0,
    errors: std.ArrayListUnmanaged(Error) = .empty,

    pub const Error = struct {
        context: []const u8,
        message: []const u8,
    };

    pub fn init() SacredVerifier {
        return .{};
    }

    pub fn deinit(self: *SacredVerifier, allocator: std.mem.Allocator) void {
        self.errors.deinit(allocator);
    }

    /// Проверить Trinity identity
    pub fn verifyTrinity(self: *SacredVerifier, allocator: std.mem.Allocator) bool {
        const computed = phi_sq + 1.0 / phi_sq;
        const ok = @abs(computed - 3.0) < 1e-10;
        if (ok) {
            self.passed += 1;
        } else {
            self.failed += 1;
            self.errors.append(allocator, .{
                .context = "Trinity Identity",
                .message = "φ² + 1/φ² ≠ 3",
            }) catch {};
        }
        return ok;
    }

    /// Проверить что размерность 3^k
    pub fn verifyTritResonance(self: *SacredVerifier, allocator: std.mem.Allocator, dims: usize, ctx: []const u8) bool {
        var n = dims;
        while (n % 3 == 0 and n > 1) n /= 3;
        const ok = n == 1;
        if (ok) {
            self.passed += 1;
        } else {
            self.failed += 1;
            self.errors.append(allocator, .{
                .context = ctx,
                .message = "dimension not 3^k",
            }) catch {};
        }
        return ok;
    }

    /// Получить отчёт
    pub fn report(self: *const SacredVerifier, allocator: std.mem.Allocator) []const u8 {
        const total = self.passed + self.failed;
        const pass_rate = if (total > 0)
            @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(total))
        else
            0.0;

        return std.fmt.allocPrint(
            allocator,
            "Sacred Verification: {d}/{d} passed ({d:.1}%){s}",
            .{
                self.passed,
                total,
                pass_rate * 100.0,
                if (self.failed > 0) " FAILED" else " OK",
            },
        ) catch "Allocation failed";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Trinity identity" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), trinity, 1e-15);
}

test "phi squared plus inverse equals 3" {
    const computed = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), computed, 1e-15);
}

test "assertTritResonance accepts 3^k" {
    comptime {
        assertTritResonance(3);
        assertTritResonance(9);
        assertTritResonance(81);
        assertTritResonance(59049);
    }
    try std.testing.expect(true);
}

test "isPowerOf3" {
    comptime {
        try std.testing.expect(isPowerOf3(1));
        try std.testing.expect(isPowerOf3(3));
        try std.testing.expect(isPowerOf3(9));
        try std.testing.expect(isPowerOf3(81));
        try std.testing.expect(isPowerOf3(59049));

        try std.testing.expect(!isPowerOf3(0));
        try std.testing.expect(!isPowerOf3(2));
        try std.testing.expect(!isPowerOf3(100));
    }
}

test "tritPower" {
    try std.testing.expectEqual(@as(comptime_int, 0), tritPower(1));
    try std.testing.expectEqual(@as(comptime_int, 1), tritPower(3));
    try std.testing.expectEqual(@as(comptime_int, 2), tritPower(9));
    try std.testing.expectEqual(@as(comptime_int, 4), tritPower(81));
}

test "computePhiDistance" {
    const dist_16_6 = computePhiDistance(16, 6); // GF16-like
    try std.testing.expect(dist_16_6 > 0 and dist_16_6 < 1.0);
}

test "SacredDimensions are 3^k" {
    comptime {
        try std.testing.expect(isPowerOf3(SacredDimensions.context_len));  // 81 = 3^4
        try std.testing.expect(isPowerOf3(SacredDimensions.embed_dim));    // 243 = 3^5
        try std.testing.expect(isPowerOf3(SacredDimensions.vsa_dim));      // 729 = 3^6
        try std.testing.expect(isPowerOf3(SacredDimensions.seq_max));      // 2187 = 3^7
    }
}

test "PowersOf3 correctness" {
    var acc: usize = 1;
    for (PowersOf3) |p| {
        try std.testing.expectEqual(acc, p);
        acc *= 3;
    }
}

test "PowersOfPhi correctness" {
    var acc: f64 = 1.0;
    for (PowersOfPhi) |p| {
        try std.testing.expectApproxEqAbs(acc, p, 1e-12);
        acc *= phi;
    }
}

test "SacredVerifier runtime checks" {
    const allocator = std.testing.allocator;
    var verifier = SacredVerifier.init();
    defer verifier.deinit(allocator);

    try std.testing.expect(verifier.verifyTrinity(allocator));
    try std.testing.expect(verifier.verifyTritResonance(allocator, 81, "test"));
    try std.testing.expect(!verifier.verifyTritResonance(allocator, 100, "test"));

    const report = verifier.report(allocator);
    defer allocator.free(report);
    try std.testing.expect(report.len > 0);
}

// φ² + 1/φ² = 3 | TRINITY
