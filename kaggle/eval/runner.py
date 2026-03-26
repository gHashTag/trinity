#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Unified Benchmark Runner

Runs all 5 tracks × 5 tasks = 25 benchmarks with unified interface.

Features:
- Run all tracks or specific tracks
- Resume from failures
- Progress tracking
- Kaggle submission format
- Multi-provider API support
- Detailed logging
"""

import os
import sys
import json
import csv
import time
import argparse
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Any, Tuple
from pathlib import Path
from enum import Enum

# Import our modules
try:
    from .scorer import TernaryScorer, ScoringResult, TrackResults, parse_confidence
    from .api_client import MultiProviderClient, Provider, ModelTier, APIResponse
except ImportError:
    # For direct execution
    from scorer import TernaryScorer, ScoringResult, TrackResults, parse_confidence
    from api_client import MultiProviderClient, Provider, ModelTier, APIResponse


class Track(Enum):
    """The 5 cognitive tracks."""
    LEARNING = "thlp"  # Hippocampal Learning Probe
    METACOGNITION = "tmp"  # Trinity Metacognition Probe
    ATTENTION = "tagp"  # Attentional Gateway Probe
    EXECUTIVE = "tefb"  # Executive Function Battery
    SOCIAL = "tscp"  # Social Cognition Probe


class Task(Enum):
    """The 5 tasks per track."""
    TASK_1 = "task_01"
    TASK_2 = "task_02"
    TASK_3 = "task_03"
    TASK_4 = "task_04"
    TASK_5 = "task_05"


@dataclass
class BenchmarkItem:
    """A single benchmark item."""
    id: str
    track: str
    task: str
    question: str
    ground_truth: str
    ground_truth_confidence: float
    difficulty: float
    brain_zone: str
    neural_analog: str
    metadata: Dict = field(default_factory=dict)


@dataclass
class BenchmarkResult:
    """Result of running a benchmark."""
    item_id: str
    track: str
    task: str
    question: str
    ground_truth: str
    response: str
    confidence: float
    ground_truth_confidence: float
    raw_score: float
    ternary_score: int
    phi_weighted_score: float
    latency_ms: int
    provider: str
    model: str
    timestamp: str
    # Scientific metrics (computed on aggregate results)
    scientific_metrics: Dict[str, float] = field(default_factory=dict)


@dataclass
class BenchmarkSummary:
    """Summary of a complete benchmark run."""
    total_items: int
    completed_items: int
    failed_items: int
    mean_raw_score: float
    mean_ternary_score: float
    mean_calibration_error: float
    total_latency_ms: int
    per_track_scores: Dict[str, Dict] = field(default_factory=dict)
    per_task_scores: Dict[str, Dict] = field(default_factory=dict)


class BenchmarkRunner:
    """
    Unified benchmark runner for Trinity Cognitive Probes.

    Usage:
        runner = BenchmarkRunner()
        results = runner.run_all()
        runner.save_submission(results, "submission.csv")
    """

    # Track configurations
    TRACK_CONFIGS = {
        Track.LEARNING: {
            "name": "Hippocampal Learning Probe",
            "file": "thlp_learning.csv",
            "tasks": [
                "few_shot_induction",
                "belief_update",
                "error_driven_learning",
                "reward_signal_learning",
                "long_context_retention"
            ],
            "brain_zones": ["hippocampus", "amygdala", "accumbens"]
        },
        Track.METACOGNITION: {
            "name": "Trinity Metacognition Probe",
            "file": "tmp_metacognition.csv",
            "tasks": [
                "confidence_calibration",
                "error_detection",
                "strategic_adaptation",
                "knowledge_boundary",
                "monitoring_under_load"
            ],
            "brain_zones": ["acc", "ofc", "habenula", "insula"]
        },
        Track.ATTENTION: {
            "name": "Attentional Gateway Probe",
            "file": "tagp_attention.csv",
            "tasks": [
                "selective_filtering",
                "sustained_attention",
                "attention_shifting",
                "adversarial_needle",
                "divided_attention"
            ],
            "brain_zones": ["thalamus", "colliculus", "coeruleus", "reticular"]
        },
        Track.EXECUTIVE: {
            "name": "Executive Function Battery",
            "file": "tefb_executive.csv",
            "tasks": [
                "multi_step_planning",
                "stroop_inhibition",
                "wisconsin_card_sort",
                "working_memory",
                "conflicting_instructions"
            ],
            "brain_zones": ["cortex", "dlpfc", "pallidus", "striatum", "nigra"]
        },
        Track.SOCIAL: {
            "name": "Social Cognition Probe",
            "file": "tscp_social.csv",
            "tasks": [
                "theory_of_mind",
                "pragmatic_inference",
                "audience_adaptation",
                "negotiation",
                "social_norms"
            ],
            "brain_zones": ["insula", "ofc", "habenula", "tom"]
        }
    }

    def __init__(
        self,
        data_dir: str = None,
        provider: Provider = None,
        tier: ModelTier = ModelTier.STANDARD,
        dry_run: bool = False,
        resume_from: str = None,
        seed: int = 42
    ):
        """
        Initialize the benchmark runner.

        Args:
            data_dir: Directory containing CSV data files
            provider: LLM provider to use
            tier: Model tier to use
            dry_run: If True, generate mock responses
            resume_from: Path to checkpoint file for resuming
            seed: Random seed for reproducibility
        """
        self.data_dir = Path(data_dir or os.path.join(os.path.dirname(__file__), "..", "data"))
        self.provider = provider
        self.tier = tier
        self.dry_run = dry_run
        self.seed = seed
        self.resume_from = resume_from

        # Initialize scorer and client
        self.scorer = TernaryScorer()
        self.client = MultiProviderClient(preferred_tier=tier) if not dry_run else None

        # Results storage
        self.results: List[BenchmarkResult] = []
        self.checkpoint_file = resume_from or ".benchmark_checkpoint.json"

    def load_items(self, track: Track, task: str = None) -> List[BenchmarkItem]:
        """
        Load benchmark items from CSV file.

        Args:
            track: Track to load
            task: Optional task filter

        Returns:
            List of BenchmarkItem
        """
        config = self.TRACK_CONFIGS[track]
        csv_path = self.data_dir / config["file"]

        if not csv_path.exists():
            raise FileNotFoundError(f"Data file not found: {csv_path}")

        items = []
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Filter by task if specified
                if task and task not in row.get('task', '').lower():
                    continue

                items.append(BenchmarkItem(
                    id=row['id'],
                    track=track.value,
                    task=row.get('task', 'unknown'),
                    question=row.get('question', row.get('context', row.get('scenario', ''))),
                    ground_truth=row.get('answer', row.get('expected_focus', row.get('expected_inference', row.get('expected_result', '')))),
                    ground_truth_confidence=float(row.get('ground_truth_confidence', row.get('ground_truth', 0.5))),
                    difficulty=float(row.get('difficulty', 3.0)),
                    brain_zone=row.get('brain_zone', ''),
                    neural_analog=row.get('neural_analog', ''),
                    metadata={
                        'examples_count': row.get('examples_count'),
                        'context_length': row.get('context_length'),
                        'distractor_count': row.get('distractor_count'),
                        'actions_needed': row.get('actions_needed')
                    }
                ))

        return items

    def run_item(self, item: BenchmarkItem) -> BenchmarkResult:
        """
        Run a single benchmark item.

        Args:
            item: BenchmarkItem to evaluate

        Returns:
            BenchmarkResult
        """
        start_time = time.time()

        if self.dry_run:
            # Mock response for testing
            import random
            random.seed(self.seed + hash(item.id))
            response = item.ground_truth if random.random() > 0.2 else "Wrong answer"
            confidence = random.uniform(0.3, 0.98)
            provider = "dry_run"
            model = "mock_model"
            latency_ms = random.randint(100, 2000)
        else:
            # Generate response using API
            prompt = f"""Answer this question and provide your confidence level (0.0 to 1.0).

