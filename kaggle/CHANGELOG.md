# Changelog — Trinity Cognitive Probes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-03-25

### Added — Sacred Mathematics Integration (Round 2)

#### Core Sacred Types
- **`Trit` enum**: Balanced ternary digit {-1, 0, +1}
  - Maps to Trinity Temple sacred mathematics (`src/b2t/trit.zig`)
  - NEGATIVE = -1 (T/tah) — wrong answer
  - ZERO = 0 (Z/zet) — partial/uncertain
  - POSITIVE = 1 (1/one) — correct answer
  - Method: `Trit.from_raw_score()` for mapping continuous scores

#### Sacred Identity Verification
- **`verify_sacred_identity()`**: Validates φ² + 1/φ² = 3
  - Foundation of Trinity's ternary logic
  - Connects golden ratio to three cognitive states
  - Reference: `src/temple/sacred_math.zig`

#### Sacred Formula Scoring
- **`sacred_formula_score()`**: V = n × 3^k × π^m × φ^p × e^q
  - Base score n (ternary: -1, 0, +1)
  - Ternary exponent k (3^k) — amplifies ternary nature
  - Pi exponent m (π^m) — circles/cycles
  - Phi exponent p (φ^p) — golden ratio scaling
  - E exponent q (e^q) — natural growth
  - Reference: `src/ternary/logic.zig` (trinityScore function)

#### Sacred Constants
- **`GAMMA`**: γ = φ⁻³ ≈ 0.236 (Barbero-Immirzi parameter)
  - Spacetime quantization in loop quantum gravity
  - Used as damping factor for overconfident wrong answers
- **`SACRED_PI`**: π_sacred = φ + 2 ≈ 3.618

#### Gamma Weighting
- **`gamma_weighted_score()`**: Apply γ damping to penalties
  - Reduces negative scores by γ factor (~0.236)
  - Preserves positive and zero scores
  - Inspired by quantum gravity physics

#### Scoring Metadata
- All scoring results now include:
  - `trit_value`: Sacred ternary digit
  - `sacred_identity_verified`: True if φ² + 1/φ² = 3 holds

### Added — Trinity S³AI Architecture Documentation

- **`docs/TRINITY_S3AI_INTEGRATION.md`**: Architecture alignment
  - Strand 2 (Metacognitive Monitoring) — primary benchmark focus
  - Strand 1 (Neuro-symbolic Reasoning) — secondary via ternary scoring
  - Strand 3 (Temporal Coherence) — future work
  - Sacred mathematics foundations
  - File cross-references to Trinity core code

### Added — Sacred Math Tests

- **`TestTrit`**: Trit enum validation (5 tests)
- **`TestSacredIdentity`**: Sacred identity verification (4 tests)
- **`TestSacredFormula`**: Sacred Formula calculations (6 tests)
- **`TestGammaWeighting`**: Gamma weighting logic (4 tests)
- **`TestSacredMathIntegration`**: End-to-end integration (3 tests)

**Total**: 57 tests passing (22 new sacred math tests)

### Changed

#### Scorer Module (`eval/scorer.py`)
- Added sacred mathematics constants (PHI, GAMMA, SACRED_PI)
- Added sacred mathematics methods (verify_sacred_identity, sacred_formula_score, gamma_weighted_score, raw_to_trit)
- Enhanced `score_item()` to include Trit value and sacred identity verification in metadata
- Updated `__main__` section with sacred mathematics verification output

#### Test Module (`tests/test_scoring.py`)
- Added `Trit` import from scorer
- Added 22 new sacred mathematics tests
- All 57 tests passing

### Documentation

- Sacred identity: φ² + 1/φ² = 3 explained as theoretical foundation
- Sacred Formula: V = n × 3^k × π^m × φ^p × e^q documented
- Trinity S³AI architecture alignment documented
- Cross-references to Trinity Temple layer (`src/temple/`)

---

## [2.1.0] - 2026-03-25

### Added — Scientific Metrics (Priority 1)

#### Confidence Discretization
- **`discretize_confidence()`**: Round confidence to 5% buckets (21 levels)
  - Based on Mielke et al. (2024) "Verbalized Confidence in LLMs"
  - Replaces noisy 0-100 continuous scale with scientifically validated 5% granularity
  - Function: `confidence_to_bucket()` for binning (0-20)

