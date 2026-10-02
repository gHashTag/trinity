import os
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
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
