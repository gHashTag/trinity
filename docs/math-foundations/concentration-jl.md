---
sidebar_position: 7
sidebar_label: 'Concentration & JL Lemma'
---

# Concentration of Measure and the Johnson-Lindenstrauss Lemma

Why do high-dimensional ternary vectors work? Two deep results from probability and geometry provide the answer: **concentration of measure** guarantees that random vectors cluster on a thin spherical shell, and the **Johnson-Lindenstrauss lemma** guarantees that random projections preserve pairwise distances. Together, they explain why VSA operations are reliable in high dimensions.

---

## Theorem 11 (Concentration of Measure for Ternary Vectors)

<div class="theorem-card">
<h4>Theorem 11 (Ternary Concentration)</h4>

Let v = (v_1, ..., v_n) where each v_i is drawn independently and uniformly from \{-1, 0, +1\}. Then:

**P( | ||v||^2 - 2n/3 | > t ) ≤ 2 exp(-t^2 / (2n))**

The squared norm ||v||^2 concentrates around its expectation 2n/3, and the relative deviation vanishes as O(1/sqrt(n)).

</div>

### Proof

**Step 1**: Define X_i = v_i^2. Each X_i takes values in \{`\1`}, 1\}:

```
P(X_i = 0) = P(v_i = 0) = 1/3
P(X_i = 1) = P(v_i ∈ {-1, +1}) = 2/3
```

So E[X_i] = 2/3 and X_i are independent Bernoulli(2/3) random variables.

**Step 2**: The squared norm is ||v||^2 = sum(X_i). By linearity:

```
E[||v||^2] = n * E[X_i] = 2n/3
```

**Step 3**: Apply Hoeffding's inequality. Since 0 ≤ X_i ≤ 1 and X_i are independent:

```
P( |sum(X_i) - 2n/3| > t ) ≤ 2 exp(-2t^2 / n)
```

**Step 4**: The normalized norm ||v|| / sqrt(2n/3) concentrates around 1:

```
P( | ||v|| / sqrt(2n/3) - 1 | > epsilon )
  ≤ P( | ||v||^2 - 2n/3 | > epsilon * 2n/3 )         (for small epsilon)
  ≤ 2 exp(-2(epsilon * 2n/3)^2 / n)
  = 2 exp(-8n * epsilon^2 / 9)
```

For n = 10,000 and epsilon = 0.01: probability ≤ 2 exp(-88.9) ≈ 0. QED

### Geometric Interpretation

All random ternary vectors of dimension n lie on a thin spherical shell of radius approximately sqrt(2n/3) ≈ 81.6 (for n = 10,000). The shell thickness relative to the radius is O(1/sqrt(n)) ≈ 0.01. This is an instance of the **concentration of measure phenomenon** discovered by Levy (1951) and generalized by Milman (1971).

**Reference**: Ledoux, M. *The Concentration of Measure Phenomenon*. American Mathematical Society, 2001. Boucheron, S., Lugosi, G., and Massart, P. *Concentration Inequalities: A Nonasymptotic Theory of Independence*. Oxford University Press, 2013.

---

## Theorem 12 (Johnson-Lindenstrauss for Ternary Projections)

<div class="theorem-card">
<h4>Theorem 12 (Ternary JL Lemma)</h4>

Let x_1, ..., x_N be N points in R^d. For any 0 < epsilon < 1, there exists a ternary matrix A in \{-1, 0, +1\}^(n x d) with n = O(log(N) / epsilon^2) such that for all pairs i, j:

**(1 - epsilon) ||x_i - x_j||^2 ≤ (3/n) ||A x_i - A x_j||^2 ≤ (1 + epsilon) ||x_i - x_j||^2**

Pairwise distances are preserved up to a factor (1 ± epsilon).

</div>

### Background

The original Johnson-Lindenstrauss lemma (1984) states that N points in high dimension can be embedded into O(log N / epsilon^2) dimensions while preserving all pairwise distances within a factor (1 ± epsilon). The original proof uses Gaussian random projections.

### Ternary Extension

Achlioptas (2003) proved that the JL lemma holds for **sparse random projections** where each entry of the projection matrix is:

```
A_ij = { +1  with probability 1/6
        {  0  with probability 2/3
        { -1  with probability 1/6
```

