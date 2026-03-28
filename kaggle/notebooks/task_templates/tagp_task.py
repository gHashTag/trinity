# Kaggle Benchmarks — Trinity Attentional Gateway Probe (TAGP)
# DeepMind AGI Hackathon 2026
# Based on MuSR pattern by Paul Mooney (Kaggle Staff)

# === CELL 1: Install & Fix ===
!pip install protobuf==5.29.6 --quiet
!pip install -q kaggle-benchmarks

# === CELL 2: Imports & Config ===
import os
os.environ["RENDER_SUBRUNS"] = "False"

import kaggle_benchmarks as kbench
import pandas as pd
import re
from dataclasses import dataclass

print("✅ Imports successful")

# === CELL 3: Structured Output Schema ===
@dataclass
class CognitiveAnswer:
    """Structured answer for cognitive tasks."""
    answer: str

# === CELL 4: Load Data ===
dataset_path = "/kaggle/input/trinity-cognitive-probes-tagp/tagp_attention.csv"
df = pd.read_csv(dataset_path)

# TAGP uses different column names: query, expected_focus
eval_df = pd.DataFrame({
    "question": df["query"],
    "expected_answer": df["expected_focus"],
})

print(f"📊 Loaded {len(eval_df)} items")

# === CELL 5: Inner Task ===
@kbench.task(name="TAGP Single", store_task=False)
def tagp_single(
    llm: kbench.LLM,
    question: str,
    expected_answer: str
) -> bool:
    """
    Inner task: Evaluate attentional capabilities on a single item.
    Tests selective filtering, sustained attention, attention shifting, needle-in-haystack.
    """
    # Attention-specific prompt: emphasize focus and filtering
    prompt = f"""Focus carefully on the key information requested. Provide the exact answer.

Question: {question}

Answer:"""

    response = llm.prompt(prompt, schema=CognitiveAnswer)

    # Word boundary match
    response_clean = response.answer.lower().strip()
    expected_clean = expected_answer.lower().strip()

    pattern = rf"\b{re.escape(expected_clean)}\b"
    return bool(re.search(pattern, response_clean))

print("✅ Inner task registered")

# === CELL 6: Outer Task ===
@kbench.task(
    name="Trinity Attentional Gateway Probe",
    description="Evaluates attentional gateway capabilities: selective attention filtering, sustained attention under load, attention shifting between tasks, needle-in-haystack retrieval, divided attention management. Based on Trinity's ACC (Anterior Cingulate Cortex) and Thalamic architecture."
)
def tagp_benchmark(llm: kbench.LLM) -> float:
    """Evaluates model on full TAGP dataset."""
    with kbench.client.enable_cache():
        runs = tagp_single.evaluate(
            llm=[llm],
            evaluation_data=eval_df,
            n_jobs=2,
            timeout=180,
            max_attempts=1,
            remove_run_files=True,
        )

    results_df = runs.as_dataframe()
    valid = results_df[results_df["result"].notna()]

    if len(valid) == 0:
        kbench.assertions.assert_true(False, expectation="No valid results")
        return 0.0

    accuracy = float(valid["result"].mean())

    kbench.assertions.assert_true(
        True,
        expectation=f"TAGP accuracy: {accuracy:.2%} ({len(valid)}/{len(eval_df)} items)"
    )

    return accuracy

print("✅ Outer benchmark task registered")

# === CELL 7: Run ===
run = tagp_benchmark.run(llm=kbench.llm)
print(f"\n🏆 Result: {run.result:.2%}")

# === CELL 8: Choose ===
%choose tagp_benchmark
