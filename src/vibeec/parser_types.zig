//! VIBEE Parser Types Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_parser_types.zig)
//! DO NOT EDIT: Modify parser_types.tri spec and regenerate

// Enums
pub const ZigMode = @import("gen_parser_types.zig").ZigMode;
pub const AllocatorStrategy = @import("gen_parser_types.zig").AllocatorStrategy;

// Core types
pub const Constant = @import("gen_parser_types.zig").Constant;
pub const Import = @import("gen_parser_types.zig").Import;
pub const ResetDef = @import("gen_parser_types.zig").ResetDef;
pub const Field = @import("gen_parser_types.zig").Field;
pub const CreationPattern = @import("gen_parser_types.zig").CreationPattern;
pub const TestCase = @import("gen_parser_types.zig").TestCase;
pub const MemoryExport = @import("gen_parser_types.zig").MemoryExport;
pub const PasPrediction = @import("gen_parser_types.zig").PasPrediction;

// Composite types
pub const TypeDef = @import("gen_parser_types.zig").TypeDef;
pub const Behavior = @import("gen_parser_types.zig").Behavior;
pub const Algorithm = @import("gen_parser_types.zig").Algorithm;

// Specification root
pub const VibeeSpec = @import("gen_parser_types.zig").VibeeSpec;

// Utility functions
pub const makeField = @import("gen_parser_types.zig").makeField;
pub const makeTestCase = @import("gen_parser_types.zig").makeTestCase;
