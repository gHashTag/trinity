//! Math Format Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_format.zig)
//! DO NOT EDIT: Modify format.tri spec and regenerate

// Color styles
pub const ColorStyle = @import("gen_format.zig").ColorStyle;

// Types
pub const OutputFormat = @import("gen_format.zig").OutputFormat;
pub const Alignment = @import("gen_format.zig").Alignment;
pub const FormatConfig = @import("gen_format.zig").FormatConfig;
pub const TableColumn = @import("gen_format.zig").TableColumn;
pub const TableFormat = @import("gen_format.zig").TableFormat;

// Functions
pub const printColored = @import("gen_format.zig").printColored;
pub const formatFloat = @import("gen_format.zig").formatFloat;
pub const formatIntGrouped = @import("gen_format.zig").formatIntGrouped;
pub const printTableHeader = @import("gen_format.zig").printTableHeader;
pub const printTableRow = @import("gen_format.zig").printTableRow;
pub const printTableFooter = @import("gen_format.zig").printTableFooter;
pub const exportCsv = @import("gen_format.zig").exportCsv;
pub const padString = @import("gen_format.zig").padString;

// Templates
pub const CONSTANTS_TABLE_COLUMNS = @import("gen_format.zig").CONSTANTS_TABLE_COLUMNS;
pub const COMPARE_TABLE_COLUMNS = @import("gen_format.zig").COMPARE_TABLE_COLUMNS;
