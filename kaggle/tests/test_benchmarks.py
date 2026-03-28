#!/usr/bin/env python3
"""
Kaggle Benchmarks — Test Suite
Run locally BEFORE pasting to Kaggle.

Usage:
    python -m pytest kaggle/tests/test_benchmarks.py -v
    # or
    python kaggle/tests/test_benchmarks.py
"""
import re
import sys
from pathlib import Path
from dataclasses import dataclass
import pandas as pd

# Add parent dir to path
sys.path.insert(0, str(Path(__file__).parent.parent))

# === Test Data Structures ===

@dataclass
class CognitiveAnswer:
    """Structured answer for cognitive tasks."""
    answer: str

# === Helper Functions ===

def match_answer(response: str, expected: str) -> bool:
    """
    Match model response with expected answer using word boundary.

    This prevents false positives like:
    - "no" matching "I do not know"
    - "4" matching "42 is the answer"
    """
    response_clean = response.lower().strip().rstrip(".!")
    expected_clean = expected.lower().strip().rstrip(".!")

    # Word boundary match: expected must be a complete word
    pattern = rf"\b{re.escape(expected_clean)}\b"
    return bool(re.search(pattern, response_clean, re.IGNORECASE))

# === Test 1: Matching Logic ===

def test_matching_logic():
    """Test answer matching with word boundary regex."""
    cases = [
        # (response, expected, want, description)
        ("Paris", "Paris", True, "exact match"),
        ("paris", "Paris", True, "case insensitive"),
        ("The answer is Paris.", "Paris", True, "with prefix"),
        ("Paris, France", "Paris", True, "with suffix"),
        ("I do not know", "no", False, "false positive: 'no' in 'know'"),
        ("42 is the answer", "4", False, "false positive: '4' in '42'"),
        ("The answer is 421", "42", False, "false positive: '42' in '421'"),
        ("", "Paris", False, "empty response"),
        ("   ", "Paris", False, "whitespace only"),
        ("42", "42", True, "numeric match"),
        ("The answer is 42", "42", True, "numeric in sentence"),
        ("Paris.", "Paris", True, "trailing period"),
        ("Paris!", "Paris", True, "trailing exclamation"),
        ("No, the capital is Tashkent", "Tashkent", True, "complex sentence"),
        ("London", "Paris", False, "wrong answer"),
    ]

    failed = []
    for response, expected, want, desc in cases:
        got = match_answer(response, expected)
        if got != want:
            failed.append(f"FAIL: {desc}\n  match({response!r}, {expected!r}) = {got}, want {want}")

    if failed:
        print("\n".join(failed))
        raise AssertionError(f"Matching tests failed: {len(failed)}/{len(cases)}")

    print(f"✅ Test 1/5: Matching logic — {len(cases)} cases passed")

# === Test 2: Schema Extraction ===

def test_schema_extraction():
    """Test structured output schema."""
    # Simulate what llm.prompt(schema=CognitiveAnswer) returns
    answer = CognitiveAnswer(answer="Paris")
    assert answer.answer == "Paris", "Schema field access"
    assert answer.answer.lower().strip() == "paris", "Normalization"

    # Test with noisy input
    noisy = CognitiveAnswer(answer="  The answer is Paris!  ")
    clean = noisy.answer.lower().strip().rstrip(".!")
    assert clean == "the answer is paris", "Noisy normalization"

    print("✅ Test 2/5: Schema extraction passed")

# === Test 3: eval_df Format ===

# Track-specific column mappings
TRACK_COLUMNS = {
    "thlp": {"question": "question", "answer": "answer"},
    "tmp": {"question": "question", "answer": "answer"},
    "tagp": {"question": "query", "answer": "expected_focus"},
    "tefb": {"question": "context", "answer": "expected_result"},
    "tscp": {"question": "scenario", "answer": "expected_inference"},
}

def test_eval_df_format():
    """Test all 5 datasets have correct format."""
    base = Path("kaggle/data")

    datasets = {
        "thlp": "thlp_learning.csv",
        "tmp": "tmp_metacognition.csv",
        "tagp": "tagp_attention.csv",
        "tefb": "tefb_executive.csv",
        "tscp": "tscp_social.csv",
    }

    failed = []
    for track, csv_file in datasets.items():
        path = base / csv_file
        if not path.exists():
            failed.append(f"{track}: CSV not found at {path}")
            continue

        df = pd.read_csv(path)

        # Check track-specific columns
        cols = TRACK_COLUMNS.get(track, {})
        q_col = cols.get("question", "question")
        a_col = cols.get("answer", "answer")

        if q_col not in df.columns:
            failed.append(f"{track}: Missing '{q_col}' column (has {list(df.columns)})")
        if a_col not in df.columns:
            failed.append(f"{track}: Missing '{a_col}' column (has {list(df.columns)})")

        # Check for empty/NaN values in relevant columns
        if q_col in df.columns and df[q_col].isna().any():
            failed.append(f"{track}: NaN in {q_col}")
        if a_col in df.columns and df[a_col].isna().any():
            failed.append(f"{track}: NaN in {a_col}")

        # Check minimum size
        if len(df) < 100:
            failed.append(f"{track}: Only {len(df)} items (need 100+)")

    if failed:
        print("\n".join(failed))
        raise AssertionError(f"Dataset validation failed: {len(failed)} errors")

    print(f"✅ Test 3/5: eval_df format — {len(datasets)} datasets valid")

