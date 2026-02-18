# 🤖 Ralph v0.11.0 — Suborbital Order

Welcome to the autonomous heart of Trinity. **Ralph** is not just an agent; it's a workflow designed to help you build complex ternary AI systems with high reliability.

## 🚀 How to Start (The 1-2-3)

1.  **Requirement**: Ensure you have [Ralph](https://github.com/frankbria/ralph-claude-code) installed globally.
2.  **Pick a Task**: Open [.ralph/fix_plan.md](fix_plan.md) and add a task you want Ralph to do.
3.  **Launch**: Run `ralph --monitor` in your terminal. Watch Ralph work in the live dashboard.

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

## 🏢 Multi-Window Ralph (v0.11.0+)

Running Ralph with `--monitor` now creates two specialized windows:

1.  **Main (Window 1)**: Core loop, tool execution, and global status.
2.  **Symbolic (Window 2)**: Dedicated environment for **B2T** (Binary-to-Ternary) symbolic AI development.
    -   **B2T CLI**: Instant access to symbolic conversion tools.
    -   **B2T Tests**: Real-time test runner for symbolic logic.
    -   **B2T Trace**: State and trace monitoring for ternary VM.

**Shortcuts:**
*   `Ctrl+B n`: Next window (Main -> Symbolic)
*   `Ctrl+B p`: Previous window (Symbolic -> Main)
*   `Ctrl+B 0-1`: Switch to specific window by number.

## 💡 Pro Tip
When Ralph finishes a task, always check **`.ralph/memory/SUCCESS_HISTORY.md`**. It's the best way to learn the specific coding patterns used in this project!

---
*φ² + 1/φ² = 3 | Trinity Autonomous Dev*
