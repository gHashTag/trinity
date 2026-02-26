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
tri log
```

Runs `git log --oneline -10` (last 10 commits).

**Example output:**

```
Git log
cecd6e5 Add DONE file - NEXUS Source Migration complete
7b814f7 NEXUS-011: Migrate remaining core/ files
bd39cf0 docs(v7): Add v7 Self-Improving Codegen section
994f231 Merge pull request #12
58a91e8 fix(v7): 138.2% overcount bug
```

