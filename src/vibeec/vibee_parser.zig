//! VIBEE Parser Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_vibee_parser.zig)
//! DO NOT EDIT: Modify vibee_parser.tri spec and regenerate

// Parser types (re-exported from gen_parser_types)
pub const VibeeSpec = @import("gen_vibee_parser.zig").VibeeSpec;
pub const TypeDef = @import("gen_vibee_parser.zig").TypeDef;
pub const Behavior = @import("gen_vibee_parser.zig").Behavior;
pub const Field = @import("gen_vibee_parser.zig").Field;
pub const TestCase = @import("gen_vibee_parser.zig").TestCase;
pub const Constant = @import("gen_vibee_parser.zig").Constant;
pub const Algorithm = @import("gen_vibee_parser.zig").Algorithm;
pub const Import = @import("gen_vibee_parser.zig").Import;

// Parse result
pub const ParseResult = @import("gen_vibee_parser.zig").ParseResult;

// Parser functions
pub const parse = @import("gen_vibee_parser.zig").parse;
pub const parseFile = @import("gen_vibee_parser.zig").parseFile;
pub const parseKeyValue = @import("gen_vibee_parser.zig").parseKeyValue;
pub const isComment = @import("gen_vibee_parser.zig").isComment;
pub const isEmptyLine = @import("gen_vibee_parser.zig").isEmptyLine;
pub const getIndentLevel = @import("gen_vibee_parser.zig").getIndentLevel;
pub const isListItem = @import("gen_vibee_parser.zig").isListItem;
pub const extractListItem = @import("gen_vibee_parser.zig").extractListItem;
pub const identifySection = @import("gen_vibee_parser.zig").identifySection;

// Validation
pub const validate = @import("gen_vibee_parser.zig").validate;
