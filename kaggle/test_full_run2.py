import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'
os.environ['MODEL_PROXY_URL'] = 'https://api.openai.com/v1'
os.environ['MODEL_PROXY_API_KEY'] = 'ce8a4b21d9134c2988b3667d032bf88f.1votRIKGtIM99Duq'
os.environ['LLM_DEFAULT'] = 'gpt-4o'

import kaggle_benchmarks as kb
import pandas as pd

# Создаём task
@kb.task(name="trinity_tmp_simple")
def tmp_simple(llm, question: str, answer: str) -> float:
    response = llm.prompt(question)
    return 1.0 if answer.lower() in response.lower() else 0.0

df = pd.DataFrame([
    {"question": "What is the capital of Uzbekistan?", "answer": "Tashkent"},
    {"question": "What is 2^20?", "answer": "1048576"},
])

print("🚀 Running benchmark...")

try:
    model = kb.kaggle.load_default_model()
    
    # Запускаем через evaluate
    with kb.client.enable_cache():
        runs = tmp_simple.evaluate(
            llm=model,
            evaluation_data=df,
            max_attempts=1
        )
    
    print(f"✅ Completed: {len(runs)} runs")
    eval_df = runs.as_dataframe()
    print(eval_df)
    
    scores = eval_df['result'].tolist()
    print(f"\n🎯 Accuracy: {sum(scores)/len(scores):.1%}")
    
except Exception as e:
    import traceback
    print(f"❌ Error: {e}")
    traceback.print_exc()
