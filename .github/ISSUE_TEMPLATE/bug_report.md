---
name: Bug report
about: Create a report to help us improve Trinity
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of what the bug is.

## Steps to Reproduce

1. Go to '...'
2. Run command '....'
3. Scroll to '....'
4. See error

**Expected Behavior:**
A clear and concise description of what you expected to happen.

**Actual Behavior:**
A clear and concise description of what actually happened. Include error messages, stack traces, or console output.

## Screenshots / Logs

If applicable, add screenshots, error logs, or terminal output to help explain your problem.

```bash
# Paste terminal output here
```

## Environment

- **Trinity Version:** (e.g., v8.27, see `zig build tri -- version`)
- **Zig Version:** (e.g., 0.15.0, see `zig version`)
- **Operating System:** (e.g., macOS 14.5, Ubuntu 22.04, Windows 11)
- **Architecture:** (e.g., x86_64, arm64)
- **Node.js Version:** (if running website/docsite, see `node --version`)

## Relevant Spec File

If this bug relates to generated code, include the `.vibee` specification:

```yaml
# specs/tri/_____.vibee
```

## Additional Context

Add any other context about the problem here:

- [ ] This bug is reproducible in the latest development version
- [ ] This bug prevents normal usage (blocking/critical)
- [ ] I have a workaround for this bug
- [ ] I'm willing to submit a PR to fix this

## Related Issues

- Related to #<issue_number>
- Blocks #<issue_number>
