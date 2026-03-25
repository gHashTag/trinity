#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Ternary Scoring System

Implements the {-1, 0, +1} ternary scoring system for evaluating model responses
with φ-scaling difficulty adjustment and calibration metrics.

Key innovations:
- Ternary outcomes: -1 (wrong), 0 (partial), +1 (correct)
- φ-scaling difficulty weights
- Confidence calibration measurement
- Multi-track scoring aggregation
"""

import math
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from enum import Enum, IntEnum


class Trit(IntEnum):
    """
    Balanced ternary digit from Trinity sacred mathematics.

    Maps to the sacred identity: φ² + 1/φ² = 3

    Values:
        NEGATIVE (-1): T (tah) — wrong answer
        ZERO (0): Z (zet) — partial/uncertain
        POSITIVE (1): 1 (one) — correct answer

    Reference: src/temple/sacred_math.zig, src/b2t/trit.zig
    """
    NEGATIVE = -1  # T (tah)
    ZERO = 0       # Z (zet)
    POSITIVE = 1   # 1 (one)

    @classmethod
    def from_raw_score(cls, raw_score: float) -> 'Trit':
        """Map continuous score to sacred ternary."""
        if raw_score >= 0.5:
            return cls.POSITIVE
        elif raw_score <= -0.5:
            return cls.NEGATIVE
        return cls.ZERO

    def __str__(self) -> str:
        """Return Coptic-inspired glyph representation."""
        return {1: "¹", 0: "°", -1: "¹"}[self.value]


class ScoringMode(Enum):
    """Scoring modes for different probe types."""
    TERNARY = "ternary"  # {-1, 0, +1}
    CALIBRATION = "calibration"  # Confidence-based
    EXACT = "exact"  # Binary exact match
    SEMANTIC = "semantic"  # Semantic similarity
    SACRED = "sacred"  # Sacred formula scoring


@dataclass
class ScoringResult:
    """Result of scoring a single item."""
    item_id: str
    raw_score: float
    ternary_score: int  # -1, 0, or +1
    confidence: float
    ground_truth: str
    response: str
    difficulty: float
    phi_weighted_score: float
    calibration_error: float
    metadata: Dict = field(default_factory=dict)


@dataclass
class TrackResults:
    """Aggregated results for a track."""
    track_name: str
    total_items: int
    correct: int  # +1 scores
    partial: int  # 0 scores
    incorrect: int  # -1 scores
    mean_raw_score: float
    mean_confidence: float
    calibration_score: float
    phi_weighted_mean: float
    per_task_breakdown: Dict[str, Dict] = field(default_factory=dict)


class TernaryScorer:
    """
    Ternary scoring system for Trinity Cognitive Probes.

    Grounded in the sacred mathematical identity: φ² + 1/φ² = 3

    Scoring rules:
    - +1: Correct answer with appropriate confidence
    - 0: Partially correct or appropriate uncertainty
    - -1: Incorrect answer or overconfident wrong answer

    Sacred Mathematics Integration:
    - PHI: Golden ratio φ = (1 + √5) / 2 ≈ 1.618
    - GAMMA: Barbero-Immirzi parameter γ = φ⁻³ ≈ 0.236
    - SACRED_PI: π_sacred = φ + 2 ≈ 3.618
    """

    # Golden ratio φ = (1 + sqrt(5)) / 2 ≈ 1.618
    PHI = (1 + math.sqrt(5)) / 2
    FIBONACCI = [3, 5, 8, 13, 21]

    # Sacred constants from Trinity Temple
    GAMMA = PHI ** -3  # γ = φ⁻³ (Barbero-Immirzi parameter)
    SACRED_PI = PHI + 2  # π_sacred = φ + 2

    # Sacred identity verification
    @staticmethod
    def verify_sacred_identity(eps: float = 1e-10) -> bool:
        """
        Verify the sacred identity: φ² + 1/φ² = 3

        This identity is the foundation of Trinity's ternary logic.
        It connects the golden ratio to the number 3, which gives us
        the three cognitive states: {-1, 0, +1}.

        Reference: src/temple/sacred_math.zig
        """
        phi_sq = TernaryScorer.PHI ** 2
        inv_phi_sq = 1.0 / phi_sq
        result = phi_sq + inv_phi_sq
        return abs(result - 3.0) < eps

    @staticmethod
    def sacred_formula_score(
        n: int,
        k: int = 0,
        m: int = 0,
        p: int = 0,
        q: int = 0
    ) -> float:
        """
        Calculate score using Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

        Args:
            n: Base score (ternary: -1, 0, +1)
            k: Ternary exponent (3^k) — amplifies ternary nature
            m: Pi exponent (π^m) — circles/cycles
            p: Phi exponent (φ^p) — golden ratio scaling
            q: E exponent (e^q) — natural growth

        Returns:
            Calculated sacred score

        Reference: src/ternary/logic.zig (trinityScore function)

        Examples:
            >>> sacred_formula_score(1)      # Standard +1
            1.0
            >>> sacred_formula_score(1, k=2) # Amplified positive (ternary boost)
            1.231...
            >>> sacred_formula_score(-1, p=3) # Strong negative (φ-weighted)
            -4.236...
        """
        base = float(n)
        ternary_factor = 3.0 ** (k / 10.0)
        pi_factor = math.pi ** (m / 20.0)
        phi_factor = TernaryScorer.PHI ** (p / 5.0)
        e_factor = math.e ** (q / 10.0)

        return base * ternary_factor * pi_factor * phi_factor * e_factor

    @staticmethod
    def gamma_weighted_score(raw_score: float, difficulty: float = 0.0) -> float:
        """
        Apply Barbero-Immirzi γ weighting for quantum-gravity inspired scoring.

        γ = φ⁻³ ≈ 0.236 represents the quantization of spacetime in loop quantum
        gravity. Here used as a damping factor for overconfident wrong answers.

        Args:
            raw_score: Original score (typically negative for wrong answers)
            difficulty: Item difficulty (optional, for additional modulation)

        Returns:
            γ-weighted score (negative scores reduced by γ factor)

        Examples:
            >>> gamma_weighted_score(-1.0)  # Penalty reduced by γ
            -0.236...
            >>> gamma_weighted_score(1.0)   # Positive scores unchanged
            1.0
        """
        if raw_score < 0:
            # Reduce negative penalty by γ factor
            return raw_score * TernaryScorer.GAMMA
        return raw_score

    def raw_to_trit(self, raw_score: float) -> Trit:
        """
        Map continuous score to sacred ternary {-1, 0, +1}.

        Uses the sacred identity as the theoretical foundation:
        - Scores >= 0.5 map to POSITIVE (+1)
        - Scores <= -0.5 map to NEGATIVE (-1)
        - Between maps to ZERO (0)

        Args:
            raw_score: Continuous score value

        Returns:
            Trit enum value
        """
        return Trit.from_raw_score(raw_score)

    def __init__(
        self,
        mode: ScoringMode = ScoringMode.TERNARY,
        calibration_tolerance: float = 0.2,
        partial_match_threshold: float = 0.5
    ):
        """
        Initialize the scorer.

        Args:
            mode: Scoring mode to use
            calibration_tolerance: Allowed deviation from ground truth confidence
            partial_match_threshold: Similarity threshold for partial credit
        """
        self.mode = mode
        self.calibration_tolerance = calibration_tolerance
        self.partial_match_threshold = partial_match_threshold

    def calculate_phi_weight(self, difficulty: float) -> float:
        """
        Calculate φ-based weight for difficulty scaling.

        ⚠️ DEPRECATED: This is NOT empirically validated.
        The golden ratio (φ) scaling is pseudo-scientific for this use case.

        Higher difficulty items get higher weights in aggregated scores.

        For scientific benchmarking, difficulty should come from:
        1. Human validation (see ARC-AGI-2 protocol)
        2. Pilot testing with real participants
        3. Item Response Theory (IRT) calibration
        """
        # Normalize difficulty to [0, 1] range
        # Max expected difficulty is approximately 21 * PHI ≈ 34
        normalized = min(difficulty / 34.0, 1.0)

        # φ-scaling: weight increases with difficulty
        return 1.0 + (self.PHI - 1.0) * normalized

    def score_item(
        self,
        item_id: str,
        response: str,
        ground_truth: str,
        confidence: float,
        ground_truth_confidence: float,
        difficulty: float,
        task_type: str = "default"
    ) -> ScoringResult:
        """
        Score a single item using ternary scoring.

        Args:
            item_id: Unique identifier for the item
            response: Model's response text
            ground_truth: Expected correct answer
            confidence: Model's reported confidence (0-1)
            ground_truth_confidence: Expected confidence for this item
            difficulty: φ-scaled difficulty value
            task_type: Type of task for specialized scoring

        Returns:
            ScoringResult with all metrics
        """
        # Determine raw correctness
        is_correct = self._is_correct(response, ground_truth, task_type)
        is_partial = self._is_partial(response, ground_truth, task_type)

        # Calculate ternary score
        if is_correct:
            ternary = 1
            raw = 1.0
        elif is_partial:
            ternary = 0
            raw = 0.5
        else:
            ternary = -1
            raw = 0.0

        # Calculate confidence calibration error
        calibration_error = abs(confidence - ground_truth_confidence)

        # Adjust for calibration (penalize overconfident wrong answers)
        if not is_correct and confidence > 0.7:
            # Overconfident wrong answer gets extra penalty
            raw = max(raw - 0.5, -1.0)
            ternary = -1
        elif is_correct and calibration_error > self.calibration_tolerance:
            # Correct but poorly calibrated gets reduced credit
            raw = raw * 0.5
            ternary = 0 if ternary == 1 else ternary

        # Calculate φ-weighted score
        phi_weight = self.calculate_phi_weight(difficulty)
        phi_weighted = raw * phi_weight

        # Apply sacred mathematics transformations
        trit_value = self.raw_to_trit(raw)

        return ScoringResult(
            item_id=item_id,
            raw_score=raw,
            ternary_score=ternary,
            confidence=confidence,
            ground_truth=ground_truth,
            response=response,
            difficulty=difficulty,
            phi_weighted_score=phi_weighted,
            calibration_error=calibration_error,
            metadata={
                "task_type": task_type,
                "phi_weight": phi_weight,
                "is_correct": is_correct,
                "is_partial": is_partial,
                "trit_value": trit_value.value,
                "sacred_identity_verified": self.verify_sacred_identity(),
            }
        )

    def _is_correct(self, response: str, ground_truth: str, task_type: str) -> bool:
        """Check if response is correct."""
        # Normalize for comparison
        response_norm = response.strip().lower()
        ground_truth_norm = ground_truth.strip().lower()

        # Exact match
        if response_norm == ground_truth_norm:
            return True

        # Contains match
        if ground_truth_norm in response_norm and len(response_norm) < len(ground_truth_norm) * 3:
            return True

        # Numeric match
        try:
            response_num = float(response_norm)
            truth_num = float(ground_truth_norm)
            if abs(response_num - truth_num) < 0.001:
                return True
        except ValueError:
            pass

        # Task-specific checks
        if task_type == "math":
            return self._check_math(response, ground_truth)
        elif task_type == "confidence_calibration":
            return self._check_confidence_response(response, ground_truth)

        return False

    def _is_partial(self, response: str, ground_truth: str, task_type: str) -> bool:
        """Check if response deserves partial credit."""
        response_words = set(response.strip().lower().split())
        ground_truth_words = set(ground_truth.strip().lower().split())

        # Word overlap check
        overlap = response_words & ground_truth_words
        if overlap and len(overlap) >= len(ground_truth_words) * 0.5:
            return True

        return False

    def _check_math(self, response: str, ground_truth: str) -> bool:
        """Specialized math checking."""
        # Extract numbers from response
        import re
        response_nums = re.findall(r'-?\d+\.?\d*', response)
        if not response_nums:
            return False

        try:
            response_val = float(response_nums[0])
            truth_val = float(ground_truth)
            return abs(response_val - truth_val) < 0.01
        except (ValueError, IndexError):
            return False

    def _check_confidence_response(self, response: str, ground_truth: str) -> bool:
        """Check confidence calibration responses."""
        # These are more subjective; look for key agreement
        response_lower = response.lower()
        truth_lower = ground_truth.lower()

        # Check for answer in response
        if truth_lower in response_lower:
            return True

        # Check for "yes" or "no" agreement
        if truth_lower.startswith(("yes", "no", "correct", "incorrect")):
            return True

        return False

    def aggregate_results(
        self,
        results: List[ScoringResult],
        track_name: str
    ) -> TrackResults:
        """
        Aggregate scoring results for a track.

        Args:
            results: List of individual scoring results
            track_name: Name of the track

        Returns:
            TrackResults with aggregated metrics
        """
        if not results:
            return TrackResults(
                track_name=track_name,
                total_items=0,
                correct=0,
                partial=0,
                incorrect=0,
                mean_raw_score=0.0,
                mean_confidence=0.0,
                calibration_score=0.0,
                phi_weighted_mean=0.0
            )

        # Count ternary outcomes
        correct = sum(1 for r in results if r.ternary_score == 1)
        partial = sum(1 for r in results if r.ternary_score == 0)
        incorrect = sum(1 for r in results if r.ternary_score == -1)

        # Calculate means
        mean_raw = sum(r.raw_score for r in results) / len(results)
        mean_conf = sum(r.confidence for r in results) / len(results)
        mean_calibration_error = sum(r.calibration_error for r in results) / len(results)

        # Calibration score (lower error is better, invert to 0-1 scale)
        calibration_score = max(0.0, 1.0 - mean_calibration_error)

        # φ-weighted mean
        phi_weighted_mean = sum(r.phi_weighted_score for r in results) / len(results)

        # Per-task breakdown
        per_task = {}
        for result in results:
            task = result.metadata.get("task_type", "default")
            if task not in per_task:
                per_task[task] = {
                    "count": 0,
                    "correct": 0,
                    "partial": 0,
                    "incorrect": 0,
                    "mean_score": 0.0
                }
            per_task[task]["count"] += 1
            per_task[task]["correct"] += 1 if result.ternary_score == 1 else 0
            per_task[task]["partial"] += 1 if result.ternary_score == 0 else 0
            per_task[task]["incorrect"] += 1 if result.ternary_score == -1 else 0
            per_task[task]["mean_score"] += result.raw_score

        # Calculate per-task means
        for task in per_task.values():
            if task["count"] > 0:
                task["mean_score"] /= task["count"]

        return TrackResults(
            track_name=track_name,
            total_items=len(results),
            correct=correct,
            partial=partial,
            incorrect=incorrect,
            mean_raw_score=mean_raw,
            mean_confidence=mean_conf,
            calibration_score=calibration_score,
            phi_weighted_mean=phi_weighted_mean,
            per_task_breakdown=per_task
        )

    def calculate_ternary_accuracy(self, results: List[ScoringResult]) -> float:
        """
        Calculate ternary accuracy score.

        Formula: (correct - incorrect) / total
        Range: [-1, 1] where 1 is perfect, 0 is random, -1 is inverse
        """
        if not results:
            return 0.0

        correct = sum(1 for r in results if r.ternary_score == 1)
        incorrect = sum(1 for r in results if r.ternary_score == -1)

        return (correct - incorrect) / len(results)

    def format_results(self, results: TrackResults) -> str:
        """Format track results for display."""
        lines = [
            f"\n{'='*60}",
            f"Track: {results.track_name}",
            f"{'='*60}",
            f"Total Items: {results.total_items}",
            f"\nTernary Outcomes:",
            f"  ✓ Correct (+1):   {results.correct:4d} ({100*results.correct/results.total_items:.1f}%)",
            f"  ~ Partial (0):    {results.partial:4d} ({100*results.partial/results.total_items:.1f}%)",
            f"  ✗ Incorrect (-1): {results.incorrect:4d} ({100*results.incorrect/results.total_items:.1f}%)",
            f"\nScores:",
            f"  Mean Raw Score:      {results.mean_raw_score:.4f}",
            f"  φ-Weighted Mean:     {results.phi_weighted_mean:.4f}",
            f"  Calibration Score:  {results.calibration_score:.4f}",
            f"  Mean Confidence:     {results.mean_confidence:.4f}",
            f"  Ternary Accuracy:    {self.calculate_ternary_accuracy([]):.4f}",  # Placeholder
        ]

        if results.per_task_breakdown:
            lines.append(f"\nPer-Task Breakdown:")
            for task, stats in results.per_task_breakdown.items():
                lines.append(
                    f"  {task}: {stats['correct']}/{stats['count']} "
                    f"(mean: {stats['mean_score']:.3f})"
                )

        lines.append(f"{'='*60}\n")
        return "\n".join(lines)


def parse_confidence(response: str) -> float:
    """
    Parse confidence score from model response.

    Supports multiple formats:
    - "confidence: 0.7"
    - "70% confident"
    - "7/10"
    - JSON: {"confidence": 0.7}
    """
    import re
    import json

    response_lower = response.strip().lower()

    # Try JSON first
    try:
        data = json.loads(response)
        if isinstance(data, dict) and "confidence" in data:
            return float(data["confidence"])
    except (json.JSONDecodeError, ValueError, TypeError):
        pass

    # Special patterns for fractions (order matters - more specific first)
    # Check for X/10 format before X/100
    match_10 = re.search(r"([0-9.]+)/10\b", response_lower)
    if match_10:
        val = float(match_10.group(1))
        return val / 10.0

    match_100 = re.search(r"([0-9.]+)/100\b", response_lower)
    if match_100:
        val = float(match_100.group(1))
        return val / 100.0

    # Other patterns
    patterns = [
        r"confidence[:\s]+([0-9.]+)",
        r"([0-9.]+)%\s+confident",
        r"certainty[:\s]+([0-9.]+)",
        r"probability[:\s]+([0-9.]+)",
    ]

    for pattern in patterns:
        match = re.search(pattern, response_lower)
        if match:
            val = float(match.group(1))
            if val <= 1.0:
                return val
            elif val <= 100:
                return val / 100

    # Default if no confidence found
    return 0.5


if __name__ == "__main__":
    # Test the scorer with sacred mathematics
    print("=" * 60)
    print("Trinity Cognitive Probes — Sacred Mathematics Verification")
    print("=" * 60)

    # Verify sacred identity
    print(f"\n📐 Sacred Identity: φ² + 1/φ² = 3")
    print(f"   φ = {TernaryScorer.PHI:.10f}")
    print(f"   γ = φ⁻³ = {TernaryScorer.GAMMA:.10f}")
    print(f"   π_sacred = φ + 2 = {TernaryScorer.SACRED_PI:.10f}")
    print(f"   Verified: {TernaryScorer.verify_sacred_identity()}")

    # Test sacred formula
    print(f"\n🔮 Sacred Formula: V = n × 3^k × π^m × φ^p × e^q")
    print(f"   V(1) = {TernaryScorer.sacred_formula_score(1):.6f}")
    print(f"   V(1, k=2) = {TernaryScorer.sacred_formula_score(1, k=2):.6f}")
    print(f"   V(-1, p=3) = {TernaryScorer.sacred_formula_score(-1, p=3):.6f}")

    # Test gamma weighting
    print(f"\n⚛️  Gamma Weighting (Barbero-Immirzi):")
    print(f"   γ-weighted(-1.0) = {TernaryScorer.gamma_weighted_score(-1.0):.6f}")
    print(f"   γ-weighted(1.0) = {TernaryScorer.gamma_weighted_score(1.0):.6f}")

    # Test Trit mapping
    print(f"\n🔱 Trit Mapping:")
    print(f"   1.0 → {Trit.from_raw_score(1.0)} ({Trit.from_raw_score(1.0).value})")
    print(f"   0.0 → {Trit.from_raw_score(0.0)} ({Trit.from_raw_score(0.0).value})")
    print(f"   -1.0 → {Trit.from_raw_score(-1.0)} ({Trit.from_raw_score(-1.0).value})")

    print("\n" + "=" * 60)
    print("Running standard scorer tests...")
    print("=" * 60)

    scorer = TernaryScorer()

    # Test items
    test_cases = [
        {
            "item_id": "test_001",
            "response": "Solikamsk",
            "ground_truth": "Solikamsk",
            "confidence": 0.95,
            "ground_truth_confidence": 0.95,
            "difficulty": 3.0,
            "task_type": "default"
        },
        {
            "item_id": "test_002",
            "response": "Paris",
            "ground_truth": "Solikamsk",
            "confidence": 0.9,
            "ground_truth_confidence": 0.95,
            "difficulty": 5.0,
            "task_type": "default"
        },
        {
            "item_id": "test_003",
            "response": "The capital might be Solikamsk or maybe another city",
            "ground_truth": "Solikamsk",
            "confidence": 0.5,
            "ground_truth_confidence": 0.95,
            "difficulty": 3.0,
            "task_type": "default"
        },
    ]

    results = []
    for tc in test_cases:
        result = scorer.score_item(**tc)
        results.append(result)
        trit_str = result.metadata.get("trit_value", "?")
        print(f"{result.item_id}: {result.ternary_score} (raw: {result.raw_score:.2f}, trit: {trit_str})")

    # Aggregate
    track_results = scorer.aggregate_results(results, "Test Track")
    print(scorer.format_results(track_results))
