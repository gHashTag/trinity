#!/usr/bin/env python3
"""Create Kaggle Dataset for THLP track (with owner ID check)."""

import os
import subprocess

# Set token
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

# Helper to run commands with background
def run_background(cmd, description):
    """Run a command and capture output."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            env=os.environ.copy()
        )
        print(f"✅ {description}: {result.stdout.strip()}")
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

# Create dataset (without owner ID - use public)
print("\n" + "="*60)
print("STEP: Create Dataset (public owner)")
print("="*60)

dataset_dir = "/Users/playra/trinity-w1/kaggle/dataset_thlp"
os.makedirs(dataset_dir, exist_ok=True)

data_file = "/Users/playra/trinity-thlp/dataset_thlp/thlp_learning.csv"

# Skip owner ID (let Kaggle use current user)
print("Creating Kaggle Dataset without owner ID...")
print("="*60)

# Use kaggle CLI to create dataset
cmd = [
    "kaggle", "datasets", "create",
    "-p", dataset_dir,
    "-u", "ghashtag",
    "--title", "Trinity Cognitive Probes - THLP Learning Track",
    "--dir-mode", "public",
]
print(f"Command: {' '.join(cmd)}")
print("="*60 + "\n")

result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, env=os.environ.copy())
print(f"Result code: {result.returncode}")
if result.returncode == 0:
    print(f"✅ Dataset created")
else:
    print(f"❌ Error (code {result.returncode})")
if result.stderr:
    print(f"   Stderr: {result.stderr}")
print("="*60)
print("NEXT STEPS")
print("="*60)
print("1. Verify dataset exists at Kaggle UI")
print("   https://www.kaggle.com/datasets/ghashtag/trinity-cognitive-probes-thlp")
print("2. Click 'Upload Dataset' button")
print("3. Click 'Create Benchmark' button")
print("4. Set submission format: id,confidence,answer,track")
print("="*60)
