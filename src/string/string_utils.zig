//! String Utilities Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_string_utils.zig)
//! DO NOT EDIT: Modify string_utils.tri spec and regenerate

// Trimming
pub const trim = @import("gen_string_utils.zig").trim;
pub const trimLeft = @import("gen_string_utils.zig").trimLeft;
pub const trimRight = @import("gen_string_utils.zig").trimRight;

// Searching
pub const startsWith = @import("gen_string_utils.zig").startsWith;
pub const endsWith = @import("gen_string_utils.zig").endsWith;
pub const contains = @import("gen_string_utils.zig").contains;

// Validation
pub const isAscii = @import("gen_string_utils.zig").isAscii;
pub const isAlnum = @import("gen_string_utils.zig").isAlnum;

// Comparison
pub const equalCaseInsensitive = @import("gen_string_utils.zig").equalCaseInsensitive;

// Concatenation
pub const join = @import("gen_string_utils.zig").join;

// Parsing
pub const parseInt = @import("gen_string_utils.zig").parseInt;
pub const formatInt = @import("gen_string_utils.zig").formatInt;

// Case conversion (allocator versions)
pub const toLowerAlloc = @import("gen_string_utils.zig").toLowerAlloc;
pub const toUpperAlloc = @import("gen_string_utils.zig").toUpperAlloc;
