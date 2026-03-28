import os
import inspect
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'

import kaggle_benchmarks as kb
client = kb.kaggle.KaggleClient()

print("=== register_task signature ===")
print(inspect.signature(client.register_task))

print("\n=== run_task signature ===")
print(inspect.signature(client.run_task))
