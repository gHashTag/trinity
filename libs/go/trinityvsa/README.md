# trinityvsa

Go library for Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```bash
go get github.com/gHashTag/trinity/libs/go/trinityvsa
```

## Quick Start

```go
package main

import (
    "fmt"
    vsa "github.com/gHashTag/trinity/libs/go/trinityvsa"
)

func main() {
    // Create random hypervectors
    apple := vsa.NewRandom(10000, 42)
    red := vsa.NewRandom(10000, 123)
    
    // Bind: create association
    redApple := vsa.Bind(apple, red)
    
    // Similarity
    sim := vsa.Similarity(redApple, apple)
    fmt.Printf("Similarity: %.3f\n", sim)
    
    // Unbind: recover original
    recovered := vsa.Unbind(redApple, red)
    recovery := vsa.Similarity(recovered, apple)
    fmt.Printf("Recovery: %.3f\n", recovery)
}
```

## API

### Types

```go
type Trit int8  // -1, 0, +1

type TritVector struct {
    Data []Trit
    Dim  int
}

type PackedTritVec struct {
    Pos, Neg []uint64
    Dim      int
}
```

### Functions

| Function | Description |
|----------|-------------|
| `NewZeros(dim)` | Create zero vector |
| `NewRandom(dim, seed)` | Create random vector |
| `Bind(a, b)` | Bind two vectors |
| `Unbind(a, b)` | Unbind (inverse of bind) |
| `Bundle(vectors)` | Bundle via majority vote |
| `Permute(v, shift)` | Circular shift |
| `Similarity(a, b)` | Cosine similarity |
| `Dot(a, b)` | Dot product |
| `HammingDistance(a, b)` | Hamming distance |

### Packed Operations

```go
pa := vsa.NewPackedFromVector(a)
pb := vsa.NewPackedFromVector(b)

bound := vsa.PackedBind(pa, pb)
dot := vsa.PackedDot(pa, pb)
```

## Benchmarks

```bash
go test -bench=.
```

## License

MIT License
