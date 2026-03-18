---
sidebar_position: 27
sidebar_label: Zenodo
---

# tri zenodo — Academic Publishing

Publish Trinity releases to Zenodo for DOI assignment and academic citation.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri zenodo publish <version>` | `<version-tag>` | Create new version, upload artifacts, publish |
| `tri zenodo status` | — | Show current Zenodo record info |
| `tri zenodo draft <version>` | `<version-tag>` | Create draft without publishing |

## Zenodo Record

- **Concept DOI:** `10.5281/zenodo.18947017`
- **Latest version:** `10.5281/zenodo.18950696` (v2.0.3)

## Examples

```bash
tri zenodo status                  # Check current record
tri zenodo draft v2.1.0            # Create draft for review
tri zenodo publish v2.1.0          # Publish new version
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ZENODO_TOKEN` | Yes | API token from [zenodo.org/account/settings/applications](https://zenodo.org/account/settings/applications/tokens/new/) |

## Handler

**File:** `src/tri/tri_zenodo.zig`