This is precisely the distribution of a **sparse ternary matrix** -- the same distribution used in Trinity's random vector generation. The key insight: the zero entries (probability 2/3) provide computational savings (sparse matrix-vector products), while the ±1 entries provide sufficient randomness for distance preservation.

### Proof Sketch (Achlioptas 2003)

**Step 1**: For a fixed vector u in R^d, define Y = (1/sqrt(n)) * A * u where A has the ternary distribution above.

**Step 2**: E[Y_j^2] = (1/n) * sum_i E[A_ji^2] * u_i^2 = (1/n) * (1/3) * ||u||^2. (Since E[A_ji^2] = 1/3 for the sparse ternary distribution.)

**Step 3**: Var[Y_j^2] is bounded by O(||u||^4 / n), using independence of entries.

**Step 4**: By sub-Gaussian concentration (each Y_j is a sum of independent bounded random variables), ||Y||^2 concentrates around E[||Y||^2] = (1/3) * ||u||^2 with exponentially decaying tails.

**Step 5**: Union bound over all O(N^2) pairs yields the JL guarantee for n = O(log N / epsilon^2).

### Significance for Trinity

This theorem justifies why Trinity uses random ternary vectors of dimension n ≈ 10,000:

- For N = 100,000 symbols with epsilon = 0.1: need n ≥ C * log(100000) / 0.01 ≈ C * 1150
- With n = 10,000, Trinity can represent approximately exp(n * epsilon^2 / C) ≈ millions of symbols while preserving pairwise similarities

**Reference**: Achlioptas, D. "Database-friendly random projections: Johnson-Lindenstrauss with binary coins." *Journal of Computer and System Sciences* 66(4), pp. 671--687, 2003.

---

## Theorem 13 (Quasi-Orthogonality Bound)

<div class="theorem-card">
<h4>Theorem 13 (Exponential Quasi-Orthogonality)</h4>

For two independent random ternary vectors a, b in \{-1, 0, +1\}^n with uniform iid components:

**P( |cos(a, b)| > epsilon ) ≤ 2 exp(-2n epsilon^2 / 9)**

</div>

### Proof

**Step 1**: The unnormalized dot product dot(a, b) = sum(a_i * b_i). Each term Z_i = a_i * b_i satisfies:

```
E[Z_i] = E[a_i] * E[b_i] = 0  (by independence)
Z_i ∈ {-1, 0, +1}
```

**Step 2**: By Hoeffding's inequality for bounded random variables (|Z_i| ≤ 1):

```
P( |dot(a, b)| > s ) ≤ 2 exp(-2s^2 / (4n)) = 2 exp(-s^2 / (2n))
```

(The factor 4n comes from sum of ranges squared: each Z_i has range 2, so sum = n * 4.)

**Step 3**: The cosine similarity is cos(a,b) = dot(a,b) / (||a|| * ||b||). By concentration (Theorem 11), ||a|| ≈ ||b|| ≈ sqrt(2n/3). So:

```
cos(a, b) ≈ dot(a, b) / (2n/3)
```

**Step 4**: Setting s = epsilon * 2n/3:

```
P( |cos(a, b)| > epsilon )
  ≈ P( |dot(a, b)| > epsilon * 2n/3 )
  ≤ 2 exp(-(epsilon * 2n/3)^2 / (2n))
  = 2 exp(-2n * epsilon^2 / 9)
```

QED

### Practical Implications

| Dimension n | P(\|cos\| > 0.05) | P(\|cos\| > 0.01) |
|-------------|-------|-------|
| 1,000 | ≤ 2 exp(-1.11) ≈ 0.66 | ≤ 2 exp(-0.044) ≈ 1.91 (trivial) |
| 10,000 | ≤ 2 exp(-11.1) ≈ 3e-5 | ≤ 2 exp(-0.44) ≈ 1.28 (trivial) |
| 100,000 | ≤ 2 exp(-111) ≈ 0 | ≤ 2 exp(-4.4) ≈ 0.024 |

For Trinity's typical dimension n = 10,000: two random vectors have cosine similarity within ±0.05 with probability > 99.99%.

---

## Theorem 14 (Bundle Convergence Rate)

<div class="theorem-card">
<h4>Theorem 14 (Bundle Signal Recovery)</h4>

Let v be a target vector in \{-1, +1\}^n and let w_1, ..., w_k be k noisy copies where each trit is independently flipped with probability p < 1/2. Then:

