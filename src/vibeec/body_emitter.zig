//! VIBEE Codegen Body Emitter Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_body_emitter.zig)
//! DO NOT EDIT: Modify body_emitter.tri spec and regenerate

// Context
pub const BodyContext = @import("gen_body_emitter.zig").BodyContext;

// Body generation functions
pub const generateReturn = @import("gen_body_emitter.zig").generateReturn;
pub const generateIfElse = @import("gen_body_emitter.zig").generateIfElse;
pub const generateForLoop = @import("gen_body_emitter.zig").generateForLoop;
pub const generateWhileLoop = @import("gen_body_emitter.zig").generateWhileLoop;
pub const generateAssignment = @import("gen_body_emitter.zig").generateAssignment;
pub const generateCall = @import("gen_body_emitter.zig").generateCall;
