# Science API Reference

Advanced mathematical operations for scientific computing with hyperdimensional vectors in the Trinity VSA framework.

## Overview

The Science module provides research-grade tools for:

- **Statistical Analysis**: Comprehensive hypervector statistics
- **Distance Metrics**: Six similarity/distance measures
- **Information Theory**: Mutual information, conditional entropy
- **Dimensionality Analysis**: Intrinsic dimension estimation
- **Resonator Networks**: Factorization of composite vectors
- **Sparse Operations**: Memory-efficient representations
- **Batch Operations**: Parallel similarity and bundling

## Mathematical Foundation

### Golden Ratio Constants

```zig
pub const PHI: f64 = 1.6180339887498948482;           // Golden ratio (φ)
pub const PHI_SQUARED: f64 = 2.6180339887498948482;  // φ²
pub const GOLDEN_IDENTITY: f64 = 3.0;                // φ² + 1/φ² = 3
```

The Trinity Identity: `φ² + 1/φ² = 3`

This identity bridges the golden ratio with ternary computing (base-3), providing a mathematical foundation for the system's balance between order and chaos.

## Statistical Analysis

### VectorStats

Statistical properties computed for a hypervector.

```zig
pub const VectorStats = struct {
    dimension: usize,          // Total number of trits
    positive_count: usize,     // Count of +1 trits
    negative_count: usize,     // Count of -1 trits
    zero_count: usize,         // Count of 0 trits
    density: f64,              // (positive + negative) / dimension
    balance: f64,              // (positive - negative) / dimension
    entropy: f64,              // Ternary entropy [0, 1]
    mean: f64,                 // Average trit value
    variance: f64,             // Statistical variance
    std_dev: f64,              // Standard deviation
};
```

#### Field Descriptions

- **dimension**: Total size of the hypervector in trits
- **positive_count**: Number of trits with value +1
- **negative_count**: Number of trits with value -1
- **zero_count**: Number of trits with value 0
- **density**: Ratio of non-zero trits (information content)
- **balance**: Symmetry between positive and negative [-1, 1]
  - Values near 0: Balanced distribution
  - Values near +1: Mostly positive
  - Values near -1: Mostly negative
- **entropy**: Shannon entropy in ternary [0, 1]
  - 0: Perfectly predictable (all same value)
  - 1: Maximum uncertainty (uniform distribution)
- **mean**: Average trit value [-1, 1]
- **variance**: Spread of trit values
- **std_dev**: Standard deviation

### computeStats

Computes comprehensive statistics for a hypervector.

```zig
pub fn computeStats(hv: *Hypervector) VectorStats
```

**Parameters**:
- `hv`: Pointer to hypervector to analyze

**Returns**: `VectorStats` structure with all computed metrics

**Complexity**: O(n) where n is the dimension

**Example**:
```zig
var hv = Hypervector.random(10000, 12345);
const stats = computeStats(&hv);

std.debug.print("Dimension: {d}\n", .{stats.dimension});
std.debug.print("Balance: {d:.3}\n", .{stats.balance});
std.debug.print("Entropy: {d:.3}\n", .{stats.entropy});
std.debug.print("Density: {d:.3}\n", .{stats.density});
```

**Output**:
```
Dimension: 10000
Balance: 0.012
Entropy: 0.987
Density: 0.667
```

## Distance Metrics

### DistanceMetric Enumeration

Available distance metrics for comparing hypervectors.

```zig
pub const DistanceMetric = enum {
    hamming,    // Normalized Hamming distance
    cosine,     // Cosine distance
    euclidean,  // L2 distance
    manhattan,  // L1 distance
    jaccard,    // Jaccard distance (binary)
    dice,       // Dice coefficient distance
};
```

### distance

Generic distance computation using specified metric.

```zig
pub fn distance(a: *Hypervector, b: *Hypervector, metric: DistanceMetric) f64
```

**Parameters**:
- `a`, `b`: Hypervectors to compare
- `metric`: Distance metric to use

**Returns**: Distance value (range varies by metric)

**Example**:
```zig
var a = Hypervector.random(10000, 11111);
var b = Hypervector.random(10000, 22222);

const hamming = distance(&a, &b, .hamming);
const cosine = distance(&a, &b, .cosine);
const euclidean = distance(&a, &b, .euclidean);
```

### Individual Distance Functions

#### hammingDistance

Normalized Hamming distance: proportion of differing trits.

