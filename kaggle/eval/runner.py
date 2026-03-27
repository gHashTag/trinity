#!/usr/bin/env python3
"""
DeepMind AGI Hackathon — Minimal Benchmark Runner

A lightweight runner for the 5 cognitive tracks with:
- Ensemble mode (Pass@K)
- Temperature calibration
- Validation support

Author: Trinity Project
Date: 2026-03-27
"""

import os
import sys
import csv
import json
import random
import time
import math
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
from enum import Enum

# For numpy imports (try/except)
try:
    import numpy as np
except ImportError:
    np = None

# For imports from parent directory
sys.path.insert(0, str(Path(__file__).parent.parent))


class Track(Enum):
    """The 5 cognitive tracks."""
    LEARNING = "thlp"
    METACOGNITION = "tmp"
    ATTENTION = "tagp"
    EXECUTIVE = "tefb"
    SOCIAL = "tscp"


# Track configurations
TRACK_CONFIGS = {
    Track.LEARNING: {
        "name": "Hippocampal Learning Probe",
        "file": "data/thlp_learning.csv",
    },
    Track.METACOGNITION: {
        "name": "Trinity Metacognition Probe",
        "file": "data/tmp_metacognition.csv",
    },
    Track.ATTENTION: {
        "name": "Attentional Gateway Probe",
        "file": "data/tagp_attention.csv",
    },
    Track.EXECUTIVE: {
        "name": "Executive Function Battery",
        "file": "data/tefb_executive.csv",
    },
    Track.SOCIAL: {
        "name": "Social Cognition Probe",
        "file": "data/tscp_social.csv",
    }
}


@dataclass
class BenchmarkResult:
    """Result of running a single benchmark item."""
    item_id: str
    track: str
    task: str
    ground_truth: str
    response: str
    confidence: float
    raw_score: float
    ternary_score: int  # -1, 0, 1


@dataclass
class CalibrationResult:
    """Result of confidence calibration."""
    optimal_temperature: float
    ece_before: float
    ece_after: float


def calculate_nll(confidences: List[float], correct: List[bool], epsilon: float = 1e-15) -> float:
    """Calculate negative log-likelihood."""
    nll = 0.0
    for conf, corr in zip(confidences, correct):
        p = conf if corr else (1.0 - conf)
        nll += -math.log(max(p, epsilon))
    return nll / len(confidences)


def calculate_ece(confidences: List[float], correct: List[bool], n_bins: int = 10) -> float:
    """Calculate Expected Calibration Error."""
    # Bin confidences
    bin_edges = np.linspace(0, 1, n_bins + 1)
    bin_indices = np.digitize(confidences, bin_edges) - 1

    ece = 0.0
    for i in range(n_bins):
        # Find items in this bin
        mask = bin_indices == i
        if not np.any(mask):
            continue

        bin_confs = np.array(confidences)[mask]
        bin_corr = np.array(correct)[mask]
        bin_acc = bin_corr.mean()

        # Average confidence in bin
        avg_conf = bin_confs.mean()

        # Weighted by number of samples
        weight = len(bin_confs) / len(confidences)
        ece += weight * abs(avg_conf - bin_acc)

    return ece


def apply_temperature(confidences: List[float], T: float) -> List[float]:
    """Apply temperature scaling to confidences."""
    # Power transform: conf^(1/T)
    scaled = np.power(np.array(confidences), 1.0 / T)
    # Normalize if needed (for multi-class)
    return scaled.tolist()


def find_optimal_temperature(
    confidences: List[float],
    correct: List[bool],
    temperature_range: tuple = (0.1, 5.0),
    n_steps: int = 50
) -> CalibrationResult:
    """Find optimal temperature by grid search."""
    ece_before = calculate_ece(confidences, correct)
    nll_before = calculate_nll(confidences, correct)

    best_T = 1.0
    best_value = float('inf')

    # Grid search
    for i in range(n_steps + 1):
        T = temperature_range[0] + (temperature_range[1] - temperature_range[0]) * i / n_steps
        scaled = apply_temperature(confidences, T)
        nll = calculate_nll(scaled, correct)
        value = nll

        if value < best_value:
            best_value = value
            best_T = T

    # Calculate final metrics
    scaled_confidences = apply_temperature(confidences, best_T)
    ece_after = calculate_ece(scaled_confidences, correct)
    nll_after = calculate_nll(scaled_confidences, correct)

    return CalibrationResult(
        optimal_temperature=best_T,
        ece_before=ece_before,
        ece_after=ece_after,
        nll_before=nll_before,
        nll_after=nll_after
    )


@dataclass
class BenchmarkItem:
    """A single benchmark item."""
    id: str
    track: str
    task: str
    question: str
    ground_truth: str
    ground_truth_confidence: float = 0.5
    difficulty: float = 3.0
    brain_zone: str = ""
    neural_analog: str = ""


