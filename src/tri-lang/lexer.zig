// ═══════════════════════════════════════════════════════════════════════════════
// Lexer (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_lexer.zig");

pub const Token = gen.Token;
pub const Keyword = gen.Keyword;
pub const Operator = gen.Operator;
pub const Lexer = gen.Lexer;

// Manual (disabled):
// const manual = @import("lexer_manual.zig");
// pub const Token = manual.Token;
// pub const Keyword = manual.Keyword;
// pub const Operator = manual.Operator;
// pub const Lexer = manual.Lexer;
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
