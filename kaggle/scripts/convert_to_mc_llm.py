#!/usr/bin/env python3
"""
Convert Trinity Cognitive Probes to MC format with LLM-generated distractors.

Uses OpenRouter API (free tier) to generate high-quality distractors.
"""

import os
import sys
import json
import re
import random
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional
import subprocess

# Configuration
CSV_FILES = {
    "tmp": "kaggle/data/tmp_metacognition.csv",
    "tagp": "kaggle/data/tagp_attention.csv",
    "tefb": "kaggle/data/tefb_executive.csv",
    "tscp": "kaggle/data/tscp_social.csv",
    "thlp": "kaggle/data/thlp_learning.csv",
}

# OpenRouter API
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_MODEL = "deepseek/deepseek-r1:free"  # Free, fast, good reasoning

# Cache for generated distractors (avoid re-generating)
DISTRACTOR_CACHE = {}


def detect_question_type(question: str, answer: str) -> str:
    """Detect if question is factual short-answer or open-ended."""
    question_lower = question.strip().lower()
    answer_lower = answer.strip().lower()

    # Check for factual short-answer patterns
    factual_patterns = [
        r"^what is the capital of \w+",
        r"^what is \d+\^?\*?\d+",
        r"^(what|who|where|when) is (the|a) \w+",
        r"^which (user|server|item|chapter|color|person)",
        r"^how many \w+",
        r"^(yes|no|true|false)$",
        r"^(user \d+|server [a-z]|item [ab])$",  # TAGP specific
    ]

    for pattern in factual_patterns:
        if re.match(pattern, question_lower):
            return "factual"

    # Check answer length - short answers (< 5 words, no parentheses) are factual
    answer_words = len(answer.split())
    if answer_words <= 4 and not any(c in answer for c in ['(', ')', '[', ']']):
        return "factual"

    # Check for long explanatory answers
    if answer_words >= 5 or any(c in answer for c in ['(', ')', '[', ']']):
        return "open-ended"

    return "factual"


