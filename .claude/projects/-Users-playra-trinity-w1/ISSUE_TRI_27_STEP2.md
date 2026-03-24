# Issue: TRI-27 Idiom 11 — Complete Contract System (AST Rewrite + DSL Parser)

## Context

TRI-27 Idiom 11 spec-in-code annotations infrastructure is PARTIALLY complete:

### ✅ Already Done
- `tri spec audit` — Scanner and coverage reporting working
- `tri spec apply` — Type inference (`inferSpecName`, `inferRequires`, `inferEnsures`)
- `contract_dsl.zig` — Tokenizer for expressions
- `contract_checker.zig` — Basic type checking skeleton
- GitHub Actions workflow — `--fail-below N` blocks PRs
- Main.zig routing — `tri spec audit/apply/help` wired up

### ❌ Remaining
1. AST-based file modification in `tri_spec_apply.zig`
2. Full expression parser in `contract_dsl.zig` (precedence, parentheses, ranges)
3. Complete `contract_checker.zig` (type checking + assertion generation)
4. Fix 11 pre-existing build errors in `tri_farm.zig` / `tri_fpga.zig`

---

## Tasks

### Task 1: AST-based Rewrite in `tri_spec_apply.zig`

**Goal**: Modify .tri files idempotently by inserting/updating spec annotations.

**Acceptance Criteria**:
- [ ] Parse .tri file into AST (using existing `vibee_parser` or lightweight YAML parser)
- [ ] For each behavior, check if `spec/require/ensure/example` exists
- [ ] Insert missing annotations at correct indent (4 spaces)
- [ ] Update existing annotations without duplicating
- [ ] Support `--dry-run` to preview changes
- [ ] Support `--confirm` flag for interactive approval

**Example**:
```yaml
# Before
behaviors:
  - name: computeSpiral
    params:
      - name: n
        type: "u32"
    returns: "PhiSpiral"

# After (tri spec apply)
behaviors:
  - name: computeSpiral
    spec: compute_spiral_coordinates
    require: "n >= 0"
    ensure: "angle in [0, 2π] and radius > 0"
    example:
      input: "n=0"
      expect: "angle=0° r=30 x=30.000 y=0.000"
    params:
      - name: n
        type: "u32"
    returns: "PhiSpiral"
```

---

### Task 2: Complete Expression Parser in `contract_dsl.zig`

**Goal**: Parse full contract expressions with operator precedence.

**Acceptance Criteria**:
- [ ] Implement `parseExpression()` with precedence climbing
- [ ] Support: `and`, `or`, `not` (logical)
- [ ] Support: `<`, `<=`, `>`, `>=`, `==`, `!=` (comparison)
- [ ] Support: `+`, `-`, `*`, `/`, `%` (arithmetic)
- [ ] Support: `in [min, max]` (range membership)
- [ ] Support: parentheses `(...)`
- [ ] Support: function calls `isValid(x, y)`
- [ ] Unit tests for each operator precedence level

**EBNF Reference**:
```
<expression> ::= <or_expr>
<or_expr>    ::= <and_expr> ( "or" <and_expr> )*
<and_expr>   ::= <comparison> ( "and" <comparison> )*
<comparison> ::= <term> ( ("<=" | ">=" | "<" | ">" | "==" | "!=" | "in" ) <term> )*
<term>       ::= <factor> ( "+" | "-" ) <factor>
<factor>     ::= <unary> ( "*" | "/" | "%" ) <unary>
<unary>      ::= "not" <unary> | "-" <unary> | <primary>
<primary>    ::= <literal> | <identifier> | <range> | <call> | "(" <expression> ")"
<range>      ::= "[" <expression> "," <expression> "]"
<call>       ::= <identifier> "(" [ <args> ] ")"
```

---

### Task 3: Complete Contract Checker in `contract_checker.zig`

**Goal**: Type-check contracts and generate runtime assertions.

**Acceptance Criteria**:
- [ ] `checkContract()` validates expression type vs function signature
- [ ] `verifyContract()` attempts compile-time proof (for simple expressions)
- [ ] `generateAssertion()` emits Zig code:
  ```zig
  debug.assert(x >= 0, "contract violated: x >= 0");
  ```
- [ ] Support for range expressions: `x in [0, 100]` → `x >= 0 and x <= 100`
- [ ] Report specific error messages with line/column info
- [ ] Integration with `tri spec audit` to check contract validity

---

### Task 4: Fix Pre-existing Build Errors (Separate)

**Goal**: Green build for `tri` binary.

**Files**: `src/tri/tri_farm.zig`, `src/tri/fpga_fly.zig`

**Errors**:
- 11× unused capture (`catch |_|` without using `err`)
- 1× unused local constant
- 1× unexpected `pub` statement

**Note**: This can be done in parallel or as a separate cleanup PR. It does NOT block contract system development.

---

## Definition of Done

- [ ] `tri spec apply` modifies .tri files correctly
- [ ] `tri spec audit --fail-below 80` passes on all core specs
- [ ] Contract expressions parse without errors for:
  - Simple: `x > 0`
  - Compound: `x >= 0 and x < 100`
  - Range: `x in [0, 100]`
  - Complex: `(x > 0 or y > 0) and not z`
- [ ] Generated Zig code compiles and tests pass
- [ ] CI workflow blocks PR when coverage < 80%
- [ ] Documentation updated in `CLAUDE.md` and/or `docs/`

---

## Technical Notes

### File Structure
```
src/tri/
  tri_spec_audit.zig      ✅ Complete
  tri_spec_command.zig     ✅ Complete
  tri_spec_apply.zig       ⚠️  Needs AST rewrite
src/vibeec/
  contract_dsl.zig          ⚠️  Tokenizer only, needs parser
  contract_checker.zig      ⚠️  Skeleton only
  parser_types.zig          ✅ Has Idiom 11 fields
  parser_sections.zig       ✅ Has parseSpecAnnotations()
  vibee_parser.zig          ✅ Calls parseSpecAnnotations()
  codegen/tests_gen.zig     ✅ Prefers @example over test_cases
```

### Priority Order
1. Task 2 (DSL Parser) — Enables Task 3
2. Task 3 (Contract Checker) — Enables validation
3. Task 1 (AST Rewrite) — Enables `tri spec apply`
4. Task 4 (Build Errors) — Can be done anytime

---

## Formula

φ² + 1/φ² = 3
