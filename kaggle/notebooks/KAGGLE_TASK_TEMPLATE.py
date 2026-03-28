#!/usr/bin/env python3
"""
Kaggle Benchmarks Task Generator
Generates ready-to-copy notebook code for each track
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
        "description": "Evaluates hippocampal-style few-shot learning, belief updating, error-driven learning"
    },
    "tmp": {
        "name": "Metacognition Probe",
        "dataset": "trinity-cognitive-probes-tmp",
        "task_id": "trinity_tmp_metacognition",
        "csv_file": "tmp_metacognition.csv",
        "description": "Evaluates confidence calibration, error detection, strategic adaptation"
    },
    "tagp": {
        "name": "Attentional Gateway Probe",
        "dataset": "trinity-cognitive-probes-tagp",
        "task_id": "trinity_tagp_attention",
        "csv_file": "tagp_attention.csv",
        "description": "Evaluates selective filtering, sustained attention, attention shifting, needle-in-haystack"
    },
    "tefb": {
        "name": "Executive Function Battery",
        "dataset": "trinity-cognitive-probes-tefb",
        "task_id": "trinity_tefb_executive",
        "csv_file": "tefb_executive.csv",
        "description": "Evaluates multi-step reasoning, stroop interference, wisconsin card sorting, working memory"
    },
    "tscp": {
        "name": "Social Cognition Probe",
        "dataset": "trinity-cognitive-probes-tscp",
        "task_id": "trinity_tscp_social",
        "csv_file": "tscp_social.csv",
        "description": "Evaluates theory of mind, pragmatic inference, audience adaptation, social norms"
    }
}

def generate_notebook_code(track_key: str, config: dict) -> str:
    """Generate complete notebook code for a track"""

    return f'''# Kaggle Benchmarks — {config['name']}
# Trinity Cognitive AGI Benchmark Suite
# DeepMind AGI Hackathon 2026

# === CELL 1: Fix Protobuf ===
# Fix protobuf version mismatch for kaggle_benchmarks
!pip install protobuf==5.29.6 --quiet

# === CELL 2: Install SDK ===
!pip install -q kaggle-benchmarks

# === CELL 3: Imports ===
import kaggle_benchmarks as kbench
import pandas as pd
import json
from dataclasses import dataclass
from typing import Literal, Optional
import sys

print("✅ All imports successful")
print(f"📦 Kaggle Benchmarks SDK version: {{kbench.__version__ if hasattr(kbench, '__version__') else 'latest'}}")

# === CELL 4: Load Data ===
# Load dataset from Kaggle input
dataset_path = "/kaggle/input/{config['dataset']}/{config['csv_file']}"
df = pd.read_csv(dataset_path)

print(f"📊 Loaded {{len(df)}} items from {{config['name']}}")
print(f"📋 Columns: {{list(df.columns)}}")
print(f"🔢 Tasks: {{df['task'].unique() if 'task' in df.columns else 'N/A'}}")
df.head(3)

# === CELL 5: Define Response Schema ===
@dataclass
class TrinityResponse:
    """Structured response with answer and confidence."""
    answer: str
    confidence: float  # 0.0 to 1.0
    reasoning: Optional[str] = None

@dataclass
class TernaryScore:
    """Trinity ternary score: {-1, 0, +1}"""
    score: Literal[-1, 0, 1]
    label: str  # "wrong", "uncertain", "correct"

    @staticmethod
    def from_response(response: TrinityResponse, ground_truth: str) -> 'TernaryScore':
        """Convert response to ternary score."""
        is_correct = response.answer.lower().strip() == ground_truth.lower().strip()
        is_uncertain = response.confidence < 0.5

        if is_correct:
            return TernaryScore(1, "correct")
        elif is_uncertain:
            return TernaryScore(0, "uncertain")
        else:
            return TernaryScore(-1, "wrong")

print("✅ Response schemas defined")

# === CELL 6: Define Main Task ===
@kbench.task(name="{config['task_id']}")
def trinity_cognitive_probe(
    llm: kbench.LLM,
    question: str,
    expected_answer: str,
    task_type: str = "general"
) -> float:
    """
    Trinity Cognitive Probe for {config['name']}

    Evaluates model performance on brain-inspired cognitive tasks.

    Returns:
        Float score: 1.0 (correct), 0.5 (partial), 0.0 (wrong)
    """

    # Build prompt based on task type
    if task_type == "confidence":
        prompt = f"""Answer this question and provide your confidence level (0.0 to 1.0).

Question: {{question}}

Respond with:
1. Your answer
2. Your confidence level (0.0 = guessing, 1.0 = certain)
"""
    elif task_type == "reasoning":
        prompt = f"""Think step by step and answer the following question.

Question: {{question}}

Provide your reasoning and final answer.
"""
    else:
        prompt = f"""Answer the following question.

Question: {{question}}