def generate_distractors_with_llm(question: str, correct_answer: str) -> List[str]:
    """Generate 3 plausible but wrong distractors using OpenRouter API."""

    # Check cache
    cache_key = f"{question[:100]}_{correct_answer[:50]}"
    if cache_key in DISTRACTOR_CACHE:
        return DISTRACTOR_CACHE[cache_key]

    # If no API key, use simple fallback
    if not OPENROUTER_API_KEY:
        return generate_simple_distractors(question, correct_answer)

    prompt = f"""Generate 3 plausible but WRONG distractors for this multiple choice question.

Question: {question}

The correct answer is: {correct_answer}

Requirements for distractors:
1. Must be SEMANTICALLY RELATED to the topic
2. Must be PLAUSIBLY wrong (not obviously incorrect)
3. Should be similar length to correct answer
4. Avoid trivial distractors like "random letters" or "potato"
5. Make them EQUALLY ATTRACTIVE to someone who doesn't know the answer

Return ONLY a JSON array of 3 strings:
["distractor 1", "distractor 2", "distractor 3"]

Do NOT include the correct answer. Do NOT add explanations."""

    try:
        result = subprocess.run(
            ["curl", "-s", "https://openrouter.ai/api/v1/chat/completions",
             "-H", f"Authorization: Bearer {OPENROUTER_API_KEY}",
             "-H", "Content-Type: application/json",
             "-d", json.dumps({
                 "model": OPENROUTER_MODEL,
                 "messages": [
                     {"role": "user", "content": prompt}
                 ],
                 "temperature": 0.7,
                 "max_tokens": 500
             })],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            response = json.loads(result.stdout)

            # Extract content
            if "choices" in response and len(response["choices"]) > 0:
                content = response["choices"][0]["message"]["content"].strip()

                # Try to parse JSON array
                try:
                    distractors = json.loads(content)
                    if isinstance(distractors, list) and len(distractors) == 3:
                        DISTRACTOR_CACHE[cache_key] = distractors
                        return distractors
                except json.JSONDecodeError:
                    # Try to extract lines
                    lines = content.strip().split('\n')
                    distractors = []
                    for line in lines:
                        line = line.strip().strip('"').strip("'")
                        if line and line not in distractors:
                            distractors.append(line)
                    if len(distractors) >= 3:
                        DISTRACTOR_CACHE[cache_key] = distractors[:3]
                        return distractors[:3]

    except Exception as e:
        print(f"  LLM error: {e}")

    # Fallback to simple distractors
    return generate_simple_distractors(question, correct_answer)


def generate_simple_distractors(question: str, correct_answer: str) -> List[str]:
    """Generate simple distractors without LLM (fallback)."""
    question_lower = question.lower()

    # Domain-specific distractors
    if "capital" in question_lower:
        country_match = re.search(r"of (\w+)", question, re.IGNORECASE)
        if country_match:
            wrong = ["Moscow", "London", "Paris", "Berlin", "Rome", "Madrid", "Tokyo", "Beijing"]
            random.shuffle(wrong)
            return wrong[:3]

    elif "quantum" in question_lower and "superposition" in question_lower:
        return [
            "A system transitions between states sequentially",
            "A system collapses into superposition after observation",
            "Multiple systems share a single quantum state through entanglement"
        ]

    elif "2^" in question_lower or "2 **" in question_lower or "2 to the power" in question_lower:
        # Math power questions
        try:
            base = 2
            for n in [18, 19, 21]:
                if str(2**n) != correct_answer:
                    return [str(2**n), str(2**20 * 2), str(2**20 // 2)]
        except:
            pass
        return ["524288", "2097152", "4194304"]

    elif "apology" in question_lower:
        return ["Ignore the lateness", "Make a joke about it", "Leave immediately"]

    elif "fairness" in question_lower or "equity" in question_lower or "negotiation" in question_lower:
        return ["Equal split regardless of contribution", "Winner takes all", "Random allocation"]

    elif "sarcas" in question_lower or "iron" in question_lower:
        return ["Literal interpretation", "Confusion", "Anger"]

    elif "false belief" in question_lower:
        return ["6 PM (updated time)", "Bob knows the time changed", "Charlie knows the new time"]

    else:
        # Generic distractors
        return [
            "None of the above",
            "Not applicable",
            "Cannot be determined"
        ]


def create_mc_question(question: str, answer: str) -> dict:
    """Convert a question to MC format with distractors."""
    question_type = detect_question_type(question, answer)

    if question_type == "open-ended":
        # Generate distractors using LLM
        distractors = generate_distractors_with_llm(question, answer)

        # Create options with shuffled positions
        options = [answer] + distractors[:3]
        letters = ["A", "B", "C", "D"]

        # Find correct position (randomize)
        correct_pos = random.randint(0, 3)
        options[0], options[correct_pos] = options[correct_pos], options[0]
        correct_letter = letters[correct_pos]

        # Build choices string
        choices = []
        for i, opt in enumerate(options):
            choices.append(f"{letters[i]}) {opt}")

        return {
            "question_type": "mc",
            "question": f"Which best describes: {question}",
            "choices": "\\n".join(choices),
            "answer": correct_letter
        }

    else:
        # Factual short-answer - keep as-is
        return {
            "question_type": "factual",
            "question": question,
            "answer": answer
        }


def process_track(track_key: str, input_path: str, output_path: str, limit: int = None) -> dict:
    """Process a single track: convert to MC format, save new CSV."""
    import pandas as pd

    df = pd.read_csv(input_path)
    if limit:
        df = df.head(limit)

    print(f"\n{'='*60}")
    print(f"Processing {track_key.upper()}: {len(df)} questions")
    print(f"{'='*60}")

    results = []
    stats = {
        "total": len(df),
        "open_ended": 0,
        "factual": 0,
        "converted": 0,
        "errors": 0
    }

    for idx, row in df.iterrows():
        # Get question and answer columns (different per track)
        if track_key == "tagp":
            question = str(row["query"])
            answer = str(row["expected_focus"])
        elif track_key == "tefb":
            question = str(row["context"])
            answer = str(row["expected_result"])
        elif track_key == "tscp":
            question = str(row["scenario"])
            answer = str(row["expected_inference"])
        else:
            question = str(row["question"])
            answer = str(row["answer"])

        # Detect question type
        question_type = detect_question_type(question, answer)

        if question_type == "open-ended":
            stats["open_ended"] += 1

            # Generate MC format
            mc_result = create_mc_question(question, answer)

            results.append({
                "id": row.get("id", f"{track_key}_{idx}"),
                "question_type": "mc",
                "question": mc_result["question"],
                "choices": mc_result["choices"],
                "answer": mc_result["answer"]
            })

            stats["converted"] += 1

            if (idx + 1) % 50 == 0:
                print(f"  Processed {idx + 1}/{len(df)} ({(idx + 1) * 100 // len(df)}%)")

        else:
            stats["factual"] += 1

            # Keep factual as-is
            results.append({
                "id": row.get("id", f"{track_key}_{idx}"),
                "question_type": "factual",
                "question": question,
                "answer": answer
            })

    # Create new DataFrame
    new_df = pd.DataFrame(results)

    # Save to CSV
    new_df.to_csv(output_path, index=False)

    print(f"\nResults for {track_key.upper()}:")
    print(f"  Total: {stats['total']}")
    print(f"  Open-ended: {stats['open_ended']}")
    print(f"  Factual: {stats['factual']}")
    print(f"  Converted to MC: {stats['converted']}")
    print(f"  Saved to: {output_path}")

    return stats


def main():
    """Convert all 5 Trinity Cognitive Probe datasets to MC format."""

    # Check for API key
    if not OPENROUTER_API_KEY:
        print("WARNING: OPENROUTER_API_KEY not set. Using simple distractors.")
        print("Set with: export OPENROUTER_API_KEY='your-key'")
        print("")

    # Create output directory
    output_dir = Path("kaggle/data/converted_mc")
    output_dir.mkdir(parents=True, exist_ok=True)

    summary = []

    for track_key, input_path in CSV_FILES.items():
        if not Path(input_path).exists():
            print(f"WARNING: {input_path} not found, skipping...")
            continue

        output_path = output_dir / f"{track_key}_mc.csv"
        result = process_track(track_key, input_path, output_path)
        result["track"] = track_key
        summary.append(result)

    # Print summary
    print(f"\n{'='*60}")
    print("=" * 60)
    print("CONVERSION SUMMARY")
    print("=" * 60)
    print(f"{'Track':<8} {'Total':<8} {'Open-Ended':<12} {'Factual':<10} {'Converted':<10}")
    print("-" * 60)

    total_questions = 0
    total_open = 0
    total_factual = 0
    total_converted = 0

    for s in summary:
        print(f"{s['track']:<8} {s['total']:<8} {s['open_ended']:<12} {s['factual']:<10} {s['converted']:<10}")
        total_questions += s['total']
        total_open += s['open_ended']
        total_factual += s['factual']
        total_converted += s['converted']

    print("-" * 60)
    print(f"{'TOTAL':<8} {total_questions:<8} {total_open:<12} {total_factual:<10} {total_converted:<10}")
    print("=" * 60)

    # Save summary to JSON
    summary_data = {
        "total_questions": total_questions,
        "total_open_ended": total_open,
        "total_factual": total_factual,
        "total_converted": total_converted,
        "tracks": summary,
        "llm_used": OPENROUTER_API_KEY is not None
    }

    summary_path = output_dir / "conversion_summary.json"
    with open(summary_path, 'w') as f:
        json.dump(summary_data, f, indent=2)

    print(f"\nSummary saved to: {summary_path}")


if __name__ == "__main__":
    main()
