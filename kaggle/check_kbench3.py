import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'

import kaggle_benchmarks as kb
print("=== KaggleClient ===")
client = kb.kaggle.KaggleClient()
print(f"Created: {client}")
print(f"Methods: {[m for m in dir(client) if not m.startswith('_')][:10]}")
