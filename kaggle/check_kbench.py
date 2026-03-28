import kaggle_benchmarks as kb
print("=== kaggle_benchmarks contents ===")
for attr in dir(kb):
    if not attr.startswith('_'):
        print(f"  {attr}")
