#!/usr/bin/env python3
"""Test Kaggle API with token from env."""

import os
import sys

# Set token from env
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

from kaggle_benchmarks import model, benchmark
from pathlib import Path

api = model.KaggleApi(token=os.getenv("KAGGLE_API_TOKEN"))
print(f"✅ Kaggle API connected with token: {os.getenv('KAGGLE_API_TOKEN')[:20]}...")

# List available methods
methods = [m for m in dir(api) if not m.startswith('_') and not m.startswith('get')]
print(f"Available methods: {methods[:20]}")

# Try to create a dataset first
print("\n" + "="*60)
print("Creating Kaggle Dataset...")
print("="*60)

data_path = Path("data/thlp_learning.csv")
print(f"Data file: {data_path}")
print(f"File exists: {data_path.exists()}")
print(f"File size: {data_path.stat().st_size if data_path.exists() else 'N/A'} bytes")

# Read first few lines to verify format
if data_path.exists():
    with open(data_path) as f:
        lines = f.readlines()[:5]
        print(f"\nFirst 5 lines:")
        for line in lines:
            print(f"  {line.rstrip()}")
