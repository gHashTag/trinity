// =============================================================================
// TRINITY NEXUS -- Lang Module (trinity-lang)
// VIBEE compiler: parser, AST, code generation, multilingual targets
// =============================================================================
// Single source of truth for the VIBEEC compiler pipeline.
// Consolidated from src/vibeec/ — all compiler logic lives here.
// CLI tools (gen_cmd, gguf_chat, http_server) remain in src/vibeec/.
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

pub const VERSION = "0.2.0";
pub const MODULE = "trinity-lang";

// ─── Parser / Lexer / AST ───────────────────────────────────────────────────────────
pub const vibee_parser = @import("vibee_parser.zig");
pub const lexer = @import("lexer.zig");
pub const ast = @import("ast.zig");
pub const parser_v3 = @import("parser_v3.zig");

// ─── Semantic Analysis ────────────────────────────────────────────────────────────
pub const semantic = @import("semantic.zig");
pub const semantic_analyzer = @import("semantic_analyzer.zig");
pub const type_system = @import("type_system.zig");
pub const type_checker = @import("type_checker.zig");
pub const error_reporter = @import("error_reporter.zig");

// ─── IR / Bytecode ────────────────────────────────────────────────────────────────
pub const ir = @import("ir.zig");
pub const bytecode = @import("bytecode.zig");
pub const bytecode_compiler = @import("bytecode_compiler.zig");
pub const spec_compiler = @import("spec_compiler.zig");

// ─── Code Generation ────────────────────────────────────────────────────────────
pub const zig_codegen = @import("zig_codegen.zig");
pub const verilog_codegen = @import("verilog_codegen.zig");
pub const protocol_defines_gen = @import("protocol_defines_gen.zig");
pub const multi_lang_codegen = @import("multi_lang_codegen.zig");
pub const multilingual_engine = @import("multilingual_engine.zig");
pub const lang_generators = @import("lang_generators.zig");

// ─── CLI Command Pattern (Cycle #118) ───────────────────────────────────────────────
pub const cli_patcher = @import("codegen/cli_patcher.zig");
pub const cli_command = @import("codegen/cli_command.zig");

// ─── Runtime / Support ──────────────────────────────────────────────────────────
pub const coptic_parser_real = @import("coptic_parser_real.zig");
pub const coptic_lexer = @import("coptic_lexer.zig");
pub const vm_runtime = @import("vm_runtime.zig");
pub const sacred_math = @import("sacred_math.zig");
pub const simd_ternary = @import("simd_ternary.zig");
pub const simd_ternary_optimized = @import("simd_ternary_optimized.zig");

// ─── Re-exported types ────────────────────────────────────────────────────────────
pub const VibeeSpec = vibee_parser.VibeeSpec;
pub const Token = lexer.Token;

test {
    // Core parser (self-contained, std-only imports)
    _ = vibee_parser;
    _ = parser_v3;

    // Code generation — primary pipeline
    _ = multi_lang_codegen;
    _ = multilingual_engine;
    _ = lang_generators;

    // Self-contained support modules
    _ = coptic_lexer;
    _ = sacred_math;
    _ = simd_ternary;
    _ = simd_ternary_optimized;

    // NOTE: The following modules use Zig 0.13-style ArrayList/IO API
    // and need migration to 0.15 ArrayListUnmanaged before inclusion:
    // _ = lexer;
    // _ = ast;
    // _ = semantic;
    // _ = semantic_analyzer;
    // _ = type_system;
    // _ = ir;
    // _ = bytecode;
    // _ = error_reporter;
}

test "trinity-lang module identity" {
    try std.testing.expectEqualStrings("trinity-lang", MODULE);
    try std.testing.expectEqualStrings("0.2.0", VERSION);
}

test "trinity-lang parser available" {
    // Verify VibeeSpec type is accessible through the module
    const T = vibee_parser.VibeeSpec;
    _ = T;
}
