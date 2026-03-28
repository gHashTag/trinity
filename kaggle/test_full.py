import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'

import kaggle_benchmarks as kb
import pandas as pd

client = kb.kaggle.KaggleClient()

# Создаём task
@kb.task(name="trinity_metacognition")
def metacognition_task(llm, question: str, answer: str) -> dict:
    response = llm.prompt(question)
    is_correct = answer.lower() in response.lower()
    kb.assertions.assert_true(is_correct, f"Should contain: {answer}")
    return {"is_correct": is_correct, "response": response}

# Test data
df = pd.DataFrame([
    {"question": "What is the capital of Uzbekistan?", "answer": "Tashkent"},
    {"question": "What is 2^20?", "answer": "1048576"},
])

print("✅ Task created")
print("📊 Test data prepared")
print(f"Task: {metacognition_task.name}")

# Try to register
try:
    result = client.register_task(metacognition_task)
    print(f"✅ Registered: {result}")
except Exception as e:
    print(f"⚠️  Register: {e}")

# Try to run
try:
    with kb.client.enable_cache():
        runs = metacognition_task.run(
            llm=kb.llm,
            evaluation_data=df,
            stop_condition=lambda r: len(r) >= 2,
            max_attempts=1
        )
    print(f"✅ Runs completed: {len(runs)}")
    print(runs.as_dataframe())
except Exception as e:
    print(f"⚠️  Run: {e}")
