// ═══════════════════════════════════════════════════════════════════════════════
// Root (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_root.zig");

// Re-export all module imports (delegated to gen_root)
pub const result_type = gen.result_type;
pub const adt_enum = gen.adt_enum;
pub const linear_types = gen.linear_types;
pub const effects = gen.effects;
pub const bit_trit_patterns = gen.bit_trit_patterns;
pub const phantom_types = gen.phantom_types;
pub const array_combinators = gen.array_combinators;
pub const auto_parallel = gen.auto_parallel;
pub const pipe = gen.pipe;
pub const guards = gen.guards;
pub const lexer = gen.lexer;
pub const parser = gen.parser;
pub const ast = gen.ast;
pub const typechecker = gen.typechecker;
pub const types = gen.types;
pub const type_env = gen.type_env;
pub const unify = gen.unify;
pub const emit_t27 = gen.emit_t27;
pub const pipeline = gen.pipeline;
pub const content_hash = gen.content_hash;
pub const content_registry = gen.content_registry;
pub const tri_lang_tests = gen.tri_lang_tests;
pub const integration_test = gen.integration_test;
pub const emu = gen.emu;

// Convenience exports
pub const Result = gen.Result;
pub const Adt = gen.Adt;
pub const Linear = gen.Linear;
pub const Owned = gen.Owned;
pub const Effect = gen.Effect;
pub const Handler = gen.Handler;

// Manual (disabled):
// const manual = @import("root_manual.zig");
// pub const result_type = manual.result_type;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
