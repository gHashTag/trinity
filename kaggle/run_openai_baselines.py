#!/usr/bin/env python3
"""
Trinity Cognitive Probes — OpenAI GPT-4o Runner
Uses MODEL_PROXY_URL from .env for API calls.
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
from dotenv import load_dotenv

# Load .env
load_dotenv()

# Configuration
MODEL_PROXY_URL = os.getenv("MODEL_PROXY_URL", "https://api.openai.com/v1")
MODEL_PROXY_API_KEY = os.getenv("MODEL_PROXY_API_KEY", "")
LLM_DEFAULT = os.getenv("LLM_DEFAULT", "gpt-4o")

TRACKS = {
    "thlp": {"file": "data/thlp_learning.csv", "name": "Learning"},
    "tmp": {"file": "data/tmp_metacognition.csv", "name": "Metacognition"},
    "tagp": {"file": "data/tagp_attention.csv", "name": "Attention"},
    "tefb": {"file": "data/tefb_executive.csv", "name": "Executive"},
    "tscp": {"file": "data/tscp_social.csv", "name": "Social"},
}

RATE_LIMIT_DELAY = 1.0  # OpenAI allows more requests

@dataclass
class BenchmarkItem:
    id: str
    track: str
    task: str
    question: str
    ground_truth: str

@dataclass
class BenchmarkResult:
    item_id: str
    track: str
    model: str
    response: str
    ground_truth: str
    confidence: float
    correct: bool
    latency_ms: int

def load_items(track: str, data_dir: Path = None) -> List[BenchmarkItem]:
    if data_dir is None:
        data_dir = Path(__file__).parent
    csv_path = data_dir / TRACKS[track]["file"]
    items = []
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            items.append(BenchmarkItem(
                id=row.get('id', f"{track}_{hash(row['question']) & 0x7FFFFFFF}"),
                track=track,
                task=row.get('task', 'unknown'),
                question=row['question'],
                ground_truth=row['answer']
            ))
    return items

def call_openai(prompt: str, model: str = LLM_DEFAULT) -> tuple[str, float]:
    """Call OpenAI-compatible API via MODEL_PROXY_URL."""
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 512,
        "temperature": 0.7
    }, ensure_ascii=False)

    req = urllib.request.Request(
        f"{MODEL_PROXY_URL}/chat/completions",
        data=body.encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {MODEL_PROXY_API_KEY}"
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode("utf-8"))
            if "choices" in result and len(result["choices"]) > 0:
                text = result["choices"][0]["message"]["content"]
                return text, 0.8  # Default confidence
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")[:500]
        print(f"⚠️  API Error {e.code}: {error_body}")
    except Exception as e:
        print(f"⚠️  Error: {e}")

    return "", 0.5

def evaluate_response(response: str, ground_truth: str) -> bool:
    """Check if response is correct."""
    response_lower = response.lower()
    gt_lower = ground_truth.lower()
    return gt_lower in response_lower

def run_track(track: str, model: str, max_items: int = 50) -> List[BenchmarkResult]:
    """Run benchmark for a single track."""
    items = load_items(track)[:max_items]
    results = []

    for i, item in enumerate(items, 1):
        print(f"[{i}/{len(items)}] {item.id}...", end=" ", flush=True)
        start = time.time()

        response, confidence = call_openai(item.question, model)
        latency_ms = int((time.time() - start) * 1000)
        correct = evaluate_response(response, item.ground_truth)

        result = BenchmarkResult(
            item_id=item.id,
            track=track,
            model=model,
            response=response,
            ground_truth=item.ground_truth,
            confidence=confidence,
            correct=correct,
            latency_ms=latency_ms
        )
        results.append(result)

        status = "✓" if correct else "✗"
        print(f"{status} {latency_ms}ms")

        time.sleep(RATE_LIMIT_DELAY)

    return results

def save_results(results: List[BenchmarkResult], output_path: Path):
    """Save results to JSON file."""
    data = [asdict(r) for r in results]
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"✅ Saved {len(results)} results to {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Run OpenAI baselines")
    parser.add_argument("--track", choices=list(TRACKS.keys()), help="Single track")
    parser.add_argument("--max-items", type=int, default=50, help="Max items per track")
    parser.add_argument("--model", default=LLM_DEFAULT, help="Model name")
    parser.add_argument("--all", action="store_true", help="Run all tracks")
    args = parser.parse_args()

    tracks_to_run = list(TRACKS.keys()) if args.all else ([args.track] if args.track else [])
    if not tracks_to_run:
        print("Usage: python run_openai_baselines.py --all | --track <name>")
        print(f"Tracks: {', '.join(TRACKS.keys())}")
        return

    print(f"🚀 Running model: {args.model}")
    print(f"Tracks: {', '.join(tracks_to_run)}")
    print(f"Max items: {args.max_items}")
    print()

    for track in tracks_to_run:
        print(f"{'='*60}")
        print(f"Track: {TRACKS[track]['name']} ({track})")
        print(f"{'='*60}")

        results = run_track(track, args.model, args.max_items)

        output_path = Path(__file__).parent / "results" / f"{track}_{args.model.replace('/', '_')}_results.json"
        save_results(results, output_path)

        # Summary
        correct = sum(1 for r in results if r.correct)
        accuracy = correct / len(results) if results else 0
        avg_latency = sum(r.latency_ms for r in results) / len(results) if results else 0
        print(f"📊 Accuracy: {accuracy:.1%}, Avg latency: {avg_latency:.0f}ms")

if __name__ == "__main__":
    main()
