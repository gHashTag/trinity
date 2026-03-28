#!/usr/bin/env python3
"""
Run Trinity Cognitive Benchmarks Locally
Then submit results to Kaggle competition
"""
import subprocess
import json
import pandas as pd
from pathlib import Path

# Install requirements
subprocess.run(["pip", "install", "-q", "kaggle-benchmarks", "openai"])

# Track configuration
TRACKS = {
    "thlp": "kaggle/data/thlp_learning.csv",
    "tmp": "kaggle/data/tmp_metacognition.csv",
    "tagp": "kaggle/data/tagp_attention.csv",
    "tefb": "kaggle/data/tefb_executive.csv",
    "tscp": "kaggle/data/tscp_social.csv",
}

# Run each notebook locally
for track, csv_path in TRACKS.items():
    print(f"Running {track} benchmark...")

    # Use papermill to execute notebook
    cmd = [
        "papermill",
        f"kaggle/notebooks/track{track[0]}*/task*_{track}*.ipynb",
        f"kaggle/results/{track}_output.ipynb",
        "-p", "DATA_PATH", csv_path,
    ]
    subprocess.run(cmd)

print("All benchmarks complete!")
print("Submit with: kaggle competitions submit -c kaggle-measuring-agi -f results/submission.csv")
