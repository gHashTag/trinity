#!/usr/bin/env python3
"""Verify Kaggle identity and check authentication status."""

import sys
sys.path.insert(0, '/tmp/kaggle-benchmarks')

from kaggle.api import KaggleApi

def main():
    try:
        api = KaggleApi()
        identity = api.identity()
        print(f"✅ Kaggle identity verified: {identity}")

        # Check if we can list competitions
        comps = api.competitions_list()
        print(f"✅ Can access {len(comps)} competitions")

        # Check the hackathon competition
        for c in comps:
            if 'measuring-agi' in c.ref.lower():
                print(f"✅ Found hackathon: {c.title} ({c.ref})")
                print(f"   Deadline: {c.deadline}")
                print(f"   Prize: {c.reward}")
                break
        else:
            print("⚠️  Measuring AGI competition not found - may need to join")

    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nTo authenticate:")
        print("1. Go to kaggle.com → Settings → API")
        print("2. Download kaggle.json")
        print("3. Place in ~/.kaggle/kaggle.json")

if __name__ == "__main__":
    main()
