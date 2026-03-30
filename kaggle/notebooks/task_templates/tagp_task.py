# Kaggle Benchmarks — Attentional Gateway Probe
# Trinity Cognitive AGI Benchmark Suite
# DeepMind AGI Hackathon 2026

# === CELL 1: Install & Fix ===
!pip install protobuf==5.29.6 --quiet
!pip install -q kaggle-benchmarks kaggle

# === CELL 2: Imports & Config ===
import os
os.environ["RENDER_SUBRUNS"] = "False"

import kaggle_benchmarks as kbench
import kaggle
import pandas as pd
import re
import glob
from dataclasses import dataclass

print("✅ Imports successful")

# === CELL 3: Structured Output Schema ===
@dataclass
class CognitiveAnswer:
    answer: str

# === CELL 4: Flexible Matching Function ===
def match_answer(response: str, expected: str) -> bool:
    """Flexible answer matching with multiple strategies.

    Strategy 0: Strip parenthetical annotations (e.g., "5 PM (inherited Bob's false belief)" -> "5 PM")
    Strategy 1: Exact match
    Strategy 2: Expected as substring (for short answers)
    Strategy 3: Word boundary match (for multi-word answers without special chars)
    Strategy 4: Fuzzy word match (all expected words present in order)
    """
    resp = response.lower().strip()
    exp = expected.lower().strip()

    # Strategy 0: Strip parenthetical annotations from expected
    # Model answers: "5 PM" vs expected: "5 PM (inherited Bob's false belief)"
    exp_core = re.sub(r'\s*\(.*?\)\s*', ' ', exp).strip()
    if exp_core and exp_core != exp:
        # Try exact match with core
        if resp == exp_core:
            return True
        # Try substring with core
        if len(exp_core) <= 30 and exp_core in resp:
            return True

    # Strategy 1: Exact match
    if resp == exp:
        return True

    # Strategy 2: Expected as substring (for short expected answers)
    if len(exp) <= 30 and exp in resp:
        return True

    # Strategy 3: Word boundary match (for multi-word expected answers)
    # Only use if expected doesn't contain special chars that confuse \b
    if not any(c in exp for c in ['(', ')', '[', ']', '*', '+', '?', '_', '-']):
        pattern = rf"\b{re.escape(exp)}\b"
        if re.search(pattern, resp):
            return True

    # Strategy 4: Fuzzy word match (all expected words present in order)
    exp_words = exp.split()
    if len(exp_words) >= 2:
        resp_words = resp.split()
        for i in range(len(resp_words) - len(exp_words) + 1):
            if resp_words[i:i+len(exp_words)] == exp_words:
                return True

    return False

print("✅ Matching function defined")

# === CELL 5: Load Data ===
print("📥 Downloading dataset...")
!mkdir -p /kaggle/working/datasets

kaggle.api.dataset_download_files(
    'playra/trinity-cognitive-probes-tagp',
    path='/kaggle/working/datasets/',
    unzip=True
)

# FIXED: Use endswith() instead of fuzzy matching to avoid wrong dataset detection
csv_files = glob.glob('/kaggle/working/datasets/**/*.csv', recursive=True)
csv_path = None
for f in csv_files:
    if f.endswith('tagp_attention.csv'):
        csv_path = f
        break

if csv_path is None:
    raise FileNotFoundError(f"CSV not found. Files: {csv_files}")

print(f"📂 Using: {csv_path}")

df = pd.read_csv(csv_path)

# Fixed column mapping for this track
eval_df = pd.DataFrame({
    "question": df["query"],
    "expected_answer": df["expected_focus"]
})

print(f"📊 Loaded {len(eval_df)} items")

# === CELL 6: Debug Log Container ===
tagp_debug_log = []

# === CELL 7: Inner Task with Debug Logging ===
@kbench.task(name="trinity_tagp_attention Single", store_task=False)
def tagp_single(llm, question, expected_answer) -> bool:
    """Single item evaluation with debug logging for first 10 failures."""
    prompt = f"""Based on the information provided, give a precise answer.

Question: {question}

Answer:"""
    response = llm.prompt(prompt, schema=CognitiveAnswer)

    matched = match_answer(response.answer, expected_answer)

    # Debug logging (first 10 failures only)
    global tagp_debug_log
    if not matched and len(tagp_debug_log) < 10:
        tagp_debug_log.append({
            "question": question[:80],
            "expected": expected_answer,
            "got": response.answer[:150]
        })

    return matched

print("✅ Inner task registered")

# === CELL 8: Outer Task ===
@kbench.task(
    name="Trinity Attentional Gateway Probe",
    description="Evaluates selective filtering, sustained attention, attention shifting, needle-in-haystack. Based on Trinity's cognitive architecture."
)
def tagp_benchmark(llm) -> float:
    with kbench.client.enable_cache():
        runs = tagp_single.evaluate(
            llm=[llm], evaluation_data=eval_df, n_jobs=2,
            timeout=180, max_attempts=1, remove_run_files=True,
        )
    results_df = runs.as_dataframe()
    valid = results_df[results_df["result"].notna()]
    if len(valid) == 0:
        kbench.assertions.assert_true(False, expectation="No valid results")
        return 0.0
    accuracy = float(valid["result"].mean())
    kbench.assertions.assert_true(True, expectation=f"Attentional Gateway Probe accuracy: {accuracy:.2%} ({len(valid)}/{len(eval_df)})")
    return accuracy

print("✅ Outer benchmark task registered")

# === CELL 9: Run ===
run = tagp_benchmark.run(llm=kbench.llm)
print(f"\n🏆 Result: {run.result:.2%}")

# === CELL 10: Debug Output ===
if tagp_debug_log:
    print(f"\n🐛 First {len(tagp_debug_log)} failures:")
    for i, entry in enumerate(tagp_debug_log, 1):
        print(f"\n{i}. Q: {entry['question']}")
        print(f"   Expected: {entry['expected']}")
        print(f"   Got: {entry['got']}")

# === CELL 11: Choose ===
%choose tagp_benchmark
