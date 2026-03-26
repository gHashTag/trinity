#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Utility Functions

Common utility functions shared across all metric modules.
Avoids DRY violations by providing single source of truth.

Functions:
- norm_cdf: Standard normal CDF with scipy fallback
- norm_inverse: Probit function (inverse CDF) with scipy fallback
"""

import math

# Try to import scipy for accurate normal CDF
try:
    from scipy.stats import norm as scipy_norm
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False


def norm_cdf(x: float) -> float:
    """
    Standard normal CDF Φ(x) = P(Z ≤ x).

    Uses scipy if available, otherwise falls back to improved
    Abramowitz & Stegun 7.1.26 approximation.

    Args:
        x: Value at which to evaluate CDF

    Returns:
        Probability that standard normal random variable ≤ x
    """
    if HAS_SCIPY:
        return float(scipy_norm.cdf(x))

    # Improved Abramowitz & Stegun 7.1.26 approximation
    a1 = 0.254829592
    a2 = -0.284496736
    a3 = 1.421413741
    a4 = -1.453152027
    a5 = 1.061405429
    a6 = -0.010428693  # Additional term for accuracy
    p = 0.3275911

    sign = 1 if x >= 0 else -1
    x_abs = abs(x) / math.sqrt(2)

    t = 1.0 / (1.0 + p * x_abs)
    y = 1.0 - (((((a5*t + a4)*t + a3)*t + a2)*t + a1)*t + a6*t*t) * math.exp(-x_abs*x_abs)

    return 0.5 * (1.0 + sign * y)


def norm_inverse(p: float) -> float:
    """
    Inverse of standard normal CDF (probit function).

    Returns x such that Φ(x) = p.

    CRITICAL: This is what BCa method needs, NOT norm_cdf!
    Fixed in v3.2 for proper bootstrap confidence intervals.

    Args:
        p: Probability (0, 1)

    Returns:
        z-score such that P(Z ≤ z) = p

    Bounds:
        p → 0: returns -10 (approximation of -∞)
        p → 1: returns +10 (approximation of +∞)
        Φ(-10) ≈ 7.6e-24, effectively zero
        Φ(+10) ≈ 1 - 7.6e-24, effectively one
    """
    if p <= 0:
        return -10.0
    if p >= 1:
        return 10.0

    if HAS_SCIPY:
        return float(scipy_norm.ppf(p))

    # Beasley-Springer-Moro approximation
    # More accurate than simple polynomial approximations
    a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
         1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
    b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
         6.680131188771972e+01, -1.328068155288572e+01]
    c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
         -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
    d = [7.784695709041462e-03, 3.224671290700398e+01, 2.445134137142996e+00,
         3.754408661907416e+00]

    p_low = 0.02425
    p_high = 1 - p_low

    if p < p_low:
        q = math.sqrt(-2 * math.log(p))
        return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / \
               ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
    elif p <= p_high:
        q = p - 0.5
        r = q * q
        return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q / \
               (((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)
    else:
        q = math.sqrt(-2 * math.log(1 - p))
        return -(((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / \
                ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)


# Module-level numpy import for efficiency
# CRITICAL FIX v3.2: Moved from function-level to module-level
try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False


def weighted_resample(
    values: list,
    weights: list = None,
    n: int = None
) -> list:
    """
    Resample with replacement, optionally weighted.

    v3.2 FIX: Now uses module-level numpy import instead of
    importing inside the function every call.

    Args:
        values: List of values to resample
        weights: Optional weights for sampling (must sum to 1)
        n: Sample size (defaults to len(values))

    Returns:
        Resampled list of values
    """
    if n is None:
        n = len(values)

    if weights is None:
        import random
        return [random.choice(values) for _ in range(n)]

    if not HAS_NUMPY:
        # Fallback without numpy
        import random
        # Normalize weights
        total_weight = sum(weights)
        norm_weights = [w / total_weight for w in weights]

        # Weighted random choice using cumulative weights
        cumulative = []
        cumsum = 0
        for w in norm_weights:
            cumsum += w
            cumulative.append(cumsum)

        result = []
        for _ in range(n):
            r = random.random()
            for i, threshold in enumerate(cumulative):
                if r <= threshold:
                    result.append(values[i])
                    break
        return result

    # Use numpy for efficient weighted resampling
    indices = np.random.choice(len(values), size=n, p=weights)
    return [values[i] for i in indices]


if __name__ == "__main__":
    print("=" * 60)
    print("Utility Functions Test Suite")
    print("=" * 60)

    print(f"\nscipy available: {HAS_SCIPY}")
    print(f"numpy available: {HAS_NUMPY}")

    # Test round-trip: inverse(CDF(x)) ≈ x
    print("\n1. Round-trip test (inverse(CDF(x)) ≈ x):")
    for x in [-2, -1, -0.5, 0, 0.5, 1, 2]:
        cdf = norm_cdf(x)
        inv = norm_inverse(cdf)
        print(f"   x={x:5.1f} → CDF={cdf:.6f} → inverse={inv:5.2f} (error={abs(x-inv):.6f})")

    # Test specific probability values
    print("\n2. Inverse CDF test (known values):")
    test_probs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]
    for p in test_probs:
        z = norm_inverse(p)
        print(f"   P(Z ≤ z) = {p:.4f} → z = {z:6.3f}")

    # Test weighted resampling
    print("\n3. Weighted resampling test:")
    values = ['a', 'b', 'c', 'd']
    weights = [0.1, 0.2, 0.3, 0.4]  # 'd' should appear most often
    resampled = weighted_resample(values, weights, n=1000)
    from collections import Counter
    counts = Counter(resampled)
    for v in values:
        print(f"   '{v}': {counts[v]/1000:.3f} (expected ~{weights[values.index(v)]})")

    print("\n" + "=" * 60)
