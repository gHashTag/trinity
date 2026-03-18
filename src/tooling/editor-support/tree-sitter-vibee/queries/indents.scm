; ═══════════════════════════════════════════════════════════════════════════════
; Tree-sitter indentation rules for VIBEE DSL
; ═══════════════════════════════════════════════════════════════════════════════

; Indent after section keywords (types:, behaviors:, constants:, etc.)
(pair
  key: (section_keyword)
  !value) @indent.begin

; Indent after type sub-section keywords (fields:, enum:, constraints:)
(pair
  key: (type_keyword)
  !value) @indent.begin

; Indent after list item that contains a pair (- name: foo → indent for given/when/then)
(list_item (pair)) @indent.begin

; Flow sequences
(flow_sequence) @indent.begin

; Dedent on closing brackets
(flow_sequence "]" @indent.end)
