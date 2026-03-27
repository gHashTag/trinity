#!/usr/bin/env python3
"""Check kaggle-benchmarks package."""

try:
    import kaggle_benchmarks
    print(f"✅ kaggle-benchmarks version: {kaggle_benchmarks.__version__}")

    # Check available modules
    import kaggle_benchmarks.client as client
    import kaggle_benchmarks.benchmark as benchmark
    import kaggle_benchmarks.model as model

    print(f"✅ Available modules:")
    print(f"   - client: {dir(client)[:5]}")
    print(f"   - benchmark: {dir(benchmark)[:5]}")
    print(f"   - model: {dir(model)[:5]}")

except ImportError as e:
    print(f"❌ kaggle-benchmarks not installed: {e}")
except Exception as e:
    print(f"❌ Error: {e}")
