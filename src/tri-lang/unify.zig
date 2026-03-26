// ═══════════════════════════════════════════════════════════════════
// Unify (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_unify.zig");

pub const Type = gen.Type;
pub const TypeId = gen.TypeId;
pub const freshTypeVar = gen.freshTypeVar;
pub const resetTypeVar = gen.resetTypeVar;
pub const UnifyResult = gen.UnifyResult;
pub const TypeError = gen.TypeError;
pub const Subst = gen.Subst;
pub const occursIn = gen.occursIn;
pub const unify = gen.unify;
pub const unifyWithSubst = gen.unifyWithSubst;

// Manual (disabled):
// const manual = @import("unify_manual.zig");
// pub const Type = manual.Type;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