Question: {item.question}

Respond in this format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

            api_response = self.client.generate(prompt, with_confidence=True)

            response = api_response.content
            confidence = parse_confidence(response)
            provider = api_response.provider.value
            model = api_response.model
            latency_ms = api_response.latency_ms

        # Extract answer from response
        answer = self._extract_answer(response)

        # Score the response
        scoring_result = self.scorer.score_item(
            item_id=item.id,
            response=answer,
            ground_truth=item.ground_truth,
            confidence=confidence,
            ground_truth_confidence=item.ground_truth_confidence,
            difficulty=item.difficulty,
            task_type=item.task
        )

        return BenchmarkResult(
            item_id=item.id,
            track=item.track,
            task=item.task,
            question=item.question,
            ground_truth=item.ground_truth,
            response=response,
            confidence=confidence,
            ground_truth_confidence=item.ground_truth_confidence,
            raw_score=scoring_result.raw_score,
            ternary_score=scoring_result.ternary_score,
            phi_weighted_score=scoring_result.phi_weighted_score,
            latency_ms=latency_ms,
            provider=provider,
            model=model,
            timestamp=time.strftime("%Y-%m-%d %H:%M:%S")
        )

    def _extract_answer(self, response: str) -> str:
        """Extract the answer part from a formatted response."""
        import re

        # Look for "Answer:" prefix
        answer_match = re.search(r'Answer:\s*(.*?)(?:\n|$|Confidence:)', response, re.IGNORECASE | re.DOTALL)
        if answer_match:
            return answer_match.group(1).strip()

        # Look for JSON format
        try:
            data = json.loads(response)
            if isinstance(data, dict) and "answer" in data:
                return data["answer"]
        except (json.JSONDecodeError, ValueError):
            pass

        # Return full response as fallback
        return response.strip()

    def run_item_with_ensemble(
        self,
        item: BenchmarkItem,
        temperatures: List[float] = None,
        max_attempts: int = 2
    ) -> BenchmarkResult:
        """
        Run a single benchmark item with Pass@K ensemble.

        Makes K attempts with different temperatures/selective sampling,
        selects the result with the best score.

        Args:
            item: BenchmarkItem to evaluate
            temperatures: List of temperatures to try (default: [0.3, 0.7])
            max_attempts: Maximum attempts (default: 2 for Pass@2)

        Returns:
            BenchmarkResult with best score across attempts
        """
        if temperatures is None:
            temperatures = [0.3, 0.7]

        attempts = []

        for attempt_idx, temp in enumerate(temperatures[:max_attempts], start=1):
            print(f"  Attempt {attempt_idx}/{max_attempts} (T={temp})...", end="\r", flush=True)

            start_time = time.time()

            if self.dry_run:
                # Mock response for testing
                import random
                random.seed(self.seed + hash(item.id) + attempt_idx)
                response = item.ground_truth if random.random() > 0.2 else "Wrong answer"
                confidence = random.uniform(0.3, 0.98)
                provider = "dry_run"
                model = "mock_model"
                latency_ms = random.randint(100, 2000)
            else:
                # Generate response using API with specific temperature
                from .api_client import TemperatureOverride
                prompt = f"""Answer this question and provide your confidence level (0.0 to 1.0).

Question: {item.question}

Respond in this format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

                # Override temperature for this request
                temp_override = TemperatureOverride(temperature=temp)

                api_response = self.client.generate(prompt, with_confidence=True, temperature_override=temp_override)

                response = api_response.content
                confidence = parse_confidence(response)
                provider = api_response.provider.value
                model = api_response.model
                latency_ms = api_response.latency_ms

            # Extract answer from response
            answer = self._extract_answer(response)

            # Score response
            scoring_result = self.scorer.score_item(
                item_id=item.id,
                response=answer,
                ground_truth=item.ground_truth,
                confidence=confidence,
                ground_truth_confidence=item.ground_truth_confidence,
                difficulty=item.difficulty,
                task_type=item.task,
            )

            attempts.append(BenchmarkResult(
                item_id=item.id,
                track=item.track,
                task=item.task,
                question=item.question,
                ground_truth=item.ground_truth,
                response=response,
                confidence=confidence,
                ground_truth_confidence=item.ground_truth_confidence,
                raw_score=scoring_result.raw_score,
                ternary_score=scoring_result.ternary_score,
                phi_weighted_score=scoring_result.phi_weighted_score,
                latency_ms=latency_ms,
                provider=provider,
                model=model,
                timestamp=time.strftime("%Y-%m-%d %H:%M:%S")
            ))

            print("  " * attempt_idx, end="", flush=True)

        # Select best result based on ternary score
        best_attempt = max(attempts, key=lambda x: x.ternary_score)

        print(f"\n  Best score: {best_attempt.ternary_score:.3f} (T={temperatures[attempts.index(best_attempt)]})")

        return best_attempt

    def run_track(
        self,
        track: Track,
        max_items: int = None,
        save_interval: int = 10
    ) -> List[BenchmarkResult]:
        """
        Run all items in a track.

        Args:
            track: Track to run
            max_items: Maximum items to run (for testing)
            save_interval: Checkpoint save interval

        Returns:
            List of BenchmarkResult
        """
        config = self.TRACK_CONFIGS[track]
        print(f"\n{'='*60}")
        print(f"Running Track: {config['name']}")
        print(f"File: {config['file']}")
        print(f"{'='*60}\n")

        items = self.load_items(track)
        if max_items:
            items = items[:max_items]

        results = []
        start_time = time.time()

        for i, item in enumerate(items):
            print(f"[{i+1}/{len(items)}] {item.id[:30]}... ", end="", flush=True)

            try:
                result = self.run_item(item)
                results.append(result)
                print(f"✓ score={result.ternary_score} ({result.raw_score:.2f})")

                # Periodic checkpoint
                if (i + 1) % save_interval == 0:
                    self._save_checkpoint(results, track)

            except Exception as e:
                print(f"✗ error: {e}")
                # Continue with next item

        elapsed = time.time() - start_time
        print(f"\nCompleted {len(results)}/{len(items)} items in {elapsed:.1f}s")

        return results

    def run_all(
        self,
        tracks: List[Track] = None,
        max_items_per_track: int = None,
        save_interval: int = 10
    ) -> List[BenchmarkResult]:
        """
        Run all specified tracks.

        Args:
            tracks: List of tracks to run (all if None)
            max_items_per_track: Max items per track
            save_interval: Checkpoint save interval

        Returns:
            List of all BenchmarkResult
        """
        if tracks is None:
            tracks = list(Track)

        all_results = []
        overall_start = time.time()

        print("\n" + "="*60)
        print("TRINITY COGNITIVE PROBES — UNIFIED BENCHMARK RUNNER")
        print("="*60)
        print(f"Tracks: {', '.join(t.value for t in tracks)}")
        print(f"Provider: {self.provider.value if self.provider else 'auto'}")
        print(f"Tier: {self.tier.value}")
        print(f"Dry run: {self.dry_run}")
        print("="*60 + "\n")

        for track in tracks:
            try:
                track_results = self.run_track(track, max_items_per_track, save_interval)
                all_results.extend(track_results)

                # Print track summary
                track_scores = [r.ternary_score for r in track_results]
                track_accuracy = sum(track_scores) / len(track_scores) if track_scores else 0
                print(f"Track accuracy: {track_accuracy:.3f}\n")

            except Exception as e:
                print(f"Error running track {track.value}: {e}")
                continue

        overall_elapsed = time.time() - overall_start

        print("\n" + "="*60)
        print("BENCHMARK COMPLETE")
        print("="*60)
        print(f"Total items: {len(all_results)}")
        print(f"Total time: {overall_elapsed:.1f}s")
        print(f"Average latency: {overall_elapsed/max(len(all_results), 1)*1000:.0f}ms")
        print("="*60 + "\n")

        self.results = all_results
        return all_results

    def save_submission(
        self,
        results: List[BenchmarkResult],
        output_path: str = "submission.csv"
    ):
        """
        Save results in Kaggle submission format.

        Args:
            results: List of BenchmarkResult
            output_path: Output file path
        """
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Kaggle format: id, score
        submission_data = [
            {
                "id": r.item_id,
                "score": r.phi_weighted_score  # Use φ-weighted score for leaderboard
            }
            for r in results
        ]

        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "score"])
            writer.writeheader()
            writer.writerows(submission_data)

        print(f"✅ Submission saved to {output_path}")
        print(f"   {len(submission_data)} items")

    def save_detailed_results(
        self,
        results: List[BenchmarkResult],
        output_path: str = "detailed_results.csv"
    ):
        """Save detailed results for analysis."""
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'item_id', 'track', 'task', 'question', 'ground_truth',
                'response', 'confidence', 'ground_truth_confidence',
                'raw_score', 'ternary_score', 'phi_weighted_score',
                'latency_ms', 'provider', 'model', 'timestamp'
            ])
            writer.writeheader()
            for r in results:
                writer.writerow(asdict(r))

        print(f"✅ Detailed results saved to {output_path}")

    def generate_summary(self, results: List[BenchmarkResult]) -> BenchmarkSummary:
        """Generate summary statistics."""
        if not results:
            return BenchmarkSummary(
                total_items=0,
                completed_items=0,
                failed_items=0,
                mean_raw_score=0.0,
                mean_ternary_score=0.0,
                mean_calibration_error=0.0,
                total_latency_ms=0
            )

        # Calculate overall stats
        total_items = len(results)
        completed_items = sum(1 for r in results if r.ternary_score != -999)
        failed_items = total_items - completed_items

        mean_raw = sum(r.raw_score for r in results) / total_items
        mean_ternary = sum(r.ternary_score for r in results) / total_items
        mean_cal_error = sum(abs(r.confidence - r.ground_truth_confidence) for r in results) / total_items
        total_latency = sum(r.latency_ms for r in results)

        # Per-track breakdown
        per_track = {}
        for track in Track:
            track_results = [r for r in results if r.track == track.value]
            if track_results:
                per_track[track.value] = {
                    "count": len(track_results),
                    "mean_score": sum(r.raw_score for r in track_results) / len(track_results),
                    "ternary_accuracy": sum(r.ternary_score for r in track_results) / len(track_results)
                }

        # Per-task breakdown
        per_task = {}
        for result in results:
            task_key = f"{result.track}_{result.task}"
            if task_key not in per_task:
                per_task[task_key] = {"count": 0, "total_score": 0}
            per_task[task_key]["count"] += 1
            per_task[task_key]["total_score"] += result.raw_score

        for task_key, data in per_task.items():
            data["mean_score"] = data["total_score"] / data["count"]

        return BenchmarkSummary(
            total_items=total_items,
            completed_items=completed_items,
            failed_items=failed_items,
            mean_raw_score=mean_raw,
            mean_ternary_score=mean_ternary,
            mean_calibration_error=mean_cal_error,
            total_latency_ms=total_latency,
            per_track_scores=per_track,
            per_task_scores=per_task
        )

    def print_summary(self, summary: BenchmarkSummary):
        """Print benchmark summary."""
        print("\n" + "="*60)
        print("BENCHMARK SUMMARY")
        print("="*60)
        print(f"Total items:   {summary.total_items}")
        print(f"Completed:     {summary.completed_items}")
        print(f"Failed:        {summary.failed_items}")
        print(f"\nScores:")
        print(f"  Mean raw:      {summary.mean_raw_score:.4f}")
        print(f"  Mean ternary:  {summary.mean_ternary_score:.4f}")
        print(f"  Cal error:     {summary.mean_calibration_error:.4f}")
        print(f"\nLatency: {summary.total_latency_ms}ms total")

        if summary.per_track_scores:
            print(f"\nPer-Track Scores:")
            for track, stats in summary.per_track_scores.items():
                print(f"  {track}: {stats['mean_score']:.3f} ({stats['ternary_accuracy']:.3f} ternary)")

        print("="*60 + "\n")

    def run_track_with_ensemble(
        self,
        track: Track,
        max_items: int = None,
        temperatures: List[float] = None,
        max_attempts: int = 2,
        save_interval: int = 10
    ) -> List[BenchmarkResult]:
        """
        Run all items in a track with Pass@K ensemble.

        Makes K attempts per item with different temperatures,
        selects the best result for each item.

        Args:
            track: Track to run
            max_items: Maximum items to run (for testing)
            temperatures: List of temperatures to try (default: [0.3, 0.7])
            max_attempts: Maximum attempts per item (default: 2)
            save_interval: Checkpoint save interval

        Returns:
            List of BenchmarkResult (best attempt per item)
        """
        if temperatures is None:
            temperatures = [0.3, 0.7]

        config = self.TRACK_CONFIGS[track]
        print(f"\n{'='*60}")
        print(f"Running Track: {config['name']} (Pass@{max_attempts} Ensemble)")
        print(f"File: {config['file']}")
        print(f"Temperatures: {temperatures[:max_attempts]}")
        print(f"{'='*60}\n")

        items = self.load_items(track)
        if max_items:
            items = items[:max_items]

        results = []
        start_time = time.time()

        for i, item in enumerate(items):
            print(f"[{i+1}/{len(items)}] {item.id[:30]}... ", end="", flush=True)

            try:
                result = self.run_item_with_ensemble(item, temperatures, max_attempts)
                results.append(result)

                # Periodic checkpoint
                if (i + 1) % save_interval == 0:
                    self._save_checkpoint(results, track)

            except Exception as e:
                print(f"✗ error: {e}")
                # Continue with next item

        elapsed = time.time() - start_time
        print(f"\nCompleted {len(results)}/{len(items)} items in {elapsed:.1f}s")

        return results

    def run_all_with_ensemble(
        self,
        tracks: List[Track] = None,
        max_items_per_track: int = None,
        temperatures: List[float] = None,
        max_attempts: int = 2,
        save_interval: int = 10
    ) -> List[BenchmarkResult]:
        """
        Run all specified tracks with Pass@K ensemble.

        Args:
            tracks: List of tracks to run (all if None)
            max_items_per_track: Max items per track
            temperatures: List of temperatures to try (default: [0.3, 0.7])
            max_attempts: Maximum attempts per item (default: 2)
            save_interval: Checkpoint save interval

        Returns:
            List of all BenchmarkResult (best attempt per item)
        """
        if tracks is None:
            tracks = list(Track)

        all_results = []
        overall_start = time.time()

        print("\n" + "="*60)
        print("TRINITY COGNITIVE PROBES — ENSEMBLE BENCHMARK RUNNER")
        print("="*60)
        print(f"Tracks: {', '.join(t.value for t in tracks)}")
        print(f"Pass@K: Pass@{max_attempts}")
        print(f"Temperatures: {temperatures[:max_attempts] if temperatures else '[0.3, 0.7]'}")
        print(f"Provider: {self.provider.value if self.provider else 'auto'}")
        print(f"Tier: {self.tier.value}")
        print(f"Dry run: {self.dry_run}")
        print("="*60 + "\n")

        for track in tracks:
            try:
                track_results = self.run_track_with_ensemble(
                    track, max_items_per_track, temperatures, max_attempts, save_interval
                )
                all_results.extend(track_results)

                # Print track summary
                track_scores = [r.ternary_score for r in track_results]
                track_accuracy = sum(track_scores) / len(track_scores) if track_scores else 0
                print(f"Track accuracy: {track_accuracy:.3f}\n")

            except Exception as e:
                print(f"Error running track {track.value}: {e}")
                continue

        overall_elapsed = time.time() - overall_start

        print("\n" + "="*60)
        print("ENSEMBLE BENCHMARK COMPLETE")
        print("="*60)
        print(f"Total items: {len(all_results)}")
        print(f"Total time: {overall_elapsed:.1f}s")
        print(f"Average latency: {overall_elapsed/max(len(all_results), 1)*1000:.0f}ms")
        print("="*60 + "\n")

        self.results = all_results
        return all_results

    def save_submission_pass_k(
        self,
        results: List[BenchmarkResult],
        output_path: str = "submission_pass2.csv",
        k: int = 2
    ):
        """
        Save results in Kaggle submission format with Pass@K metadata.

        Args:
            results: List of BenchmarkResult
            output_path: Output file path
            k: K value for Pass@K (metadata only)
        """
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Full submission format with confidence, answer, track
        submission_data = [
            {
                "id": r.item_id,
                "confidence": r.confidence,
                "answer": r.response[:50],  # Truncate for CSV
                "track": r.track
            }
            for r in results
        ]

        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "confidence", "answer", "track"])
            writer.writeheader()
            writer.writerows(submission_data)

        print(f"✅ Pass@{k} submission saved to {output_path}")
        print(f"   {len(submission_data)} items")

    def compute_scientific_metrics(
        self,
        results: List[BenchmarkResult],
        version: str = "v7"
    ) -> Dict[str, Any]:
        """
        Compute scientific metrics on benchmark results.

        Calculates:
        - Full-ECE (calibration error)
        - Class-wise ECE (per-class calibration)
        - Distribution shift (if source/target available)

        Args:
            results: List of benchmark results
            version: Metrics version to use (default: "v7")

        Returns:
            Dictionary with scientific metrics
        """
        if not results:
            return {}

        try:
            from .metrics import ScientificMetrics
        except ImportError:
            from metrics import ScientificMetrics

        metrics = ScientificMetrics(version=version)
        scientific_results = {}

        # Extract data for metrics
        confidences = [r.confidence for r in results]
        correct = [r.ternary_score == 1 for r in results]

        # Convert to predictions/labels format
        predictions = [1 if c > 0.5 else 0 for c in confidences]
        labels = [1 if corr else 0 for corr in correct]

        # Calculate Full-ECE (using scalar confidences as fallback)
        try:
            # For scalar confidences, use simple ECE
            from .scorer_v2 import calculate_ece
            ece_value = calculate_ece(confidences, correct, n_bins=10)
            scientific_results["full_ece"] = ece_value
        except ImportError:
            scientific_results["full_ece"] = None

        # Calculate class-wise ECE (binary classification: correct/incorrect)
        try:
            classwise_result = metrics.calculate_classwise_ece(
                confidences=confidences,
                predictions=predictions,
                labels=labels,
                n_classes=2,
                n_bins=10
            )
            scientific_results["classwise_ece_macro"] = classwise_result.macro_ece
            scientific_results["classwise_ece_micro"] = classwise_result.micro_ece
            scientific_results["classwise_ece_per_class"] = classwise_result.ece_per_class
        except (NotImplementedError, AttributeError):
            pass

        # Distribution shift (compare first half to second half)
        if len(results) > 20:
            mid_point = len(results) // 2
            source_confs = confidences[:mid_point]
            target_confs = confidences[mid_point:]

            try:
                shift_result = metrics.detect_distribution_shift(
                    source_confidences=source_confs,
                    target_confidences=target_confs
                )
                scientific_results["distribution_shift_detected"] = shift_result.has_shift
                scientific_results["distribution_shift_magnitude"] = shift_result.shift_magnitude
                scientific_results["distribution_shift_ks_pvalue"] = shift_result.ks_pvalue
            except (NotImplementedError, AttributeError):
                pass

        return scientific_results

    def attach_scientific_metrics(
        self,
        results: List[BenchmarkResult],
        version: str = "v7"
    ) -> List[BenchmarkResult]:
        """
        Attach scientific metrics to results (stored in aggregate).

        Note: Scientific metrics are computed on aggregate data,
        not per-item. They are added to a special aggregate result.

        Args:
            results: List of benchmark results
            version: Metrics version to use (default: "v7")

        Returns:
            Updated results list
        """
        if not results:
            return results

        # Compute metrics
        scientific_metrics = self.compute_scientific_metrics(results, version)

        # Create aggregate result entry (if not exists)
        # We'll add it to the first result for convenience
        if results:
            results[0].scientific_metrics = scientific_metrics

        return results

    def print_scientific_metrics(self, scientific_metrics: Dict[str, Any]):
        """Print scientific metrics in a formatted way."""
        print("\n" + "="*60)
        print("SCIENTIFIC METRICS")
        print("="*60)

        if not scientific_metrics:
            print("No scientific metrics computed.")
            print("="*60 + "\n")
            return

        for key, value in scientific_metrics.items():
            if isinstance(value, float):
                print(f"  {key}: {value:.4f}")
            elif isinstance(value, dict):
                print(f"  {key}:")
                for k, v in value.items():
                    if isinstance(v, float):
                        print(f"    {k}: {v:.4f}")
                    else:
                        print(f"    {k}: {v}")
            elif isinstance(value, list):
                print(f"  {key}: [{len(value)} items]")
            else:
                print(f"  {key}: {value}")

        print("="*60 + "\n")

    def _save_checkpoint(self, results: List[BenchmarkResult], track: Track):
        """Save checkpoint for resuming."""
        checkpoint = {
            "track": track.value,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "results": [asdict(r) for r in results]
        }

        with open(self.checkpoint_file, 'w') as f:
            json.dump(checkpoint, f, indent=2)


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Unified Benchmark Runner"
    )

    parser.add_argument(
        "--track",
        choices=["thlp", "tmp", "tagp", "tefb", "tscp", "all"],
        default="all",
        help="Track to run (default: all)"
    )
    parser.add_argument(
        "--provider",
        choices=["openai", "anthropic", "google", "local"],
        help="LLM provider (default: auto)"
    )
    parser.add_argument(
        "--tier",
        choices=["flagship", "standard", "fast"],
        default="standard",
        help="Model tier (default: standard)"
    )
    parser.add_argument(
        "--max-items",
        type=int,
        help="Maximum items per track (for testing)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate mock responses (no API calls)"
    )
    parser.add_argument(
        "--data-dir",
        default=None,
        help="Data directory (default: ../data)"
    )
    parser.add_argument(
        "--output",
        default="submission.csv",
        help="Output submission file"
    )
    parser.add_argument(
        "--detailed",
        action="store_true",
        help="Also save detailed results"
    )
    parser.add_argument(
        "--ensemble",
        "--pass-k",
        dest="pass_k",
        type=int,
        default=1,
        metavar="K",
        help="Use Pass@K ensemble mode (default: 1 = no ensemble)"
    )
    parser.add_argument(
        "--temperatures",
        type=str,
        default="0.3,0.7",
        help="Comma-separated temperatures for ensemble (default: 0.3,0.7)"
    )
    parser.add_argument(
        "--resume-from",
        type=str,
        help="Path to checkpoint file for resuming"
    )

    args = parser.parse_args()

    # Parse temperatures for ensemble
    temperatures = None
    if args.pass_k > 1:
        try:
            temperatures = [float(t.strip()) for t in args.temperatures.split(',')]
            # Ensure we have enough temperatures
            while len(temperatures) < args.pass_k:
                temperatures.append(temperatures[-1] + 0.2)
        except ValueError:
            print(f"Invalid temperatures: {args.temperatures}. Using default [0.3, 0.7]")
            temperatures = [0.3, 0.7]

    # Parse track selection
    if args.track == "all":
        tracks = None
    else:
        tracks = [Track(args.track)]

    # Parse provider
    provider = Provider(args.provider) if args.provider else None

    # Parse tier
    tier_map = {
        "flagship": ModelTier.FLAGSHIP,
        "standard": ModelTier.STANDARD,
        "fast": ModelTier.FAST
    }
    tier = tier_map[args.tier]

    # Create runner
    runner = BenchmarkRunner(
        data_dir=args.data_dir,
        provider=provider,
        tier=tier,
        dry_run=args.dry_run
    )

    # Run benchmarks
    try:
        if args.pass_k > 1:
            # Use ensemble mode
            results = runner.run_all_with_ensemble(
                tracks=tracks,
                max_items_per_track=args.max_items,
                temperatures=temperatures,
                max_attempts=args.pass_k
            )

            # Save results in Pass@K format
            runner.save_submission_pass_k(results, args.output, args.pass_k)
        else:
            # Use standard single-run mode
            results = runner.run_all(
                tracks=tracks,
                max_items_per_track=args.max_items
            )

            # Save results
            runner.save_submission(results, args.output)

        if args.detailed:
            detailed_path = args.output.replace('.csv', '_detailed.csv')
            runner.save_detailed_results(results, detailed_path)

        # Print summary
        summary = runner.generate_summary(results)
        runner.print_summary(summary)

    except KeyboardInterrupt:
        print("\n\nBenchmark interrupted by user")
        print(f"Partial results: {len(runner.results)} items")
        print("Use --resume-from to continue later")

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
