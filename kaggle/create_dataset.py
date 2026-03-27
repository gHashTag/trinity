#!/usr/bin/env python3
"""Create Kaggle Dataset for THLP track."""

import os
import subprocess

os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

# Step 1: Initialize dataset metadata
print("="*60)
print("STEP 1: Initialize Dataset Metadata")
print("="*60)

dataset_dir = "/Users/playra/trinity-w1/kaggle/dataset_thlp"
os.makedirs(dataset_dir, exist_ok=True)

# Create data subdirectory and copy data file
import shutil
data_subdir = f"{dataset_dir}/data"
os.makedirs(data_subdir, exist_ok=True)

data_src = "/Users/playra/trinity-w1/kaggle/data/thlp_learning.csv"
data_dst = f"{data_subdir}/thlp_learning.csv"
shutil.copy(data_src, data_dst)
print(f"✅ Copied data file to {data_dst}")

# Create dataset.json
import json
dataset_meta = {
    "title": "Trinity Cognitive Probes - THLP Learning Track",
    "id": "ghashtag/trinity-cognitive-probes-thlp",
    "licenses": [{"name": "MIT"}],  # REQUIRED field
    "slug": "trinity-cognitive-probes-thlp",
    "subtitle": "Hippocampal Learning Probe for AGI Assessment",
    "description": """
**Part of the DeepMind AGI Hackathon Submission**

The THLP (Trinity Hippocampal Learning Probe) track evaluates few-shot learning, belief updating, and error-driven learning capabilities.

**Contains:**
- 2,400 test items
- Ground truth labels
- Difficulty levels (φ-scaled: 3, 5, 8, 13, 21)
- 5 cognitive task types

**Neural Analog:** Hippocampal cache invalidation triggers belief revision

**Expected Baselines:**
- Claude 3.5 Sonnet: ~64% accuracy (real pilot data)
- Nemotron 120B: ~22% accuracy (real pilot data)
- 42% spread = excellent task differentiation

**Evaluation Metrics:**
- Accuracy: Binary correct/incorrect per item
- ECE (Expected Calibration Error): Confidence calibration
- Brier Score: Mean squared error of probabilities
- Composite: 60% accuracy + 20% calibration + 20% mean score

**Organization:** gHashTag/trinity
**License:** MIT
""",
    "id": "ghashtag/trinity-cognitive-probes-thlp",
    "resources": [
        {
            "path": "data/thlp_learning.csv",
            "description": "THLP Learning Track - 2,400 items with ground truth"
        }
    ]
}

with open(f"{dataset_dir}/dataset-metadata.json", "w") as f:
    json.dump(dataset_meta, f, indent=2)

print(f"✅ Created metadata at {dataset_dir}/dataset-metadata.json")

# Step 2: Create dataset
print("\n" + "="*60)
print("STEP 2: Create Dataset")
print("="*60)

# Use kaggle CLI to create dataset
cmd = [
    "kaggle", "datasets", "create",
    "-p", dataset_dir,
    "-u",  # public dataset
    "-r", "skip"  # skip directory mode, upload files directly
]

result = subprocess.run(cmd, capture_output=True, text=True, env=os.environ.copy())
print(f"stdout: {result.stdout}")
if result.returncode != 0:
    print(f"stderr: {result.stderr}")
else:
    print("✅ Dataset creation command sent")

print("\n" + "="*60)
print("NEXT STEPS")
print("="*60)
print("1. Verify dataset created at:")
print("   https://www.kaggle.com/datasets/ghashtag/trinity-cognitive-probes-thlp")
print("2. Create Benchmark via Kaggle UI:")
print("   - Link dataset to benchmark")
print("   - Set submission format (id, confidence, answer, track)")
print("   - Include evaluation script")
