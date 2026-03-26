//! Sacred Mathematical Functions — φ-based Operations
//!
//! Advanced mathematical functions using golden ratio φ for
//! natural computations in Trinity S³AI framework.
//!
//! Mathematical Foundation:
//! - φ = (1 + √5) / 2 ≈ 1.618
//! - φ² = φ + 1 ≈ 2.618
//! - φ⁻¹ = φ - 1 ≈ 0.618
//! - φ² + φ⁻² = 3 (Trinity Identity)

const std = @import("std");
const sacred = @import("sacred_math.zig");

// ═══════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════

/// φ inverse: 1/φ = φ - 1 ≈ 0.618
pub const PHI_INV: f64 = 1.0 / sacred.PHI;

/// φ squared: φ² ≈ 2.618
pub const PHI_SQ: f64 = sacred.PHI * sacred.PHI;

/// φ inverse squared: φ⁻² ≈ 0.382
pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV;

/// φ inverse cubed: φ⁻³ ≈ 0.236
pub const PHI_INV_CUBED: f64 = PHI_INV * PHI_INV * PHI_INV;

/// Euler's number adjusted by φ: e^φ ≈ 5.043
pub const E_PHI: f64 = std.math.exp(sacred.PHI);

/// Natural log of φ: ln(φ) ≈ 0.481
pub const LN_PHI: f64 = @log(sacred.PHI);

/// Log base φ of 2: log_φ(2) ≈ 1.441
pub const LOG_PHI_2: f64 = @log(2.0) / LN_PHI;

// ═══════════════════════════════════════════════════════════════════════════
// SACRED EXPONENTIAL FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// φ-exponential: exp_φ(x) = exp(x / φ)
/// Natural decay/growth scaled by golden ratio
pub fn phiExp(x: f64) f64 {
    return std.math.exp(x / sacred.PHI);
}

/// φ-logarithm: log_φ(x) = ln(x) / ln(φ)
/// Logarithm in base φ
pub fn phiLog(x: f64) f64 {
    if (x <= 0) return std.math.nan(f64);
    return @log(x) / LN_PHI;
}

/// φ-power: x^φ
pub fn phiPow(x: f64) f64 {
    return std.math.pow(f64, x, sacred.PHI);
}

/// φ-root: ⁿ√x using φ as exponent guide
pub fn phiRoot(x: f64, n: f64) f64 {
    return std.math.pow(f64, x, 1.0 / n);
}

/// Sacred sigmoid: 1 / (1 + exp(-x/φ))
/// φ-adjusted logistic function for neural activations
pub fn sacredSigmoid(x: f64) f64 {
    return 1.0 / (1.0 + std.math.exp(-x / sacred.PHI));
}

/// Sacred tanh: tanh(x/φ)
/// φ-adjusted hyperbolic tangent
pub fn sacredTanh(x: f64) f64 {
    const ex = std.math.exp(x / sacred.PHI);
    const enx = std.math.exp(-x / sacred.PHI);
    return (ex - enx) / (ex + enx);
}

