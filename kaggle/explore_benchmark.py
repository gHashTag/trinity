#!/usr/bin/env python3
"""Explore kaggle-benchmarks benchmark module."""

import kaggle_benchmarks as kb

print("=" * 60)
print("BENCHMARK MODULE EXPLORATION")
print("=" * 60)

# Check benchmark module
print("\nbenchmark module:")
for attr in dir(kb.benchmark):
    if not attr.startswith('_'):
        print(f"  - {attr}")

# Check client module
print("\nclient module:")
for attr in dir(kb.client):
    if not attr.startswith('_'):
        print(f"  - {attr}")

# Check task module
print("\ntask module:")
for attr in dir(kb.task):
    if not attr.startswith('_'):
        print(f"  - {attr}")

# Try to import key classes
print("\n" + "=" * 60)
print("TRYING TO IMPORT KEY CLASSES")
print("=" * 60)

try:
    from kaggle_benchmarks.benchmark import Benchmark
    print(f"✅ Benchmark class: {Benchmark}")
except ImportError as e:
    print(f"❌ Benchmark class: {e}")

try:
    from kaggle_benchmarks.client import Client
    print(f"✅ Client class: {Client}")
except ImportError as e:
    print(f"❌ Client class: {e}")

try:
    from kaggle_benchmarks.task import Task
    print(f"✅ Task class: {Task}")
except ImportError as e:
    print(f"❌ Task class: {e}")

# Check if kaggle module exists (for authentication)
try:
    from kaggle_benchmarks import kaggle
    print(f"\n✅ kaggle module: {dir(kaggle)[:10]}")
except Exception as e:
    print(f"\n❌ kaggle module: {e}")
