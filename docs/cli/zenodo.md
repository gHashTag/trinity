# `tri zenodo` — Zenodo CLI Commands

> Part of the Trinity CLI — see [ZENODO_HUB](../ZENODO_HUB.md) for complete reference

## Commands

### `tri zenodo publish <version>`

Create a new version, upload to Zenodo, and publish.

```bash
tri zenodo publish 8.0
```

**What it does:**
1. Creates a new version on Zenodo
2. Uploads all metadata files
3. Publishes immediately (visible publicly)

### `tri zenodo status`

Show current record information.

```bash
tri zenodo status
```

**Output:**
- Current DOI
- Version number
- Publication date
- File counts

### `tri zenodo draft <version>`

Create a draft version without publishing.

```bash
tri zenodo draft 8.0
```

**What it does:**
1. Creates a new version on Zenodo
2. Uploads all metadata files
3. Keeps as draft (not publicly visible)

### `tri zenodo bundle <A-G>`

Publish an individual bundle.

```bash
tri zenodo bundle A  # B001
tri zenodo bundle B  # B002
tri zenodo bundle C  # B003
tri zenodo bundle D  # B004
tri zenodo bundle E  # B005
tri zenodo bundle F  # B006
tri zenodo bundle G  # B007
```

**Bundle aliases:** A=B001, B=B002, C=B003, D=B004, E=B005, F=B006, G=B007

### `tri zenodo validate <bundle>`

Validate metadata quality.

```bash
tri zenodo validate B001
tri zenodo validate A  # Same as B001
```

**Checks:**
- Title format
- Authors (ORCID required)
- Abstract length
- Keywords count
- Year validity
- DOI format
- arXiv ID format (if applicable)

### `tri zenodo generate <bundle>`

Generate full JSON metadata from templates.

```bash
tri zenodo generate B001
tri zenodo generate PARENT
```

**Output:** JSON file with all metadata fields populated

## Environment

Set your Zenodo API token:

```bash
export ZENODO_TOKEN="your-token-here"
```

Get token: https://zenodo.org/account/settings/applications/tokens/new

## Implementation

Source code: `src/tri/tri_zenodo.zig` (~58K LOC)

---

**See also:** [ZENODO_HUB](../ZENODO_HUB.md) | [Python Upload Script](../../tools/zenodo_upload_v8.py)
