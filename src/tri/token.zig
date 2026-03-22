//! Token type definitions for Tri language
//! v0.2 — 30 token types

pub const Token = union(enum) {
    // Keywords (13)
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
    t_cpu, // @cpu
    t_fpga, // @fpga
    t_any, // @any

    // Types (7)
    t_trit,
    t_t3,
    t_t9,
    t_t27,
    t_gf16,
    t_tf3,
    t_void,

    // Literals (6)
    lit_trit: TritValue,
    lit_word: []const u8,
    lit_int: i64,
    lit_float: f64,
    identifier: []const u8,
    underscore, // _

    // Operators (10)
    op_at_at, // @@
    op_plus_plus, // ++
    op_tilde, // ~
    op_plus, // +
    op_minus, // -
    op_times, // *
    op_assign, // =
    op_eq, // ==
    op_neq, // !=
    op_gt, // >
    op_lt, // <

    // Delimiters (10)
    l_paren, // (
    r_paren, // )
    l_bracket, // [
    r_bracket, // ]
    l_brace, // {
    r_brace, // }
    comma, // ,
    colon, // :
    arrow, // =>
    semicolon, // ;
};

pub const TritValue = enum {
    neg, // N
    zero, // O
    pos, // P
};
