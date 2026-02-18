# trinity-vsa

[![Crates.io](https://img.shields.io/crates/v/trinity-vsa.svg)](https://crates.io/crates/trinity-vsa)
[![Documentation](https://docs.rs/trinity-vsa/badge.svg)](https://docs.rs/trinity-vsa)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

High-performance Vector Symbolic Architecture (VSA) library with balanced ternary arithmetic, SIMD acceleration, and FPGA support.

## Features

- **Balanced Ternary**: Values in {-1, 0, +1} for efficient computation
- **VSA Operations**: bind, bundle, permute, similarity, hamming distance
- **Multiple Storage Formats**: Dense, Packed (2 bits/trit), Sparse
- **SIMD Acceleration**: AVX-512, AVX2, NEON support
- **FPGA Ready**: Designed for hardware acceleration with BitNet

## Why trinity-vsa?

| Feature | trit-vsa | **trinity-vsa** |
|---------|----------|-----------------|
| Core VSA ops | ✅ | ✅ |
| SIMD (AVX2/NEON) | ✅ | ✅ + AVX-512 |
| Packed storage | ✅ | ✅ |
| Sparse vectors | ✅ | ✅ |
| **FPGA acceleration** | ❌ | ✅ |
| **Knowledge Graph** | ❌ | ✅ |
| **BitNet integration** | ❌ | ✅ |

## Quick Start

```rust
use trinity_vsa::prelude::*;

fn main() {
    // Create random hypervectors
    let apple = TritVector::random(10000);
    let red = TritVector::random(10000);
    let fruit = TritVector::random(10000);

    // Bind: create association "red apple"
    let red_apple = bind(&apple, &red);

    // Bundle: combine concepts
    let fruits = bundle(&[&apple, &red_apple, &fruit]);

    // Similarity: compare vectors
    let sim = similarity(&red_apple, &apple);
    println!("Similarity: {:.3}", sim);

    // Unbind: retrieve associated concept
    let recovered = unbind(&red_apple, &red);
    let recovery_sim = similarity(&recovered, &apple);
    println!("Recovery similarity: {:.3}", recovery_sim);
}
```

## Storage Formats

### Dense (TritVector)
```rust
let v = TritVector::random(10000);
// 10KB memory (1 byte per trit)
```

### Packed (PackedTritVec)
```rust
let packed = PackedTritVec::from_trit_vector(&v);
// 2.5KB memory (2 bits per trit) - 4x savings
```

### Sparse (SparseVec)
```rust
let sparse = SparseVec::from_trit_vector(&v);
// ~1KB for 10% density - 10x savings
```

## VSA Theory

Vector Symbolic Architecture represents concepts as high-dimensional vectors:

- **Binding** (⊗): Creates associations via element-wise multiplication
  - `bind(a, a) = all +1` (self-binding)
  - `bind(a, bind(a, b)) = b` (unbinding)

- **Bundling** (+): Combines concepts via majority voting
  - Result is similar to all inputs

- **Permutation** (ρ): Encodes sequences via circular shift
  - `sequence = bind(word1, permute(word2, 1), permute(word3, 2))`

**Golden Identity**: φ² + 1/φ² = 3

## Benchmarks

```
bind (10K dim):      0.8 µs
bundle (10K, 5 vec): 1.4 µs
similarity (10K):    0.5 µs
packed bind (10K):   0.3 µs
```

## Features

```toml
[dependencies]
trinity-vsa = { version = "0.1", features = ["simd"] }

# Optional features:
# simd    - SIMD acceleration (default)
# avx512  - AVX-512 support
# neon    - ARM NEON support
# cuda    - CUDA GPU support
# fpga    - FPGA integration
```

## License

MIT License - see [LICENSE](LICENSE)

## References

1. Kanerva, P. (2009). "Hyperdimensional Computing"
2. Ma, H., et al. (2024). "The Era of 1-bit LLMs" (arXiv:2402.17764)
3. [Trinity Project](https://github.com/gHashTag/trinity)
