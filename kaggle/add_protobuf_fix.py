#!/usr/bin/env python3
"""
Add protobuf version fix to all notebooks
"""
import json
from pathlib import Path

# Protobuf fix cell
FIX_CELL = {
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "# Fix protobuf version mismatch for kaggle_benchmarks\n",
        "!pip install protobuf==5.29.6 --quiet\n"
    ]
}

def fix_notebook(nb_path: Path):
    """Add protobuf fix as first cell if not already present"""
    with open(nb_path) as f:
        data = json.load(f)

    # Check if fix already exists
    first_cell = data.get("cells", [{}])[0]
    source = first_cell.get("source", [])
    if isinstance(source, str):
        source_lines = source.split('\n')
    else:
        source_lines = source

    has_fix = any("protobuf" in line for line in source_lines if isinstance(line, str))

    if not has_fix:
        data["cells"].insert(0, FIX_CELL)
        with open(nb_path, 'w') as f:
            json.dump(data, f, indent=1)
        print(f"✅ Fixed {nb_path.name}")
        return True
    else:
        print(f"⏭️  Already fixed {nb_path.name}")
        return False

def main():
    base = Path("kaggle/notebooks")
    fixed_count = 0

    for nb_file in base.glob("track*/*.ipynb"):
        if fix_notebook(nb_file):
            fixed_count += 1

    print(f"\n📊 Fixed {fixed_count} notebooks")

if __name__ == "__main__":
    main()
