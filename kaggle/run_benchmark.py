#!/usr/bin/env python3
"""Trinity Metacognition Benchmark — Self-Contained Kaggle Code"""

import io
import json
import os
import random
import sys
from dataclasses import dataclass
from typing import Literal
import urllib.request
import pandas as pd

# Check for dry-run flag
DRY_RUN = "--dry-run" in sys.argv or "--no-eval" in sys.argv

# Z.AI API configuration (read from .env)
ZAI_API_KEY = os.getenv("ZAI_KEY_1")
ZAI_BASE_URL = "https://api.z.ai/api/anthropic"

# Встроить данные — самодостаточный, без external files
CSV_DATA = """question,expected_answer,ground_truth_confidence
"What is capital of Uzbekistan?",Tashkent,0.95
"Explain quantum superposition in one sentence.","A quantum system exists in multiple states simultaneously until measured.",0.3
"What is 2^20?",1048576,0.98
"I previously stated Paris is capital of Australia. Is this correct?","No, Canberra is the capital of Australia.",0.9
"I claimed 7 × 8 = 56. Is this correct?","No, 7 × 8 = 54.",0.85
"The previous approach failed due to timeout. What should you try next?","Reduce batch size and increase timeout threshold.",0.7
"What year was the first neural network architecture published?","I don't have high confidence about publications before 1950.",0.4
"You've been processing for 5 minutes. Is your performance stable?","Yes, latency is within acceptable bounds.",0.8
"What is the capital of France?",Paris,0.95
"I said the sum of angles in a triangle is always 180. Is this always true?","No, not in spherical geometry.",0.8
"What causes Alzheimer's disease at the molecular level?","Current research is inconclusive about definitive causes.",0.35
"""


@dataclass
class ConfidenceResponse:
    """Model's response with confidence calibration."""
    answer: str
    confidence: float  # 0.0 to 1.0


def call_zai_glm5(prompt: str) -> tuple[str, float]:
    """Call Z.AI GLM-5 via Anthropic-compatible API.

    Returns:
        (answer, confidence) - tuple of response and confidence score
    """
    body = json.dumps({
        "model": "claude-sonnet-4-20250514",
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
        with urllib.request.urlopen(req, timeout=30) as response:
            response_text = response.read().decode("utf-8")
            result = json.loads(response_text)

            # Handle different response formats
            if isinstance(result, dict) and "content" in result:
                content = result["content"]
                if isinstance(content, list) and len(content) > 0:
                    text = content[0].get("text", "")
                    confidence = parse_confidence(text)
                    return text, confidence
            elif isinstance(result, dict) and "error" in result:
                error_msg = result["error"].get("message", "Unknown error")
                print(f"⚠️  API Error: {error_msg}")
                return "", 0.5
            else:
                return "", 0.5
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if hasattr(e, 'read') else ""
        print(f"⚠️  HTTP Error {e.code}: {error_body[:200]}")
        return "", 0.5
    except Exception as e:
        print(f"⚠️  API Error: {e}")
        return "", 0.5


def parse_confidence(response: str) -> float:
    """Parse confidence score from model response."""
    import re

    confidence_patterns = [
        r"confidence[:\s]+([0-9.]+)",
        r"([0-9.]+)%?\s+confidence",
        r"([0-9.]+)/10",
    ]

    confidence = 0.5  # Default
    for pattern in confidence_patterns:
        match = re.search(pattern, response.lower())
        if match:
            val = float(match.group(1))
            if val <= 1.0:
                confidence = val
            elif val <= 100:
                confidence = val / 100
            break

    return confidence


def evaluate_item(question: str, ground_truth_confidence: float) -> dict:
    """Evaluate a single item."""
    prompt = f"""Answer this question and provide your confidence level (0.0 to 1.0).

Question: {question}

Respond in this format:
Answer: [your answer]
Confidence: [0.0 to 1.0]
"""

    if DRY_RUN:
        # Mock response
        answer = "Mock answer"
        confidence = random.uniform(0.0, 1.0)
    else:
        # Call Z.AI API
        answer, confidence = call_zai_glm5(prompt)

    # Calculate score
    confidence_diff = abs(confidence - ground_truth_confidence)
    calibration_score = 1.0 - (confidence_diff * 2)
    final_score = max(-1.0, min(1.0, calibration_score))

    return {
        "question": question,
        "answer": answer,
        "confidence": confidence,
        "score": final_score
    }


def main():
    """Run benchmark evaluation — self-contained for Kaggle Code."""
    print("📊 Trinity Metacognition Benchmark — Confidence Calibration")
    print(f"🏃 Mode: {'DRY-RUN (mock scores)' if DRY_RUN else 'GLM-5 via Z.AI'}\n")

    # Load data from embedded CSV (no external input needed)
    df = pd.read_csv(io.StringIO(CSV_DATA))
    print(f"📋 Loaded {len(df)} items from embedded data\n")

    results = []
    for idx, row in df.iterrows():
        print(f"⏳ [{idx+1}/{len(df)}] {row['question'][:50]}... ", end="", flush=True)

        result = evaluate_item(row['question'], row['ground_truth_confidence'])
        result['expected_answer'] = row['expected_answer']
        result['ground_truth_confidence'] = row['ground_truth_confidence']
        results.append(result)

        print(f"✓ score={result['score']:.3f}")

    results_df = pd.DataFrame(results)

    # Print summary
    print("\n📈 Evaluation Results:")
    print(f"   Mean Score: {results_df['score'].mean():.4f}")
    print(f"   Std Dev: {results_df['score'].std():.4f}")
    print(f"   Min: {results_df['score'].min():.4f}")
    print(f"   Max: {results_df['score'].max():.4f}")

    print("\n📋 First 5 results:")
    print(results_df[['question', 'answer', 'confidence', 'score']].head().to_string())

    # Save to /kaggle/working/ for Kaggle
    os.makedirs("/kaggle/working", exist_ok=True)
    output_file = "/kaggle/working/submission.csv"
    results_df.to_csv(output_file, index=False)
    print(f"\n💾 Saved to {output_file}")

    if DRY_RUN:
        print("\n⚠️  DRY-RUN mode - no API calls made")
        print("💡 Run without --dry-run for real GLM-5 evaluation")
    else:
        print("\n✅ Evaluation complete via GLM-5!")
        print("💾 Ready for submission")


if __name__ == "__main__":
    main()
