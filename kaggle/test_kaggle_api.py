#!/usr/bin/env python3
import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'

try:
    import kaggle_benchmarks as kbench
    print("✅ kaggle_benchmarks imported")
    client = kbench.KaggleClient()
    methods = [m for m in dir(client) if not m.startswith('_') and callable(getattr(client, m))]
    print(f"📋 Methods: {methods[:15]}")
except Exception as e:
    print(f"❌ Error: {e}")