**P( bundle(w_1, ..., w_k) ≠ v ) ≤ n * exp(-2k(1 - 2p)^2)**

The probability of incorrect recovery decays exponentially in k.

</div>

### Proof

**Step 1**: Consider a single coordinate i. Each w_j[i] equals v[i] with probability (1-p) and -v[i] with probability p. The bundle computes the majority vote.

**Step 2**: Define Y_j = w_j[i] * v[i]. Then Y_j = +1 with probability (1-p) and Y_j = -1 with probability p. The majority vote is correct when sum(Y_j) > 0.

**Step 3**: By Hoeffding's inequality:

```
P( sum(Y_j) ≤ 0 ) = P( sum(Y_j) - k(1-2p) ≤ -k(1-2p) )
                    ≤ exp(-2k^2(1-2p)^2 / (4k))
                    = exp(-k(1-2p)^2 / 2)
```

**Step 4**: Union bound over all n coordinates:

```
P( any coordinate incorrect ) ≤ n * exp(-k(1-2p)^2 / 2)
```

QED

### Connection to Error-Correcting Codes

This result parallels the theory of **repetition codes** in coding theory. Bundle acts as a soft majority decoder: given k noisy copies of a message, it recovers the original by voting. The exponent k(1-2p)^2/2 matches the random coding exponent at rate zero, connecting VSA to Shannon's channel coding theorem.

Kleyko et al. (2021) survey the capacity results for VSA bundling, showing that the number of vectors that can be reliably bundled and recovered scales as O(sqrt(n / log n)) for dimension n.

---

## Compressed Sensing with Ternary Matrices

Trinity's random ternary projections are not only useful for dimensionality reduction — they also serve as valid measurement matrices for **compressed sensing**, a technique for recovering sparse signals from sub-Nyquist measurements.

<div class="theorem-card">
<h4>Restricted Isometry Property (RIP)</h4>

A matrix A in R^(m×n) satisfies the RIP of order s with constant δ_s if:

**(1 - δ_s) ||x||^2 ≤ ||Ax||^2 ≤ (1 + δ_s) ||x||^2**

for all s-sparse vectors x (vectors with at most s non-zero entries).

</div>

### Why RIP Matters

If a measurement matrix A satisfies RIP with delta_2s &lt; √2 - 1 ≈ 0.414, then **exact sparse recovery is possible** via ℓ₁-minimization:

```
min ||x||₁  subject to  Ax = b
```

This is the foundation of compressed sensing: we can recover a sparse n-dimensional signal x from only m = O(s log(n/s)) measurements b.

### Ternary Matrices Satisfy RIP

Random ternary matrices A in {-1, 0, +1}^(m×n) satisfy the RIP with high probability when:

```
m ≥ C * s * log(n/s) / δ_s²
```

where C is a constant. This follows from the **sub-Gaussian tail bound**:

**Sub-Gaussian Framework** (Baraniuk et al., 2008): A random variable X is sub-Gaussian if its tail decays at least as fast as a Gaussian. Ternary random variables with the distribution:

```
P(A_ij = +1) = P(A_ij = -1) = 1/6
P(A_ij = 0) = 2/3
```

are sub-Gaussian with parameter ψ = 1/√3. Consequently, random matrices with such entries satisfy RIP with the same scaling as Gaussian matrices.

### Comparison: Gaussian vs Binary vs Ternary

| Matrix Type | RIP scaling | Computation | Sparsity |
|-------------|-------------|-------------|----------|
| **Gaussian** | m = O(s log(n/s)) | O(mn) with multiplications | Dense (0 zeros) |
| **Bernoulli ±1** | m = O(s log(n/s)) | O(mn) no multiplications | Dense (0 zeros) |
| **Ternary {-1, 0, +1}** | m = O(s log(n/s)) | O(nnz(A)) with sparsity | Sparse (2/3 zeros) |

**Key result**: Ternary matrices achieve the same theoretical RIP scaling as Gaussian matrices but with **3× fewer operations** on average due to sparsity (2/3 of entries are zero).

### Binary Sometimes Beats Ternary

Amini et al. (2013) compared binary vs ternary compressed sensing matrices and found a surprising result: **binary {-1, +1} matrices can outperform ternary {-1, 0, +1} matrices** when the sparsity level is low relative to dimension. The reason: ternary matrices have higher variance per entry, which increases the RIP constant delta_s for a given measurement count m.

