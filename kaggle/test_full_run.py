import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'
os.environ['MODEL_PROXY_URL'] = 'https://api.openai.com/v1'
os.environ['MODEL_PROXY_API_KEY'] = 'ce8a4b21d9134c2988b3667d032bf88f.1votRIKGtIM99Duq'
os.environ['LLM_DEFAULT'] = 'gpt-4o'

import kaggle_benchmarks as kb
import pandas as pd

client = kb.kaggle.KaggleClient()

# Создаём task для TMP (Metacognition)
@kb.task(name="trinity_metacognition_calibration")
def metacognition_calibration(llm, question: str, answer: str) -> float:
    """Returns accuracy (0-1) for metacognition calibration."""
    response = llm.prompt(question)
    is_correct = answer.lower() in response.lower()
    kb.assertions.assert_true(is_correct, f"Should contain: {answer}")
    return 1.0 if is_correct else 0.0

# Test data
df = pd.DataFrame([
    {"question": "What is the capital of Uzbekistan?", "answer": "Tashkent"},
    {"question": "What is 2^20?", "answer": "1048576"},
    {"question": "Who wrote 1984?", "answer": "Orwell"},
])

print("🚀 Running Trinity Metacognition Benchmark")
print(f"Task: {metacognition_calibration.name}")
print(f"Items: {len(df)}")
print()

# Run benchmark
try:
    model = kb.kaggle.load_default_model()
    print(f"✅ Model loaded: {model}")
    
    with kb.client.enable_cache():
        runs = metacognition_calibration.run(
            llm=model,
            evaluation_data=df,
            stop_condition=lambda r: len(r) >= len(df),
            max_attempts=3,
            n_jobs=1
        )
    
    print(f"✅ Completed: {len(runs)} runs")
    
    # Results
    eval_df = runs.as_dataframe()
    print("\n📊 Results:")
    print(eval_df)
    
    scores = eval_df['result'].tolist()
    accuracy = sum(scores) / len(scores) if scores else 0
    print(f"\n🎯 Accuracy: {accuracy:.1%}")
    
except Exception as e:
    import traceback
    print(f"❌ Error: {e}")
    traceback.print_exc()
