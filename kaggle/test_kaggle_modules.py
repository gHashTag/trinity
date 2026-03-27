#!/usr/bin/env python3
"""Test Kaggle API with token from env."""

import os
import kaggle_benchmarks as kb

# Set token from env
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

# Check what's available in kaggle_benchmarks
print(f"Available in kaggle_benchmarks:")
print([x for x in dir(kb) if not x.startswith("_")][:20])

# Try to import model
try:
    from kaggle_benchmarks import model
    print(f"\n✅ model module imported")
except ImportError as e:
    print(f"\n❌ Error importing model: {e}")

# Try benchmark module
try:
    from kaggle_benchmarks import benchmark
    print(f"✅ benchmark module imported")
except ImportError as e:
    print(f"❌ Error importing benchmark: {e}")

# Check if KaggleApi exists in kaggle module
try:
    import kaggle as kg
    print(f"\n✅ kaggle module version: {kg.__version__}")
    api = kg.KaggleApi()
    print(f"✅ KaggleApi created")
except Exception as e:
    print(f"\n❌ Error with kaggle module: {e}")
