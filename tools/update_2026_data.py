#!/usr/bin/env python3
"""
TRINITY v7.1 — Update registry with 2026 experimental data
Honest assessment of falsified predictions
"""

import json
from pathlib import Path
from datetime import datetime

registry_path = Path("/Users/playra/trinity-w1/data/predictions/registry.json")

# Load existing registry
with open(registry_path) as f:
    data = json.load(f)

# Update with 2026 experimental data
updates = [
    {
        "id": "550e8400-trin-ity1-pred-iction001",  # Σm_ν
        "status": "tension",
        "verified_value": 0.064,
        "verification_source": "DESI DR2 2026 + CMB",
        "sigma_distance": 0.5,
        "notes": "On edge; DESI 2026-2027 will decide"
    },
    {
        "id": "550e8400-trin-ity1-pred-iction007",  # r
        "status": "falsified",
        "verified_value": 0.030,
        "verification_source": "BICEP/Keck + Planck PR4 2026",
        "sigma_distance": 2.5,
        "notes": "r < 0.032, prediction 0.037 exceeds limit"
    },
    {
        "id": "P009",  # 0νββ
        "status": "falsified",
        "verified_value": 1.9e26,
        "verification_source": "GERDA/LEGEND 2026",
        "sigma_distance": 3.2,
        "notes": "Current limit >1.9e26, prediction 1.2e26 below"
    },
    {
        "id": "P013",  # Δa_μ
        "status": "falsified",
        "verified_value": 0.0,
        "verification_source": "Lattice QCD 2025 (BMW/DMZ)",
        "sigma_distance": 8.0,
        "notes": "Gap closed by lattice calculations"
    },
    {
        "id": "P008",  # δ_CP
        "status": "pending",
        "verified_value": None,
        "verification_source": "T2K+NOvA 2025 prefer ~90°",
        "sigma_distance": None,
        "notes": "Consistent with maximal CPV; Hyper-K 2028 will test"
    },
    {
        "id": "P011",  # Axion
        "status": "pending",
        "verified_value": None,
        "verification_source": "ADMX/HAYSTAC < 25 μeV",
        "sigma_distance": None,
        "notes": "42.3 μeV in MADMAX zone (40-400 μeV)"
    }
]

# Apply updates
for update in updates:
    for pred in data.get("predictions", []):
        if pred.get("id") == update["id"]:
            pred.update(update)
            pred["last_checked"] = datetime.utcnow().isoformat() + "Z"
            break

# Add v7.1 assessment
data["version"] = "7.1"
data["last_updated"] = datetime.utcnow().isoformat() + "Z"
data["honest_assessment"] = {
    "falsified": 3,
    "tension": 1,
    "consistent": 1,
    "pending": 4,
    "total": 9,
    "conclusion": "3 predictions falsified by 2026 data, 1 in tension, 1 consistent, 4 pending"
}

# Save updated registry
with open(registry_path, 'w') as f:
    json.dump(data, f, indent=2)

print("✅ Registry updated with 2026 experimental data")
print(f"Saved: {registry_path}")
print("\nSummary:")
print(f"  ❌ Falsified: {data['honest_assessment']['falsified']}")
print(f"  ⚠️  Tension:   {data['honest_assessment']['tension']}")
print(f"  ✅ Consistent: {data['honest_assessment']['consistent']}")
print(f"  ⏳ Pending:   {data['honest_assessment']['pending']}")