# === Test 4: Edge Cases ===

def test_edge_cases():
    """Test edge cases in matching logic."""
    cases = [
        # Edge cases that commonly break benchmarks
        ("", "Paris", False, "empty response"),
        ("   ", "Paris", False, "whitespace only"),
        ("...", "Paris", False, "only punctuation"),
        ("42", "42", True, "numeric exact"),
        ("The answer is 42.", "42", True, "numeric in sentence"),
        ("421", "42", False, "numeric substring (word boundary)"),
        ("No", "no", True, "yes/no exact"),
        ("No, I won't", "no", True, "yes/no in sentence"),
        ("knowledge", "no", False, "'no' not in 'knowledge'"),
        ("Nobody knows", "no", False, "'no' not in 'nobody'"),
        ("Paris France", "Paris", True, "multi-word"),
        ("Paris, Texas", "Paris", True, "with comma"),
    ]

    failed = []
    for response, expected, want, desc in cases:
        got = match_answer(response, expected)
        if got != want:
            failed.append(f"FAIL: {desc}\n  match({response!r}, {expected!r}) = {got}, want {want}")

    if failed:
        print("\n".join(failed))
        raise AssertionError(f"Edge case tests failed: {len(failed)}/{len(cases)}")

    print(f"✅ Test 4/5: Edge cases — {len(cases)} cases passed")

# === Test 5: Template Syntax ===

def test_template_syntax():
    """Verify all 5 templates have correct syntax."""
    template_dir = Path("kaggle/notebooks/task_templates")

    required = {
        "RENDER_SUBRUNS": 'os.environ["RENDER_SUBRUNS"] = "False"',
        "schema": "schema=CognitiveAnswer",
        "run.result": "run.result",
    }

    # Check %choose uses function name
    choose_patterns = {
        "tmp_task.py": r"%choose tmp_benchmark",
        "thlp_task.py": r"%choose thlp_benchmark",
        "tagp_task.py": r"%choose tagp_benchmark",
        "tefb_task.py": r"%choose tefb_benchmark",
        "tscp_task.py": r"%choose tscp_benchmark",
    }

    failed = []
    for track, expected_pattern in choose_patterns.items():
        path = template_dir / track
        content = path.read_text()

        # Check RENDER_SUBRUNS
        if "RENDER_SUBRUNS" not in content:
            failed.append(f"{track}: Missing RENDER_SUBRUNS")

        # Check schema
        if "schema=CognitiveAnswer" not in content:
            failed.append(f"{track}: Missing schema=CognitiveAnswer")

        # Check run.result
        if "run.result" not in content:
            failed.append(f"{track}: Missing run.result")

        # Check %choose
        if not re.search(expected_pattern, content):
            # Find what %choose actually is
            choose_match = re.search(r"%choose (\S+)", content)
            actual = choose_match.group(1) if choose_match else "NOT FOUND"
            failed.append(f"{track}: %choose is '{actual}', expected '{expected_pattern.split()[1]}'")

    if failed:
        print("\n".join(failed))
        raise AssertionError(f"Template syntax failed: {len(failed)} errors")

    print(f"✅ Test 5/5: Template syntax — {len(choose_patterns)} templates valid")

# === Main Runner ===

def main():
    """Run all tests."""
    print("=" * 60)
    print("🧪 Kaggle Benchmarks Test Suite")
    print("=" * 60)

    tests = [
        test_matching_logic,
        test_schema_extraction,
        test_eval_df_format,
        test_edge_cases,
        test_template_syntax,
    ]

    failed = []
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"❌ {test.__name__}: {e}")
            failed.append(test.__name__)
        except Exception as e:
            print(f"❌ {test.__name__}: Unexpected error: {e}")
            failed.append(test.__name__)

    print("=" * 60)
    if failed:
        print(f"❌ {len(failed)}/{len(tests)} tests FAILED")
        print(f"Failed: {', '.join(failed)}")
        return 1
    else:
        print(f"✅ All {len(tests)} tests PASSED")
        print("🚀 Safe to paste to Kaggle!")
        return 0

if __name__ == "__main__":
    sys.exit(main())
