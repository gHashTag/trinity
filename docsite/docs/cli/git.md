---
sidebar_position: 7
sidebar_label: Git
---

# Version Control

Built-in Git commands for commit, diff, status, and log.

## commit

Stage all changes and commit.

```bash
tri commit [message]
tri commit "feat: add new module"
```

Runs `git add -A` followed by `git commit -m "message"`. Displays stdout/stderr with color formatting.

**Important:** `git add -A` stages **all** changes including new files, modifications, and deletions. This is intentional — TRI CLI follows the "commit everything" philosophy for development cycles.

## diff

Show working tree changes.

```bash
tri diff
```

Runs `git diff --color=always`. Supports up to 10MB output.

**Example output:**

```
Git diff
diff --git a/src/tri/main.zig b/src/tri/main.zig
--- a/src/tri/main.zig
+++ b/src/tri/main.zig
@@ -58,6 +58,7 @@
+    .new_command => tri_commands.runNewCommand(args),
```

## status

Show concise file status.

```bash
tri status
```

Runs `git status --short`.

**Example output:**

```
Git status
 M src/tri/main.zig
 M src/tri/tri_commands.zig
?? new_file.zig
```

## log

Show recent commit history.

```bash
tri log              # Last 10 commits (default)
tri log 20           # Last 20 commits
```

Runs `git log --oneline -N` where N defaults to 10. Pass a number to customize the count.

**Example output:**

```
Git log
cecd6e5 Add DONE file - NEXUS Source Migration complete
7b814f7 NEXUS-011: Migrate remaining core/ files
bd39cf0 docs(v7): Add v7 Self-Improving Codegen section
994f231 Merge pull request #12
58a91e8 fix(v7): 138.2% overcount bug
```

## Implementation

All git commands execute shell commands via Zig's `std.process.Child` with a 10MB output buffer. The output is displayed with color formatting (stdout in green, stderr in red).

| Command | Shell equivalent | Output buffer |
|---------|-----------------|---------------|
| `tri status` | `git status --short` | 10 MB |
| `tri diff` | `git diff --color=always` | 10 MB |
| `tri log [N]` | `git log --oneline -N` | 10 MB |
| `tri commit <msg>` | `git add -A && git commit -m "<msg>"` | 10 MB |

## Pipeline Integration

Git commands are used in **Link 15** of the [Golden Chain pipeline](/cli/pipeline). After the toxic verdict (Link 14), changes are automatically committed and pushed:

```
Link 15: GIT
  git add -A
  git commit -m "cycle(N): <description>"
  git push
```

## See Also

- [Pipeline](/cli/pipeline) — Link 15 (Git commit) in the Golden Chain
- [Swarm](/cli/swarm) — `swarm status` also shows git info

