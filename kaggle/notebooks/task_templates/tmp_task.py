# Kaggle Benchmarks — Trinity Metacognition Probe (TMP)
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
dataset_path = "/kaggle/input/trinity-cognitive-probes-tmp/tmp_metacognition.csv"
df = pd.read_csv(dataset_path)

eval_df = pd.DataFrame({
    "question": df["question"],
    "expected_answer": df["answer"],
})

print(f"📊 Loaded {len(eval_df)} items")

# === CELL 5: Inner Task ===
@kbench.task(name="TMP Single", store_task=False)
def tmp_single(
    llm: kbench.LLM,
    question: str,
    expected_answer: str
) -> bool:
    """
    Inner task: Evaluate metacognition on a single item.
    Tests confidence calibration, error detection, knowledge boundaries.
    """
    # Metacognition-specific prompt: ask for explicit answer
    prompt = f"""Provide a direct, concise answer to this question.

Question: {question}

Answer:"""

    response = llm.prompt(prompt, schema=CognitiveAnswer)

    # Word boundary match: prevents "4" matching "42" or "no" matching "know"
    response_clean = response.answer.lower().strip()
    expected_clean = expected_answer.lower().strip()

    pattern = rf"\b{re.escape(expected_clean)}\b"
    return bool(re.search(pattern, response_clean))

print("✅ Inner task registered")

# === CELL 6: Outer Task ===
@kbench.task(
    name="Trinity Metacognition Probe",
    description="Evaluates metacognitive abilities: confidence calibration, error self-detection, knowledge boundary recognition, strategic adaptation. Based on Trinity's OFC (Orbitofrontal Cortex) architecture."
)
def tmp_benchmark(llm: kbench.LLM) -> float:
    """Evaluates model on full TMP dataset."""
    with kbench.client.enable_cache():
        runs = tmp_single.evaluate(
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
        expectation=f"TMP accuracy: {accuracy:.2%} ({len(valid)}/{len(eval_df)} items)"
    )

    return accuracy

print("✅ Outer benchmark task registered")

# === CELL 7: Run ===
run = tmp_benchmark.run(llm=kbench.llm)
print(f"\n🏆 Result: {run.result:.2%}")

# === CELL 8: Choose ===
%choose tmp_benchmark
