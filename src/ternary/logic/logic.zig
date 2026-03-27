//! Ternary Logic Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_logic.zig)
//! DO NOT EDIT: Modify specs/ternary/logic.tri and regenerate

pub const Trit = @import("gen_logic.zig").Trit;
pub const Tekum = @import("gen_logic.zig").Tekum;

pub const tritNot = @import("gen_logic.zig").tritNot;
pub const tritAnd = @import("gen_logic.zig").tritAnd;
pub const tritOr = @import("gen_logic.zig").tritOr;
pub const tritMajority = @import("gen_logic.zig").tritMajority;
