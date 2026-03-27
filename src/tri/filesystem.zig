//! TRI Filesystem Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const PathError = @import("gen_filesystem.zig").PathError;
pub const FileInfo = @import("gen_filesystem.zig").FileInfo;

pub const separator = @import("gen_filesystem.zig").separator;
pub const join = @import("gen_filesystem.zig").join;
pub const basename = @import("gen_filesystem.zig").basename;
pub const dirname = @import("gen_filesystem.zig").dirname;
pub const ext = @import("gen_filesystem.zig").ext;
pub const hasExt = @import("gen_filesystem.zig").hasExt;
pub const isAbsolute = @import("gen_filesystem.zig").isAbsolute;
pub const normalize = @import("gen_filesystem.zig").normalize;
