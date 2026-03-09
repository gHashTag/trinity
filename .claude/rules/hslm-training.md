---
paths:
  - "src/hslm/**/*.zig"
---

# HSLM (Hybrid Symbolic Language Model) Rules

- Autograd engine in trainer.zig — backward pass must match forward exactly
- Training data: TinyStories in `data/tinystories/` — do not commit data files
- Checkpoints saved to `data/checkpoints/` — gitignored, do not commit
- 74/74 tests must pass: `zig test src/hslm/model.zig`
- Trinity block (`trinity_block.zig`) uses ternary {-1,0,+1} — never mix with float
- Constants in `constants.zig` are phi-derived — verify against phi^2 + 1/phi^2 = 3
- Consciousness module is experimental — document any changes thoroughly
- CLI in `cli.zig` handles TinyStories pipeline — test with small dataset first
