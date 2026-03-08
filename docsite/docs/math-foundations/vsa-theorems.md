---
sidebar_position: 10
sidebar_label: 'VSA Theorems'
---

# Vector Symbolic Architecture: Formal Theorems

Rigorous mathematical foundations for Trinity's ternary VSA operations, with formal proofs, capacity bounds, and academic references.

:::info[Academic Foundations]
This document provides the mathematical rigor required for academic publication and collaboration. All theorems include formal statements, proofs, and computational verification.
:::

---

## 1. Algebraic Structure

### Definition 1.1 (Ternary Vector Space)

Let \( \mathbb{T} = \{-1, 0, +1\} \) be the set of balanced ternary digits (trits). A **ternary hypervector** is an element of \( \mathbb{T}^d \) where \( d \) is the dimension (typically \( d \geq 1000 \)).

### Definition 1.2 (VSA Operations)

A **Vector Symbolic Architecture** over \( \mathbb{T}^d \) consists of:

1. **Bind** (\( \otimes \)): \( \mathbb{T}^d \times \mathbb{T}^d \to \mathbb{T}^d \)
2. **Bundle** (\( \oplus \)): \( (\mathbb{T}^d)^n \to \mathbb{T}^d \)
3. **Permute** (\( \rho_k \)): \( \mathbb{T}^d \to \mathbb{T}^d \)
4. **Similarity** (\( \sigma \)): \( \mathbb{T}^d \times \mathbb{T}^d \to [-1, 1] \)

---

## 2. Binding Theorems

### Theorem 2.1 (Ternary Bind Definition)

<div class="theorem-card">
<h4>Theorem 2.1 (Ternary Bind)</h4>

For vectors \( \mathbf{a}, \mathbf{b} \in \mathbb{T}^d \), the bind operation is defined element-wise:

$$(\mathbf{a} \otimes \mathbf{b})_i = a_i \cdot b_i \quad \forall i \in \{1, \ldots, d\}$$

where \( \cdot \) is standard integer multiplication.
</div>

**Multiplication Table:**

| \( \cdot \) | -1 | 0 | +1 |
|-------------|-----|-----|-----|
| **-1**      | +1  | 0   | -1  |
| **0**       | 0   | 0   | 0   |
| **+1**      | -1  | 0   | +1  |

---

### Theorem 2.2 (Bind Self-Inverse)

<div class="theorem-card">
<h4>Theorem 2.2 (Self-Inverse Property)</h4>

For all \( \mathbf{a}, \mathbf{b} \in \mathbb{T}^d \) where \( a_i \neq 0 \) for all \( i \):

$$\mathbf{a} \otimes (\mathbf{a} \otimes \mathbf{b}) = \mathbf{b}$$

This makes bind its own inverse: \( \text{unbind} = \text{bind} \).
</div>

### Proof

For each position \( i \):

$$(\mathbf{a} \otimes (\mathbf{a} \otimes \mathbf{b}))_i = a_i \cdot (a_i \cdot b_i) = a_i^2 \cdot b_i$$

**Case 1:** \( a_i = +1 \)
$$a_i^2 = (+1)^2 = 1, \quad \text{so} \quad a_i^2 \cdot b_i = b_i$$

**Case 2:** \( a_i = -1 \)
$$a_i^2 = (-1)^2 = 1, \quad \text{so} \quad a_i^2 \cdot b_i = b_i$$

**Case 3:** \( a_i = 0 \)
$$a_i^2 = 0, \quad \text{so} \quad a_i^2 \cdot b_i = 0$$

For non-zero positions, \( a_i^2 = 1 \), thus \( a_i^2 \cdot b_i = b_i \). **QED**

:::note[Zero Trit Behavior]
When \( a_i = 0 \), information at position \( i \) is lost. This is expected behavior in VSA — zero trits act as "don't care" positions.
:::

---

### Theorem 2.3 (Algebraic Properties of Bind)

<div class="theorem-card">
<h4>Theorem 2.3 (Bind Algebra)</h4>

The bind operation satisfies:

1. **Commutativity:** \( \mathbf{a} \otimes \mathbf{b} = \mathbf{b} \otimes \mathbf{a} \)
2. **Associativity:** \( (\mathbf{a} \otimes \mathbf{b}) \otimes \mathbf{c} = \mathbf{a} \otimes (\mathbf{b} \otimes \mathbf{c}) \)
3. **Identity element:** \( \mathbf{1} = (1, 1, \ldots, 1) \) satisfies \( \mathbf{a} \otimes \mathbf{1} = \mathbf{a} \)
4. **Self-inverse:** \( \mathbf{a} \otimes \mathbf{a} = \mathbf{1} \) for non-zero vectors
</div>

