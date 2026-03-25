// TTT — Trusted Tri Temple — L0 Sacred Layer
// Root module: re-exports all sacred types, formats, and Coptic system
//
// φ² + 1/φ² = 3 | TRINITY

// Core sacred modules
pub const intraparietal_sulcus = @import("intraparietal_sulcus.zig");
pub const weber_tuning = @import("weber_tuning.zig");
pub const coptic = @import("coptic.zig");
pub const tri27_core = @import("tri27_core.zig");
pub const sacred_math = @import("sacred_math.zig");
pub const tri_lang_core = @import("tri_lang_core.zig");

// Re-export core sacred types for convenience
pub const GoldenFloat16 = intraparietal_sulcus.GoldenFloat16;
pub const TernaryFloat9 = intraparietal_sulcus.TernaryFloat9;
pub const CopticReg = coptic.CopticReg;

// Re-export TRI-27 core types
pub const CopticValue = tri27_core.CopticValue;
pub const CopticArray = tri27_core.CopticArray;

// Re-export sacred math constants
pub const PHI = sacred_math.PHI;
pub const PHI_SQUARED = sacred_math.PHI_SQUARED;
pub const TRINITY_IDENTITY = sacred_math.TRINITY_IDENTITY;
