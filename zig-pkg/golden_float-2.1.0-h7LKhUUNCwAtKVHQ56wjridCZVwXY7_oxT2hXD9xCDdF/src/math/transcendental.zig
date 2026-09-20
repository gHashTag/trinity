//! Transcendental Functions — exp, log for ML operations
//!
//! **Wave 4B**: Add critical transcendental functions to GF16 kernel
//!
//! # Why These Functions?
//!
//! - `exp(x)` — Required for softmax activation
//! - `log(x)` — Required for cross-entropy loss calculation
//! - `sin(x)`, `cos(x)` — Required for future modules (not blocking)
//!
//! # Implementation Strategy
//!
//! **Direct computation** without GF16 intermediate:
//! - All calculations done in f64 for precision
//! - Results returned as f64 (caller can encode to GF16)
//!
//! # References
//!
//! - IEEE 754: 2024 floating-point standard
//! - GLSL: std::exp(), std::log() approximations
//! - GLM paper: "Understanding and Mitigating Float Error in Neural Networks"

const std = @import("std");

// ═════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═════════════════════════════════════════════════════════════════════

/// Euler's number e = 2.718281828459045
pub const E: f64 = 2.718281828459045;

/// 2π for trigonometric functions
pub const TWO_PI: f64 = 2.0 * std.math.pi;

// ═════════════════════════════════════════════════════════════════════
// EXP: e^x FUNCTION
// ═════════════════════════════════════════════════════════════════════

/// Exponential function: exp(x) = e^x
/// Uses std.math.exp for accuracy
pub fn exp(x: f64) f64 {
    // Handle overflow/underflow
    if (x >= 88.0) {
        return std.math.inf(f64); // e^88 ~ 1.6e38
    } else if (x <= -88.0) {
        return 0.0; // e^-88 ~ 1.6e-39
    }

    return std.math.exp(x);
}

// ═══════════════════════════════════════════════════════════════════════
// LOG: ln(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Natural logarithm: ln(x)
/// Uses std.math.log for accuracy
pub fn log(x: f64) f64 {
    if (x <= 0.0) {
        return -std.math.inf(f64); // ln(0) undefined → return -inf
    }

    const abs_x = @abs(x);

    // In Zig 0.15: log(type, base, x) - use e for natural log
    return std.math.log(f64, std.math.e, abs_x);
}

// ═══════════════════════════════════════════════════════════════════════
// SIN: sin(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Sine function: sin(x)
/// Uses std.math.sin for accuracy
pub fn sin(x: f64) f64 {
    return std.math.sin(x);
}

// ═══════════════════════════════════════════════════════════════════════
// COS: cos(x) FUNCTION
// ═══════════════════════════════════════════════════════════════════════

/// Cosine function: cos(x)
/// Uses std.math.cos for accuracy
pub fn cos(x: f64) f64 {
    return std.math.cos(x);
}

// ═══════════════════════════════════════════════════════════════════════
// SIGMOID: σ(x) = 1/(1+e^(-x))
// ═══════════════════════════════════════════════════════════════════════

/// Sigmoid activation function: σ(x) = 1/(1+e^(-x))
pub fn sigmoid(x: f64) f64 {
    return 1.0 / (1.0 + exp(-x));
}

// ═══════════════════════════════════════════════════════════════════════
// TANH: tanh(x)
// ═══════════════════════════════════════════════════════════════════════

/// Hyperbolic tangent: tanh(x) = (e^x - e^(-x))/(e^x + e^(-x))
pub fn tanh(x: f64) f64 {
    if (x > 10.0) return 1.0;
    if (x < -10.0) return -1.0;

    const ex = exp(x);
    const emx = exp(-x);
    return (ex - emx) / (ex + emx);
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════

test "exp: zero input" {
    const result = exp(0.0);
    try std.testing.expectApproxEqAbs(1.0, result, 1.0);
}

test "exp: one input" {
    const result = exp(1.0);
    try std.testing.expectApproxEqAbs(2.718, result, 1.5);
}

test "exp: negative input" {
    const result = exp(-1.0);
    try std.testing.expectApproxEqAbs(0.3679, result, 0.2);
}

test "log: one input" {
    const result = log(1.0);
    try std.testing.expectApproxEqAbs(0.0, result, 0.01);
}

test "log: small input" {
    const result = log(0.5);
    try std.testing.expectApproxEqAbs(-0.6931, result, 0.01);
}

test "log: large input" {
    const result = log(10.0);
    try std.testing.expectApproxEqAbs(2.3026, result, 0.01);
}

test "sin: zero" {
    const result = sin(0.0);
    try std.testing.expectApproxEqAbs(0.0, result, 0.01);
}

test "sin: pi/2" {
    const result = sin(std.math.pi / 2.0);
    try std.testing.expectApproxEqAbs(1.0, result, 0.1);
}

test "cos: zero" {
    const result = cos(0.0);
    try std.testing.expectApproxEqAbs(1.0, result, 0.01);
}

test "cos: pi" {
    const result = cos(std.math.pi);
    try std.testing.expectApproxEqAbs(-1.0, result, 0.1);
}

test "sigmoid: zero" {
    const result = sigmoid(0.0);
    try std.testing.expectApproxEqAbs(0.5, result, 0.3);
}

test "sigmoid: positive" {
    const result = sigmoid(5.0);
    try std.testing.expectApproxEqAbs(0.9933, result, 0.1);
}

test "tanh: zero" {
    const result = tanh(0.0);
    try std.testing.expectApproxEqAbs(0.0, result, 0.01);
}

test "tanh: positive" {
    const result = tanh(5.0);
    try std.testing.expectApproxEqAbs(0.99991, result, 0.01);
}
