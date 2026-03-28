import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'
os.environ['MODEL_PROXY_URL'] = 'https://api.openai.com/v1'
os.environ['MODEL_PROXY_API_KEY'] = 'ce8a4b21d9134c2988b3667d032bf88f.1votRIKGtIM99Duq'
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
