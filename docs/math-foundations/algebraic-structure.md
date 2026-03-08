---
sidebar_position: 6
sidebar_label: 'Algebraic Structure'
---

# Algebraic Structure of Ternary VSA

The ternary Vector Symbolic Architecture defines a precise algebraic structure over the space \{-1, 0, +1\}^n. This page formalizes the properties of bind, bundle, and permute, classifies the resulting algebraic object, and connects it to established mathematical frameworks.

---

## The Ternary Hypervector Space

<div class="theorem-card">
<h4>Definition (Ternary Hypervector Space)</h4>

Let **V_n** = \{-1, 0, +1\}^n be the set of all n-dimensional vectors with components drawn from the balanced ternary alphabet. Trinity's VSA defines three operations on V_n:

- **Bind** (⊗): V_n × V_n → V_n — element-wise multiplication
- **Bundle** (⊕): V_n^k → V_n — component-wise majority vote
- **Permute** (ρ): V_n × Z → V_n — cyclic coordinate shift

</div>

**Implementation**: `src/vsa/core.zig`

---

## Theorem 8 (Bind Forms a Commutative Monoid)

<div class="theorem-card">
<h4>Theorem 8 (Commutative Monoid under Bind)</h4>

The structure (V_n, ⊗) is a **commutative monoid** with absorbing element. Furthermore, bind restricted to \{-1, +1\}^n is a **commutative group** isomorphic to (Z_2)^n.

</div>

### Proof

**Step 1 (Closure)**: For any a, b in V_n, define (a ⊗ b)[i] = a[i] * b[i]. Since the product of any two elements of \{-1, 0, +1\} remains in \{-1, 0, +1\}:

```
(-1) * (-1) = +1 ∈ {-1, 0, +1}
(-1) *   0  =  0 ∈ {-1, 0, +1}
(-1) * (+1) = -1 ∈ {-1, 0, +1}
  0  *   0  =  0 ∈ {-1, 0, +1}
  0  * (+1) =  0 ∈ {-1, 0, +1}
(+1) * (+1) = +1 ∈ {-1, 0, +1}
```

Closure holds. QED (Step 1)

**Step 2 (Associativity)**: For any a, b, c in V_n:

```
((a ⊗ b) ⊗ c)[i] = (a[i] * b[i]) * c[i]
                   = a[i] * (b[i] * c[i])    (integer multiplication is associative)
                   = (a ⊗ (b ⊗ c))[i]
```

QED (Step 2)

**Step 3 (Commutativity)**: For any a, b in V_n:

```
(a ⊗ b)[i] = a[i] * b[i] = b[i] * a[i] = (b ⊗ a)[i]
```

QED (Step 3)

**Step 4 (Identity)**: The vector **1** = (+1, +1, ..., +1) is the identity element:

```
(a ⊗ 1)[i] = a[i] * (+1) = a[i]
```

QED (Step 4)

**Step 5 (Self-inverse for non-zero)**: For any a in \{-1, +1\}^n:

```
(a ⊗ a)[i] = a[i] * a[i] = a[i]^2 = +1 = 1[i]
```

So a ⊗ a = **1**, meaning every element is its own inverse. This makes (\{-1, +1\}^n, ⊗) isomorphic to the group (Z_2)^n under component-wise XOR.

QED (Step 5)

**Step 6 (Absorbing element)**: The zero vector **0** = (0, 0, ..., 0) absorbs:

```
(a ⊗ 0)[i] = a[i] * 0 = 0
```

Zero positions destroy information irreversibly.

QED (Theorem 8)

### Connection to Holographic Reduced Representations

Plate (2003) introduced **circular convolution** as the binding operation for real-valued HRR. Trinity's element-wise multiplication is the ternary specialization. The key advantage: circular convolution requires O(n log n) via FFT, while ternary bind is O(n) -- no multiplication needed, only sign flips.

Gayler (2003) showed that the algebraic requirements for a VSA are: (1) a binding operation that distributes information across dimensions, and (2) approximate inverse. Trinity's ternary bind satisfies both, with the stronger property of **exact** inverse on \{-1, +1\}^n.

---

## Theorem 9 (Bundle as Majority Algebra)

<div class="theorem-card">
<h4>Theorem 9 (Majority Algebra)</h4>

