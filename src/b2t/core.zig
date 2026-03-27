//! B2T Core Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_core.zig)
//! DO NOT EDIT: Modify core.tri spec and regenerate

// Types
pub const Trit = @import("gen_core.zig").Trit;
pub const BinaryInput = @import("gen_core.zig").BinaryInput;
pub const TernaryOutput = @import("gen_core.zig").TernaryOutput;

// Constants
pub const TRIT_VALUES = @import("gen_core.zig").TRIT_VALUES;
pub const TRINARY_LOG_BASE = @import("gen_core.zig").TRINARY_LOG_BASE;

// Functions
pub const decode = @import("gen_core.zig").decode;
pub const encode = @import("gen_core.zig").encode;
pub const isReversible = @import("gen_core.zig").isReversible;
