#!/usr/bin/env python3
"""Check if benchmark exists or needs creation."""

import os
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

import kaggle as kg

api = kg.KaggleApi()

print("=" * 60)
print("CHECKING BENCHMARK STATUS")
print("=" * 60)

# Try to get benchmark info
try:
    # Check if benchmark already exists
    print("\nChecking for existing benchmarks...")
    print("\n⚠️  Kaggle CLI doesn't have benchmark listing yet")
    print("   You need to check manually on the website")
except Exception as e:
    print(f"Error: {e}")

print("\n" + "=" * 60)
print("INSTRUCTIONS")
print("=" * 60)

print("""
На странице dataset ищи кнопку:

1. **"Create Benchmark"** или **"New Benchmark"**
   - Если есть → нажми и создай benchmark

2. **Если нет такой кнопки**:
   - Это значит Kaggle Community Benchmarks ещё не доступен
   - Или нужно включить через Kaggle Labs

3. **При создании benchmark** укажи:
   - Title: Trinity Cognitive Probes - THLP Learning Track
   - Dataset: (выбери из списка)
   - Metrics: Accuracy, ECE, Brier Score
   - Models: Claude 3.5 Sonnet, GPT-4o, Gemini
   - Submission format: id,confidence,answer,track

4. **После создания** - жюри сможет прогонять модели автоматически
""")

print("\nDataset URL:")
print("https://www.kaggle.com/datasets/playra/trinity-cognitive-probes-thlp")
