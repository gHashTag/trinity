#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Unified CLI

Command-line interface for:
- Scientific metrics evaluation
- Benchmark running
- Result analysis and visualization

Usage:
    python -m kaggle.cli --metric minkpp --input results.json --vocab-size 50000
    python -m kaggle.cli --metric codec --input results.json
    python -m kaggle.cli --metric ece --input results.json --bins 15
    python -m kaggle.cli --run-benchmark --track thlp --dry-run
"""

import sys
import json
import argparse
import csv
from pathlib import Path
from typing import List, Dict, Any, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.metrics import (
    ScientificMetrics,
    RECOMMENDED_VERSION,
    VERSION_INFO,
    compare_versions
)


def load_json_data(input_path: str) -> Dict[str, Any]:
    """Load data from JSON file."""
    path = Path(input_path)
    if not path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    with open(path, 'r') as f:
        return json.load(f)


def save_json(data: Dict[str, Any], output_path: str):
    """Save data to JSON file."""
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)


def print_result(metric_name: str, result: Any, verbose: bool = False):
    """Print metric result in a formatted way."""
    print(f"\n{'='*60}")
    print(f"{metric_name} Result")
    print(f"{'='*60}")

    if hasattr(result, '__dataclass_fields__'):
        # It's a dataclass
        for field, value in result.__dict__.items():
            if isinstance(value, float):
                print(f"  {field}: {value:.4f}")
            elif isinstance(value, list) and len(value) > 10:
                print(f"  {field}: [{len(value)} items]")
            else:
                print(f"  {field}: {value}")
    elif isinstance(result, dict):
        for key, value in result.items():
            if isinstance(value, float):
                print(f"  {key}: {value:.4f}")
            elif isinstance(value, list) and len(value) > 10:
                print(f"  {key}: [{len(value)} items]")
            else:
                print(f"  {key}: {value}")
    else:
        print(f"  {result}")

    print(f"{'='*60}\n")


def cmd_minkpp(args: argparse.Namespace):
    """Run Min-K%++ contamination detection."""
    data = load_json_data(args.input)

    # Extract log probabilities
    if "log_probabilities" in data:
        log_probs = data["log_probabilities"]
    elif "logprobs" in data:
        log_probs = data["logprobs"]
    elif "log_probs" in data:
        log_probs = data["log_probs"]
    else:
        # Try to find in nested structure
        log_probs = data.get("predictions", {}).get("log_probabilities", [])

    vocab_size = args.vocab_size or data.get("vocab_size", 50000)

    metrics = ScientificMetrics(version=args.version)
    result = metrics.detect_contamination_mink_pp(
        log_probabilities=log_probs,
        vocab_size=vocab_size,
        k_percent=args.k_percent,
        statistical_threshold=args.threshold
    )

    print_result("Min-K%++ Contamination Detection", result, args.verbose)

    if args.output:
        save_json({"mink_pp": result.__dict__}, args.output)
        print(f"Result saved to {args.output}")

    return 0 if not result.is_contaminated else 1


def cmd_codec(args: argparse.Namespace):
    """Run CoDeC contamination detection."""
    data = load_json_data(args.input)

    # Extract labels and confidence drops
    true_labels = data.get("true_labels", data.get("labels", []))
    confidence_drops = data.get("confidence_drops", data.get("conf_drops", []))

    if not true_labels or not confidence_drops:
        raise ValueError("Input must contain 'true_labels' and 'confidence_drops'")

    metrics = ScientificMetrics(version=args.version)
    result = metrics.detect_contamination_codec(
        true_labels=true_labels,
        confidence_drops=confidence_drops
    )

    print_result("CoDeC Contamination Detection", result, args.verbose)

    if args.output:
        save_json({"codec": result.__dict__}, args.output)
        print(f"Result saved to {args.output}")

    return 0 if not result.is_contaminated else 1


def cmd_ece(args: argparse.Namespace):
    """Run Expected Calibration Error calculation."""
    data = load_json_data(args.input)

    confidences = data.get("confidences", [])
    correct_indices = data.get("correct_token_indices", data.get("correct_indices", []))

    if not confidences or not correct_indices:
        raise ValueError("Input must contain 'confidences' and 'correct_token_indices'")

    vocab_size = args.vocab_size or data.get("vocab_size", None)

    metrics = ScientificMetrics(version=args.version)
    result = metrics.calculate_full_ece(
        confidences=confidences,
        correct_token_indices=correct_indices,
        n_bins=args.bins,
        vocab_size=vocab_size
    )

    print_result("Full-ECE Calibration", result, args.verbose)

    if args.output:
        save_json({"full_ece": result.__dict__}, args.output)
        print(f"Result saved to {args.output}")

    return 0


def cmd_classwise_ece(args: argparse.Namespace):
    """Run class-wise ECE calculation."""
    data = load_json_data(args.input)

    confidences = data.get("confidences", [])
    predictions = data.get("predictions", data.get("preds", []))
    labels = data.get("labels", data.get("true_labels", []))
    n_classes = args.n_classes or data.get("n_classes", 2)

    metrics = ScientificMetrics(version=args.version)
    result = metrics.calculate_classwise_ece(
        confidences=confidences,
        predictions=predictions,
        labels=labels,
        n_classes=n_classes,
        n_bins=args.bins
    )

    print_result("Class-wise ECE", result, args.verbose)

    if args.output:
        save_json({"classwise_ece": result.__dict__}, args.output)
        print(f"Result saved to {args.output}")

    return 0


def cmd_distribution_shift(args: argparse.Namespace):
    """Run distribution shift detection."""
    data = load_json_data(args.input)

    source_confs = data.get("source_confidences", data.get("train_confidences", []))
    target_confs = data.get("target_confidences", data.get("test_confidences", []))

    metrics = ScientificMetrics(version=args.version)
    result = metrics.detect_distribution_shift(
        source_confidences=source_confs,
        target_confidences=target_confs,
        threshold=args.threshold
    )

    print_result("Distribution Shift Detection", result, args.verbose)

    if args.output:
        save_json({"distribution_shift": result.__dict__}, args.output)
        print(f"Result saved to {args.output}")

    return 0


def cmd_all(args: argparse.Namespace):
    """Run all available metrics."""
    data = load_json_data(args.input)

    metrics = ScientificMetrics(version=args.version)
    results = metrics.run_all_metrics(data)

    print(f"\n{'='*60}")
    print(f"All Metrics Results ({args.version})")
    print(f"{'='*60}")

    for metric_name, result in results.items():
        if "error" in result:
            print(f"\n{metric_name}: ERROR - {result['error']}")
        else:
            print(f"\n{metric_name}:")
            for key, value in result.items():
                if isinstance(value, float):
                    print(f"  {key}: {value:.4f}")
                else:
                    print(f"  {key}: {value}")

    print(f"\n{'='*60}\n")

    if args.output:
        save_json(results, args.output)
        print(f"Results saved to {args.output}")

    return 0


def cmd_compare(args: argparse.Namespace):
    """Compare results across metric versions."""
    data = load_json_data(args.input)

    versions = args.versions or ["v5", "v6"]
    results = compare_versions(data, versions)

    print(f"\n{'='*60}")
    print("Version Comparison")
    print(f"{'='*60}")

    for version, result in results.items():
        print(f"\n{version}:")
        if "error" in result:
            print(f"  ERROR: {result['error']}")
        else:
            for metric_name, metric_result in result.items():
                print(f"  {metric_name}: {metric_result}")

    print(f"\n{'='*60}\n")

    if args.output:
        save_json(results, args.output)
        print(f"Comparison saved to {args.output}")

    return 0


def cmd_list_metrics(args: argparse.Namespace):
    """List all available metrics."""
    print(f"\n{'='*60}")
    print("Available Metrics by Version")
    print(f"{'='*60}\n")

    for version in ["v3", "v4", "v5", "v6"]:
        info = VERSION_INFO[version]
        recommended = " (RECOMMENDED)" if info.is_recommended else ""
        print(f"{version}: {info.description}{recommended}")

        metrics = ScientificMetrics(version=version)
        available = metrics.list_available_metrics()

        for metric_name, is_available in available.items():
            status = "  ✓" if is_available else "  ✗"
            print(f"{status} {metric_name}")

        print()

    print(f"{'='*60}\n")
    return 0


def cmd_run_benchmark(args: argparse.Namespace):
    """Run benchmark using runner module."""
    from eval.runner import BenchmarkRunner, Track

    # Parse track
    track_map = {
        "thlp": Track.LEARNING,
        "tmp": Track.METACOGNITION,
        "tagp": Track.ATTENTION,
        "tefb": Track.EXECUTIVE,
        "tscp": Track.SOCIAL
    }

    if args.track == "all":
        tracks = None
    else:
        tracks = [track_map[args.track]]

    # Create runner
    runner = BenchmarkRunner(
        data_dir=args.data_dir,
        dry_run=args.dry_run,
        seed=args.seed
    )

    # Run benchmark
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

    return 0


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Unified CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Min-K%++ contamination detection
  python -m kaggle.cli --metric minkpp --input results.json --vocab-size 50000

  # CoDeC contamination detection
  python -m kaggle.cli --metric codec --input results.json

  # Full-ECE calibration
  python -m kaggle.cli --metric ece --input results.json --bins 15

  # Run all metrics
  python -m kaggle.cli --metric all --input results.json --output metrics.json

  # Compare versions
  python -m kaggle.cli --metric compare --input results.json --versions v5 v6

  # List available metrics
  python -m kaggle.cli --metric list

  # Run benchmark
  python -m kaggle.cli --run-benchmark --track thlp --dry-run
        """
    )

    parser.add_argument(
        "--metric",
        choices=["minkpp", "codec", "ece", "classwise-ece", "shift", "all", "compare", "list"],
        help="Metric to run or action"
    )

    parser.add_argument(
        "--run-benchmark",
        action="store_true",
        help="Run benchmark instead of metrics"
    )

    # Input/Output
    parser.add_argument("--input", "-i", help="Input JSON file")
    parser.add_argument("--output", "-o", help="Output JSON file")

    # Metric options
    parser.add_argument("--version", "-v", default=RECOMMENDED_VERSION,
                        choices=["v3", "v4", "v5", "v6"],
                        help=f"Metrics version (default: {RECOMMENDED_VERSION})")
    parser.add_argument("--vocab-size", type=int, help="Vocabulary size")
    parser.add_argument("--k-percent", type=float, default=5.0,
                        help="K%% for Min-K%%++ (default: 5.0)")
    parser.add_argument("--threshold", type=float, default=0.05,
                        help="Statistical threshold (default: 0.05)")
    parser.add_argument("--bins", type=int, default=10,
                        help="Number of bins for ECE (default: 10)")
    parser.add_argument("--n-classes", type=int, default=2,
                        help="Number of classes (default: 2)")
    parser.add_argument("--versions", nargs="+", choices=["v3", "v4", "v5", "v6"],
                        help="Versions to compare")

    # Benchmark options
    parser.add_argument("--track", choices=["thlp", "tmp", "tagp", "tefb", "tscp", "all"],
                        default="all", help="Track to run")
    parser.add_argument("--data-dir", help="Data directory")
    parser.add_argument("--max-items", type=int, help="Max items per track")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")

    # Common options
    parser.add_argument("--dry-run", action="store_true", help="Dry run (no API calls)")
    parser.add_argument("--detailed", action="store_true", help="Save detailed results")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")

    args = parser.parse_args()

    # Route to appropriate command
    if args.run_benchmark:
        return cmd_run_benchmark(args)

    if args.metric == "minkpp":
        return cmd_minkpp(args)
    elif args.metric == "codec":
        return cmd_codec(args)
    elif args.metric == "ece":
        return cmd_ece(args)
    elif args.metric == "classwise-ece":
        return cmd_classwise_ece(args)
    elif args.metric == "shift":
        return cmd_distribution_shift(args)
    elif args.metric == "all":
        return cmd_all(args)
    elif args.metric == "compare":
        return cmd_compare(args)
    elif args.metric == "list":
        return cmd_list_metrics(args)
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
