import os
# KAGGLE_API_TOKEN is read from the environment (Railway/Infisical); never hardcode it.
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
