# TTT Dogfood — .tri is Source of Truth

## Rule

**`.tri` spec = SINGLE source of truth for ALL target languages.**

Every `.zig` file in `trinity/src/` must have a corresponding `.tri` spec in `specs/`.
All code generation goes through `tri gen` from `.tri` specs.

```
.tri (VIBEE spec)          ← SINGLE source of truth
    │
    ├── tri gen → .t27     ← TRI-27 Assembly (our language)
    ├── tri gen → .zig     ← via zig-golden-float (kernel)
    ├── tri gen → .py      ← Python target (future)
    ├── tri gen → .rs      ← Rust target (future)
    └── tri gen → .go      ← Go target (future)
```

## Architecture

- **zig-golden-float/** = Kernel (numerical operations, VSA, Ternary VM)
- **trinity/** = Language layer (.tri specs, .t27 assembly, configs, docs)
- **NO .zig files in trinity/src/** except build.zig

## 10-Step Pipeline

1. `tri dev scan` — Read issues + experience
2. `tri dev pick --smart` — Priority + MNL (avoid 3+ fails)
3. `tri issue comment N` — Immutable GitHub record
4. `tri spec create` — .tri spec from experience template
5. `tri gen` — .tri → .t27 + .zig + ...
6. `tri test` — Compare outputs
7. `tri verdict --toxic` — "Past: 3/7. Now: 7/7"
8. `tri experience save` — Episode + learnings + mistakes
9. `tri git commit` — [DONE] + push
10. `tri loop decide` — Continue or Done?

## MNL Pattern (Mistake → Not-repeat → Learning)

- Task X: 3 consecutive fails → SKIP (toxic)
- Task Y: 0 fails, similar to solved Z → PICK
- Task Z: 1 fail, but fix found → PICK with learning

## Agent Behavior

**All agents must follow**: "if something can't be done via tri → fix in zig-golden-float kernel"

- Never create .zig files directly in `trinity/src/` without .tri spec
- Always use `tri gen` from `.tri` spec for code generation
- If kernel limitation found → fix in zig-golden-float, regenerate from .tri
