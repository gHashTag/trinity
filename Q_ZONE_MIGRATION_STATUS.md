# Q-Zone Migration Status

## Current State

The Anti-Fragile Import Law implementation has been successfully completed for:
- ✅ **Temple zone** (T-zone) — `src/temple/root.zig` re-exports all sacred modules
- ✅ **TRI-27** — compiles successfully using tri_lang named module
- ✅ **TRI-Lang zone** (J-zone) — `src/tri-lang/root.zig` re-exports compiler modules
- ✅ **VSA zone** (V-zone) — `src/vsa.zig` re-exports all VSA modules

## Q-Zone Issues (Migration Debt)

The Queen zone (Q-zone) has deep architectural issues that cannot be quickly fixed:

### Module Ownership Conflicts

Files in `src/tri/` are imported by both:
1. **tri executable** (root module: `src/tri/main.zig`)
2. **queen module** (root: `src/queen/root.zig`)

Zig doesn't allow a file to belong to two modules simultaneously.

### Conflicting Files

| File | Used By (tri) | Used By (queen) | Conflict |
|------|---------------|-----------------|----------|
| `github_client.zig` | tri_cloud.zig | queen_issues.zig | ❌ |
| `github_app_auth.zig` | tri_cloud.zig | queen_issues.zig | ❌ |
| `hippocampus.zig` | main.zig (as tri_memory) | queen_dmpfc.zig | ❌ |
| `farm_accounts.zig` | tri_cloud.zig | queen_dlpfc.zig | ❌ |
| `tri_colors.zig` | tri_utils.zig | queen_actions.zig | ⚠️ (fixed locally) |

### Files in Wrong Zone

These files exist in `src/queen/` but should be in `src/tri/`:
- `faculty_types.zig`
- `cortex.zig`
- `thalamus.zig`
- `cerebellum.zig`
- `insula.zig`
- `phoenix_medulla.zig`
- `phoenix_pons.zig`

## Solution Path

### Option A: Full Zone Separation (Wave 3)

1. Move conflicting files from `src/tri/` to dedicated zones:
   - `src/github/` — github_client, github_app_auth
   - `src/memory/` — hippocampus
   - `src/farm/` — farm_accounts
   - `src/brain/` — faculty_types, cortex, thalamus, etc.

2. Create root.zig for each new zone

3. Update build.zig with all zone modules

4. Update imports in queen and tri

**Estimated effort**: ~500 LOC, affects 30+ files

### Option B: Copy Functionality (Temporary)

1. Create queen-specific versions of conflicting modules in `src/queen/`
2. Use `@import("github_client.zig")` within queen zone (local import)

**Estimated effort**: ~300 LOC, creates duplication

### Option C: Interface Segregation (Recommended)

1. Create interface modules that don't import implementation:
   - `src/tri/github_client_iface.zig` — just type definitions
   - `src/queen/github_client_impl.zig` — actual implementation

2. Queen uses interfaces, tri uses implementations

**Estimated effort**: ~200 LOC, clean separation

## Latest Progress (2025-03-25)

**Agent A (import fixes) completed:**
- Removed `src/tri/queen.zig` (27k LOC redundant)
- Fixed queen imports: hippocampus, tri_colors → use module imports
- Added cortex_mod, faculty_types_mod, thalamus_mod, queen_ofc_mod to build.zig
- Updated tri/main.zig: faculty_board → cortex module

**Remaining blocker:**
- Circular module dependency still exists
- queen_dlpfc.zig imports `../tri/farm_accounts.zig` (relative path)
- Creates "file exists in both root and queen" conflict
- Requires architectural decision (see Options A-C above)

## Current Build Status

```
zig build tri: ❌ 1 error (module conflict)
zig build tri27: ✅ Passes (isolated)
zig build temple: ✅ Passes (isolated)
```

## Recommendation

**Defer to Wave 3** with proper zone separation. For now:
- Document the migration debt
- Keep temple, tri27, tri-lang working (✅)
- Accept that `zig build tri` will have errors until Q-zone migration

## Files Modified

- `src/temple/root.zig` — ✅ Created
- `src/tri-lang/root.zig` — ✅ Created
- `src/tri-lang/emu/root.zig` — ✅ Created
- `src/vsa.zig` — ✅ Modified
- `src/vsa/common.zig` — ✅ Modified
- `src/brain/root.zig` — ⚠️ Created (not used due to conflicts)
- `src/tri/root.zig` — ⚠️ Created (not used due to conflicts)
- `build.zig` — ✅ Modified (temple_mod, tri_lang_mod, brain modules moved, queen_mod)

## Import Law (Canon)

Added to `docs/research/trilanguage_canon.md` v1.2.0:

```markdown
### Import Law (Anti-Fragile Imports)

1. NEVER use relative path imports across zone boundaries
2. Every zone has root.zig that re-exports all public symbols
3. build.zig declares ALL zones as named modules
4. Within a zone, relative imports are allowed
5. Cross-zone imports MUST use named modules
```

---

**φ² + 1/φ² = 3 | TRINITY**
