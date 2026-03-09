# Proof Discipline Charter v1.0

**Status**: Active — All TRINITY formulas must comply
**Effective**: 2025-03-08
**Enforcement**: `tri prove` + `tri goal` + `tri trace`

---

## Organization

This Charter has two distinct sections:

- **Discipline Rules (R1–R4)** — Human-facing constraints on how formulas are introduced and promoted through evidence levels. These are *policy decisions* that developers must follow.
- **Engine Invariants (I5–I10)** — Automatically checked by the Proof Graph Engine on every `tri math prove`. These are *mechanical checks* that enforce consistency.

**Key distinction:** Discipline Rules are about *what you're allowed to do*; Engine Invariants are about *what the engine verifies automatically*.

---

## Core Principles

1. **No formula without proof graph** — Every formula must be traceable through `tri trace <id>` to its foundational definitions.
2. **Evidence is explicit** — Verdict levels (exact/validated/candidate/speculative/rejected) are assigned by invariant checks, not manual assertion.
3. **Gamma is not axiom** — γ = φ⁻³ is marked `candidate` with explicit dependency chain; never promoted to `trusted core` without experimental validation.
4. **Gamma structural limit** — **Any formula depending on γ (via `def.gamma` or `r>0`) is structurally ineligible for `exact` verdict and can be at most `validated` with explicit γ-dependency in trace.** This is not a temporary limitation but a fundamental property: γ is a HYPOTHESIS, not an axiom.
5. **Separation of concerns** — Mathematical identities (`exact`) are distinguished from experimentally verified (`validated`) and hypothetical (`candidate`/`speculative`).
6. **Epistemic integrity** — **Canonical layer must be mismatch-free.** Any formula with `fit_origin=canonical` MUST have I16 invariant pass (declared_expression matches computed value). Violations trigger automatic verdict override to `formula_mismatch`. Enforcement via `tri math ci-check` CI gate.

---

## Discipline Rules (R1–R4)

### R1: Immutable Axiom Layer
```
EXACT verdict requires ALL dependencies to be trusted core
→ def.phi, def.pi, def.e, def.trinity ONLY
→ No formula jumps from candidate to exact without passing through validated
```

### R2: Evidence Gradient
```
validated → MUST have PDG2024 or equivalent external reference
           → error_pct < 1.0%
           → All Engine Invariants PASS

candidate → Plausible but incomplete evidence
           → May depend on γ (candidate)
           → Open goals listed in `tri goal`

speculative → Exploratory, pre-registered
            → Falsification trigger defined
            → No claim to canonical status
```

### R3: Gamma Structural Limit
```
Any formula depending on γ (via `def.gamma` or `params.r > 0`) is
**structurally ineligible** for `exact` verdict and can be at most
`validated` with explicit γ-dependency in trace.

This is not a temporary limitation but a fundamental property:
γ is a HYPOTHESIS (γ = φ⁻³), not an axiom.
```

### R4: Reference Present Invariant
```
For VALIDATED verdict:
  - formula.target_value != null
  - formula.references includes "PDG2024" or equivalent
  - formula.error_pct < threshold (default 1.0%)
```

---

## Engine Invariants (I5–I10)

**These are automatically checked by `tri math prove` on every run.**

### I5: No Circular Dependencies (Invariant: no_circular_dependencies)
```
Formula dependency graph MUST be acyclic.
Check: `tri trace <id>` — no loops in DAG.
Enforcement: Automatic via ProofChecker.checkInvariant().
```

### I6: Allowed Symbols Only (Invariant: allowed_symbol_set)
```
Formula params may ONLY use:
  - Core: n, k, m, p, q (for 3, π, φ, e)
  - Extended: r, t, u (for γ, C, G)

Domain-specific symbols require explicit Domain tag.
Enforcement: Automatic via symbol registry validation.
```