#### Type II Signal Detection Theory
- **`calculate_meta_d_prime()`**: Metacognitive sensitivity metric
  - Based on Maniscalco et al. (2023)
  - Returns: (meta_d_prime, d_prime, mratio)
  - Separates task performance from metacognitive ability
  - Uses inverse normal CDF (probit function)

#### Expected Calibration Error
- **`calculate_ece()`**: Calibration measurement
  - Based on Fleming & Lau (2014)
  - Measures confidence vs accuracy mismatch
  - Configurable bin count (default: 10)

#### Calibration Curve
- **`calculate_calibration_curve()`**: Per-bucket accuracy data
  - Returns: [(bin, avg_conf, avg_acc, count), ...]
  - Used for calibration visualization

### Added — Pass@2 Scoring (Priority 2)

- **`score_pass_at_two()`**: ARC-AGI-2 protocol implementation
  - Two independent attempts per item
  - Score = 1.0 if EITHER attempt correct
  - Measures generalization, not memorization

### Added — Contamination Detection (Priority 3)

#### New Module: `validate/contamination.py`
- **`ContaminationDetector`**: Training data leakage detection
  - N-gram overlap detection (3, 4, 5-grams)
  - Semantic similarity (optional, with embeddings)
  - Similarity thresholds: Confirmed (0.98), Likely (0.90), Suspicious (0.75)
  - CLI: `python -m kaggle.validate.contamination`

- **`KnownBenchmarksChecker`**: Fact-based contamination detection
  - Checks against known facts in training data
  - Estimates contamination risk by category

- **Temporal holdout validation**: `check_temporal_holdout()`
  - Verifies questions are newer than training cutoff

### Added — Kaggle UX Improvements (Priority 4)

#### Documentation
- **`docs/FAQ.md`**: 50+ common questions with answers
  - Scoring questions
  - Technical questions
  - Strategy questions
  - Common pitfalls

- **`docs/LEADERBOARD_STRATEGIES.md`**: Competition guide
  - Tier 1-5 strategies
  - Track-specific tips
  - Common pitfalls
  - Experimental strategies (self-consistency, ensembling)

- **`docs/DATASET_CARD_v2.1.md`**: Updated dataset card
  - Scientific metrics explanation
  - Baseline results table
  - Inter-rater reliability
  - Key references (bibtex)

#### Starter Notebook
- **`notebooks/starter_baseline.ipynb`**: Quick start guide
  - < 5 min runtime
  - Tier 1-3 example strategies
  - Works offline (for testing)
  - Clear comments

### Added — Multi-Language Support

- **Russian (RU)**: `questions/ru/metacognition.json`
  - 20 culturally-adapted questions
  - Tests cross-lingual transfer
  - Russian literature, history, geography
  - Now 5 languages: EN, ES, ZH, AR, RU

### Changed

#### Scoring Module
- **`eval/scorer.py`**: Original scorer (v2.0) preserved
- **`eval/scorer_v2.py`**: New scientific metrics (v2.1)
  - Backward compatible with v2.0
  - Add `from scorer_v2 import TernaryScorerV2` to use

#### API Improvements
- **`discretize_confidence()`**: Now returns 5% buckets
- **`parse_confidence()`**: Unchanged, still supports multiple formats

### Fixed

- Confidence calibration tolerance: 0.2 → 0.15 (tighter for discrete confidence)
- Ternary accuracy calculation in `format_results()`: Now uses actual results

### Deprecated

- **φ-scaling**: Marked as "not empirically validated"
  - For scientific benchmarking, use human-validated difficulty (ARC-AGI-2)
  - Kept for compatibility

### Security

- Added warnings about API key storage
- Documentation on rate limiting

---

## [2.0.0] - 2026-03-20

### Added
- 5 cognitive tracks × 5 tasks = 25 benchmarks
- Ternary scoring system {-1, 0, +1}
- φ-scaling difficulty weighting
- Multi-provider API support (OpenAI, Anthropic, Google, Local)
- Multi-language support (EN, ES, ZH, AR)
- Dataset validation (diversity, difficulty, leakage)
- Comprehensive test suite
- Dockerfile for reproducibility

### Changed
- Unified evaluation framework (runner, scorer, API client)
- Enhanced question diversity (100+ templates per task)

---

## [1.0.0] - 2026-03-15

### Added
- Initial release
- Basic metacognition benchmark
- 100 test items
