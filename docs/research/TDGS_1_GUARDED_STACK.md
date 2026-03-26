# TDGS-1: Tri Dev Guarded Stack — Full Stack Guarded Editing

## Sacred Formula
V = n × 3^k × π^m × φ^p × e^q
φ² + 1/φ² = 3

---

## Goal

All critical Trinity/Tri layers (from Zig core to Tri code and .t27) are modified **only through `tri dev`**, not manually in an editor. This reduces errors, ensures unified pipeline checks, and prepares the ground for auto-generation/self-hosting.

---

## TDGS-1: Core Development Law (Extended)

> **Any changes to files in the "Guarded scope" list MUST be performed EXCLUSIVELY through `tri dev` commands.**
>
> **Direct manual editing of these files is considered a violation** and is blocked by pre-commit/CI.

---

## 1. Scope

### 1.1 Trusted Tri Core (TTC, Zig)

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri-lang/lexer.zig` | 310 | Tokenization |
| `src/tri-lang/parser.zig` | 300 | Parse AST |
| `src/tri-lang/ast.zig` | 370 | AST definitions |
| `src/tri-lang/typecheck_core.zig` | ~150 | Type checking |
| `src/tri-lang/emit_t27.zig` | ~200 | .t27 generation |
| `src/tri-lang/emit_zig.zig` | ~200 | Zig emission |
| `src/tri/cell.zig` | 150 | NA-R11 signature |
| `src/tri/t27_cli.zig` | 50 | CLI for verify/diff |
| `src/tri27/coptic.zig` | 170 | Coptic alphabet |

**Total TTC: ≤ 3000 LOC Zig**

### 1.2 Tri Language (core modules)

- All files `src/tri-lang/*.tri` (language/stdlib/combinators)
- All Tri modules marked as **core/canon** in `canon_map.json`

### 1.3 TRI-27 Artifacts and Specifications

- All `.t27` files in `src/tri27/`
- All research specifications in `docs/research/*.md` and `docs/tri27/*.md` marked as **normative**

### 1.4 Build System

- `build.zig` (tri-specific sections)
- `zig.mod` (module dependencies)

---

## 2. Guarded Commands

### 2.1 Basic Commands

```bash
# Initialize development session
tri dev init

# Edit a guarded file
tri dev edit src/tri-lang/parser.zig

# Mark file as fixed (manual edit)
tri dev fix src/tri-lang/parser.zig

# Show status
tri dev status

# Commit changes
tri dev commit "feat(parser): add error recovery"
```

### 2.2 Workflow

1. **Pre-commit hook** blocks direct edits to guarded files
2. **tri dev edit** creates a temporary copy for editing
3. **tri dev fix** marks manual edits as intentional
4. **tri dev commit** validates and commits changes

---

## 3. Validation

### 3.1 Pre-commit Hook

- [ ] `tri dev init` installs `.git/hooks/pre-commit`
- [ ] Hook blocks direct edits to Guarded files

### 3.2 Build Verification

- [ ] `zig build` passes without errors
- [ ] `zig build test` passes (all tests)
- [ ] No undefined behavior (UBSan clean)

### 3.3 Code Review

- [ ] Create `.tri` spec with `@spec/@example` template
- [ ] Add test skeleton
- [ ] Request review before committing

---

## 4. Protected Files List

### 4.1 Core Protected

```
src/tri-lang/
src/tri/cell.zig
src/tri/t27_cli.zig
src/tri27/coptic.zig
src/tri27/emu/*.zig
```

### 4.2 Generated Files (Never Edit Manually)

```
generated/
var/trinity/output/
*.gen.zig
*.gen.v
```

---

## 5. Violation Detection

### 5.1 Automatic Detection

Pre-commit hook detects:
- Direct edits to guarded files (without `tri dev edit`)
- Edits to generated files
- Uncommitted changes before push

### 5.2 Consequences

1. **Warning**: First violation — notification only
2. **Block**: Second violation — commit blocked
3. **Escalation**: Chronic violations — admin notification

---

## 6. Documentation

### 6.1 User Documentation

- [x] `docs/research/CORE_DEVELOPMENT_LAW.md`
- [x] `docs/research/TDGS_1_GUARDED_STACK.md`

### 6.2 Developer Documentation

- [x] Inline documentation in all guarded files
- [x] API documentation for public functions
- [x] Algorithm descriptions in LaTeX/pseudocode

### 6.3 Pre-commit hook

- [ ] `tri dev init` installs `.git/hooks/pre-commit`
- [ ] Hook blocks direct Guarded file edits

### 6.4 TDGS-1 Documentation

- [x] `docs/research/CORE_DEVELOPMENT_LAW.md`
- [x] `docs/research/TDGS_1_GUARDED_STACK.md`

---

## 7. Related Issues

- #411: Linear Types + Ownership Modes (completed)
- #421: tri dev core audit implementation (next)
- #422: Tri self-hosting phase 1
- #423: Tri self-hosting phase 2

---

## 8. Analogues in Other Systems

| System | Approach |
|--------|----------|
| **seL4** | Formal verification, tiny kernel |
| **CompCert** | Coq-spec → C code |

---

**φ² + 1/φ² = 3 | TRINITY**
