#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Z.AI Claude Runner
Uses Z.AI API (Anthropic-compatible).
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

# Load .env files (both project root and kaggle directory)
project_env = Path(__file__).parent.parent / ".env"
kaggle_env = Path(__file__).parent / ".env"
load_dotenv(project_env)
load_dotenv(kaggle_env, override=True)

# Configuration
ZAI_API_KEY = os.getenv("ZAI_KEY_1", "")
ZAI_BASE_URL = "https://api.z.ai/api/anthropic"
MODEL = "claude-sonnet-4-20250514"

TRACKS = {
    "thlp": {"file": "data/thlp_learning.csv", "name": "Learning"},
    "tmp": {"file": "data/tmp_metacognition.csv", "name": "Metacognition"},
    "tagp": {"file": "data/tagp_attention.csv", "name": "Attention"},
    "tefb": {"file": "data/tefb_executive.csv", "name": "Executive"},
    "tscp": {"file": "data/tscp_social.csv", "name": "Social"},
}

RATE_LIMIT_DELAY = 2.0  # Conservative delay

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

def call_zai(prompt: str) -> tuple[str, float]:
    """Call Z.AI Claude via Anthropic-compatible API."""
    body = json.dumps({
        "model": MODEL,
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": prompt}]
    }, ensure_ascii=False)

    req = urllib.request.Request(
        f"{ZAI_BASE_URL}/v1/messages",
        data=body.encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-api-key": ZAI_API_KEY,
            "anthropic-version": "2023-06-01"
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode("utf-8"))
            if "content" in result and len(result["content"]) > 0:
                text = result["content"][0].get("text", "")
                return text, 0.8
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

def run_track(track: str, max_items: int = 50) -> List[BenchmarkResult]:
    """Run benchmark for a single track."""
    items = load_items(track)[:max_items]
    results = []

    for i, item in enumerate(items, 1):
        print(f"[{i}/{len(items)}] {item.id}...", end=" ", flush=True)
        start = time.time()

        response, confidence = call_zai(item.question)
        latency_ms = int((time.time() - start) * 1000)
        correct = evaluate_response(response, item.ground_truth)

        result = BenchmarkResult(
            item_id=item.id,
            track=track,
            model=MODEL,
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

def save_results(results: List[BenchmarkResult], track: str):
    """Save results to JSON file."""
    model_name = MODEL.replace("-", "_")
    output_path = Path(__file__).parent / "results" / f"{track}_{model_name}_results.json"
    data = [asdict(r) for r in results]
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"✅ Saved {len(results)} results to {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Run Z.AI Claude baselines")
    parser.add_argument("--track", choices=list(TRACKS.keys()), help="Single track")
    parser.add_argument("--max-items", type=int, default=50, help="Max items per track")
    parser.add_argument("--all", action="store_true", help="Run all tracks")
    args = parser.parse_args()

    tracks_to_run = list(TRACKS.keys()) if args.all else ([args.track] if args.track else [])
    if not tracks_to_run:
        print("Usage: python run_zai_baselines.py --all | --track <name>")
        print(f"Tracks: {', '.join(TRACKS.keys())}")
        return

    if not ZAI_API_KEY:
        print("❌ ZAI_KEY_1 not found in .env")
        return

    print(f"🚀 Running model: {MODEL}")
    print(f"Tracks: {', '.join(tracks_to_run)}")
    print(f"Max items: {args.max_items}")
    print()

    for track in tracks_to_run:
        print(f"{'='*60}")
        print(f"Track: {TRACKS[track]['name']} ({track})")
        print(f"{'='*60}")

        results = run_track(track, args.max_items)
        save_results(results, track)

        # Summary
        correct = sum(1 for r in results if r.correct)
        accuracy = correct / len(results) if results else 0
        avg_latency = sum(r.latency_ms for r in results) / len(results) if results else 0
        print(f"📊 Accuracy: {accuracy:.1%}, Avg latency: {avg_latency:.0f}ms")

if __name__ == "__main__":
    main()
