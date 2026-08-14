# Operational Plan — FFI Integration & Vendor Submodule Recovery

**Created**: 2026-04-19
**Owner**: Dmitrii
**Timeline**: 5 days (Day 1 = 2026-04-21, Day 5 = 2026-04-25)
**Goal**: Clear all RED list blockers and restore 70%+ GREEN status in ARCHITECTURE_MAP.md

---

## Day 1: Vendor Submodule Recovery (2026-04-21)

### Tasks

#### 1.1 Add zig-hdc submodule
```bash
git submodule add https://github.com/gHashTag/zig-hdc.git vendor/zig-hdc
cd vendor/zig-hdc
git checkout main  # or appropriate branch
cd ../..
git add vendor/zig-hdc
git commit -m "chore(vendor): add zig-hdc submodule

Добавлен zig-hdc submodule для hyperdimensional computing.

Add zig-hdc submodule for hyperdimensional computing."
```

#### 1.2 Add zig-physics submodule ✅
```bash
git submodule add https://github.com/gHashTag/zig-physics.git vendor/zig-physics
```
**Result**: vendor/zig-physics cloned (nested vendor structure corrected)
```bash
git submodule add https://github.com/gHashTag/zig-physics.git vendor/zig-physics
cd vendor/zig-physics
git checkout main
cd ../..
git add vendor/zig-physics
git commit -m "chore(vendor): add zig-physics submodule

Добавлен zig-physics submodule для physical constants.

Add zig-physics submodule for physical constants."
```

#### 1.3 Initialize all submodules ✅
```bash
git submodule update --init --recursive
```
**Result**: vendor/physics restored from commit, vendor/zig-hdc initialized
```bash
git submodule update --init --recursive
```

#### 1.4 Build verification
```bash
# Test zig-hdc build
cd vendor/zig-hdc
zig build
cd ../..

# Test zig-physics build
cd vendor/zig-physics
zig build
cd ../..
```

#### 1.5 zig-sacred-geometry 404 ✅ SKIPPED
**Reason**: gHashTag/zig-sacred-geometry repository returns 404 Not Found.

### Acceptance Criteria
- ✅ vendor/zig-hdc exists and builds
- ✅ vendor/zig-physics exists and builds  
- ✅ .gitmodules updated with 2 new submodules
- ✅ zig-sacred-geometry documented as unavailble

### Estimated time: 2 hours (ahead of plan)

---

## Day 2: T27 Specs Completion (2026-04-22)

### Tasks