### I7: Dimensional Consistency (Invariant: dimensional_consistency)
```
Units MUST remain consistent through derivation:
  - dimensionless ratios → dimensionless result
  - mass scales → mass output
Enforcement: Automatic via dimensional analysis.
```

### I8: Numeric Stability (Invariant: numeric_stability)
```
Computation MUST be stable at f64 precision:
  - No subtraction of nearly-equal values
  - No exp(log()) roundoff cascades
Enforcement: Automatic via numerical analysis.
```

### I9: Provenance Complete (Invariant: provenance_complete)
```
For VALIDATED formulas:
  - formula.provenance.source = "PDG2024" or equivalent
  - formula.provenance.version = year or DOI
  - formula.provenance.authors non-empty
Enforcement: Automatic via metadata validation.
```

### I10: Falsification Triggers (Invariant: rejected_if_falsification_triggered)
```
For CANDIDATE/SPECULATIVE formulas:
  - formula.falsification_trigger defined
  - Example: "Error > 5%" or "LISA deviation > 10%"
  - On trigger: automatic verdict downgrade to REJECTED
Enforcement: Automatic via threshold monitoring.
```

### I11: Cross-Domain Density Sum (Invariant: cosmology_density_sum)
```
Ω_Λ + Ω_DM + Ω_baryon ≈ 1.0 (within 5%)
Checks: Cosmological density parameters sum to critical density
Enforcement: Automatic via cross-domain consistency check
```

### I12: QCD Scale Consistency (Invariant: qcd_scale_consistency)
```
α_s running must be consistent across energy scales
Checks: α_s(M_Z), α_s(m_τ) follow expected RG evolution
Enforcement: Automatic via cross-domain consistency check
```

### I13: Particle Mass Relations (Invariant: particle_mass_relations)
```
Mass ratios must be consistent with decay chains
Checks: m_μ/m_e, m_τ/m_μ follow hierarchy
Enforcement: Automatic via cross-domain consistency check
```

### I14: Consciousness Energy Scale (Invariant: consciousness_energy_scale)
```
f_γ ≈ 56 Hz must be consistent with thermal energy scales
Checks: kT at 300K (≈ 6 THz) ≫ f_γ for quantum coherence
Enforcement: Automatic via cross-domain consistency check
```

### I15: Gravity-Cosmology Link (Invariant: gravity_cosmology_link)
```
G from φ must link to cosmological Ω parameters
Checks: G = π³γ²/φ consistent with Ω_Λ = γ⁸π⁴/φ²
Enforcement: Automatic via cross-domain consistency check
```

---

## Cross-Domain Stress Tests

These test combinations should either be compatible or fail explicitly:

| Test | Formulas | Expected |
|------|----------|----------|
| CD-001 | Ω_Λ + Ω_DM + Ω_b | ≈ 1.0 (within 5%) |
| CD-002 | α_s(M_Z) vs α_s(m_τ) | Running consistent |
| CD-003 | f_γ vs thermal kT | kT at 300K ≫ f_γ |
| CD-004 | G from φ vs Ω_Λ | Consistent γ-power |
| CD-005 | Mass ratios | Decay chain consistency |

Run with: `tri math doctor --cross-domain`

---

## Duplicate Rules Removed (v1.0)

Note: Previous versions had duplicate "Rule 1-4" sections after I10. These have been removed
to maintain clarity. The authoritative rules are Discipline Rules R1-R4 and Engine
Invariants I5-I15.

---

## Formula Reference Table
```
EXACT verdict requires ALL dependencies to be trusted core
→ def.phi, def.pi, def.e, def.trinity ONLY
→ No formula jumps from candidate to exact without passing through validated
```

### Rule 2: Evidence Gradient
```
validated → MUST have PDG2024 or equivalent external reference
           → error_pct < 1.0%
           → All 8 invariants PASS

candidate → Plausible but incomplete evidence
           → May depend on γ (candidate)
           → Open goals listed in `tri goal`

speculative → Exploratory, pre-registered
            → Falsification trigger defined
            → No claim to canonical status
```

