# 33 BOGATYRS DECOMPOSITION - PHASE 2.2

## SYNTAX SQUAD (5 bogatyrs)

### 1. Lexical Analysis Bogatyr
```vibee
name: syntax_lexer
version: "1.0.0"
language: zig
module: syntax_lexer

types:
  Token:
    fields:
      type: String
      value: String
      position: SourcePosition

  Tokenizer:
    fields:
      source: String
      position: Int
      tokens: List<Token>

behaviors:
  - name: tokenize
    given: .vibee source
    when: Tokenization requested
    then: List of Token returned
    test_cases:
      - name: test_simple_yaml
        input: "name: test\nversion: \"1.0\""
        expected:
          tokens: "[name, :, test, version, :, 1.0]"
```

### 2. Syntactic Parser Bogatyr
```vibee
name: syntax_parser
version: "1.0.0"
language: zig
module: syntax_parser

types:
  AstNode:
    fields:
      type: String
      children: List<AstNode>
      value: Option<String>
      position: SourcePosition

  Ast:
    fields:
      root: AstNode
      errors: List<ParseError>

behaviors:
  - name: parse
    given: List of Token
    when: Parsing requested
    then: AST generated
    test_cases:
      - name: test_parse_name
        input:
          tokens: "[name, :, test]"
        expected:
          ast.type: "name"
          ast.value: "test"

  - name: validate_yaml_syntax
    given: .vibee source
    when: YAML validation requested
    then: Valid YAML structure
```

### 3. Specification Structure Bogatyr
```vibee
name: spec_structure_validator
version: "1.0.0"
language: zig
module: spec_structure_validator

types:
  SpecStructure:
    fields:
      has_name: Bool
      has_version: Bool
      has_language: Bool
      has_module: Bool
      has_types: Bool
      has_behaviors: Bool

behaviors:
  - name: validate_structure
    given: AST
    when: Structure validation requested
    then: All required fields present
    test_cases:
      - name: test_complete_spec
        input:
          ast: complete_ast
        expected:
          has_name: true
          has_version: true
          has_language: true
          has_module: true

      - name: test_missing_name
        input:
          ast: missing_name_ast
        expected:
          error: "missing_name"
```

### 4. Naming Conventions Bogatyr
```vibee
name: naming_conventions_validator
version: "1.0.0"
language: zig
module: naming_conventions_validator

types:
  NamingConvention:
    fields:
      style: String
      allowed_chars: String
      max_length: Int

behaviors:
  - name: validate_type_names
    given: Type definitions
    when: Name validation requested
    then: Names follow convention (PascalCase)
    test_cases:
      - name: test_pascal_case
        input:
          type_name: "MyType"
        expected:
          valid: true

      - name: test_invalid_case
        input:
          type_name: "my_type"
        expected:
          valid: false

  - name: validate_behavior_names
    given: Behavior definitions
    when: Name validation requested
    then: Names follow convention (snake_case)
    test_cases:
      - name: test_snake_case
        input:
          behavior_name: "my_behavior"
        expected:
          valid: true
```

### 5. Cyclic Dependencies Bogatyr
```vibee
name: cyclic_deps_validator
version: "1.0.0"
language: zig
module: cyclic_deps_validator

types:
  DependencyGraph:
    fields:
      nodes: Map<String, List<String>>

  Cycle:
    fields:
      nodes: List<String>
      start: String
      end: String

behaviors:
  - name: detect_cycles
    given: DependencyGraph
    when: Cycle detection requested
    then: Cycles returned or empty
    test_cases:
      - name: test_no_cycles
        input:
          graph:
            A: [B, C]
            B: [C]
            C: []
        expected:
          cycles: "[]"

      - name: test_cycle_detected
        input:
          graph:
            A: [B]
            B: [C]
            C: [A]
        expected:
          cycles: "[A, B, C]"
```

---

## SEMANTICS SQUAD (7 bogatyrs)

