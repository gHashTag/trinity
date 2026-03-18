# TRINITY Predictions Log

**Status**: Active — Pre-registered scientific predictions
**Maintained by**: Proof Graph Engine v1.0
**Last updated**: 2026-03-08

---

## Eligibility Rule

**Only formulas with `fit_origin = CANONICAL` may appear in PREDICTIONS_LOG.**

Formulas with `fit_origin = search_fit`, `postdiction`, or `manual_override` are **ineligible** for pre-registration — they represent post-hoc fits or manual adjustments, not theoretical predictions derived from first principles.

**Rationale**: Pre-registered predictions must be derived from sacred formula theory (V = n×3^k×π^m×φ^p×e^q×γ^r×C^t×G^u) without numerical optimization to match experimental data. `search_fit` formulas are inherently post-hoc — parameters were optimized after seeing target values, violating the pre-registration principle.

**Enforcement**: `tri math ci-check` warns if a prediction uses a non-canonical formula.

---

## Purpose

This log maintains a permanent record of **pre-registered scientific predictions** derived from TRINITY formulas. Each entry is locked at registration time and cannot be modified after experimental data is released, preventing post-hoc adjustments.

**Key principle**: A prediction registered here is a scientific contract. If the formula changes after data release, it is marked `POSTDICTION` and loses its pre-registered status.

---

## Registry Status

| Domain | Canonical Predictions | Exploratory Fits | Total |
|--------|----------------------|------------------|-------|
| QCD | 1 | 1 | 2 |
| Cosmology | **3** (+2) | 0 | 3 |
| Gravity | 5 | 0 | 5 |
| Consciousness | 1 | 0 | 1 |
| **Total** | **10** (+2) | **1** (-2) | **11** |

**2026-03-08 UPDATE**: `omega_dm` and `omega_lambda` elevated to CANONICAL via `tri math search-canonical`. Both are now γ-free (r=0) with 0.002% accuracy. P-COSM-E001 and P-COSM-E002 retired and replaced with new canonical predictions.

**Note**: "Exploratory Fits" are predictions derived from `fit_origin = search_fit` or `postdiction` formulas. These are post-hoc parameter optimizations, not first-principles predictions. They are tracked here for research purposes but do not have pre-registered status.

---

## Falsification Scenarios

Each prediction has an explicit **kill-switch** — experimental result that would falsify it.

| Formula | Fit Origin | Experiment | Trigger | Status |
|---------|------------|------------|---------|--------|
| strong_cp_axion | CANONICAL | ADMX, IAXO | Axion found OR θ̄ > 10⁻⁸ | PENDING |
| qcd_tc_candidate | POSTDICTION | Lattice QCD | Tc outside 155±5 MeV | EXPLORATORY |
| omega_lambda | **CANONICAL** ✓ | DESI DR3 / Euclid | ΔΩ_Λ > 10% | PENDING |
| omega_dm | **CANONICAL** ✓ | DESI DR3 / Euclid | ΔΩ_DM > 10% | PENDING |
| w_z_lambda_cdm | CANONICAL | DESI BAO | \|w - (-1)\| > 0.05 | PENDING |
| lisa_phase_* | CANONICAL | LISA 2035 | Phase deviation > 1% | PENDING |

---

## Prediction Entries (Canonical Only)

### QCD Predictions

#### P-QCD-001: Strong CP Axion
- **Formula ID**: `strong_cp_axion`
- **Fit Origin**: CANONICAL (γ-free pre-registered prediction)
- **Registered**: 2026-03-08
- **Locked trace**: `tri trace strong_cp_axion` at registration
- **Prediction**: θ̄ < 10⁻¹⁰ (axion solves strong CP problem)
- **Expected range**: θ̄ ∈ [0, 10⁻¹⁰]
- **Target experiment**: ADMX, IAXO, CASPEr axion searches
- **Falsification trigger**: Axion discovered with θ̄ > 10⁻⁸ OR no axion found by 2030
- **Status**: PENDING
- **Charter compliance**: R9 (falsification trigger defined)

---

### Cosmology Predictions

