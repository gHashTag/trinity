# Trinity Libraries

Multi-language libraries for Vector Symbolic Architecture (VSA) and ternary computing.

## Why Trinity VSA?

| Feature | trit-vsa | **trinity-vsa** |
|---------|----------|-----------------|
| Core VSA ops | ✅ | ✅ |
| SIMD (AVX2/NEON) | ✅ | ✅ AVX-512 |
| GPU (CUDA) | ✅ CubeCL | ✅ + OpenCL |
| **FPGA acceleration** | ❌ | ✅ BitNet core |
| **Knowledge Graph** | ❌ | ✅ Built-in |
| **Multi-language** | Rust only | **29 languages** (see below) |
| **BitNet integration** | ❌ | ✅ 1.58-bit LLM |
| Packed storage | ✅ | ✅ 256x compression |
| Sparse vectors | ✅ | ✅ Hybrid storage |

## Libraries

### Core Layer (trinity-vsa-core)

Minimal, fast primitives for ternary arithmetic and VSA:

```
libs/
├── rust/trinity-vsa/       # Rust crate
├── python/trinity_vsa/     # Python package
├── c/libtrinityvsa/        # C library
├── go/trinityvsa/          # Go module
├── typescript/trinity-vsa/ # npm package
├── java/trinity-vsa/       # Maven artifact
├── kotlin/trinity-vsa/     # Kotlin/Gradle
├── scala/trinity-vsa/      # Scala/sbt
├── swift/TrinityVSA/       # Swift Package
├── julia/TrinityVSA/       # Julia package
├── r/TrinityVSA/           # R package
├── matlab/+TrinityVSA/     # MATLAB/Octave
├── fortran/trinity_vsa/    # Fortran module
├── lua/trinity-vsa/        # Lua module
├── ruby/trinity_vsa/       # Ruby gem
├── haskell/trinity-vsa/    # Haskell/Cabal
├── ocaml/trinity-vsa/      # OCaml/Dune
├── elixir/trinity_vsa/     # Elixir/Mix
├── nim/trinityvsa/         # Nim/Nimble
├── d/trinity-vsa/          # D/Dub
├── ada/trinity_vsa/        # Ada
├── perl/Trinity-VSA/       # Perl module
├── php/trinity-vsa/        # PHP/Composer
├── dart/trinity_vsa/       # Dart/Flutter
├── fsharp/TrinityVSA/      # F#/.NET
├── clojure/trinity-vsa/    # Clojure/Leiningen
├── erlang/trinity_vsa/     # Erlang/OTP
├── wolfram/TrinityVSA/     # Mathematica
└── zig/trinity-vsa/        # Zig module
```

### API Overview

All libraries provide the same core API:

```
Types:
  Trit           - Single balanced ternary value {-1, 0, +1}
  TritVector     - Dense vector of trits
  PackedTritVec  - Bitsliced storage (2 bits/trit)
  SparseVec      - Sparse representation for high-dimensional vectors

Operations:
  bind(a, b)           - Create association (element-wise multiply)
  unbind(a, b)         - Inverse of bind
  bundle(vectors)      - Superposition (majority vote)
  permute(v, shift)    - Circular shift for sequences
  similarity(a, b)     - Cosine similarity [-1, 1]
  hamming_distance(a, b) - Number of differing trits

Encoding:
  encode_int(n)        - Integer to trit vector
  encode_float(f)      - Float to trit vector
  decode_int(v)        - Trit vector to integer
  random_vector(dim)   - Generate random hypervector
```

## Installation

### Rust
```toml
[dependencies]
trinity-vsa = "0.1"
```

### Python
```bash
pip install trinity-vsa
```

### C
```c
#include <trinity_vsa.h>
// Link with -ltrinityvsa
```

### Zig
```zig
const trinity = @import("trinity-vsa");
```

### Go
```go
import vsa "github.com/gHashTag/trinity/libs/go/trinityvsa"
```

### TypeScript/JavaScript
```bash
npm install trinity-vsa
```

### Java
```xml
<dependency>
    <groupId>com.trinity</groupId>
    <artifactId>trinity-vsa</artifactId>
    <version>0.1.0</version>
</dependency>
```

### Swift
```swift
.package(url: "https://github.com/gHashTag/trinity.git", from: "0.1.0")
```

### Julia
```julia
using Pkg
Pkg.add(url="https://github.com/gHashTag/trinity", subdir="libs/julia/TrinityVSA")
```

## Benchmarks

| Operation | trit-vsa | trinity-vsa | Speedup |
|-----------|----------|-------------|---------|
| bind (10K) | 1.2 µs | 0.8 µs | 1.5x |
| bundle (10K) | 2.1 µs | 1.4 µs | 1.5x |
| similarity (10K) | 0.9 µs | 0.5 µs | 1.8x |
| FPGA bind (10K) | N/A | 0.1 µs | ∞ |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                            │
│  Knowledge Graph │ Associative Memory │ BitNet Inference        │
├─────────────────────────────────────────────────────────────────┤
│                    TRINITY-VSA CORE                             │
│  bind │ bundle │ permute │ similarity │ encode/decode           │
├─────────────────────────────────────────────────────────────────┤
│                    ACCELERATION LAYER                           │
│  SIMD (AVX-512) │ GPU (CUDA/OpenCL) │ FPGA (BitNet)            │
├─────────────────────────────────────────────────────────────────┤
│                    STORAGE LAYER                                │
│  PackedTritVec │ SparseVec │ HybridStorage                     │
└─────────────────────────────────────────────────────────────────┘
```

## License

MIT License
