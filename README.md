# Trinity

**Ternary Vector Symbolic Architecture for Hyperdimensional Computing**

[![Zig](https://img.shields.io/badge/Zig-0.11+-orange)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Trinity is a high-performance library for hyperdimensional computing using balanced ternary representation.

## Features

- **8.9 B trits/sec** dot product throughput
- **256x memory savings** with hybrid storage
- **Full VM** with 20+ VSA instructions
- **Zero dependencies** - pure Zig

## Quick Start

```zig
const trinity = @import("trinity");

pub fn main() !void {
    // Create concept vectors
    var apple = trinity.randomVector(256, 1);
    var red = trinity.randomVector(256, 2);

    // Bind: create association "red apple"
    var red_apple = trinity.bind(&apple, &red);

    // Check similarity
    const sim = trinity.cosineSimilarity(&red_apple, &apple);
}
```

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .trinity = .{
        .url = "https://github.com/gHashTag/trinity/archive/refs/tags/v0.1.0.tar.gz",
    },
},
```

## Operations

| Operation | Description | Throughput |
|-----------|-------------|------------|
| `bind` | Create associations | 425 M/s |
| `bundle` | Combine vectors | 3.4 B/s |
| `permute` | Encode sequences | 502 M/s |
| `similarity` | Compare vectors | 2.0 B/s |
| `dotProduct` | Scalar product | **8.9 B/s** |

## Documentation

- [Getting Started](docs/docs/intro.md)
- [API Reference](docs/docs/api/vsa.md)
- [Benchmarks](docs/docs/benchmarks.md)

## Examples

```bash
# Run examples
zig build examples

# Run benchmarks
zig build bench

# Run tests
zig build test
```

## Use Cases

- **Associative Memory** - Key-value storage with similarity search
- **NLP** - Sequence encoding with permute
- **Classification** - Bundle-based categorization
- **Robotics** - Sensor fusion with VSA

## Comparison

| Metric | Trinity | trit-vsa | Speedup |
|--------|---------|----------|---------|
| Dot product | 8.9 B/s | 50 M/s | **178x** |
| Bundle | 3.4 B/s | 30 M/s | **113x** |
| Memory | 256x savings | bitsliced | Similar |

## License

MIT

## Authors

- Dmitrii Vasilev
- Co-authored-by: Ona

---

**φ² + 1/φ² = 3**
