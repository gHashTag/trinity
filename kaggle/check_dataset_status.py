#!/usr/bin/env python3
"""Check dataset status via Kaggle API."""

import os
import kaggle as kg

os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

print("=" * 60)
print("CHECKING DATASET STATUS VIA API")
print("=" * 60)

try:
    api = kg.KaggleApi()

    # Try to get dataset info
    print("\nTrying to get dataset: playra/trinity-cognitive-probes-thlp")

    # Note: Kaggle API 2.0 has different methods
    # Try to list datasets for current user
    datasets = api.datasets_list(mine=True)

    print(f"\nUser's datasets: {len(datasets)}")

    found = False
    for ds in datasets:
        print(f"\n  - {ds['ref']}")
        print(f"    Title: {ds['title']}")
        print(f"    URL: {ds['url']}")

        if 'playra/trinity-cognitive-probes-thlp' in ds.get('ref', ''):
            found = True
            print(f"    ✅ THIS IS OUR DATASET!")

    if not found:
        print(f"\n❌ Dataset not found in user's datasets list")
        print(f"   Might still be processing...")

except Exception as e:
    print(f"\n❌ Error: {e}")
    print(f"\nNote: Kaggle CLI 2.0 has different API structure")
    print(f"Check dataset manually at: https://www.kaggle.com/datasets/playra/trinity-cognitive-probes-thlp")
