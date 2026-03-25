// ═══════════════════════════════════════════════════════════════════════════════
// Array Types (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_array_types.zig");

pub const ArrayFixed = gen.ArrayFixed;
pub const LoweredArray = gen.LoweredArray;
pub const arrayAddress = gen.arrayAddress;
pub const lowerArrayFixed = gen.lowerArrayFixed;

// Manual (disabled):
// const manual = @import("array_types_manual.zig");
// pub const ArrayFixed = manual.ArrayFixed;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