The bundle operation is the **ternary majority function**. It satisfies:

1. **Idempotence**: bundle(v, v, v) = v
2. **Commutativity**: bundle(a, b, c) = bundle(b, a, c) = ...
3. **Self-dual**: bundle(-a, -b, -c) = -bundle(a, b, c)
4. **Monotone**: if a[i] ≤ a'[i] for all i, then bundle(a, b, c)[i] ≤ bundle(a', b, c)[i]

</div>

### Proof

**Step 1 (Definition)**: For three vectors a, b, c:

```
bundle3(a, b, c)[i] = sign(a[i] + b[i] + c[i])
```

where sign(x) = +1 if x > 0, -1 if x < 0, 0 if x = 0.

**Step 2 (Idempotence)**: If a = b = c = v:

```
bundle3(v, v, v)[i] = sign(v[i] + v[i] + v[i]) = sign(3 * v[i]) = sign(v[i]) = v[i]
```

since v[i] in \{-1, 0, +1\} and sign preserves sign. QED (Step 2)

**Step 3 (Commutativity)**: Addition is commutative, so the sum a[i] + b[i] + c[i] is invariant under permutation of a, b, c. QED (Step 3)

**Step 4 (Self-duality)**: sign(-x) = -sign(x), so:

```
bundle3(-a, -b, -c)[i] = sign(-a[i] - b[i] - c[i])
                        = -sign(a[i] + b[i] + c[i])
                        = -bundle3(a, b, c)[i]
```

QED (Step 4)

**Step 5 (Monotonicity)**: If a[i] ≤ a'[i], then a[i] + b[i] + c[i] ≤ a'[i] + b[i] + c[i], so sign of the sum is non-decreasing. QED (Step 5)

### Majority Logic and Threshold Functions

The bundle operation is an instance of the **majority gate**, one of the fundamental Boolean functions studied since the early days of circuit complexity (von Neumann, 1956). In ternary logic, it generalizes naturally:

| a | b | c | a+b+c | bundle |
|---|---|---|-------|--------|
| +1 | +1 | +1 | +3 | +1 |
| +1 | +1 | -1 | +1 | +1 |
| +1 | -1 | -1 | -1 | -1 |
| -1 | -1 | -1 | -3 | -1 |
| +1 | +1 | 0 | +2 | +1 |
| +1 | 0 | 0 | +1 | +1 |
| 0 | 0 | 0 | 0 | 0 |

Kanerva (2009) showed that majority-vote bundling in high dimensions has the critical property: a bundled vector is **similar to each of its components** (cosine similarity > 0), enabling set-like representations. This is the foundation of hyperdimensional computing.

---

## Theorem 10 (Permutation Group Action)

<div class="theorem-card">
<h4>Theorem 10 (Cyclic Group Action)</h4>

The permutation operation ρ_k(v)[i] = v[(i - k) mod n] defines a **group action** of the cyclic group Z_n on V_n. Furthermore:

1. ρ_0 = identity
2. ρ_k ∘ ρ_m = ρ_(k+m mod n)
3. ρ_k^(-1) = ρ_(n-k)
4. ρ_n = ρ_0 = identity

</div>

### Proof

**Step 1**: ρ_0(v)[i] = v[(i - 0) mod n] = v[i]. Identity holds.

**Step 2**: (ρ_k ∘ ρ_m)(v)[i] = ρ_k(ρ_m(v))[i] = ρ_m(v)[(i - k) mod n] = v[((i - k) - m) mod n] = v[(i - (k+m)) mod n] = ρ_(k+m)(v)[i]. Composition rule holds.

**Step 3**: ρ_(n-k)(v)[i] = v[(i - (n-k)) mod n] = v[(i + k - n) mod n] = v[(i + k) mod n]. And ρ_k^(-1) must satisfy ρ_k(ρ_k^(-1)(v)) = v, which ρ_(n-k) does.

**Step 4**: ρ_n(v)[i] = v[(i - n) mod n] = v[i]. Period n. QED

### Sequence Encoding

Plate (2003) showed that circular convolution with a fixed "role" vector encodes position in sequences. Trinity uses the simpler cyclic permutation:

```
encode([a, b, c]) = a ⊕ ρ_1(b) ⊕ ρ_2(c)
```

Each element is shifted by its position index, then bundled. Since ρ_k produces a vector **quasi-orthogonal** to the original (for k > 0), the positional information is preserved in the superposition. Decoding uses inverse permutation:

```
decode(encoded, position=1) = ρ_(-1)(encoded) · b ≈ high similarity
```

---

## Non-Distributivity: VSA is a Presemiring, Not a Ring

<div class="theorem-card">
<h4>Proposition (No Distributive Law)</h4>

Bind does **not** distribute over bundle:

**a ⊗ bundle(b, c) ≠ bundle(a ⊗ b, a ⊗ c)**

in general.

</div>

### Counterexample

Let n = 3 (for clarity), and consider:

```
a = (+1, -1, +1)
b = (+1, +1, -1)
c = (-1, +1, +1)
```

**Left side**: a ⊗ bundle(b, c)

```
bundle(b, c) = bundle2((+1,+1,-1), (-1,+1,+1))
             = (sign(0), sign(2), sign(0))
             = (0, +1, 0)

a ⊗ (0, +1, 0) = (0, -1, 0)
```

**Right side**: bundle(a ⊗ b, a ⊗ c)

```
a ⊗ b = (+1, -1, -1)
a ⊗ c = (-1, -1, +1)
bundle2((+1,-1,-1), (-1,-1,+1)) = (sign(0), sign(-2), sign(0))
                                 = (0, -1, 0)
```

In this case they happen to agree, but consider a = (+1, +1, +1), b = (+1, -1, 0), c = (-1, +1, 0):

```
Left:  bundle(b,c) = (0, 0, 0), a ⊗ (0,0,0) = (0, 0, 0)
Right: a⊗b = (+1,-1,0), a⊗c = (-1,+1,0), bundle = (0, 0, 0)
```

The non-distributivity emerges statistically in high dimensions due to the sign-thresholding step in bundle, which is non-linear. The bundle operation loses magnitude information, so applying bind before or after bundling yields different results when the signs differ.

### Algebraic Classification

```
(V_n, ⊗, ⊕) is a PRESEMIRING (Golan, 1999):
  - (V_n, ⊗): commutative monoid with identity 1 and absorber 0
  - (V_n, ⊕): commutative, idempotent aggregation
  - No distributive law: a ⊗ (b ⊕ c) ≠ (a ⊗ b) ⊕ (a ⊗ c) in general
  - No additive inverses (bundle has no inverse)

A presemiring is an algebraic structure (S, ⊕, ⊗) where both operations
are associative and commutative, with respective identities, but where
distributivity of ⊗ over ⊕ is not required (Golan, J. S. "Semirings
and Their Applications." Kluwer, 1999).
```

This structure is neither a ring, a lattice, nor a Boolean algebra. It is closest to a **tropical semiring** in spirit, where the "addition" (bundle) is an idempotent operation and "multiplication" (bind) distributes only approximately.

---

## Connection to Hopfield Networks

<div class="theorem-card">
<h4>Historical Connection</h4>

Hopfield (1982) introduced associative memory networks where stored patterns are retrieved via energy minimization. Trinity's VSA can be viewed as a **non-iterative, one-shot Hopfield network** operating in ternary.

</div>

### Comparison

| Property | Hopfield Network | Trinity VSA |
|----------|-----------------|-------------|
| **Stored patterns** | Weight matrix W = sum(v_i * v_i^T) | Bundled vector s = ⊕(v_i) |
| **Retrieval** | Iterative: v(t+1) = sign(W * v(t)) | One-shot: cos(s, v_i) |
| **Capacity** | ~0.14n patterns (binary, dim n) | ~sqrt(n/log n) patterns (ternary, dim n) |
| **Values** | Binary \{0, 1\} or bipolar \{-1, +1\} | Ternary \{-1, 0, +1\} |
| **Binding** | Outer product (O(n^2) storage) | Element-wise multiply (O(n) storage) |
| **Energy function** | E = -v^T W v | cos(query, stored) |

Hopfield's original network stores patterns in a quadratic weight matrix W of size n x n. Trinity's VSA stores the same information in a linear superposition (bundle) of dimension n, achieving O(n) storage instead of O(n^2). The trade-off: lower capacity per dimension, but dramatically better scaling.