/// Sacred GELU approximation (φ-adjusted)
/// GELU(x) ≈ x · Φ(x/φ) where Φ is CDF
pub fn sacredGELU(x: f64) f64 {
    const scaled = x / sacred.PHI;
    // Approximation: 0.5 * x * (1 + tanh(√(2/π) * (x + 0.044715x³)))
    const sqrt_2_over_pi = 0.7978845608;
    const cdf = 0.5 * (1.0 + std.math.tanh(sqrt_2_over_pi * (scaled + 0.044715 * scaled * scaled * scaled)));
    return x * cdf;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED MATRIX OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

/// φ-scaled matrix multiplication
/// Result = (A × B) / φ for natural normalization
pub fn sacredMatMul(allocator: std.mem.Allocator, a: []const []const f64, b: []const []const f64) ![][]f64 {
    const rows_a = a.len;
    const cols_a = a[0].len;
    const cols_b = b[0].len;

    if (cols_a != b.len) return error.DimensionMismatch;

    var result = try allocator.alloc([]f64, rows_a);
    errdefer {
        for (result) |row| allocator.free(row);
        allocator.free(result);
    }

    for (0..rows_a) |i| {
        result[i] = try allocator.alloc(f64, cols_b);
        for (0..cols_b) |j| {
            var sum: f64 = 0.0;
            for (0..cols_a) |k| {
                sum += a[i][k] * b[k][j];
            }
            result[i][j] = sum / sacred.PHI; // φ-normalization
        }
    }

    return result;
}

/// Sacred matrix transpose
pub fn sacredTranspose(allocator: std.mem.Allocator, m: []const []const f64) ![][]f64 {
    const rows = m.len;
    const cols = m[0].len;

    var result = try allocator.alloc([]f64, cols);
    errdefer {
        for (result) |row| allocator.free(row);
        allocator.free(result);
    }

    for (0..cols) |j| {
        result[j] = try allocator.alloc(f64, rows);
        for (0..rows) |i| {
            result[j][i] = m[i][j] / sacred.PHI;
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED LEARNING RATE SCHEDULES
// ═══════════════════════════════════════════════════════════════════════════

/// Sacred learning rate: lr(t) = lr₀ · φ^(-t/φ)
/// Natural decay following golden ratio
pub fn sacredLR(initial_lr: f64, step: u32, max_steps: u32) f64 {
    if (max_steps == 0) return initial_lr;
    const progress: f64 = @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(max_steps));
    return initial_lr * std.math.pow(f64, sacred.PHI, -progress / sacred.PHI);
}

/// Cosine with φ modulation: lr(t) = lr₀ · (1 + cos(πt/φ)) / 2
pub fn sacredCosineLR(initial_lr: f64, step: u32, max_steps: u32) f64 {
    if (max_steps == 0) return initial_lr;
    const progress: f64 = @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(max_steps));
    const cosine = 0.5 * (1.0 + std.math.cos(std.math.pi * progress / sacred.PHI));
    return initial_lr * cosine;
}

/// Warmup with φ: lr(t) = lr₀ · min(1, t / (warmup · φ⁻¹))
pub fn sacredWarmupLR(initial_lr: f64, step: u32, warmup: u32) f64 {
    const adjusted_warmup = @as(f64, @floatFromInt(warmup)) * PHI_INV;
    if (adjusted_warmup < 1.0) return initial_lr;

    const progress: f64 = @as(f64, @floatFromInt(step)) / adjusted_warmup;
    const factor = if (progress < 1.0) progress else 1.0;
    return initial_lr * factor;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════

/// Sacred initialization scale: σ = d^(-φ⁻³)
/// Used for neural network weight initialization
pub fn sacredInitScale(dim: usize) f64 {
    const d: f64 = @floatFromInt(dim);
    return std.math.pow(f64, d, -PHI_INV_CUBED);
}

/// Xavier-like initialization with φ
pub fn sacredXavierInit(fan_in: usize, fan_out: usize) f64 {
    const fi: f64 = @floatFromInt(fan_in);
    const fo: f64 = @floatFromInt(fan_out);
    return std.math.sqrt(2.0 / (fi + fo)) * sacred.PHI_INV;
}

/// Kaiming-like initialization with φ
pub fn sacredKaimingInit(fan_in: usize) f64 {
    const fi: f64 = @floatFromInt(fan_in);
    return std.math.sqrt(3.0 / fi) * sacred.PHI_INV;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED TERNARY QUANTIZATION
// ═══════════════════════════════════════════════════════════════════════════

/// Ternary quantization threshold using φ
/// Threshold = φ⁻¹ · σ ≈ 0.618 · σ
pub fn ternaryThreshold(std_dev: f64) f64 {
    return PHI_INV * std_dev;
}

/// Quantize floating-point to ternary {-1, 0, +1}
pub fn quantizeToTernary(x: f64, threshold: f64) i8 {
    if (x > threshold) return 1;
    if (x < -threshold) return -1;
    return 0;
}

/// Quantize slice to ternary
pub fn quantizeSlice(data: []const f64, threshold: f64, allocator: std.mem.Allocator) ![]i8 {
    const result = try allocator.alloc(i8, data.len);
    for (data, 0..) |x, i| {
        result[i] = quantizeToTernary(x, threshold);
    }
    return result;
}

/// Dequantize from ternary to floating-point
pub fn dequantizeFromTernary(t: i8, scale: f64) f64 {
    return @as(f64, @floatFromInt(t)) * scale;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED LOSS FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// φ-adjusted mean squared error: MSE / φ
pub fn sacredMSE(predictions: []const f64, targets: []const f64) f64 {
    if (predictions.len != targets.len) return 0.0;

    var sum_sq: f64 = 0.0;
    for (predictions, targets) |p, t| {
        const diff = p - t;
        sum_sq += diff * diff;
    }

    return (sum_sq / @as(f64, @floatFromInt(predictions.len))) / sacred.PHI;
}

/// Sacred cross-entropy: CE / φ
pub fn sacredCrossEntropy(logits: []const f64, targets: []const f64) f64 {
    if (logits.len != targets.len) return 0.0;

    var sum: f64 = 0.0;
    for (logits, targets) |l, t| {
        const clamped = if (l < 0.0001) 0.0001 else l;
        sum += t * @log(clamped);
    }

    return -sum / sacred.PHI;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED NUMERICAL STABILITY
// ═══════════════════════════════════════════════════════════════════════════

/// Log-sum-exp with φ stabilization
/// log(sum(exp(x_i))) ≈ max(x) + log(sum(exp(x_i - max(x))))
pub fn sacredLogSumExp(values: []const f64) f64 {
    if (values.len == 0) return 0.0;

    var max_val = values[0];
    for (values[1..]) |v| {
        if (v > max_val) max_val = v;
    }

    var sum: f64 = 0.0;
    for (values) |v| {
        sum += std.math.exp((v - max_val) / sacred.PHI);
    }

    return max_val + @log(sum) * sacred.PHI;
}

/// Softmax with φ temperature
pub fn sacredSoftmax(logits: []const f64, allocator: std.mem.Allocator) ![]f64 {
    const result = try allocator.alloc(f64, logits.len);

    // Find max for stability
    var max_val = logits[0];
    for (logits[1..]) |l| {
        if (l > max_val) max_val = l;
    }

    // Compute exp with φ temperature
    var sum: f64 = 0.0;
    for (logits, 0..) |l, i| {
        const exp_val = std.math.exp((l - max_val) / sacred.PHI);
        result[i] = exp_val;
        sum += exp_val;
    }

    // Normalize
    for (result) |*r| {
        r.* /= sum;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// TRINITY IDENTITY VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════

/// Verify Trinity Identity: φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() bool {
    const phi_sq = sacred.PHI * sacred.PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    return @abs(result - 3.0) < 1e-10;
}

/// Verify φ Fibonacci relationship: φ^n = F_n·φ + F_{n-1}
/// Where F_n is the nth Fibonacci number
pub fn verifyFibonacciPhi(n: u32) bool {
    if (n < 1) return false;

    var fib_n: u64 = 1;
    var fib_n_minus_1: u64 = 0;

    var i: u32 = 1;
    while (i < n) : (i += 1) {
        const temp = fib_n;
        fib_n += fib_n_minus_1;
        fib_n_minus_1 = temp;
    }

    const lhs = std.math.pow(f64, sacred.PHI, @as(f64, @floatFromInt(n)));
    const rhs = @as(f64, @floatFromInt(fib_n)) * sacred.PHI + @as(f64, @floatFromInt(fib_n_minus_1));

    return @abs(lhs - rhs) < 0.01;
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED NUMBER THEORY
// ═══════════════════════════════════════════════════════════════════════════

/// Check if number is in Fibonacci sequence using φ
/// A number n is Fibonacci iff one of 5n² ± 4 is a perfect square
/// Using φ: n = round(φ^k / √5) for some k
pub fn isFibonacci(n: u64) bool {
    if (n == 0) return true;

    // Use f64 to avoid overflow for large n
    const n_sq = @as(f64, @floatFromInt(n)) * @as(f64, @floatFromInt(n));
    const x_f64 = 5.0 * n_sq + 4.0;
    const y_f64 = 5.0 * n_sq - 4.0;

    // Check if positive and within u64 range
    if (x_f64 < 0 or x_f64 > @as(f64, @floatFromInt(std.math.maxInt(u64)))) return false;
    if (y_f64 < 0) return false; // y can be negative for n=0, already handled

    const x = @as(u64, @intFromFloat(x_f64));
    const y = @as(u64, @intFromFloat(y_f64));

    return isPerfectSquare(x) or isPerfectSquare(y);
}

fn isPerfectSquare(n: u64) bool {
    const root = @as(u64, @intFromFloat(std.math.sqrt(@as(f64, @floatFromInt(n)))));
    return root * root == n;
}

/// Generate Fibonacci number using φ (Binet's formula)
/// F_n = round(φ^n / √5)
pub fn fibonacciBinet(n: u32) u64 {
    const sqrt_5: f64 = 2.23606797749979;
    const result = std.math.pow(f64, sacred.PHI, @as(f64, @floatFromInt(n))) / sqrt_5;
    return @intFromFloat(@round(result));
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "Trinity Identity verification" {
    try std.testing.expect(verifyTrinityIdentity());
}

test "φ constant values" {
    try std.testing.expectApproxEqRel(sacred.PHI, 1.618033988749895, 0.001);
    try std.testing.expectApproxEqRel(PHI_INV, 0.6180339887498951, 0.001);
    try std.testing.expectApproxEqRel(PHI_SQ, 2.618033988749895, 0.001);
}

test "Sacred sigmoid" {
    const x = 0.0;
    const result = sacredSigmoid(x);
    try std.testing.expectApproxEqRel(result, 0.5, 0.01);
}

test "Sacred tanh" {
    const x = 0.0;
    const result = sacredTanh(x);
    try std.testing.expectApproxEqRel(result, 0.0, 0.001);
}

test "φ-exponential" {
    const x = 1.0;
    const result = phiExp(x);
    const expected = std.math.exp(1.0 / sacred.PHI);
    try std.testing.expectApproxEqRel(result, expected, 0.001);
}

test "φ-logarithm" {
    const x = sacred.PHI;
    const result = phiLog(x);
    try std.testing.expectApproxEqRel(result, 1.0, 0.001);
}

test "Sacred learning rate" {
    const initial = 0.001;
    const lr = sacredLR(initial, 500, 1000);
    try std.testing.expect(lr > 0.0);
    try std.testing.expect(lr < initial); // Should decay
}

test "Ternary quantization" {
    const threshold = ternaryThreshold(1.0);
    try std.testing.expect(threshold > 0.6); // ≈ 0.618

    try std.testing.expectEqual(@as(i8, 1), quantizeToTernary(1.0, threshold));
    try std.testing.expectEqual(@as(i8, -1), quantizeToTernary(-1.0, threshold));
    try std.testing.expectEqual(@as(i8, 0), quantizeToTernary(0.1, threshold));
}

test "Sacred MSE" {
    const predictions = [_]f64{ 1.0, 2.0, 3.0 };
    const targets = [_]f64{ 1.1, 2.1, 3.1 };

    const mse = sacredMSE(&predictions, &targets);
    try std.testing.expect(mse > 0.0);
    try std.testing.expect(mse < 0.1);
}

test "Sacred softmax" {
    const logits = [_]f64{ 1.0, 2.0, 3.0 };
    const result = try sacredSoftmax(&logits, std.testing.allocator);
    defer std.testing.allocator.free(result);

    // Sum should be 1.0
    var sum: f64 = 0.0;
    for (result) |r| sum += r;
    try std.testing.expectApproxEqRel(sum, 1.0, 0.001);

    // Result should be increasing (higher logits → higher probs)
    try std.testing.expect(result[2] > result[1]);
    try std.testing.expect(result[1] > result[0]);
}

test "Fibonacci tests" {
    try std.testing.expect(isFibonacci(0));
    try std.testing.expect(isFibonacci(1));
    try std.testing.expect(isFibonacci(2));
    try std.testing.expect(isFibonacci(3));
    try std.testing.expect(isFibonacci(5));
    try std.testing.expect(isFibonacci(8));
    try std.testing.expect(isFibonacci(13));
    try std.testing.expect(!isFibonacci(4));
    try std.testing.expect(!isFibonacci(6));

    try std.testing.expectEqual(@as(u64, 1), fibonacciBinet(1));
    try std.testing.expectEqual(@as(u64, 1), fibonacciBinet(2));
    try std.testing.expectEqual(@as(u64, 2), fibonacciBinet(3));
    try std.testing.expectEqual(@as(u64, 3), fibonacciBinet(4));
    try std.testing.expectEqual(@as(u64, 5), fibonacciBinet(5));
    try std.testing.expectEqual(@as(u64, 8), fibonacciBinet(6));
}
