#!/usr/bin/env python3
"""
compare_gamma_candidates.py
===========================
Verification script for Trinity Conjecture GI1: gamma = phi^{-3} = sqrt(5) - 2

Compares three gamma candidates:
  gamma_phi = phi^{-3} = sqrt(5) - 2  (Trinity conjecture GI1)
  gamma_1   = ln(2) / (pi * sqrt(3))   (Meissner 2004, LQG standard)
  gamma_2   = 0.27398563527...          (Ghosh-Mitra, LQG alternative)

For each affected formula {G1, BH1, SC3, SC4}, computes:
  - Trinity prediction with gamma_phi
  - Trinity prediction with gamma_1
  - Deviation from CODATA 2022 / experimental reference

Status: SEALED before first run — see PREREGISTRATION.md

Requires: Python 3.8+ with mpmath (pip install mpmath)
"""

try:
    from mpmath import mp, mpf, sqrt, log, pi, exp, cos, acos
    HAS_MPMATH = True
except ImportError:
    from decimal import Decimal, getcontext
    HAS_MPMATH = False
    print("WARNING: mpmath not found, falling back to stdlib Decimal (50 digits)")

import sys

# ─── Precision ───────────────────────────────────────────────────────────────

if HAS_MPMATH:
    mp.dps = 60  # 60 decimal places

    # Fundamental constants
    PHI = (1 + sqrt(5)) / 2
    E = mp.e
    PI = pi

    # Gamma candidates
    GAMMA_PHI = PHI**(-3)          # Trinity GI1: sqrt(5) - 2
    GAMMA_1   = log(2) / (PI * sqrt(3))   # Meissner 2004
    GAMMA_2   = mpf('0.27398563527')       # Ghosh-Mitra

    # CODATA 2022 references
    G_CODATA   = mpf('6.67430e-11')   # m^3 kg^-1 s^-2
    HBAR       = mpf('1.054571817e-34')
    C          = mpf('2.99792458e8')
    M_P        = mpf('2.176434e-8')   # Planck mass in kg

else:
    getcontext().prec = 60
    D = Decimal
    PHI = (1 + D(5).sqrt()) / 2
    GAMMA_PHI = D(5).sqrt() - 2
    GAMMA_1   = D(2).ln() / (D(str('3.14159265358979323846')) * D(3).sqrt())
    GAMMA_2   = D('0.27398563527')
    G_CODATA  = D('6.67430e-11')

# ─── Helper ──────────────────────────────────────────────────────────────────

def pct_dev(predicted, reference):
    """Percentage deviation: (predicted - reference) / reference * 100"""
    return float((predicted - reference) / reference * 100)

def fmt(x, digits=10):
    if HAS_MPMATH:
        return mp.nstr(x, digits)
    return str(round(x, digits))

# ─── Core computation ────────────────────────────────────────────────────────

def compute_G1(gamma):
    """G1: G = pi^3 * gamma^2 / phi"""
    return PI**3 * gamma**2 / PHI

def compute_BH_ratio(gamma):
    """BH1: Correction factor gamma_1 / gamma (relative to LQG baseline)"""
    return GAMMA_1 / gamma

# ─── Results table ───────────────────────────────────────────────────────────

def print_separator(width=78):
    print("─" * width)

def print_header():
    print()
    print_separator()
    print("  TRINITY γ-CONJECTURE VERIFICATION  (compare_gamma_candidates.py)")
    print_separator()
    print()

def print_gamma_comparison():
    print("  γ CANDIDATES")
    print_separator()
    print(f"  γ_φ = φ⁻³ = √5−2  = {fmt(GAMMA_PHI, 20)}  [Trinity GI1]")
    print(f"  γ₁  = ln2/(π√3)   = {fmt(GAMMA_1,   20)}  [Meissner 2004]")
    print(f"  γ₂  = 0.273...    = {fmt(GAMMA_2,   20)}  [Ghosh-Mitra]")
    print()

    gap_phi_1 = pct_dev(GAMMA_PHI, GAMMA_1)
    gap_2_1   = pct_dev(GAMMA_2,   GAMMA_1)
    ratio     = abs(gap_2_1 / gap_phi_1)

    print(f"  Δ(γ_φ − γ₁) / γ₁ = {gap_phi_1:+.4f}%")
    print(f"  Δ(γ₂  − γ₁) / γ₁ = {gap_2_1:+.4f}%")
    print(f"  Ratio (LQG internal / Trinity-LQG) = {ratio:.1f}×")
    print()

