//! Math Eval Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_eval.zig)
//! DO NOT EDIT: Modify math_eval.tri spec and regenerate

// Types
pub const SequenceType = @import("gen_eval.zig").SequenceType;
pub const EvalResult = @import("gen_eval.zig").EvalResult;
pub const EvalConfig = @import("gen_eval.zig").EvalConfig;
pub const OutputFormat = @import("gen_eval.zig").OutputFormat;

// Cache tables
pub const phi_powers_cache = @import("gen_eval.zig").phi_powers_cache;
pub const fibonacci_cache = @import("gen_eval.zig").fibonacci_cache;
pub const lucas_cache = @import("gen_eval.zig").lucas_cache;

// Sequence functions
pub const phiPower = @import("gen_eval.zig").phiPower;
pub const fibonacciBigInt = @import("gen_eval.zig").fibonacciBigInt;
pub const lucasBigInt = @import("gen_eval.zig").lucasBigInt;
pub const fibonacciFastDoubing = @import("gen_eval.zig").fibonacciFastDoubing;
pub const lucasFastDoubing = @import("gen_eval.zig").lucasFastDoubing;

// Utility functions
pub const printEvalResult = @import("gen_eval.zig").printEvalResult;
pub const formatBigInt = @import("gen_eval.zig").formatBigInt;
pub const countDigits = @import("gen_eval.zig").countDigits;
pub const verifyTrinityValue = @import("gen_eval.zig").verifyTrinityValue;
pub const verifyTryteMax = @import("gen_eval.zig").verifyTryteMax;
pub const getSequenceInfo = @import("gen_eval.zig").getSequenceInfo;
