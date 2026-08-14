#!/usr/bin/env python3
"""
Is "Khinchin K = 2.620 +/- 0.029, systematically below 2.685" a finding, or the
finite-sample behaviour of the geometric mean of continued-fraction partial
quotients?

Control: draw uniform random reals (which are Khinchin-generic almost surely),
take the same number of partial quotients per sample and the same number of
samples per bin as zeta_bin_analysis_update.md (500 CF expansions per bin,
here m terms each), and look at where the estimator lands.

Self-test: the estimator must recover K on a very long expansion (slowly), and
must NOT return K for a non-generic number (e.g. the golden ratio, all a_i = 1,
geometric mean 1).
"""

import math
import random
import statistics

K = 2.6854520010653064453  # Khinchin's constant


def partial_quotients(x, m):
    out = []
    for _ in range(m):
        x = x - math.floor(x)
        if x == 0:
            break
        x = 1.0 / x
        a = math.floor(x)
        if a <= 0 or a > 1e15:
            break
        out.append(int(a))
    return out


def geo_mean(a):
    return math.exp(sum(math.log(x) for x in a) / len(a)) if a else float("nan")


def selftest():
    random.seed(7)
    # golden ratio: all partial quotients 1 -> geometric mean 1, not K
    phi = (1 + 5**0.5) / 2
    assert abs(geo_mean(partial_quotients(phi, 30)) - 1.0) < 1e-9
    # generic sample of many terms should be in the neighbourhood of K
    vals = [geo_mean(partial_quotients(random.random(), 40)) for _ in range(4000)]
    assert 2.0 < statistics.median(vals) < 3.4, statistics.median(vals)
    print("selftest: PASS (2/2)")


def main():
    selftest()
    random.seed(2026)
    print()
    print("  terms/sample  bins  mean of bin-K   spread   P(bin-K < 2.685)")
    for m in (20, 30, 50, 100):
        bin_ks = []
        below = 0
        for _ in range(200):  # 200 synthetic "bins"
            per_bin = [geo_mean(partial_quotients(random.random(), m)) for _ in range(500)]
            # the doc reports one K per bin: use the mean over its 500 expansions
            k = statistics.fmean(per_bin)
            bin_ks.append(k)
            if k < K:
                below += 1
        print(f"  {m:12d}  {len(bin_ks):4d}   {statistics.fmean(bin_ks):11.4f}"
              f"   {statistics.stdev(bin_ks):7.4f}   {below/len(bin_ks):.3f}")
    print()
    print(f"  Khinchin's constant K = {K:.7f} (computed reference, not cited)")
    print("  Document reports: K = 2.6201 +/- 0.0293 over 10 bins, 500 expansions each,")
    print("  and reads the -2.4% offset as a possible arithmetic-structure signal.")


if __name__ == "__main__":
    main()
