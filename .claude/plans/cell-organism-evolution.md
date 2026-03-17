# Cell Organism Evolution — Decomposed TODO

## Context
- **Done**: CELL_SCAN_DIRS unified in `src/tri/const.zig` (all 116 cells visible)
- **Current State**: Ribosome, Cytoplasm, Plugin layers see full organism
- **Next**: Wave 3 integration (dual-write cytoplasm ↔ hippocampus)

---

## 🔴 CRITICAL (Wave 3 Blockers)

### C1. Dual-Write Protocol: Cytoplasm ↔ Hippocampus
**Why**: Cell health changes must persist in memory for learning patterns
**Effort**: ~200 LOC

- [ ] C1.1 Define `CellHealthEvent` struct (cell_id, health_delta, timestamp, trigger)
- [ ] C1.2 Add `hippocampus.storeCellHealth()` API
- [ ] C1.3 Hook into `cytoplasm.runHealth()` after each cell scan
- [ ] C1.4 Add replay: `hippocampus.getCellHistory(id, days)` → trend graph
- [ ] C1.5 Test: modify cell.tri → verify event written to hippocampus

**Dependencies**: `src/tri/hippocampus.zig` exists, needs API extension

### C2. Missing [biology] Section Detection
**Why**: 8 agents in `tools/agents/` have no bio_system → "unclassified"
**Effort**: ~100 LOC

- [ ] C2.1 Run `tri cell bio | grep unclassified` → list offenders
- [ ] C2.2 Auto-suggest bio_system based on path (`tools/agents/*` → `immune`)
- [ ] C2.3 Interactive: `tri cell fix-bio <agent>` → patch cell.tri
- [ ] C2.4 Bulk: `tri cell fix-bio --all` → patch all missing

**Files**: `tools/agents/{queen-*,tri-*}/cell.tri`

---

## 🟡 HIGH (Wave 3 Readiness)

### H1. Cell Health Dashboard — Live Monitoring
**Why**: See organism state at glance, catch regressions early
**Effort**: ~150 LOC

- [ ] H1.1 `tri cell watch` — TUI dashboard with auto-refresh (5s)
- [ ] H1.2 Color coding: 🟢 healthy (80-100), 🟡 recovering (50-79), 🔴 critical (<50)
- [ ] H1.3 Top 5 worst cells + suggestion (tri cell fix <id>)
- [ ] H1.4 Trend arrow (↑↓) vs last scan
- [ ] H1.5 Export: `tri cell health --json > dashboard.json`

**Tech**: ncurses-like ANSI codes (no deps), reuses `runHealth()` logic

### H2. Auto-Registration: New Cell Detection
**Why**: Adding new cell should auto-register, not manual discovery
**Effort**: ~120 LOC

- [ ] H2.1 `.git/hooks/post-commit` → run `tri cell check --auto-register`
- [ ] H2.2 `const.zig`: add `WATCH_DIRS` for auto-detection
- [ ] H2.3 New cell.tri detected → prompt: "Register new cell? [y/N]"
- [ ] H2.4 Auto-suggest bio_system from path patterns
- [ ] H2.5 Write to `.trinity/cells/registry.json` (append mode)

**Integration**: Git hook + `tri cell` command

### H3. Cell Dependency Validation
**Why**: Broken deps = silent failures, hard to debug
**Effort**: ~80 LOC

- [ ] H3.1 `tri cell deps --validate` → check each dep exists
- [ ] H3.2 Detect orphan cells (no one depends on them)
- [ ] H3.3 Detect circular deps (A→B→A)
- [ ] H3.4 Score: dep_health = valid_deps / total_deps
- [ ] H3.5 Fail build if dep_health < 0.8 (configurable)

**Existing**: `runDeps()` exists, add validation mode

---

## 🟢 MEDIUM (Quality of Life)

### M1. Cell Scan Performance Optimization
**Why**: 116 cells = ~2s scan, will slow down with 200+
**Effort**: ~60 LOC

- [ ] M1.1 Cache manifest parse results (`.zig-cache/cells/`)
- [ ] M1.2 Invalidate on cell.tri mtime change
- [ ] M1.3 Parallel scan: `std.Thread.Pool` across CELL_SCAN_DIRS
- [ ] M1.4 Benchmark: before/after (target: <500ms for 200 cells)

