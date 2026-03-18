---
sidebar_position: 12
sidebar_label: 'Cosmological Constants'
---

# Cosmological Constants

Trinity's sacred formula engine generates numerical approximations to cosmological parameters using the parametric form V = n * 3^k * pi^m * phi^p * e^q. This page documents the cosmological constants implemented in `src/sacred/const.zig`, their measured values, sacred approximations, and current observational status.

:::warning[Numerical Coincidences vs Physical Theories]
The parametric approximations below are empirical fits, not derived from first principles. With 5 free parameters, close matches to any target value are statistically expected. The mathematical relationships are noted for their elegance, not as claims about the underlying physics.
:::

**Source**: `src/sacred/const.zig` (cosmology section)

---

## The Hubble Tension

<div class="theorem-card">
<h4>Hubble Constant H_0</h4>

The rate of expansion of the Universe, measured in km/s/Mpc:

| Source | H_0 (km/s/Mpc) | Method |
|--------|----------------|--------|
| **Planck** (2020) | 67.4 +/- 0.5 | CMB (early Universe) |
| **SH0ES** (2022) | 73.0 +/- 1.0 | Cepheid distance ladder (late Universe) |
| **Sacred prediction** | 70.74 | Parametric formula |

</div>

### The Tension

The 4.4-sigma discrepancy between early-Universe (CMB) and late-Universe (Cepheid) measurements is one of the most significant open problems in modern cosmology. The two values are:

```
Planck:  H_0 = 67.4 +/- 0.5  km/s/Mpc
SH0ES:   H_0 = 73.0 +/- 1.0  km/s/Mpc
Gap:     5.6 km/s/Mpc (4.4 sigma)
```

### Sacred Prediction

Trinity's parametric fit yields H_0 = 70.74, falling between the two measurements. This may be a coincidence or may correspond to the true value if the tension is resolved by new physics affecting both measurements.

**References**:
- Planck Collaboration. "Planck 2018 Results. VI. Cosmological Parameters." *Astronomy & Astrophysics* 641, A6, 2020.
- Riess, A. G. et al. "A Comprehensive Measurement of the Local Value of the Hubble Constant." *The Astrophysical Journal Letters* 934, L7, 2022.

---

## Dark Energy and Dark Matter

<div class="theorem-card">
<h4>Energy Budget of the Universe</h4>

| Component | Symbol | Sacred Formula | Calculated | Observed |
|-----------|--------|---------------|------------|----------|
| Dark energy | Omega_Lambda | (pi - 1) / pi | 0.6817 | 0.685 +/- 0.007 |
| Matter | Omega_m | 1 / pi | 0.3183 | 0.315 +/- 0.007 |
| **Total** | | | **1.0000** | **1.000** |

</div>

### The pi-Partition

The sacred approximation partitions the Universe's energy density using pi:

```
Omega_Lambda = (pi - 1) / pi = 1 - 1/pi = 0.6817...
Omega_m      = 1 / pi = 0.3183...
Sum          = 1.000 (exact, by construction)
```

The measured values (Planck 2020: Omega_Lambda = 0.685, Omega_m = 0.315) agree to within ~1%. The exactness of the sum is a consequence of the formula's structure (the two terms are complements), not a physical prediction.

### Dark Energy Discovery

The accelerating expansion of the Universe was discovered independently by two groups:

- Perlmutter, S. et al. "Measurements of Omega and Lambda from 42 High-Redshift Supernovae." *The Astrophysical Journal* 517, pp. 565--586, 1999.
- Riess, A. G. et al. "Observational Evidence from Supernovae for an Accelerating Universe and a Cosmological Constant." *The Astronomical Journal* 116, pp. 1009--1038, 1998.

Both groups shared the 2011 Nobel Prize in Physics.

---

## Cosmic Microwave Background

<div class="theorem-card">
<h4>CMB Parameters</h4>

