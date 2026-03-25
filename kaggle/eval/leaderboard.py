#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Kaggle Leaderboard Helper

Generates submission files in the correct Kaggle format and provides
utilities for leaderboard analysis and comparison.

Features:
- Kaggle submission format validation
- Score prediction
- Leaderboard position estimation
- Historical tracking
"""

import os
import csv
import json
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from datetime import datetime


@dataclass
class LeaderboardEntry:
    """An entry on the Kaggle leaderboard."""
    rank: int
    team_name: str
    score: float
    submission_date: str


@dataclass
class SubmissionSummary:
    """Summary of a submission."""
    filename: str
    total_items: int
    mean_score: float
    min_score: float
    max_score: float
    std_score: float
    per_track_scores: Dict[str, float] = field(default_factory=dict)
    timestamp: str = ""


class KaggleLeaderboard:
    """
    Helper for Kaggle leaderboard operations.

    Usage:
        leaderboard = KaggleLeaderboard()
        leaderboard.validate_submission("submission.csv")
        leaderboard.predict_rank(mean_score=0.75)
    """

    # Expected Kaggle submission format
    REQUIRED_COLUMNS = ["id", "score"]
    KAGGLE_OUTPUT_DIR = "/kaggle/working"

    # Historical benchmarks (for prediction)
    BENCHMARK_SCORES = {
        "random": 0.0,
        "majority_class": 0.1,
        "baseline_heuristic": 0.3,
        "small_language_model": 0.5,
        "gpt_3.5_turbo": 0.65,
        "gpt_4": 0.75,
        "claude_3_opus": 0.78,
        "claude_3_sonnet": 0.72,
        "gemini_ultra": 0.76,
        "human_expert": 0.95
    }

    def __init__(self, data_dir: str = None):
        """
        Initialize the leaderboard helper.

        Args:
            data_dir: Directory containing submission files
        """
        self.data_dir = Path(data_dir or os.path.join(os.path.dirname(__file__), "..", "data"))
        self.submissions_dir = Path(self.KAGGLE_OUTPUT_DIR) if Path(self.KAGGLE_OUTPUT_DIR).exists() else Path(".")

    def validate_submission(self, submission_path: str) -> Tuple[bool, List[str]]:
        """
        Validate a submission file for Kaggle format.

        Args:
            submission_path: Path to submission CSV

        Returns:
            Tuple of (is_valid, list of error messages)
        """
        errors = []
        submission_path = Path(submission_path)

        if not submission_path.exists():
            return False, [f"File not found: {submission_path}"]

        try:
            with open(submission_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                rows = list(reader)

            # Check columns
            if set(reader.fieldnames) != set(self.REQUIRED_COLUMNS):
                errors.append(
                    f"Invalid columns. Expected: {self.REQUIRED_COLUMNS}, "
                    f"Got: {reader.fieldnames}"
                )

            # Check rows
            if len(rows) == 0:
                errors.append("No data rows found")

            # Check for required IDs
            ids = set(row.get("id", "") for row in rows)
            if len(ids) < len(rows):
                errors.append("Duplicate IDs found")

            # Check score ranges
            for i, row in enumerate(rows[:10]):  # Sample check
                try:
                    score = float(row.get("score", 0))
                    if score < -1.0 or score > 2.0:
                        errors.append(f"Score out of expected range at row {i}: {score}")
                except ValueError:
                    errors.append(f"Invalid score at row {i}: {row.get('score', '')}")

        except Exception as e:
            errors.append(f"Failed to read CSV: {e}")

        return len(errors) == 0, errors

    def generate_submission(
        self,
        results: List[Dict],
        output_path: str = "submission.csv"
    ) -> bool:
        """
        Generate a Kaggle submission file from results.

        Args:
            results: List of result dictionaries with 'id' and 'score'
            output_path: Output file path

        Returns:
            True if successful
        """
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            with open(output_path, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=self.REQUIRED_COLUMNS)
                writer.writeheader()

                for result in results:
                    writer.writerow({
                        "id": result.get("id", ""),
                        "score": result.get("score", result.get("phi_weighted_score", 0.0))
                    })

            print(f"✅ Submission saved: {output_path}")
            return True

        except Exception as e:
            print(f"❌ Failed to generate submission: {e}")
            return False

    def analyze_submission(self, submission_path: str) -> SubmissionSummary:
        """
        Analyze a submission file and return summary statistics.

        Args:
            submission_path: Path to submission CSV

        Returns:
            SubmissionSummary with statistics
        """
        submission_path = Path(submission_path)

        scores = []
        per_track = {}

        with open(submission_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                score = float(row.get("score", 0.0))
                scores.append(score)

                # Track by prefix (track)
                item_id = row.get("id", "")
                track = item_id.split("_")[0] if "_" in item_id else "unknown"
                if track not in per_track:
                    per_track[track] = []
                per_track[track].append(score)

        # Calculate statistics
        import statistics
        mean_score = statistics.mean(scores) if scores else 0.0
        min_score = min(scores) if scores else 0.0
        max_score = max(scores) if scores else 0.0
        std_score = statistics.stdev(scores) if len(scores) > 1 else 0.0

        # Calculate per-track means
        per_track_means = {
            track: statistics.mean(track_scores)
            for track, track_scores in per_track.items()
        }

        return SubmissionSummary(
            filename=submission_path.name,
            total_items=len(scores),
            mean_score=mean_score,
            min_score=min_score,
            max_score=max_score,
            std_score=std_score,
            per_track_scores=per_track_means,
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )

    def predict_rank(self, mean_score: float, total_competitors: int = 100) -> int:
        """
        Predict leaderboard rank based on score.

        Args:
            mean_score: Mean submission score
            total_competitors: Total number of competitors

        Returns:
            Predicted rank (1 is best)
        """
        # Simple prediction based on historical benchmarks
        # In reality, this would use actual leaderboard data

        if mean_score >= 0.8:
            percentile = 95  # Top 5%
        elif mean_score >= 0.75:
            percentile = 90  # Top 10%
        elif mean_score >= 0.7:
            percentile = 75  # Top 25%
        elif mean_score >= 0.6:
            percentile = 50  # Top half
        elif mean_score >= 0.5:
            percentile = 30  # Top third
        elif mean_score >= 0.3:
            percentile = 15  # Top third
        else:
            percentile = 5   # Bottom 5%

        predicted_rank = max(1, int(total_competitors * (100 - percentile) / 100))
        return predicted_rank

    def compare_to_benchmarks(self, mean_score: float) -> Dict[str, str]:
        """
        Compare score to known benchmarks.

        Args:
            mean_score: Mean submission score

        Returns:
            Dictionary with comparison results
        """
        comparisons = {}

        for benchmark, benchmark_score in self.BENCHMARK_SCORES.items():
            diff = mean_score - benchmark_score
            if diff > 0.05:
                status = "above"
            elif diff < -0.05:
                status = "below"
            else:
                status = "similar"

            comparisons[benchmark] = {
                "benchmark_score": benchmark_score,
                "difference": round(diff, 3),
                "status": status
            }

        return comparisons

    def print_leaderboard_prediction(
        self,
        summary: SubmissionSummary,
        total_competitors: int = 100
    ):
        """
        Print leaderboard prediction and comparisons.

        Args:
            summary: SubmissionSummary from analyze_submission
            total_competitors: Total competitors on leaderboard
        """
        print("\n" + "="*60)
        print("KAGGLE LEADERBOARD PREDICTION")
        print("="*60)

        print(f"\nSubmission: {summary.filename}")
        print(f"Items: {summary.total_items}")
        print(f"Mean Score: {summary.mean_score:.4f}")
        print(f"Score Range: [{summary.min_score:.4f}, {summary.max_score:.4f}]")
        print(f"Std Dev: {summary.std_score:.4f}")

        # Predict rank
        predicted_rank = self.predict_rank(summary.mean_score, total_competitors)
        percentile = (total_competitors - predicted_rank) / total_competitors * 100

        print(f"\nPredicted Rank: #{predicted_rank} / {total_competitors}")
        print(f"Percentile: Top {percentile:.1f}%")

        # Compare to benchmarks
        print(f"\nBenchmark Comparisons:")
        comparisons = self.compare_to_benchmarks(summary.mean_score)

        for benchmark, comp in comparisons.items():
            symbol = "↑" if comp["status"] == "above" else "↓" if comp["status"] == "below" else "≈"
            print(f"  {symbol} {benchmark:20s}: {comp['benchmark_score']:.2f} ({comp['difference']:+.3f})")

        print("="*60 + "\n")

    def create_submission_archive(self, submission_files: List[str], output_path: str = "submission_package.tar.gz"):
        """
        Create a tar.gz archive of all submission files.

        Args:
            submission_files: List of files to include
            output_path: Output archive path
        """
        import tarfile

        with tarfile.open(output_path, "w:gz") as tar:
            for file_path in submission_files:
                if Path(file_path).exists():
                    tar.add(file_path)
                    print(f"Added: {file_path}")
                else:
                    print(f"Warning: File not found: {file_path}")

        print(f"\n✅ Archive created: {output_path}")

    def get_historical_leaderboard(self, leaderboard_path: str = None) -> List[LeaderboardEntry]:
        """
        Load historical leaderboard data for comparison.

        Args:
            leaderboard_path: Path to leaderboard JSON file

        Returns:
            List of LeaderboardEntry
        """
        leaderboard_path = leaderboard_path or self.data_dir / "leaderboard.json"

        if not leaderboard_path.exists():
            # Create sample leaderboard
            return self._create_sample_leaderboard()

        with open(leaderboard_path, 'r') as f:
            data = json.load(f)

        return [
            LeaderboardEntry(
                rank=entry.get("rank", i+1),
                team_name=entry.get("team_name", "Unknown"),
                score=entry.get("score", 0.0),
                submission_date=entry.get("submission_date", "")
            )
            for i, entry in enumerate(data.get("entries", []))
        ]

    def _create_sample_leaderboard(self) -> List[LeaderboardEntry]:
        """Create a sample leaderboard for testing."""
        return [
            LeaderboardEntry(1, "Trinity Team", 0.82, "2026-03-20"),
            LeaderboardEntry(2, "AGI Lab", 0.79, "2026-03-19"),
            LeaderboardEntry(3, "DeepMind Fan", 0.75, "2026-03-18"),
            LeaderboardEntry(4, "Benchmark Bot", 0.65, "2026-03-17"),
            LeaderboardEntry(5, "GPT-4 Wrapper", 0.72, "2026-03-16"),
        ]


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Kaggle Leaderboard Helper"
    )

    parser.add_argument(
        "action",
        choices=["validate", "analyze", "predict", "archive"],
        help="Action to perform"
    )
    parser.add_argument(
        "--submission",
        help="Path to submission file"
    )
    parser.add_argument(
        "--output",
        help="Output file path"
    )
    parser.add_argument(
        "--competitors",
        type=int,
        default=100,
        help="Total number of competitors (for prediction)"
    )

    args = parser.parse_args()

    leaderboard = KaggleLeaderboard()

    if args.action == "validate":
        if not args.submission:
            print("Error: --submission required for validate action")
            return 1

        is_valid, errors = leaderboard.validate_submission(args.submission)

        if is_valid:
            print(f"✅ {args.submission} is valid!")
            return 0
        else:
            print(f"❌ Validation failed:")
            for error in errors:
                print(f"  - {error}")
            return 1

    elif args.action == "analyze":
        if not args.submission:
            print("Error: --submission required for analyze action")
            return 1

        summary = leaderboard.analyze_submission(args.submission)
        leaderboard.print_leaderboard_prediction(summary, args.competitors)
        return 0

    elif args.action == "predict":
        # Interactive score input
        try:
            score = float(input("Enter mean score: "))
            rank = leaderboard.predict_rank(score, args.competitors)
            percentile = (args.competitors - rank) / args.competitors * 100

            print(f"\nPredicted Rank: #{rank} / {args.competitors}")
            print(f"Percentile: Top {percentile:.1f}%")

            comparisons = leaderboard.compare_to_benchmarks(score)
            print("\nBenchmark Comparisons:")
            for benchmark, comp in comparisons.items():
                symbol = "↑" if comp["status"] == "above" else "↓" if comp["status"] == "below" else "≈"
                print(f"  {symbol} {benchmark}: {comp['benchmark_score']:.2f} ({comp['difference']:+.3f})")

        except (ValueError, KeyboardInterrupt):
            print("\nCancelled or invalid input")
            return 1

        return 0

    elif args.action == "archive":
        # Would need list of files to archive
        print("Archive action requires file list (not implemented)")
        return 1

    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