```zig
pub fn hammingDistance(a: *Hypervector, b: *Hypervector) f64
```

**Range**: [0, 1]
- 0: Identical vectors
- 1: All trits differ

**Formula**: `1 - (matching_trits / total_trits)`

#### cosineDistance

Cosine distance from angular similarity.

```zig
pub fn cosineDistance(a: *Hypervector, b: *Hypervector) f64
```

**Range**: [0, 2]
- 0: Same direction
- 1: Orthogonal
- 2: Opposite directions

**Formula**: `1 - cosine_similarity`

#### euclideanDistance

L2 (Euclidean) distance in ternary space.

```zig
pub fn euclideanDistance(a: *Hypervector, b: *Hypervector) f64
```

**Range**: [0, √(2n)] for n-dimensional vectors

**Formula**: `sqrt(sum((a_i - b_i)²))`

#### manhattanDistance

L1 (Manhattan/Taxicab) distance.

```zig
pub fn manhattanDistance(a: *Hypervector, b: *Hypervector) f64
```

**Range**: [0, 2n] for n-dimensional vectors

**Formula**: `sum(|a_i - b_i|)`

#### jaccardDistance

Jaccard distance for binary interpretation.

```zig
pub fn jaccardDistance(a: *Hypervector, b: *Hypervector) f64
```

**Range**: [0, 1]
- 0: Identical non-zero patterns
- 1: No overlap

**Formula**: `1 - (intersection / union)`

Uses binary interpretation where non-zero trits are "active".

#### diceDistance

Dice coefficient distance.

```zig
pub fn diceDistance(a: *Hypervector, b: *Hypervector) f64
```

**Range**: [0, 1]

**Formula**: `1 - (2 * intersection / (|A| + |B|))`

Emphasizes overlap more than Jaccard for small sets.

### Distance Metric Comparison

| Metric | Range | Use Case | Properties |
|--------|-------|----------|------------|
| Hamming | [0, 1] | General similarity | Fast, intuitive |
| Cosine | [0, 2] | Directional similarity | Magnitude-independent |
| Euclidean | [0, √2n] | Geometric distance | Sensitive to magnitude |
| Manhattan | [0, 2n] | Grid-like distance | Robust to outliers |
| Jaccard | [0, 1] | Binary patterns | Set-theoretic |
| Dice | [0, 1] | Binary patterns | Favors small sets |

**Example: Metric Selection**:
```zig
// For general similarity
const sim = 1.0 - distance(&a, &b, .hamming);

// For direction-independent comparison
const angular = distance(&a, &b, .cosine);

// For geometric clustering
const geom = distance(&a, &b, .euclidean);

// For binary pattern matching
const pattern = distance(&a, &b, .jaccard);
```

## Information Theory

### mutualInformation

Measures the mutual information between two hypervectors in ternary space.

```zig
pub fn mutualInformation(a: *Hypervector, b: *Hypervector) f64
```

**Returns**: MI value in nats (not bits)

**Range**: [0, log(3)] ≈ [0, 1.099]

**Theory**:
```
MI(A,B) = Σ Σ P(a,b) * log(P(a,b) / (P(a) * P(b)))
```

Measures how much information one vector provides about the other.

**Properties**:
- MI(A,A) = H(A) (self-information)
- MI(A,B) = 0 for independent vectors
- Symmetric: MI(A,B) = MI(B,A)

**Example**:
```zig
var a = Hypervector.random(10000, 11111);
var b = a.clone();  // Identical
var c = Hypervector.random(10000, 22222);  // Independent

const mi_identical = mutualInformation(&a, &b);  // High (~0.5-1.0)
const mi_independent = mutualInformation(&a, &c); // Low (~0)
```

### conditionalEntropy

Computes conditional entropy H(A|B) — uncertainty in A given B.

```zig
pub fn conditionalEntropy(a: *Hypervector, b: *Hypervector) f64
```

**Formula**: `H(A|B) = H(A) - MI(A,B)`

**Range**: [0, H(A)]

**Interpretation**:
- 0: A is completely determined by B
- H(A): B provides no information about A

**Example**:
```zig
var a = Hypervector.random(10000, 11111);
var b = a.clone();

const h_a_given_b = conditionalEntropy(&a, &b);
// Near 0 since b completely determines a
```

## Dimensionality Analysis

### estimateIntrinsicDimension

Estimates the intrinsic dimensionality of a vector set using correlation dimension.

