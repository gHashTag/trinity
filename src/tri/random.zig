//! TRI Random Module Selector
pub const Rng = @import("gen_random.zig").Rng;
pub const init = @import("gen_random.zig").init;
pub const next = @import("gen_random.zig").next;
pub const range = @import("gen_random.zig").range;
pub const rangeInclusive = @import("gen_random.zig").rangeInclusive;