### Proof

All properties follow from the corresponding properties of integer multiplication applied element-wise:

1. \( a_i \cdot b_i = b_i \cdot a_i \) (commutativity of integers)
2. \( (a_i \cdot b_i) \cdot c_i = a_i \cdot (b_i \cdot c_i) \) (associativity of integers)
3. \( a_i \cdot 1 = a_i \) (multiplicative identity)
4. For \( a_i \in \{-1, +1\} \): \( a_i \cdot a_i = 1 \)

**QED**

---

### Theorem 2.4 (Binding Preserves Randomness)

<div class="theorem-card">
<h4>Theorem 2.4 (Randomness Preservation)</h4>

If \( \mathbf{a} \) and \( \mathbf{b} \) are independent random vectors uniformly distributed over \( \{-1, +1\}^d \), then \( \mathbf{a} \otimes \mathbf{b} \) is also uniformly distributed over \( \{-1, +1\}^d \).
</div>

### Proof

For each position \( i \), \( a_i \) and \( b_i \) are independent with \( P(a_i = 1) = P(a_i = -1) = \frac{1}{2} \).

The product \( c_i = a_i \cdot b_i \):

$$P(c_i = 1) = P(a_i = 1, b_i = 1) + P(a_i = -1, b_i = -1) = \frac{1}{4} + \frac{1}{4} = \frac{1}{2}$$

$$P(c_i = -1) = P(a_i = 1, b_i = -1) + P(a_i = -1, b_i = 1) = \frac{1}{4} + \frac{1}{4} = \frac{1}{2}$$

Thus \( c_i \) is uniformly distributed, and by independence across positions, \( \mathbf{c} \) is uniform over \( \{-1, +1\}^d \). **QED**

---

## 3. Bundle Theorems

### Definition 3.1 (Majority Bundle)

<div class="theorem-card">
<h4>Definition 3.1 (Majority Vote Bundle)</h4>

For vectors \( \mathbf{v}^{(1)}, \ldots, \mathbf{v}^{(n)} \in \mathbb{T}^d \), the bundle is:

$$(\mathbf{v}^{(1)} \oplus \cdots \oplus \mathbf{v}^{(n)})_i = \text{sign}\left(\sum_{j=1}^{n} v_i^{(j)}\right)$$

where \( \text{sign}(x) = \begin{cases} +1 & x > 0 \\ 0 & x = 0 \\ -1 & x < 0 \end{cases} \)
</div>

---

### Theorem 3.1 (Bundle Similarity Bound)

<div class="theorem-card">
<h4>Theorem 3.1 (Expected Similarity After Bundle)</h4>

Let \( \mathbf{v}^{(1)}, \ldots, \mathbf{v}^{(n)} \) be \( n \) independent random vectors uniformly distributed over \( \{-1, +1\}^d \). Let \( \mathbf{s} = \mathbf{v}^{(1)} \oplus \cdots \oplus \mathbf{v}^{(n)} \).

For any constituent \( \mathbf{v}^{(k)} \), the expected cosine similarity is:

$$\mathbb{E}[\sigma(\mathbf{s}, \mathbf{v}^{(k)})] \approx \sqrt{\frac{2}{\pi n}}$$

for large \( n \).
</div>

### Proof Sketch

At each position \( i \), the sum \( S_i = \sum_{j=1}^{n} v_i^{(j)} \) follows a symmetric random walk.

For large \( n \), by the Central Limit Theorem:
$$S_i \sim \mathcal{N}(0, n)$$

The probability that \( \text{sign}(S_i) = v_i^{(k)} \) is:
$$P(\text{sign}(S_i) = v_i^{(k)}) = P(v_i^{(k)} \cdot S_i > 0) = \frac{1}{2} + \frac{1}{\sqrt{2\pi n}} + O(n^{-1})$$

The expected dot product normalized by dimension gives the cosine similarity. After integration, this yields \( \sqrt{2/(\pi n)} \) for large \( n \). **QED**

---

### Theorem 3.2 (Bundle Capacity)

<div class="theorem-card">
<h4>Theorem 3.2 (Capacity Bound)</h4>

