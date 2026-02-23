/**
 * Tree-sitter Grammar for VIBEE Specification Language
 * Cycle 70 - Semantic Trinity Core Ascension
 *
 * VIBEE is a YAML-like specification language for code generation.
 * This grammar enables AST parsing for semantic indexing.
 */

module.exports = grammar({
    name: 'vibee',

    extras: $ => [
        /\s/,          // whitespace
        /#.*/,         // comments
        /(?:\/\/|#).*$/ // line comments
    ],

    rules: {
        source_file: $ => repeat($._entry),

        _entry: $ => choice(
            $.module_declaration,
            $.type_definition,
            $.behavior_definition,
            $.algorithm_definition,
            $.test_case_definition,
            $.import_statement,
            $.constant_definition
        ),

        // Module declaration: name, version, language
        module_declaration: $ => seq(
            field('name', $.identifier),
            optional(seq(':', $.version_number)),
            field('language', choice('zig', 'varlog', 'python', 'typescript', 'verilog')),
            optional(field('module', $.identifier))
        ),

        version_number: $ => /"[\d.]+"/,

        // Type definition
        type_definition: $ => seq(
            field('kind', 'types'),
            ':',
            $.type_name,
            ':',
            optional(choice('struct', 'enum', 'union')),
            '{',
            repeat(choice(
                $.field_definition,
                $.constraint,
                $.default_value
            )),
            '}'
        ),

        type_name: $ => $.identifier,

        field_definition: $ => seq(
            $.identifier,
            ':',
            $.type_annotation
        ),

        type_annotation: $ => choice(
            $.primitive_type,
            $.list_type,
            $.optional_type,
            $.map_type,
            $.user_type
        ),

        primitive_type: $ => choice(
            'String', 'Int', 'Float', 'Bool', 'U8', 'U16', 'U32', 'U64',
            'I8', 'I16', 'I32', 'I64', 'Usize', 'f32', 'f64'
        ),

        list_type: $ => seq('List', '<', $.type_annotation, '>'),

        optional_type: $ => seq('Option', '<', $.type_annotation, '>'),

        map_type: $ => seq('Map', '<', $.type_annotation, ',', $.type_annotation, '>'),

        user_type: $ => $.identifier,

        constraint: $ => seq(
            'constraint',
            '=',
            $.constraint_expression
        ),

        constraint_expression: $ => choice(
            $.range_constraint,
            $.value_constraint,
            $.regex_constraint
        ),

        range_constraint: $ => seq('[', $.number, '..', $.number, ']'),

        value_constraint: $ => $.literal,

        regex_constraint: $ => /\/.*\/,

        default_value: $ => seq('default', '=', $.literal),

        // Behavior definition (Given/When/Then)
        behavior_definition: $ => seq(
            '-',
            'name:',
            $.identifier,
            field('given', $.precondition),
            field('when', $.action),
            field('then', $.result)
        ),

        precondition: $ => $.text_block,

        action: $ => $.text_block,

        result: $ => $.text_block,

        // Algorithm step-by-step definition
        algorithm_definition: $ => seq(
            field('kind', 'algorithms'),
            ':',
            $.algorithm_name,
            ':',
            optional(seq('input', $.type_annotation)),
            optional(seq('output', $.type_annotation)),
            '{',
            repeat($.algorithm_step),
            '}'
        ),

        algorithm_name: $ => $.identifier,

        algorithm_step: $ => seq(
            $.step_number,
            '.',
            $.step_description,
            optional(seq('->', $.step_result))
        ),

        step_number: $ => /\d+/,

        step_description: $ => $.text,

        step_result: $ => $.text,

        // Test case definition
        test_case_definition: $ => seq(
            '-',
            'name:',
            $.test_name,
            field('given', $.test_setup),
            field('when', $.test_action),
            field('then', $.test_expected)
        ),

        test_name: $ => $.identifier,

        test_setup: $ => choice($.code_block, $.literal),

        test_action: $ => choice($.code_block, $.expression),

        test_expected: $ => choice($.code_block, $.assertion),

        // Import statement
        import_statement: $ => seq(
            'import',
            $.string_literal,
            optional(seq('as', $.identifier))
        ),

        // Constant definition
        constant_definition: $ => seq(
            'const',
            $.identifier,
            '=',
            $.literal
        ),

        // Helper constructs
        text_block: $ => choice(
            $.multiline_string,
            $.text
        ),

        text: $ => /[^\n{}]+/,

        multiline_string: $ => seq(
            '|',
            repeat(choice($.text_line, $.empty_line))
        ),

        text_line: $ => /[^\n]+/,

        empty_line: $ => '\n',

        code_block: $ => seq(
            '```',
            optional($.language_identifier),
            repeat($.code_line),
            '```'
        ),

        language_identifier: $ => /[a-z]+/,

        code_line: $ => /[^\n]+/,

        expression: $ => /[^\n]+/,

        assertion: $ => choice(
            seq('assert', $.expression),
            seq('expect', $.expression)
        ),

        // Literals
        literal: $ => choice(
            $.string_literal,
            $.number,
            $.boolean,
            $.identifier
        ),

        string_literal: $ => /"[^"]*"/,

        number: $ => /\d+(\.\d+)?/,

        boolean: $ => choice('true', 'false'),

        identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/
    }
});

// Helper function for field names
function field(name, rule) {
    return {
        type: 'field',
        name: name,
        value: rule
    };
}
