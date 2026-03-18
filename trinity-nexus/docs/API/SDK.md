# Trinity SDK Documentation

**Version**: 0.2.0  
**Author**: Dmitrii Vasilev  
**Formula**: V = n × 3^k × π^m × φ^p × e^q  
**Identity**: φ² + 1/φ² = 3

## Overview

Trinity SDK provides high-level APIs for hyperdimensional computing (HDC) using balanced ternary vectors. The SDK is designed for two audiences:

1. **Developers** (`sdk.zig`) - Simple, intuitive API for building applications
2. **Researchers** (`science.zig`) - Mathematical operations for scientific analysis

## Quick Start

```zig
const trinity = @import("trinity");

// Create hypervectors
var apple = trinity.Hypervector.random(10000, 0xAPPLE);
var banana = trinity.Hypervector.random(10000, 0xBANANA);

// Bind (association)
var apple_banana = apple.bind(&banana);

// Bundle (superposition)
var fruits = apple.bundle(&banana);

// Similarity
const sim = apple.similarity(&banana);  // ≈ 0 (orthogonal)
```

## Core Concepts

### Hypervectors

Hypervectors are high-dimensional vectors with ternary values {-1, 0, +1}. Key properties:

- **High dimensionality** (typically 1,000 - 10,000)
- **Quasi-orthogonality**: Random vectors are nearly orthogonal
- **Holographic**: Information distributed across all dimensions
- **Noise-tolerant**: Robust to errors and missing data

### Operations

| Operation | Symbol | Description | Properties |
|-----------|--------|-------------|------------|
| **Bind** | ⊗ | Association | Self-inverse, preserves similarity |
| **Bundle** | + | Superposition | Similar to all inputs |
| **Permute** | ρ | Position encoding | Quasi-orthogonal shifts |

## Developer API (sdk.zig)

### Hypervector

```zig
const Hypervector = trinity.Hypervector;

// Creation
var hv = Hypervector.init(dimension);           // Zero vector
var hv = Hypervector.random(dimension, seed);   // Random vector

// Operations
var bound = a.bind(&b);           // Association
var unbound = bound.unbind(&b);   // Recover a
var bundled = a.bundle(&b);       // Superposition
var permuted = a.permute(k);      // Shift by k

// Similarity
const sim = a.similarity(&b);           // Cosine [-1, 1]
const hamming = a.hammingDistance(&b);  // Count of differences
const dot = a.dotSimilarity(&b);        // Normalized dot product

// Utility
const dim = hv.dimension();
const density = hv.density();
const count = hv.countNonZero();
var clone = hv.clone();
var neg = hv.negate();
```

### Codebook

Symbol table for encoding/decoding:

```zig
var codebook = Codebook.init(allocator, dimension);
defer codebook.deinit();

// Encode symbol to hypervector
var apple_hv = try codebook.encode("apple");

// Decode hypervector to nearest symbol
const symbol = codebook.decode(&query_hv);

// Decode with threshold
const symbol = codebook.decodeWithThreshold(&query_hv, 0.5);
```

### AssociativeMemory

Content-addressable memory:

```zig
var memory = AssociativeMemory.init(dimension);

// Store key-value pairs
memory.store(&key, &value);

// Retrieve by key
var retrieved = memory.retrieve(&key);

// Check existence
const exists = memory.contains(&key, 0.3);

// Clear
memory.clear();
```

### SequenceEncoder

For ordered data:

```zig
var encoder = SequenceEncoder.init(dimension);

// Encode sequence
var items = [_]Hypervector{ a, b, c };
var sequence = encoder.encode(&items);

// Probe for element at position
const sim = encoder.probe(&sequence, &candidate, position);

// Find position of element
const pos = encoder.findPosition(&sequence, &candidate, max_len, threshold);
```

### GraphEncoder

For relational data (RDF-like triples):

