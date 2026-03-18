---
sidebar_position: 32
sidebar_label: Issue
---

# tri issue — GitHub Issue Management

Create, manage, and track GitHub issues. Every agent action is logged as an issue comment per the Trinity Protocol.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri issue list` | — | List open issues |
| `tri issue view <N>` | `<issue-number>` | View issue details |
| `tri issue create "<title>"` | `<title> [--body "..."]` | Create new issue |
| `tri issue comment <N>` | `<issue-number> --body "..."` | Add comment to issue |
| `tri issue close <N>` | `<issue-number>` | Close issue |
| `tri issue assign <N>` | `<issue-number> --assignee <user>` | Assign issue |
| `tri issue decompose <N>` | `<issue-number>` | Break issue into sub-issues |

## Examples

```bash
tri issue list                     # List open issues
tri issue view 42                  # View issue #42
tri issue create "Add FPGA tests"  # Create new issue
tri issue comment 42 --body "Step 1 complete"  # Add progress comment
tri issue close 42                 # Close issue
tri issue decompose 42             # Create sub-issues
```

## Handler

**File:** `src/tri/github_commands.zig:61-87`
