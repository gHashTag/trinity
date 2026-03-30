#!/usr/bin/env python3
"""
Generate quality MCQ distractors using OpenRouter free LLM.

Processes unique questions only (deduplication) to minimize API calls.
"""

import os
import sys
import json
import re
import random
import hashlib
from pathlib import Path
from typing import List, Dict, Tuple
import subprocess
import time

# Configuration
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_MODEL = "google/gemma-3-4b-it:free"  # Free, fast
ALT_MODEL = "deepseek/deepseek-r1:free"  # Alternative

# Cache to avoid regenerating same distractors
CACHE_FILE = Path("kaggle/data/.distractor_cache.json")

def load_cache() -> Dict:
    """Load distractor cache from disk."""
    if CACHE_FILE.exists():
        with open(CACHE_FILE) as f:
            return json.load(f)
    return {}

def save_cache(cache: Dict):
    """Save distractor cache to disk."""
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CACHE_FILE, 'w') as f:
        json.dump(cache, f, indent=2)

def get_question_hash(question: str, answer: str) -> str:
    """Get hash for question deduplication."""
    content = f"{question[:200]}_{answer[:100]}"
    return hashlib.md5(content.encode()).hexdigest()[:16]

def call_llm(prompt: str, model: str = None) -> str:
    """Call OpenRouter API with retry logic."""
    if not OPENROUTER_API_KEY:
        raise Exception("OPENROUTER_API_KEY not set")

    model = model or OPENROUTER_MODEL

    for attempt in range(3):
        try:
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.8,
                "max_tokens": 300
            }

            result = subprocess.run(
                ["curl", "-s", "https://openrouter.ai/api/v1/chat/completions",
                 "-H", f"Authorization: Bearer {OPENROUTER_API_KEY}",
                 "-H", "Content-Type: application/json",
                 "-d", json.dumps(payload),
                 "--connect-timeout", "30",
                 "--max-time", "60"],
                capture_output=True,
                text=True,
                timeout=90
            )

            if result.returncode == 0:
                response = json.loads(result.stdout)
                if "choices" in response and len(response["choices"]) > 0:
                    content = response["choices"][0]["message"]["content"].strip()
                    return content
            else:
                print(f"  API error: {result.stderr[:200]}")

        except subprocess.TimeoutExpired:
            print(f"  Timeout (attempt {attempt + 1}/3)")
            if attempt < 2:
                time.sleep(2)
                continue
        except Exception as e:
            print(f"  Error: {e}")
            if attempt < 2:
                time.sleep(2)
                continue

    raise Exception(f"LLM call failed after 3 attempts")

def generate_quality_distractors(question: str, correct_answer: str, context: str = "") -> List[str]:
    """Generate 3 plausible but wrong distractors using LLM."""

    # Check cache first
    cache = load_cache()
    qhash = get_question_hash(question, correct_answer)
    if qhash in cache:
        return cache[qhash]

    # Build prompt for distractor generation
    prompt = f"""You are creating multiple choice questions for a cognitive science benchmark.

Generate 3 PLAUSIBLE but WRONG distractors for this question.

QUESTION: {question}

CORRECT ANSWER: {correct_answer}

{"CONTEXT: " + context if context else ""}

CRITICAL REQUIREMENTS:
1. Each distractor must be FACTUALLY WRONG but SEMANTICALLY RELATED
2. Distractors should sound plausible to someone who doesn't know the answer
3. AVOID obvious wrong answers (e.g., "potato", random letters, numbers)
4. Make distractors SIMILAR in length and style to the correct answer
5. Use common misconceptions, related concepts, or confusable facts

Return ONLY a JSON array of 3 strings:
["distractor 1", "distractor 2", "distractor 3"]

No markdown, no explanation, just the JSON array."""

    try:
        response = call_llm(prompt)

        # Extract JSON array from response
        # Try direct parse first
        try:
            distractors = json.loads(response)
            if isinstance(distractors, list) and len(distractors) >= 3:
                result = [str(d).strip() for d in distractors[:3]]
                cache[qhash] = result
                save_cache(cache)
                return result
        except json.JSONDecodeError:
            pass

        # Try to find JSON array in response
        match = re.search(r'\[.*?\]', response, re.DOTALL)
        if match:
            try:
                distractors = json.loads(match.group(0))
                if isinstance(distractors, list) and len(distractors) >= 3:
                    result = [str(d).strip() for d in distractors[:3]]
                    cache[qhash] = result
                    save_cache(cache)
                    return result
            except json.JSONDecodeError:
                pass

        # Parse line-by-line as fallback
        lines = response.strip().split('\n')
        distractors = []
        for line in lines:
            line = line.strip()
            line = re.sub(r'^[\-\*\d+\.\)]+\s*', '', line)  # Remove bullets
            line = line.strip('"\'')
            if line and len(line) > 3 and line not in distractors:
                distractors.append(line)
            if len(distractors) >= 3:
                break

        if len(distractors) >= 3:
            result = distractors[:3]
            cache[qhash] = result
            save_cache(cache)
            return result

    except Exception as e:
        print(f"  LLM generation failed: {e}")

    # Ultimate fallback (should rarely happen with API key)
    return generate_fallback_distractors(question, correct_answer)