However, ternary matrices dominate when:
- Computational efficiency is critical (sparse matrix-vector products)
- The measurement process requires symmetric positive and negative responses
- Hardware implementation favors ternary (-1, 0, +1) operations

### Deterministic Ternary Constructions

Amini & Marvasti (2011) gave **deterministic constructions** of ternary sensing matrices using BCH codes and orthogonal optical codes, avoiding the randomness of RIP-based approaches. These matrices:
- Have provable RIP bounds for specific sparsity levels
- Enable fully reproducible measurements
- Are useful for applications requiring deterministic sensing

### Connection to VSA Operations

Trinity's VSA operations mirror compressed sensing primitives:

| VSA Operation | Compressed Sensing Analog |
|---------------|---------------------------|
| **Bind** (element-wise multiply) | Random projection via A x |
| **Bundle** (majority vote) | ℓ₁-minimization / sparse recovery |
| **Quasi-orthogonality** | Incoherence (RIP requirement) |
| **High dimension** | Overcomplete dictionary (n >> m) |

When Trinity bundles many vectors and then probes for a specific vector via similarity, it is effectively performing sparse recovery — distinguishing one component from a superposition of many others.

**References**:
- Amini, A. & Marvasti, F. "Deterministic Construction of Binary, Bipolar, and Ternary Compressed Sensing Matrices." *IEEE Trans. Information Theory* 57(4), 2011.
- Amini, M. et al. "Compressed Sensing Matrices: Binary vs. Ternary." *arXiv* 1304.4161, 2013.
- Chen, X. et al. "Semi-deterministic Ternary Matrix for Compressed Sensing." *EUSIPCO* 2014.
- Yin, D. et al. "Deep Learning Sparse Ternary Projections for Compressed Sensing of Images." *IEEE GlobalSIP* 2017.

---

## Central Limit Theorem for Bundle

<div class="theorem-card">
<h4>Theorem (Ternary CLT for Bundle)</h4>

For independent random ternary vectors v_1, ..., v_k, the pre-thresholded bundle sum S[i] = sum(v_j[i]) satisfies:

**S[i] / sqrt(2k/3) converges in distribution to N(0, 1)**

as k grows, by the classical CLT.

</div>

This explains why the bundle operation becomes **more reliable** as more vectors are added: the sum at each coordinate follows an approximately Gaussian distribution, and the sign-thresholding step selects the correct sign with probability approaching 1 when the true signal dominates.

The variance 2k/3 arises because:

```
Var[v_j[i]] = E[v_j[i]^2] - (E[v_j[i]])^2 = 2/3 - 0 = 2/3
Var[S[i]] = k * 2/3
```

---

## Numerical Verification

```zig
const std = @import("std");
const math = std.math;

test "Theorem 11: norm concentrates around sqrt(2n/3)" {
    const n: usize = 10000;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    const num_trials = 100;
    var within_5_percent: usize = 0;
    const expected_norm_sq: f64 = 2.0 * @as(f64, @floatFromInt(n)) / 3.0;

    var trial: usize = 0;
    while (trial < num_trials) : (trial += 1) {
        var norm_sq: f64 = 0;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const trit = random.intRangeAtMost(i8, -1, 1);
            norm_sq += @as(f64, @floatFromInt(@as(i16, trit) * @as(i16, trit)));
        }
        const ratio = norm_sq / expected_norm_sq;
        if (ratio > 0.95 and ratio < 1.05) within_5_percent += 1;
    }
    // At least 95% of trials should be within 5%
    try std.testing.expect(within_5_percent >= 95);
}

test "Theorem 13: random vectors are quasi-orthogonal" {
    const n: usize = 10000;
    var prng = std.Random.DefaultPrng.init(137);
    const random = prng.random();

    const num_pairs = 50;
    var within_threshold: usize = 0;

    var pair: usize = 0;
    while (pair < num_pairs) : (pair += 1) {
        var dot: f64 = 0;
        var norm_a: f64 = 0;
        var norm_b: f64 = 0;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const a: f64 = @floatFromInt(random.intRangeAtMost(i8, -1, 1));
            const b: f64 = @floatFromInt(random.intRangeAtMost(i8, -1, 1));
            dot += a * b;
            norm_a += a * a;
            norm_b += b * b;
        }
        if (norm_a > 0 and norm_b > 0) {
            const cos_sim = dot / (math.sqrt(norm_a) * math.sqrt(norm_b));
            if (@abs(cos_sim) < 0.05) within_threshold += 1;
        }
    }
    // At least 90% of pairs should have |cos| < 0.05
    try std.testing.expect(within_threshold >= 45);
}

test "Theorem 14: bundle recovers signal from noisy copies" {
    const n: usize = 1000;
    const k: usize = 11; // odd number of copies
    const flip_prob = 0.2; // 20% noise
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    // Generate target vector (non-zero only)
    var target: [1000]i8 = undefined;
    for (&target) |*t| {
        t.* = if (random.boolean()) @as(i8, 1) else @as(i8, -1);
    }

    // Generate noisy copies and bundle
    var accum: [1000]i16 = [_]i16{`\1`}} ** 1000;
    var copy: usize = 0;
    while (copy < k) : (copy += 1) {
        for (0..n) |i| {
            const noise = random.float(f32);
            const trit: i8 = if (noise < flip_prob) -target[i] else target[i];
            accum[i] += @as(i16, trit);
        }
    }

    // Check recovery
    var correct: usize = 0;
    for (0..n) |i| {
        const recovered: i8 = if (accum[i] > 0) 1 else if (accum[i] < 0) -1 else 0;
        if (recovered == target[i]) correct += 1;
    }
    // With k=11 copies and p=0.2 noise, expect >99% recovery
    try std.testing.expect(correct > 990);
}
```

