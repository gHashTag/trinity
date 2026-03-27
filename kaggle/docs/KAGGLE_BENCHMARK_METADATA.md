# Kaggle Community Benchmarks — Metadata Templates

## THLP (Learning Track)

### Dataset Metadata
```json
{
  "title": "Trinity Cognitive Probes - THLP Learning Track",
  "description": "Part of the Trinity Cognitive Probes framework for the DeepMind AGI Hackathon.\n\nThis dataset contains 2,400 test items for evaluating learning capabilities:\n- Few-shot rule induction (3-5 examples → new rule)\n- Belief update under correction (prior → evidence → revision)\n- Error-driven learning (feedback → adaptation)\n- Reward-signal learning (outcome → policy update)\n- Long-context retention (100+ token memory)\n\nGround truth included for evaluation.",
  "keywords": ["ai", "cognitive-science", "learning", "benchmark", "deepmind", "agi", "hippocampus", "few-shot"],
  "licenses": [{"name": "MIT"}],
  "default_tags": ["ai", "cognitive-science", "learning", "benchmark"]
}
```

### Benchmark Metadata
```json
{
  "title": "Trinity Cognitive Probes - Learning Track (THLP)",
  "description": "Evaluate few-shot learning, belief updating, and error-driven learning capabilities.\n\nThis benchmark measures how well AI systems can:\n- Induce rules from few examples (3-5 shot)\n- Update beliefs when corrected by evidence\n- Learn from errors rapidly (single-shot feedback)\n- Maintain long-context information (100+ tokens)\n\n**Neural Analog**: Hippocampal cache invalidation triggers belief revision\n\n**Scoring**: Composite = 60% accuracy + 20% calibration (1-ECE) + 20% mean score\n\n**Expected Baselines**:\n- Claude 3.5 Sonnet: ~64% accuracy\n- GPT-4o: ~60-70% accuracy\n- Llama 3.3 70B: ~55-65% accuracy",
  "documentation_url": "https://github.com/gHashTag/trinity",
  "evaluation_script": "evaluate.py",
  "submission_format": {
    "columns": ["id", "confidence", "answer", "track"],
    "example": "id,confidence,answer,track\nthlp_belief_0047,0.93,100°C,thlp"
  }
}
```

## TMP (Metacognition Track)

### Benchmark Metadata
```json
{
  "title": "Trinity Cognitive Probes - Metacognition Track (TMP)",
  "description": "Evaluate confidence calibration and meta-cognitive judgment.\n\nThis benchmark measures how well AI systems can:\n- Calibrate confidence to match accuracy\n- Recognize uncertainty (\"I don't know\")\n- Discriminate known vs unknown\n- Avoid overconfidence on wrong answers\n\n**Neural Analog**: Prefrontal cortex monitoring with ACC conflict detection\n\n**Expected Baselines**:\n- Claude 3.5 Sonnet: ~34% accuracy (harder than learning)\n- GPT-4o: ~30-40% accuracy\n- Expected ECE: 0.15-0.25 (poor calibration)"
}
```

## TAGP (Attention Track)

### Benchmark Metadata
```json
{
  "title": "Trinity Cognitive Probes - Attention Track (TAGP)",
  "description": "Evaluate attentional filtering, sustained attention, and set-shifting.\n\nThis benchmark measures how well AI systems can:\n- Filter distractors from relevant information\n- Maintain focus over long contexts\n- Shift attention between task sets\n- Detect targets amid noise\n\n**Neural Analog**: Parietal-Frontal attention network with thalamic gating\n\n**Expected Baselines**: TBD (first pilot data March 2026)"
}
```

## TEFB (Executive Function Track)

### Benchmark Metadata
```json
{
  "title": "Trinity Cognitive Probes - Executive Function Track (TEFB)",
  "description": "Evaluate planning, inhibition, and working memory under constraints.\n\nThis benchmark measures how well AI systems can:\n- Plan multi-step actions under constraints\n- Inhibit prepotent responses (Stroop-like)\n- Maintain working memory under distraction\n- Resolve conflicting instructions\n\n**Complexity Enhancement**: Items include ambiguity, distractors, hidden rules\n\n**Neural Analog**: Dorsolateral PFC + Nigra + ACC for action selection\n\n**Expected Baselines**: 40-70% accuracy (complicated to avoid ceiling effects)"
}
```

## TSCP (Social Cognition Track)

### Benchmark Metadata
```json
{
  "title": "Trinity Cognitive Probes - Social Cognition Track (TSCP)",
  "description": "Evaluate theory of mind, pragmatics, and social reasoning.\n\nThis benchmark measures how well AI systems can:\n- Infer mental states (beliefs, desires, intentions)\n- Understand pragmatic implicature\n- Reason about social norms\n- Detect sarcasm and indirect meaning\n\n**Neural Analog**: Temporoparietal junction (TPJ) + medial PFC\n\n**Expected Baselines**: TBD (first pilot data March 2026)"
}
```

## Submission Format (All Tracks)

```csv
id,confidence,answer,track
thlp_belief_0047,0.930852,100°C,thlp
tmp_confidence_0000,0.896176,Tashkent,tmp
tagp_filter_0015,0.823451,The red circle,tagp
tefb_conflict_0052,0.712343,Blue,tefb
tscp_pragmatic_0030,0.654321,She was being sarcastic,tscp
```

## Evaluation Logic

The `evaluate.py` script computes:

1. **Accuracy**: Binary correct/incorrect per item (exact match or contains)
2. **ECE (Expected Calibration Error)**: Binned confidence vs accuracy
3. **Brier Score**: Mean squared error of probabilities
4. **Per-Track Metrics**: Separate accuracy/ECE for each track
5. **Composite Score**: `0.6 × accuracy + 0.2 × (1-ECE) + 0.2 × mean_score`

## Publication Checklist

### Step 1: Create Dataset (via UI)
- [ ] Go to https://www.kaggle.com/datasets
- [ ] Click "New Dataset"
- [ ] Upload `data/thlp_learning.csv`
- [ ] Set title, description, tags (from metadata above)
- [ ] Set visibility: Public
- [ ] Click "Create"

### Step 2: Create Benchmark (via UI)
- [ ] Go to https://www.kaggle.com/benchmarks
- [ ] Click "Create Benchmark"
- [ ] Fill basic info (title, description, org)
- [ ] Select dataset from Step 1
- [ ] Upload `evaluate.py` as evaluation script
- [ ] Set submission format (id, confidence, answer, track)
- [ ] Click "Create Benchmark"

### Step 3: Verify
- [ ] Go to benchmark page
- [ ] Click "Submit" (test submission)
- [ ] Upload sample submission
- [ ] Check evaluation runs successfully
- [ ] Verify scores appear on leaderboard

### Step 4: Repeat for remaining 4 tracks
- [ ] TMP (Metacognition)
- [ ] TAGP (Attention)
- [ ] TEFB (Executive Function)
- [ ] TSCP (Social Cognition)