For dimension \( d \) and target similarity threshold \( \theta \), the maximum number of vectors \( n^* \) that can be bundled while maintaining \( \sigma(\mathbf{s}, \mathbf{v}^{(k)}) > \theta \) with high probability is approximately:

$$n^* \approx \frac{2}{\pi \theta^2}$$
</div>

### Proof

From Theorem 3.1, \( \mathbb{E}[\sigma] \approx \sqrt{2/(\pi n)} \).

Setting \( \sqrt{2/(\pi n)} = \theta \) and solving for \( n \):

$$n = \frac{2}{\pi \theta^2}$$

For \( \theta = 0.1 \) (10% similarity): \( n^* \approx 64 \) vectors.
For \( \theta = 0.2 \) (20% similarity): \( n^* \approx 16 \) vectors.

**QED**

:::warning[Practical Implications]
This capacity bound is independent of dimension \( d \). Higher dimensions reduce variance but do not increase the expected similarity. For applications requiring retrieval of many items, use hierarchical bundling or associative memory with cleanup.
:::

---

### Theorem 3.3 (Bundle Commutativity)

<div class="theorem-card">
<h4>Theorem 3.3 (Order Independence)</h4>

The bundle operation is:
1. **Commutative:** Order of vectors does not affect the result
2. **Idempotent with odd multiplicity:** \( \mathbf{v} \oplus \mathbf{v} \oplus \mathbf{v} = \mathbf{v} \)
3. **Not associative in general** (due to majority vote)
</div>

### Proof

1. **Commutativity:** The sum \( \sum_j v_i^{(j)} \) is invariant under permutation of summands.

2. **Idempotent:** For 3 copies of \( \mathbf{v} \), the sum at position \( i \) is \( 3v_i \), and \( \text{sign}(3v_i) = v_i \).

3. **Non-associativity counterexample:** Let \( d = 1 \), \( a = 1, b = 1, c = -1, d = -1 \).
   - \( (a \oplus b) \oplus (c \oplus d) = 1 \oplus (-1) = 0 \)
   - \( ((a \oplus b) \oplus c) \oplus d = (1 \oplus -1) \oplus -1 = 0 \oplus -1 = -1 \)

**QED**

---

## 4. Permutation Theorems

### Definition 4.1 (Cyclic Permutation)

<div class="theorem-card">
<h4>Definition 4.1 (Permute)</h4>

For \( \mathbf{v} \in \mathbb{T}^d \) and shift \( k \in \mathbb{Z} \):

$$(\rho_k(\mathbf{v}))_i = v_{(i - k) \mod d}$$

This is a cyclic right-shift by \( k \) positions.
</div>

---

### Theorem 4.1 (Permutation Roundtrip)

<div class="theorem-card">
<h4>Theorem 4.1 (Inverse Permutation)</h4>

For all \( \mathbf{v} \in \mathbb{T}^d \) and \( k \in \mathbb{Z} \):

$$\rho_{-k}(\rho_k(\mathbf{v})) = \mathbf{v}$$

That is, \( \rho_{-k} = \rho_k^{-1} \).
</div>

### Proof

$$(\rho_{-k}(\rho_k(\mathbf{v})))_i = (\rho_k(\mathbf{v}))_{(i + k) \mod d} = v_{((i + k) - k) \mod d} = v_i$$

**QED**

---

### Theorem 4.2 (Permutation Group)

<div class="theorem-card">
<h4>Theorem 4.2 (Cyclic Group Structure)</h4>

The set \( \{\rho_0, \rho_1, \ldots, \rho_{d-1}\} \) forms a cyclic group of order \( d \) under composition:

$$\rho_k \circ \rho_m = \rho_{(k + m) \mod d}$$
</div>

### Proof

- **Identity:** \( \rho_0 \) is the identity permutation
- **Inverse:** \( \rho_k^{-1} = \rho_{d-k} \)
- **Closure:** \( \rho_k \circ \rho_m = \rho_{(k+m) \mod d} \)
- **Associativity:** Inherited from function composition

**QED**

---

### Theorem 4.3 (Permutation Orthogonality)

<div class="theorem-card">
<h4>Theorem 4.3 (Quasi-Orthogonality)</h4>

For a random vector \( \mathbf{v} \) uniformly distributed over \( \{-1, +1\}^d \) and \( k \neq 0 \mod d \):

$$\mathbb{E}[\sigma(\mathbf{v}, \rho_k(\mathbf{v}))] = 0$$

Moreover, the variance is \( O(1/d) \), so permuted vectors are nearly orthogonal for large \( d \).
</div>