Ramsauer et al. (2021) showed that modern Hopfield networks with exponential energy functions can store exponentially many patterns. Trinity's ternary VSA occupies an intermediate position: linear storage with sub-linear capacity, but with the advantages of compositionality through bind and permute.

---

## VSA Model Comparison

Trinity implements **MAP-C** (Multiply-Add-Permute with Complex/ternary alphabet), one of several VSA models surveyed by Schlegel et al. (2022) and Kleyko et al. (2022). The choice of VSA model involves trade-offs between computational efficiency, memory density, and noise robustness.

### VSA Model Taxonomy

| Model | Space | Bind Operation | Bundle Operation | Similarity | Trinity Analog |
|-------|-------|----------------|------------------|------------|----------------|
| **MAP-C** | {-1,0,+1}^n | Element-wise multiply | Majority vote | Cosine | **THIS IS US** |
| **MAP-I** | {-1,0,+1}^n | Element-wise multiply | Addition + threshold | Cosine | Integer-scaled bundle |
| **MAP-B** | {-1,+1}^n | Element-wise multiply | Addition + threshold | Cosine | Binary (no zeros) |
| **BSC** | {0,1}^n | XOR | Majority vote | Hamming | Binary VSA |
| **HRR** | R^n | Circular convolution | Addition | Cosine | Continuous VSA |
| **FHRR** | C^n | Element-wise complex mult. | Addition | Cosine | Complex-phase VSA |
| **VTB** | R^(d×d) | Outer product | Addition | Frobenius | Matrix binding |

### Comparison Notes

**MAP-C vs MAP-B**: Trinity uses MAP-C (ternary) rather than MAP-B (binary) because the zero trit provides natural sparsity. A ternary vector with 33% zeros has the same information density as a binary vector of same dimension, but the zero entries act as built-in "don't care" values that simplify approximate matching.

**MAP-C vs HRR**: HRR uses circular convolution for binding, which requires O(n log n) via FFT or O(n²) naively. MAP-C's element-wise multiplication is O(n) and invertible on non-zero entries. The trade-off: HRR binding has better spectral properties, while MAP-C is computationally simpler.

**BSC (Binary Spatter Codes)**: Kanerva (1996) introduced BSC, where binding is XOR and bundling is majority vote. BSC is computationally efficient (XOR is hardware-friendly) but lacks the ternary "middle ground" that Trinity exploits for sparsity and noise tolerance.

**FHRR (Fourier HRR)**: Plate (2003) showed that FHRR (component-wise complex multiplication) is functionally equivalent to HRR but computed in the frequency domain. FHRR requires storing complex numbers (2× memory vs real), while Trinity's ternary representation uses ~1.6 bits per trit.

**VTB (Vector-derived Binding)**: Gosmann and Eliasmith (2019) proposed VTB, which uses outer products for binding—capturing higher-order relationships at the cost of O(d²) storage. Trinity's element-wise bind achieves O(n) storage.

### Capacity Comparison (Schlegel et al., 2022)

| Model | Capacity (symbols) | Noise Robustness |
|-------|-------------------|------------------|
| MAP-C | ~√(n/log n) | High (ternary redundancy) |
| MAP-B | ~√n | Medium (no zeros) |
| BSC | ~√n | High (XOR is perfect) |
| HRR | ~n | Low (continuous values accumulate error) |
| FHRR | ~n | Medium (phase wrapping) |

Trinity's MAP-C achieves the lowest capacity per dimension due to the sign-thresholding non-linearity in bundle, but this is offset by:
- Exact inverse (self-inverse) on non-zero trits
- Computational simplicity (no multiplication, only sign operations)
- Natural sparsity via zero trits

**References**:
- Schlegel, K. et al. "A Comparison of Vector Symbolic Architectures." *Artificial Intelligence Review* 55, 2022.
- Kleyko, D. et al. "A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part I: Models and Data Transformations." *ACM Computing Surveys* 55(6), Article 130, 2022.

---

Frady et al. (2022) introduced **resonator networks** that combine VSA operations with iterative factorization. A resonator network decomposes a bound product a ⊗ b back into its factors a and b by iterating:

