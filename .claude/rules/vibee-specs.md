---
paths:
  - "specs/**/*.vibee"
  - "trinity-nexus/tri/*.vibee"
---

# VIBEE Specification Rules

- .vibee files are the SOURCE OF TRUTH — all application logic flows from specs
- Generate code: `zig build vibee -- gen <path/to/spec.vibee>`
- Never manually edit generated output in `trinity/output/` or `generated/`
- Spec format: YAML with name, version, language, module, types, behaviors
- Supported languages: `zig` (default), `varlog` (Verilog/FPGA), `python`
- Each behavior needs: name, given (precondition), when (action), then (result)
- Version specs semantically (1.0.0, 1.1.0, etc.)
- After editing a spec, regenerate and run tests immediately
