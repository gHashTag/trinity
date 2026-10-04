import os
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
os.environ['MODEL_PROXY_URL'] = 'https://api.openai.com/v1'
# MODEL_PROXY_API_KEY is read from the environment (Railway/Infisical); never hardcode it.
os.environ['LLM_DEFAULT'] = 'gpt-4o'

import kaggle_benchmarks as kb
import pandas as pd

@kb.task(name="trinity_tmp_v2")
def tmp_task(llm, question: str, answer: str) -> float:
    response = llm.prompt(question)
    return 1.0 if answer.lower() in response.lower() else 0.0

df = pd.DataFrame([
    {"question": "Capital of Uzbekistan?", "answer": "Tashkent"},
    {"question": "What is 2^20?", "answer": "1048576"},
])

print("🚀 Running benchmark...")

try:
    # Используем grid для параметров
    with kb.client.enable_cache():
        runs = tmp_task.evaluate(
            evaluation_data=df,
            grid={"llm": [kb.kaggle.load_default_model()]},
            max_attempts=1
        )
    
    print(f"✅ Runs: {len(runs)}")
    eval_df = runs.as_dataframe()
    print(eval_df[['question', 'answer', 'result']])
    
except Exception as e:
    import traceback
    print(f"❌ Error: {e}")
    traceback.print_exc()
