#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Free Models Batch Runner

Runs baseline evaluation using OpenRouter free models ($0, no API key).

Usage:
    # Pilot: 3 models × 50 items × 5 tracks = 750 requests
    python run_free_baselines.py --pilot

    # Full: All models × all items (overnight)
    python run_free_baselines.py --full

    # Specific model and track
    python run_free_baselines.py --model deepseek-r1 --track thlp --max-items 100
"""

import argparse
import csv
import json
import os
import sys
import time
import urllib.request
import urllib.error
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Dict, Any

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

# ============================================================================
# Configuration
# ============================================================================

OPENROUTER_FREE_MODELS = {
    "deepseek-r1": "deepseek/deepseek-r1:free",
    "qwen3-coder": "qwen/qwen3-coder-480b:free",
    "mimo-v2": "xiaomi/mimo-v2-flash:free",
    "gpt-oss": "openai/gpt-oss-120b:free",
    "llama-3.3": "meta-llama/llama-3.3-70b:free",
    "glm-4.5-air": "z-ai/glm-4.5-air:free",
    "nemotron": "nvidia/nemotron-3-super-120b:free",
}

TRACKS = {
    "thlp": {"file": "data/thlp_learning.csv", "name": "Learning"},
    "tmp": {"file": "data/tmp_metacognition.csv", "name": "Metacognition"},
    "tagp": {"file": "data/tagp_attention.csv", "name": "Attention"},
    "tefb": {"file": "data/tefb_executive.csv", "name": "Executive"},
    "tscp": {"file": "data/tscp_social.csv", "name": "Social"},
}

# Rate limiting: 20 RPM = 3.1 sec between requests
RATE_LIMIT_DELAY = 3.1

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
# Rate Limiter
# ============================================================================

class RateLimiter:
    """Simple rate limiter for API calls."""

    def __init__(self, requests_per_minute: int = 20):
        self.min_interval = 60.0 / requests_per_minute
        self.last_call = 0

    def wait(self):
        """Wait if needed to respect rate limit."""
        now = time.time()
        elapsed = now - self.last_call
        if elapsed < self.min_interval:
            sleep_time = self.min_interval - elapsed
            time.sleep(sleep_time)
        self.last_call = time.time()

# Global rate limiter
_rate_limiter = RateLimiter(requests_per_minute=20)

# ============================================================================
# OpenRouter Free Client
# ============================================================================

def call_free_model(model_id: str, prompt: str, temperature: float = 0.3) -> Dict[str, Any]:
    """
    Call OpenRouter free model (no API key required).

    Args:
        model_id: Full model ID (e.g., "deepseek/deepseek-r1:free")
        prompt: The prompt to send
        temperature: Sampling temperature

    Returns:
        Dict with: content, model, latency_ms, tokens_used
    """
    # Rate limiting
    _rate_limiter.wait()

    start_time = time.time()

    headers = {
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/gHashTag/trinity",
        "X-Title": "Trinity Cognitive Probes",
    }

    # Optional: Use API key if available (bypasses some limits)
    api_key = os.getenv("OPENROUTER_API_KEY", "")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    body = {
        "model": model_id,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 512,
        "temperature": temperature,
    }

    try:
        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            data=json.dumps(body).encode("utf-8"),
            headers=headers,
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode("utf-8"))

            content = result["choices"][0]["message"]["content"]

            return {
                "content": content,
                "model": result.get("model", model_id),
                "latency_ms": int((time.time() - start_time) * 1000),
                "tokens_used": result.get("usage", {}).get("total_tokens", 0),
            }

    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        raise RuntimeError(f"OpenRouter API error: {e.code} - {error_body}")

# ============================================================================
# Data Loading
# ============================================================================

def load_items(track: str, max_items: int = None, data_dir: Path = None) -> List[BenchmarkItem]:
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
            # Handle different column names for different tracks
            ground_truth = row.get('answer', row.get('ground_truth', row.get('expected_result', '')))
            question = row.get('question', row.get('context', ''))

            items.append(BenchmarkItem(
                id=row['id'],
                track=track,
                task=row.get('task', 'unknown'),
                question=question,
                ground_truth=ground_truth,
            ))

            if max_items and len(items) >= max_items:
                break

    return items

# ============================================================================
# Scoring
# ============================================================================

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
    match = re.search(r'[Cc]onfidence[:\s]+([0-9.]+)', response)
    if match:
        try:
            conf = float(match.group(1))
            return max(0.0, min(1.0, conf))
        except ValueError:
            pass

    # Default confidence
    return 0.5

# ============================================================================
# Evaluation
# ============================================================================

def evaluate_item(item: BenchmarkItem, model_name: str, model_id: str) -> BenchmarkResult:
    """Evaluate a single benchmark item."""
    # Build prompt
    prompt = f"""{item.question}

Provide your answer followed by your confidence level (0.0 to 1.0).

Format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

    # Call model
    result = call_free_model(model_id, prompt)

    # Extract answer (before "Confidence:" line)
    response = result["content"]
    lines = response.split('\n')
    answer_lines = []
    for line in lines:
        if 'confidence:' in line.lower():
            break
        answer_lines.append(line)
    answer = '\n'.join(answer_lines).strip()

    # Score
    correct = score_response(answer, item.ground_truth)
    confidence = extract_confidence(response)

    return BenchmarkResult(
        item_id=item.id,
        track=item.track,
        model=model_name,
        response=answer[:100],  # Truncate for submission
        ground_truth=item.ground_truth,
        confidence=confidence,
        correct=correct,
        latency_ms=result["latency_ms"],
    )

