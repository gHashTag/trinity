#!/usr/bin/env python3
"""Explore Kaggle API methods."""

import os
import kaggle as kg

os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

print("=" * 60)
print("KAGGLE API METHODS")
print("=" * 60)

api = kg.KaggleApi()

methods = [m for m in dir(api) if not m.startswith('_') and callable(getattr(api, m))]

print(f"\nFound {len(methods)} public methods:")
for method in sorted(methods):
    print(f"  - {method}")

# Check dataset methods
print("\n" + "=" * 60)
print("DATASET METHODS")
print("=" * 60)

dataset_methods = [m for m in methods if 'dataset' in m.lower()]
for method in sorted(dataset_methods):
    print(f"  - {method}")
