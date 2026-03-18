# MEMORY: Archive Migration Rule

## CRITICAL RULE

**ALWAYS check `archive/` before writing new code.**

### Why:
- Archive contains tested, working code
- Migration takes 5 min vs 2+ hours to write
- Token savings: ~30K tokens per component
- Preserves proven logic

### Archive Location:
`/Users/playra/trinity/archive/`

### Useful Code in Archive:
- `archive/implementations/zig/src/ml/` — tensor, model, trainer, quantum
- `archive/implementations/zig/src/` — attention, optimizers, quantization

### Migration Process:
1. Search: `find archive -name "*.zig"`
2. Read: `cat archive/path/file.zig`
3. Copy: `cp archive/path/file.zig trinity-nexus/module/src/`
4. Update imports
5. Test

### Example:
```
NEED: tensor.zig
FOUND: archive/implementations/zig/src/ml/tensor.zig
MIGRATED: trinity-nexus/core/src/ml/tensor.zig
SAVED: 2 hours, 20K tokens
```

### Rule File:
`.ralph/RULES.md`
