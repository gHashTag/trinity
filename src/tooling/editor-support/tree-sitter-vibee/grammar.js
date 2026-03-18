// ═══════════════════════════════════════════════════════════════════════════════
// Tree-sitter grammar for VIBEE DSL
// VIBEE is a YAML-like specification language for the Trinity project.
// Supports: metadata, constants, types, behaviors, algorithms, HDL, and more.
//
// Install: npm install && npx tree-sitter generate
// Test:    npx tree-sitter test
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

'use strict';

module.exports = grammar({
  name: 'vibee',

  word: $ => $.plain_identifier,

  extras: $ => [
    /\s/,
    $.comment,
  ],

  conflicts: $ => [
    [$.pair],
  ],

  rules: {
    // ─────────────────────────────────────────────────────────────────────────
    // TOP LEVEL: A .vibee file is a sequence of key-value pairs
    // This mirrors YAML: every line is either a comment, a pair, or a list item
    // ─────────────────────────────────────────────────────────────────────────
    source_file: $ => repeat($._entry),

    _entry: $ => choice(
      $.pair,
      $.list_item,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // PAIR: key: value (the fundamental unit of VIBEE)
    // Covers: metadata (name: foo), sections (types:), fields (x: Int), etc.
    // ─────────────────────────────────────────────────────────────────────────
    pair: $ => seq(
      field('key', $._key),
      ':',
      optional(field('value', $._value)),
    ),

    _key: $ => choice(
      $.section_keyword,
      $.type_keyword,
      $.behavior_keyword,
      $.identifier,
      $.quoted_string,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION KEYWORDS: recognized section names get special highlighting
    // ─────────────────────────────────────────────────────────────────────────
    section_keyword: $ => choice(
      'name', 'version', 'language', 'module', 'description', 'author', 'license',
      'constants', 'types', 'behaviors', 'algorithms', 'imports',
      'creation_patterns', 'wasm_exports', 'pas_predictions',
      'signals', 'fsm', 'reset', 'test_cases', 'tests', 'cli', 'theorems',
      'targets', 'fpga_target', 'pipeline', 'target_frequency',
    ),

    // Sub-section keywords within types, behaviors, etc.
    type_keyword: $ => choice(
      'fields', 'enum', 'constraints', 'base', 'generic',
      'functions', 'memory', 'states', 'transitions', 'outputs', 'timers', 'flags',
    ),

    // BDD keywords within behaviors
    behavior_keyword: $ => choice(
      'given', 'when', 'then', 'implementation',
      'input', 'expected', 'tolerance',
      'complexity', 'pattern', 'steps', 'formula',
      'source', 'transformer', 'result',
      'target', 'current', 'predicted', 'confidence', 'status', 'timeline',
      'width', 'direction', 'signed', 'default',
      'initial', 'encoding', 'from', 'to',
      'type', 'level', 'short', 'category',
      'id', 'statement', 'significance',
      'size', 'alignment',
      'scope', 'timeout_constant', 'timeout_value',
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // VALUES: everything that can appear after ':'
    // ─────────────────────────────────────────────────────────────────────────
    _value: $ => choice(
      $.quoted_string,
      $.multiline_string,
      $.float_number,
      $.number,
      $.boolean,
      $.null_value,
      $.type_expression,
      $.flow_sequence,
      $.identifier,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // LIST ITEM: - value or - key: value
    // ─────────────────────────────────────────────────────────────────────────
    list_item: $ => seq(
      '-',
      choice(
        $.pair,
        $._value,
      ),
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // TYPE EXPRESSIONS: List<String>, Map<K,V>, Option<T>, Set<Int>
    // ─────────────────────────────────────────────────────────────────────────
    type_expression: $ => seq(
      field('name', $.generic_type_name),
      '<',
      commaSep1($.type_argument),
      '>',
    ),

    generic_type_name: $ => choice(
      'List', 'Set', 'Map', 'Option', 'Array', 'Dict', 'Tuple',
    ),

    type_argument: $ => choice(
      $.type_expression,
      $.identifier,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FLOW SEQUENCE: [a, b, c] — inline arrays
    // ─────────────────────────────────────────────────────────────────────────
    flow_sequence: $ => seq(
      '[',
      optional(commaSep1($._flow_value)),
      optional(','),
      ']',
    ),

    _flow_value: $ => choice(
      $.quoted_string,
      $.float_number,
      $.number,
      $.boolean,
      $.null_value,
      $.identifier,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // LITERALS
    // ─────────────────────────────────────────────────────────────────────────
    quoted_string: $ => seq(
      '"',
      repeat(choice(
        $.string_content,
        $.escape_sequence,
        $.interpolation,
      )),
      '"',
    ),

    string_content: $ => token.immediate(/[^"\\$]+|\$[^{"]/),

    escape_sequence: $ => token.immediate(
      /\\[nrt\\\/"'0abfv]|\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8}/,
    ),

    interpolation: $ => seq(
      token.immediate('${'),
      $.identifier,
      '}',
    ),

    multiline_string: $ => seq(
      token('|'),
      /[^\n]*/,
    ),

    float_number: $ => /[0-9]+\.[0-9]+/,

    number: $ => /[0-9]+/,

    boolean: $ => choice('true', 'false'),

    null_value: $ => choice('null', 'nil', 'none'),

    // Identifiers: allow hyphens and dots for YAML-style keys
    identifier: $ => choice(
      $.plain_identifier,
      $.dotted_identifier,
    ),

    plain_identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    dotted_identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)+/,

    // ─────────────────────────────────────────────────────────────────────────
    // COMMENTS: # to end of line
    // ─────────────────────────────────────────────────────────────────────────
    comment: $ => token(seq('#', /.*/)),
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}

function commaSep(rule) {
  return optional(commaSep1(rule));
}
