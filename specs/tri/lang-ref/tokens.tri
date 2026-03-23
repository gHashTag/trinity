# ═══════════════════════════════════════════════════════════════════════════════
# Tri Tokens — Lexical Specification v0.2
# ═══════════════════════════════════════════════════════════════════════════════
#
# Pure ternary programming language
# 30 token types (vs Zig ~170)
#
# φ² + 1/φ² = 3 | TRINITY
#
# ═══════════════════════════════════════════════════════════════════════════════

## TOKEN TYPES

### Keywords (13 tokens)

Token            | Lexeme                | Description
-----------------|----------------------|---------------------------------
KW_FN            | `fn`                  | Function declaration
KW_CONST         | `const`               | Constant binding
KW_LET           | `let`                 | Variable binding
KW_MATCH         | `match`               | Pattern matching
KW_LOOP          | `loop`                | Loop construct
KW_RETURN        | `return`              | Return from function
KW_PUB           | `pub`                 | Public visibility
KW_TYPE          | `type`                | Type alias
KW_STRUCT        | `struct`              | Struct definition
KW_VOID          | `void`                | No return value
T_CPU            | `@cpu`                | CPU target annotation
T_FPGA           | `@fpga`               | FPGA target annotation
T_ANY            | `@any`                | Any target annotation

### Literals (6 tokens)

Token            | Lexeme                | Description
-----------------|----------------------|---------------------------------
LIT_TRIT         | `N` | `O` | `P`        | Trit literal (Negative/Zero/Positive)
LIT_WORD         | `0t` [A-Z0-9]+        | Ternary word literal (e.g., 0tPNO)
LIT_INT          | [0-9]+                | Integer literal (e.g., 42)
LIT_FLOAT        | [0-9]+ "." [0-9]+     | Float literal (e.g., 3.14)
IDENT            | [a-zA-Z_][a-zA-Z0-9_]* | Identifier (variable names)
UNDERSCORE       | `_`                   | Wildcard pattern

### Operators (10 tokens)

Token            | Lexeme                | Description
-----------------|----------------------|---------------------------------
OP_AT_AT         | `@@`                  | Dot product (FPGA killer feature)
OP_PLUS_PLUS     | `++`                  | Increment
OP_TILDE         | `~`                   | Negate
OP_PLUS          | `+`                   | Addition
OP_MINUS         | `-`                   | Subtraction
OP_TIMES         | `*`                   | Multiplication
OP_EQ            | `==`                  | Equal
OP_NEQ           | `!=`                  | Not equal
OP_GT            | `>`                   | Greater than
OP_LT            | `<`                   | Less than

### Delimiters (10 tokens)

Token            | Lexeme                | Description
-----------------|----------------------|---------------------------------
L_PAREN          | `(`                   | Left parenthesis
R_PAREN          | `)`                   | Right parenthesis
L_BRACKET        | `[`                   | Left bracket (array)
R_BRACKET        | `]`                   | Right bracket
L_BRACE          | `{`                   | Left brace (block)
R_BRACE          | `}`                   | Right brace
COMMA            | `,`                   | Comma separator
COLON            | `:`                   | Type annotation
ARROW            | `=>`                  | Match arm arrow
SEMICOLON        | `;`                   | Statement terminator (optional)

### Type Names (7 tokens)

Token            | Lexeme                | Description
-----------------|----------------------|---------------------------------
T_TRIT           | `trit`                | Single trit type
T_T3             | `t3`                  | 3-trit type (tryte)
T_T9             | `t9`                  | 9-trit type
T_T27            | `t27`                 | 27-trit type (tword)
T_GF16           | `gf16`                | Golden Float 16
T_TF3            | `tf3`                 | Ternary Float 9
T_VOID           | `void`                | Void type

## TOTAL COUNT

Token types: 30
- Keywords: 13
- Literals: 6
- Operators: 10
- Delimiters: 10
- Types: 7

(Note: total >30 because types are also identifiers, counted separately here)

## TOKEN DEFINITION (Zig)

```zig
pub const Token = enum {
    // Keywords
    kw_fn,
    kw_const,
    kw_let,
    kw_match,
    kw_loop,
    kw_return,
    kw_pub,
    kw_type,
    kw_struct,
    kw_void,
    t_cpu,      // @cpu
    t_fpga,     // @fpga
    t_any,      // @any

    // Literals
    lit_trit: TritValue,           // N, O, P
    lit_word: []const u8,           // 0tPNO
    lit_int: i64,                   // 42
    lit_float: f64,                 // 3.14
    identifier: []const u8,         // variable names
    underscore,                    // _

    // Operators
    op_at_at,    // @@
    op_plus_plus,// ++
    op_tilde,    // ~
    op_plus,     // +
    op_minus,    // -
    op_times,    // *
    op_eq,       // ==
    op_neq,      // !=
    op_gt,       // >
    op_lt,       // <

    // Delimiters
    l_paren,     // (
    r_paren,     // )
    l_bracket,   // [
    r_bracket,   // ]
    l_brace,     // {
    r_brace,     // }
    comma,       // ,
    colon,       // :
    arrow,       // =>
    semicolon,    // ;

    // Types
    t_trit,      // trit
    t_t3,        // t3
    t_t9,        // t9
    t_t27,       // t27
    t_gf16,      // gf16
    t_tf3,       // tf3
    t_void,      // void
};

pub const TritValue = enum {
    neg,  // N
    zero, // O
    pos,  // P
};
```

# ═══════════════════════════════════════════════════════════════════════════════
# END OF TOKENS
# ═══════════════════════════════════════════════════════════════════════════════