#### 2.1 Complete specs/golden-float/*.t27
- Review existing specs/golden-float/*.t27
- Add missing operations (compress, quantize, etc.)
- Validate against zig-golden-float exports

#### 2.2 Complete specs/hdc/*.t27
- Review existing specs/hdc/*.t27
- Add missing operations (map, bind, bundle)
- Validate against zig-hdc exports

#### 2.3 Complete specs/physics/*.t27
- Review existing specs/physics/*.t27
- Add missing constants and formulas
- Validate against zig-physics exports

#### 2.4 Complete specs/sacred-geometry/*.t27
- Review existing specs/sacred-geometry/*.t27
- Add missing sacred sequence operations
- Document alternative if zig-sacred-geometry unavailable

#### 2.5 Validate all .t27 specs
```bash
# Run spec validator (if exists)
tri spec validate

# Or manual review
find specs/ -name "*.t27" -exec echo "Checking: {}" \;
```

### Acceptance Criteria
- ✅ All .t27 specs are complete and valid
- ✅ Specs match vendor module exports
- ✅ No TODO or FIXME comments in critical paths

### Estimated time: 6-8 hours

---

## Day 3: FFI Symbol Export Fix (2026-04-23)

### Tasks

#### 3.1 Fix zig-crypto-mining sha256 export
```zig
// In vendor/zig-crypto-mining/src/export.zig or similar
pub export fn sha256_hash(input: [*]const u8, len: usize, output: [*]u8) void {
    // Implementation
}
```

#### 3.2 Fix zig-golden-float GF16 exports
```zig
// In vendor/zig-golden-float/src/export.zig or similar
pub export fn _gf16_compress_weights(weights: [*]const f32, len: usize, output: [*]u8) void {
    // Implementation
}

pub export fn _gf16_decompress_weights(compressed: [*]const u8, len: usize, output: [*]f32) void {
    // Implementation
}
```

#### 3.3 Fix zig-sacred-geometry sacred sequence exports
```zig
// In vendor/zig-sacred-geometry/src/export.zig or similar
// OR: Recreate sacred geometry module in Trinity if vendor unavailable

pub export fn _sacred_golden_sequence(n: usize, output: [*]f64) void {
    // Implementation - generate golden sequence
}
```

#### 3.4 Rebuild all vendor modules
```bash
# Rebuild each vendor module
cd vendor/zig-crypto-mining && zig build && cd ../..
cd vendor/zig-golden-float && zig build && cd ../..
cd vendor/zig-sacred-geometry && zig build && cd ../..
```

#### 3.5 Rebuild trios FFI wrappers
```bash
# In trios workspace
cargo build -p trios-crypto
cargo build -p trios-golden-float
cargo build -p trios-sacred
```

### Acceptance Criteria
- ✅ All FFI symbols exported in vendor modules
- ✅ All trios-* crates build without link errors
- ✅ No "undefined reference" errors

### Estimated time: 6-8 hours

---

## Day 4: Integration Testing (2026-04-24)

### Tasks

#### 4.1 Run tri gen for all trios modules
```bash
tri gen specs/golden-float/*.t27
tri gen specs/hdc/*.t27
tri gen specs/physics/*.t27
tri gen specs/sacred-geometry/*.t27
```

#### 4.2 Verify FFI wrappers find symbols
```bash
# Test each wrapper
cargo test -p trios-crypto
cargo test -p trios-golden-float
cargo test -p trios-hdc
cargo test -p trios-physics
cargo test -p trios-sacred
```

#### 4.3 Run full test suite
```bash
cargo test --workspace
```

#### 4.4 Fix remaining link errors
- Investigate any remaining "undefined reference" errors
- Update export.zig files as needed
- Document workarounds in TECH_DEBT.md

### Acceptance Criteria
- ✅ All tri gen commands succeed
- ✅ All FFI wrappers pass tests
- ✅ Full workspace builds and tests pass
- ✅ < 3 remaining link errors (non-critical)

### Estimated time: 4-6 hours

---

## Day 5: Documentation & Cleanup (2026-04-25)

### Tasks

#### 5.1 Update ARCHITECTURE_MAP.md
- Update status columns: 🔴 → ✅ for completed modules
- Update RED_LIST.md: remove cleared blockers
- Add new modules if any

#### 5.2 Update TECH_DEBT.md
- Document resolved issues
- Add any new technical debt discovered
- Update debt priority rankings

#### 5.3 Create CHANGELOG.md entry
```markdown
## [Unreleased]

### Added
- zig-hdc vendor submodule
- zig-physics vendor submodule
- Complete T27 specs for golden-float, hdc, physics, sacred-geometry

### Fixed
- trios-crypto FFI sha256 symbol export
- trios-golden-float FFI GF16 symbol export
- trios-sacred FFI golden sequence symbol export

### Changed
- Updated vendor submodule references in .gitmodules
- Improved FFI integration layer

### Removed
- 7 RED list blockers cleared
```

#### 5.4 Commit and push
```bash
git add docs/ vendor/ .gitmodules
git commit -m "fix(trios): complete FFI integration and vendor submodule recovery

Day 1-5 operational plan completion:
- Added zig-hdc and zig-physics vendor submodules
- Completed all T27 specs (golden-float, hdc, physics, sacred-geometry)
- Fixed FFI symbol exports (sha256, GF16, sacred sequence)
- All trios-* modules now build and test successfully
- Updated ARCHITECTURE_MAP.md, RED_LIST.md, TECH_DEBT.md

FFI integration phase complete. 70%+ GREEN status achieved.

Full FFI integration and vendor submodule recovery completed.
All trios-* modules now build and test successfully."
git push
```

### Acceptance Criteria
- ✅ ARCHITECTURE_MAP.md shows >70% GREEN status
- ✅ RED_LIST.md has 0-1 non-critical items
- ✅ TECH_DEBT.md updated with resolved issues
- ✅ CHANGELOG.md entry created
- ✅ All changes committed and pushed

### Estimated time: 2-4 hours

---

## Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| GREEN modules | 70%+ | 7/19 (36%) |
| RED blockers | 0 | 7 |
| FFI link errors | 0 | ~10 |
| T27 specs complete | 100% | ~50% |

**Target by Day 5**: 12/19 (63%+) GREEN, 0 RED blockers, 0 FFI link errors, 100% specs complete

---

## Risk Mitigation

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| zig-sacred-geometry cannot be restored | High | High | Recreate sacred geometry module in Trinity |
| zig-golden-float symbols mismatch persists | Medium | High | Document workaround, use alternative implementation |
| zig-hdc build fails | Low | Medium | Work with zig-hdc maintainer, patch locally |
| zig-physics build fails | Low | Medium | Work with zig-physics maintainer, patch locally |

### Contingency Plans

**If zig-sacred-geometry cannot be restored:**
- Create src/sacred-geometry/ in Trinity
- Implement golden sequence operations directly
- Update trios-sacred to use local implementation
- Document in TECH_DEBT.md

**If zig-golden-float symbols cannot be matched:**
- Create adapter layer in trios-golden-float
- Map expected symbols to actual zig-golden-float exports
- Document symbol mapping in ARCHITECTURE_MAP.md

---

## Related Documents

- **ARCHITECTURE_MAP.md**: Current architecture status
- **RED_LIST.md**: Active blockers tracking
- **TECH_DEBT.md**: Technical debt tracking
- **CHANGELOG.md**: Version history (to be updated)