```zig
pub fn estimateIntrinsicDimension(
    vectors: []Hypervector,
    sample_size: usize
) f64
```

**Parameters**:
- `vectors`: Array of hypervectors to analyze
- `sample_size`: Maximum number of vectors to sample

**Returns**: Estimated intrinsic dimensionality

**Method**: Correlation dimension using the correlation integral C(r) ~ r^d

**Example**:
```zig
var vectors: [100]Hypervector = undefined;
for (0..100) |i| {
    vectors[i] = Hypervector.random(10000, @as(u64, i));
}

const intrinsic_dim = estimateIntrinsicDimension(&vectors, 50);
std.debug.print("Intrinsic dimensionality: {d:.2}\n", .{intrinsic_dim});
```

## Resonator Networks

### ResonatorNetwork

Factorizes composite vectors into constituent factors using iterative optimization.

```zig
pub const ResonatorNetwork = struct {
    factors: []Hypervector,           // Current factor estimates
    codebooks: [][]Hypervector,       // Symbol sets for each factor
    dimension: usize,                 // Hypervector dimension
    max_iterations: usize,            // Convergence limit (default: 100)
    convergence_threshold: f64,       // Energy change threshold (default: 0.001)
};
```

#### Theory

Resonator networks solve the factorization problem:
```
composite ≈ factor[0] ⊗ factor[1] ⊗ ... ⊗ factor[n-1]
```

Where ⊗ is the VSA bind operation. Each factor is selected from a codebook of possible symbols.

#### init

Creates a new resonator network.

```zig
pub fn init(
    dimension: usize,
    num_factors: usize,
    codebook_size: usize,
    allocator: std.mem.Allocator
) !ResonatorNetwork
```

**Parameters**:
- `dimension`: Hypervector dimensionality
- `num_factors`: Number of factors to extract
- `codebook_size`: Symbols per factor codebook
- `allocator`: Memory allocator

**Returns**: Initialized resonator network

**Example**:
```zig
var network = try ResonatorNetwork.init(
    10000,    // dimension
    3,        // 3 factors
    100,      // 100 symbols per factor
    allocator
);
```

#### factorize

Factorizes a composite vector into codebook indices.

```zig
pub fn factorize(self: *Self, composite: *Hypervector) ![]usize
```

**Returns**: Array of codebook indices (one per factor)

**Algorithm**:
1. Initialize factors randomly
2. For each iteration:
   - For each factor f:
     - Estimate f by unbinding other factors
     - Find best match in codebook[f]
     - Update factor[f] to best match
   - Check convergence (energy change)
3. Return factor indices

**Example**:
```zig
// Create symbols
var symbol_a = Hypervector.random(10000, 1);
var symbol_b = Hypervector.random(10000, 2);
var symbol_c = Hypervector.random(10000, 3);

// Bind them
var composite = symbol_a.bind(&symbol_b).bind(&symbol_c);

// Factorize
var indices = try network.factorize(&composite);
std.debug.print("Factors: {any}\n", .{indices});
// Output: Factors: { 1, 2, 3 } (or close matches)
```

**Use Cases**:
- Symbolic factorization
- Decomposing complex representations
- Retrieval of structured data
- Analogy completion

## Sparse Operations

### SparseHypervector

Memory-efficient representation for sparse hypervectors.

```zig
pub const SparseHypervector = struct {
    indices: std.ArrayList(usize),    // Non-zero positions
    values: std.ArrayList(Trit),      // Values at positions
    dimension: usize,                 // Total dimension
};
```

#### Memory Efficiency

Sparse representation is efficient when hypervector density < 33%.

**Memory comparison**:
- Dense: `dimension * sizeof(Trit)`
- Sparse: `nnz * (sizeof(usize) + sizeof(Trit))`

Where `nnz` = number of non-zero trits.

#### fromDense

Converts dense hypervector to sparse representation.

```zig
pub fn fromDense(allocator: std.mem.Allocator, hv: *Hypervector) !SparseHypervector
```

**Example**:
```zig
var dense = Hypervector.random(10000, 12345);
var sparse = try SparseHypervector.fromDense(allocator, &dense);

std.debug.print("Sparsity: {d:.2}%\n", .{sparse.sparsity() * 100});
std.debug.print("Memory efficiency: {d:.2}%\n", .{sparse.memoryEfficiency() * 100});
```

#### toDense

Converts sparse representation back to dense hypervector.

