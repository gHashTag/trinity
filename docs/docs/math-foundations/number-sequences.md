---
sidebar_position: 9
sidebar_label: 'Number Sequences'
---

# Number Sequences

Trinity implements a rich collection of integer sequences in `src/sacred/sequences.zig`. Each sequence has deep connections to the golden ratio, ternary arithmetic, or combinatorial structures. This page provides mathematical definitions, key properties, OEIS references, and connections to Trinity's architecture.

---

## Metallic Means Family

The golden ratio phi is the first member of an infinite family of **metallic means** -- algebraic numbers that generalize the self-similarity property phi^2 = phi + 1.

<div class="theorem-card">
<h4>Definition (Metallic Means)</h4>

The k-th metallic mean delta_k is the positive root of x^2 - k*x - 1 = 0:

**delta_k = (k + sqrt(k^2 + 4)) / 2**

</div>

| k | Name | Value | Companion Sequence |
|---|------|-------|--------------------|
| 1 | **Golden** (phi) | 1.6180339887... | Fibonacci |
| 2 | **Silver** (delta_S) | 2.4142135623... = 1 + sqrt(2) | Pell |
| 3 | **Bronze** (delta_B) | 3.3027756377... | "Tribonacci-like" |

### Properties Shared by All Metallic Means

```
delta_k^2 = k * delta_k + 1        (defining equation)
1/delta_k = delta_k - k             (reciprocal relation)
delta_k + 1/delta_k = sqrt(k^2 + 4) (sum with reciprocal)
```

For the golden mean (k=1): delta_1 + 1/delta_1 = sqrt(5), and delta_1^2 + 1/delta_1^2 = 3 = TRINITY.

---

## Fibonacci Numbers (OEIS A000045)

<div class="theorem-card">
<h4>Definition</h4>

**F(0) = 0, F(1) = 1, F(n) = F(n-1) + F(n-2)**

Sequence: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, ...

</div>

### Binet's Formula

```
F(n) = (phi^n - psi^n) / sqrt(5)

where phi = (1 + sqrt(5))/2, psi = (1 - sqrt(5))/2
```

### Key Properties

| Property | Formula | Significance |
|----------|---------|-------------|
| Limit ratio | lim F(n+1)/F(n) = phi | Theorem 5 (see Proofs) |
| GCD | gcd(F(m), F(n)) = F(gcd(m,n)) | Fibonacci numbers form a divisibility lattice |
| Sum of squares | F(n)^2 + F(n+1)^2 = F(2n+1) | Connects to Pythagorean triples |
| Zeckendorf | Every positive integer has unique Fibonacci representation | Basis for Fibonacci coding |
| F(4) = 3 | **TRINITY appears at index 4** | phi^4 = 3*phi + 2 |

### Connection to Trinity

