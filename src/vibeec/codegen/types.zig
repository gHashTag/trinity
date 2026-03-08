// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN TYPES - Type definitions and imports
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
pub const vibee_parser = @import("../vibee_parser.zig");
pub const parser_types = @import("../parser_types.zig");

pub const Allocator = std.mem.Allocator;
pub const ArrayList = std.ArrayListUnmanaged;

// Re-export parser types
pub const VibeeSpec = vibee_parser.VibeeSpec;
pub const ZigMode = parser_types.ZigMode;
pub const AllocatorStrategy = parser_types.AllocatorStrategy;
pub const Import = vibee_parser.Import;
pub const Constant = vibee_parser.Constant;
pub const TypeDef = vibee_parser.TypeDef;
pub const Field = vibee_parser.Field;
pub const CreationPattern = vibee_parser.CreationPattern;
pub const Behavior = vibee_parser.Behavior;
pub const TestCase = vibee_parser.TestCase;
