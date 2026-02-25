//! Prometheus Seed - Ternary Weight Types
//! Minimal stub for trinity_format.zig compatibility

/// Trit weight representation for ternary computing
pub const TritWeight = enum {
    /// Positive value (+1)
    Pos,
    /// Negative value (-1)
    Neg,
    /// Zero value (0)
    Zero,
};
