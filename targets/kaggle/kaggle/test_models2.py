import os
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
os.environ['MODEL_PROXY_URL'] = 'https://api.openai.com/v1'
# MODEL_PROXY_API_KEY is read from the environment (Railway/Infisical); never hardcode it.
os.environ['LLM_DEFAULT'] = 'gpt-4o'

import kaggle_benchmarks as kb

print("=== Default model ===")
try:
    model = kb.kaggle.load_default_model()
    print(f"✅ Model: {model}")
    print(f"Type: {type(model)}")
except Exception as e:
    print(f"❌ Error: {e}")

print("\n=== Judge model ===")
try:
    judge = kb.kaggle.load_judge_model()
    print(f"✅ Judge: {judge}")
except Exception as e:
    print(f"❌ Error: {e}")
