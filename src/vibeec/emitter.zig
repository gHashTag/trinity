//! VIBEE Codegen Emitter Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_emitter.zig)
//! DO NOT EDIT: Modify emitter.tri spec and regenerate

// Configuration
pub const EmitConfig = @import("gen_emitter.zig").EmitConfig;

// Code builder
pub const CodeBuilder = @import("gen_emitter.zig").CodeBuilder;

// Emitter functions
pub const emit = @import("gen_emitter.zig").emit;
