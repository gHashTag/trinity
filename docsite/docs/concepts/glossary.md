---
sidebar_position: 4
---

# Glossary

Quick reference for terms used throughout Trinity documentation. If a term is missing, check the [API Reference](/docs/api/) for module-specific definitions.

---

### Balanced ternary

Number system using \{-1, 0, +1\} instead of \{0, 1, 2\}. Negation is a simple sign flip. Truncation rounds to the nearest value automatically. See [Ternary Computing Concepts](/docs/concepts/).

### Bind

VSA operation that links two vectors via element-wise multiplication. The result is dissimilar to both inputs. Binding is its own inverse: `bind(bind(a, b), b) = a`. See [VSA API](/docs/api/vsa).

### BitNet b1.58

Neural network architecture using ternary weights \{-1, 0, +1\}. Each weight uses approximately 1.58 bits of storage. Eliminates multiplication in matrix operations. See [BitNet](/docs/bitnet).

### Bundle

VSA operation that combines vectors via majority vote. The result is similar to all inputs. Used to store multiple items in a single vector. See [VSA API](/docs/api/vsa).

### Codebook

A mapping from symbols (characters, words, labels) to [hypervectors](#hypervector). Also called ItemMemory. Each symbol gets a unique random vector. See [Sequence HDC](/docs/api/sequence-hdc).

### Cosine similarity

Measure of the angle between two vectors. Range: \[-1, 1\]. A value of +1 means identical, 0 means unrelated, and -1 means opposite. The primary similarity metric in Trinity's VSA.

### Dense vector

Vector that stores all elements explicitly, including zeros. Contrast with [sparse vector](#sparse-vector). See [HybridBigInt](/docs/api/hybrid).

### Dimension

The number of elements ([trits](#trit)) in a vector. Typical range: 1000 to 10000. Higher dimensions give better noise tolerance and cleaner separation between unrelated vectors.

### Dot product

Sum of element-wise products of two vectors. Related to [cosine similarity](#cosine-similarity) but without normalization by vector magnitudes.

### Hamming distance

Count of positions where two vectors differ. A distance of zero means the vectors are identical. Maximum distance equals the [dimension](#dimension).

### HDC

Hyperdimensional Computing. A computing framework that uses high-dimensional vectors for representation and reasoning. Equivalent to [VSA](#vsa). The two terms are used interchangeably.

### HybridBigInt

Trinity's main vector type. Supports dual-mode storage: [packed mode](#packed-mode) for memory efficiency and [unpacked mode](#unpacked-mode) for fast computation. Switches between modes automatically. See [Hybrid API](/docs/api/hybrid).

### Hypervector

A vector with thousands of dimensions, typically 1000 to 10000 [trits](#trit). The high dimensionality ensures that random vectors are [quasi-orthogonal](#quasi-orthogonal).

### JIT

Just-In-Time compilation. Trinity's JIT engine generates native SIMD instructions at runtime for faster VSA operations. See [JIT API](/docs/api/jit).

### Majority vote

Decision rule used in [bundling](#bundle). For each position, take the most common value among the input vectors. Ties are broken randomly. This preserves the signal from each input.

### N-gram

A contiguous subsequence of N items. For text, these are usually characters. The word "hello" contains the trigrams (3-grams): "hel", "ell", "llo". Used in [Sequence HDC](/docs/api/sequence-hdc) for text encoding.

### Packed mode

Storage mode using approximately 1.58 bits per [trit](#trit). Highly memory-efficient. Element access requires bit manipulation, making it slower than [unpacked mode](#unpacked-mode). Ideal for storage and transfer. See [Hybrid API](/docs/api/hybrid).

### Permute

Cyclic shift of vector elements. Shifts all elements by a given count, wrapping around at the boundary. The result is dissimilar to the original vector. Used to encode position or sequence order. See [VSA API](/docs/api/vsa).

### Quasi-orthogonal

Two vectors with [cosine similarity](#cosine-similarity) near zero. In high-dimensional spaces, random vectors are almost always quasi-orthogonal. This is the mathematical foundation that allows random vectors to represent distinct concepts.

### Sparse vector

Vector that stores only non-zero elements using coordinate (COO) format. Efficient when most elements are zero. Uses less memory than [dense vectors](#dense-vector) for high-sparsity data. See [Sparse API](/docs/api/sparse).

### Trit

A ternary digit. Takes the value -1, 0, or +1. Carries log2(3) = 1.58 bits of information. The fundamental unit of data in Trinity.

### Unbind

Reverse of [bind](#bind). Recovers one vector from a binding given the other. Because binding uses element-wise multiplication and trits are self-inverse, unbinding is mathematically identical to binding. See [VSA API](/docs/api/vsa).

### Unpacked mode

Storage mode using 8 bits (one byte) per [trit](#trit). Allows fast element access with no bit manipulation. Uses 5x more memory than [packed mode](#packed-mode). Ideal for computation. See [Hybrid API](/docs/api/hybrid).

### VSA

Vector Symbolic Architecture. A framework for symbolic AI that uses high-dimensional vectors. Core operations are [bind](#bind), [bundle](#bundle), and [permute](#permute). Trinity implements VSA using balanced ternary vectors. See [VSA API](/docs/api/vsa).
