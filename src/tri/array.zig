//! TRI Array Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const ArrayViewi32 = @import("gen_array.zig").ArrayViewi32;
pub const SliceRange = @import("gen_array.zig").SliceRange;

pub const slice = @import("gen_array.zig").slice;
pub const sliceFrom = @import("gen_array.zig").sliceFrom;
pub const first = @import("gen_array.zig").first;
pub const last = @import("gen_array.zig").last;
pub const isEmpty = @import("gen_array.zig").isEmpty;
pub const contains = @import("gen_array.zig").contains;
pub const indexOf = @import("gen_array.zig").indexOf;
pub const reverse = @import("gen_array.zig").reverse;
pub const concat = @import("gen_array.zig").concat;

pub const sliceBytes = @import("gen_array.zig").sliceBytes;
pub const containsByte = @import("gen_array.zig").containsByte;
pub const indexOfByte = @import("gen_array.zig").indexOfByte;
pub const reverseBytes = @import("gen_array.zig").reverseBytes;
pub const concatBytes = @import("gen_array.zig").concatBytes;