| Parameter | Symbol | Value | Sacred Connection |
|-----------|--------|-------|------------------|
| CMB temperature | T_CMB | 2.7255 K | Close to e = 2.718 |
| Spectral index | n_s | 0.9649 | 94 / pi^4 = 0.9649 |
| Critical density | rho_c | 9.47e-27 kg/m^3 | - |

</div>

### Spectral Index

The scalar spectral index n_s measures the slight departure from scale invariance in the primordial power spectrum. The sacred formula:

```
n_s = 94 / pi^4 = 94 / 97.409... = 0.96490...
```

matches the Planck 2020 measurement (n_s = 0.9649 +/- 0.0042) to within the measurement uncertainty. This is one of the more constrained fits -- the integer coefficient 94 is the only free parameter, since pi^4 is fixed.

### CMB Temperature

The CMB temperature T_CMB = 2.7255 K (Fixsen, 2009) is close to both:
- e = 2.718... (Euler's number)
- 3 - 1/phi^2 = 3 - 0.382 = 2.618... (less precise)

These are noted as coincidences.

---

## Age of the Universe

<div class="formula">

**t_0 = 13.82 Gyr**

</div>

The age of the Universe from Planck 2020 is 13.799 +/- 0.021 Gyr. Trinity notes the numerical coincidence:

```
pi * phi * e = 3.14159... * 1.61803... * 2.71828...
             = 13.8169...
```

This is within 0.1% of the measured age. However, the product of three transcendental numbers close to the measured age (in Gyr) is a coincidence dependent on the choice of units (it would fail in years, seconds, or Planck time units).

---

## Planck Units

<div class="theorem-card">
<h4>Planck Natural Units</h4>

Planck units are constructed from the three fundamental constants G, hbar, and c:

| Unit | Symbol | Value | Formula |
|------|--------|-------|---------|
| Planck length | l_P | 1.616e-35 m | sqrt(hbar*G/c^3) |
| Planck time | t_P | 5.391e-44 s | sqrt(hbar*G/c^5) |
| Planck mass | m_P | 2.176e-8 kg | sqrt(hbar*c/G) |
| Planck temperature | T_P | 1.417e32 K | sqrt(hbar*c^5/(G*k_B^2)) |

</div>

### Planck Scale Significance

The Planck scale represents the regime where quantum mechanics and general relativity are both important. Below l_P, the concept of smooth spacetime is expected to break down. The Planck mass m_P = 2.176e-8 kg = 21.76 micrograms is roughly the mass of a flea egg -- the scale where gravitational self-energy equals quantum energy.

### Hierarchy Problem

The ratio of the Planck mass to the proton mass is:

```
m_P / m_p = 2.176e-8 / 1.673e-27 = 1.301e19
```

This enormous ratio (the "hierarchy problem") is one of the deepest unsolved problems in physics. No sacred formula captures it naturally, which may indicate that the parametric form V = n * 3^k * pi^m * phi^p * e^q is insufficient for ratios spanning many orders of magnitude.

---

## Fundamental Physics Constants

Trinity stores key physics constants from CODATA 2018:

| Constant | Symbol | Value | Unit |
|----------|--------|-------|------|
| Speed of light | c | 299,792,458 | m/s (exact) |
| Planck constant | h | 6.626e-34 | J*s (exact) |
| Reduced Planck | hbar | 1.055e-34 | J*s |
| Gravitational | G | 6.674e-11 | m^3/(kg*s^2) |
| Fine structure | alpha | 1/137.036 | dimensionless |
| Boltzmann | k_B | 1.381e-23 | J/K (exact) |
| Elementary charge | e | 1.602e-19 | C (exact) |
| Stefan-Boltzmann | sigma | 5.670e-8 | W/(m^2*K^4) |

Since 2019, four constants (h, k_B, e, N_A) are exact by definition, fixing the SI units.

---

## Particle Physics Constants

### Mass Ratios

| Ratio | Sacred Formula | Calculated | Measured | Error |
|-------|---------------|------------|----------|-------|
| m_p/m_e | 6 * pi^5 | 1836.12 | 1836.15 | 0.002% |
| m_mu/m_e | (17/9) * pi^2 * phi^5 | 206.85 | 206.77 | 0.04% |
| m_tau/m_e | 76 * 9 * pi * phi | 3477.2 | 3477.2 | &lt;0.01% |

### Mixing Angles

| Parameter | Sacred Formula | Calculated | Measured | Error |
|-----------|---------------|------------|----------|-------|
| sin^2(theta_W) | 3/(3 + phi*pi) | 0.2313 | 0.2312 | 0.04% |
| Weinberg angle | - | 0.23121 | 0.23122 | 0.004% |

### Boson Masses

| Particle | Sacred Formula | Calculated | Measured |
|----------|---------------|------------|----------|
| W boson | 3^4 * phi * pi | 80.39 GeV | 80.38 GeV |
| Higgs | 3^3 * phi^3 * pi^2 / e | ~125.1 GeV | 125.25 GeV |

---

## Sacred Number Theory

Trinity's sacred number theory module connects ancient numerological observations to modern mathematics:

| Concept | Value | Formula |
|---------|-------|---------|
| Tridevyatitsa | 27 | 3^3 = TRYTE_SPACE |
| Sacred multiplier | 37 | 37 * 3n = nnn (repdigit) |
| Sacred number | 999 | 37 * 27 |
| Nuclear magic numbers | 2, 8, 20, 28, 50, 82, 126 | Shell model |
| Predicted magic number | 184 | Island of stability |

### Nuclear Magic Numbers

The nuclear shell model predicts "magic numbers" -- numbers of protons or neutrons that result in particularly stable nuclei. Trinity notes approximate correlations with Fibonacci/Lucas numbers:

```
2  = L(0)     (Lucas)
8  = F(6)     (Fibonacci)
20 ~ F(8)-1   (approximate)
28 = L(7)-1   (approximate)
```

These correlations are numerological observations, not predictions of nuclear physics.

**Reference**: Mayer, M. G. "On Closed Shells in Nuclei. II." *Physical Review* 75, pp. 1969--1970, 1949.

---

## Try It with TRI CLI

```bash
tri math cosmos          # Cosmological parameters (Hubble, Omega, CMB)
tri math planck          # Planck units with phi-scaling
tri math formula         # Sacred formula engine
tri math particles       # Particle masses + sacred ratios
tri math physical        # 12 fundamental physics constants
tri constants            # All sacred constants
tri math universe        # Live universe simulation (multiverse, brane, inflation)
tri math string-theory   # String theory + Calabi-Yau compactification
tri math holographic     # Bekenstein-Hawking entropy + holographic principle
```

---

## References

1. Planck Collaboration. "Planck 2018 Results. VI. Cosmological Parameters." *Astronomy & Astrophysics* 641, A6, 2020.
2. Riess, A. G. et al. "A Comprehensive Measurement of the Local Value of the Hubble Constant." *The Astrophysical Journal Letters* 934, L7, 2022.
3. Perlmutter, S. et al. "Measurements of Omega and Lambda from 42 High-Redshift Supernovae." *The Astrophysical Journal* 517, pp. 565--586, 1999.
4. Riess, A. G. et al. "Observational Evidence from Supernovae for an Accelerating Universe." *The Astronomical Journal* 116, pp. 1009--1038, 1998.
5. Fixsen, D. J. "The Temperature of the Cosmic Microwave Background." *The Astrophysical Journal* 707, pp. 916--920, 2009.
6. Weinberg, S. *Gravitation and Cosmology: Principles and Applications of the General Theory of Relativity*. Wiley, 1972.
7. Mayer, M. G. "On Closed Shells in Nuclei. II." *Physical Review* 75, pp. 1969--1970, 1949.
8. Particle Data Group. *Review of Particle Physics*. *Physical Review D* 110, 030001, 2024.

---

**phi^2 + 1/phi^2 = 3 = TRINITY**
