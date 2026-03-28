# Kaggle Benchmarks — Trinity Executive Function Battery (TEFB)
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
dataset_path = "/kaggle/input/trinity-cognitive-probes-tefb/tefb_executive.csv"
df = pd.read_csv(dataset_path)

# TEFB uses different column names: context, expected_result
eval_df = pd.DataFrame({
    "question": df["context"],
    "expected_answer": df["expected_result"],
})

print(f"📊 Loaded {len(eval_df)} items")

# === CELL 5: Inner Task ===
@kbench.task(name="TEFB Single", store_task=False)
def tefb_single(
    llm: kbench.LLM,
    question: str,
    expected_answer: str
) -> bool:
    """
    Inner task: Evaluate executive function on a single item.
    Tests multi-step reasoning, interference control, cognitive flexibility.
    """
    # Executive function prompt: emphasize planning and step-by-step thinking
    prompt = f"""Think through this carefully and provide the specific result.

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
    name="Trinity Executive Function Battery",
    description="Evaluates executive function capabilities: multi-step reasoning and planning, Stroop-like interference control, Wisconsin Card Sorting cognitive flexibility, working memory under load, conflict resolution. Based on Trinity's PFC (Prefrontal Cortex) architecture."
)
def tefb_benchmark(llm: kbench.LLM) -> float:
    """Evaluates model on full TEFB dataset."""
    with kbench.client.enable_cache():
        runs = tefb_single.evaluate(
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
        expectation=f"TEFB accuracy: {accuracy:.2%} ({len(valid)}/{len(eval_df)} items)"
    )

    return accuracy

print("✅ Outer benchmark task registered")

# === CELL 7: Run ===
run = tefb_benchmark.run(llm=kbench.llm)
print(f"\n🏆 Result: {run.result:.2%}")

# === CELL 8: Choose ===
%choose tefb_benchmark
