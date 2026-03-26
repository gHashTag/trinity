// ═══════════════════════════════════════════════════════════════════════════════
// Types (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_types.zig");

pub const TypeId = gen.TypeId;
pub const Type = gen.Type;
pub const freshTypeVar = gen.freshTypeVar;
pub const resetTypeVar = gen.resetTypeVar;

// Manual (disabled):
// const manual = @import("types_manual.zig");
// pub const TypeId = manual.TypeId;
// pub const Type = manual.Type;
// pub const freshTypeVar = manual.freshTypeVar;
// pub const resetTypeVar = manual.resetTypeVar;
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