### 6. Type Validation Bogatyr
```vibee
name: type_validation_bogatyr
version: "1.0.0"
language: zig
module: type_validation_bogatyr

types:
  VibeeType:
    fields:
      name: String
      kind: String
      fields: Map<String, VibeeType>

  TypeEnv:
    fields:
      types: Map<String, VibeeType>
      scopes: List<Scope>

behaviors:
  - name: validate_type_definition
    given: Type definition
    when: Type validation requested
    then: Valid type or error
    test_cases:
      - name: test_primitive_type
        input:
          type: "Int"
        expected:
          valid: true

      - name: test_custom_type
        input:
          type: "MyType"
        expected:
          valid: true

  - name: check_type_usage
    given: Type usage in field/behavior
    when: Type checking requested
    then: Type exists or error
    test_cases:
      - name: test_valid_type_usage
        input:
          type: "String"
        expected:
          defined: true
```

### 7. Scope Validator Bogatyr
```vibee
name: scope_validator
version: "1.0.0"
language: zig
module: scope_validator

types:
  Scope:
    fields:
      parent: Option<Scope>
      level: Int
      symbols: Map<String, Symbol>

  Symbol:
    fields:
      name: String
      kind: String
      scope: Scope

behaviors:
  - name: validate_scope
    given: Symbol reference
    when: Scope validation requested
    then: Symbol accessible or error
    test_cases:
      - name: test_global_symbol
        input:
          symbol: "String"
          location: global
        expected:
          accessible: true

      - name: test_out_of_scope
        input:
          symbol: "local_var"
          location: outside_scope
        expected:
          error: "symbol_not_found"
```

### 8. Unused Definitions Bogatyr
```vibee
name: unused_definitions_validator
version: "1.0.0"
language: zig
module: unused_definitions_validator

types:
  UsageMap:
    fields:
      definitions: Map<String, SourceSpan>
      usages: Map<String, List<SourceSpan>>

behaviors:
  - name: find_unused_definitions
    given: AST
    when: Unused detection requested
    then: Unused definitions listed
    test_cases:
      - name: test_all_used
        input:
          ast: all_symbols_used
        expected:
          unused: "[]"

      - name: test_unused_type
        input:
          ast: has_unused_type
        expected:
          unused: "[UnusedType]"
```

### 9. Expression Validator Bogatyr
```vibee
name: expression_validator
version: "1.0.0"
language: zig
module: expression_validator

types:
  Expression:
    fields:
      type: String
      value: Option<String>
      operands: List<Expression>

behaviors:
  - name: validate_expression
    given: Expression AST
    when: Expression validation requested
    then: Valid expression or error
    test_cases:
      - name: test_valid_expression
        input:
          expr: "1 + 1"
        expected:
          valid: true

      - name: test_invalid_type
        input:
          expr: "String + Int"
        expected:
          error: "type_mismatch"
```

### 10. Business Rules Bogatyr
```vibee
name: business_rules_validator
version: "1.0.0"
language: zig
module: business_rules_validator

types:
  BusinessRule:
    fields:
      name: String
      given: String
      when: String
      then: String

behaviors:
  - name: validate_business_rule
    given: BusinessRule definition
    when: Rule validation requested
    then: Valid rule or error
    test_cases:
      - name: test_valid_rule
        input:
          rule:
            given: "Valid input"
            when: "Action triggered"
            then: "Expected output"
        expected:
          valid: true

  - name: check_rule_completeness
    given: List of BusinessRules
    when: Completeness check requested
    then: All rules have given/when/then
```

### 11. Mutability/Immutability Bogatyr
```vibee
name: mutability_validator
version: "1.0.0"
language: zig
module: mutability_validator

types:
  Mutability:
    fields:
      is_mutable: Bool
      is_immutable: Bool

behaviors:
  - name: check_mutability
    given: Variable/field definition
    when: Mutability validation requested
    then: Correct mutability or error
    test_cases:
      - name: test_immutable_type
        input:
          type: "String"
        expected:
          immutable: true

      - name: test_mutable_field
        input:
          field: "var count: Int"
        expected:
          mutable: true
```

