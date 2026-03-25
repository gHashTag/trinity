"""
Trinity Cognitive Probes — Evaluation Framework

Unified evaluation framework for all 5 tracks × 5 tasks = 25 benchmarks.

Modules:
- scorer: Ternary scoring system {-1, 0, +1}
- api_client: Multi-provider LLM client
- runner: Unified benchmark runner

Usage:
    from kaggle.eval import BenchmarkRunner, TernaryScorer

    # Run all benchmarks
    runner = BenchmarkRunner()
    results = runner.run_all()
    runner.save_submission(results)

    # Score individual items
    scorer = TernaryScorer()
    result = scorer.score_item(
        item_id="test_001",
        response="Tashkent",
        ground_truth="Tashkent",
        confidence=0.95,
        ground_truth_confidence=0.95,
        difficulty=3.0
    )
"""

from .scorer import (
    TernaryScorer,
    ScoringResult,
    TrackResults,
    ScoringMode,
    parse_confidence
)

from .api_client import (
    MultiProviderClient,
    LLMClient,
    OpenAIClient,
    AnthropicClient,
    GoogleClient,
    LocalClient,
    CustomClient,
    Provider,
    ModelTier,
    APIResponse,
    ModelConfig
)

from .runner import (
    BenchmarkRunner,
    BenchmarkItem,
    BenchmarkResult,
    BenchmarkSummary,
    Track,
    Task
)

__version__ = "1.0.0"
__all__ = [
    # Scorer
    "TernaryScorer",
    "ScoringResult",
    "TrackResults",
    "ScoringMode",
    "parse_confidence",

    # API Client
    "MultiProviderClient",
    "LLMClient",
    "OpenAIClient",
    "AnthropicClient",
    "GoogleClient",
    "LocalClient",
    "CustomClient",
    "Provider",
    "ModelTier",
    "APIResponse",
    "ModelConfig",

    # Runner
    "BenchmarkRunner",
    "BenchmarkItem",
    "BenchmarkResult",
    "BenchmarkSummary",
    "Track",
    "Task"
]