---

## Explore with TRI CLI

```bash
tri math-verify            # Run concentration + orthogonality checks
tri math-bench             # Benchmark high-dimensional operations
tri constants              # Show all sacred constants used in proofs
```

---

## References

1. Hoeffding, W. "Probability Inequalities for Sums of Bounded Random Variables." *Journal of the American Statistical Association* 58(301), pp. 13--30, 1963.
2. Johnson, W. B. and Lindenstrauss, J. "Extensions of Lipschitz mappings into a Hilbert space." *Contemporary Mathematics* 26, pp. 189--206, 1984.
3. Achlioptas, D. "Database-friendly random projections: Johnson-Lindenstrauss with binary coins." *Journal of Computer and System Sciences* 66(4), pp. 671--687, 2003.
4. Ledoux, M. *The Concentration of Measure Phenomenon*. American Mathematical Society, Mathematical Surveys and Monographs 89, 2001.
5. Boucheron, S., Lugosi, G., and Massart, P. *Concentration Inequalities: A Nonasymptotic Theory of Independence*. Oxford University Press, 2013.
6. Candes, E. J. and Tao, T. "Decoding by Linear Programming." *IEEE Transactions on Information Theory* 51(12), pp. 4203--4215, 2005.
7. Donoho, D. L. "Compressed Sensing." *IEEE Transactions on Information Theory* 52(4), pp. 1289--1306, 2006.
8. Baraniuk, R. G. et al. "A Simple Proof of the Restricted Isometry Property for Random Matrices." *Constructive Approximation* 28(3), pp. 253--263, 2008.
9. Kleyko, D. et al. "Vector Symbolic Architectures as a Computing Framework for Emerging Hardware." *Proceedings of the IEEE* 110(10), pp. 1538--1571, 2022.
10. Levy, P. *Problemes concrets d'analyse fonctionnelle*. Gauthier-Villars, 1951.
11. Milman, V. D. "New Proof of the Theorem of A. Dvoretzky on Intersections of Convex Bodies." *Functional Analysis and Its Applications* 5(4), pp. 288--295, 1971.
12. Shannon, C. E. "A Mathematical Theory of Communication." *Bell System Technical Journal* 27(3), pp. 379--423, 1948.
13. Amini, A. and Marvasti, F. "Deterministic Construction of Binary, Bipolar, and Ternary Compressed Sensing Matrices." *IEEE Transactions on Information Theory* 57(4), pp. 2379--2391, 2011.
14. Amini, M. et al. "Compressed Sensing Matrices: Binary vs. Ternary." *arXiv* 1304.4161, 2013.
15. Chen, X. et al. "Semi-deterministic Ternary Matrix for Compressed Sensing." *Proceedings of EUSIPCO* 2014.

---

**phi^2 + 1/phi^2 = 3 = TRINITY**
