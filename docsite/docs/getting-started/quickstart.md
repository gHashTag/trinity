---
sidebar_position: 1
---

# Quick Start

Get up and running with Trinity in 5 minutes.

## Prerequisites

- **Zig 0.13.0** — [Download](https://ziglang.org/download/)
- **Git** — Version control

## Installation

```bash
# Clone the repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Verify Zig version
zig version  # Should show 0.13.0

# Build
zig build
```

## Run Your First Example

```bash
# Run VSA example
zig run examples/memory.zig
```

## Basic VSA Operations

```zig
const vsa = @import("vsa.zig");

// Create random vectors
var a = vsa.HybridBigInt.random(1000);
var b = vsa.HybridBigInt.random(1000);

// Bind vectors (create association)
var bound = vsa.bind(&a, &b);

// Check similarity
const similarity = vsa.cosineSimilarity(&a, &bound);
```

## Run Tests

```bash
# All tests
zig build test

# Specific module
zig test src/vsa.zig
```

## CLI Tools

```bash
# Generate code from specification
./bin/vibee gen specs/tri/module.vibee

# Run program via VM
./bin/vibee run program.999

# Start chat with model
./bin/vibee chat --model path/to/model.gguf
```

## Try It Now

No installation needed — experiment with ternary vectors in your browser:

```jsx live
function TernaryDemo() {
  const [dim, setDim] = React.useState(8);

  // Generate random ternary vector {-1, 0, +1}
  const randomTernary = (n) =>
    Array.from({length: n}, () => Math.floor(Math.random() * 3) - 1);

  const [vecA, setVecA] = React.useState(randomTernary(8));
  const [vecB, setVecB] = React.useState(randomTernary(8));

  const regenerate = () => {
    setVecA(randomTernary(dim));
    setVecB(randomTernary(dim));
  };

  // VSA operations
  const bind = (a, b) => a.map((v, i) => v * b[i]);
  const similarity = (a, b) => {
    const dot = a.reduce((s, v, i) => s + v * b[i], 0);
    return dot / Math.sqrt(a.length);
  };

  const bound = bind(vecA, vecB);
  const sim = similarity(vecA, vecB).toFixed(3);

  return (
    <div style={{fontFamily: 'monospace'}}>
      <button onClick={regenerate}>Generate New Vectors</button>
      <div style={{marginTop: '1rem'}}>
        <div><b>A:</b> [{vecA.join(', ')}]</div>
        <div><b>B:</b> [{vecB.join(', ')}]</div>
        <div><b>bind(A,B):</b> [{bound.join(', ')}]</div>
        <div><b>similarity:</b> {sim}</div>
      </div>
    </div>
  );
}
```

## Next Steps

- [Installation Guide](/docs/getting-started/installation) — Detailed setup
- [Development Setup](/docs/getting-started/development-setup) — IDE configuration
- [API Reference](/docs/api/) — Complete API documentation
