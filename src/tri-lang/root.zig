// TRI Language — Zone Root
// Re-exports all TRI language compiler and runtime modules
//
// φ² + 1/φ² = 3 | TRINITY

// Core language modules
pub const result_type = @import("result_type.zig");
pub const adt_enum = @import("adt_enum.zig");
pub const linear_types = @import("linear_types.zig");
pub const effects = @import("effects.zig");
pub const bit_trit_patterns = @import("bit_trit_patterns.zig");
pub const phantom_types = @import("phantom_types.zig");
pub const array_combinators = @import("array_combinators.zig");
pub const auto_parallel = @import("auto_parallel.zig");

// Compiler pipeline
pub const lexer = @import("lexer.zig");
pub const parser = @import("parser.zig");
pub const ast = @import("ast.zig");
pub const typechecker = @import("typechecker.zig");
pub const types = @import("types.zig");
pub const type_env = @import("type_env.zig");
pub const unify = @import("unify.zig");

// Code generation
pub const emit_t27 = @import("emit_t27.zig");
pub const pipeline = @import("pipeline.zig");

// Testing
pub const tri_lang_tests = @import("tri_lang_tests.zig");
pub const integration_test = @import("integration_test.zig");

// Re-export commonly used types for convenience
pub const Result = result_type.Result;
pub const Adt = adt_enum.Adt;
pub const Linear = linear_types.Linear;
pub const Owned = linear_types.Owned;
pub const Effect = effects.Effect;
pub const Handler = effects.Handler;
