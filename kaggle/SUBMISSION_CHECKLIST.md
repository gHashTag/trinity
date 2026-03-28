# DeepMind AGI Hackathon — Submission Checklist

## Current Status

### ✅ Completed
- [x] 5 datasets uploaded to Kaggle
- [x] 20 notebooks created with protobuf fix
- [x] kernel-metadata.json files generated
- [x] 1 kernel pushed: `playra/trinity-metacognition-probe-tmp-t27`
- [x] Task templates generated (5 files)

### ⏳ Pending (Kaggle UI Required)
- [ ] Create 5 Benchmark Tasks via Kaggle Benchmarks UI
- [ ] Run 8-10 models on each benchmark
- [ ] Collect leaderboard results
- [ ] Write Writeup (<1500 words)
- [ ] Submit Writeup to Hackathon

---

## Step-by-Step Instructions

### Step 1: Create Benchmark Tasks (30 minutes)

1. Go to: https://www.kaggle.com/benchmarks
2. For each track, click **"Create task"** → **"Write a Task"**

3. Use these task templates:
   - **THLP**: Copy `kaggle/notebooks/task_templates/thlp_task.py`
   - **TMP**: Copy `kaggle/notebooks/task_templates/tmp_task.py`
   - **TAGP**: Copy `kaggle/notebooks/task_templates/tagp_task.py`
   - **TEFB**: Copy `kaggle/notebooks/task_templates/tefb_task.py`
   - **TSCP**: Copy `kaggle/notebooks/task_templates/tscp_task.py`

4. Paste into notebook editor
5. **IMPORTANT**: Make sure Cell 1 has the protobuf fix
6. Click **"Save Task"**
7. Add description: "Trinity Cognitive AGI Benchmark - [Track Name]"
8. Make task **public**

### Step 2: Verify Tasks Run (10 minutes)

For each task:
1. Click **"Save & Run All"**
2. Check for errors
3. Verify output shows scores

**Expected output:**
```
✅ All imports successful
📊 Loaded 50 items from [Track Name]
✅ Task 'trinity_XXX_probe' registered
🧪 Testing with default model...
✅ Test run complete!
📊 Mean Score: 0.XXXX
```

### Step 3: Add Models to Each Task (15 minutes)

For each task page:
1. Click **"+ Add Models"**
2. Select these models:
   - gpt-4o
   - claude-sonnet-4-20250514
   - gemini-2.5-flash-exp
   - gemini-2.5-pro
   - deepseek-r1
   - llama-3.3-70b-instruct
   - mistral-large
   - qwen-3-next
3. Click **"Run"**

### Step 4: Collect Results (after runs complete)

For each benchmark:
1. Screenshot the leaderboard
2. Record scores:
   ```
   Track: [NAME]
   URL: [benchmark URL]

   Model | Score | Std Dev
   ------|-------|--------
   GPT-4o | 0.XX | 0.XX
   Claude | 0.XX | 0.XX
   ...
   ```

### Step 5: Create Benchmark (5 minutes)

1. Go to: https://www.kaggle.com/benchmarks
2. Click **"Create benchmark"**
3. Name: **"Trinity Cognitive AGI Benchmark Suite"**
4. Add all 5 tasks
5. Add all models
6. Make public

### Step 6: Write Writeup (<1500 words)

Use template in `HACKATHON_GUIDE.md`

Structure:
1. Abstract (100 words)
2. Introduction (200 words)
3. Benchmark Descriptions (500 words)
4. Results (400 words)
5. Discussion (200 words)
6. Conclusion (100 words)

Include:
- All 5 benchmark URLs
- Leaderboard tables
- Model comparison
- Trinity architecture notes

### Step 7: Submit to Hackathon

1. Go to Hackathon page
2. Submit Writeup as PDF
3. Include benchmark URLs in submission

---

## File Locations

| File | Path |
|------|------|
| Task Templates | `kaggle/notebooks/task_templates/*.py` |
| Guide | `kaggle/HACKATHON_GUIDE.md` |
| Datasets | `kaggle/data/*.csv` |
| Notebooks | `kaggle/notebooks/track*/*.ipynb` |

---

## Quick Commands

```bash
# List datasets
kaggle datasets list --mine

# List kernels
kaggle kernels list --mine

# View task template
cat kaggle/notebooks/task_templates/tmp_task.py
```

---

## Troubleshooting

### "Protobuf version mismatch"
**Solution**: First cell must have:
```python
!pip install protobuf==5.29.6 --quiet
```

### "kaggle_benchmarks not found"
**Solution**: Only works in Kaggle notebook environment

### "No models available"
**Solution**: Check account verification (phone + ID)

### "Task not public"
**Solution**: Task Detail → Make public

---

## Success Criteria

✅ 5 public benchmark tasks on Kaggle
✅ 8-10 models run on each
✅ Leaderboard shows model gradients
✅ Writeup <1500 words
✅ All benchmark URLs included

---

## Trinity Identity

φ² + 1/φ² = 3

This mathematical relationship underpins our ternary computing model
and cognitive architecture design principles.