### Rule 3: Reference Present Invariant
```
For VALIDATED verdict:
  - formula.target_value != null
  - formula.references includes "PDG2024" or equivalent
  - formula.error_pct < threshold (default 1.0%)
```

### Rule 4: No Circular Dependencies
```
Lemma dependency graph MUST be acyclic:
  - Formula cannot depend on itself (direct or transitive)
  - Check via: `tri trace <id>` — no loops in DAG
```

### Rule 5: Allowed Symbols Only
```
Formula params may ONLY use:
  - n, k, m, p, q (core sacred: 3, π, φ, e)
  - r, t, u (extensions: γ, C, G)

Domain-specific symbols require explicit Domain tag:
  - .particle: α, αₛ, masses
  - .qcd: Tc, axion parameters
  - .cosmology: w(z), zc, Ω_Λ
```

### Rule 6: Dimensional Consistency
```
Units MUST remain consistent through derivation:
  - dimensionless ratios → dimensionless result
  - mass scales → mass output
  - Check via: invariant.dimensional_consistency
```

### Rule 7: Numeric Stability
```
Computation MUST be stable at f64 precision:
  - No subtraction of nearly-equal values
  - No exp(log()) roundoff cascades
  - Check via: invariant.numeric_stability
```

### Rule 8: Provenance Complete
```
For VALIDATED formulas:
  - formula.provenance.source = "PDG2024" or equivalent
  - formula.provenance.version = year or DOI
  - formula.provenance.authors non-empty
```

### Rule 9: Falsification Triggers
```
For CANDIDATE/SPECULATIVE formulas:
  - formula.falsification_trigger defined
  - Example: "Error > 5%" or "LISA deviation > 10%"
  - On trigger: automatic verdict downgrade to REJECTED
```

### Rule 10: Verdict Assignment
```
Verdicts are ASSIGNED by ProofChecker, not asserted:
  - buildGoalState() runs all 8 invariants
  - Final verdict = consensus of invariant results
  - Manual override requires explicit justification
```

---

## Domain-Specific Guidelines

### Particle Physics (.particle)
```
- All masses MUST reference PDG2024
- Coupling constants (α, αₛ) MUST have error_pct < 1%
- Formulas with γ extensions marked candidate
```

### QCD (.qcd)
```
- Tc predictions: candidate until lattice confirmation
- Axion formulas: speculative with falsification trigger
- Running coupling: validated at scale, extrapolated = candidate
```

### Cosmology (.cosmology)
```
- w(z) fits: validated for ΛCDM, candidate for alternatives
- zc (cosmological constant): speculative (γ-dependent)
- Ω_Λ, Ω_DM: validated from Planck + lensing
```

### Biology/Consciousness (.biology/.consciousness)
```
- Default: speculative
- Elevated to candidate ONLY with:
  - Experimental replication (n ≥ 3)
  - Falsification trigger defined
  - Independent lab confirmation
```

---

## Formula Reference Table

| ID | Domain | Evidence | Charter anchor | Notes |
|----|--------|----------|----------------|-------|
| def.phi | core | exact | R1 (trusted core) | φ = 1.618... |
| def.pi | core | exact | R1 (trusted core) | π = 3.141... |
| def.e | core | exact | R1 (trusted core) | e = 2.718... |
| def.trinity | core | exact | R1 (trusted core) | φ² + φ⁻² = 3 |
| def.gamma | core | candidate | R3 (γ is hypothesis) | γ = φ⁻³ |
| fine_structure_inv | particle | validated | R1,R4,I9 (PDG2024) | 1/α ≈ 137.036 |
| alpha_s | qcd | validated | R1,R4,I9 (PDG2024) | α_s(M_Z) ≈ 0.1185 |
| qcd_tc_candidate | qcd | candidate | R1,R3,R9 (γ + trigger) | Uses γ (r=1) |
| strong_cp_axion | qcd | speculative | R3,R9 (γ + trigger) | θ̄ < 10⁻¹⁰ |
| omega_lambda | cosmology | candidate | R3,R9 (γ-dependent) | Uses γ (r=8) |
| omega_dm | cosmology | candidate | R3,R9 (γ-dependent) | Uses γ (r=4) |
| zc_cosmological | cosmology | speculative | R3,R9 (γ + trigger) | Redshift of Λ |
| w_z_lambda_cdm | cosmology | candidate | R3 (γ in formula) | Dark energy EoS |

