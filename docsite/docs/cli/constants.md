---
sidebar_position: 15
sidebar_label: Sacred Constants
---

# Sacred Constants Reference

Complete catalog of mathematical, physical, and exotic constants available in TRI CLI. All constants are defined in `src/tri/tri_math.zig` and accessible via `tri constants` and `tri math` subcommands.

## Quick Access

```bash
tri constants           # Show core sacred constants
tri math exotic         # Exotic mathematical constants
tri math physical       # Physics constants
tri math chaos          # Chaos theory constants
tri math all            # Display ALL constants
```

## Core Sacred Constants (Cycle 82)

### Golden Ratio Family

| Constant | Symbol | Value | Formula |
|----------|--------|-------|---------|
| Golden ratio | $\phi$ | 1.6180339887498948 | $\frac{1+\sqrt{5}}{2}$ |
| Golden ratio squared | $\phi^2$ | 2.6180339887498948 | $\phi + 1$ |
| Inverse golden ratio | $\phi^{-1}$ | 0.6180339887498948 | $\phi - 1 = \frac{1}{\phi}$ |
| Inverse squared | $\phi^{-2}$ | 0.3819660112501051 | $\frac{1}{\phi^2}$ |

**Trinity Identity:**

$$\phi^2 + \frac{1}{\phi^2} = 3 = \text{TRINITY}$$

### Fundamental Mathematical Constants

| Constant | Symbol | Value |
|----------|--------|-------|
| Pi | $\pi$ | 3.1415926535897932 |
| Euler's number | $e$ | 2.7182818284590452 |
| Square root of 2 | $\sqrt{2}$ | 1.4142135623730950 |
| Square root of 3 | $\sqrt{3}$ | 1.7320508075688772 |
| Square root of 5 | $\sqrt{5}$ | 2.2360679774997896 |
| Natural log of 2 | $\ln 2$ | 0.6931471805599453 |
| Euler-Mascheroni | $\gamma$ | 0.5772156649015328 |

### Trinity-Specific Constants

| Constant | Symbol | Value | Description |
|----------|--------|-------|-------------|
| TRINITY | $T$ | 3 | $\phi^2 + 1/\phi^2$ |
| MU | $\mu$ | 0.0382 | $\phi^{-4}$ |
| CHI | $\chi$ | 0.0618 | $\phi^{-2} - \phi^{-3}$ |
| SIGMA | $\sigma$ | 1.618 | $\approx \phi$ |
| EPSILON | $\varepsilon$ | 0.333 | $\approx 1/3$ |
| Transcendental | — | 13.8168907... | $\phi \cdot \pi \cdot e^{\pi/\phi}$ |

## Exotic Mathematical Constants (Cycle 83)

```bash
tri math exotic
```

| Constant | Value | Description |
|----------|-------|-------------|
| Apery's constant $\zeta(3)$ | 1.2020569031595942 | Sum $\sum_{n=1}^{\infty} 1/n^3$, proved irrational by Apery (1978) |
| Catalan's constant $G$ | 0.9159655941772190 | $\sum_{n=0}^{\infty} (-1)^n / (2n+1)^2$ |
| Feigenbaum delta $\delta$ | 4.6692016091029906 | Period-doubling bifurcation ratio (chaos theory) |
| Feigenbaum alpha $\alpha$ | 2.5029078750958928 | Scaling factor in bifurcation diagram |
| Khinchin's constant $K$ | 2.6854520010653064 | Geometric mean of continued fraction coefficients |
| Glaisher-Kinkelin $A$ | 1.2824271291006226 | Related to Barnes G-function |
| Omega constant $\Omega$ | 0.5671432904097838 | $W(1)$ where $W$ is Lambert W function ($xe^x = 1$) |
| Plastic number $\rho$ | 1.3247179572447460 | Real root of $x^3 = x + 1$ (cubic golden ratio) |
| Landau-Ramanujan | 0.7642236535892206 | Density of sums of two squares |
| Conway's constant $\lambda$ | 1.3035772690342963 | Growth rate of look-and-say sequence |

## Physics Constants (Cycle 83)

```bash
tri math physical
```

### Quantum & Electromagnetic

