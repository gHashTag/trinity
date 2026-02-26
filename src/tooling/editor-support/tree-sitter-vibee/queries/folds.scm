; ═══════════════════════════════════════════════════════════════════════════════
; Tree-sitter folding rules for VIBEE DSL
; ═══════════════════════════════════════════════════════════════════════════════

; Fold section blocks (types:, behaviors:, constants:, etc.)
(pair
  key: (section_keyword)
  !value) @fold

; Fold type sub-sections (fields:, enum:, constraints:)
(pair
  key: (type_keyword)
  !value) @fold

; Fold flow sequences
(flow_sequence) @fold