- **F(4) = 3 = TRINITY**: The fourth Fibonacci number is the ternary base
- **F(7) = 13 = TRYTE_MAX**: Maximum value of a balanced ternary tryte (3 trits: 1+3+9)
- **Fibonacci encoding**: Every non-negative integer can be uniquely represented as a sum of non-consecutive Fibonacci numbers (Zeckendorf's theorem, 1972). This connects to balanced ternary representation via a different basis

**Reference**: Koshy, T. *Fibonacci and Lucas Numbers with Applications*. Wiley, 2001.

---

## Lucas Numbers (OEIS A000032)

<div class="theorem-card">
<h4>Definition</h4>

**L(0) = 2, L(1) = 1, L(n) = L(n-1) + L(n-2)**

Sequence: 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, ...

</div>

### Closed Form

```
L(n) = phi^n + psi^n = phi^n + (-1/phi)^n
```

### Key Properties

| Property | Formula |
|----------|---------|
| Fibonacci relation | L(n) = F(n-1) + F(n+1) |
| Product | F(n) * L(n) = F(2n) |
| Identity | L(n)^2 - 5*F(n)^2 = 4*(-1)^n |
| **L(2) = 3** | **TRINITY is the second Lucas number** |

### Trinity Connections

- **L(2) = 3 = TRINITY**: The most direct appearance of 3 in the golden ratio family
- **L(n) = phi^n + 1/phi^n** (for even n): This generalizes the Trinity Identity. At n=2: phi^2 + 1/phi^2 = 3
- **L(10) = 123**: Used as a magic constant in several Trinity modules

---

## Pell Numbers (OEIS A000129)

<div class="theorem-card">
<h4>Definition</h4>

**P(0) = 0, P(1) = 1, P(n) = 2*P(n-1) + P(n-2)**

Sequence: 0, 1, 2, 5, 12, 29, 70, 169, 408, 985, ...

</div>

### Silver Ratio Connection

```
lim P(n+1)/P(n) = delta_S = 1 + sqrt(2) = 2.41421356...
```

The Pell numbers play the same role for the **silver ratio** (delta_S) that Fibonacci numbers play for the golden ratio (phi). They provide the best rational approximations to sqrt(2):

```
P(1)/P(0) → undefined
P(2)/P(1) = 2/1 = 2.000
P(3)/P(2) = 5/2 = 2.500
P(4)/P(3) = 12/5 = 2.400
P(5)/P(4) = 29/12 = 2.4166...
P(6)/P(5) = 70/29 = 2.4137...   (converging to sqrt(2) + 1)
```

### Connection to Trinity

- The silver ratio satisfies delta_S^2 = 2*delta_S + 1, analogous to phi^2 = phi + 1
- However, delta_S^2 + 1/delta_S^2 = 6 ≠ 3. The Trinity Identity is **unique to the golden ratio**

**Reference**: Sloane, N. J. A. "Sequence A000129." The On-Line Encyclopedia of Integer Sequences.

---

## Tribonacci Numbers (OEIS A000073)

<div class="theorem-card">
<h4>Definition</h4>

**T(0) = 0, T(1) = 0, T(2) = 1, T(n) = T(n-1) + T(n-2) + T(n-3)**

Sequence: 0, 0, 1, 1, 2, 4, 7, 13, 24, 44, 81, 149, ...

</div>

### Tribonacci Constant (Tetranacci Ratio)

```
lim T(n+1)/T(n) = tau_3 ≈ 1.8392867552141612
```

This is the real root of x^3 = x^2 + x + 1 (the tribonacci polynomial).

### Properties

```
tau_3^3 = tau_3^2 + tau_3 + 1     (defining equation)
tau_3 is the unique real root > 1 of x^3 - x^2 - x - 1 = 0
```

### Connection to Trinity

The tribonacci recurrence sums **three** previous terms, making it a natural ternary generalization of Fibonacci. Note that T(6) = 7, T(7) = 13 = TRYTE_MAX, and T(10) = 81 = 3^4.

---

## Padovan Sequence (OEIS A000931)

<div class="theorem-card">
<h4>Definition</h4>

**P(0) = 1, P(1) = 0, P(2) = 0, P(n) = P(n-2) + P(n-3)**

Sequence: 1, 0, 0, 1, 0, 1, 1, 1, 2, 2, 3, 4, 5, 7, 9, 12, ...

</div>

### Plastic Number

```
lim P(n+1)/P(n) = rho ≈ 1.3247179572447460
```

The **plastic number** rho is the real root of x^3 = x + 1. It was named by Dom Hans van der Laan (1967), who used it in architecture as an alternative to the golden ratio.

### Properties

```
rho^3 = rho + 1                     (defining equation)
rho is the smallest Pisot-Vijayaraghavan number > 1
rho^(3n) approaches integers rapidly
```

### Connection to Trinity

The plastic number is the **smallest PV number** -- an algebraic integer greater than 1 whose conjugates all lie strictly inside the unit circle. PV numbers have deep connections to:
- Quasicrystals (Penrose tilings use phi; Padovan-based tilings use rho)
- Number theory (Salem numbers, Lehmer's conjecture)

---

## Perrin Sequence (OEIS A001608)

<div class="theorem-card">
<h4>Definition</h4>

**R(0) = 3, R(1) = 0, R(2) = 2, R(n) = R(n-2) + R(n-3)**

Sequence: 3, 0, 2, 3, 2, 5, 5, 7, 10, 12, 17, 22, 29, ...

</div>

### Primality Connection

A remarkable property: if p is prime, then p divides R(p). The converse is **almost** true -- Perrin pseudoprimes are extremely rare (only 17 below 10^9).

### Connection to Trinity

- **R(0) = 3 = TRINITY**: The Perrin sequence begins with Trinity
- Same limiting ratio as Padovan (plastic number rho)

---

## Catalan Numbers (OEIS A000108)

<div class="theorem-card">
<h4>Definition</h4>

**C_n = (2n)! / ((n+1)! * n!) = binom(2n, n) / (n+1)**

Sequence: 1, 1, 2, 5, 14, 42, 132, 429, 1430, 4862, ...

</div>

### Combinatorial Interpretations

Catalan numbers count (among many other things):
- **Binary trees** with n+1 leaves
- **Balanced parenthesizations** of n pairs
- **Triangulations** of a convex (n+2)-gon
- **Dyck paths** of length 2n (lattice paths that never dip below the x-axis)
- **Non-crossing partitions** of \{1, ..., n\}

### Generating Function

```
C(x) = (1 - sqrt(1 - 4x)) / (2x) = sum C_n * x^n
```

### Asymptotic Growth

```
C_n ~ 4^n / (sqrt(pi) * n^(3/2))
```

### Connection to Trinity

Catalan numbers count the number of ways to structure **recursive ternary computations**:
- Binary tree structures for organizing VSA bind/bundle operations
- Non-crossing partitions relate to the algebraic structure of bundle (Theorem 9)
- The generating function involves sqrt, connecting to the golden ratio's sqrt(5) definition

**Reference**: Stanley, R. P. *Catalan Numbers*. Cambridge University Press, 2015.

---

## Bernoulli Numbers (OEIS A027642)

<div class="theorem-card">
<h4>Definition</h4>

Bernoulli numbers B_n are defined by the generating function:

**x / (e^x - 1) = sum B_n * x^n / n!**

First values: B_0 = 1, B_1 = -1/2, B_2 = 1/6, B_4 = -1/30, B_6 = 1/42

(All odd Bernoulli numbers except B_1 are zero.)

</div>

### Connection to Riemann Zeta

```
zeta(2n) = (-1)^(n+1) * B_{2n} * (2*pi)^(2n) / (2 * (2n)!)
```

This gives:

| n | zeta(2n) | Formula |
|---|----------|---------|
| 1 | pi^2/6 | B_2 = 1/6 |
| 2 | pi^4/90 | B_4 = -1/30 |
| 3 | pi^6/945 | B_6 = 1/42 |

### Connection to Trinity

- **B_2 = 1/6** and **zeta(2) = pi^2/6**: the denominator 6 = 2 * 3 = 2 * TRINITY
- Bernoulli numbers appear in the **Euler-Maclaurin summation formula**, which connects discrete sums to integrals -- the mathematical bridge between ternary (discrete) and continuous computation

---

## Euler Numbers (OEIS A122045)

<div class="theorem-card">
<h4>Definition</h4>

Euler numbers E_n are defined by:

**1 / cosh(x) = sech(x) = sum E_n * x^n / n!**

First values: E_0 = 1, E_2 = -1, E_4 = 5, E_6 = -61, E_8 = 1385

(All odd Euler numbers are zero.)

</div>

### Tangent Numbers

The closely related tangent numbers (coefficients of tan(x)) are:

```
T_1 = 1, T_3 = 2, T_5 = 16, T_7 = 272
```

### Connection to Trinity

- |E_0| = 1, |E_2| = 1, |E_4| = 5: the sequence 1, 1, 5 satisfies 1 + 1 + ... = building blocks of ternary arithmetic
- Euler numbers count **alternating permutations** (zigzag permutations), connecting to the structure of cyclic permutations in VSA (Theorem 10)

---

## Summary Table

| Sequence | Recurrence | Limiting Ratio | OEIS | Trinity Connection |
|----------|-----------|----------------|------|--------------------|
| Fibonacci | F(n) = F(n-1) + F(n-2) | phi = 1.618... | A000045 | F(4) = 3 = TRINITY |
| Lucas | L(n) = L(n-1) + L(n-2) | phi = 1.618... | A000032 | L(2) = 3, phi^2 + 1/phi^2 = 3 |
| Pell | P(n) = 2P(n-1) + P(n-2) | 1+sqrt(2) = 2.414... | A000129 | Silver ratio analog |
| Tribonacci | T(n) = T(n-1)+T(n-2)+T(n-3) | 1.839... | A000073 | 3-term = ternary recurrence |
| Padovan | P(n) = P(n-2) + P(n-3) | rho = 1.325... | A000931 | Smallest PV number |
| Perrin | R(n) = R(n-2) + R(n-3) | rho = 1.325... | A001608 | R(0) = 3 = TRINITY |
| Catalan | C_n = binom(2n,n)/(n+1) | 4^n growth | A000108 | Binary tree counting |
| Bernoulli | Generating function | -- | A027642 | zeta(2n), Euler-Maclaurin |
| Euler | Generating function | -- | A122045 | Alternating permutations |

---

## Numerical Verification

```zig
const std = @import("std");
const math = std.math;

const PHI: f64 = (1.0 + math.sqrt(5.0)) / 2.0;

test "Fibonacci: F(4) = 3 = TRINITY" {
    const fib = [_]u64{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34 };
    try std.testing.expectEqual(@as(u64, 3), fib[4]);
}

test "Lucas: L(2) = 3 = TRINITY" {
    const lucas = [_]u64{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76 };
    try std.testing.expectEqual(@as(u64, 3), lucas[2]);
}

test "Lucas closed form: L(n) = phi^n + psi^n" {
    const psi = (1.0 - math.sqrt(5.0)) / 2.0;
    var n: usize = 0;
    const lucas = [_]u64{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76 };
    while (n < 10) : (n += 1) {
        const phi_n = math.pow(f64, PHI, @floatFromInt(n));
        const psi_n = math.pow(f64, psi, @floatFromInt(n));
        const computed = phi_n + psi_n;
        try std.testing.expectApproxEqAbs(
            @as(f64, @floatFromInt(lucas[n])),
            computed,
            0.001,
        );
    }
}

test "Pell: ratio converges to silver ratio" {
    var a: f64 = 0;
    var b: f64 = 1;
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        const temp = b;
        b = 2 * b + a;
        a = temp;
    }
    const silver = 1.0 + math.sqrt(2.0);
    try std.testing.expectApproxEqAbs(b / a, silver, 1e-10);
}

test "Golden uniqueness: only phi gives identity = 3" {
    // phi^2 + 1/phi^2 = 3
    const golden = PHI * PHI + 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(golden, 3.0, 1e-10);

    // Silver: delta_S^2 + 1/delta_S^2 = 6, NOT 3
    const silver = 1.0 + math.sqrt(2.0);
    const silver_sum = silver * silver + 1.0 / (silver * silver);
    try std.testing.expectApproxEqAbs(silver_sum, 6.0, 1e-10);

    // Bronze: delta_B^2 + 1/delta_B^2 = 11, NOT 3
    const bronze = (3.0 + math.sqrt(13.0)) / 2.0;
    const bronze_sum = bronze * bronze + 1.0 / (bronze * bronze);
    try std.testing.expectApproxEqAbs(bronze_sum, 11.0, 1e-10);
}
```

The last test demonstrates that the Trinity Identity phi^2 + 1/phi^2 = 3 is **unique to the golden ratio**. No other metallic mean produces 3.

---

## Compute with TRI CLI

```bash
tri fib 30                 # F(30) = 832040
tri lucas 10               # L(10) = 123
tri math golden-function   # Pellis 2025: G(x) = phi^x + phi^(-x)
tri math-compare           # Side-by-side comparison table
tri math nuclear           # Nuclear Fibonacci shell stability
```

---

## References

1. Koshy, T. *Fibonacci and Lucas Numbers with Applications*. Wiley, 2001.
2. Graham, R. L., Knuth, D. E., and Patashnik, O. *Concrete Mathematics: A Foundation for Computer Science*. Addison-Wesley, 2nd edition, 1994.
3. Stanley, R. P. *Catalan Numbers*. Cambridge University Press, 2015.
4. Sloane, N. J. A. *The On-Line Encyclopedia of Integer Sequences*. https://oeis.org/.
5. Zeckendorf, E. "Representation des nombres naturels par une somme de nombres de Fibonacci ou de nombres de Lucas." *Bulletin de la Societe Royale des Sciences de Liege* 41, pp. 179--182, 1972.
6. van der Laan, H. *Le Nombre Plastique: Quinze Lecons sur l'Ordonnance Architectonique*. Brill, 1960.
7. Hardy, G. H. and Wright, E. M. *An Introduction to the Theory of Numbers*. Oxford University Press, 6th edition, 2008.
8. Ireland, K. and Rosen, M. *A Classical Introduction to Modern Number Theory*. Springer, 2nd edition, 1990.

---

**phi^2 + 1/phi^2 = 3 = TRINITY**