**Charter anchor codes:**
- **R1**: Immutable Axiom Layer (trusted core only)
- **R3**: Gamma Structural Limit (γ is hypothesis)
- **R4**: Reference Present Invariant (PDG2024 required)
- **R9**: Falsification Triggers (auto-downgrade)
- **I9**: Provenance Complete invariant check

---

## Falsification Scenarios (R3 + R9 Examples)

Each γ-dependent formula must have an explicit **kill-switch** — experimental result that would falsify it. These are registered in `docs/PREDICTIONS_LOG.md`.

| Formula | Experiment | Trigger | If triggered... |
|---------|------------|---------|----------------|
| `qcd_tc_candidate` | Lattice QCD | Tc outside 155±5 MeV | → CANDIDATE → REJECTED |
| `omega_lambda` | DESI DR3 / Euclid | ΔΩ_Λ > 10% | → CANDIDATE → REJECTED |
| `omega_dm` | DESI DR3 / Euclid | ΔΩ_DM > 10% | → CANDIDATE → REJECTED |
| `strong_cp_axion` | ADMX, IAXO | Axion found OR none by 2030 | → SPECULATIVE → CONFIRMED/REJECTED |
| `w_z_lambda_cdm` | DESI BAO | \|w - (-1)\| > 0.05 | → VALIDATED → REJECTED |
| `lisa_*` | LISA 2035 | Phase deviation > 1% | → SPECULATIVE → CONFIRMED/REJECTED |

**Workflow**:
1. Pre-register prediction in `PREDICTIONS_LOG.md`
2. Lock formula + trace with timestamp
3. Awaiting experimental data
4. On data release: update ONLY verdict/evidence, NEVER formula
5. If trigger fires: automatic downgrade to REJECTED

**Post-hoc protection**: Any formula modification after data release = automatic `POSTDICTION` tag, loss of pre-registered status.

---

## Enforcement Workflow

```bash
# Before committing new formula:
tri prove <formula_id>     # Check full proof graph
tri goal <formula_id>      # Verify all goals met
tri trace <formula_id>     # Confirm no circular deps

# For validated formulas:
#   - All invariants [OK]
#   - EVIDENCE section present
#   - error_pct < threshold

# For candidate formulas:
#   - Open goals listed
#   - Dependencies on γ marked [candidate]
#   - Falsification trigger defined
```

---

## Violation Categories

| Severity | Condition | Action |
|----------|-----------|--------|
| CRITICAL | Circular dependency | Reject commit |
| CRITICAL | VALIDATED without reference | Reject commit |
| CRITICAL | γ marked as trusted core | Reject commit |
| CRITICAL | Formula mismatch (I16 violation) | Terminal override to FORMULA_MISMATCH |
| HIGH | 3+ invariants FAIL | Review required |
| MEDIUM | Open goals without HINT | Warning |
| LOW | Formatting inconsistency | Fix in next commit |

---

## Epistemic Failure Taxonomy (v1.1)

**Status**: New — Enforced via I16/I17 invariants and `tri math doctor --epistemic`

### Failure Types

