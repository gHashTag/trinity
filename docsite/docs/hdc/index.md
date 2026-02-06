---
sidebar_position: 1
---
# Hyperdimensional Computing

## What is HDC / VSA?

Hyperdimensional Computing (HDC), also known as Vector Symbolic Architecture (VSA), is a computational framework that represents and manipulates information using high-dimensional vectors. In Trinity, these vectors operate in ternary space, with each dimension taking a value from **\{-1, 0, +1\}** -- the same trit encoding used throughout the framework.

The fundamental insight of HDC is that in very high-dimensional spaces (typically 10,000 dimensions), randomly generated vectors are almost certainly quasi-orthogonal to one another. This mathematical property means that a large number of independent concepts can be represented simultaneously without interference, and complex data structures can be composed from simple algebraic operations.

## Core Concepts

### High-Dimensional Ternary Vectors

Each concept, symbol, or data item is represented as a **hypervector** -- a vector with 10,000 ternary dimensions. These vectors are stored using Trinity's `HybridBigInt` type, which supports both packed encoding (1.58 bits per trit) for memory efficiency and unpacked caching for fast element-wise operations.

Random hypervectors serve as the atomic building blocks. When generated independently, any two random 10,000-dimensional ternary vectors will have a cosine similarity very close to zero, meaning they are effectively orthogonal. This quasi-orthogonality is what makes the entire system work.

### Core Operations

Trinity's VSA module (`src/vsa.zig`) implements three fundamental operations:

**Bind** -- Associates two vectors together. Binding is implemented as element-wise multiplication of trits. The result is a new vector that is dissimilar to both inputs, representing the paired concept. Binding is its own inverse: `unbind(bind(A, B), A) = B`. This property enables retrieval of one element from a pair when the other is known.

**Bundle** -- Combines multiple vectors into a single composite vector through element-wise majority vote. Given several input vectors, the output trit at each dimension is the most common value among the inputs at that dimension. The result is similar to all inputs, representing their superposition. This is used to create class prototypes, memory vectors, and set representations.

**Permute** -- Shifts vector elements cyclically by a given count. Permutation creates a vector that is dissimilar to the original but can be reversed. It is used to encode positional or sequential information, so that the same symbol appearing at different positions produces different representations.

### Similarity Measurement

Trinity provides three similarity metrics for comparing hypervectors:

- **Cosine Similarity**: Measures the angle between two vectors, returning a value in [-1, 1]. This is the primary metric for classification and retrieval tasks.
- **Hamming Distance**: Counts the number of dimensions where two vectors differ. Useful for discrete distance measurement.
- **Dot Product Similarity**: Computes the inner product of two vectors. A simpler and faster alternative to cosine when magnitude normalization is not critical.

## Why HDC is Useful

**One-shot learning**: Because random vectors are quasi-orthogonal, a single example is often sufficient to define a class prototype. There is no need for thousands of training samples or gradient descent.

**Noise robustness**: The high dimensionality provides natural error correction. Even if a significant fraction of dimensions are corrupted, the overall similarity structure is preserved.

**Hardware efficiency**: All operations are element-wise on ternary values. Binding is multiplication of \{-1, 0, +1\} (equivalent to conditional sign flip). Bundling is majority vote. No floating-point multiply-accumulate units are needed, making HDC ideal for edge devices and FPGA implementations.

**Incremental learning**: New classes or data points can be added by simply bundling new vectors into existing prototypes. No retraining of the entire model is required, and previously learned knowledge is not disrupted.

**Interpretability**: Similarity scores provide direct, human-readable confidence measures. The algebraic structure allows decomposition of composite vectors to understand which components contributed to a decision.

## Continual Learning Results

Trinity's HDC implementation has been tested for continual learning across 10 phases with 20 classes. The key result: hyperdimensional prototypes do not suffer from catastrophic forgetting because each class has its own independent prototype vector with no shared weights.

| Metric | HDC (Trinity) | Neural Networks (Typical) |
|--------|---------------|---------------------------|
| Average forgetting | **3.04%** | 30-60% |
| Maximum forgetting | **12.5%** | 50-90% (catastrophic) |
| Retraining required | No | Yes (replay buffer, EWC) |
| Memory per class | O(dimension) | O(parameters) |

The small forgetting observed (max 12.5%) is attributable to decision boundary crowding as more classes are added, and vocabulary overlap between semantically related classes (e.g., "gaming" and "sports" share words like "game", "player"). The old prototype vectors themselves remain unchanged.

Test configuration: 10,000-dimensional vectors, 30 samples per class, 10 test samples per class, learning rate 0.5. All 9 continual learning tests pass. See `src/phi-engine/hdc/continual_learner.zig` for the implementation.

## How Trinity Implements HDC

The HDC subsystem is built on top of Trinity's core VSA operations. The `sequence_hdc.zig` module provides:

- **ItemMemory (Codebook)**: Maps symbols to random hypervectors. Each symbol is assigned a deterministic pseudo-random vector based on a seed value, ensuring reproducibility. Vectors are generated lazily and cached.

- **NGramEncoder**: Encodes sequences of symbols (such as characters in a word) using position-encoded binding. An n-gram is encoded as `bind(perm(c[0], n-1), bind(perm(c[1], n-2), ..., perm(c[n-1], 0)))`, where each character vector is permuted by its position before binding. This captures both the identity and order of symbols.

- **HDCTextEncoder**: A shared text encoding module supporting multiple encoding modes -- character n-gram, word-level with positional encoding, word-level with TF-IDF weighting, and hybrid combinations. This encoder is the foundation for all downstream HDC applications.

The full HDC application suite comprises 23 modules specified as `.vibee` specifications in the `specs/tri/` directory, covering classification, anomaly detection, knowledge graphs, reinforcement learning, and more. See the [HDC Applications](/docs/hdc/applications) page for the complete catalog.
