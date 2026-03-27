#!/usr/bin/env python3
"""Explore kaggle-benchmarks package structure."""

import kaggle_benchmarks

print("=" * 60)
print("KAGGLE-BENCHMARKS PACKAGE EXPLORATION")
print("=" * 60)
print(f"Version: {kaggle_benchmarks.__version__}")
print(f"File: {kaggle_benchmarks.__file__}")

print("\nAll attributes:")
for attr in dir(kaggle_benchmarks):
    if not attr.startswith('_'):
        print(f"  - {attr}")

# Try to find main classes
print("\nLooking for classes...")
for attr in dir(kaggle_benchmarks):
    try:
        obj = getattr(kaggle_benchmarks, attr)
        if isinstance(obj, type) and obj.__module__ == 'kaggle_benchmarks':
            print(f"  Found class: {attr}")
            print(f"    {obj}")
    except:
        pass