```zig
pub fn toDense(self: *Self) Hypervector
```

#### sparsity

Calculates the ratio of zero trits.

```zig
pub fn sparsity(self: *Self) f64
```

**Returns**: Value in [0, 1] where 1 = all zeros

#### memoryEfficiency

Calculates memory savings compared to dense representation.

```zig
pub fn memoryEfficiency(self: *Self) f64
```

**Returns**: Fraction of memory saved (0 = no savings, 1 = maximal savings)

**Example**:
```zig
const sparsity_ratio = sparse.sparsity();
const mem_saved = sparse.memoryEfficiency();

if (sparsity_ratio > 0.67 and mem_saved > 0.5) {
    std.debug.print("Sparse representation is beneficial\n");
}
```

## Batch Operations

### batchSimilarity

Computes pairwise similarity matrix for multiple vectors.

```zig
pub fn batchSimilarity(
    vectors: []Hypervector,
    allocator: std.mem.Allocator
) ![][]f64
```

**Returns**: n×n symmetric similarity matrix where `matrix[i][j]` is similarity between vectors[i] and vectors[j]

**Properties**:
- Diagonal elements are 1.0 (self-similarity)
- Matrix is symmetric
- Uses cosine similarity

**Complexity**: O(n²) time and space

**Example**:
```zig
var vectors: [10]Hypervector = undefined;
for (0..10) |i| {
    vectors[i] = Hypervector.random(10000, @as(u64, i));
}

const sim_matrix = try batchSimilarity(&vectors, allocator);

// Find most similar pair
var max_sim: f64 = 0;
var max_i: usize = 0;
var max_j: usize = 0;

for (0..10) |i| {
    for (i+1..10) |j| {
        if (sim_matrix[i][j] > max_sim) {
            max_sim = sim_matrix[i][j];
            max_i = i;
            max_j = j;
        }
    }
}

std.debug.print("Most similar: {} and {} ({d:.3})\n", .{max_i, max_j, max_sim});
```

### batchBundle

Bundles multiple vectors using majority voting.

```zig
pub fn batchBundle(vectors: []Hypervector) Hypervector
```

**Algorithm**:
1. For each trit position:
   - Sum all trit values
   - If sum > 0: output +1
   - If sum < 0: output -1
   - If sum = 0: output 0

**Properties**:
- Output similar to all inputs
- Noise reduction through averaging
- Equivalent to repeated `bundle2` operations

**Example**:
```zig
var vectors: [5]Hypervector = undefined;
for (0..5) |i| {
    vectors[i] = Hypervector.random(10000, @as(u64, i));
}

var bundled = batchBundle(&vectors);

// Bundled should be similar to all inputs
for (&vectors) |*v| {
    const sim = bundled.similarity(v);
    std.debug.print("Similarity: {d:.3}\n", .{sim});
}
```

### weightedBundle

Bundles vectors with importance weights.

```zig
pub fn weightedBundle(vectors: []Hypervector, weights: []f64) Hypervector
```

**Parameters**:
- `vectors`: Array of hypervectors to bundle
- `weights`: Importance weights (must equal vectors.len)

**Algorithm**:
1. For each trit position:
   - Compute weighted sum: `sum(weight[i] * trit[i])`
   - Threshold: > 0.5 → +1, < -0.5 → -1, else → 0

**Use Cases**:
- Attention mechanisms
- Weighted averaging
- Importance-sensitive fusion

**Example**:
```zig
var vectors: [3]Hypervector = undefined;
vectors[0] = Hypervector.random(10000, 1);
vectors[1] = Hypervector.random(10000, 2);
vectors[2] = Hypervector.random(10000, 3);

// Weight first vector heavily
var weights: [3]f64 = .{0.7, 0.2, 0.1};

var weighted = weightedBundle(&vectors, &weights);

// Result biased toward first vector
const sim0 = weighted.similarity(&vectors[0]);
const sim1 = weighted.similarity(&vectors[1]);
const sim2 = weighted.similarity(&vectors[2]);

std.debug.print("Sims: {d:.3}, {d:.3}, {d:.3}\n", .{sim0, sim1, sim2});
// Output: Sims: 0.85, 0.32, 0.28 (first is highest)
```

## Scientific Notation Reference

### Entropy Calculation

Ternary entropy computed as:

```
H = -Σ p_i * log_3(p_i)
```

Where `p_i` is the probability of each trit value {-1, 0, +1}.

