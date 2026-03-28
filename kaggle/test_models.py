import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'

import kaggle_benchmarks as kb

# Check available models
print("=== Available models ===")
try:
    models = kb.kaggle.load_available_models()
    print(f"Models: {models}")
except Exception as e:
    print(f"Error: {e}")

print("\n=== Default model ===")
try:
    model = kb.kaggle.load_default_model()
    print(f"Default model: {model}")
except Exception as e:
    print(f"Error: {e}")
