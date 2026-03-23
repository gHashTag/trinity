# ADR 001: VIBEE Specification-Driven Compiler

**Date:** 2025-02-01
**Status:** Accepted
**Deciders:** @gHashTag
**Related:** [ADR-002](./002-ternary-representation.md), [ADR-003](./003-sacred-constants-unified.md)

---

## Context

Trinity requires code generation for multiple targets:
- Zig (primary language)
- Verilog (FPGA synthesis)
- Python (scientific computing)
- Rust (performance-critical components)

**Problems:**
1. Manual code generation is error-prone and non-idempotent
2. Sacred constants duplicated across 500+ files
3. No single source of truth for module interfaces
4. Cross-language consistency difficult to maintain

**Constraints:**
- Must support Zig 0.15.x
- Must generate valid Verilog for Yosys synthesis
- Must maintain compile-time verification of sacred constants

---

## Decision

**Adopt VIBEE as the single source of truth for all application code.**

### VIBEE Specification Format

```yaml
name: module_name
version: "1.0.0"
language: zig          # zig | varlog | python | rust
module: module_name

types:
  TypeName:
    fields:
      field1: String
      field2: Int

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
```

### Architecture

```
.vibee spec → VIBEE Parser → AST → Codegen → Zig/Verilog/Python
                      ↓
               Sacred Constants Verification
```

### Implementation

- **Parser:** `trinity-nexus/lang/src/vibee_parser.zig`
- **Codegen:** `trinity-nexus/lang/src/zig_codegen.zig`, `verilog_codegen.zig`
- **CLI:** `src/vibeec/gen_cmd.zig` (thin wrapper)

---

## Consequences

### Positive

✅ **Single source of truth** — All code generated from .vibee specs
✅ **Idempotency** — Same spec always produces identical code
✅ **Cross-language consistency** — One spec, multiple targets
✅ **Compile-time verification** — Sacred constants verified at comptime
✅ **Self-improvement** — VIBEE can analyze and patch its own output

### Negative

⚠️ **Learning curve** — Developers must learn VIBEE DSL
⚠️ **Indirect workflow** — Cannot edit generated code directly
⚠️ **Build complexity** — Additional step in development cycle

### Neutral

- Generated code located in `var/trinity/output/` (gitignored)
- Specs located in `specs/tri/*.vibee`

---

## References

- [VIBEE Specification](/vibee/specification)
- [Architecture Overview](/depin/architecture)

---

**φ² + 1/φ² = 3 = TRINITY**