| Type | Trigger | Severity | Automatic Action |
|------|---------|----------|-------------------|
| **formula_mismatch** | I16: declared_expression ≠ computed value | CRITICAL | Verdict → FORMULA_MISMATCH |
| **fit_error** | Large error with `fit_origin=search_fit` | HIGH | Downgrade to CANDIDATE |
| **missing_scale_factor** | I17: Undeclared unit/scale conversion | MEDIUM | Warning + goal to declare |
| **postdiction_contamination** | `fit_origin=postdiction` without explicit tag | CRITICAL | Tag as POSTDICTION |

### I16: Expression Mismatch Detection

**Invariant**: `expression_matches_params`

```
TRIGGERS: |computed_value - target_value| / target_value > 10%
          AND formula.declared_expression != null

PUNISHMENT: Verdict → FORMULA_MISMATCH (terminal override)
           [MISMATCH] tag in trace output
           EPISTEMIC FAILURE banner in prove output

RECOVERY:  1. Fix declared_expression to match actual parameters
           2. Mark fit_origin=search_fit (honest admission)
           3. Declare missing_scale_factor if applicable
```

**Examples of I16 violations:**
- `Ω_Λ = γ⁸π⁴/φ²` → computes 0.000052, target 0.689
- `Tc = π²/φ × γ` → computes 2.12 MeV, target 155 MeV

### I17: Missing Scale Factor Declaration

**Invariant**: `unit_scale_declared`

```
TRIGGERS: formula.target_value != null
          AND formula.declared_expression == null

PUNISHMENT: Warning in epistemic check
           Goal added: "declare_missing_scale_factor"

RECOVERY:  Add formula.declared_expression with explicit scale:
           "X = (sacred expression) × SCALE_FACTOR"
```

### Fit Origin Enforcement

**Policy**: System must not lie to itself about how parameters were obtained.

| Origin | When to use | Charter compliance |
|--------|-------------|-------------------|
| **canonical** | Derived from sacred formula V = n×3^k×π^m×φ^p×e^q×γ^r×C^t×G^u | Must pass I16 |
| **search_fit** | Numerical optimization/curve-fitting | Must declare openly |
| **postdiction** | Adjusted after seeing data | Tagged, not hidden |
| **manual_override** | Explicit user setting | Requires justification |

**Detection via `tri math doctor --epistemic`:**
- Counts formulas by fit_origin type
- Warns if search_fit > 30% of registry
- Flags formulas missing fit_origin metadata

### Postdiction Contamination

**Rule**: Any formula modified after seeing experimental data must be tagged `postdiction`.

```
TRIGGERS: formula.modified_at > experiment.published_at
          AND fit_origin != postdiction

PUNISHMENT: Automatic downgrade to SPECULATIVE
           Permanent POSTDICTION tag in trace

PREVENTION: Pre-register predictions in PREDICTIONS_LOG.md
           Lock formula + trace with timestamp before data release
```

### Epistemic Health Checks

**Command**: `tri math doctor --epistemic`

**Checks performed:**
1. **[EPISTEMIC-001]** Formula Mismatch Detection
2. **[EPISTEMIC-002]** Missing Declared Expressions
3. **[EPISTEMIC-003]** Missing Fit Origin
4. **[EPISTEMIC-004]** Fit Origin Classification (search_fit %)
5. **[EPISTEMIC-005]** I16 Invariant Violations

**Remediation workflow:**
```bash
# 1. Detect issues
tri math doctor --epistemic

# 2. Audit specific formula
tri math audit-mismatch          # List all mismatches
tri math fit-origin <id>          # Check fit origin

# 3. See full details
tri math prove <id>               # Shows EPISTEMIC FAILURE banner
tri math goal <id>                # Shows repair goals
tri math trace <id>               # Shows [MISMATCH] tags

# 4. Fix and re-verify
# Update formula.declared_expression or formula.fit_origin
tri math doctor --epistemic       # Re-run checks
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-03-08 | Initial charter — 10 rules, domain guidelines, enforcement workflow |

---

**φ² + 1/φ² = 3 = TRINITY**

*All proof paths lead to TRINITY.*
