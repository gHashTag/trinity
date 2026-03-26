# .autonomous/ — MOVED

> **Status**: Scratchpad only — NOT source of truth

All governance and logs have moved to `.trinity/`:

| Old Path | New Path | Purpose |
|----------|----------|---------|
| `.autonomous/HIVELOG.md` | `.trinity/queen/HIVELOG.md` | Master swarm log |
| `.autonomous/tdgs3-progress.md` | `.trinity/hippocampus/tdgs3-progress.md` | TDGS tracking |
| N/A | `.trinity/agents/{ZONE}/HIVELOG.md` | Per-agent logs |
| N/A | `.trinity/thalamus/agent_reports/` | Structured JSON reports |

## What Remains Here

- Temporary scratch files (safe to delete)
- Agent workspace directories (issue-specific)
- Development artifacts

## Single Source of Truth

All truth lives in `.trinity/**`:
- `.trinity/queen/HIVELOG.md` — Consolidated swarm log
- `.trinity/agents/{ZONE}/HIVELOG.md` — Per-agent detailed logs
- `.trinity/thalamus/agent_reports/*.json` — Structured reports
- `.trinity/hippocampus/` — Long-term memory

---
*Created: 2026-03-25*
*Reason: NA-R11 Alphabet Canon 27 + Queen-Agent Bridge*