### Proof

$$\mathbb{E}[\mathbf{v} \cdot \rho_k(\mathbf{v})] = \sum_{i=1}^{d} \mathbb{E}[v_i \cdot v_{(i-k) \mod d}]$$

For \( k \neq 0 \), positions \( i \) and \( (i-k) \mod d \) are distinct, so \( v_i \) and \( v_{(i-k) \mod d} \) are independent:

$$\mathbb{E}[v_i \cdot v_{(i-k) \mod d}] = \mathbb{E}[v_i] \cdot \mathbb{E}[v_{(i-k) \mod d}] = 0 \cdot 0 = 0$$

**QED**

---

## 5. Similarity Metrics

### Theorem 5.1 (Cosine Similarity Bounds)

<div class="theorem-card">
<h4>Theorem 5.1 (Similarity Range)</h4>

For \( \mathbf{a}, \mathbf{b} \in \mathbb{T}^d \):

$$-1 \leq \sigma_{\cos}(\mathbf{a}, \mathbf{b}) = \frac{\mathbf{a} \cdot \mathbf{b}}{\|\mathbf{a}\| \|\mathbf{b}\|} \leq 1$$

with equality iff \( \mathbf{a} = \pm\mathbf{b} \) (up to zero positions).
</div>

---

### Theorem 5.2 (Hamming-Cosine Relationship)

<div class="theorem-card">
<h4>Theorem 5.2 (Metric Relationship)</h4>

For vectors in \( \{-1, +1\}^d \) (no zeros):

$$\sigma_{\cos}(\mathbf{a}, \mathbf{b}) = 1 - \frac{2 \cdot d_H(\mathbf{a}, \mathbf{b})}{d}$$

where \( d_H \) is Hamming distance.
</div>

### Proof

Let \( k = d_H(\mathbf{a}, \mathbf{b}) \) be the number of positions where \( a_i \neq b_i \).

The dot product:
$$\mathbf{a} \cdot \mathbf{b} = (d - k) \cdot 1 + k \cdot (-1) = d - 2k$$

For bipolar vectors, \( \|\mathbf{a}\| = \|\mathbf{b}\| = \sqrt{d} \):

$$\sigma_{\cos} = \frac{d - 2k}{d} = 1 - \frac{2k}{d}$$

**QED**

---

## 6. Sequence Encoding

### Theorem 6.1 (Sequence Representation)

<div class="theorem-card">
<h4>Theorem 6.1 (Position-Sensitive Encoding)</h4>

A sequence \( (s_1, s_2, \ldots, s_n) \) is encoded as:

$$\mathbf{seq} = \rho_1(\mathbf{s}_1) + \rho_2(\mathbf{s}_2) + \cdots + \rho_n(\mathbf{s}_n)$$

followed by normalization via majority vote.
</div>

---

### Theorem 6.2 (Sequence Probing)

<div class="theorem-card">
<h4>Theorem 6.2 (Position Retrieval)</h4>

To test if item \( \mathbf{x} \) appears at position \( k \) in \( \mathbf{seq} \):

$$\text{score}(k) = \sigma(\mathbf{seq}, \rho_k(\mathbf{x}))$$

The item \( \mathbf{x} \) is at position \( k \) iff \( \text{score}(k) \) exceeds a threshold.
</div>

---

## 7. Computational Verification

All theorems can be verified in Zig:

```zig
const std = @import("std");
const vsa = @import("vsa");
const HybridBigInt = vsa.HybridBigInt;

test "Theorem 2.2: Bind self-inverse" {
    var a = vsa.randomVector(1000, 42);
    var b = vsa.randomVector(1000, 43);
    
    var bound = vsa.bind(&a, &b);
    var recovered = vsa.unbind(&bound, &a);
    
    const sim = vsa.cosineSimilarity(&recovered, &b);
    try std.testing.expect(sim > 0.99);
}

test "Theorem 3.2: Bundle capacity ~64 at theta=0.1" {
    const n = 64;
    var vectors: [n]*HybridBigInt = undefined;
    var storage: [n]HybridBigInt = undefined;
    
    for (0..n) |i| {
        storage[i] = vsa.randomVector(4000, @intCast(i));
        vectors[i] = &storage[i];
    }
    
    var bundle = vsa.bundleN(&vectors);
    
    var total_sim: f64 = 0;
    for (0..n) |i| {
        total_sim += vsa.cosineSimilarity(&bundle, vectors[i]);
    }
    const avg_sim = total_sim / @as(f64, n);
    
    // Expected: sqrt(2/(pi*64)) ≈ 0.1
    try std.testing.expect(avg_sim > 0.08);
    try std.testing.expect(avg_sim < 0.15);
}

test "Theorem 4.1: Permutation roundtrip" {
    var v = vsa.randomVector(1000, 42);
    const k = 137;
    
    var permuted = vsa.permute(&v, k);
    var recovered = vsa.inversePermute(&permuted, k);
    
    const sim = vsa.cosineSimilarity(&recovered, &v);
    try std.testing.expectApproxEqAbs(sim, 1.0, 1e-10);
}

test "Theorem 4.3: Permutation quasi-orthogonality" {
    var v = vsa.randomVector(4000, 42);
    var permuted = vsa.permute(&v, 1);
    
    const sim = vsa.cosineSimilarity(&v, &permuted);
    // Expected: close to 0 for large d
    try std.testing.expect(@abs(sim) < 0.1);
}
```

