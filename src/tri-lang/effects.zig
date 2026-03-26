// ═══════════════════════════════════════════════════════════════════════════════
// Algebraic Effects + Handlers (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_effects.zig");

pub const SourceLocation = gen.SourceLocation;
pub const EffectId = gen.EffectId;
pub const EffectOp = gen.EffectOp;
pub const Effect = gen.Effect;
pub const Handler = gen.Handler;
pub const EffectContext = gen.EffectContext;
pub const ErrorContext = gen.ErrorContext;
pub const ErrorEntry = gen.ErrorEntry;

// Manual (disabled):
// const manual = @import("effects_manual.zig");
// pub const Effect = manual.Effect;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
