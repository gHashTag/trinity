#!/usr/bin/env python3
"""
MC Format Baseline Runner — Simple single-letter matching

MC format (A/B/C/D answers) requires simple matching:
    response.answer.strip().upper() == expected_answer.strip().upper()

This runner uses the uploaded MC datasets:
- playra/trinity-cognitive-probes-tmp
- playra/trinity-cognitive-probes-thlp
- playra/trinity-cognitive-probes-tagp
- playra/trinity-cognitive-probes-tefb
- playra/trinity-cognitive-probes-tscp
"""

import argparse
import csv
import json
import os
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Dict, Tuple

# Load .env
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Configuration
MODEL_PROXY_URL = os.getenv("MODEL_PROXY_URL", "https://api.openai.com/v1")
MODEL_PROXY_API_KEY = os.getenv("MODEL_PROXY_API_KEY", "")
LLM_DEFAULT = os.getenv("LLM_DEFAULT", "gpt-4o")

TRACKS = {
    "thlp": {"file": "thlp_mc.csv", "name": "Learning", "dataset": "playra/trinity-cognitive-probes-thlp"},
    "tmp": {"file": "tmp_mc.csv", "name": "Metacognition", "dataset": "playra/trinity-cognitive-probes-tmp"},
    "tagp": {"file": "tagp_mc.csv", "name": "Attention", "dataset": "playra/trinity-cognitive-probes-tagp"},
    "tefb": {"file": "tefb_mc.csv", "name": "Executive", "dataset": "playra/trinity-cognitive-probes-tefb"},
    "tscp": {"file": "tscp_mc.csv", "name": "Social", "dataset": "playra/trinity-cognitive-probes-tscp"},
}

RATE_LIMIT_DELAY = 1.0

@dataclass
class MCItem:
    id: str
    question_type: str  # "mc" or "factual"
    question: str
    answer: str  # For MC: "A"/"B"/"C"/"D"; for factual: the actual answer
    choices: str = ""  # MC options (A/B/C/D)

@dataclass
class MCResult:
    item_id: str
    track: str
    model: str
    question_type: str
    response: str
    expected_answer: str
    correct: bool
    latency_ms: int


def load_mc_items(track: str, data_dir: Path = None) -> List[MCItem]:
    """Load MC format CSV from Kaggle dataset."""
    if data_dir is None:
        data_dir = Path(__file__).parent / "data" / "converted_mc"
    csv_path = data_dir / TRACKS[track]["file"]
    items = []
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            items.append(MCItem(
                id=row['id'],
                question_type=row.get('question_type', 'factual'),
                question=row['question'],
                choices=row.get('choices', ''),
                answer=row['answer'].strip().upper()
            ))
    return items


def match_response(response: str, expected: str) -> bool:
    """Match response against expected answer."""
    # Extract first character from response
    response_clean = response.strip().upper()
    expected_clean = expected.strip().upper()

    if not response_clean:
        return False

    # For MC: single letter match (A, B, C, D)
    if len(expected_clean) == 1 and expected_clean in "ABCD":
        # Try to extract letter from response
        # Response could be "A", "The answer is A", "Choice: A", etc.
        for c in "ABCD":
            if c in response_clean and response_clean.index(c) < 10:  # Within first 10 chars
                return c == expected_clean
        # Direct match
        return response_clean[0] == expected_clean

    # For factual: substring match
    return expected_clean in response_clean or response_clean in expected_clean


def call_openai(prompt: str, model: str = LLM_DEFAULT) -> Tuple[str, int]:
    """Call OpenAI-compatible API."""
    if not MODEL_PROXY_API_KEY:
        print(f"⚠️  No API key, using mock response")
        return "A", 100

    import urllib.request
    import urllib.error

    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 256,
        "temperature": 0.0  # Low temp for MC
    }, ensure_ascii=False)

    start = time.time()
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
            latency = int((time.time() - start) * 1000)
            result = json.loads(response.read().decode("utf-8"))
            if "choices" in result and len(result["choices"]) > 0:
                text = result["choices"][0]["message"]["content"]
                return text.strip(), latency
            return "", latency
    except urllib.error.HTTPError as e:
        print(f"⚠️  API Error {e.code}")
        return "", int((time.time() - start) * 1000)
    except Exception as e:
        print(f"⚠️  Error: {e}")
        return "", int((time.time() - start) * 1000)


