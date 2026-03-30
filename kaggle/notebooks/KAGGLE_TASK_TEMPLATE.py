#!/usr/bin/env python3
"""
Kaggle Benchmarks Task Generator v2
Generates ready-to-copy notebook code for each track
FIXED: CSV detection bug + flexible matching + debug logging
"""
import os
from pathlib import Path

# Track configuration
TRACKS = {
    "thlp": {
        "name": "Hippocampal Learning Probe",
        "dataset": "trinity-cognitive-probes-thlp",
        "task_id": "trinity_thlp_learning",
        "csv_file": "thlp_learning.csv",
        "description": "Evaluates hippocampal-style few-shot learning, belief updating, error-driven learning",
        "question_col": "question",
        "answer_col": "answer"
    },
    "tmp": {
        "name": "Metacognition Probe",
        "dataset": "trinity-cognitive-probes-tmp",
        "task_id": "trinity_tmp_metacognition",
        "csv_file": "tmp_metacognition.csv",
        "description": "Evaluates confidence calibration, error detection, strategic adaptation",
        "question_col": "question",
        "answer_col": "answer"
    },
    "tagp": {
        "name": "Attentional Gateway Probe",
        "dataset": "trinity-cognitive-probes-tagp",
        "task_id": "trinity_tagp_attention",
        "csv_file": "tagp_attention.csv",
        "description": "Evaluates selective filtering, sustained attention, attention shifting, needle-in-haystack",
        "question_col": "query",
        "answer_col": "expected_focus"
    },
    "tefb": {
        "name": "Executive Function Battery",
        "dataset": "trinity-cognitive-probes-tefb",
        "task_id": "trinity_tefb_executive",
        "csv_file": "tefb_executive.csv",
        "description": "Evaluates multi-step reasoning, stroop interference, wisconsin card sorting, working memory",
        "question_col": "context",
        "answer_col": "expected_result"
    },
    "tscp": {
        "name": "Social Cognition Probe",
        "dataset": "trinity-cognitive-probes-tscp",
        "task_id": "trinity_tscp_social",
        "csv_file": "tscp_social.csv",
        "description": "Evaluates theory of mind, pragmatic inference, audience adaptation, social norms",
        "question_col": "scenario",
        "answer_col": "expected_inference"
    }
}

def generate_notebook_code(track_key: str, config: dict) -> str:
    """Generate complete notebook code for a track"""

    return f'''# Kaggle Benchmarks — {config['name']}
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
    exp_core = re.sub(r'\\s*\\(.*?\\)\\s*', ' ', exp).strip()
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
    # Only use if expected doesn't contain special chars that confuse \\b
    if not any(c in exp for c in ['(', ')', '[', ']', '*', '+', '?', '_', '-']):
        pattern = rf"\\b{{re.escape(exp)}}\\b"
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
    'playra/{config['dataset']}',
    path='/kaggle/working/datasets/',
    unzip=True
)

# FIXED: Use endswith() instead of fuzzy matching to avoid wrong dataset detection
csv_files = glob.glob('/kaggle/working/datasets/**/*.csv', recursive=True)
csv_path = None
for f in csv_files:
    if f.endswith('{config['csv_file']}'):
        csv_path = f
        break

if csv_path is None:
    raise FileNotFoundError(f"CSV not found. Files: {{csv_files}}")

print(f"📂 Using: {{csv_path}}")

df = pd.read_csv(csv_path)

# Fixed column mapping for this track
eval_df = pd.DataFrame({{
    "question": df["{config['question_col']}"],
    "expected_answer": df["{config['answer_col']}"]
}})

print(f"📊 Loaded {{len(eval_df)}} items")

# === CELL 6: Inner Task with Debug Logging ===
@kbench.task(name="{config['task_id']} Single", store_task=False)
def {track_key}_single(llm, question, expected_answer) -> bool:
    """Single item evaluation with debug logging for first 10 failures."""
    prompt = f"""Based on the information provided, give a precise answer.

Question: {{question}}

Answer:"""
    response = llm.prompt(prompt, schema=CognitiveAnswer)

    matched = match_answer(response.answer, expected_answer)

    # Debug logging (first 10 failures only, stored in global)
    if not matched and len({track_key}_single.debug_log) < 10:
        {track_key}_single.debug_log.append({{
            "question": question[:80],
            "expected": expected_answer,
            "got": response.answer[:150]
        }})

    return matched

# Initialize debug log
{track_key}_single.debug_log = []

print("✅ Inner task registered")

# === CELL 7: Outer Task ===
@kbench.task(
    name="Trinity {config['name']}",
    description="{config['description']}. Based on Trinity's cognitive architecture."
)
def {track_key}_benchmark(llm) -> float:
    with kbench.client.enable_cache():
        runs = {track_key}_single.evaluate(
            llm=[llm], evaluation_data=eval_df, n_jobs=2,
            timeout=180, max_attempts=1, remove_run_files=True,
        )
    results_df = runs.as_dataframe()
    valid = results_df[results_df["result"].notna()]
    if len(valid) == 0:
        kbench.assertions.assert_true(False, expectation="No valid results")
        return 0.0
    accuracy = float(valid["result"].mean())
    kbench.assertions.assert_true(True, expectation=f"{config['name']} accuracy: {{accuracy:.2%}} ({{len(valid)}}/{{len(eval_df)}})")
    return accuracy

print("✅ Outer benchmark task registered")

# === CELL 8: Run ===
run = {track_key}_benchmark.run(llm=kbench.llm)
print(f"\\n🏆 Result: {{run.result:.2%}}")

# === CELL 9: Debug Output ===
if {track_key}_single.debug_log:
    print(f"\\n🐛 First {{len({track_key}_single.debug_log)}} failures:")
    for i, entry in enumerate({track_key}_single.debug_log, 1):
        print(f"\\n{{i}}. Q: {{entry['question']}}")
        print(f"   Expected: {{entry['expected']}}")
        print(f"   Got: {{entry['got']}}")

# === CELL 10: Choose ===
%choose {track_key}_benchmark
'''

def main():
    """Generate notebook code for all tracks"""
    output_dir = Path("kaggle/notebooks/task_templates")
    output_dir.mkdir(exist_ok=True)

    for track_key, config in TRACKS.items():
        code = generate_notebook_code(track_key, config)
        output_path = output_dir / f"{track_key}_task.py"
        with open(output_path, 'w') as f:
            f.write(code)
        print(f"✅ Generated {output_path}")

    print(f"\n📊 Generated {len(TRACKS)} task templates")
    print(f"📁 Output directory: {output_dir}")
    print("\n📝 Changes:")
    print("  • FIXED: CSV detection using endswith() instead of fuzzy match")
    print("  • ADDED: Strategy 0 matching (strip parenthetical annotations)")
    print("  • ADDED: Flexible matching with 5 strategies")
    print("  • ADDED: Debug logging for first 10 failures")
    print("  • FIXED: Hardcoded column mappings per track (no undefined variables)")

if __name__ == "__main__":
    main()
