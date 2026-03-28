# Kaggle Benchmarks — Trinity Hippocampal Learning Probe (THLP)
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

# === CELL 4: Load Data ===
print("📥 Downloading dataset...")
!mkdir -p /kaggle/working/datasets

kaggle.api.dataset_download_files(
    'playra/trinity-cognitive-probes-thlp',
    path='/kaggle/working/datasets/',
    unzip=True
)

csv_files = glob.glob('/kaggle/working/datasets/**/*.csv', recursive=True)
csv_path = None
for f in csv_files:
    if 'thlp_learning.csv' in f or 'thlp' in f.lower():
        csv_path = f
        break

if csv_path is None:
    raise FileNotFoundError(f"CSV not found. Files: {csv_files}")

print(f"📂 Using: {csv_path}")

df = pd.read_csv(csv_path)
eval_df = pd.DataFrame({
    "question": df["question"],
    "expected_answer": df["answer"],
})
print(f"📊 Loaded {len(eval_df)} items")

# === CELL 5: Inner Task ===
@kbench.task(name="THLP Single", store_task=False)
def thlp_single(llm, question, expected_answer) -> bool:
    prompt = f"""Based on the information provided, give a precise answer.

Question: {question}

Answer:"""
    response = llm.prompt(prompt, schema=CognitiveAnswer)
    response_clean = response.answer.lower().strip()
    expected_clean = expected_answer.lower().strip()
    pattern = rf"\b{re.escape(expected_clean)}\b"
    return bool(re.search(pattern, response_clean))

print("✅ Inner task registered")

# === CELL 6: Outer Task ===
@kbench.task(
    name="Trinity Hippocampal Learning Probe",
    description="Evaluates hippocampal-style learning: few-shot pattern induction, belief updating from evidence, error-driven learning, reward signal integration, long-context learning. Based on Trinity's Hippocampus zone."
)
def thlp_benchmark(llm) -> float:
    with kbench.client.enable_cache():
        runs = thlp_single.evaluate(
            llm=[llm], evaluation_data=eval_df, n_jobs=2,
            timeout=180, max_attempts=1, remove_run_files=True,
        )
    results_df = runs.as_dataframe()
    valid = results_df[results_df["result"].notna()]
    if len(valid) == 0:
        kbench.assertions.assert_true(False, expectation="No valid results")
        return 0.0
    accuracy = float(valid["result"].mean())
    kbench.assertions.assert_true(True, expectation=f"THLP accuracy: {accuracy:.2%} ({len(valid)}/{len(eval_df)})")
    return accuracy

print("✅ Outer benchmark task registered")

# === CELL 7: Run ===
run = thlp_benchmark.run(llm=kbench.llm)
print(f"\n🏆 Result: {run.result:.2%}")

# === CELL 8: Choose ===
%choose thlp_benchmark