def print_G1_table():
    print("  FORMULA G1: Newton's G = π³γ²/φ")
    print_separator()
    print(f"  CODATA 2022:       G = {float(G_CODATA):.6e} m³ kg⁻¹ s⁻²")

    G_phi = compute_G1(GAMMA_PHI)
    G_1   = compute_G1(GAMMA_1)
    G_2   = compute_G1(GAMMA_2)

    dev_phi = pct_dev(G_phi, G_CODATA)
    dev_1   = pct_dev(G_1,   G_CODATA)
    dev_2   = pct_dev(G_2,   G_CODATA)

    print(f"  Trinity (γ_φ):     G = {float(G_phi):.6e}   Δ = {dev_phi:+.4f}%")
    print(f"  Trinity (γ₁):      G = {float(G_1):.6e}   Δ = {dev_1:+.4f}%")
    print(f"  Trinity (γ₂):      G = {float(G_2):.6e}   Δ = {dev_2:+.4f}%")

    winner_phi_vs_1 = "γ_φ" if abs(dev_phi) < abs(dev_1) else "γ₁"
    print(f"  Winner (φ vs γ₁):  {winner_phi_vs_1}")
    print()
    return {"phi": dev_phi, "gamma1": dev_1, "gamma2": dev_2}

def print_BH_table():
    print("  FORMULA BH1: Entropy correction factor = γ₁/γ")
    print_separator()
    print(f"  LQG baseline:      ratio = 1.000000 (γ = γ₁)")

    r_phi = float(compute_BH_ratio(GAMMA_PHI))
    r_2   = float(GAMMA_1 / GAMMA_2)

    print(f"  Trinity (γ_φ):     ratio = {r_phi:.8f}   (S larger by {(r_phi-1)*100:.4f}%)")
    print(f"  Trinity (γ₂):      ratio = {r_2:.8f}   (S smaller by {(1-r_2)*100:.4f}%)")
    print()

def print_algebraic_check():
    print("  ALGEBRAIC IDENTITY CHECK: φ⁻³ = √5 − 2")
    print_separator()
    if HAS_MPMATH:
        sqrt5_minus_2 = sqrt(5) - 2
        phi_inv_cube  = PHI**(-3)
        diff = abs(sqrt5_minus_2 - phi_inv_cube)
        print(f"  √5 − 2     = {fmt(sqrt5_minus_2, 30)}")
        print(f"  φ⁻³        = {fmt(phi_inv_cube,  30)}")
        print(f"  Difference = {float(diff):.2e}  (should be < 1e-55)")
        print(f"  Identity:  {'✓ EXACT' if diff < mpf('1e-55') else '✗ MISMATCH'}")
    else:
        from decimal import Decimal as D
        diff = abs((D(5).sqrt() - 2) - GAMMA_PHI)
        print(f"  √5 − 2 = φ⁻³  Difference = {diff:.2e}")
    print()

def print_summary(G1_devs):
    print("  SUMMARY")
    print_separator()
    print("  Formula │ γ_φ deviation │ γ₁ deviation │ Winner")
    print("  ────────┼──────────────┼──────────────┼───────")
    winner = "γ_φ" if abs(G1_devs["phi"]) < abs(G1_devs["gamma1"]) else "γ₁"
    print(f"  G1      │ {G1_devs['phi']:>+10.4f}%  │ {G1_devs['gamma1']:>+10.4f}%  │ {winner}")
    print()
    print("  NOTE: SC3, SC4 formulas require full Trinity formula catalogue.")
    print("        Run `tri math compare --gamma-conflict` for complete output.")
    print()
    print("  Pre-registration: research/trinity-gamma-paper/PREREGISTRATION.md")
    print("  Spec:             specs/physics/gamma_conjecture.t27")
    print_separator()
    print()

# ─── Main ────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print_header()
    print_gamma_comparison()
    print_algebraic_check()
    G1_devs = print_G1_table()
    print_BH_table()
    print_summary(G1_devs)
