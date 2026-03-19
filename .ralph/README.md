# 🤖 Ralph — Trinity Autonomous Development

Welcome to the autonomous heart of Trinity. **Ralph** is the built-in workflow system for developing complex ternary AI systems with high reliability.

## 🚀 How to Start (The 1-2-3)

1.  **Build**: Run `zig build` to compile all binaries including `ralph-agent`.
2.  **Pick a Task**: Open [.ralph/fix_plan.md](fix_plan.md) and add a task you want Ralph to do.
3.  **Launch**: Run `./zig-out/bin/ralph-agent` or use `tri agent run <issue-number>` for autonomous issue resolution.

## 📂 What are these files?

If you're new, here's the "cheat sheet" for this directory:

| File | Purpose | Why you should care |
| :--- | :--- | :--- |
| **`fix_plan.md`** | **The Todo List** | Add new tasks here. Ralph picks the top uncompleted one. |
| **`RULES.md`** | **The Constitution** | Hard constraints on build, test, and architecture. |
| **`TECH_TREE.md`** | **The Roadmap** | Shows what's done and what can be built next. |
| **`memory/`** | **The Brain** | Stores `SUCCESS_HISTORY.md` and `REGRESSION_PATTERNS.md`. |
| **`scripts/`** | **The Tools** | Contains automation scripts (`gate.sh`, `audit.sh`, etc.). |
| **`internal/`** | **State Data** | Hidden files for session and call tracking. |
| **`logs/`** | **Runtime Info** | Real-time status and loop logs. |

## 🛠 Beginner Helper Scripts

You don't need to wait for Ralph to run these. You can use them manually:

*   `./.ralph/scripts/gate.sh`: "Am I okay to commit?" — Checks build, tests, and formatting.
*   `./.ralph/scripts/audit.sh`: "Is the project messy?" — Finds large files and unresolved TODOs.
*   `./.ralph/scripts/bench.sh`: "Is it still fast?" — Compares speed against the baseline.

## 🔧 Built-in Binaries

Trinity includes Ralph as built-in binaries:

| Binary | Purpose |
|--------|---------|
| `ralph-agent` | Sleep-wake daemon, picks GitHub issues |
| `ralph-hook` | Hook events → Telegram notifications |
| `scholar-agent` | Research-focused agent |
| `mu-agent` | Memory/learning agent |

## 💡 Pro Tip

## 💡 Pro Tip
When Ralph finishes a task, always check **`.ralph/memory/SUCCESS_HISTORY.md`**. It's the best way to learn the specific coding patterns used in this project!

---
*φ² + 1/φ² = 3 | Trinity Autonomous Dev*
