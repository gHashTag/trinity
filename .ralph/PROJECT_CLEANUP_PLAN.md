# Trinity Project Cleanup Plan

**Goal:** Organize project structure for production readiness
**Date:** 2026-02-18
**Priority:** HIGH

---

## 📊 Current State Analysis

### Problems:
1. **40+ top-level directories** - too many, hard to navigate
2. **Models scattered** - bitnet-cpp/models, models/, src/vibeec/*.tri
3. **Duplicate structures** - tools/ vs scripts/, docs/ vs book/
4. **Legacy code** - archive/, old examples/
5. **Build artifacts** - zig-out/, .zig-cache/, *.o files

---

## 🎯 Target Structure

```
trinity/
├── src/                    # Source code
│   ├── core/              # Core VM
│   ├── lang/              # VIBEE compiler
│   ├── symb/              # Symbolic AI
│   ├── network/           # P2P/DHT
│   ├── canvas/            # UI
│   └── tools/             # CLI tools
├── trinity-nexus/         # Modular workspace
│   ├── core/
│   ├── lang/
│   ├── symb/
│   ├── network/
│   ├── canvas/
│   └── tools/
├── models/                # ALL models in one place
│   ├── bitnet/
│   ├── mistral/
│   ├── qwen/
│   ├── tinyllama/
│   ├── test/
│   └── vocab/
├── specs/                 # .vibee specifications
│   └── tri/
├── generated/             # Generated code from specs
├── tests/                 # All tests
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/                  # Documentation
│   ├── api/
│   ├── architecture/
│   └── guides/
├── examples/              # Working examples only
├── deploy/                # Deployment configs
│   ├── docker/
│   ├── kubernetes/
│   └── fly.io/
├── scripts/               # Utility scripts
├── .ralph/               # Ralph agent configs
└── build.zig             # Build system

```

---

## 🗑️ Cleanup Actions

### Phase 1: Remove Redundancies

#### Move/Consolidate:
- [ ] `bitnet-cpp/models/` → `models/bitnet/`
- [ ] `src/vibeec/*.tri` → `models/test/`
- [ ] `tools/` → `scripts/`
- [ ] `book/` → `docs/guides/`
- [ ] `demos/` → `examples/`
- [ ] `trinity/` (subdir) → remove or merge

#### Remove:
- [ ] `archive/` - move to separate repo
- [ ] `zig-out/` - add to .gitignore
- [ ] `.zig-cache/` - add to .gitignore
- [ ] `*.o` files - add to .gitignore
- [ ] `node_modules/` - already in .gitignore
- [ ] Empty directories

### Phase 2: Reorganize Structure

#### Create New:
- [ ] `tests/unit/`
- [ ] `tests/integration/`
- [ ] `tests/e2e/`
- [ ] `docs/api/`
- [ ] `docs/architecture/`

#### Move:
- [ ] All test files → `tests/`
- [ ] All docs → `docs/`
- [ ] All examples → `examples/`

### Phase 3: Update References

- [ ] Update build.zig paths
- [ ] Update README.md
- [ ] Update .gitignore
- [ ] Update import paths in code

---

## 📋 Specific Files to Move

### Models (→ models/):
```
bitnet-cpp/models/BitNet-b1.58-2B-4T/model.safetensors → models/bitnet/
src/vibeec/mistral-7b-layer1.tri → models/test/
src/vibeec/test_*.tri → models/test/
```

### Examples (→ examples/):
```
examples/*.tri → keep (already correct)
bindings/wasm/igla_benchmark.tri → examples/
```

### Documentation (→ docs/):
```
book/ → docs/guides/
README.md → keep (root)
CLAUDE.md → docs/
CHANGELOG.md → docs/
```

### Scripts (→ scripts/):
```
tools/*.sh → scripts/
*.sh (root) → scripts/
```

---

## 🚫 Files/Directories to Remove

```
archive/           → Move to separate archive repo
zig-out/           → Build artifact (.gitignore)
.zig-cache/        → Build artifact (.gitignore)
*.o                → Build artifacts (.gitignore)
*.tmp              → Temp files (.gitignore)
photon_*.ppm       → Test artifacts
photon_*.wav       → Test artifacts
```

---

## 📊 Progress Tracking

| Task | Status | Files |
|------|--------|-------|
| Consolidate models | ⏳ | ~10 |
| Remove redundancies | ⏳ | ~20 |
| Reorganize structure | ⏳ | ~50 |
| Update references | ⏳ | ~30 |
| Clean gitignore | ⏳ | 1 |

**Total estimated moves:** ~110 files
**Estimated time:** 2-3 hours

---

## ✅ Success Criteria

1. All models in `models/`
2. All tests in `tests/`
3. All docs in `docs/`
4. All examples in `examples/`
5. No duplicate directories
6. No build artifacts in git
7. Clear README with structure map
8. All imports still work
9. Build passes
10. Tests pass

---

## 🔄 Next Steps

1. **Backup current state**
   ```bash
   git checkout -b cleanup/reorganization
   git add .
   git commit -m "chore: backup before cleanup"
   ```

2. **Execute cleanup in phases**
   - Phase 1: Models consolidation
   - Phase 2: Structure reorganization
   - Phase 3: Update references

3. **Verify everything works**
   ```bash
   zig build test
   zig build
   ```

4. **Commit changes**
   ```bash
   git add .
   git commit -m "chore: reorganize project structure"
   git push
   ```

---

**Status:** 📝 Plan Created
**Next:** Execute Phase 1 (Models)
**Owner:** VIBEE
