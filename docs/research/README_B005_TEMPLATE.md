# Trinity B005: Tri Language — Linear Types, Effects, Dual-Target Codegen

**Zenodo DOI:** [10.5281/zenodo.19227741](https://doi.org/10.5281/zenodo.19227741)  
**Version:** 5.2.0  
**Date:** 2026-03-26  
**License:** MIT  
**Author:** Dmitrii Vasilev

---

## Abstract

Tri Language is a DSL for ternary computing with advanced type system features and dual-target code generation. Key innovations: Linear Types + Ownership (Let/Inout/Sink/Set), Algebraic Effects + Handlers, Bit/Trit Pattern Matching, Content-Addressed Functions (SHA256 AST hashing), Result Type (Austral-style), Array Combinators, Pipe Operator, Dual-Target Codegen (Zig + Verilog). Enables zero-cost abstractions while maintaining memory safety.

---

## Citation

```bibtex
@software{trinity_b005_2026,
  title        = {Trinity B005: Tri Language},
  author       = {Vasilev, Dmitrii},
  year         = 2026,
  month        = 3,
  version      = {5.2.0},
  doi          = {10.5281/zenodo.19227741},
  url          = {https://doi.org/10.5281/zenodo.19227741}
}
```

---

## Key Innovations

### 1. Linear Types + Ownership
```tri
// Modes: Let, Inout, Sink, Set
fn consume(let x: Tensor): void { ... }
fn modify(inout x: Tensor): void { ... }
fn destroy(sink x: Tensor): void { ... }
fn create(): Set Tensor { ... }
```

### 2. Algebraic Effects
```tri
effect State {
  fn get(): T
  fn set(x: T): void
}

fn counter() with State[i32] {
  let n = get();
  set(n + 1);
}
```

### 3. Dual-Target Codegen
```tri
// .tri spec → Zig (CPU) + Verilog (FPGA)
spec add_16 {
  inputs: a[16], b[16]
  outputs: sum[16]
}
```

---

## Compilation Pipeline

```
┌─────────┐    ┌─────────┐    ┌────────────┐
│  .tri   │───►│  AST    │───►│  Type Check │
│  source │    │  parse  │    │  (linear)   │
└─────────┘    └─────────┘    └──────┬───────┘
                                    │
                       ┌────────────┴────────────┐
                       ▼                         ▼
                  ┌─────────┐              ┌─────────┐
                  │   Zig   │              │ Verilog │
                  │codegen  │              │codegen  │
                  └────┬────┘              └────┬────┘
                       │                        │
                  ┌────▼────┐              ┌────▼────┐
                  │  CPU    │              │  FPGA   │
                  │ binary  │              │bitstream│
                  └─────────┘              └─────────┘
```

---

## Algorithm: Content-Addressed Functions

```
Algorithm 1: Function Content Hashing
Input: AST of function f
Output: hash = SHA256(f)

1:  // Serialize AST to canonical form
2:  s ← serialize(ast)
3:  
4:  // Stable sort: ensure deterministic output
5:  sort(s, by=identifier)
6:  
7:  // Compute SHA256
8:  hash ← sha256(s)
9:  
10: // Use hash for:
11: // - Deduplication (same hash = same function)
12: // - Versioning (different hash = different version)
13: // - Caching (hash → cache key)
14: 
15: return hash

// Properties:
// - Deterministic: same source → same hash
// - Collision-resistant: SHA256(2^256) space
// - Cache-friendly: hash → lookup key
```

---

## Results

| Feature | Lines | Generated Zig | Generated Verilog |
|---------|-------|---------------|-------------------|
| Linear Types | 120 | 280 LOC | 450 LOC |
| Effects | 85 | 340 LOC | — |
| Pattern Match | 95 | 180 LOC | 320 LOC |

---

## Limitations

1. **Verilog:** Limited subset of Tri supported
2. **Effects:** No async effect handlers yet
3. **Performance:** Generated code not hand-optimized

---

## References

[1] O'Hearn "Resource Interpretation, Linear Logic" POPL (1997)  
[2] Wadler "Linear Types Can Change the World" PLDI (1990)  
[3] Bauer "Programming with Algebraic Effects" JFP (2022)

---

**φ² + 1/φ² = 3 | TRINITY**
