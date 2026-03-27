//! TRI Args Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const Arg = @import("gen_args.zig").Arg;
pub const ArgValue = @import("gen_args.zig").ArgValue;
pub const ParseResult = @import("gen_args.zig").ParseResult;

pub const parse = @import("gen_args.zig").parse;
pub const hasFlag = @import("gen_args.zig").hasFlag;
pub const getValue = @import("gen_args.zig").getValue;
pub const getPositional = @import("gen_args.zig").getPositional;
