#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Mock Baseline Generator

Generates mock model responses with controlled accuracy levels
to demonstrate task differentiation on Kaggle benchmarks.

Usage:
    # Generate all 5 tracks with 3 mock models
    python run_mock_baselines.py --all

    # Single track with specific accuracy
    python run_mock_baselines.py --track thlp --accuracy 0.25
"""

import argparse
import csv
import json
import os
import random
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Dict, Any

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

# ============================================================================
# Configuration
# ============================================================================

TRACKS = {
    "thlp": {"file": "data/thlp_learning.csv", "name": "Learning"},
    "tmp": {"file": "data/tmp_metacognition.csv", "name": "Metacognition"},
    "tagp": {"file": "data/tagp_attention.csv", "name": "Attention"},
    "tefb": {"file": "data/tefb_executive.csv", "name": "Executive"},
    "tscp": {"file": "data/tscp_social.csv", "name": "Social"},
}

MOCK_MODELS = {
    "weak-baseline": {"accuracy": 0.25, "name": "Mock Weak Baseline"},
    "nemotron-real": {"accuracy": 0.57, "name": "Nemotron Super (Real Pilot)"},
    "strong-baseline": {"accuracy": 0.85, "name": "Mock Strong Baseline"},
}

# ============================================================================
# Data Classes
# ============================================================================

@dataclass
class BenchmarkItem:
    """A single benchmark item."""
    id: str
    track: str
    task: str
    question: str
    ground_truth: str

@dataclass
class BenchmarkResult:
    """Result of running a single benchmark item."""
    item_id: str
    track: str
    model: str
    response: str
    ground_truth: str
    confidence: float
    correct: bool
    latency_ms: int

# ============================================================================
# Data Loading
# ============================================================================

def load_items(track: str, data_dir: Path = None) -> List[BenchmarkItem]:
    """Load benchmark items from CSV file."""
    if data_dir is None:
        data_dir = Path(__file__).parent

    track_config = TRACKS[track]
    csv_path = data_dir / track_config["file"]

    if not csv_path.exists():
        raise FileNotFoundError(f"Data file not found: {csv_path}")

    items = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Handle different column names for ground truth across tracks
            ground_truth = row.get(
                'answer',
                row.get('ground_truth',
                    row.get('expected_result',
                        row.get('expected_focus',  # TAGP
                            row.get('expected_inference', ''))))  # TSCP
            )
            question = row.get('question', row.get('context', row.get('scenario', '')))

            items.append(BenchmarkItem(
                id=row['id'],
                track=track,
                task=row.get('task', 'unknown'),
                question=question,
                ground_truth=ground_truth,
            ))

    return items

def score_response(response: str, ground_truth: str) -> bool:
    """Score a response against ground truth (binary correct/incorrect)."""
    if not response or not ground_truth:
        return False

    response_clean = response.strip().lower()
    gt_clean = ground_truth.strip().lower()

    # Direct match
    if response_clean == gt_clean:
        return True

    # Contains
    if gt_clean in response_clean or response_clean in gt_clean:
        return True

    # Word overlap (at least 50% of GT words present)
    response_words = set(response_clean.split())
    gt_words = set(gt_clean.split())
    if response_words & gt_words:
        overlap = len(response_words & gt_words) / max(len(gt_words), 1)
        return overlap >= 0.5

    return False

def extract_confidence(response: str) -> float:
    """Extract confidence from response (0-1 scale)."""
    # Look for "Confidence: X.X" pattern
    import re
    match = re.search(r'[Cc]onfidenc[:\\s]+([0-9.]+)', response)
    if match:
        try:
            conf = float(match.group(1))
            return max(0.0, min(1.0, conf))
        except ValueError:
            pass

    # Default confidence
    return 0.5

# ============================================================================
# Mock Generation
# ============================================================================

def generate_mock_response(item: BenchmarkItem, model_config: Dict[str, Any]) -> str:
    """Generate a mock response with controlled accuracy."""
    target_accuracy = model_config["accuracy"]

    # Split ground truth into words
    gt_words = item.ground_truth.split()

    # Decide correct/incorrect based on target accuracy
    is_correct = random.random() < target_accuracy

    if is_correct:
        # Correct answer: ground truth or close match
        if random.random() < 0.8:
            answer = item.ground_truth
        else:
            # Close but not exact match (e.g., "100°C" vs "100 degrees Celsius")
            if gt_words:
                answer = f"Answer: {item.ground_truth}"
            else:
                answer = "Answer: " + item.ground_truth
        confidence = random.uniform(0.7, 1.0)  # Correct answers have high confidence
    else:
        # Incorrect answer: generate plausible wrong answer
        wrong_templates = [
            f"Answer: I'm not sure about this.",
            f"Answer: {gt_words[0] if gt_words else 'unknown'}",
            f"Answer: The opposite of {item.ground_truth}.",
            f"Answer: Let me think about this more...",
            f"Answer: Incorrect.",
        ]
        answer = random.choice(wrong_templates)
        confidence = random.uniform(0.6, 0.95)  # Wrong answers still confident

    return answer

def evaluate_item_mock(item: BenchmarkItem, model_name: str, model_config: Dict[str, Any]) -> BenchmarkResult:
    """Evaluate a single benchmark item with mock response."""
    response = generate_mock_response(item, model_config)
    correct = score_response(response, item.ground_truth)
    confidence = extract_confidence(response)

    return BenchmarkResult(
        item_id=item.id,
        track=item.track,
        model=model_name,
        response=response[:100],  # Truncate for submission
        ground_truth=item.ground_truth,
        confidence=confidence,
        correct=correct,
        latency_ms=random.randint(1000, 5000),  # Simulated latency
    )

def evaluate_track(
    track: str,
    model_name: str,
    model_config: Dict[str, Any],
    max_items: int = None,
    output_dir: Path = None
) -> List[BenchmarkResult]:
    """Evaluate all items in a track with mock responses."""
    if output_dir is None:
        output_dir = Path(__file__).parent / "results"

    output_dir.mkdir(parents=True, exist_ok=True)

    track_config = TRACKS[track]
    print(f"\n{'='*60}")
    print(f"Track: {track_config['name']} ({track})")
    print(f"Model: {model_name} (target accuracy: {model_config['accuracy']:.1%})")
    print(f"{'='*60}")

    items = load_items(track)
    print(f"Loaded {len(items)} items")

    results = []
    correct_count = 0

    for i, item in enumerate(items):
        if max_items and i >= max_items:
            break

        result = evaluate_item_mock(item, model_name, model_config)
        results.append(result)

        if result.correct:
            correct_count += 1

    if (i + 1) % 10 == 0:
        accuracy = correct_count / len(results) if results else 0
        print(f"[{i+1}/{len(items)}] Current accuracy: {accuracy:.1%}", flush=True)

    elapsed = random.uniform(0.1, 0.5)  # Simulated time
    accuracy = correct_count / len(results) if results else 0

    print(f"\nCompleted {len(results)} items")
    print(f"Target accuracy: {model_config['accuracy']:.1%}")
    print(f"Achieved accuracy: {accuracy:.1%}")
    print(f"Diff: {(accuracy - model_config['accuracy']):+.1f}%")

    # Save results
    output_file = output_dir / f"{track}_{model_name}_results.json"
    with open(output_file, 'w') as f:
        json.dump([asdict(r) for r in results], f, indent=2)
    print(f"Results saved to {output_file}")

    return results

# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Mock Baseline Generator"
    )

    parser.add_argument(
        "--track",
        choices=list(TRACKS.keys()) + ["all"],
        default="all",
        help="Track to generate (default: all)"
    )
    parser.add_argument(
        "--model",
        choices=list(MOCK_MODELS.keys()),
        default=None,
        help="Specific model to run (default: all models)"
    )
    parser.add_argument(
        "--accuracy",
        type=float,
        help="Target accuracy for mock model (overrides preset)"
    )
    parser.add_argument(
        "--max-items",
        type=int,
        help="Maximum items per track"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).parent / "results",
        help="Output directory for results"
    )
    parser.add_argument(
        "--csv-output",
        action="store_true",
        help="Also output CSV submission format"
    )

    args = parser.parse_args()

    # Determine tracks
    if args.track == "all":
        tracks = list(TRACKS.keys())
    else:
        tracks = [args.track]

    # Determine models
    if args.model:
        models = {args.model: MOCK_MODELS[args.model]}
    else:
        models = MOCK_MODELS

    # Override accuracy if specified
    if args.accuracy:
        for model_name in models:
            models[model_name]["accuracy"] = args.accuracy

    print("\n" + "="*60)
    print("TRINITY COGNITIVE PROBES — MOCK BASELINE GENERATOR")
    print("="*60)
    print(f"Tracks: {', '.join(tracks)}")
    model_names = []
    for k, v in models.items():
        acc = v.get("accuracy", 0)
        model_names.append(f"{k} ({acc:.1f}%)")
    print(f"Models: {', '.join(model_names)}")
    print("="*60 + "\n")

    # Run evaluation - accumulate results to avoid overwriting
    all_results = []

    for model_name, model_config in models.items():
        print(f"\n{'='*60}")
        print(f"Model: {model_name}")
        target_acc = model_config['accuracy']
        print(f"Target Accuracy: {target_acc:.1%}")
        print(f"{'='*60}")

        for track in tracks:
            try:
                results = evaluate_track(track, model_name, model_config, args.max_items, args.output_dir)
                all_results.extend(results)
            except Exception as e:
                print(f"Error generating {track} for {model_name}: {e}")
                continue

    # Save combined submission
    if all_results:
        submission_path = args.output_dir / "submission.csv"
        submission_data = [
            {
                "id": r.item_id,
                "confidence": round(r.confidence, 6),
                "answer": r.response,
                "track": r.track
            }
            for r in all_results
        ]

        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "confidence", "answer", "track"])
            writer.writeheader()
            writer.writerows(submission_data)

        print(f"\n{'='*60}")
        print("SUBMISSION SAVED")
        print("="*60)
        print(f"Path: {submission_path}")
        print(f"Total items: {len(submission_data)}")
        unique_tracks = set(r.track for r in all_results)
        print(f"Unique tracks: {len(unique_tracks)}")
        print("="*60)

        # Summary per model/track
        print("\nAccuracy Summary:")
        for model_name in models.keys():
            print(f"\n  {model_name}:")
            for track in tracks:
                track_results = [r for r in all_results if r.track == track and r.model == model_name]
                if track_results:
                    track_correct = sum(1 for r in track_results if r.correct)
                    track_acc = track_correct / len(track_results)
                    print(f"    {track}: {track_acc:.1%} ({track_correct}/{len(track_results)})")

if __name__ == "__main__":
    main()