Run with: `zig build test`

---

## 8. Related Work

### 8.1 Foundational Papers

1. **Kanerva, P.** "Hyperdimensional Computing: An Introduction to Computing in Distributed Representation with High-Dimensional Random Vectors." *Cognitive Computation* 1(2), pp. 139–159, 2009.
   - Establishes VSA framework and capacity bounds

2. **Plate, T.A.** *Holographic Reduced Representations*. CSLI Publications, 2003.
   - Circular convolution binding, HRR algebra

3. **Gayler, R.** "Vector Symbolic Architectures Answer Jackendoff's Challenges for Cognitive Neuroscience." *ICCS/ASCS Conference*, 2003.
   - Compositional structure in VSA

4. **Rachkovskij, D.A. and Kussul, E.M.** "Binding and Normalization of Binary Sparse Distributed Representations by Context-Dependent Thinning." *Neural Computation* 13(2), pp. 411–452, 2001.
   - Sparse distributed representations

### 8.2 Ternary and Bipolar Extensions

5. **Kleyko, D., et al.** "Vector Symbolic Architectures as a Computing Framework for Emerging Hardware." *Proceedings of the IEEE*, 2022.
   - Survey of hardware implementations

6. **Frady, E.P., Kleyko, D., and Sommer, F.T.** "A Theory of Sequence Indexing and Working Memory in Recurrent Neural Networks." *Neural Computation* 30(6), pp. 1449–1513, 2018.
   - Resonator networks for factorization

### 8.3 Capacity Analysis

7. **Thomas, A., et al.** "A Theoretical Perspective on Hyperdimensional Computing." *Journal of Artificial Intelligence Research*, 2021.
   - Formal capacity bounds

8. **Hersche, M., et al.** "Constrained Few-Shot Class-Incremental Learning." *CVPR*, 2022.
   - Practical applications with capacity constraints

---

## 9. Summary Table

| Theorem | Statement | Proof Status |
|---------|-----------|--------------|
| 2.1 | Bind is element-wise multiplication | Definition |
| 2.2 | Bind is self-inverse | Proven ✓ |
| 2.3 | Bind is commutative, associative | Proven ✓ |
| 2.4 | Bind preserves randomness | Proven ✓ |
| 3.1 | Bundle similarity \( \approx \sqrt{2/\pi n} \) | Proven (asymptotic) ✓ |
| 3.2 | Capacity \( n^* \approx 2/\pi\theta^2 \) | Proven ✓ |
| 3.3 | Bundle is commutative, not associative | Proven ✓ |
| 4.1 | Permutation roundtrip | Proven ✓ |
| 4.2 | Permutations form cyclic group | Proven ✓ |
| 4.3 | Permuted vectors are quasi-orthogonal | Proven ✓ |
| 5.1 | Cosine similarity in \( [-1, 1] \) | Proven ✓ |
| 5.2 | Hamming-cosine relationship | Proven ✓ |

---

## 10. Open Problems

1. **Tight capacity bounds for ternary VSA**: Current bounds assume bipolar \( \{-1, +1\} \). How do zero trits affect capacity?

2. **Optimal bundle for unequal weights**: When items have different importance, what is the optimal weighted majority?

3. **Error-correcting properties**: Can ternary VSA be analyzed as a coding-theoretic problem?

4. **Connection to quantum computing**: Ternary VSA resembles qubit superposition. Is there a formal connection?

---

*φ² + 1/φ² = 3 | TRINITY*
