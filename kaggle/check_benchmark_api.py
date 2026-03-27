#!/usr/bin/env python3
"""Check Kaggle benchmark API."""

import os
from pathlib import Path

# Set token
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

# Import kaggle CLI
import kaggle as kg
api = kg.KaggleApi()
print(f"✅ KaggleApi connected")

# Try to list datasets
try:
    datasets = api.datasets_list()
    print(f"✅ Found {len(datasets)} datasets")
    for d in datasets[:5]:
        print(f"  - {d.title}")
except Exception as e:
    print(f"❌ Error listing datasets: {e}")

# Try to check for existing benchmarks
print("\n" + "="*60)
print("Checking existing datasets/benchmarks...")
print("="*60)

# Try to upload a test dataset
print("\nData file check:")
data_path = Path("/Users/playra/trinity-w1/kaggle/data/thlp_learning.csv")
print(f"  Path: {data_path}")
print(f"  Exists: {data_path.exists()}")
if data_path.exists():
    print(f"  Size: {data_path.stat().st_size} bytes")

# Try using kaggle CLI command
print("\n" + "="*60)
print("Trying kaggle CLI commands...")
print("="*60)
