// ═══════════════════════════════════════════════════════════════════════════════
// TS_BRIDGE — Compile-time feature detection for tree-sitter (Cycle 78)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Provides conditional access to tree-sitter bindings based on build options.
// When -Dtreesitter=true: imports real FFI modules from src/tvc/treesitter/
// When default (false): provides empty stubs so code compiles without C deps.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const build_options = @import("build_options");

/// Whether tree-sitter is available (set via -Dtreesitter=true)
pub const available = build_options.enable_treesitter;

// ═══════════════════════════════════════════════════════════════════════════════
// CONDITIONAL IMPORTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Tree-sitter Zig parser module (real FFI when available, empty stub otherwise)
pub const zig_parser = if (available) @import("treesitter_zig") else struct {
    pub const Parser = void;
    pub const Tree = void;
    pub const Node = void;
    pub const Point = void;
    pub const ChildIterator = void;

    pub fn createZigParser() error{LanguageNotFound}!void {
        return error.LanguageNotFound;
    }

    pub fn findNodesOfType(_: anytype, _: anytype, _: []const u8) error{LanguageNotFound}![]void {
        return error.LanguageNotFound;
    }
};

/// AST node extraction module (real when available, empty stub otherwise)
pub const ast_nodes = if (available) @import("treesitter_ast") else struct {
    pub const Language = void;
    pub const SymbolKind = void;
    pub const Symbol = void;
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE ALIASES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Node = if (available) zig_parser.Node else void;
pub const Parser = if (available) zig_parser.Parser else void;
pub const Point = if (available) zig_parser.Point else void;
pub const ChildIterator = if (available) zig_parser.ChildIterator else void;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ts_bridge_available_flag" {
    // available must match build option at compile time
    const expected = build_options.enable_treesitter;
    try std.testing.expectEqual(expected, available);
}

test "ts_bridge_stub_types" {
    // When tree-sitter is disabled, stub types should be void
    if (!available) {
        try std.testing.expect(Node == void);
        try std.testing.expect(Parser == void);
    }
}
