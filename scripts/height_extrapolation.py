#!/usr/bin/env python3
"""Where does the -5% spacing-variance deficit of the zeta zeros come from?

Established by unfolding_test.py: it is NOT an unfolding artifact -- the exact
Riemann-von Mangoldt unfolding and the leading-order one agree to 1e-5.

Established here: it is a finite-height effect.  Known corrections to the
statistics of the zeros are of order 1/L with L = ln(gamma / 2 pi) (the
Bogomolny-Keating / Berry arithmetic corrections to the pair correlation), so
the natural test is: split the zeros into bins by height, measure the
statistic per bin, and extrapolate linearly in 1/L to L -> infinity.  If the
deficit is a finite-height effect, the extrapolation lands on the exact GUE
value; if it is a property of the zeros, it does not.

At gamma ~ 7.5e4 we have L ~ 9.3, i.e. 1/L ~ 0.11, so a first-order
correction of a few percent is exactly the size to expect -- and nothing about
"Montgomery-Odlyzko holds only approximately" follows from it.

Self-tests at the bottom; run this file to execute them.
"""

import math

import numpy as np
from scipy.special import loggamma

EXACT = {"std": 0.424258, "p50": 0.962807, "p90": 1.570136,
         "p95": 1.757099, "p99": 2.120406}


def theta(t):
    t = np.asarray(t, dtype=float)
    return np.imag(loggamma(0.25 + 0.5j * t)) - 0.5 * t * math.log(math.pi)


def spacings(gamma):
    return np.diff(theta(gamma)) / math.pi


def stat(s, key):
    if key == "std":
        return float(np.std(s, ddof=1))
    return float(np.percentile(s, float(key[1:])))


def binned(gamma, nbins, key):
    """Return (1/L, value) per height bin."""
    m = len(gamma) // nbins
    out = []
    for i in range(nbins):
        g = gamma[i * m:(i + 1) * m + 1]
        s = spacings(g)
        lmean = float(np.mean(np.log(g[:-1] / (2.0 * math.pi))))
        out.append((1.0 / lmean, stat(s, key), g[0], g[-1]))
    return out


def extrapolate(points):
    """Least-squares line through (1/L, value); return (intercept, slope)."""
    x = np.array([p[0] for p in points])
    y = np.array([p[1] for p in points])
    a, b = np.polyfit(x, y, 1)  # y = a x + b
    return float(b), float(a)


def self_test(gamma) -> int:
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

    # 1. the extrapolation machinery must recover a known intercept exactly
    pts = [(0.1, 2.0 + 3.0 * 0.1), (0.05, 2.0 + 3.0 * 0.05), (0.2, 2.0 + 3.0 * 0.2)]
    b, a = extrapolate(pts)
    check("linear extrapolation is exact on a line",
          abs(b - 2.0) < 1e-10 and abs(a - 3.0) < 1e-10,
          "intercept %.10f slope %.10f" % (b, a))

    # 2. planted-wrong-answer guard: a Poisson sequence must extrapolate to
    #    std ~ 1 (Poisson), not to the GUE value.  Without this guard the
    #    procedure could be manufacturing agreement out of any input.
    #    The control has to be built in UNFOLDED space and mapped back through
    #    theta^{-1}; a first attempt that laid Poisson points down with a
    #    constant step in gamma failed this test (intercept 1.70), because the
    #    density of the zeros grows with height and the constant step inflated
    #    the variance.  The guard caught that, which is the point of it.
    rng = np.random.default_rng(20260813)
    grid = np.linspace(gamma[0], gamma[-1] * 1.05, 400000)
    th = theta(grid) / math.pi
    u = th[0] + np.cumsum(rng.exponential(size=len(gamma)))
    u = u[u <= th[-1]]
    t = np.interp(u, th, grid)          # theta^{-1}: Poisson in unfolded space
    p = binned(np.asarray(t), 10, "std")
    b, _ = extrapolate(p)
    check("Poisson control does not extrapolate to GUE",
          abs(b - 1.0) < 0.06 and abs(b - EXACT["std"]) > 0.3,
          "intercept %.4f (Poisson 1.0, GUE %.4f)" % (b, EXACT["std"]))

    # 3. the trend must actually be present, otherwise there is nothing to
    #    extrapolate and the finite-height reading is unsupported
    p = binned(gamma, 10, "std")
    _, slope = extrapolate(p)
    check("a height trend exists in the data", abs(slope) > 0.05,
          "slope d(std)/d(1/L) = %.4f" % slope)

    print("\n  self-test: %d passed, %d failed" % (ok, fail))
    return fail


def main():
    path = "/home/user/workspace/corpus/trinity/data/zeta/zeros_odlyzko_100k.txt"
    gamma = np.loadtxt(path)
    print("zeros: %d, range %.3f .. %.3f\n" % (len(gamma), gamma[0], gamma[-1]))

    print("self-test:")
    failed = self_test(gamma)

    for key in ("std", "p95", "p99", "p90", "p50"):
        pts = binned(gamma, 10, key)
        b, a = extrapolate(pts)
        e = EXACT[key]
        print("\n%s: exact GUE %.6f" % (key, e))
        print("  %-20s %8s %12s" % ("bin", "1/L", key))
        for x, v, lo, hi in pts:
            print("  %-20s %8.5f %12.6f" % ("%.0f..%.0f" % (lo, hi), x, v))
        print("  fit %s = %.6f %+.6f / L" % (key, b, a))
        print("  extrapolated L -> inf: %.6f   deviation from exact GUE %+.2f%%"
              % (b, 100.0 * (b - e) / e))
        print("  at the last bin (1/L = %.5f):        deviation %+.2f%%"
              % (pts[-1][0], 100.0 * (pts[-1][1] - e) / e))

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