def load_items(track: Track, data_dir: Path = None) -> List[BenchmarkItem]:
    """Load benchmark items from CSV file."""
    if data_dir is None:
        data_dir = Path.cwd()

    config = TRACK_CONFIGS[track]
    csv_path = data_dir / config["file"]

    if not csv_path.exists():
        raise FileNotFoundError(f"Data file not found: {csv_path}")

    items = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Parse difficulty (may be empty or non-numeric)
            try:
                difficulty_val = float(row.get('difficulty', 3.0))
            except (ValueError, TypeError):
                difficulty_val = 3.0

            # Parse ground_truth_confidence
            gt_conf = row.get('ground_truth_confidence')
            if gt_conf is None:
                gt_conf = 0.5
            else:
                try:
                    gt_conf = float(gt_conf)
                except (ValueError, TypeError):
                    gt_conf = 0.5

            # Handle different column names for different tracks
            ground_truth = row.get('answer', row.get('ground_truth', ''))
            question = row.get('question', row.get('context', ''))

            items.append(BenchmarkItem(
                id=row['id'],
                track=track.value,
                task=row.get('task', 'unknown'),
                question=question,
                ground_truth=ground_truth,
                ground_truth_confidence=gt_conf,
                difficulty=difficulty_val,
                brain_zone=row.get('brain_zone', ''),
                neural_analog=row.get('neural_analog', '')
            ))

    return items


def score_response(response: str, ground_truth: str) -> tuple[float, int]:
    """Score a response against ground truth."""
    # Extract answer from response
    response_clean = response.strip()

    # Normalize ground truth
    gt_clean = ground_truth.strip()

    # Direct match
    if response_clean == gt_clean:
        return 1.0, 1  # Perfect

    # Partial match - check if ground truth is substring of response
    if gt_clean.lower() in response_clean.lower() or response_clean.lower() in gt_clean.lower():
        return 0.5, 0  # Partial

    # Wrong
    return 0.0, -1  # Wrong


def run_item(item: BenchmarkItem, dry_run: bool = True, seed: int = 42) -> BenchmarkResult:
    """Run a single benchmark item."""
    if dry_run:
        # Mock response for testing
        random.seed(seed + hash(item.id))

        if item.track == "tmp":
            # For metacognition, simulate model responses
            # Higher accuracy for testing (70% correct instead of 50%)
            if random.random() > 0.3:
                # Correct answer
                response = item.ground_truth
                confidence = random.uniform(0.7, 0.98)
            else:
                # Wrong answer - generate plausible wrong response
                wrong_responses = [
                    "I don't know the answer",
                    "I'm not certain",
                    "Could be anything"
                ]
                response = random.choice(wrong_responses)
                confidence = random.uniform(0.3, 0.6)
        else:
            # Mock response with some accuracy
            if random.random() > 0.2:
                # Correct answer
                response = item.ground_truth
                confidence = random.uniform(0.7, 0.98)
            else:
                # Wrong answer
                wrong_answers = ["A", "B", "C", "D", "True", "False"]
                response = random.choice(wrong_answers)
                confidence = random.uniform(0.3, 0.8)

        raw_score, ternary_score = score_response(response, item.ground_truth)

        return BenchmarkResult(
            item_id=item.id,
            track=item.track,
            task=item.task,
            ground_truth=item.ground_truth,
            response=response,
            confidence=confidence,
            raw_score=raw_score,
            ternary_score=ternary_score
        )


def run_track(
    track: Track,
    max_items: int = None,
    dry_run: bool = True,
    seed: int = 42
) -> List[BenchmarkResult]:
    """Run all items in a track."""
    config = TRACK_CONFIGS[track]
    print(f"\n{'='*60}")
    print(f"Running Track: {config['name']}")
    print(f"File: {config['file']}")
    print(f"{'='*60}")

    items = load_items(track)
    if max_items:
        items = items[:max_items]

    results = []
    start_time = time.time()

    for i, item in enumerate(items):
        print(f"[{i+1}/{len(items)}] {item.id[:30]}... ", end="", flush=True)

        try:
            result = run_item(item, dry_run=dry_run, seed=seed + i)
            results.append(result)

            score_emoji = "✓" if result.ternary_score == 1 else "✗"
            print(f"{score_emoji} score={result.ternary_score} ({result.raw_score:.2f})")

        except Exception as e:
            print(f"✗ error: {e}")
            continue

    elapsed = time.time() - start_time
    print(f"\nCompleted {len(results)}/{len(items)} items in {elapsed:.1f}s")

    # Calculate accuracy
    if results:
        ternary_scores = [r.ternary_score for r in results]
        accuracy = sum(ternary_scores) / len(ternary_scores)
        print(f"Track accuracy: {accuracy:.3f}\n")

    return results