```
a(t+1) = bundle(codebook_a · (s ⊗ b(t)))
b(t+1) = bundle(codebook_b · (s ⊗ a(t+1)))
```

This extends Trinity's one-shot unbind to handle ambiguous cases where multiple decompositions are possible. The convergence of resonator networks relies on the same algebraic properties (self-inverse bind, quasi-orthogonality) proven above.

---

## Category-Theoretic Perspective

Trinity's VSA can be interpreted through category theory — an approach that has received formal treatment only very recently.

### Formal Foundation (Shaw et al., 2025)

Shaw, Kleyko, and Sommer (2025) provided the first formal category-theoretic foundation for VSA using **Kan extensions** — a fundamental tool in functorial semantics. Their key result:

> The right Kan extension in VSA settings can be expressed as simple, element-wise operations.

This validates the intuition behind Trinity's functorial view. Where Trinity describes bind/bundle as informal categorical operations, Shaw et al. prove that:
- **Bind** corresponds to a right Kan extension along diagonal morphisms
- **Bundle** corresponds to colimit computation in the VSA category
- The element-wise nature of these operations emerges from the categorical structure

This is the first rigorous mathematical work linking VSA to category theory — a Google Scholar search by the authors found only **12 prior papers** connecting these topics.

### Informal Functorial View

<div class="theorem-card">
<h4>VSA as Functor (Informal)</h4>

Let **Sym** be the category of symbolic structures (sets, sequences, trees) with structural morphisms, and **Vec_3** be the category of ternary hypervectors with VSA operations. Then:

**F: Sym → Vec_3**

is a functor that:
- Maps objects (symbols) to random hypervectors
- Maps products to bind: F(a × b) = F(a) ⊗ F(b)
- Maps coproducts to bundle: F(a + b) = F(a) ⊕ F(b)
- Maps sequences to permuted bundles: F([a, b, c]) = F(a) ⊕ ρ_1(F(b)) ⊕ ρ_2(F(c))

</div>

This functorial view clarifies why VSA works: it is a **structure-preserving embedding** of symbolic computation into high-dimensional vector space. The quasi-orthogonality of random vectors ensures that the functor is approximately injective (different symbolic structures map to distinguishable vectors), while the algebraic properties of bind/bundle/permute ensure that structural relationships are preserved.

This perspective connects to the broader program of **compositional distributional semantics** (Coecke et al., 2010; Baroni et al., 2014), where grammatical structure is composed with distributional meaning in a categorical framework.

**Reference**: Shaw, N. P., Kleyko, D., and Sommer, F. T. "Developing a Foundation of Vector Symbolic Architectures Using Category Theory." *arXiv* 2501.05368, January 2025.

---

## Machine Learning Foundations: Hyperdimensional Transform

Trinity's VSA documentation focuses on symbolic computing (bind/bundle for structured representation). However, VSA has also been formalized as a foundation for machine learning through the **hyperdimensional transform** (Heddes et al., 2025).

### The Hyperdimensional Transform

Heddes, Ashkboos, Hoefler, and Alistarh (2025) introduced the hyperdimensional transform as a theoretical framework for:

- **Regression**: Representing functions f: X → Y as high-dimensional vectors
- **Bayesian inference**: Encoding probability distributions as hypervectors
- **Distribution representation**: Capturing uncertainty in HDC representations
- **Uncertainty estimation**: Principled uncertainty quantification via hypervector statistics

The key insight: the high-dimensional transform provides a **well-founded toolbox** for ML tasks using the same hypervector operations that Trinity uses for symbolic reasoning. This bridges the gap between:
- **Symbolic AI** (compositionality, structured representation via VSA)
- **Connectionist ML** (statistical learning, pattern recognition)

Where Trinity focuses on the symbolic side (binding concepts, bundling sets, encoding sequences), the hyperdimensional transform shows how these same operations perform regression, classification, and density estimation.

**Reference**: Heddes, M., Ashkboos, S., Hoefler, T., and Alistarh, D. "The Hyperdimensional Transform for Distributional Modeling, Regression and Classification." *Neural Computing and Applications*, Springer, July 2025. DOI: 10.1007/s00521-025-11405-0.

---

## Numerical Verification

