# Contributing Tutorial

**15 minutes to your first contribution to Trinity**

---

## Goal

Make your first pull request to Trinity.

**What you will learn:**
- How the Golden Chain workflow works
- How to create VIBEE specifications
- How to do code review
- How to submit changes

---

## Golden Chain Workflow

Trinity uses a **16-step development cycle**:

```
1. Create .vibee spec
2. Generate code
3. Run tests
4. Write critical assessment
5. Propose 3 tech tree options
6. Get review
7. Make revisions
8. Merge
... (repeat)
```

---

## Step 1: Fork & Clone

```bash
# Fork on GitHub
# https://github.com/gHashTag/trinity

# Clone your fork
git clone https://github.com/YOUR_USERNAME/trinity.git
cd trinity
git remote add upstream https://github.com/gHashTag/trinity.git
```

---

## Step 2: Create Branch

```bash
# Create feature branch
git checkout -b feat/my-new-feature

# Or using TRI
./zig-out/bin/tri branch feat/my-new-feature
```

**Branch naming:**
- `feat/` — new feature
- `fix/` — bug fix
- `docs/` — documentation
- `refactor/` — refactoring

---

## Step 3: Create VIBEE Spec

```bash
# Create spec
cat > specs/tri/my_feature.vibee << 'EOF'
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  MyType:
    fields:
      value: Int

behaviors:
  - name: process
    given: input value
    when: process is called
    then: returns result
EOF
```

---

## Step 4: Generate Code

```bash
# Generate from spec
./zig-out/bin/tri gen specs/tri/my_feature.vibee

# Check generated code
cat trinity/output/my_feature.zig
```

---

## Step 5: Write Tests

```zig
// tests/my_feature_test.zig
const std = @import("std");
const MyFeature = @import("trinity/output/my_feature.zig");

test "process returns correct result" {
    const result = MyFeature.process(42);
    try std.testing.expectEqual(@as(i32, 42), result);
}
```

---

## Step 6: Run Tests

```bash
# Run all tests
zig build test

# Run specific test
zig test tests/my_feature_test.zig
```

---

## Step 7: Critical Assessment

Create a `CRITICAL_ASSESSMENT.md`:

```markdown
# Critical Assessment: My Feature

## What Works
- Code generates correctly
- Tests pass

## What Doesn't
- Error handling could be better
- Performance optimization needed

## Next Steps Options
1. Add error handling (recommended)
2. Optimize for performance
3. Add documentation
```

---

## Step 8: Commit & Push

```bash
# Stage changes
git add specs/tri/my_feature.vibee
git add trinity/output/my_feature.zig
git add tests/my_feature_test.zig

# Commit
git commit -m "feat: add my new feature

- Implements process function
- Adds unit tests
- Part of Golden Chain cycle N"

# Push
git push origin feat/my-new-feature
```

---

## Step 9: Create Pull Request

```bash
# Or using GitHub CLI
gh pr create --title "feat: add my new feature" \
  --body "See CRITICAL_ASSESSMENT.md for details"
```

**PR Template:**
```markdown
## Description
Brief description of changes.

## Changes
- [ ] Added VIBEE spec
- [ ] Generated code
- [ ] Added tests
- [ ] All tests pass

## Checklist
- [ ] Code follows style guide
- [ ] Tests added/updated
- [ ] Documentation updated
```

---

## Code Review Guidelines

**Reviewers check:**
1. VIBEE spec follows format
2. Generated code is idiomatic Zig
3. Tests cover edge cases
4. Documentation is clear
5. No sacred constants hardcoded

---

## After Merge

```bash
# Update your branch
git checkout main
git pull upstream main
git branch -d feat/my-new-feature
```

---

## Contributing Areas

| Area | Difficulty | Priority |
|------|-----------|----------|
| Documentation | Low | High |
| Tests | Medium | High |
| VIBEE specs | Medium | Medium |
| Core VSA | High | High |
| FPGA | High | Medium |

---

## What's Next?

| Resource | Link |
|----------|------|
| Contributing Guide | /contributing |
| Tech Tree | docs/TECH_TREE.md |
| Issues | github.com/gHashTag/trinity/issues |

---

**φ² + 1/φ² = 3 = TRINITY**
