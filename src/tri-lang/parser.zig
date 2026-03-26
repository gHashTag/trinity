// ═══════════════════════════════════════════════════════════════════════════════
// Parser (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_parser.zig");

pub const ParseError = gen.ParseError;
pub const Parser = gen.Parser;

// Manual (disabled):
// const manual = @import("parser_manual.zig");
// pub const ParseError = manual.ParseError;
// pub const Parser = manual.Parser;
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