def generate_fallback_distractors(question: str, correct_answer: str) -> List[str]:
    """Generate reasonable fallback distractors without LLM."""
    q_lower = question.lower()

    # Domain-specific fallbacks
    if "quantum" in q_lower and "superposition" in q_lower:
        return [
            "A system transitions between states sequentially",
            "A system collapses into superposition after observation",
            "Multiple systems share a single quantum state"
        ]

    elif "capital" in q_lower:
        wrong_capitals = ["London", "Paris", "Berlin", "Moscow", "Tokyo", "Beijing"]
        if correct_answer not in wrong_capitals:
            return wrong_capitals[:3]
        return ["Moscow", "London", "Paris"]

    elif any(x in q_lower for x in ["fair", "equity", "negotiation"]):
        return [
            "Equal split regardless of contribution",
            "Winner takes all",
            "Random allocation"
        ]

    elif "sarcas" in q_lower or "iron" in q_lower:
        return ["Literal interpretation", "Confusion", "Anger"]

    elif "false belief" in q_lower:
        return [
            "The updated time",
            "They know the information changed",
            "Everyone has correct information"
        ]

    else:
        return [
            "None of the above",
            "Cannot be determined",
            "Not applicable"
        ]

def create_mcq(question: str, answer: str, context: str = "") -> Dict:
    """Create a multiple choice question with shuffled options."""

    # Get distractors
    distractors = generate_quality_distractors(question, answer, context)

    # Combine and shuffle
    options = [answer] + distractors
    letters = ["A", "B", "C", "D"]

    # Shuffle (keep track of correct position)
    correct_pos = random.randint(0, 3)
    options[0], options[correct_pos] = options[correct_pos], options[0]

    # Build choices string
    choices_list = []
    for i, opt in enumerate(options):
        choices_list.append(f"{letters[i]}) {opt}")

    return {
        "question": question,
        "choices": "\\n".join(choices_list),
        "answer": letters[correct_pos],
        "original_answer": answer
    }

