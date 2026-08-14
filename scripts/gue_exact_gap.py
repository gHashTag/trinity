#!/usr/bin/env python3
"""Exact GUE bulk nearest-neighbour spacing law, computed — not cited.

The Wigner surmise p(s) = (32/pi^2) s^2 exp(-4 s^2/pi) is a two-by-two
approximation.  Deviations of a couple of percent cannot be attributed to
the data while the reference itself is off by a comparable amount, so the
reference has to be the real thing:

    E_2(s) = det(I - K_s),   K(x,y) = sin(pi (x-y)) / (pi (x-y))  on [0, s]

    p(s) = d^2 E_2(s) / d s^2

E_2(s) is the probability that an interval of length s (in units of the mean
spacing) contains no eigenvalue.  The determinant is evaluated by the Nystrom
method on Gauss-Legendre nodes, which converges spectrally because the sine
kernel is analytic: det(I - K_s) = prod_i (1 - lambda_i) with
lambda_i the eigenvalues of sqrt(w_i) K(x_i, x_j) sqrt(w_j).

Self-tests at the bottom; run this file to execute them.
"""

import math

import numpy as np
from numpy.polynomial.legendre import leggauss


def e2_no_eigenvalue(s: float, n: int = 100) -> float:
    """Probability that a bulk interval of length s contains no eigenvalue."""
    if s <= 0.0:
        return 1.0
    x, w = leggauss(n)
    # map [-1, 1] -> [0, s]
    x = 0.5 * s * (x + 1.0)
    w = 0.5 * s * w
    dx = x[:, None] - x[None, :]
    with np.errstate(divide="ignore", invalid="ignore"):
        k = np.sin(math.pi * dx) / (math.pi * dx)
    np.fill_diagonal(k, 1.0)
    sw = np.sqrt(w)
    m = sw[:, None] * k * sw[None, :]
    lam = np.linalg.eigvalsh(m)
    lam = np.clip(lam, None, 1.0 - 1e-15)
    return float(np.exp(np.sum(np.log1p(-lam))))


def gap_pdf_grid(s_max: float = 6.0, h: float = 2.0e-3, n: int = 100):
    """Return (s, p(s)) on a uniform grid via p = d^2 E_2 / d s^2."""
    m = int(round(s_max / h))
    s = np.arange(0, m + 1) * h
    e = np.array([e2_no_eigenvalue(float(v), n) for v in s])
    # second difference on the interior; the density is smooth and E_2 is
    # computed to ~1e-13, so h = 2e-3 leaves the truncation error dominant
    # at ~1e-6 -- well below the 2% effects under discussion.
    p = (e[2:] - 2.0 * e[1:-1] + e[:-2]) / (h * h)
    return s[1:-1], p


class GapLaw:
    """Normalised exact gap law with quantiles."""

    def __init__(self, s_max: float = 6.0, h: float = 2.0e-3, n: int = 100):
        s, p = gap_pdf_grid(s_max, h, n)
        p = np.clip(p, 0.0, None)
        norm = np.trapezoid(p, s)
        self.s = s
        self.p = p / norm
        self.cdf = np.concatenate([[0.0], np.cumsum(0.5 * (self.p[1:] + self.p[:-1]) * np.diff(s))])
        self.cdf /= self.cdf[-1]

    def mean(self) -> float:
        return float(np.trapezoid(self.s * self.p, self.s))

    def std(self) -> float:
        m = self.mean()
        return float(math.sqrt(np.trapezoid((self.s - m) ** 2 * self.p, self.s)))

    def quantile(self, q: float) -> float:
        return float(np.interp(q, self.cdf, self.s))


# --- the surmise, for side-by-side comparison -------------------------------

def surmise_pdf(s):
    return (32.0 / math.pi ** 2) * s ** 2 * np.exp(-4.0 * s ** 2 / math.pi)


def surmise_cdf(s):
    return math.erf(2.0 * s / math.sqrt(math.pi)) - (4.0 * s / math.pi) * math.exp(
        -4.0 * s ** 2 / math.pi
    )


def surmise_quantile(q: float) -> float:
    lo, hi = 0.0, 10.0
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if surmise_cdf(mid) < q:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


SURMISE_STD = math.sqrt(3.0 * math.pi / 8.0 - 1.0)


def self_test() -> int:
    ok = 0
    fail = 0

    def check(name, cond, detail=""):
        nonlocal ok, fail
        if cond:
            ok += 1
            print("  ok   %s %s" % (name, detail))
        else:
            fail += 1
            print("  FAIL %s %s" % (name, detail))

    # 1. E_2(0) = 1 and E_2 decays
    check("E2(0) = 1", abs(e2_no_eigenvalue(0.0) - 1.0) < 1e-12)
    check("E2 monotone decreasing",
          e2_no_eigenvalue(0.5) > e2_no_eigenvalue(1.0) > e2_no_eigenvalue(2.0))

    # 2. small-s expansion: E_2(s) = 1 - s + (pi^2/6) s^3/... ; the density
    #    must vanish as s^2 with the known coefficient pi^2/3 (level repulsion
    #    exponent beta = 2).  This is the guard that distinguishes GUE from
    #    GOE (p ~ s) and from Poisson (p -> 1).
    law = GapLaw()
    i = np.searchsorted(law.s, 0.05)
    c = law.p[i] / law.s[i] ** 2
    check("level repulsion p(s) ~ (pi^2/3) s^2", abs(c - math.pi ** 2 / 3.0) < 0.02,
          "coefficient %.5f vs %.5f" % (c, math.pi ** 2 / 3.0))

    # 3. normalisation and unit mean are not imposed on the mean, only on the
    #    integral -- so mean = 1 is a real test of the construction.
    check("unit mean", abs(law.mean() - 1.0) < 2e-3, "mean %.6f" % law.mean())

    # 4. planted-wrong-answer guard: the surmise must NOT reproduce the exact
    #    law to better than 1e-3 in std, otherwise this whole script is
    #    measuring nothing and could be replaced by the surmise.
    check("exact law differs from the surmise",
          abs(law.std() - SURMISE_STD) > 1e-3,
          "exact %.6f vs surmise %.6f" % (law.std(), SURMISE_STD))

    # 5. quadrature convergence: n = 60 and n = 140 must agree far better than
    #    the effects under discussion.
    a = e2_no_eigenvalue(1.7, 60)
    b = e2_no_eigenvalue(1.7, 140)
    check("Nystrom converged", abs(a - b) < 1e-10, "|dE2| = %.2e" % abs(a - b))

    print("\n  self-test: %d passed, %d failed" % (ok, fail))
    return fail


if __name__ == "__main__":
    print("self-test:")
    failed = self_test()

    law = GapLaw()
    print("\nexact GUE bulk gap law vs Wigner surmise")
    print("  %-6s %12s %12s %8s" % ("q", "exact", "surmise", "diff %"))
    for q in (0.5, 0.9, 0.95, 0.99):
        e = law.quantile(q)
        s = surmise_quantile(q)
        print("  p%-5d %12.6f %12.6f %+8.2f" % (round(q * 100), e, s, 100.0 * (s - e) / e))
    print("  %-6s %12.6f %12.6f %+8.2f" % ("std", law.std(), SURMISE_STD,
                                           100.0 * (SURMISE_STD - law.std()) / law.std()))
    print("  %-6s %12.6f %12.6f" % ("mean", law.mean(), 1.0))
    raise SystemExit(1 if failed else 0)
