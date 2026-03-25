// ═══════════════════════════════════════════════════════════════════════════════
// Bit/Trit Pattern Matching (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_bit_trit_patterns.zig");

pub const SourceLocation = gen.SourceLocation;
pub const BitPattern = gen.BitPattern;
pub const Trit = gen.Trit;
pub const TritPattern = gen.TritPattern;
pub const Hole = gen.Hole;
pub const PatternMatcher = gen.PatternMatcher;
pub const OpcodePatterns = gen.OpcodePatterns;

// Manual (disabled):
// const manual = @import("bit_trit_patterns_manual.zig");
// pub const BitPattern = manual.BitPattern;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
