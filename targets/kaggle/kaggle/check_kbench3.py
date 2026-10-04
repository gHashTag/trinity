import os
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
import kaggle_benchmarks as kb
print("=== KaggleClient ===")
client = kb.kaggle.KaggleClient()
print(f"Created: {client}")
print(f"Methods: {[m for m in dir(client) if not m.startswith('_')][:10]}")
