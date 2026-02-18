// =============================================================================
// TRINITY NEXUS -- Lang Module (trinity-lang)
// VIBEE compiler: parser, AST, code generation, multilingual targets
// =============================================================================
// Migrated from src/vibeec/ in NEXUS-003
// 38 files, 28186 lines — core compiler pipeline
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

pub const VERSION = "0.1.0";
pub const MODULE = "trinity-lang";

// ─── Parser / Lexer / AST ───────────────────────────────────────────────────────────
pub const vibee_parser = @import("vibee_parser.zig");
pub const lexer = @import("lexer.zig");
pub const ast = @import("ast.zig");

// ─── Semantic Analysis ────────────────────────────────────────────────────────────
pub const semantic = @import("semantic.zig");
pub const semantic_analyzer = @import("semantic_analyzer.zig");
pub const type_system = @import("type_system.zig");

// ─── IR / Bytecode ────────────────────────────────────────────────────────────────
pub const ir = @import("ir.zig");
pub const bytecode = @import("bytecode.zig");

// ─── Code Generation ────────────────────────────────────────────────────────────
pub const zig_codegen = @import("zig_codegen.zig");
pub const verilog_codegen = @import("verilog_codegen.zig");
pub const multi_lang_codegen = @import("multi_lang_codegen.zig");
pub const multilingual_engine = @import("multilingual_engine.zig");
pub const lang_generators = @import("lang_generators.zig");

// ─── Codegen Module ─────────────────────────────────────────────────────────────
pub const codegen = @import("codegen/mod.zig");

// ─── Re-exported types ────────────────────────────────────────────────────────────
pub const VibeeSpec = vibee_parser.VibeeSpec;
pub const Token = lexer.Token;

test {
    // Core parser/lexer/AST (self-contained, std-only imports)
    _ = vibee_parser;
    _ = lexer;
    _ = ast;

    // Semantic analysis
    _ = semantic;
    _ = semantic_analyzer;
    _ = type_system;

    // IR / Bytecode
    _ = ir;
    _ = bytecode;

    // Code generation
    _ = multi_lang_codegen;
    _ = multilingual_engine;
    _ = lang_generators;
}

test "trinity-lang module identity" {
    try std.testing.expectEqualStrings("trinity-lang", MODULE);
    try std.testing.expectEqualStrings("0.1.0", VERSION);
}

test "trinity-lang parser available" {
    // Verify VibeeSpec type is accessible through the module
    const T = vibee_parser.VibeeSpec;
    _ = T;
}
