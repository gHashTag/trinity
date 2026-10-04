# Trinity Field Manual — Quick Reference

## 6-Phase Cycle (Quick)

1. **Plan** → `tri plan --impact <node>`
2. **Specify** → `tri spec create`
3. **Generate** → `tri gen`
4. **Test** → `tri test`
5. **Verdict** → `tri verdict --toxic`
6. **Evolve** → `tri experience save`

## W→F/M→V→E→W Micro-Loop

- W: `tri cell begin` — seal step start
- F/M: Validate and measure
- V: `tri verdict --toxic`
- E: `tri experience save`
- W: `tri cell commit` — seal step end

## Key Commands

| Task | Command |
|------|---------|
| Create ADR | `tri adr create` |
| Initialize SOUL | `tri soul init` |
| Scan issues | `tri dev scan` |
| Pick task | `tri dev pick --smart` |
| Generate code | `tri gen` |
| Run tests | `tri test` |
| Toxic verdict | `tri verdict --toxic` |
| Save experience | `tri experience save` |
| Git commit | `tri git commit` |

## Agent Reference (Key Letters)

- **T**: Orchestration, Queen
- **N**: Numeric (GF16, TF3)
- **P**: Physics (φ, sacred constants)
- **S**: Specs (.t27 files)
- **V**: Verdict, validation
- **W**: Workflow, tri cell

## Links

- **Architecture**: [docs/ARCHITECTURE.md](ARCHITECTURE.md)
- **Documentation Index**: [docs/DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)
- **TRI-27 Language**: https://github.com/gHashTag/t27
