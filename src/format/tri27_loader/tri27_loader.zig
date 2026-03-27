//! TRI-27 Loader Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_tri27_loader.zig)
//! DO NOT EDIT: Modify format/tri27_loader.tri spec and regenerate

// Types and error handling
pub const LoadError = @import("gen_tri27_loader.zig").LoadError;
pub const LoadResult = @import("gen_tri27_loader.zig").LoadResult;

// Constants
pub const MAX_FILE_SIZE = @import("gen_tri27_loader.zig").MAX_FILE_SIZE;
pub const TRI27_MAGIC = @import("gen_tri27_loader.zig").TRI27_MAGIC;

// Load function
pub const loadBinary = @import("gen_tri27_loader.zig").loadBinary;
