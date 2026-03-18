// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE E2E Test Fixture - Invalid Zig Code
// ═══════════════════════════════════════════════════════════════════════════════
//
// This file contains intentional syntax errors for testing quality gates.
//
// Errors:
// 1. Unbalanced braces (missing closing brace for fn broken1)
// 2. Unbalanced parentheses (in fn broken2)
// 3. Mismatched brackets (in array declaration)
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Function with missing closing brace - PARSE ERROR
pub fn broken1(a: i32, b: i32) i32 {
    return a + b;
// Missing closing brace here!

/// Function with unbalanced parentheses - PARSE ERROR
pub fn broken2(a: i32, b: i32 i32 {
    return a + b;
}

/// Array with mismatched brackets - PARSE ERROR
pub const broken_array = [1, 2, 3, 4;

/// This function is actually OK (for reference)
pub fn okay(c: i32) i32 {
    return c * 2;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Expected Quality Gates Results:
// - parse_ok: false
// - violations: 3+ (unbalanced braces, unbalanced parens, mismatched brackets)
// - safety_score: < 50.0
// ═══════════════════════════════════════════════════════════════════════════════
