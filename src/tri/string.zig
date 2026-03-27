//! TRI String Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const concat = @import("gen_string.zig").concat;
pub const trim = @import("gen_string.zig").trim;
pub const contains = @import("gen_string.zig").contains;
pub const startsWith = @import("gen_string.zig").startsWith;
pub const endsWith = @import("gen_string.zig").endsWith;
pub const toUpper = @import("gen_string.zig").toUpper;
pub const toLower = @import("gen_string.zig").toLower;