| Constant | Symbol | Value | Units |
|----------|--------|-------|-------|
| Fine structure | $\alpha$ | 0.0072973525693 | dimensionless |
| Fine structure inverse | $1/\alpha$ | 137.036 | dimensionless |
| CHSH bound | $2\sqrt{2}$ | 2.8284271247461903 | Bell test maximum |
| Elementary charge | $e$ | $1.602176634 \times 10^{-19}$ | C |
| Speed of light | $c$ | 299,792,458 | m/s |

### Planck Units

| Constant | Symbol | Value | Units |
|----------|--------|-------|-------|
| Planck constant | $h$ | $6.62607015 \times 10^{-34}$ | J·s |
| Reduced Planck | $\hbar$ | $1.054571817 \times 10^{-34}$ | J·s |
| Planck length | $l_P$ | $1.616255 \times 10^{-35}$ | m |
| Planck time | $t_P$ | $5.391247 \times 10^{-44}$ | s |
| Planck mass | $m_P$ | $2.176434 \times 10^{-8}$ | kg |

### Thermodynamics & Gravity

| Constant | Symbol | Value | Units |
|----------|--------|-------|-------|
| Boltzmann | $k_B$ | $1.380649 \times 10^{-23}$ | J/K |
| Gravitational | $G$ | $6.67430 \times 10^{-11}$ | m$^3$/(kg·s$^2$) |
| Avogadro's number | $N_A$ | $6.02214076 \times 10^{23}$ | 1/mol |

## Golden Function Constants (Cycle 84)

Based on Pellis 2025: "The Golden Function and its applications to mathematical physics."

```bash
tri math golden-function
```

| Constant | Value | Description |
|----------|-------|-------------|
| $\phi^{1/2}$ | 1.2720196495 | $\sqrt{\phi}$ |
| $G(0.5)$ | 2.0581710272 | $\sqrt{\phi} + 1/\sqrt{\phi}$ |
| $\phi^{\phi}$ | 2.3903891399 | Golden self-exponentiation |
| $\phi^{\pi}$ | 4.5310082907 | Transcendental golden power |

The **Golden Function** $G(x) = \phi^x + \phi^{-x}$ is the continuous extension of Lucas numbers: $G(n) = L(n)$ for integer $n$.

## Nuclear Fibonacci Constants (Cycle 84)

```bash
tri math nuclear
```

Nuclear shell magic numbers correlate with Fibonacci/Lucas sequences:

| Magic number | Fibonacci/Lucas connection |
|-------------|---------------------------|
| 2 | $L(0) = 2$ |
| 8 | $F(6) = 8$ |
| 20 | $\approx F(8) - 1$ |
| 28 | $= L(7) - 1$ |
| 50 | $\approx F(10) - 5$ |
| 82 | stable shell |
| 126 | stable shell |

- N/Z stability ratio for heavy nuclei: $\phi / \sqrt{2} \approx 1.144$
- Binding energy peak: $8.8 \text{ MeV} \approx F(6) + \phi^{-1}$

## Chaos Theory (Cycle 83)

```bash
tri math chaos
```

The **Feigenbaum constants** govern the universal behavior of chaotic systems:

- $\delta = 4.669...$: Ratio of successive period-doubling intervals
- $\alpha = 2.502...$: Scaling factor of function values at bifurcation points

These constants appear in **any** system exhibiting period-doubling route to chaos — from fluid dynamics to population models.

## Command Summary

| Command | Category | Constants shown |
|---------|----------|----------------|
| `tri constants` | Core | 14+ golden ratio, pi, e, Trinity |
| `tri math exotic` | Exotic | 10 rare mathematical constants |
| `tri math physical` | Physics | 12 fundamental physics constants |
| `tri math chaos` | Chaos | Feigenbaum + logistic map demo |
| `tri math all` | Complete | All 76+ constants in catalog |
| `tri math golden-function` | Advanced | Pellis 2025 continuous Lucas |
| `tri math nuclear` | Advanced | Nuclear shell magic numbers |
| `tri math fractal` | Advanced | Fractal dimensions (Sierpinski, Koch, Menger) |

## See Also

- [Sacred Math](/cli/math) — Full math command reference (40+ commands)
- [Mathematical Foundations](/math-foundations/) — Proofs and theory
- [Concepts: Trinity Identity](/concepts/trinity-identity) — $\phi^2 + 1/\phi^2 = 3$ proof
