// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Common Types (Selector)
// ═══════════════════════════════════════════════════════════════════════════════════
// This file re-exports from generated code (gen_common.zig)
// DO NOT EDIT: Modify common.tri spec and regenerate
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════

// Types (re-exported from gen_common)
pub const Trit = @import("gen_common.zig").Trit;
pub const TritRange = @import("gen_common.zig").TritRange;
pub const SearchResult = @import("gen_common.zig").SearchResult;
pub const Vec32i8 = @import("gen_common.zig").Vec32i8;
pub const Vec32i16 = @import("gen_common.zig").Vec32i16;

// Constants (re-exported from gen_common)
pub const SIMD_WIDTH = @import("gen_common.zig").SIMD_WIDTH;
pub const NEGATIVE = @import("gen_common.zig").NEGATIVE;
pub const ZERO = @import("gen_common.zig").ZERO;
pub const POSITIVE = @import("gen_common.zig").POSITIVE;
pub const ValidRange = @import("gen_common.zig").ValidRange;

// Trit utilities (re-exported from gen_common)
pub const isNegative = @import("gen_common.zig").isNegative;
pub const isZero = @import("gen_common.zig").isZero;
pub const isPositive = @import("gen_common.zig").isPositive;
pub const isNonZero = @import("gen_common.zig").isNonZero;
pub const tritValue = @import("gen_common.zig").tritValue;
pub const tritFromInt = @import("gen_common.zig").tritFromInt;
pub const isTritValid = @import("gen_common.zig").isTritValid;
pub const normalizeTrit = @import("gen_common.zig").normalizeTrit;
pub const countNonZero = @import("gen_common.zig").countNonZero;
pub const allSame = @import("gen_common.zig").allSame;
pub const countTrit = @import("gen_common.zig").countTrit;

// SIMD utilities (re-exported from gen_common)
pub const broadcastTrit = @import("gen_common.zig").broadcastTrit;
pub const loadTrits = @import("gen_common.zig").loadTrits;
pub const storeTrits = @import("gen_common.zig").storeTrits;
