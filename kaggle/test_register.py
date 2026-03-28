import os
os.environ['KAGGLE_API_TOKEN'] = 'KGAT_c178a7497385fc3a63aed579e53e5ef9'

import kaggle_benchmarks as kb
from kaggle_benchmarks import tasks

# Создаём простой task
@kb.task(name="trinity_test_task")
def test_task(llm, question: str) -> dict:
    response = llm.prompt(question)
    return {"response": response}

print("✅ Task created:", test_task)
print(f"Name: {test_task.name}")
print(f"Type: {type(test_task)}")
