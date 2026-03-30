# No Patronizing Labels Rule

**Rule**: Never label documentation audience as "school students", "kids", "12-14 year olds", "young learners".

## Principle

**Accessible, project-based documentation ≠ "for children".**

This is simply good UX. Rust Book, Go Tour, Gleam Tour — all use analogies and progressively complex projects. None of them announce "for school students" in their changelogs.

## Examples

| ❌ Avoid | ✅ Use Instead |
|----------|----------------|
| "Documentation for school students" | "Documentation created" |
| "Target audience: 12-14 year olds" | (don't mention age at all) |
| "Kids-friendly guide" | "Beginner-friendly guide" |
| "School documentation" | "Getting started guide" |
| "Young learners" | (nothing — just write clearly) |

## Applies To

- Commit messages
- Issue comments
- Agent reports
- Documentation summaries

## Why

Good documentation speaks for itself. If it's accessible, users will discover that. Announcing "this is for kids" creates an unnecessary hierarchy and can alienate adult beginners.

## Reference

- Rust Book — no age mentioned, just "helps you learn Rust"
- Zig Guide — "regardless of your systems programming experience"
- Gleam Tour — project-based learning, no age labels
