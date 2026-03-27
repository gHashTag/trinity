#!/usr/bin/env python3
"""Check Kaggle authentication and SDK setup."""

import sys
import kaggle_benchmarks as kb

# Try to use the kaggle client from SDK
try:
    from kaggle_benchmarks import client
    print("✅ kaggle_benchmarks.client imported")

    # Check authentication
    kc = client.get_kaggle_client()
    print(f"✅ Kaggle client: {kc}")

    # Try to get user info
    if hasattr(kc, 'user'):
        user = kc.user
        print(f"✅ User: {user}")
except Exception as e:
    print(f"❌ Error: {e}")

# Try the kaggle module directly
try:
    import kaggle as kg
    print(f"✅ kaggle module version: {kg.__version__}")

    # Try to authenticate
    api = kg.KaggleApi()
    print(f"✅ KaggleApi created")

    # Get user info
    user = api.get_user()
    print(f"✅ Authenticated as: {user}")
except Exception as e:
    print(f"❌ kaggle module error: {e}")

print("\nTo authenticate Kaggle CLI:")
print("1. Go to https://www.kaggle.com/settings")
print("2. Click 'Create New API Token'")
print("3. Download kaggle.json")
print("4. Move to ~/.kaggle/kaggle.json")
