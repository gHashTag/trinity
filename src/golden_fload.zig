//! GoldenFloat — Thin wrapper for zig-golden-float package
//!
//! This module re-exports from the golden_float package dependency.
//! Once the package is fully integrated, this file can be removed
//! and imports can use @import("golden-float") directly.

const std = @import("std");

// Import from golden-float package
const gf = @import("golden-float");

// Re-export formats from package
pub const formats = gf.formats;
