// VIBEE Code Generation Module
// Core pattern system for code generation from .vibee specifications
// φ² + 1/φ² = 3

pub const types = @import("types.zig");
pub const builder = @import("builder.zig");
pub const utils = @import("utils.zig");
pub const patterns = @import("patterns.zig");
pub const tests_gen = @import("tests_gen.zig");
pub const emitter = @import("emitter.zig");

// Pattern system (CORE for self-improvement)
pub const pattern_engine = @import("pattern_engine.zig");
pub const pattern_resolver = @import("pattern_resolver.zig");
pub const pattern_registry = @import("pattern_registry.zig");

// Re-export key types for convenience
pub const Pattern = pattern_engine.Pattern;
pub const PatternEngine = pattern_engine.PatternEngine;
pub const PatternRef = pattern_resolver.PatternRef;
pub const PatternResolver = pattern_resolver.PatternResolver;
pub const PatternRegistry = pattern_registry.PatternRegistry;
pub const GeneratedCode = pattern_engine.GeneratedCode;
pub const Context = pattern_engine.Context;
