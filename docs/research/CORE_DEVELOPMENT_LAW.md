# Core Development Law (CDL-1) — TTC Guarded Editing

## Sacred Formula
V = n × 3^k × π^m × φ^p × e^q
φ² + 1/φ² = 3

---

## Principle: Tiny Trusted Core (TTC)

Following seL4/CompCert/Lean 4 methodology:
- **Small, maximally simple Zig layer** = only trusted code
- **Everything above it** = Tri-code, .t27, and autogeneration
- **Changes ONLY via `tri dev`** — no direct editing

---

## CDL-1: Core Development Law

> **All changes to the Trusted Tri Core (TTC) MUST be performed exclusively via `tri dev` commands.**
>
> **Direct edits to these Zig files are FORBIDDEN** and will be rejected by:
> - git pre-commit hook (tri dev generates a core-signature)
> - CI checks (tri dev core audit)

---

## TTC Scope (Frozen Zig Files)

| File | LOC | Purpose | Status |
|------|-----|---------|--------|
| `src/tri-lang/lexer.zig` | 310 | Tokenization | Frozen |
| `src/tri-lang/parser.zig` | 300 | Parse AST | Frozen |
| `src/tri-lang/ast.zig` | 370 | AST definitions | Frozen |
| `src/tri-lang/typecheck_core.zig` | ~150 | Type checking | Frozen |
| `src/tri-lang/emit_t27.zig` | ~200 | .t27 generation | Frozen |
| `src/tri-lang/emit_zig.zig` | ~200 | Zig emission | Frozen |
| `src/tri/cell.zig` | 150 | NA-R11 signature | Frozen |
| `src/tri/t27_cli.zig` | 50 | CLI for verify/diff | Frozen |
| `src/tri27/coptic.zig` | 170 | Coptic alphabet | Frozen |

**Total TTC: ≤ 3000 LOC Zig**

---

## Enforcement

### 1. Core Signature (in every TTC file)

```zig
// TRI_CORE_SIGNATURE: tri-dev:1711900800:sha256:a3f2...b7c1
// TRI_CORE_SCOPE: TTC
// DO NOT EDIT MANUALLY — USE `tri dev core ...`
```

### 2. Pre-commit Hook

```bash
# .git/hooks/pre-commit
for f in $(git diff --cached --name-only | grep -E 'src/tri-lang/|src/tri/cell.zig|src/tri27/coptic.zig'); do
    tri t27 verify-core "$f" || {
        echo "ERROR: $f modified without tri dev"
        echo "Use 'tri dev core ...' to change TTC files"
        exit 1
    }
done
```

### 3. CI Audit

- `tri dev core audit` checks:
  - TTC ≤ 3000 LOC
  - Valid signatures in all TTC files
  - No new Zig files outside TTC

---

## tri dev Commands

### Core Editing

| Command | Purpose |
|---------|---------|
| `tri dev core audit` | Check TTC health (LOC, signatures) |
| `tri dev core sign` | Update core signatures after changes |
| `tri dev ast edit` | Edit AST via declarative spec |
| `tri dev parser add-rule` | Add parser rule from grammar |
| `tri dev core edit-emit` | Update emit_t27/emit_zig |

### Tri Language

| Command | Purpose |
|---------|---------|
| `tri dev tri new-module <name>` | Create new .tri module |
| `tri dev tri refactor <op>` | Safe refactoring (AST-level) |
| `tri dev tri canonize <module>` | Mark module as canon |

### .t27 Files

| Command | Purpose |
|---------|---------|
| `tri dev t27 create <region>` | Generate .t27 from spec |
| `tri dev t27 regen` | Regenerate all .t27 from sources |

---

## Configuration

TTC files listed in `.trinity/ttc.toml`:

```toml
[ttc]
name = "Trusted Tri Core"
version = "1.0.0"

[files]
lexer = "src/tri-lang/lexer.zig"
parser = "src/tri-lang/parser.zig"
ast = "src/tri-lang/ast.zig"
# ... (all 9 files)

[enforcement]
max_loc = 3000
signature_required = true
```

---

## Related Issues

- #421: tri dev — Guarded TTC Editing (THIS)
- #422: Tri self-hosting phase 1 — parser in Tri
- #423: Tri self-hosting phase 2 — typechecker in Tri

---

## Analogs in Other Systems

| System | Approach |
|--------|----------|
| **seL4** | Formal verification, tiny kernel |
| **CompCert** | Coq-spec → C code generation |
| **Lean 4** | Trusted kernel + tactics |
| **JetBrains MPS** | Projectional editing |
| **Intentional Programming** | Domain code → generator |

---

φ² + 1/φ² = 3 | TRINITY
