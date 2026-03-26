# Trusted Tri Core (TTC) - Zig Microkernel

## Principle: Tiny Trusted Core (TTC)

Following seL4/CompCert/Lean 4 methodology:
- Small, maximally simple Zig layer = **only trusted code**
- Everything above it = Tri-code, .t27, and autogeneration

## TTC Scope (Zig-only, never reimplemented in Tri)

### Core Parsing & Typing

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri-lang/lexer.zig` | 310 | Tokenization of Tri source |
| `src/tri-lang/parser.zig` | 300 | Parse AST from tokens |
| `src/tri-lang/ast.zig` | 370 | AST node definitions |
| `src/tri-lang/typecheck_core.zig` | ~150 | Basic type checking |

### Backend Glue

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri-lang/emit_t27.zig` | ~200 | Generate TRI-27 bytecode |
| `src/tri-lang/emit_zig.zig` | ~200 | Emit Zig code from AST |

### Security & Canon Infrastructure

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri/cell.zig` | 150 | NA-R11 signature/verification |
| `src/tri/t27_cli.zig` | 50 | CLI for verify/diff/sign |
| `src/tri27/coptic.zig` | 170 | Coptic alphabet + 3-bank |

### Build System

| File | LOC | Purpose |
|------|-----|---------|
| `build.zig` (tri-specific) | ~100 | Build gate for .t27 verification |

**Total TTC: ~2000 LOC Zig**

## TTC Freeze Rules

1. **All files listed above are frozen** - changes only with justification
2. **Any new Zig file outside TTC** is temporary and MUST migrate to Tri
3. **LOC limit**: TTC ≤ 3000 LOC Zig total
4. **Audit command**: `tri core audit` checks for Zig files outside TTC

## Target for Tri Migration

The following SHOULD be implemented in Tri (not Zig):

- Queen Lotus Cycle logic (phases 0-5)
- HSLM training loops
- Neuro-pipelines (PPL stabilization, quality classification)
- Advanced type system (Result, Phantom, Linear)
- Effects and algebraic handlers
- Array combinators (map/reduce/scan)
- Auto-parallelism (DAG extraction)
- Test scenarios and BDD

## Self-Hosting Goal

Once Tri can compile itself to .t27/.zig:
1. Write parser in Tri (parse Tri source to AST)
2. Write typechecker in Tri (advanced typing)
3. Write emitter in Tri (AST → .t27)
4. Bootstrap: Tri compiles Tri

This follows Zig's self-hosting path but with Tri as the target.

## Directory Structure

```
src/
├── tri-core-zig/           # TTC (trusted, frozen)
│   ├── lexer.zig
│   ├── parser.zig
│   ├── ast.zig
│   ├── typecheck_core.zig
│   ├── emit_t27.zig
│   └── emit_zig.zig
├── tri/                     # CLI glue (TTC-adjacent)
│   ├── cell.zig
│   └── t27_cli.zig
├── tri27/                   # TRI-27 ISA (TTC-adjacent)
│   ├── coptic.zig
│   └── asm_parser.zig
└── [everything else]        # Target for Tri migration
```

## Related Issues

- #421: TTC freeze - enumerate Zig files, mark core vs migrate-to-Tri
- #422: Tri self-hosting phase 1 - parser in Tri
- #423: Tri self-hosting phase 2 - typechecker in Tri

---

φ² + 1/φ² = 3 | TRINITY
