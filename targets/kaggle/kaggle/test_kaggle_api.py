#!/usr/bin/env python3
import os
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
try:
    import kaggle_benchmarks as kbench
    print("✅ kaggle_benchmarks imported")
    client = kbench.KaggleClient()
    methods = [m for m in dir(client) if not m.startswith('_') and callable(getattr(client, m))]
    print(f"📋 Methods: {methods[:15]}")
except Exception as e:
    print(f"❌ Error: {e}")
