// ═══════════════════════════════════════════════════════════════════
// tri_lang_tests.zig - Tests for ADT Enum + Match + Pipe (Issue #408)
// ═════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// ═════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ast = @import("ast.zig");
const Lexer = @import("lexer.zig");

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════

// ADT enum: data-carrying enum like Rust's Option<T>
test "adt_enum_basic" {
    const src =
        \\enum Result(trit, error) {
        \\    Ok(value: trit),
        \\    Err(msg: string),
        \\}
    ;

    _ = src; // TODO: implement parse
    // const result = try parse(src);
    // try std.testing.expectEqual(@as(ast.Node, result).?, .EnumDef);
}

// Match: Rust-style exhaustive pattern matching
test "exhaustive_match_pattern" {
    const src =
        \\fn classify(signal: trit) Quality {
        \\    match signal {
        \\        .pos => .good,
        \\        .zero => .unknown,
        \\        .neg => .bad,
        \\    }
        \\}
    ;

    _ = src; // TODO: implement parse
    // const result = try parse(src);
    // try std.testing.expectEqual(@as(ast.Node, result).?, .Function);
    // try std.testing.expect(@as(ast.Node, result).Function.body.len == 1); // One match statement
}

// Pipe: Elixir-style |> operator for function chaining
test "pipe_operator_basic" {
    // TODO: Implement parse function
    const src = "let result = input";
    _ = src;
}

// Pipe with 3+ stages
test "pipe_with_multiple_stages" {
    // TODO: Implement parse function
    const src = "let result = input";
    _ = src;
}

test "guard_condition" {
// Guard: Haskell-style | condition in match arm
    const src =
        \\fn check(x: i32) bool {
            match x {
                v | v > 10 => true,
                v => false,
            }
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Function);
}

test "guard_with_expression" {
// Guard with boolean expression
    const src =
        \\fn check(x: i32) bool {
            match x {
                v | x > 0 and x < 100 => true,
                _ => false,
            }
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Function);
}

test "named_pipeline_reference" {
// Named pipeline: pipeline_name reference
    const src =
        \\let result = data |> my_pipeline

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Let);
}

test "pattern_enum_variant" {
// Pattern: enum variant with data
    const src =
        \\match value {
            Active(level) => activate(level),
            Inhibited => decay(),
            Resting(potential) => check_threshold(potential),
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Match);
}

test "pattern_wildcard" {
// Pattern: wildcard _ matches anything
    const src =
        \\match value {
            _ => default_action(),
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Match);
}

test "pattern_array_literal" {
// Pattern: array literal [1, 2, 3]
    const src =
        \\match data {
            [1, 2] => handle_pair(),
            _ => handle_other(),
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Match);
}

test "ternary_literal_trit" {
// Ternary literal: 'tr' for trit value
    const src =
        \\fn test_trit() trit {
            return 'tr';
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Function);
}

test "range_pattern_inclusive" {
// Range pattern: start..=end (inclusive)
    const src =
        \\match value {
            0..=10 => in_range(),
            _ => out_of_range(),
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Match);
}

test "range_pattern_exclusive" {
// Range pattern: start..end (exclusive)
    const src =
        \\match value {
            0..10 => in_range(),
            _ => out_of_range(),
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Match);
}

test "struct_pattern_with_fields" {
// Pattern: struct with field patterns
    const src =
        \\match point {
            Point { x, y } => has_x_y(),
            Point { x, y, z } => has_xyz(),
        }

    const result = try parse(src);
    try std.testing.expectEqual(@as(ast.Node, result).?, .Match);
}

/// Helper: parse Tri source to AST
fn parse(src: []const u8) !ast.Node {
    var parser = try ast.Parser.init(src, std.testing.allocator);
    const program = try parser.parseProgram();

    // Get first node (assuming single declaration)
    if (program.len == 0) return error.ProgramEmpty;
    return program[0];
}
