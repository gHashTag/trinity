# trinity-vsa

[![PyPI](https://img.shields.io/pypi/v/trinity-vsa.svg)](https://pypi.org/project/trinity-vsa/)
[![Python](https://img.shields.io/pypi/pyversions/trinity-vsa.svg)](https://pypi.org/project/trinity-vsa/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

High-performance Vector Symbolic Architecture (VSA) library with balanced ternary arithmetic.

## Installation

```bash
pip install trinity-vsa
```

With PyTorch integration:
```bash
pip install trinity-vsa[torch]
```

## Quick Start

```python
from trinity_vsa import TritVector, bind, bundle, similarity

# Create random hypervectors
apple = TritVector.random(10000)
red = TritVector.random(10000)
fruit = TritVector.random(10000)

# Bind: create association "red apple"
red_apple = bind(apple, red)

# Bundle: combine concepts
fruits = bundle([apple, red_apple, fruit])

# Similarity: compare vectors
sim = similarity(red_apple, apple)
print(f"Similarity: {sim:.3f}")

# Unbind: retrieve associated concept
from trinity_vsa import unbind
recovered = unbind(red_apple, red)
recovery_sim = similarity(recovered, apple)
print(f"Recovery similarity: {recovery_sim:.3f}")
```

## Features

- **Balanced Ternary**: Values in {-1, 0, +1}
- **VSA Operations**: bind, bundle, permute, similarity
- **Multiple Storage**: Dense, Packed (4x savings), Sparse
- **NumPy Integration**: Seamless array operations
- **PyTorch/JAX**: Optional deep learning integration

## Storage Formats

```python
from trinity_vsa import TritVector, PackedTritVec, SparseVec

# Dense: 1 byte per trit
v = TritVector.random(10000)  # 10KB

# Packed: 2 bits per trit
packed = PackedTritVec.from_trit_vector(v)  # 2.5KB

# Sparse: only non-zeros
sparse = SparseVec.from_trit_vector(v)  # ~3KB for 33% density
```

## VSA Theory

```
Binding (⊗):   bind(a, b) = element-wise multiply
               bind(a, a) = all +1
               bind(a, bind(a, b)) = b

Bundling (+):  bundle([a, b, c]) = majority vote
               Result similar to all inputs

Permutation:   permute(v, k) = circular shift by k
               Used for sequence encoding
```

## Examples

### Associative Memory

```python
from trinity_vsa import TritVector, bind, similarity

# Create item-attribute pairs
items = {
    "apple": TritVector.random(10000),
    "banana": TritVector.random(10000),
}
colors = {
    "red": TritVector.random(10000),
    "yellow": TritVector.random(10000),
}

# Store associations
memory = [
    bind(items["apple"], colors["red"]),
    bind(items["banana"], colors["yellow"]),
]

# Query: "What color is apple?"
query = bind(items["apple"], colors["red"])
for i, mem in enumerate(memory):
    print(f"Memory {i}: {similarity(query, mem):.3f}")
```

### Sequence Encoding

```python
from trinity_vsa import TritVector, bind, permute, similarity

# Word vectors
words = {w: TritVector.random(10000) for w in ["the", "cat", "sat"]}

# Encode sequence with position
def encode_sequence(word_list):
    result = words[word_list[0]]
    for i, word in enumerate(word_list[1:], 1):
        result = bind(result, permute(words[word], i))
    return result

seq1 = encode_sequence(["the", "cat", "sat"])
seq2 = encode_sequence(["the", "sat", "cat"])  # Different order

print(f"Same order similarity: {similarity(seq1, seq1):.3f}")
print(f"Different order: {similarity(seq1, seq2):.3f}")
```

## Benchmarks

| Operation | Dimension | Time |
|-----------|-----------|------|
| bind | 10,000 | 15 µs |
| bundle (5 vectors) | 10,000 | 45 µs |
| similarity | 10,000 | 12 µs |
| packed bind | 10,000 | 8 µs |

## Why trinity-vsa?

| Feature | trit-vsa (Rust) | **trinity-vsa** |
|---------|-----------------|-----------------|
| Language | Rust only | Python, Rust, C, Zig |
| NumPy integration | ❌ | ✅ |
| PyTorch integration | ❌ | ✅ |
| FPGA support | ❌ | ✅ |
| Knowledge Graph | ❌ | ✅ |

## License

MIT License

## References

1. Kanerva, P. (2009). "Hyperdimensional Computing"
2. [Trinity Project](https://github.com/gHashTag/trinity)