```zig
var graph = GraphEncoder.init(dimension);

// Encode triple (subject, predicate, object)
var triple = graph.encodeTriple(&subject, &predicate, &object);

// Query components
var subj = graph.querySubject(&triple);
var pred = graph.queryPredicate(&triple);
var obj = graph.queryObject(&triple);
```

### Classifier

Simple HDC classifier:

```zig
var classifier = Classifier.init(allocator, dimension);
defer classifier.deinit();

// Train
try classifier.train("positive", &sample1);
try classifier.train("positive", &sample2);
try classifier.train("negative", &sample3);

// Predict
const class = classifier.predict(&query);

// Predict with confidence
const result = classifier.predictWithConfidence(&query);
// result.class, result.confidence
```

## Science API (science.zig)

### Statistical Analysis

```zig
const stats = trinity.computeStats(&hv);

// Available fields:
stats.dimension
stats.positive_count
stats.negative_count
stats.zero_count
stats.density
stats.balance
stats.entropy
stats.mean
stats.variance
stats.std_dev
```

### Distance Metrics

```zig
const d = trinity.distance(&a, &b, metric);

// Available metrics:
.hamming     // Normalized Hamming distance
.cosine      // 1 - cosine similarity
.euclidean   // L2 distance
.manhattan   // L1 distance
.jaccard     // Jaccard distance
.dice        // Dice distance
```

### Information Theory

```zig
// Mutual information
const mi = trinity.mutualInformation(&a, &b);

// Conditional entropy H(A|B)
const ce = trinity.science.conditionalEntropy(&a, &b);
```

### Batch Operations

```zig
// Batch similarity matrix
const matrix = try trinity.batchSimilarity(&vectors, allocator);

// Batch bundle (majority voting)
const bundled = trinity.batchBundle(&vectors);

// Weighted bundle
const weighted = trinity.weightedBundle(&vectors, &weights);
```

### Sparse Hypervectors

For memory-efficient storage:

```zig
var sparse = try SparseHypervector.fromDense(allocator, &hv);
defer sparse.deinit();

const sparsity = sparse.sparsity();
const efficiency = sparse.memoryEfficiency();

var dense = sparse.toDense();
```

### Resonator Network

For factorization problems:

```zig
var resonator = try ResonatorNetwork.init(dimension, num_factors, codebook_size, allocator);

const factors = try resonator.factorize(&composite);
```

## Mathematical Constants

```zig
trinity.PHI              // 1.618... (golden ratio)
trinity.PHI_SQUARED      // 2.618... (φ²)
trinity.GOLDEN_IDENTITY  // 3.0 (φ² + 1/φ² = 3)
```

## Examples

### Text Classification

```zig
// Encode text using n-grams
var encoder = TextEncoder.init(allocator, 10000, 3);
var encoded = try encoder.encode("great product");

// Train classifier
try classifier.train("positive", &encoded);

// Predict
const class = classifier.predict(&query);
```

### Knowledge Graph

```zig
// Encode triple
var triple = graph.encodeTriple(&paris, &capital_of, &france);

// Query: What is the capital of France?
var subject = graph.querySubject(&triple);
const answer = codebook.decode(&subject);  // "Paris"
```

### Analogical Reasoning

```zig
// Paris : France :: Berlin : ?
var relation = france.unbind(&paris);
var answer = berlin.bind(&relation);
// answer ≈ Germany
```

## Performance Tips

1. **Dimension**: Use 1,000-10,000 for most applications
2. **Seed**: Use consistent seeds for reproducible results
3. **Batch operations**: Use `batchBundle` for many vectors
4. **Sparse**: Use `SparseHypervector` for >90% zero trits

## References

1. Kanerva, P. (2009). Hyperdimensional Computing
2. Rahimi, A. et al. (2016). Hyperdimensional Computing for NLP
3. Kleyko, D. et al. (2021). Vector Symbolic Architectures Survey

---

**ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q**

**φ² + 1/φ² = 3**
