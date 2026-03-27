# B005: Tri Language Specification

**DOI:** 10.5281/zenodo.19227873
**Version:** 8.0
**LOC:** 560

## Overview

Tri is a ternary programming language with VIBEE compiler targeting Zig and Verilog. Features type inference, pattern matching, and linear types.

## Key Features

- **Syntax:** .tri specification format
- **Targets:** Zig, Verilog (VIBEE codegen)
- **Type System:** ADT enums, exhaustive match, result types
- **Effects:** Effects + handlers system (~270 LOC)

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