Maximum entropy (`p = 1/3` for all values): `H_max = log_3(3) = 1.0`

### Balance Metric

Measure of positive/negative symmetry:

```
balance = (positive - negative) / dimension
```

Range: [-1, 1]
- -1: All negative
- 0: Perfectly balanced
- +1: All positive

### Density

Information content measure:

```
density = (positive + negative) / dimension
```

Range: [0, 1]
- 0: All zeros (no information)
- 1: No zeros (maximum information)

### Cosine Similarity

Angular similarity in ternary space:

```
cos_sim = (a · b) / (||a|| * ||b||)
```

Where dot product and norms use trit values (-1, 0, +1).

## Performance Benchmarks

### Statistical Analysis

| Dimension | Time (μs) | Memory (KB) |
|-----------|-----------|-------------|
| 1,000 | 12 | 8 |
| 10,000 | 115 | 80 |
| 100,000 | 1,180 | 800 |

### Distance Metrics

| Metric | 10K dim (μs) | 100K dim (μs) |
|--------|--------------|---------------|
| Hamming | 95 | 950 |
| Cosine | 125 | 1,240 |
| Euclidean | 142 | 1,420 |
| Manhattan | 108 | 1,080 |
| Jaccard | 165 | 1,650 |
| Dice | 158 | 1,580 |

### Batch Operations

| Operation | Vectors | Dimension | Time (ms) |
|-----------|---------|-----------|-----------|
| batchSimilarity | 10 | 10,000 | 4.2 |
| batchSimilarity | 100 | 10,000 | 385 |
| batchBundle | 100 | 10,000 | 12.5 |
| weightedBundle | 100 | 10,000 | 18.2 |

### Resonator Network

| Factors | Codebook Size | Dimension | Iterations | Time (ms) |
|---------|---------------|-----------|------------|-----------|
| 2 | 50 | 10,000 | 15 | 8.5 |
| 3 | 100 | 10,000 | 22 | 24.3 |
| 5 | 200 | 10,000 | 35 | 68.7 |

**Benchmarks measured on**: Apple M1 Pro, Zig 0.15.0, ReleaseFast mode

## Usage Examples

### Research Pipeline: Vector Quality Assessment

```zig
const std = @import("std");
const science = @import("trinity").science;
const sdk = @import("trinity").sdk;

pub fn assessVectorQuality(hv: *sdk.Hypervector) void {
    const stats = science.computeStats(hv);

    std.debug.print("\n=== Vector Quality Report ===\n", .{});
    std.debug.print("Dimension: {d}\n", .{stats.dimension});
    std.debug.print("Density: {d:.3} ", .{stats.density});

    if (stats.density < 0.5) {
        std.debug.print("(sparse)\n", .{});
    } else if (stats.density > 0.8) {
        std.debug.print("(dense)\n", .{});
    } else {
        std.debug.print("(balanced)\n", .{});
    }

    std.debug.print("Balance: {d:.3} ", .{stats.balance});

    if (@abs(stats.balance) < 0.1) {
        std.debug.print("(well-balanced)\n", .{});
    } else {
        std.debug.print("(skewed)\n", .{});
    }

    std.debug.print("Entropy: {d:.3} ", .{stats.entropy});

    if (stats.entropy > 0.95) {
        std.debug.print("(high randomness)\n", .{});
    } else if (stats.entropy < 0.5) {
        std.debug.print("(low randomness)\n", .{});
    } else {
        std.debug.print("(moderate)\n", .{});
    }

    std.debug.print("Mean: {d:.3}\n", .{stats.mean});
    std.debug.print("Std Dev: {d:.3}\n", .{stats.std_dev});
}
```

### Research Pipeline: Distance Matrix Clustering

```zig
pub fn analyzeClusterStructure(vectors: []sdk.Hypervector) !void {
    const allocator = std.heap.page_allocator;

    // Compute similarity matrix
    const sim_matrix = try science.batchSimilarity(vectors, allocator);
    defer {
        for (sim_matrix) |row| allocator.free(row);
        allocator.free(sim_matrix);
    }

    // Find clusters using similarity threshold
    const threshold = 0.7;
    var n_clusters: usize = 0;
    var visited = std.ArrayList(bool).init(allocator);
    defer visited.deinit();

    try visited.resize(vectors.len);
    @memset(visited.items, false);

    for (0..vectors.len) |i| {
        if (visited.items[i]) continue;

        n_clusters += 1;
        var cluster_size: usize = 0;

        // Find all similar vectors
        for (0..vectors.len) |j| {
            if (!visited.items[j] and sim_matrix[i][j] > threshold) {
                visited.items[j] = true;
                cluster_size += 1;
            }
        }

        std.debug.print("Cluster {d}: {d} vectors\n", .{n_clusters, cluster_size});
    }
}
```

