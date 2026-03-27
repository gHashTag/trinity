#!/usr/bin/env python3
"""Check dataset status via Kaggle API."""

import os
import kaggle as kg

os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

print("=" * 60)
print("CHECKING DATASET STATUS")
print("=" * 60)

api = kg.KaggleApi()

# Try dataset_list to get user's datasets
print("\nMethod 1: dataset_list()")
try:
    result = api.dataset_list(mine=True)
    print(f"✅ Got {len(result)} datasets")

    found = False
    for ds in result:
        ref = getattr(ds, 'ref', getattr(ds, 'url', 'N/A'))
        title = getattr(ds, 'title', 'N/A')

        if 'trinity-cognitive-probes-thlp' in str(ref).lower() or 'trinity' in str(title).lower():
            print(f"\n✅ FOUND: {title}")
            print(f"   Ref: {ref}")
            found = True
        else:
            print(f"   - {title}")

    if not found:
        print(f"\n❌ Dataset 'trinity-cognitive-probes-thlp' not found")
        print(f"   Still processing...")

except Exception as e:
    print(f"❌ Error: {e}")

# Try dataset_status
print("\n" + "=" * 60)
print("Method 2: dataset_status()")
try:
    result = api.dataset_status('playra/trinity-cognitive-probes-thlp')
    print(f"✅ Status: {result}")
except Exception as e:
    print(f"❌ Error: {e}")

print("\n" + "=" * 60)
print("MANUAL CHECK")
print("=" * 60)
print("Open: https://www.kaggle.com/datasets/playra/trinity-cognitive-probes-thlp")
