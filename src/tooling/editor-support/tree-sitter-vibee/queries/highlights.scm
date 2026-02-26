; ═══════════════════════════════════════════════════════════════════════════════
; Tree-sitter highlights for VIBEE DSL
; phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
; ═══════════════════════════════════════════════════════════════════════════════

; ─── Section Keywords (top-level) ─────────────────────────────────────────────

(section_keyword) @keyword

; ─── Type Sub-section Keywords ────────────────────────────────────────────────

(type_keyword) @keyword.type

; ─── BDD / Behavior Keywords ─────────────────────────────────────────────────

(behavior_keyword) @keyword.directive

; ─── Generic Type Names ──────────────────────────────────────────────────────

(generic_type_name) @type.builtin

; ─── Type Arguments (type names after <) ─────────────────────────────────────

(type_argument (identifier) @type)

; ─── Type Expressions ────────────────────────────────────────────────────────

(type_expression "<" @punctuation.bracket)
(type_expression ">" @punctuation.bracket)

; ─── Pair keys ───────────────────────────────────────────────────────────────

(pair key: (identifier) @property)
(pair key: (quoted_string) @property)

; ─── Pair values ─────────────────────────────────────────────────────────────

(pair value: (identifier) @string.special)

; ─── Strings ─────────────────────────────────────────────────────────────────

(quoted_string) @string
(string_content) @string
(multiline_string) @string

; ─── String special ──────────────────────────────────────────────────────────

(escape_sequence) @string.escape
(interpolation) @embedded
(interpolation "${" @punctuation.special)
(interpolation "}" @punctuation.special)

; ─── Numbers ─────────────────────────────────────────────────────────────────

(number) @number
(float_number) @number.float

; ─── Booleans ────────────────────────────────────────────────────────────────

(boolean) @boolean

; ─── Null ────────────────────────────────────────────────────────────────────

(null_value) @constant.builtin

; ─── Flow sequences ──────────────────────────────────────────────────────────

(flow_sequence "[" @punctuation.bracket)
(flow_sequence "]" @punctuation.bracket)

; ─── List items ──────────────────────────────────────────────────────────────

(list_item "-" @punctuation.special)

; ─── Punctuation ─────────────────────────────────────────────────────────────

(pair ":" @punctuation.delimiter)

; ─── Comments ────────────────────────────────────────────────────────────────

(comment) @comment

; ─── Special identifiers ─────────────────────────────────────────────────────

((identifier) @variable.builtin
  (#match? @variable.builtin "^(self|ctx|state)$"))

; ─── Sacred constants ────────────────────────────────────────────────────────

((identifier) @constant
  (#match? @constant "^[A-Z][A-Z0-9_]+$"))

; ─── Known type names ────────────────────────────────────────────────────────

((identifier) @type
  (#match? @type "^(Int|Float|Bool|String|Timestamp|Object|Trit|TritVector)$"))
