// ═══════════════════════════════════════════════════════════════════════════════
// Emit T27 (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_emit_t27.zig");

pub const Opcode = gen.Opcode;
pub const BytecodeBuffer = gen.BytecodeBuffer;
pub const Codegen = gen.Codegen;
pub const CodegenError = gen.CodegenError;
pub const compileExpr = gen.compileExpr;
pub const compileResultOk = gen.compileResultOk;
pub const compileResultErr = gen.compileResultErr;
pub const compileLinearConsume = gen.compileLinearConsume;
pub const compileLinearMove = gen.compileLinearMove;
pub const compileLinearBorrow = gen.compileLinearBorrow;
pub const compileArrayGet = gen.compileArrayGet;
pub const compileArraySet = gen.compileArraySet;
pub const compileArrayLen = gen.compileArrayLen;

// Manual (disabled):
// const manual = @import("emit_t27_manual.zig");
// pub const Opcode = manual.Opcode;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
