// ═══════════════════════════════════════════════════════════════════════════════
// ADT Enum for Tri Language (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_adt_enum.zig");

pub const Variant = gen.Variant;
pub const ADT = gen.ADT;
pub const parseADT = gen.parseADT;
pub const isExhaustive = gen.isExhaustive;

// Manual (disabled):
// const manual = @import("adt_enum_manual.zig");
// pub const ADT = manual.ADT;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
