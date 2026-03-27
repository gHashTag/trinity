#!/usr/bin/env python3
"""
Create a simple test benchmark on Kaggle to verify format.

Usage:
    python create_test_benchmark.py
"""

import json
import os
from pathlib import Path
from kaggle_benchmarks import benchmark, model

# Try to use token from env or default
kaggle_token = os.getenv("KAGGLE_API_TOKEN", "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62")

# Get API with token
api = model.KaggleApi(token=kaggle_token)
print(f"Using Kaggle API token: {kaggle_token[:20]}...")

try:
    # Create a test benchmark
    b = benchmark.benchmark(
        title="Trinity Cognitive Probes - THLP Track Test",
        description="""
Test benchmark to verify Kaggle submission format.
Contains 250 items with mock baselines showing ~50% performance spread.
ECE, Brier, and accuracy metrics included.
""",
        data=Path(__file__).parent / "kaggle" / "data" / "thlp_learning.csv",
        model=model.Model(
            id="trinity-test-nemotron",
            gpu=None,
            architecture="trinity-cognitive-framework",
            inputs=["answer", "confidence"],
            predict=["answer"],
        ),
    submit_competition="kaggle-measuring-agi",
    )

    print(f"✅ Benchmark created!")
    print(f"Benchmark ID: {b.benchmark_id}")
    print(f"Title: {b.title}")
    print(f"Description: {b.description}")
    print(f"Data: {b.data}")
    print(f"Model: {b.model.id}")
    print(f"Competition: {b.submit_competition}")

    # Upload data to benchmark
    print("\n" + "="*60)
    print("Uploading data to Kaggle...")
    print("="*60)

    try:
        data_file = b.data
        with open(data_file, 'rb') as f:
            api.upload_data_file(b.benchmark_id, f)
        print(f"✅ Data uploaded: {data_file}")
    print(f"✅ Benchmark published: {b.benchmark_id}")
        print(f"\n" + "="*60)
        print("SUCCESS: Test benchmark ready on Kaggle!")
        print("Link to verify:")
        print(f"https://www.kaggle.com/competitions/{b.submit_competition}/{b.benchmark_id}")

    except Exception as e:
        print(f"❌ Error: {e}")
        print("\n" + "="*60)
        print("Check that:")
        print("1. You're logged into kaggle.com")
        print("2. Your account has permission to create competitions")
        print("3. Kaggle API token is valid")
        print("4. Data file exists at path")
