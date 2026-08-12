#!/usr/bin/env python3
"""
Computable reference column for the GUE Wigner surmise, unit mean spacing.

    p(s) = (32/pi^2) s^2 exp(-4 s^2/pi)
    F(s) = erf(2 s/sqrt(pi)) - (4 s/pi) exp(-4 s^2/pi)      [exact]

Everything printed below is regenerated here, not cited. Also prints the
buggy s^3 variant (F = 1 - e^{-x}(1+x), x = 4s^2/pi) found in
trinity/src/sacred/zeta_spacing.zig:225, and the GOE surmise, so a reader can
see which wrong reference reproduces which wrong number.

Self-tests: closed form vs quadrature, normalisation, mean = 1, analytic
moments (mean 1, var 3*pi/8 - 1) vs numeric.
"""

import math

SP = math.sqrt(math.pi)


def pdf_gue(s):
    return 0.0 if s <= 0 else (32.0 / math.pi**2) * s * s * math.exp(-4.0 * s * s / math.pi)


def cdf_gue(s):
    if s <= 0:
        return 0.0
    return math.erf(2.0 * s / SP) - (4.0 * s / math.pi) * math.exp(-4.0 * s * s / math.pi)


def cdf_gue_s3_bug(s):
    """The s^3 variant: its density is (32/pi^2) s^3 exp(-4s^2/pi) -- not a GUE pdf."""
    x = 4.0 * s * s / math.pi
    return 1.0 - math.exp(-x) * (1.0 + x)


def cdf_goe(s):
    return 1.0 - math.exp(-math.pi * s * s / 4.0)


def simpson(f, a, b, n=200_000):
    n += n % 2
    h = (b - a) / n
    t = f(a) + f(b)
    for i in range(1, n):
        t += (4.0 if i % 2 else 2.0) * f(a + i * h)
    return t * h / 3.0


def quantile(F, p, hi=20.0):
    lo = 0.0
    for _ in range(200):
        m = 0.5 * (lo + hi)
        if F(m) < p:
            lo = m
        else:
            hi = m
    return 0.5 * (lo + hi)


def selftest():
    h = 1e-6
    for s in (0.1, 0.5, 1.0, 1.7518, 3.0):
        d = (cdf_gue(s + h) - cdf_gue(s - h)) / (2 * h)
        assert abs(d - pdf_gue(s)) < 1e-7, ("dF/ds != pdf", s)
    for s in (0.25, 1.0, 2.0, 4.0):
        assert abs(simpson(pdf_gue, 0, s, 20_000) - cdf_gue(s)) < 1e-9, ("quad", s)
    assert abs(cdf_gue(12.0) - 1.0) < 1e-12
    m1 = simpson(lambda s: s * pdf_gue(s), 0, 12, 40_000)
    m2 = simpson(lambda s: s * s * pdf_gue(s), 0, 12, 40_000)
    assert abs(m1 - 1.0) < 1e-9, ("mean", m1)
    var_analytic = 3.0 * math.pi / 8.0 - 1.0
    assert abs((m2 - m1 * m1) - var_analytic) < 1e-8, ("var", m2 - m1 * m1)
    # the s^3 bug must be distinguishable from the truth
    assert abs(quantile(cdf_gue_s3_bug, 0.95) - quantile(cdf_gue, 0.95)) > 0.1
    # GUE vs GOE cross near s=1: never guard there
    assert abs(cdf_goe(1.0) - cdf_gue(1.0)) < 0.02
    assert cdf_goe(0.3) / cdf_gue(0.3) > 2.0
    print("selftest: PASS (7/7)")


if __name__ == "__main__":
    selftest()
    var = 3.0 * math.pi / 8.0 - 1.0
    print()
    print(f"mean      = 1 (exact, by normalisation)")
    print(f"std       = sqrt(3*pi/8 - 1) = {math.sqrt(var):.6f}")
    print()
    print("quantile |   GUE (correct) |  s^3 bug |  GOE surmise")
    for p in (0.50, 0.90, 0.95, 0.99):
        print(
            f"  p{int(p*100):02d}    |    {quantile(cdf_gue, p):.6f}     | {quantile(cdf_gue_s3_bug, p):.4f}   |  {quantile(cdf_goe, p):.4f}"
        )
