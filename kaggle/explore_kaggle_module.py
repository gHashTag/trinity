#!/usr/bin/env python3
"""Explore kaggle_benchmarks.kaggle module."""

from kaggle_benchmarks import kaggle

print("=" * 60)
print("KAGGLE MODULE (kaggle_benchmarks.kaggle)")
print("=" * 60)

# Check all classes
for name in dir(kaggle):
    if not name.startswith('_'):
        obj = getattr(kaggle, name)
        if isinstance(obj, type):
            print(f"\nClass: {name}")
            print(f"  Doc: {obj.__doc__[:100] if obj.__doc__ else 'N/A'}")

# Try KaggleClient
print("\n" + "=" * 60)
print("TRYING KAGGLECLIENT")
print("=" * 60)

try:
    client = kaggle.KaggleClient()
    print(f"✅ KaggleClient created: {client}")
except Exception as e:
    print(f"❌ KaggleClient error: {e}")

# Check BenchmarkTaskRun
print("\n" + "=" * 60)
print("BENCHMARKTASKRUN")
print("=" * 60)

try:
    print(f"✅ BenchmarkTaskRun: {kaggle.BenchmarkTaskRun}")
    print(f"   Attributes: {[a for a in dir(kaggle.BenchmarkTaskRun) if not a.startswith('_')][:20]}")
except Exception as e:
    print(f"❌ BenchmarkTaskRun error: {e}")

# Check if there's a benchmark creation function
print("\n" + "=" * 60)
print("LOOKING FOR CREATE/UPLOAD FUNCTIONS")
print("=" * 60)

for module_name in ['kaggle_benchmarks', 'kaggle_benchmarks.kaggle']:
    try:
        import importlib
        mod = importlib.import_module(module_name)
        print(f"\n{module_name}:")
        for attr in dir(mod):
            if 'create' in attr.lower() or 'upload' in attr.lower() or 'publish' in attr.lower():
                print(f"  - {attr}")
    except:
        pass