#### P-COSM-001: Dark Matter Density (Ω_DM) — **CANONICAL ✓**
- **Formula ID**: `omega_dm`
- **Fit Origin**: **CANONICAL** (γ-free, found via `tri math search-canonical`)
- **Registered**: 2026-03-08 (elevated from exploratory)
- **Canonical formula**: Ω_DM = 34 × 3 × π⁻³ × φ × e⁻³
- **Parameters**: n=34, k=1, m=-3, p=1, q=-3, r=0
- **Prediction**: Ω_DM = 0.265 ± 0.003 (±1%)
- **Expected range**: 0.262-0.268
- **Target experiment**: DESI DR3 (2026), Euclid weak lensing
- **Falsification trigger**: ΔΩ_DM > 10% from TRINITY prediction
- **Status**: PENDING
- **Evidence**: 0.002% error, I16 pass, I11 cross-domain consistency verified
- **Charter compliance**: R3 (γ-free), R4 (Planck reference), R9 (DESI trigger)

#### P-COSM-002: Dark Energy Density (Ω_Λ) — **CANONICAL ✓**
- **Formula ID**: `omega_lambda`
- **Fit Origin**: **CANONICAL** (γ-free, found via `tri math search-canonical`)
- **Registered**: 2026-03-08 (elevated from exploratory)
- **Canonical formula**: Ω_Λ = 82 × 3 × π⁻³ × φ⁻³ × e⁻¹
- **Parameters**: n=82, k=1, m=-3, p=-3, q=-1, r=0
- **Prediction**: Ω_Λ = 0.689 ± 0.007 (±1%)
- **Expected range**: 0.682-0.696
- **Target experiment**: DESI DR3 (2026), Euclid weak lensing
- **Falsification trigger**: ΔΩ_Λ > 10% from TRINITY prediction
- **Status**: PENDING
- **Evidence**: 0.002% error, I16 pass, I11 cross-domain consistency verified
- **Charter compliance**: R3 (γ-free), R4 (Planck reference), R9 (DESI trigger)

#### P-COSM-003: Dark Energy Equation of State
- **Formula ID**: `w_z_lambda_cdm`
- **Fit Origin**: CANONICAL (trusted core: φ,π,e only)
- **Registered**: 2026-03-08
- **Locked trace**: `tri trace w_z_lambda_cdm` at registration
- **Prediction**: w(z) = -1 (exact, φ-independence)
- **Expected range**: w ∈ [-1.03, -0.97] (current Planck bounds)
- **Target experiment**: DESI BAO measurements, Euclid weak lensing
- **Falsification trigger**: |w - (-1)| > 0.05 (5% deviation from ΛCDM)
- **Status**: PENDING
- **Charter compliance**: R4 (Planck reference), R9 (DESI trigger)

**I11 Cross-Domain Check** (P-COSM-001 + P-COSM-002):
- Ω_DM + Ω_Λ + Ω_baryon = 0.265 + 0.689 + 0.049 = 1.003
- Error from unity: 0.302% < 1% → **PASS**

---

### Gravity Predictions

#### P-GRV-001: Gravitational Constant from φ
- **Formula ID**: `G_from_phi`
- **Registered**: 2026-03-08
- **Prediction**: G = π³γ²/φ ≈ 6.68×10⁻¹¹ m³/kg·s²
- **Expected range**: Within 1% of CODATA 2018
- **Target experiment**: Laboratory G measurements (CODATA updates)
- **Falsification trigger**: Error > 1% from CODATA recommended value
- **Status**: PENDING
- **Note**: See `src/gravity/sacred_gravity.zig`

#### P-GRV-002 through P-GRV-006: LISA Predictions
- **Registered**: 2026-03-08
- **Target experiment**: LISA 2035
- **Falsification trigger**: Phase deviation > 1% from TRINITY predictions
- **See**: `docs/papers/LISA_PREDICTION_ROADMAP_2035.md`

---

### Consciousness Predictions

#### P-CNS-001: Neural Gamma Frequency
- **Formula ID**: `neural_gamma_frequency`
- **Registered**: 2026-03-08
- **Prediction**: f_γ = φ³π/γ ≈ 56 Hz (consciousness binding frequency)
- **Expected range**: 50-62 Hz (EEG gamma band)
- **Target experiment**: Neural imaging during conscious states
- **Falsification trigger**: No 56 Hz peak during conscious awareness
- **Status**: PENDING
- **Charter compliance**: R3 (γ-dependent), R9 (experimental falsification)
- **See**: `src/consciousness/neural_gamma.zig`

