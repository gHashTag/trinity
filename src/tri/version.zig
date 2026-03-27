//! TRI Version Module Selector
pub const Version = @import("gen_version.zig").Version;
pub const VersionReq = @import("gen_version.zig").VersionReq;
pub const RequirementOp = @import("gen_version.zig").RequirementOp;
pub const Ordering = @import("gen_version.zig").Ordering;
pub const parse = @import("gen_version.zig").parse;
pub const satisfies = @import("gen_version.zig").satisfies;
pub const compare = @import("gen_version.zig").compare;