Your answer:"""

    # Get model response
    response = llm.prompt(prompt)

    # Extract answer (handle different response formats)
    if isinstance(response, dict):
        answer = response.get("answer", str(response))
    else:
        answer = str(response)

    # Calculate score
    expected_lower = expected_answer.lower().strip()
    answer_lower = answer.lower().strip()

    if expected_lower == answer_lower:
        return 1.0  # Correct
    elif expected_lower in answer_lower or answer_lower in expected_lower:
        return 0.5  # Partial credit
    else:
        return 0.0  # Wrong

print("✅ Task '{config['task_id']}' registered")

# === CELL 7: CRITICAL - Mark as Main Task ===
# This magic command marks this task as the main one for the leaderboard
%choose {config['task_id']}

# === CELL 8: Prepare Evaluation Data ===
# Prepare data for evaluation
eval_data = df[["question", "answer"]].head(50)  # Start with 50 items for testing
eval_data.columns = ["question", "expected_answer"]

print(f"🎯 Ready to evaluate {{len(eval_data)}} items")
print(f"📊 Sample questions:")
for i, row in eval_data.head(3).iterrows():
    print(f"  {{i+1}}. {{row['question'][:60]}}...")

# === CELL 9: Run Evaluation (Single Model Test) ===
# First test with a single model
print("🧪 Testing with default model...")

test_results = trinity_cognitive_probe.run(
    llm=kbench.llm,  # Default test LLM
    evaluation_data=eval_data.head(10)  # Test with 10 items first
)

print(f"✅ Test run complete!")
print(f"📊 Mean Score: {{test_results['score'].mean():.4f}}")
print(f"📈 Std Dev: {{test_results['score'].std():.4f}}")
print(f"🔢 Min: {{test_results['score'].min():.4f}}, Max: {{test_results['score'].max():.4f}}")

# === CELL 10: Full Evaluation ===
# Uncomment when ready for full evaluation
print("🚀 Running full evaluation...")

# Available models (check what's available)
available_models = list(kbench.llms.keys())
print(f"🤖 Available models ({{len(available_models)}}):")
for i, model in enumerate(available_models[:10], 1):
    print(f"  {{i}}. {{model}}")

# Run on selected models (modify as needed)
SELECTED_MODELS = [
    "gpt-4o",
    "claude-sonnet-4-20250514",
    "gemini-2.5-flash-exp",
    "deepseek-r1",
    "llama-3.3-70b-instruct",
]

# Filter to only available models
models_to_run = [m for m in SELECTED_MODELS if m in available_models]
print(f"🎯 Running on {{len(models_to_run)}} models: {{models_to_run}}")

if models_to_run:
    full_results = trinity_cognitive_probe.run(
        llm=models_to_run,
        evaluation_data=eval_data
    )

    # Display results
    print(f"\\n📊 Full Results ({{len(eval_data)}} items, {{len(models_to_run)}} models):")
    print("=" * 60)

    for model in models_to_run:
        model_scores = full_results[full_results['model'] == model]['score']
        print(f"{{model:40s}} | Mean: {{model_scores.mean():.4f}} | Std: {{model_scores.std():.4f}}")

    print("=" * 60)
    print(f"✅ Evaluation complete!")
    print(f"📈 Overall mean: {{full_results['score'].mean():.4f}}")
else:
    print("⚠️ No selected models available. Using default model.")
    full_results = trinity_cognitive_probe.run(
        llm=kbench.llm,
        evaluation_data=eval_data
    )
    print(f"📊 Mean Score: {{full_results['score'].mean():.4f}}")

# === CELL 11: Save Results ===
# Save results for analysis
results_summary = {{
    "track": "{track_key}",
    "benchmark": "{config['name']}",
    "n_items": len(eval_data),
    "mean_score": float(full_results['score'].mean()),
    "std_score": float(full_results['score'].std()),
    "models_tested": models_to_run if models_to_run else ["default"],
}}

output_path = "/kaggle/working/trinity_results.json"
with open(output_path, 'w') as f:
    json.dump(results_summary, f, indent=2)

print(f"💾 Results saved to: {{output_path}}")
print(json.dumps(results_summary, indent=2))

# === CELL 12: Leaderboard Summary ===
print("\\n" + "=" * 60)
print("🏆 TRINITY {config['name'].upper()} — LEADERBOARD")
print("=" * 60)
print(f"Track: {config['name']}")
print(f"Dataset: {config['dataset']}")
print(f"Items: {{len(eval_data)}}")
print(f"Overall Score: {{results_summary['mean_score']:.4f}}")
print("=" * 60)
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
    print("\n📝 Next steps:")
    print("1. Copy the code for each track")
    print("2. Go to https://www.kaggle.com/benchmarks")
    print("3. Click 'Create task' → 'Write a Task'")
    print("4. Paste the code into the notebook editor")
    print("5. Click 'Save Task'")
    print("6. Make task public")

if __name__ == "__main__":
    main()
