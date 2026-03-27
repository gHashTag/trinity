//! TRI Config Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const ConfigValue = @import("gen_config.zig").ConfigValue;
pub const ConfigEntry = @import("gen_config.zig").ConfigEntry;
pub const Config = @import("gen_config.zig").Config;

pub const parse = @import("gen_config.zig").parse;
pub const getString = @import("gen_config.zig").getString;
pub const getNumber = @import("gen_config.zig").getNumber;
pub const getBool = @import("gen_config.zig").getBool;
