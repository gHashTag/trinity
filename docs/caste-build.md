# Trinity Caste System Build

## Architectural Invariant

**L0 and L1 must build independently of L2/L3.** If Workers (tri_farm, tri_fpga) fail to compile, Temple and Queens still build successfully.

## Build Targets

```bash
# L0: TTT (Trusted Tri Temple) — Sacred layer only
zig build l0
# → temple binary (sacred math, tri27 core, types)

# L1: Queens (Supervisors) — Independent of Workers
zig build queens    # or: zig build l1
# → queen-lotus + doctor + queens (unified L1 entry point)

# Full build (all castes)
zig build tri
# → All binaries including L2 Workers, L3 Foragers
```

## Caste Layers

| Caste | Level | Target | Binaries | Dependencies |
|-------|-------|--------|----------|--------------|
| **Temple (TTT)** | L0 | `l0` | `temple` | None (std only) |
| **Queens** | L1 | `queens`, `l1` | `queen-lotus`, `doctor`, `queens` | L0 only |
| **Workers** | L2 | - | `tri_farm`, `tri_fpga`, `inference` | L0 + L1 |
| **Foragers** | L3 | - | `train-*`, benchmarks | Any |

## Verification

```bash
# L0 must build without L2/L3
zig build l0
echo $?  # 0

# L1 must build without L2/L3
zig build queens
echo $?  # 0

# L1 entry point works
./zig-out/bin/tri-queens doctor help
```

## Implementation Notes

- `build.zig` lines 339-387: Caste system step definitions
- `src/tri/main_queens.zig`: L1 unified entry point
- `src/temple/tests.zig`: L0 sacred tests
- `src/tri/doctor/`: L1 health monitoring (Queen + Doctor)

## Migration from Old Build

Old tiered build targets (`tier-temple`, `tier-queens`) were removed to avoid duplication. Use caste targets instead:

- ❌ `zig build tier-temple` → ✅ `zig build l0`
- ❌ `zig build tier-queens` → ✅ `zig build queens`
