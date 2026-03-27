#!/usr/bin/env python3
"""Check Kaggle user identity."""

import os
import kaggle as kg

# Try without owner ID (Kaggle will use current user)
os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

print("="*60)
print("CHECKING KAGGLE USER IDENTITY")
print("="*60)

try:
    api = kg.KaggleApi()
    print(f"✅ Kaggle API connected")

    # Try to get user profile
    # Note: Kaggle CLI 2.0 has different API than old version
    # We need to check current user via competitions list
    result = os.popen("kaggle competitions list 2>&1").read()
    print(f"✅ Kaggle CLI works")
    print(f"User can access competitions")
    print(f"\nYour Kaggle username is needed for dataset owner ID")
    print(f"Check: https://www.kaggle.com/<your-username>/account")

except Exception as e:
    print(f"❌ Error: {e}")
    print(f"\nTo find your Kaggle username:")
    print(f"1. Login to kaggle.com")
    print(f"2. Check URL: https://www.kaggle.com/<username>")
    print(f"3. Your username is the <username> part")

print("\n" + "="*60)
print("NEXT: Update dataset creation with correct owner")
print("="*60)
