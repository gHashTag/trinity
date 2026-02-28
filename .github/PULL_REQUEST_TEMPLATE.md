## Description

Briefly describe what this PR does and why it's needed.

## Related Issue

Closes #<issue_number>
Related to #<issue_number>

## Specification Link

If this implements a feature from a `.vibee` specification, link it here:

**Spec:** `specs/tri/<feature_name>.vibee`
**Generated Code:** `trinity/output/<feature_name>.zig`

## Changes Made

<!-- List the main changes in this PR -->

- [ ] **Feature:** Added support for ...
- [ ] **Bug Fix:** Fixed issue where ...
- [ ] **Refactor:** Improved ...
- [ ] **Documentation:** Updated ...
- [ ] **Tests:** Added tests for ...

### Files Changed

- `src/file1.zig` - Description of changes
- `specs/tri/feature.vibee` - Updated specification
- `trinity/output/feature.zig` - Generated code (DO NOT EDIT MANUALLY)
- `docs/feature.md` - Documentation updates

## Golden Chain Checklist

All PRs MUST follow the Golden Chain workflow:

- [ ] **Spec First:** Created `.vibee` specification before writing code
- [ ] **Code Generation:** Generated code with `zig build vibee -- gen specs/tri/<feature>.vibee`
- [ ] **Tests Pass:** `zig build test` passes (100% coverage for new code)
- [ ] **Format Applied:** `zig fmt src/` applied (code follows style guide)
- [ ] **No Forbidden Files:** No `.html`, `.css`, `.js`, `.ts`, `.jsx`, `.tsx` files (use VIBEE gen)
- [ ] **No Manual Edits:** Did not manually edit files in `trinity/output/`

## Testing Checklist

- [ ] **Build:** `zig build` completes without errors
- [ ] **Unit Tests:** `zig test src/<module>.zig` passes
- [ ] **Integration Tests:** `zig build test` passes all tests
- [ ] **Verification:** Ran `tri verify` (Links 7-11: tests + benchmarks)
- [ ] **Manual Testing:** Tested the feature manually in real-world scenarios
- [ ] **Documentation:** Updated docs in `docsite/docs/` if needed
- [ ] **Dashboard Widget:** Added Canvas Mirror widget if new module (see CLAUDE.md)

### Test Results

```bash
# Paste test output here
zig build test
# All tests passed!
```

### Performance Impact

- [ ] Performance improved (include benchmarks below)
- [ ] No performance change
- [ ] Performance degraded (explain why acceptable)

**Benchmarks (if applicable):**
```bash
zig build bench
# Paste results here
```

## Breaking Changes

Does this PR introduce breaking changes?

- [ ] **No** - This PR is backward compatible
- [ ] **Yes** - This PR contains breaking changes

### If Yes, describe breaking changes:

1. **Change:** ...
   - **Impact:** ...
   - **Migration Guide:** ...

## 🔥 TOXIC VERDICT

**CRITICAL:** Perform honest self-assessment of this PR before requesting review.

### What Works
- List what actually works in this PR
- Be specific and evidence-based
- Include metrics, test results, screenshots

### What Doesn't Work
- List what doesn't work or needs improvement
- Be honest about limitations
- No sugarcoating - if it's broken, say so

### Tech Debt
- What technical debt does this PR introduce?
- Is there a better way we deferred?
- What should be cleaned up later?

### Known Issues
- Any edge cases not handled?
- Performance concerns?
- Security implications?
- What tests are missing?

### Metrics
- **Before:** ___ | **After:** ___ | **Δ:** ___%
- **Test Coverage:** ___%
- **Benchmark Improvement:** ___%

### Toxic Verdict

**Overall Assessment:** [APPROVE / REQUEST CHANGES / REJECT]

**Reasoning:**
Provide honest, critical assessment. If this PR should be blocked or rewritten, say so.

**Self-Score:** __/10

## 🌳 TECH TREE Options

Based on this PR, propose 3 next steps for the project's evolution:

### Option 1: [Name]
- **Description:** ...
- **Pros:** ...
- **Cons:** ...
- **Complexity:** ★☆☆☆☆ to ★★★★★
- **Estimated Effort:** ...
- **Tech Tree Branch:** ...

### Option 2: [Name]
- **Description:** ...
- **Pros:** ...
- **Cons:** ...
- **Complexity:** ★☆☆☆☆ to ★★★★★
- **Estimated Effort:** ...
- **Tech Tree Branch:** ...

### Option 3: [Name]
- **Description:** ...
- **Pros:** ...
- **Cons:** ...
- **Complexity:** ★☆☆☆☆ to ★★★★★
- **Estimated Effort:** ...
- **Tech Tree Branch:** ...

**Recommendation:** Option [X] is the best next step because ...

## Sacred Mathematics (if applicable)

If this PR involves sacred mathematics, golden ratio, or ternary computing:

- **Trit Balance:** [-1, 0, +1] distribution
- **Golden Ratio:** φ = 1.618... used in ...
- **Lucas Numbers:** L(n) sequence applied to ...
- **VSA Operations:** bind/unbind/bundle improvements

## Deployment Notes

- [ ] Website deployment required (see `CLAUDE.md` "Deployment" section)
- [ ] Docsite deployment required
- [ ] Database migration required
- [ ] Configuration changes required
- [ ] Environment variable changes required

**Deployment Steps:**
1. Build website: `cd website && npx vite build`
2. Build docsite: `cd docsite && npm run build`
3. Assemble and deploy to gh-pages (see CLAUDE.md)

## Reviewer Notes

Any specific areas you'd like reviewers to focus on:

- "Pay special attention to the ..."
- "The implementation of ... is tricky because ..."
- "I'm unsure about the best approach for ..."

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have tested this PR locally
- [ ] I have updated the TECH_TREE.md if this completes a milestone
- [ ] I have documented this achievement in `docsite/docs/research/` (if applicable)
- [ ] I have added a Canvas Mirror widget for new modules (see CLAUDE.md)