def evaluate_track(
    track: str,
    model_name: str,
    model_id: str,
    max_items: int = None,
    output_dir: Path = None
) -> List[BenchmarkResult]:
    """Evaluate all items in a track."""
    if output_dir is None:
        output_dir = Path(__file__).parent / "results"

    output_dir.mkdir(parents=True, exist_ok=True)

    track_config = TRACKS[track]
    print(f"\n{'='*60}")
    print(f"Track: {track_config['name']} ({track})")
    print(f"Model: {model_name}")
    print(f"{'='*60}")

    items = load_items(track, max_items)
    print(f"Loaded {len(items)} items")

    results = []
    start_time = time.time()
    correct_count = 0

    for i, item in enumerate(items):
        print(f"[{i+1}/{len(items)}] {item.id[:30]}... ", end="", flush=True)

        try:
            result = evaluate_item(item, model_name, model_id)
            results.append(result)

            if result.correct:
                correct_count += 1
                print(f"✓ {result.latency_ms}ms")
            else:
                print(f"✗ {result.latency_ms}ms")

        except Exception as e:
            print(f"✗ error: {e}")
            continue

    elapsed = time.time() - start_time
    accuracy = correct_count / len(results) if results else 0

    print(f"\nCompleted {len(results)}/{len(items)} items in {elapsed:.1f}s")
    print(f"Accuracy: {accuracy:.3f} ({correct_count}/{len(results)})")

    # Save results
    output_file = output_dir / f"{track}_{model_name}_results.json"
    with open(output_file, 'w') as f:
        json.dump([asdict(r) for r in results], f, indent=2)
    print(f"Results saved to {output_file}")

    return results

def evaluate_all_tracks(
    model_name: str,
    max_items_per_track: int = None,
    output_dir: Path = None
) -> Dict[str, List[BenchmarkResult]]:
    """Evaluate all tracks for a model."""
    model_id = OPENROUTER_FREE_MODELS[model_name]
    all_results = {}

    for track in TRACKS.keys():
        try:
            results = evaluate_track(track, model_name, model_id, max_items_per_track, output_dir)
            all_results[track] = results
        except Exception as e:
            print(f"Error evaluating track {track}: {e}")
            continue

    return all_results

def save_submission(results: List[BenchmarkResult], output_path: str):
    """Save results in Kaggle submission format."""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    submission_data = [
        {
            "id": r.item_id,
            "confidence": round(r.confidence, 6),
            "answer": r.response,
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

# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Free Models Batch Runner"
    )

    parser.add_argument(
        "--model",
        choices=list(OPENROUTER_FREE_MODELS.keys()),
        help="Specific model to run (default: all for pilot, all for full)"
    )
    parser.add_argument(
        "--track",
        choices=list(TRACKS.keys()) + ["all"],
        default="all",
        help="Track to run (default: all)"
    )
    parser.add_argument(
        "--max-items",
        type=int,
        help="Maximum items per track"
    )
    parser.add_argument(
        "--pilot",
        action="store_true",
        help="Run pilot: 3 models × 50 items × 5 tracks"
    )
    parser.add_argument(
        "--full",
        action="store_true",
        help="Run full: All models × all items"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).parent / "results",
        help="Output directory for results"
    )

    args = parser.parse_args()

    # Determine models to run
    if args.model:
        models = [args.model]
    elif args.pilot:
        # Pilot: 3 fastest models
        models = ["mimo-v2", "llama-3.3", "glm-4.5-air"]
    elif args.full:
        models = list(OPENROUTER_FREE_MODELS.keys())
    else:
        models = ["mimo-v2"]  # Default: single fastest model

    # Determine max items
    if args.max_items:
        max_items = args.max_items
    elif args.pilot:
        max_items = 50
    else:
        max_items = None  # All items

    # Determine tracks
    if args.track == "all":
        tracks = list(TRACKS.keys())
    else:
        tracks = [args.track]

    print("\n" + "="*60)
    print("TRINITY COGNITIVE PROBES — FREE MODELS RUNNER")
    print("="*60)
    print(f"Models: {', '.join(models)}")
    print(f"Tracks: {', '.join(tracks)}")
    print(f"Max items per track: {max_items or 'all'}")
    print(f"Rate limit: {RATE_LIMIT_DELAY}s between requests (20 RPM)")
    print("="*60 + "\n")

    # Run evaluation
    all_results = []
    overall_start = time.time()

    for model in models:
        print(f"\n🚀 Running model: {model}")
        model_id = OPENROUTER_FREE_MODELS[model]

        for track in tracks:
            try:
                results = evaluate_track(track, model, model_id, max_items, args.output_dir)
                all_results.extend(results)
            except Exception as e:
                print(f"Error evaluating {track} with {model}: {e}")
                continue

    overall_elapsed = time.time() - overall_start

    # Summary
    print("\n" + "="*60)
    print("BENCHMARK COMPLETE")
    print("="*60)
    print(f"Total results: {len(all_results)}")
    print(f"Total time: {overall_elapsed:.1f}s ({overall_elapsed/60:.1f} minutes)")

    if all_results:
        correct = sum(1 for r in all_results if r.correct)
        accuracy = correct / len(all_results)
        print(f"Overall accuracy: {accuracy:.3f} ({correct}/{len(all_results)})")

        # Per-track summary
        print("\nPer-track accuracy:")
        for track in tracks:
            track_results = [r for r in all_results if r.track == track]
            if track_results:
                track_correct = sum(1 for r in track_results if r.correct)
                track_acc = track_correct / len(track_results)
                print(f"  {track}: {track_acc:.3f} ({track_correct}/{len(track_results)})")

    # Save combined submission
    if all_results:
        submission_path = args.output_dir / "submission.csv"
        save_submission(all_results, submission_path)

    print("="*60 + "\n")

if __name__ == "__main__":
    main()