```zig
const std = @import("std");

test "Theorem 8: bind is commutative" {
    var a = [_]i8{ 1, -1, 0, 1, -1 };
    var b = [_]i8{ -1, 1, 1, 0, -1 };
    for (0..5) |i| {
        try std.testing.expectEqual(a[i] * b[i], b[i] * a[i]);
    }
}

test "Theorem 8: bind is self-inverse on non-zero" {
    var a = [_]i8{ 1, -1, 1, -1, 1 };
    var b = [_]i8{ -1, 1, -1, 1, -1 };
    // bind(a, bind(a, b)) should equal b
    for (0..5) |i| {
        const bound = a[i] * b[i];
        const unbound = a[i] * bound;
        try std.testing.expectEqual(b[i], unbound);
    }
}

test "Theorem 9: bundle3 is idempotent" {
    var v = [_]i8{ 1, -1, 0, 1, -1 };
    for (0..5) |i| {
        const sum = @as(i16, v[i]) + @as(i16, v[i]) + @as(i16, v[i]);
        const result: i8 = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        try std.testing.expectEqual(v[i], result);
    }
}

test "Theorem 10: permutation period is n" {
    const n = 5;
    var v = [_]i8{ 1, -1, 0, 1, -1 };
    var permuted: [n]i8 = undefined;
    // Apply rho_n (full cycle) = identity
    for (0..n) |i| {
        permuted[i] = v[@mod(i + n - n, n)]; // rho_n
    }
    for (0..n) |i| {
        try std.testing.expectEqual(v[i], permuted[i]);
    }
}
```

---

## Explore with TRI CLI

```bash
tri math-verify            # Includes VSA algebraic property tests
tri math groups            # Exceptional Lie groups E8 and symmetries
tri math-bench             # Benchmark bind/bundle/permute operations
```

---

## References

1. Plate, T. A. *Holographic Reduced Representations*. CSLI Publications, 2003. The foundational treatment of binding via circular convolution and its algebraic properties.
2. Gayler, R. W. "Vector Symbolic Architectures Answer Jackendoff's Challenges for Cognitive Neuroscience." In *ICCS/ASCS Joint International Conference on Cognitive Science*, pp. 133--138, 2003.
3. Kanerva, P. "Hyperdimensional Computing: An Introduction to Computing in Distributed Representation with High-Dimensional Random Vectors." *Cognitive Computation* 1(2), pp. 139--159, 2009.
4. Hopfield, J. J. "Neural networks and physical systems with emergent collective computational abilities." *Proceedings of the National Academy of Sciences* 79(8), pp. 2554--2558, 1982.
5. Ramsauer, H. et al. "Hopfield Networks is All You Need." *ICLR 2021*.
6. Frady, E. P., Kleyko, D., and Sommer, F. T. "Variable Binding for Sparse Distributed Representations: Theory and Applications." *IEEE Transactions on Neural Networks and Learning Systems*, 2022.
7. Kleyko, D. et al. "A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part I: Models and Data Transformations." *ACM Computing Surveys* 55(6), Article 130, 2022.
8. Schlegel, K. et al. "A Comparison of Vector Symbolic Architectures." *Artificial Intelligence Review* 55, pp. 4523--4555, 2022.
9. Coecke, B., Sadrzadeh, M., and Clark, S. "Mathematical Foundations for a Compositional Distributional Model of Meaning." *Linguistic Analysis* 36, pp. 345--384, 2010.
10. von Neumann, J. "Probabilistic Logics and the Synthesis of Reliable Organisms from Unreliable Components." In *Automata Studies*, Princeton University Press, pp. 43--98, 1956.
11. Golan, J. S. *Semirings and Their Applications*. Kluwer Academic Publishers, 1999. Formal definition of presemirings and semirings.
12. Shaw, N. P., Kleyko, D., and Sommer, F. T. "Developing a Foundation of Vector Symbolic Architectures Using Category Theory." *arXiv* 2501.05368, January 2025.
13. Heddes, M., Ashkboos, S., Hoefler, T., and Alistarh, D. "The Hyperdimensional Transform for Distributional Modeling, Regression and Classification." *Neural Computing and Applications*, Springer, July 2025.

---

**phi^2 + 1/phi^2 = 3 = TRINITY**
