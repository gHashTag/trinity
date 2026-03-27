#!/usr/bin/env python3
"""Explore KaggleClient methods."""

from kaggle_benchmarks.kaggle import KaggleClient

print("=" * 60)
print("KAGGLECLIENT METHODS")
print("=" * 60)

client = KaggleClient()

# Show all public methods (not starting with _)
methods = [m for m in dir(client) if not m.startswith('_') and callable(getattr(client, m))]

print(f"\nFound {len(methods)} public methods:")
for method in sorted(methods):
    print(f"  - {method}")

# Check for benchmark-related methods
print("\n" + "=" * 60)
print("BENCHMARK-RELATED METHODS")
print("=" * 60)

benchmark_methods = [m for m in methods if 'benchmark' in m.lower()]
if benchmark_methods:
    for method in sorted(benchmark_methods):
        print(f"  - {method}")
else:
    print("  No direct 'benchmark' methods found")

# Check for create methods
print("\n" + "=" * 60)
print("CREATE METHODS")
print("=" * 60)

create_methods = [m for m in methods if 'create' in m.lower()]
if create_methods:
    for method in sorted(create_methods):
        print(f"  - {method}")
else:
    print("  No 'create' methods found")

# Try to get help on one method
print("\n" + "=" * 60)
print("SAMPLE METHOD HELP")
print("=" * 60)

# Try to understand the client structure
print(f"\nClient attributes: {[a for a in dir(client) if not a.startswith('_')][:20]}")
