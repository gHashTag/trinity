// ═══════════════════════════════════════════════════════════════════════════════
// TypeEnv (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_type_env.zig");

pub const Scheme = gen.Scheme;
pub const Poly = gen.Poly;
pub const Binding = gen.Binding;
pub const TypeEnv = gen.TypeEnv;
pub const Subst = gen.Subst;

// Manual (disabled):
// const manual = @import("type_env_manual.zig");
// pub const Scheme = manual.Scheme;
// pub const Poly = manual.Poly;
// pub const Binding = manual.Binding;
// pub const TypeEnv = manual.TypeEnv;
// pub const Subst = manual.Subst;
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