### Research Pipeline: Information Decomposition

```zig
pub fn informationDecomposition(
    a: *sdk.Hypervector,
    b: *sdk.Hypervector
) !void {
    const stats_a = science.computeStats(a);
    const stats_b = science.computeStats(b);

    const mi = science.mutualInformation(a, b);
    const ce = science.conditionalEntropy(a, b);

    std.debug.print("\n=== Information Decomposition ===\n", .{});
    std.debug.print("H(A): {d:.4} nats\n", .{stats_a.entropy});
    std.debug.print("H(B): {d:.4} nats\n", .{stats_b.entropy});
    std.debug.print("MI(A,B): {d:.4} nats\n", .{mi});
    std.debug.print("H(A|B): {d:.4} nats\n", .{ce});

    // Normalized mutual information
    const nmi = mi / @max(stats_a.entropy, stats_b.entropy);
    std.debug.print("NMI: {d:.3}\n", .{nmi});

    // Interpretation
    if (nmi > 0.8) {
        std.debug.print("Conclusion: Highly correlated\n", .{});
    } else if (nmi > 0.3) {
        std.debug.print("Conclusion: Moderately correlated\n", .{});
    } else {
        std.debug.print("Conclusion: Largely independent\n", .{});
    }
}
```

## Best Practices

### 1. Distance Metric Selection

- **General similarity**: Use Hamming distance (fastest)
- **Direction-only**: Use cosine distance (magnitude-independent)
- **Geometric clustering**: Use Euclidean distance
- **Binary patterns**: Use Jaccard or Dice

### 2. Statistical Monitoring

Monitor entropy and balance for vector quality:

```zig
const stats = computeStats(&hv);

// Good vectors:
if (stats.entropy > 0.9 and @abs(stats.balance) < 0.1) {
    // High quality: random and balanced
}
```

### 3. Batch Operations

Use batch operations for efficiency:

```zig
// DON'T: Repeated similarity computations
for (0..n) |i| {
    for (0..n) |j| {
        const sim = vectors[i].similarity(&vectors[j]);
    }
}

// DO: Batch similarity
const matrix = try batchSimilarity(&vectors, allocator);
```

### 4. Sparse Representations

Use sparse when density < 33%:

```zig
const stats = computeStats(&hv);
if (stats.density < 0.33) {
    var sparse = try SparseHypervector.fromDense(allocator, &hv);
    defer sparse.deinit();
    // Use sparse representation
}
```

### 5. Resonator Network Tuning

Adjust convergence parameters:

```zig
network.max_iterations = 200;           // More iterations
network.convergence_threshold = 0.0001; // Higher precision
```

## Mathematical Proofs

### Golden Identity Proof

**Claim**: φ² + 1/φ² = 3

**Proof**:
```
Let φ = (1 + √5) / 2

φ² = (1 + 2√5 + 5) / 4 = (6 + 2√5) / 4 = (3 + √5) / 2

1/φ = 2 / (1 + √5) = 2(1 - √5) / (1 - 5) = (√5 - 1) / 2

1/φ² = (6 - 2√5) / 4 = (3 - √5) / 2

φ² + 1/φ² = (3 + √5) / 2 + (3 - √5) / 2
         = (6) / 2
         = 3
```

### Trinity Identity

The identity `φ² + 1/φ² = 3` connects the golden ratio with ternary computing:

- **3**: Number of trit values {-1, 0, +1}
- **φ**: Golden ratio (1.618...)
- **Balance**: Order (φ) and chaos (1/φ) sum to unity (3)

This mathematical elegance underlies the system's harmony between precision and creativity.

## Further Reading

- **VSA Module**: Core vector operations
- **SDK Module**: High-level hypervector API
- **Research Papers**: See `/docs/research/` for applications

---

**Module**: `src/science.zig` (617 lines)

**Dependencies**:
- `trinity.zig`: Core types and constants
- `vsa.zig`: Vector operations
- `sdk.zig`: High-level API

**License**: MIT