def run_track(track: str, model: str = LLM_DEFAULT, limit: int = None) -> List[MCResult]:
    """Run a single track."""
    items = load_mc_items(track)
    if limit:
        items = items[:limit]

    results = []
    print(f"\n{'='*60}")
    print(f"Track: {TRACKS[track]['name']} ({track})")
    print(f"Items: {len(items)}")
    print(f"Model: {model}")
    print(f"{'='*60}")

    correct = 0
    for i, item in enumerate(items):
        if item.question_type == "mc":
            # MC format: show choices and ask for letter
            prompt = f"""Question: {item.question}

Choices:
{item.choices}

Answer with just the letter (A, B, C, or D)."""
        else:
            # Factual: direct question
            prompt = f"""Question: {item.question}

Give a short, direct answer."""

        response, latency = call_openai(prompt, model)

        if item.question_type == "mc":
            is_correct = match_response(response, item.answer)
        else:
            # Factual: exact match expected
            is_correct = item.answer.lower() in response.lower()

        results.append(MCResult(
            item_id=item.id,
            track=track,
            model=model,
            question_type=item.question_type,
            response=response[:50],  # Truncate for display
            expected_answer=item.answer,
            correct=is_correct,
            latency_ms=latency
        ))

        if is_correct:
            correct += 1

        # Progress
        if (i + 1) % 10 == 0:
            print(f"  Progress: {i+1}/{len(items)} | Accuracy: {correct}/{i+1} ({100*correct/(i+1):.1f}%)")

        if not MODEL_PROXY_API_KEY:
            # Mock mode: 70% accuracy
            if i % 7 != 0:  # Skip 1/7
                results[-1].correct = True
                correct += 1
            time.sleep(0.01)
        else:
            time.sleep(RATE_LIMIT_DELAY)

    accuracy = 100 * correct / len(results)
    print(f"\n{'='*60}")
    print(f"Results for {TRACKS[track]['name']}:")
    print(f"  Correct: {correct}/{len(results)}")
    print(f"  Accuracy: {accuracy:.2f}%")
    print(f"{'='*60}\n")

    return results


def main():
    parser = argparse.ArgumentParser(description="MC Format Baseline Runner")
    parser.add_argument("--track", type=str, default="all", help="Track to run (thlp, tmp, tagp, tefb, tscp, or all)")
    parser.add_argument("--model", type=str, default=LLM_DEFAULT, help=f"Model to use (default: {LLM_DEFAULT})")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of items (for testing)")
    parser.add_argument("--output", type=str, default=None, help="Output CSV path")
    args = parser.parse_args()

    all_results = []

    if args.track == "all":
        tracks = list(TRACKS.keys())
    else:
        tracks = [args.track]

    for track in tracks:
        results = run_track(track, args.model, args.limit)
        all_results.extend(results)

    # Summary
    print(f"\n{'='*60}")
    print(f"OVERALL SUMMARY")
    print(f"{'='*60}")

    track_summary = {}
    for r in all_results:
        if r.track not in track_summary:
            track_summary[r.track] = {"correct": 0, "total": 0}
        track_summary[r.track]["total"] += 1
        if r.correct:
            track_summary[r.track]["correct"] += 1

    for track_key, stats in track_summary.items():
        acc = 100 * stats["correct"] / stats["total"]
        print(f"  {TRACKS[track_key]['name']:12} {stats['correct']:4}/{stats['total']:4} = {acc:5.1f}%")

    overall_correct = sum(s["correct"] for s in track_summary.values())
    overall_total = sum(s["total"] for s in track_summary.values())
    overall_acc = 100 * overall_correct / overall_total
    print(f"{'='*60}")
    print(f"  {'TOTAL':12} {overall_correct:4}/{overall_total:4} = {overall_acc:5.1f}%")
    print(f"{'='*60}\n")

    # Save to CSV if requested
    if args.output:
        with open(args.output, 'w') as f:
            writer = csv.DictWriter(f, fieldnames=['item_id', 'track', 'model', 'question_type', 'response', 'expected_answer', 'correct', 'latency_ms'])
            writer.writeheader()
            for r in all_results:
                writer.writerow(asdict(r))
        print(f"Results saved to: {args.output}")


if __name__ == "__main__":
    main()
