#!/usr/bin/env python3
"""
Automated Kaggle Benchmark Creation via Selenium
Creates TMP and THLP benchmark tasks from official template.
"""

import time
import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options

# Kaggle credentials
KAGGLE_USERNAME = "playra"
KAGGLE_EMAIL = "playra777@gmail.com"  # Change if different

# Code to insert (TMP task)
TMP_CODE = """import kaggle_benchmarks as kbench
import pandas as pd

@kbench.task(name="tmp_single_item")
def tmp_single_item(llm, question: str, answer: str) -> dict:
    response = llm.prompt(question)
    is_correct = answer.lower() in response.lower()
    kbench.assertions.assert_true(
        is_correct,
        expectation=f"The model's answer should contain '{answer}'."
    )
    return {"is_correct": is_correct, "model_response": response}

df = pd.DataFrame([
    {"question": "What is the capital of Uzbekistan?", "answer": "Tashkent"},
    {"question": "I incorrectly stated whales are fish. Are whales fish or mammals?", "answer": "mammals"},
    {"question": "If it rains, ground gets wet. Ground is wet. Did it rain?", "answer": "not necessarily"},
    {"question": "What's 2^20?", "answer": "1048576"},
    {"question": "Who wrote 1984?", "answer": "Orwell"}
])

@kbench.task(name="tmp_batch_accuracy")
def score_tmp_accuracy(llm, df) -> float:
    with kbench.client.enable_cache():
        runs = tmp_single_item.evaluate(
            stop_condition=lambda r: len(r) == df.shape[0],
            max_attempts=1,
            llm=[llm],
            evaluation_data=df,
            n_jobs=3,
        )
    eval_df = runs.as_dataframe()
    accuracy = float(eval_df.result.str.get("is_correct").mean())
    return accuracy

# Uncomment to test:
# _ = score_tmp_accuracy.run(kbench.llm, df)

%choose tmp_batch_accuracy
"""


class KaggleBenchmarkCreator:
    def __init__(self, headless=False):
        self.driver = None
        self.wait = None
        self.headless = headless

    def init_driver(self):
        """Initialize Chrome driver with options."""
        options = Options()
        if self.headless:
            options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])

        self.driver = webdriver.Chrome(options=options)
        self.wait = WebDriverWait(self.driver, 30)

    def login_if_needed(self):
        """Check if logged in, redirect to login if not."""
        self.driver.get("https://www.kaggle.com/account")
        time.sleep(2)

        if "login" in self.driver.current_url.lower():
            print("🔐 Login required. Please log in manually in the browser.")
            print(f"   Email: {KAGGLE_EMAIL}")
            print("   Waiting for login...")

            # Wait for user to login manually
            while "login" in self.driver.current_url.lower():
                time.sleep(2)
                if self.driver.current_url == "https://www.kaggle.com/account":
                    break

            print("✅ Logged in!")
        else:
            print("✅ Already logged in")

    def copy_official_notebook(self):
        """Copy the official Getting Started notebook."""
        print("\n📋 Opening official Getting Started notebook...")
        self.driver.get("https://www.kaggle.com/code/nicholaskanggoog/kaggle-benchmarks-getting-started-notebook")
        time.sleep(3)

        # Find and click "Copy & Edit" button
        try:
            copy_button = self.wait.until(
                EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Copy') or contains(@aria-label, 'Copy') or contains(text(), 'Edit')]"))
            )
            copy_button.click()
            print("✅ Clicked Copy & Edit")
            time.sleep(5)
        except Exception as e:
            print(f"⚠️  Copy button not found, trying alternative...")
            # Alternative: go directly to create new notebook
            self.driver.get("https://www.kaggle.com/code/new")
            time.sleep(3)

    def clear_and_replace_cells(self, code):
        """Clear existing cells and insert new code."""
        print("\n📝 Inserting new code...")

        # Wait for notebook editor to load
        time.sleep(5)

        # This is tricky - Kaggle uses Monaco editor
        # We'll try multiple approaches

        try:
            # Approach 1: Find all cell inputs and replace
            cells = self.driver.find_elements(By.CLASS_NAME, "jp-Cell-inputArea")

            if len(cells) >= 1:
                # Clear first cell and insert new code
                first_cell = cells[0]
                input_area = first_cell.find_element(By.CLASS_NAME, "jp-InputArea-editor")

                # Clear existing content
                input_area.send_keys(Keys.CONTROL + "a")
                time.sleep(0.5)
                input_area.send_keys(Keys.DELETE)

                # Insert new code
                input_area.send_keys(code)
                print("✅ Code inserted!")
                return True

        except Exception as e:
            print(f"⚠️  Cell approach failed: {e}")

        # Approach 2: Try Monaco editor API
        try:
            self.driver.execute_script("""
                // Find Monaco editor instance
                var editor = window.monaco.editor.getEditors()[0];
                if (editor) {{
                    editor.setValue(arguments[0]);
                    return 'success';
                }}
                return 'not_found';
            """, code)
            print("✅ Code inserted via Monaco API!")
            return True
        except Exception as e:
            print(f"⚠️  Monaco approach failed: {e}")

        return False

    def save_task(self):
        """Click Save Task button."""
        print("\n💾 Looking for Save Task button...")

        try:
            # Wait for Save Task button to appear
            save_button = self.wait.until(
                EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Save Task') or contains(@title, 'Save Task')]"))
            )
            save_button.click()
            print("✅ Clicked Save Task!")
            time.sleep(3)
            return True
        except Exception as e:
            print(f"⚠️  Save Task button not found: {e}")
            return False

    def run_all_cells(self):
        """Run all cells in the notebook."""
        print("\n▶️  Running all cells...")

        try:
            run_button = self.driver.find_element(By.XPATH, "//button[contains(@title, 'Run') or contains(text(), 'Run All')]")
            run_button.click()
            print("✅ Running cells...")
            time.sleep(10)  # Wait for execution
            return True
        except Exception as e:
            print(f"⚠️  Run button not found: {e}")
            return False

    def create_benchmark(self, name, code):
        """Create a single benchmark."""
        print(f"\n{'='*60}")
        print(f"Creating Benchmark: {name}")
        print(f"{'='*60}")

        self.copy_official_notebook()
        self.clear_and_replace_cells(code)

        # Optionally run cells first
        # self.run_all_cells()

        # Save Task
        self.save_task()

        print(f"\n✅ {name} notebook ready!")
        print(f"   URL: {self.driver.current_url}")
        print(f"\n   Next steps:")
        print(f"   1. Verify code looks correct")
        print(f"   2. Click 'Save Task' if not already saved")
        print(f"   3. Add to existing or new Benchmark")

    def quit(self):
        """Close the browser."""
        if self.driver:
            print("\n👋 Closing browser...")
            self.driver.quit()


def main():
    print("=" * 60)
    print("KAGGLE BENCHMARK AUTOMATOR")
    print("=" * 60)

    creator = KaggleBenchmarkCreator(headless=False)

    try:
        creator.init_driver()
        creator.login_if_needed()

        # Create TMP benchmark
        creator.create_benchmark("TMP (Metacognition)", TMP_CODE)

        print("\n" + "=" * 60)
        print("✅ AUTOMATION COMPLETE")
        print("=" * 60)
        print("\nBrowser will stay open for manual verification.")
        print("Press Enter to close...")
        input()

    except KeyboardInterrupt:
        print("\n⚠️  Interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        creator.quit()


if __name__ == "__main__":
    main()
