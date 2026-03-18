---
sidebar_position: 12
sidebar_label: Python SDK
---

# Python SDK — trinity-vsa

Python ctypes binding to `libtrinity-vsa`. Uses the real SIMD-accelerated Zig core — ~20x faster than pure-Python numpy.

**Package:** `libs/python/trinity_vsa/`
**Module:** `trinity_vsa.native`

## Setup

```bash
# 1. Build the native library
zig build libvsa

# 2. Use from Python (no pip install needed)
python -c "
import sys; sys.path.insert(0, 'libs/python/trinity_vsa/src')
from trinity_vsa.native import NativeVSA
vsa = NativeVSA()
print(vsa.version())
"
```

The library auto-detects `zig-out/lib/libtrinity-vsa.dylib` (macOS) or `.so` (Linux). You can also pass an explicit path:

```python
vsa = NativeVSA(lib_path="/path/to/libtrinity-vsa.dylib")
```

## Two API Levels

### NativeVSA — Low-level handle-based API

Returns integer handles. You must call `vsa.free(handle)` for every vector.

```python
from trinity_vsa.native import NativeVSA

vsa = NativeVSA()

# Create vectors
a = vsa.random(10000, seed=42)
b = vsa.random(10000, seed=123)

# Compute similarity
sim = vsa.similarity(a, b)  # ~0.0 (quasi-orthogonal)

# Bind and unbind
bound = vsa.bind(a, b)
recovered = vsa.unbind(bound, b)
print(vsa.similarity(a, recovered))  # > 0.8

# Cleanup (required!)
vsa.free(a)
vsa.free(b)
vsa.free(bound)
vsa.free(recovered)
```

### Vector — RAII wrapper with automatic memory management

Vectors are freed automatically when garbage collected. Use keyword constructors.

```python
from trinity_vsa.native import NativeVSA, Vector

vsa = NativeVSA()

# Create vectors (multiple constructors)
v1 = Vector(vsa, random=(10000, 42))
v2 = Vector(vsa, text_words="machine learning")
v3 = Vector(vsa, zeros=1000)
v4 = Vector(vsa, data=[1, -1, 0, 1, -1])

# Operations return new Vectors
bound = v1.bind(v2)
bundled = v1.bundle(v2)
permuted = v1.permute(5)
clone = v1.clone()

# Similarity
print(v1.similarity(v2))
print(v1.hamming(v2))
print(v1.dot(v2))

# Properties
print(v1.dim)        # 10000
print(v1.to_list())  # [-1, 0, 1, 1, -1, ...]
# No manual free needed — handled by __del__
```

## Text Encoding & Search

### Word-level encoding

```python
vsa = NativeVSA()

v1 = Vector(vsa, text_words="machine learning")
v2 = Vector(vsa, text_words="deep learning")
v3 = Vector(vsa, text_words="database optimization")

print(v1.similarity(v2))   # 0.4133 (shared "learning")
print(v1.similarity(v3))   # -0.03  (unrelated)
print(v1.similarity(v1))   # 1.0    (identical)
```

### Semantic search

```python
vsa = NativeVSA()

corpus = [
    "machine learning algorithms for classification",
    "deep neural networks and backpropagation",
    "database query optimization techniques",
    "Zig systems programming language",
    "ternary computing and balanced ternary",
]

results = vsa.search("machine learning", corpus, top_n=3)
for sim, idx, text in results:
    print(f"  [{sim:.4f}] {text}")

# Output:
#   [0.5317] machine learning algorithms for classification
#   [0.2574] deep neural networks and backpropagation  (shared: "learning" context)
#   [0.0809] ...
```

### Associative memory

```python
vsa = NativeVSA()

france  = Vector(vsa, text_words="france")
paris   = Vector(vsa, text_words="paris")
germany = Vector(vsa, text_words="germany")
berlin  = Vector(vsa, text_words="berlin")

# Bind: country * capital
fr_pair = france.bind(paris)

# Query: what is the capital of France?
result = fr_pair.unbind(france)
print(result.similarity(paris))   # 0.8153 (strong match)
print(result.similarity(berlin))  # 0.0487 (weak — wrong city)
```

## NativeVSA API Reference

### Info

| Method | Returns | Description |
|--------|---------|-------------|
| `version()` | `str` | Library version (e.g. "0.2.0") |
| `max_dim()` | `int` | Maximum dimension (59049) |

### Vector Creation

| Method | Returns | Description |
|--------|---------|-------------|
| `zeros(dim)` | handle | Zero vector |
| `random(dim, seed)` | handle | Random hypervector (deterministic) |
| `from_array(list)` | handle | From list of int8 values |
| `clone(v)` | handle | Deep copy |
| `free(v)` | None | Free vector (NULL-safe) |

### VSA Operations

| Method | Returns | Description |
|--------|---------|-------------|
| `bind(a, b)` | handle | Element-wise multiply (association) |
| `unbind(bound, key)` | handle | Inverse of bind |
| `bundle2(a, b)` | handle | Majority vote of 2 vectors |
| `bundle3(a, b, c)` | handle | Majority vote of 3 vectors |
| `permute(v, shift)` | handle | Cyclic permutation |

### Similarity

| Method | Returns | Description |
|--------|---------|-------------|
| `similarity(a, b)` | `float` | Cosine similarity [-1.0, 1.0] |
| `hamming(a, b)` | `int` | Hamming distance |
| `dot(a, b)` | `int` | Dot product |

### Text Encoding

| Method | Returns | Description |
|--------|---------|-------------|
| `encode_text(text)` | handle | Character-level positional encoding |
| `encode_text_words(text)` | handle | Word-level bag-of-words (recommended for search) |
| `decode_text(v, max_len)` | `str` | Decode vector back to text |

### Search

| Method | Returns | Description |
|--------|---------|-------------|
| `search(query, corpus, top_n)` | `list[(sim, idx, text)]` | Semantic search over text list |

### Vector Access

| Method | Returns | Description |
|--------|---------|-------------|
| `dim(v)` | `int` | Vector dimension |
| `get_trit(v, i)` | `int` | Trit at index (-1, 0, +1) |
| `set_trit(v, i, val)` | None | Set trit at index |
| `to_list(v)` | `list[int]` | Export to list |

## Performance

Measured on Apple Silicon M1 (Python 3.12, ctypes -> libtrinity-vsa.dylib):

| Operation | Latency | Notes |
|-----------|---------|-------|
| `cosine_similarity` | 0.053 ms | SIMD-accelerated |
| `bind` + `free` | 0.106 ms | Heap alloc included |
| `encode_text_words` | 1.441 ms | Per text string |
| Search 16 items | 0.5-2.4 ms | End-to-end |
| `bundle2` | ~0.1 ms | SIMD majority vote |

Compared to pure-Python numpy implementation: **~20x faster** for core operations.