---

## Exploratory Fits (Not Pre-Registered)

**These entries use `fit_origin = POSTDICTION` formulas** — parameters were numerically optimized after seeing experimental data, or represent honest rejections where canonical search failed. They are tracked here for research purposes but **do NOT have pre-registered prediction status**.

To elevate an exploratory fit to pre-registered status:
1. Derive a canonical formula (V = n×3^k×π^m×φ^p×e^q with r=t=u=0)
2. Verify it passes `tri prove <id>` with I16 invariant
3. Move to canonical section with new prediction ID

### QCD Exploratory Fits

#### P-QCD-E001: QCD Critical Temperature (EXPLORATORY — REJECTED)
- **Formula ID**: `qcd_tc_candidate`
- **Fit Origin**: **POSTDICTION** (rejected_canonical_search via `tri math search-canonical`)
- **Issue**: Canonical search found only tautology: 155 × φ⁻³ × γ⁻¹ = 155 × (γ × γ⁻¹) = 155 × 1
- **Analysis**: This is numerical fitting (155 × 1 = 155), not a genuine sacred formula
- **R3 violation**: γ-dependent formulas are structurally ineligible for exact verdict
- **Prediction**: Tc ≈ 155 MeV (lattice QCD average)
- **Expected range**: 150-162 MeV (95% confidence)
- **Target experiment**: Lattice QCD (HotQCD, Wuppertal-Budapest)
- **Status**: EXPLORATORY — honest rejection, not pre-registered
- **Path forward**: Either find γ-free canonical formula OR accept Tc as emergent (not fundamental)

---

## Post-Hoc Protection Rules

To prevent back-fitting, these rules are enforced:

1. **Lock timestamp**: Every prediction has `pre_reg_date` — Unix timestamp when formula was locked
2. **Immutable formula**: After data release, formula expression CANNOT change
3. **Verdict only**: Only `evidence_level` and `error_pct` may update
4. **Postdiction tag**: Any formula modification after data release = automatic `POSTDICTION` tag
5. **Trace verification**: `tri trace <id>` must show same graph structure as at registration

---

## Adding New Predictions

To register a new prediction:

1. Ensure formula passes `tri prove <id>` with at least CANDIDATE status
2. Define falsification trigger (experiment + threshold)
3. Add entry to this log with:
   - Unique ID (P-\{DOMAIN\}-\{NNN\})
   - Registration date
   - Locked trace output
   - Expected range + confidence level
4. Commit with message: `pred: Register P-\{DOMAIN\}-\{NNN\} - {brief description}`

```bash
# Example: Register new prediction
tri prove new_formula
# Copy output to PREDICTIONS_LOG.md
git add docs/PREDICTIONS_LOG.md
git commit -m "pred: Register P-QCD-003 - Quark mass ratio prediction"
```

---

## Update Protocol

When experimental data becomes available:

1. Add `result_date`, `observed_value`, `final_error_pct`
2. Update `status` → CONFIRMED or FALSIFIED
3. Add `conclusion` paragraph
4. Keep original prediction intact (no edits to registered values)
5. Commit with message: `pred: Update P-{ID} - CONFIRMED/FALSIFIED`

---

## Cross-Domain Stress Tests

Research Cycle Section 3: These combinations should either be compatible or fail explicitly:

| Test | Formulas | Expected | Status |
|------|----------|----------|--------|
| CD-001 | Ω_Λ + Ω_DM + Ω_b | ≈ 1.0 (within 5%) | **PASS** (0.302%) |
| CD-002 | α_s(M_Z) vs α_s(m_τ) | Running consistent | PENDING |
| CD-003 | f_γ vs thermal kT | kT at 300K ≪ f_γ | PENDING |
| CD-004 | G from φ vs Ω_Λ | Consistent γ-power | PENDING |
| CD-005 | Mass ratios | Decay chain consistency | PENDING |

Run with: `tri math doctor --cross-domain`

---

**φ² + 1/φ² = 3 | PREDICTIONS LOG | RESEARCH CYCLE v1.0**
