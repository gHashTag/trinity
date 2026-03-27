# B005: Tri Language Specification

**DOI:** 10.5281/zenodo.19227873
**Version:** 9.0
**LOC:** 642

## Overview

Tri is a ternary programming language with VIBEE compiler targeting Zig and Verilog. Features type inference, pattern matching, and linear types.

## Key Features

- **Syntax:** .tri specification format (Coptic-inspired notation)
- **Targets:** Zig, Verilog (VIBEE codegen)
- **Type System:** ADT enums, exhaustive match, result types
- **Effects:** Effects + handlers system (~270 LOC)
- **Parser:** Generated from `vibee_parser.tri` spec
- **Compilation:** Multi-stage pipeline (parse → validate → codegen → optimize)

## VIBEE Compilation Pipeline

```
.tri spec → Parse → AST → Type Check → Zig/Verilog
                    ↓
                  Validate (exhaustive patterns)
                    ↓
                  Codegen (tri_compiler.zig)
                    ↓
                  Optimize (inlining, dead code elimination)
                    ↓
                  Output (Zig/Verilog/Assembly)
```

**Supported Targets:**
- `zig` - Native code with φ-optimized ternary operations
- `verilog` - FPGA bitstream synthesis (B002 compatible)
- `wasm` - WebAssembly for browser deployment
- `x86_64` - SIMD-optimized native assembly

## Code Example

```tri
enum Option<T> {
    Some(T),
    None,
}

fn map<T, U>(self: Option<T>, f: fn(T) -> U) -> Option<U> {
    match self {
        Some(x) => Some(f(x)),
        None => None,
    }
}
```

## Files

- Metadata: `docs/research/.zenodo.B005_v8.0.json`
- Compiler: `src/vibee/`
- Specs: `specs/tri/*.tri`
- Roadmap: `docs/research/tri_language_roadmap.md`

## Related Bundles

**B005 TriLang** compiles to:
- [B001 HSLM](B001_HSLM.md) — Neural network inference code
- [B002 FPGA](B002_FPGA.md) — Hardware acceleration

**B005 TriLang** uses:
- [B006 GF16](B006_GF16.md) — Ternary data serialization

## Citation

```bibtex
@software{trinity_b005,
  title={Trinity B005: Tri Language Specification},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19227873},
  publisher={Zenodo}
}
```

## Links

- Zenodo: https://zenodo.org/doi/10.5281/zenodo.19227873
- GitHub: https://github.com/gHashTag/trinity
