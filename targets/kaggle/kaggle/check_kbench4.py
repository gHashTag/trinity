import os
import inspect
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
import kaggle_benchmarks as kb
client = kb.kaggle.KaggleClient()

print("=== register_task signature ===")
print(inspect.signature(client.register_task))

print("\n=== run_task signature ===")
print(inspect.signature(client.run_task))