def calibrate_results(
    results: List[BenchmarkResult],
    val_split: float = 0.2
) -> List[BenchmarkResult]:
    """Apply temperature calibration to results."""
    if not results:
        return results

    # Group by track for per-track calibration
    track_groups: Dict[str, List[BenchmarkResult]] = {}
    for r in results:
        if r.track not in track_groups:
            track_groups[r.track] = []
        track_groups[r.track].append(r)

    calibrated_results = []

    for track, track_results in track_groups.items():
        n_items = len(track_results)
        n_val = max(1, int(n_items * val_split))

        # Split into val/train
        val_results = track_results[:n_val]
        train_results = track_results[n_val:]

        # Extract calibration data from validation set
        val_confs = [r.confidence for r in val_results]
        val_correct = [r.ternary_score == 1 for r in val_results]

        # Find optimal temperature
        print(f"\nCalibrating {track} ({n_items} items, {n_val} validation)...")

        try:
            temp_result = find_optimal_temperature(val_confs, val_correct)
            T = temp_result.optimal_temperature
            print(f"  Optimal T = {T:.3f}")
            print(f"  ECE: {temp_result.ece_before:.4f} → {temp_result.ece_after:.4f}")
        except Exception as e:
            print(f"  ⚠️  Calibration failed: {e}")
            T = 1.0

        # Apply to all results in this track
        for r in track_results:
            calibrated_r = BenchmarkResult(
                item_id=r.item_id,
                track=r.track,
                task=r.task,
                ground_truth=r.ground_truth,
                response=r.response,
                confidence=apply_temperature([r.confidence], T)[0],
                raw_score=r.raw_score,
                ternary_score=r.ternary_score
            )
            calibrated_results.append(calibrated_r)

    return calibrated_results


def save_submission(
    results: List[BenchmarkResult],
    output_path: str = "submission.csv"
):
    """Save results in Kaggle submission format."""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    submission_data = [
        {
            "id": r.item_id,
            "confidence": round(r.confidence, 6),
            "answer": r.response[:100] if r.response else "",
            "track": r.track
        }
        for r in results
    ]

    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=["id", "confidence", "answer", "track"])
        writer.writeheader()
        writer.writerows(submission_data)

    print(f"✅ Submission saved to {output_path}")
    print(f"   {len(submission_data)} items")


def run_all(
    tracks: List[Track] = None,
    max_items_per_track: int = None,
    dry_run: bool = True,
    calibrate: bool = False,
    val_split: float = 0.2,
    output: str = "submission.csv"
):
    """Run all specified tracks."""
    if tracks is None:
        tracks = list(Track)

    all_results = []
    overall_start = time.time()

    print("\n" + "="*60)
    print("TRINITY COGNITIVE PROBES — MINIMAL BENCHMARK RUNNER")
    print("="*60)
    print(f"Tracks: {', '.join(t.value for t in tracks)}")
    print(f"Dry run: {dry_run}")
    print(f"Calibrate: {calibrate}")
    print("="*60 + "\n")

    for track in tracks:
        try:
            track_results = run_track(track, max_items_per_track, dry_run=dry_run)
            all_results.extend(track_results)

        except Exception as e:
            print(f"Error running track {track.value}: {e}")
            continue

    # Apply calibration if requested
    if calibrate and all_results:
        print("\n" + "="*60)
        print("APPLYING CALIBRATION")
        print("="*60 + "\n")
        all_results = calibrate_results(all_results, val_split)

    # Save results
    save_submission(all_results, output)

    overall_elapsed = time.time() - overall_start

    # Print summary
    print("\n" + "="*60)
    print("BENCHMARK COMPLETE")
    print("="*60)
    print(f"Total items: {len(all_results)}")
    print(f"Total time: {overall_elapsed:.1f}s")

    if all_results:
        ternary_scores = [r.ternary_score for r in all_results]
        mean_ternary = sum(ternary_scores) / len(ternary_scores)
        print(f"Mean ternary: {mean_ternary:.4f}")

    print("="*60 + "\n")

    return all_results


def main():
    parser = argparse.ArgumentParser(
        description="DeepMind AGI Hackathon — Minimal Benchmark Runner"
    )

    parser.add_argument(
        "--track",
        choices=["thlp", "tmp", "tagp", "tefb", "tscp", "all"],
        default="all",
        help="Track to run (default: all)"
    )
    parser.add_argument(
        "--max-items",
        type=int,
        help="Maximum items per track (for testing)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Generate mock responses (no API calls)"
    )
    parser.add_argument(
        "--calibrate",
        action="store_true",
        help="Apply temperature calibration"
    )
    parser.add_argument(
        "--val-split",
        type=float,
        default=0.2,
        help="Validation split for calibration (default: 0.2)"
    )
    parser.add_argument(
        "--output",
        default="submission.csv",
        help="Output submission file"
    )

    args = parser.parse_args()

    # Parse track selection
    if args.track == "all":
        tracks = None
    else:
        tracks = [Track(args.track)]

    # Run benchmarks
    try:
        run_all(
            tracks=tracks,
            max_items_per_track=args.max_items,
            dry_run=args.dry_run,
            calibrate=args.calibrate,
            val_split=args.val_split,
            output=args.output
        )

    except KeyboardInterrupt:
        print("\n\nBenchmark interrupted by user")

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