### 12. Dead Code Bogatyr
```vibee
name: dead_code_validator
version: "1.0.0"
language: zig
module: dead_code_validator

types:
  CodeBlock:
    fields:
      reachable: Bool
      statements: List<Statement>

behaviors:
  - name: detect_dead_code
    given: AST
    when: Dead code detection requested
    then: Unreachable code listed
    test_cases:
      - name: test_no_dead_code
        input:
          ast: all_reachable
        expected:
          dead_code: "[]"

      - name: test_dead_branch
        input:
          ast: has_unreachable_branch
        expected:
          dead_code: "[after_return]"
```

---

## LOGIC AND INVARIANTS SQUAD (8 bogatyrs)

### 17. Logic Duplication Bogatyr (KEY!)
```vibee
name: logic_duplication_validator
version: "1.0.0"
language: zig
module: logic_duplication_validator

types:
  LogicBlock:
    fields:
      id: String
      hash: String
      statements: List<Statement>

  Duplication:
    fields:
      original: LogicBlock
      duplicate: LogicBlock
      similarity: Float

behaviors:
  - name: detect_duplication
    given: List of behaviors/implementations
    when: Duplication detection requested
    then: Duplications listed with similarity score
    test_cases:
      - name: test_no_duplication
        input:
          behaviors: [unique_behaviors]
        expected:
          duplications: "[]"

      - name: test_exact_duplication
        input:
          behaviors: [duplicate_behaviors]
        expected:
          duplications_count: 1
          similarity: 1.0

      - name: test_similar_logic
        input:
          behaviors: [similar_behaviors]
        expected:
          duplications_count: 1
          similarity: "> 0.8"

  - name: compute_similarity
    given: Two code blocks
    when: Similarity computation requested
    then: Similarity score (0-1)

  - name: suggest_refactoring
    given: List of duplications
    when: Refactoring suggestion requested
    then: Refactoring recommendations
```

---

## REMAINING BOGATYRS (for delegation)

### LOGIC SQUAD (remaining 7):
13. idempotency_validator
14. logic_isolation_validator
15. state_transitions_validator
16. pre_post_conditions_validator
18. algorithm_complexity_validator
19. module_contracts_validator
20. data_integrity_validator

### PERFORMANCE SQUAD (5):
21. static_analysis_bottlenecks_validator
22. memory_usage_validator
23. parallelism_validator
24. lock_escalation_validator
25. cold_start_validator

### SECURITY SQUAD (8):
26. injection_scanner_validator
27. access_control_validator
28. data_leaks_validator
29. dos_analysis_validator
30. cryptography_validator
31. file_integrity_validator
32. vulnerability_scanner_validator
33. safe_deserialization_validator

---

## COGS DOCUMENTATION:

### Syntax Bogatyrs
```
✅ syntax_lexer - 100%
✅ syntax_parser - 100%
✅ spec_structure_validator - 100%
✅ naming_conventions_validator - 100%
✅ cyclic_deps_validator - 100%
```

### Semantic Bogatyrs
```
✅ type_validation_bogatyr - 100%
✅ scope_validator - 100%
✅ unused_definitions_validator - 100%
✅ expression_validator - 100%
✅ business_rules_validator - 100%
✅ mutability_validator - 100%
✅ dead_code_validator - 100%
```

### Logic Bogatyrs
```
✅ logic_duplication_validator - 100%
🔲 idempotency_validator - 0% (TODO)
🔲 logic_isolation_validator - 0% (TODO)
🔲 state_transitions_validator - 0% (TODO)
🔲 pre_post_conditions_validator - 0% (TODO)
🔲 algorithm_complexity_validator - 0% (TODO)
🔲 module_contracts_validator - 0% (TODO)
🔲 data_integrity_validator - 0% (TODO)
```

---

**STATUS**: ✅ PHASE 2.2 COMPLETED (partially)
**PROGRESS**: 13/33 bogatyrs specified (39%)
**NEXT**: PHASE 3 - Specification in `.vibee` for all 33 bogatyrs