### M2. Cell Test Coverage Enforcement
**Why**: Cells without tests = brittle organism
**Effort**: ~50 LOC

- [ ] M2.1 `tri cell coverage` → % cells with tests > 0
- [ ] M2.2 Fail pre-commit if coverage < 70%
- [ ] M2.3 `tri cell init --with-test` → scaffold test file
- [ ] M2.4 Track in registry.json: `tests: true/false`

### M3. Cell Version Tracking
**Why**: Know which cells need regeneration after API change
**Effort**: ~70 LOC

- [ ] M3.1 Store `cell_version` in registry.json (hash of cell.tri)
- [ ] M3.2 `tri cell outdated` → list cells with old version
- [ ] M3.3 `tri cell regenerate --outdated` → batch regen
- [ ] M3.4 Add `[cell] core_version` min requirement check

---

## 🔵 LOW (Nice to Have)

### L1. Cell Graph Visualization
**Why**: See dependency relationships visually
**Effort**: ~100 LOC

- [ ] L1.1 `tri cell graph --output deps.svg` → Mermaid → SVG
- [ ] L1.2 Color by bio_system (DNA=blue, Brain=purple, etc.)
- [ ] L1.3 Highlight problem cells (health < 50)
- [ ] L1.4 Interactive HTML with D3.js (optional)

### L2. Cell Search & Discovery
**Why**: Quick find by tag, capability, name
**Effort**: ~60 LOC

- [ ] L2.1 `tri cell search <query>` → fuzzy match name/id/desc
- [ ] L2.2 `tri cell find --capability "http"` → filter by contributes
- [ ] L2.3 `tri cell list --tag scope:brain` → filter by tags

### L3. Cell Template Library
**Why**: Accelerate new cell creation with patterns
**Effort**: ~80 LOC

- [ ] L3.1 `tri cell init --template <name>` (e.g. "agent", "tool", "fpga")
- [ ] L3.2 Store templates in `src/tri/templates/`
- [ ] L3.3 Template vars: {{CELL_ID}}, {{BIO_SYSTEM}}, {{CAPABILITIES}}
- [ ] L3.4 Custom templates: user can add `~/.tri/templates/`

---

## 📊 Metrics & Tracking

### Success Criteria
- [ ] **Cell Discovery**: 116 cells (baseline) → grows with project
- [ ] **Scan Time**: <500ms for 200 cells (from ~2s for 116)
- [ ] **Biology Coverage**: >95% cells have [biology] section (current: ~93%)
- [ ] **Test Coverage**: >70% cells have tests (current: TBD)
- [ ] **Health Score**: >80/100 sustained (current: 79/100)

### Regression Prevention
- [ ] Add to CI: `tri cell check --ci` → fail on issues
- [ ] Nightly: `tri cell health --json > .trinity/metrics/health.json`
- [ ] Alert: if health drops >10 points → notify via Telegram

---

## 🔄 Wave 3 Integration Path

```
const.zig (116 cells)
    ↓
[C1] Dual-write → hippocampus (health events)
    ↓
[H1] Dashboard → visual monitoring
    ↓
[C2] Fix missing bio → 100% coverage
    ↓
[H2] Auto-register → self-expanding organism
    ↓
[M3] Version tracking → regeneration trigger
```

---

## Estimated Effort Summary

| Priority | Tasks | LOC | Time |
|----------|-------|-----|------|
| 🔴 CRITICAL | 2 | ~300 | 1-2 days |
| 🟡 HIGH | 3 | ~370 | 2-3 days |
| 🟢 MEDIUM | 3 | ~180 | 1-2 days |
| 🔵 LOW | 3 | ~240 | 1-2 days |
| **Total** | **11** | **~1090** | **5-9 days** |

---

## Suggested Execution Order

1. **C1** (dual-write) — enables Wave 3 learning loop
2. **C2** (fix bio) — quick win, improves health score
3. **H1** (dashboard) — visibility into organism state
4. **H2** (auto-register) — reduces friction adding cells
5. **H3** (deps validation) — prevents broken builds

After H1-H3: organism is self-monitoring, self-expanding. Wave 3 can rely on stable cell infrastructure.
