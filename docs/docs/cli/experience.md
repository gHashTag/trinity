---
sidebar_position: 33
sidebar_label: Experience
---

# tri experience — Memory & Learning

Persistent episode storage, mistake pattern tracking, and ExpeL (Experience + Learning) log.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri experience save` | `[options]` | Save episode to `.trinity/experience/episodes/` |
| `tri experience recall` | `[--task "query"] [--type TYPE] [--category CAT]` | Recall episodes by keyword or filter |
| `tri experience mistakes` | — | Show mistake patterns sorted by frequency |

## Options for `tri experience save`

| Option | Default | Description |
|--------|---------|-------------|
| `--issue <N>` | — | GitHub issue number |
| `--task "<desc>"` | *(required)* | Task description |
| `--verdict <v>` | `UNKNOWN` | PASS / FAIL / PARTIAL |
| `--iterations <N>` | `1` | Number of iterations |
| `--mistake "<text>"` | — | Add mistake (up to 8) |
| `--learning "<text>"` | — | Add learning (up to 8) |

## Storage

| Path | Content |
|------|---------|
| `.trinity/experience/episodes/{issue}_{ts}.json` | Episode records |
| `.trinity/experience/mistakes/{hash}.json` | Mistake patterns |
| `EXPERIENCE_LOG.md` | ExpeL log (human-readable) |

## Examples

```bash
tri experience save --task "Fix build" --verdict PASS --learning "Check imports"
tri experience recall --task "build"    # Find related episodes
tri experience mistakes                 # Show common mistakes
```

## Handler

**File:** `src/tri/tri_experience.zig`