def process_csv(input_path: Path, output_path: Path, track_name: str):
    """Process a CSV file and convert open-ended questions to MCQ."""
    import pandas as pd

    df = pd.read_csv(input_path)
    print(f"\n{'='*60}")
    print(f"Processing {track_name}: {len(df)} questions")
    print(f"{'='*60}")

    results = []
    stats = {"total": len(df), "open_ended": 0, "factual": 0, "mc_converted": 0}

    cache = load_cache()
    api_calls = 0

    for idx, row in df.iterrows():
        # Get question and answer based on track
        if track_name == "tagp":
            question = str(row.get("query", ""))
            answer = str(row.get("expected_focus", ""))
            context = str(row.get("context", ""))
        elif track_name == "tefb":
            question = str(row.get("context", ""))
            answer = str(row.get("expected_result", ""))
            context = ""
        elif track_name == "tscp":
            question = str(row.get("scenario", ""))
            answer = str(row.get("expected_inference", ""))
            context = str(row.get("perspective", ""))
        else:
            question = str(row.get("question", ""))
            answer = str(row.get("answer", ""))
            context = ""

        # Detect if open-ended (needs MC conversion)
        qhash = get_question_hash(question, answer)
        is_open_ended = (
            len(answer.split()) > 4 or  # Long answer
            any(c in answer for c in ['(', ')', '[', ']']) or  # Has brackets
            "?" in question  # Has question mark
        )

        # Also check if already in cache (open-ended)
        was_cached = qhash in cache

        if is_open_ended:
            stats["open_ended"] += 1

            mcq = create_mcq(question, answer, context)

            # Check if we made a new API call
            new_cache = load_cache()
            if qhash in new_cache and not was_cached:
                api_calls += 1

            results.append({
                "id": row.get("id", f"{track_name}_{idx}"),
                "task": row.get("task", ""),
                "question": mcq["question"],
                "choices": mcq["choices"],
                "answer": mcq["answer"],
                "original_answer": mcq["original_answer"],
                "difficulty": row.get("difficulty", "5.0"),
                "brain_zone": row.get("brain_zone", ""),
                "neural_analog": row.get("neural_analog", "")
            })

            stats["mc_converted"] += 1

            if (idx + 1) % 50 == 0:
                print(f"  Progress: {idx + 1}/{len(df)} | API calls: {api_calls} | Cache hits: {stats['mc_converted'] - api_calls}")

        else:
            stats["factual"] += 1
            results.append({
                "id": row.get("id", f"{track_name}_{idx}"),
                "task": row.get("task", ""),
                "question": question,
                "answer": answer,
                "difficulty": row.get("difficulty", "5.0"),
                "brain_zone": row.get("brain_zone", ""),
                "neural_analog": row.get("neural_analog", "")
            })

    # Save results
    output_df = pd.DataFrame(results)
    output_df.to_csv(output_path, index=False)

    print(f"\nResults:")
    print(f"  Total: {stats['total']}")
    print(f"  Open-ended: {stats['open_ended']}")
    print(f"  Factual: {stats['factual']}")
    print(f"  MC converted: {stats['mc_converted']}")
    print(f"  API calls made: {api_calls}")
    print(f"  Saved to: {output_path}")

    return stats

def main():
    """Main entry point."""

    if not OPENROUTER_API_KEY:
        print("ERROR: OPENROUTER_API_KEY not set!")
        print("\nGet a free key at: https://openrouter.ai/")
        print("Then run: export OPENROUTER_API_KEY='your-key-here'")
        print("\nFor quick testing, you can also pass as argument:")
        print("  python mcq_distractor_gen.py YOUR_API_KEY")
        sys.exit(1)

    # Check for API key from command line
    if len(sys.argv) > 1:
        OPENROUTER_API_KEY = sys.argv[1]
        os.environ["OPENROUTER_API_KEY"] = OPENROUTER_API_KEY

    output_dir = Path("kaggle/data/converted_mc")
    output_dir.mkdir(parents=True, exist_ok=True)

    tracks = {
        "tmp": Path("kaggle/data/tmp_metacognition.csv"),
        "thlp": Path("kaggle/data/thlp_learning.csv"),
        "tagp": Path("kaggle/data/tagp_attention.csv"),
        "tefb": Path("kaggle/data/tefb_executive.csv"),
        "tscp": Path("kaggle/data/tscp_social.csv"),
    }

    summary = {}

    for track_name, input_path in tracks.items():
        if not input_path.exists():
            print(f"WARNING: {input_path} not found, skipping...")
            continue

        output_path = output_dir / f"{track_name}_mcq.csv"
        summary[track_name] = process_csv(input_path, output_path, track_name)

    # Print final summary
    print(f"\n{'='*60}")
    print("FINAL SUMMARY")
    print(f"{'='*60}")

    cache = load_cache()
    print(f"Total unique questions in cache: {len(cache)}")

    total_mc = sum(s.get("mc_converted", 0) for s in summary.values())
    print(f"Total MC questions generated: {total_mc}")

if __name__ == "__main__":
    main()
