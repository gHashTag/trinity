# Trinity γ-Paper: Barbero-Immirzi from the Golden Section

**Status:** Draft v0.1 · Pre-registration checkpoint · April 2026

## Overview

This directory contains the second Trinity/Pellis research paper, addressing the conflict between:

- **Trinity:** γ = φ⁻³ = √5 − 2 ≈ 0.23607 (Conjecture GI1)
- **LQG standard (Meissner 2004):** γ₁ = ln 2 / (π√3) ≈ 0.23753
- **LQG alternative (Ghosh-Mitra):** γ₂ ≈ 0.274

**Key finding:** Gap between γ_φ and γ₁ is only **0.63%** — 22× smaller than the internal LQG dispute (13.9%).

## Files

| File | Description |
|------|-------------|
| `GAMMA_PAPER_DRAFT_v0.1.md` | Main paper draft (IMRaD structure) |
| `PREREGISTRATION.md` | Pre-registered hypotheses H-A, H-B, H-C |

## Related Files

| File | Location |
|------|----------|
| Formal spec (GI1) | `specs/physics/gamma_conjecture.t27` |
| Verification script | `scripts/compare_gamma_candidates.py` |
| Formula catalogue | `docs/docs/research/formulas-catalog-2026.md` |
| Pellis paper | `research/trinity-pellis-paper/` |

## Quick Start

```bash
# Run verification (requires Python + mpmath)
python3 scripts/compare_gamma_candidates.py

# Verify spec parses
tri spec verify specs/physics/gamma_conjecture.t27
```

## Falsification Protocol

See `PREREGISTRATION.md` for three pre-registered hypotheses:
- **H-A:** γ_true = φ⁻³ (Trinity correct, LQG entropy counting needs revision)
- **H-B:** γ_true = γ₁ (LQG correct, Trinity needs additional parameter)
- **H-C:** γ is a running constant (φ⁻³ is IR limit, γ₁ is UV fixed point)

## Connection to Pellis Paper

This paper is the second in the Trinity series. The first paper (`research/trinity-pellis-paper/`) establishes the φ-framework and the α⁻¹ Pellis formula. This paper extends the framework to quantum gravity via the Barbero-Immirzi parameter.
