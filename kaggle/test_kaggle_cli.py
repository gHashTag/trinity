#!/usr/bin/env python3
"""Test Kaggle CLI commands for dataset and benchmark creation."""

import os
import subprocess

# Set token
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

def run_command(cmd, description):
    """Run a command and capture output."""
    try:
        if isinstance(cmd, str):
            cmd_list = cmd.split()
        else:
            cmd_list = cmd
        result = subprocess.run(
            cmd_list,
            capture_output=True,
            text=True,
            timeout=30,
            env=os.environ.copy()
        )
        print(f"{description}")
        if result.returncode == 0:
            print(f"✅ Success: {result.stdout.strip()}")
        else:
            print(f"❌ Error (code {result.returncode}):")
            if result.stderr:
                print(f"   stderr: {result.stderr}")
            return result.stdout.strip()
    except subprocess.TimeoutExpired:
        print("❌ Timeout after 30s")
        return None
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None

def main():
    print("="*60)
    print("TESTING KAGGLE CLI COMMANDS")
    print("="*60)
    print(f"Token: {os.getenv('KAGGLE_API_TOKEN')[:20]}...")

    # Test 1: Dataset file check
    print("\n" + "-"*60)
    print("TEST 1: Dataset file check")
    dataset_file = "/Users/playra/trinity-w1/kaggle/data/thlp_learning.csv"
    run_command(f"ls -lh {dataset_file}", f"Verify dataset file exists")

    # Test 2: List Kaggle datasets
    print("\n" + "-"*60)
    print("TEST 2: List Kaggle datasets")
    run_command("kaggle datasets list", "List Kaggle datasets")

    # Test 3: Create dataset
    print("\n" + "-"*60)
    print("TEST 3: Create new dataset (dry-run)")
    # kaggle datasets new -p <folder> --title "<title>" --dir-mode <mode>
    run_command("kaggle datasets --help", "Show datasets help")

    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print("Kaggle CLI appears to have different command structure")
    print("Recommendation: Use Kaggle CLI directly with 'kaggle datasets' and 'kaggle benchmarks' commands")

if __name__ == "__main__":
    main()
