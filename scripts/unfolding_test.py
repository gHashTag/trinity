#!/usr/bin/env python3
"""Is the spacing-variance deficit of the zeta zeros real, or an unfolding artifact?

The corpus unfolds the zeros with the leading term of the density only,

    s_i = (gamma_{i+1} - gamma_i) * ln(gamma_i / 2 pi) / (2 pi),

which is the derivative of the leading term of the counting function.  The
exact mean counting function of the nontrivial zeros is Riemann-von Mangoldt,

    N(t) = theta(t)/pi + 1 + (small oscillation),
    theta(t) = arg Gamma(1/4 + i t / 2) - (t/2) ln pi,

so the unfolding with no truncation error at all is simply

    s_i = (theta(gamma_{i+1}) - theta(gamma_i)) / pi.

If the reported deficit in the spacing variance (-5%) is a property of the
zeros, both unfoldings must show it.  If it is an artifact of dropping the
higher-order terms of the density, only the truncated one shows it.

Self-tests at the bottom; run this file to execute them.
"""

import math

import numpy as np
from scipy.special import loggamma


def theta(t):
    """Riemann-Siegel theta, computed from log Gamma (no series truncation)."""
    t = np.asarray(t, dtype=float)
    return np.imag(loggamma(0.25 + 0.5j * t)) - 0.5 * t * math.log(math.pi)


def spacings_theta(gamma):
    """Exact unfolding: increments of the mean counting function."""
    return np.diff(theta(gamma)) / math.pi


def spacings_leading(gamma):
    """The corpus unfolding: leading-order local density."""
    return np.diff(gamma) * np.log(gamma[:-1] / (2.0 * math.pi)) / (2.0 * math.pi)


def stats(s):
    return {
        "n": len(s),
        "mean": float(np.mean(s)),
        "std": float(np.std(s, ddof=1)),
        "p50": float(np.percentile(s, 50)),
        "p90": float(np.percentile(s, 90)),
        "p95": float(np.percentile(s, 95)),
        "p99": float(np.percentile(s, 99)),
    }


# Exact GUE bulk gap law, from gue_exact_gap.py (recomputed there, not cited).
EXACT = {"mean": 1.0, "std": 0.424258, "p50": 0.962807, "p90": 1.570136,
         "p95": 1.757099, "p99": 2.120406}


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

    # 1. theta must reproduce the known zero count: N(t) = theta(t)/pi + 1.
    #    At the 100000th zero the count is 100000, so theta/pi + 1 must land
    #    within one unit (the remaining S(t) oscillation is O(log t)/pi ~ 1).
    n_est = theta(gamma[-1]) / math.pi + 1.0
    check("counting function recovers the index",
          abs(n_est - len(gamma)) < 1.5,
          "N_est %.3f vs index %d" % (n_est, len(gamma)))

    # 2. both unfoldings must give unit mean spacing (that is what unfolding is)
    st = spacings_theta(gamma)
    sl = spacings_leading(gamma)
    check("theta unfolding has unit mean", abs(np.mean(st) - 1.0) < 1e-3,
          "mean %.6f" % np.mean(st))
    check("leading unfolding has unit mean", abs(np.mean(sl) - 1.0) < 5e-3,
          "mean %.6f" % np.mean(sl))

    # 3. planted-wrong-answer guard: a Poisson sequence pushed through the same
    #    pipeline must NOT come out looking like GUE.  Without this the whole
    #    script could be reporting agreement it manufactured itself.
    rng = np.random.default_rng(20260813)
    t = gamma[0] + np.cumsum(rng.exponential(size=len(gamma)) * 2.0 * math.pi
                             / math.log(gamma[len(gamma) // 2] / (2.0 * math.pi)))
    sp = spacings_theta(np.asarray(t))
    sp = sp / np.mean(sp)
    check("Poisson control is rejected", abs(np.std(sp, ddof=1) - 1.0) < 0.05,
          "std %.4f (Poisson = 1, GUE = %.4f)" % (np.std(sp, ddof=1), EXACT["std"]))

    # 4. the two unfoldings must not be identical, or the comparison is empty
    check("the two unfoldings differ",
          abs(np.std(st, ddof=1) - np.std(sl, ddof=1)) > 1e-4,
          "|dstd| = %.5f" % abs(np.std(st, ddof=1) - np.std(sl, ddof=1)))

    print("\n  self-test: %d passed, %d failed" % (ok, fail))
    return fail


def main():
    path = "/home/user/workspace/corpus/trinity/data/zeta/zeros_odlyzko_100k.txt"
    gamma = np.loadtxt(path)
    print("zeros: %d, range %.3f .. %.3f\n" % (len(gamma), gamma[0], gamma[-1]))

    print("self-test:")
    failed = self_test(gamma)

    st = stats(spacings_theta(gamma))
    sl = stats(spacings_leading(gamma))

    print("\nobserved spacings vs the exact GUE gap law")
    print("  %-5s %12s %12s %12s %10s %10s"
          % ("", "exact GUE", "theta unfold", "leading unf", "dev theta", "dev lead"))
    for k in ("mean", "std", "p50", "p90", "p95", "p99"):
        e = EXACT[k]
        print("  %-5s %12.6f %12.6f %12.6f %9.2f%% %9.2f%%"
              % (k, e, st[k], sl[k],
                 100.0 * (st[k] - e) / e, 100.0 * (sl[k] - e) / e))

    # split by height: if the deficit is an unfolding artifact it must shrink
    # with height under the truncated unfolding and stay flat under theta.
    print("\nby height (10 equal-count bins, std of spacings)")
    print("  %-22s %12s %12s" % ("bin (gamma range)", "theta", "leading"))
    m = len(gamma) // 10
    for i in range(10):
        g = gamma[i * m:(i + 1) * m + 1]
        a = float(np.std(spacings_theta(g), ddof=1))
        b = float(np.std(spacings_leading(g), ddof=1))
        print("  %-22s %12.6f %12.6f" % ("%.0f..%.0f" % (g[0], g[-1]), a, b))

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
