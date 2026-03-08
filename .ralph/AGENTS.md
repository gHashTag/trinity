# AGENTS.md — Agent Development Rules

## Parallel Documentation Rule

**ALL agents MUST document website changes in parallel with code changes.**

### The Golden Rule

> "Code without website documentation is HALF-DONE."

### Every Agent Action Requires

1. Code Change → Update `website/src/services/chatApi.ts`
2. New Widget → Add to `website/src/components/sections/`
3. New Feature → Create `docsite/docs/features/<feature>.md`
4. API Change → Update `docsite/docs/api/`

### Checklist Before Commit

```bash
cd website && npm run build
cd ../docsite && npm run build
git add website/ docsite/
git commit "feat: <feature> + website docs"
```

### Exit Criteria

A task is COMPLETE only when:

- [ ] Code works (tests pass)
- [ ] `website/` updated (API functions, components)
- [ ] `docsite/docs/` updated (documentation pages)
- [ ] Both sites build successfully
- [ ] Changes committed together

### Parallel Development Mapping

| Development Phase | Website Action |
|-------------------|----------------|
| **Spec** | Create draft doc in `docsite/docs/` |
| **Generate** | Add API to `chatApi.ts` |
| **Implement** | Create/update feature component |
| **Test** | Update benchmarks page |
| **Document** | Update docsite + sidebars |
| **Commit** | Include both code and website |

### Mandatory File Updates

For ANY feature addition:

```
website/src/services/chatApi.ts        # API functions
website/src/components/sections/       # Feature widgets
docsite/docs/                          # Technical docs
docsite/sidebars.ts                    # Navigation
```

### Deployment Rule

**ALWAYS deploy website and docsite TOGETHER with code.**

See `CLAUDE.md` → "Deployment (GitHub Pages)" for full procedure.

---

## Quick Reference

### Add API Function

```typescript
// website/src/services/chatApi.ts
export async function myFeature(input: string): Promise<Result> {
  return fetchWithError('/api/my-feature', { input });
}
```

### Add Widget

```tsx
// website/src/components/sections/MyFeatureWidget.tsx
export function MyFeatureWidget() {
  // Use glassStyle() + column colors
}
```

### Add Documentation

```markdown
# docsite/docs/features/my-feature.md
---
title: My Feature
sidebar_position: 10
---
```

---

*This file is part of the Ralph Autonomous Development System.*
