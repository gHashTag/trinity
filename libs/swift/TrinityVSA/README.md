# TrinityVSA

Swift library for Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/gHashTag/trinity.git", from: "0.1.0")
]
```

## Quick Start

```swift
import TrinityVSA

// Create random hypervectors
let apple = TritVector.random(10000, seed: 42)
let red = TritVector.random(10000, seed: 123)

// Bind: create association
let redApple = bind(apple, red)

// Similarity
let sim = similarity(redApple, apple)
print("Similarity: \(String(format: "%.3f", sim))")

// Unbind: recover original
let recovered = unbind(redApple, red)
let recovery = similarity(recovered, apple)
print("Recovery: \(String(format: "%.3f", recovery))")
```

## API

### Types

```swift
enum Trit: Int8 {
    case neg = -1
    case zero = 0
    case pos = 1
}

struct TritVector {
    var data: [Int8]
    var dim: Int
    
    static func zeros(_ dim: Int) -> TritVector
    static func random(_ dim: Int, seed: UInt64) -> TritVector
    var nnz: Int
    var sparsity: Double
}

struct PackedTritVec {
    var pos: [UInt64]
    var neg: [UInt64]
    let dim: Int
    
    static func from(_ v: TritVector) -> PackedTritVec
    func toVector() -> TritVector
}
```

### Functions

| Function | Description |
|----------|-------------|
| `bind(a, b)` | Bind two vectors |
| `unbind(a, b)` | Unbind (inverse of bind) |
| `bundle(vectors)` | Bundle via majority vote |
| `permute(v, shift:)` | Circular shift |
| `similarity(a, b)` | Cosine similarity |
| `dot(a, b)` | Dot product |
| `hammingDistance(a, b)` | Hamming distance |
| `packedBind(a, b)` | Fast packed bind |
| `packedDot(a, b)` | Fast packed dot |

## Example: Associative Memory

```swift
import TrinityVSA

// Create concepts
let items = [
    "apple": TritVector.random(10000, seed: 1),
    "banana": TritVector.random(10000, seed: 2)
]

let colors = [
    "red": TritVector.random(10000, seed: 3),
    "yellow": TritVector.random(10000, seed: 4)
]

// Store associations
let memory = [
    bind(items["apple"]!, colors["red"]!),
    bind(items["banana"]!, colors["yellow"]!)
]

// Query
let query = bind(items["apple"]!, colors["red"]!)
for (i, mem) in memory.enumerated() {
    let sim = similarity(query, mem)
    print("Memory \(i): \(String(format: "%.3f", sim))")
}
```

## License

MIT License
