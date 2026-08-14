#!/usr/bin/env python3
"""
Independent recomputation of the spacing statistics in
trinity/data/zeta/zeta_gue_analysis_results.md and zeta_bin_analysis_update.md,
against a GUE reference column computed here rather than cited.

Normalisation: s_n = (g_{n+1} - g_n) * log(g_n / (2*pi)) / (2*pi)   (unfolding
by the local mean density; the same formula the corpus uses).

Reference: GUE Wigner surmise, F(s) = erf(2s/sqrt(pi)) - (4s/pi) e^{-4s^2/pi}.

Self-test: on synthetic samples drawn from the surmise itself (inverse-CDF of
uniforms), the pipeline must return the surmise quantiles; and on exponential
(Poisson) samples it must NOT.
"""

import math
import random
import sys

SP = math.sqrt(math.pi)


def cdf_gue(s):
    if s <= 0:
        return 0.0
    return math.erf(2.0 * s / SP) - (4.0 * s / math.pi) * math.exp(-4.0 * s * s / math.pi)


def quantile_of(F, p, hi=20.0):
    lo = 0.0
    for _ in range(200):
        m = 0.5 * (lo + hi)
        if F(m) < p:
            lo = m
        else:
            hi = m
    return 0.5 * (lo + hi)


GUE_REF = {p: quantile_of(cdf_gue, p) for p in (0.50, 0.90, 0.95, 0.99)}
GUE_STD = math.sqrt(3.0 * math.pi / 8.0 - 1.0)


def pct(sorted_vals, p):
    """Linear-interpolated percentile."""
    n = len(sorted_vals)
    if n == 0:
        return float("nan")
    k = (n - 1) * p
    f = math.floor(k)
    c = min(f + 1, n - 1)
    return sorted_vals[f] + (k - f) * (sorted_vals[c] - sorted_vals[f])


def stats(vals):
    v = sorted(vals)
    n = len(v)
    mean = sum(v) / n
    var = sum((x - mean) ** 2 for x in v) / (n - 1)
    return {
        "n": n,
        "mean": mean,
        "std": math.sqrt(var),
        "p50": pct(v, 0.50),
        "p90": pct(v, 0.90),
        "p95": pct(v, 0.95),
        "p99": pct(v, 0.99),
    }


def unfold(zeros):
    out = []
    for a, b in zip(zeros, zeros[1:]):
        out.append((b - a) * math.log(a / (2.0 * math.pi)) / (2.0 * math.pi))
    return out


def selftest():
    random.seed(11)
    # draw from the surmise by inverse CDF
    draw = [quantile_of(cdf_gue, random.random()) for _ in range(20000)]
    st = stats(draw)
    assert abs(st["p95"] - GUE_REF[0.95]) < 0.03, ("surmise p95 not recovered", st["p95"])
    assert abs(st["std"] - GUE_STD) < 0.02, ("surmise std not recovered", st["std"])
    # Poisson control must be rejected by the same pipeline
    poi = [-math.log(random.random()) for _ in range(20000)]
    assert abs(stats(poi)["p95"] - GUE_REF[0.95]) > 0.5
    print("selftest: PASS (3/3)")


def main(path):
    selftest()
    zeros = [float(x) for x in open(path).read().split()]
    s = unfold(zeros)
    print(f"\nzeros: {len(zeros)}  range {zeros[0]:.3f} .. {zeros[-1]:.1f}  spacings: {len(s)}")
    print(f"\nGUE surmise reference (computed here): "
          f"p50={GUE_REF[0.50]:.4f} p90={GUE_REF[0.90]:.4f} "
          f"p95={GUE_REF[0.95]:.4f} p99={GUE_REF[0.99]:.4f} std={GUE_STD:.4f}")

    g = stats(s)
    print("\nGLOBAL")
    print(f"  {'metric':6s} {'observed':>10s} {'GUE (correct)':>14s} {'dev':>9s}   doc says GUE is")
    doc = {"p50": "0.91", "p95": "2.15", "p99": "2.75", "std": "0.42-0.43"}
    for k, ref in (("p50", GUE_REF[0.50]), ("p95", GUE_REF[0.95]),
                   ("p99", GUE_REF[0.99]), ("std", GUE_STD)):
        dev = 100.0 * (g[k] - ref) / ref
        print(f"  {k:6s} {g[k]:10.4f} {ref:14.4f} {dev:+8.2f}%   {doc[k]}")
    print(f"  mean   {g['mean']:10.4f} {1.0:14.4f} {100*(g['mean']-1):+8.2f}%   1.0")

    print("\nTEN EQUAL-COUNT BINS (as in zeta_bin_analysis_update.md)")
    nb = 10
    per = len(s) // nb
    print(f"  {'bin':>3s} {'T_mid':>9s} {'N':>6s} {'p95':>7s} {'dev%':>7s} {'p99':>7s} {'dev%':>7s} {'std':>6s}")
    p95s = []
    for b in range(nb):
        lo = b * per
        hi = len(s) if b == nb - 1 else (b + 1) * per
        chunk = s[lo:hi]
        t_mid = 0.5 * (zeros[lo] + zeros[hi])
        st = stats(chunk)
        p95s.append(st["p95"])
        d95 = 100 * (st["p95"] - GUE_REF[0.95]) / GUE_REF[0.95]
        d99 = 100 * (st["p99"] - GUE_REF[0.99]) / GUE_REF[0.99]
        print(f"  {b+1:3d} {t_mid:9.0f} {st['n']:6d} {st['p95']:7.4f} {d95:+6.2f}% "
              f"{st['p99']:7.4f} {d99:+6.2f}% {st['std']:6.4f}")
    m = sum(p95s) / len(p95s)
    sd = math.sqrt(sum((x - m) ** 2 for x in p95s) / (len(p95s) - 1))
    print(f"\n  p95 across bins: {m:.4f} +/- {sd:.4f}   "
          f"vs GUE {GUE_REF[0.95]:.4f}  -> {100*(m-GUE_REF[0.95])/GUE_REF[0.95]:+.2f}% "
          f"(doc claims -19.8% against 2.15)")


if __name__ == "__main__":
    main(sys.argv[1])
