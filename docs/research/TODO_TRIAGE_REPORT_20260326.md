# TODO/FIXME Triage Report

**Generated**: 2026-03-26
**Total Occurrences Found**: 277 TODO/FIXME/XXX/HACK comments across 107 files

## Summary

| Type | Count | Priority |
|------|-------|----------|
| TODO | 200+ | Varies |
| FIXME | 50+ | High |
| XXX | 15+ | Critical |
| HACK | 10+ | Review needed |

## Priority Breakdown

### P0 - Critical (blocks releases)

None found - codebase is buildable and tests pass.

### P1 - High (should be addressed soon)

| File | Issue | Suggested Action |
|------|-------|------------------|
| `src/tri/pathology.zig` | 14 HACK/TODO | Consolidate error handling patterns |
| `src/tri/cytoplasm.zig` | 13 TODO | Complete agent lifecycle management |
| `src/tri/tri_commands.zig` | 31 TODO | Finish CLI command implementations |
| `src/tri-lang/gen_tri_lang_tests_manual.zig` | 10 TODO | Complete test coverage |
| `src/tri-lang/tri_lang_tests_manual.zig` | 10 TODO | Complete test coverage |

### P2 - Medium (technical debt, no immediate impact)

| File | Issue | Notes |
|------|-------|-------|
| `src/hslm/fpga_backend.zig` | 6 TODO | FPGA optimization opportunities |
| `src/vibeec/verified_seed_validator.zig` | 5 TODO | Validation improvements |
| `src/vibeec/semantic_dedup.zig` | 5 TODO | Deduplication enhancements |
| `src/vibeec/reasoning_engine.zig` | 4 TODO | Reasoning improvements |
| `src/tri/dev_guarded.zig` | 7 TODO | Dev workflow refinements |

### P3 - Low (nice to have)

| File | Issue | Notes |
|------|-------|-------|
| `src/tri/emu/tri_asm.zig` | 6 TODO | Assembly language enhancements |
| `src/bsd/vsa_fpga.zig` | 7 TODO | FPGA VSA optimizations |
| Various | 1-2 TODO each | Minor enhancements |

## Categorized by Type

### Error Handling (30+ items)
- Files: `src/tri/pathology.zig`, `src/queen/queen_trinity.zig`
- Status: Core error handling works, edge cases documented
- Recommendation: Document current patterns, add error codes

### Test Coverage (40+ items)
- Files: `src/tri-lang/*`, `src/vibeec/*`
- Status: Core tests pass, additional tests documented
- Recommendation: Add to test backlog, prioritize by user-facing code

### Performance Optimization (50+ items)
- Files: `src/hslm/*`, `src/bsd/*`, `src/vsa/*`
- Status: Current implementation has good performance (SIMD working)
- Recommendation: Benchmark before optimizing, track in performance.md

### Feature Implementation (100+ items)
- Files: `src/tri/*`, `src/vibeec/*`, `src/agent_mu/*`
- Status: Many planned features documented
- Recommendation: Move to GitHub issues, prioritize by demand

## Recommendations

1. **Create GitHub Issues** for P1 items
2. **Document patterns** for recurring TODOs (error handling, tests)
3. **Remove obsolete TODOs** - audit items that may already be complete
4. **Add TODO labels** to track progress in project board
5. **Set quarterly TODO cleanup** sprints

## Next Steps

1. Create issues for P1 items with clear acceptance criteria
2. Add `// TODO-TRACKING: issue #N` comments to link to issues
3. Run `zig build test-all` when implemented to verify no regressions
4. Update this report quarterly

---

*This report was generated automatically. For updates, run:*
```bash
grep -r "TODO\|FIXME\|XXX\|HACK" src/ --include="*.zig" | wc -l
```
