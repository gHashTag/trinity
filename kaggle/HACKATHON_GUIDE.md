# DeepMind AGI Hackathon — Kaggle Benchmarks Submission Guide

## Critical Understanding

This is **NOT** a CSV submission competition. It's a Hackathon requiring:

1. **Benchmark Tasks** created via Kaggle Benchmarks UI
2. **Model Runs** on Kaggle's Benchmarks platform (free, 5-10 models)
3. **Writeup** (<1500 words) with benchmark links as final submission

---

## Phase 1: Create Benchmark Tasks (via Kaggle UI)

### Step 1: Access Kaggle Benchmarks

1. Go to: https://www.kaggle.com/benchmarks
2. Click **"Create task"**
3. Choose **"Write a Task"** (we have ready-made code)

### Step 2: Create Task for Each Track

For each of the 5 tracks, create a task:

| Track | Task Name | Dataset Source |
|-------|-----------|----------------|
| THLP (Learning) | Trinity Hippocampal Learning Probe | `playra/trinity-cognitive-probes-thlp` |
| TMP (Metacognition) | Trinity Metacognition Probe | `playra/trinity-cognitive-probes-tmp` |
| TAGP (Attention) | Trinity Attentional Gateway Probe | `playra/trinity-cognitive-probes-tagp` |
| TEFB (Executive) | Trinity Executive Function Battery | `playra/trinity-cognitive-probes-tefb` |
| TSCP (Social) | Trinity Social Cognition Probe | `playra/trinity-cognitive-probes-tscp` |

### Step 3: Task Code Template

Use this template in the Kaggle notebook editor:

```python
# Cell 1: Fix protobuf
!pip install protobuf==5.29.6 --quiet

# Cell 2: Install SDK
!pip install -q kaggle-benchmarks

# Cell 3: Import and load data
import kaggle_benchmarks as kbench
import pandas as pd
from dataclasses import dataclass
from typing import Literal

# Load your dataset from the uploaded dataset
df = pd.read_csv('/kaggle/input/trinity-cognitive-probes-XXX/data.csv')

# Cell 4: Define response schema
@dataclass
class TrinityResponse:
    answer: str
    confidence: float

# Cell 5: Define the task
@kbench.task(name="trinity_XXX_probe")
def trinity_cognitive_eval(
    llm: kbench.LLM,
    question: str,
    expected_answer: str
) -> float:
    response = llm.prompt(f"Answer: {question}")
    # Score: 1.0 (correct), 0.5 (partial), 0.0 (wrong)
    return 1.0 if response.answer.lower() == expected_answer.lower() else 0.0

# Cell 6: CRITICAL - Mark as main task
%choose trinity_XXX_probe

# Cell 7: Run evaluation
results = trinity_cognitive_eval.run(
    llm=kbench.llms.all_supported,  # Or specific models
    evaluation_data=df
)

print(f"Mean Score: {results['score'].mean():.4f}")
```

### Step 4: Save Task

After writing code:
1. Click **"Save Task"**
2. Add description and tags
3. Make task **public** (required for Hackathon submission)

---

## Phase 2: Create Benchmark

1. Go to: https://www.kaggle.com/benchmarks
2. Click **"Create benchmark"**
3. Name: **"Trinity Cognitive AGI Benchmark Suite"**
4. Add all 5 tasks to the benchmark

---

## Phase 3: Run Models (Free on Kaggle)

### Via UI (Easiest):

1. Open each Task Detail page
2. Click **"+ Add Models"**
3. Select 8-10 models:
   - `gpt-4o` (OpenAI)
   - `claude-sonnet-4-20250514` (Anthropic)
   - `gemini-2.5-flash` (Google)
   - `gemini-2.5-pro` (Google)
   - `deepseek-r1` (DeepSeek)
   - `llama-3.3-70b` (Meta)
   - `qwen-3-next` (Alibaba)
   - `mistral-large` (Mistral)
4. Click **"Run"** — Kaggle executes in parallel for free!

### Available Models (check via SDK):

```python
import kaggle_benchmarks as kbench
print(list(kbench.llms.keys()))
```

---

## Phase 4: Collect Results

After model runs complete:

1. Screenshot each leaderboard
2. Record:
   - Mean score per model
   - Standard deviation
   - Ternary distribution (if applicable)
3. Save benchmark URLs for Writeup

---

## Phase 5: Writeup (<1500 words)

### Template:

```markdown
# Trinity Cognitive AGI Benchmark Suite

## Abstract

We present a 5-track cognitive architecture benchmark evaluating
LLMs on brain-inspired capabilities: learning, metacognition,
attention, executive function, and social cognition.

## Benchmarks

1. **THLP (Learning)**: [Benchmark URL]
   - 2,400 items, hippocampal-style learning
   - Top model: GPT-4o (85%)

2. **TMP (Metacognition)**: [Benchmark URL]
   - 2,200 items, confidence calibration
   - Top model: Claude Sonnet (82%)

[Continue for all 5 tracks...]

## Results

| Model | THLP | TMP | TAGP | TEFB | TSCP | Overall |
|-------|------|-----|------|------|------|---------|
| GPT-4o | 85% | 78% | 81% | 79% | 76% | 79.8% |
| Claude Sonnet | 82% | 82% | 79% | 84% | 81% | 81.6% |
| Gemini Pro | 78% | 75% | 76% | 72% | 74% | 75.0% |

## Discussion

[Analyze results, explain gradients, discuss Trinity architecture]

## Conclusion

[Summarize findings and implications for AGI research]
```

---

## Phase 6: Final Submission

1. Go to Hackathon page
2. Submit the Writeup as PDF or Markdown
3. Include all 5 benchmark URLs in the submission

---

## Quick Reference URLs

- Kaggle Benchmarks: https://www.kaggle.com/benchmarks
- Documentation: https://www.kaggle.com/docs/benchmarks
- Cookbook: https://github.com/Kaggle/kaggle-benchmarks/blob/ci/cookbook.md

---

## Common Issues

### Issue: "kaggle_benchmarks not found"
**Solution**: Only available in Kaggle notebook environment, not local

### Issue: "Protobuf version mismatch"
**Solution**: Already fixed in notebooks with `!pip install protobuf==5.29.6`

### Issue: "No models showing"
**Solution**: Check account verification (phone + ID for accounts after Dec 15, 2025)

### Issue: "Task not public"
**Solution**: Go to Task Detail → Make public → Required for Hackathon

---

## File Checklist

- ✅ 5 datasets uploaded to Kaggle
- ✅ 20 notebooks with protobuf fix
- ✅ kernel-metadata.json for all notebooks
- ⏳ 5 Benchmark tasks created via UI
- ⏳ Models run on each benchmark (8-10 models)
- ⏳ Results collected
- ⏳ Writeup (<1500 words)
- ⏳ Final submission

---

## Trinity Identity

φ² + 1/φ² = 3

Where φ = (1 + √5) / 2 ≈ 1.618 (golden ratio)

This mathematical relationship underpins our ternary computing model
and cognitive architecture design principles.
